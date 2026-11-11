# Phase 1 客户端接入对照表

> 给 Antigravity。后端已全部就绪，客户端只需接这 8 个调用。  
> 先接 `state`，再接编成/手牌，最后接战斗回放。

---

## 1. GET /api/slice/state

一次拿到地图、民心、手牌、编成、已出令。

```json
{
  "map": {
    "nodes": [
      {"code": "N2", "name": "听雨台", "morale": 1, "morale_cap": 2, "owner": null}
    ]
  },
  "hand": {
    "cards": ["night_raid", "fortify", "scout", "supply"],
    "redraw_used": false
  },
  "composition": {
    "types": ["cav", "shield", "arc"],
    "changed_once": false
  },
  "card_orders": [
    {"slot": 0, "card_code": "night_raid", "target_node_code": "N2", "lane": 1, "row_pos": "front"}
  ],
  "scouted_nodes": ["N2"],
  "reachable_targets": ["A_START", "N1", "N2"],
  "bulletin": {
    "turn_id": 3,
    "options": [
      {"code": "grain", "title": "粮草先行", "desc": "你的队伍本回合兵力 +5%", "icon": "🌾"},
      {"code": "ram", "title": "攻城器械", "desc": "你的队伍本回合攻城伤害 +25%", "icon": "🪵"}
    ],
    "choice": null
  }
}
```

客户端渲染：

- 每座城画 `morale / morale_cap` 小格；
- 底部 4 张手牌；
- 编成面板 3 个兵种；
- 已出令显示在槽位里；
- `composition` 返回的是**当前回合所属周**的编成，不是固定第 1 周；
- `scouted_nodes` 是本回合已打出「哨探」的城，未侦察城不显示守军细节；
- `bulletin` 是当日邸报，二选一；`choice=null` 表示还没选；
- `reachable_targets` 是当前可出令的城（己方城 + 相邻城），其余城应置灰。

---

## 1.05 GET/POST /api/slice/bulletin

```text
GET  /api/slice/bulletin?turn_id=3
POST /api/slice/bulletin  {"turn_id": 3, "choice": "grain"}
Authorization: Bearer <token>
```

返回结构同 `state.bulletin`。选择在结算前可改；结算时按最终选择生效。

三个备选，每天每人只出现两个：

```text
grain 粮草先行  你的队伍本回合兵力 +5%
ram   攻城器械  你的队伍本回合攻城伤害 +25%（3 名先锋可叠到 +75%）
scout 斥候密报  本回合所有敌城守军可见
```

---

## 1.1 GET /api/slice/season

```text
GET /api/slice/season
Authorization: Bearer <token>
```

返回：

```json
{
  "game": "MAP12_TEST",
  "week": 3,
  "turn_no": 15,
  "days_left": 13,
  "season_over": false,
  "factions": [
    {"code": "bi", "name": "笔", "color": "#B83B32", "cities": 3, "morale": 4}
  ],
  "neutral_cities": 2,
  "changan": {"node_code": "changan", "name": "长安", "owner": null, "morale": 1, "morale_cap": 5},
  "winner": null
}
```

- `week` 1–4；
- `days_left = max(0, 28 - turn_no)`；
- 占长安直接获胜：`winner.reason = "changan"`；
- 第 28 回合后按城数、再按民心：`winner.reason = "cities"`；
- 平局时 `winner = null`。

---

## 1.2 GET /api/slice/season/history

```text
GET /api/slice/season/history
Authorization: Bearer <token>
```

返回赛季史书：按周聚合的战斗、易主、关键战役和周末排名。

```json
{
  "game": "MAP12_TEST",
  "current_week": 1,
  "max_turn": 4,
  "weeks": [
    {
      "week": 1,
      "turn_from": 1,
      "turn_to": 4,
      "complete": false,
      "battles": 4,
      "captures": [
        {"turn_no": 3, "node_code": "hanzhong", "node_name": "汉中", "winner": {"code": "bi", "name": "笔", "color": "#B83B32"}}
      ],
      "key_battle": {
        "turn_no": 3, "node_code": "hanzhong", "node_name": "汉中",
        "headline": "大捷", "score": 3, "wall": 0, "ticks": 58,
        "attacker": {"code": "bi", "name": "笔", "color": "#B83B32"},
        "defender": null
      },
      "standings": [
        {"code": "bi", "name": "笔", "color": "#B83B32", "cities": 2},
        {"code": "neutral", "name": "中立", "color": "#7a7066", "cities": 7}
      ],
      "headline": "第 1 周：笔 2 城领先，1 城易主"
    }
  ]
}
```

- `weeks` 只返回已开始或已结束的周；
- `complete=true` 表示该周 7 天都已结算；
- `key_battle` 取本周战果分最高、其次回合数最长的一场；
- `standings` 是周末归属，`neutral` 固定排最后。

---

## 1.3 GET /api/slice/merit

```text
GET /api/slice/merit?turn_id=3&week=1
Authorization: Bearer <token>
```

返回：

```json
{
  "week_no": 1,
  "me": {
    "total": 100, "week": 100, "week_no": 1, "rank": 1, "week_rank": 1,
    "breakdown": {"vanguard": 40, "capture": 40, "participation": 10, "assault": 10},
    "recent": [
      {"turn_no": 2, "kind": "capture", "label": "破城", "amount": 40,
       "detail": {"node_code": "N1", "role": "vanguard"}}
    ]
  },
  "top": [{"player_id": 10, "nickname": "青竹一", "faction": "bi", "faction_name": "笔", "color": "#B83B32", "total": 100}],
  "week_top": []
}
```

`state.merit` 是同一份 `me` 结构，客户端不用额外请求。

---

## 1.4 GET/POST /api/slice/estate

```text
GET  /api/slice/estate
POST /api/slice/estate/upgrade  {"room": "study"}
Authorization: Bearer <token>
```

返回文房小院（个人封地）：

```json
{
  "home_node": {"code": "liangzhou", "name": "凉州"},
  "level": 2,
  "banner": "",
  "merit_total": 186,
  "merit_spent": 30,
  "merit_balance": 156,
  "next_level_at": 300,
  "rooms": [
    {"code": "study", "name": "书房", "icon": "📜", "level": 2, "max_level": 3,
     "effect": "每日可预读 2 张未抽到的牌",
     "next_effect": "每日可预读 3 张未抽到的牌", "next_cost": 80},
    {"code": "drill", "name": "练兵场", "icon": "⚔", "level": 1, "max_level": 3,
     "effect": "每周可改 1 次编成", "next_effect": "每周可改 2 次编成", "next_cost": 30},
    {"code": "tower", "name": "望楼", "icon": "🔭", "level": 1, "max_level": 3,
     "effect": "侦察时多看 1 座邻城", "next_effect": "侦察时多看 2 座邻城", "next_cost": 30}
  ],
  "influence": [
    {"code": "hanzhong", "name": "汉中", "count": 3, "merit": 43}
  ],
  "governorships": [
    {"code": "hanzhong", "name": "汉中", "week": 1, "merit": 43}
  ]
}
```

规则：

```text
书房：预读张数 = 等级
练兵场：每周可改编成次数 = 等级
望楼：侦察额外覆盖邻城数 = 等级
升级消耗军功余额：2 级 30，3 级 80
只给便利和外观，不加战力，不碰 students.score
```

`state.map.nodes[].governor` 返回本周太守（昵称/阵营/颜色），没有则为 `null`。

---

## 1.5 GET /api/slice/me/report

```text
GET /api/slice/me/report?turn_id=3
Authorization: Bearer <token>
```

个人战报：结算后第一屏。

```json
{
  "turn_no": 2,
  "settled_at": "2026-11-11 21:00:00",
  "orders": [
    {"slot": 0, "card": "night_raid", "node_code": "N1", "node_name": "松风渡",
     "lane": 1, "row": "front", "role": "vanguard",
     "damage": 300.6, "wall_damage": 120.0, "troops_lost": 80.0,
     "contribution": 0.33, "captured": true}
  ],
  "battles_joined": 1,
  "damage": 300.6,
  "wall_damage": 120.0,
  "troops_lost": 80.0,
  "merit": {"turn_total": 65, "items": [{"kind": "capture", "label": "破城", "amount": 40}]},
  "highlight": "你的队伍参与了松风渡的破城，贡献 33%"
}
```

角色：

```text
vanguard 先锋 / support 支援 / garrison 驻守 / scout 侦察 / fire 火攻 / feint 疑兵 / reserve 未接战
```

`/api/slice/report` 的返回里也带 `me_report`，旧战报页可直接用。

战斗数据 `slice_battles.log_json.players` 按玩家聚合：

```json
{"10": {"damage": 300.6, "wall_damage": 120.0, "troops_initial": 456.8,
        "troops_lost": 80.0, "teams": 1, "contribution": 0.33}}
```

---

## 2. POST /api/slice/composition

```json
{"week_no": 1, "types": ["cav", "cav", "shield"]}
```

响应：

```json
{"types": ["cav", "cav", "shield"], "changed_once": false}
```

- `types` 必须 3 个；
- 可重复；
- `week_no` 可省略，服务端按当前回合推导（每 7 回合一周，1–4）；
- 第一次设置 `changed_once=false`；
- 第二次改 `changed_once=true`；
- 第三次返回 `COMPOSITION_LOCKED`。

---

## 3. POST /api/slice/hand/redraw

```json
{"turn_id": 1}
```

响应：

```json
{"cards": ["fire_attack", "fortify", "feint", "supply"], "redraw_used": true}
```

- 每天 1 次；
- 第二次返回 `REDRAW_USED`。

---

## 3.1 GET /api/slice/intel

```text
GET /api/slice/intel?node=N2&turn_id=1
Authorization: Bearer <token>
```

前提：**本回合已经对该城打出「哨探」**。没有哨探返回：

```json
{"ok": false, "error": {"code": "SCOUT_REQUIRED", "message": "需要先对这座城打出「哨探」"}}
```

有哨探时：

```json
{
  "turn_id": 1,
  "node_code": "N2",
  "owner_faction_id": null,
  "lane": {"lane": 2, "type": "spear", "name": "枪", "row": "front", "troops": 366},
  "massing": [
    {"faction": "mo", "name": "墨", "players": 2, "teams": 3, "troops": 870, "feint": false}
  ]
}
```

- `lane` 是按 `turn/player/node` 确定性选的一路，刷新页面不变；
- `massing` 是本城其他阵营的活跃令按阵营聚合（不含己方）；
- `feint: true` 表示该阵营打出了「疑兵」，`troops` 已经 ×1.5，UI 要标“疑似”；
- 没有哨探时不要轮询该接口。

---

## 4. POST /api/slice/order/play

```json
{
  "turn_id": 1,
  "slot": 0,
  "card_code": "night_raid",
  "target_node_code": "N2",
  "lane": 1,
  "row_pos": "front",
  "request_key": "p1_t1_s0_001"
}
```

响应：

```json
{"slot": 0, "card_code": "night_raid", "target_node_code": "N2", "lane": 1, "row_pos": "front"}
```

- `slot` 0/1/2；
- `lane` 1/2/3；
- `row_pos` front/back；
- `slot` 同时决定这支队伍用本周编成的第几个兵种；
- **队伍牌**（夜袭/急行/坚壁/犄角/空城/死守/反间/运粮/断粮）才需要 `lane` / `row_pos`；
- **非队伍牌**（火攻/哨探/疑兵）的 `lane` / `row_pos` 可传 `null`，结算不占队伍位；
- **目标是自己阵营的城 = 驻守**：结算时该城守方取驻守令的前 3 名学生，各出 1 队；
- 没有驻守令时，才回落到固定守军（中立 990 / 归属城 1320）；
- `request_key` 8–64 位字母数字下划线；
- 同一张牌不能出两次；
- 同一槽位可以改目标。

错误码：

```text
CARD_NOT_IN_HAND
CARD_ALREADY_PLAYED
PLAY_LIMIT_REACHED
BAD_SLOT / BAD_LANE / BAD_ROW / BAD_REQUEST_KEY
CHANGAN_LOCKED       第 1–2 周不能打长安
SEASON_FINAL_WEEK    第 4 周只能打长安或长安邻城
NOT_ADJACENT         目标城不与己方领土相邻
UNKNOWN_TARGET       目标城不存在
```

---

## 5. POST /api/slice/order/withdraw

```json
{"turn_id": 1, "slot": 0}
```

响应：

```json
{"withdrawn": true}
```

---

## 6. POST /api/slice/battle/demo

先用演示战斗把回放接通；正式版再换成城防数据。

```json
{"turn_id": 1, "node_code": "N2", "fire": true}
```

响应：

```json
{
  "battle_id": 3,
  "attacker": {"general": "def", "troops": 1305, "composition": ["cav","shield","arc"], "fire": true},
  "defender": {"general": "atk", "troops": 1320, "composition": ["shield","spear","arc"]},
  "log": {
    "att_slots": {...},
    "def_slots": {...},
    "units": [...],
    "events": [...],
    "result": {"wall": 428.5, "score": 1, "ticks": 49, "headline": "撼城"}
  }
}
```

客户端：

```gdscript
battle_replay.play_data(response.data.log)
```

`log` 的格式和 `BattleReplay.gd` 现在的样例完全一致。

---

## 7. POST /api/slice/battle/settle

```json
{"battle_id": 3}
```

响应：

```json
{
  "node_code": "N2",
  "cap": 2,
  "morale_before": 0,
  "morale_after": 1,
  "owner_before": null,
  "owner_after": null,
  "captured": false,
  "reason": "morale_push"
}
```

客户端：

- 更新该城民心；
- 如果 `captured=true`，换旗、播易主动画；
- 然后重新 `GET /state`。

---

## 8. GET /api/slice/battle?id=3

读回完整战斗，用于历史回放。

```json
{
  "id": 3,
  "node_code": "N2",
  "log": {"units": [...], "events": [...], "result": {...}},
  "result": {"wall": 428.5, "score": 1, "ticks": 49, "headline": "撼城"}
}
```

---

## 9. 客户端流程

```text
登录
→ GET /state
→ 渲染地图（民心）、手牌、编成
→ 改编成 POST /composition
→ 出牌 POST /order/play × 3
→ 开战 POST /battle/demo
→ BattleReplay.play_data(log)
→ POST /battle/settle
→ GET /state（刷新民心/归属）
```

---

## 10. 接入位置

| 文件 | 改什么 |
|---|---|
| `client/Api.gd` | 加 `getState` 已有；加 `setComposition`、`redrawHand`、`playCard`、`withdrawCard`、`demoBattle`、`settleBattle`、`getBattle` |
| `client/Slice.gd` | `_apply_state` 里读 `hand`/`composition`/`card_orders`；底部加手牌条；城池卡加民心格 |
| `client/CompositionPanel.gd` | 调 `POST /composition` |
| `client/BattleReplay.gd` | 已经能读 `log`；接 `demoBattle` 的返回即可 |

---

## 11. 验收

```text
1. 登录后能看到 4 张手牌和 3 个兵种
2. 改编成后刷新不变
3. 出 3 张牌后 /state 的 card_orders 有 3 条
4. 开战能播 60 秒回放，可跳过
5. 结算后城池民心 +1
6. 第二场结算后易主
7. 720×514 手牌不挡城池抽屉
8. ClientSmoke / ReplaySmoke / BattleReplaySmoke 全过
```
