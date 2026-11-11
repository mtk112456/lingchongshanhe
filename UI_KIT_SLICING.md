# UI Kit 切片报告 · `ui_kit_c.png` → 8 个独立 PNG

> 生成：2026-11-11 · 只新增 `client/assets/art/` 8 个 PNG 与 `scratch/` 产物，**未改任何 `.gd`、未运行 Godot、未 commit/push**。
> 源图：`art_src/gpt/assets_c/ui_kit_c.png`（1586×992，2.84 MB）
> 预览：**`scratch/ui_kit_sliced_preview.png`**（1240×1180，含源区域标注 / 1:1 原图 / 九宫格拉伸实测 / 4× 边缘）

---

## 0. 结论

| 文件 | 尺寸 | 体积 | 建议 9-patch margin | 源区域（左,上,右,下） | 状态 |
|---|---:|---:|---:|---|---|
| `ui_panel_card.png` | 256×256 | 105.5 KB | **32** | `(70,36)-(768,948)` → 裁出 680×895 | 新增 |
| `ui_button_primary.png` | 192×40 | 15.1 KB | **16** | `(848,52)-(1474,234)` → 614×168 | 新增 |
| `ui_button_secondary.png` | 192×40 | 16.1 KB | **16** | `(851,252)-(1466,414)` → 599×144 | 新增 |
| `ui_button_confirm.png` | 192×40 | 12.8 KB | **16** | 同 primary（色相重映射） | 新增（派生） |
| `ui_resource_grain.png` | 128×128 | 19.6 KB | — | `(822,430)-(1128,690)` | 新增（可选） |
| `ui_resource_wood.png` | 128×128 | 16.2 KB | — | `(1172,439)-(1474,667)` | 新增（可选） |
| `ui_resource_iron.png` | 128×128 | 14.5 KB | — | `(832,703)-(1114,909)` | 新增（可选） |
| `ui_resource_jade.png` | 128×128 | 22.0 KB | — | `(1194,679)-(1438,920)` | 新增（可选） |

全部 RGBA、透明底、四角 flood fill 去木纹、边缘 2px 色度 matting。
**目标路径原本不存在同名文件，没有覆盖任何人已有的资产。**

### 三个必须知道的结论

1. **面板 margin = 32**（角花占到 28px）。`Slice.gd:467-470` 当前已经是 32，与本次交付一致；若回退到 16，角花会被切成两半、沿边拉出横条（对比图 `scratch/t_panel_m16_vs_m32.png`）。
2. **按钮交付 192×40 而不是 192×72**。源按钮端头是「阶梯」造型，深度恒等于高度的 **38.9%**；九宫格要求 margin ≥ 阶梯深度，运行时又要求 2×margin ≤ 按钮高度。代码里按钮高度是 **32–52px**（`Slice.gd` 的 `_button(..., height)` 调用点实测），所以纹理高度上限 41px。72px 纹理在 42px 按钮上会上下角块重叠、端头破形（见预览第 ⑤ 块）。
3. **按钮 margin = 16**（阶梯深 15.6px）。`Slice.gd:505-515` 当前已经是 16；若回退到 12，端头会出现小尖角（对比图 `scratch/t_btn_margin12_vs16.png`）。

---

## 1. 怎么切的

| 步骤 | 做法 |
|---|---|
| 去木纹 | 逐像素判「木纹」= 明度 `L < 132`（实测木桌 L≤83、宣纸 L≥204，中间有 120 的安全带），从四角与四边 flood fill，只吃连通区，不碰被纸包住的深色（角花、按钮暗红内圈） |
| 边缘 | 边界 2px 做 matting：用 7×7 邻域估局部前景色/背景色，按投影求 alpha，再反预乘去掉木色描边 |
| 缩放 | 全部走「预乘 alpha + LANCZOS 重采样」，避免半透明边出现黑边 |
| 面板整容 | 拼图里 3 个内嵌卡框（`x114-721`、`y157-820` 三条圆角框）是排版示意，用「镜像填充」抹掉，保证中心区可安全拉伸 |
| 面板造型 | 按 9 宫格重排：四角/四边按源比例落在 32px 内，只有中心压缩（宣纸均匀，肉眼看不出） |
| 暖金边 | alpha 轮廓内侧 2px 向 `#c9a227` 混 30%，落在 margin 区，不污染可拉伸区 |
| 按钮 | 原图等比缩放（40px 版本无需去中间料；72px 母版才需要去掉中间 166/215px 并做 12px 交叉淡化） |

**为什么面板中心必须干净**：`_panel_style` 用 `StyleBoxTexture`，中心九宫格会被拉伸到任意尺寸；只要中心有 1 条线，就会被拉成一条横贯面板的带子。

---

## 2. 逐项说明

### 2.1 `ui_panel_card.png` — 宣纸面板

- 源：整张宣纸（含四角「回」字角花、撕边、内嵌 3 个卡框）
- 处理：去木纹 → 抹掉 3 个卡框 → 九宫格重排到 256×256 → 中心再补一次残留 → 暖金边
- 结果：撕边完整、四角角花完整、中心是干净宣纸，透明底
- **建议 margin 32**：角花外接框实测 6.8–27.8px，32 留 4px 余量；撕边振幅约 7px 也在 margin 内

> 3 个内嵌卡框没有单独导出：代码里没有对应插槽，且它们只是同一张宣纸上的排版示意。需要的话可以再切一套「卡片框」资产。

### 2.2 三个按钮

| 文件 | 来源 | 说明 |
|---|---|---|
| `ui_button_primary.png` | 朱砂红按钮 | 原样，未改色 |
| `ui_button_secondary.png` | 墨蓝按钮 | 原样，未改色 |
| `ui_button_confirm.png` | **朱砂红按钮 → 色相重映射** | 拼图里**没有**竹青/绿色按钮 |

**关于 confirm 为什么是绿的**：`Slice.gd:498` 把 `C_ZHUQING(#276f57)` / `BAMBOO` 映射到 `btn_confirm`，所以确认键在语义上就该是竹青。做法是把朱砂像素的色相重映射到 158°、饱和 ×0.8、明度 ×0.62（奶油边与金线不动）。实际色值：均值 `#2a8a69`，暗部 `#268663`、亮部 `#359f78` 一类的自然水彩层次。

> 如果就是要「红/金」确认键：`scratch/ui_kit_72px/ui_button_confirm_redgold_72px.png`（72px 版）已有；40px 版把 `scratch/ui_kit_build.py` 里 `build_button("button_red", "ui_button_confirm.png", ..., hue=158.0)` 的 `hue` 去掉重跑即可。

**尺寸取舍（重要）**：见第 4 节。

### 2.3 四个资源图标（可选件）

粮 / 木 / 铁 / 玉，贴纸描边自带奶油轮廓，切得很干净，正方形居中、主体占 80%，128×128。

⚠️ **代码里没有插槽**：HUD 现在用纯文字资源条（`Slice.gd` 的 `_create_res_pill`），这四个图**放进去也不会显示**，需要先接线。所以它们是「备好等接线」，不是「已接入」。

---

## 3. 代码侧 margin 现状（本次未改代码，只核对）

> 说明：写这份报告期间，另一 Agent 已在并行改 `client/Slice.gd`（工作区未提交），下面这些数字**当前已经生效**，与本批切片对得上。

| 位置 | 当前值 | 与切片是否匹配 |
|---|---|---|
| `Slice.gd:467-470` 面板 `texture_margin_*` | **32** | ✅ 匹配面板角花 28px |
| `Slice.gd:505-508` 按钮 normal `texture_margin_*` | **16** | ✅ 匹配阶梯 15.6px |
| `Slice.gd:512-515` 按钮 disabled `texture_margin_*` | **16** | ✅ |
| 面板 `content_margin_*`（`:471-474`） | `pad`（12） | ✅ 不受影响 |

若你在别的分支上看到旧值（面板 16 / 按钮 12），照上表改即可：面板 16 → **32**，按钮 12 → **16**。

### 3.1 仍需补的两处（不改会露馅）

**(a) hover / pressed 没有贴图样式** → 鼠标一悬停就退回 Godot 默认灰按钮。
贴图分支只覆盖了 `normal` 和 `disabled`，`hover` / `pressed` 会落到默认主题。建议照 `sd` 的写法补：

```gdscript
var sh := s.duplicate() as StyleBoxTexture
sh.modulate_color = Color(1.10, 1.10, 1.10)
b.add_theme_stylebox_override("hover", sh)
var sp := s.duplicate() as StyleBoxTexture
sp.modulate_color = Color(0.86, 0.86, 0.86)
b.add_theme_stylebox_override("pressed", sp)
```

**(b) `content_margin` 是 -1 时会拿 texture_margin 当内容边距** → 按钮最小高度 = 文字高(~21) + 2×margin。
margin 16 时最小高度约 **53px**，会顶破现在 32–52px 的行高。贴图分支里补一行即可：

```gdscript
s.content_margin_left = 0
s.content_margin_top = 0
s.content_margin_right = 0
s.content_margin_bottom = 0   # sd 同样
```

> `Slice.gd:462-476` 的面板分支已经显式设了 content_margin，所以面板没有这个问题。

---

## 4. 为什么按钮是 192×40 / margin 16（而不是 192×72 / 24）

源按钮端头是「阶梯」造型（匾额式），在 192×72 的成品上实测：

```text
阶梯深度 = 28px = 纹理高度的 38.9%
九宫格要求：margin ≥ 28      （否则阶梯被切进可拉伸区）
运行时要求：2 × margin ≤ 按钮高度
```

`Slice.gd` 里 `_button(...)` 的高度实参：`32, 34, 36, 38, 40, 42, 44, 46, 48, 52`（最大 52）。
两式联立 → 纹理高度 ≤ 41px。所以：

| 方案 | 42px 按钮上的结果 | 结论 |
|---|---|---|
| 192×72 + margin 30 | 上下角块重叠 18px，端头错位「破形」 | ✗ |
| 192×72 + margin 24 | 同上（重叠 6px + 阶梯被切） | ✗ |
| 192×40 + margin 16 | 阶梯完整、无重叠 | ✓ |

**72px 母版仍然生成了**，放在 `scratch/ui_kit_72px/`（3 个配色 + 红/金 confirm）。
将来若把 UI 整体放大到按钮 ≥60px 高，直接换母版并把 margin 改成 30 即可。

> 证据图：`scratch/t_btn_corner5x.png`（左端 5×）、`scratch/t_corner_compare.png`（6 种组合）、`scratch/t_btn_delivered_sizes.png`（32/36/38/42/48/52px 实测）、`scratch/t_panel_m16_vs_m32.png`（面板 margin）。

---

## 5. 没切的 / 没做的，以及原因

| 项 | 原因 |
|---|---|
| 竹青 confirm 原图 | 拼图里没有；只能由朱砂重映射（见 2.2） |
| 面板内 3 个卡框 | 排版示意，已抹除；代码无插槽，未单独导出 |
| 木桌底纹 / 外框 / 整张拼图 | 展示背景，不该进包（2.84 MB） |
| `ui_report_banner` / `ui_replay_frame` / `icon_order_*` | 这张拼图里没有，属于**未交付**，不是切漏 |
| 资源图标接线 | 四个图标只是备件；HUD 目前纯文字，需另开接线任务 |
| 按下/悬停/禁用三态贴图 | 由代码 `modulate_color` 派生，不另出图（见 3.1a） |

---

## 6. 自检数据（`python scratch/ui_kit_verify.py`）

| 文件 | 尺寸 | 半透明边像素 | 边缘平均亮度 | 半透明且发深褐（木纹残留） | 中心区梯度 |
|---|---:|---:|---:|---:|---:|
| ui_panel_card | 256×256 | 1042 | 238.4 | **0** | 4.92 |
| ui_button_primary | 192×40 | 424 | 253.5 | **0** | 9.90 |
| ui_button_secondary | 192×40 | 425 | 253.8 | **0** | 12.43 |
| ui_button_confirm | 192×40 | 424 | 253.5 | **0** | 5.64 |
| ui_resource_grain | 128×128 | 473 | 252.4 | **0** | — |
| ui_resource_wood | 128×128 | 300 | 252.7 | **0** | — |
| ui_resource_iron | 128×128 | 242 | 252.9 | **0** | — |
| ui_resource_jade | 128×128 | 377 | 248.4 | **0** | — |

- 「深褐残留 = 0」= alpha 边缘里没有任何「深色 + 偏红」像素，木纹/投影没有留在描边上。
- 边缘平均亮度 248–254 说明半透明像素都是奶油/宣纸色，不是深色描边。
- 四边最外 1 行 alpha 最大 43–71、第 2 行就回到 255 → 有 1px 透明余量，没有切掉纸边。
- 面板中心梯度 4.92（< 10）说明可拉伸区是平的，拉伸不会出现纹理拉丝。

---

## 7. 仓库状态提醒（不影响交付）

- `client/assets/art/ui_kit_c.png` 在本次任务中途被**其他 Agent** 按 `ASSET_INTEGRATION.md §3.4`「建议清出 client」执行了删除（`git status` 显示 `D`）。本次改读 `art_src/gpt/assets_c/ui_kit_c.png`；两者 git blob 相同（`3629448dd3b5e900a6f12e5a15ae38dbd1a98185`），重切结果与原路径逐字节一致（已用 MD5 复核）。
- 期间另一 Agent 连续提交（`c066f90` → `5dfda02` → `1178920`），其中 `1178920` 已经把这批 **192×40** 的按钮与面板/图标一并提交，所以 `git status` 里 `client/assets/art` 现在是干净的。`UI_KIT_SLICING.md` 与 `scratch/` 仍是我这边新增的未跟踪文件。
- `Slice.gd` 里 margin 32 / 16 是**其他 Agent 的并行改动**（工作区未提交），不是我改的；本文只负责让切片与这两个数字对上。
- `ui_panel_card.png.import` / `ui_button_*.png.import` 等是本机引擎/编辑器在我写文件后自动生成的，不是我写的，也不影响 PNG 内容。

---

## 8. 复现

```powershell
cd D:\DeskBox\游戏
python scratch\ui_kit_build.py      # 重切 8 个 PNG + 72px 母版
python scratch\ui_kit_preview.py    # 重出预览
python scratch\ui_kit_verify.py     # 自检表
```

脚本入口：`scratch/ui_kit_build.py`（尺寸/margin 都是文件顶部常量），像素库：`scratch/ui_kit_lib.py`。

---

## 9. 交付格式

```text
改了什么：从 ui_kit_c.png 切出面板/三按钮/四资源图标，透明化并给出九宫格 margin
改了哪些文件：新增 client/assets/art/{ui_panel_card,ui_button_primary,ui_button_secondary,
             ui_button_confirm,ui_resource_grain,ui_resource_wood,ui_resource_iron,ui_resource_jade}.png
             + UI_KIT_SLICING.md + scratch/*（预览、72px 母版、脚本、证据图）
跑了什么验收：python scratch/ui_kit_build.py / ui_kit_preview.py / ui_kit_verify.py（纯 PIL，未跑 Godot）
结果：8/8 生成；alpha 边缘木纹残留 0；面板/按钮九宫格拉伸实测无破图
截图/产物：scratch/ui_kit_sliced_preview.png（主预览）
没做/阻塞：未改代码（面板 32 / 按钮 16 的 margin 已由并行改动就位，与切片一致）；
             hover/pressed 仍未覆盖；content_margin 未归零（按钮最小高度会涨到 ~53px）；
             资源图标无插槽未接线；confirm 绿色系派生非原图
```
