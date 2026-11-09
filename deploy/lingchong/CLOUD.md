# 家庭实验室 + 云服务器分工

> 状态：架构方案，尚未在真实服务器执行。  
> 适用：现有班级量化系统继续留在家庭实验室；另有云服务器和域名。

---

## 1. 结论

不要把两个数据库都变成主库。

推荐：

- **家庭实验室**：班级量化系统、MariaDB、异步游戏 API；
- **云服务器**：实时房间服务（WebSocket）、Redis；
- **Cloudflare / 域名**：异步 API 和实时入口分别指向两台机器；
- **实时房间服不直连 MariaDB**，只通过 Tailscale 调家庭实验室的内部 API。

---

## 2. 拓扑

```text
                    Cloudflare DNS
        ┌────────────────┴────────────────┐
        │                                 │
 game.yourdomain.com                rt.yourdomain.com
        │                                 │
 Cloudflare Tunnel                 Cloudflare Tunnel / TLS
        │                                 │
        ▼                                 ▼
家庭实验室                             云服务器
  teaching-app                          lingchong-rt
  MariaDB（唯一主库）                    Redis
  lingchong-api（异步 REST）             房间/匹配/WebSocket
        ▲                                 │
        └──────── Tailscale 内网 ─────────┘
               RT 只调内部 HTTP API
```

---

## 3. 职责

| 组件 | 位置 | 职责 |
|---|---|---|
| `teaching-app` | 家庭实验室 | 现有班级量化、学生、积分、班宠 |
| MariaDB | 家庭实验室 | 唯一主库；不暴露公网 |
| `lingchong-api` | 家庭实验室 | 切片/异步 API；同网络直连 `db:3306` |
| `lingchong-rt` | 云服务器 | WebSocket 房间、匹配、战斗 tick |
| Redis | 云服务器 | 房间状态、断线重连、短期缓存 |
| Cloudflare | 公网 | HTTPS、Tunnel、隐藏源站 |

---

## 4. 域名建议

| 域名 | 指向 | 用途 |
|---|---|---|
| `game.yourdomain.com` | 家庭实验室 Cloudflare Tunnel → `localhost:8090` | 登录、军令、战报、异步结算 |
| `rt.yourdomain.com` | 云服务器 | 实时房间 WebSocket |
| `school.yourdomain.com` | 家庭实验室现有入口 | 班级量化系统本身 |

Godot 客户端可配置两个地址：

```text
API_BASE=https://game.yourdomain.com
RT_BASE=wss://rt.yourdomain.com
```

没有实时活动时只连 API。

---

## 5. 实时房间服的鉴权与写回

### 不直接连数据库

`lingchong-rt` 不持有 MariaDB 密码，也不直连 `3306`。

通过 Tailscale 调用家庭实验室内部接口：

```text
POST /api/internal/rt/verify
  Authorization: Bearer <玩家 token>
  → 返回 player_id / faction / pet / 当前回合

POST /api/internal/rt/result
  Authorization: Bearer <RT 服务密钥>
  → 写入战斗结果 / 战报 / 回合状态
```

这两个接口需要新加，并加服务间密钥；不能暴露给公网。

### 为什么

- 学生数据只留在一个主库；
- 云服务器被攻破也拿不到数据库；
- 避免两个主库/双向同步；
- 备份、审计、积分计算仍只在家庭实验室。

---

## 6. 实时方案选择

| 方案 | 放哪 | 说明 |
|---|---|---|
| 战斗回放 | 家庭实验室 | 21:00 结算后客户端播动画；不需要同时在线 |
| 周五同步回合制 | 云服务器 | WebSocket；每 30 秒下令；5 回合；推荐 |
| 真·实时操作 | 云服务器 | 需要 UDP/ENet/WebTransport、客户端预测、服务器权威 |

### 周五同步回合制

- 每周五 20:00–20:20；
- 双方在线，30 秒/回合；
- 缺席默认防御；
- 只影响周五额外奖励，不替代每日 21:00 结算；
- 云服务器 2C2G 可跑 40 人规模；
- Cloudflare Tunnel 支持 WebSocket，但建议 30 秒 ping 保活。

### 真·实时操作

- 不建议走家庭宽带 + Cloudflare Tunnel；
- 云服务器需要公网 IP，UDP 端口单独放行；
- 战斗状态由 RT 服务器权威计算；
- 结果通过内部 API 回写；
- 需要额外 2–4 周开发和压测。

---

## 7. 部署顺序

1. 家庭实验室先部署异步 `lingchong-api`（`deploy/lingchong/README.md`）；
2. Cloudflare 增加 `game` 子域名；
3. 跑通 8–12 人三回合切片；
4. 云服务器部署 `lingchong-rt` + Redis；
5. Tailscale 打通云服务器 → 家庭实验室内部 API；
6. Cloudflare 增加 `rt` 子域名；
7. 先做周五同步回合制，再评估真·实时。

---

## 8. 安全边界

- MariaDB 不开公网，不发布 `0.0.0.0:3306`；
- 云服务器不保存数据库密码；
- RT 服务密钥只存在两台服务器的环境变量；
- Tailscale ACL 只允许云 RT 访问家庭 API 的内部端口；
- 内部 API 只监听 Tailscale IP，不监听公网；
- 所有公网入口走 HTTPS/WSS；
- 生产迁移前备份，测试库先演练。

---

## 9. 还没做的事

- `lingchong-rt` 代码与协议；
- `/api/internal/rt/verify`、`/api/internal/rt/result`；
- Tailscale ACL 与 systemd/Docker 部署；
- 云服务器实际压测；
- 同步回合制的规则、缺席默认防御、奖励结算；
- 真·实时操作的网络方案。

这份文档只定分工，不代表实时功能已经实现。
