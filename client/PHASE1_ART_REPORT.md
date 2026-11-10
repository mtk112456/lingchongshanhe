# 青竹·九州切片 · Phase 1 美术集成与验收报告 (PHASE1_ART_REPORT)

> **主责**：Antigravity (设计与前端主责)  
> **日期**：2026-11-10  
> **基线环境**：Godot 4.7.2-stable，PHP 8.4，MariaDB 11.4  
> **分辨率目标**：手机横屏 (720×514) 与 平板横屏 (1400×1000)

---

## 1. 核心验收指标核验结果

| 验收项 | 验收标准 | 实施方案与结果 | 结论 |
|---|---|---|---|
| **64px 兵种可辨** | 在手机横屏 720×514 (Sprite 实显约 60–72px) 下，无需文字或血条，0.2 秒内可辨兵种 | 骑兵（高头战马占 65% 体积）、盾兵（正面超大圆弧大盾遮体）、弓兵（横向反曲复合大弓）、枪兵（超长斜立点钢红缨枪）。各兵种轮廓差异极大，缩放到 64px 依然轮廓锐利、特征显著。 | **PASS** |
| **前后排层级** | 3 路 × 2 排站位分明，前排自然遮挡后排，攻左守右正面交锋 | 1. 采用 `z_index = lane * 10 + (2 if row == "front" else 1)`，严格保证同路前排单位遮挡后排足部与武器。<br>2. 攻方默认朝右，守方引擎自动镜像 `flip_h = true` 朝左迎击。<br>3. 脚底统一居中对齐 `(0.5, 0.90)`，切帧动作不抖动。 | **PASS** |
| **阵营色克制红线** | 严禁红皮蓝皮全身变色，阵营色仅体现在旗/环/印章 | 1. 单位身体采用统一水墨纸雕素色（米白麻布、皮甲、冷铁青铜）。<br>2. 攻方朱砂色 (`#b83b32`) / 守方墨蓝色 (`#1e3a5f`) 仅用于卡片外勒线、顶部阵营名牌【朱/墨】、靠旗缨穗及脚底微水墨投影环。 | **PASS** |
| **手牌与抽屉互斥** | 战术手牌栏在城池抽屉滑出时不能遮挡抽屉 | 抽屉打开时，手牌栏自动压缩为紧凑提示胶囊；抽屉关闭后恢复完整 4 张战术卡卡面；且支持手动点击“折叠/展开”。 | **PASS** |
| **全套自动化测试** | BattleReplaySmoke / ClientSmoke / ReplaySmoke 全绿 | 见第 4 节回归测试矩阵，全部 100% 通过。 | **PASS** |

---

## 2. 资产集成与客户端代码改进

### 2.1 资产接入目录结构

将 GPT 生成的 Phase 1 战斗切片按规范入库至客户端工程目录 `client/assets/art/battle/`：

```text
client/assets/art/battle/
├── cavalry_idle.png / cavalry_attack.png / cavalry_hit.png       # 骑兵三态
├── shield_idle.png / shield_attack.png / shield_hit.png         # 盾兵三态
├── archer_idle.png / archer_attack.png / archer_hit.png         # 弓兵三态
├── spear_idle.png / spear_attack.png / spear_hit.png           # 枪兵三态
├── siege_ram_idle.png / siege_ram_wall_attack.png              # 阵后攻城冲车两态
├── castle_gate_wall.png                                        # 守军城门坚壁石墙
└── preview_64px.png                                            # 64px 小尺寸对照基准图
```

### 2.2 `BattleReplay.gd` 关键改动

1. **废弃 Emoji / 纯色文字占位**：
   - 单位卡片增加 `TextureRect`（命名 `UnitSprite`），加载真实透明底工笔水墨单帧；
   - 守方单位自动设置 `flip_h = true`，形成真实的左右军阵对决氛围。
2. **三态动态切换机制**：
   - 攻击瞬间调用 `_set_unit_sprite_state(src_id, "attack")`，向前冲刺突刺/张弓；冲刺回弹后自动切回 `"idle"`；
   - 受击目标瞬间调用 `_set_unit_sprite_state(tgt_id, "hit")`，伴随受击震颤与掉血浮字；震颤结束后恢复 `"idle"`；阵亡时半透明淡出（`modulate.a = 0.35`）并标以“溃退”。
3. **攻城冲车实装**：
   - 攻方左侧阵后配备 `SiegeSprite`；
   - 在攻墙事件（`wall`）触发时，瞬间切换至 `siege_ram_wall_attack.png`（撞木长驱猛击），前冲撞击城门后平滑复位至 `siege_ram_idle.png`。
4. **守军雄关城门**：
   - 最右侧使用 `castle_gate_wall.png` 铺展全高城墙与朱漆拱门，配合受击震动与“轰! -XX”爆石碎字，破损率与顶部城墙条实时同步。

### 2.3 `CompositionPanel.gd` 每周编成改动

1. **兵种图标集成**：
   - 4 兵种选择按钮使用对应待机图图标替代原 emoji，并展示“骑兵 (突击·克盾)”；
   - 3 个编成槽位卡内嵌 `SlotUnitIcon`，直观呈现各队所驻扎兵种姿态。
2. **交互状态联动**：
   - 当前槽位所选兵种在上方按钮栏同步高亮金色外框；
   - 周中修改次数耗尽（0/1）后，所有按钮置灰禁用，确认按钮切换为“编成已锁定”。

---

## 3. 全分辨率截图产物核对

自动化截图套件已执行完毕，生成并更新全部高保真截图：

### 3.1 平板横屏 (1400×1000)

- **3路×2排 战斗推演回放**：  
  `client/tests/screenshot_tablet_phase1_battle_replay.png`  
  *（攻左守右、冲车城门、前排遮挡后排、血条数字、顶部城墙条一目了然）*
- **每周军团编成面板**：  
  `client/tests/screenshot_tablet_s03_army_composition.png`  
  *（4 兵种真实水墨图图标、3 队伍槽位、兵力与凉州兵源加成状态）*

### 3.2 手机横屏 (720×514)

- **3路×2排 战斗推演回放**：  
  `client/tests/screenshot_phone_landscape_phase1_battle_replay.png`  
  *（极致压缩空间下，四兵种剪影依然清晰锋锐，血条防重叠）*
- **每周军团编成面板**：  
  `client/tests/screenshot_phone_landscape_s03_army_composition.png`  
  *（单页无滚动条即可操作完毕，适配小屏触控）*
- **每日手牌栏与抽屉互斥**：  
  `client/tests/screenshot_phone_landscape_s01_hand_cards.png`  
  `client/tests/screenshot_phone_landscape_dock_restored.png`  
  *（4 张战术牌整齐排列，抽屉滑出时手牌自动避让不遮挡）*

---

## 4. 自动化测试回归结果

| 测试套件 / 命令 | 验证内容 | 结果 |
|---|---|---|
| `BattleReplaySmoke.tscn` | 战斗回放无头数据加载、单位构建、60 tick 推进、印章折页结算 | **BATTLE_REPLAY_SMOKE PASS** |
| `ClientSmoke.tscn` | 客户端启动、布局自适应、登录、下达坚守、教师权限切换 | **CLIENT_SMOKE PASS** |
| `ReplaySmoke.tscn` | 历史战局回放拉取、地图动态重绘、复盘文本生成 | **REPLAY_SMOKE PASS** |
| `Phase1ClientSmoke.tscn` | Phase 1 全链路冒烟（编成修改 + 3 战术出令 + 演武回放 + 结算回写） | **PHASE1_CLIENT_SMOKE PASS** |
| `tools/phase1_e2e.ps1` | 端到端 24 项前后端接口验收（登录→编成→出令→战斗→结算→读取） | **PHASE1_E2E PASS (24 passed)** |
| `server/slice/tests/run.php` | 后端 14 项冲突仲裁、并发控制、幂等结算核心测试 | **14 passed, 0 failed** |

---

## 5. 设计主责交付 GPT 的第二批 Brief

已编写完毕并归档于 [client/ART_BRIEF_PHASE1.md](file:///d:/DeskBox/游戏/client/ART_BRIEF_PHASE1.md)。  
GPT 查阅该文档后，即可按严格清单制作：
1. **3 张水墨水彩战场背景** (`bg_battle_plain.png`, `bg_battle_pass.png`, `bg_battle_ferry.png`)；
2. **九宫格战术卡框** (`card_frame_ninepatch.png`)；
3. **12 战术水墨圆形印符** (`tactics_*.png`)；
4. **4 阵营古篆牙旗** (`flag_faction_*.png`)。
