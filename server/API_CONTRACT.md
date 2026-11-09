# 《青竹文房·灵宠山河》API 契约（第一期）

> Base URL：`https://qi.qnengs.tech/api/game/war`  
> 鉴权：`Authorization: Bearer <token>`  
> 统一响应：`{ "code": 0, "msg": "success", "data": {} }`  
> 错误：`code != 0`，HTTP 4xx/5xx 按现有系统约定

---

## 一、鉴权

### 复用登录

`POST /api/game/auth/login`

```json
{ "name": "张明远", "password": "******" }
```

返回：

```json
{
  "token": "base64(studentId:hmac)",
  "student": { "id": 1, "show_name": "张明远", "class_id": 1 }
}
```

- Token 复用现有 `Auth::generateTokenHash()` 思路；
- App/小游戏存安全存储；
- 后续微信小游戏用 `wx.login` + openid 绑定。

---

## 二、学生端接口

### 1. 启动数据

`GET /bootstrap`

返回：

```json
{
  "season": { "id": 1, "name": "S1 九州争霸", "week": 1, "phase": 1, "settle_time": "21:00" },
  "faction": { "id": 1, "code": "bi", "name": "笔", "color": "#b83b32", "food": 500, "wood": 500, "iron": 500 },
  "general": { "id": 1, "display_name": "小青竹", "role": "general", "troops": 1000, "troop_type": "cavalry", "morale": 80, "supply_days": 3, "province_id": 1 },
  "turn": { "date": "2026-11-09", "status": "open", "orders_used": 1, "orders_limit": 3 },
  "weather": { "code": "sunny", "name": "晴" },
  "report_unread": true,
  "bounties": [ { "id": 1, "title": "侦察洛阳", "status": "active" } ]
}
```

### 2. 地图

`GET /map`

返回节点、相邻、归属、可见军队：

```json
{
  "provinces": [
    {
      "id": 1, "code": "changan", "name": "长安", "terrain": "plain",
      "victory_points": 3, "owner_faction_id": 1, "owner_color": "#b83b32",
      "wall_level": 2, "neutral_garrison": 0,
      "adjacency": ["luoyang", "hanzhong"],
      "visible_armies": [ { "general_id": 1, "display_name": "小青竹", "troops": 1000, "troop_type": "cavalry" } ]
    }
  ]
}
```

### 3. 节点详情

`GET /province/{id}`

返回建筑、守军、可见军队、补给线、战报入口。

### 4. 我的将军

`GET /general`

返回班宠将军、角色、兵力、士气、补给、技能/法宝摘要。

### 5. 下军令

`POST /orders`

```json
{
  "order_slot": 1,
  "order_type": "march",
  "target_province_id": 2,
  "payload": { "troop_type": "cavalry" },
  "idempotency_key": "uuid-xxxx"
}
```

规则：

- 每天 3 道，`order_slot` 1/2/3；
- 同一 slot 可覆盖（21:00 前）；
- `march` 目标必须相邻或满足路线；
- `recruit` 消耗粮/铁；
- `build` 消耗木/铁；
- 返回军令状态/预计消耗。

### 6. 取消/修改军令

`POST /orders/cancel`

```json
{ "order_slot": 1 }
```

- 21:00 前有效；
- 结算中/已结算不可取消。

### 7. 今日日报

`GET /reports/today`

返回：

```json
{
  "date": "2026-11-09",
  "headline": "昨夜襄阳易主！",
  "map_changes": [ { "province": "襄阳", "from": "墨", "to": "笔" } ],
  "top_battles": [ { "battle_id": 10, "title": "以少胜多", "attacker": "小青竹", "defender": "墨点精" } ],
  "mvp": [ { "student": "张*远", "merit": 120, "type": "battle" } ],
  "rumor": "传闻墨阵营在太原集结。"
}
```

### 8. 标记日报已读

`POST /reports/{id}/read`

### 9. 悬赏

`GET /bounties`  
`POST /bounties/{id}/claim`

### 10. 角色

`POST /role`

```json
{ "role": "strategist" }
```

- 每周可换一次；
- 返回新角色与本周加成。

---

## 三、第二期接口（预留）

| 接口 | 用途 |
|---|---|
| `POST /predictions` | 竞猜战斗胜负 |
| `GET /predictions` | 我的竞猜/结算 |
| `POST /spy` | 侦察/破坏/假情报 |
| `POST /treaty` | 外交条约提案 |
| `POST /combo` | 双人合击邀请/确认 |
| `GET /neutrals` | 中立文魔据点 |
| `POST /neutrals/attack` | 攻打文魔 |

## 四、第三期接口（预留）

| 接口 | 用途 |
|---|---|
| `POST /siege` | 建造/部署攻城器械 |
| `POST /wonder` | 国家奇观捐献 |
| `GET /cross-war` | 跨班战争状态 |

---

## 五、老师/后台接口

### 1. 创建赛季

`POST /api/admin/game/war/season`

```json
{
  "class_id": 1,
  "name": "S1 九州争霸",
  "map_code": "jiuzhou_12",
  "phase": 1,
  "start_date": "2026-11-10",
  "end_date": "2026-12-08",
  "settle_time": "21:00"
}
```

### 2. 赛季总览

`GET /api/admin/game/war/overview?season_id=1`

返回：地图、阵营资源、将军、今日军令数、结算状态、异常。

### 3. 手动补算

`POST /api/admin/game/war/settle`

```json
{ "season_id": 1, "turn_date": "2026-11-09", "force": false }
```

- 只允许 `failed` 或 `open` 状态补算；
- 幂等；
- 记录操作人。

### 4. 开关

`POST /api/admin/game/war/toggle`

```json
{ "season_id": 1, "enabled": false }
```

---

## 六、错误码

| code | 含义 |
|---|---|
| `INVALID_TOKEN` | 登录失效 |
| `GAME_DISABLED` | 游戏关闭 |
| `TURN_CLOSED` | 21:00 后军令锁定 |
| `ORDER_LIMIT` | 超过 3 道军令 |
| `INVALID_ORDER` | 非法军令 |
| `NOT_ADJACENT` | 目标不相邻 |
| `INSUFFICIENT_RESOURCES` | 粮/木/铁不足 |
| `IDEMPOTENT_REPLAY` | 重复提交，返回上次结果 |
| `SETTLEMENT_PENDING` | 结算中，请稍后 |
| `SETTLEMENT_FAILED` | 结算失败，已记录 |
| `NOT_YOUR_GENERAL` | 无权操作该将军 |

---

## 七、21:00 结算任务

```text
1. 查找当天 status=open 的 turn
2. 置为 settling
3. 按顺序结算：
   recruit/build/transport → scout/spy → march → battle → siege → capture → supply/morale → report
4. 生成 game_war_reports
5. 置为 settled
6. 失败置为 failed，记录 error_text，支持补算
```

- 定时任务用系统 cron + `dragonmantank/cron-expression`；
- 队列/重试用 `symfony/messenger`（可选）；
- 所有写操作带幂等键；
- 事务 + 行锁。

---

## 八、安全底线

1. 所有战斗结果服务端计算；
2. 客户端只提交军令，不提交战果；
3. 写操作幂等；
4. 事务 + 行锁；
5. 老师总开关；
6. 测试用独立测试班/测试库；
7. 不写 `students.score`；
8. 积分走 `shop_orders`。
