from pathlib import Path

p = Path(r"D:\DeskBox\游戏\DECISIONS.md")
t = p.read_text(encoding="utf-8")

add = """## ADR-025 兵力由宠物战力决定

- 兵力不再用 `1000 + 等级×50`，改为直接由班宠四维/等级/成长计算。
- 基础战力 = `(base_hp + base_atk×2 + base_def×2 + base_spd) / 2`
- 等级战力 = 基础战力 × `(1 + 0.05×(level-1))` × `growth_rate`
- 装备战力 = Σ 技能 `power_val` + Σ 已装备法宝 `power_val`
- 总兵力 = 等级战力 + 装备战力；3 支队伍平分，每队 = 总兵力 / 3。
- 兵种只修正攻防/射程/攻墙，不改兵力：步（防高）、骑（快）、弓（远程）、器（攻墙、正面弱）。
- 原型用 1 将 + 3 队：班宠是将军，不上场；3 张将令是 3 支队伍。
- 正式版升级为 3 将 + 3 队：攻方贡献前 3、守方驻守前 3。
- 第一版模拟：小青竹 10 级战力 1088，每队 362，城墙 2400，攻方胜率 49.8%。
- 待调：器兵偏弱（35.5%）、多数战斗打到 60 tick 时限。
- 详见 `ARMY_MODEL.md`、`server/slice/tools/battle_sim.php`。

"""
if "## ADR-025 兵力由宠物战力决定" not in t:
    t = t.rstrip() + "\n\n" + add
p.write_text(t, encoding="utf-8")
print("ADR-025 added")
