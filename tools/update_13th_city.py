from pathlib import Path

root = Path(r"D:\DeskBox\游戏")

# MAP_SPEC: add 13th neutral royal city.
m = root / "MAP_SPEC.md"
t = m.read_text(encoding="utf-8")
section = """
### 8.5 第 13 中立王城：问鼎台

- **位置**：全图中心 `(0.50, 0.50)`；
- **性质**：中立王城，不属于四阵营；赛季终极争夺目标；
- **环境**：中原金田中央的高台/祭坛/王城，四面水渠与驰道交汇；
- **资产**：512×512 RGBA，neutral/gold，无文字，64px 可辨；
- **拓扑**：四区各有一条主干道通向问鼎台，王城不与所有城直连，避免路线过密；
- **LOD**：
  - 0.35x：王城大金环 + 旗帜，不显示文字；
  - 0.50x：显示“问鼎台”城名；
  - 1.4x+：显示祭坛/宫殿/台阶细节；
- **赛季规则（待细化）**：赛季结束时占领问鼎台的阵营获胜；无人占领则按王城积分/城池数决胜。

> 12 座阵营城 + 1 座中立王城 = 13 个地图节点。  
> 王城是“问鼎中原”的赛季目标，不是第 5 个阵营。
"""
if "### 8.5 第 13 中立王城" not in t:
    m.write_text(t.rstrip() + section, encoding="utf-8")

# ENVIRONMENT_SPEC: add central royal city.
e = root / "ENVIRONMENT_SPEC.md"
et = e.read_text(encoding="utf-8")
add = """
---

## 7. 第 13 中立王城：问鼎台

| 项 | 内容 |
|---|---|
| 位置 | 全图中心 0.50, 0.50 |
| 环境 | 中原金田中央的高台/祭坛/王城，四面水渠与驰道交汇 |
| 色彩 | 宣纸米黄 + 藤金 + 朱砂点缀，区别于四阵营 |
| 地标 | 祭坛/宫殿/高台/台阶，不做成普通关楼 |
| 识别 | 遮住城名也能看出是“王城/祭坛”，不是普通城池 |
| LOD | 0.35x 大金环+旗帜；0.50x 城名；1.4x+ 祭坛细节 |

王城是赛季争夺目标，不属于四阵营；四区各有一条主干道通向中心，避免全连接造成路线过密。
"""
if "## 7. 第 13 中立王城" not in et:
    e.write_text(et.rstrip() + add, encoding="utf-8")

# DECISIONS: ADR-012.
d = root / "DECISIONS.md"
dt = d.read_text(encoding="utf-8")
adr = """## ADR-012 第 13 中立王城

- 决定：12 座阵营城之外，增加 1 座中立王城“问鼎台”，位于全图中心。
- 性质：中立，不属于四阵营；赛季终极争夺目标。
- 原因：中央金田是天然视觉焦点，空置会像“第 13 城”却无战术承载；加王城可解决构图焦点，并提供赛季胜负目标。
- 拓扑：四区各一条主干道通向王城，不与所有城直连。
- 资产：512×512 RGBA，neutral/gold，无文字；王城用祭坛/高台/宫殿区分普通城池。

"""
if "## ADR-012 第 13 中立王城" not in dt:
    d.write_text(dt.rstrip() + "\n\n" + adr, encoding="utf-8")

print("13th royal city updated")
