# 100 人并发出令 / 教师双击结算 · 并发安全报告

- 日期：2026-11-11
- 被测入口：`server/slice/public/index.php`
- 隔离库：`test_load` @ `127.0.0.1:3307`，用户 `qingzhu_test`
- 测试脚本：`server/slice/tests/load_concurrency_test.php`
- 隔离配置：`server/slice/config.load.php`
- HTTP：`127.0.0.1:8098` 主实例 + `8108–8116` 辅助实例，测试后全部释放
- 约束：未改业务代码 / schema / 现有测试；未触碰 `qingzhu_slice_test`、`qingzhu_slice_trial`、`test_merit`、`test_sim`、`test_api`；未 commit / push。

---

## 0. 一句话结论

```text
300 个并发出令：300/300 200，库里 300 条 active，无重复、无死锁。
教师并发结算：5 次完整运行共 250 轮，每轮恰好 1 次真实结算；
             没有重复 slice_battles / merit 金额 / turn_results / game 状态。
但发现 2 个确定的竞态：
  1) 同一玩家并发取手牌 → 1062 重复键 → 500；
  2) 结算开始后仍可出令 → 200 但令永不结算。
另有 1 个代码级 TOCTOU：
  结算状态检查在 GET_LOCK 之前、锁内不复查；250 轮未复现，但窗口存在。
```

**判定：核心出令 / 结算路径基本可用，但当前版本不能判定为“完全并发安全”。建议先修 P0 两项，再上 100 人真实试跑。**

---

## 1. 隔离与方法

### 1.1 为什么用 10 个 PHP 进程

本机 PHP 8.4.25（Windows）的 `php -S` 是单线程的，`PHP_CLI_SERVER_WORKERS` 在 Windows 不可用。单端口 8098 的请求会串行执行，无法制造数据库层竞态。

因此测试启动 10 个内置服务器：

```text
主实例：127.0.0.1:8098
辅助：  127.0.0.1:8108–8116
全部使用同一个 config.load.php / test_load
300 个出令请求按轮询分摊到 10 个实例
```

这不是为了模拟 10 台机器，而是为了得到 ≥10 个真正并行的 PHP 进程。生产用 php-fpm / Apache 多 worker，并发度更高；本报告的数据库结论仍然成立，延迟数字只代表本机 10 进程。

### 1.2 无 curl / 无 pcntl

本机 PHP 未启用 `curl`，也没有 `pcntl`。脚本用：

```text
stream_socket_client() 建立非阻塞连接
stream_select() 多路复用
最多 120 个在途连接
按 start_at 计划发送，可构造 0–T 的错峰并发
```

所有请求带 `Connection: close`，读到 EOF / Content-Length 后解析状态码与 JSON。

### 1.3 数据准备

```text
setup_test_db.php --force   +   setup_map12_db.php
克隆 MAP12_TEST 的 13 节点 / 19 边 / 4 阵营为 LOAD_CC
100 名玩家 LC001–LC100（每阵营 25 人）
1 名探针玩家 LC101（只用于“结算中出令”）
1 名教师
每人 3 令，共 300
目标取本阵营相邻中立城（排除长安）
结果：6 场战斗 + 1 场对峙（jiangling）+ 1 座中立城未被攻击
```

100 名玩家先各自取一次手牌，再并发出令，避免把“手牌首次创建”混入 300 令指标。

### 1.4 限流

`config.load.php` 关闭了 `app.ratelimit.enabled`。

原因：

```text
login 默认 10 次/分钟/IP
100 人同机 / 同 NAT 登录，第 11 个请求就会 429
出令 60 次/分钟/玩家对每人 3 令不构成限制
```

这是压测隔离手段，不是生产建议；生产风险见 §8.1。

---

## 2. 100 人 × 3 令并发提交

### 2.1 响应时间与错误码

| 阶段 | 请求数 | 成功 | p50 | p95 | max | 备注 |
|---|---:|---:|---:|---:|---:|---|
| 101 人登录 | 101 | 101 × 200 | 1068.7 ms | 1899.1 ms | 2072.3 ms | bcrypt × 101，10 个单线程实例排队 |
| 100 人取手牌 | 100 | 100 × 200 | 133.6 ms | 170.1 ms | 212.1 ms | 每人 4 张 |
| 300 个出令 | 300 | 300 × 200 | 203.2 ms | 433.1 ms | 479.4 ms | 总耗时 1208 ms，约 248 req/s |
| 同 key 20 次 | 20 | 20 × 200 | 40.2 ms | 49.1 ms | 49.7 ms | 同 slot、同 body |

出令错误码分布：

```text
HTTP 200: 300
HTTP 4xx: 0
HTTP 5xx: 0
error.code: 无
```

没有出现 `RATE_LIMITED`、`PLAY_LIMIT_REACHED`、`CARD_ALREADY_PLAYED`、`TURN_NOT_OPEN`、死锁 1213 或 500。

> 延迟说明：p50/p95 包含 10 个单线程实例的排队时间，不等于数据库锁等待。真正的结算工作约 200 ms（见 §4）；单个出令的服务端处理时间远低于 p50。

### 2.2 数据库校验

```text
slice_order_slots active            = 300
distinct player_id                  = 100
每人 slot 数不等于 3 的玩家          = 0
last_request_key 与发送值不一致      = 0
(turn_id, player_id, slot) 重复      = 0（唯一键兜底）
```

结论：**100 人 × 3 令的并发出令路径通过**。并发下没有重复扣令、没有覆盖、没有死锁。

---

## 3. 同一 `request_key` 重复 20 次

### 3.1 结果

```text
20 个请求同时发（同 turn / 同 player / 同 slot / 同 body）
HTTP 200 × 20
响应 p50 48.6 ms / p95 53.0 ms / max 65.8 ms
库里该 (turn, player, slot) 只有 1 条 active 令
全库 active 仍为 300
```

单看这一项是 PASS，但**不能据此认为 `request_key` 有幂等性**。

### 3.2 关键发现：`request_key` 不是幂等键

同一 key 换一个 slot 再提交：

```text
slot 0 + key K → 200
slot 1 + key K → 200
库里 last_request_key = K 的 active 令 = 2 条
```

原因：

- `HandService::play()` 只校验 key 格式，然后把它写进 `slice_order_slots.last_request_key`；
- 没有任何 `SELECT ... WHERE request_key = ?` 的去重；
- 20 次同 key 只产生 1 条，是因为 `uk_slots_turn_player_slot (turn_id, player_id, slot)` 唯一键，而不是幂等；
- `slice_order_requests` 表（`schema.sql` 170–183，唯一键 `uk_requests_turn_player_key`）已经存在，但只被旧军令 `SliceService::submitOrder()` 使用（845–960），卡牌出令路径完全没用。

影响：

```text
客户端超时重试：同 key 可能覆盖另一个 slot，或让 2 条令共享一个 key；
服务端无法返回 IDEMPOTENCY_CONFLICT；
last_request_key 被最后一个写入者覆盖，不能作为历史凭证。
```

修复建议见 §9 P1-3。

---

## 4. 教师并发结算

### 4.1 基线：单请求结算

| 指标 | 值 |
|---|---:|
| HTTP | 200，`already_settled=false` |
| 响应时间 | 203.0 ms |
| `slice_battles` | 6 |
| `battle_nodes`（不同城） | 6 |
| 每城最多战斗数 | 1 |
| `slice_merit_events` 行数 | 256 |
| `slice_merit_events` 金额合计 | 2636 |
| `slice_node_changes` | 6 |
| `slice_turn_results` | 1 |
| `slice_turns.status` | settled |
| `slice_games.status` | running |

`data.battles` 数组有 7 条，其中 1 条是 `jiangling:standoff`（`battle_id=null`）。`teacher.html` 已经处理这种条目（242–244 行）；客户端不要用数组长度当战斗数。

### 4.2 50 轮并发结算

每轮用 2 个或 4 个不同端口的进程同时 POST `/api/slice/admin/card-settle`，延迟覆盖 `0 ms → 基线 T`：

```text
总请求 116
真实结算（200 + already_settled=false）    50
已结算（200 + already_settled=true）       10
结算忙（409 + SETTLE_BUSY）                56
其他（5xx / 超时 / 未知）                   0
```

每轮结果组合：

| 组合 | 轮数 |
|---|---:|
| `real=1, busy=1`（两请求重叠，一个赢） | 40 |
| `real=1, already=1`（第二个晚到，已提交） | 2 |
| `real=1, already=1, busy=2`（4 请求） | 8 |

**每一轮都恰好只有 1 次真实结算。**

响应时间：

| 类型 | n | p50 | p95 | max |
|---|---:|---:|---:|---:|
| 真实结算 | 50 | 189.7 ms | 212.8 ms | 217.0 ms |
| `SETTLE_BUSY` | 56 | 18.7 ms | 34.9 ms | 42.6 ms |
| `already_settled` | 10 | 18.2 ms | 34.5 ms | 34.5 ms |

每轮数据库不变量：

```text
slice_battles                  = 6
battle_nodes                   = 6
max_battles_per_node           = 1
slice_merit_events 行数         = 256
slice_merit_events 金额合计     = 2636
slice_node_changes             = 6
slice_turn_results             = 1
slice_turns.status             = settled
slice_games.status             = running
异常轮数                        = 0
```

加上前面 4 次完整运行，**共 5 次运行 / 250 轮，0 次双重真实结算，0 次重复战斗，0 次军功翻倍，0 次 game / turn_result 异常；每轮战斗数、军功行数、军功金额都严格等于单次结算基线。**

### 4.3 结论与代码级 TOCTOU

`GET_LOCK('slice_settle_' . $turnId, 0)` 在实测并发下有效：

- 重叠请求 → 一个拿到锁，另一个快速 409 `SETTLE_BUSY`（约 21 ms，不会挂住）；
- 晚到请求 → 200 `already_settled=true`；
- 没有出现两个请求都 `already_settled=false`。

但代码仍有 1 个**理论窗口**（`CardSettlementService.php`）：

```php
// 69–71：先检查状态
if ((string)$turn['status'] === 'settled') {
    return ['turn_id' => $turnId, 'already_settled' => true, 'battles' => []];
}

// 73–78：再拿锁；拿不到就 409
$stmt = $this->pdo->prepare('SELECT GET_LOCK(?, 0)');
...
if ((int)$stmt->fetchColumn() !== 1) {
    throw new ApiException('SETTLE_BUSY', '??????????????', 409);
}

// 127–131：最后才把 turn 置为 settled；没有检查 rowCount
UPDATE slice_turns SET status = "settled", settled_at = NOW()
WHERE id = ? AND game_id = ? AND status != "settled"
```

失败序列：

```text
B: SELECT turn.status → open
B: 被 OS 抢占（或 PHP/DB 调度抖动）
A: 拿锁 → 完成结算 → UPDATE settled → RELEASE_LOCK
B: 恢复 → GET_LOCK 成功（A 已释放）→ 再次结算
```

一旦命中：

- `slice_battles` 会重复（该表只有 `KEY idx_battles_turn_node (turn_id, node_code)`，没有唯一约束，`schema.sql` 391–405）；
- `slice_merit_events` 不会多行（`uk_merit_turn_player_kind`，`schema.sql` 438），但 `ON DUPLICATE KEY UPDATE amount = amount + VALUES(amount)` 会把金额翻倍（`MeritService.php` 46–50）；
- `slice_node_changes` / `slice_turn_results` 会被 upsert 覆盖，**反而掩盖**重复结算；
- `slice_turns.status` 仍是 settled，`slice_games.status` 通常不变。

因此未来的监控不能只看“merit 行数”或“turn_results 行数”，要看：

```text
COUNT(slice_battles) vs COUNT(DISTINCT node_code)
SUM(slice_merit_events.amount) vs 单次结算基线
```

本次 250 轮没有复现，窗口在 `SELECT status` 与 `GET_LOCK` 之间的亚毫秒级；但修复成本很低，建议按 §9 P0-1 处理。

---

## 5. 已确认竞态 #1：同一玩家并发取手牌 → 500

### 5.1 复现

对探针玩家 LC101 连续做 5 轮、每轮 16 个并发 `GET /api/slice/hand?turn_id=3`：

```text
HTTP 200 × 79
HTTP 500 × 1
库里 slice_hands 行数 = 1
```

500 的响应体（`expose_error_details=true`）：

```text
SQLSTATE[23000]: Integrity constraint violation:
1062 Duplicate entry '3-119' for key 'uk_hand_turn_player'
```

首轮 8 并发也命中过 1 次 500；另一次 8 并发没有命中，说明是**偶发窗口**，需要压力才能稳定复现。

### 5.2 原因

`HandService::getOrCreateHand()`（34–66 行）：

```php
SELECT ... FROM slice_hands WHERE turn_id = ? AND player_id = ?
if ($row) { return ...; }

// 没有 ON DUPLICATE，也没有 catch 1062
INSERT INTO slice_hands (...) VALUES (...)
```

两个进程同时 SELECT 不到 → 同时 INSERT → 一个成功，另一个撞 `uk_hand_turn_player (turn_id, player_id)`（`schema.sql` 363）→ PDOException → 500。

### 5.3 影响与修复

影响：

- 学生双击 / 两台设备 / 客户端重试时，第一次打开手牌可能直接 500；
- 手牌其实已经创建成功，重试就会好，但用户体验是“报错”；
- 不会产生重复数据（唯一键兜底）。

修复（二选一）：

```sql
INSERT INTO slice_hands (...)
VALUES (...)
ON DUPLICATE KEY UPDATE hand_seed = hand_seed;
-- 然后再 SELECT 一次
```

或：

```php
try {
    // INSERT
} catch (PDOException $e) {
    if ($e->getCode() === '23000') {
        // 重新 SELECT 并返回
    }
    throw $e;
}
```

---

## 6. 已确认竞态 #2：结算开始后仍可出令，200 但永不结算

### 6.1 复现

每轮保留 300 条 active 令，让教师结算与探针玩家 LC101 的出令错峰进行（不同端口，真正并行）：

| 尝试 | 出令延迟 | 结算耗时 | 出令结果 | 结算后 turn | 探针令 | 探针军功 | 进战斗 players |
|---|---:|---:|---|---|---:|---:|---|
| 1 | 71.1 ms | 185.8 ms | 200 | settled | 1 条 active | 0 | 否 |
| 2 | 101.5 ms | 205.1 ms | 200 | settled | 1 条 active | 0 | 否 |
| 3 | 132.0 ms | 215.5 ms | 200 | settled | 1 条 active | 0 | 否 |

```text
3 / 3 次确认：出令返回 200，但结算快照没有包含它。
```

### 6.2 原因

`CardSettlementService::settle()` 的时序：

```text
1. SELECT turn；确认 open
2. GET_LOCK
3. SELECT slice_order_slots ...（快照）
4. 逐城结算、发军功、写 slice_battles
5. UPDATE slice_turns SET status='settled'   ← 最后才关闸
6. saveTurnResult / RELEASE_LOCK
```

`HandService::assertTurnEditable()` 只检查 `slice_turns.status === 'open'`。在步骤 3 之后、步骤 5 之前到达的出令：

```text
看到 open → 校验通过 → INSERT/UPDATE slice_order_slots → 200
但结算已经取过快照 → 这条令永远不会被处理
```

窗口不是亚毫秒，而是**整个结算时长（约 170–230 ms）**。100 人真实场景里，学生在 21:00:00 点“出令”、教师同时点“结算”，很容易命中。

### 6.3 影响

- 学生收到 200“军令已确认”，但本回合没有参与军功、没有进战斗；
- `slice_order_slots` 留下一条 active 令挂在已 settled 的 turn 下；
- 学生/教师看到的数据不一致，且没有错误提示。

> 注意：正常结算后 300 条令也仍然是 `active`（结算代码不更新令状态），所以**不能只凭 `status='active'` 判断漏令**。本次是用探针玩家的 `participation` 军功 = 0、且不在 `slice_battles.result_json.players` 里来证明它没有被结算。

### 6.4 修复

在结算开始时**原子地把 turn 从 open 抢占为 settling**，再取快照：

```sql
UPDATE slice_turns
SET status = 'settling', locked_at = NOW()
WHERE id = ? AND game_id = ? AND status = 'open';

-- rowCount = 0 → 已经在 settling / settled / locked
-- 返回 409 SETTLE_BUSY 或 200 already_settled，不要继续结算
```

`HandService::assertTurnEditable()` 只允许 `status='open'`：

```text
settling → 409 TURN_SETTLING（新错误码）
settled  → 409 TURN_NOT_OPEN（现有）
```

结算成功后再 `settling → settled`；失败则 `settling → failed`（或按现有失败处理逻辑回退）。

这个改动同时修复 §4.3 的 TOCTOU：两个结算请求只有一个能把 `open` 改成 `settling`。

---

## 7. 其他发现

### 7.1 `SETTLE_BUSY` 错误文案损坏

`CardSettlementService.php:77` 实际文件内容：

```php
throw new ApiException('SETTLE_BUSY', '??????????????', 409);
```

接口返回：

```json
{"ok":false,"error":{"code":"SETTLE_BUSY","message":"??????????????"}}
```

教师端无法理解。建议改成 `结算进行中，请稍后再试`。

### 7.2 双击后的 `already_settled` 返回空战报

`settle()` 对已结算回合返回：

```php
['turn_id' => $turnId, 'already_settled' => true, 'battles' => []]
```

`teacher.html` 的 `renderBattles(result.battles || [])` 会把结果区渲染成“本回合没有发生战斗”。教师如果因为网络重试/多标签页拿到这个响应，会误以为没有战斗。建议前端识别 `already_settled` 并刷新战报，或后端返回上一次的战报摘要。

> 注：`teacher.html` 的 `runAction()` 有 `state.busy` 守卫，单页面双击不会发两个请求；但多标签页、Godot 教师端、超时重试仍可并发。

### 7.3 `data.battles` 含非战斗条目

本次 `jiangling` 是 `standoff`，返回：

```json
{"node_code":"jiangling","battle_id":null,"reason":"standoff"}
```

`teacher.html` 已处理；`http100_test.php` 也按 `battle_id` 过滤。这不是缺陷，但接口文档应明确：**客户端不能用 `count(data.battles)` 当战斗数**。

### 7.4 `slice_battles` 没有唯一约束

```sql
KEY idx_battles_turn_node (turn_id, node_code)
```

不是唯一键。平时没问题（卡牌结算每城一场），但它是双重结算唯一会“看得见”的重复数据。建议加监控或按 §9 P2-6 加约束。

### 7.5 没有死锁

300 个并发 play + 20 个同 key 并发 upsert：

```text
无 1213 deadlock
无 500
无 429
```

同 key 的 20 个并发 upsert 会被行锁串行化，p95 53 ms，可接受。

### 7.6 结算后令状态不落标记，漏令不可观测

`CardSettlementService` 只读取 `slice_order_slots`，结算完成后**不会**把令标记为 settled。因此：

```text
正常结算：300 条令仍然 active
漏结算：  那条令也仍然 active
```

两者在数据库里长得一样。建议：

- 给 `slice_order_slots` 增加 `settled_at` / `settlement_id`；
- 结算成功后在同一个事务里标记本次快照中的令；
- 巡检 `settled_at IS NULL AND turn.status = 'settled'` 才能发现漏令。

这不是本次新增的并发缺陷，但它让 §6 的竞态很难在线上被发现。

---

## 8. 生产风险

### 8.1 登录限流会挡住一个班

`RateLimiter::DEFAULT_RULES`：

```php
'login' => ['limit' => 10, 'window' => 60]
```

按客户端 IP 计数。学校机房/校园网通常共用一个出口 IP：

```text
第 11 个学生登录 → 429 RATE_LIMITED
```

本次压测因此关闭了限流。上真实 100 人前必须处理，可选：

1. 给校园出口 IP 单独提高 login 限额（如 120/分钟）；
2. 增加“按账号”维度，IP 只做粗粒度防刷；
3. 确认 Cloudflare Tunnel 的 `CF-Connecting-IP` 只在可信代理下生效；
4. 教师提前批量发 token / 学生分批登录。

出令 60/分钟/玩家对 3 令足够；不需要调整。

### 8.2 不要用 PHP 内置服务器上 100 人

`php -S` 单线程；本次用 10 个进程才得到并发。生产至少：

```text
php-fpm / Apache，≥ 20 worker
MariaDB max_connections ≥ worker 数 + 20 余量
```

### 8.3 `GET_LOCK` 的适用范围

`GET_LOCK` 是 MariaDB 服务器级锁，单库单实例没问题。如果未来分库/多主，需要改成数据库行抢占（§6.4 的 `UPDATE ... WHERE status='open'`）或 Redis 锁。

---

## 9. 修复建议（按优先级）

### P0-1：结算前原子抢占 turn（同时修 §4.3 和 §6）

```sql
UPDATE slice_turns
SET status = 'settling', locked_at = NOW()
WHERE id = ? AND game_id = ? AND status = 'open';
```

- `rowCount=1`：抢到，继续结算；
- `rowCount=0`：读当前状态，返回：
  - `settled` → 200 `already_settled=true`；
  - `settling` → 409 `SETTLE_BUSY`；
  - `locked` → 409 `TURN_LOCKED`；
- 结算结束：`settling → settled`；
- 结算异常：`settling → failed`，记录 `failure_reason`；
- `HandService::assertTurnEditable()` 只认 `open`，`settling` 返回 409 `TURN_SETTLING`；
- `GET_LOCK` 可以保留作为第二道防线，但不能再作为唯一防线。

### P0-2：手牌创建改成幂等

```sql
INSERT INTO slice_hands (game_id, turn_id, player_id, cards_json, redraw_used, hand_seed)
VALUES (?, ?, ?, ?, 0, ?)
ON DUPLICATE KEY UPDATE hand_seed = hand_seed;

SELECT cards_json, redraw_used, hand_seed
FROM slice_hands WHERE turn_id = ? AND player_id = ?;
```

或 catch `23000` 后重新 SELECT。

### P1-3：卡牌出令复用 `slice_order_requests` 做真幂等

建议直接复用旧军令的实现（`SliceService.php` 845–960）：

```text
1. 开事务
2. SELECT * FROM slice_order_requests
   WHERE turn_id=? AND player_id=? AND request_key=? FOR UPDATE
3. 有记录：
   - payload_hash 相同 → 返回 response_json，idempotent=true
   - payload_hash 不同 → 409 IDEMPOTENCY_CONFLICT
4. 无记录：
   - 执行 slot upsert
   - INSERT slice_order_requests(... payload_hash, response_json)
   - commit
```

`payload_hash` 至少包含：`turn_id + slot + card_code + target_node_code + lane + row_pos`。

这样：

- 同 key 同 body 重试 → 返回第一次结果，不重复写；
- 同 key 不同 body → 明确 409，而不是静默写第二个 slot；
- `last_request_key` 只作为调试字段。

### P1-4：`GET_LOCK` 内复查状态 + 检查最终 UPDATE 的 rowCount

即使保留现有锁逻辑，也应在拿到锁后：

```php
SELECT status FROM slice_turns WHERE id = ? FOR UPDATE;
if (status !== 'open') { ... already_settled / busy ... }
```

并检查：

```php
$stmt->execute([...]);
if ($stmt->rowCount() === 0) {
    // 另一个进程已经结算，按 already_settled 返回
}
```

### P1-5：修 `SETTLE_BUSY` 文案

`CardSettlementService.php:77` 的 `'??????????????'` 改成正常中文。

### P2-6：给卡牌战斗加唯一约束 / 结算标识

`slice_battles` 目前没有唯一键。不要直接加 `UNIQUE (turn_id, node_code)`，因为 `/api/slice/battle/demo` 可能在同一 turn/城写多场演示战斗。可选：

- 给卡牌结算写一个 `settlement_key`（如 `card:{turn_id}:{node_code}`）并加唯一索引；
- 或只在 `CardSettlementService` 写入前做 `SELECT ... FOR UPDATE` 检查。

### P2-7：前端处理 `already_settled`

`teacher.html` / Godot 教师端：

```text
if (result.already_settled) {
    提示“本回合已结算”，刷新战报；
    不要用 result.battles=[] 渲染“没有战斗”。
}
```

### P2-8：限流调整

按 §8.1 处理校园 NAT 的登录限额。

### P2-9：监控

建议加 3 个巡检 SQL：

```sql
-- 1) 同一 turn/城是否重复战斗
SELECT turn_id, node_code, COUNT(*) c
FROM slice_battles GROUP BY turn_id, node_code HAVING c > 1;

-- 2) 结算漏令：当前 schema 没有“这条令已被结算”的标记，
--    正常结算后 300 条令仍然是 active，无法用 status 区分“正常”与“漏结算”。
--    建议给 slice_order_slots 加 settled_at / settlement_id，结算时统一标记，
--    再巡检 settled_at IS NULL AND turn.status = 'settled'。
SELECT o.turn_id, COUNT(*)
FROM slice_order_slots o
JOIN slice_turns t ON t.id = o.turn_id
WHERE o.settled_at IS NULL AND t.status = 'settled'
GROUP BY o.turn_id;

-- 3) 单回合军功金额是否异常（需要基线或历史对比）
SELECT turn_id, SUM(amount) FROM slice_merit_events GROUP BY turn_id;
```

---

## 10. 复现

### 10.1 一次性建库 + 授权

```sql
CREATE DATABASE IF NOT EXISTS test_load
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON test_load.* TO 'qingzhu_test'@'127.0.0.1';
GRANT ALL PRIVILEGES ON test_load.* TO 'qingzhu_test'@'localhost';
FLUSH PRIVILEGES;
```

### 10.2 运行

```powershell
cd D:\DeskBox\游戏

$php = "C:\Users\MTK\AppData\Local\Microsoft\WinGet\Packages\PHP.PHP.8.4_Microsoft.Winget.Source_8wekyb3d8bbwe\php.exe"
$ext = "C:\Users\MTK\AppData\Local\Microsoft\WinGet\Packages\PHP.PHP.8.4_Microsoft.Winget.Source_8wekyb3d8bbwe\ext"
$env:SLICE_CONFIG = "D:\DeskBox\游戏\server\slice\config.load.php"

& $php -d "extension_dir=$ext" -d extension=pdo_mysql server\slice\tests\load_concurrency_test.php
```

脚本行为：

1. 校验 `SLICE_CONFIG` 和库名必须是 `test_load`；
2. 跑 `setup_test_db.php --force` + `setup_map12_db.php`；
3. 造 `LOAD_CC`、100 玩家、探针、教师；
4. 启动 8098 + 8108–8116，轮询 `/api/health`；
5. 并发登录 / 取手牌 / 300 出令 / 20 次同 key / 50 轮结算 / 3 次结算中出令；
6. `finally` 里杀全部 API、确认端口释放、删除 `LOAD_CC` 和 `LC*`。

> 脚本在发现已确认竞态时会返回 1（本次 `failed=2, races=2`），这是设计行为，不是脚本崩了。核心断言全部打印为 PASS/FAIL，竞态单独打印 `[RACE]` / `[FIND]`。

### 10.3 清理状态

本次运行后：

```text
8098 / 8108–8116：无监听
test_load：只剩 MAP12_TEST + SLICE_A 两个种子局
            LC* 学生 0，LOAD_CC 0，压测临时行 0
qingzhu_slice_test / test_api 等：未触碰
```

`config.load.php` 含本地测试口令；仓库 `.gitignore` 已包含 `server/slice/config.load.php`，无需再改。本次未修改 `.gitignore`。

---

## 11. 交付文件

| 文件 | 作用 |
|---|---|
| `server/slice/config.load.php` | 隔离库 `test_load` 配置；关闭限流仅用于压测 |
| `server/slice/tests/load_concurrency_test.php` | 100 人 / 300 令 / 同 key 20 次 / 50 轮教师并发结算 / 结算中出令 |
| `LOAD_CONCURRENCY_REPORT.md` | 本报告 |

未修改 `server/slice/src/`、`schema.sql`、`migrations/`、现有测试；未 commit / push。

---

## 12. 附：最终运行关键 JSON（节选，`late_order.attempts` 已简化）

```json
{
  "players": 100,
  "play_requests": 300,
  "play_ok": 300,
  "play_ms": {"p50": 203.2, "p95": 433.1, "max": 479.4},
  "active_orders": 300,
  "idempotent_rows": 1,
  "same_key_cross_slot_rows": 2,
  "settle_baseline_ms": 203.0,
  "settle_baseline": {
    "battles": 6, "battle_nodes": 6, "max_battles_per_node": 1,
    "merit_rows": 256, "merit_sum": 2636,
    "node_changes": 6, "turn_results": 1,
    "turn_status": "settled", "game_status": "running"
  },
  "settle_rounds": {
    "rounds": 50, "real_success": 50, "already": 10, "busy": 56,
    "other": 0, "double_real": 0, "battle_dup": 0, "merit_dup": 0,
    "battle_mismatch": 0, "merit_mismatch": 0,
    "game_bad": 0, "turn_result_bad": 0
  },
  "settle_ms_by_kind": {
    "real":    {"p50": 189.7, "p95": 212.8, "max": 217.0},
    "busy":    {"p50": 18.7,  "p95": 34.9,  "max": 42.6},
    "already": {"p50": 18.2,  "p95": 34.5,  "max": 34.5}
  },
  "hand_race": {
    "codes": {"200": 79, "500": 1},
    "error": "SQLSTATE[23000]: Integrity constraint violation: 1062 Duplicate entry '3-119' for key 'uk_hand_turn_player'",
    "hand_rows": 1
  },
  "late_order": {
    "attempts": 3,
    "confirmed": 3,
    "detail": "play=200, turn=settled, order=active, merit=0, not in battle players"
  }
}
```

---

## 13. 最终判定

| 检查项 | 结果 |
|---|---|
| 100 人 × 3 令并发提交 | **PASS**（300/300，300 条 active，无重复） |
| 同一 request_key 20 次同 slot | **PASS**（1 条） |
| request_key 真幂等 | **FAIL**（同 key 跨 slot → 2 条；`slice_order_requests` 未使用） |
| 教师并发结算只成功一次 | **PASS（实测 250 轮）**；代码仍有 TOCTOU 风险 |
| `slice_battles` 不重复 | **PASS（实测）** |
| `slice_merit_events` 不翻倍 | **PASS（实测）** |
| `slice_games` / `slice_turn_results` 状态 | **PASS（实测）** |
| 手牌并发创建 | **FAIL**（1062 → 500，1–2/80，偶发） |
| 结算中出令不丢失 | **FAIL**（3/3 返回 200 但未结算） |

**总判定：不建议直接上 100 人真实试跑；先修 P0-1（结算抢占 turn）和 P0-2（手牌幂等），再跑本脚本确认 `FAIL` 归零。**
