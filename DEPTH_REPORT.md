# 深度层实装报告

> 目标：让 13 城地图和编成真正影响战局，而不是背景板。
> 日期：2026-11-11

---

## D1 邻接扩张（已实装）

```text
只能从己方领土打相邻城
打自己城 = 驻守
```

实测：

```text
5 节点：bi 从 A_START 可打 N1/N2，打 N3 → NOT_ADJACENT
12 城：bi 从凉州可打汉中、跨区太原，打成都 → NOT_ADJACENT
```

接口新增：

```json
"reachable_targets": ["liangzhou", "hanzhong", "xiangyang", "taiyuan"]
```

测试：`ADJACENCY PASS`

---

## D3 区域加成（已实装）

```text
一个阵营控制本区 3 城 → 全军 +5% 兵力
```

区域：

```text
笔：凉州 / 汉中 / 襄阳
墨：邺城 / 太原 / 洛阳
砚：成都 / 江陵 / 长沙
纸：建业 / 会稽 / 寿春
```

测试：

```text
未控全区：region_bonus=false
控全区：region_bonus=true，兵力 913.5 → 959.2
```

测试：`REGION_BONUS PASS`

---

## D4 混编羁绊（已实装）

```text
3 队不同兵种：混编，攻防 +5%
3 队同兵种：专精，攻击 +8%、防御 -8%
2+1：无加成
```

战报会带：

```json
"att_formation": "mixed",
"def_formation": "same"
```

测试：`FORMATION PASS`

---

## D7 城池功能（第一版）

```text
大营：阵营拥有任意大营，进攻 +5% 兵力
关隘：守方拥有任意关隘，守军 +10%
```

战报会带：

```json
"camp_bonus": true,
"pass_bonus": true
```

测试：

```text
大营：913.5 兵
关隘：守军 1452
```

测试：`CITY_BUFF PASS`

---

## D2 迷雾 / 侦察（后端已就绪）

```text
state 返回 scouted_nodes
  本回合打出哨探的城
未侦察城：只显示归属/民心，不显示守军细节
```

测试：

```text
SCOUT_STATE PASS
N2 已侦察 → ["N2"]
reachable_targets → ["A_START","N1","N2"]
```

客户端待接：未侦察敌城不显示守军、已侦察显示 👁。

---

## D5 支援可见（已实装）

战报新增：

```json
"supporters": 1,
"support_mult": 1.224
```

每多 1 人 +2%，上限 +15%，普通学生也能看到自己的支援进了战斗。

测试：`PHASE15_CARDS PASS`

---

## D6 每日邸报（已实装）

```text
每天每个学生从 3 个备选里抽 2 个，二选一
grain 粮草先行：你的队伍兵力 +5%
ram   攻城器械：你的队伍攻城伤害 +25%（3 名先锋可叠到 +75%）
scout 斥候密报：本回合所有敌城守军可见
结算前可改选，按最终选择生效
```

实测：

```text
无邸报：1305.0 兵，siege_mult=1
3 人粮草：1370.2 兵（+5%）
3 人器械：siege_mult=1.75
斥候：1 座敌城全部进入 scouted_nodes
```

测试：`BULLETIN PASS`

---

## D8 赛季史书（后端已实装）

```text
GET /api/slice/season/history
按周聚合：战斗数、易主城、关键战役、周末排名、一句话头条
```

实测（4 回合）：

```text
周 1 记录 4 场战斗
1 城易主：汉中 → 笔
头条：第 1 周：笔 2 城领先，1 城易主
```

测试：`SEASON_HISTORY PASS`

---

## 个人封地：文房小院（后端已实装）

```text
每人一块小院，挂在阵营起始城，不占 13 城节点
3 个房间：书房 / 练兵场 / 望楼，1–3 级
升级消耗军功余额：2 级 30，3 级 80
```

效果：

```text
书房：预读张数 = 等级
练兵场：每周可改编成次数 = 等级
望楼：侦察额外覆盖邻城数 = 等级
```

太守：

```text
每周每城贡献第一 = 太守
state.map.nodes[].governor 返回昵称/阵营/颜色
```

测试：`ESTATE PASS`

---

## 战前军议 / 个人战报（后端已实装）

战前预估：

```text
POST /api/slice/battle/forecast
用当前已出的令模拟一次不落库的战斗
返回：破墙、战果分、民心变化、克制统计、建议
未侦察敌城隐藏守军队伍，只给兵力区间
己方城返回 DEFEND_CITY，不模拟进攻
```

个人战报：

```text
GET /api/slice/me/report
每条令的角色、伤害、破墙、损失、贡献%
军功、本周排名、高光句
```

测试：

```text
FORECAST PASS
MERIT PASS
```

---

## 当前深度

```text
地图：邻接 + 跨区边 + 区域目标
编成：混编 / 同兵种取舍
攻城：大营 / 关隘差异
```

学生每天的选择开始有连锁后果：

```text
先打哪座城 → 是否连成区 → 是否吃到区域 +5%
带哪三个兵种 → 混编还是专精
守哪座关隘 → 守军 +10%
```

---

## 下一步

```text
D8 赛季史书：客户端史书面板 + 分享图
长安决战 UI：第 4 周专属提示
13 城主场景：Map12Map 接 Slice.tscn
文房小院：S02 页面 + 太守旗 + 势力足迹
战前军议：S01 城池抽屉接预估
个人战报：S04 首卡接 me/report
```
