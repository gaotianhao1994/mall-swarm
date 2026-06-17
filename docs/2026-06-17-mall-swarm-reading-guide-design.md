# mall-swarm 微服务架构渐进式阅读指南设计文档

> 目标读者：有一定微服务基础但根基不够扎实的Java后端开发者
> 学习方式：跟着真实请求流转追踪，在过程中理解各组件角色

## 设计概览

采用**渐进式请求追踪**方式，分3个Phase由简到繁，每个Phase追踪一条真实的业务请求，覆盖2-3个微服务组件。每阶段结束形成独立的知识闭环，后续Phase自然叠加新组件。

| Phase | 请求场景 | 覆盖的微服务模式 | 涉及的中间件 | 复杂度 |
|-------|---------|----------------|------------|--------|
| Phase 1 | 用户登录 | Gateway路由 + Sa-Token认证 + Feign远程调用 | Redis(会话) | ⭐⭐ |
| Phase 2 | 商品浏览+搜索 | Gateway权限校验 + Nacos配置/发现 + ES搜索 | Redis(权限) + Nacos + ES | ⭐⭐⭐ |
| Phase 3 | 下单+支付+超时取消 | 异步消息解耦 + 分布式ID + 库存锁定 + 多数据源 | RabbitMQ + Redis(ID+库存) + MongoDB | ⭐⭐⭐⭐ |

每个Phase的知识直接支撑下一个：
- **Phase 1** 的Sa-Token认证 → **Phase 2** 在此基础上叠加权限校验
- **Phase 2** 的服务发现 → **Phase 3** 在此基础上叠加跨服务异步消息

---

## Phase 1：认证请求流「用户登录」

### 追踪请求

`POST http://localhost:8201/mall-auth/auth/login?clientId=admin-app&username=admin&password=123456`

### 请求流转路径

```
前端发起登录请求(8201端口)
  → mall-gateway: 路由匹配 /mall-auth/** → lb://mall-auth + 白名单放行
  → mall-auth: AuthController 按 clientId 分流
      admin-app → @FeignClient("mall-admin") 远程调用
      portal-app → @FeignClient("mall-portal") 远程调用
  → mall-admin: UmsAdminController.login() 执行登录逻辑
  → Sa-Token JWT: StpUtil.login(adminId) → Redis存储会话 → 返回token
  → 返回 CommonResult.success(tokenMap)
```

### 需读文件清单（共10个，按阅读顺序）

| # | 文件路径 | 关注点 | 难度 |
|---|---------|--------|------|
| 1 | `mall-gateway/src/main/resources/application.yml` (L19-79) | 路由规则：`lb://mall-auth`是什么意思？白名单：`/mall-auth/**`为什么在白名单里？ | ⭐ |
| 2 | `mall-gateway/src/main/java/com/macro/mall/config/IgnoreUrlsConfig.java` | `@ConfigurationProperties(prefix="secure.ignore")`如何将yaml白名单映射到Java对象 | ⭐ |
| 3 | `mall-gateway/src/main/java/com/macro/mall/config/SaTokenConfig.java` | **核心！** 看`SaReactorFilter`如何拦截所有请求、白名单放行、按路径匹配做认证 | ⭐⭐⭐ |
| 4 | `mall-auth/src/main/java/com/macro/mall/auth/controller/AuthController.java` | clientId分流：admin-app走`UmsAdminService`，portal-app走`UmsMemberService` | ⭐⭐ |
| 5 | `mall-auth/src/main/java/com/macro/mall/auth/service/UmsAdminService.java` | `@FeignClient("mall-admin")`如何声明远程调用接口 | ⭐⭐ |
| 6 | `mall-auth/src/main/java/com/macro/mall/auth/service/UmsMemberService.java` | `@FeignClient("mall-portal")`同理 | ⭐⭐ |
| 7 | `mall-admin/src/main/java/com/macro/mall/controller/UmsAdminController.java` (L54-66) | `login()`方法如何接收Feign调用、返回`SaTokenInfo` | ⭐⭐ |
| 8 | `mall-admin/src/main/java/com/macro/mall/service/impl/UmsAdminServiceImpl.java` (L88-118) | 登录核心逻辑：BCrypt密码校验 → `StpUtil.login()` → Session存UserDto → 返回token | ⭐⭐⭐ |
| 9 | `mall-admin/src/main/java/com/macro/mall/config/SaTokenConfigure.java` | JWT Simple模式：`StpLogicJwtForSimple`是什么（token是JWT格式，会话数据仍存Redis） | ⭐⭐ |
| 10 | `mall-gateway/src/main/java/com/macro/mall/util/StpMemberUtil.java` (前50行) | 多账号体系：TYPE="memberLogin" vs 默认StpUtil的TYPE="login"，两套独立登录态 | ⭐⭐ |

### Phase 1 学到的微服务知识点

1. **Gateway路由机制** — `predicates`（路径匹配）+ `filters`（StripPrefix去掉前缀）+ `lb://`（负载均衡+服务发现）
2. **Gateway白名单** — `ConfigurationProperties`绑定yaml到Java对象，`SaReactorFilter`排除白名单路径
3. **Sa-Token网关鉴权** — 全局过滤器模式，按URL模式分别做admin/member认证
4. **OpenFeign跨服务调用** — Auth服务通过Feign调用Admin/Portal，体现"认证与业务分离"的架构设计
5. **Sa-Token多账号体系** — `StpUtil`管后台管理员，`StpMemberUtil`管前台会员，两套独立登录态
6. **JWT Simple模式** — token本身是JWT格式，但会话数据仍存Redis（不是纯JWT无状态）

---

## Phase 2：读请求流「商品浏览 + 搜索」

这一阶段追踪两条读请求，分别经过 mall-admin（需鉴权+权限）和 mall-search（白名单免鉴权），让你对比理解"已登录请求"和"公开请求"在网关中的不同处理路径。

### 请求 A：后台管理员查看商品列表（需鉴权+权限）

**追踪请求：** `GET http://localhost:8201/mall-admin/product/list?pageSize=5&pageNum=1`
**请求头：** `Authorization: Bearer xxx-token-xxx`

```
前端携带token请求商品列表
  → Gateway路由: /mall-admin/** → lb://mall-admin (StripPrefix=1)
  → SaReactorFilter: StpUtil.checkLogin() 登录校验
  → 权限校验: Redis读取pathResourceMap + AntPathMatcher匹配 + StpUtil.checkPermissionOr()
  → mall-admin: PmsProductController.list()
  → PmsProductService → PageHelper.startPage分页 → MyBatis Mapper查询
  → 返回 CommonResult<CommonPage<PmsProduct>>
```

### 请求 B：前台用户搜索商品（免鉴权，白名单）

**追踪请求：** `GET http://localhost:8201/mall-search/esProduct/search/simple?keyword=手机`

```
前台无token请求搜索商品
  → Gateway路由: /mall-search/** → lb://mall-search (StripPrefix=1)
  → 白名单放行: /mall-search/** 在 IgnoreUrlsConfig 中，跳过Sa-Token认证
  → mall-search: EsProductController.search()
  → EsProductService → Elasticsearch Spring Data ES查询
  → 返回 CommonResult<CommonPage<EsProduct>>
```

### Phase 2 需读文件清单（共12个，按阅读顺序）

| # | 文件路径 | 关注点 | 难度 |
|---|---------|--------|------|
| **请求A——鉴权链路** ||||
| 1 | `mall-gateway/src/main/resources/application.yml` (L56-79) | 回看白名单，`/mall-admin/admin/login`在白名单但`/mall-admin/product/list`不在 | ⭐ |
| 2 | `mall-gateway/src/main/java/com/macro/mall/config/SaTokenConfig.java` (L46-73) | **核心重读！** 权限校验：Redis pathResourceMap + AntPathMatcher + StpUtil.checkPermissionOr() | ⭐⭐⭐ |
| 3 | `mall-gateway/src/main/java/com/macro/mall/component/StpInterfaceImpl.java` | Sa-Token如何获取用户权限列表：从Session取出`UserDto.permissionList` | ⭐⭐ |
| 4 | `mall-admin/src/main/java/com/macro/mall/service/impl/UmsAdminServiceImpl.java` (L88-118) | 回看login方法：往Session存了`UserDto`含`permissionList`（`resourceId:resourceName`格式） | ⭐⭐⭐ |
| 5 | `mall-admin/src/main/java/com/macro/mall/controller/PmsProductController.java` (L62-70) | 分页查询模式：`PageHelper.startPage` + `CommonPage.restPage` | ⭐⭐ |
| 6 | `mall-mbg/src/main/java/com/macro/mall/model/PmsProduct.java` | 只看字段定义，理解商品数据模型（MBG生成的） | ⭐ |
| **请求B——ES搜索链路** ||||
| 7 | `mall-gateway/src/main/resources/application.yml` (L19-49) | 路由`lb://mall-search`和`/mall-search/**`白名单放行 | ⭐ |
| 8 | `mall-search/src/main/java/com/macro/mall/search/controller/EsProductController.java` (L67-75) | 简单搜索：keyword + pageNum + pageSize → esProductService.search() | ⭐⭐ |
| 9 | `mall-search/src/main/java/com/macro/mall/search/service/EsProductService.java` | ES搜索Service接口定义 | ⭐ |
| 10 | `mall-search/src/main/java/com/macro/mall/search/dao/EsProductDao.java` | MySQL→ES数据导入的自定义Dao | ⭐⭐ |
| **Nacos配置中心** ||||
| 11 | `mall-gateway/src/main/resources/application-dev.yml` | `spring.cloud.nacos`：discovery + config + `spring.config.import: nacos:mall-gateway-dev.yaml` | ⭐⭐ |
| 12 | `config/gateway/mall-gateway-dev.yaml` | Nacos远程配置内容（Redis、Logstash等） | ⭐ |

### Phase 2 学到的微服务知识点

1. **Gateway权限校验完整链路** — 请求进入 → 登录校验 → 从Redis取权限规则 → AntPathMatcher匹配路径 → Sa-Token checkPermissionOr()校验
2. **权限数据如何流转** — Admin登录时：查询用户资源 → 拼成`id:name`格式 → 存入Sa-Token Session → Gateway需要时通过StpInterfaceImpl取出
3. **MyBatis + PageHelper分页模式** — `PageHelper.startPage()`拦截下一条SQL → 自动加LIMIT → `CommonPage.restPage()`封装分页结果
4. **Nacos配置中心机制** — 本地application-dev.yml只配Nacos地址 → `spring.config.import`拉取远程yaml → 远程配置覆盖本地默认值
5. **Elasticsearch集成模式** — MySQL数据通过EsProductDao导入ES → Spring Data Elasticsearch Repository搜索 → Controller返回CommonPage<EsProduct>
6. **公开接口 vs 鉴权接口** — 白名单机制让搜索等公开接口无需token即可访问，后台管理接口必须经过完整的登录+权限校验

---

## Phase 3：写请求流「下单 + 支付 + 超时取消」

这是最复杂的阶段，涉及跨数据源（MySQL + Redis + MongoDB + RabbitMQ）和异步消息解耦。

### 追踪请求：前台会员下单

**追踪请求：** `POST http://localhost:8201/mall-portal/order/generateOrder`
**请求头：** `Authorization: Bearer xxx-member-token-xxx`

```
前台会员下单请求(携带会员token)
  → Gateway路由: /mall-portal/** → lb://mall-portal (StripPrefix=1)
  → SaReactorFilter: StpMemberUtil.checkLogin() 会员登录校验
  → OmsPortalOrderController.generateOrder()
  → OmsPortalOrderServiceImpl.generateOrder() [@Transactional]
      ├─ 校验: 收货地址 + 库存 + 优惠券 + 积分
      ├─ 金额计算: 总金额 → 促销优惠 → 优惠券抵扣 → 积分抵扣 → 实付金额
      ├─ 锁定库存: lockStock() 更新 PmsSkuStock.lockStock
      ├─ Redis生成订单号: generateOrderSn() (8位日期+2位来源+2位支付+6位自增ID)
      ├─ MySQL插入: order表 + order_item表
      ├─ 优惠券/积分状态更新
      ├─ 清除购物车已下单商品
      ├─ RabbitMQ发送延迟消息: sendDelayMessageCancelOrder(orderId)
      │   → TTL队列(mall.order.cancel.ttl) → 超时后死信转发 → 消费队列(mall.order.cancel)
      │   → CancelOrderReceiver → cancelOrder() → 恢复库存+返还优惠券+返还积分
      └─ MongoDB: MemberReadHistory 浏览记录(非核心数据存MongoDB)
```

### 支付成功回调

**追踪请求：** `POST http://localhost:8201/mall-portal/order/paySuccess?orderId=xxx&payType=1`

```
支付宝回调paySuccess
  → 修改订单状态: 待付款(0) → 待发货(1)
  → 释放锁定库存 + 扣减真实库存: portalOrderDao.updateSkuStock()
```

### Phase 3 需读文件清单（共10个，按阅读顺序）

| # | 文件路径 | 关注点 | 难度 |
|---|---------|--------|------|
| **下单核心链路** ||||
| 1 | `mall-portal/src/main/java/com/macro/mall/portal/controller/OmsPortalOrderController.java` (L40-46) | 下单入口：`generateOrder(@RequestBody OrderParam)` | ⭐ |
| 2 | `mall-portal/src/main/java/com/macro/mall/portal/service/impl/OmsPortalOrderServiceImpl.java` (L93-250) | **最核心！** generateOrder()全流程：校验→金额计算→锁库存→插入订单→发延迟消息→清购物车 | ⭐⭐⭐⭐ |
| 3 | 同上 (L439-454) | generateOrderSn()：8位日期+2位来源+2位支付+Redis自增ID | ⭐⭐⭐ |
| 4 | 同上 (L327-334) | sendDelayMessageCancelOrder()：获取超时时间→调用cancelOrderSender.sendMessage() | ⭐⭐ |
| **RabbitMQ延迟消息** ||||
| 5 | `mall-portal/src/main/java/com/macro/mall/portal/config/RabbitMqConfig.java` | 死信队列配置：TTL队列绑定死信交换机 → 超时后转发到实际消费队列 | ⭐⭐⭐ |
| 6 | `mall-portal/src/main/java/com/macro/mall/portal/domain/QueueEnum.java` | 两个队列枚举：QUEUE_ORDER_CANCEL(消费) + QUEUE_TTL_ORDER_CANCEL(延迟) | ⭐⭐ |
| 7 | `mall-portal/src/main/java/com/macro/mall/portal/component/CancelOrderSender.java` | 发送端：amqpTemplate.convertAndSend() + 设置消息过期时间 | ⭐⭐ |
| 8 | `mall-portal/src/main/java/com/macro/mall/portal/component/CancelOrderReceiver.java` | 消费端：@RabbitListener(queues="mall.order.cancel") → cancelOrder() | ⭐⭐ |
| **支付+MongoDB** ||||
| 9 | `mall-portal/src/main/java/com/macro/mall/portal/service/impl/OmsPortalOrderServiceImpl.java` (L252-265) | paySuccess()：修改订单状态 → 释放锁库存 → 扣减真实库存 | ⭐⭐ |
| 10 | `mall-portal/src/main/java/com/macro/mall/portal/service/MemberReadHistoryService.java` | MongoDB浏览历史接口：create/delete/list/clear | ⭐⭐ |

### Phase 3 学到的微服务知识点

1. **RabbitMQ死信队列延迟消息模式** — 电商最经典的设计：
   - 下单时 → 发消息到TTL队列（设置过期时间 = 订单超时时间）
   - TTL队列无消费者 → 消息过期后成为"死信" → 自动转发到消费交换机
   - CancelOrderReceiver监听消费队列 → 执行取消逻辑
   - 如果用户在超时前支付了 → paySuccess()修改订单状态，延迟消息到达时发现订单已付款就不取消

2. **Redis分布式ID生成** — generateOrderSn()用Redis INCR保证订单号全局唯一且自增，避免数据库序列的性能瓶颈

3. **库存锁定机制** — 下单时锁定库存(lockStock)，支付后释放锁定并扣减真实库存，超时未支付则释放锁定

4. **@Transactional在微服务中的局限** — generateOrder()有@Transactional，但它只保证单个MySQL数据库的事务一致性。跨服务需要Seata分布式事务，本项目简化为同库操作

5. **MongoDB用于非核心数据** — 浏览历史存在MongoDB而非MySQL，体现"核心数据MySQL + 非核心数据MongoDB"的存储分层思想

6. **会员鉴权 vs 管理员鉴权** — Phase 1已学过StpUtil，Phase 3对比看StpMemberUtil.checkLogin()（TYPE="memberLogin"）的不同体系

---

## 附录：项目全局速览

### 模块职责对照表

| 层次 | 模块 | 文件规模 | 核心职责 |
|------|------|----------|----------|
| 基础设施层 | mall-common | ~10个包 | 通用返回体CommonResult、异常、常量、日志 |
| 数据层 | mall-mbg | 76个mapper+152个model | MyBatisGenerator生成的全量数据模型 |
| 网关层 | mall-gateway | ~6个文件 | Spring Cloud Gateway + Sa-Token路由鉴权 + 跨域 |
| 认证层 | mall-auth | ~5个文件 | 统一登录（admin-app / portal-app双clientId） |
| 业务层-后台 | mall-admin | 31 controller + 32 service + 29 dto | 后台管理全业务 |
| 业务层-前台 | mall-portal | 13 controller + 16 service | 移动端商城 |
| 业务层-搜索 | mall-search | 1 controller + 2 service | Elasticsearch商品搜索 |
| 运维层 | mall-monitor | 小 | Spring Boot Admin监控 |

### 各服务端口与配置

| 服务 | 端口 | 本地配置文件 | Nacos远程配置 |
|------|------|-------------|-------------|
| mall-gateway | 8201 | application.yml + application-dev.yml | mall-gateway-dev.yaml |
| mall-auth | 8401 | application.yml + application-dev.yml | mall-auth-dev.yaml |
| mall-admin | 8080 | application.yml + application-dev.yml | mall-admin-dev.yaml |
| mall-portal | 8085 | application.yml + application-dev.yml | mall-portal-dev.yaml |
| mall-search | 8081 | application.yml + application-dev.yml | mall-search-dev.yaml |

### 核心代码模式

- Controller → Service → Dao(mapper) → Model(mbg生成)，经典三层架构
- 统一返回 CommonResult<T> + 分页 CommonPage<T>
- Sa-Token替代Spring Security OAuth2做认证授权
- 配置全部放Nacos（config/目录下的yaml文件）
