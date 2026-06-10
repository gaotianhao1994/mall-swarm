# 腾讯云主服务器 — 部署进度追踪

> **服务器**: 腾讯云 4核4G | **公网 IP**: `106.53.106.41`
> **系统**: Ubuntu 22.04 LTS | **角色**: 主服务器（核心应用 + 基础中间件）
> **最后更新**: 2026-06-11

---

## 当前阶段总览

| 阶段 | 内容 | 状态 |
|------|------|------|
| 阶段0 | 环境准备 | ⏳ **进行中** |
| 阶段1 | 基础骨架（MySQL + Redis + Nacos + Gateway + Admin + Auth） | ☐ 待开始 |
| 阶段2 | — （本服务器不部署 ES） | — |
| 阶段3 | — （本服务器不部署 Mongo/RabbitMQ） | — |
| 阶段4 | 日志监控（mall-monitor） | ☐ 待开始 |
| 阶段5 | 前端部署（Nginx 静态托管） | ☐ 待开始 |

---

## 阶段0：环境准备

### 2.1 重装系统确认

- [x] 系统已重装为 Ubuntu 22.04 LTS
- [x] 已设置 root 密码
- [x] 已通过 SSH 连接成功

### 2.2 安装 Docker

- [ ] 更新包索引 (`apt-get update`)
- [ ] 安装依赖包（ca-certificates, curl, gnupg, lsb-release）
- [ ] 添加 Docker 官方 GPG 密钥
- [ ] 添加 Docker 仓库源
- [ ] 安装 Docker Engine（docker-ce, docker-ce-cli, containerd.io, buildx-plugin, compose-plugin）
- [ ] 将当前用户加入 docker 组
- [ ] 验证：`docker --version`

**安装结果记录**: _________________

### 2.3 安装 Docker Compose

- [ ] 验证 Docker Compose 插件已随 Docker 一起安装
- [ ] 验证：`docker compose version`

**版本记录**: _________________

### 2.4 安装 Git

- [ ] 执行 `apt-get install -y git`
- [ ] 验证：`git --version`

**版本记录**: _________________

### 2.5 验证安装

- [ ] `docker --version` ✅ / ❌
- [ ] `docker compose version` ✅ / ❌
- [ ] `git --version` ✅ / ❌
- [ ] `docker run hello-world` 测试 ✅ / ❌

### 2.6 防火墙/安全组端口开放

> **需要在腾讯云控制台操作的安全组规则：**

| 端口 | 用途 | 已开放 |
|------|------|--------|
| 22 | SSH | ☐ |
| 80 | HTTP/Nginx | ☐ |
| 443 | HTTPS（如需要） | ☐ |
| 3306 | MySQL（建议仅内网） | ☐ |
| 6379 | Redis（建议仅内网） | ☐ |
| 8848 | Nacos 控制台 | ☐ |
| 8201 | mall-gateway | ☐ |
| 8080 | mall-admin | ☐ |
| 8401 | mall-auth | ☐ |

### 2.7 Hosts 配置

- [ ] 配置 `/etc/hosts`，添加阿里云内网映射

**当前 hosts 内容**:
```bash
# 待配置
```

---

## 阶段1：基础微服务骨架

### 3.1~3.7 基础设施准备

- [ ] Fork 项目到 GitHub
- [ ] 创建阿里云 ACR 镜像仓库
- [ ] 获取 ACR 凭证并配置 GitHub Secrets
- [ ] 编写 GitHub Actions 工作流文件
- [ ] 在服务器上克隆项目 (`git clone ... /opt/mall-swarm`)
- [ ] 准备目录结构和 .env 文件模板
- [ ] 导入数据库初始化 SQL

### 4.1~4.8 阶段1 服务部署

- [ ] 编写 docker-compose.base.yml
- [ ] 各服务的 Dockerfile 就绪
- [ ] Nacos 配置导入
- [ ] Nginx 反向代理配置
- [ ] 按顺序启动服务
- [ ] 验证清单全部通过

**启动时间**: _________________
**验证结果**: _________________

---

## 问题日志

| 时间 | 阶段 | 问题描述 | 解决方案 | 状态 |
|------|------|---------|---------|------|
| — | — | — | — | — |

<!-- 新的问题追加在上方 -->

---

## 关键备忘

### SSH 连接信息
```bash
ssh root@106.53.106.41
```

### 重要路径
| 用途 | 路径 |
|------|------|
| 项目根目录 | `/opt/mall-swarm` |
| Docker Compose 文件 | `/opt/mall-swarm/docker/` |
| 数据卷（数据持久化） | `/opt/mall-swarm/data/` |
| Nacos 配置导出 | `/opt/mall-swarm/config/` |
| 日志目录 | `/opt/mall-swarm/logs/` |

### .env 文件中的关键变量（填写后更新）
| 变量 | 值 |
|------|-----|
| MYSQL_ROOT_PASSWORD | _________________ |
| REDIS_PASSWORD | _________________ |
| NACOS_AUTH_TOKEN | _________________ |
| ACR_REGISTRY | _________________ |
| ACR_USERNAME | _________________ |
| ACR_PASSWORD | _________________ |
