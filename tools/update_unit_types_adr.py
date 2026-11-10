from pathlib import Path

p = Path(r"D:\DeskBox\游戏\DECISIONS.md")
t = p.read_text(encoding="utf-8")

add = """## ADR-026 4 兵种 + 器械装备

- 兵种只做 4 个：骑 / 盾 / 弓 / 枪。
- 循环：骑 > 盾 > 弓 > 枪 > 骑；克制 ×1.2，被克 ×0.85。
- 器械是攻城装备，不是兵种：不占兵种位、不参与克制、不放进 3 路。
- 器械在阵后攻墙；攻方前排还有任意单位存活时安全，前排全灭则停止攻墙。
- 火攻牌让器械攻墙 +50%。
- 3 路 × 2 排：骑/盾/枪前排，弓后排；前排没死，后排不被近战攻击。
- 第一版模拟（8192 局）：不带器械 29.5% 胜率，带器械 80.7%；骑 65.3%、盾 52.2%、弓 47.7%、枪 55.1%。
- 待调：器械差距过大（51 个百分点），下一步改为“每场都有器械，火攻只加 50%”，再跑 10000 局。
- 取代 ADR-025 中“步/骑/弓/器”的兵种列表。
- 详见 `UNIT_TYPES_REFERENCE.md`、`ARMY_MODEL.md`、`server/slice/tools/battle_sim.php`。

"""
if "## ADR-026 4 兵种 + 器械装备" not in t:
    t = t.rstrip() + "\n\n" + add
p.write_text(t, encoding="utf-8")
print("ADR-026 added")
