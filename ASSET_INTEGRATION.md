# 美术资产接入盘点 · GPT 交付 ↔ 客户端引用

> 生成：2026-11-11 · 只读盘点，未改 `client/`、`server/`、`art_src/`，未运行 Godot，未 commit/push。
> 方法：逐文件 MD5 比对 + `client/*.gd` 全量 `res://` 提取（含动态模板展开）+ PNG 头解析尺寸 + `ResourceLoader.exists` 调用点核对。
> 数据源：`art_src/gpt/**`（161 张图）、`client/assets/art/**`（148 个非 `.import` 文件）、`QA_REPORT_20261111.md`、`tools/message_gpt_*.txt`。

---

## 0. 结论摘要

| 指标 | 数值 | 说明 |
|---|---:|---|
| GPT 交付图片总数 | 161 | 含 12 张预览/对比/风格参考 |
| 其中正式资产 | 149 | 去掉 preview/contact sheet/`style_a|b|c`/`compare*` |
| `client/assets/art/` 现有文件 | 148 | 含 15 张本地生成的 `_trim` |
| 代码引用到的图片路径 | 117 | 102 张与 GPT 原图**字节一致** + 15 张本地裁切派生 |
| 其中真正会渲染 | 111 | 扣掉 6 条死分支/死插槽（§2.1 的 `USE_LANDMARK_PNGS=false` 备用分支 + §3.2） |
| 已交付但在库未被引用 | 31 个文件 / **27.47 MB** | 见 §3.4，占 APK 体积大头 |
| 引用路径缺文件（图） | **20 条** | 11 条影响可见，9 条是死插槽 |
| 引用路径缺文件（音） | 2 条 | `confirm` / `card_withdraw`，可用别名零成本绕过 |
| 13 城专属立绘 | 10 / 13 | **邺城、成都、建业** 借用别城图，其中邺城=建业 同一张 |
| 战斗 VFX | 36 / 36 | 6 组 × 6 帧全部在库且在链路内 |
| 赛季 | 0 / 1 | `season_keyart` 已交付未拷入；赛季页无任何贴图代码 |

**一句话**：战斗层（兵种/器械/VFX/战术/背景）已经 100% 落地；缺口全部集中在**主界面 UI Kit（4 个按钮/面板）、小院（7 条插槽全空）、三座城立绘**，以及**已交付但从未拷进 client 的 7 个资产**（P0 三张 + 赛季 keyart + 启动图 2 张 + app_icon）。

---

## 1. 判定口径

| 状态 | 定义 | 判定依据 |
|---|---|---|
| **已接入** | 代码引用的路径上存在文件，且该路径确实被消费（直接 load 或动态模板命中），文件与 GPT 源 MD5 一致 | 路径存在 + 引用点有消费者 + 哈希一致 |
| **已接入（派生）** | 文件在库并被消费，但不是 GPT 原图，而是本地裁切/合成（`city_*_trim.png`） | 哈希不一致，但由 GPT 原图裁出 |
| **未接入** | 文件在 `client/assets/art/`，但没有任何代码引用；或路径被登记却无消费者 | 全量 `res://` 扫描无命中 / 只有字典登记 |
| **路径不符** | 代码引用 A，文件实际在 B（A 无文件） | 同图在别处、路径字面不同 |
| **缺失** | 引用路径无文件，且无对应 GPT 源（或源未拷入） | `ResourceLoader.exists == false` |
| **未拷入** | GPT 源已交付，但从未出现在 `client/` | 源目录有、client 无、代码也无引用 |

> 关键区别：**"路径登记"≠"会显示"**。`Slice.gd` 的 `UI_ASSET_PATHS` 登记了 14 个插槽，但只有 4 个（`panel_card` + 3 个按钮）有消费者；其余 10 个填了图也不会出现（§6）。

---

## 2. 资产总表（按域分组）

### 2.1 十三城（13 节点 + 5 城切片）

代码入口：`client/Map12Map.gd:23` `NODES_DATA` → `Map12Map.gd:27..99` 的 `tex` 字段。
13 节点 = 12 外围城 + 中央长安；其中 4 座是阵营出生主城（凉州/邺城/成都/建业）。

| 资产名 | GPT 源路径 | client 目标路径 | 代码引用位置 | 状态 |
|---|---|---|---|---|
| 凉州（笔·出生主城） | `ai_pipeline_v1/city_liangzhou.png` | `assets/art/city_liangzhou_trim.png` | `Map12Map.gd:27` | 已接入（派生） |
| 汉中（笔） | `PHASE2_CITY_ASSETS/city_hanzhong.png` | `assets/art/city_hanzhong_trim.png` | `Map12Map.gd:33` | 已接入（派生） |
| 襄阳（笔） | `PHASE2_CITY_ASSETS/city_xiangyang.png` | `assets/art/city_xiangyang_trim.png` | `Map12Map.gd:39` | 已接入（派生） |
| **邺城（墨·出生主城）** | **无专属源** | 借用 `assets/art/city_yanhui_trim.png` | `Map12Map.gd:45` | **缺失（借用雁回关）** |
| 太原（墨） | `PHASE2_CITY_ASSETS/city_taiyuan.png` | `assets/art/city_taiyuan_trim.png` | `Map12Map.gd:51` | 已接入（派生） |
| 洛阳（墨） | `PHASE2_CITY_ASSETS/city_luoyang.png` | `assets/art/city_luoyang_trim.png` | `Map12Map.gd:57` | 已接入（派生） |
| **成都（砚·出生主城）** | **无专属源** | 借用 `assets/art/city_tingyu_trim.png` | `Map12Map.gd:63` | **缺失（借用听雨台）** |
| 江陵（砚） | `PHASE2_CITY_ASSETS/city_jiangling.png` | `assets/art/city_jiangling_trim.png` | `Map12Map.gd:69` | 已接入（派生） |
| 长沙（砚） | `PHASE2_CITY_ASSETS/city_changsha.png` | `assets/art/city_changsha_trim.png` | `Map12Map.gd:75` | 已接入（派生） |
| **建业（纸·出生主城）** | **无专属源** | 借用 `assets/art/city_yanhui_trim.png`（与邺城同图） | `Map12Map.gd:81` | **缺失（借用 + 重复）** |
| 会稽（纸） | `PHASE2_CITY_ASSETS/city_kuaiji.png` | `assets/art/city_kuaiji_trim.png` | `Map12Map.gd:87` | 已接入（派生） |
| 寿春（纸） | `PHASE2_CITY_ASSETS/city_shouchun.png` | `assets/art/city_shouchun_trim.png` | `Map12Map.gd:93` | 已接入（派生） |
| 长安（中央王城） | `ai_pipeline_v1/city_changan.png` | `assets/art/city_changan_trim.png` | `Map12Map.gd:99` | 已接入（派生） |
| 云麓关 A_START | `assets_c_v2/city_yunlu.png` | `assets/art/city_yunlu_trim.png` | `SliceMap.gd:60` | 已接入（派生） |
| 雁回关 B_START | `assets_c_v2/city_yanhui.png` | `assets/art/city_yanhui_trim.png` | `SliceMap.gd:61` | 已接入（派生） |
| 落霞原 N2 | `assets_c_v2/city_luoxia.png` | `assets/art/city_luoxia_trim.png` | `SliceMap.gd:62` | 已接入（派生） |
| 听雨台 N3 | `assets_c_v2/city_tingyu.png` | `assets/art/city_tingyu_trim.png` | `SliceMap.gd:63` | 已接入（派生） |
| 松风渡 N1 | `assets_c_v2/city_songfeng.png` | `assets/art/city_songfeng_trim.png` | `SliceMap.gd:64` | 已接入（派生） |
| 5 城地标原图（备用分支） | `assets_c_v2/city_*.png` | `assets/art/city_{yunlu,songfeng,luoxia,tingyu,yanhui}.png` | `SliceMap.gd:69`（`USE_LANDMARK_PNGS=false`，`:68`） | 未接入（分支关闭） |
| 5 城 v1（贴纸感旧版） | `assets_c/city_*.png` | 同路径已被 v2 覆盖 | — | 未接入（被 v2 取代） |

**要点**

1. 13 节点只有 **12 张不同图**；`yecheng` 与 `jianye` 指向同一个 `city_yanhui_trim.png`，地图上会出现两座一模一样的城。
2. **4 个出生主城里 3 个没有专属图**（邺城、成都、建业）。玩家第一回合看到的就是这四座城。
3. `_trim` 尺寸差异很大（凉州 484×169、长沙 478×512、江陵 512×339），导致 `Map12Map.gd:374` 只能给凉州写死 `target_h = 78.0` 特判；`Map12Map.gd:386` 按高度归一后宽度会大幅跳动。这是**源图构图不统一**导致的客户端补丁，应在下一批修掉（§5）。

---

### 2.2 战斗（兵种 / 器械 / 背景 / VFX / 战术）

| 资产名 | GPT 源路径 | client 目标路径 | 代码引用位置 | 状态 |
|---|---|---|---|---|
| 4 兵种 × 3 态 = 12 张 | `PHASE1_BATTLE_ASSETS/{shield,spear,cavalry,archer}_{idle,attack,hit}.png` | `assets/art/battle/` 同名 | `BattleReplay.gd:258`（动态）、`:1123`；`CompositionPanel.gd:181,417` | 已接入 12/12 |
| 冲车 idle / 撞墙 | `PHASE1_BATTLE_ASSETS/siege_ram_{idle,wall_attack}.png` | `assets/art/battle/` 同名 | `BattleReplay.gd:400,408,1184` | 已接入 2/2 |
| 城门墙 | `PHASE1_BATTLE_ASSETS/castle_gate_wall.png` | `assets/art/battle/castle_gate_wall.png` | `BattleReplay.gd:1217` | 已接入 |
| 战斗背景 ×3 | `PHASE1_BATTLE_ASSETS_BATCH2/bg_battle_{plain,ferry,pass}.png` | `assets/art/battle/` 同名 | `BattleReplay.gd:1451..1458` | 已接入 3/3 |
| 卡框 9-patch | `PHASE1_BATTLE_ASSETS_BATCH2/card_frame_ninepatch.png` | `assets/art/ui/card_frame_ninepatch.png` | `Slice.gd:4722`、`BattleReplay.gd:1307`、`CompositionPanel.gd:389` | 已接入 |
| 单位头像 ×4 | `PHASE1_BATTLE_ASSETS_BATCH2/unit_icon_{arc,cav,shield,spear}.png` | `assets/art/ui/` 同名 | `CompositionPanel.gd:179,415`（动态） | 已接入 4/4 |
| 战术图标 ×12 | `PHASE1_BATTLE_ASSETS_BATCH2/tactics_*.png` | `assets/art/tactics/` 同名 | `Slice.gd:4760`（`tactics_%s.png`） | 已接入 12/12 |
| 刀光/命中/箭矢/尘土/火攻/城墙裂 6 组 ×6 帧 = 36 | `PHASE3_QUALITY_VFX/vfx_{slash,hit,arrow,dust,fire,wall_crack}_01..06.png` | `assets/art/vfx/` 同名 | `BattleReplay.gd:447`（`vfx_%s_0%d.png`） | 已接入 36/36 |
| 战斗预览拼图 | `PHASE1_BATTLE_ASSETS/preview_64px.png` | `assets/art/battle/preview_64px.png` | 无 | 未接入（仅预览用） |

**结论：战斗域是唯一满编的域（71 个资产全部在链路内）**，且动态模板 100% 命中，没有静默回退。

> 小瑕疵：`card_frame_ninepatch.png` 是 256×384 的**竖版卡框**，却被当通用面板底（`Slice.gd:4722`，460×320 结果卡）使用，四边 `texture_margin=32`。拉伸后卡框比例与原稿不同，属"素材用途与形态不匹配"，非缺失。

---

### 2.3 UI Kit（面板 / 按钮 / 图标 / 印章横幅 / 卡背 / 旗）

| 资产名 | GPT 源路径 | client 目标路径 | 代码引用位置 | 状态 |
|---|---|---|---|---|
| 奶油纸卡面板（9-patch） | **无单文件**（仅 `assets_c/ui_kit_c.png` 拼图内） | 期望 `assets/art/ui_panel_card.png` | `Slice.gd:66` → 消费于 `:444`（`_panel_style`，**24 处调用**） | **缺失** |
| 朱砂主按钮 | **无单文件**（同上拼图） | 期望 `assets/art/ui_button_primary.png` | `Slice.gd:67` → `:482`（`_button`，**23 处调用**） | **缺失** |
| 墨蓝次按钮 | **无单文件** | 期望 `assets/art/ui_button_secondary.png` | `Slice.gd:68` → `:482` | **缺失** |
| 竹青确认按钮 | **无单文件** | 期望 `assets/art/ui_button_confirm.png` | `Slice.gd:69` → `:482` | **缺失** |
| 军报抬头横幅 | 未交付 | 期望 `assets/art/ui_report_banner.png` | `Slice.gd:70` | **缺失（死插槽）** |
| 回放木框 | 未交付 | 期望 `assets/art/ui_replay_frame.png` | `Slice.gd:71` | **缺失（死插槽）** |
| 胜利印章 | `PHASE3_QUALITY_VFX/seal_victory.png` | `assets/art/ui/seal_victory.png` | 登记于 `Slice.gd:72`（路径错）；真载入 `Slice.gd:3154`、`BattleReplay.gd:631` | 已接入（登记路径不符） |
| 失败印章 | `PHASE3_QUALITY_VFX/seal_defeat.png` | `assets/art/ui/seal_defeat.png` | 登记于 `Slice.gd:73`（路径错）；真载入同上 | 已接入（登记路径不符） |
| 军令图标 ×4（进军/驻守/侦察/补给） | 未交付 | 期望 `assets/art/icon_order_{advance,defend,scout,supply}.png` | `Slice.gd:74..77` | **缺失（死插槽）** |
| 班宠·青竹（普通） | `assets_c/mascot_bamboo_normal.png` | `assets/art/mascot_bamboo_normal.png` | `Slice.gd:78` | 未接入（登记无消费者） |
| 班宠·墨点（普通） | `assets_c/mascot_inkdrop_normal.png` | 期望 `assets/art/mascot_ink_normal.png` | `Slice.gd:79` | **路径不符 + 死插槽** |
| 班宠其余 4 张 | `assets_c/mascot_{bamboo_happy,bamboo_nervous,inkdrop_proud,inkdrop_sad}.png` | `assets/art/` 同名 | 无 | 未接入 4 张 |
| 设置/音乐/音效/跳过/教学/减速/倍速 图标 ×10 | `PHASE3_QUALITY_VFX/icon_*.png` | `assets/art/ui/` 同名 | `Slice.gd:1340,1592,3988..4030,4086,4127`；`BattleReplay.gd:851,1274` | 已接入 10/10 |
| 城头换旗横幅 | `PHASE3_QUALITY_VFX/banner_capture.png` | `assets/art/ui/banner_capture.png` | `BattleReplay.gd:623` | 已接入（图内含烘焙文字，见 §5.6） |
| 守城成功横幅 | `PHASE3_QUALITY_VFX/banner_defense.png` | `assets/art/ui/banner_defense.png` | `BattleReplay.gd:623` | 已接入（同上） |
| 阵营旗 ×4（bi/mo/yan/zhi） | `PHASE2_CITY_ASSETS/flag_faction_{bi,mo,yan,zhi}.png` | `assets/art/ui/` 同名 | `Map12Map.gd:224..227`、`SliceMap.gd:124..131` | 已接入 4/4 |
| 旧旗 dan / shuang | `PHASE1_BATTLE_ASSETS_BATCH2/flag_faction_{dan,shuang}.png` | `assets/art/ui/` 同名 | 无（后端 code 是 yan/zhi） | 未接入 2 张（遗留，建议删） |
| 阵营卡背 ×4 | `PHASE2_CITY_ASSETS/card_back_{bi,mo,yan,zhi}.png` | `assets/art/ui/` 同名 | **无任何引用** | 未接入 4/4 |
| UI Kit 拼图（参考） | `assets_c/ui_kit_c.png` | `assets/art/ui_kit_c.png` | 无 | 未接入（不应进包，2.84 MB） |

**要点**

- UI Kit 缺口**不是"没画"**，而是 `ui_kit_c.png` 是一张 1586×992 的**拼图**（纸卡面板 + 红/蓝按钮 + 粮/木/铁/玉 4 个资源图标 + 木桌背景），没人切分。而代码要的是 4 个独立 9-patch 文件。
- 拼图里的 4 个资源图标（粮/木/铁/玉）**代码里连插槽都没有**（HUD 用纯文字 `Slice.gd:128-130`）。
- 印章/横幅都已交付且在用，但 `seal_*` 在 `UI_ASSET_PATHS` 里登记成了错误路径——**这条登记是死插槽**，真正生效的是另一条正确路径，所以"路径不符"目前不影响观感（见 §3.2）。

---

### 2.4 教学

| 资产名 | GPT 源路径 | client 目标路径 | 代码引用位置 | 状态 |
|---|---|---|---|---|
| 教学 01 点城 | `PHASE3_QUALITY_VFX/tutorial_01_choose_city.png` | `assets/art/ui/tutorial_01_choose_city.png` | `Slice.gd:4286` | 已接入 |
| 教学 02 手牌展开 | `PHASE3_QUALITY_VFX/tutorial_02_choose_card.png` | `assets/art/ui/tutorial_02_choose_card.png` | `Slice.gd:4287` | 已接入 |
| 教学 03 出令确认 | `PHASE3_QUALITY_VFX/tutorial_03_confirm.png` | `assets/art/ui/tutorial_03_confirm.png` | `Slice.gd:4288` | 已接入 |
| 教学入口图标 | `PHASE3_QUALITY_VFX/icon_tutorial.png` | `assets/art/ui/icon_tutorial.png` | `Slice.gd:4127` | 已接入 |
| **首令引导「牌→城」** | `P0_FLOW/first_order_city_card_guide.png` | 既定：`assets/art/ui/first_order_city_card_guide.png`（`tools/message_antigravity_p0_art_integration.txt:28`） | 无（待接首次 3 步教学第 1 步） | **未拷入（方案已定、未执行）** |
| 个人军报「送达」 | `P0_FLOW/personal_report_delivery.png` | 既定：`assets/art/ui/personal_report_delivery.png`（同文件 `:22`） | 无（待接 `MorningReportModal.gd` 上半部） | **未拷入（方案已定、未执行）** |

**要点**：三步教学插画（1024×576）已全量落地。P0 的两张"首令引导 / 个人军报"**接入方案已写在 `tools/message_antigravity_p0_art_integration.txt`**，目标路径与用法都明确了，只是还没执行——属于"差一次复制 + 一次接线"，不是"缺资产"。

---

### 2.5 小院（Estate）

| 资产名 | GPT 源路径 | client 目标路径 | 代码引用位置 | 状态 |
|---|---|---|---|---|
| 小院主视觉（通用） | `P0_FLOW/estate_home_base.png`（1600×640） | **A 路（零代码）**：`assets/art/estate/estate_courtyard.png`；**B 路（既定方案）**：`assets/art/ui/estate_home_base.png` | A：`EstateView.gd:1922`；B：待接 `EstateView.gd` 主卡背景（`tools/message_antigravity_p0_art_integration.txt:16`） | **未拷入（A 路复制即生效）** |
| 小院主视觉 lv1 / lv2 / lv3 | 未交付 | 期望 `assets/art/estate/estate_courtyard_lv{1,2,3}.png` | `EstateView.gd:1919` | **缺失 3 张** |
| 书房 room | 未交付 | 期望 `assets/art/estate/estate_room_study.png` | `EstateView.gd:2055` | **缺失** |
| 练兵场 room | 未交付 | 期望 `assets/art/estate/estate_room_drill.png` | `EstateView.gd:2055` | **缺失** |
| 望楼 room | 未交付 | 期望 `assets/art/estate/estate_room_tower.png` | `EstateView.gd:2055` | **缺失** |

**要点**

- `client/assets/art/estate/` **整个目录不存在**，7 条插槽全空 → `EstateView.gd:1928` 起 100 余行程序化绘制在跑（远山/院墙/主殿/旗/沙池/竹林）。能看，但与 Style C 其他页面不是一个层级。
- `estate_home_base.png` 与程序化绘制的内容**一一对应**（牌位、门楼、书房、班宠、木桩、望楼、旗杆），是现成的替换件。两条路都能用：
  - **A 路（零代码）**：放进 `estate/estate_courtyard.png`，被 `:1922` 的 `elif` 直接接住；
  - **B 路（既定方案，效果更好）**：放进 `ui/estate_home_base.png`，由 Antigravity 接到小院主卡背景（`message_antigravity_p0_art_integration.txt:16`，手机 410×182 / 平板 834×544 裁切保住书案/望楼/门牌）。
- 唯一不足：单张 1600×640，没有等级变体，lv1/2/3 会长得一样。

---

### 2.6 赛季

| 资产名 | GPT 源路径 | client 目标路径 | 代码引用位置 | 状态 |
|---|---|---|---|---|
| 赛季 Key Art | `PHASE2_CITY_ASSETS/season_keyart.png`（2560×1440） | 无 | 无 | **未拷入** |
| 史书页边框 | `PHASE3_QUALITY_VFX/season_book_frame.png` | `assets/art/ui/season_book_frame.png` | 无 | 未接入 |
| 四阵营勋章 ×4 | `PHASE3_QUALITY_VFX/medal_{bi,mo,yan,zhi}.png` | `assets/art/ui/` 同名 | 无 | 未接入 4/4 |
| 赛季页兜底底图 | `keyart_c.png` | `assets/art/keyart_c.png` | `Slice.gd:3821`（`page_id == "S10_SEASON"`） | 已接入（临时兜底） |

**要点**

- `client/SeasonView.gd` 全文 **0 个 `Texture` / 0 处贴图引用**（唯一 `res://` 是 `:10` 的字体）—— 赛季页是纯程序化绘制，**没有任何贴图入口**。所以 `season_keyart` / 勋章 / 史书框即使拷进去也不会显示。
- 现状：赛季页用登录主视觉 `keyart_c.png` 当背景（`Slice.gd:3821`），能用但不是赛季主题（缺"九州 + 四旗"）。

---

### 2.7 音频

> 音频不是 GPT 美术任务范围；此处只核对"代码要的名字 ↔ 磁盘上的文件"。**`QA_REPORT_20261111.md` §3.3 的"`client/assets/audio/` 目录整体不存在"已过时** —— 目录与 10 个 wav 现在都在（2026-11-11 00:25 生成）。

| 资产名 | 源 | client 路径 | 代码引用位置 | 状态 |
|---|---|---|---|---|
| `hit` | 占位 wav | `assets/audio/sfx/hit.wav` | `BattleReplay.gd:308` | 已接入 |
| `arrow` | 占位 wav | `assets/audio/sfx/arrow.wav` | `BattleReplay.gd:384` | 已接入 |
| `wall_break` | 占位 wav | 别名 → `sfx/wall.wav`（`AudioManager.gd:23`） | `BattleReplay.gd:414` | 已接入（别名） |
| `stamp` | 占位 wav | 别名 → `sfx/victory.wav`（`AudioManager.gd:24`） | `BattleReplay.gd:655`、`Slice.gd:4962` | 已接入（别名） |
| `victory` | 占位 wav | `sfx/victory.wav` | `EstateView.gd:1068` | 已接入 |
| `click` | 占位 wav | `sfx/click.wav` | `Slice.gd:4063,4895..4942,5608`、`EstateView.gd:1537` | 已接入 |
| `confirm` | — | 期望 `sfx/confirm.wav` | `EstateView.gd:1131` | **缺失** |
| `card_withdraw` | — | 期望 `sfx/card_withdraw.wav` | `Slice.gd:4978` | **缺失** |
| BGM `map` / `battle` | 占位 wav | `assets/audio/bgm/{map,battle}.wav` | **无 `play_bgm()` 调用** | 未接入（有文件、无人播） |
| `defeat` / `draw` / `play` | 占位 wav | `sfx/` 同名 | 无 | 未接入 3 个 |

**要点**

- 缺的 2 个音效**可以零新资产解决**：`play.wav`（10.6 KB）与 `draw.wav`（8 KB）疑似就是"确认/抽牌"的旧命名，在 `AudioManager.gd:22` 的 `SFX_ALIASES` 里加两条即可：
  `"confirm": "play"`、`"card_withdraw": "draw"`。
- **BGM 全程不会响**：`play_bgm` 定义了但没有任何调用点。这是接线问题，不是资产问题。

---

## 3. 真实缺失清单（`ResourceLoader.exists` 会静默回退）

### 3.1 有消费者、玩家能直接看出（11 图 + 2 音）

| # | 引用路径 | 引用位置 | 缺失后果（当前表现） |
|---|---|---|---|
| 1 | `res://assets/art/ui_panel_card.png` | `Slice.gd:66` → `:444` | 所有面板退回纯色 `StyleBoxFlat`（米黄底 + 细边），没有纸纹/角贴/暖阴影；**24 处调用同时受影响** |
| 2 | `res://assets/art/ui_button_primary.png` | `Slice.gd:67` → `:482` | 主行动按钮为纯朱砂色块，无纸片厚度 |
| 3 | `res://assets/art/ui_button_secondary.png` | `Slice.gd:68` → `:482` | 次按钮为纯墨蓝色块 |
| 4 | `res://assets/art/ui_button_confirm.png` | `Slice.gd:69` → `:482` | 确认按钮为纯竹青色块 |
| 5 | `res://assets/art/estate/estate_courtyard.png` | `EstateView.gd:1922` | 小院主视觉 100% 程序化（`:1928` 起 100 余行 `_draw`） |
| 6 | `res://assets/art/estate/estate_courtyard_lv1.png` | `EstateView.gd:1919` | 同上；且三级小院外观无差异 |
| 7 | `res://assets/art/estate/estate_courtyard_lv2.png` | 同上 | 同上 |
| 8 | `res://assets/art/estate/estate_courtyard_lv3.png` | 同上 | 同上 |
| 9 | `res://assets/art/estate/estate_room_study.png` | `EstateView.gd:2055` | 书房卡退回"竹简+封泥"矢量图 |
| 10 | `res://assets/art/estate/estate_room_drill.png` | 同上 | 练兵场卡退回矢量图 |
| 11 | `res://assets/art/estate/estate_room_tower.png` | 同上 | 望楼卡退回矢量图 |
| 12 | `sfx/confirm.wav` | `EstateView.gd:1131` | 小院"升级/确认"点击无声（`play_sfx` 静默 return） |
| 13 | `sfx/card_withdraw.wav` | `Slice.gd:4978` | 撤回手牌无声 |

> 注：`estate_courtyard_lv%d` 与 `estate_room_%s` 是动态模板，静态扫描不会报"缺失"，但运行期同样静默回退——这是本次最容易漏掉的一类。

### 3.2 无消费者、补了也不会显示（9 条，先接线再谈图）

| 引用路径 | 引用位置 | 说明 |
|---|---|---|
| `res://assets/art/icon_order_advance.png` | `Slice.gd:74` | 只在字典里登记，全项目无 `ui_kit_textures["order_advance"]` 读取 |
| `res://assets/art/icon_order_defend.png` | `Slice.gd:75` | 同上 |
| `res://assets/art/icon_order_scout.png` | `Slice.gd:76` | 同上 |
| `res://assets/art/icon_order_supply.png` | `Slice.gd:77` | 同上 |
| `res://assets/art/ui_report_banner.png` | `Slice.gd:70` | 无读取 |
| `res://assets/art/ui_replay_frame.png` | `Slice.gd:71` | 无读取（回放框是程序化 `StyleBox`） |
| `res://assets/art/ui_seal_victory.png` | `Slice.gd:72` | 路径不符：真图在 `ui/seal_victory.png`，且已由 `Slice.gd:3154` / `BattleReplay.gd:631` 正确加载 |
| `res://assets/art/ui_seal_defeat.png` | `Slice.gd:73` | 同上 |
| `res://assets/art/mascot_ink_normal.png` | `Slice.gd:79` | 路径不符：真名 `mascot_inkdrop_normal.png`；且 6 张班宠**全部无消费者** |

### 3.3 已交付但从未进入 client（7 个）

| 文件 | 尺寸 | 体积 | 为什么该进 |
|---|---|---:|---|
| `PHASE2_CITY_ASSETS/season_keyart.png` | 2560×1440 RGB | 7.0 MB | 赛季页唯一缺失的主视觉 |
| `PHASE3_QUALITY_VFX/app_icon.png` | 1024×1024 RGB | 1.9 MB | `project.godot` 仍是 `config/icon="res://icon.svg"`（Godot 默认图标），`export_presets.cfg` 的 `launcher_icons/*` 三项全为空 → **APK 装到桌面就是 Godot 图标** |
| `PHASE3_QUALITY_VFX/splash_portrait.png` | 1080×1920 RGB | 3.2 MB | 无启动图 |
| `PHASE3_QUALITY_VFX/splash_landscape.png` | 1920×1080 RGB | 4.2 MB | 无启动图 |
| `P0_FLOW/estate_home_base.png` | 1600×640 RGB | 1.9 MB | 小院现成替换件（A 路零代码 / B 路既定 `ui/estate_home_base.png`） |
| `P0_FLOW/first_order_city_card_guide.png` | 1024×576 RGB | 1.2 MB | 首令引导（既定 `ui/first_order_city_card_guide.png`） |
| `P0_FLOW/personal_report_delivery.png` | 1024×576 RGB | 1.1 MB | 结算个人军报（既定 `ui/personal_report_delivery.png`） |

### 3.4 在库但零引用（31 个文件 / 27.47 MB）

按性质分三类，处理方式不同：

| 类别 | 文件 | 体积 | 建议 |
|---|---|---:|---|
| 待接线的成品 | `card_back_*`×4、`medal_*`×4、`season_book_frame`、`mascot_*`×5 | 4.4 MB | 保留，等 Antigravity 接线（§6） |
| 原尺寸城池 PNG（只用 trim） | `city_{changan,changsha,hanzhong,jiangling,kuaiji,liangzhou,luoyang,shouchun,taiyuan,xiangyang}.png` | 3.4 MB | 可移出包（保留 `art_src` 源），或改为运行时裁切 |
| 历史版本 / 参考图 | `map_c.png`、`map_c_v3_clean.png`、`map_c_portrait.png`、`ui_kit_c.png`、`flag_faction_{dan,shuang}.png`、`battle/preview_64px.png` | 19.7 MB | **建议清出 `client/`**，其中 `map_c_v3_clean` 单张 10.2 MB |

> APK 当前 124 MB，`client/assets/art/` 合计 92.3 MB。仅清理上表第三类就能省约 20 MB。

---

## 4. 下一批最该补的 10 个资产（按玩家可见影响排序）

排序依据：**出现频次 × 屏幕面积 × 是否已在主流程可见**。前 3 项的共同点是"资产一到位，观感立刻变，且不需要改代码或只改配置"。

| # | 资产 | 类型 | 玩家可见影响（证据） | 交付要求 | 验收 |
|---|---|---|---|---|---|
| 1 | `ui_panel_card.png`（9-patch 纸卡面板） | 新出图（从拼图切+重做 9-patch） | 主界面所有卡片/弹层/抽屉的底；`_panel_style` **24 处调用**（`Slice.gd:444`），现为纯色块 | 512×512 RGBA，四边 16px 等宽可拉伸 | 640×360 与 1280×720 下边框不变形、无拉伸纹 |
| 2 | `ui_button_primary / secondary / confirm.png` | 新出图（3 个） | 全部按钮；`_button` **23 处调用**（`Slice.gd:482`），现为三种纯色块 | 384×96 RGBA，四边 12px 等宽 | 文字 15px 居中时不压边；按下/禁用不靠改图 |
| 3 | 小院底图落位（`estate_home_base.png`） | 拷入（A 路零代码） | 小院整页；现为 100 余行程序化绘制（`EstateView.gd:1928`） | A 路：复制为 `assets/art/estate/estate_courtyard.png`；B 路：复制为 `assets/art/ui/estate_home_base.png` 并接主卡背景 | 1280×720 下面板不裁到门楼/望楼 |
| 4 | `app_icon.png` + `splash_portrait/landscape.png` | 拷入 + 改配置 | 安装图标与首启 3 秒；现在桌面是 **Godot 默认图标**（`export_presets.cfg` 三个 launcher_icons 为空） | 1024×1024 不透明；1080×1920 / 1920×1080；安全区上下各留 15% | 真机安装后图标正确、启动图无拉伸 |
| 5 | `city_yecheng.png` + `city_jianye.png` | 新出图（2 个） | 13 城地图上**两座城共用同一张雁回关图**（`Map12Map.gd:45` 与 `:81`）；且都是出生主城 | 512×512 RGBA，底座居中，主体高度占比统一 | 与雁回关并排时不混淆；64px 可辨 |
| 6 | `city_chengdu.png` | 新出图（1 个） | 砚阵营出生主城借用"听雨台"（`Map12Map.gd:63`），与 5 城切片同图 | 同上 | 同上 |
| 7 | `season_keyart.png` | 拷入 + 接线 | 赛季页现在拿登录主视觉兜底（`Slice.gd:3821`），缺"长安+九州+四旗" | 已有 2560×1440，建议压到 ≤2 MB | S10 页面背景铺满、文字区不压主体 |
| 8 | `sfx/confirm.wav`、`sfx/card_withdraw.wav` | **可零新增**：加 2 条别名 | 小院确认、撤回手牌两处操作**完全无声**（`EstateView.gd:1131`、`Slice.gd:4978`） | 优先在 `AudioManager.gd:22` 加 `"confirm":"play"`、`"card_withdraw":"draw"`；要独立音色再出 wav | 两处点击有反馈；`click` 与 `confirm` 能听出区别 |
| 9 | `personal_report_delivery.png` | 拷入 + 接线（方案已定） | 回合结算首屏（"我今天下了 3 令"），目前无图 | 复制到 `assets/art/ui/personal_report_delivery.png`，接 `MorningReportModal.gd` 上半部 | 720×514 下右侧留白能放 3 行 12px 文字 |
| 10 | `first_order_city_card_guide.png` | 拷入 + 接线（方案已定） | 首次 5 分钟"牌→城"认知，决定首令是否卡住 | 复制到 `assets/art/ui/first_order_city_card_guide.png`，接教学第 1 步/首令浮层 | 新玩家不看文字也能指向"先选城再出牌" |

**备选（第 11 位）**：`icon_order_{advance,defend,scout,supply}.png` 4 枚 128×128。军令是核心操作，但目前 `Slice.gd:74-77` 是**死插槽**，出图前必须先接线，否则投了也看不见，故排在 P0 流程之后。

---

## 5. 给 GPT 的命名 / 尺寸规范建议

> 本节的每一条都对应本次实际发生的接入失败，不是通用建议。

### 5.1 五条硬规则

1. **一资产一文件**。禁止交付拼图 / contact sheet / 九宫格总览。本次 `ui_kit_c.png`（1586×992，面板+按钮+4 资源图标+木桌底）直接导致 4 个 UI 插槽全空。
2. **文件名 = 代码插槽名**。交付前对照 §5.2 映射表；不要自创 `ui_panel_main.9.png`（`TASKS_GPT_ART.md:80` 的旧名）而代码要 `ui_panel_card.png`。
3. **图里零文字**，包括印章、横幅、勋章、城池牌。本次 `seal_victory.png` 烘了"破城"、`banner_capture.png` 烘了"城头换旗"，而代码同时还会画 `【破城】`/`【大获全胜】`（`BattleReplay.gd:616` + `:1349`）→ 战果页出现**同一句意思写两遍**，且印章被缩到 38px（`:1344`）后烘的字糊成一团。
4. **不交 `_trim`、不交裁切版**。城市裁切由客户端生成（`city_*_trim.png` 是本地产物），GPT 只交 512×512 完整画布。
5. **不带版本号 / 尺寸 / 中文进文件名**。`preview_64px.png` 已在两个批次重名（`PHASE1_BATTLE_ASSETS` 384×192 与 `assets_c_v2` 320×64），哈希比对时产生歧义。

### 5.2 代码插槽映射表（照这个交，直接可接）

| 代码插槽 | 要交付的文件名 | 当前状态 |
|---|---|---|
| `panel_card` | `ui_panel_card.png` | 缺 |
| `btn_primary` | `ui_button_primary.png` | 缺 |
| `btn_secondary` | `ui_button_secondary.png` | 缺 |
| `btn_confirm` | `ui_button_confirm.png` | 缺 |
| `report_banner` | `ui_report_banner.png` | 缺（需接线） |
| `replay_frame` | `ui_replay_frame.png` | 缺（需接线） |
| `order_advance/defend/scout/supply` | `icon_order_{advance,defend,scout,supply}.png` | 缺（需接线） |
| `mascot_bamboo` | `mascot_bamboo_normal.png` | 已有 |
| `mascot_ink` | `mascot_ink_normal.png` | 实际叫 `mascot_inkdrop_normal.png` |
| 小院主视觉 | `estate/estate_courtyard.png`（A 路，零代码）或 `ui/estate_home_base.png`（B 路，既定） | 缺 |
| 小院房间 | `estate/estate_room_{study,drill,tower}.png` | 缺 |
| 城池（13 城） | `city_{liangzhou,hanzhong,xiangyang,yecheng,taiyuan,luoyang,chengdu,jiangling,changsha,jianye,kuaiji,shouchun,changan}.png` | 缺 3 座 |
| 战斗 VFX | `vfx_{slash,hit,arrow,dust,fire,wall_crack}_01..06.png` | 已有（沿用格式） |
| 战术图标 | `tactics_<code>.png`（12 个 code 固定） | 已有 |
| 首令引导 / 个人军报 | `ui/first_order_city_card_guide.png`、`ui/personal_report_delivery.png` | 缺（既定路径，见 `message_antigravity_p0_art_integration.txt`） |

> 若要沿用现成 `UI_ASSET_PATHS` 的旧路径（`assets/art/ui_panel_card.png` 这种平铺），也行；但**不要再出现第三个名字**。

### 5.3 尺寸 / 格式表

| 类别 | 画布 | 格式 | 透明底 | 构图约束 |
|---|---|---|---|---|
| 城池立绘 | 512×512 | RGBA PNG | 是 | 建筑底座中点 = 画布**底边中心**；主体高度占画布 **75–85%**，宽度 ≤70%（避免客户端按城特判，见 `Map12Map.gd:374`） |
| 面板 9-patch | 512×512 | RGBA PNG | 是 | 四边各 16px 等宽、无纹理变化的可拉伸边 |
| 按钮 9-patch | 384×96 | RGBA PNG | 是 | 四边各 12px；按下态不做（代码只换色） |
| 通用图标 | 128×128 | RGBA PNG | 是 | 主体占 80%，64px 下可辨 |
| 战术 / 单位图标 | 128×128 | RGBA PNG | 是 | 沿用现有 |
| 兵种立绘 | 512×512 | RGBA PNG | 是 | 脚底中点 = 底边中心；idle/attack/hit 三态同画布同位置 |
| 器械 | 512×512 | RGBA PNG | 是 | 同上 |
| 城墙 / 城门 | 1024×512 | RGBA PNG | 是 | 底边贴齐 |
| VFX 序列 | 256×256 ×6 | RGBA PNG | 是 | 同一视觉中心；`_01.._06`；12fps |
| 战斗背景 | 1920×1080 | RGB PNG | 否 | 中央 60% 留空给单位 |
| 教学 / 流程插画 | 1024×576 | RGB PNG | 否 | 明确标出文字留白区（左上/右下） |
| 小院全景 | 1600×640（或 1920×720） | RGB PNG | 否 | 上方 1/3 淡雾留标题；左侧门牌位、右侧旗杆位 |
| 小院房间 | 512×384 | RGBA 优先 | 建议是 | 主体居中，四角留 8px |
| 赛季 Key Art | 2560×1440 | RGB，≤2 MB | 否 | 中央留标题区 |
| 全屏底图 | 2560×1600 | RGB，≤2 MB | 否 | 长边不超过 2560，优先压过的 PNG/WebP |
| 竖屏底图 | 1080×1920 | RGB | 否 | — |
| 印章 | 256×256 | RGBA PNG | 是 | **不写字**；会被缩到 38px 使用 |
| 横幅 | 1024×256 | RGBA PNG | 是 | **不写字**；会被压到 36px 高使用 |
| 卡背 | 256×384 | RGBA PNG | 是 | 与 `card_frame_ninepatch` 同纸感 |
| 勋章 | 256×256 | RGBA PNG | 是 | 无文字、无排名数字 |
| 班宠 | 1024×1024 | RGBA PNG | 是 | 三表情同画布、同站位、同头部比例 |
| 启动图 | 1080×1920 / 1920×1080 | RGB | 否 | 上下各留 15% 安全区（防裁切） |
| App 图标 | 1024×1024 | RGB（不透明） | 否 | **不要自己做圆角**，系统会裁 |

### 5.4 体积红线（当前 APK 124 MB 的直接原因）

- 单张全屏底图 ≤ 2 MB；本次 `map12_concept_v2.png` **12.9 MB**、`map_c_v4.png` **10.5 MB**、`map_c_v3_clean.png` **10.2 MB**。
- 同一资产不要交多个"迭代版"进 `client/`（本次 3 张地图旧版共 16.8 MB 在包里）。
- 需要 `_trim` 的不要交裁切版；需要多分辨率的用 2x 单张 + 运行时缩放，不要交 1x/2x 两套。

### 5.5 交付附带清单（强烈建议）

每批交付附一个 `MANIFEST.csv`，六列即可：

```text
filename,width,height,alpha,intended_slot,notes
ui_panel_card.png,512,512,yes,panel_card,"4边16px可拉伸"
```

这样 OpenCode 侧可以脚本校验"尺寸/透明/命名/插槽"四项，避免再来一轮"图交了但接不上"。

### 5.6 本次实际退回原因（按损失排序）

| # | 问题 | 证据 | 损失 |
|---|---|---|---|
| 1 | 拼图代替单文件 | `assets_c/ui_kit_c.png` 1586×992 | 4 个高频 UI 插槽全空 |
| 2 | 烘焙中文 | `seal_victory.png`="破城"、`banner_capture.png`="城头换旗" | 战果页语义重复 + 38px 下糊 |
| 3 | 命名不符 | `mascot_inkdrop_*` vs 代码 `mascot_ink_*`；`dan/shuang` vs 后端 `yan/zhi` | 2 次无效交付、2 张旗作废 |
| 4 | 缺等级/状态变体 | 小院只有 1 张 1600×640，代码要 lv1–3 | 三级小院无差别 |
| 5 | 构图比例不统一 | `_trim` 宽高比 2.86（凉州）↔ 0.93（长沙） | 客户端写死特判 `Map12Map.gd:374` |
| 6 | 版本稿混入成品目录 | 3 张地图旧版、`style_a/b/c`、`compare*.jpg` 平铺 `art_src/gpt/` | 难以判断哪张是正式资产 |

---

## 6. 需要 Antigravity 配合的接线点（不是资产问题）

这些位置**图到位也不会显示**，需要先加消费者：

| # | 位置 | 现状 | 需要的动作 |
|---|---|---|---|
| 1 | `Slice.gd:70` `report_banner` | 字典登记，无读取 | 军报页 `_build_report_card()` 顶部接 `TextureRect` |
| 2 | `Slice.gd:71` `replay_frame` | 字典登记，无读取 | 回放容器改用 `StyleBoxTexture` |
| 3 | `Slice.gd:74-77` 军令图标 ×4 | 字典登记，无读取 | 出令按钮 / 手牌卡角标接 `icon` |
| 4 | `Slice.gd:78-79` 班宠 ×2 | 字典登记，无读取 | 登录页/战报点评位接 `TextureRect`（6 张图已在库） |
| 5 | `SeasonView.gd`（全文） | 0 贴图 | 加 `season_keyart` 背景 + 4 枚 `medal_*` + `season_book_frame` |
| 6 | `card_back_*` ×4 | 无引用 | 手牌背面/未发牌位接入（注意：`card_back` 与 `card_frame` 同尺寸 256×384，可共用槽） |
| 7 | `AudioManager.gd:22` | `confirm`/`card_withdraw` 无别名 | 加 2 条别名，或补 2 个 wav |
| 8 | `AudioManager.play_bgm` | 0 调用 | 主城/战斗切场景时播 `map` / `battle` |
| 9 | `project.godot:config/icon` + `export_presets.cfg:launcher_icons/*` | 仍指向 Godot 默认 | 拷入 `app_icon.png` 后改 4 处配置 |
| 10 | 首次登录/结算页 | 无插槽 | 按 `tools/message_antigravity_p0_art_integration.txt` 与 `message_antigravity_personal_report.txt`：小院主卡背景、`MorningReportModal` 上半部、教学第 1 步各加一个插图容器 |

---

## 7. 方法与复现

- **引用提取**：读取 `client/` 根目录 **15 个 `.gd`**（另有 13 个 `client/tests/*.gd` 只引用场景/脚本，无美术引用），正则 `res://[^"'\s\)\],]+`，共 **135 处字面量** → 去重 **90 条**（83 条具体 + 7 条 `%s`/`%d` 模板）。把模板按代码语义展开（兵种 4×3、VFX 6×6、战术 12、单位图标 4、小院等级 3、房间 3），再加上 1 处字符串拼接（`BattleReplay.gd:1275` 倍速图标 2 条），得到 **155 条具体路径**。
- **存在性**：155 条中 138 条位于 `assets/art/`，17 条是脚本/场景/字体/数据（全部存在）。`assets/art` 的 138 条里 **117 条命中**、**20 条无文件**、1 条是用于拼接的目录前缀 `res://assets/art/ui/`。
- **来源核实**：对 `art_src/gpt/**` 与 `client/assets/art/**` 全量 MD5，逐一判定"字节一致 / 同图裁切 / 完全无源"。
- **尺寸**：解析 PNG IHDR（宽高 / 位深 / 颜色类型）。
- **未做**：未运行 Godot，未跑 ClientSmoke/ReplaySmoke，未打开 APK 验证实际观感；所有"玩家可见"判断基于代码调用点与素材用途，属静态推断。

### 与 `QA_REPORT_20261111.md` 的差异（3 处）

| 项 | QA 报告 | 本次实测 | 原因 |
|---|---|---|---|
| 静态缺失 | 13 处 | 14 处 | 新增 `assets/art/estate/estate_courtyard.png`（`EstateView.gd:1922`）未被上轮扫描覆盖 |
| 动态缺失 | 未量化 | 6 条（小院 3 等级 + 3 房间） | 上轮只统计了"静态字面量"，`%d`/`%s` 模板未展开 |
| 音频 | "`client/assets/audio/` 整体不存在" | 目录存在，10 个 wav 齐全 | 音频于 2026-11-11 00:25 落地，报告结论已过时；真实缺口只剩 2 个文件名 |

---

**本次仅新增 `ASSET_INTEGRATION.md`，未修改 client / server / 资产，未运行 Godot，未 commit/push。**
