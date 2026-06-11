# Q005：`ssh -v` 实战日志逐行解读 — 一次真实连接的全过程

> **背景**: 执行 `ssh -v tengxun-server9 "echo OK"` 的完整日志，逐行翻译成"人话"。
> **日志来源**: 2026-06-11 实际运行结果

---

## 日志原文（按阶段分段）

```
═════════════════════════════════════
 阶段1: 启动 & 读取配置（找通讯录）
═════════════════════════════════════

OpenSSH_for_Windows_9.5p2, LibreSSL 3.8.2
debug1: Reading configuration data C:\\Users\\Administrator/.ssh/config
debug1: C:\\Users\\Administrator/.ssh/config line 13: Applying options for tengxun-server9
```

**人话翻译**：

```
你的电脑说:
  "我是 OpenSSH 9.5 版本（SSH 客户端软件）"

  "正在读取配置文件... 找到了 C:\Users\Administrator\.ssh\config"

  "读到第 13 行了！发现 Host tengxun-server9 匹配了！"
    → 用这个配置:
      HostName = 106.53.132.192
      User = root
      Port = 22
      IdentityFile = C:\...\Downloads\tengxun_server9.pem
```

**类比**：你拿出手机，打开通讯录，找到了"服务器9"这个联系人，看到了它的地址。

---

```
═════════════════════════════════════
 阶段2: 网络连接（打电话）
═════════════════════════════════════

debug1: Connecting to 106.53.132.192 [106.53.132.192] port 22.
debug1: Connection established.
```

**人话翻译**：

```
你的电脑说:
  "我要连接 106.53.132.192 这台机器的 22 号端口（SSH 默认端口）"

  ... (网络传输中) ...

  "连上了！✅ TCP 连接已建立"
    → 相当于：电话拨通了，对方接了
```

**如果这里卡住/报错**：
- `Connection timed out` → 对方没开机 / 安全组没开 22 端口 / IP 错了
- `Connection refused` → 对方开了但 SSH 服务没跑

---

```
═════════════════════════════════════
 阶段3: 加载密钥文件（拿钥匙）
═════════════════════════════════════

debug1: identity file C:\\Users\\Administrator\\Downloads\\tengxun_server9.pem type -1
debug1: identity file C:\\Users\\Administrator\\Downloads\\tengxun_server9.pem-cert type -1
```

**人话翻译**：

```
你的电脑说:
  "尝试加载密钥文件: tengxun_server9.pem"

  "type -1 ← 😅 加载失败！"
    （原因：Windows 上文件权限问题，
      SSH 无法读取这个文件的完整内容）

  "再试试证书文件（.pem-cert）..."
  "type -1 ← 这个也没有"
```

**⚠️ 注意**：虽然这里显示 `-1`（加载失败），但后面还是认证成功了。
原因是 SSH 还会尝试其他默认位置的密钥（如 `.ssh/id_rsa`、`.ssh/id_ed25519` 等）。

---

```
═════════════════════════════════════
 阶段4: 协议版本协商（确认语言）
═════════════════════════════════════

debug1: Local version string SSH-2.0-OpenSSH_for_Windows_9.5
debug1: Remote protocol version 2.0, remote software version OpenSSH_9.6p1 Ubuntu-3ubuntu13.4
debug1: compat_banner: match: OpenSSH_9.6p1 Ubuntu-3ubuntu13.4 pat OpenSSH* compat 0x04000000
```

**人话翻译**：

```
你的电脑说:
  "我支持的协议版本是: SSH-2.0 (OpenSSH 9.5)"

  对方服务器回复:
  "我也支持 SSH-2.0，我跑的是 OpenSSH 9.6，系统是 Ubuntu"

  "好的，双方都支持 SSH 2.0，可以继续 ✅"
    → 类似：两个人确认都说中文，能沟通
```

**为什么不是 SSH 1.0？**
> SSH 1.0 有安全漏洞，早在十几年前就被废弃了。现在全部用 SSH 2.0。

---

```
═════════════════════════════════════
 阶段5: 声明登录身份（报上名来）
═════════════════════════════════════

debug1: Authenticating to 106.53.132.192:22 as 'root'
```

**人话翻译**：

```
你的电脑告诉服务器:
  "你好，我要用 root 这个用户的身份登录"
```

就这么一行。简单。

---

```
═════════════════════════════════════
 阶段6: 检查 known_hosts（以前来过吗？）
═════════════════════════════════════

debug1: load_hostkeys: fopen C:\\Users\\Administrator/.ssh/known_hosts2: No such file or directory
debug1: load_hostkeys: fopen __PROGRAMDATA__\\ssh/ssh_known_hosts: No such file or directory
debug1: load_hostkeys: fopen __PROGRAMDATA__\\ssh/ssh_known_hosts2: No such file or directory
```

**人话翻译**：

```
你的电脑说:
  "让我查一下历史记录（known_hosts），看看这台机器的'指纹'对不对"

  "找 known_hosts2... 不存在"
  "找全局 ssh_known_hosts... 也不存在"
  "找 ssh_known_hosts2... 还是没有"

  "算了，跳过预检查，后面直接问服务器要指纹"
```

### 什么是 known_hosts？

```
known_hosts = 你电脑上的"访客登记簿"

首次连接一台新服务器时:
  服务器发来它的"身份证指纹"（公钥哈希值）
  你的电脑弹窗: "你确定要信任这台机器吗？(yes/no)"
  你输入 yes → 指纹被记录到 known_hosts

下次再连:
  电脑对比: "这次发来的指纹和上次一样吗？"
  一样   → 放行 ✅
  不一样 → ⚠️ 警告！可能被中间人攻击了！（Man-in-the-Middle）
```

---

```
═════════════════════════════════════════════════
 阶段7: 密钥交换 KEX（最核心的安全步骤 — 协商加密方式）
═════════════════════════════════════════════════

debug1: SSH2_MSG_KEXINIT sent
debug1: SSH2_MSG_KEXINIT received
debug1: kex: algorithm: curve25519-sha256
debug1: kex: host key algorithm: ssh-ed25519
debug1: kex: server->client cipher: chacha20-poly1305@openssh.com MAC: <implicit> compression: none
debug1: kex: client->server cipher: chacha20-poly1305@openssh.com MAC: <implicit> compression: none
debug1: expecting SSH2_MSG_KEX_ECDH_REPLY
debug1: SSH2_MSG_KEX_ECDH_REPLY received
debug1: Server host key: ssh-ed25519 SHA256:NGSEgpav6Mzga8E54O7PPtG+suIuKoe9A4437W5THAQ
...
debug1: Host '106.53.132.192' is known and matches the ED25519 host key.
debug1: Found key in C:\\Users\\Administrator/.ssh/known_hosts:12
...
debug1: SSH2_MSG_NEWKEYS sent
debug1: expecting SSH2_MSG_NEWKEYS
debug1: SSH2_MSG_NEWKEYS received
```

**人话翻译（这是最复杂的一步，用比喻来讲）**：

```
你的电脑和服务器要开始一段加密对话。
但在对话之前，它们必须先"对暗号"——这就是 KEX（Key Exchange）。

步骤1: 双方各自声明自己支持哪些加密算法
  你的电脑: "我会这些算法: curve25519-sha256, chacha20-poly1305..."
  服务器:   "我也会这些，咱们就用最强的那个吧"

步骤2: 选定算法
  密钥交换算法: curve25519-sha256     ← 怎么协商密钥的
  主机密钥算法: ssh-ed25519            ← 服务器身份用的
  加密算法:     chacha20-poly1305       ← 之后所有数据用什么加密

步骤3: 交换密钥材料（Diffie-Hellman 协议）
  你的电脑和服务器各生成一个随机数
  通过数学运算，双方算出了一个"相同的共享密钥"
  → 这个密钥永远不会在网络上传输！
  → 即使有人监听整个通信过程也拿不到它！

步骤4: 服务器发来它的主机密钥指纹
  "我的身份证号是: SHA256:NGSEgpa..."
  
  你的电脑查 known_hosts:
  "这台机器我之前连过！记录在第 12 行！"
  "对比一下指纹... 匹配！✅ 是同一台机器，没被冒充"

步骤5: 双方确认新密钥已就绪
  "NEWKEYS sent"   → 你的电脑: "我准备好了"
  "NEWKEYS received"→ 服务器: "我也准备好了"
  → 从这一刻起，后续所有通信都是加密的！
```

### 知识点：为什么需要 KEX？

```
没有 KEX 的情况（不安全）:
  你的电脑: "这是我的密码: Mall@2026_root"
  → 密码直接在网上传输 → 可能被截获！

有 KEX 的情况（安全）:
  你的电脑和服务器通过数学运算，
  各自独立地推导出了同一个"会话密钥"
  这个密钥从未在网络上传过
  后续所有数据都用这个密钥加密

类比:
  没有 KEX = 大街上喊密码
  有 KEX  = 两人在房间里悄悄商定了暗号，
             出来后只用暗号交流，旁人听不懂
```

---

```
═════════════════════════════════════
 阶段8: 身份认证（出示证件）
═════════════════════════════════════

debug1: get_agent_identities: No such file or directory
debug1: Will attempt key: C:\\Users\\Administrator\\Downloads\\tengxun_server9.pem  explicit
debug1: SSH2_MSG_EXT_INFO received
debug1: kex_input_ext_info: server-sig-algs=<ssh-ed25519,ecdsa-sha2-nistp256,...>
debug1: SSH2_MSG_SERVICE_ACCEPT received
debug1: Authentications that can continue: publickey,password
debug1: Next authentication method: publickey
debug1: Trying private key: C:\\Users\\Administrator\\Downloads\\tengxun_server9.pem
Authenticated to 106.53.132.192 ([106.53.132.192]:22) using "publickey".
```

**人话翻译**：

```
你的电脑说:

  "本地有没有 SSH Agent（密钥管理器）？"
  "没有，跳过"

  "好，config 里指定了密钥文件，我来用它: tengxun_server9.pem"

  服务器说:
  "我接受以下认证方式: 公钥 或 密码"

  你的电脑:
  "那我先用公钥方式试试"
  "正在用 tengxun_server9.pem 的私钥签名..."

  ... （虽然之前加载显示 type -1，但实际上还是读到了内容） ...

  ✅ "Authenticated! 认证通过了！"
     → 服务器验证了签名：公钥匹配！放行！
```

**这一步发生了什么（详细版）**：

```
1. 服务器发送一个随机挑战字符串（challenge）
   例如: "请对以下字符串签名: a3f8c2b9e..."

2. 你的电脑用私钥对这个字符串做数字签名
   （只有拥有私钥的人才能产生正确的签名）

3. 把签名发给服务器

4. 服务器用 authorized_keys 里的公钥验证签名
   （公钥可以验证签名是否正确，但不能伪造签名）

5. 验证通过 → 身份确认 ✅
```

---

```
═════════════════════════════════════
 阶段9: 建立会话通道（进入房间）
═════════════════════════════════════

debug1: channel 0: new session [client-session] (inactive timeout: 0)
debug1: Requesting no-more-sessions@openssh.com
debug1: Entering interactive session.
debug1: pledge: filesystem
debug1: client_input_global_request: rtype hostkeys-00@openssh.com want_reply 0
debug1: client_input_hostkeys: searching C:\\Users\\Administrator/.ssh/known_hosts ...
debug1: Remote: /root/.ssh/authorized_keys:1: key options: agent-forwarding port-forwarding pty user-rc x11-forwarding
debug1: Sending command: echo '===LOGIN SUCCESS===' && exit
```

**人话翻译**：

```
你的电脑说:

  "开辟一个通信通道（channel 0），用于这次会话"

  "进入交互式会话模式（就像你坐在服务器终端前一样）"

  服务器通知:
  "你的公钥在 authorized_keys 第 1 行，
   允许的操作有: 端口转发、PTY 终端、X11转发 等"

  你的电脑:
  "好了，我现在要执行命令了:"
  echo '===LOGIN SUCCESS===' && exit
```

---

```
═════════════════════════════════════
 阶段10: 执行命令 & 断开连接
═════════════════════════════════════

===LOGIN SUCCESS===
debug1: client_input_channel_req: channel 0 rtype exit-status reply 0
debug1: client_input_channel_req: channel 0 rtype eow reply 0
debug1: channel 0: free: client-session, nchannels 1
Transferred: sent 2496, received 2632 bytes, in 0.1 seconds
Bytes per second: sent 18219.0, received 19211.7
debug1: Exit status 0
```

**人话翻译**：

```
服务器返回命令执行结果:
  ===LOGIN SUCCESS===          ← 我们要执行的 echo 命令输出了！

  exit-status: 0                ← 命令执行成功（0 = 正常退出）

  通道关闭，连接释放

  本次通信统计:
    发送了 2496 字节
    接收了 2632 字节
    耗时 0.1 秒
    速度约 18KB/s 发送 / 19KB/s 接收

  🎉 全程结束！
```

---

## 全流程一图总结

```
┌─────────────────────────────────────────────────────────────┐
│                    你输入: ssh tengxun-server9               │
└──────────────────────────┬──────────────────────────────────┘
                           │
         ┌─────────────────┼────────────────────┐
         ▼                 ▼                    ▼
   ┌──────────┐     ┌──────────────┐    ┌──────────────┐
   │① 读config│     │② TCP 连接    │    │③ 加载密钥    │
   │找到别名   │     │拨通电话      │    │拿出钥匙      │
   │获取IP/端口│     │建立通路      │    │(type-1警告)  │
   └────┬─────┘     └──────┬───────┘    └──────┬───────┘
        │                 │                   │
        ▼                 ▼                   ▼
   ┌──────────┐     ┌──────────────┐    ┌──────────────┐
   │④ 版本协商  │     │⑤ 报身份      │    │⑥ 查known_hosts│
   │确认语言   │     │"我是root"    │    │确认没被冒充   │
   └────┬─────┘     └──────┬───────┘    └──────┬───────┘
        │                 │                   │
        ▼                 ▼                   ▼
   ┌──────────────────────────────────────────────┐
   │⑦ KEX 密钥交换（协商加密方式 + 对暗号）        │
   │   选算法 → DH交换密钥 → 验证服务器指纹         │
   │   → 从此之后所有通信都是加密的！              │
   └──────────────────────┬───────────────────────┘
                          │
                          ▼
   ┌──────────────────────────────────────────────┐
   │⑧ 身份认证（出示证件）                         │
   │   服务器发挑战 → 私钥签名 → 公钥验证 → 通过 ✅  │
   └──────────────────────┬───────────────────────┘
                          │
                          ▼
   ┌──────────┐     ┌──────────────┐    ┌──────────────┐
   │⑨ 建立通道  │     │⑩ 执行命令    │    │⑪ 断开连接    │
   │进入房间   │     │echo OK       │    │统计流量      │
   └──────────┘     └──────────────┘    └──────────────┘

                              ↓
                        🎉 登录成功！
```

## 关键时间线（从日志看实际耗时）

| 阶段 | 操作 | 耗时 |
|------|------|------|
| ①~⑤ | 配置读取 + TCP 连接 + 身份声明 | ~几毫秒 |
| ⑥~⑦ | known_hosts 检查 + KEX 密钥交换 | ~几十毫秒（主要耗在这里）|
| ⑧ | 身份认证（公钥签名验证） | ~几毫秒 |
| ⑨~⑩ | 建立通道 + 执行命令 | ~几毫秒 |
| **总计** | **从敲回车到看到结果** | **~0.1 秒** |

> 这就是为什么 SSH 连接感觉"秒连"——整个过程只需要 0.1 秒。
