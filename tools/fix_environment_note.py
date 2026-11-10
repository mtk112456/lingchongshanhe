from pathlib import Path

p = Path(r"D:\DeskBox\游戏\ENVIRONMENT_SPEC.md")
t = p.read_text(encoding="utf-8")
t = t.replace(
    "- 正式版若使用真实中国地图，必须使用自然资源部标准地图 + 审图号；",
    "- 正式版使用架空九州地图，不画真实轮廓/边界；城池名/地标只作文脉主题；",
)
p.write_text(t, encoding="utf-8")

m = Path(r"D:\DeskBox\游戏\MAP_SPEC.md")
mt = m.read_text(encoding="utf-8")
print("MAP fiction note:", "架空九州地图" in mt)
print("ENV real-map line removed:", "正式版若使用真实中国地图" not in t)
