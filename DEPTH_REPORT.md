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
D2 迷雾：未侦察城只显示归属，不显示守军
D5 支援令：普通学生可给主攻 +10%
D6 每日邸报：二选一，小 buff
D8 赛季史书
```
