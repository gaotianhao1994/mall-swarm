# mall-swarm 部署 — 换机交接文档

> **创建时间**: 2026-06-11
> **用途**: 在新电脑上从零恢复工作环境，无缝衔接当前进度

---

## 一、当前状态速览

### 项目是什么？
mall-swarm 微服务商城系统的 **Docker 生产级部署**，目标是在两台云服务器上通过 5 个渐进式阶段完成部署。

### 目前做到哪了？

| 事项 | 状态 |
|------|------|
| 两台 Ubuntu 22.04 LTS 服务器就绪 | ✅ 完成 |
| SSH 免密登录（root）配好 | ✅ 完成 |
| 腾讯云 root 密码已修改 | ✅ 完成 |
| Docker 安装 | ❌ **下一步要做** |
| Git 安装 | ❌ 待做 |
| 克隆项目到 /opt | ❌ 待做 |
| 阶段1 基础骨架部署 | ❌ 待做 |

**一句话总结：环境准备刚起步，接下来从装 Docker 开始。**

---

## 二、在新电脑上的操作步骤

### Step 1：安装 Trae IDE

- 下载安装 Trae IDE（如果公司电脑还没装）
- 登录账号，确保能访问本项目

### Step 2：配置 SSH 密钥

新电脑没有 SSH 密钥，需要生成并推送到两台服务器：

```powershell
# 1. 生成新的 SSH 密钥对（一路回车即可）
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"

# 2. 把公钥推送到腾讯云
type $env:USERPROFILE\.ssh\id_rsa.pub | ssh root@106.53.106.41 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"

# 3. 把公钥推送到阿里云
type $env:USERPROFILE\.ssh\id_rsa.pub | ssh root@8.134.65.121 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
```

> ⚠️ 上面的 `ssh` 命令会要求输入密码（见下方"关键密码"部分）

### Step 3：配置 SSH config（方便后续操作）

创建/编辑 `C:\Users\你的用户名\.ssh\config`，写入以下内容：

```
Host aliyun-server
    HostName 8.134.65.121
    User root
    Port 22
    IdentityFile ~/.ssh/id_rsa

Host tengxun-server
    HostName 106.53.106.41
    User root
    Port 22
    IdentityFile ~/.ssh/id_rsa

Host github.com
    ProxyCommand connect -S 127.0.0.1:1081 -a none %h %p
```

> 最后一条 `github.com` 的代理配置，根据公司网络情况决定是否保留。如果公司网络能直连 GitHub 就删掉这行。

### Step 4：克隆项目

```powershell
git clone git@github.com:gaotianhao1994/mall-swarm.git e:\projects\202606\mall-swarm
cd e:\projects\202606\mall-swarm
```

### Step 5：用 Trae IDE 打开项目，开始部署

打开 `docs/docker-deployment-guide.md`，从 **第 2 章 2.2 安装 Docker** 开始执行。

同时参考三个进度文档追踪状态：
- `docs/progress-tencent-cloud.md` — 腾讯云进度
- `docs/progress-alibaba-cloud.md` — 阿里云进度
- `docs/progress-overview.md` — 总进度看板

---

## 三、关键信息备忘（重要！请妥善保存）

### 服务器信息

| 服务器 | 公网 IP | 系统 | 配置 | SSH 别名 |
|--------|---------|------|------|---------|
| 腾讯云 主服务器 | `106.53.106.41` | Ubuntu 22.04 | 4核4G | `tengxun-server` |
| 阿里云 扩展服务器 | `8.134.65.121` | Ubuntu 22.04 | 2核4G | `aliyun-server` |

### 密码信息

| 用途 | 密码 | 说明 |
|------|------|------|
| 腾讯云 root 密码 | `Tx@Mall2026Secure!` | 紧急备用（平时用免密登录） |
| 阿里云 root 密码 | （你自己设的，记在这里：__________） | 紧急备用 |

> **建议**: 把这些密码抄到公司的密码管理器或纸质笔记中。

### GitHub 仓库

```
git@github.com:gaotianhao1994/mall-swarm.git
```

---

## 四、接下来的部署路线图

在新电脑上完成 Steps 1~4 后，按以下顺序推进：

```
Step 5: 两台服务器并行安装 Docker（文档 2.2 节）
   │
   ├─ 腾讯云：ssh tengxun-server → 执行 Docker 安装命令
   └─ 阿里云：ssh aliyun-server → 执行同样的命令
   │
Step 6: 安装 Docker Compose + Git + 验证（文档 2.3~2.5 节）
   │
Step 7: 开放安全组端口（文档 2.6 节）
   │
   ├─ 腾讯云控制台 → 安全组 → 开放 22,80,3306,6379,8848,8201,8080,8401
   └─ 阿里云控制台 → 安全组 → 开放 22,9200,27017,5672,15672,5601
   │
Step 8: 配置 Hosts + 克隆项目（文档 2.7 节 + 3.5 节）
   │
Step 9: 进入第3章 基础设施准备（ACR、GitHub Actions...）
   │
Step 10: 进入第4章 阶段1 基础骨架部署
```

---

## 五、docs 目录下的文件说明

打开项目后，`docs/` 文件夹里有 4 个文件，用途如下：

| 文件名 | 用途 | 什么时候看 |
|--------|------|-----------|
| `docker-deployment-guide.md` | **完整部署指南**（操作手册） | **主要参考文档，每一步都按它来** |
| `progress-overview.md` | 总进度看板 + 架构图 + 里程碑 | 了解全局进度时看 |
| `progress-tencent-cloud.md` | 腾讯云详细 checklist + 问题日志 | 操作腾讯云时逐项勾选 |
| `progress-alibaba-cloud.md` | 阿里云详细 checklist + 内存预警表 | 操作阿里云时逐项勾选 |
| **本文件** `handover-new-computer.md` | **换机交接文档（你正在看的这个）** | 新电脑首次配置时看 |

---

## 六、常见问题

### Q: 公司电脑连不上 GitHub 怎么办？
A: `docker-deployment-guide.md` 中的 GitHub Actions 部分（第3章）需要推送代码到 GitHub。如果公司网络不能访问 GitHub：
- 方案1：使用手机热点临时操作
- 方案2：确认 `.ssh/config` 中 github.com 的代理配置是否可用
- 方案3：这部分可以回家再做，先完成不需要 GitHub 的步骤（Docker 安装、基础中间件启动等）

### Q: SSH 连接提示权限被拒绝？
A: 确认公钥已正确推送（Step 2），且 `.ssh/config` 中路径正确。

### Q: 忘了 root 密码怎么办？
A: 通过云厂商控制台的「重置密码」功能重置（腾讯云控制台 / 阿里云控制台都有这个功能）。

---

## 七、快速验证清单

在新电脑上完成后，逐一确认：

- [ ] Trae IDE 已安装并能打开项目
- [ ] `ssh tengxun-server` 能免密登录（或输密码能登录）
- [ ] `ssh aliyun-server` 能免密登录（或输密码能登录）
- [ ] 项目已 clone 到本地
- [ ] 打开 `docs/docker-deployment-guide.md`，定位到 2.2 节
- [ ] 准备好开始执行 Docker 安装命令

全部打勾后，就可以无缝继续部署了。
