# 腾讯云数据服务器 — 部署进度追踪

> **服务器**: 腾讯云 4核4G | **公网 IP**: `106.53.132.192`
> **系统**: Ubuntu 24.04 LTS | **角色**: 数据/核心业务服务器（MySQL + Redis + Admin + Auth）
> **最后更新**: 2026-06-11 (新建)

---

## 当前阶段总览

| 阶段 | 内容 | 状态 |
|------|------|------|
| **阶段0** | 环境准备 | ⏳ **进行中** |
| 阶段1 Part B | 基础数据层（MySQL + Redis + Admin + Auth） | ☐ 待开始 |
| 阶段2~5 | 后续阶段（本服务器不参与） | — |

---

## 阶段0：环境准备

### 2.1 系统确认
- [x] 系统：Ubuntu 24.04 LTS
- [x] 内存：3.6GB（可用 3.1GB）
- [x] CPU：4 核
- [x] Swap：1.9GB（已自动配置）
- [x] Root 用户已启用（密码 `Mall@2026_root`）
- [x] SSH 密钥认证已配置（`ssh tengxun-server9`）

### 2.2 安装 Docker
- [ ] 更新包索引 (`apt-get update`)
- [ ] 安装依赖包（ca-certificates, curl, gnupg, lsb-release）
- [ ] 添加 Docker 官方 GPG 密钥（使用国内镜像源）
- [ ] 添加 Docker 仓库源
- [ ] 安装 Docker Engine（docker-ce, docker-ce-cli, containerd.io, buildx-plugin, compose-plugin）
- [ ] 配置国内镜像加速器
- [ ] 验证：`docker --version`

### 2.3 安装 Docker Compose
- [ ] 验证 Docker Compose 插件已随 Docker 一起安装
- [ ] 验证：`docker compose version`

### 2.4 安装 Git
- [ ] Git 已预装或手动安装
- [ ] 验证：`git --version`

### 2.5 验证安装
- [ ] `docker --version`
- [ ] `docker compose version`
- [ ] `git --version`
- [ ] `docker run hello-world` 测试

### 2.6 防火墙/安全组端口开放

> **需要在腾讯云控制台操作的安全组规则：**

| 端口 | 用途 | 已开放 |
|------|------|--------|
| 22 | SSH | ✅ |
| 3306 | MySQL（建议仅内网） | ⬜ 待开放 |
| 6379 | Redis（建议仅内网） | ⬜ 待开放 |
| 8080 | mall-admin | ⬜ 待开放 |
| 8401 | mall-auth | ⬜ 待开放 |

### 2.7 Hosts 配置
- [ ] 配置 `/etc/hosts`，添加其他两台服务器映射：
```bash
# mall-swarm 集群服务器映射
106.53.106.41  tencent-cloud-gateway   # 腾讯云 网关服务器
8.134.65.121  aliyun-server            # 阿里云 扩展服务器
```

---

## 阶段1 Part B：基础数据层服务

### 3.1 克隆项目 & 拉取镜像
- [ ] 克隆项目到 `/opt/mall-swarm`
- [ ] 登录阿里云 ACR
- [ ] 从 ACR 拉取阶段1 Part B 所需镜像（mysql, redis, mall-admin, mall-auth）

### 3.2 编写 docker-compose.data.yml
- [ ] MySQL 5.7 配置（内存优化，字符集 utf8mb4）
- [ ] Redis 7 配置（持久化 + 密码）
- [ ] mall-admin 配置（连接本地 MySQL/Redis，注册到远程 Nacos）
- [ ] mall-auth 配置（连接本地 Redis，注册到远程 Nacos）

> **关键配置点**：
> - Nacos 地址需指向网关服务器: `106.53.106.41:8848`
> - MySQL/Redis 地址使用 Docker 内部服务名
> - .env 文件需与网关服务器保持一致的密码配置

### 3.3 启动并验证
- [ ] 启动所有容器
- [ ] 验证 MySQL → healthy
- [ ] 验证 Redis → healthy
- [ ] 验证 mall-admin 注册到 Nacos
- [ ] 验证 mall-auth 注册到 Nacos
- [ ] 通过 Gateway 转发验证端到端访问

---

## 内存预警线（4核4G 机器）

| 阶段 | 预估内存占用 | 剩余可用 | 状态 |
|------|-------------|---------|------|
| 仅环境准备 | ~100MB | ~3.5GB | ✅ 宽裕 |
| + MySQL + Redis | ~600MB | ~3.0GB | ✅ 宽裕 |
| + Admin + Auth | ~1.3GB | ~2.3GB | ✅ 宽裕 |

---

## 问题日志

| 时间 | 阶段 | 问题描述 | 解决方案 | 状态 |
|------|------|---------|---------|------|
| 2026-06-11 | 阶段0 | 默认用户为 ubuntu 非 root | 设置 root 密码 + 复制公钥 + 开启 PermitRootLogin | ✅ 已解决 |

<!-- 新的问题追加在上方 -->

---

## 关键备忘

### SSH 连接信息
```bash
ssh tengxun-server9        # 或 ssh root@106.53.132.192
```

### 重要路径
| 用途 | 路径 |
|------|------|
| 项目根目录 | `/opt/mall-swarm` |
| Docker Compose 文件 | `/opt/mall-swarm/docker/` |
| 数据卷（数据持久化） | `/opt/mall-swarm/data/` |
| MySQL 数据目录 | `/opt/mall-swarm/data/mysql` |
| Redis 数据目录 | `/opt/mall-swarm/data/redis` |
| 日志目录 | `/opt/mall-swarm/logs/` |

### .env 文件中的关键变量（与网关服务器保持一致）
| 变量 | 值 |
|------|-----|
| MYSQL_ROOT_PASSWORD | `Mall@2026_root` |
| REDIS_PASSWORD | `Mall@2026_redis` |
| NACOS_SERVER_ADDR | `106.53.106.41:8848` (远程 Nacos) |
| ACR_REGISTRY | `crpi-9lhedueyyvqzcyrk.cn-guangzhou.personal.cr.aliyuncs.com` |
| ACR_NAMESPACE | `mall-swarm-202606` |

### 常用命令速查
```bash
# 启动数据层服务
cd /opt/mall-swarm/docker && docker compose -f docker-compose.data.yml up -d

# 仅启动数据库
cd /opt/mall-swarm/docker && docker compose -f docker-compose.data.yml up -d mysql redis

# 查看日志
docker compose -f docker-compose.data.yml logs -f mall-admin

# 停止所有服务
docker compose -f docker-compose.data.yml down
```

### 下次继续时的起点
```
从「阶段0 — 2.2 安装 Docker」开始：
  1. apt-get update && 安装 Docker（参考阿里云服务器的安装步骤）
  2. 配置国内镜像加速器
  3. docker run hello-world 测试
  4. 克隆项目 / opt/mall-swarm
  5. 编写 docker-compose.data.yml（拆分自原 docker-compose.base.yml）
  6. 启动并验证各服务
```
