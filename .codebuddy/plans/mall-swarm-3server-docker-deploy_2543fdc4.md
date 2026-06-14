---
name: mall-swarm-3server-docker-deploy
overview: 将 mall-swarm 微服务系统以 Docker Compose 全量部署到三台云服务器，包含环境准备、配置文件创建、Nacos 配置导入、按序启动和端到端验证。
todos:
  - id: create-compose-and-config
    content: 创建三个 docker-compose 编排文件 + nginx.conf + .env 到本地 docker/ 目录
    status: completed
  - id: create-nacos-configs
    content: 创建 Nacos prod 配置文件(5个) + import-config.sh 到本地 docker/nacos-config/
    status: completed
  - id: install-docker-and-distribute
    content: tengxun-server9 安装 Docker/Compose V2 + scp 分发文件到三台服务器
    status: completed
    dependencies:
      - create-compose-and-config
      - create-nacos-configs
  - id: deploy-gateway-server
    content: "部署 tengxun-server: Nacos -> 导入配置 -> ES/Gateway/Search/Nginx"
    status: completed
    dependencies:
      - install-docker-and-distribute
  - id: deploy-data-and-extend
    content: 部署 tengxun-server9(MySQL/Redis/Admin/Auth) + aliyun-server(RabbitMQ/Mongo/Portal/Monitor)
    status: completed
    dependencies:
      - deploy-gateway-server
  - id: e2e-verify
    content: "端到端验证: Nginx -> Gateway -> 各服务全链路通畅"
    status: completed
    dependencies:
      - deploy-data-and-extend
---

## 产品概述

将 mall-swarm 微服务商城系统以 Docker Compose 形式全量部署到三台云服务器，使所有中间件和应用服务正常运行，Nginx 提供统一入口，端到端链路通畅。

## 核心功能

- 三台服务器分角色部署：网关层(Nacos+Gateway+Nginx+ES+Search)、数据层(MySQL+Redis+Admin+Auth)、扩展层(RabbitMQ+Mongo+Portal+Monitor)
- 通过环境变量覆盖解决跨服务器 Nacos 注册发现问题
- 通过 import-config.sh 脚本将 Nacos 配置中心的中间件地址从 Docker 别名替换为实际 IP
- Nginx 反向代理提供统一入口
- 端到端验证全链路通畅

## 技术栈

- 容器编排: Docker Compose V2（每台服务器独立编排文件）
- 镜像仓库: 阿里云 ACR 个人版（6个镜像已推送）
- 配置中心: Nacos 2.1.0（服务注册 + 配置管理，通过 Open API 导入配置）
- 执行方式: 本地 PowerShell 通过 scp/ssh 远程操作三台服务器

## 服务器角色与组件分配

| 服务器 | SSH 别名 | IP | 规格 | 容器 |
| --- | --- | --- | --- | --- |
| 网关服务器 | tengxun-server | 106.53.106.41 | 4C4G | Nacos + Gateway + Nginx + ES + Search |
| 数据服务器 | tengxun-server9 | 106.53.132.192 | 4C4G | MySQL + Redis + Admin + Auth |
| 扩展服务器 | aliyun-server | 8.134.65.121 | 2C4G | RabbitMQ + Mongo + Portal + Monitor |


优化说明：Portal 依赖 RabbitMQ+Mongo，放同台低延迟；tengxun-server9 降到4容器更稳定；aliyun-server 资源利用率提升。

## 实施方案

### 核心策略

按服务器角色将 docker-compose.base.yml 拆分为 3 个独立编排文件，本地创建所有配置后通过 scp 分发，远程 ssh 执行部署。

### 关键技术决策

**1. Nacos 地址覆盖**

- 所有应用服务的 application-prod.yml 中 Nacos 地址为 `nacos-registry:8848`（Docker 服务名），跨服务器无法解析
- 在 docker-compose 中通过 `SPRING_CLOUD_NACOS_DISCOVERY_SERVER-ADDR` 和 `SPRING_CLOUD_NACOS_CONFIG_SERVER-ADDR` 环境变量覆盖，指向 `106.53.106.41:8848`
- 同时设置 `SPRING_PROFILES_ACTIVE=prod` 激活 prod 配置
- 优势：无需重新构建镜像，无需修改源码

**2. Nacos 配置中心中间件地址更新**

- 编写 import-config.sh 脚本，通过 Nacos Open API 在 Nacos 启动后自动导入
- 配置文件中的地址替换规则：

| 原别名 | 替换为 | 说明 |
| --- | --- | --- |
| `db` | `106.53.132.192` | MySQL 在数据服务器 |
| `redis` | `106.53.132.192` | Redis 在数据服务器 |
| `es` | `106.53.106.41` | ES 在网关服务器 |
| `mongo` | `8.134.65.121` | MongoDB 在扩展服务器 |
| `rabbit` | `8.134.65.121` | RabbitMQ 在扩展服务器 |
| `logstash` | `8.134.65.121` | Logstash 在扩展服务器 |


**3. 密码统一方案**

- MySQL root: `Mall@2026_root`
- Redis: `Mall@2026_redis`
- Nacos 配置中的 MySQL 连接统一为 root/Mall@2026_root

**4. HEALTHCHECK 端口覆盖**

- Dockerfile.module 默认健康检查端口 8080，但 Gateway(8201)/Auth(8401)/Search(8081)/Portal(8085)/Monitor(8101) 端口不同
- 在 docker-compose 中通过 healthcheck 覆盖，或在 JAVA_OPTS 中加入 actuator 端口配置

**5. Auth 最小 Nacos 配置**

- config/ 下无 mall-auth-prod.yaml，需创建最小的配置文件（Auth 无特殊中间件依赖，仅注册到 Nacos）

**6. RabbitMQ vhost 配置**

- Portal 需要 `/mall` vhost，通过 RABBITMQ_DEFAULT_VHSOT 环境变量在首次启动时自动创建

**7. 内存优化**

- tengxun-server (4G): Nacos(512m) + Gateway(384m) + ES(512m) + Search(384m) + Nginx(约64m) 约1.9G
- tengxun-server9 (4G): MySQL(256m buffer) + Redis(128m) + Admin(384m) + Auth(320m) 约1.6G
- aliyun-server (2C4G): RabbitMQ(默认256m) + Mongo(默认) + Portal(384m) + Monitor(256m) 约2.5G

## 目录结构

```
mall-swarm/docker/
├── docker-compose.base.yml               # [KEEP] 单机参考，不再使用
├── docker-compose.gateway.yml            # [NEW] 网关服务器编排: Nacos + Gateway + Nginx + ES + Search
├── docker-compose.data.yml               # [NEW] 数据服务器编排: MySQL + Redis + Admin + Auth
├── docker-compose.extend.yml             # [NEW] 扩展服务器编排: RabbitMQ + Mongo + Portal + Monitor
├── Dockerfile.module                     # [KEEP] 无需修改
├── .env                                  # [NEW] 实际环境变量（含密码，不提交Git）
├── .env.example                          # [MODIFY] 增加三台服务器IP和新中间件变量
├── nginx/
│   └── nginx.conf                        # [NEW] Nginx 反向代理配置
├── nacos-config/
│   ├── import-config.sh                  # [NEW] 自动导入 Nacos 配置的 Shell 脚本
│   ├── mall-admin-prod.yaml             # [NEW] Admin 生产配置（db→106.53.132.192, redis→106.53.132.192, root/Mall@2026_root）
│   ├── mall-gateway-prod.yaml            # [NEW] Gateway 生产配置（redis→106.53.132.192）
│   ├── mall-search-prod.yaml             # [NEW] Search 生产配置（db→106.53.132.192, es→106.53.106.41, root/Mall@2026_root）
│   ├── mall-portal-prod.yaml             # [NEW] Portal 生产配置（db→106.53.132.192, redis→106.53.132.192, mongo→8.134.65.121, rabbit→8.134.65.121）
│   └── mall-auth-prod.yaml              # [NEW] Auth 最小生产配置（无中间件依赖）
└── sql/
    └── init/
        └── mall.sql                      # [KEEP] MySQL 初始化脚本
```

### 各编排文件详细说明

**docker-compose.gateway.yml** — tengxun-server (106.53.106.41)

- `nacos`: Nacos 2.1.0 standalone, 端口 8848, JVM 256m/512m, 开启鉴权
- `elasticsearch`: ES 7.17.3, 端口 9200/9300, JVM 512m/512m, single-node, discovery.type=single-node
- `mall-gateway`: ACR 镜像, 端口 8201, JVM 256m/384m, NACOS_ADDR 环境变量覆盖, healthcheck 端口 8201
- `mall-search`: ACR 镜像, 端口 8081, JVM 256m/384m, NACOS_ADDR 环境变量覆盖, healthcheck 端口 8081
- `nginx`: Nginx 1.22, 端口 80, 反向代理到 gateway:8201

**docker-compose.data.yml** — tengxun-server9 (106.53.132.192)

- `mysql`: MySQL 5.7, 端口 3306, innodb_buffer_pool=256M, 自动导入 mall.sql, root 密码 Mall@2026_root
- `redis`: Redis 7, 端口 6379, maxmemory 128mb, 密码 Mall@2026_redis
- `mall-admin`: ACR 镜像, 端口 8080, JVM 256m/384m, NACOS_ADDR 环境变量覆盖
- `mall-auth`: ACR 镜像, 端口 8401, JVM 192m/320m, NACOS_ADDR 环境变量覆盖, healthcheck 端口 8401

**docker-compose.extend.yml** — aliyun-server (8.134.65.121)

- `rabbitmq`: RabbitMQ 3.9.11-management, 端口 5672/15672, 用户 mall/mall, vhost /mall
- `mongo`: Mongo 4, 端口 27017
- `mall-portal`: ACR 镜像, 端口 8085, JVM 256m/384m, NACOS_ADDR 环境变量覆盖, healthcheck 端口 8085
- `mall-monitor`: ACR 镜像, 端口 8101, JVM 192m/256m, NACOS_ADDR 环境变量覆盖, healthcheck 端口 8101

## 实施注意事项

1. **tengxun-server9 未安装 Docker**：需先远程安装 Docker Engine + Compose V2 插件
2. **Nacos 必须最先启动**：所有应用依赖 Nacos 注册和配置，Nacos 挂了全部无法启动
3. **Nacos 配置导入时机**：Nacos 启动健康后、应用服务启动前，通过 import-config.sh 导入
4. **MySQL 初始化**：mall.sql 通过 docker-entrypoint-initdb.d 自动导入，仅首次启动执行
5. **ES 内存限制关键**：aliyun-server 只有 2C4G，ES 必须 -Xms512m -Xmx512m
6. **安全组**：三台防火墙已全部放开，无需额外操作
7. **代码目录**：三台服务器 /root/projects 目录已存在
8. **服务器间无互信**：所有操作从本地通过 SSH 执行，scp 传文件
9. **Redis 密码**：Nacos 配置中所有 redis password 需设置为 Mall@2026_redis

## SubAgent

- **code-explorer**: 在编写 Nacos 配置和 docker-compose 文件时，用于搜索各微服务的完整依赖关系和配置项（如 actuator 端口、Sa-Token 配置、ES 连接参数等），确保不遗漏任何中间件连接配置