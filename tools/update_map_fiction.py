from pathlib import Path

root = Path(r"D:\DeskBox\游戏")

# 1. MAP_SPEC: replace real-map requirement with fictional map decision.
map_spec = root / "MAP_SPEC.md"
text = map_spec.read_text(encoding="utf-8")
old = "> 正式版地图若使用真实中国地图，必须使用自然资源部标准地图 + 审图号；当前原型只做布局。"
new = "> 正式版使用**架空九州地图**，不画真实中国轮廓、不标真实坐标，因此不要求标准地图/审图号。城池名与地标只作为“文脉主题”，不表示真实位置；若后续改用真实地图，再补标准地图 + 审图号。"
if old in text:
    text = text.replace(old, new)
elif "架空九州地图" not in text:
    text = text.replace("---\n\n## 4. 5 节点切片的地标占位", "> 正式版使用**架空九州地图**，不画真实中国轮廓、不标真实坐标，因此不要求标准地图/审图号。城池名与地标只作为“文脉主题”，不表示真实位置。\n\n---\n\n## 4. 5 节点切片的地标占位", 1)
map_spec.write_text(text, encoding="utf-8")

# 2. ENVIRONMENT_SPEC: add fiction note.
env = root / "ENVIRONMENT_SPEC.md"
etext = env.read_text(encoding="utf-8")
marker = "## 2.1 架空九州说明"
section = """## 2.1 架空九州说明

正式版地图是**架空九州**，不是真实中国地图：

- 不画真实海岸线、省界、国界；
- 不标真实经纬度；
- 不需要标准地图/审图号；
- 城池名（长安/洛阳/成都等）与地标（大雁塔/龙门石窟等）只作为“文脉主题”，不表示真实位置；
- 地域环境用“原型”表达：关中黄土、中原平原、巴蜀湿润、江南水乡、塞北关隘、楚地水乡等。

这样既能保留“当地环境特点”，又不会被真实地理绑死。

"""
if marker not in etext:
    etext = etext.replace("## 3. 地形底图出图要求", section + "## 3. 地形底图出图要求", 1)
    env.write_text(etext, encoding="utf-8")

# 3. DECISIONS: add ADR-010.
decisions = root / "DECISIONS.md"
dtext = decisions.read_text(encoding="utf-8")
adr_marker = "## ADR-010 架空九州地图"
adr = """## ADR-010 架空九州地图

- 决定：正式版使用架空九州地图，不使用真实中国地图轮廓/边界/坐标。
- 原因：避免真实地图审图与地理准确性问题；同时保留“地域环境原型”（关中、中原、巴蜀、江南、塞北、楚地等）。
- 城池名与地标只作为文脉主题，不表示真实位置；不要求标准地图/审图号。
- 若后续改用真实地图，再补自然资源部标准地图 + 审图号。

"""
if adr_marker not in dtext:
    decisions.write_text(dtext.rstrip() + "\n\n" + adr, encoding="utf-8")

print("fiction map decisions updated")
