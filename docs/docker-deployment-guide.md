# mall-swarm 微服务商城系统 — Docker 部署指南

> **适用版本**: mall-swarm 1.0-SNAPSHOT | Spring Boot 3.5 + Spring Cloud 2025 + Spring Cloud Alibaba
> **最后更新**: 2026-06-10
> **作者**: 基于 macrozheng/mall-swarm 项目编写

***

## 目录

- [mall-swarm 微服务商城系统 — Docker 部署指南](#mall-swarm-微服务商城系统--docker-部署指南)
  - [目录](#目录)
  - [第1章：概述](#第1章概述)
    - [1.1 文档目标与读者假设](#11-文档目标与读者假设)
    - [1.2 整体架构图](#12-整体架构图)
    - [知识点：微服务架构 vs 单体架构](#知识点微服务架构-vs-单体架构)
    - [1.3 技术选型说明](#13-技术选型说明)
    - [知识点：为什么用 Docker 而不是直接跑 jar？](#知识点为什么用-docker-而不是直接跑-jar)
    - [1.4 服务器规划](#14-服务器规划)
      - [主服务器（腾讯云 4核4G） — 公网 IP：`106.53.106.41`](#主服务器腾讯云-4核4g--公网-ip1065310641)
      - [扩展服务器（阿里云 2核4G） — 公网 IP：`8.134.65.121`](#扩展服务器阿里云-2核4g--公网-ip813465121)
    - [知识点：为什么要把 ES/Mongo/RabbitMQ 放到另一台机器？](#知识点为什么要把-esmongorabbitmq-放到另一台机器)
    - [1.5 部署阶段总览](#15-部署阶段总览)
    - [1.6 内存预估表](#16-内存预估表)
  - [第2章：环境准备（两台服务器都要做）](#第2章环境准备两台服务器都要做)
    - [2.1 重装系统建议](#21-重装系统建议)
    - [2.2 安装 Docker](#22-安装-docker)
      - [方式一：Ubuntu 22.04（推荐）](#方式一ubuntu-2204推荐)
      - [方式二：CentOS 7.9](#方式二centos-79)
    - [知识点：为什么不用 `apt install docker` 或 `yum install docker`？](#知识点为什么不用-apt-install-docker-或-yum-install-docker)
    - [2.3 安装 Docker Compose](#23-安装-docker-compose)
    - [2.4 安装 Git](#24-安装-git)
    - [知识点：为什么服务器需要 Git？](#知识点为什么服务器需要-git)
    - [2.5 验证安装](#25-验证安装)
    - [2.6 防火墙/安全组端口开放指南](#26-防火墙安全组端口开放指南)
    - [知识点：防火墙 vs 安全组 — 两道防线](#知识点防火墙-vs-安全组--两道防线)
      - [必须开放的端口汇总](#必须开放的端口汇总)
      - [云厂商安全组配置步骤](#云厂商安全组配置步骤)
      - [操作系统防火墙配置](#操作系统防火墙配置)
    - [2.7 Hosts 配置（可选但推荐）](#27-hosts-配置可选但推荐)
  - [第3章：基础设施准备](#第3章基础设施准备)
    - [3.1 Fork 项目到自己的 GitHub](#31-fork-项目到自己的-github)
    - [知识点：为什么 Fork 而不是直接 Clone 原项目？](#知识点为什么-fork-而不是直接-clone-原项目)
    - [3.2 创建阿里云 ACR 镜像仓库](#32-创建阿里云-acr-镜像仓库)
    - [知识点：什么是 ACR？为什么不用 Docker Hub？](#知识点什么是-acr为什么不用-docker-hub)
    - [3.3 获取 ACR 凭证并配置 GitHub Secrets](#33-获取-acr-凭证并配置-github-secrets)
    - [知识点：什么是 GitHub Secrets？为什么需要它？](#知识点什么是-github-secrets为什么需要它)
    - [3.4 编写 GitHub Actions 工作流文件](#34-编写-github-actions-工作流文件)
    - [知识点：GitHub Actions 是什么？为什么用它来做 CI/CD？](#知识点github-actions-是什么为什么用它来做-cicd)
    - [知识点：为什么用多阶段构建（Multi-stage Build）？](#知识点为什么用多阶段构建multi-stage-build)
    - [3.5 在服务器上克隆项目](#35-在服务器上克隆项目)
    - [3.6 准备目录结构和 .env 文件模板](#36-准备目录结构和-env-文件模板)
    - [知识点：为什么 ES 需要 vm.max\_map\_count？](#知识点为什么-es-需要-vmmax_map_count)
    - [3.7 导入数据库初始化 SQL](#37-导入数据库初始化-sql)
  - [第4章：阶段1 — 基础微服务骨架](#第4章阶段1--基础微服务骨架)
    - [4.1 本阶段目标和服务列表](#41-本阶段目标和服务列表)
    - [4.2 编写 docker-compose.base.yml](#42-编写-docker-composebaseyml)
    - [知识点：为什么用 `depends_on` + `condition: service_healthy`？](#知识点为什么用-depends_on--condition-service_healthy)
    - [4.3 各服务的 Dockerfile](#43-各服务的-dockerfile)
    - [知识点：原项目 docker-maven-plugin vs 我们的 Dockerfile 对比](#知识点原项目-docker-maven-plugin-vs-我们的-dockerfile-对比)
    - [4.4 Nacos 配置导入指南](#44-nacos-配置导入指南)
    - [知识点：Nacos 配置中心是什么？为什么要用它？](#知识点nacos-配置中心是什么为什么要用它)
      - [导入步骤](#导入步骤)
    - [4.5 Nginx 反向代理配置](#45-nginx-反向代理配置)
    - [4.6 启动命令和顺序](#46-启动命令和顺序)
    - [知识点：为什么启动顺序很重要？](#知识点为什么启动顺序很重要)
      - [启动前检查清单](#启动前检查清单)
      - [第一次启动（带数据库初始化）](#第一次启动带数据库初始化)
      - [日常启动（数据库已有数据）](#日常启动数据库已有数据)
      - [停止服务](#停止服务)
    - [4.7 验证清单](#47-验证清单)
      - [✅ 步骤 1：验证基础设施](#-步骤-1验证基础设施)
      - [✅ 步骤 2：验证应用服务注册到 Nacos](#-步骤-2验证应用服务注册到-nacos)
      - [✅ 步骤 3：验证 mall-auth（认证中心）](#-步骤-3验证-mall-auth认证中心)
      - [✅ 步骤 4：验证 mall-admin（后台管理）](#-步骤-4验证-mall-admin后台管理)
      - [✅ 步骤 5：验证 mall-gateway（API 网关）](#-步骤-5验证-mall-gatewayapi-网关)
      - [✅ 步骤 6：验证 Nginx 反向代理](#-步骤-6验证-nginx-反向代理)
      - [📋 阶段 1 完整验证清单](#-阶段-1-完整验证清单)
    - [4.8 常见问题排查](#48-常见问题排查)
      - [问题 1：MySQL 容器不断重启](#问题-1mysql-容器不断重启)
      - [问题 2：Nacos 启动后无法访问控制台](#问题-2nacos-启动后无法访问控制台)
      - [问题 3：应用服务无法注册到 Nacos](#问题-3应用服务无法注册到-nacos)
      - [问题 4：镜像拉取失败](#问题-4镜像拉取失败)
  - [第5章：阶段2 — 商品搜索服务](#第5章阶段2--商品搜索服务)
    - [5.1 新增服务说明](#51-新增服务说明)
    - [知识点：为什么商品搜索需要 Elasticsearch？](#知识点为什么商品搜索需要-elasticsearch)
    - [5.2 docker-compose.search.yml 完整内容](#52-docker-composesearchyml-完整内容)
    - [5.3 Elasticsearch 内存优化配置（针对低配服务器）](#53-elasticsearch-内存优化配置针对低配服务器)
    - [知识点：ES 为什么这么吃内存？](#知识点es-为什么这么吃内存)
    - [5.4 启动和验证](#54-启动和验证)
      - [启动命令](#启动命令)
      - [验证清单](#验证清单)
      - [关于跨服务器通信的重要说明](#关于跨服务器通信的重要说明)
  - [第6章：阶段3 — 前台商城服务](#第6章阶段3--前台商城服务)
    - [6.1 新增服务说明](#61-新增服务说明)
    - [6.2 docker-compose.portal.yml 完整内容](#62-docker-composeportalyml-完整内容)
    - [6.3 MongoDB 和 RabbitMQ 基础配置](#63-mongodb-和-rabbitmq-基础配置)
      - [MongoDB 初始化](#mongodb-初始化)
      - [RabbitMQ 配置](#rabbitmq-配置)
    - [6.4 启动和验证](#64-启动和验证)
      - [启动命令](#启动命令-1)
      - [验证清单](#验证清单-1)
  - [第7章：阶段4 — 日志监控](#第7章阶段4--日志监控)
    - [7.1 ELK 架构说明](#71-elk-架构说明)
    - [知识点：为什么需要集中式日志？](#知识点为什么需要集中式日志)
    - [7.2 docker-compose.elk.yml 完整内容](#72-docker-composeelkyml-完整内容)
    - [7.3 Logstash 配置文件](#73-logstash-配置文件)
    - [知识点：为什么 Logstash 需要四个端口？](#知识点为什么-logstash-需要四个端口)
    - [7.4 启动和验证](#74-启动和验证)
      - [启动命令](#启动命令-2)
      - [验证清单](#验证清单-2)
      - [Kibana 快速配置指南](#kibana-快速配置指南)
  - [第8章：前端部署](#第8章前端部署)
    - [8.1 mall-admin-web 前端项目说明](#81-mall-admin-web-前端项目说明)
    - [8.2 构建前端静态资源](#82-构建前端静态资源)
      - [前提条件](#前提条件)
      - [构建步骤](#构建步骤)
      - [修改 API 请求地址](#修改-api-请求地址)
    - [8.3 部署到 Nginx](#83-部署到-nginx)
      - [方式一：直接复制静态文件](#方式一直接复制静态文件)
      - [方式二：通过 Docker Volume 挂载](#方式二通过-docker-volume-挂载)
      - [验证前端部署](#验证前端部署)
  - [第9章：运维指南](#第9章运维指南)
    - [9.1 常用命令速查表](#91-常用命令速查表)
      - [容器管理](#容器管理)
      - [镜像管理](#镜像管理)
      - [网络与调试](#网络与调试)
    - [9.2 日志查看方法](#92-日志查看方法)
      - [方式一：Docker Logs（最常用）](#方式一docker-logs最常用)
      - [方式二：宿主机日志文件](#方式二宿主机日志文件)
      - [方式三：Kibana（推荐生产环境使用）](#方式三kibana推荐生产环境使用)
      - [方式四：Nacos 控制台日志](#方式四nacos-控制台日志)
    - [9.3 服务重启流程](#93-服务重启流程)
      - [正常重启单个服务](#正常重启单个服务)
      - [滚动更新（零停机）](#滚动更新零停机)
      - [全量重启（谨慎使用）](#全量重启谨慎使用)
    - [9.4 数据备份策略](#94-数据备份策略)
      - [MySQL 备份](#mysql-备份)
      - [Redis 备份](#redis-备份)
      - [Nacos 配置备份](#nacos-配置备份)
      - [Elasticsearch 索引快照（可选）](#elasticsearch-索引快照可选)
    - [9.5 更新部署流程](#95-更新部署流程)
  - [第10章：排障指南](#第10章排障指南)
    - [10.1 容器启动失败常见原因](#101-容器启动失败常见原因)
      - [排查流程图](#排查流程图)
      - [常见错误码速查](#常见错误码速查)
    - [10.2 服务间连接失败排查](#102-服务间连接失败排查)
    - [知识点：Docker 容器间是如何通信的？](#知识点docker-容器间是如何通信的)
    - [10.3 Nacos 注册失败处理](#103-nacos-注册失败处理)
    - [10.4 内存不足(OOM)应对](#104-内存不足oom应对)
    - [知识点：Linux OOM Killer 是什么？](#知识点linux-oom-killer-是什么)
    - [10.5 网络不通排查思路](#105-网络不通排查思路)
      - [排查矩阵](#排查矩阵)
      - [逐步排查命令](#逐步排查命令)
      - [常见网络问题速查](#常见网络问题速查)
  - [附录](#附录)
    - [附录 A: 完整端口参考表](#附录-a-完整端口参考表)
    - [附录 B: .env 文件完整模板](#附录-b-env-文件完整模板)
    - [附录 C: docker-compose 文件完整汇总](#附录-c-docker-compose-文件完整汇总)
    - [附录 D: 推荐学习路径](#附录-d-推荐学习路径)
    - [附录 E: 从本方案进阶到 K8s 的方向指引](#附录-e-从本方案进阶到-k8s-的方向指引)
      - [为什么以及什么时候需要 K8s？](#为什么以及什么时候需要-k8s)
      - [进阶路线图](#进阶路线图)
      - [关键转换对照表](#关键转换对照表)

***

## 第1章：概述

### 1.1 文档目标与读者假设

**是什么？**
这是一份面向**个人开发者 / 小团队**的 mall-swarm 微服务商城系统的 **Docker 生产级部署指南**。目标是让你从零开始，在两台低配云服务器上，通过 **4 个渐进式阶段**完成整个微服务集群的部署。

**为什么？**
mall-swarm 是一个经典的 Spring Cloud Alibaba 微服务学习项目，但原项目的部署文档偏重于本地开发环境。对于想要**真正把这套系统跑在生产服务器上**的开发者来说，缺少一份覆盖 CI/CD、镜像管理、分阶段部署、故障排查的完整指南。

**追问：为什么需要"渐进式部署"？**

因为一次性启动所有容器会带来三个问题：

| 问题   | 原因                                                 | 渐进式解决            |
| ---- | -------------------------------------------------- | ---------------- |
| 内存爆满 | ES + MongoDB + RabbitMQ + MySQL + Redis 同时运行需要大量内存 | 分散到不同阶段          |
| 排错困难 | 10+ 个服务同时启动，任何一个出问题都难以定位                           | 每个阶段只增加 1\~3 个服务 |
| 心理压力 | 一上来就面对复杂度爆炸的系统容易放弃                                 | 先跑通最小可用系统，逐步扩展   |

**读者假设：**

* 你有一台或多台 Linux 云服务器（腾讯云 / 阿里云均可）

* 你会用基本的 Linux 命令（`cd`、`ls`、`vim`、`cat`）

* 你了解 Docker 的基本概念（镜像、容器、卷），但不一定精通

* 你有 GitHub 账号，了解 Git 基本操作

* **不需要**你在服务器上装 JDK 或 Maven —— 所有构建都在云端完成

***

### 1.2 整体架构图

```
                          ┌─────────────────────────────────────┐
                          │         用户浏览器 (公网访问)          │
                          └──────────────┬──────────────────────┘
                                         │ HTTP :80
                                         ▼
                          ┌─────────────────────────────────────┐
                          │           Nginx (反向代理)            │
                          │    主服务器 | nginx:1.22 | 端口 80     │
                          └───┬──────────┬──────────┬───────────┘
                              │          │          │
                   静态资源    │   API请求  │   API请求  │  管理后台页面
                       ▼      ▼          ▼          ▼
              ┌──────────┐ ┌──────────────────────────────┐
              │ 前端静态  │ │      mall-gateway (8201)      │
              │  HTML/JS │ │   Spring Cloud Gateway        │
              └──────────┘ │   Sa-Token 认证 + 路由转发      │
                              └──┬──────┬──────┬───────────┘
                                 │      │      │
                    /mall-admin/**│      │/mall-auth/**  │/mall-portal/**
                                 ▼      ▼               ▼
                    ┌──────────────┐ ┌──────────┐  ┌──────────────┐
                    │ mall-admin   │ │ mall-auth│  │ mall-portal  │
                    │  (8080)      │ │ (8401)   │  │  (8085)      │
                    │ 后台管理系统  │ │ 认证中心  │  │ 前台商城      │
                    └──────┬───────┘ └────┬─────┘  └──────┬───────┘
                           │              │                │
           ┌───────────────┼──────────────┼────────────────┼────────┐
           │               │              │                        │
           ▼               ▼              ▼                        ▼
   ┌──────────────┐ ┌──────────┐ ┌──────────────┐       ┌──────────────┐
   │ MySQL (3306) │ │ Redis    │ │ Nacos (8848) │       │ mall-search  │
   │ mysql:5.7    │ │ redis:7  │ │ 注册+配置中心 │       │  (8081)      │
   └──────────────┘ │ (6379)   │ └──────────────┘       │ 商品搜索(ES)  │
                     └──────────┘                         └──────┬───────┘
                                                            │
                                                            ▼
                                                   ┌──────────────┐
                                                   │ Elasticsearch │
                                                   │  (9200/9300)  │
                                                   └──────────────┘

═══════════════════════════════════════════════════════════════════
                    扩展服务器（阿里云 2核4G）
═══════════════════════════════════════════════════════════════════
   ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌────────────┐
   │ Elasticsearch│ │   MongoDB    │ │  RabbitMQ    │ │  Logstash  │
   │  (9200/9300) │ │   (27017)    │ │ (5672/15672) │ │ (4560-4563)│
   └──────────────┘ └──────────────┘ └──────────────┘ └──────┬─────┘
                                                                  │
                                                           ┌──────▼─────┐
                                                           │  Kibana    │
                                                           │  (5601)    │
                                                           └────────────┘
```

### 知识点：微服务架构 vs 单体架构

**是什么？**
单体架构 = 一个 `.jar` 包含所有功能（用户、商品、订单...）
微服务架构 = 拆成多个独立小服务，每个服务独立开发、部署、扩展

**为什么选微服务？**

* **独立部署**：改商品模块不影响订单模块

* **技术异构**：搜索用 Java + ES，可以用其他语言写其他服务

* **水平扩展**：订单量大就多起几个订单服务实例

**追问：那为什么不是所有项目都用微服务？**
因为微服务带来了**分布式复杂性**：服务间通信、数据一致性、运维复杂度都大幅上升。mall-swarm 作为学习项目正好适合用来掌握这些挑战。

***

### 1.3 技术选型说明

| 技术                   | 版本         | 用途          | 为什么选它                               |
| -------------------- | ---------- | ----------- | ----------------------------------- |
| Java                 | 17         | 运行时         | LTS 长期支持版本，性能优秀                     |
| Spring Boot          | 3.5.14     | 应用框架        | 最新稳定版，原生支持 GraalVM                  |
| Spring Cloud         | 2025.0.2   | 微服务框架       | Netflix 组件已过时，Spring Cloud 自家组件成熟   |
| Spring Cloud Alibaba | 2025.0.0.0 | 国产微服务生态     | Nacos（注册+配置一体）比 Eureka + Config 更方便 |
| Nacos                | v2.1.0     | 注册中心 + 配置中心 | 一个组件干两件事，减少基础设施数量                   |
| Sa-Token             | 1.42.0     | 认证授权        | 比 Spring Security 更轻量，API 更简洁       |
| MyBatis              | 3.5.19     | ORM 框架      | 国内主流，SQL 可控性强                       |
| MySQL                | 5.7        | 关系数据库       | 成熟稳定，5.7 仍是生产主力                     |
| Redis                | 7          | 缓存          | 性能极高，支持多种数据结构                       |
| Elasticsearch        | 7.17.3     | 搜索引擎        | 全文检索的事实标准                           |
| MongoDB              | 4          | NoSQL       | 门户内容存储灵活 schema                     |
| RabbitMQ             | 3.9.11     | 消息队列        | 可靠的消息投递保证                           |
| Docker               | latest     | 容器化         | 标准化交付，环境一致性                         |
| Docker Compose       | v2+        | 编排工具        | 多容器一键启停                             |

### 知识点：为什么用 Docker 而不是直接跑 jar？

**是什么？**
Docker 把应用及其依赖打包成「集装箱」，在任何装有 Docker 的机器上都能一致运行。

**为什么？**

* **环境一致性**：「在我电脑上能跑」→ 在服务器也能跑

* **依赖隔离**：ES 需要 JDK 8，你的应用需要 JDK 17 → 不冲突

* **快速部署**：`docker compose up` 一条命令启动整套系统

* **版本回滚**：镜像打标签，随时切回旧版本

**追问：为什么不直接用 K8s？**
K8s（Kubernetes）是容器编排的终极方案，但对于 **2 台 4GB 内存的个人学习服务器** 来说：

* K8s 本身就要吃掉 \~1GB 内存

* 学习曲线陡峭（Pod、Service、Ingress、ConfigMap...）

* **先用 Docker Compose 跑通全流程，理解原理后再迁移 K8s**（见附录 E）

***

### 1.4 服务器规划

#### 主服务器（腾讯云 4核4G） — 公网 IP：`106.53.106.41`

| 角色           | 部署的服务                                             | 说明          |
| ------------ | ------------------------------------------------- | ----------- |
| **核心应用**     | mall-gateway, mall-admin, mall-auth, mall-monitor | 业务核心        |
| **基础中间件**    | MySQL, Redis, Nacos, Nginx                        | 必需的基础设施     |
| **CI/CD 触发** | 无（由 GitHub Actions 远程构建）                          | 服务器只负责拉取和运行 |

#### 扩展服务器（阿里云 2核4G） — 公网 IP：`8.134.65.121`

| 角色        | 部署的服务                            | 说明       |
| --------- | -------------------------------- | -------- |
| **重资源服务** | Elasticsearch, MongoDB, RabbitMQ | 吃内存大户    |
| **日志体系**  | Logstash, Kibana                 | ELK 日志栈  |
| **可选应用**  | mall-search, mall-portal         | 也可放在主服务器 |

### 知识点：为什么要把 ES/Mongo/RabbitMQ 放到另一台机器？

**是什么？**
Elasticsearch 默认 JVM 堆内存 **1GB 起**，MongoDB 和 RabbitMQ 也各自需要几百 MB。

**为什么分离？**

* **内存隔离**：ES 发生 GC（垃圾回收）停顿不会影响核心业务

* **避免 OOM**：4GB 机器同时跑 MySQL(\~500MB) + Redis(\~100MB) + Nacos(\~512MB) + 6 个 Java 应用(\~每个256MB) ≈ **2.5GB+**，再塞 ES 就危险了

* **故障域隔离**：一台挂了不影响另一台

**追问：只有一台服务器怎么办？**
可以！但需要：

1. 给 ES 设置极低的 JVM 内存（`-Xms256m -Xmx512m`）
2. 不启用 RabbitMQ 管理界面（省 \~200MB）
3. 预期会有较慢的搜索响应

***

### 1.5 部署阶段总览

```
阶段1: 基础骨架 ████████████████████████░░░░░░░░  完成!
  ├── MySQL + Redis + Nacos（基础设施）
  ├── mall-gateway（API网关）
  ├── mall-admin（后台管理）
  └── mall-auth（认证中心）
         │
         ▼
阶段2: 商品搜索 ████████████████████████████░░░░░  进行中...
  ├── Elasticsearch（搜索引擎）
  └── mall-search（搜索服务）
         │
         ▼
阶段3: 前台商城 ██████████████████████████████░░░  待开始
  ├── MongoDB（NoSQL）
  ├── RabbitMQ（消息队列）
  └── mall-portal（前台门户）
         │
         ▼
阶段4: 日志监控 ████████████████████████████████░  待开始
  ├── Logstash（日志收集）
  ├── Kibana（日志可视化）
  └── mall-monitor（Spring Boot Admin）
         │
         ▼
阶段5: 前端部署
  └── mall-admin-web → Nginx 静态托管
```

每个阶段都是**可独立运行的完整子系统**，你可以随时停在任意阶段。

***

### 1.6 内存预估表

以下为**单个容器**的内存占用估算（基于默认配置）：

| 服务            | 镜像                         | 预估内存    | 所在阶段 | 服务器   |
| ------------- | -------------------------- | ------- | ---- | ----- |
| MySQL         | mysql:5.7                  | \~400MB | 阶段1  | 主服务器  |
| Redis         | redis:7                    | \~50MB  | 阶段1  | 主服务器  |
| Nacos         | nacos/nacos-server:v2.1.0  | \~512MB | 阶段1  | 主服务器  |
| Nginx         | nginx:1.22                 | \~20MB  | 阶段1  | 主服务器  |
| mall-gateway  | openjdk:17                 | \~300MB | 阶段1  | 主服务器  |
| mall-admin    | openjdk:17                 | \~350MB | 阶段1  | 主服务器  |
| mall-auth     | openjdk:17                 | \~250MB | 阶段1  | 主服务器  |
| mall-monitor  | openjdk:17                 | \~300MB | 阶段4  | 主服务器  |
| Elasticsearch | elasticsearch:7.17.3       | \~1GB+  | 阶段2  | 扩展服务器 |
| mall-search   | openjdk:17                 | \~350MB | 阶段2  | 扩展服务器 |
| MongoDB       | mongo:4                    | \~200MB | 阶段3  | 扩展服务器 |
| RabbitMQ      | rabbitmq:3.9.11-management | \~400MB | 阶段3  | 扩展服务器 |
| mall-portal   | openjdk:17                 | \~350MB | 阶段3  | 扩展服务器 |
| Logstash      | logstash:7.17.3            | \~500MB | 阶段4  | 扩展服务器 |
| Kibana        | kibana:7.17.3              | \~300MB | 阶段4  | 扩展服务器 |

**各阶段总内存估算：**

| 阶段        | 主服务器    | 扩展服务器   | 合计              |
| --------- | ------- | ------- | --------------- |
| 阶段1（基础骨架） | \~1.9GB | 0       | \~1.9GB ✅ 4GB够用 |
| 阶段2（+搜索）  | \~1.9GB | \~1.4GB | \~3.3GB         |
| 阶段3（+门户）  | \~1.9GB | \~2.3GB | ⚠️ 接近上限         |
| 阶段4（+监控）  | \~2.2GB | \~2.5GB | ⚠️ 需要调优         |

> ⚠️ **注意**：以上为估算值，实际占用取决于请求数据量和 JVM 配置。如果遇到 OOM，参见 [10.4 内存不足(OOM)应对](#104-内存不足oom应对)。

***

## 第2章：环境准备（两台服务器都要做）

> 本章操作需要在**两台服务器上都执行一次**。如果你只有一台服务器，只需执行一次即可。

### 2.1 重装系统建议

**强烈建议**：在开始之前，将云服务器**重装为纯净的操作系统**。

**为什么？**

| 原因    | 说明                                |
| ----- | --------------------------------- |
| 干净的环境 | 避免残留的旧版 Java、Maven、Node.js 导致版本冲突 |
| 安全性   | 清除可能存在的后门或错误配置                    |
| 可复现性  | 确保本文档每一步都能精确复现                    |
| 节省空间  | 卸载预装的无用软件释放磁盘空间                   |

**推荐系统选择：**

| 系统                   | 推荐度   | 说明                                        |
| -------------------- | ----- | ----------------------------------------- |
| **Ubuntu 22.04 LTS** | ⭐⭐⭐⭐⭐ | 包管理器 `apt` 友好，社区资料最多，Docker 安装最简单         |
| CentOS 7.9           | ⭐⭐⭐⭐  | 企业常用，但 2024 年 6 月已停止维护（EOL），建议新项目用 Ubuntu |
| Debian 12            | ⭐⭐⭐⭐  | 比 Ubuntu 更轻量，但部分软件源更新稍慢                   |
| Rocky Linux 9        | ⭐⭐⭐   | CentOS 的精神续作，兼容性好                         |

> 💡 **本文档以 Ubuntu 22.04 LTS 为主要示例**，同时提供 CentOS 7.9 的命令作为备选。

**重装步骤（以腾讯云为例）：**

1. 登录腾讯云控制台 → 云服务器列表
2. 点击对应实例的「更多」→ 「重装系统」
3. 选择 **Ubuntu 22.04 LTS 64位**
4. 设置 root 密码（**记住这个密码！**）
5. 确认重装（数据会全部丢失，提前备份重要数据）

***

### 2.2 安装 Docker

#### 方式一：Ubuntu 22.04（推荐）

```bash
# 1. 更新包索引
sudo apt-get update

# 2. 安装必要的依赖包（让 apt 能通过 HTTPS 使用仓库）
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# 3. 添加 Docker 官方 GPG 密钥
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# 4. 添加 Docker 仓库源
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 5. 安装 Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 6. 将当前用户加入 docker 组（免 sudo 使用 docker）
sudo usermod -aG docker $USER

# 7. 使组权限生效（或者重新登录）
newgrp docker
```

#### 方式二：CentOS 7.9

```bash
# 1. 安装必要工具
sudo yum install -y yum-utils

# 2. 添加 Docker 仓库
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# 3. 安装 Docker Engine
sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 4. 启动 Docker 并设置开机自启
sudo systemctl start docker
sudo systemctl enable docker

# 5. 将当前用户加入 docker 组
sudo usermod -aG docker $USER
```

### 知识点：为什么不用 `apt install docker` 或 `yum install docker`？

**是什么？**
系统自带仓库里的 Docker 包通常叫 `docker.io`（Ubuntu）或 `docker`（CentOS），版本非常旧。

**为什么用官方源？**

* **版本新**：官方源提供最新稳定版，包含最新安全补丁

* **buildx 支持**：新版 Docker 内置 buildx，支持多平台构建和缓存

* **compose 插件**：`docker compose`（V2，子命令形式）比独立的 `docker-compose`（V1）更快更稳定

**追问：docker compose V1 和 V2 有什么区别？**

* V1：独立安装的 Python 程序，命令是 `docker-compose up`

* V2：Go 编写的插件，集成在 Docker 中，命令是 `docker compose up`（注意没有连字符）

* **本文档统一使用 V2 语法**（`docker compose`）

***

### 2.3 安装 Docker Compose

如果你使用上面的方式一或方式二安装 Docker，**Docker Compose 已经作为插件自动安装好了**。

验证一下：

```bash
docker compose version
```

应该输出类似：

```
Docker Compose version v2.x.x
```

如果提示找不到命令，手动安装：

```bash
# 下载 Docker Compose 二进制文件（最新稳定版）
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" -o /usr/local/bin/docker-compose

# 赋予执行权限
sudo chmod +x /usr/local/bin/docker-compose

# 验证
docker-compose --version
```

***

### 2.4 安装 Git

```bash
# Ubuntu
sudo apt-get install -y git

# CentOS
sudo yum install -y git

# 验证
git --version
```

### 知识点：为什么服务器需要 Git？

**是什么？**
Git 是版本控制系统。我们在服务器上用它来**克隆项目代码**（包含 docker-compose 配置文件、Nginx 配置等）。

**为什么不在服务器上写代码？**

* **单一职责**：服务器只管「运行」，代码开发和构建交给 GitHub Actions

* **配置同步**：修改了 docker-compose 配置后 push 到 GitHub，服务器 `git pull` 即可同步

* **审计追踪**：所有配置变更都有 git 历史记录

***

### 2.5 验证安装

在两台服务器上分别执行以下命令，确认所有工具就绪：

```bash
echo "=== 系统信息 ==="
uname -a
free -h
df -h /

echo ""
echo "=== Docker 版本 ==="
docker --version

echo ""
echo "=== Docker Compose 版本 ==="
docker compose version

echo ""
echo "=== Git 版本 ==="
git --version

echo ""
echo "=== Docker 是否正常运行 ==="
docker info | head -5

echo ""
echo "=== 测试 Docker（运行 hello-world） ==="
docker run --rm hello-world
```

预期输出关键项：

* `docker --version` → 显示版本号（如 `27.x.x`）

* `docker compose version` → 显示版本号（如 `v2.x.x`）

* `docker run hello-world` → 输出 "Hello from Docker!"

如果 `hello-world` 正常输出了欢迎信息，说明 Docker 安装完全正常！🎉

***

### 2.6 防火墙/安全组端口开放指南

### 知识点：防火墙 vs 安全组 — 两道防线

**是什么？**

* **安全组**：云厂商层面的虚拟防火墙（在流量到达服务器**之前**拦截）

* **防火墙（iptables/firewalld/ufw）**：操作系统层面的防火墙（在服务器**内部**拦截）

**为什么两层都要配？**

* 安全组是第一道防线，防止恶意流量进入

* 操作系统防火墙是第二道防线，即使安全组误放行了，OS 层还能挡住

* **最佳实践：安全组放开必要端口 + OS 防火墙也放开对应端口**

#### 必须开放的端口汇总

| 端口            | 服务                  | 开放对象            | 说明                 |
| ------------- | ------------------- | --------------- | ------------------ |
| **22**        | SSH                 | 你的 IP           | 服务器管理入口，**限制 IP！** |
| **80**        | Nginx               | 所有 IP (0.0.0.0) | HTTP 访问入口          |
| **443**       | Nginx (HTTPS)       | 所有 IP           | HTTPS（后续加 SSL 时需要） |
| **3306**      | MySQL               | **仅内网/特定IP**    | ⚠️ **绝对不要对公网开放！**  |
| **6379**      | Redis               | **仅内网**         | ⚠️ 无密码时极度危险        |
| **8848**      | Nacos               | **仅内网/你的IP**    | 配置中心含敏感信息          |
| **8201**      | mall-gateway        | **仅内网/你的IP**    | API 网关             |
| **8080**      | mall-admin          | **仅内网/你的IP**    | 后台管理               |
| **8401**      | mall-auth           | **仅内网/你的IP**    | 认证中心               |
| **8085**      | mall-portal         | **仅内网/你的IP**    | 前台商城               |
| **8081**      | mall-search         | **仅内网/你的IP**    | 搜索服务               |
| **8101**      | mall-monitor        | **仅内网/你的IP**    | 监控中心               |
| **9200**      | Elasticsearch       | **仅内网**         | ES REST API        |
| **9300**      | Elasticsearch       | **仅内网**         | ES 节点通信            |
| **27017**     | MongoDB             | **仅内网**         | Mongo 服务端口         |
| **5672**      | RabbitMQ            | **仅内网**         | AMQP 端口            |
| **15672**     | RabbitMQ Management | **仅内网/你的IP**    | Web 管理界面           |
| **4560-4563** | Logstash            | **仅内网**         | 日志收集 TCP 端口        |
| **5601**      | Kibana              | **仅内网/你的IP**    | 日志可视化 Web          |

#### 云厂商安全组配置步骤

**腾讯云：**

1. 控制台 → 云服务器 → 安全组
2. 选择实例绑定的安全组 → 编辑规则
3. 添加入站规则（参考上表）

**阿里云：**

1. 控制台 → ECS → 安全组
2. 配置规则 → 入方向 → 手动添加

> ⚠️ **安全警告**：MySQL(3306)、Redis(6379)、MongoDB(27017)、RabbitMQ(5672) 这些端口**绝不能对 0.0.0.0/0（全网）开放**！曾有无数服务器因这些端口暴露被勒索病毒感染。要么限制为特定 IP，要么不开放（Docker 内部网络通信不需要对外开端口）。

#### 操作系统防火墙配置

```bash
# Ubuntu (ufw)
# 先检查状态
sudo ufw status

# 如果是 inactive，启用它
sudo ufw allow 22/tcp      # SSH
sudo ufw allow 80/tcp      # HTTP
sudo ufw allow 443/tcp     # HTTPS
sudo ufw enable

# 允许 Docker 修改防火墙规则（否则容器端口可能无法映射）
# 编辑 /etc/default/ufw，确保 DEFAULT_FORWARD_POLICY="ACCEPT"

# CentOS (firewalld)
sudo systemctl start firewalld
sudo systemctl enable firewalld
sudo firewall-cmd --permanent --add-port=22/tcp
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --reload
```

***

### 2.7 Hosts 配置（可选但推荐）

当两台服务器需要互相访问时，使用域名比记 IP 方便得多。

**在主服务器上编辑** **`/etc/hosts`：**

```bash
sudo vim /etc/hosts
```

添加以下内容（**将 IP 替换为你实际的扩展服务器 IP**）：

```
${EXT_SERVER_IP}  ext-server
```

**在扩展服务器上编辑** **`/etc/hosts`：**

```bash
sudo vim /etc/hosts
```

添加：

```
${MAIN_SERVER_IP}  main-server
```

这样你就可以用 `ext-server` 和 `main-server` 代替 IP 地址了。

***

## 第3章：基础设施准备

> 本章的操作主要在你的**本地电脑**和 **GitHub** 上完成，服务器上的操作在第 3.5 节之后。

### 3.1 Fork 项目到自己的 GitHub

### 知识点：为什么 Fork 而不是直接 Clone 原项目？

**是什么？**
Fork = 在你的 GitHub 账号下创建一个原项目的副本，你可以自由修改而不影响原作者。

**为什么 Fork？**

* **CI/CD 权限**：你需要在自己的仓库上配置 GitHub Actions Secrets（ACR 密码等），无法在别人的仓库上操作

* **自定义修改**：你可能需要调整配置、修复 bug、添加功能

* **保持同步**：可以通过 upstream 同步原作者的更新

**操作步骤：**

1. 打开浏览器访问：<https://github.com/macrozheng/mall-swarm>
2. 点击右上角的 **「Fork」** 按钮
3. 选择 Fork 到你的账号下
4. Fork 完成后，你的仓库地址类似：`https://github.com/${YOUR_GITHUB_USERNAME}/mall-swarm`

**将 Fork 后的仓库 Clone 到本地电脑：**

```bash
git clone https://github.com/${YOUR_GITHUB_USERNAME}/mall-swarm.git
cd mall-swarm
```

**添加上游仓库（用于同步原作者更新）：**

```bash
git remote add upstream https://github.com/macrozheng/mall-swarm.git
git remote -v
# 输出应显示:
# origin    https://github.com/YOU/mall-swarm.git (fetch)
# upstream  https://github.com/macrozheng/mall-swarm.git (fetch)
```

以后同步上游更新的命令：

```bash
git fetch upstream
git merge upstream/master
git push origin master
```

***

### 3.2 创建阿里云 ACR 镜像仓库

### 知识点：什么是 ACR？为什么不用 Docker Hub？

**是什么？**
ACR（Alibaba Container Registry）= 阿里云提供的容器镜像仓库服务，类似于 GitHub 对代码的作用——存放 Docker 镜像。

**为什么选 ACR 而非 Docker Hub？**

| 特性     | Docker Hub | 阿里云 ACR 个人实例 |
| ------ | ---------- | ------------ |
| 国内拉取速度 | ❌ 极慢（经常超时） | ✅ 阿里云内网极速    |
| 免费额度   | 1 个私有仓库    | ✅ 个人实例免费     |
| 并发构建   | 受限         | ✅ 高并发        |
| 与国内服务器 | 跨国网络       | ✅ 同区域网络      |

**创建步骤（详细图文描述）：**

1. **登录阿里云控制台**

   * 访问 <https://www.aliyun.com> → 登录你的阿里云账号

   * 搜索「**容器镜像服务**」或「**ACR**」

2. **开通服务（首次使用）**

   * 点击「立即开通」→ 选择「**个人实例**」（免费）

   * 选择地域：**尽量与你的扩展服务器同地域**（如华南1-深圳）

   * 设置仓库名称：如 `mall-swarm-registry`

3. **创建命名空间（Namespace）**

   * 左侧菜单 → 「命名空间」→ 「创建命名空间」

   * 名称填：`mall`

   * 自动创建仓库：开启（方便后续操作）

4. **创建镜像仓库**

   * 左侧菜单 → 「镜像仓库」→ 「创建镜像仓库」

   * 命名空间：选择刚创建的 `mall`

   * 仓库名称：`mall-gateway`

   * 摘要：`mall-swarm API网关服务`

   * 仓库类型：**私有**

   * 代码源：**本地仓库**（我们用 GitHub Actions 推送）

   * 点击「确定」

5. **重复创建其他仓库**
   按照同样方式创建以下仓库（都在 `mall` 命名空间下）：

   | 仓库名称           | 用途     |
   | -------------- | ------ |
   | `mall-gateway` | API 网关 |
   | `mall-admin`   | 后台管理   |
   | `mall-auth`    | 认证中心   |
   | `mall-portal`  | 前台商城   |
   | `mall-search`  | 商品搜索   |
   | `mall-monitor` | 监控中心   |

6. **获取登录凭证**

   * 左侧菜单 → 「访问凭证」→ 设置固定密码（或使用临时密码）

   * **记住**：用户名格式通常是 `<阿里云账号ID>`，密码是你设置的固定密码

   * 这个后面要配置到 GitHub Secrets 中

7. **确认镜像仓库地址**

   * 进入某个刚创建的仓库 → 「基本信息」页

   * 你会看到类似这样的地址：

   ```
   ${ACR_REGISTRY}.cn-${REGION}.aliyuncs.com/mall/mall-gateway
   ```

   * `${ACR_REGISTRY}` 是你的实例名称

   * `${REGION}` 是地域代码（如 `shenzhen`、`hangzhou`）

***

### 3.3 获取 ACR 凭证并配置 GitHub Secrets

### 知识点：什么是 GitHub Secrets？为什么需要它？

**是什么？**
GitHub Secrets 是 GitHub 仓库级别的加密变量存储，用于在 GitHub Actions 中安全地使用敏感信息（密码、Token 等）。

**为什么需要？**

* **安全性**：密码明文写在 YAML 工作流文件中会被所有人看到（即使私有仓库也有风险）

* **隔离性**：开发者看不到实际值，只能引用变量名

* **可轮换**：密码泄露时只需更新 Secret，不用改代码

**配置步骤：**

1. 打开你 Fork 后的仓库：`https://github.com/${YOUR_GITHUB_USERNAME}/mall-swarm`

2. 点击 **Settings** → 左侧菜单 **Secrets and variables** → **Actions**

3. 点击 **New repository secret**，依次添加以下 Secret：

   | Secret 名称       | 值             | 说明                               |
   | --------------- | ------------- | -------------------------------- |
   | `ACR_USERNAME`  | 你的阿里云账号ID     | ACR 登录用户名                        |
   | `ACR_PASSWORD`  | 你设置的 ACR 固定密码 | ACR 登录密码                         |
   | `ACR_REGISTRY`  | 你的 ACR 实例地址   | 如 `xxx.cn-shenzhen.aliyuncs.com` |
   | `ACR_NAMESPACE` | `mall`        | 命名空间                             |
   | `ACR_REGION`    | 地域代码          | 如 `cn-shenzhen`                  |

4. 每个添加完成后点击 **Add secret**

> 💡 **验证方法**：添加完后，Secrets 列表中只会显示名称（如 `ACR_PASSWORD`），值被隐藏。这是正常的——如果你能看到值，别人也能看到！

***

### 3.4 编写 GitHub Actions 工作流文件

### 知识点：GitHub Actions 是什么？为什么用它来做 CI/CD？

**是什么？**
GitHub Actions 是 GitHub 提供的自动化工作流平台。当你的代码发生变更（push / PR）时，它可以自动执行一系列任务：编译、测试、构建镜像、推送镜像...

**为什么用它而不是在服务器上构建？**

* **服务器零负担**：不需要在服务器装 JDK、Maven、Node.js，节省 CPU 和内存

* **标准化构建**：每次构建环境完全一致（Ubuntu + JDK 17 + Maven）

* **并行构建**：GitHub 提供 2\~4 核 CPU 的 runner，编译速度通常快于低配服务器

* **免费额度**：公开仓库无限时长，私有仓库每月 2000 分钟免费

* **缓存加速**：Maven 依赖和 Docker layer cache 都可以缓存，二次构建飞快

**创建工作流文件：**

在项目根目录创建 `.github/workflows/docker-build.yml`：

```yaml
# ============================================================
#  mall-swarm CI/CD 工作流 — 自动构建 Docker 镜像并推送到 ACR
#  触发条件：推送到 main/master 分支，或手动触发
# ============================================================

name: Build and Push Docker Images

on:
  push:
    branches: [ main, master ]
    tags: [ 'v*' ]
  workflow_dispatch:  # 支持手动触发（在 Actions 页面点击 Run workflow）

env:
  # 镜像标签：使用 git commit 的短 hash 作为标签，保证唯一性
  IMAGE_TAG: ${{ github.sha }}
  # 基础镜像仓库地址
  REGISTRY: ${{ secrets.ACR_REGISTRY }}
  NAMESPACE: ${{ secrets.ACR_NAMESPACE }}

jobs:
  build-and-push:
    name: 构建并推送镜像
    runs-on: ubuntu-latest
    timeout-minutes: 30  # 超时时间

    steps:
      # -------------------------------------------------------
      # Step 1: 检出代码
      # -------------------------------------------------------
      - name: Checkout code
        uses: actions/checkout@v4

      # -------------------------------------------------------
      # Step 2: 设置 JDK  环境
      # -------------------------------------------------------
      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'  # Eclipse Temurin（推荐，开源免费）
          cache: maven             # 缓存 Maven 依赖，加速后续构建

      # -------------------------------------------------------
      # Step 3: Maven 编译打包（跳过测试以加速）
      # -------------------------------------------------------
      - name: Build with Maven
        run: |
          mvn clean package -DskipTests -pl \
            !mall-demo \
            -am

      # -------------------------------------------------------
      # Step 4: 设置 Docker Buildx（多平台构建 + 缓存）
      # -------------------------------------------------------
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      # -------------------------------------------------------
      # Step 5: 登录阿里云 ACR
      # -------------------------------------------------------
      - name: Login to ACR
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ secrets.ACR_USERNAME }}
          password: ${{ secrets.ACR_PASSWORD }}

      # -------------------------------------------------------
      # Step 6: 定义要构建的服务列表
      # -------------------------------------------------------
      - name: Define services
        id: services
        run: |
          echo "services=mall-gateway,mall-admin,mall-auth,mall-portal,mall-search,mall-monitor" >> $GITHUB_OUTPUT

      # -------------------------------------------------------
      # Step 7: 构建并推送每个服务的镜像
      # -------------------------------------------------------
      - name: Build and push images
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./Dockerfile.app
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.NAMESPACE }}/mall-gateway:${{ env.IMAGE_TAG }}
            ${{ env.REGISTRY }}/${{ env.NAMESPACE }}/mall-gateway:latest
            ${{ env.REGISTRY }}/${{ env.NAMESPACE }}/mall-admin:${{ env.IMAGE_TAG }}
            ${{ env.REGISTRY }}/${{ env.NAMESPACE }}/mall-admin:latest
            ${{ env.REGISTRY }}/${{ env.NAMESPACE }}/mall-auth:${{ env.IMAGE_TAG }}
            ${{ env.REGISTRY }}/${{ env.NAMESPACE }}/mall-auth:latest
            ${{ env.REGISTRY }}/${{ env.NAMESPACE }}/mall-portal:${{ env.IMAGE_TAG }}
            ${{ env.REGISTRY }}/${{ env.NAMESPACE }}/mall-portal:latest
            ${{ env.REGISTRY }}/${{ env.NAMESPACE }}/mall-search:${{ env.IMAGE_TAG }}
            ${{ env.REGISTRY }}/${{ env.NAMESPACE }}/mall-search:latest
            ${{ env.REGISTRY }}/${{ env.NAMESPACE }}/mall-monitor:${{ env.IMAGE_TAG }}
            ${{ env.REGISTRY }}/${{ env.NAMESPACE }}/mall-monitor:latest
          build-args: |
            APP_NAME=mall-gateway
          cache-from: type=gha
          cache-to: type=gha,mode=max

      # -------------------------------------------------------
      # Step 8: 构建其他服务的镜像（逐个构建以支持不同的 JAR 路径）
      # 注意：由于各模块 JAR 在不同目录，这里采用矩阵策略
      # -------------------------------------------------------

      - name: Build mall-admin image
        uses: docker/build-push-action@v5
        with:
          context: ./mall-admin
          file: ./Dockerfile.module
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.NAMESPACE }}/mall-admin:${{ env.IMAGE_TAG }}
            ${{ env.REGISTRY }}/${{ env.NAMESPACE }}/mall-admin:latest
          build-args: |
            JAR_FILE=target/mall-admin-1.0-SNAPSHOT.jar
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Build mall-auth image
        uses: docker/build-push-action@v5
        with:
          context: ./mall-auth
          file: ./Dockerfile.module
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.NAMESPACE }}/mall-auth:${{ env.IMAGE_TAG }}
            ${{ env.REGISTRY }}/${{ env.NAMESPACE }}/mall-auth:latest
          build-args: |
            JAR_FILE=target/mall-auth-1.0-SNAPSHOT.jar
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Build mall-gateway image
        uses: docker/build-push-action@v5
        with:
          context: ./mall-gateway
          file: ./Dockerfile.module
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.NAMESPACE }}/mall-gateway:${{ env.IMAGE_TAG }}
            ${{ env.REGISTRY }}/${{ env.NAMESPACE }}/mall-gateway:latest
          build-args: |
            JAR_FILE=target/mall-gateway-1.0-SNAPSHOT.jar
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Build mall-portal image
        uses: docker/build-push-action@v5
        with:
          context: ./mall-portal
          file: ./Dockerfile.module
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.NAMESPACE }}/mall-portal:${{ env.IMAGE_TAG }}
            ${{ env.REGISTRY }}/${{ env.NAMESPACE }}/mall-portal:latest
          build-args: |
            JAR_FILE=target/mall-portal-1.0-SNAPSHOT.jar
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Build mall-search image
        uses: docker/build-push-action@v5
        with:
          context: ./mall-search
          file: ./Dockerfile.module
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.NAMESPACE }}/mall-search:${{ env.IMAGE_TAG }}
            ${{ env.REGISTRY }}/${{ env.NAMESPACE }}/mall-search:latest
          build-args: |
            JAR_FILE=target/mall-search-1.0-SNAPSHOT.jar
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Build mall-monitor image
        uses: docker/build-push-action@v5
        with:
          context: ./mall-monitor
          file: ./Dockerfile.module
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.NAMESPACE }}/mall-monitor:${{ env.IMAGE_TAG }}
            ${{ env.REGISTRY }}/${{ env.NAMESPACE }}/mall-monitor:latest
          build-args: |
            JAR_FILE=target/mall-monitor-1.0-SNAPSHOT.jar
          cache-from: type=gha
          cache-to: type=gha,mode=max

      # -------------------------------------------------------
      # Step 9: 构建摘要通知
      # -------------------------------------------------------
      - name: Image build summary
        if: always()
        run: |
          echo "### 🐳 镜像构建结果" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "| 服务 | 镜像地址 |" >> $GITHUB_STEP_SUMMARY
          echo "|------|----------|" >> $GITHUB_STEP_SUMMARY
          echo "| mall-gateway | \`${{ env.REGISTRY }}/${{ env.NAMESPACE }}/mall-gateway:${{ env.IMAGE_TAG }}\` |" >> $GITHUB_STEP_SUMMARY
          echo "| mall-admin | \`${{ env.REGISTRY }}/${{ env.NAMESPACE }}/mall-admin:${{ env.IMAGE_TAG }}\` |" >> $GITHUB_STEP_SUMMARY
          echo "| mall-auth | \`${{ env.REGISTRY }}/${{ env.NAMESPACE }}/mall-auth:${{ env.IMAGE_TAG }}\` |" >> $GITHUB_STEP_SUMMARY
          echo "| mall-portal | \`${{ env.REGISTRY }}/${{ env.NAMESPACE }}/mall-portal:${{ env.IMAGE_TAG }}\` |" >> $GITHUB_STEP_SUMMARY
          echo "| mall-search | \`${{ env.REGISTRY }}/${{ env.NAMESPACE }}/mall-search:${{ env.IMAGE_TAG }}\` |" >> $GITHUB_STEP_SUMMARY
          echo "| mall-monitor | \`${{ env.REGISTRY }}/${{ env.NAMESPACE }}/mall-monitor:${{ env.IMAGE_TAG }}\` |" >> $GITHUB_STEP_SUMMARY
```

> ⚠️ **关于上面工作流的说明**：由于 mall-swarm 是多模块 Maven 项目，每个子模块的 JAR 包在不同目录下。上述工作流采用了**逐模块构建**的方式，每个服务使用自己的 `context`（构建上下文目录）。这种方式虽然步骤较多，但清晰可控。
>
> 如果你希望更精简的方式，可以在根目录先执行 `mvn clean package -DskipTests` 将所有 JAR 打好，然后用统一的 Dockerfile 配合 COPY 指令从不同位置复制 JAR。

还需要创建两个 Dockerfile 模板文件：

**项目根目录** **`Dockerfile.module`（通用模块 Dockerfile）：**

```dockerfile
# ============================================================
#  mall-swarm 应用服务 Dockerfile
#  基于项目 pom.xml 中 docker-maven-plugin 配置转换而来
#  用法: docker build --build-arg JAR_FILE=xxx.jar -t xxx .
# ============================================================

# 第一阶段：构建（利用 Maven 已编译好的 JAR）
FROM openjdk:17-jdk-slim as builder
WORKDIR /app
ARG JAR_FILE
COPY ${JAR_FILE} app.jar

# 第二阶段：运行（最小化镜像体积）
FROM openjdk:17-jdk-slim
MAINTAINER macrozheng

# 创建非 root 用户运行应用（安全最佳实践）
RUN groupadd -r appuser && useradd -r -g appuser appuser

# 设置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# JVM 参数优化
ENV JAVA_OPTS="-Xms256m -Xmx512m -XX:+UseG1GC -XX:MaxGCPauseMillis=200"

WORKDIR /app
COPY --from=builder /app/app.jar app.jar

# 切换到非 root 用户
USER appuser

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# 启动命令（prod 配置由 Nacos 远程配置提供）
ENTRYPOINT ["sh", "-c", "java ${JAVA_OPTS} -Dspring.profiles.active=prod -jar app.jar"]
```

### 知识点：为什么用多阶段构建（Multi-stage Build）？

**是什么？**
Docker 多阶段构建允许在一个 Dockerfile 中定义多个 `FROM` 指令，前一阶段的产物可以复制到后一阶段，最终镜像只保留最后一层。

**为什么？**

* **镜像体积小**：最终镜像只包含 JAR + JRE，不包含 Maven、源码等构建工具

  * 不用多阶段：`openjdk:17` (\~471MB) + JAR (\~80MB) ≈ **550MB**

  * 多阶段后：`openjdk:17-jdk-slim` (\~207MB) + JAR (\~80MB) ≈ **290MB**

* **安全性**：最终镜像不含构建工具，攻击面更小

* **构建缓存友好**：JAR 不变时，第二阶段直接命中缓存

**追问：为什么用** **`jdk-slim`** **而不是** **`jre`？**
Spring Boot Admin 等监控工具可能需要 JDK 中的某些工具。而且 OpenJDK 从 11 开始不再单独发布 JRE 镜像，`jdk-slim` 已经足够精简。

***

### 3.5 在服务器上克隆项目

现在回到**两台服务器**上，执行以下操作：

**主服务器：**

```bash
# 创建项目目录
sudo mkdir -p /data/projects
sudo chown $USER:$USER /data/projects
cd /data/projects

# 克隆你自己 Fork 的仓库（替换为你的 GitHub 用户名）
git clone https://github.com/${YOUR_GITHUB_USERNAME}/mall-swarm.git
cd mall-swarm

# 查看目录结构
ls -la
```

**扩展服务器：**

```bash
# 同样操作
sudo mkdir -p /data/projects
sudo chown $USER:$USER /data/projects
cd /data/projects
git clone https://github.com/${YOUR_GITHUB_USERNAME}/mall-swarm.git
cd mall-swarm
```

> 💡 **为什么克隆到** **`/data/projects`** **而不是** **`/home`？**
>
> * `/data` 通常是数据盘挂载点（与系统盘分离）
>
> * 即使系统盘满了，数据盘不受影响
>
> * 符合 Linux FHS（文件系统层次标准）惯例

***

### 3.6 准备目录结构和 .env 文件模板

**在主服务器上创建所需的数据目录：**

```bash
# ===== 基础设施数据目录 =====
sudo mkdir -p /mydata/mysql/data/db
sudo mkdir -p /mydata/mysql/data/conf
sudo mkdir -p /mydata/mysql/log

sudo mkdir -p /mydata/redis/data

sudo mkdir -p /mydata/nacos/logs

sudo mkdir -p /mydata/nginx/conf
sudo mkdir -p /mydata/nginx/html
sudo mkdir -p /mydata/nginx/log

# ===== 应用服务日志目录 =====
sudo mkdir -p /mydata/app/mall-gateway/logs
sudo mkdir -p /mydata/app/mall-admin/logs
sudo mkdir -p /mydata/app/mall-auth/logs
sudo mkdir -p /mydata/app/mall-monitor/logs

# ===== 设置权限 =====
sudo chown -R $USER:$USER /mydata
```

**在扩展服务器上创建数据目录：**

```bash
# ===== 基础设施数据目录 =====
sudo mkdir -p /mydata/elasticsearch/plugins
sudo mkdir -p /mydata/elasticsearch/data
sudo mkdir -p /mydata/mongo/db
sudo mkdir -p /mydata/rabbitmq/data
sudo mkdir -p /mydata/rabbitmq/log
sudo mkdir -p /mydata/logstash
sudo mkdir -p /mydata/kibana

# ===== 应用服务日志目录 =====
sudo mkdir -p /mydata/app/mall-search/logs
sudo mkdir -p /mydata/app/mall-portal/logs

# ===== 设置权限 =====
sudo chown -R $USER:$USER /mydata

# Elasticsearch 需要特殊权限（ES 不允许 root 运行）
sudo sysctl -w vm.max_map_count=262144
# 永久生效：写入 /etc/sysctl.conf
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

### 知识点：为什么 ES 需要 vm.max\_map\_count？

**是什么？**
`vm.max_map_count` 是 Linux 内核参数，限制一个进程可以拥有的最大内存映射区域数。

**为什么 ES 需要调高？**
Elasticsearch 使用 **Lucene** 引擎，Lucene 大量使用 `mmap`（内存映射文件）来操作索引文件。默认值 `65530` 对 ES 来说太低，会导致 ES 启动时报错：

```
max virtual memory areas vm.max_map_count [65530] is too low
```

ES 要求至少 **262144**。

**追问：这会影响系统稳定性吗？**
不会。这只限制了**单个进程**的最大映射数，不是全局限制。除非你有程序存在内存泄漏导致疯狂 mmap，否则不会有问题。

***

**创建 .env 文件（在主服务器的项目目录下）：**

```bash
cd /data/projects/mall-swarm
vim .env
```

完整模板见 [附录 B: .env 文件完整模板](#附录-b-env-文件完整模板)，以下是基础版本：

```bash
# ============================================
#  mall-swarm 部署环境变量配置
#  复制此文件为 .env 并根据实际情况修改
# ============================================

# ----- 通用配置 -----
TIME_ZONE=Asia/Shanghai

# ----- MySQL 配置 -----
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-root}
MYSQL_DATABASE=mall

# ----- Redis 配置 -----
REDIS_PORT=6379

# ----- Nacos 配置 -----
NACOS_PORT=8848

# ----- 阿里云 ACR 配置 -----
ACR_REGISTRY=${ACR_REGISTRY:-your-registry.cn-shenzhen.aliyuncs.com}
ACR_NAMESPACE=mall

# ----- 镜像版本（默认使用 latest，也可指定具体 tag）-----
IMAGE_TAG=latest

# ----- 主服务器 IP（用于跨服务器访问）-----
MAIN_SERVER_IP=${MAIN_SERVER_IP:-your-main-server-ip}
EXT_SERVER_IP=${EXT_SERVER_IP:-your-ext-server-ip}

# ----- Elasticsearch 配置（阶段2使用）-----
ES_JAVA_OPTS=-Xms256m -Xmx512m

# ----- RabbitMQ 配置（阶段3使用）-----
RABBITMQ_DEFAULT_USER=mall
RABBITMQ_DEFAULT_PASS=mall
```

> ⚠️ **重要**：`.env` 文件包含敏感信息（数据库密码等）。确保：
>
> 1. 不要将 `.env` 文件提交到 Git（已在 `.gitignore` 中忽略）
> 2. 不要在生产环境中使用默认密码

***

### 3.7 导入数据库初始化 SQL

**等待 MySQL 容器启动后执行（见第4章启动顺序），也可以预先准备好：**

首先查看 SQL 文件：

```bash
# 在项目中查看 SQL 文件大小
ls -lh document/sql/mall.sql
```

**导入方式一：通过 Docker CLI 导入（推荐）**

```bash
# 在 MySQL 容器启动后执行
docker exec -i mysql mysql -uroot -p${MYSQL_ROOT_PASSWORD} mall < document/sql/mall.sql
```

**导入方式二：进入 MySQL 容器内部导入**

```bash
# 复制 SQL 文件到容器中
docker cp document/sql/mall.sql mysql:/tmp/mall.sql

# 进入容器执行导入
docker exec -it mysql bash
mysql -uroot -proot mall < /tmp/mall.sql
exit
```

**导入方式三：通过 MySQL 客户端远程导入**

```bash
# 如果你的本地电脑装了 mysql 客户端
mysql -h ${MAIN_SERVER_IP} -P 3306 -u root -p mall < document/sql/mall.sql
```

**验证导入结果：**

```bash
# 查看导入了多少张表
docker exec -i mysql mysql -uroot -proot mall -e "SHOW TABLES;" | wc -l

# 应该输出约 90+ 张表（具体数字视版本而定）
```

***

## 第4章：阶段1 — 基础微服务骨架

> **本章目标**：搭建最小的可运行微服务系统，包括基础设施（MySQL、Redis、Nacos）和核心业务服务（Gateway、Admin、Auth）。

### 4.1 本阶段目标和服务列表

**本阶段启动的服务：**

| 类别   | 服务           | 容器名              | 端口   | 所在服务器 |
| ---- | ------------ | ---------------- | ---- | ----- |
| 基础设施 | MySQL 5.7    | `mysql`          | 3306 | 主服务器  |
| 基础设施 | Redis 7      | `redis`          | 6379 | 主服务器  |
| 基础设施 | Nacos v2.1.0 | `nacos-registry` | 8848 | 主服务器  |
| 基础设施 | Nginx 1.22   | `nginx`          | 80   | 主服务器  |
| 应用服务 | mall-gateway | `mall-gateway`   | 8201 | 主服务器  |
| 应用服务 | mall-admin   | `mall-admin`     | 8080 | 主服务器  |
| 应用服务 | mall-auth    | `mall-auth`      | 8401 | 主服务器  |

**本阶段不启动的服务**：mall-search、mall-portal、mall-monitor、ES、MongoDB、RabbitMQ、ELK（后续阶段逐步加入）

### 4.2 编写 docker-compose.base.yml

在主服务器的 `/data/projects/mall-swarm/deploy/` 目录下创建 `docker-compose.base.yml`：

```bash
mkdir -p /data/projects/mall-swarm/deploy
```

**完整内容如下：**

```yaml
# ============================================================
#  mall-swarm 阶段1：基础微服务骨架
#  包含：MySQL + Redis + Nacos + Nginx + Gateway + Admin + Auth
#
#  使用方式：
#    cd /data/projects/mall-swarm/deploy
#    docker compose -f docker-compose.base.yml up -d
# ============================================================

version: '3'

services:

  # ==================== 基础设施 ====================

  mysql:
    image: mysql:5.7
    container_name: mysql
    restart: unless-stopped
    command: mysqld --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD:-root}
      MYSQL_DATABASE: ${MYSQL_DATABASE:-mall}
      TZ: Asia/Shanghai
    ports:
      - "${MYSQL_PORT:-3306}:3306"
    volumes:
      - /mydata/mysql/data/db:/var/lib/mysql
      - /mydata/mysql/data/conf:/etc/mysql/conf.d
      - /mydata/mysql/log:/var/log/mysql
    networks:
      - mall-network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-uroot", "-p${MYSQL_ROOT_PASSWORD:-root}"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 30s

  redis:
    image: redis:7
    container_name: redis
    restart: unless-stopped
    command: redis-server --appendonly yes --maxmemory 128mb --maxmemory-policy allkeys-lru
    ports:
      - "${REDIS_PORT:-6379}:6379"
    volumes:
      - /mydata/redis/data:/data
    networks:
      - mall-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  nacos-registry:
    image: nacos/nacos-server:v2.1.0
    container_name: nacos-registry
    restart: unless-stopped
    environment:
      - MODE=standalone
      - SPRING_DATASOURCE_PLATFORM=mysql
      - MYSQL_SERVICE_HOST=mysql
      - MYSQL_SERVICE_PORT=3306
      - MYSQL_SERVICE_DB_NAME=nacos_config
      - MYSQL_SERVICE_USER=root
      - MYSQL_SERVICE_PASSWORD=${MYSQL_ROOT_PASSWORD:-root}
      - TZ=Asia/Shanghai
      - JVM_XMS=256m
      - JVM_XMX=512m
      - JVM_MN=256m
    ports:
      - "${NACOS_PORT:-8848}:8848"
    volumes:
      - /mydata/nacos/logs:/home/nacos/logs
    depends_on:
      mysql:
        condition: service_healthy
    networks:
      - mall-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8848/nacos/v1/console/health/readiness"]
      interval: 15s
      timeout: 10s
      retries: 10
      start_period: 60s

  nginx:
    image: nginx:1.22
    container_name: nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /mydata/nginx/conf/nginx.conf:/etc/nginx/nginx.conf:ro
      - /mydata/nginx/conf/conf.d:/etc/nginx/conf.d:ro
      - /mydata/nginx/html:/usr/share/nginx/html
      - /mydata/nginx/log:/var/log/nginx
    networks:
      - mall-network
    depends_on:
      - mall-gateway

  # ==================== 应用服务 ====================

  mall-gateway:
    image: ${ACR_REGISTRY:-your-registry.cn-shenzhen.aliyuncs.com}/${ACR_NAMESPACE:-mall}/mall-gateway:${IMAGE_TAG:-latest}
    container_name: mall-gateway
    restart: unless-stopped
    environment:
      - TZ=Asia/Shanghai
    ports:
      - "8201:8201"
    volumes:
      - /mydata/app/mall-gateway/logs:/var/logs
      - /etc/localtime:/etc/localtime
    depends_on:
      nacos-registry:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - mall-network

  mall-admin:
    image: ${ACR_REGISTRY:-your-registry.cn-shenzhen.aliyuncs.com}/${ACR_NAMESPACE:-mall}/mall-admin:${IMAGE_TAG:-latest}
    container_name: mall-admin
    restart: unless-stopped
    environment:
      - TZ=Asia/Shanghai
    ports:
      - "8080:8080"
    volumes:
      - /mydata/app/mall-admin/logs:/var/logs
      - /etc/localtime:/etc/localtime
    depends_on:
      nacos-registry:
        condition: service_healthy
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - mall-network

  mall-auth:
    image: ${ACR_REGISTRY:-your-registry.cn-shenzhen.aliyuncs.com}/${ACR_NAMESPACE:-mall}/mall-auth:${IMAGE_TAG:-latest}
    container_name: mall-auth
    restart: unless-stopped
    environment:
      - TZ=Asia/Shanghai
    ports:
      - "8401:8401"
    volumes:
      - /mydata/app/mall-auth/logs:/var/logs
      - /etc/localtime:/etc/localtime
    depends_on:
      nacos-registry:
        condition: service_healthy
    networks:
      - mall-network

networks:
  mall-network:
    driver: bridge
```

### 知识点：为什么用 `depends_on` + `condition: service_healthy`？

**是什么？**
`depends_on` 控制 Docker Compose 的启动顺序；`condition: service_healthy` 让它不仅等待容器启动，还要等待健康检查通过后才启动下一个服务。

**为什么？**

* **Nacos 必须先于应用服务启动**：应用服务启动时会向 Nacos 注册自己，如果 Nacos 还没就绪，注册就会失败

* **MySQL 必须先于 Nacos 启动**：Nacos 2.x 可以使用 MySQL 存储配置数据（比内置 Derby 更可靠）

* **单纯** **`depends_on`** **不够**：容器启动 ≠ 服务就绪。MySQL 容器启动后可能还在初始化数据库（耗时 10\~30 秒），此时连接会被拒绝

**追问：为什么 Nacos 要用 MySQL 存储？**

* Nacos 默认使用嵌入式 **Derby** 数据库，不适合生产环境（不支持集群、数据不易备份）

* 外接 MySQL 后，配置数据持久化，且可以配合主从/哨兵提高可靠性

* **注意**：首次启动时 Nacos 会自动在 MySQL 中创建 `nacos_config` 库和相关表

***

### 4.3 各服务的 Dockerfile

本项目使用的是 **pom.xml 中的** **`io.fabric8:docker-maven-plugin`** 来构建镜像。我们已经将其转换为独立的 Dockerfile（见 3.4 节的 `Dockerfile.module`）。

**确保 Dockerfile.module 在项目根目录：**

```bash
# 确认文件存在
ls -la /data/projects/mall-swarm/Dockerfile.module
```

如果不存在，创建它（内容见 [3.4 节](#34-编写-github-actions-工作流文件)）。

### 知识点：原项目 docker-maven-plugin vs 我们的 Dockerfile 对比

| 维度     | 原项目 (docker-maven-plugin) | 我们的方案 (Dockerfile + GH Actions)  |
| ------ | ------------------------- | -------------------------------- |
| 构建位置   | 本地或服务器（需要 JDK + Maven）    | GitHub Actions 云端构建              |
| 基础镜像   | `openjdk:17`              | `openjdk:17-jdk-slim`（更小）        |
| JVM 参数 | 无优化                       | `-Xms256m -Xmx512m -XX:+UseG1GC` |
| 安全性    | root 用户运行                 | 非 root 用户（appuser）               |
| 健康检查   | 无                         | 有（curl actuator/health）          |
| 镜像仓库   | 本地 Docker daemon          | 阿里云 ACR（可随时拉取）                   |
| 缓存     | 无                         | GHA Cache + Docker layer cache   |

***

### 4.4 Nacos 配置导入指南

### 知识点：Nacos 配置中心是什么？为什么要用它？

**是什么？**
Nacos 配置中心是一个分布式的配置管理服务。应用启动时从 Nacos 拉取配置，而不是硬编码在 `application.yml` 里。

**为什么？**

* **动态更新**：修改 Nacos 中的配置，应用可以热加载（无需重启）

* **环境隔离**：dev / prod / test 环境用不同的配置（命名空间/分组）

* **敏感信息保护**：数据库密码等放在 Nacos 中，不出现在代码仓库里

* **集中管理**：所有服务的配置在一个地方统一管理

**追问：配置文件到底在哪里？**
mall-swarm 采用 **Bootstrap + Remote Config** 模式：

1. `application-prod.yml`（本地）→ 只告诉应用去哪里找 Nacos
2. Nacos 中的 YAML 文件（远程）→ 包含真正的数据库连接、Redis 地址等详细配置

#### 导入步骤

**第一步：启动 Nacos 容器**

确保 Nacos 已经通过 `docker compose` 启动了（见 4.6 节）。

**第二步：打开 Nacos 控制台**

浏览器访问：`http://${MAIN_SERVER_IP}:8848/nacos`

默认账号密码：`nacos / nacos`

> ⚠️ **首次登录请务必修改默认密码！** 左侧菜单 → 权限控制 → 用户列表 → 点击编辑 → 修改密码

**第三步：创建命名空间（Namespace）**

1. 左侧菜单 → **命名空间** → **新建命名空间**
2. 命名空间 ID：`prod`（或留空自动生成）
3. 命名空间名：`生产环境`
4. 点击确定

**第四步：导入配置文件**

Nacos 支持批量导入 ZIP 包。我们需要先把项目中的配置文件打包：

```bash
# 在本地电脑的项目目录下执行
cd config

# 创建 Nacos 导出格式的目录结构
mkdir -p nacos-export
cp admin/mall-admin-prod.yaml nacos-export/
cp gateway/mall-gateway-prod.yaml nacos-export/
cp auth/mall-auth-prod.yaml nacos-export/ 2>/dev/null || echo "auth config not found in config dir"
cp portal/mall-portal-prod.yaml nacos-export/
cp search/mall-search-prod.yaml nacos-export/
cp demo/mall-demo-prod.yaml nacos-export/

# 查看有哪些配置文件
ls -la nacos-export/
```

**手动逐个导入（推荐初学者使用）：**

在 Nacos 控制台中：

1. 左侧菜单 → **配置管理** → **配置列表**
2. 点击右上角 **「+」** 新建配置
3. 按照以下表格逐个填写：

**Data ID 与 Group 对照表：**

| Data ID                  | Group           | 来源文件                                    | 说明     |
| ------------------------ | --------------- | --------------------------------------- | ------ |
| `mall-gateway-prod.yaml` | `DEFAULT_GROUP` | `config/gateway/mall-gateway-prod.yaml` | 网关配置   |
| `mall-admin-prod.yaml`   | `DEFAULT_GROUP` | `config/admin/mall-admin-prod.yaml`     | 后台管理配置 |
| `mall-auth-prod.yaml`    | `DEFAULT_GROUP` | 需手动创建（见下方）                              | 认证中心配置 |
| `mall-portal-prod.yaml`  | `DEFAULT_GROUP` | `config/portal/mall-portal-prod.yaml`   | 门户配置   |
| `mall-search-prod.yaml`  | `DEFAULT_GROUP` | `config/search/mall-search-prod.yaml`   | 搜索配置   |
| `mall-demo-prod.yaml`    | `DEFAULT_GROUP` | `config/demo/mall-demo-prod.yaml`       | 测试配置   |

**每个配置的操作步骤相同：**

1. Data ID 填入上方表格中的值（如 `mall-admin-prod.yaml`）
2. Group 填 `DEFAULT_GROUP`
3. 配置格式选 **YAML**
4. 配置内容：粘贴对应的 YAML 文件内容
5. 点击 **发布**

**关于 mall-auth-prod.yaml：**

项目中 `config/auth/` 目录下没有 `mall-auth-prod.yaml` 文件。根据 mall-auth 模块的 `application-prod.yml`，它从 Nacos 加载 `mall-auth-prod.yaml`。你需要手动创建这个配置文件。以下是推荐的配置内容：

```yaml
spring:
  datasource:
    url: jdbc:mysql://db:3306/mall?useUnicode=true&characterEncoding=utf-8&serverTimezone=Asia/Shanghai&useSSL=false
    username: root
    password: root
  data:
    redis:
      host: redis
      database: 0
      port: 6379
      password:
logging:
  file:
    path: /var/logs
  level:
    root: info
    com.macro.mall: info
logstash:
  host: logstash
```

> ⚠️ **关键提醒**：Nacos 配置中的主机名（如 `db`、`redis`、`nacos-registry`）必须与 Docker Compose 中的 `container_name` **完全一致**！这是因为 Docker 网络中容器之间通过容器名进行 DNS 解析。

**第五步：验证配置导入成功**

在 Nacos 控制台的配置列表中，你应该能看到 6 条配置记录。点击任意一条，确认配置内容正确。

***

### 4.5 Nginx 反向代理配置

**创建 Nginx 主配置文件：**

```bash
# 创建配置目录
sudo mkdir -p /mydata/nginx/conf/conf.d
```

**主配置文件** **`/mydata/nginx/conf/nginx.conf`：**

```nginx
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for" '
                      '$request_time';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    tcp_nopush      on;
    keepalive_timeout  65;
    gzip  on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;

    # 引入额外的配置文件（各站点配置）
    include /etc/nginx/conf.d/*.conf;

    # 默认 server
    server {
        listen       80;
        server_name  _;

        location / {
            root   /usr/share/nginx/html;
            index  index.html index.htm;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   /usr/share/nginx/html;
        }
    }
}
```

**API 反向代理配置** **`/mydata/nginx/conf/conf.d/api.conf`：**

```nginx
# ============================================================
#  mall-swarm API 反向代理配置
#  通过 Nginx 将外部请求转发给 mall-gateway
# ============================================================

# API 请求 -> 转发到网关
server {
    listen 80;
    server_name api.your-domain.com;  # 替换为你的域名或 IP

    # API 文档聚合（Knife4j 网关模式）
    location /doc.html {
        proxy_pass http://mall-gateway:8201/doc.html;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # Swagger/OpenAPI 相关资源
    location /swagger-resources {
        proxy_pass http://mall-gateway:8201/swagger-resources;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /v3/api-docs {
        proxy_pass http://mall-gateway:8201/v3/api-docs;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /webjars/ {
        proxy_pass http://mall-gateway:8201/webjars/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # 所有 API 请求转发到网关
    location / {
        proxy_pass http://mall-gateway:8201;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket 支持（如果需要）
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # 访问日志
    access_log /var/log/nginx/api_access.log main;
}

# 后台管理 API（可选：单独的 server block）
server {
    listen 80;
    server_name admin.your-domain.com;  # 替换为你的域名或使用同一 IP

    location / {
        proxy_pass http://mall-gateway:8201;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

> 💡 **如果没有域名**：可以将 `server_name` 设为 `_`（匹配所有），或者直接用 IP 地址。但要注意：如果多个 `server` 块都用同一个 `server_name`，Nginx 会按配置文件顺序匹配。

***

### 4.6 启动命令和顺序

### 知识点：为什么启动顺序很重要？

**是什么？**
Docker 容器的启动不是瞬间的——MySQL 需要初始化数据文件（首次约 20\~40 秒）、Nacos 需要建立数据库连接、Java 应用需要连接 Nacos 拉取配置...

**为什么关注顺序？**
如果 mall-admin 在 MySQL 还没就绪时就尝试连接数据库，它会报 `Connection refused` 然后反复重试，浪费时间和日志空间。更糟糕的是，有些应用**不会自动重试**，直接就启动失败了。

我们的 `docker-compose.base.yml` 已经通过 `depends_on` + `healthcheck` 解决了这个问题。但你仍然需要知道正确的启动逻辑。

#### 启动前检查清单

```bash
# 1. 确认 .env 文件存在
cd /data/projects/mall-swarm/deploy
ls -la ../.env

# 2. 确认镜像已经构建好（或在 ACR 中可用）
# 如果还没有镜像，先在 GitHub 上触发一次 Actions 构建
# 或者手动拉取：
echo "检查是否需要先登录 ACR"
docker login --username=${ACR_USERNAME} ${ACR_REGISTRY}

# 3. 确认目录结构
ls -la /mydata/
```

#### 第一次启动（带数据库初始化）

```bash
cd /data/projects/mall-swarm/deploy

# 第一步：先只启动基础设施（MySQL + Redis + Nacos）
docker compose -f docker-compose.base.yml up -d mysql redis nacos-registry

# 等待它们变为 healthy（大约 30~60 秒）
docker compose -f docker-compose.base.yml ps

# 第二步：导入数据库 SQL
docker exec -i mysql mysql -uroot -proot mall < ../../document/sql/mall.sql

# 第三步：启动剩余服务（Nginx + 应用服务）
docker compose -f docker-compose.base.yml up -d

# 第四步：查看所有容器状态
docker compose -f docker-compose.base.yml ps
```

#### 日常启动（数据库已有数据）

```bash
cd /data/projects/mall-swarm/deploy
docker compose -f docker-compose.base.yml up -d

# 查看日志确认启动成功
docker compose -f docker-compose.base.yml logs -f --tail=50
```

#### 停止服务

```bash
cd /data/projects/mall-swarm/deploy

# 停止所有容器（保留数据）
docker compose -f docker-compose.base.yml down

# 停止并删除卷（⚠️ 会丢失数据！谨慎使用）
# docker compose -f docker-compose.base.yml down -v
```

***

### 4.7 验证清单

启动完成后，按以下顺序逐一验证：

#### ✅ 步骤 1：验证基础设施

```bash
# ---- MySQL ----
docker exec -it mysql mysql -uroot -proot -e "SELECT 1;"
# 输出: +---+
#       | 1 |
#       +---+

# 检查 mall 数据库是否存在
docker exec -it mysql mysql -uroot -proot -e "SHOW DATABASES;"
# 应包含: information_schema, mall, mysql, nacos_config, performance_schema, sys

# ---- Redis ----
docker exec -it redis redis-cli ping
# 输出: PONG

# ---- Nacos ----
# 浏览器访问: http://${MAIN_SERVER_IP}:8848/nacos
# 应看到 Nacos 控制台登录页
# 登录后左侧「服务管理」→「服务列表」应能看到注册的服务
```

#### ✅ 步骤 2：验证应用服务注册到 Nacos

```bash
# 等待约 30~60 秒让应用服务完成注册
sleep 45

# 查看 Nacos 中的服务列表（通过 API）
curl -s "http://localhost:8848/nacos/v1/ns/service/list?pageNo=1&pageSize=20" | python3 -m json.tool
```

预期输出应包含：`mall-gateway`、`mall-admin`、`mall-auth` 等服务名。

或者在 Nacos 控制台查看：**服务管理** → **服务列表**

#### ✅ 步骤 3：验证 mall-auth（认证中心）

```bash
# 检查容器状态
docker ps | grep mall-auth

# 查看启动日志（确认无 ERROR）
docker logs mall-auth --tail 30

# 测试认证接口
curl -s -X POST "http://localhost:8401/mall-auth/admin/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"123456"}' | python3 -m json.tool
```

#### ✅ 步骤 4：验证 mall-admin（后台管理）

```bash
# 检查容器状态
docker ps | grep mall-admin

# 查看启动日志
docker logs mall-admin --tail 30

# 测试健康检查端点
curl -s "http://localhost:8080/actuator/health" | python3 -m json.tool
```

#### ✅ 步骤 5：验证 mall-gateway（API 网关）

```bash
# 检查容器状态
docker ps | grep mall-gateway

# 查看启动日志
docker logs mall-gateway --tail 30

# 通过网关访问认证接口（测试路由转发）
curl -s -X POST "http://localhost:8201/mall-auth/admin/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"123456"}' | python3 -m json.tool

# 访问 Knife4j API 文档
# 浏览器打开: http://${MAIN_SERVER_IP}:8201/doc.html
```

#### ✅ 步骤 6：验证 Nginx 反向代理

```bash
# 通过 Nginx (80端口) 访问网关
curl -s "http://localhost/" -o /dev/null -w "%{http_code}"
# 应返回 200 或相关页面

# 通过 Nginx 访问 API 文档
curl -s "http://localhost/doc.html" -o /dev/null -w "%{http_code}"
```

#### 📋 阶段 1 完整验证清单

| 验证项             | 命令/方式                               | 预期结果         |
| --------------- | ----------------------------------- | ------------ |
| MySQL 运行        | `docker ps \| grep mysql`           | Up (healthy) |
| MySQL 连通        | `mysql -uroot -proot -e "SELECT 1"` | 1            |
| mall 数据库        | `SHOW DATABASES`                    | 含 mall       |
| Redis 运行        | `docker ps \| grep redis`           | Up (healthy) |
| Redis Ping      | `redis-cli ping`                    | PONG         |
| Nacos 运行        | `docker ps \| grep nacos`           | Up (healthy) |
| Nacos 控制台       | 浏览器 `:8848/nacos`                   | 可登录          |
| Nacos 服务列表      | 控制台查看                               | ≥3 个服务       |
| mall-auth 运行    | `docker ps \| grep auth`            | Up           |
| mall-auth 日志    | `docker logs mall-auth`             | 无 ERROR      |
| mall-admin 运行   | `docker ps \| grep admin`           | Up           |
| mall-admin 健康   | `curl :8080/actuator/health`        | UP           |
| mall-gateway 运行 | `docker ps \| grep gateway`         | Up           |
| 网关路由            | `curl :8201/mall-auth/...`          | 正常响应         |
| Nginx 运行        | `docker ps \| grep nginx`           | Up           |
| Nginx 代理        | `curl localhost/`                   | 200          |

全部通过？恭喜！🎉 **阶段 1 完成！** 你已经有了一个可用的微服务骨架。

***

### 4.8 常见问题排查

#### 问题 1：MySQL 容器不断重启

**现象**：`docker ps` 显示 mysql 容器处于 `Restarting` 状态

**排查**：

```bash
# 查看日志
docker logs mysql --tail 50

# 常见原因：
# 1. 数据目录权限问题
ls -la /mydata/mysql/data/db/
# 修复：sudo chmod -R 755 /mydata/mysql/

# 2. 端口被占用
sudo lsof -i :3306
# 修复：杀掉占用进程或修改映射端口

# 3. 内存不足
free -h
# 修复：关闭其他服务或增加 swap
```

#### 问题 2：Nacos 启动后无法访问控制台

**现象**：浏览器访问 `:8848/nacos` 无法打开

**排查**：

```bash
# 1. 检查容器是否真的在运行
docker ps -a | grep nacos

# 2. 检查端口映射
docker port nacos-registry

# 3. 查看日志
docker logs nacos-registry --tail 50

# 4. 常见原因：Nacos 依赖的 MySQL 未就绪
# 确保 mysql 显示 healthy 状态
docker inspect --format='{{json .State.Health.Status}}' mysql
```

#### 问题 3：应用服务无法注册到 Nacos

**现象**：应用容器在运行，但 Nacos 服务列表中没有它

**排查**：

```bash
# 1. 查看应用日志
docker logs mall-admin --tail 100 | grep -i nacos

# 2. 常见错误："connect to nacos-registry:8848 failed"
#    原因：容器间 DNS 解析失败
#    检查：docker exec mall-admin ping nacos-registry

# 3. 常见错误："config not found: mall-admin-prod.yaml"
#    原因：Nacos 中还没导入配置文件
#    解决：按 4.4 节导入配置

# 4. 常见错误：连接被拒绝
#    原因：Nacos 还没完全启动（需要等 30~60 秒）
#    解决：耐心等待，或检查 Nacos healthcheck 状态
```

#### 问题 4：镜像拉取失败

**现象**：`Error response from daemon: pull access denied`

**排查**：

```bash
# 1. 确认 ACR 登录状态
docker info | grep -i registry

# 2. 重新登录
docker login --username=${ACR_USERNAME} ${ACR_REGISTRY}

# 3. 确认镜像确实存在于 ACR
# 登录阿里云 ACR 控制台查看镜像列表

# 4. 确认 .env 中的 ACR_REGISTRY 地址正确
cat /data/projects/mall-swarm/.env | grep ACR_REGISTRY
```

***

## 第5章：阶段2 — 商品搜索服务

> **本章目标**：在扩展服务器上部署 Elasticsearch 和 mall-search 服务，实现商品搜索功能。

### 5.1 新增服务说明

| 新增服务                 | 部署位置         | 说明      |
| -------------------- | ------------ | ------- |
| Elasticsearch 7.17.3 | 扩展服务器        | 全文搜索引擎  |
| mall-search          | 扩展服务器（或主服务器） | 商品搜索微服务 |

### 知识点：为什么商品搜索需要 Elasticsearch？

**是什么？**
Elasticsearch（简称 ES）是一个基于 Lucene 的**分布式全文搜索引擎**，提供 RESTful API。

**为什么不用 MySQL LIKE 搜索？**

| 对比维度  | MySQL LIKE           | Elasticsearch        |
| ----- | -------------------- | -------------------- |
| 中文分词  | ❌ 不支持（`%关键词%` 是模糊匹配） | ✅ IK 分词器支持智能分词       |
| 搜索性能  | 数据量大时全表扫描，极慢         | **倒排索引**，毫秒级响应       |
| 相关性排序 | ❌ 只能精确/模糊匹配          | ✅ TF-IDF + BM25 算法评分 |
| 高亮显示  | 需自行实现                | ✅ 内置高亮               |
| 百万级数据 | 秒级甚至更慢               | **毫秒级**              |

**追问：倒排索引是什么？**
想象一本书末尾的关键词索引页：

* **正排索引**（MySQL）：第1页出现"手机"，第3页出现"电脑"... → 搜索时要翻每一页

* **倒排索引**（ES）："手机" → 出现在第1, 15, 23页；"电脑" → 出现在第3, 18页 → 搜索时直接定位

***

### 5.2 docker-compose.search.yml 完整内容

在**扩展服务器**的 `/data/projects/mall-swarm/deploy/` 目录下创建：

```yaml
# ============================================================
#  mall-swarm 阶段2：商品搜索服务
#  包含：Elasticsearch + mall-search
#
#  使用方式：
#    cd /data/projects/mall-swarm/deploy
#    docker compose -f docker-compose.search.yml up -d
# ============================================================

version: '3'

services:

  elasticsearch:
    image: elasticsearch:7.17.3
    container_name: elasticsearch
    restart: unless-stopped
    user: root
    environment:
      - cluster.name=mall-es-cluster
      - discovery.type=single-node
      - "ES_JAVA_OPTS=${ES_JAVA_OPTS:--Xms256m -Xmx512m}"
      - xpack.security.enabled=false
      - TZ=Asia/Shanghai
    ports:
      - "9200:9200"
      - "9300:9300"
    volumes:
      - /mydata/elasticsearch/plugins:/usr/share/elasticsearch/plugins
      - /mydata/elasticsearch/data:/usr/share/elasticsearch/data
    networks:
      - mall-network
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:9200/_cluster/health || exit 1"]
      interval: 20s
      timeout: 10s
      retries: 10
      start_period: 60s

  mall-search:
    image: ${ACR_REGISTRY:-your-registry.cn-shenzhen.aliyuncs.com}/${ACR_NAMESPACE:-mall}/mall-search:${IMAGE_TAG:-latest}
    container_name: mall-search
    restart: unless-stopped
    environment:
      - TZ=Asia/Shanghai
      # 如果 ES 在另一台服务器，需要配置 ES 的实际地址
      # 这里假设 ES 和 search 在同一台服务器（同一 Docker 网络）
    ports:
      - "8081:8081"
    volumes:
      - /mydata/app/mall-search/logs:/var/logs
      - /etc/localtime:/etc/localtime
    depends_on:
      elasticsearch:
        condition: service_healthy
    extra_hosts:
      # 如果 Nacos/MySQL/Redis 在主服务器，需要在这里映射
      - "nacos-registry:${MAIN_SERVER_IP}"
      - "db:${MAIN_SERVER_IP}"
      - "redis:${MAIN_SERVER_IP}"
    networks:
      - mall-network

networks:
  mall-network:
    driver: bridge
```

### 5.3 Elasticsearch 内存优化配置（针对低配服务器）

### 知识点：ES 为什么这么吃内存？

**是什么？**
Elasticsearch 是一个 Java 应用，运行在 JVM 之上。它的内存消耗主要来自两部分：

1. **JVM Heap**（堆内存）：用于索引数据、缓存查询结果
2. **Lucene 段缓存**（Off-heap）：用于操作系统级别的文件缓存

**为什么默认配置在低配服务器上不行？**

* ES 默认 JVM Heap = **1GB**

* 加上 Lucene 缓存和 ES 自身开销，总共需要 **1.5\~2GB**

* 对于 4GB 服务器来说，留给 OS 和其他服务的空间所剩无几

**针对 2核4G 扩展服务器的优化配置：**

```yaml
# 在 docker-compose.search.yml 中的 ES_JAVA_OPTS
environment:
  - "ES_JAVA_OPTS=-Xms256m -Xmx512m"
```

| 参数     | 默认值   | 优化值     | 说明         |
| ------ | ----- | ------- | ---------- |
| `-Xms` | 1g    | 256m    | JVM 最小堆内存  |
| `-Xmx` | 1g    | 512m    | JVM 最大堆内存  |
| 总计     | \~2GB | \~800MB | 节省约 60% 内存 |

**额外优化手段（写入 ES 配置文件）：**

创建 `/mydata/elasticsearch/config/elasticsearch.yml`：

```yaml
cluster.name: mall-es-cluster
node.name: es-node-1
network.host: 0.0.0.0
discovery.type: single-node

# 内存优化
bootstrap.memory_lock: false  # 低内存环境下禁用内存锁定

# 索引优化（降低内存占用）
indices.fielddata.cache.size: 20%
indices.queries.cache.size: 10%

# 线程池优化（降低线程数以节省内存）
thread_pool.search.size: 2
thread_pool.search.queue_size: 100
thread_pool.write.size: 1
thread_pool.write.queue_size: 200
```

然后在 `docker-compose.search.yml` 中挂载此配置：

```yaml
volumes:
  - /mydata/elasticsearch/config/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml:ro
  - /mydata/elasticsearch/plugins:/usr/share/elasticsearch/plugins
  - /mydata/elasticsearch/data:/usr/share/elasticsearch/data
```

> ⚠️ **警告**：以上优化会影响 ES 的搜索性能和数据容量。如果后续发现搜索变慢或索引失败，适当增大 `-Xmx` 值。

***

### 5.4 启动和验证

#### 启动命令

```bash
# 在扩展服务器上执行
cd /data/projects/mall-swarm/deploy

# 确保内核参数已设置
sudo sysctl -w vm.max_map_count=262144

# 启动阶段2服务
docker compose -f docker-compose.search.yml up -d

# 查看状态
docker compose -f docker-compose.search.yml ps

# 查看 ES 日志（首次启动较慢）
docker logs elasticsearch -f
```

#### 验证清单

```bash
# 1. 验证 Elasticsearch
curl -s "http://localhost:9200/?pretty" | python3 -m json.tool
# 预期输出包含:
# {
#   "name" : "es-node-1",
#   "cluster_name" : "mall-es-cluster",
#   ...
#   "status" : "green" (或 "yellow"，单节点通常为 yellow)
# }

# 2. 验证 ES 集群健康状态
curl -s "http://localhost:9200/_cluster/health?pretty"

# 3. 验证 mall-search 服务
docker logs mall-search --tail 30

# 4. 验证 search 服务注册到 Nacos
# 在 Nacos 控制台查看服务列表，应包含 mall-search

# 5. 通过网关测试搜索接口
# （需要在主服务器上执行，因为网关在主服务器）
curl -s "http://${MAIN_SERVER_IP}:8201/mall-search/esProduct/search?keyword=小米" \
  -H "Content-Type: application/json"
```

#### 关于跨服务器通信的重要说明

**问题**：mall-search 在扩展服务器上，但它需要连接主服务器上的 Nacos、MySQL、Redis。

**解决方案**：我们在 `docker-compose.search.yml` 中使用了 `extra_hosts` 将主服务器 IP 映射为容器名。但这要求：

1. **Nacos 配置调整**：如果 mall-search 的 Nacos 配置中使用的是 `nacos-registry:8848`，`extra_hosts` 映射会让它解析到主服务器 IP
2. **防火墙开放**：确保主服务器的 8848、3306、6379 端口对扩展服务器 IP 开放
3. **替代方案**：如果跨服务器网络不稳定，可以考虑将 mall-search 也部署在主服务器上（只是会进一步增加主服务器内存压力）

***

## 第6章：阶段3 — 前台商城服务

> **本章目标**：部署 MongoDB、RabbitMQ 和 mall-portal 前台商城服务。

### 6.1 新增服务说明

| 新增服务            | 部署位置         | 说明                |
| --------------- | ------------ | ----------------- |
| MongoDB 4       | 扩展服务器        | NoSQL 数据库（存储门户内容） |
| RabbitMQ 3.9.11 | 扩展服务器        | 消息队列（异步处理订单等）     |
| mall-portal     | 扩展服务器（或主服务器） | 前台商城微服务           |

### 6.2 docker-compose.portal.yml 完整内容

在**扩展服务器**的 `/data/projects/mall-swarm/deploy/` 目录下创建：

```yaml
# ============================================================
#  mall-swarm 阶段3：前台商城服务
#  包含：MongoDB + RabbitMQ + mall-portal
#
#  使用方式：
#    cd /data/projects/mall-swarm/deploy
#    docker compose -f docker-compose.portal.yml up -d
# ============================================================

version: '3'

services:

  mongo:
    image: mongo:4
    container_name: mongo
    restart: unless-stopped
    environment:
      MONGO_INITDB_DATABASE: mall-port
      TZ: Asia/Shanghai
    ports:
      - "27017:27017"
    volumes:
      - /mydata/mongo/db:/data/db
      - /mydata/mongo/config:/data/config
    networks:
      - mall-network
    command: mongod --auth  # 启用认证（生产环境必须！）

  rabbitmq:
    image: rabbitmq:3.9.11-management
    container_name: rabbitmq
    restart: unless-stopped
    environment:
      RABBITMQ_DEFAULT_USER: ${RABBITMQ_DEFAULT_USER:-mall}
      RABBITMQ_DEFAULT_PASS: ${RABBITMQ_DEFAULT_PASS:-mall}
      RABBITMQ_DEFAULT_VHOST: /mall
      TZ: Asia/Shanghai
    ports:
      - "5672:5672"    # AMQP 端口
      - "15672:15672"  # 管理界面端口
    volumes:
      - /mydata/rabbitmq/data:/var/lib/rabbitmq
      - /mydata/rabbitmq/log:/var/log/rabbitmq
    networks:
      - mall-network
    healthcheck:
      test: ["CMD", "rabbitmqctl", "wait", "--timeout", "30"]
      interval: 15s
      timeout: 10s
      retries: 5

  mall-portal:
    image: ${ACR_REGISTRY:-your-registry.cn-shenzhen.aliyuncs.com}/${ACR_NAMESPACE:-mall}/mall-portal:${IMAGE_TAG:-latest}
    container_name: mall-portal
    restart: unless-stopped
    environment:
      - TZ=Asia/Shanghai
    ports:
      - "8085:8085"
    volumes:
      - /mydata/app/mall-portal/logs:/var/logs
      - /etc/localtime:/etc/localtime
    depends_on:
      mongo:
        condition: service_started
      rabbitmq:
        condition: service_healthy
    extra_hosts:
      - "nacos-registry:${MAIN_SERVER_IP}"
      - "db:${MAIN_SERVER_IP}"
      - "redis:${MAIN_SERVER_IP}"
      - "rabbit:${EXT_SERVER_IP}"  # RabbitMQ 在本机，但也通过 extra_hosts 映射
      - "mongo:${EXT_SERVER_IP}"   # MongoDB 在本机
    networks:
      - mall-network

networks:
  mall-network:
    driver: bridge
```

### 6.3 MongoDB 和 RabbitMQ 基础配置

#### MongoDB 初始化

```bash
# 进入 MongoDB 容器创建用户
docker exec -it mongo mongosh

# 在 MongoDB shell 中执行：
use admin
db.createUser({
  user: "mall",
  pwd: "mall",
  roles: [{ role: "readWrite", db: "mall-port" }]
})

# 验证用户创建
db.getUsers()
exit
```

> ⚠️ **安全提醒**：生产环境中请使用更强的密码！这里的 `mall/mall` 仅用于学习环境。

#### RabbitMQ 配置

**通过管理界面配置（推荐）：**

1. 浏览器访问：`http://${EXT_SERVER_IP}:15672`
2. 默认账号密码：`mall / mall`（来自 docker-compose 环境变量）
3. 创建 Virtual Host：

   * Admin → Virtual Hosts → Add Virtual Host

   * Name: `/mall`

   * 点击 Add
4. 设置用户权限：

   * Admin → Users → 点击 `mall` 用户

   * Permissions → 选择 Virtual Host `/mall`

   * 设置权限：`.*` `.*` `.*`（全部权限）

   * 点击 Set Permission

**验证 RabbitMQ：**

```bash
# 检查节点状态
docker exec rabbitmq rabbitmqctl status

# 检查队列列表
docker exec rabbitmq rabbitmqctl list_queues name messages

# 检查 Virtual Host
docker exec rabbitmq rabbitmqctl list_vhosts
```

### 6.4 启动和验证

#### 启动命令

```bash
# 在扩展服务器上执行
cd /data/projects/mall-swarm/deploy

# 启动阶段3服务
docker compose -f docker-compose.portal.yml up -d

# 查看状态
docker compose -f docker-compose.portal.yml ps

# 查看日志
docker compose -f docker-compose.portal.yml logs -f
```

#### 验证清单

```bash
# 1. 验证 MongoDB
docker exec -it mongo mongosh --eval "db.runCommand({ping:1})"
# 输出: { ok: 1 }

# 2. 验证 RabbitMQ 管理界面
# 浏览器: http://${EXT_SERVER_IP}:15672
# 应能看到管理面板

# 3. 验证 RabbitMQ AMQP 端口
docker exec rabbitmq rabbitmqctl status | grep "Listeners"

# 4. 验证 mall-portal 服务
docker logs mall-portal --tail 30

# 5. 验证 portal 注册到 Nacos
# Nacos 控制台 → 服务列表 → 应包含 mall-portal

# 6. 通过网关测试门户接口
curl -s "http://${MAIN_SERVER_IP}:8201/mall-portal/home/content" | python3 -m json.tool
```

***

## 第7章：阶段4 — 日志监控

> **本章目标**：部署 ELK（Elasticsearch + Logstash + Kibana）日志体系和 Spring Boot Admin 监控中心。

### 7.1 ELK 架构说明

```
┌─────────────┐     TCP:4560-4563      ┌──────────────┐
│  各应用服务   │ ─────────────────────→ │   Logstash    │
│ (logback-appender)│  (JSON 格式日志)    │  (日志收集/过滤) │
└─────────────┘                         └──────┬───────┘
                                               │
                                               │ HTTP:9200
                                               ▼
                                        ┌──────────────┐
                                        │Elasticsearch │
                                        │ (日志存储/索引)│
                                        └──────┬───────┘
                                               │
                                               │ HTTP:5601
                                               ▼
                                        ┌──────────────┐
                                        │   Kibana     │
                                        │ (日志可视化)  │
                                        └──────────────┘
```

### 知识点：为什么需要集中式日志？

**是什么？**
每个 Docker 容器都有自己的日志（`docker logs` 可以查看），但当服务多了以后：

* 要查一个请求经过了哪些服务？得挨个 `docker logs`

* 日志分散在各处，出了问题很难关联

* 容器重建后旧日志丢失

**为什么用 ELK？**

* **Logstash**：从各个服务收集日志，统一格式化

* **Elasticsearch**：存储和搜索海量日志数据

* **Kibana**：提供可视化界面，支持搜索、过滤、图表

**追问：为什么不直接用 Docker 自带的日志驱动？**
Docker 的 `json-file` 日志驱动适合简单场景，但不支持：

* 日志聚合搜索（跨服务查询）

* 日志分析统计（QPS、错误率趋势）

* 日志告警（错误激增时通知）

* 长期存储（容器重建后日志不丢失）

***

### 7.2 docker-compose.elk.yml 完整内容

在**扩展服务器**的 `/data/projects/mall-swarm/deploy/` 目录下创建：

```yaml
# ============================================================
#  mall-swarm 阶段4：日志监控（ELK + Monitor）
#  包含：Logstash + Kibana + mall-monitor
#  注意：Elasticsearch 应已在阶段2中启动
#
#  使用方式：
#    cd /data/projects/mall-swarm/deploy
#    docker compose -f docker-compose.elk.yml up -d
# ============================================================

version: '3'

services:

  logstash:
    image: logstash:7.17.3
    container_name: logstash
    restart: unless-stopped
    environment:
      TZ: Asia/Shanghai
      LS_JAVA_OPTS: "-Xms256m -Xmx512m"
    volumes:
      - /mydata/logstash/logstash.conf:/usr/share/logstash/pipeline/logstash.conf:ro
      - /mydata/logstash/data:/usr/share/logstash/data
    ports:
      - "4560:4560"
      - "4561:4561"
      - "4562:4562"
      - "4563:4563"
    depends_on:
      elasticsearch:
        condition: service_healthy
    networks:
      - mall-network
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:9600 || exit 1"]
      interval: 20s
      timeout: 10s
      retries: 5

  kibana:
    image: kibana:7.17.3
    container_name: kibana
    restart: unless-stopped
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - I18N_LOCALE=zh-CN
      - TZ=Asia/Shanghai
    ports:
      - "5601:5601"
    depends_on:
      elasticsearch:
        condition: service_healthy
    networks:
      - mall-network

  mall-monitor:
    image: ${ACR_REGISTRY:-your-registry.cn-shenzhen.aliyuncs.com}/${ACR_NAMESPACE:-mall}/mall-monitor:${IMAGE_TAG:-latest}
    container_name: mall-monitor
    restart: unless-stopped
    environment:
      - TZ=Asia/Shanghai
    ports:
      - "8101:8101"
    volumes:
      - /mydata/app/mall-monitor/logs:/var/logs
      - /etc/localtime:/etc/localtime
    extra_hosts:
      - "nacos-registry:${MAIN_SERVER_IP}"
    networks:
      - mall-network

networks:
  mall-network:
    driver: bridge
```

> ⚠️ **注意**：此 compose 文件依赖阶段 2 中已启动的 Elasticsearch。确保 ES 正在运行。

***

### 7.3 Logstash 配置文件

创建 `/mydata/logstash/logstash.conf`：

```conf
# ============================================================
#  mall-swarm Logstash 配置
#  功能：接收各应用服务发送的结构化日志，处理后存入 ES
#
#  端口分配：
#    4560 - debug 级别日志
#    4561 - error 级别日志
#    4562 - business 业务日志
#    4563 - record 操作记录日志
# ============================================================

input {
  tcp {
    mode => "server"
    host => "0.0.0.0"
    port => 4560
    codec => json_lines
    type => "debug"
  }
  tcp {
    mode => "server"
    host => "0.0.0.0"
    port => 4561
    codec => json_lines
    type => "error"
  }
  tcp {
    mode => "server"
    host => "0.0.0.0"
    port => 4562
    codec => json_lines
    type => "business"
  }
  tcp {
    mode => "server"
    host => "0.0.0.0"
    port => 4563
    codec => json_lines
    type => "record"
  }
}

filter {
  if [type] == "record" {
    mutate {
      remove_field => ["port", "host", "@version"]
    }
    json {
      source => "message"
      remove_field => ["message"]
    }
  }

  # 解析时间戳
  date {
    match => ["timestamp", "ISO8601"]
  }

  # 提取来源服务名
  if [appname] {
    mutate { add_field => { "service" => "%{appname}" } }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "mall-%{type}-%{+YYYY.MM.dd}"
    template_name => "mall-log"
    template_overwrite => true
  }

  # 同时输出到标准输出（方便 docker logs 查看）
  stdout {
    codec => rubydebug
  }
}
```

### 知识点：为什么 Logstash 需要四个端口？

**是什么？**
mall-swarm 的 `logback-spring.xml` 配置了 Logstash appender，将日志分为 **4 个级别** 分别发送到不同端口：

| 端口   | 类型       | 用途   | Kibana 中筛选      |
| ---- | -------- | ---- | --------------- |
| 4560 | debug    | 调试日志 | `type:debug`    |
| 4561 | error    | 错误日志 | `type:error`    |
| 4562 | business | 业务日志 | `type:business` |
| 4563 | record   | 操作记录 | `type:record`   |

**为什么分开？**

* **分级存储**：error 日志保留 30 天，debug 日志只保留 3 天

* **独立索引**：Kibana 可以按类型分别创建仪表板

* **性能优化**：error 日志可以设置更高的优先级处理

***

### 7.4 启动和验证

#### 启动命令

```bash
# 在扩展服务器上执行
cd /data/projects/mall-swarm/deploy

# 确保 ES 正在运行（阶段2）
docker ps | grep elasticsearch

# 启动 ELK + Monitor
docker compose -f docker-compose.elk.yml up -d

# 查看状态
docker compose -f docker-compose.elk.yml ps

# Logstash 首次启动较慢（要加载插件），查看日志
docker logs logstash -f
```

#### 验证清单

```bash
# 1. 验证 Logstash
curl -s "http://localhost:9600/?pretty"
# 应输出 Logstash 状态信息

# 2. 验证 Kibana
# 浏览器访问: http://${EXT_SERVER_IP}:5601
# 首次打开需要等待 ES 索引就绪

# 3. 验证 mall-monitor
docker logs mall-monitor --tail 30

# 4. 在 Kibana 中创建索引模式
#    打开 Kibana → Management → Stack Management → 索引模式
#    创建模式: mall-*
#    时间字段: @timestamp

# 5. 验证日志采集链路
#    触发一些 API 请求后在 Kibana Discover 中搜索
#    应能看到 mall-* 索引下的日志数据
```

#### Kibana 快速配置指南

首次打开 Kibana 后：

1. **创建索引模式**：

   * 菜单 → **Management** → **Stack Management** → **索引模式** → **创建索引模式**

   * 模式名称：`mall-*`

   * 时间字段：`@timestamp`

2. **查看日志**：

   * 菜单 → **Analytics** → **Discover**

   * 应能看到来自各服务的日志

3. **（可选）保存搜索**：

   * 筛选 `type:error` → 只看错误日志

   * 保存为 "错误日志" 搜索

***

## 第8章：前端部署

### 8.1 mall-admin-web 前端项目说明

mall-swarm 的前端管理后台是基于 **Vue + Element UI** 构建的独立项目，位于：

<https://github.com/macrozheng/mall-admin-web>

这是一个与后端完全解耦的前端项目，最终产物是**静态文件**（HTML/CSS/JS），可以部署到任何 Web 服务器上。

### 8.2 构建前端静态资源

#### 前提条件

你需要在一台**有 Node.js 环境**的机器上执行构建（可以是你的本地电脑）：

```bash
# 检查 Node.js 版本（需要 >= 14）
node -v
npm -v
```

#### 构建步骤

```bash
# 1. 克隆前端项目
git clone https://github.com/macrozheng/mall-admin-web.git
cd mall-admin-web

# 2. 安装依赖
npm install

# 3. 修改 API 请求地址（重要！）
# 编辑 vue.config.js 或 .env.production
# 将 baseURL 改为你的网关地址或 Nginx 地址
# 例如: baseURL: 'http://your-server-ip' 或 baseURL: ''

# 4. 构建（生成 dist 目录）
npm run build

# 5. 查看产物
ls -la dist/
# 应包含: index.html, static/, favicon.ico 等
```

#### 修改 API 请求地址

**找到配置文件并修改：**

```javascript
// 在 mall-admin-web 项目中找到以下文件之一进行修改：
// - vue.config.js (Vue CLI 项目)
// - .env.production (环境变量)
// - src/utils/request.js (axios 配置)

// 将 API 基础地址改为空字符串（走 Nginx 代理）
// 或者改为你的网关地址

// 推荐：设为空字符串，通过 Nginx 反向代理转发
// 这样前端静态资源和 API 请求共用同一个域名/端口
module.exports = {
  // ...
  devServer: {
    port: 80,
    proxy: {
      '/mall-admin': {
        target: 'http://your-gateway-ip:8201',
        changeOrigin: true,
        pathRewrite: {'^/mall-admin': '/mall-admin'}
      }
    }
  },
  // ...
}
```

### 8.3 部署到 Nginx

#### 方式一：直接复制静态文件

```bash
# 将构建产物复制到主服务器的 Nginx html 目录
# 在本地电脑执行：
scp -r dist/* user@${MAIN_SERVER_IP}:/mydata/nginx/html/admin/

# 或者在主服务器上（如果有 git）：
cd /mydata/nginx/html
mkdir -p admin
# 将 dist 目录的内容放入 admin/
```

#### 方式二：通过 Docker Volume 挂载

如果你希望前端也纳入 Docker 管理，可以创建一个专门的前端容器：

```yaml
# 在 docker-compose.base.yml 中追加（或单独文件）
  mall-admin-web:
    image: nginx:1.22-alpine
    container_name: mall-admin-web
    restart: unless-stopped
    volumes:
      - /mydata/nginx/html/admin:/usr/share/nginx/html:ro
      - /mydata/nginx/conf/conf.d/admin.conf:/etc/nginx/conf.d/default.conf:ro
    ports:
      - "8088:80"
    networks:
      - mall-network
```

**Nginx 前端站点配置** **`/mydata/nginx/conf/conf.d/admin.conf`：**

```nginx
server {
    listen 80;
    server_name admin.your-domain.com;
    root /usr/share/nginx/html;
    index index.html;

    # Vue Router history 模式支持
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API 请求代理到网关
    location /mall-admin/ {
        proxy_pass http://mall-gateway:8201/mall-admin/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # 静态资源缓存
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    access_log /var/log/nginx/admin_access.log main;
}
```

#### 验证前端部署

```bash
# 重载 Nginx 配置
docker exec nginx nginx -s reload

# 浏览器访问:
# http://${MAIN_SERVER_IP}/admin/  (如果用了子目录)
# 或 http://${MAIN_SERVER_IP}:8088/ (如果用了独立容器)
```

> 💡 **前端部署的本质**：Vue/React 等现代前端框架构建后就是纯静态文件（HTML+CSS+JS），任何能提供静态文件服务的 Web 服务器都可以托管（Nginx、Apache、CDN 等）。

***

## 第9章：运维指南

### 9.1 常用命令速查表

#### 容器管理

```bash
# ===== 查看状态 =====
docker ps                          # 运行中的容器
docker ps -a                       # 所有容器（含已停止的）
docker compose -f xxx.yml ps        # Compose 项目状态

# ===== 查看日志 =====
docker logs <container_name>                  # 查看全部日志
docker logs <container_name> --tail 100       # 最后 100 行
docker logs <container_name> -f               # 实时跟踪日志
docker logs <container_name> --since 1h       # 最近 1 小时的日志
docker compose -f xxx.yml logs -f             # 实时跟踪所有服务日志

# ===== 进入容器 =====
docker exec -it <container_name> bash         # 进入容器（交互式）
docker exec -it <container_name> sh           # alpine 镜像用 sh

# ===== 启停重启 =====
docker compose -f xxx.yml up -d               # 后台启动
docker compose -f xxx.yml down                # 停止并删除容器
docker compose -f xxx.yml restart             # 重启
docker restart <container_name>               # 重启单个容器

# ===== 清理 =====
docker system df                             # 查看磁盘使用情况
docker system prune -a                        # 清理未使用的资源（⚠️ 会删除未使用的镜像）
```

#### 镜像管理

```bash
# ===== 拉取/推送 =====
docker pull ${ACR_REGISTRY}/mall/mall-admin:latest    # 拉取镜像
docker login ${ACR_REGISTRY}                          # 登录 ACR

# ===== 查看镜像 =====
docker images                                         # 本地镜像列表
docker images | grep mall                             # 过滤 mall 相关镜像

# ===== 清理 =====
docker image prune                                    # 清理悬空镜像
```

#### 网络与调试

```bash
# ===== 网络 =====
docker network ls                                     # 查看网络列表
docker network inspect mall-network                    # 查看网络详情
docker exec <c1> ping <c2-container-name>             # 容器间连通性测试

# ===== 资源监控 =====
docker stats                                          # 实时资源使用情况
docker stats --no-stream                               # 当前时刻的资源快照
```

***

### 9.2 日志查看方法

#### 方式一：Docker Logs（最常用）

```bash
# 实时跟踪某个服务的日志
docker logs -f mall-admin --tail 100

# 搜索关键字
docker logs mall-admin 2>&1 | grep -i "error"
docker logs mall-admin 2>&1 | grep -i "exception"

# 按时间范围查看
docker logs mall-admin --since "2024-01-01" --until "2024-01-02"
```

#### 方式二：宿主机日志文件

```bash
# 我们在 docker-compose 中将日志挂载到了 /mydata/app/<service>/logs
tail -f /mydata/app/mall-admin/logs/*.log
```

#### 方式三：Kibana（推荐生产环境使用）

```
浏览器 → http://${EXT_SERVER_IP}:5601 → Discover
筛选条件示例：
  - type: "error"              → 只看错误日志
  - service: "mall-admin"      → 只看 admin 服务
  - message: *Exception*       → 包含 Exception 的日志
  - @timestamp: last 15 minutes → 最近 15 分钟
```

#### 方式四：Nacos 控制台日志

部分服务的日志也会输出到 Nacos 控制台（如果配置了日志上报）。

***

### 9.3 服务重启流程

#### 正常重启单个服务

```bash
cd /data/projects/mall-swarm/deploy

# 重启单个服务（例如 mall-admin）
docker compose -f docker-compose.base.yml restart mall-admin

# 查看确认启动成功
docker logs mall-admin --tail 20
```

#### 滚动更新（零停机）

```bash
# 拉取新镜像
docker pull ${ACR_REGISTRY}/mall/mall-admin:latest

# 使用新镜像重建容器
docker compose -f docker-compose.base.yml up -d --force-recreate mall-admin
```

#### 全量重启（谨慎使用）

```bash
cd /data/projects/mall-swarm/deploy

# 按顺序重启（先基础设施，后应用）
docker compose -f docker-compose.base.yml restart mysql redis nacos-registry
sleep 30  # 等待基础设施就绪
docker compose -f docker-compose.base.yml restart mall-gateway mall-admin mall-auth
```

> ⚠️ **不要使用** **`docker compose down && docker compose up -d`** 来"重启"，因为这会短暂中断所有服务。使用 `restart` 命令才是安全的重启方式。

***

### 9.4 数据备份策略

#### MySQL 备份

```bash
# ===== 自动备份脚本 =====
# 创建 /data/scripts/backup-mysql.sh

#!/bin/bash
# MySQL 自动备份脚本
BACKUP_DIR=/data/backups/mysql
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

mkdir -p $BACKUP_DIR

# 执行备份
docker exec mysqldump -uroot -proot --single-transaction --routines --triggers mall \
  | gzip > $BACKUP_DIR/mall_${DATE}.sql.gz

# 清理过期备份
find $BACKUP_DIR -name "mall_*.sql.gz" -mtime +$RETENTION_DAYS -delete

echo "[$(date)] Backup completed: mall_${DATE}.sql.gz"
```

```bash
# 设置定时任务（每天凌晨 3 点备份）
crontab -e
# 添加以下行：
0 3 * * * /bin/bash /data/scripts/backup-mysql.sh >> /data/backups/backup.log 2>&1
```

#### Redis 备份

```bash
# Redis RDB 快照（AOF 开启的情况下）
# Redis 的 appendonly=yes 会自动持久化到 /mydata/redis/data/
# 备份这个目录即可：
tar czf /data/backups/redis_$(date +%Y%m%d).tar.gz -C /mydata redis/data/
```

#### Nacos 配置备份

```bash
# 方式一：通过 Nacos 控制台导出
# 控制台 → 配置管理 → 更多操作 → 导出

# 方式二：直接备份 MySQL 中的 nacos_config 数据库
docker exec mysqldump -uroot -proot nacos_config | gzip > /data/backups/nacos_config_$(date +%Y%m%d).sql.gz
```

#### Elasticsearch 索引快照（可选）

```bash
# ES 快照需要先配置快照仓库
# 参考: https://www.elastic.co/guide/en/elasticsearch/reference/current/snapshots-register-repository.html
curl -X PUT "localhost:9200/_snapshot/my_backup" -H 'Content-Type: application/json' -d'
{
  "type": "fs",
  "settings": {
    "location": "/mydata/elasticsearch/backups"
  }
}'
```

***

### 9.5 更新部署流程

当你修改了代码并想部署新版本时，完整流程如下：

```
┌─────────────────────────────────────────────────────┐
│                    更新部署流程                       │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ① 本地修改代码                                      │
│     ↓                                               │
│  ② git commit & git push                            │
│     ↓                                               │
│  ③ GitHub Actions 自动触发构建                        │
│     ├→ Maven 编译                                   │
│     ├→ Docker Build                                 │
│     └→ Push 到 ACR                                  │
│     ↓                                               │
│  ④ 服务器拉取新镜像                                   │
│     docker pull ${ACR}/mall/mall-xxx:latest         │
│     ↓                                               │
│  ⑤ 重启对应服务                                       │
│     docker compose up -d --force-recreate <service>  │
│     ↓                                               │
│  ⑥ 验证                                             │
│     curl /actuator/health                           │
│                                                     │
└─────────────────────────────────────────────────────┘
```

**详细步骤：**

```bash
# ===== 步骤 ①②：本地提交推送 =====
# （在你的开发电脑上执行）
git add .
git commit -m "feat: 优化商品搜索性能"
git push origin main

# ===== 步骤 ③：自动构建 =====
# GitHub Actions 会自动触发，可以在以下地址查看进度：
# https://github.com/YOU/mall-swarm/actions

# ===== 步骤 ④⑤：服务器更新 =====
# （在主服务器上执行）
cd /data/projects/mall-swarm/deploy

# 拉取最新镜像（假设 Actions 已经成功构建并推送）
docker pull ${ACR_REGISTRY}/mall/mall-admin:latest

# 重建容器（使用新镜像）
docker compose -f docker-compose.base.yml up -d --force-recreate mall-admin

# ===== 步骤 ⑥：验证 =====
docker logs mall-admin --tail 20
curl -s http://localhost:8080/actuator/health
```

***

## 第10章：排障指南

### 10.1 容器启动失败常见原因

#### 排查流程图

```
容器启动失败？
    │
    ├─→ docker logs <container> 查看日志
    │       │
    │       ├─ "Connection refused" ──→ 见 10.2
    │       ├─ "OutOfMemoryError"   ──→ 见 10.4
    │       ├─ "config not found"   ──→ Nacos 配置缺失
    │       ├─ "permission denied"  ──→ 目录权限问题
    │       └─ "port already in use"→ 端口冲突
    │
    ├─→ docker inspect <container> 查看详情
    │       └─ State.ExitCode: 非零 = 异常退出
    │
    └─→ docker events 实时事件流
```

#### 常见错误码速查

| Exit Code | 含义         | 常见原因              | 解决方案             |
| --------- | ---------- | ----------------- | ---------------- |
| 1         | 一般错误       | 应用异常退出            | 查看 `docker logs` |
| 137       | OOM Killed | 内存不足被 kill        | 见 10.4           |
| 139       | SIGSEGV    | 段错误（JNI 问题）       | 检查 JNI/native 库  |
| 143       | SIGTERM    | 收到终止信号（正常）        | 通常无需处理           |
| 126       | 权限不可执行     | entrypoint 脚本无执行权 | `chmod +x`       |

***

### 10.2 服务间连接失败排查

### 知识点：Docker 容器间是如何通信的？

**是什么？**
Docker Compose 创建的服务默认连接到一个自定义 **bridge 网络**。在这个网络中，容器之间可以通过 **容器名（container\_name）** 作为主机名互相访问。

**为什么有时连不上？**

1. **不在同一网络**：不同 `docker-compose.yml` 文件创建的网络默认是隔离的
2. **容器名拼写错误**：Nacos 配置中的 `db` 和容器名 `mysql` 不一致
3. **目标容器没启动**：依赖的服务还没 ready 就来连接了
4. **跨服务器场景**：两台物理机的容器不在同一个 Docker 网络

**排查命令：**

```bash
# 1. 检查两个容器是否在同一网络
docker network inspect mall-network
# 查看 Containers 字段，确认两个服务都在其中

# 2. 从容器 A 测试能否连通容器 B
docker exec mall-admin ping -c 3 db
docker exec mall-admin ping -c 3 redis
docker exec mall-admin ping -c 3 nacos-registry

# 3. 测试端口是否可达
docker exec mall-admin bash -c "echo > /dev/tcp/db/3306" && echo "OK" || echo "FAIL"

# 4. 检查 DNS 解析
docker exec mall-admin nslookup db
# 应返回 db 的容器内部 IP（如 172.18.0.2）

# 5. 如果跨服务器，检查 extra_hosts 映射
docker exec mall-admin cat /etc/hosts
```

***

### 10.3 Nacos 注册失败处理

**现象**：应用启动正常，但在 Nacos 控制台的服务列表中看不到它

**排查步骤：**

```bash
# 1. 查看应用日志中的 Nacos 相关信息
docker logs mall-admin 2>&1 | grep -i nacos

# 2. 常见日志及解决方案：

# --- "Failed to req API:/nacos/v1/ns/instance after all servers" ---
#    原因：Nacos 地址不可达
#    检查：docker exec mall-admin ping nacos-registry
#    检查：docker exec mall-admin curl nacos-registry:8848/nacos/v1/console/health/readiness

# --- "register instance for service:xxx failed" ---
#    原因：Nacos 还没完全启动
#    解决：等待 Nacos healthcheck 变为 healthy

# --- "config data not found: mall-admin-prod.yaml" ---
#    原因：Nacos 中没有导入配置文件
#    解决：按 4.4 节导入配置

# --- "503 Service Temporarily Unavailable from Nacos" ---
#    原因：Nacos 内部错误（可能是 MySQL 连接问题）
#    检查：docker logs nacos-registry | tail -50
```

**手动强制重新注册：**

```bash
# 重启应用服务让它重新注册
docker restart mall-admin
# 等待 30 秒后检查 Nacos 控制台
```

***

### 10.4 内存不足(OOM)应对

### 知识点：Linux OOM Killer 是什么？

**是什么？**
当系统物理内存 + Swap 空间都不够用时，Linux 内核的 OOM Killer 会主动**杀掉占用内存最多的进程**来「自救」。被杀掉的 Docker 容器会显示 Exit Code 137。

**为什么会被 OOM Kill？**

* 服务器物理内存太小（4GB 跑太多服务）

* JVM 堆内存设置过大（`-Xmx` 太高）

* 内存泄漏（应用 bug）

* ES/Lucene 占用过多 off-heap 内存

**排查：**

```bash
# 1. 确认是否被 OOM Kill
docker inspect mall-admin --format='{{.State.OOMKilled}}'
# 输出 true 表示曾被 OOM Kill

# 2. 查看 dmesg 中的 OOM 记录
sudo dmesg | grep -i "oom\|kill"
# 会显示哪个进程被杀了，当时内存状况如何

# 3. 查看当前内存使用
free -h
docker stats --no-stream

# 4. 查看 JVM 实际使用
docker exec mall-admin jcmd 1 GC.heap_info  # 如果镜像包含 jcmd
# 或
docker exec mall-admin java -XX:+PrintFlagsFinal -version 2>&1 | grep HeapSize
```

**解决方案（按优先级排列）：**

| 方案           | 操作                                                                                 | 预期效果          |
| ------------ | ---------------------------------------------------------------------------------- | ------------- |
| **减小 JVM 堆** | 修改 Dockerfile 中的 `JAVA_OPTS`: `-Xms128m -Xmx384m`                                  | 立竿见影          |
| **关闭不需要的服务** | `docker stop mall-monitor`（如果暂时不需要监控）                                              | 释放 \~300MB    |
| **添加 Swap**  | `sudo fallocate -l 2G /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile` | 增加 2GB 虚拟内存   |
| **ES 降配**    | `ES_JAVA_OPTS=-Xms128m -Xmx256m`                                                   | ES 释放 \~500MB |
| **升级服务器**    | 联系云厂商升级配置                                                                          | 根本解决          |

**添加 Swap 详细步骤：**

```bash
# 创建 2GB Swap 文件
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 验证
free -h
# 应看到 Swap 行有 2G

# 持久化（重启后仍然生效）
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

> ⚠️ **Swap 是双刃剑**：它能防止 OOM Kill，但如果频繁使用 Swap 会导致性能严重下降（磁盘比内存慢 100 倍以上）。Swap 只是应急手段，根本解决方案还是合理规划内存使用。

***

### 10.5 网络不通排查思路

#### 排查矩阵

```
                    目标
                容器A    容器B    公网    其他服务器
源              ─────   ─────   ─────   ──────────
容器A           ✅DNS    ✅DNS    ✅NAT   ❌需extra_hosts
宿主机          ✅端口映射 ✅端口映射 ✅直连  ✅直连
其他服务器      ❌需端口开放 ❌需端口开放 ✅直连  ✅直连
公网            ❌需端口开放 ❌需端口开放 ✅直连  ✅直连
```

#### 逐步排查命令

```bash
# ===== 第1层：容器内部网络 =====
# 容器能否解析域名？
docker exec mall-admin nslookup nacos-registry

# 容器能否 ping 通？
docker exec mall-admin ping -c 2 nacos-registry

# 容器端口是否监听？
docker exec mall-admin ss -tlnp

# ===== 第2层：Docker 网络层 =====
# 端口映射是否正确？
docker port mall-admin

# iptables 规则是否有？
sudo iptables -t nat -L DOCKER -n

# ===== 第3层：宿主机防火墙层 =====
# 防火墙是否放行？
sudo ufw status  # Ubuntu
sudo firewall-cmd --list-all  # CentOS

# ===== 第4层：云安全组层 =====
# 这一步要去云厂商控制台操作！
# 确认安全组入站规则包含了需要的端口

# ===== 第5层：跨服务器连通性 =====
# 从主服务器 telnet 扩展服务器的端口
telnet ${EXT_SERVER_IP} 9200

# 从扩展服务器 telnet 主服务器的端口
telnet ${MAIN_SERVER_IP} 8848
```

#### 常见网络问题速查

| 症状          | 可能原因                    | 解决方案                                       |
| ----------- | ----------------------- | ------------------------------------------ |
| 容器间 ping 不通 | 不在同一 Docker 网络          | 使用 `networks:` 配置加入同一网络                    |
| 宿主机访问不了容器端口 | 端口映射未配置或冲突              | 检查 `ports:` 配置                             |
| 公网访问不了      | 安全组/防火墙未开放端口            | 检查 2.6 节端口开放指南                             |
| 跨服务器容器不通    | extra\_hosts 未配置或 IP 错误 | 检查 docker-compose 中的 extra\_hosts          |
| DNS 解析失败    | Docker DNS 配置问题         | 重启 Docker: `sudo systemctl restart docker` |

***

## 附录

### 附录 A: 完整端口参考表

| 端口        | 协议  | 服务                      | 方向 | 开放范围    | 所在服务器 |
| --------- | --- | ----------------------- | -- | ------- | ----- |
| 22        | TCP | SSH                     | 入站 | 你的 IP   | 两台    |
| 80        | TCP | Nginx HTTP              | 入站 | 所有 IP   | 主服务器  |
| 443       | TCP | Nginx HTTPS             | 入站 | 所有 IP   | 主服务器  |
| 3306      | TCP | MySQL                   | 入站 | 内网/特定IP | 主服务器  |
| 6379      | TCP | Redis                   | 入站 | 内网      | 主服务器  |
| 8848      | TCP | Nacos                   | 入站 | 内网/你的IP | 主服务器  |
| 8201      | TCP | mall-gateway            | 入站 | 内网/你的IP | 主服务器  |
| 8080      | TCP | mall-admin              | 入站 | 内网/你的IP | 主服务器  |
| 8401      | TCP | mall-auth               | 入站 | 内网/你的IP | 主服务器  |
| 8085      | TCP | mall-portal             | 入站 | 内网/你的IP | 扩展服务器 |
| 8081      | TCP | mall-search             | 入站 | 内网/你的IP | 扩展服务器 |
| 8101      | TCP | mall-monitor            | 入站 | 内网/你的IP | 主服务器  |
| 9200      | TCP | Elasticsearch HTTP      | 入站 | 内网      | 扩展服务器 |
| 9300      | TCP | Elasticsearch Transport | 入站 | 内网      | 扩展服务器 |
| 27017     | TCP | MongoDB                 | 入站 | 内网      | 扩展服务器 |
| 5672      | TCP | RabbitMQ AMQP           | 入站 | 内网      | 扩展服务器 |
| 15672     | TCP | RabbitMQ Management     | 入站 | 内网/你的IP | 扩展服务器 |
| 4560-4563 | TCP | Logstash                | 入站 | 内网      | 扩展服务器 |
| 5601      | TCP | Kibana                  | 入站 | 内网/你的IP | 扩展服务器 |

***

### 附录 B: .env 文件完整模板

```bash
# ============================================
#  mall-swarm 部署环境变量
#  复制此文件为 .env 并修改所有占位符
# ============================================

# ----- 通用 -----
TIME_ZONE=Asia/Shanghai

# ----- MySQL（阶段1）-----
MYSQL_ROOT_PASSWORD=your_mysql_root_password    # ⚠️ 请修改！
MYSQL_DATABASE=mall
MYSQL_PORT=3306

# ----- Redis（阶段1）-----
REDIS_PORT=6379

# ----- Nacos（阶段1）-----
NACOS_PORT=8848

# ----- 阿里云 ACR（必须修改！）-----
ACR_REGISTRY=your-registry.cn-shenzhen.aliyuncs.com   # ⚠️ 替换为实际值
ACR_NAMESPACE=mall
ACR_USERNAME=your_aliyun_account_id                  # ⚠️ 替换为实际值
ACR_PASSWORD=your_acr_fixed_password                  # ⚠️ 替换为实际值
ACR_REGION=cn-shenzhen                                # 替换为实际地域

# ----- 镜像版本 -----
IMAGE_TAG=latest                                     # 或指定具体 commit hash

# ----- 服务器 IP（跨服务器通信必须配置）-----
MAIN_SERVER_IP=x.x.x.x                               # ⚠️ 替换为主服务器公网IP
EXT_SERVER_IP=x.x.x.x                                # ⚠️ 替换为扩展服务器公网IP

# ----- Elasticsearch（阶段2）-----
ES_JAVA_OPTS=-Xms256m -Xmx512m                       # 低配服务器优化值

# ----- RabbitMQ（阶段3）-----
RABBITMQ_DEFAULT_USER=mall
RABBITMQ_DEFAULT_PASS=mall                            # ⚠️ 生产环境请改强密码
```

***

### 附录 C: docker-compose 文件完整汇总

| 文件名                         | 用途      | 所在服务器 | 包含服务                                             |
| --------------------------- | ------- | ----- | ------------------------------------------------ |
| `docker-compose.base.yml`   | 基础微服务骨架 | 主服务器  | MySQL, Redis, Nacos, Nginx, Gateway, Admin, Auth |
| `docker-compose.search.yml` | 商品搜索服务  | 扩展服务器 | Elasticsearch, mall-search                       |
| `docker-compose.portal.yml` | 前台商城服务  | 扩展服务器 | MongoDB, RabbitMQ, mall-portal                   |
| `docker-compose.elk.yml`    | 日志监控    | 扩展服务器 | Logstash, Kibana, mall-monitor                   |

**组合使用方式：**

```bash
# 只启动基础骨架（阶段1）
docker compose -f docker-compose.base.yml up -d

# 启动阶段1 + 阶段2
docker compose -f docker-compose.base.yml -f docker-compose.search.yml up -d

# 启动全部（主服务器）
docker compose -f docker-compose.base.yml up -d

# 启动全部（扩展服务器）
docker compose -f docker-compose.search.yml -f docker-compose.portal.yml -f docker-compose.elk.yml up -d
```

***

### 附录 D: 推荐学习路径

如果你是第一次接触微服务和 Docker，建议按以下顺序学习：

```
第1周：基础入门
  ├─ Docker 基础概念（镜像、容器、卷、网络）
  ├─ 手动运行一个 Spring Boot 应用在 Docker 中
  └─ 理解 docker-compose.yml 的基本语法

第2周：mall-swarm 部署实践
  ├─ 按本文档完成阶段1部署（基础骨架）
  ├─ 理解 Nacos 注册中心和配置中心
  └─ 理解 API 网关的路由机制

第3周：深入微服务
  ├─ 完成阶段2~4的部署
  ├─ 阅读 mall-swarm 源码，理解服务间调用方式
  └─ 尝试修改一个接口并走通完整的 CI/CD 流程

第4周：进阶主题
  ├─ ELK 日志分析实战
  ├─ Spring Boot Admin 监控配置
  └─ Docker 网络原理（bridge/host/overlay）

推荐资源：
- 《Docker — 从入门到实践》（免费电子书）
- Spring Cloud Alibaba 官方文档
- Nacos 官方文档（https://nacos.io/zh-cn/docs/what-is-nacos.html）
- macrozheng 的 mall 系列教程（https://www.macrozheng.com/mall/）
```

***

### 附录 E: 从本方案进阶到 K8s 的方向指引

当你已经熟练掌握了 Docker Compose 部署方案后，可以考虑向 Kubernetes（K8s）进阶：

#### 为什么以及什么时候需要 K8s？

| 场景              | Docker Compose  | Kubernetes     |
| --------------- | --------------- | -------------- |
| 个人学习 / 小项目      | ✅ 足够            | 杀鸡用牛刀          |
| 2\~5 台服务器       | ✅ 可以管理          | 可以但复杂度高        |
| 需要自动扩缩容         | ❌ 手动操作          | ✅ HPA 自动水平扩展   |
| 需要滚动更新 / 金丝雀发布  | ❌ 不支持           | ✅ 原生支持         |
| 多团队协作 / 多环境     | ❌ 困难            | ✅ Namespace 隔离 |
| 需要 Self-healing | ⚠️ restart only | ✅ 自动检测并重建      |
| 50+ 个微服务        | ❌ 管理困难          | ✅ 声明式管理        |

#### 进阶路线图

```
当前状态: Docker Compose 部署 ✓
        │
        ▼
Step 1: 学习 K8s 核心概念（1~2 周）
  ├─ Pod vs Container（Pod 是什么？为什么需要一个 Pod 包装多个容器？）
  ├─ Service（ClusterIP / NodePort / LoadBalancer 各自用途）
  ├─ Deployment（声明式更新、滚动升级策略）
  ├─ ConfigMap & Secret（配置和敏感信息管理）
  └─ Ingress（统一入口，替代 Nginx 手动配置）

        │
        ▼
Step 2: 使用 minikube / kind 本地搭建 K8s 集群
  ├─ kind（Kubernetes in Docker）：最轻量，适合学习
  ├─ 将当前 docker-compose.yml 转换为 K8s manifests
  └─ 项目已有 k8s/ 目录下的 YAML 可作参考起点

        │
        ▼
Step 3: 云厂商托管 K8s（生产级）
  ├─ 阿里云 ACK（容器服务 Kubernetes 版）
  ├─ 腾讯云 TKE（容器服务）
  └─ 选择原因：免去 Master 节点运维，按量付费

        │
        ▼
Step 4: CI/CD 升级
  ├─ GitHub Actions → 构建 → 推送到 ACR
  ├─ kubectl set image 或 kubectl apply 滚动更新
  └─ 可选：ArgoCD 实现 GitOps（声明式持续交付）
```

#### 关键转换对照表

| Docker Compose 概念          | Kubernetes 对应                         |
| -------------------------- | ------------------------------------- |
| `service:` (定义容器)          | Deployment + Pod                      |
| `image:`                   | Container.image                       |
| `ports:`                   | Service (NodePort / LoadBalancer)     |
| `volumes:`                 | PersistentVolumeClaim                 |
| `environment:` + `.env`    | ConfigMap + Secret                    |
| `depends_on` + healthcheck | readinessProbe + livenessProbe        |
| `networks:`                | 同一 Namespace 下的 Pod 天然互通              |
| `restart: unless-stopped`  | Deployment 的 replicas 和 restartPolicy |
| `docker compose up -d`     | `kubectl apply -f deployment.yaml`    |
| `docker compose logs`      | `kubectl logs <pod>`                  |
| `docker compose ps`        | `kubectl get pods`                    |

> 💡 **核心思维转变**：Docker Compose 是「命令式」（告诉它怎么做），Kubernetes 是「声明式」（告诉它你想要什么状态，K8s 自己去达成那个状态）。这是理解 K8s 的关键。

***

> **文档结束**
>
> 如果你在部署过程中遇到本文档未覆盖的问题，欢迎到 mall-swarm 的 GitHub Issues 提问：
> <https://github.com/macrozheng/mall-swarm/issues>
>
> 祝部署顺利！🚀

