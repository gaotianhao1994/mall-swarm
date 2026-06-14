---
name: mall-swarm-full-docker-deployment
overview: 将 mall-swarm 微服务系统以 Docker 形式全量部署到三台云服务器，包括所有中间件（MySQL/Redis/Nacos/ES/MongoDB/RabbitMQ）和所有应用服务（Gateway/Admin/Auth/Search/Portal/Monitor），以及 Nginx 反向代理。
todos:
  - id: server2-env
    content: Server ② 安装 Docker/Compose/Git 并配置镜像加速和 hosts
    status: pending
  - id: compose-files
    content: 创建三个 docker-compose 编排文件(gateway/data/extend)和更新 .env
    status: pending
    dependencies:
      - server2-env
  - id: nacos-config
    content: 编写 Nacos 生产配置文件和自动导入脚本(import-config.sh)
    status: pending
    dependencies:
      - compose-files
  - id: nginx-config
    content: 编写 Nginx 反向代理配置(nginx.conf)
    status: pending
    dependencies:
      - compose-files
  - id: deploy-gateway
    content: "部署 ① 网关服务器: Nacos + 导入配置 + Gateway + Nginx"
    status: pending
    dependencies:
      - nacos-config
      - nginx-config
  - id: deploy-data
    content: "部署 ② 数据服务器: MySQL + Redis + Admin + Auth 并验证注册"
    status: pending
    dependencies:
      - deploy-gateway
  - id: deploy-extend
    content: "部署 ③ 扩展服务器: ES + Mongo + RabbitMQ + Search + Portal + Monitor 并验证"
    status: pending
    dependencies:
      - deploy-gateway
  - id: e2e-verify
    content: "端到端验证: Nginx → Gateway → 各服务全链路通畅"
    status: pending
    dependencies:
      - deploy-data
      - deploy-extend
---

## Product Overview

将 mall-swarm 微服务商城系统以 Docker Compose 形式全量部署到三台云服务器，使所有服务正常运行并可互相通信。

## Core Features

- 三台服务器全量部署：网关层(Nacos+Gateway+Nginx)、数据层(MySQL+Redis+Admin+Auth)、扩展层(ES+MongoDB+RabbitMQ+Search+Portal+Monitor)
- 解决微服务跨服务器 Nacos 注册发现问题
- 更新 Nacos 配置中心的中件间地址（Docker 别名替换为实际 IP）
- 配置 Nginx 反向代理实现统一入口
- 所有服务启动并验证端到端链路通畅

## Tech Stack

- 容器编排: Docker Compose（每台服务器独立编排文件）
- 镜像仓库: 阿里云 ACR 个人版（已有，6个镜像已推送）
- 配置中心: Nacos 2.1.0（服务注册 + 配置管理）
- CI/CD: GitHub Actions（已完成，无需重新构建镜像）

## Implementation Approach

### 核心策略

按服务器角色将 `docker-compose.base.yml` 拆分为 3 个独立编排文件，通过环境变量覆盖解决跨机器通信问题。

### 关键技术决策

**1. Nacos 地址覆盖方案**

- 问题：`application-prod.yml` 中 Nacos 地址为 `nacos-registry:8848`（Docker 服务名），跨服务器无法解析
- 方案：在 docker-compose 中通过 `SPRING_CLOUD_NACOS_DISCOVERY_SERVER-ADDR` 和 `SPRING_CLOUD_NACOS_CONFIG_SERVER-ADDR` 环境变量覆盖，指向网关服务器实际 IP `106.53.106.41:8848`
- 优势：无需重新构建镜像，无需修改源码，纯运维层面解决

**2. Nacos 配置中心中间件地址更新**

- 问题：`config/` 下的 prod YAML 中间件地址为 Docker 别名（`db`、`redis`、`es`、`mongo`、`rabbit`），跨服务器无法解析
- 方案：编写脚本通过 Nacos Open API 自动导入更新后的配置，将别名替换为实际 IP：
- `db` → `106.53.132.192`（MySQL 在数据服务器）
- `redis` → `106.53.132.192`（Redis 在数据服务器）
- `es` → `8.134.65.121`（ES 在扩展服务器）
- `mongo` → `8.134.65.121`（MongoDB 在扩展服务器）
- `rabbit` → `8.134.65.121`（RabbitMQ 在扩展服务器）
- `logstash` → `8.134.65.121`（Logstash 在扩展服务器）

**3. MySQL 用户问题**

- 问题：`mall-admin-prod.yaml` 中 MySQL 用户为 `reader` 密码 `123456`，而 `mall-portal-prod.yaml` 用户为 `root` 密码 `root`
- 方案：在 Nacos 配置中统一使用 `root` 用户和实际密码 `Mall@2026_root`

**4. 启动顺序控制**

- 先启动 Nacos（网关服务器）
- 导入 Nacos 配置
- 再启动中间件（MySQL/Redis/ES/MongoDB/RabbitMQ）
- 最后启动应用服务（Gateway/Admin/Auth/Search/Portal/Monitor）
- 依赖关系通过 `depends_on` + `healthcheck` + `restart: always` 控制

**5. 内存优化**

- ② 数据服务器 4G：MySQL(256MB buffer) + Redis(128MB max) + Admin(384MB) + Auth(320MB) ≈ 2GB
- ③ 扩展服务器 4G：ES(512MB heap) + Mongo + RabbitMQ + Search(384MB) + Portal(384MB) ≈ 2.5GB，紧张但可行
- 各 JVM 使用 `-Xms256m -Xmx384m` 限制堆内存

## Architecture Design

```
用户请求 → ① Nginx(:80) → Gateway(:8201) → Nacos(:8848) 服务发现
                                           ↓
                          ┌────────────────┴────────────────┐
                          ↓                                  ↓
            ② Admin(:8080) + Auth(:8401)      ③ Search(:8081) + Portal(:8085)
            ② MySQL(:3306) + Redis(:6379)     ③ ES(:9200) + Mongo(:27017) + RabbitMQ(:5672)
```

## Directory Structure

```
mall-swarm/
├── docker/
│   ├── docker-compose.base.yml          # [MODIFY] 保留但标记为单机参考，不再使用
│   ├── docker-compose.gateway.yml       # [NEW] ① 网关服务器编排: Nacos + Gateway + Nginx
│   ├── docker-compose.data.yml          # [NEW] ② 数据服务器编排: MySQL + Redis + Admin + Auth
│   ├── docker-compose.extend.yml        # [NEW] ③ 扩展服务器编排: ES + Mongo + RabbitMQ + Search + Portal + Monitor
│   ├── nginx/
│   │   └── nginx.conf                   # [NEW] Nginx 配置文件（反向代理到 Gateway + 静态资源）
│   ├── nacos-config/
│   │   ├── import-config.sh             # [NEW] 自动导入 Nacos 配置的 Shell 脚本
│   │   ├── mall-admin-prod.yaml          # [NEW] Admin 生产配置（中间件地址替换为实际 IP）
│   │   ├── mall-gateway-prod.yaml        # [NEW] Gateway 生产配置
│   │   ├── mall-search-prod.yaml         # [NEW] Search 生产配置
│   │   ├── mall-portal-prod.yaml         # [NEW] Portal 生产配置
│   │   └── mall-auth-prod.yaml           # [NEW] Auth 生产配置（如需要）
│   ├── .env.example                     # [MODIFY] 增加三台服务器 IP 和新增中间件的环境变量
│   ├── Dockerfile.module                # [KEEP] 无需修改
│   └── sql/init/mall.sql                # [KEEP] 无需修改
```

### 各编排文件详细说明

**docker-compose.gateway.yml** — ① 网关服务器 (106.53.106.41)

- `nacos`: Nacos 2.1.0 standalone, 端口 8848, JVM 256m/512m
- `mall-gateway`: 从 ACR 拉取, 端口 8201, JVM 256m/384m, NACOS_ADDR=106.53.106.41:8848, Redis 指向 106.53.132.192
- `nginx`: Nginx 1.22, 端口 80/443, 反向代理到 gateway:8201

**docker-compose.data.yml** — ② 数据服务器 (106.53.132.192)

- `mysql`: MySQL 5.7, 端口 3306, innodb_buffer_pool=256M, 自动导入 mall.sql
- `redis`: Redis 7, 端口 6379, maxmemory 128mb, 密码认证
- `mall-admin`: 从 ACR 拉取, 端口 8080, JVM 256m/384m, NACOS_ADDR=106.53.106.41:8848
- `mall-auth`: 从 ACR 拉取, 端口 8401, JVM 192m/320m, NACOS_ADDR=106.53.106.41:8848

**docker-compose.extend.yml** — ③ 扩展服务器 (8.134.65.121)

- `elasticsearch`: ES 7.17.3, 端口 9200/9300, JVM 512m/512m, single-node
- `mongo`: Mongo 4, 端口 27017
- `rabbitmq`: RabbitMQ 3.9.11-management, 端口 5672/15672, 用户 mall/mall, vhost /mall
- `mall-search`: 从 ACR 拉取, 端口 8081, JVM 256m/384m, NACOS_ADDR=106.53.106.41:8848
- `mall-portal`: 从 ACR 拉取, 端口 8085, JVM 256m/384m, NACOS_ADDR=106.53.106.41:8848
- `mall-monitor`: 从 ACR 拉取, 端口 8101, JVM 192m/256m, NACOS_ADDR=106.53.106.41:8848

### Nacos 配置文件说明

所有 prod 配置中的中间件地址替换规则：

| 原别名 | 替换为 | 说明 |
| --- | --- | --- |
| `db` | `106.53.132.192` | MySQL 在数据服务器 |
| `redis` | `106.53.132.192` | Redis 在数据服务器 |
| `es` | `8.134.65.121` | ES 在扩展服务器 |
| `mongo` | `8.134.65.121` | MongoDB 在扩展服务器 |
| `rabbit` | `8.134.65.121` | RabbitMQ 在扩展服务器 |
| `logstash` | `8.134.65.121` | Logstash 在扩展服务器 |


MySQL 连接信息统一为: `root` / `Mall@2026_root`
Redis 密码统一为: `Mall@2026_redis`

## Implementation Notes

1. **Server ② 环境准备是前提**：未安装 Docker，必须先完成
2. **Nacos 必须最先启动并健康**：所有应用服务依赖 Nacos 注册和配置，Nacos 挂了全部无法启动
3. **Nacos 配置导入时机**：在 Nacos 启动后、应用服务启动前，通过 `import-config.sh` 脚本导入
4. **MySQL 初始化**：mall.sql 通过 docker-entrypoint-initdb.d 自动导入，仅在首次启动时执行
5. **ES 内存限制关键**：扩展服务器只有 4G，ES 必须 -Xms512m -Xmx512m，否则 OOM
6. **RabbitMQ vhost 配置**：portal 需要的 vhost `/mall` 需在 RabbitMQ 启动后手动创建或通过环境变量
7. **安全组检查**：② 号服务器安全组端口未全部开放，部署前需确认
8. **Gateway Redis 连接**：Gateway 需要连 Redis（Sa-Token），在跨服务器场景下需指向 106.53.132.192:6379

## Agent Extensions

### SubAgent

- **code-explorer**: 在编写 Nacos 配置和 docker-compose 文件时，用于快速搜索各微服务的完整依赖关系和配置项，确保不遗漏任何中间件连接配置