# 8 人 × 3 回合模拟试跑报告（P1.5 最终彩排）

> 目的：按 `TRIAL_RUNBOOK.md` 走完整彩排：重置试跑库 → 8 人 3 回合 → 教师结算 → 下一回合 → 导出 CSV。
> 脚本：`tools/trial_8p.ps1`
> 日期：2026-11-10

---

## 1. 配置

```text
青竹一 ~ 青竹四  → 笔阵营（bi）
墨点一 ~ 墨点四  → 墨阵营（mo）
5 节点：A_START / N1 / N2 / N3 / B_START
主城固定 N2：4 笔 vs 3 墨
墨点四打 N3 侧城
每人 3 令，编成按玩家轮换
每回合 21:00 教师 card-settle
```

```powershell
powershell -File tools/trial_8p.ps1 -Trial -Reset -Turns 3
```

`-Trial` 指向 `qingzhu_slice_trial`，不会被 smoke / E2E 重置。

---

## 2. 三回合结果

| 回合 | 城 | 比分 | 城墙 | 民心 | 结果 |
|---|---|---|---:|---|---|
| 1 | N2 | 1 | 674.5 | 0→1 | 推一格 |
| 2 | N2 | 1 | 674.5 | 1→0 | **易主，归笔** |
| 2 | N3 | 0 | 1198.4 | 0→0 | 对峙 |
| 3 | N2 | 0 | 757.1 | 0→0 | 笔驻守，守住 |
| 3 | N3 | -1 | 1213 | 0→0 | 被挡 |

关键：

```text
第 1 晚：中立城推 1 格
第 2 晚：推满 2 格，城头换旗
第 3 晚：墨反攻笔刚占的 N2，笔驻守，0 分守住
```

这正是设计里的“普通城 1–1.5 晚易主 + 已占城守方优势”。

---

## 3. 队伍与卡牌

第 2 晚 N2 攻方：

```text
cav    lane 1 front  forced_march
shield lane 1 front  mutual_support
spear  lane 1 front  supply
```

第 3 晚 N2 攻方（墨反攻）：

```text
cav    lane 1 front  cut_supply
shield lane 1 front  empty_fort
arc    lane 1 back   cut_supply
```

说明：

```text
一令 = 一队
每队保留自己的牌
弓兵后排
真实守军：笔占城后，笔的令变成守军
```

---

## 4. 本轮调平

中立守军从 990 降到 **803**。

原因：

```text
990：8 人 3 队前两晚都是 0 分，三晚不 flip
803：第 1 晚 +1，第 2 晚 +1 → 易主
```

100 人规模此前已验证 3 队 + 30% 支援可以破 990；
803 让 8 人小样本也能在 2 晚完成易主，符合“普通城 1–1.5 晚”。

---

## 5. 数据导出

```powershell
$env:SLICE_CONFIG = "$PWD\server\slice\config.trial.php"
php server/slice/scripts/export_trial.php
```

本次导出：

```text
orders=69
battles=5
changes=5
captures=1
```

文件：

```text
trial_results/20261110_235409/
  orders.csv
  battles.csv
  changes.csv
  turns.csv
  nodes.csv
  compositions.csv
  summary.json
  observation.md
```

---

## 6. 验收

```text
TRIAL_8P PASS
一令一队：通过
每队带牌：通过
弓兵后排：通过
3 队上限：通过
民心推进：通过
两晚易主：通过
真实守军守住反攻：通过
21:00 结算：通过
独立试跑库：通过
CSV 导出：通过
```

---

## 7. 还没验证

```text
真实学生能否理解“平票”
真实学生能否解释“为什么没打下来”
教师投屏与课堂节奏
4 周赛季延续
```

---

## 8. 一句话

> **8 个 bot 三回合：中立城第二晚换旗，第三晚守方守住；整条试跑链路和导出都跑通了。**
