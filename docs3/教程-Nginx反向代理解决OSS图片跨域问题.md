# Nginx 反向代理解决 OSS 图片跨域不显示问题

> 最后更新: 2026-06-19
>
> **适用场景：** 前端页面引用了第三方 OSS（如阿里云 OSS）上的图片，但图片无法在浏览器中显示。

---

## 一、问题现象

部署完成后，浏览器访问 http://106.53.106.41:8085（商城 H5 首页），发现：

- 页面框架、文字、布局正常
- **所有来自阿里云 OSS 的图片都不显示**（轮播图空白、品牌 logo 缺失、商品图片缺失）
- 本地图标（如专题、话题等 `/static/` 下的图标）正常显示

打开浏览器 F12 开发者工具 → Network 标签页，可以看到：

```
GET http://macro-oss.oss-cn-shenzhen.aliyuncs.com/mall/images/20221108/xiaomi_banner_01.png
Status: (failed)
net::ERR_BLOCKED_BY_ORB
```

所有 OSS 图片请求都返回 `ERR_BLOCKED_BY_ORB`。

---

## 二、原因分析

### 2.1 什么是 ORB（Opaque Response Blocking）

ORB 是浏览器的一种安全机制，会阻止跨域的"不透明响应"。当以下条件同时满足时，浏览器会拦截请求：

1. **跨域请求**：页面在 `http://106.53.106.41:8085`，图片在 `http://macro-oss.oss-cn-shenzhen.aliyuncs.com`
2. **OSS 未返回正确的 CORS headers**：阿里云 OSS 默认不配置跨域访问头（`Access-Control-Allow-Origin`）
3. **请求类型触发 ORB**：图片、字体等资源会被 ORB 拦截

### 2.2 为什么 curl 能访问但浏览器不行

```bash
# 服务器上执行 - 返回 200 OK
curl -sI http://macro-oss.oss-cn-shenzhen.aliyuncs.com/mall/images/20221108/xiaomi_banner_01.png
# HTTP/1.1 200 OK
```

**curl 没有跨域安全策略**，它直接请求 OSS 并拿到响应。但浏览器遵循同源策略（Same-Origin Policy），会检查响应头中是否包含 CORS 相关字段。

### 2.3 为什么其他服务器能访问

日志中可以看到其他 IP（如 114.132.203.195）请求同一张图片返回 200。这可能是因为：

- 这些请求来自不同的网络环境（直连 OSS 无代理）
- 或者 OSS 对某些来源做了白名单

但无论如何，**你的前端页面通过代理服务器访问 OSS 时，浏览器会因 CORS 策略拦截**。

---

## 三、解决方案：Nginx 反向代理

### 3.1 原理

```
┌──────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   浏览器      │────▶│  Nginx 代理       │────▶│  阿里云 OSS     │
│  106.53.106.41│     │  /oss/mall/images/│     │  macro-oss...   │
└──────────────┘     └──────────────────┘     └─────────────────┘
       │                      │                        │
       │  不跨域（同源）       │  跨域但服务端不检查      │
       │  200 OK              │  200 OK                 │
```

- 浏览器请求 `/oss/mall/images/xxx.png` → 同源请求，不触发 CORS
- Nginx 代理请求 `http://macro-oss.../mall/images/xxx.png` → 服务端直接访问，不受 CORS 限制
- 图片正常返回给浏览器

### 3.2 Nginx 配置

```nginx
# OSS 上游服务器
upstream oss {
    server macro-oss.oss-cn-shenzhen.aliyuncs.com:80;
}

server {
    # ...

    # ========================================
    #  OSS 图片反向代理
    #  ^~ 前缀匹配，优先级高于正则匹配
    #  （避免 .png/.jpg 被静态文件规则拦截）
    # ========================================
    location ^~ /oss/ {
        proxy_pass http://macro-oss.oss-cn-shenzhen.aliyuncs.com/;
        proxy_set_header Host macro-oss.oss-cn-shenzhen.aliyuncs.com;
        proxy_set_header Referer "";          # 关键：去掉 Referer 避免防盗链
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 图片缓存（内容不变，长期缓存）
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # ========================================
    #  API 响应中的 URL 重写
    #  将 OSS 绝对 URL 改为 /oss/ 相对路径
    # ========================================
    location /mall-portal/ {
        proxy_pass http://gateway;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 重写 OSS URL
        sub_filter 'http://macro-oss.oss-cn-shenzhen.aliyuncs.com' '/oss';
        sub_filter_once off;
        sub_filter_types application/json text/plain;
    }
}
```

### 3.3 关键配置解释

| 配置 | 作用 | 为什么需要 |
|------|------|-----------|
| `location ^~ /oss/` | 优先匹配 `/oss/` 路径 | 防止被 `location ~* \.(png\|jpg)$` 的正则规则拦截 |
| `proxy_pass http://macro-oss.../;` | 转发到 OSS | 末尾的 `/` 会替换 `/oss/` 前缀 |
| `proxy_set_header Referer "";` | 清空 Referer | 阿里云 OSS 有 Referer 防盗链，带了你的域名会被拒绝（403） |
| `sub_filter` | 替换 API 响应中的 URL | 后端返回 `http://macro-oss.../mall/images/xxx`，改为 `/oss/mall/images/xxx` |
| `sub_filter_once off` | 替换所有匹配 | 一个响应中可能有多张图片 URL |

---

## 四、涉及的知识点

### 4.1 CORS（Cross-Origin Resource Sharing）

浏览器的同源策略规定：协议、域名、端口三者都相同才算同源。跨域请求需要服务端返回 `Access-Control-Allow-Origin` 等响应头。

**OSS 默认不配置 CORS**，所以浏览器会拦截跨域的图片请求。

### 4.2 ORB（Opaque Response Blocking）

ORB 是 Chrome 68+ 引入的安全机制，针对 `no-cors` 模式的跨域请求。如果响应缺少 CORS 头，浏览器会"阻断"响应体。

`net::ERR_BLOCKED_BY_ORB` 就是 ORB 拦截的标志。

### 4.3 Nginx proxy_pass 路径替换

```nginx
location /oss/ {
    proxy_pass http://macro-oss.oss-cn-shenzhen.aliyuncs.com/;
}
```

- `location /oss/` 匹配 `/oss/mall/images/xxx.png`
- `proxy_pass` 末尾有 `/`，会将 `/oss/` 替换为 `/`
- 实际请求：`http://macro-oss.../mall/images/xxx.png`

如果 `proxy_pass` 末尾没有 `/`，则会保留原始路径，请求变成：
`http://macro-oss.../oss/mall/images/xxx.png`（404）

### 4.4 Nginx location 优先级

```
精确匹配 > ^~ 前缀匹配 > ~ 正则匹配 > 普通前缀匹配
```

文档中使用 `^~` 是因为还有这个正则规则：

```nginx
location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
    expires 7d;
    add_header Cache-Control "public, immutable";
}
```

如果不加 `^~`，`/oss/xxx.png` 会被正则规则匹配（返回 404 本地文件），而不是走代理。

### 4.5 sub_filter 响应体替换

Nginx 的 `sub_filter` 模块可以在代理响应时替换内容：

```nginx
sub_filter 'http://macro-oss.oss-cn-shenzhen.aliyuncs.com' '/oss';
sub_filter_once off;                    # 替换所有匹配（默认只替换第一个）
sub_filter_types application/json;      # 只对 JSON 响应生效
```

后端 API 返回：
```json
{"pic": "http://macro-oss.oss-cn-shenzhen.aliyuncs.com/mall/images/xxx.png"}
```

经过 `sub_filter` 后，浏览器收到：
```json
{"pic": "/oss/mall/images/xxx.png"}
```

### 4.6 Referer 防盗链

阿里云 OSS 支持 Referer 白名单防盗链。当请求带 `Referer` 头时，OSS 会检查 Referer 是否在白名单中。

Nginx 代理默认会转发浏览器的 `Referer` 头（如 `Referer: http://106.53.106.41:8085/`），OSS 不认这个来源，返回 403 Forbidden。

**解决方法**：在代理中设置 `proxy_set_header Referer "";`，清空 Referer 头。

---

## 五、验证方法

### 5.1 验证 sub_filter 是否生效

```bash
# 在 tengxun-server 上执行
curl -s http://127.0.0.1:8085/mall-portal/home/content | head -c 200
```

**预期**：图片 URL 显示为 `/oss/mall/images/...` 而不是 `http://macro-oss...`

### 5.2 验证 OSS 代理是否工作

```bash
# 模拟浏览器请求（带 Referer 头）
curl -s -o /dev/null -w '%{http_code}' \
  -H 'Referer: http://106.53.106.41:8085/' \
  -H 'User-Agent: Mozilla/5.0 Chrome/120' \
  http://127.0.0.1:8085/oss/mall/images/20221108/xiaomi_banner_01.png
```

**预期**：返回 `200`

### 5.3 浏览器验证

1. 打开 http://106.53.106.41:8085
2. 按 F12 打开开发者工具
3. 切换到 Network 标签页
4. 刷新页面
5. 检查图片请求是否都是 `/oss/...` 开头，状态码是否为 200

---

## 六、常见问题

### Q1: 代理返回 404

**原因**：`proxy_pass` 末尾缺少 `/`，导致路径未正确替换。

```nginx
# 错误 - 会请求 /oss/mall/images/xxx（不存在）
proxy_pass http://macro-oss.oss-cn-shenzhen.aliyuncs.com;

# 正确 - 会请求 /mall/images/xxx
proxy_pass http://macro-oss.oss-cn-shenzhen.aliyuncs.com/;
```

### Q2: 代理返回 403 Forbidden

**原因**：OSS 的 Referer 防盗链拦截了请求。

```nginx
# 添加这行
proxy_set_header Referer "";
```

### Q3: sub_filter 没生效

**原因**：响应的 Content-Type 不在 `sub_filter_types` 列表中。

```nginx
# 默认只处理 text/html，需要加上 JSON
sub_filter_types application/json text/plain;
```

### Q4: 图片加载很慢

**原因**：没有配置缓存，每次请求都走代理。

```nginx
expires 30d;
add_header Cache-Control "public, immutable";
```

---

## 七、总结

| 问题 | 原因 | 解决 |
|------|------|------|
| 图片不显示（ORB） | OSS 无 CORS 头，浏览器跨域拦截 | Nginx 反向代理，走同源 |
| API 返回绝对 URL | 后端返回 `http://macro-oss...` | `sub_filter` 重写为 `/oss/` |
| 代理返回 403 | OSS Referer 防盗链 | `proxy_set_header Referer ""` |
| /oss/ 路径返回 404 | 被正则规则拦截 | `^~` 前缀匹配优先级 |
| proxy_pass 路径错误 | 末尾缺少 `/` | `proxy_pass http://.../;` |
