# 8 人 × 3 回合模拟试跑报告

> 目的：在真实学生试跑前，用 8 个 bot 账号跑完 5 节点 3 回合，验证多玩家、多回合、民心、易主、21:00 结算。
> 脚本：`tools/trial_8p.ps1`

---

## 1. 配置

```text
青竹一 ~ 青竹四  → 笔阵营（bi）
墨点一 ~ 墨点四  → 墨阵营（mo）
5 节点：A_START / N1 / N2 / N3 / B_START
每回合每人 3 张将令
21:00 教师统一 card-settle
```

---

## 2. 三回合结果

### 第 1 回合

```text
N1：score 1，城墙 679.7，民心 0 → 1
N2：score 1，城墙 308.8，民心 0 → 1
```

两座中立城都只被推了一格，没有一晚易主。

### 第 2 回合

```text
N1：score 1，城墙 308.8，民心 1 → 2，易主 → bi
N2：score 1，城墙 465.7，民心 1 → 2，易主 → mo
```

中立城两回合拿下，节奏符合“普通城 1–2 晚”。

### 第 3 回合

```text
N1（bi 已占）：mo 进攻，score 0，城墙 875.9，民心 0 → 0，守住
N2（mo 已占）：bi 进攻，score 1，城墙 661.9，民心 0 → 1，未破
```

已占城第一回合只推 0–1 格，守方有优势，没有连锁崩盘。

---

## 3. 发现并修复的问题

| 问题 | 影响 | 修复 |
|---|---|---|
| 先锋聚合把完整战力全带上 | 3 先锋 = 3 倍兵力，一晚必破 | 每人只带 1/3，`petPower / 3` |
| `request_key` 带中文 | 被正则拒绝，play 返回 500 | 改成 ASCII GUID |
| `InvalidArgumentException` 未转换 | 参数错误返回 500 | 路由捕获，转 400 `BAD_REQUEST` |
| 第 3 回合脚本打自己刚占的城 | 只显示 `already_owned` | 改成互打对方城 |

---

## 4. 结论

```text
8 人登录/发牌/出令：通过
两阵营同时进攻：通过
民心 0→1→2：通过
两回合易主：通过
已占城防守：通过
21:00 统一结算：通过
重复结算幂等：通过
```

---

## 5. 还没验证

- 真实学生的理解度：能否解释为什么没打下来；
- 8 人同时在线（脚本是顺序请求，不是并发）；
- 教师投屏/课堂节奏；
- 3 回合后的赛季延续。

这些要等真实 8–12 人试跑。

---

## 6. 复现

```powershell
# 先启动 MariaDB
powershell -NoProfile -ExecutionPolicy Bypass -File server/slice/start_mariadb.ps1

# 重建测试库
php server/slice/scripts/setup_test_db.php

# 8 人 3 回合
powershell -NoProfile -ExecutionPolicy Bypass -File tools/trial_8p.ps1
```

---

## 7. 一句话

> **8 个 bot、2 阵营、3 回合：中立城两回合拿下，第三回合攻已占城只推 0–1 格，8 人链路和 21:00 结算全部跑通。**
