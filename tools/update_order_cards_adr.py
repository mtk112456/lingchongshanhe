from pathlib import Path

p = Path(r"D:\DeskBox\游戏\DECISIONS.md")
t = p.read_text(encoding="utf-8")

add = """## ADR-021 三道将令手牌化

- 状态：**取代 ADR-017 中“每人每天 3 个军令点数”的表述**，结算目标不变。
- 每天开局抽 4 张将令，选 3 张打到地图上；手牌当天有效，不囤积。
- 12 张免费固定牌：夜袭/急行/火攻、坚壁/犄角/空城/死守、哨探/反间/疑兵、运粮/断粮。
- 每天 1 次重抽；同一学生同一城同一类最多 1 张；每天最多 1 张进军牌。
- 死守每阵营每赛季限 1 次；其余牌无次数限制。
- 服务端发牌，种子由 HMAC(secret, turn_id:player_id) 生成，刷新不变。
- 规则版本 `cards_v1` 与现有 `v1` 并存；旧 14 项验收继续跑 `v1`。
- 不改：4 阵营、13 城、21:00 同时结算、软上限、班宠被动、民心条。
- 详见 `ORDER_CARDS.md`。

"""
if "## ADR-021 三道将令手牌化" not in t:
    t = t.rstrip() + "\n\n" + add
p.write_text(t, encoding="utf-8")
print("ADR-021 added")
