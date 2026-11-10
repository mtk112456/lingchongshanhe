from pathlib import Path

root = Path(r"D:\DeskBox\游戏")

# AGENTS.md: update Antigravity role and add design ownership note.
a = root / "AGENTS.md"
t = a.read_text(encoding="utf-8")
t = t.replace(
    "| **Antigravity** | Godot 前端、地图/回放/平板可读性、界面整合、截图 | 不改后端/schema |",
    "| **Antigravity** | Godot 前端、**设计系统/页面视觉/组件规范/动效**、地图/回放/平板可读性、界面整合、截图 | 不改后端/schema |"
)
marker = "### 设计权"
section = """### 设计权

- **Antigravity**：设计主责。页面布局、视觉层级、组件规范、设计系统、动效、可读性由它主导。
- **GPT**：美术资产主责。概念图、地形、城池、UI Kit、图标、班宠、卡面。
- **OpenCode**：技术主责。只给技术约束、验收红线、性能/体积/兼容性要求，不逐页指定像素和视觉风格。
- **用户**：最终审美拍板。

> 设计问题先由 Antigravity 判断；OpenCode 不越权做视觉决策，只验收“能不能用、能不能读、能不能跑”。

"""
if marker not in t:
    t = t.replace("### 协作链路", section + "### 协作链路", 1)
a.write_text(t, encoding="utf-8")

# DECISIONS.md: ADR-013.
d = root / "DECISIONS.md"
dt = d.read_text(encoding="utf-8")
adr = """## ADR-013 设计权归 Antigravity

- 决定：页面设计、组件规范、视觉层级、设计系统、动效由 Antigravity 主导。
- GPT 负责美术资产；OpenCode 负责技术约束、验收、合并；用户最终审美拍板。
- 原因：前端主责最了解 Godot 约束、多端布局和可读性；避免 OpenCode 越权做视觉决策。
- 影响：OpenCode 只给验收红线（可读性/触控/性能/不抄袭/不缩小字号），不逐页指定像素；Antigravity 对设计结果负责。

"""
if "## ADR-013 设计权归 Antigravity" not in dt:
    dt = dt.rstrip() + "\n\n" + adr
d.write_text(dt, encoding="utf-8")

print("design ownership updated")
