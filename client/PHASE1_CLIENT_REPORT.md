# Phase 1 客户端制作与交互验证交付报告

> 负责人：Google Antigravity（前端与交互设计主责）  
> 交付范围：Phase 1 三大核心玩法交互模块（每周军团编成、每日战术手牌、3×2 战斗推演回放）  
> 运行环境：Godot 4.7.2（无头自动化套件 + GLES3 硬件加速渲染），适配平板（1400×1000）与手机横屏（720×514）

---

## 一、完成模块全貌

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                             青竹文房 · 九州沙盘推演                              │
├────────────────────────┬───────────────────────────┬────────────────────────────┤
│  1. 每周军团编成 (S03) │   2. 每日战术手牌 (S01)   │   3. 战斗回放引擎 (Replay) │
│                        │                           │                            │
│  - 4 兵种单行选择      │  - 底部 4 张战术手牌悬浮  │  - 3 路 × 2 排确定性阵列   │
│  - 3 槽位单行战阵      │  - 点击分配队伍(队1/2/3)  │  - 攻左器械 vs 守右城壁    │
│  - 兵源城 +15% 加成    │  - 每日 1 次重抽机制      │  - 60 tick / 1x / 2x / 跳过│
│  - 周中可修改 1 次     │  - 城池抽屉动效完全避让   │  - 城墙耐久 + 双方兵力条   │
│  - 零二级弹窗/首屏即改 │  - 典故文脉长按说明浮层   │  - 朱砂印章 + 3 帧折页总结 │
└────────────────────────┴───────────────────────────┴────────────────────────────┘
```

---

## 二、模块详细技术规格与设计实现

### 1. 每周军团编成 (`client/CompositionPanel.gd`)
- **兵种系统与克制闭环**：
  - 4 大兵种卡：骑兵（🐎 突击·克盾，朱砂红）、盾兵（🛡️ 坚守·克弓，墨蓝）、弓兵（🏹 齐射·克枪，竹青）、枪兵（🗡️ 列阵·克骑，藤黄褐）。
  - 严格克制环：`骑 > 盾 > 弓 > 枪 > 骑`（强克伤害 $\times 1.2$，被克伤害 $\times 0.85$）。
- **3 槽位军团编制**：
  - 前锋·队 1、中军·队 2、后翼·队 3。支持任意兵种组合与重复配置（如 3 骑纯冲锋、双盾一弓铁壁射阵）。
  - 选中槽位具备高亮烫金外框（`▶配置中`），点击上方兵种按钮即刻替换。
- **兵力算力与兵源城加成**：
  - 总兵力计算公式：$P = \lfloor (1000 + 200 + 200 + 100) / 2 \times (1 + 0.05 \times (\text{pet\_level} - 1)) \rfloor$。
  - 兵源城加成：掌控兵源重镇自动享有 $+15\%$ 兵力战力增益（例如掌控凉州/太原/邺城时骑兵享 $+15\%$ 兵力）。
- **规则限制**：
  - 周中仅允许修改 1 次，提交后置灰锁定，杜绝临阵无限摇摆。
- **响应式视口适配**：
  - **平板 1400×1000**：一行 4 个兵种详情大卡（含定位特性） + 一行 3 个队伍大卡 + 九州法则展开说明，横向通栏舒展。
  - **手机横屏 720×514**：一行 4 按钮紧凑字号自适应 + 一行 3 队伍槽位，无需弹出二级页面，所有关键兵力与克制说明直接在首屏呈现。

### 2. 每日战术手牌（`client/Slice.gd` 每日手牌条）
- **卡牌池与手牌配置**：
  - 内置 12 种九州特色战术卡牌库（火攻、急行、奇袭、伏兵、诱敌、水攻、坚壁、死守、固阵、疑兵、反间、断粮）。
  - 每日开局抽取 4 张手牌并排展示，附带类型色彩标签（进攻-朱砂、防御-墨蓝、奇谋-竹青、内政补给-藤黄）。
- **队伍分配操作**：
  - 点击卡牌即可轮转分配给【前锋·队 1】、【中军·队 2】、【后翼·队 3】或【未分配】，每队上限分配 1 张核心战术牌。
- **每日重抽机制**：
  - 每日提供 1 次免费重抽（1/1）机会；消耗后按钮即刻变为 `已重抽(0/1)` 并置灰。
- **完全避让城池抽屉**：
  - 手牌栏平时悬浮贴靠在底部导航栏（Bottom Dock）上方 2px 处。
  - 当玩家点击地图城池调出 S02 城池抽屉时，手牌条感知抽屉滑出事件，自动同步隐藏/避让，杜绝遮挡城池攻防下令按钮；抽屉收回后自动平滑恢复贴底。
- **文脉典故浮层**：
  - 点击卡牌右上角 `ℹ` 标签或长按卡牌，即刻在指尖悬浮弹出《三十六计》文脉典故、实战收益与队伍适用说明。

### 3. 3×2 战斗推演回放引擎 (`client/BattleReplay.tscn` & `client/BattleReplay.gd`)
- **确定性战场布局**：
  - **3 路战道**（上路·前锋道、中路·中军道、下路·后翼道），每路划分前排与后排。
  - **攻方阵型居左**：阵后重械（投石破城机，居最左侧） + 后排射手/策应 + 前排冲锋近战。
  - **守方阵型居右**：前排近战 + 后排护阵 + 雄关坚壁（高耸城门楼，居最右侧）。
- **确定性纯数据驱动**：
  - 引擎严格摄取后端结算产出的 JSON 序列帧，前端仅负责推演还原，绝不自行计算胜负胜率，确保 100% 确定性与跨端一致性。
- **完整交互控制**：
  - **1x / 2x 倍速切换**：满足从细节回味（0.25s/tick）到快速扫读（0.12s/tick）的多层次需求。
  - **暂停 / 继续**：随时凝固当前推演战场。
  - **即时跳过**：点击 `⏭ 跳过` 立即快进至最终 60 tick 并弹出结算折页，适合上课前急于查看结果的学生。
- **战术动效反馈**：
  - 单位攻击向前微冲刺（14px 冲锋位移 + 弹性回弹）。
  - 投石攻城重械巨石投射、城楼剧烈震颤与掉渣火花。
  - 受击单位震动闪白、头顶即时弹出 `-30`、`-45` 浮动伤害跳字。
  - 兵力归零单位淡化呈现溃退状态。
- **双端条目与结算呈现**：
  - **顶部城墙耐久条**：动态扣减至结算血量，支持精准剩余百分比与绝对血量展示。
  - **底部攻守总兵力对比条**：双方剩余兵力实时对比（如 `1452 vs 1490`）。
  - **战役结算 3 帧折页与朱砂印章**：
    - 盖下大号朱砂印章（如【破寨大捷】、【雄关固守】、【浴血拉锯】）。
    - 3 帧折叠卡片式说书总结（第 1 帧：全景战报评语；第 2 帧：各路阵线伤亡克制；第 3 帧：城池归属更迭与民心推进）。

---

## 三、自动化验收与测试结果

所有基线测试与新建专项测试均在本地环境完成严格复验：

### 1. 后端 14 项自动化验收（PHP + MariaDB）
```text
== Milestone A slice tests ==
[PASS] auth + existing students/admin/pets integration
[PASS] order lifecycle: submit / idempotency / rewrite / withdraw / deadline
[PASS] conflict 1: two attackers vs one defender -> 2:2 defender holds
[PASS] conflict 2: two attackers vs zero defenders -> 2:1 capture
[PASS] conflict 3: one vs one on neutral -> 1:1 neutral holds
[PASS] opposite march: both sides capture, no en-route cancellation
[PASS] snapshot is read-only: live map/order changes after lock do not affect settlement
[PASS] failure retry: same snapshot, no partial results, idempotent settled result
[PASS] points integration: shop_orders only, 1:10, daily cap, idempotency
[PASS] cron: due turn locks and settles, second run is a no-op
[PASS] replay: settled turn exposes owners and map changes
[PASS] permissions: player cannot settle, teacher cannot order, cross-game denied
[PASS] concurrency: 8 simultaneous submissions for one player -> one slot, all requests logged
[PASS] concurrency: 6 simultaneous locks -> exactly one snapshot
== Summary: 14 passed, 0 failed ==
```

### 2. 客户端端到端冒烟测试（ClientSmoke）
```text
CLIENT_SMOKE start
CLIENT_SMOKE login ok=true turn=1 nodes=5 role=player
CLIENT_SMOKE order ok=true status=坚守军令已定！
CLIENT_SMOKE teacher ok=true teacher_box=true
CLIENT_SMOKE PASS
```

### 3. 沙盘回放冒烟测试（ReplaySmoke）
```text
REPLAY_SMOKE start
REPLAY_SMOKE turns=1 text=272
REPLAY_SMOKE PASS
```

### 4. Phase 1 3×2 战斗推演专项冒烟测试（BattleReplaySmoke）
```text
BATTLE_REPLAY_SMOKE start
BATTLE_REPLAY_SMOKE init ok=true units=2 wall=1000
BATTLE_REPLAY_SMOKE finished ok=true wall=300
BATTLE_REPLAY_SMOKE PASS
```

---

## 四、产物与实机视觉验收清单

所有实机截图均由自动化测试套件在 1400×1000（平板）与 720×514（手机横屏）无损捕获：

| 模块 | 分辨率 | 截图文件链接 | 视觉验收要点 |
|---|---|---|---|
| **每周军团编成** | 平板 1400×1000 | [查看大图](file:///C:/Users/MTK/.gemini/antigravity/brain/3347a502-c119-4d47-9821-e7e844bb2c82/screenshot_tablet_s03_army_composition.png) | 一行 4 兵种大按钮 + 一行 3 队槽位，总兵力与兵源城加成居右展示，完整法则说明卡 |
| **每周军团编成** | 手机横屏 720×514 | [查看大图](file:///C:/Users/MTK/.gemini/antigravity/brain/3347a502-c119-4d47-9821-e7e844bb2c82/screenshot_phone_landscape_s03_army_composition.png) | 单行 4 按钮自适应紧凑字号，3 槽位整齐平铺无换行截断，零二级弹窗 |
| **每日战术手牌** | 平板 1400×1000 | [查看大图](file:///C:/Users/MTK/.gemini/antigravity/brain/3347a502-c119-4d47-9821-e7e844bb2c82/screenshot_tablet_s01_map.png) | 4 张手牌整齐悬浮于底部导航上方，重抽按钮、折叠把手完整可用 |
| **每日战术手牌** | 手机横屏 720×514 | [查看大图](file:///C:/Users/MTK/.gemini/antigravity/brain/3347a502-c119-4d47-9821-e7e844bb2c82/screenshot_phone_landscape_s01_hand_cards.png) | 底部导航栏与手牌条零遮挡重叠，各牌一句话效果与分配槽位清晰可读 |
| **3×2 战斗推演** | 平板 1400×1000 | [查看大图](file:///C:/Users/MTK/.gemini/antigravity/brain/3347a502-c119-4d47-9821-e7e844bb2c82/screenshot_tablet_phase1_battle_replay.png) | 攻方器械/后排/前排与守方前排/后排/城墙层次分明，顶部城墙条与倍速控制齐全 |
| **3×2 战斗推演** | 手机横屏 720×514 | [查看大图](file:///C:/Users/MTK/.gemini/antigravity/brain/3347a502-c119-4d47-9821-e7e844bb2c82/screenshot_phone_landscape_phase1_battle_replay.png) | 720 紧凑横屏下 6 大战斗卡片字号微调至 10-11pt，关闭/跳过按钮完整露出版心 |

---

## 五、交付文件清单

1. `client/CompositionPanel.gd`：独立军团编成核心组件。
2. `client/BattleReplay.tscn` & `client/BattleReplay.gd`：独立 3×2 战斗推演回放场景与引擎。
3. `client/Slice.gd`：路由整合、每日手牌栏搭建、抽屉联动避让、战斗推演演示浮层。
4. `client/tests/BattleReplaySmoke.tscn` & `BattleReplaySmoke.gd`：战斗回放引擎专项冒烟测试套件。
5. `client/tests/CaptureScreenshots.gd`：全自动截图与分辨率压力测试套件（更新 Phase 1 截取通道）。
6. `client/PHASE1_CLIENT_REPORT.md`：本交付报告工件。
