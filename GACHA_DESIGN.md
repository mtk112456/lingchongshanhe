# 抽卡设计 · 文房开卷

> 状态：用户已拍板“可以做抽卡，用现成积分”。本文替换 ADR-014 的“不抽卡”。
> 底线：只用班级积分，不接真实付费；只出外观，不出战力；概率公示、有保底、有每日上限、教师可关。
> 名称：对外不叫“抽卡/盲盒”，叫 **开卷**（抽一次 = 展一卷）。

---

## 0. 一句话规则

```text
积分 → 文玉（现有 1:10 兑换，20 分/天）
→ 100 文玉开一卷 / 900 文玉开十卷
→ 只出称号、头像框、战报印章、案头、文脉卡面、行军路线
→ 不出攻防、军令、补给、城防、资源
```

---

## 1. 为什么只出外观

| 如果出战力 | 后果 |
|---|---|
| 积分来自班级表现 | 分数高的学生抽得更多、战力更强 |
| 60–100 人、4 阵营 | 少数高分学生决定战局，普通学生变成观众 |
| 8–12 人试跑 | 数据被“谁分高”污染，无法判断规则好不好玩 |
| 赛季 4 周 | 第一周就雪球，后面三周没有悬念 |

外观 + 图鉴荣誉可以解决“抽到了有什么用”：

- 称号显示在战报/城池抽屉；
- 头像框显示在阵营页；
- 战报印章盖在每日战报上；
- 案头是个人主页背景；
- 文脉卡面进个人图鉴，累计 **文脉值**；
- 行军路线特效只改自己下令的路线颜色/笔触。

**文脉值只排名誉，不进结算。**

---

## 2. 货币与价格

复用现有管线，不新造货币：

```text
可用积分 = max(0, students.score - 100 - SUM(shop_orders.points_spent))
1 积分 = 10 文玉
每日最多兑换 20 积分 = 200 文玉
```

| 商品 | 价格 | 折合积分 |
|---|---:|---:|
| 开一卷（1 抽） | 100 文玉 | 10 积分 |
| 开十卷（10 抽） | 900 文玉 | 90 积分（9 折） |

节奏：

- 每天兑换上限 200 文玉 = 2 卷/天；
- 4.5 天可攒一次十卷；
- 28 天赛季满勤 ≈ 5600 文玉 ≈ 62 卷。

**不直接扣积分。** 原因：积分同时是班级商城（文具/奖品）的钱，直接扣会和线下奖励抢预算；文玉是游戏内隔离货币，花光不影响学生换实物。

> 如果坚持“积分直接抽”：加 `shop_orders.type='game_gacha'` 也能做，但会绕过 20 分/天保护，且学生可能把换奖品的积分抽光。默认不做。

---

## 3. 池子

常驻池「文房四宝」，48 件，全部个人可见：

| 类别 | 数量 | 说明 |
|---|---:|---|
| 称号 | 10 | 显示在战报、城池抽屉 |
| 头像框 | 8 | 阵营页、战报 |
| 战报印章 | 8 | 盖在每日战报落款 |
| 案头背景 | 8 | 个人主页 |
| 文脉卡面 | 8 | 个人图鉴，累计文脉值 |
| 行军路线 | 6 | 只改自己下令的路线笔触 |

稀有度用墨色，不用 SSR：

| 稀有度 | 概率 | 数量 | 说明 |
|---|---:|---:|---|
| 淡墨 | 62% | 18 | 常见 |
| 重墨 | 26.5% | 14 | 少见 |
| 浓墨 | 9% | 10 | 稀有 |
| 焦墨 | 2.5% | 6 | 赛季目标 |

赛季池「长安」：12 件限定，赛季结束下架，不进常驻。

---

## 4. 保底

| 机制 | 规则 |
|---|---|
| 十卷保底 | 每 10 抽至少 1 件浓墨或以上 |
| 焦墨保底 | 累计 50 抽未出焦墨，第 50 抽必出 |
| 新物品保底 | 每 10 抽至少 1 件未拥有（池子集齐后转为墨屑） |

保底计数按池子存，换池重置。

---

## 5. 重复与墨屑

重复物品自动转 **墨屑**：

| 稀有度 | 重复转墨屑 | 墨屑兑换价 |
|---|---:|---:|
| 淡墨 | 10 | 100 |
| 重墨 | 25 | 250 |
| 浓墨 | 70 | 700 |
| 焦墨 | 250 | 不可兑换 |

- 墨屑可兑换任意**已下架/未抽到**的淡墨/重墨/浓墨物品；
- 焦墨只能靠抽或保底，保持稀缺；
- 墨屑跨赛季保留。

---

## 6. 防赌博设计

必须做：

- 概率公示，一屏可查；
- 每日最多开 5 卷（在文玉上限之外再加一道）；
- 结果 1.2 秒内直接展示，不做卷轴滚动、不做闪光、不做“差一点”；
- 不做“再抽一次”自动连点；
- 不做消费排行榜；
- 不做限时弹窗倒计时；
- 教师可一键关闭抽卡；
- 不接真实付费、不接 `shop_blind_box`。

界面语言：

```text
开卷 / 展卷 / 墨屑 / 文脉值
不用：抽卡、开箱、爆率、欧皇、十连必出
```

---

## 7. 教师控制

| 开关 | 默认 | 说明 |
|---|---|---|
| `gacha_enabled` | 开 | 关闭后入口隐藏，已抽物品保留 |
| `gacha_daily_draw_cap` | 5 | 每日最多开卷数 |
| `gacha_pool_id` | 常驻 | 可切赛季池 |
| `gacha_visible_rank` | 关 | 文脉值排行榜，默认不显示 |

教师可查：

- 谁在什么时候抽了什么；
- 消耗多少文玉；
- 重复转了多少墨屑；
- 导出 CSV。

教师看不到、也不生成“消费排名”。

---

## 8. 数据表

```sql
CREATE TABLE game_gacha_pools (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(32) NOT NULL UNIQUE,
  name VARCHAR(64) NOT NULL,
  season_code VARCHAR(32) NULL,
  single_price INT UNSIGNED NOT NULL DEFAULT 100,
  ten_price INT UNSIGNED NOT NULL DEFAULT 900,
  rates_json JSON NOT NULL,
  pity_limit INT UNSIGNED NOT NULL DEFAULT 50,
  daily_draw_cap INT UNSIGNED NOT NULL DEFAULT 5,
  enabled TINYINT(1) NOT NULL DEFAULT 1,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE game_gacha_items (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  pool_id INT UNSIGNED NOT NULL,
  code VARCHAR(48) NOT NULL,
  name VARCHAR(64) NOT NULL,
  category ENUM('title','frame','seal','desk','cardface','trail') NOT NULL,
  rarity ENUM('diluted','heavy','dense','burnt') NOT NULL,
  weight INT UNSIGNED NOT NULL DEFAULT 100,
  art_path VARCHAR(255) NULL,
  exchange_cost INT UNSIGNED NULL,
  enabled TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uk_pool_code (pool_id, code),
  KEY idx_pool_rarity (pool_id, rarity)
);

CREATE TABLE game_gacha_draws (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  student_id INT UNSIGNED NOT NULL,
  pool_id INT UNSIGNED NOT NULL,
  request_key VARCHAR(64) NOT NULL,
  draw_count TINYINT UNSIGNED NOT NULL,
  cost_jade INT UNSIGNED NOT NULL,
  results_json JSON NOT NULL,
  pity_before INT UNSIGNED NOT NULL,
  pity_after INT UNSIGNED NOT NULL,
  pool_version INT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_draw_student_key (student_id, request_key),
  KEY idx_draw_student_time (student_id, created_at)
);

CREATE TABLE game_player_items (
  student_id INT UNSIGNED NOT NULL,
  item_id INT UNSIGNED NOT NULL,
  obtained_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  source VARCHAR(24) NOT NULL DEFAULT 'gacha',
  PRIMARY KEY (student_id, item_id)
);

CREATE TABLE game_player_fragments (
  student_id INT UNSIGNED NOT NULL PRIMARY KEY,
  balance INT UNSIGNED NOT NULL DEFAULT 0
);

CREATE TABLE game_fragment_transactions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  student_id INT UNSIGNED NOT NULL,
  delta INT NOT NULL,
  balance_after INT UNSIGNED NOT NULL,
  reason VARCHAR(32) NOT NULL,
  ref_draw_id BIGINT UNSIGNED NULL,
  ref_item_id INT UNSIGNED NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

扣文玉复用现有钱包：

```text
game_wallets.balance_jade -= cost       （SELECT ... FOR UPDATE）
game_wallet_transactions:
  reason = 'gacha_draw'
  jade_delta = -cost
  points_spent = 0
```

**不写 `students.score`；不写 `shop_blind_box`。**

---

## 9. API

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/api/slice/gacha/pool` | 池子、概率、价格、我的墨屑/文脉值 |
| POST | `/api/slice/gacha/draw` | `{count:1|10, request_key}` |
| GET | `/api/slice/gacha/collection` | 已拥有、未拥有、兑换价 |
| POST | `/api/slice/gacha/exchange` | `{item_id, request_key}` |
| GET | `/api/slice/admin/gacha/log` | 教师查记录 |
| POST | `/api/slice/admin/gacha/toggle` | `{enabled}` |

开卷响应：

```json
{
  "draw_id": 123,
  "count": 10,
  "cost_jade": 900,
  "jade_balance": 1100,
  "results": [
    {"item_id": 7, "name": "青竹落款", "rarity": "dense", "category": "seal",
     "is_new": true, "fragments": 0, "roll": 8231}
  ],
  "pity_after": 12,
  "fragments_gained": 180,
  "fragments_balance": 430,
  "idempotent": false
}
```

- `request_key` 幂等，同一 key 返回同一结果；
- 服务端 `random_int` 掷点，`roll` 存档，可按概率表复核；
- 并发开卷对钱包 `FOR UPDATE`，防负余额。

---

## 10. 经济测算

假设学生满勤兑换：

| 周期 | 文玉 | 单卷 | 十卷 |
|---|---:|---:|---:|
| 1 天 | 200 | 2 | 0 |
| 1 周 | 1400 | 14 | 1 |
| 4 周 | 5600 | 56 | 6 |

- 池子 48 件，一赛季约收集 32–38 件；
- 焦墨 6 件，保底 50 抽 → 一赛季 1–2 件；
- 剩下 10–16 件留给下赛季或墨屑兑换。

这个节奏是“每天有 1–2 次开卷”，不是“一次抽爽”。如果希望更快，把单卷降到 80 文玉即可，不改结构。

---

## 11. 验收

后端：

- 100 并发同时开卷，文玉不为负；
- 同一 `request_key` 重复请求只扣一次；
- 50 抽保底准确；
- 十卷保底准确；
- 每日 5 卷上限准确；
- 教师关闭后接口返回 `GACHA_DISABLED`；
- 不写 `students.score`、不写 `shop_blind_box`。

前端：

- 概率公示一屏可查；
- 开卷结果 1.2 秒内出现；
- 重复物品明确显示“转墨屑”；
- 720×514 横屏下十卷结果不滚动糊屏；
- 关闭后入口完全隐藏。

产品：

- 8–12 人试跑后，学生能说出“我抽到了什么、能显示在哪”；
- 不出现“再抽一次”的强迫感；
- 教师认为不需要每天管。

---

## 12. 分阶段

```text
阶段 1：常驻池 48 件 + 单抽/十抽 + 保底 + 墨屑
阶段 2：个人图鉴/文脉值 + 教师开关/日志
阶段 3：赛季限定池「长安」12 件
阶段 4：班宠表情/挂饰（需先确认 student_pets 只读边界）
```

阶段 4 单独评估：班宠属于班级系统，游戏只读。做皮肤时只改显示，不改 `student_pets` 数值。

---

## 13. 一句话

> **用现有积分换文玉来开卷；只出外观和图鉴；100 文玉一卷、900 十卷；十卷保底浓墨、50 抽保底焦墨、10 抽保底 1 新；重复转墨屑；每天 5 卷上限；教师可关。**
