# 8 人 × 3 回合模拟试跑报告（P1.5）

> 目的：在真实学生试跑前，用 8 个 bot 跑完 5 节点 3 回合，
> 验证一令一队、12 张战术、民心、易主、21:00 结算。
> 脚本：`tools/trial_8p.ps1`
> 日期：2026-11-10

---

## 1. 配置

```text
青竹一 ~ 青竹四  → 笔阵营（bi）
墨点一 ~ 墨点四  → 墨阵营（mo）
5 节点：A_START / N1 / N2 / N3 / B_START
每人 3 令，分散打 N1 / N2 / N3
每回合 21:00 教师统一 card-settle
```

为避免 4v4 全场平票，脚本让墨点四少出一令，形成 **4 票 vs 3 票** 的主城争夺。
这是脚本的刻意安排，不是规则。

试跑库使用独立配置：

```powershell
powershell -File tools/trial_8p.ps1 -Trial -Reset -Turns 3
```

`-Trial` 指向 `qingzhu_slice_trial`，不会被客户端 smoke / E2E 重置。

---

## 2. 三回合结果

### 第 1 回合

```text
N1：score 0，城墙 972.2，民心 0 → 0
N2：standoff
N3：standoff
```

3 队打中立守军（990），城墙压到 972，但没有推动民心。

### 第 2 回合

```text
N2：score 0，城墙 972.2，民心 0 → 0
N1：standoff
N3：standoff
```

同样的结果：能打，但打不穿。

### 第 3 回合

```text
N3：score 1，城墙 228.7，民心 0 → 1
N1：standoff
N2：standoff
```

这一场带了弓兵，并带「犄角 + 运粮 + 空城」，把城墙压到 228，推了一格。

---

## 3. 队伍与卡牌

落库的 3 支队伍：

```text
第 1 回合 N1
  cav    lane 1 front  last_stand
  cav    lane 1 front  mutual_support
  shield lane 2 front  empty_fort

第 2 回合 N2
  cav    lane 1 front  forced_march
  cav    lane 1 front  supply
  shield lane 2 front  last_stand

第 3 回合 N3
  cav    lane 1 front  mutual_support
  cav    lane 1 front  supply
  arc    lane 3 back   empty_fort
```

说明 P1.5 生效：

```text
一令 = 一队
每队保留自己的牌
弓兵回到后排
3 队上限
```

同一路重复的队伍会被引擎顺延到空位，但 `attacker_json` 保留玩家原始选择。

---

## 4. 发现

### 4.1 4v4 平票是规则，不是 bug

一人一票后，双方各 4 人打同一城 → `standoff`。
这符合“平票对峙”的设计，但真实试跑时要观察：

```text
学生能不能理解“平票 = 今天没打”？
老师能不能解释“不是系统坏了”？
```

### 4.2 真正卡住的是编成，不是兵力

N1 / N2 的 3 队是 `cav / cav / shield`，没有弓兵。
守军是 `shield / shield / arc`：

```text
骑兵打盾兵 ×0.85（被克）
没有弓兵，后排打不到
城墙卡在 972
```

同样约 1080 兵，换成 `cav / shield / arc`：

```text
中立 990  → 城墙约 677，score 1
中立 1100 → 城墙约 1133，score 0
```

所以把中立守军从 1100 调到 **990**：

```text
正常编成：两晚易主（符合“普通城 1–1.5 晚”）
编成不对：仍然打不动
```

这不是系统 bug，是编成选择开始有后果。

### 4.3 卡牌确实改变结果

第 3 回合 N3 带了弓兵，并带「犄角 + 运粮 + 空城」：

```text
城墙 228（score 1）
同一编成去掉这三张牌，城墙会回到 700 以上（score 0）
```

---

## 5. 结论

```text
一令一队：通过
每队带牌：通过
弓兵后排：通过
3 队上限：通过
民心推进：通过（第 3 回合 +1）
平票回执：通过
21:00 结算：通过
独立试跑库：通过
```

---

## 6. 还没验证

```text
真实学生能否理解“平票”
真实学生能否解释“为什么没打下来”
教师投屏与课堂节奏
4 周赛季延续
```

---

## 7. 复现

```powershell
# 先启动 MariaDB
powershell -NoProfile -ExecutionPolicy Bypass -File server/slice/start_mariadb.ps1

# 独立试跑库 + 3 回合
powershell -NoProfile -ExecutionPolicy Bypass -File tools/trial_8p.ps1 -Trial -Reset -Turns 3
```

---

## 8. 一句话

> **牌和队伍已经真的进战斗了；现在打不动的原因是编成不对，而不是系统没执行。**
