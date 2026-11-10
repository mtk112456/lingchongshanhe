from pathlib import Path

root = Path(r"D:\DeskBox\游戏")

page = root / "PAGE_DESIGN.md"
text = page.read_text(encoding="utf-8")
marker = "## 0. 2026-11-10 布局复核修正"
section = """## 0. 2026-11-10 布局复核修正（重要）

三方复核结论：当前版本**借的是信息架构，不是视口布局**。

- 真同构：地图常驻、点城底部抽屉、二次确认、独立战报/回放、阵营/赛季入口。
- 不同构：当前平板是“文房案台 Container-First”（左右 140px 深色实心侧栏 + 居中纸卷 + 浮动胶囊 Dock）；率土/三战是“无界沙盘 Camera-First”（地图 100% 铺满 + 贴边半透明 HUD）。
- 因此，不能再说“布局和率土/三战一样”。准确说法：**信息架构参考主流 SLG，视觉是 C 版文房案台。**
- 正在执行 P0：平板地图全屏化、左右入口改悬浮图标、Dock 贴底、保留 2–3px 细纸边。

---

"""
if marker not in text:
    # insert after the intro block (before the first "## 1.")
    text = text.replace("## 1. 参考矩阵", section + "## 1. 参考矩阵", 1)
    page.write_text(text, encoding="utf-8")

decisions = root / "DECISIONS.md"
dtext = decisions.read_text(encoding="utf-8")
adr_marker = "## ADR-009 布局参考边界"
adr = """## ADR-009 布局参考边界

- 决定：参考主流 SLG 的**信息架构**（地图常驻、底部抽屉、二次确认、独立战报/回放），不复制其**视口布局**。
- 当前平板是“文房案台 Container-First”，率土/三战是“无界沙盘 Camera-First”；不能声称“布局一样”。
- P0 改造：平板地图全屏化、左右入口改悬浮图标、Dock 贴底、保留细纸边。
- 原因：三方复核（OpenCode / Antigravity / GPT）一致认为原布局在视口与空间隐喻上不同，过度声称会误导验收。

"""
if adr_marker not in dtext:
    decisions.write_text(dtext.rstrip() + "\n\n" + adr, encoding="utf-8")

print("layout decisions updated")
