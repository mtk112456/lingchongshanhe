from pathlib import Path

root = Path(r"D:\DeskBox\游戏")

# ADR-014: no gacha / blind box.
d = root / "DECISIONS.md"
t = d.read_text(encoding="utf-8")
adr = """## ADR-014 不做抽卡/盲盒

- 决定：游戏内不做抽卡、不做盲盒、不做概率掉落；商城只做直购外观/便利。
- 现有班级系统的 `shop_blind_box` 仍归班级系统，不接进游戏；游戏不读不写该表。
- 原因：面向 10–15 岁学生，避免赌博机制、概率不透明和班级不公平；积分只换确定的外观/便利。
- 影响：`PAGE_DESIGN.md` / `CITY_DESIGN.md` 中“不抽卡”继续有效；后续任何抽卡需求必须重新评审。

"""
if "## ADR-014 不做抽卡/盲盒" not in t:
    t = t.rstrip() + "\n\n" + adr
d.write_text(t, encoding="utf-8")

# CITY_DESIGN: make the no-gacha rule explicit.
c = root / "CITY_DESIGN.md"
ct = c.read_text(encoding="utf-8")
marker = "## 10. 不要做"
add = """## 9.1 获取方式

- 城池外观、班宠表情/皮肤、头像框、称号、战报印章：**文玉直购**；
- 文脉卡/诗句：通过守城/图鉴/赛季获得，不靠概率；
- 不做抽卡、不做盲盒、不做概率掉落；
- 现有班级系统 `shop_blind_box` 不接进游戏。

"""
if "## 9.1 获取方式" not in ct:
    ct = ct.replace(marker, add + marker, 1)
    c.write_text(ct, encoding="utf-8")

# PAGE_DESIGN: shop direct purchase only.
p = root / "PAGE_DESIGN.md"
pt = p.read_text(encoding="utf-8")
if "商城只做直购" not in pt:
    pt = pt.replace(
        "### 3.10 商店/赛季页",
        "### 3.10 商店/赛季页\n\n> **不做抽卡/盲盒**：商城只做文玉直购外观/便利；现有班级系统盲盒不接进游戏。",
        1
    )
    p.write_text(pt, encoding="utf-8")

print("no-gacha decision updated")
