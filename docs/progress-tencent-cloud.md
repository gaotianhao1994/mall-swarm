# 腾讯云主服务器 — 部署进度追踪

> **服务器**: 腾讯云 4核4G | **公网 IP**: `106.53.106.41`
> **系统**: Ubuntu 22.04 LTS | **角色**: 主服务器（核心应用 + 基础中间件）
> **最后更新**: 2026-06-11 (部署日)

---

## 当前阶段总览

| 阶段 | 内容 | 状态 |
|------|------|------|
| **阶段0** | 环境准备 | ✅ **已完成** |
| **阶段1** | 基础骨架（MySQL + Redis + Nacos + Gateway + Admin + Auth） | 🔧 **进行中 — CI/CD 已通，服务启动待调 Nacos 配置** |
| 阶段2 | 商品搜索（ES + mall-search）→ 阿里云服务器 | ☐ 待开始 |
| 阶段3 | 前台商城（MongoDB + RabbitMQ + mall-portal）→ 阿里云服务器 | ☐ 待开始 |
| 阶段4 | 日志监控（ELK + mall-monitor） | ☐ 待开始 |
| 阶段5 | 前端部署（mall-admin-web → Nginx） | ☐ 待开始 |

---

## 阶段0：环境准备 ✅ 全部完成

### 2.1 重装系统确认
- [x] 系统已重装为 Ubuntu 22.04 LTS
- [x] 已设置 root 密码
- [x] 已通过 SSH 连接成功

### 2.2 安装 Docker
- [x] 使用阿里云镜像源安装（国内源，绕过 Docker Hub 限制）
- [x] 安装完成：**Docker 29.5.3** + **Docker Compose v5.1.4**
- [x] 已配置国内镜像加速器（腾讯云/中科大/网易/百度）
- [x] `docker run hello-world` 测试通过

### 2.3 安装 Git
- [x] 系统预装 **Git 2.34.1**

### 2.4 安全组端口开放
- [x] 所有端口已在腾讯云控制台开放（22/80/443/3306/6379/8848/8201/8080/8401）

### 2.5 Hosts 配置
- [x] 已配置 `/etc/hosts`，添加阿里云映射：
```bash
8.134.65.121  aliyun-server
```
- [x] 两台服务器 ping 通，延迟 ~12ms

---

## 阶段1：基础微服务骨架 🔧 进行中

### Part A：基础设施准备 ✅ 全部完成

#### 3.1 GitHub & ACR 配置
- [x] 项目已 Fork 到 GitHub: `gaotianhao1994/mall-swarm`（master 分支）
- [x] 已创建阿里云 ACR 个人版实例（广州区域）

**ACR 信息**:
| 项目 | 值 |
|------|-----|
| Registry | `crpi-9lhedueyyvqzcyrk.cn-guangzhou.personal.cr.aliyuncs.com` |
| 命名空间 | `mall-swarm-202606` |
| 仓库名称 | `mall-swarm-202606` |
| 类型 | 私有 |

- [x] GitHub Secrets 已配置（ACR_REGISTRY / ACR_NAMESPACE / ACR_USERNAME / ACR_PASSWORD）
- [x] 项目已克隆到 `/opt/mall-swarm`

#### 3.2 CI/CD 工作流（GitHub Actions）✅ 构建成功
- [x] 创建 `.github/workflows/docker-build.yml`
- [x] 创建 `docker/Dockerfile.module`（单阶段 JRE Alpine 镜像）
- [x] 创建 `docker/docker-compose.base.yml`（阶段1 编排文件）
- [x] 创建 `docker/.env.example` 和 `docker/.env`（环境变量）
- [x] 复制 SQL 初始化文件到 `docker/sql/init/mall.sql`

**⚠️ CI/CD 排障记录（共 8 次构建迭代）：**

| 构建 # | 失败原因 | 修复方案 |
|--------|---------|---------|
| #1~#2 | Dockerfile 内部 Maven 构建找不到 pom.xml | 改为单阶段 Dockerfile |
| #3~#4 | context=模块目录导致 COPY 找不到 JAR | context 改为根目录 "." |
| **#5** | **docker-maven-plugin 导致 Maven 中断** | 添加 `-Ddocker.skip=true` |
| #6 | GitHub Actions 拉取 Docker Hub 超时 | 配置 daemon.json 镜像加速 |
| **#7** | **ACR 地址错误（杭州→广州）+ 推送权限不足** | 修正 Registry 地址 |
| **#8** | **ACR 个人版无法自动创建仓库** | **改为单仓库 + Tag 区分策略** |
| **#9** | ✅ **全部通过！6 个镜像成功推送到 ACR** | — |

**最终镜像路径格式**：
```
crpi-9lhedueyyvqzcyrk.cn-guangzhou.personal.cr.aliyuncs.com/mall-swarm-202606/mall-swarm-202606:mall-gateway-latest
crpi-9lhedueyyvqzcyrk.cn-guangzhou.personal.cr.aliyuncs.com/mall-swarm-202606/mall-swarm-202606:mall-admin-latest
crpi-9lhedueyyvqzcyrk.cn-guangzhou.personal.cr.aliyuncs.com/mall-swarm-202606/mall-swarm-202606:mall-auth-latest
...（portal/search-monitor 同理）
```

### Part B：服务部署 ⏳ 进行中

#### 4.1 基础设施容器启动 ✅ 成功
- [x] MySQL 5.7 → healthy ✅ （端口 3306）
- [x] Redis 7 → healthy ✅ （端口 6379）
- [x] Nacos 2.1.0 → healthy ✅ （端口 8848）

#### 4.2 应用服务容器启动 ✅ 启动成功，待调配置
- [x] mall-gateway → 已拉取镜像并启动（端口 8201）
- [x] mall-admin → 已拉取镜像并启动（端口 8080）
- [x] mall-auth → 已拉取镜像并启动（端口 8401）

**⚠️ 发现问题（未解决）：**

Gateway 日志显示连接 Nacos 失败：
```
Fail to connect server, after trying 12 times,
last try server is {serverIp = 'localhost', server main port = 8848}
```

**原因分析**：应用内部配置的 Nacos 地址为 `localhost:8848`，
但在 Docker 容器内应使用服务名 `nacos:8848`。
需要检查各服务的 `bootstrap.yml` 或 Nacos 配置中心中的注册地址。

**下次继续时需处理**：
1. [ ] 检查各微服务模块的 `bootstrap.yml` 中 Nacos server-addr 配置
2. [ ] 如为硬编码 localhost，需改为环境变量或 Nacos 配置中心覆盖
3. [ ] 可能需要在 docker-compose.base.yml 中增加 NACOS_SERVER_ADDR 环境变量
4. [ ] 确认各服务在 Nacos 控制台中正确注册
5. [ ] 通过 Gateway 访问 Admin API 进行端到端验证
6. [ ] 配置 Nginx 反向代理（阶段5可提前做）

#### 4.3 性能注意
- 4G 内存运行 6 个容器（MySQL + Redis + Nacos + 3个 Java 服务）接近满载
- 建议：后续考虑添加 Swap 分区或升级内存到 8G
- 当前方案：不使用时关闭容器释放资源（`docker compose down`）

---

## 已创建的文件清单

```
/opt/mall-swarm/
├── .github/workflows/
│   └── docker-build.yml              ← CI/CD 工作流（Maven构建 + Docker推送ACR）
├── docker/
│   ├── Dockerfile.module             ← 微服务通用 Dockerfile（JRE Alpine）
│   ├── docker-compose.base.yml       ← 阶段1 编排（MySQL/Redis/Nacos/Gateway/Admin/Auth）
│   ├── .env                          ← 生产环境变量（含密码，已 gitignore）
│   ├── .env.example                  ← 环境变量模板
│   └── sql/init/mall.sql             ← 数据库初始化 SQL（407KB）
└── .gitignore                        ← 已更新（排除 .env）
```

---

## 问题日志

| 时间 | 阶段 | 问题描述 | 解决方案 | 状态 |
|------|------|---------|---------|------|
| 06-11 | 阶段0 | apt-get install 被 IDE 沙箱限制 | 用户切换为沙箱外执行模式 | ✅ |
| 06-11 | 阶段0 | Docker Hub 国内访问超时 | 配置 daemon.json 国内镜像加速 | ✅ |
| 06-11 | 阶段0 | ACR 企业版入口难找 | 切换个人认证账号后找到 | ✅ |
| 06-11 | 阶段1 | Dockerfile 内部 Maven 找不到 pom.xml | 移除多阶段构建，改为预构建 JAR | ✅ |
| 06-11 | 阶段1 | context 错误导致 COPY JAR 失败 | context 统一改 "." 根目录 | ✅ |
| 06-11 | 阶段1 | docker-maven-plugin 连接失败导致构建中断 | `-Ddocker.skip=true` 跳过 | ✅ |
| 06-11 | 阶段1 | GitHub Actions Docker Hub 超时 | daemon.json 加镜像源 | ✅ |
| 06-11 | 阶段1 | ACR Registry 地址错误（杭州 vs 广州） | 改为广州个人版地址 | ✅ |
| 06-11 | 阶段1 | ACR push access denied（仓库不存在） | 单仓库 + Tag 区分策略 | ✅ |
| 06-11 | 阶段1 | 服务连接 Nacos 用 localhost 而非服务名 | **待解决：需调整应用配置** | 🔧 |

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
| 日志目录 | `/opt/mall-swarm/logs/` |
| SQL 初始化文件 | `/opt/mall-swarm/document/sql/mall.sql` |

### .env 文件关键变量
| 变量 | 值 |
|------|-----|
| MYSQL_ROOT_PASSWORD | `Mall@2026_root` |
| REDIS_PASSWORD | `Mall@2026_redis` |
| NACOS_AUTH_TOKEN | (默认值) |
| ACR_REGISTRY | `crpi-9lhedueyyvqzcyrk.cn-guangzhou.personal.cr.aliyuncs.com` |
| ACR_NAMESPACE | `mall-swarm-202606` |

### 常用命令速查
```bash
# 启动所有阶段1服务
cd /opt/mall-swarm/docker && docker compose -f docker-compose.base.yml up -d

# 仅启动基础设施
cd /opt/mall-swarm/docker && docker compose -f docker-compose.base.yml up -d mysql redis nacos

# 查看日志
docker compose -f docker-compose.base.yml logs -f mall-gateway

# 停止所有服务
docker compose -f docker-compose.base.yml down

# 重新触发 CI/CD 构建
# 方式1: 推送代码自动触发
# 方式2: GitHub Actions 页面手动 Run workflow
```

### 下次继续时的起点
```
从「阶段1 Part B — 4.2 应用服务配置调试」开始：
  1. 启动基础设施: docker compose up -d mysql redis nacos
  2. 检查 bootstrap.yml 中 Nacos server-addr 配置
  3. 修改为支持环境变量或 Docker DNS 服务名
  4. 重新构建镜像（如需改代码则 push 触发 CI/CD）
  5. 启动应用服务并验证注册到 Nacos
  6. 端到端测试: curl http://106.53.106.41:8201/...
```
