from pathlib import Path

root = Path(r"D:\DeskBox\游戏")

brief = root / "ART_BRIEF_GPT.md"
brief_text = brief.read_text(encoding="utf-8")
brief_section = """

---

## 8. C 原版锁定（2026-11-10）

用户确认：**以 `art_src/gpt/style_c.png` / `keyart_c.png` 的水彩纸雕原版为准**。  
`art_src/gpt/assets_c/` 中第一版 5 城地标偏“贴纸感”：红金圆框、饱和度高、细节过密，放到地图上会盖住原画留白，不作为地图资产。

新规则：

- 地图底图只用 `keyart_c.png` 裁出的 `client/assets/art/map_c.png`；
- 5 城地标重做时必须直接参考 `style_c.png` / `keyart_c.png`：
  - 软水彩边缘、细墨线、低饱和；
  - 不要圆形/红金边框，不要独立徽章底座；
  - 透明背景，建筑完整，底部不留阴影；
  - 单城 512×512，缩到 64px 仍能认出轮廓；
- 手机竖屏需要一张 9:16 的 C 版地图/加载页（5 城纵向排布），单独出图；
- UI Kit 仍按 C 色板，但按钮/面板要干净硬边，不能有水彩毛边。

验收：先看 64px 缩略图是否能认出城，再看 512px 细节。
"""
if "## 8. C 原版锁定" not in brief_text:
    brief.write_text(brief_text.rstrip() + brief_section, encoding="utf-8")

review = root / "art_src" / "gpt" / "REVIEW.md"
review_text = review.read_text(encoding="utf-8")
review_section = """

## 4.2 C 原版与 assets_c 的偏差（2026-11-10）

用户复看后确认：`style_c.png` / `keyart_c.png` 的原版更好看。  
`assets_c` 的 5 城地标偏贴纸感，原因：

- 红金圆框把建筑包成徽章；
- 饱和度高于原画；
- 细节密度过高，64px 下糊成一团；
- 透明背景边缘有低透明度残留。

处理：

- 地图改用 `keyart_c.png` 裁出的 `map_c.png`；
- `assets_c` 地标只保留作参考/抽屉缩略图，不盖地图；
- 下一版按 `style_c.png` 重做，去掉圆框，降低饱和，简化轮廓。
"""
if "## 4.2 C 原版与 assets_c 的偏差" not in review_text:
    review.write_text(review_text.rstrip() + review_section, encoding="utf-8")

print("docs updated")
