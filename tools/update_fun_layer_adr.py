from pathlib import Path

p = Path(r"D:\DeskBox\游戏\DECISIONS.md")
t = p.read_text(encoding="utf-8")
add = """## ADR-019 可玩性补强顺序

- 第一：战报说书/名场面（不改结算，只改呈现）。
- 第二：每日军议事件（10–15 秒二选一；v1 只影响情报/补给上限/断连，不改攻防点数）。
- 第三：班宠组合技（v1 只做战报连携/表情，不加数值；试跑后再评估）。
- 第四：每周锦囊暂缓；若做，固定自选 1 张，不随机。
- 第五：每周军议大会不做实时版；只保留异步目标旗/自动周报。
- Among Us/狼人杀式背叛机制永久禁止。
- 先做战报 + 事件并完成 8–12 人试跑，不先扩 12 城美术。

"""
if "## ADR-019 可玩性补强顺序" not in t:
    t = t.rstrip() + "\n\n" + add
p.write_text(t, encoding="utf-8")
print("fun layer ADR updated")
