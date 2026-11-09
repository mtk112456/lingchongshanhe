# 《青竹文房·灵宠山河》开发路线图（GitHub 方案版）

> 目标：每一步都找到可复用/可参考的 GitHub 方案，避免从零造轮子  
> 原则：GitHub 补“工程能力”，不补“玩法/美术/内容/运营”  
> 数据时间：2026-11-09，星数/许可证以仓库实际为准

> **引擎变更**：已改为 **Godot 4.7.2**，不做微信小游戏。  
> 本文中 Cocos 相关步骤仅作历史参考；Godot 版路线图后续重写。

---

## 零、先明确：GitHub 能补什么，不能补什么

| 能补 | 不能补 |
|---|---|
| 引擎、构建、CI/CD | 核心玩法是否好玩 |
| 后端、账号、匹配、联机 | 美术质量、动画手感 |
| 崩溃监控、数据分析、灰度 | 内容量、剧情、关卡 |
| 自动化测试、性能分析 | 运营、市场、社区 |
| 地图/动画/叙事工具 | 数值平衡、长期调优 |

**结论：GitHub 能让项目“像专业团队做的”，但不能让个人团队变成大型游戏公司。**

---

## 一、总览：0–12 步

| 步骤 | 目标 | GitHub 方案 | 自研部分 |
|---:|---|---|---|
| 0 | 项目脚手架 + CI | Cocos、mini-game-workflow、GitHub Actions、fastlane | 项目结构 |
| 1 | 地图 + 回合 | Tiled、Cocos TileMap、boardgame.io 参考 | 12 节点图/军令 |
| 2 | 后端 + 账号 | 现有 PHP、php-jwt、ramsey/uuid | game_war_* 表/API |
| 3 | 班宠接入 | 现有 PetBattleEngine/PetHelper | 将军适配/战报 |
| 4 | 21:00 结算 | cron-expression、symfony/messenger | 结算顺序/幂等/重试 |
| 5 | 日报/分工/悬赏 | 自研 + Ink/Yarn Spinner 可选 | 全部玩法 |
| 6 | 数据/崩溃/灰度 | Sentry、Aptabase/PostHog、Flagsmith | 埋点方案 |
| 7 | QA/性能 | Playwright、Appium、Perfetto | 测试用例 |
| 8 | 内容管线 | Tiled、DragonBones/Spine、Ink/Yarn Spinner | 美术规范 |
| 9 | 微信小游戏 | Cocos 构建、mini-game-workflow | 远程资源/分包 |
| 10 | 第二期玩法 | 自研 + Flagsmith 灰度 | 天气/外交/间谍/士气/文魔/合击 |
| 11 | 第三期玩法 | 自研 + Nakama/Colyseus/Agones/Open Match | 攻城/奇观/跨班 |
| 12 | 运营/监控 | Grafana/Prometheus/ClickHouse/OpenTelemetry | 看板/告警 |

---

## 步骤 0：项目脚手架 + CI

**目标：** 三端能构建，代码能自动检查。

| 项目 | Stars | License | 用法 |
|---|---:|---|---|
| [cocos/cocos-engine](https://github.com/cocos/cocos-engine) | 9,909 | 需核对 | 客户端引擎 |
| [cocos/example-projects](https://github.com/cocos/example-projects) | 1,321 | 需核对 | 官方示例，学场景/UI/构建 |
| [zhitaie/mini-game-workflow](https://github.com/zhitaie/mini-game-workflow) | 198 | Apache-2.0 | Cocos + 微信小游戏 TypeScript 工作流 |
| [fastlane/fastlane](https://github.com/fastlane/fastlane) | 42,372 | MIT | Android/iOS 自动打包 |
| [vitest-dev/vitest](https://github.com/vitest-dev/vitest) | 17,352 | MIT | TS 单元测试 |

**自研：** 目录结构、场景划分、构建脚本。

**验收：**

- Android APK 能出包；
- Web Desktop 能打开；
- 微信小游戏能在开发者工具打开；
- push 后 CI 能跑 lint + 单测 + 构建。

---

## 步骤 1：地图 + 回合

**目标：** 12 节点地图、四阵营、3 军令、每日结算。

| 项目 | Stars | License | 用法 |
|---|---:|---|---|
| [mapeditor/tiled](https://github.com/mapeditor/tiled) | 13,036 | 需核对 | 地图数据/节点/地形编辑 |
| [boardgameio/boardgame.io](https://github.com/boardgameio/boardgame.io) | 12,486 | MIT | 回合制状态/大厅设计参考，不一定要接 |

**自研：**

- 12 节点图 + 邻接表；
- 地形/资源/胜利点；
- 3 军令：征兵/进军/驻守/筑城/侦察/运粮；
- 21:00 结算顺序。

**验收：**

- 点节点能看信息；
- 能下 3 道军令；
- 能模拟一天结算；
- 地图不卡、不糊。

---

## 步骤 2：后端 + 账号

**目标：** 登录、地图状态、军令、阵营、赛季。

| 项目 | Stars | License | 用法 |
|---|---:|---|---|
| 现有 PHP + MySQL | - | - | 复用 `students`、`shop_orders`、`pet_*` |
| [googleapis/php-jwt](https://github.com/googleapis/php-jwt) | 9,803 | BSD-3-Clause | Bearer Token |
| [ramsey/uuid](https://github.com/ramsey/uuid) | 12,633 | MIT | 幂等键/订单号 |

**自研：**

- `game_war_seasons/factions/provinces/generals/armies/orders/battles/buildings/supply/reports`；
- `/api/game/war/*`；
- 权限：学生/老师/管理员。

**验收：**

- 学生登录拿 Token；
- 老师能配置赛季；
- 军令写入成功；
- 重复提交不会双花。

---

## 步骤 3：班宠接入

**目标：** 班宠 = 将军，复用现有战斗引擎。

| 现有资产 | 用法 |
|---|---|
| `student_pets` | 将军等级/饱食度/技能槽 |
| `pet_templates` | 四维/系别/稀有度 |
| `pet_skills` / `student_pet_skills` | 技能 |
| `student_pet_artifacts` | 法宝 |
| `PetHelper::calcPetUnifiedPower()` | 战力 |
| `PetBattleEngine::fight()` | 战报 |

**自研：**

- 将军适配层：宠物数据 → 军队将军；
- 战力修正：兵力/兵种/地形/城防/士气/补给/天气；
- 战报回放：只读宠物数据，不写属性。

**验收：**

- 同一只班宠在地图战斗和原有天梯都能用；
- 地图战斗不修改宠物等级/技能/经验；
- 弱宠有归一化，不会被一刀秒。

---

## 步骤 4：21:00 结算

**目标：** 每天 21:00 可靠结算全班军令。

| 项目 | Stars | License | 用法 |
|---|---:|---|---|
| [dragonmantank/cron-expression](https://github.com/dragonmantank/cron-expression) | 4,677 | MIT | 解析/计算定时任务 |
| [symfony/messenger](https://github.com/symfony/messenger) | 1,111 | MIT | 队列/重试（可选） |

**自研：**

- 结算顺序：征兵/筑城/运粮 → 侦察/间谍 → 行军 → 遭遇 → 攻城 → 易主 → 补给/士气 → 日报；
- 事务 + 行锁；
- 幂等键；
- 失败重试/补算；
- 战报 JSON 存档。

**验收：**

- 100 个学生军令 30 秒内结算完；
- 失败能重试；
- 同一批军令重复结算不会翻倍；
- 第二天能看到战报。

---

## 步骤 5：日报/分工/悬赏

**目标：** 第一期三个留存玩法。

| 项目 | Stars | License | 用法 |
|---|---:|---|---|
| [inkle/ink](https://github.com/inkle/ink) | 5,008 | MIT | 日报/事件文案脚本（可选） |
| [YarnSpinnerTool/YarnSpinner](https://github.com/YarnSpinnerTool/YarnSpinner) | 2,871 | MIT | 对话/任务文案（可选） |

**自研：**

- 战争日报：头条/地图变化/最佳战报/MVP/传闻；
- 角色分工：将军/军师/粮官/斥候；
- 悬赏榜：3 个/天；
- 战功三榜：战斗/后勤/情报。

**验收：**

- 每天早上自动生成日报；
- 每个角色有专属动作；
- 悬赏可完成/领取；
- 战功分榜可见。

---

## 步骤 6：数据/崩溃/灰度

**目标：** 知道学生卡在哪、为什么流失。

| 项目 | Stars | License | 用法 |
|---|---:|---|---|
| [getsentry/sentry](https://github.com/getsentry/sentry) | 45,736 | 需核对 | 崩溃/错误/性能 |
| [aptabase/aptabase](https://github.com/aptabase/aptabase) | 1,868 | AGPL-3.0 | 隐私优先的轻量分析 |
| [PostHog/posthog](https://github.com/PostHog/posthog) | 40,709 | 需核对 | 漏斗/A/B/Feature Flag |
| [Flagsmith/flagsmith](https://github.com/Flagsmith/flagsmith) | 6,901 | BSD-3-Clause | 远程配置/灰度 |
| [Unleash/unleash](https://github.com/Unleash/unleash) | 14,276 | AGPL-3.0 | Feature Flag |

**首版建议：** Sentry + Aptabase/PostHog + Flagsmith。  
**自研：** 埋点事件表：登录、看日报、下军令、战斗、领悬赏、流失。

**验收：**

- 能看到“第 1 天流失在哪一步”；
- 崩溃有堆栈；
- 能远程关某个玩法，不用发版。

---

## 步骤 7：QA/性能

**目标：** 低端安卓不卡、关键路径不崩。

| 项目 | Stars | License | 用法 |
|---|---:|---|---|
| [microsoft/playwright](https://github.com/microsoft/playwright) | 99,640 | Apache-2.0 | 课堂 Web/登录/军令自动化 |
| [appium/appium](https://github.com/appium/appium) | 22,203 | Apache-2.0 | Android 关键路径自动化 |
| [google/perfetto](https://github.com/google/perfetto) | 6,773 | Apache-2.0 | Android 性能追踪 |
| [wolfpld/tracy](https://github.com/wolfpld/tracy) | 17,089 | 需核对 | 帧级性能（可选） |

**自研：** 测试用例、性能基线。

**验收：**

- 登录→看日报→下军令→结算→看战报，全链路自动跑；
- 低端安卓 30fps+；
- 首屏 <3 秒；
- 无严重闪退。

---

## 步骤 8：内容管线

**目标：** 地图/动画/剧情不是手摆，而是有管线。

| 项目 | Stars | License | 用法 |
|---|---:|---|---|
| [mapeditor/tiled](https://github.com/mapeditor/tiled) | 13,036 | 需核对 | 地图 |
| [DragonBones/DragonBonesJS](https://github.com/DragonBones/DragonBonesJS) | 860 | MIT | 2D 骨骼动画（免费） |
| [EsotericSoftware/spine-runtimes](https://github.com/EsotericSoftware/spine-runtimes) | 5,356 | 需核对 | Spine 动画（编辑器付费） |
| [inkle/ink](https://github.com/inkle/ink) | 5,008 | MIT | 剧情/事件 |
| [YarnSpinnerTool/YarnSpinner](https://github.com/YarnSpinnerTool/YarnSpinner) | 2,871 | MIT | 对话/任务 |
| [AUTOMATIC1111/stable-diffusion-webui](https://github.com/AUTOMATIC1111/stable-diffusion-webui) | 165,268 | AGPL-3.0 | 概念图/AI 草稿，不直接当成品 |

**自研：** 美术规范、命名、导出、验收。

**验收：**

- 一张地图从 Tiled 到 Cocos 能跑；
- 一个将军从 DragonBones/Spine 到战斗能播；
- 一段日报/事件从 Ink/Yarn 到游戏能显示。

---

## 步骤 9：微信小游戏

**目标：** 一套代码出小游戏。

| 项目 | Stars | License | 用法 |
|---|---:|---|---|
| Cocos Creator 构建 | - | - | 官方微信小游戏导出 |
| [zhitaie/mini-game-workflow](https://github.com/zhitaie/mini-game-workflow) | 198 | Apache-2.0 | 工作流参考 |
| 微信开发者工具 | - | - | 预览/上传/审核 |

**自研：** 远程资源、分包、微信登录绑定、包体优化。

**验收：**

- 主包 <4MB，总包 <20MB（以官方最新为准）；
- 低端安卓 30fps+；
- 微信登录能绑定学生；
- 审核类目/版号先咨询。

---

## 步骤 10：第二期玩法

**目标：** 天气、竞猜、外交、间谍、士气、中立文魔、合击。

| 项目 | 用法 |
|---|---|
| Flagsmith/Unleash | 每个玩法单独开关/灰度 |
| Sentry/PostHog | 看新玩法留存/崩溃 |
| 自研 | 全部玩法逻辑 |

**验收：**

- 每个玩法可单独关闭；
- 新玩法不影响第一期主循环；
- 第二期上线后 D7 留存不下降。

---

## 步骤 11：第三期玩法

**目标：** 攻城器械、国家奇观、跨班战争。

| 项目 | Stars | License | 用法 |
|---|---:|---|---|
| [heroiclabs/nakama](https://github.com/heroiclabs/nakama) | 13,690 | Apache-2.0 | 跨班/公会/排行榜/聊天 |
| [colyseus/colyseus](https://github.com/colyseus/colyseus) | 7,523 | MIT | 实时房间（如果做实时观战） |
| [agones-dev/agones](https://github.com/agones-dev/agones) | 7,099 | Apache-2.0 | 游戏服务器扩缩容（校级） |
| [googleforgames/open-match](https://github.com/googleforgames/open-match) | 3,428 | Apache-2.0 | 大规模匹配（校级） |

**建议：** 班级规模不需要 Agones/Open Match；校级/区级再上。

**验收：**

- 两个班能打一个赛季；
- 匹配按人数/活跃度；
- 服务器能扛住结算峰值。

---

## 步骤 12：运营/监控

**目标：** 长期维护，不靠人肉看日志。

| 项目 | Stars | License | 用法 |
|---|---:|---|---|
| [grafana/grafana](https://github.com/grafana/grafana) | 77,781 | AGPL-3.0 | 监控面板 |
| [prometheus/prometheus](https://github.com/prometheus/prometheus) | 67,574 | Apache-2.0 | 指标采集 |
| [ClickHouse/ClickHouse](https://github.com/ClickHouse/ClickHouse) | 50,832 | Apache-2.0 | 分析数据库 |
| [open-telemetry/opentelemetry-collector](https://github.com/open-telemetry/opentelemetry-collector) | 7,744 | Apache-2.0 | 全链路遥测 |

**建议：** 首版 Sentry + Aptabase/PostHog 就够；Grafana/Prometheus/ClickHouse 是校级以后。

**验收：**

- 结算成功率/延迟看板；
- 崩溃率/留存看板；
- 告警能到老师/开发者。

---

## 二、最小专业栈（首版）

```text
客户端：Cocos Creator 3.8 + TypeScript
后端：现有 PHP + MySQL
监控：Sentry + Aptabase/PostHog
灰度：Flagsmith
测试：Playwright + Appium
性能：Perfetto + Cocos Profiler
地图：Tiled
动画：DragonBones（免费）或 Spine（付费）
剧情：Ink / Yarn Spinner
CI：GitHub Actions + fastlane
```

**先不要上：** Nakama、Colyseus、Agones、Open Match、Grafana、Prometheus、ClickHouse、OpenTelemetry。  
班级规模用不上，等校级再说。

---

## 三、许可证提醒

| 许可证 | 项目 | 注意 |
|---|---|---|
| MIT/BSD/Apache | fastlane、Vitest、php-jwt、ramsey/uuid、cron-expression、symfony/messenger、boardgame.io、Colyseus、Flagsmith、Playwright、Appium、Perfetto、Ink、Yarn Spinner、DragonBonesJS | 相对安全，商用前仍核对 |
| AGPL-3.0 | Grafana、Unleash、Aptabase、Stable Diffusion WebUI | 自托管/内部用通常可；分发/商用要核对 |
| 需核对 | Cocos、Sentry、PostHog、Tiled、Spine、Tracy | 以仓库 LICENSE 为准 |

---

## 四、结论

- **GitHub 能补齐：** 构建、后端、监控、灰度、测试、性能、地图/动画/剧情管线；
- **GitHub 补不了：** 玩法是否好玩、美术质量、内容量、运营、市场；
- **首版只上最小专业栈**，不要一开始就 Nakama/Agones/ClickHouse；
- **每一步都要有验收标准**，不要“接入了就算完成”。

下一步：按步骤 0 开始，先做三端构建 + CI，再进入步骤 1 的 12 节点地图。
