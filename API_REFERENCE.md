# 青竹文房 · Slice API 参考（客户端 / 教师端）

> 生成日期：2026-11-11
> 唯一依据：`server/slice/public/index.php`、`server/slice/src/*.php` 实读代码。
> 参考文档：`PHASE1_CLIENT_CONTRACT.md`、`GAMEPLAY_DESIGN.md`、`INTEGRATION.md`。
> 适用版本：`rules_version = cards_v1`（12+1 城主玩法）与 `A1`（5 节点切片）共用同一套接口。
> 凡是本文与旧文档冲突处，以本文「第 6.4 节」标注的实现行为为准。

---

## 0. 通用约定

### 0.1 地址

| 项 | 值 |
|---|---|
| Base URL | `http://<host>:8080`（本地）/ 试跑用 `:8081` |
| API 前缀 | `/api` |
| 教师控制台 | `GET /teacher`（或 `/teacher.html`，同内容） |
| 根路径 | `GET /` 返回一张 HTML 说明页，不是 JSON |
| CORS | `Access-Control-Allow-Origin: *`；允许 `Content-Type, Authorization, X-Auth-Token, X-Request-Id` |
| 预检 | `OPTIONS *` → `204`，无 body |

### 0.2 响应封套

成功（`index.php:68-75`）：

```json
{
  "ok": true,
  "data": { },
  "server_time": "2026-11-11 20:59:58"
}
```

失败（`index.php:77-88`）：

```json
{
  "ok": false,
  "error": {
    "code": "TURN_LOCKED",
    "message": "本回合已锁定，不能再改军令",
    "details": { "turn_status": "locked" }
  },
  "server_time": "2026-11-11 20:59:58"
}
```

- `error.details` 恒存在，可能是 `{}` 或 `[]`。
- `server_time` 是应用时区（默认 `Asia/Shanghai`）的 `Y-m-d H:i:s`。
- 少数接口的 `data` 里**再带一个 `server_time`**（`/api/slice/orders`、`/api/slice/recharge`），属历史遗留，不是错误。

### 0.3 认证

```
Authorization: Bearer <token>
```

- 也接受 `X-Auth-Token: <token>`（`index.php:117-125`），两者同时存在时 `Bearer` 优先。
- Token 为 64 位十六进制字符串，服务端只存 `sha256(token)`。
- 默认 TTL **43200 秒（12 小时）**，见 `config.*.php` 的 `app.token_ttl_seconds`。
- 会话表 `slice_sessions`，`expires_at` 过期即失效；每次鉴权会刷新 `slice_players.last_seen_at`。
- 角色：`player`（学生）/ `teacher`（教师）。教师账号无 `student_id`、无钱包、无手牌。

### 0.4 错误码总表

HTTP 状态与 `error.code` 的对应由 `ApiException` 构造参数决定；**未捕获的 `RuntimeException` 一律变成 500 `INTERNAL`**。

| HTTP | code | 典型触发 | 备注 |
|---|---|---|---|
| 400 | `BAD_REQUEST` | 缺参数、参数格式错、非法 JSON | 也承载 `InvalidArgumentException` 的哨兵字符串，见下 |
| 400 | `BAD_JSON` | 请求体不是合法 JSON | `jsonBody()` |
| 401 | `UNAUTHORIZED` | 未带 token / token 过期 / 姓名密码错 | |
| 403 | `FORBIDDEN` | 角色不符、跨测试局、未编入本局 | |
| 403 | `NOT_ENROLLED` | 学生/管理员不在本局名单 | |
| 403 | `PET_REQUIRED` | 学生还没有班宠 | 仅学生登录 |
| 403 | `SCOUT_REQUIRED` | 未对该城打「哨探」就查情报 | |
| 404 | `TURN_NOT_FOUND` | 回合 id 不存在 / 不属于本局 / 局内无当前回合 | |
| 404 | `GAME_NOT_FOUND` | 测试局不存在 | |
| 404 | `NODE_NOT_FOUND` | 城池不存在 | |
| 404 | `NOT_FOUND` | 路由不存在 / 战斗不存在 | 战斗越权也返回此码 |
| 404 | `RESULT_NOT_FOUND` | 回合无结算结果 | |
| 404 | `STUDENT_NOT_FOUND` | 学生账号不存在 | 钱包接口 |
| 409 | `AMBIGUOUS_NAME` | 重名学生未用带序号显示名登录 | |
| 409 | `GAME_PAUSED` | 测试局已暂停 | 旧军令接口 |
| 409 | `TURN_LOCKED` | 回合非 open | 旧军令接口 |
| 409 | `TURN_DEADLINE_PASSED` | 已过 `deadline_at` | 旧军令接口 |
| 409 | `TURN_NOT_OPEN` | 锁令时回合状态不对 | |
| 409 | `DEADLINE_NOT_REACHED` | 未到截止时间且未 `force` | |
| 409 | `SETTLE_NOT_READY` | 未锁令 / 无快照 / 回合未结算就翻页 | |
| 409 | `SETTLE_RUNNING` | 同一回合计结 60 秒内重复调用 | |
| 409 | `SEASON_FINISHED` | 赛季已结束（5 城图 3 回合、12 城图 28 回合） | |
| 409 | `REPORT_NOT_READY` | 回合未结算就要战报 | |
| 409 | `IDEMPOTENCY_CONFLICT` | 同一 `request_key` 换了载荷 | |
| 409 | `ESTATE_MAX_LEVEL` / `ESTATE_INSUFFICIENT_MERIT` / `ESTATE_NO_HOME` | 小院升级 | |
| 409 | `POINTS_INSUFFICIENT` / `DAILY_CAP_EXCEEDED` | 积分兑换 | |
| 409 | `NO_FACTION` | 预测时玩家无阵营 | |
| 422 | `START_PROTECTED` | 打敌方起点（仅 `node_type='start'` 的图） | |
| 422 | `NOT_YOUR_CITY` | 从别人的城进军 / 驻守别人城 | |
| 422 | `NOT_ADJACENT` | 目标与己方领土不相邻 | 旧军令接口 |
| 500 | `INTERNAL` | 未捕获异常 | 见 0.4.1 |
| 500 | `SETTLE_FAILED` | 结算异常，快照保留可重试 | details 有 `reason` |
| 500 | `BOOTSTRAP_FAILED` | 配置/数据库连不上 | |
| 500 | `VERIFY_CODE_FAILED` | 核销码生成失败 | |

#### 0.4.1 手牌/编成接口的「假错误码」（重要）

`HandService`、`HandDeck` 抛的是 `InvalidArgumentException` / `RuntimeException`，`index.php` 只把前者转成 **400 `BAD_REQUEST`**，后者直接落到 **500 `INTERNAL`**。

因此下列字符串**不是 `error.code`，而是 `error.message`**：

| 字符串 | 实际 HTTP / code | 出处 |
|---|---|---|
| `BAD_SLOT` `EMPTY_TARGET` `BAD_LANE` `BAD_ROW` `BAD_REQUEST_KEY` | 400 / `BAD_REQUEST` | `HandService::play` |
| `UNKNOWN_TARGET` `NOT_ADJACENT` `CHANGAN_LOCKED` `SEASON_FINAL_WEEK` | 400 / `BAD_REQUEST` | `HandService::assert*` |
| `UNKNOWN_TACTIC: x` `CARD_NOT_IN_HAND: x` `CARD_ALREADY_PLAYED: x` `PLAY_LIMIT_REACHED` | 400 / `BAD_REQUEST` | `HandDeck::validatePlay` |
| `NEEDS_3_TYPES` `UNKNOWN_UNIT_TYPE: x` | 400 / `BAD_REQUEST` | `HandService::setComposition` |
| `REDRAW_USED` | **500 / `INTERNAL`** | `HandService::redraw` |
| `COMPOSITION_LOCKED` | **500 / `INTERNAL`** | `HandService::setComposition` |
| `PLAY_LIMIT_REACHED`（槽位已满分支） | 代码写了 **500 / `INTERNAL`**，但实际不可达 | `HandService::play` 第 186 行（`validatePlay` 会先抛 400） |
| `TURN_NOT_FOUND`（卡牌结算） | **500 / `INTERNAL`** | `CardSettlementService::settle` |
| `NODE_NOT_FOUND`（战斗结算落库） | **500 / `INTERNAL`** | `BattleSettlementService::apply` |
| `GAME_NOT_FOUND`（赛季） | **500 / `INTERNAL`** | `SeasonService` / `SeasonHistoryService` |

客户端判断必须写成：

```gdscript
if code == "BAD_REQUEST" and message.begins_with("CARD_NOT_IN_HAND"): ...
```

不能只按 `code` 分支。

### 0.5 `turn_id` 默认值矩阵

| 接口 | `turn_id` 来源 | 省略时 |
|---|---|---|
| `GET /api/slice/state` | `?turn_id=` | 用 `slice_games.current_turn_id`；为空 → 404 `TURN_NOT_FOUND` |
| `GET /api/slice/hand` | `?turn_id=` | 用登录态里的 `game.current_turn_id`；`<=0` → 400 |
| `POST /api/slice/hand/redraw` | body `turn_id` | 同上 |
| `GET /api/slice/intel` | `?turn_id=` | 同上；另必须有 `node` |
| `GET|POST /api/slice/bulletin` | query / body | 同上 |
| `GET /api/slice/merit` | `?turn_id=` | 同上（只用于推导周次；`week` 参数优先且被 clamp 到 1–4） |
| `GET /api/slice/me/report` | `?turn_id=` | 同上，`<=0` → 400 |
| `GET /api/slice/estate` | `?turn_id=` | 同上（只用于推导周次） |
| `GET|POST /api/slice/composition` | `week_no` | 缺省用当前回合推导的周次；**不做 1–4 clamp** |
| `POST /api/slice/order/play` | body `turn_id` | 同上，`<=0` → 400 |
| `POST /api/slice/order/withdraw` | body `turn_id` | 同上，`<=0` → 400 |
| `POST /api/slice/battle/forecast` | body `turn_id` | 同上 |
| `POST /api/slice/battle/demo` | body `turn_id` | 同上 |
| `POST /api/slice/battle/settle` | 无（用 `battle_id` 反查） | — |
| `GET /api/slice/report` | `?turn_id=` | **必填**，`<=0` → 400 |
| `GET /api/slice/history` | 无 | `limit` 默认 10，clamp 1–30 |
| `GET /api/slice/replay` | 无 | 返回全部已结算回合 |
| `POST /api/slice/admin/lock` / `settle` / `card-settle` | body `turn_id` | **必填**，`0` → 404 `TURN_NOT_FOUND`（card-settle 为 400） |
| `POST /api/slice/admin/next-turn` | body `from_turn_id`（兼容 `turn_id`） | **必填**，`0` → 404 `TURN_NOT_FOUND` |
| `POST /api/slice/admin/pause` / `resume` | 无 | 作用于当前登录教师所在局 |

> 用 `state.turn.id` 作为一切写操作的 `turn_id`；不要自己加减。

### 0.6 幂等键

| 接口 | 键 | 真幂等？ | 行为 |
|---|---|---|---|
| `POST /api/slice/orders` | `request_key`（8–64 位 `[A-Za-z0-9_-]`） | ✅ | 同键同载荷 → 返回原响应 + `idempotent:true`；同键异载荷 → 409 `IDEMPOTENCY_CONFLICT` |
| `POST /api/slice/orders/withdraw` | `request_key` | ✅ | 同上（载荷 hash 只含 `withdraw|turn_id`） |
| `POST /api/slice/recharge` | `request_key` | ✅ | 存 `game_recharge_requests`；同键异积分数 → 409 |
| `POST /api/slice/order/play` | `request_key` | ❌ | **只校验格式并落 `last_request_key`，不查重**。同槽位重复 POST 等价于覆盖 |
| `POST /api/slice/order/withdraw` | 无 | ❌ | 看 `withdrawn` 布尔 |
| `POST /api/slice/battle/settle` | 无 | ❌ | 每次调用都推一次民心（见风险 R4） |
| `POST /api/slice/admin/lock` | 无 | ⚠️ | 已 `locked`/`settled` 返回 `already:true` |
| `POST /api/slice/admin/settle` | 无 | ⚠️ | 已 `settled` 返回既有结果；60 秒内并发 → 409 |
| `POST /api/slice/admin/card-settle` | 无 | ⚠️ | 已 `settled` 返回 `already_settled:true`，但**无事务/无锁**（见风险 R5） |

### 0.7 时间与时区

- 所有 `opens_at` / `deadline_at` / `settled_at` / `server_time` 都是应用时区字符串。
- `turn.seconds_remaining` 由服务端时钟算，客户端只做本地倒计时递减，**不要**用设备时间重算截止。
- 例外：`CardSettlementService::settle` 写 `settled_at = NOW()`（数据库时区），其余路径用 PHP `Clock`（`Asia/Shanghai`）。DB 若不同区，卡牌结算的时间戳会偏。

### 0.8 GET 也会写库（缓存/重试要注意）

| 接口 | 副作用 |
|---|---|
| `GET /api/slice/state` | `getOrCreateHand`（写 `slice_hands`）、`BulletinService::summary`（写 `slice_bulletins`）、`EstateService::summary → ensure`（写 `slice_estates`） |
| `GET /api/slice/hand` | 同上（手牌 + 编成，不写 bulletin） |
| `GET /api/slice/bulletin` | 首次调用写当日两个选项 |
| `GET /api/slice/estate` | `ensure` 写小院行 |
| `GET /api/slice/season*` / `history` / `replay` / `battle` / `wallet` | 只读 |

> 结论：`state` 不能当纯只读探针无限重试；但它自身是幂等的（`ON DUPLICATE KEY` / 唯一键兜底），重复调用不会造重复行。

---

## 1. 认证（学生 / 教师）

### 1.1 `POST /api/auth/login`

**Auth**：不需要（公开）
**角色**：学生（对应 `slice_players.role='player'`）

**Body**

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `name` | string | ✅ | 学生姓名或显示名；也接受别名 `nickname` |
| `password` | string | ✅ | 与 `students.password` 做 `password_verify` |
| `game_code` | string | ❌ | 指定测试局 code，如 `MAP12_TEST`；不传则按 `running → paused → finished → draft` 优先取最新一局 |

**成功 200**

```json
{
  "ok": true,
  "data": {
    "token": "9f2c4e0d7a1b8c3d5e6f708192a3b4c5d6e7f8091a2b3c4d5e6f708192a3b4c5",
    "expires_at": "2026-11-12 08:59:58",
    "player": {
      "id": 11,
      "nickname": "青竹一",
      "role": "player",
      "student": { "id": 1, "name": "试验青竹一", "show_name": "青竹一", "class_id": 1, "score": 140 },
      "admin": null,
      "pet": {
        "instance_id": 1,
        "nickname": "小青竹·一",
        "level": 10,
        "hunger": 90,
        "exp": 0,
        "template_code": "pet_bamboo_01",
        "template_name": "小青竹",
        "element": "诗词",
        "rarity": "N",
        "power": 1000
      },
      "pet_code": "pet_bamboo_01",
      "pet_name": "小青竹·一",
      "faction": { "id": 1, "code": "bi", "name": "笔", "color": "#B83B32" },
      "game": {
        "id": 2,
        "code": "MAP12_TEST",
        "name": "12+1 城·九州测试",
        "status": "running",
        "rules_version": "cards_v1",
        "turn_seconds": 600,
        "current_turn_id": 14
      }
    },
    "wallet": {
      "student_id": 1,
      "student_name": "青竹一",
      "class_id": 1,
      "total_score": 140,
      "base_score": 100,
      "gross_net": 40,
      "spent_points": 0,
      "available_points": 40,
      "today_recharged_points": 0,
      "daily_cap_points": 20,
      "remaining_daily_points": 20,
      "exchange_rate": 10,
      "jade_balance": 0
    }
  },
  "server_time": "2026-11-11 20:59:58"
}
```

**错误**

| HTTP | code | 触发 |
|---|---|---|
| 400 | `BAD_REQUEST` | 姓名或密码为空 |
| 400 | `BAD_JSON` | body 不是 JSON |
| 401 | `UNAUTHORIZED` | 查无此人或密码错误 |
| 409 | `AMBIGUOUS_NAME` | 同名多条且未用带序号显示名 |
| 403 | `NOT_ENROLLED` | 学生存在但不在该局 `slice_players` |
| 403 | `PET_REQUIRED` | 该学生没有 `student_pets` 记录 |

**客户端注意**

- `data.player.pet.power` 恒为 `1000`（硬编码占位），**不要**拿它算战力；真实兵力由服务端 `BattleService::petPower()` 按四维/等级/成长算。
- 登录会顺带回写 `slice_players.nickname/pet_code/pet_name`（同步显示名），不改 `students` / `student_pets`。
- `game_code` 传空串 `""` 视为「未指定」。
- 同一学生重复登录会新增一条 session，旧 token 仍有效直到过期。

---

### 1.2 `POST /api/auth/admin-login`

**Auth**：不需要
**角色**：教师（`slice_players.role='teacher'`，绑定 `admin` 表）

**Body**

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `username` | string | ✅ | `admin.username` |
| `password` | string | ✅ | |
| `game_code` | string | ❌ | 多局时指定 |

**成功 200**

```json
{
  "ok": true,
  "data": {
    "token": "3b1d5f7a9c2e4b6d8f0a1c3e5b7d9f2a4c6e8b0d2f4a6c8e0b2d4f6a8c0e2b4d",
    "expires_at": "2026-11-12 08:59:58",
    "player": {
      "id": 1,
      "nickname": "先生",
      "role": "teacher",
      "student": null,
      "admin": { "id": 1, "username": "teacher", "nickname": "先生" },
      "pet": null,
      "pet_code": "",
      "pet_name": "",
      "faction": null,
      "game": {
        "id": 2, "code": "MAP12_TEST", "name": "12+1 城·九州测试",
        "status": "running", "rules_version": "cards_v1",
        "turn_seconds": 600, "current_turn_id": 14
      }
    },
    "wallet": null
  },
  "server_time": "2026-11-11 20:59:58"
}
```

**错误**：`400 BAD_REQUEST`、`401 UNAUTHORIZED`、`403 NOT_ENROLLED`

**客户端注意**

- 教师 `player.pet` 为 `null`，`faction` 通常为 `null`；教师不能下军令、不能出牌、没有钱包。
- 教师台 HTML 默认账号提示为 `teacher / teacher2026`（见 `teacher.html` 占位符），实际以种子为准。

---

### 1.3 `POST /api/auth/logout`

**Auth**：Bearer ✅
**Body**：无（可传 `{}`）

**成功 200**

```json
{ "ok": true, "data": { "ok": true }, "server_time": "2026-11-11 21:00:03" }
```

**错误**：`401 UNAUTHORIZED`

**客户端注意**

- 只删除**当前这一个** token 对应的 session；其它设备 token 不受影响。
- 会写审计 `auth.logout`。
- Godot 客户端当前登出是**纯本地**的（`Slice.gd:_on_logout → _logout_local`，不调本接口），因此服务端 token 会活到 12 小时过期。见风险 R8。

---

### 1.4 `GET /api/health`

**Auth**：不需要
**成功 200**

```json
{
  "ok": true,
  "data": { "ok": true, "server_time": "2026-11-11 21:00:05", "games": 2, "php": "8.3.12" },
  "server_time": "2026-11-11 21:00:05"
}
```

**错误**：`500 BOOTSTRAP_FAILED`（DB 不通）

**注意**：`data.ok` 与外层 `ok` 重复，属历史结构；适合做探活，不适合做业务就绪判断。

---

## 2. 状态与地图

### 2.1 `GET /api/slice/state`

**Auth**：Bearer ✅
**角色**：学生 / 教师均可（教师分支下 `hand/composition/card_orders/bulletin/merit/estate` 为 `null`）
**Query**

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `turn_id` | int | ❌ | 查看指定回合；省略用当前回合 |

**这是客户端唯一必需的「全量首屏」接口。** 返回地图、回合、我的手牌/编成/已出令、邸报、军功、小院、可下令目标、上一份战报摘要。

**成功 200（节选，实际 13 城）**

```json
{
  "ok": true,
  "data": {
    "server_time": "2026-11-11 20:25:00",
    "wallet": {
      "student_id": 1, "student_name": "青竹一", "class_id": 1,
      "total_score": 140, "base_score": 100, "gross_net": 40,
      "spent_points": 0, "available_points": 40,
      "today_recharged_points": 0, "daily_cap_points": 20,
      "remaining_daily_points": 20, "exchange_rate": 10, "jade_balance": 0
    },
    "game": {
      "id": 2, "code": "MAP12_TEST", "name": "12+1 城·九州测试",
      "status": "running", "rules_version": "cards_v1",
      "turn_seconds": 600, "current_turn_no": 14
    },
    "turn": {
      "id": 14, "turn_no": 14, "status": "open", "status_label": "可下令",
      "opens_at": "2026-11-11 20:21:12", "deadline_at": "2026-11-11 20:31:12",
      "locked_at": null, "settled_at": null,
      "seconds_remaining": 372, "can_edit": true, "snapshot_id": null,
      "failure_reason": null, "rules_version": "cards_v1"
    },
    "me": {
      "id": 11, "nickname": "青竹一", "role": "player",
      "student": { "id": 1, "name": "试验青竹一", "show_name": "青竹一", "class_id": 1, "score": 140 },
      "admin": null,
      "pet": { "instance_id": 1, "nickname": "小青竹·一", "level": 10, "hunger": 90, "exp": 0,
               "template_code": "pet_bamboo_01", "template_name": "小青竹",
               "element": "诗词", "rarity": "N", "power": 1000 },
      "pet_code": "pet_bamboo_01", "pet_name": "小青竹·一",
      "faction": { "id": 1, "code": "bi", "name": "笔", "color": "#B83B32" },
      "game": { "id": 2, "code": "MAP12_TEST", "name": "12+1 城·九州测试",
                "status": "running", "rules_version": "cards_v1",
                "turn_seconds": 600, "current_turn_id": 14 }
    },
    "map": {
      "nodes": [
        {
          "code": "liangzhou", "name": "凉州", "x": 688, "y": 461,
          "type": "camp", "is_start": false,
          "morale": 1, "morale_cap": 3,
          "owner": { "id": 1, "code": "bi", "name": "笔", "color": "#B83B32" },
          "initial_owner": { "id": 1, "code": "bi", "name": "笔", "color": "#B83B32" },
          "is_my_faction": true,
          "can_advance_from": true, "can_defend": true,
          "governor": { "player_id": 11, "nickname": "青竹一", "faction": "bi", "color": "#B83B32", "merit": 43 },
          "reachable_targets": ["hanzhong", "xiangyang", "taiyuan"]
        },
        {
          "code": "hanzhong", "name": "汉中", "x": 1229, "y": 654,
          "type": "pass", "is_start": false,
          "morale": 0, "morale_cap": 3,
          "owner": null, "initial_owner": null,
          "is_my_faction": false,
          "can_advance_from": false, "can_defend": false,
          "governor": null,
          "reachable_targets": []
        }
      ],
      "edges": [["liangzhou", "hanzhong"]]
    },
    "my_order": null,
    "hand": {
      "cards": ["night_raid", "fortify", "scout", "supply"],
      "redraw_used": false,
      "seed": "a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718",
      "preview": ["fire_attack", "cut_supply"]
    },
    "composition": {
      "types": ["cav", "shield", "arc"],
      "changed_once": false,
      "changes_used": 0,
      "changes_allowed": 1
    },
    "card_orders": [
      { "slot": 0, "card_code": "night_raid", "target_node_code": "hanzhong",
        "lane": 1, "row_pos": "front", "last_request_key": "p11_t14_s0_001" }
    ],
    "scouted_nodes": ["hanzhong"],
    "bulletin": {
      "turn_id": 14,
      "options": [
        { "code": "grain", "title": "粮草先行", "desc": "你的队伍本回合兵力 +5%", "icon": "🌾" },
        { "code": "ram",   "title": "攻城器械", "desc": "你的队伍本回合攻城伤害 +25%", "icon": "🪵" }
      ],
      "choice": null
    },
    "merit": {
      "total": 186, "week": 96, "week_no": 2,
      "rank": 3, "week_rank": 2,
      "roles": [ { "kind": "vanguard", "label": "先锋", "week": 2, "rank": 1 } ],
      "breakdown": { "vanguard": 60, "capture": 80, "participation": 25, "scout": 8, "assault": 13 },
      "recent": [
        { "turn_no": 13, "kind": "capture", "label": "破城", "amount": 40,
          "detail": { "node_code": "hanzhong", "role": "vanguard" } }
      ]
    },
    "estate": {
      "home_node": { "code": "liangzhou", "name": "凉州" },
      "level": 2, "banner": "",
      "merit_total": 186, "merit_spent": 30, "merit_balance": 156,
      "next_level_at": 300,
      "rooms": [
        { "code": "study", "name": "书房", "icon": "📜", "level": 2, "max_level": 3,
          "effect": "每日可预读 2 张未抽到的牌", "next_effect": "每日可预读 3 张未抽到的牌", "next_cost": 80 },
        { "code": "drill", "name": "练兵场", "icon": "⚔", "level": 1, "max_level": 3,
          "effect": "每周可改 1 次编成", "next_effect": "每周可改 2 次编成", "next_cost": 30 },
        { "code": "tower", "name": "望楼", "icon": "🔭", "level": 1, "max_level": 3,
          "effect": "侦察时多看 1 座邻城", "next_effect": "侦察时多看 2 座邻城", "next_cost": 30 }
      ],
      "influence": [ { "code": "hanzhong", "name": "汉中", "count": 2, "merit": 43 } ],
      "governorships": [ { "code": "liangzhou", "name": "凉州", "week": 2, "merit": 30 } ]
    },
    "reachable_targets": ["liangzhou", "hanzhong", "xiangyang", "taiyuan", "changan"],
    "options": {
      "advance_from": { "liangzhou": ["hanzhong", "xiangyang", "taiyuan"] },
      "defend_targets": ["liangzhou"]
    },
    "orders_confirmed": 5,
    "participants": 8,
    "faction_participation": [
      { "faction": { "id": 1, "code": "bi", "name": "笔", "color": "#B83B32" }, "confirmed": 3, "players": 4 },
      { "faction": { "id": 2, "code": "mo", "name": "墨", "color": "#1E3A5F" }, "confirmed": 2, "players": 4 }
    ],
    "can_edit": true,
    "edit_block_reason": null,
    "last_report": { "turn_id": 13, "turn_no": 13, "headline": "第 13 回合：汉中易主" },
    "next_turn": null,
    "rules": [
      "进军：从己方城派宠到相邻城，计 1 点。",
      "驻守：在己方城驻守，计 1 点；原归属方另有 1 点基础守备。",
      "最高分且大于 0 的阵营取得；平局或无人行动，保留原归属。",
      "敌方起点不可作为进军目标；对向行军各计目标城。",
      "第三回合后，每座非起点城为归属方计 1 分，同分并列。"
    ]
  },
  "server_time": "2026-11-11 20:31:12"
}
```

**错误**

| HTTP | code | 触发 |
|---|---|---|
| 401 | `UNAUTHORIZED` | 无/过期 token |
| 404 | `TURN_NOT_FOUND` | 局内无当前回合，或 `turn_id` 不存在 |
| 403 | `FORBIDDEN` | `turn_id` 属于别的测试局 |

**客户端注意**

- **`can_edit` 有两层**：顶层 `data.can_edit` 同时要求「局 running + 回合 open + 未过截止」；`data.turn.can_edit` 只看「回合 open + 未过截止」。局暂停时会出现 `turn.can_edit=true` 而 `can_edit=false`，以顶层为准。
- `edit_block_reason` 取值：`GAME_PAUSED` / `TURN_LOCKED` / `TURN_SETTLING` / `TURN_SETTLED` / `TURN_FAILED` / `TURN_DEADLINE_PASSED` / `null`。
- `morale_cap` 按城型：`king`=5；`camp/pass/ferry/culture/water`=3；其余（含 5 节点图的 `start/neutral`）=2。
- `is_start` 只在 `node_type='start'` 时为 `true`（5 节点切片）。**12+1 图的出生城是 `camp`，`is_start=false`**，与 `rules[]` 文案不符，见 6.4-12。
- `reachable_targets` = 己方全部城 + 其相邻城（去重），用于整体置灰；单城可用目标看 `nodes[].reachable_targets` 与 `options.advance_from`。
- `scouted_nodes` 已包含望楼加成与邸报 `scout` 加成；不要自己推。
- `hand.preview` 是书房「预读」的下几张牌，只读，不影响手牌；书房 0 级时为 `[]`。
- `card_orders[].last_request_key` 会回传，可用来判断「这张是不是我刚出的」。
- **`my_order` 是旧军令（`slice_orders`），不是手牌**；3 张将令看 `card_orders`。两者互不影响。
- `bulletin.choice` 为 `null` 表示还未选；选项只有 2 个（3 选 2）。
- `last_report` 只有 `turn_id/turn_no/headline`；正文要另调 `/report` 或 `/me/report`。
- `next_turn` 是**已存在**的下一回合（`turnPublic` 结构），没有则为 `null`；它不代表现在能下令。
- 教师调用时 `hand/composition/card_orders/bulletin/merit/estate` 全为 `null`，`scouted_nodes`、`reachable_targets` 为 `[]`。

---

### 2.2 `GET /api/slice/season`

**Auth**：Bearer ✅（学生/教师均可）
**Query**：无

**成功 200**

```json
{
  "ok": true,
  "data": {
    "game": "MAP12_TEST",
    "week": 2,
    "turn_no": 14,
    "days_left": 14,
    "season_over": false,
    "factions": [
      { "code": "bi",  "name": "笔", "color": "#B83B32", "cities": 4, "morale": 5 },
      { "code": "mo",  "name": "墨", "color": "#1E3A5F", "cities": 3, "morale": 4 },
      { "code": "yan", "name": "砚", "color": "#276F57", "cities": 3, "morale": 3 },
      { "code": "zhi", "name": "纸", "color": "#C9A227", "cities": 2, "morale": 2 }
    ],
    "neutral_cities": 1,
    "changan": {
      "node_code": "changan", "name": "长安",
      "owner": null, "owner_name": null,
      "morale": 0, "morale_cap": 5
    },
    "winner": null
  },
  "server_time": "2026-11-11 21:00:20"
}
```

**错误**：`401 UNAUTHORIZED`；局不存在时是 **500 `INTERNAL`**（`SeasonService` 抛 `RuntimeException`）。

**注意**

- `week = floor((turn_no-1)/7)+1`，不 clamp 到 4；超过 28 回合会得到 5。
- `days_left = max(0, 28 - turn_no)`，对 5 节点 3 回合切片同样按 28 算，**在切片局里没有意义**。
- `winner.reason`：`"changan"`（谁占长安谁赢，`owner` 非空即成立，第 1 回合也可能触发）或 `"cities"`（`turn_no>=28` 或 `game.status='finished'` 时按城数、再按民心）。
- 完全平局 → `winner=null` 且 `season_over` 可能仍为 `true`（`turn_no>=28`）。
- `changan` 在 5 节点图不存在 → `null`。

---

### 2.3 `GET /api/slice/season/history`

**Auth**：Bearer ✅
**Query**：无

**成功 200**

```json
{
  "ok": true,
  "data": {
    "game": "MAP12_TEST",
    "name": "12+1 城·九州测试",
    "current_week": 2,
    "max_turn": 14,
    "weeks": [
      {
        "week": 1,
        "turn_from": 1,
        "turn_to": 7,
        "complete": true,
        "battles": 11,
        "captures": [
          { "turn_no": 3, "node_code": "hanzhong", "node_name": "汉中",
            "winner": { "code": "bi", "name": "笔", "color": "#B83B32" } }
        ],
        "key_battle": {
          "turn_no": 3, "node_code": "hanzhong", "node_name": "汉中",
          "headline": "破城", "score": 2, "wall": 0, "ticks": 58,
          "attacker": { "code": "bi", "name": "笔", "color": "#B83B32" },
          "defender": null
        },
        "standings": [
          { "code": "bi",  "name": "笔", "color": "#B83B32", "cities": 4 },
          { "code": "mo",  "name": "墨", "color": "#1E3A5F", "cities": 3 },
          { "code": "yan", "name": "砚", "color": "#276F57", "cities": 3 },
          { "code": "zhi", "name": "纸", "color": "#C9A227", "cities": 2 },
          { "code": "neutral", "name": "中立", "color": "#7a7066", "cities": 1 }
        ],
        "headline": "第 1 周：笔 4 城领先，6 城易主"
      }
    ]
  },
  "server_time": "2026-11-11 21:00:24"
}
```

**错误**：`401 UNAUTHORIZED`；局不存在 → 500 `INTERNAL`。

**注意**

- 只返回到 `current_week` 为止的周；`complete = max_turn >= week*7`。
- `standings` 末尾固定追加 `neutral` 行（颜色 `#7a7066`），渲染时不要当阵营。
- `key_battle` 只考虑 `score > 0` 的战斗，取分数最高、再取 `ticks` 最长的；全周无胜仗则为 `null`。
- `captures` 只记录「归属真的变了」的城（`owner_after !== null && before !== after`）。

---

### 2.4 `GET /api/slice/history`

**Auth**：Bearer ✅
**Query**

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `limit` | int | ❌ | 默认 10，服务端 clamp 1–30 |

**成功 200**

```json
{
  "ok": true,
  "data": {
    "turns": [
      {
        "id": 14, "turn_no": 14, "status": "open", "status_label": "可下令",
        "opens_at": "2026-11-11 20:21:12", "deadline_at": "2026-11-11 20:31:12",
        "locked_at": null, "settled_at": null,
        "seconds_remaining": 372, "can_edit": true, "snapshot_id": null,
        "failure_reason": null, "rules_version": "cards_v1",
        "headline": null,
        "my_report": null
      },
      {
        "id": 13, "turn_no": 13, "status": "settled", "status_label": "已结算",
        "opens_at": "2026-11-11 20:11:12", "deadline_at": "2026-11-11 20:21:12",
        "locked_at": "2026-11-11 20:21:13", "settled_at": "2026-11-11 20:21:14",
        "seconds_remaining": 0, "can_edit": false, "snapshot_id": 13,
        "failure_reason": null, "rules_version": "cards_v1",
        "headline": "第 13 回合：汉中易主",
        "my_report": "你的进军参与夺取【汉中】。……"
      }
    ]
  },
  "server_time": "2026-11-11 21:00:30"
}
```

**错误**：`401 UNAUTHORIZED`

**注意**

- 按 `turn_no DESC` 排序。
- `my_report` 只来自**旧军令结算**写的 `slice_player_reports`；卡牌结算不写这张表 → 卡牌局里为 `null`，请改用 `/me/report`。
- `headline` 来自 `slice_turn_results.result_json.headline`；卡牌结算结果没有该字段 → `null`（见 6.4-10）。

---

### 2.5 `GET /api/slice/intel`（哨探情报）

**Auth**：Bearer ✅
**角色**：学生
**Query**

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `node` | string | ✅ | 城池 code，如 `hanzhong` |
| `turn_id` | int | ❌ | 省略用当前回合 |

**前置条件**：本回合必须对**同一座城**打出过 `scout`（`slice_order_slots.status='active'`），否则 403。

**成功 200**

```json
{
  "ok": true,
  "data": {
    "turn_id": 14,
    "node_code": "hanzhong",
    "owner_faction_id": null,
    "lane": {
      "lane": 2,
      "type": "shield",
      "name": "盾",
      "row": "front",
      "troops": 367
    },
    "massing": [
      { "faction": "mo", "name": "墨", "players": 2, "teams": 3, "troops": 870, "feint": false }
    ]
  },
  "server_time": "2026-11-11 21:00:40"
}
```

**错误**

| HTTP | code | 触发 |
|---|---|---|
| 400 | `BAD_REQUEST` | 缺 `node` 或 `turn_id`（且登录态无当前回合） |
| 403 | `SCOUT_REQUIRED` | 本回合没对这座城打「哨探」 |
| 404 | `NODE_NOT_FOUND` | 城池不属于本局 |

**注意**

- `lane` 由 `crc32(turn_id:player_id:node_code) % 3 + 1` 决定，**同一回合刷新不变**，换回合会变。
- `lane.troops` 是「一路守军」：中立 1100/3≈367，归属城 1320/3=440（含 ×1.10）。**注意中立路兵力与实战固定守军 803/3≈268 不一致**，见 6.4-1。
- `massing` 只聚合**其他阵营**；己方「疑兵」不会骗到自己。
- `players` 是去重后的学生数，`teams` 是活跃令条数。
- `feint=true` 时 `troops` 已被 ×1.5，UI 必须标「疑似」。
- **没有哨探不要轮询**（403 且打日志）。

---

## 3. 手牌与出令

### 3.1 `GET /api/slice/hand`

**Auth**：Bearer ✅
**Query**：`turn_id`（可选，见 0.5）

**成功 200**

```json
{
  "ok": true,
  "data": {
    "turn_id": 14,
    "hand": {
      "cards": ["night_raid", "fortify", "scout", "supply"],
      "redraw_used": false,
      "seed": "a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718",
      "preview": ["fire_attack"]
    },
    "composition": {
      "types": ["cav", "shield", "arc"],
      "changed_once": false,
      "changes_used": 0,
      "changes_allowed": 1
    },
    "orders": [
      { "slot": 0, "card_code": "night_raid", "target_node_code": "hanzhong",
        "lane": 1, "row_pos": "front", "last_request_key": "p11_t14_s0_001" }
    ]
  },
  "server_time": "2026-11-11 21:00:44"
}
```

**错误**：`400 BAD_REQUEST`（缺 `turn_id` 且登录态无当前回合）、`401`

**注意**

- 与 `state.hand` / `state.composition` / `state.card_orders` 同源；首屏用 `state` 就够了。
- `seed` 只用于排查「为什么我今天抽到这几张」，客户端不应据此自行洗牌。
- `composition` 是**该 `turn_id` 所属周**的编成，不是固定第 1 周。
- 此接口会创建手牌行（写库）。

---

### 3.2 `POST /api/slice/hand/redraw`

**Auth**：Bearer ✅
**Body**

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `turn_id` | int | ❌ | 省略用当前回合 |

**成功 200**

```json
{
  "ok": true,
  "data": {
    "cards": ["fire_attack", "fortify", "feint", "supply"],
    "redraw_used": true,
    "seed": "a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718:redraw",
    "preview": ["cut_supply"]
  },
  "server_time": "2026-11-11 21:00:50"
}
```

**错误**：重复重抽 → **500 `INTERNAL`**（`REDRAW_USED` 只在 500 的日志里，客户端看不到该字符串）；`400 BAD_REQUEST`。

**注意**

- 每个 `turn_id` 每名学生**只能重抽一次**，标志落在 `slice_hands.redraw_used`。
- 重抽后 `seed` 追加 `:redraw`，因此新牌与原牌不同但可复现。
- 重抽**不会**清空已出的牌；已出的牌若不在新手牌里，槽位数据仍在。
- 建议客户端在 `hand.redraw_used=true` 时直接禁用按钮，别靠错误码判断。

---

### 3.3 `GET /api/slice/composition`

**Auth**：Bearer ✅
**Query**

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `week_no` | int | ❌ | 省略用当前回合所属周；**不做 1–4 clamp** |

**成功 200**

```json
{
  "ok": true,
  "data": {
    "types": ["cav", "shield", "arc"],
    "changed_once": false,
    "changes_used": 0,
    "changes_allowed": 1
  },
  "server_time": "2026-11-11 21:00:54"
}
```

**错误**：`401`

**注意**：无记录时返回默认 `["cav","shield","arc"]` 且不写库。

---

### 3.4 `POST /api/slice/composition`

**Auth**：Bearer ✅
**Body**

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `week_no` | int | ❌ | 省略用当前回合所属周 |
| `types` | string[3] | ✅ | 3 个兵种 code，可重复；非数组按 `[]` 处理 → 400 |

**成功 200**

```json
{
  "ok": true,
  "data": {
    "types": ["cav", "cav", "shield"],
    "changed_once": true,
    "changes_used": 1,
    "changes_allowed": 2
  },
  "server_time": "2026-11-11 21:01:00"
}
```

**错误**

| HTTP | code | 触发 |
|---|---|---|
| 400 | `BAD_REQUEST` + message `NEEDS_3_TYPES` | `types` 不是 3 个 |
| 400 | `BAD_REQUEST` + message `UNKNOWN_UNIT_TYPE: x` | 兵种 code 不在 `cav/shield/arc/spear` |
| 500 | `INTERNAL` | 改动次数用尽（`COMPOSITION_LOCKED`） |

**注意**

- 改动次数上限 = `slice_estates.drill_level`（练兵场等级，默认 1，满级 3），即 `changes_allowed`。
- 第一次设置不计次（`changes_used` 保持 0）；之后每改一次 +1。
- 达到上限后再 POST 是 **500**，不是 409；客户端应先用 `changes_used >= changes_allowed` 拦截。
- `slot` 决定用编成第几个兵种（0/1/2），所以数组顺序有意义。
- **Godot 客户端现在硬编码 `week_no=1`**（`Slice.gd:4567`），第 2 周以后改了不生效，见 6.4-15。

---

### 3.5 `POST /api/slice/order/play`（出将令）

**Auth**：Bearer ✅
**Body**

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `turn_id` | int | ❌ | 省略用当前回合 |
| `slot` | int | ✅ | 0 / 1 / 2，同时决定用编成第几个兵种 |
| `card_code` | string | ✅ | 12 张战术之一，必须在手牌中 |
| `target_node_code` | string | ✅ | 目标城；己方城 = 驻守 |
| `lane` | int\|null | ❌ | 1 / 2 / 3；队伍牌建议传 |
| `row_pos` | string\|null | ❌ | `front` / `back`；弓兵会被强制 `back` |
| `request_key` | string | ✅ | 8–64 位 `[A-Za-z0-9_-]`（**不查重**） |

**成功 200**

```json
{
  "ok": true,
  "data": {
    "slot": 0,
    "card_code": "night_raid",
    "target_node_code": "hanzhong",
    "lane": 1,
    "row_pos": "front"
  },
  "server_time": "2026-11-11 21:01:05"
}
```

**错误**

| HTTP | code | message 哨兵 | 触发 |
|---|---|---|---|
| 400 | `BAD_REQUEST` | `BAD_SLOT` | slot 不在 0–2 |
| 400 | `BAD_REQUEST` | `EMPTY_TARGET` | 目标为空 |
| 400 | `BAD_REQUEST` | `BAD_LANE` | lane 不在 1–3 |
| 400 | `BAD_REQUEST` | `BAD_ROW` | row 不是 front/back |
| 400 | `BAD_REQUEST` | `BAD_REQUEST_KEY` | request_key 格式错 |
| 400 | `BAD_REQUEST` | `UNKNOWN_TARGET` | 城不在本局 |
| 400 | `BAD_REQUEST` | `NOT_ADJACENT` | 目标不与己方领土相邻（无领土时放行） |
| 400 | `BAD_REQUEST` | `CHANGAN_LOCKED` | 第 1–2 周打长安 |
| 400 | `BAD_REQUEST` | `SEASON_FINAL_WEEK` | 第 4 周打了长安及其邻城以外的城 |
| 400 | `BAD_REQUEST` | `UNKNOWN_TACTIC: x` | 卡 code 不认识 |
| 400 | `BAD_REQUEST` | `CARD_NOT_IN_HAND: x` | 卡不在手牌 |
| 400 | `BAD_REQUEST` | `CARD_ALREADY_PLAYED: x` | 同一张卡已在别的槽 |
| 400 | `BAD_REQUEST` | `PLAY_LIMIT_REACHED` | 已出 3 张还要开新槽 |
| 500 | `INTERNAL` | — | 已出 3 张时新增第 4 槽的兜底分支（实际被上一行先拦住，基本不可达） |

**客户端注意**

- **不校验回合状态、截止时间、局是否暂停**。锁定/结算后仍然能写（见风险 R1），客户端必须自己按 `state.can_edit` 禁用。
- `request_key` 只是格式校验，重复 POST 等价于覆盖同一槽，**不是幂等键**。
- 同槽改目标 / 改牌 = 覆盖；`status` 会重新置 `active`（撤过的槽也能再出）。
- 打己方城 = 驻守，结算时该城守军取驻守令前 3 名学生。
- 非队伍牌（`fire_attack` / `scout` / `feint`）不占队伍位，`lane`/`row_pos` 可传 `null`。
- 第 4 周限制只对存在 `node_type='king'` 的图生效（12+1 图）。
- 没有阵营的账号会跳过相邻校验（新局防锁死），但这类账号通常也登录不进来。

**12 张战术**

| code | 名称 | 说明 |
|---|---|---|
| `night_raid` | 夜袭 | 目标未侦察，伤害 +20% |
| `forced_march` | 急行 | 首轮先手，无视断连 |
| `fire_attack` | 火攻 | 器械攻墙 +50%（不占队伍位） |
| `fortify` | 坚壁 | 本队防御 +20% |
| `mutual_support` | 犄角 | 相邻队防御 +10% |
| `empty_fort` | 空城 | 敌军攻击 -10% |
| `last_stand` | 死守 | 本队免疫一次破城 |
| `scout` | 哨探 | 开战前显示敌方一路（不占队伍位） |
| `counter_intel` | 反间 | 敌军攻击 -10% |
| `feint` | 疑兵 | 显示假兵力（不占队伍位） |
| `supply` | 运粮 | 每 15 tick 回复 5% |
| `cut_supply` | 断粮 | 敌军每 15 tick 损失 3% |

> 「队伍牌」= 除 `fire_attack` / `scout` / `feint` 之外的 9 张（`CardSettlementService::TEAM_CARDS`）。

---

### 3.6 `POST /api/slice/order/withdraw`

**Auth**：Bearer ✅
**Body**

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `turn_id` | int | ❌ | 省略用当前回合 |
| `slot` | int | ✅ | 0 / 1 / 2 |

**成功 200（撤回了一张）**

```json
{ "ok": true, "data": { "withdrawn": true }, "server_time": "2026-11-11 21:01:12" }
```

**成功 200（本来就没有）**

```json
{ "ok": true, "data": { "withdrawn": false }, "server_time": "2026-11-11 21:01:12" }
```

**错误**：`400 BAD_REQUEST`（`turn_id<=0`）、`401`

**注意**

- **不校验回合状态/截止时间**：结算后撤牌也会成功，并会改写 `/me/report` 的 `orders`（见风险 R2）。
- 撤牌只把 `status` 改 `withdrawn`，不删行；再出同槽会复用该行。
- 撤牌不返还「已出张数」以外的任何资源，也不退重抽。

---

### 3.7 旧军令（v1，仍在线）

> 5 节点切片时代的「1 令」体系，走 `slice_orders`，与 3 张将令/卡牌结算**并行存在**。12+1 城主玩法不应再调用，但 `Slice.gd` 仍在使用。

#### 3.7.1 `POST /api/slice/orders`

**Auth**：Bearer ✅｜**角色**：学生

**Body**

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `turn_id` | int | ✅ | **无默认值**，`<=0` → 400 |
| `action` | string | ✅ | `advance` / `defend` |
| `target_node` | string | ✅ | 注意字段名是 `target_node`，不是 `target_node_code` |
| `origin_node` | string | advance 必填 | `defend` 会被强制清空 |
| `request_key` | string | ✅ | 8–64 位，真幂等 |

**成功 200**

```json
{
  "ok": true,
  "data": {
    "order": {
      "id": 41, "action": "advance", "action_label": "进军",
      "origin_node_code": "liangzhou", "origin_name": "凉州",
      "target_node_code": "hanzhong", "target_name": "汉中",
      "status": "active", "updated_at": "2026-11-11 20:29:00"
    },
    "turn": { "id": 14, "turn_no": 14, "status": "open",
              "deadline_at": "2026-11-11 20:31:12", "can_edit": true },
    "idempotent": false,
    "message": "军令已确认，可在截止前撤改。",
    "server_time": "2026-11-11 20:29:00"
  },
  "server_time": "2026-11-11 20:29:00"
}
```

重复提交同一 `request_key` → `data.idempotent = true`，其余字段原样回放。

**错误**

| HTTP | code | 触发 |
|---|---|---|
| 400 | `BAD_REQUEST` | 缺字段 / `request_key` 格式错 |
| 403 | `FORBIDDEN` | 教师调用、跨局、账号无阵营 |
| 404 | `TURN_NOT_FOUND` | `turn_id` 不存在 |
| 409 | `GAME_PAUSED` | 局非 `running` |
| 409 | `TURN_LOCKED` | 回合非 `open`（details 带 `turn_status`） |
| 409 | `TURN_DEADLINE_PASSED` | 已过截止 |
| 409 | `IDEMPOTENCY_CONFLICT` | 同键不同军令 |
| 400 | `INVALID_TARGET` | 城不存在（`ApiException` 默认 400） |
| 422 | `START_PROTECTED` | 敌方 `node_type='start'` 城 |
| 422 | `NOT_YOUR_CITY` | 出发城/驻守城不是己方 |
| 422 | `NOT_ADJACENT` | 目标不相邻 |

**注意**：一个回合只有一条 `slice_orders`（`turn_id + player_id`），再次提交是覆盖。

#### 3.7.2 `POST /api/slice/orders/withdraw`

**Body**：`turn_id`（必填）、`request_key`（必填）

```json
{
  "ok": true,
  "data": {
    "withdrawn": true, "had_order": true,
    "message": "已撤回军令；若截止前不再下令，将按默认驻守己方起点结算。",
    "turn": { "id": 14, "turn_no": 14, "status": "open",
              "deadline_at": "2026-11-11 20:31:12", "can_edit": true },
    "idempotent": false,
    "server_time": "2026-11-11 20:29:20"
  },
  "server_time": "2026-11-11 20:29:20"
}
```

**注意**

- `withdrawn` 恒为 `true`（表示「请求已处理」），是否真撤到用 `had_order` 判断。
- 与 `/order/withdraw` 不同：这里**校验**局暂停、回合锁定、截止时间。

---

### 3.8 `GET|POST /api/slice/bulletin`（每日邸报）

**Auth**：Bearer ✅｜**角色**：学生

#### GET

**Query**：`turn_id`（可选）

```json
{
  "ok": true,
  "data": {
    "turn_id": 14,
    "options": [
      { "code": "grain", "title": "粮草先行", "desc": "你的队伍本回合兵力 +5%", "icon": "🌾" },
      { "code": "ram",   "title": "攻城器械", "desc": "你的队伍本回合攻城伤害 +25%", "icon": "🪵" }
    ],
    "choice": null
  },
  "server_time": "2026-11-11 21:01:32"
}
```

#### POST

**Body**：`turn_id`（可选）、`choice`（必填，必须是当日两个选项之一）

返回结构同 GET；`choice` 变为所选 code。

**错误**

| HTTP | code | 触发 |
|---|---|---|
| 400 | `BAD_REQUEST` | 缺 `choice` / `turn_id`，或 `choice` 不在当日选项 |
| 401 | `UNAUTHORIZED` | |

**注意**

- 三个备选 `grain` / `ram` / `scout`，每人每天**只出现两个**（按 `crc32` 确定性抽取）。
- 结算前可反复改，结算按最终值生效。
- 效果：`grain` 队伍兵力 ×1.05；`ram` 攻城伤害 +25%（每名先锋叠加，最多 +75%）；`scout` 全图敌城守军可见（会体现在 `state.scouted_nodes`）。
- 效果只在**卡牌结算**（`/admin/card-settle`）里生效，旧军令结算不读邸报。
- 目前 Godot 前端没有调用本接口（只读 `state.bulletin`），改选必调 POST。

---

### 3.9 `GET /api/slice/merit`（军功）

**Auth**：Bearer ✅｜**角色**：学生（教师也可查，但数据为空/他人榜）
**Query**

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `turn_id` | int | ❌ | 只用于推导默认 `week` |
| `week` | int | ❌ | 指定周；服务端 clamp 到 1–4 |

**成功 200**

```json
{
  "ok": true,
  "data": {
    "week_no": 2,
    "me": {
      "total": 186, "week": 96, "week_no": 2,
      "rank": 3, "week_rank": 2,
      "roles": [
        { "kind": "vanguard", "label": "先锋", "week": 2, "rank": 1 },
        { "kind": "scout",    "label": "侦察", "week": 2, "rank": 2 }
      ],
      "breakdown": { "vanguard": 60, "capture": 80, "participation": 25, "scout": 8, "assault": 13 },
      "recent": [
        { "turn_no": 13, "kind": "capture", "label": "破城", "amount": 40,
          "detail": { "node_code": "hanzhong", "role": "vanguard" } }
      ]
    },
    "top": [
      { "player_id": 11, "nickname": "青竹一", "faction": "bi", "faction_name": "笔",
        "color": "#B83B32", "total": 186 }
    ],
    "week_top": [
      { "player_id": 11, "nickname": "青竹一", "faction": "bi", "faction_name": "笔",
        "color": "#B83B32", "total": 96 }
    ]
  },
  "server_time": "2026-11-11 21:01:38"
}
```

**错误**：`401`

**注意**

- `roles` 只列本周有分的角色，取值来自 `vanguard/support/scout/defend/fire`。
- `recent` 最多 8 条，按回合倒序。
- 榜单条数固定 10（服务层上限 50）。
- `state.merit` 就是这里的 `me`，首屏不必再请求。
- 军功**不影响战力、不写 `students.score`**，只用于小院升级与荣誉。

**计分口径**（`CardSettlementService`）

| kind | 分值 | 条件 |
|---|---|---|
| `participation` | 5 | 本回合有任意活跃令 |
| `vanguard` | 20 | 进入该城先锋 3 人 |
| `capture` | 40 | 先锋且该城易主 |
| `assault` | 10 | 先锋且 `score > 0`（未破城） |
| `support` | 10 | 同阵营非先锋支援 |
| `capture_support` | 15 | 支援且该城易主 |
| `scout` | 8 | 本城打出哨探 |
| `fire` | 10 | 本城打出火攻 |
| `garrison` | 15 | 真实驻守（守方前 3 人） |
| `defend` | 30 | 驻守且未失城 |

---

### 3.10 `GET /api/slice/estate`（文房小院）

**Auth**：Bearer ✅｜**角色**：学生
**Query**：`turn_id`（可选，仅用于推导周次）

**成功 200**

```json
{
  "ok": true,
  "data": {
    "home_node": { "code": "liangzhou", "name": "凉州" },
    "level": 2,
    "banner": "",
    "merit_total": 186,
    "merit_spent": 30,
    "merit_balance": 156,
    "next_level_at": 300,
    "rooms": [
      { "code": "study", "name": "书房", "icon": "📜", "level": 2, "max_level": 3,
        "effect": "每日可预读 2 张未抽到的牌", "next_effect": "每日可预读 3 张未抽到的牌", "next_cost": 80 },
      { "code": "drill", "name": "练兵场", "icon": "⚔", "level": 1, "max_level": 3,
        "effect": "每周可改 1 次编成", "next_effect": "每周可改 2 次编成", "next_cost": 30 },
      { "code": "tower", "name": "望楼", "icon": "🔭", "level": 1, "max_level": 3,
        "effect": "侦察时多看 1 座邻城", "next_effect": "侦察时多看 2 座邻城", "next_cost": 30 }
    ],
    "influence": [ { "code": "hanzhong", "name": "汉中", "count": 2, "merit": 43 } ],
    "governorships": [ { "code": "liangzhou", "name": "凉州", "week": 2, "merit": 30 } ]
  },
  "server_time": "2026-11-11 21:01:42"
}
```

**错误**：`409 ESTATE_NO_HOME`（找不到阵营起始城）、`401`

**注意**

- 首次调用会创建小院行（`ensure`），出生城 = 阵营 `start_node_code`。
- `level` = 三个房间的最高等级，不是总和。
- `next_level_at` 只是展示值（`level×150`），**升级实际扣的是固定价 30 / 80**，两者不是同一套规则。
- `influence` 看最近 7 个回合，最多 5 城。
- `governorships` 只返回**参数周**的太守记录。

---

### 3.11 `POST /api/slice/estate/upgrade`

**Auth**：Bearer ✅｜**角色**：学生
**Body**

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `room` | string | ✅ | `study` / `drill` / `tower` |
| `turn_id` | int | ❌ | 不参与逻辑 |

**成功 200**：返回升级后的完整 `estate` 结构，并多一个字段：

```json
{
  "ok": true,
  "data": {
    "home_node": { "code": "liangzhou", "name": "凉州" },
    "level": 2,
    "banner": "",
    "merit_total": 186,
    "merit_spent": 60,
    "merit_balance": 126,
    "next_level_at": 300,
    "rooms": [ ],
    "influence": [ ],
    "governorships": [ ],
    "upgraded": { "room": "study", "level": 2, "spent": 30 }
  },
  "server_time": "2026-11-11 21:01:50"
}
```

**错误**

| HTTP | code | details | 触发 |
|---|---|---|---|
| 400 | `ESTATE_BAD_ROOM` | — | room 不认识 |
| 409 | `ESTATE_MAX_LEVEL` | — | 已 3 级 |
| 409 | `ESTATE_INSUFFICIENT_MERIT` | `{balance, cost, gap}` | 军功余额不足 |
| 409 | `ESTATE_NO_HOME` | — | 无阵营起始城 |

**注意**

- 价格：2 级 30、3 级 80（`EstateService::COSTS`）。
- 示例中 `rooms` / `influence` / `governorships` 做了省略，结构与 `GET /api/slice/estate` 完全一致。
- 余额 = 军功总收入 − `spent_merit`，与 `/merit` 的 `total` 同源。
- 只给便利：书房预读、练兵场改编成次数、望楼侦察范围，**不加战力**。

---

### 3.12 `GET /api/slice/me/report`（个人战报）

**Auth**：Bearer ✅｜**角色**：学生
**Query**：`turn_id`（可选，默认当前；`<=0` → 400）

**成功 200**

```json
{
  "ok": true,
  "data": {
    "turn_no": 13,
    "settled_at": "2026-11-11 20:21:14",
    "orders": [
      { "slot": 0, "card": "night_raid", "node_code": "hanzhong", "node_name": "汉中",
        "lane": 1, "row": "front", "role": "vanguard",
        "damage": 300.6, "wall_damage": 120.0, "troops_lost": 80.0,
        "contribution": 0.33, "captured": true }
    ],
    "battles_joined": 1,
    "damage": 300.6,
    "wall_damage": 120.0,
    "troops_lost": 80.0,
    "merit": {
      "turn_total": 65,
      "items": [
        { "kind": "vanguard", "label": "先锋", "amount": 20 },
        { "kind": "capture",  "label": "破城", "amount": 40 },
        { "kind": "participation", "label": "出令", "amount": 5 }
      ]
    },
    "highlight": "你的队伍参与了汉中的破城，贡献 33%"
  },
  "server_time": "2026-11-11 21:01:56"
}
```

**错误**

| HTTP | code | 触发 |
|---|---|---|
| 400 | `BAD_REQUEST` | 缺 `turn_id` 且无当前回合 |
| 404 | `TURN_NOT_FOUND` | 回合不属于本局 |
| 409 | `REPORT_NOT_READY` | 回合未结算 |

**注意**

- `role` 取值：`vanguard` / `support` / `garrison` / `scout` / `fire` / `feint` / `reserve`。
- 只有真的进入 `slice_battles` 的玩家才有 `damage/wall_damage/troops_lost/contribution`；否则为 `0`、`contribution=0`。
- `orders` 读的是**当前** `slice_order_slots.status='active'`，所以结算后撤牌会改这份战报（见风险 R2）。
- 卡牌局的战报走这里；旧军令结算的战报在 `/report` 的 `me` 里。

---

### 3.13 `POST /api/slice/battle/forecast`（战前军议）

**Auth**：Bearer ✅｜**角色**：学生
**Body**

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `turn_id` | int | ❌ | 省略用当前回合 |
| `node` | string | ✅ | 城池 code；也接受别名 `node_code` |

**成功 200（可预估）**

```json
{
  "ok": true,
  "data": {
    "node_code": "hanzhong",
    "node_name": "汉中",
    "role": "attack",
    "ready": true,
    "intel_known": false,
    "attacker": {
      "faction_id": 1,
      "troops": 1305.0,
      "teams": [
        { "type": "cav", "troops": 435.0, "lane": 1, "row": "front",
          "card": "night_raid", "player_id": 11, "bulletin": "ram" }
      ],
      "supporters": 1,
      "support_mult": 1.224,
      "camp_bonus": true,
      "region_bonus": false
    },
    "defender": {
      "known": false,
      "faction_id": null,
      "troops": null,
      "troops_range": [562, 1043],
      "teams": [],
      "real_garrison": false,
      "pass_bonus": false
    },
    "forecast": {
      "wall": 448.3, "score": 1, "ticks": 49,
      "morale_before": 0, "morale_after": 1, "morale_cap": 3,
      "capture_estimate": false, "verdict": "优势"
    },
    "counters": { "cav>shield": 3 },
    "counter_damage": { "cav>shield": 120.5 },
    "advice": ["守军未知，先派哨探或接受风险。", "带火攻可让器械攻墙 +50%。"]
  },
  "server_time": "2026-11-11 21:02:02"
}
```

**未就绪的三种形态**

```json
{
  "ok": true,
  "data": {
    "node_code": "liangzhou", "node_name": "凉州",
    "role": "defend", "ready": false, "reason": "DEFEND_CITY",
    "advice": ["这是己方城，出令 = 驻守；战前预估只用于进攻。"]
  },
  "server_time": "2026-11-11 21:02:02"
}
```

```json
{
  "ok": true,
  "data": {
    "node_code": "hanzhong", "node_name": "汉中",
    "role": "attack", "ready": false, "reason": "NO_ORDERS",
    "advice": ["先给这座城出一张令，再来预估。"]
  },
  "server_time": "2026-11-11 21:02:02"
}
```

```json
{
  "ok": true,
  "data": {
    "node_code": "hanzhong", "node_name": "汉中",
    "role": "attack", "ready": false, "reason": "NO_VANGUARD",
    "advice": ["队伍牌才能进战场；火攻/侦察/疑兵不占队伍位。"]
  },
  "server_time": "2026-11-11 21:02:02"
}
```

**错误**

| HTTP | code | 触发 |
|---|---|---|
| 400 | `BAD_REQUEST` | 缺 `turn_id` 或 `node` |
| 404 | `NODE_NOT_FOUND` | 城不在本局 |
| 409 | `NO_FACTION` | 玩家没有阵营 |

**注意**

- **不落库**：不写 `slice_battles`、不改民心、不发军功、不改回合状态。
- `role=defend` 时永远 `ready=false`，不要拿它模拟守城。
- `intel_known=false` 时 `defender.troops=null`、`teams=[]`，只给 `troops_range`（±30%）；`intel_known` 为真当且仅当：中立城 / 己方城 / 本回合对该城打了哨探 / 邸报选了 `scout`。
- `attacker.support_mult` 已含卡牌结算的 ×1.20 系数；`defender.support_mult` 不含。
- 预估用当前**已出**的令，所以同一批令下结果与正式结算一致（正式结算还会按票数决定攻方，可能不同）。
- 示例中 `attacker.teams` 只保留 1 支，实际最多 3 支；`troops` 是各队合计。
- `attacker.siege_mult`（邸报攻城叠加）**没有**出现在返回里，玩家看不到 +75% 的来源，见 6.4-13。

---

## 4. 战斗与回放

### 4.1 `GET /api/slice/battle?id=`

**Auth**：Bearer ✅｜**角色**：学生/教师（只校验同局）
**Query**

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `id` | int | ✅ | `battle_id` |

**成功 200**

```json
{
  "ok": true,
  "data": {
    "id": 37,
    "game_id": 2,
    "turn_id": 13,
    "node_code": "hanzhong",
    "att_faction_id": 1,
    "def_faction_id": null,
    "attacker": {
      "general": "def",
      "teams": [
        { "type": "cav", "troops": 435.0, "lane": 1, "row": "front",
          "card": "night_raid", "player_id": 11, "bulletin": "ram" }
      ],
      "troops": 1305.0, "scouted": true, "fire": true,
      "supporters": 1, "support_mult": 1.224, "siege_mult": 1.25,
      "camp_bonus": true, "region_bonus": false
    },
    "defender": {
      "general": "def", "teams": [], "troops": 803.0,
      "real_garrison": false, "pass_bonus": false,
      "supporters": 0, "support_mult": 1.0
    },
    "log": {
      "wall": 448.3, "score": 1, "ticks": 49,
      "att_slots": { },
      "def_slots": { },
      "att_formation": "mixed",
      "def_formation": "mixed",
      "units": [ ],
      "final_units": [ ],
      "players": {
        "11": { "damage": 300.6, "wall_damage": 120.0, "troops_initial": 435.0,
                "troops_lost": 80.0, "teams": 1, "contribution": 0.333 }
      },
      "counters": { "cav>shield": 3 },
      "counter_damage": { "cav>shield": 120.5 },
      "events": [ ]
    },
    "result": { "wall": 448.3, "score": 1, "ticks": 49, "headline": "撼城" }
  },
  "server_time": "2026-11-11 21:02:10"
}
```

**错误**

| HTTP | code | 触发 |
|---|---|---|
| 404 | `NOT_FOUND` | 战斗不存在、`id` 缺失（按 0 查）、或属于别的局 |

**注意**

- `log` 是完整引擎输出（`BattleEngine::resolve`）：`att_slots/def_slots/att_formation/def_formation/units/final_units/players/counters/counter_damage/events`。
- `log.result` 被服务端补成与顶层 `result` 同结构，可直接喂 `BattleReplay`。
- `BattleEngine` 是确定性的：同输入同输出，60 tick 上限，`score` ∈ {-1, 0, 1, 2}，`headline` ∈ {被挡/对峙/撼城/破城}。
- **越权口径是「同局」不是「本人」**：同局任何学生都能读任意 `battle_id`（见风险 R7）。
- 示例中 `attacker.teams` / `units` / `final_units` / `events` 均做了截断：`teams` 实际最多 3 支，`units` 为 6 支初始队伍，`events` 可达数百条。

---

### 4.2 `POST /api/slice/battle/demo`（演示战斗）

**Auth**：Bearer ✅｜**角色**：学生（教师调用会 404 `PET_NOT_FOUND`）
**Body**

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `turn_id` | int | ❌ | 省略用当前回合 |
| `node_code` | string | ❌ | 默认 `hanzhong`；只写进记录，不校验存在 |
| `fire` | bool | ❌ | 默认 `false` |

**成功 200**

```json
{
  "ok": true,
  "data": {
    "battle_id": 38,
    "attacker": {
      "general": "def",
      "troops": 1566.0,
      "composition": ["cav", "shield", "arc"],
      "fire": true
    },
    "defender": {
      "general": "atk",
      "troops": 1320.0,
      "composition": ["shield", "spear", "arc"]
    },
    "log": {
      "wall": 0, "score": 2, "ticks": 52,
      "att_slots": { }, "def_slots": { },
      "att_formation": "mixed", "def_formation": "mixed",
      "units": [ ], "final_units": [ ],
      "players": { },
      "counters": { "cav>shield": 4 },
      "counter_damage": { "cav>shield": 210.4 },
      "events": [ ],
      "result": { "wall": 0, "score": 2, "ticks": 52, "headline": "破城" }
    }
  },
  "server_time": "2026-11-11 21:02:16"
}
```

**错误**

| HTTP | code | 触发 |
|---|---|---|
| 400 | `BAD_REQUEST` | 缺 `turn_id` 且无当前回合 |
| 404 | `PET_NOT_FOUND` | 玩家无班宠 |

**注意**

- 攻方：`general` 由班宠模板决定（`pet_inkdrop_01 → tac`，其余 `def`）；`troops = petPower × 1.20`；`composition` = 当前周编成；`fire` 取 body。
- 守方：固定 `atk` 将、`1320` 兵、`[shield, spear, arc]`。
- **会真实写 `slice_battles`**，但**不改民心/归属/回合状态**；要改城必须再调 `/battle/settle`。
- 不校验回合是否可编辑，任何时刻都能造演示战。

---

### 4.3 `POST /api/slice/battle/settle`（战斗落城）

**Auth**：Bearer ✅｜**角色**：任意同局账号
**Body**

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `battle_id` | int | ✅ | |

**成功 200**

```json
{
  "ok": true,
  "data": {
    "node_code": "hanzhong",
    "cap": 3,
    "morale_before": 0,
    "morale_after": 1,
    "owner_before": null,
    "owner_after": null,
    "captured": false,
    "reason": "morale_push"
  },
  "server_time": "2026-11-11 21:02:22"
}
```

**错误**

| HTTP | code | 触发 |
|---|---|---|
| 404 | `NOT_FOUND` | 战斗不存在/跨局 |
| 500 | `INTERNAL` | 城池行缺失（`BattleSettlementService` 抛 `RuntimeException`） |

**注意**

- 民心：`delta = clamp(score, -1, 2)`；`after = clamp(before+delta, 0, cap)`；`after >= cap` 且攻方不是现主 → 易主、民心清零。
- `cap`：`king`=5；`camp/pass/ferry/culture/water`=3；其余=2。
- `reason`：`captured` / `morale_push` / `morale_recede` / `hold`。
- **非幂等**：同一 `battle_id` 连点会重复推民心（见风险 R4）。客户端必须在成功后禁用按钮并刷新 `state`。
- `score` 取的是战斗当次结果，与“现在”的出令无关。

---

### 4.4 `GET /api/slice/report?turn_id=`

**Auth**：Bearer ✅
**Query**：`turn_id`（**必填**）

**成功 200**

```json
{
  "ok": true,
  "data": {
    "turn": {
      "id": 13, "turn_no": 13, "status": "settled", "status_label": "已结算",
      "opens_at": "2026-11-11 20:11:12", "deadline_at": "2026-11-11 20:21:12",
      "locked_at": "2026-11-11 20:21:13", "settled_at": "2026-11-11 20:21:14",
      "seconds_remaining": 0, "can_edit": false, "snapshot_id": 13,
      "failure_reason": null, "rules_version": "cards_v1"
    },
    "report": {
      "mode": "cards",
      "battles": [
        {
          "node_code": "hanzhong",
          "battle_id": 37,
          "score": 1,
          "wall": 448.3,
          "attacker_faction_id": 1,
          "owner_before": null,
          "owner_after": null,
          "captured": false,
          "morale_before": 0,
          "morale_after": 1,
          "reason": "morale_push",
          "scouted": true,
          "fire": true,
          "teams": [ ],
          "defender_teams": [ ],
          "real_garrison": false,
          "merit": { "11": { "total": 65, "items": [ ] } },
          "contribution": { "11": { "damage": 300.6, "wall_damage": 120.0,
                                    "troops_lost": 80.0, "contribution": 0.333 } },
          "counters": { "cav>shield": 3 },
          "counter_damage": { "cav>shield": 120.5 }
        }
      ],
      "result_id": 13,
      "content_hash": "1f0c…"
    },
    "me": {
      "merit": { "turn_total": 35, "items": [
        { "kind": "vanguard", "label": "先锋", "amount": 20 },
        { "kind": "assault",  "label": "攻城", "amount": 10 },
        { "kind": "participation", "label": "出令", "amount": 5 }
      ] }
    },
    "me_report": {
      "turn_no": 13,
      "settled_at": "2026-11-11 20:21:14",
      "orders": [
        { "slot": 0, "card": "night_raid", "node_code": "hanzhong", "node_name": "汉中",
          "lane": 1, "row": "front", "role": "vanguard",
          "damage": 300.6, "wall_damage": 120.0, "troops_lost": 80.0,
          "contribution": 0.333, "captured": false }
      ],
      "battles_joined": 1,
      "damage": 300.6, "wall_damage": 120.0, "troops_lost": 80.0,
      "merit": { "turn_total": 35, "items": [ ] },
      "highlight": "你在汉中打出 301 伤害，贡献 33%"
    }
  },
  "server_time": "2026-11-11 21:02:30"
}
```

**错误**

| HTTP | code | 触发 |
|---|---|---|
| 400 | `BAD_REQUEST` | 缺 `turn_id` |
| 404 | `TURN_NOT_FOUND` | 回合不存在 |
| 403 | `FORBIDDEN` | 跨局 |
| 409 | `REPORT_NOT_READY` | 回合未结算（details 带 `turn_status`） |

**注意**

- `report` 的形态取决于**哪种结算先跑**：
  - 卡牌结算：`{mode:'cards', battles:[...], result_id, content_hash}`；
  - 旧军令结算：`{turn_id, turn_no, headline, summary, node_changes[], orders[], standings, is_final_turn, scoring_note, result_id, content_hash}`。
  客户端不要假设 `node_changes` 一定存在。
- `me` 只有在**旧军令**结算过时才有 `order/outcome/readable_text`；卡牌局里是 `{merit:{...}}`，正文用 `me_report`。
- `me.order` 的 `action_label` 对默认驻守是「默认驻守」，`outcome.contribution` 恒为 1（旧体系按人计 1 点）。
- 战报页要兼容两种形态（见 6.4-10）。

旧军令结算（`/admin/settle`）后的 `report` / `me` 形态：

```json
{
  "report": {
    "turn_id": 14, "turn_no": 14, "rules_version": "cards_v1",
    "settled_at": "2026-11-11 21:03:02",
    "headline": "第 14 回合：汉中易主",
    "summary": { "captured": 1, "defended": 2, "held": 5, "neutral_held": 2,
                 "no_action": 3, "start_protected": 0 },
    "node_changes": [
      { "node_code": "hanzhong", "node_name": "汉中", "is_start": false,
        "owner_before": null,
        "owner_after": { "id": 1, "code": "bi", "name": "笔", "color": "#B83B32" },
        "winner": { "id": 1, "code": "bi", "name": "笔", "color": "#B83B32" },
        "scores": { "bi": 2, "mo": 1 }, "score_rows": [ ],
        "breakdown": { "bi": { "advance": 2, "defend": 0, "default_defend": 0 } },
        "order_details": [ ], "reason": "captured",
        "reason_text": "【汉中】笔 2，墨 1；笔夺取汉中。", "changed": true }
    ],
    "orders": [ ],
    "standings": null,
    "is_final_turn": false,
    "scoring_note": "进军 1 点；驻守 1 点；原归属方 +1 基础守备；中立城无基础守备。",
    "result_id": 14, "content_hash": "1f0c…"
  },
  "me": {
    "order": { "action": "advance", "action_label": "进军",
               "origin_node_code": "liangzhou", "target_node_code": "hanzhong",
               "target_name": "汉中", "is_default": false },
    "outcome": { "target_node_code": "hanzhong", "target_name": "汉中",
                 "owner_before": null, "owner_after": null, "winner": null,
                 "scores": { "bi": 2, "mo": 1 }, "reason": "defended",
                 "reason_text": "【汉中】笔 2，墨 1；笔守住了汉中。",
                 "result": "failed", "contribution": 1, "is_default": false,
                 "changed": false,
                 "next_hint": "目标有守备或双方同分；下回合可集中两路进军，或先驻守己方前沿。" },
    "readable_text": "你的进军未能拿下【汉中】。……",
    "merit": { "turn_total": 0, "items": [ ] }
  }
}
```

> `me_report` 在旧结算下仍会返回，但 `orders` 读的是 `slice_order_slots`（手牌槽），旧军令玩家的槽位通常为空 → `orders=[]`、`damage=0`。

---

### 4.5 `GET /api/slice/replay`（战局回放）

**Auth**：Bearer ✅
**Query**：无

**成功 200**

```json
{
  "ok": true,
  "data": {
    "game": { "code": "MAP12_TEST", "name": "12+1 城·九州测试" },
    "nodes": [
      { "code": "liangzhou", "name": "凉州", "x": 688, "y": 461, "type": "camp" },
      { "code": "hanzhong",  "name": "汉中", "x": 1229, "y": 654, "type": "pass" }
    ],
    "edges": [["liangzhou", "hanzhong"]],
    "turns": [
      {
        "turn_id": 13,
        "turn_no": 13,
        "settled_at": "2026-11-11 20:21:14",
        "headline": "第 13 回合：汉中易主",
        "changes": [
          { "node_code": "hanzhong", "node_name": "汉中",
            "owner_before": null,
            "owner_after": { "id": 1, "code": "bi", "name": "笔", "color": "#B83B32" },
            "scores": { "bi": 2, "mo": 1 },
            "reason": "captured",
            "reason_text": "【汉中】笔 2，墨 1；笔夺取汉中。",
            "changed": true }
        ],
        "owners": {
          "liangzhou": { "id": 1, "code": "bi", "name": "笔", "color": "#B83B32" },
          "hanzhong":  { "id": 1, "code": "bi", "name": "笔", "color": "#B83B32" }
        },
        "standings": null
      }
    ]
  },
  "server_time": "2026-11-11 21:02:36"
}
```

**错误**：`401`

**注意**

- `owners` 是**累积到该回合结束**的快照，客户端逐回合播放即可，不要自己累加 `changes`。
- `turns` 只含 `status='settled'` 且存在 `slice_turn_results` 的回合。
- `standings` 只在**最后一回合**（旧结算体系里 `turn_no>=3`）或卡牌结算结果里才有；否则 `null`。
- `nodes[].type` 用于上色/图标；`nodes` 不含民心与当前归属，归属看 `owners`。
- **卡牌结算的回合 `changes` 为空**（结果里没有 `node_changes`），见 6.4-10。

---

## 5. 教师控制

> 通用：所有 `/api/slice/admin/*` 都要求 `role='teacher'`，否则 403 `FORBIDDEN`「只有教师可以执行该操作」。
> 教师台两个入口：`GET /teacher`（HTML，功能最全）与 Godot 内置教师面板（只覆盖部分接口，且有 payload bug）。

### 5.1 `GET /api/slice/admin/status`

**Auth**：Bearer ✅｜**教师**

**成功 200**

```json
{
  "ok": true,
  "data": {
    "game": { "id": 2, "code": "MAP12_TEST", "name": "12+1 城·九州测试",
              "status": "running", "current_turn_id": 14 },
    "participants": 8,
    "turns": [
      {
        "turn": { "id": 14, "turn_no": 14, "status": "open", "status_label": "可下令",
                  "opens_at": "2026-11-11 20:21:12", "deadline_at": "2026-11-11 20:31:12",
                  "locked_at": null, "settled_at": null, "seconds_remaining": 372,
                  "can_edit": true, "snapshot_id": null, "failure_reason": null,
                  "rules_version": "cards_v1" },
        "active_orders": 5,
        "withdrawn_orders": 1,
        "job": null,
        "headline": null
      },
      {
        "turn": { "id": 13, "turn_no": 13, "status": "settled", "status_label": "已结算",
                  "opens_at": "2026-11-11 20:11:12", "deadline_at": "2026-11-11 20:21:12",
                  "locked_at": "2026-11-11 20:21:13", "settled_at": "2026-11-11 20:21:14",
                  "seconds_remaining": 0, "can_edit": false, "snapshot_id": 13,
                  "failure_reason": null, "rules_version": "cards_v1" },
        "active_orders": 4,
        "withdrawn_orders": 0,
        "job": { "status": "done", "attempts": 1, "last_error": null,
                 "started_at": "2026-11-11 20:21:13", "finished_at": "2026-11-11 20:21:14" },
        "headline": "第 13 回合：汉中易主"
      }
    ]
  },
  "server_time": "2026-11-11 21:02:44"
}
```

**错误**：`403 FORBIDDEN`、`404 GAME_NOT_FOUND`

**注意**

- `active_orders/withdrawn_orders` 统计的是**旧军令** `slice_orders`，不是手牌槽位 `slice_order_slots`。看卡牌局出令数请用 `state.orders_confirmed`。
- `job` 来自 `slice_settlement_jobs`，只有旧结算链路会写。

---

### 5.2 `POST /api/slice/admin/lock`（锁令 + 快照）

**Auth**：Bearer ✅｜**教师**
**Body**

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `turn_id` | int | ✅ | |
| `force` | bool | ❌ | 提前锁令；需 `app.allow_force_lock=true` |

**成功 200（新锁）**

```json
{
  "ok": true,
  "data": {
    "already": false,
    "settled": false,
    "turn": { "id": 14, "turn_no": 14, "status": "locked", "status_label": "已锁定，待结算",
              "opens_at": "2026-11-11 20:21:12", "deadline_at": "2026-11-11 20:31:12",
              "locked_at": "2026-11-11 21:02:50", "settled_at": null,
              "seconds_remaining": 0, "can_edit": false, "snapshot_id": 21,
              "failure_reason": null, "rules_version": "cards_v1" },
    "snapshot": {
      "snapshot_id": 21,
      "content_hash": "8a3f…",
      "orders_count": 8,
      "default_count": 1,
      "locked_at": "2026-11-11 21:02:50"
    },
    "message": "已锁定并生成只读快照，接下来可以结算。"
  },
  "server_time": "2026-11-11 21:02:50"
}
```

**成功 200（已锁过）**

```json
{
  "ok": true,
  "data": {
    "already": true, "settled": false,
    "turn": { "id": 14, "turn_no": 14, "status": "locked", "status_label": "已锁定，待结算" },
    "snapshot": { "snapshot_id": 21, "content_hash": "8a3f…",
                  "orders_count": 8, "default_count": 1,
                  "created_at": "2026-11-11 21:02:50" }
  },
  "server_time": "2026-11-11 21:02:52"
}
```

**成功 200（已结算）**

```json
{
  "ok": true,
  "data": {
    "already": true, "settled": true,
    "turn": { "id": 14, "turn_no": 14, "status": "settled", "status_label": "已结算" },
    "message": "本回合已结算。"
  },
  "server_time": "2026-11-11 21:02:54"
}
```

**错误**

| HTTP | code | details | 触发 |
|---|---|---|---|
| 403 | `FORBIDDEN` | — | 非教师 / `force` 不被环境允许 |
| 404 | `TURN_NOT_FOUND` | — | 回合不存在/跨局 |
| 409 | `TURN_NOT_OPEN` | `{turn_status}` | 回合是 `settling/failed` 等 |
| 409 | `DEADLINE_NOT_REACHED` | `{deadline_at}` | 未过截止且 `force=false` |

**注意**

- 快照只对**旧军令** `slice_orders` 生成（`buildSnapshot`），未下令的学生按「默认驻守己方起点」补一条。
- 上面第二个示例的 `turn` 做了截断，实际始终返回完整 `turnPublic`（与第一个示例同结构）。
- 卡牌结算不需要快照，也不需要锁令；`card-settle` 不看 `snapshot_id`。
- `snapshotSummary` 返回的 `created_at` 与首次返回的 `locked_at` 字段名不同。

---

### 5.3 `POST /api/slice/admin/settle`（旧军令结算）

**Auth**：Bearer ✅｜**教师**
**Body**

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `turn_id` | int | ✅ | |
| `inject_failure` | bool | ❌ | 仅当 `app.allow_fault_injection=true` 可注入一次失败 |

**成功 200**

```json
{
  "ok": true,
  "data": {
    "turn_id": 14,
    "turn_no": 14,
    "rules_version": "cards_v1",
    "settled_at": "2026-11-11 21:03:02",
    "headline": "第 14 回合：汉中易主",
    "summary": { "captured": 1, "defended": 2, "held": 5, "neutral_held": 2,
                 "no_action": 3, "start_protected": 0 },
    "node_changes": [
      {
        "node_code": "hanzhong", "node_name": "汉中", "is_start": false,
        "owner_before": null,
        "owner_after": { "id": 1, "code": "bi", "name": "笔", "color": "#B83B32" },
        "winner": { "id": 1, "code": "bi", "name": "笔", "color": "#B83B32" },
        "scores": { "bi": 2, "mo": 1 },
        "score_rows": [
          { "faction": { "id": 1, "code": "bi", "name": "笔", "color": "#B83B32" },
            "points": 2, "sort_order": 1 }
        ],
        "breakdown": { "bi": { "advance": 2, "defend": 0, "default_defend": 0 } },
        "order_details": [
          { "player_id": 11, "nickname": "青竹一", "pet_name": "小青竹·一",
            "faction": { "id": 1, "code": "bi", "name": "笔", "color": "#B83B32" },
            "action": "advance", "is_default": false }
        ],
        "reason": "captured",
        "reason_text": "【汉中】笔 2，墨 1；笔夺取汉中。",
        "changed": true
      }
    ],
    "orders": [
      { "player_id": 11, "nickname": "青竹一", "pet_name": "小青竹·一",
        "faction": { "id": 1, "code": "bi", "name": "笔", "color": "#B83B32" },
        "action": "advance", "action_label": "进军",
        "origin_node_code": "liangzhou", "origin_name": "凉州",
        "target_node_code": "hanzhong", "target_name": "汉中",
        "is_default": false }
    ],
    "standings": null,
    "is_final_turn": false,
    "scoring_note": "进军 1 点；驻守 1 点；原归属方 +1 基础守备；中立城无基础守备。",
    "result_id": 14,
    "content_hash": "1f0c…"
  },
  "server_time": "2026-11-11 21:03:02"
}
```

**错误**

| HTTP | code | details | 触发 |
|---|---|---|---|
| 403 | `FORBIDDEN` | — | 非教师 / 环境禁止故障注入 |
| 404 | `TURN_NOT_FOUND` | — | |
| 409 | `SETTLE_NOT_READY` | `{turn_status}` | 回合非 `locked/failed/settling` |
| 409 | `SETTLE_NOT_READY` | — | 没有快照 |
| 409 | `SETTLE_RUNNING` | — | 60 秒内已有结算在跑 |
| 500 | `SETTLE_FAILED` | `{turn_id, snapshot_id, reason}` | 结算异常；快照保留可重试 |

**注意**

- 已 `settled` 时直接回既有结果（幂等）。
- **`turn_no >= 3` 就把 `slice_games.status` 置 `finished`**（硬编码 3，与 12 城 28 回合冲突；见 6.4-19）。卡牌结算不改局状态。
- 结算后写 `slice_turn_results` / `slice_node_changes` / `slice_player_reports`，并更新 `slice_nodes.owner_faction_id`。
- **与卡牌结算共用 `slice_turn_results`**：谁先跑谁写，另一个变成 no-op（见风险 R6）。
- `summary` 只统计城，不统计人。

---

### 5.4 `POST /api/slice/admin/card-settle`（卡牌结算，12 城主力）

**Auth**：Bearer ✅｜**教师**（`index.php` 里显式再查一次 role）
**Body**

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `turn_id` | int | ✅ | 缺 → 400 |

**成功 200**

```json
{
  "ok": true,
  "data": {
    "turn_id": 14,
    "already_settled": false,
    "battles": [
      {
        "node_code": "hanzhong",
        "battle_id": 41,
        "score": 2,
        "wall": 0,
        "attacker_faction_id": 1,
        "owner_before": null,
        "owner_after": { "id": 1, "code": "bi", "name": "笔", "color": "#B83B32" },
        "captured": true,
        "morale_before": 2,
        "morale_after": 0,
        "reason": "captured",
        "scouted": true,
        "fire": false,
        "teams": [ ],
        "defender_teams": [ ],
        "real_garrison": false,
        "merit": { "11": { "total": 75, "items": [ ] } },
        "contribution": { "11": { "damage": 512.4, "wall_damage": 210.0,
                                  "troops_lost": 96.2, "contribution": 0.412 } },
        "counters": { "cav>shield": 4 },
        "counter_damage": { "cav>shield": 210.4 }
      },
      { "node_code": "xiangyang", "battle_id": null, "reason": "standoff" },
      { "node_code": "yecheng",   "battle_id": null, "reason": "already_owned" }
    ]
  },
  "server_time": "2026-11-11 21:03:10"
}
```

**已结算过**

```json
{
  "ok": true,
  "data": { "turn_id": 14, "already_settled": true, "battles": [] },
  "server_time": "2026-11-11 21:03:12"
}
```

**错误**

| HTTP | code | 触发 |
|---|---|---|
| 403 | `FORBIDDEN` | 非教师 |
| 400 | `BAD_REQUEST` | 缺 `turn_id` |
| 500 | `INTERNAL` | 回合不存在（`TURN_NOT_FOUND` 被吞成 500） |

**注意**

- 按城聚合 `slice_order_slots`：每城一战；**攻方 = 该城非守方的令数最多的阵营**，并列 → `standoff` 不战。
- 每城结果可能没有 `battle_id`：`already_owned`（只有守方自己的令）/ `standoff`（并列）/ `no_vanguard`（只有火攻/哨探/疑兵）/ `no_faction`。
- 先锋 = 攻方按班宠战力前 3 名学生，一人一队；支援每人 +2%，上限 +30%，另有卡牌结算的 ×1.20。
- 守军：优先取守方驻守令前 3 人；没有才回落固定守军（中立 730×1.10=803，归属 1200×1.10=1320）。
- 增益：邸报 `ram` 攻城叠加、`grain` 兵力 ×1.05、大营 +5%、区域 3 城 +5%、关隘守军 +10%。
- 之后写 `slice_turn_results`（`{mode:'cards', battles}`）、`slice_node_changes`、`slice_battles`、`slice_turn_results`，回合置 `settled`。
- **不发快照、不校验回合是否 open、不写 `slice_player_reports`**。
- 示例中 `battles[].teams` / `defender_teams` 做了截断，实际最多各 3 支。
- 没有事务/行锁；并发双击可能重复结算（见风险 R5）。

---

### 5.5 `POST /api/slice/admin/next-turn`

**Auth**：Bearer ✅｜**教师**
**Body**

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `from_turn_id` | int | ✅ | 也接受别名 `turn_id`；**没有 `game_id` 参数** |

**成功 200（新建）**

```json
{
  "ok": true,
  "data": {
    "created": true,
    "turn": { "id": 15, "turn_no": 15, "status": "open", "status_label": "可下令",
              "opens_at": "2026-11-11 21:03:20", "deadline_at": "2026-11-11 21:13:20",
              "locked_at": null, "settled_at": null, "seconds_remaining": 600,
              "can_edit": true, "snapshot_id": null, "failure_reason": null,
              "rules_version": "cards_v1" }
  },
  "server_time": "2026-11-11 21:03:20"
}
```

**成功 200（已存在）**

```json
{
  "ok": true,
  "data": {
    "created": false,
    "turn": { "id": 15, "turn_no": 15, "status": "open", "status_label": "可下令" }
  },
  "server_time": "2026-11-11 21:03:22"
}
```

**错误**

| HTTP | code | 触发 |
|---|---|---|
| 403 | `FORBIDDEN` | 非教师 |
| 404 | `TURN_NOT_FOUND` | `from_turn_id` 缺失（0）或不存在 |
| 409 | `SETTLE_NOT_READY` | 当前回合未结算 |
| 409 | `SEASON_FINISHED` | 已到上限（5 城图 3 回合、12 城图 28 回合） |

**注意**

- 上限由城池数推：`count(nodes) >= 13 ? 28 : 3`。
- 新回合 `deadline_at = now + slice_games.turn_seconds`（默认 600 秒），并更新 `slice_games.current_turn_id`。
- 每 7 回合（`turn_no % 7 == 1`）会刷新上一周太守（`refreshGovernors`）。
- **Godot 教师面板传的是 `{game_id}`** → `from_turn_id=0` → 必然 404，见 6.4-15。

---

### 5.6 `POST /api/slice/admin/pause` / `POST /api/slice/admin/resume`

**Auth**：Bearer ✅｜**教师**
**Body**：无

**成功 200**

```json
{ "ok": true, "data": { "status": "paused" }, "server_time": "2026-11-11 21:03:30" }
```

```json
{ "ok": true, "data": { "status": "running" }, "server_time": "2026-11-11 21:03:32" }
```

**错误**

| HTTP | code | 触发 |
|---|---|---|
| 403 | `FORBIDDEN` | 非教师 |
| 409 | `SEASON_FINISHED` | 局已 `finished` |

**注意**

- 只改 `slice_games.status`，不动回合、不冻结 `deadline_at`：暂停期间倒计时照走，恢复后可能已过截止（`can_edit=false`）。
- 暂停后旧军令接口返回 409 `GAME_PAUSED`；**手牌出令接口完全不拦**（见风险 R1）。
- 目前**没有任何前端调用**这个接口。

---

## 6. 路由审计

### 6.1 全量路由 × Service（38 个 JSON 路由）

| # | Method | Path | 实现 / Service | Auth | 角色 | 前端调用方 |
|---|---|---|---|---|---|---|
| 1 | GET | `/api/health` | `SliceService::health` | 无 | — | 无（仅 HTML 首页链接） |
| 2 | POST | `/api/auth/login` | `SliceService::loginStudent` | 无 | — | Godot |
| 3 | POST | `/api/auth/admin-login` | `SliceService::loginAdmin` | 无 | — | Godot |
| 4 | POST | `/api/auth/logout` | `SliceService::logout` | Bearer | 任意 | 仅 `Api.gd` 包装，无 UI 调用 |
| 5 | GET | `/api/slice/state` | `SliceService::getState` + `HandService` + `BulletinService` + `MeritService` + `EstateService` | Bearer | 任意 | Godot（多处） |
| 6 | GET | `/api/slice/season` | `SeasonService::summary` | Bearer | 任意 | `teacher.html` |
| 7 | GET | `/api/slice/season/history` | `SeasonHistoryService::history` | Bearer | 任意 | `teacher.html` |
| 8 | POST | `/api/slice/orders` | `SliceService::submitOrder` | Bearer | 学生 | Godot（旧面板） |
| 9 | POST | `/api/slice/orders/withdraw` | `SliceService::withdrawOrder` | Bearer | 学生 | Godot（旧面板） |
| 10 | GET | `/api/slice/hand` | `HandService::getOrCreateHand/getComposition/getOrders` | Bearer | 任意 | **无** |
| 11 | POST | `/api/slice/hand/redraw` | `HandService::redraw` | Bearer | 任意 | Godot |
| 12 | GET | `/api/slice/intel` | **`index.php` 内联 SQL** + `BattleEngine::TYPES` + `BattleService::petPower` | Bearer | 任意 | Godot |
| 13 | GET | `/api/slice/bulletin` | `BulletinService::summary` | Bearer | 任意 | **无** |
| 14 | POST | `/api/slice/bulletin` | `BulletinService::choose` | Bearer | 任意 | **无** |
| 15 | GET | `/api/slice/merit` | `MeritService::summary/top/weekTop` | Bearer | 任意 | Godot |
| 16 | GET | `/api/slice/me/report` | `PlayerReportService::forTurn` | Bearer | 任意 | Godot + 测试 |
| 17 | GET | `/api/slice/estate` | `EstateService::summary` | Bearer | 任意 | Godot |
| 18 | POST | `/api/slice/estate/upgrade` | `EstateService::upgrade` | Bearer | 任意 | Godot |
| 19 | GET | `/api/slice/composition` | `HandService::getComposition` | Bearer | 任意 | **无** |
| 20 | POST | `/api/slice/composition` | `HandService::setComposition` | Bearer | 任意 | Godot（week 写死 1） |
| 21 | POST | `/api/slice/order/play` | `HandService::play` | Bearer | 任意 | Godot |
| 22 | POST | `/api/slice/order/withdraw` | `HandService::withdraw` | Bearer | 任意 | Godot |
| 23 | POST | `/api/slice/battle/forecast` | `CardSettlementService::forecast` | Bearer | 任意 | **无** |
| 24 | POST | `/api/slice/battle/demo` | **`index.php` 内联 SQL** + `HandService` + `BattleService::resolve/saveBattle` | Bearer | 任意 | Godot + 测试 |
| 25 | GET | `/api/slice/battle` | `BattleService::getBattle` | Bearer | 任意 | 仅包装，无 UI 调用 |
| 26 | POST | `/api/slice/battle/settle` | `BattleSettlementService::apply` | Bearer | 任意 | Godot |
| 27 | GET | `/api/slice/report` | `SliceService::getReport` + `PlayerReportService` + `MeritService` | Bearer | 任意 | Godot |
| 28 | GET | `/api/slice/history` | `SliceService::getHistory` | Bearer | 任意 | **无** |
| 29 | GET | `/api/slice/replay` | `SliceService::getReplay` | Bearer | 任意 | Godot |
| 30 | GET | `/api/slice/wallet` | `SliceService::getWalletForPlayer → PointsService::getWallet` | Bearer | 学生 | 仅包装，无 UI 调用 |
| 31 | POST | `/api/slice/recharge` | `SliceService::rechargePlayer → PointsService::recharge` | Bearer | 学生 | Godot（字段错，见 6.4-16） |
| 32 | GET | `/api/slice/admin/status` | `SliceService::adminStatus` | Bearer | 教师 | `teacher.html` |
| 33 | POST | `/api/slice/admin/lock` | `SliceService::lockTurn` | Bearer | 教师 | Godot + `teacher.html` |
| 34 | POST | `/api/slice/admin/settle` | `SliceService::settleTurn` | Bearer | 教师 | Godot |
| 35 | POST | `/api/slice/admin/card-settle` | `CardSettlementService::settle` | Bearer | 教师 | `teacher.html` |
| 36 | POST | `/api/slice/admin/next-turn` | `SliceService::nextTurn` | Bearer | 教师 | `teacher.html` + Godot（坏） |
| 37 | POST | `/api/slice/admin/pause` | `SliceService::setGameStatus` | Bearer | 教师 | **无** |
| 38 | POST | `/api/slice/admin/resume` | `SliceService::setGameStatus` | Bearer | 教师 | **无** |

另有 3 个非 JSON 入口 + 1 个预检：

| Method | Path | 行为 | Auth |
|---|---|---|---|
| GET | `/teacher` | `readfile(teacher.html)` | 无（页面自己登录） |
| GET | `/teacher.html` | 同上 | 无 |
| GET | `/` | HTML 说明页 | 无 |
| OPTIONS | `*` | 204 + CORS 头 | 无 |

> 合计 **42 个 handler**，其中 **38 个 JSON API**。

**非 HTTP 入口**（同样影响业务状态，排查问题时不要忽略）：

| 入口 | 行为 |
|---|---|
| `php scripts/cron.php` | `SliceService::runDueTurns(true)`：对所有 `running` 局中已过 `deadline_at` 的 `open/locked/failed` 回合执行**旧体系**锁令 + 结算；教师账号只作审计 actor，无需登录 |
| `php scripts/apply_migration.php` | 迁移执行 |
| `php scripts/setup_*.php` / `export_trial.php` | 建库/种子/导出，不参与运行期 |

### 6.2 没有 auth 的路由

| 路由 | 说明 |
|---|---|
| `GET /api/health` | 探活；会暴露 `games` 数量与 PHP 版本 |
| `POST /api/auth/login` | 必须公开 |
| `POST /api/auth/admin-login` | 必须公开 |
| `GET /`、`GET /teacher`、`GET /teacher.html` | 静态页；`teacher.html` 只是登录表单，无数据 |
| `OPTIONS *` | CORS 预检 |

**结论**：`/api/slice/*` 全部要求 Bearer，没有漏鉴权的业务路由。

但要注意「有 auth ≠ 有授权」：

| 路由 | 缺失的授权校验 |
|---|---|
| `/api/slice/hand`、`/hand/redraw`、`/composition`、`/order/play`、`/order/withdraw`、`/bulletin` | **不校验 `role='player'`**，教师账号也能写 |
| `/api/slice/order/play`、`/order/withdraw` | 不校验回合 `status` / 截止时间 / 局暂停 |
| `/api/slice/battle/settle` | 不校验调用者是否本场参与者，同局任意人可落城 |
| `/api/slice/estate/upgrade` | 不校验调用者角色（教师会 409 `ESTATE_NO_HOME`） |
| `/api/slice/admin/settle`、`/lock`、`/next-turn`、pause/resume | 有 role 校验（`requireTeacher`） |
| `/api/slice/admin/card-settle` | role 在 `index.php` 显式校验 |

### 6.3 前端没有调用方的路由

以 Godot 客户端（`client/*.gd`）为准：

| 路由 | 现状 |
|---|---|
| `GET /api/slice/hand` | 无任何包装/调用；首屏靠 `state.hand` |
| `GET /api/slice/bulletin` | 无；只读 `state.bulletin` |
| `POST /api/slice/bulletin` | **无** → 学生无法在 App 里选邸报（只能用 `teacher.html` 之外的界面？实际无人能选） |
| `GET /api/slice/composition` | 无；只调 POST |
| `POST /api/slice/battle/forecast` | 无 → “军议”按钮未接 |
| `GET /api/slice/history` | 仅 `Api.gd` 包装，无 UI 调用 |
| `GET /api/slice/wallet` | 仅包装；UI 用 `state.wallet` |
| `GET /api/slice/battle` | 仅包装；回放走 `/replay` |
| `GET /api/slice/admin/status` | 仅包装；Godot 教师面板「刷新全盘」实际调 `_refresh_state`（`/state`） |
| `POST /api/slice/admin/pause` / `resume` | **完全没有调用方**（Godot 和 teacher.html 都没有按钮） |
| `POST /api/slice/admin/card-settle` | Godot 有包装但无按钮；只有 `teacher.html` 用 |
| `GET /api/slice/season` / `season/history` | Godot 无调用；只有 `teacher.html` |
| `GET /api/health` | 无客户端调用 |
| `POST /api/auth/logout` | 仅包装；Godot 登出是本地清态，不请求 |

### 6.4 文档与实现不一致

| # | 文档说法 | 实现 | 证据 |
|---|---|---|---|
| 1 | `PHASE1` §4：「没有驻守令时回落固定守军（中立 990 / 归属 1320）」 | 中立 **803**、归属 1320；`intel` 里中立一路按 1100/3≈367 报，比实战高 ~37% | `CardSettlementService.php:648-651`、`index.php:254` |
| 2 | `PHASE1` §2：第三次改编成返回 `COMPOSITION_LOCKED` | **500 `INTERNAL`**，客户端拿不到该字符串 | `HandService.php:288` + `index.php:671-688` |
| 3 | `PHASE1` §3：第二次重抽返回 `REDRAW_USED` | **500 `INTERNAL`** | `HandService.php:99` |
| 4 | `PHASE1` §4 错误表读起来像独立错误码（`CARD_NOT_IN_HAND` 等） | `error.code` 恒为 `BAD_REQUEST`，哨兵在 `error.message`（`PLAY_LIMIT_REACHED` 实际也只走 400；500 分支不可达） | `index.php:659-660`、`HandService.php:184-188` |
| 5 | `PHASE1` §4：`request_key` 只允许字母数字下划线 | 允许短横线 `[A-Za-z0-9_-]` | `HandService.php:159`、`PointsService.php:106` |
| 6 | `PHASE1` §1：`hand` 只有 `cards/redraw_used` | 还有 `seed`、`preview` | `HandService.php:43-64` |
| 7 | `PHASE1` §1 的 state 示例只覆盖了部分字段（未列 `morale_cap`/`governor`/`next_turn`/`last_report`/`edit_block_reason`） | 实现全部返回；客户端可放心使用，但旧文档不足以据此做字段清单 | `SliceService.php:588-741` |
| 8 | `INTEGRATION.md` 路由表只有 14 项（旧体系） | 实际 38 项；`hand/order/bulletin/merit/estate/composition/forecast/card-settle/season` 全部缺席 | `INTEGRATION.md:160-176` |
| 9 | `INTEGRATION.md` 仍把 `pause/resume` 当作可用功能 | 路由在，但**无任何前端入口** | 6.3 |
| 10 | 战报/回放文档默认 `result_json` 含 `headline`/`node_changes` | 卡牌结算写的是 `{mode:'cards', battles}` → `replay.turns[].changes=[]`、`history.headline=null`、`state.last_report.headline=''` | `CardSettlementService.php:436-470`、`SliceService.php:2319-2332` |
| 11 | `GAMEPLAY_DESIGN` §11：教师台支持「暂停/继续、锁令、结算、下一回合」 | 暂停/继续无入口；Godot「结算」调的是旧 `/admin/settle`，不是卡牌结算 | `Slice.gd:4797`、`Api.gd:269-273` |
| 12 | `state.rules[]`：「敌方起点不可作为进军目标」 | 仅 `node_type='start'` 生效；**12+1 图的出生城是 `camp`，可被攻占** | `SliceService.php:851-853`、`seed_map12.sql:26-38` |
| 13 | `PHASE1` §1.05：邸报 `ram`「3 名先锋可叠到 +75%」，预估/战报里应能看出 | `siege_mult` 只在结算内部计算，`/battle/forecast` 不返回，玩家无法验证叠加是否生效 | `CardSettlementService.php:256-260` vs `399-407` |
| 14 | 旧文档默认「回合锁了就不能再动」 | 手牌出令/撤牌**完全不看锁/截止/暂停** | `HandService.php:136-221` |
| 15 | Godot 客户端行为 | `next-turn` 传 `{game_id}`（后端不认）；`composition` 写死 `week_no=1` | `Slice.gd:4807`、`Slice.gd:4567` |
| 16 | Godot 客户端行为 | 充值发 `{jade_amount}`（后端要 `points`）；读 `wallet.jade/score/daily_cap`（后端是 `jade_balance/total_score/daily_cap_points`）→ 文玉恒 0、充值必 400 | `Slice.gd:4865-4884`、`PointsService.php:84-98` |
| 17 | Godot 客户端行为 | 顶栏用 `me.name` / `pet.name`，后端只给 `nickname` / `pet.nickname` → 显示「学子」「令」 | `Slice.gd:5058,5069`、`SliceService.php:185-193` |
| 18 | `state.turn.can_edit` 与顶层 `can_edit` 同名 | 语义不同（见 2.1） | `SliceService.php:546-558` vs `756` |
| 19 | 文档默认「3 回合切片 / 28 回合赛季按各自规则结束」 | `settleTurn` 里 `turn_no >= 3` 就置 `finished`，**12 城图也会在第 3 回合被判结束**；`cron.php` 又会对所有 `running` 局跑这套旧结算 | `SliceService.php:1481-1484`、`scripts/cron.php:8` |
| 20 | 文档默认「教师台结算 = 结算本回合」 | Godot 教师面板调 `/admin/settle`（旧体系），HTML 教师台调 `/admin/card-settle`；两者的战报形态与结束条件都不同 | `Slice.gd:4797`、`teacher.html:407` |

### 6.5 风险清单

| # | 风险 | 影响 | 建议 |
|---|---|---|---|
| R1 | 手牌出令/撤牌不校验回合状态、截止时间、局暂停 | 锁令/结算/暂停后仍可改牌；结算后撤牌可改战报口径 | 在 `HandService::play/withdraw/redraw` 加 turn/game 状态校验（与 `submitOrder` 对齐） |
| R2 | `/order/withdraw` 结算后仍可撤 | `/me/report` 的 `orders/role/contribution` 与历史结算不一致 | 同上；或在 report 侧改成读快照 |
| R3 | `order/play` 不校验 `turn_id` 属于本局 | 可对他局的 `turn_id` 写 `slice_hands/slice_order_slots`（FK 允许） | 加 `SELECT game_id FROM slice_turns WHERE id=?` 校验 |
| R4 | `/battle/settle` 非幂等 | 连点/重试重复推民心，直到 cap 再易主 | 加 `battle_id` 结算标记或唯一约束 |
| R5 | `card-settle` 无事务/行锁/幂等 | 并发双击可能重复发军功、重复写 `slice_battles` | 用 `slice_settlement_jobs` 式的 `FOR UPDATE` 或回合级锁 |
| R6 | 两套结算共用 `slice_turn_results` | 先跑者胜；另一套静默 no-op；战报/回放形态随执行顺序变化 | 明确 12 城只用 `card-settle`，或在 `settleTurn` 里拒绝 card 模式回合 |
| R7 | `/battle`、`/battle/settle` 只校验同局 | 同局学生可读任意战报、替任意战斗落城 | 记录 `player_id` 归属或限制为参与者 |
| R8 | Godot 登出不调 `/auth/logout` | token 最长残留 12 小时 | 登出时调接口；服务端可加 token 轮换 |
| R9 | `GET /api/slice/state` 有写副作用 | 被监控/健康检查高频调用会写手牌/邸报/小院行 | 文档标注；或将 `ensure` 改为懒加载 |
| R10 | `season/history`、`season`、`card-settle` 的“不存在”是 500 | 客户端无法区分 404 与真故障 | 改成 `ApiException(..., 404)` |
| R11 | `state.rules[]` 文案写死 5 节点规则 | 12 城玩家读到错误规则（起点保护/3 回合结束） | 按 `rules_version` 或城数返回对应文案 |
| R12 | `turn_seconds` 配置项 `app.turn_seconds` 未被路由使用 | 改配置不生效，实际用 `slice_games.turn_seconds` | 统一数据源或删除死配置 |
| R13 | 卡牌结算 `settled_at = NOW()`（DB 时区） | DB 非 +08:00 时战报时间偏移 | 改用 `Clock` |
| R14 | 卡牌结算不写 `slice_player_reports` | `/history.my_report`、`/report.me` 在卡牌局为空 | 补写或前端统一走 `/me/report` |
| R15 | 邸报 `POST /bulletin` 无前端入口 | 学生实际无法选择 buff，`grain/ram/scout` 形同虚设 | 在 App 邸报卡片上接 POST |
| R16 | `cron.php` 对所有 `running` 局跑旧锁令/结算；`settleTurn` 在 `turn_no>=3` 置 `finished` | 12 城卡牌局被 cron 提前“结算”（空 `slice_orders` → 全场默认驻守）并在第 3 回合结束 | cron 只处理非卡牌局，或 `settleTurn` 按城数判断结束回合 |

---

## 7. 附录

### 7.1 兵种（`BattleEngine::TYPES`）

| code | 名称 | 攻 | 防 | 攻击间隔 | 排 |
|---|---|---|---|---|---|
| `cav` | 骑 | 1.10 | 0.85 | 4 | front |
| `shield` | 盾 | 0.85 | 1.25 | 5 | front |
| `arc` | 弓 | 1.90 | 0.85 | 5 | back |
| `spear` | 枪 | 1.05 | 1.00 | 5 | front |

克制：骑 > 盾 > 弓 > 枪 > 骑；克制 ×1.2，被克 ×0.85。
羁绊：3 种不同 = 混编（攻防 +5%）；3 队同种 = 专精（攻 +8%、防 -8%）；2+1 = 无。

### 7.2 主将（`BattleEngine::GENERALS`）

| code | 名称 | 效果 |
|---|---|---|
| `atk` | 攻将 | 攻 +10% |
| `def` | 守将 | 防 +10% |
| `tac` | 谋将 | 敌攻 -5% |
| `sup` | 运将 | 每 tick 治疗 5% |

> 卡牌结算里主将由**先锋第一人的班宠模板**决定：`pet_inkdrop_01 → tac`，其它 → `def`。`atk/sup` 目前只在演示战斗的守方出现。

### 7.3 城型与民心上限（`BattleSettlementService::cap`）

| node_type | cap |
|---|---|
| `king`（长安） | 5 |
| `camp` / `pass` / `ferry` / `culture` / `water` | 3 |
| `start` / `neutral` / 其它 | 2 |

### 7.4 周次与回合

| 项 | 规则 |
|---|---|
| 每周回合数 | 7 |
| 周次 | `floor((turn_no-1)/7)+1`，1–4 |
| 5 节点切片 | 3 回合结束 |
| 12+1 城 | 28 回合（4 周） |
| 长安开放 | 第 3 周起（`CHANGAN_LOCKED`） |
| 第 4 周限制 | 只能打长安或长安邻城（`SEASON_FINAL_WEEK`） |

### 7.5 快速自查清单（接客户端时）

1. 登录拿 `token`，后续全部走 `Authorization: Bearer`。
2. 首屏只调 `GET /state`，把 `turn.id` 存为全局 `turn_id`。
3. 渲染地图用 `map.nodes[].morale/morale_cap/owner/reachable_targets`，用 `can_edit` 统一禁用。
4. 出牌前检查 `slot < 3`、`card ∈ hand.cards`、`target ∈ reachable_targets`；出牌后重拉 `state`。
5. 出完 3 张后不要调 `/battle/demo` 来“结算”，12 城要走教师端 `card-settle`；演示战斗只用于回放。
6. 战报优先读 `me_report`；`report` 的形态按 `mode` 分支。
7. 回放只读 `/replay`，不要自己累加 `changes`。
8. 错误处理先看 `code`，再看 `message` 的哨兵字符串（0.4.1）。
