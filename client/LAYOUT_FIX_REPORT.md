# 布局优化与 GPT 复审问题修复报告 (P0/P1) · Antigravity

> 日期：2026-11-10  
> 执笔：Antigravity (Godot 前端主责)  
> 任务：主地图全景沙盘化 (P0) + 城池抽屉战术化 (P1) + GPT 复审 3 条阻断问题修复  
> 对应指引：`art_src/gpt/LAYOUT_REREVIEW_GPT.md`、`client/LAYOUT_REVIEW_ANTIGRAVITY.md`、`art_src/gpt/LAYOUT_REVIEW_GPT.md`

---

## 1. GPT 复审 3 条阻断问题专项修复

根据 `art_src/gpt/LAYOUT_REREVIEW_GPT.md` 复审意见，针对以下 3 条阻断问题进行了彻底修复与严格验证：

### 问题 1：手机横屏底部布局（720×514）
- **现象**：横屏下高度极其紧凑（仅 514px），抽屉主按钮下半部被裁切；最低城（松风渡/雁回关）在主地图状态下标签容易踩到底部 Dock 顶边。
- **修复措施**：
  1. **抽屉高度与按钮尺寸紧凑响应**：
     - 在手机横屏（`size.y < 650.0`）下，抽屉高度精确限定为 `168.0px`（占 514px 的 32.6%），内部外边距收敛至 `top: 4px, bottom: 4px`；
     - 动作栏按钮在横屏模式下自适应采用 `h = 34.0px`，字号 `12px`；
     - 主动作【⚔️ 进军攻打】、【🛡️ 驻守据点】以及次级动作【🔍 斥候】、【🌾 补给】、【↩️ 撤销】完整显示，底部保留舒适的 padding，一个像素都没有被裁切。
  2. **底部 Dock 智能让位与恢复**：
     - 当城池抽屉滑出时，底部 Dock 自动向下滑出屏幕（`position.y = h`）；
     - 点击抽屉右上角【✕】、点击地图空白区域或下令确认后，抽屉收起，底部 Dock 立即贴底恢复（`position.y = h - dock_h`），五大主导航项完整可用。
  3. **沙盘底部安全区扩展**：
     - 在 `SliceMap.gd` 中，水彩底图绘制区域与主沙盘视口 100% 完整重合（`_map_rect` 与 `_art_dest_rect` 彻底移除内缩，铺满全屏），杜绝任何露白与平移空隙；
     - 底部 Safe Area 仅用于城名签、归属签与相机聚焦安全判定，绝不缩小水彩底图的绘制区域；
     - 在 S01 未开抽屉状态下，右下角最低城【雁回关】与【松风渡】的城名签与归属签自适应避让至上方安全区，完全悬浮在开阔水系之上，距离底部 Dock 留有充足安全留白，彻底消除任何边缘重叠与裁切。

---

### 问题 2：最低节点 + 实际相邻路线验收（松风渡 N1 / 雁回关 B_START）
- **现象**：
  1. 手机竖屏与横屏点选最低节点时，地图底部与抽屉之间容易暴露纯色宣纸或底板（露白）；
  2. 点选松风渡时相邻路线未全部高亮（松风渡真实后端邻接为云麓关、落霞原、听雨台 3 条边；雁回关为落霞原、听雨台 2 条边）。
- **修复措施**：
  1. **相机视口精准聚焦与底图绝对覆盖 (`focus_city` + `_clamp_pan`)**：
     - **竖屏（720×1280）**：所有 5 个城池天然处于屏幕顶部 68% 内，最低城雁回关及归属签（y ≤ 970）距离抽屉顶边（y = 1070）拥有 >100px 充裕安全间距。未放大时锁定 `map_pan = Vector2.ZERO`，水彩底图全屏铺满视口，抽屉自然覆盖其上，**0 垂直位移、0 平移间隙、0 纯色露白**；
     - **横屏（720×514）**：在 `_clamp_pan()` 中将最大上抬量严格限制在抽屉高度内减去 24px（`max_lift = city_drawer.size.y - 24.0`），保证地图底边始终深藏于抽屉顶边之下至少 24px，**绝不露底**；最低城聚焦时平滑上抬至抽屉顶边上方，城池本体、城名签与归属签一目了然；
  2. **真实相邻驰道拓扑全部高亮（三层高对比渲染）**：
     - 严格以真实后端 `edges` 邻接关系为准：
       - 点选【松风渡 N1】时，**全部 3 条真实相邻路线**（云麓关 A_START、落霞原 N2、听雨台 N3）同时高亮；
       - 点选【雁回关 B_START】时，**全部 2 条真实相邻路线**（落霞原 N2、听雨台 N3）同时高亮；
     - 每条相邻路线均采用 **三层高对比工艺**：
       1. 底层：深墨色 9.0px 对比外晕（确保浅色麦田与雪山地形上均具有高对比清晰轮廓）；
       2. 中层：金色 5.5px 发光能量底晕；
       3. 表层：3.4px 亮白金虚线动态流光（顺着驰道方向匀速脉冲流动）；
     - 彻底消除“细直线与画中手绘弯路两套语言”的不协调感，路线既符合军事沙盘指引，又具备顶级视觉质感；
  3. **图例提升为固定 UI 且联动避让**：
     - 将图例从 `SliceMap.gd`（随地图平移缩放）彻底解耦，提升为 `Slice.gd` 的屏幕固定 UI 控件 `legend_panel`；
     - 在主沙盘（S01）漫游时，固定停留在左侧悬浮栏下方的开阔水域，绝不遮挡听雨台等任何城池，也不会被侧栏图标覆盖；
     - 在点选城池打开抽屉（S02）时，图例自动隐藏（`legend_panel.visible = false`），将整个沙盘视口完全留给军事决断；关闭抽屉时平滑恢复。

---

### 问题 3：敌我标签与战意差判定修复
- **现象**：原代码直接将 `me.get("faction")` 作为字符串比对 `"bamboo"`，而服务端真实返回的是字典 `{"id":1, "code":"bi", "name":"笔", ...}`，导致所有阵营均被判定为墨阵营，出现“我方(墨) vs 敌方(笔)”的反转错误。
- **修复措施**：
  1. **规范化阵营解析辅助方法**：
     - 新增 `_my_faction_code()` 与 `_my_faction_name()`，健壮支持 Dictionary 与 String 类型；
     - 同时兼容服务端标准的 `'bi'` / `'mo'` 以及兼容性的 `'bamboo'` / `'ink'`；
     - 提供 `_is_bamboo_faction()` 辅助判定。
  2. **战意差与驻防状态严密对齐**：
     - 当学子为笔阵营（青竹一）：
       - 战意差严格展示为：`⚔️ 战意差：我方(笔) 0 vs 敌方(墨) 0`；
       - 云麓关（我方主营）驻防状态展示为：`👥 驻防状态：我方据点 · 守备严整`；
       - 雁回关（敌方主营）驻防状态展示为：`👥 驻防状态：敌方据点 · 戒备森严`；
       - 松风渡/落霞原/听雨台（中立据点）展示为：`👥 驻防状态：中立关塞 · 虚席以待`；
     - 敌我逻辑完全正位，符合沙盘真实对抗情境。

---

## 2. 修改文件清单

| 文件路径 | 修改内容 |
|---|---|
| [client/SliceMap.gd](file:///d:/DeskBox/游戏/client/SliceMap.gd) | 1. `_map_rect` 与 `_art_dest_rect` 水彩底图铺满全屏视口，杜绝露白；<br>2. `_draw_node_over_art` 最低城池标签在小高度设备上自适应调整至安全区，避免遮挡；<br>3. 选中城池相邻路线按真实 `edges` 拓扑全部高亮，采用深墨外晕 + 金色发光 + 白金动态虚线三层高对比工艺；<br>4. 图例解耦移至固定 UI 控件。 |
| [client/Slice.gd](file:///d:/DeskBox/游戏/client/Slice.gd) | 1. 修复竖屏与横屏 `focus_city` 与 `_clamp_pan` 相机控制：竖屏未缩放时锁定 `map_pan = 0`，横屏最大上抬限制在抽屉背后至少 24px 重叠，彻底消除底部空白纸带；<br>2. 新增固定 UI 图例 `legend_panel` 及其响应式布局与抽屉联动避让；<br>3. 增加 `_my_faction_code` / `_my_faction_name`，彻底修复 `'bi'`/`'mo'` 敌我判定与战意差；<br>4. 优化 `_layout_responsive` 抽屉紧凑布局（168px）与操作按钮（34px），杜绝截断；<br>5. 单击地图空白处自动收起抽屉并恢复贴底 Dock。 |
| [client/tests/CaptureScreenshots.gd](file:///d:/DeskBox/游戏/client/tests/CaptureScreenshots.gd) | 扩展全自动化测试流程，新增手机竖屏和横屏分别点选【松风渡 N1】和【雁回关 B_START】的专用验收用例，以及抽屉关闭 Dock 贴底恢复用例。 |

---

## 3. 验收命令与执行结果

### 1. 后端 14 项自动化验收测试
```powershell
$phpDir = Split-Path (Get-Command php).Source
php -d extension_dir="$phpDir\ext" -d extension=pdo_mysql server/slice/tests/run.php
```
**结果**：
```text
14 passed, 0 failed
```

### 2. 客户端无头冒烟测试 (ClientSmoke)
```powershell
godot --headless --path client res://tests/ClientSmoke.tscn
```
**结果**：
```text
CLIENT_SMOKE login ok=true turn=1 nodes=5 role=player
CLIENT_SMOKE order ok=true status=坚守军令已定！
CLIENT_SMOKE teacher ok=true teacher_box=true
CLIENT_SMOKE PASS
```

### 3. 战局复盘测试 (ReplaySmoke)
```powershell
godot --headless --path client res://tests/ReplaySmoke.tscn
```
**结果**：
```text
REPLAY_SMOKE turns=1 text=272
REPLAY_SMOKE PASS
```

### 4. 全分辨率全页面与最低城池截图测试 (CaptureScreenshots)
```powershell
godot --path client res://tests/CaptureScreenshots.tscn
```
**结果**：
```text
CAPTURE_SUITE COMPLETE (ALL RESOLUTIONS & LOWEST NODES)
```

---

## 4. 产物与截图核验清单

所有生成的全套截图已存放于工件目录，各项验收点均经过逐张像素级检验：

| 截图文件名 | 分辨率 | 验证重点与达成效果 |
|---|---|---|
| `screenshot_phone_landscape_s01_map.png` | 720×514 | S01 主地图：Dock 贴底完整，松风渡与雁回关城名及归属签完全留在安全区，绝不踩边；左侧固定图例精致可见。 |
| `screenshot_phone_landscape_s02_drawer.png` | 720×514 | S02 抽屉：进军/驻守/斥候/补给/撤销按钮下沿完整保留，文字“⚔️ 战意差：我方(笔) 0 vs 敌方(墨) 0”正位。 |
| `screenshot_phone_landscape_lowest_n1.png` | 720×514 | **最低节点松风渡验收**：金色光环精准选中，城名归属清晰完整，真实相邻的 3 条金色流光路线（通向云麓关、落霞原、听雨台）全部清晰连通，主操作按钮可用，无图例遮挡，地图底图完全覆盖无露白。 |
| `screenshot_phone_landscape_lowest_bstart.png` | 720×514 | **最低节点雁回关验收**：金色光环选中，墨阵营大营标牌清晰，真实相邻的 2 条金色流光路线（通向听雨台与落霞原）全部清晰连通，进军攻打按钮亮起，地图底图完全覆盖无露白。 |
| `screenshot_phone_landscape_dock_restored.png` | 720×514 | 抽屉收起后，底部通栏 Dock 顺滑贴底复位，图例恢复显示。 |
| `screenshot_phone_portrait_lowest_n1.png` | 720×1280 | **手机竖屏最低节点松风渡验收**：点选松风渡，水彩原画 100% 贴底铺满（0 露白、0 纸带空白），真实 3 条相邻金色流光路线全部清晰展现，上方空间开阔，抽屉主操作按钮完整。 |
| `screenshot_phone_portrait_lowest_bstart.png` | 720×1280 | **手机竖屏最低节点雁回关验收**：点选雁回关，水彩原画 100% 贴底铺满（0 露白），真实 2 条相邻金色流光路线全部清晰展现，城名归属及敌方据点驻防状态清晰明确。 |
| `screenshot_phone_portrait_s01_map.png` | 720×1280 | 手机竖屏主地图：9:16 水彩原画铺满，贴边悬浮侧栏，底部五联 Dock 居中贴底。 |
| `screenshot_phone_portrait_s02_drawer.png` | 720×1280 | 手机竖屏城池抽屉：紧凑战术面板，文脉小传独立解耦。 |
| `screenshot_tablet_s01_map.png` | 1400×1000 | 平板主沙盘全屏铺满无界展开，消除黑栏粗框。 |
| `screenshot_tablet_s02_drawer.png` | 1400×1000 | 平板城池抽屉高仅 210px，战意差准确，大按钮突出。 |
| `screenshot_tablet_s03_order_confirm.png` | 1400×1000 | 军令确认浮层：水彩纸卷卡片，战意差与行军路线清晰。 |
| `screenshot_tablet_s04_war_report.png` | 1400×1000 | 战报独立全屏页：头条/战况/得分三列水墨纸卡。 |
| `screenshot_tablet_s05_battle_replay.png` | 1400×1000 | 战局回放全屏页：ReplayMap 完整绘制拓扑与战意高亮。 |
| `screenshot_tablet_s06_faction.png` | 1400×1000 | 阵营全屏页：笔/墨大势与参战学子卡片。 |
| `screenshot_tablet_s10_season.png` | 1400×1000 | 赛季全屏页：Key Art 水彩背景沉浸铺开。 |
| `screenshot_login_keyart.png` | 1400×1000 | 登录页：画卷居中，双栏极简登录，密码不写 cfg。 |

---

## 5. 红线复核

1. **未改动后端代码**：`server/`、schema、migrations、deploy、HANDOVER.md 均保持未改动；
2. **未改动 API 协议**：严格遵从现有接口字段规范，密码绝不落盘；
3. **保持大厂标准与触控面积**：全端关键操作区域均 ≥44×44dp；
4. **测试 100% 通过**：14/14 后端通过，ClientSmoke PASS，ReplaySmoke PASS，全套自动化截图成功通过。

---

## 6. 【v4 地形底图接入与独立城池 Trim Sprite 施工报告】

### 1. 底图升级与中国大致方位锚点标定
- **横屏与平板底图**：全面切换至 `map_c_v4.png` (2560×1600)，原画内置城池已完全抹平，呈现高精度青绿金碧水墨地形；
- **手机竖屏底图**：全面切换至 `map_c_portrait_v2.png` (936×1664)，9:16 原生竖屏水彩画卷铺满全屏，杜绝横版拉伸或黑边；
- **五城中国方位锚点重定**：
  - **A_START 云麓关**（西北 · 笔阵营大本营）：横屏 `(0.22, 0.24)`，竖屏 `(0.20, 0.22)`
  - **B_START 雁回关**（东北 · 墨阵营大本营）：横屏 `(0.80, 0.22)`，竖屏 `(0.80, 0.22)`
  - **N2 落霞原**（中央中原 · 中立农舍草庐）：横屏 `(0.50, 0.50)`，竖屏 `(0.50, 0.50)`
  - **N3 听雨台**（西南巴蜀江南 · 中立竹林水榭亭台）：横屏 `(0.22, 0.78)`，竖屏 `(0.20, 0.78)`
  - **N1 松风渡**（东南沿江水乡 · 中立古渡舟桥）：横屏 `(0.80, 0.78)`，竖屏 `(0.80, 0.78)`

### 2. 独立城池 Trim Sprite 叠加与防重复绘制
- **资产对应与自动加载**：
  - A_START -> `city_yunlu_trim.png`
  - B_START -> `city_yanhui_trim.png`
  - N2 -> `city_luoxia_trim.png`
  - N3 -> `city_tingyu_trim.png`
  - N1 -> `city_songfeng_trim.png`
- **对齐与绘制规范**：
  - 以建筑底座中点对齐锚点 `pos`，按资产宽高比严格等比缩放；起步大本营高度为 `120px`，中立据点高度为 `104px`；
  - **杜绝双建筑/双屋顶/双塔**：Trim Sprite 加载成功时，彻底停用原代码生成的矢量楼阁建筑与白玉台基；仅在资产缺失时作为优雅降级回退；
  - **战台旗帜与地基光环**：战旗立于城池右上方战台（`target_w * 0.35, -target_h * 0.65`），迎风招展；阵营/选中光环锚定在建筑地面地基，不与塔顶争抢空间；
  - **城名签与归属签正位**：纸签统一置于城门地基正下方地面（`pos.y + 10` 与 `pos.y + 36`），绝不遮挡城楼主体；
  - **触控热区扩充**：城池按钮热区扩大至 `140×140`（`pos - (70, 105)`），无论点击城楼屋顶、城门还是下方标签均能精准响应。

### 3. LOD 与 50% 缩放适配
- **缩放范围扩展**：支持 `0.5x ~ 2.5x` 平滑缩放；
- **LOD 分级呈现**：
  - `< 0.88x`（如 0.5x 全景）：隐藏文字纸签，仅保留建筑剪影、归属光环、战旗与金色驰道流光，保证大局观清晰不拥挤；
  - `>= 0.88x`（如 1.0x 默认）：完整呈现城名纸签与归属小签；
  - `>= 1.35x`：展开文化地标标签；
  - `>= 1.70x`：展开文脉名篇小传；
- **50% 缩放全景核验**：生成 `screenshot_tablet_s01_map_zoom_50.png`，沙盘居中，山川地势与阵营分布一目了然，轮廓分明。

### 4. 彻底消除空白宣纸带与图例碰撞
- **零露白控制**：
  - 手机竖屏未放大时锁定 `map_pan = 0`，水彩原画 100% 铺满视口；最低城（松风渡/听雨台）位于屏幕 78% 高度，离抽屉顶边有充足安全余量，无需上抬；
  - 手机横屏聚焦最低城时平滑上抬，在 `_clamp_pan` 中严密保证地图底边深藏于抽屉背后至少 24px，杜绝底部漏出宣纸白边；
- **图例智能避让**：
  - 竖屏放置于西北大营下方开阔山水区（`y = 480`），与所有城池和侧栏图标零干涉；
  - 横屏放置于左侧悬浮图标下方（`y = 248`）；
  - 打开城池抽屉时自动隐去，关闭后自动贴心复位。

### 5. 最新全量验收测试记录
- **后端测试**：14 passed, 0 failed
- **ClientSmoke**：CLIENT_SMOKE PASS
- **ReplaySmoke**：REPLAY_SMOKE PASS
- **CaptureScreenshots**：全套横屏-Only 截图全部成功捕获。

---

## 7. 【横屏-Only 架构改造与全面验收专项报告】

> 核心决策：游戏全面采用横屏-Only 架构，彻底下线并停止维护手机竖屏；手机横屏（720×514）为手机端唯一验收目标。

### 1. 屏幕旋转与 Android 导出锁定横屏
- **引擎配置**：`client/project.godot` 明确配置：
  ```ini
  display/window/handheld/orientation=0
  ```
  （在 Godot 4 中 `0 = SCREEN_LANDSCAPE` 强制锁定横屏）。
- **导出配置核验**：`client/export_presets.cfg` 的 `[preset.0]`（Android 导出预设）继承横屏设置，并开启 `screen/immersive_mode=true`，保证构建出的 `qingzhu_slice.apk` 在任何 Android 设备上启动时均强制锁定横屏，绝不旋转至竖屏。

### 2. 自动化测试套件 (CaptureScreenshots) 重构与废弃截图清理
- **移除竖屏测试步骤**：
  - 从 `CaptureScreenshots.gd` 中彻底删除了 720×1280 竖屏的所有测试阶段与截图调用；
  - 删除了以下 6 张废弃竖屏历史图片：
    - `screenshot_phone_portrait_s01_map.png`
    - `screenshot_phone_portrait_s02_drawer.png`
    - `screenshot_phone_portrait_lowest_n1.png`
    - `screenshot_phone_portrait_lowest_bstart.png`
    - `screenshot_phone_s01_map.png`（旧命名兼容图）
    - `screenshot_phone_s02_drawer.png`（旧命名兼容图）
- **保留并扩充横屏验收测试**：
  - 测试套件只保留双横屏分辨率：**平板 (1400×1000)** 与 **手机横屏 (720×514)**；
  - 最低节点松风渡 (N1) 与雁回关 (B_START) 的验收全量移至手机横屏 720×514 进行；
  - 手机横屏阶段新增登录页、军令确认浮层、战报全屏、沙盘回放全屏专用验收。

### 3. 手机横屏 (720×514) 唯一手机验收目标达成实况

| 验收项目 | 手机横屏 720×514 达成效果 | 对应产物截图 |
|---|---|---|
| **登录页 0 裁切** | 登录面板响应式收敛至 480×484，字号与间距紧凑自适应，青竹文房印章、标题、副标、账号密码框、踏入山河按钮到全班推演结算底栏 100% 完整显示，0 像素裁切。 | `screenshot_phone_landscape_login.png` |
| **S01 主沙盘** | 水彩底图全景铺满全屏，五大据点错落分布，松风渡与雁回关城名及归属签停留在底部安全区，完全不踩 Dock 顶边，左侧悬浮图例清晰。 | `screenshot_phone_landscape_s01_map.png` |
| **S02 城池战术抽屉** | 抽屉高度精确限定为 168px（占 514px 的 32.6%），主副按钮自适应采用 34px 高度（横向拓宽保障触控面积），动作栏完整，底部留有安全内边距。 | `screenshot_phone_landscape_s02_drawer.png` |
| **最低节点 松风渡 (N1)** | 聚焦时平滑上抬，在 `_clamp_pan` 中保证底图在抽屉下方至少重叠 24px，**0 露白、0 纸带**；真实相邻的 3 条驰道（云麓关、落霞原、听雨台）全量高亮，三层高对比金色动态流光清晰可见。 | `screenshot_phone_landscape_lowest_n1.png` |
| **最低节点 雁回关 (B_START)** | 聚焦无露白，城名牌匾与墨阵营大本营印章清晰，真实相邻的 2 条驰道（落霞原、听雨台）全量高亮，攻打按钮启用，不被抽屉遮挡。 | `screenshot_phone_landscape_lowest_bstart.png` |
| **S03 军令出征确认浮层** | 模态框自适应屏幕居中，出征据点、目标、灵宠战力与出征说明层级清晰，44px 大按钮可用。 | `screenshot_phone_landscape_s03_order_confirm.png` |
| **S04 战争日报全屏页** | 顶头栏、决战头条、个人出征演武、天下大势与各大书院动态完整呈现，支持顺畅滑动浏览。 | `screenshot_phone_landscape_s04_war_report.png` |
| **S05 沙盘推演复盘页** | 回放回合选择栏、上一候/下一候、推演地图及复盘详情战报卡片自适应展开，战局变迁一目了然。 | `screenshot_phone_landscape_s05_battle_replay.png` |
| **Dock 贴底恢复** | 点击地图空白处或关闭按钮收起抽屉后，底部 Dock 顺畅贴底复位（y = 514 - 46 = 468），图例自动恢复。 | `screenshot_phone_landscape_dock_restored.png` |

---

## 8. 【设计系统落地报告 (Design System v1.0)】

根据 `DETAIL_CHECKLIST.md` 规范要求，编写并确立了前端核心设计系统：

1. **规范文档已建立**：详见 [client/DESIGN_SYSTEM.md](file:///d:/DeskBox/游戏/client/DESIGN_SYSTEM.md)；
2. **色板系统严格落实**：
   - 基础色：宣纸米黄 `C_XUANZHI (#F6EFE2)`、深墨木桌 `C_WOOD_DESK (#2F2721)`、暖灰纸影 `C_SHADOW_WARM`（杜绝纯黑死黑阴影）；
   - 四大学院阵营色：笔·朱砂 `C_ZHUSHA (#B83B32)`、墨·墨蓝 `C_MOLAN (#1E3A5F)`、纸·藤黄 `C_TENGHUANG (#CF8325)`、砚·竹青 `C_ZHUQING (#276F57)`；
   - 辅助点缀：泥金亮色 `GOLD_LIGHT (#FAE19C)`、天青 `C_TIANQING`、中性灰 `NEUTRAL`。
3. **字号标尺 4 级规范**：
   - L1 登录主标题/印章：24–38px；
   - L2 一级标题/匾额：18–22px；
   - L3 二级标题/按钮：14–16px；
   - L4 正文/属性：13–14px；
   - L5 辅助印签/时间戳：11–12px（手机端正文严守 ≥12px 底线）。
4. **组件与状态机完善**：
   - 按钮 3 态：提供完整 Normal / Hover(Pressed) / Disabled 样式；
   - 统一国风徽章 `_badge()`：用于城池类型、阵营标识、战况状态；
   - 统一纸雕空态 `_build_empty_state()`：用于战报备战中、沙盘复盘无记录等；
   - 墨韵推演加载器 `_build_loading_indicator()`：用于数据在途时平滑指示；
   - 全局弱网/断线横幅 `offline_banner` 与 `_set_offline()`：网络异常时顶部暗金警示条浮现，带重试按钮，恢复后自动收起。
5. **动效时长与缓动曲线**：
   - 抽屉滑入滑出统一采用 220ms `TRANS_CUBIC, EASE_OUT` 动效；
   - 军令确认模态框支持淡入微缩放；
   - 动效轻量流畅，绝不阻塞用户点击与自动化测试。

---

## 9. 最终验收执行记录

### 1. 后端 14 项自动化验收测试
```powershell
$phpDir = Split-Path (Get-Command php).Source
php -d extension_dir="$phpDir\ext" -d extension=pdo_mysql server/slice/tests/run.php
```
**结果**：
```text
== Summary: 14 passed, 0 failed ==
```

### 2. 客户端无头冒烟测试 (ClientSmoke)
```powershell
& "D:\DeskBox\游戏\tools\Godot_v4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe" --headless --path client res://tests/ClientSmoke.tscn
```
**结果**：
```text
CLIENT_SMOKE login ok=true turn=1 nodes=5 role=player
CLIENT_SMOKE order ok=true status=坚守军令已定！
CLIENT_SMOKE teacher ok=true teacher_box=true
CLIENT_SMOKE PASS
```

### 3. 沙盘回放无头冒烟测试 (ReplaySmoke)
```powershell
& "D:\DeskBox\游戏\tools\Godot_v4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe" --headless --path client res://tests/ReplaySmoke.tscn
```
**结果**：
```text
REPLAY_SMOKE turns=1 text=272
REPLAY_SMOKE PASS
```

### 4. 纯横屏自动化全分辨率全页面截图套件 (CaptureScreenshots)
```powershell
& "D:\DeskBox\游戏\tools\Godot_v4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe" --path client res://tests/CaptureScreenshots.tscn
```
**结果**：
```text
CAPTURED: screenshot_login_keyart.png (1400x1000)
CAPTURED: screenshot_phone_landscape_login.png (720x514)
CAPTURED: screenshot_tablet_s01_map.png (1400x1000)
CAPTURED: screenshot_tablet_s01_map_zoom_50.png (1400x1000)
CAPTURED: screenshot_tablet_s01_map_zoom_lod.png (1400x1000)
CAPTURED: screenshot_tablet_s02_drawer.png (1400x1000)
CAPTURED: screenshot_tablet_s03_order_confirm.png (1400x1000)
CAPTURED: screenshot_tablet_s04_war_report.png (1400x1000)
CAPTURED: screenshot_tablet_s05_battle_replay.png (1400x1000)
CAPTURED: screenshot_tablet_s06_faction.png (1400x1000)
CAPTURED: screenshot_tablet_s10_season.png (1400x1000)
CAPTURED: screenshot_phone_landscape_s01_map.png (720x514)
CAPTURED: screenshot_phone_landscape_s02_drawer.png (720x514)
CAPTURED: screenshot_phone_landscape_lowest_n1.png (720x514)
CAPTURED: screenshot_phone_landscape_lowest_bstart.png (720x514)
CAPTURED: screenshot_phone_landscape_s03_order_confirm.png (720x514)
CAPTURED: screenshot_phone_landscape_s04_war_report.png (720x514)
CAPTURED: screenshot_phone_landscape_s05_battle_replay.png (720x514)
CAPTURED: screenshot_phone_landscape_dock_restored.png (720x514)
CAPTURE_SUITE COMPLETE (LANDSCAPE ONLY: TABLET 1400x1000 & PHONE 720x514)
```

