# 云服务器部署 SOCKS5 代理 — 执行指南

> **给云服务器 AI 助手的完整指令文档**
>
> 背景：本地电脑网络不稳定，需要通过这台阿里云服务器（8.134.65.121）作为中转，让浏览器、Git、终端等所有流量都能稳定访问 GitHub 等外网服务。

---

## 一、为什么要做这件事？

### 1.1 问题背景

- **用户**在 Windows 11 本地写代码
- **本地网络不稳定**，经常无法访问 GitHub
- **这台阿里云服务器**可以稳定访问外网/GitHub
- 所以需要把服务器变成一个**稳定的代理出口**

### 1.2 之前的方案（已废弃）

之前用的是 `ssh -D 1080` 方案：在本地开一个 SSH 隧道，创建本地 SOCKS5 代理。

**致命缺陷**：
- 本地 SSH 隧道进程太脆弱 — 电脑休眠、WiFi 切换、网络波动都会断
- 断了之后浏览器代理就废了，Edge 没有任何反馈机制
- 每次都要手动重新执行命令，很麻烦

### 1.3 新方案（本文要做的）

**把代理服务直接部署到云服务器上**：

```
本地浏览器/Git/终端 → 直连 → 云服务器:20080(SOCKS5) → 目标网站(GitHub)
```

**优势**：
| 对比项 | 旧方案(ssh -D) | 新方案(云端 gost) |
|--------|---------------|-------------------|
| 稳定性 | 差（依赖本地进程） | **极强（服务器 24 小时在线）** |
| 本地依赖 | 需要维护 SSH 隧道进程 | **零依赖，直连即可** |
| 断线恢复 | 需要手动重连 | **自动恢复（systemd 守护）** |
| 浏览器反馈 | 断了完全没感知 | **连接失败会立即报错** |

---

## 二、技术选型：为什么用 gost？

选用 **gost**（https://github.com/ginuerzh/gost）作为代理服务端。

| 对比维度 | gost | microsocks | 3proxy |
|---------|------|-----------|--------|
| 单二进制部署 | ✅ 一个文件搞定 | ✅ | 需编译安装 |
| SOCKS5 密码认证 | ✅ 内置支持 | ❌ 不支持 | ✅ |
| systemd 服务化 | ✅ 简单配置 | 需手写脚本 | ✅ |
| 项目活跃度 | ✅ 持续维护 | 已停更 | 停更很久 |

---

## 三、安全设计

| 安全措施 | 说明 |
|---------|------|
| **用户名+密码认证** | 不是开放代理，只有知道密码的人才能用 |
| **非标准端口 20080** | 减少被扫描探测的风险 |
| **普通用户运行** | 不用 root 权限运行 gost 进程 |
| **日志记录** | 记录到 `/var/log/gost.log`，方便排查问题 |

**账号信息**：
- 用户名：`gao`
- 密码：`Gao2026Proxy`
- 端口：`20080`

> ⚠️ 以上密码仅作示例，生产环境请使用更强的密码。

---

## 四、执行步骤

### Step 1：下载并安装 gost

```bash
# 创建目录
mkdir -p /etc/gost /var/log

# 下载 gost（GitHub Release，Linux amd64 版本）
wget https://github.com/ginuerzh/gost/releases/download/v2.12.0/gost_2.12.0_linux_amd64.tar.gz -O /tmp/gost.tar.gz

# 如果 GitHub 下载慢或超时，尝试以下镜像源之一：
# 镜像1: wget https://mirror.ghproxy.com/https://github.com/ginuerzh/gost/releases/download/v2.12.0/gost_2.12.0_linux_amd64.tar.gz -O /tmp/gost.tar.gz
# 镜像2: wget https://ghfast.top/https://github.com/ginuerzh/gost/releases/download/v2.12.0/gost_2.12.0_linux_amd64.tar.gz -O /tmp/gost.tar.gz

# 解压并安装到系统路径
tar -xzf /tmp/gost.tar.gz -C /tmp
mv /tmp/gost /usr/local/bin/gost
chmod +x /usr/local/bin/gost

# 清理临时文件
rm -f /tmp/gost.tar.gz

# 验证安装成功
gost -version
```

**预期输出**：显示版本号如 `gost 2.12.0`（具体版本号可能略有差异）

---

### Step 2：创建 gost 配置文件

```bash
cat > /etc/gost/config.json << 'EOF'
{
  "ServeNodes": ["socks5://gao:Gao2026Proxy@:20080"],
  "Retries": 3,
  "Log": {
    "Output": "/var/log/gost.log",
    "Level": "warn"
  }
}
EOF
```

**配置逐项解释**：

| 配置项 | 值 | 含义 |
|-------|-----|------|
| `ServeNodes` | `socks5://gao:Gao2026Proxy@:20080` | 监听在 20080 端口，提供 SOCKS5 代理，需用户名密码认证 |
| `Retries` | `3` | 失败时自动重试 3 次 |
| `Log.Output` | `/var/log/gost.log` | 日志输出到这个文件 |
| `Log.Level` | `warn` | 只记录警告及以上级别的日志（减少日志量） |

> 注意 `@:20080` 中冒号前没有 IP 地址，表示监听在所有网卡上（即 `0.0.0.0:20080`），这样外网才能访问。

---

### Step 3：创建 systemd 服务（开机自启 + 自动重启）

```bash
cat > /etc/systemd/system/gost.service << 'EOF'
[Unit]
Description=GOST SOCKS5 Proxy Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/gost -C /etc/gost/config.json
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

**systemd 配置解释**：

| 配置项 | 含义 |
|-------|------|
| `After=network.target` | 等待网络就绪后再启动 |
| `Type=simple` | 前台运行的常驻进程类型 |
| `ExecStart` | 启动命令，`-C` 指定配置文件路径 |
| `Restart=always` | 进程崩溃后**自动重启** |
| `RestartSec=5` | 重启前等待 5 秒（防止频繁重启） |
| `WantedBy=multi-user.target` | 多用户模式下开机自启 |

---

### Step 4：启动服务并验证

```bash
# 重新加载 systemd 配置
systemctl daemon-reload

# 设置开机自启 并 立即启动
systemctl enable --now gost

# 查看运行状态
systemctl status gost
```

**预期输出**（关键部分）：
```
● gost.service - GOST SOCKS5 Proxy Server
   Loaded: loaded (/etc/systemd/system/gost.service; enabled; vendor preset: enabled)
   Active: active (running) since ...
```

重点确认：
- `Loaded:` 后面有 **enabled** → 开机自启已设置
- `Active:` 后面是 **active (running)** → 正在运行

---

### Step 5：验证代理是否工作

```bash
# 在服务器本地测试 SOCKS5 代理
curl -x socks5://gao:Gao2026Proxy@127.0.0.1:20080 https://httpbin.org/ip
```

**预期输出**：
```json
{
  "origin": "8.134.65.121"
}
```

如果返回的 IP 是 `8.134.65.121`（本机公网 IP），说明代理工作正常。

---

### Step 6：开放防火墙端口

```bash
# 方法1：如果有 ufw
ufw allow 20080/tcp comment "SOCKS5 Proxy"

# 方法2：如果有 firewalld
firewall-cmd --permanent --add-port=20080/tcp
firewall-cmd --reload

# 方法3：如果只有 iptables
iptables -I INPUT -p tcp --dport 20080 -j ACCEPT
# 注意：iptables 规则重启后会丢失，建议用 iptables-persistent 保存
apt install -y iptables-persistent   # 安装时会提示保存当前规则
```

> **⚠️ 最重要的一步**：除了系统防火墙，还必须去 **阿里云控制台 → ECS实例 → 安全组** 中添加入方向规则，放行 TCP 20080 端口！否则外网无法连接！

---

## 五、故障排查

### 问题：curl 测试返回错误

```bash
# 查看 gost 日志
tail -50 /var/log/gost.log

# 检查端口是否在监听
ss -tlnp | grep 20080
# 应该看到类似：LISTEN 0 128  *:20080  *:*  users:(("gost",pid=12345,...))

# 检查服务状态
systemctl status gost
```

### 问题：外网连不上

1. 确认阿里云安全组已放行 20080 端口
2. 确认系统防火墙（ufw/iptables）已放行
3. 确认 gost 配置中的地址是 `@:20080`（不是 `@127.0.0.1:20080`）

### 问题：想修改账号密码

```bash
# 编辑配置文件
nano /etc/gost/config.json

# 修改后重启服务
systemctl restart gost
```

### 问题：想停止/卸载

```bash
# 停止服务
systemctl stop gost

# 取消开机自启
systemctl disable gost

# 删除服务文件
rm /etc/systemd/system/gost.service
systemctl daemon-reload

# 删除程序和配置
rm /usr/local/bin/gost
rm -rf /etc/gost
```

---

## 六、完成后的下一步

服务器端部署完成后，**本地还需要做以下配置**（由用户在 Windows 上操作）：

1. **SwitchyOmega**（浏览器扩展）：新建情景模式指向 `8.134.65.121:20080`，协议 SOCKS5，填入账号密码
2. **SSH config**：更新 `Host github.com` 的 ProxyCommand 或保持现有 ProxyJump
3. **终端环境变量**：设置 `ALL_PROXY=socks5://gao:Gao2026Proxy@8.134.65.121:20080`
4. **验证**：浏览器访问 `https://httpbin.org/ip`，应返回 `8.134.65.121`

---

## 七、实际部署记录

### 7.1 部署时间

**2026-06-12 23:19 ~ 23:36（CST）**

### 7.2 部署过程摘要

| 步骤 | 状态 | 备注 |
|------|------|------|
| gost v2.12.0 安装 | ✅ | GitHub 直连下载成功（约8分钟） |
| 配置文件创建 | ✅ | `/etc/gost/config.json` |
| systemd 服务创建 | ✅ | enabled + active (running) |
| SOCKS5 代理测试 | ✅ | curl 返回 `8.134.65.121` |
| 系统防火墙 (ufw) | ✅ | 20080/tcp 已放行 |
| 端口监听确认 | ✅ | `*:20080` PID 正常 |

### 7.3 ⚠️ 重要踩坑：浏览器不支持 SOCKS5 密码认证

**问题现象**：

SwitchyOmega 配置 SOCKS5 协议 + 用户名密码后，弹出错误提示：

> **"您的浏览器不支持 socks5 认证！"**
> 所有网页无法访问。

**原因分析**：

浏览器的原生 SOCKS5 客户端实现**不支持 RFC 1929 的用户名/密码认证协议**。这是所有基于 Chromium 的浏览器（Edge、Chrome）的已知限制。SwitchyOmega 本质上依赖浏览器的网络栈，所以填了账号密码也没用。

**解决方案**：

在 gost 配置中额外添加一个 **HTTP 代理端口**（20081），因为 HTTP 代理的 Basic 认证是浏览器完全支持的：

```json
{
  "ServeNodes": [
    "socks5://gao:Gao2026Proxy@:20080",
    "http://gao:Gao2026Proxy@:20081"
  ],
  "Retries": 3,
  "Log": {
    "Output": "/var/log/gost.log",
    "Level": "warn"
  }
}
```

修改后执行 `sudo systemctl restart gost` 即可生效。

### 7.4 最终服务状态

```
● gost.service - GOST SOCKS5 Proxy Server
   Loaded: loaded (/etc/systemd/system/gost.service; **enabled**)
   Active: **active (running)** since Fri 2026-06-12 23:35:25 CST
   Main PID: 402876 (gost)

监听端口：
  LISTEN  *:20080  (SOCKS5 代理)
  LISTEN  *:20081  (HTTP 代理)
```

### 7.5 最终连接信息汇总

| 用途 | 协议 | 地址 | 端口 | 适用场景 |
|------|------|------|------|----------|
| 终端/Git/curl | SOCKS5 | `8.134.65.121` | **20080** | 命令行工具 |
| 浏览器(SwitchyOmega) | **HTTP** | `8.134.65.121` | **20081** | Edge / Chrome |

**共同凭据**：
- 用户名：`gao`
- 密码：`Gao2026Proxy`

### 7.6 SwitchyOmega 正确配置

| 字段 | 值 |
|------|-----|
| 协议 | **HTTP**（不是 SOCKS5！） |
| 服务器 | `8.134.65.121` |
| 端口 | **20081** |
| 用户名 | `gao` |
| 密码 | `Gao2026Proxy` |

> 如果选了 SOCKS5，即使填了账号密码也会报"不支持socks5认证"的错误。

### 7.7 终端使用方式

```bash
# 方式1：SOCKS5（推荐给 git、curl 等命令行工具）
export ALL_PROXY=socks5://gao:Gao2026Proxy@8.134.65.121:20080

# 方式2：HTTP（同样可用）
export ALL_PROXY=http://gao:Gao2026Proxy@8.134.65.121:20081

# 单次使用测试
curl -x http://gao:Gao2026Proxy@8.134.65.121:20081 https://httpbin.org/ip
# 预期返回：{"origin": "8.134.65.121"}
```

### 7.8 阿里云安全组需放行的端口

| 端口 | 协议 | 用途 | 状态 |
|------|------|------|------|
| 20080 | TCP | SOCKS5 代理 | ✅ 已在安全组放行 |
| 20081 | TCP | HTTP 代理 | ⚠️ **需手动去安全组放行** |

> 操作路径：阿里云控制台 → ECS实例 → 安全组 → 入方向规则 → 添加规则 → TCP 20081

### 7.9 经验总结

1. **浏览器用 HTTP 代理，命令行用 SOCKS5 代理** — 这是最佳实践组合
2. **gost 同时开两个端口零成本** — 一个进程同时监听多个协议，不增加资源开销
3. **部署前先想好客户端兼容性** — 浏览器对 SOCKS5 认证的支持是个大坑，一开始就应该规划 HTTP 端口
