from pathlib import Path

p = Path(r"D:\DeskBox\游戏\DECISIONS.md")
t = p.read_text(encoding="utf-8")

add = """## ADR-028 宠物战力只决定兵力，兵种由学生编成

- 班宠战力只决定总兵力；不决定兵种，不限制学生选择。
- 学生每周自选 3 个兵种：骑/盾/弓/枪，可重复；周中可改 1 次。
- 卡牌只提供战术，不再绑定兵种；火攻分配给器械，不占队伍。
- 3 支队伍平分总兵力；可选 6/3/1 分配（最低 10%，最高 60%）。
- 兵源城只给该兵种 +15% 兵力，不是解锁；丢了城就丢加成。
- 将军只给全军光环，不限制兵种；攻将也能带盾，守将也能带骑。
- 不做兵营建造、资源采集、抽兵种、兵种升星、每日招募次数。
- 详见 `RECRUITMENT.md`。

"""
if "## ADR-028 宠物战力只决定兵力" not in t:
    t = t.rstrip() + "\n\n" + add
p.write_text(t, encoding="utf-8")
print("ADR-028 added")
