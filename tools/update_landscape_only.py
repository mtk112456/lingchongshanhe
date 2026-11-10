from pathlib import Path

root = Path(r"D:\DeskBox\游戏")

# ADR-011
d = root / "DECISIONS.md"
t = d.read_text(encoding="utf-8")
if "## ADR-011 横屏-only" not in t:
    t = t.rstrip() + """

## ADR-011 横屏-only

- 决定：游戏只支持横屏，不维护手机竖屏布局/截图。
- 平台：平板 1400×1000、手机横屏 720×514 为主；Android 锁定 landscape。
- 原因：地图、城池抽屉、战报、回放需要横向空间；竖屏会挤压地图和战报，维护两套布局成本高。
- 影响：`project.godot` 设置 `display/window/handheld/orientation=0`；移除竖屏截图/验收；手机竖屏代码可保留但不验收。
"""
    d.write_text(t, encoding="utf-8")

# Top notes for docs with portrait references.
notes = {
    "PAGE_DESIGN.md": "\n> **2026-11-10 起横屏-only**：手机竖屏布局与截图不再作为验收目标；手机以 720×514 横屏、平板以 1400×1000 横屏为准。\n",
    "SCREEN_SPEC.md": "\n> **2026-11-10 起横屏-only**：文中手机竖屏相关段落作废；手机以 720×514 横屏为准。\n",
    "UI_STRUCTURE.md": "\n> **2026-11-10 起横屏-only**：手机竖屏不再作为验收目标；手机横屏与平板横屏共用一套分层结构。\n",
    "MAP_SPEC.md": "\n> **2026-11-10 起横屏-only**：手机竖屏 9:16 地图不再作为验收目标；手机横屏 720×514 与平板 1400×1000 为准。\n",
}
for name, note in notes.items():
    p = root / name
    if not p.is_file():
        continue
    t = p.read_text(encoding="utf-8")
    if "横屏-only" not in t:
        lines = t.splitlines()
        # insert after the first heading line
        if lines and lines[0].startswith("#"):
            t = lines[0] + "\n" + note + "\n".join(lines[1:])
        else:
            t = note + t
        p.write_text(t, encoding="utf-8")

# Automation doc: replace portrait dimensions.
a = root / "AUTOMATION_ACCEPTANCE.md"
if a.is_file():
    t = a.read_text(encoding="utf-8")
    t = t.replace("平板 1400×1000、手机竖屏 720×1280、手机横屏 720×514", "平板 1400×1000、手机横屏 720×514（仅横屏）")
    t = t.replace("平板 1400×1000、手机竖屏 720×1280、手机横屏 720×514", "平板 1400×1000、手机横屏 720×514")
    t = t.replace("平板/手机竖屏/横屏", "平板/手机横屏")
    a.write_text(t, encoding="utf-8")

# Acceptance: add landscape-only note.
acc = root / "ACCEPTANCE_STANDARD.md"
if acc.is_file():
    t = acc.read_text(encoding="utf-8")
    note = "> **2026-11-10 起横屏-only**：手机竖屏不再作为验收目标；目标机为 Android 手机横屏 + 平板横屏。\n\n"
    if "横屏-only" not in t:
        t = note + t
    t = t.replace("目标 Android 手机 + 平板各 1 台实测", "目标 Android 手机横屏 + 平板横屏各 1 台实测")
    acc.write_text(t, encoding="utf-8")

print("landscape-only docs updated")
