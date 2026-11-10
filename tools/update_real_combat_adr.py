from pathlib import Path

p = Path(r"D:\DeskBox\游戏\DECISIONS.md")
t = p.read_text(encoding="utf-8")

add = """## ADR-024 实战战斗路线

- 用户选择：先做 21:00 观战动画，同时做异步自动战斗原型。
- 不做实时 PvP；不做单位对撞/血条实时操作。
- 架构：服务端确定性模拟，客户端只回放事件；无随机数，同部署同结果。
- 原型：3 路 × 6 格，攻方 3 单位从 0 出发，守方 3 单位固定 4，城门 5，60 tick。
- 4 个原型：攻/守/谋/运；先跑通再扩到 12 张将令。
- 结果只给 ±2（破门 +2 / 压线 +1 / 被挡 0 / 大败 -1），主力仍是牌 + 补给 + 软上限。
- 跳过 = 同结果，只看不播动画；不能因为跳过吃亏。
- 第一版模拟：4096 组合，攻方 52.3% 胜率，平均 17–26 tick；仍需调“运”和强势组合。
- 参考：部落冲突（异步预设防守）、Super Auto Pets（小队自动战斗）、Backpack Battles（快照）、三国志战略版（战报）、Into the Breach（信息透明）、Frozen Synapse（规划→回放）。
- 详见 `REAL_COMBAT_OPTIONS.md`、`COMBAT_REFERENCES.md`、`server/slice/tools/battle_sim.php`。

"""
if "## ADR-024 实战战斗路线" not in t:
    t = t.rstrip() + "\n\n" + add
p.write_text(t, encoding="utf-8")
print("ADR-024 added")
