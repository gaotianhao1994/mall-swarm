# 阿里云扩展服务器 — 部署进度追踪

> **服务器**: 阿里云 2核4G | **公网 IP**: `8.134.65.121`
> **系统**: Ubuntu 22.04 LTS | **角色**: 扩展服务器（重资源服务 + 日志体系）
> **最后更新**: 2026-06-11

---

## 当前阶段总览

| 阶段 | 内容 | 状态 |
|------|------|------|
| 阶段0 | 环境准备 | ✅ **已完成** |
| 阶段1 | — （本服务器不部署基础骨架） | — |
| 阶段2 | 商品搜索（Elasticsearch + mall-search） | ☐ 待开始 |
| 阶段3 | 前台商城（MongoDB + RabbitMQ + mall-portal） | ☐ 待开始 |
| 阶段4 | 日志监控（Logstash + Kibana） | ☐ 待开始 |

---

## 阶段0：环境准备

### 2.1 重装系统确认

- [x] 系统已重装为 Ubuntu 22.04 LTS
- [x] 已设置 root 密码
- [x] 已通过 SSH 连接成功

### 2.2 安装 Docker

- [x] 更新包索引 (`apt-get update`)
- [x] 安装依赖包（ca-certificates, curl, gnupg, lsb-release）
- [x] 添加 Docker 官方 GPG 密钥（使用阿里云镜像源）
- [x] 添加 Docker 仓库源
- [x] 安装 Docker Engine（docker-ce, docker-ce-cli, containerd.io, buildx-plugin, compose-plugin）
- [ ] 将当前用户加入 docker 组（当前为 root 用户，暂不需要）
- [x] 验证：`docker --version`

**安装结果记录**: Docker 29.5.3 (2026-06-11)

### 2.3 安装 Docker Compose

- [x] 验证 Docker Compose 插件已随 Docker 一起安装
- [x] 验证：`docker compose version`

**版本记录**: Docker Compose v5.1.4 (2026-06-11)

### 2.4 安装 Git

- [x] Git 已预装（系统自带）
- [x] 验证：`git --version`

**版本记录**: Git 2.34.1 (2026-06-11)

### 2.5 验证安装

- [x] `docker --version` ✅ (29.5.3)
- [x] `docker compose version` ✅ (v5.1.4)
- [x] `git --version` ✅ (2.34.1)
- [ ] `docker run hello-world` 测试 ⚠️ (Docker Hub 超时，使用 ACR 代替)

### 2.6 防火墙/安全组端口开放

> **需要在阿里云控制台操作的安全组规则：**

| 端口 | 用途 | 已开放 |
|------|------|--------|
| 22 | SSH | ✅ |
| 9200 | Elasticsearch HTTP | ✅ |
| 9300 | Elasticsearch TCP（节点间通信，建议仅内网） | ✅ |
| 27017 | MongoDB（建议仅内网） | ✅ |
| 5672 | RabbitMQ（建议仅内网） | ✅ |
| 15672 | RabbitMQ 管理界面 | ✅ |
| 8081 | mall-search | ✅ |
| 8085 | mall-portal | ✅ |
| 5044 | Logstash 输入 | ✅ |
| 5601 | Kibana | ✅ |

### 2.7 Hosts 配置

- [x] 配置 `/etc/hosts`，添加腾讯云内网映射

**当前 hosts 内容**:
```bash
# mall-swarm 集群服务器映射
106.53.106.41  tencent-cloud-main   # 腾讯云 网关服务器（原主服务器）
106.53.132.192  tencent-cloud-data  # 腾讯云 数据服务器（新增）
```

**网络连通性**: ✅ ping 延迟 ~12ms，0% 丢包

---

## 阶段2：商品搜索服务

### 5.1~5.4 阶段2 服务部署

- [ ] 在扩展服务器克隆项目
- [ ] 编写 docker-compose.search.yml
- [ ] Elasticsearch 内存优化配置（`-Xms512m -Xmx512m`）
- [ ] 启动 ES 并验证
- [ ] 启动 mall-search 并验证

**启动时间**: _________________
**ES 内存配置**: _________________
**验证结果**: _________________

---

## 阶段3：前台商城服务

### 6.1~6.4 阶段3 服务部署

- [ ] 编写 docker-compose.portal.yml
- [ ] MongoDB 基础配置
- [ ] RabbitMQ 基础配置（用户名/密码/vhost）
- [ ] 启动并验证各服务

**启动时间**: _________________
**验证结果**: _________________

---

## 阶段4：日志监控（ELK）

### 7.1~7.4 阶段4 服务部署

- [ ] 编写 docker-compose.elk.yml
- [ ] Logstash 配置文件（对接各服务日志）
- [ ] Kibana 配置（连接 ES）
- [ ] 启动 ELK 并验证日志采集

**启动时间**: _________________
**验证结果**: _________________

---

## 问题日志

| 时间 | 阶段 | 问题描述 | 解决方案 | 状态 |
|------|------|---------|---------|------|
| 2026-06-11 | 阶段0 | Docker Hub 连接超时 (i/o timeout) | 配置镜像加速器 + 使用阿里云 ACR | ✅ 已解决 |

<!-- 新的问题追加在上方 -->

---

## 关键备忘

### SSH 连接信息
```bash
ssh root@8.134.65.121
```

### 重要路径
| 用途 | 路径 |
|------|------|
| 项目根目录 | `/root/projects/mall-swarm` |
| Docker Compose 文件 | `/root/projects/mall-swarm/docker/` |
| 数据卷（数据持久化） | `/root/projects/mall-swarm/data/` |
| ES 数据目录 | `/root/projects/mall-swarm/data/elasticsearch` |
| MongoDB 数据目录 | `/root/projects/mall-swarm/data/mongodb` |
| 日志目录 | `/root/projects/mall-swarm/logs/` |

### 内存预警线（2核4G 机器）

| 阶段 | 预估内存占用 | 剩余可用 | 状态 |
|------|-------------|---------|------|
| 仅环境准备 | ~100MB | ~3.9GB | ✅ 宽裕 |
| + 阶段2（ES+search） | ~1.4GB | ~2.5GB | ⚠️ 注意 |
| + 阶段3（Mongo+RabbitMQ+portal） | ~2.3GB | ~1.6GB | ⚠️ 紧张 |
| + 阶段4（ELK） | ~2.5GB | ~1.4GB | 🔴 需调优 |

### .env 文件中的关键变量（填写后更新）
| 变量 | 值 |
|------|-----|
| ES_JVM_HEAP | _________________ |
| MONGO_INITDB_ROOT_USERNAME | _________________ |
| MONGO_INITDB_ROOT_PASSWORD | _________________ |
| RABBITMQ_DEFAULT_USER | _________________ |
| RABBITMQ_DEFAULT_PASS | _________________ |
