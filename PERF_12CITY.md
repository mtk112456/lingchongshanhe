# 12+1 城 × 100 人性能测试（PERF12）

日期：2026-11-11  
测试脚本：`server/slice/tests/perf12_test.php`  
结果：**PERF12 PASS**（7 回合全部通过，p95 / max 均低于阈值）

---

## 1. 测试目标

在真实规模下验证 `CardSettlementService::settle()` 的结算性能：

- 12+1 城：13 节点、19 条边、4 阵营；
- 100 名玩家，每阵营 25 人；
- 每回合 300 条令（每人 3 令）；
- 连续结算 7 个回合；
- 随机混合编成、邸报选择（grain / ram / scout）、战术卡牌与目标城；
- 当前代码基线包含 `MeritService` 个人军功写入（migration 008）。

阈值：

| 指标 | 阈值 | 实测 | 结论 |
|---|---:|---:|---|
| 结算 p95 | < 500 ms | 162.2 ms | PASS |
| 单回合 max | < 1500 ms | 162.2 ms | PASS |
| SQL / 结算异常 | 0 | 0 | PASS |

---

## 2. 环境

| 项 | 值 |
|---|---|
| 机器 | AMD Ryzen 9 7945HX |
| 系统 | Windows 11（中文版） |
| PHP | 8.4.25 CLI，`memory_limit=128M`，CLI 未启用 OPcache |
| 数据库 | MariaDB 11.4.9，`127.0.0.1:3307` |
| 性能专用库 | `test_perf`（`server/slice/config.perf.php`） |
| 连接方式 | `slice_bootstrap()`，受 `SLICE_CONFIG` 环境变量控制 |
| 代码基线 | 含 `MeritService` / `slice_merit_events`（migration 008） |
| 随机种子 | `mt_srand(121213)`（固定种子；邸报选项仍受自增 turn_id 影响，跨次运行不是逐字节复现） |

隔离说明：

- 脚本只允许连接 `test_perf`，库名不符会直接退出，不会误跑回归库；
- 运行前执行 `seed_map12.sql` 重置 `MAP12_TEST`；
- 性能局使用独立 `PERF12` 游戏，结束后删除；
- 100 名测试学生使用 `PERF12xxx` 前缀，结束后删除；
- 不修改 `qingzhu_slice_test`、既有 schema 或 trial 数据。

> 本轮 `test_perf` 在测试前补齐了 `migrations/008_player_merit.sql`（`slice_merit_events`）。该表已并入当前 `schema.sql`，新建性能库时执行 `setup_test_db.php` 即会包含。

---

## 3. 命令

```powershell
$env:SLICE_CONFIG = "D:\DeskBox\游戏\server\slice\config.perf.php"
$php = "C:\Users\MTK\AppData\Local\Microsoft\WinGet\Packages\PHP.PHP.8.4_Microsoft.Winget.Source_8wekyb3d8bbwe\php.exe"
$args = @(
  '-d', 'extension_dir=C:\Users\MTK\AppData\Local\Microsoft\WinGet\Packages\PHP.PHP.8.4_Microsoft.Winget.Source_8wekyb3d8bbwe\ext',
  '-d', 'extension=pdo_mysql'
)

# 1. 初始化 12+1 城种子（脚本自身也会再执行一次 seed）
& $php @args server/slice/scripts/setup_map12_db.php

# 2. 性能测试
& $php @args server/slice/tests/perf12_test.php
```

---

## 4. 测试构造

1. `seed_map12.sql` 重置 `MAP12_TEST`（13 节点 / 19 边 / 4 阵营 / 8 学生）。
2. 克隆地图与阵营到 `PERF12`，新建 100 名学生、100 只班宠、100 名玩家。
3. 第 1 周为每人写入随机编成（4 兵种取 3）；第 4 回合让一半玩家周中改一次编成。
4. 每回合为每人写入 3 条令，共 300 条：
   - 卡牌：从 12 张战术中随机取 3 张不重复，保证至少 1 张可带队伍的牌；
   - 目标：10% 出生城、20% 本区三城、70% 全图 13 城随机；
   - 位次：lane 1–3、front/back 随机。
5. 每回合通过 `BulletinService` 的真实两选一流程写入邸报选择，按 `grain / ram / scout` 轮换，缺项时选全局出现较少的选项。
6. 仅对 `CardSettlementService::settle()` 计时；300 条令写入与邸报写入不计入结算耗时。
7. 结算内部包含 `MeritService` 的参与军功与战斗军功写入，每回合约 238–294 条 award。
8. 每个回合结算前 `memory_reset_peak_usage()`，结算后读取 `memory_get_peak_usage(true)` 作为该回合内存峰值。

说明：为了保证 7 回合内覆盖全部 13 城并保持 300 令压力，脚本直接写入 `slice_order_slots`，不走 `HandService` 的邻接与周次校验；因此第 1 周也会攻击长安。这是刻意的压力构造，不是规则验证。

---

## 5. 结果（代表性运行，含军功）

| 回合 | 令数 | 实际战斗 | 易主 | 军功行数 | 结算耗时 (ms) | 内存峰值 (MB) |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 300 | 11 | 0 | 238 | 162.2 | 4.0 |
| 2 | 300 | 13 | 7 | 283 | 158.1 | 4.0 |
| 3 | 300 | 11 | 3 | 282 | 150.5 | 4.0 |
| 4 | 300 | 10 | 3 | 294 | 153.2 | 4.0 |
| 5 | 300 | 9 | 4 | 268 | 139.9 | 4.0 |
| 6 | 300 | 10 | 3 | 250 | 137.5 | 4.0 |
| 7 | 300 | 11 | 2 | 278 | 150.6 | 4.0 |
| **合计** | **2100** | **75** | **22** | **1893** | — | **4.0** |

汇总：

```text
p50 = 150.6 ms
p95 = 162.2 ms
max = 162.2 ms
avg = 150.3 ms
memory peak (max of rounds) = 4.0 MB
```

同基线第二次运行：p50 = 151.0 ms，p95 / max = 158.3 ms，avg = 147.6 ms，76 场战斗、22 次易主。  
两次运行均为 7/7 回合结算、每回合 300 令、0 异常，单回合区间约 129–162 ms。

注：7 个样本下最近秩 p95 等于 max，因此 p95 阈值实际等价于“7 回合全部 < 500 ms”。

邸报选择分布（代表性运行）：

```json
{"grain": 234, "ram": 233, "scout": 233}
```

### 与军功集成前的对比

同一脚本、同一机器，`CardSettlementService` 尚未接入 `MeritService` 时测得：

```text
p50 = 33.4 ms, p95 = 39.0 ms, max = 39.0 ms, avg = 32.8 ms
```

接入军功后 p95 从约 39 ms 升至约 162 ms，增量约 120 ms/回合；同期每回合新增 238–294 条军功写入。增量与逐条 `INSERT ... ON DUPLICATE KEY UPDATE` 的数量基本吻合。

---

## 6. 瓶颈观察

1. **个人军功写入是当前最大成本。** 每回合 238–294 条 award（7 回合共 1893 条），其中 100 条是出令参与军功，其余来自先锋、支援、破城、侦察、火攻、驻守等战斗角色。`MeritService::award()` 每条执行一次独立 `INSERT ... ON DUPLICATE KEY UPDATE`，约占本回合结算时间的一半以上。
2. **城级战斗与数据库往返是第二成本。** 300 条令通过单条 SQL 一次取出，随后按目标城聚合；每座城固定执行节点查询、阵营加成判断、先锋/守军编成查询、战斗落库与民心更新。每回合 9–13 场战斗，对应约 30–50 ms，与军功集成前的整回合耗时一致。
3. **内存稳定在 4 MB 量级。** 第 1 回合后达到 4 MB 并保持平坦，没有逐回合增长，未发现明显泄漏或大对象累积；主要对象是 300 条令的查询结果、单场战斗 JSON 和军功结果数组。
4. **规模有天然上限。** 城数固定 13，单回合令数上限 300；继续增加玩家只会增加令数与支援人数统计，不会增加战斗场次。`slice_battles` 每回合约 9–13 行，28 回合赛季约 300 行，当前索引 `(turn_id, node_code)` 足够；`slice_merit_events` 每回合约 270 行，28 回合约 7500 行，当前 `(turn_id, player_id, kind)` 唯一键与 `(game_id, player_id)` 索引可支撑。
5. **未覆盖的链路。** 本测试只测 `CardSettlementService::settle()`：不包含 HTTP 层、快照、`slice_turn_results`、100 份个人战报生成、结算任务队列和并发锁。若上线前需要端到端 SLA，应另做一次带 job/API 的整链路压测。
6. **阈值余量。** 最慢回合 162.2 ms，对比 500 ms p95 线约 3.1 倍余量；对比 1500 ms max 线约 9.2 倍余量。当前机器为开发机，部署服务器性能不同，建议在目标服务器复测一次。

优化方向（本次未改代码）：

- 将同一回合的军功 award 合并为批量多行 INSERT，或放入结算后的异步任务，可把约 120 ms 的军功成本压到十几毫秒；
- 若后续玩家数继续增加，可缓存城级阵营加成查询结果，减少每城重复的 `slice_factions` / `slice_nodes` 查询；
- 在目标服务器复测时保留相同的 7 回合口径，并同时记录 DB 慢查询日志。

---

## 7. 结论

- 12+1 城、100 人、每回合 300 令、连续 7 回合的结算路径通过性能验收。
- p95 162.2 ms、max 162.2 ms、内存峰值 4.0 MB，均低于阈值，未发现 SQL 异常或逐回合性能退化。
- 与军功集成前相比，结算耗时上升约 4 倍，主要来自逐条军功 INSERT；当前阈值下仍有 3 倍以上余量。
- 当前实现足以支撑 8–12 名真实学生的三回合切片，也为 100 人规模留出了余量；若未来提高人数或收紧 p95，优先批量化军功写入。
- 后续若增加个人战报、快照或 HTTP 并发，应扩展测试范围并在部署环境复测。
