# mall-swarm 部署总体规划

> **项目**: mall-swarm 微服务商城系统
> **部署方式**: 基于项目自带 Docker Compose，适配三台云服务器
> **最后更新**: 2026-06-11

---

## 一、项目是什么？

mall-swarm 是一套基于 **Spring Cloud Alibaba** 的微服务商城系统，包含 **9 个 Maven 子模块**：

| 模块 | 端口 | 职责 |
|------|------|------|
| `mall-gateway` | 8201 | API 网关（统一入口、路由转发） |
| `mall-admin` | 8080 | 后台管理系统（商品/订单/会员/营销） |
| `mall-auth` | 8401 | 认证授权（Sa-Token + JWT） |
| `mall-search` | 8081 | 商品搜索（Elasticsearch） |
| `mall-portal` | 8085 | 前台门户（商城前台） |
| `mall-monitor` | 8101 | 服务监控（Spring Boot Admin） |
| `mall-common` | — | 公共工具库（被其他模块依赖，不独立部署） |
| `mall-mbg` | — | MyBatis 代码生成器（开发工具，不部署） |
| `mall-demo` | — | Feign 调用示例（CI 构建时排除，不部署） |

**技术栈**: Spring Boot 3.5 + Java 17 + MySQL 5.7 + Redis 7 + Nacos 2.1 + Elasticsearch 7.17 + MongoDB 4 + RabbitMQ 3.9

**需要的外部中间件**（共 9 个）：

| 中间件 | 版本 | 用途 |
|--------|------|------|
| MySQL | 5.7 | 主数据库（76 张表） |
| Redis | 7 | 缓存 / Session / Sa-Token |
| Nacos | 2.1.0 | 注册中心 + 配置中心 |
| Nginx | 1.22 | 反向代理 / 静态资源 / 前端托管 |
| Elasticsearch | 7.17.3 | 商品搜索引擎 |
| MongoDB | 4 | 前台内容存储 |
| RabbitMQ | 3.9.11 | 异步消息队列 |
| Logstash | 7.17.3 | 日志采集 |
| Kibana | 7.17.3 | 日志可视化 |

---

## 二、我们有哪些服务器？

```
┌─────────────────────────────────────────────────────────┐
│                      公网访问                            │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│  ① 腾讯云 网关服务器                                     │
│     106.53.106.41  │  Ubuntu 22.04  │  4核4G            │
│                                                         │
│  角色：流量入口 + 服务注册                               │
│  部署：Nacos + Gateway + Nginx                          │
└────────────────────────┬────────────────────────────────┘
                         │ 内网通信
          ┌──────────────┴──────────────┐
          ▼                              ▼
┌──────────────────────┐    ┌──────────────────────────────┐
│ ② 腾讯云 数据服务器   │    │ ③ 阿里云 扩展服务器           │
│ 106.53.132.192       │    │ 8.134.65.121                 │
│ Ubuntu 24.04 │ 4核4G  │    │ Ubuntu 22.04 │ 2核4G         │
│                      │    │                              │
│ 角色：核心数据+业务    │    │ 角色：重资源扩展服务         │
│ 部署：MySQL+Redis     │    │ 部置：ES+MongoDB+RabbitMQ   │
│      +Admin+Auth      │    │       +search+portal+ELK    │
└──────────────────────┘    └──────────────────────────────┘
```

### 为什么这样分配？

原方案把所有东西塞一台 4核4G → CPU 90%。现在按 **资源消耗特征** 拆分：

| 特征 | 网关服务器 (①) | 数据服务器 (②) | 扩展服务器 (③) |
|------|---------------|---------------|---------------|
| CPU 密集型 | Gateway（路由转发） | Admin/Auth（业务计算） | ES（索引构建） |
| 内存密集型 | Nacos (~512MB) | MySQL (~500MB) | ES (~1GB), Mongo (~300MB) |
| IO 密集型 | Nginx | MySQL 磁盘读写 | RabbitMQ 消息持久化 |
| 容器数量 | 3 个 | 4 个 | ~8 个 |
| 预估内存占用 | ~1.2GB / 4GB | ~2GB / 4GB | ~2.5GB / 4GB |

---

## 三、项目自带的 Docker 文件

项目 `document/docker/` 目录下已有两套 Docker Compose 编排文件（这是官方提供的参考配置）：

### 3.1 基础设施编排 — `docker-compose-env.yml`

定义了 **9 个中间件容器**：

```yaml
mysql        :3306    # 主数据库
redis        :6379    # 缓存
nginx        :80      # Web 服务器
rabbitmq     :5672/15672  # 消息队列
elasticsearch :9200/9300  # 搜索引擎
logstash      :4560-4563   # 日志采集
kibana        :5601    # 日志可视化
mongo         :27017   # 文档数据库
nacos-registry :8848   # 注册中心
```

### 3.2 应用服务编排 — `docker-compose-app.yml`

定义了 **6 个应用容器**：

```yaml
mall-admin    :8080    # 后台管理
mall-search   :8081    # 搜索服务
mall-portal   :8085    # 前台门户
mall-auth     :8401    # 认证授权
mall-gateway  :8201    # API 网关
mall-monitor  :8101    # 服务监控
```

### 3.3 我们要做什么改造？

原文件是为 **单机开发环境** 设计的，直接用到生产环境有以下问题：

| 问题 | 原文件现状 | 生产环境需要 |
|------|----------|------------|
| 镜像地址 | `mall/mall-admin:1.0-SNAPSHOT`（本地构建） | 从 ACR 镜像仓库拉取（或 CI/CD 构建） |
| 所有服务一个文件 | 15 个服务全在一起 | 按 **服务器角色拆分** 成多个 yml |
| 密码明文 | `MYSQL_ROOT_PASSWORD: root` | `.env` 文件管理，不提交 Git |
| 无健康检查 | 没有 healthcheck | 加 healthcheck 保证启动顺序 |
| Redis 无密码 | `redis-server --appendonly yes` | 加密码认证 |
| ES 内存过大 | `-Xmx1024m` | 小机器改为 `-Xms256m -Xmx512m` |
| 网络隔离 | 用废弃的 `links`/`external_links` | 统一 bridge network |
| 数据卷路径 | `/mydata/mysql/data` | 统一 `/opt/mall-swarm/data/` |

**策略：以原文件为蓝本，做生产化改造后拆分到三台服务器。**

---

## 四、整体部署步骤（总览）

```
步骤 0 ─── 准备工作（本地 + 三台服务器）
  │
  ├── 0.1 本地确认项目能编译通过
  ├── 0.2 三台服务器安装 Docker + 配置镜像加速
  ├── 0.3 三台服务器配置 SSH 互信 + Hosts
  ├── 0.4 三台服务器开放安全组端口
  └── 0.5 创建阿里云 ACR 镜像仓库（如尚未创建）
  │
  ▼
步骤 1 ─── CI/CD 镜像构建流水线（GitHub Actions → ACR）
  │
  ├── 1.1 编写 Dockerfile.module（通用微服务镜像）
  ├── 1.2 编写 GitHub Actions 工作流（Maven 构建 + Docker 推送 ACR）
  ├── 1.3 配置 GitHub Secrets（ACR 账号密码）
  ├── 1.4 手动触发首次构建，验证 6 个镜像全部推送成功
  └── 1.5 各服务器配置 ACR 登录凭据
  │
  ▼
步骤 2 ─── 网关服务器部署（① 腾讯云 106.53.106.41）
  │
  ├── 2.1 克隆项目到 /opt/mall-swarm
  ├── 2.2 基于 docker-compose-env.yml 改造 → docker-compose.gateway.yml
  │   └── 仅保留：Nacos + Nginx（Gateway 在步骤 2.3 单独加）
  ├── 2.3 启动 Nacos，验证可访问 :8848
  ├── 2.4 启动 Gateway，验证注册到 Nacos
  ├── 2.5 配置 Nginx 反向代理（转发到 Gateway :8201）
  └── 2.6 验证：公网 IP → Nginx → Gateway → Nacos 全链路通
  │
  ▼
步骤 3 ─── 数据服务器部署（② 腾讯云 106.53.132.192）
  │
  ├── 3.1 克隆项目到 /opt/mall-swarm
  ├── 3.2 基于 docker-compose-env.yml 改造 → docker-compose.data.yml
  │   └── 仅保留：MySQL + Redis
  ├── 3.3 初始化数据库（挂载 mall.sql，自动建表 76 张）
  ├── 3.4 基于 docker-compose-app.yml 改造 → docker-compose.app-core.yml
  │   └── 仅保留：Admin + Auth
  ├── 3.5 启动全部服务，验证注册到远程 Nacos（① 的 Nacos）
  └── 3.6 验证：通过 ① 的 Gateway 转发到 ② 的 Admin/Auth
  │
  ▼
步骤 4 ─── 扩展服务器部署（③ 阿里云 8.134.65.121）
  │
  ├── 4.1 克隆项目到 /opt/mall-swarm
  ├── 4.2 改造 → docker-compose.extend-env.yml
  │   └── ES + MongoDB + RabbitMQ
  ├── 4.3 改造 → docker-compose.extend-app.yml
  │   └── Search + Portal
  ├── 4.4 启动并验证各服务注册到远程 Nacos
  └── 4.5 验证：通过 ① 的 Gateway 转发到 ③ 的 Search/Portal
  │
  ▼
步骤 5 ─── 日志监控体系（ELK）（可选，③ 阿里云）
  │
  ├── 5.1 部署 Logstash + Kibana
  ├── 5.2 配置日志采集规则（对接所有服务的 /var/logs）
  └── 5.3 验证 Kibana 可查看各服务日志
  │
  ▼
步骤 6 ─── 前端部署（① 腾讯云 网关服务器）
  │
  ├── 6.1 构建前端静态资源（mall-admin-web）
  ├── 6.2 上传到 Nginx 静态目录
  ├── 6.3 Nginx 配置 API 反向代理 + 前端路由
  └── 6.4 验证：浏览器访问完整商城系统
  │
  ▼
完成 ✅
```

---

## 五、每台服务器最终跑什么？

### 服务器 ① — 网关服务器 (`docker-compose.gateway.yml`)

| 容器 | 镜像 | 端口 | 说明 |
|------|------|------|------|
| nacos | `nacos/nacos-server:v2.1.0` | 8848 | 注册中心（集群核心，放网关层减少跨机器延迟） |
| nginx | `nginx:1.22` | 80, 443 | 反向代理 + 前端静态资源托管 |
| mall-gateway | ACR `:mall-gateway-latest` | 8201 | API 网关 |

**安全组需开放的端口**: 22, 80, 443, 8848, 8201

---

### 服务器 ② — 数据服务器 (`docker-compose.data.yml` + `docker-compose.app-core.yml`)

| 容器 | 镜像 | 端口 | 说明 |
|------|------|------|------|
| mysql | `mysql:5.7` | 3306 | 主数据库 |
| redis | `redis:7` | 6379 | 缓存 |
| mall-admin | ACR `:mall-admin-latest` | 8080 | 后台管理 API |
| mall-auth | ACR `:mall-auth-latest` | 8401 | 认证授权 API |

**安全组需开放的端口**: 22, 3306, 6379, 8080, 8401（3306/6379 建议仅内网）

**关键配置点**：
- Nacos 地址指向 ①：`106.53.106.41:8848`
- MySQL/Redis 使用本机 Docker 内部服务名

---

### 服务器 ③ — 扩展服务器 (`docker-compose.extend-env.yml` + `docker-compose.extend-app.yml`)

| 容器 | 镜像 | 端口 | 说明 |
|------|------|------|------|
| elasticsearch | `elasticsearch:7.17.3` | 9200, 9300 | 搜索引擎 |
| mongo | `mongo:4` | 27017 | 文档数据库 |
| rabbitmq | `rabbitmq:3.9.11-management` | 5672, 15672 | 消息队列 |
| logstash | `logstash:7.17.3` | 4560-4563 | 日志采集（阶段5） |
| kibana | `kibana:7.17.3` | 5601 | 日志可视化（阶段5） |
| mall-search | ACR `:mall-search-latest` | 8081 | 搜索服务 |
| mall-portal | ACR `:mall-portal-latest` | 8085 | 前台门户 |
| mall-monitor | ACR `:mall-monitor-latest` | 8101 | 监控中心（可选） |

**安全组需开放的端口**: 22, 9200, 27017, 5672, 15672, 8081, 8085, 5601, 5044（大部分建议仅内网）

**关键配置点**：
- Nacos 地址指向 ①：`106.53.106.41:8848`
- MySQL 地址指向 ②：`106.53.132.192:3306`
- Redis 地址指向 ②：`106.53.132.192:6379`

---

## 六、服务间调用关系图

```
                        用户请求
                           │
                           ▼
┌──────────────────────────────────────────────────────────┐
│  ① 网关服务器 106.53.106.41                              │
│                                                          │
│   :80 Nginx                                              │
│     │                                                    │
│     ▼ 反向代理                                            │
│   :8201 mall-gateway ◄──── 路由规则分发                  │
│     │  │           │                                    │
│     │  │           ├─→ /admin/**  ──────────┐           │
│     │  │           ├─→ /auth/**   ───────┐  │           │
│     │  │           ├─→ /search/** ──────┐│  │           │
│     │  │           └─→ /portal/** ────┐││  │           │
│     │  │                          │││  │           │
│     ▼  ▼                          ▼▼▼  ▼           │
│  :8848 Nacos（服务注册发现）                       │
│  （所有服务都注册到这里）                             │
└──────────────────────────┬───────────────────────────┘
                           │ 内网 HTTP 调用
           ┌───────────────┼───────────────┐
           ▼               ▼               ▼
┌─────────────────┐ ┌─────────────┐ ┌─────────────────┐
│ ② 数据服务器     │ │             │ │ ③ 扩展服务器     │
│ 106.53.132.192   │ │             │ │ 8.134.65.121     │
│                  │ │             │ │                  │
│ :3306 MySQL ◄────┼─┼─────────────┼─┤ :9200 ES        │
│ :6379 Redis ◄────┼─┼─────────────┤ │ :27017 Mongo     │
│                  │ │             │ │ :5672 RabbitMQ   │
│ :8080 mall-admin │ │             │ │                  │
│   ↑ 读/写 DB     │ │             │ │ :8081 mall-search│
│   ↑ 读 Cache     │ │             │ │   ↑ 读 ES        │
│                  │ │             │ │                  │
│ :8401 mall-auth  │ │             │ │ :8085 mall-portal│
│   ↑ 读 Redis     │ │             │ │   ↑ 读 Mongo     │
│   ↑ 写 Redis     │ │             │ │   ↑ 发 RabbitMQ  │
│                  │ │             │ │                  │
└─────────────────┘ │             │ │ :8101 mall-monitor│
                    │             │ └─────────────────┘
                    └─────────────┘
```

---

## 七、当前进度与状态

### 服务器状态

| # | 服务器 | IP | Docker 已装？ | 当前状态 |
|---|--------|-----|------------|---------|
| ① | 腾讯云 网关 | 106.53.106.41 | ✅ Docker 29.5.3 | 曾启动过全量容器，CPU 90%，待清理重部署 |
| ② | 腾讯云 数据 | 106.53.132.192 | ❌ 待安装 | 新机器，刚配好 SSH |
| ③ | 阿里云 扩展 | 8.134.65.121 | ✅ Docker 29.5.3 | 环境就绪，等待部署 |

### SSH 连接方式

```bash
ssh tengxun-server     # → ① 106.53.106.41 (root)
ssh tengxun-server9   # → ② 106.53.132.192 (root)
ssh aliyun-server     # → ③ 8.134.65.121 (root)
```

### 已完成的事项

- [x] 三台服务器 SSH 连接已配置
- [x] ① 和 ③ 的 Docker 环境已安装
- [x] 阿里云 ACR 镜像仓库已创建
- [x] GitHub Actions CI/CD 工作流已编写（首次构建成功，6 个镜像已推送到 ACR）
- [x] 项目自带 Docker Compose 文件已分析清楚

### 下一步行动

**从「步骤 0」开始**：先在 ② 号数据服务器上安装 Docker 环境，然后逐步推进。

---

## 八、文件清单（规划中的产出物）

部署过程中将产生以下文件（均放在项目仓库中）：

```
mall-swarm/
├── .github/workflows/
│   └── docker-build.yml              ← CI/CD（已完成 ✅）
├── docker/
│   ├── Dockerfile.module             ← 微服务通用 Dockerfile（已完成 ✅）
│   ├── docker-compose.gateway.yml    ← ① 网关服务器：Nacos + Gateway + Nginx
│   ├── docker-compose.data.yml       ← ② 数据服务器：MySQL + Redis
│   ├── docker-compose.app-core.yml   ← ② 数据服务器：Admin + Auth
│   ├── docker-compose.extend-env.yml  ← ③ 扩展服务器：ES + Mongo + RabbitMQ
│   ├── docker-compose.extend-app.yml  ← ③ 扩展服务器：Search + Portal + Monitor
│   ├── docker-compose.elk.yml        ← ③ 扩展服务器：Logstash + Kibana
│   ├── .env                          ← 生产环境变量（gitignore）
│   ├── .env.example                  ← 环境变量模板
│   └── sql/init/mall.sql             ← 数据库初始化脚本（已完成 ✅）
└── docs2/
    └── plan.md                       ← 本文档（总体规划）
```
