# Phase 1 任务板 · 3 将令 + 4 兵种 + 3×2 战斗

> 目标：把 5 节点切片升级到新玩法，能跑 8–12 人试跑。  
> 周期：2 周。  
> 验收：后端 14 项旧测试 + 新增 10 项；ClientSmoke / ReplaySmoke；720×514 与 1400×1000 截图。

---

## 0. 范围

```text
5 节点地图不变
每个学生：每周编成 3 个兵种
每天：4 抽 3 张战术，分配给 3 支队伍
21:00：3 路 × 2 排自动战斗，60 秒回放
战斗结果 → 民心条 → 易主
```

不做：12 城、长安、赛季、抽卡、守城阵容、天气。

---

## 1. 分工

| 角色 | 负责 | 不碰 |
|---|---|---|
| **OpenCode** | 数据库、发牌、编成、战斗引擎、结算、测试 | 不改 Godot UI |
| **Antigravity** | 手牌 UI、编成 UI、战斗回放、720×514/1400×1000 | 不改后端/schema |
| **GPT** | 4 兵种精灵、器械、城墙、3 个战场背景、卡框、12 战术图标 | 不改逻辑 |

---

## 2. OpenCode

### 2.1 数据库

- `slice_hands`：每日手牌、重抽、种子；
- `slice_compositions`：每周编成、3 个兵种、锁定；
- `slice_battles`：战斗记录、tick log、结果；
- `slice_orders`：扩展 slot / card_code / lane / row；
- 唯一键：`(turn_id, player_id, slot)`。

### 2.2 服务

- `HandService`：发牌、重抽、出牌、撤回；
- `BattleEngine`：3 路 × 2 排、4 兵种、器械、60 tick、确定性；
- `BattleService`：把订单转成战斗、存 log、返回结果；
- 战斗结果：城墙 0 → +2；<50% → +1；50–80% → 0；>80% → -1。

### 2.3 测试

- 4 兵种克制各 1 条；
- 器械被保护/失效各 1 条；
- 同部署同结果；
- 发牌不重复、重抽 1 次；
- 出牌 3 张上限；
- 幂等 request_key；
- 100 并发不改负兵力。

### 2.4 交付

- `server/slice/migrations/004_phase1_cards_battle.sql`
- `server/slice/src/HandService.php`
- `server/slice/src/BattleEngine.php`
- `server/slice/src/BattleService.php`
- `server/slice/tests/run.php` 新增 10 项
- `PHASE1_BACKEND_REPORT.md`

---

## 3. Antigravity

### 3.1 编成 UI

```text
每周编成：选 3 个兵种（骑/盾/弓/枪，可重复）
周中可改 1 次
显示：3 个兵种、总兵力、每队兵力、兵源城加成
```

720×514：一行 4 个兵种按钮 + 3 个槽位；不弹二级页。  
1400×1000：同上，放大。

### 3.2 手牌 UI

```text
底部 4 张战术牌
拖到 3 支队伍上分配
每张牌显示：名字、一行效果、已分配给哪队
重抽按钮 1 次
```

约束：

- 手牌不遮挡城池抽屉；
- 抽屉打开时手牌收成一条；
- 长按看完整说明。

### 3.3 战斗回放

```text
3 路 × 2 排
每路：前排 / 后排
攻方左，守方右，城门在最右
4 兵种 + 器械
60 秒，1x / 2x / 跳过
顶部：城墙耐久条
底部：双方兵力条
结束：结果印章 + 3 帧折页
```

输入：`BattleReplay` 读 JSON tick log，不自己算结果。

### 3.4 交付

- `client/BattleReplay.tscn` + `client/BattleReplay.gd`
- `client/CompositionPanel.gd`（或整合进 Slice.gd）
- `client/tests/BattleReplaySmoke.tscn`
- `client/PHASE1_CLIENT_REPORT.md`
- 720×514 / 1400×1000 截图

### 3.5 验收

- ClientSmoke PASS；
- ReplaySmoke PASS；
- BattleReplaySmoke PASS；
- 用样例 JSON 能播完 60 秒，可跳过；
- 0.50x 手机横屏能看清兵种和前后排。

---

## 4. GPT

### 4.1 资产清单

| 资产 | 数量 | 规格 |
|---|---:|---|
| 4 兵种精灵 | 4 × 3 状态 | 512×512 PNG 透明 |
| 器械 | 1 × 2 状态 | 512×512 |
| 城门/城墙 | 1 | 1024×512 |
| 战场背景 | 3（平原/关隘/渡口） | 2048×768 |
| 卡框 | 1 | 256×360，九宫格 |
| 12 战术图标 | 12 | 128×128 |
| 阵营旗 | 4 | 128×128 |

### 4.2 风格

- 纸雕水墨、低饱和；
- 2D 侧 3/4 视角；
- 不烘焙阵营色、不烘焙文字；
- 兵种轮廓必须一眼可分：骑=马、盾=大盾、弓=弓、枪=长枪；
- 720×514 下缩到 64px 仍能认。

### 4.3 交付

- `art_src/gpt/PHASE1_BATTLE_ASSETS/`
- `PHASE1_BATTLE_ASSET_BRIEF.md`：每张图的 prompt、尺寸、用途
- 先出 4 兵种 + 器械 + 城门，背景和图标第二批

### 4.4 终审

- 检查反重力的回放截图：兵种是否可辨、前后排是否可读、城墙是否清楚；
- 检查 0.50x 手机横屏是否糊。

---

## 5. 时间线

```text
第 1 周
  OpenCode：迁移 + HandService + BattleEngine
  Antigravity：编成 UI + 手牌 UI
  GPT：4 兵种 + 器械 + 城门

第 2 周
  OpenCode：BattleService + 10 项测试 + 5 节点接入
  Antigravity：BattleReplay + 截图
  GPT：背景 + 卡框 + 12 图标

第 2 周末
  8–12 人试跑
```

---

## 6. 验收红线

1. 旧 14 项后端测试全过；
2. ClientSmoke / ReplaySmoke / BattleReplaySmoke PASS；
3. 同部署同结果；
4. 4 兵种克制可解释；
5. 器械被保护/失效可解释；
6. 720×514 能看清手牌、前后排、城门；
7. 不写 `students.score`、不改 `student_pets`；
8. 教师每天 0–5 分钟。
