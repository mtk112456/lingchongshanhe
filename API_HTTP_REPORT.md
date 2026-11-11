# 12+1 城城主流程 · HTTP 集成测试报告

- 日期：2026-11-11
- 被测入口：`server/slice/public/index.php`（PHP 内置服务器 `127.0.0.1:8099`）
- 隔离库：`test_api` @ `127.0.0.1:3307`，用户 `qingzhu_test`
- 测试脚本：`server/slice/tests/api_http_test.php`
- 最终结果：**23 / 23 通过，0 失败，总耗时 3.52 s**
- 约束：未使用 8080 / 8081；未读写 `qingzhu_slice_test`、`qingzhu_slice_trial`、`test_merit`、`test_sim`、`test_perf`；未改业务代码 / schema / 现有测试；未 commit / push。

---

## 1. 隔离与前置

### 1.1 端口 / 数据库边界

| 资源 | 测试使用 | 说明 |
|---|---|---|
| HTTP | `127.0.0.1:8099` | 测试脚本自行启动、结束自行杀掉；启动前若 8099 被占用会拒绝运行，不杀未知进程 |
| 数据库 | `test_api` | 由 `server/slice/config.api.php` 指定；默认每次运行先 `setup_test_db.php` + `setup_map12_db.php` |
| 未触碰 | 8080 / 8081 / 3306 / 3307 上其他库 | 测试前后 8080、8081 原进程保持监听；8099 测试后无监听 |

### 1.2 一次性授权（已在本机执行）

`qingzhu_test` 原本只有 `qingzhu_slice_test` / `qingzhu_slice_trial` 权限，且不能建库。用本机 MariaDB root 执行：

```sql
CREATE DATABASE IF NOT EXISTS test_api
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON test_api.* TO 'qingzhu_test'@'127.0.0.1';
FLUSH PRIVILEGES;
```

> 换机器 / 重建 MariaDB 后需要重跑这段。`setup_test_db.php` 不会建库。

### 1.3 配置文件

`server/slice/config.api.php`：

- host `127.0.0.1`，port `3307`，db `test_api`
- user `qingzhu_test` / pass `slice_dev_only_2026`
- `log_path = logs/api-http-test.log`
- 仅测试开关：`allow_fault_injection` / `allow_force_lock` / `expose_error_details` 均为 true

**主线程待办：把 `server/slice/config.api.php` 加入 `.gitignore`。** 本次按“只新建 3 个文件”的约束没有改 `.gitignore`，该文件目前是 untracked，内含本地测试口令，不要提交。

### 1.4 无 curl 依赖

本机 PHP 8.4.25 未启用 curl 扩展（`php -m` 无 curl）。测试全部用：

```php
file_get_contents($url, false, stream_context_create([...]))
```

`ignore_errors => true` 保留 4xx/5xx 响应体，便于断言错误码。

---

## 2. 运行命令

```powershell
cd D:\DeskBox\游戏\server\slice

$php = "C:\Users\MTK\AppData\Local\Microsoft\WinGet\Packages\PHP.PHP.8.4_Microsoft.Winget.Source_8wekyb3d8bbwe\php.exe"
$ext = "C:\Users\MTK\AppData\Local\Microsoft\WinGet\Packages\PHP.PHP.8.4_Microsoft.Winget.Source_8wekyb3d8bbwe\ext"

& $php -d "extension_dir=$ext" -d extension=pdo_mysql tests\api_http_test.php
```

可选参数：

```powershell
# 保留当前 test_api 数据，不重跑 setup
& $php -d "extension_dir=$ext" -d extension=pdo_mysql tests\api_http_test.php --skip-setup
```

> `--skip-setup` 只适合排查单步；如果库里的回合已经结算，测试会按预期在出令/状态断言处失败，因为默认流程不会自动重置回合。

脚本行为：

1. 检查 `config.api.php`、router 与 8099 是否空闲；
2. `SLICE_CONFIG` 指向 `config.api.php`；
3. 跑 `scripts/setup_test_db.php`、`scripts/setup_map12_db.php`；
4. 启动 `php -S 127.0.0.1:8099 -t public public/index.php`；
5. 轮询 `/api/health` 直到就绪（最多 20 s）；
6. 顺序跑 23 个测试步骤；
7. `proc_terminate` 杀服务器，并轮询确认 8099 已释放。

---

## 3. 每步结果与耗时

以下为最终一次运行的实录（第二次运行；第一次见“失败点”）。

| # | 步骤 | HTTP | 耗时 |
|---:|---|---|---:|
| 01 | 重置 test_api（`setup_test_db` + `setup_map12_db`） | cli:0, cli:0 | 807.5 ms |
| 02 | 启动 127.0.0.1:8099 并做健康检查 | 200 | 535.5 ms |
| 03 | 学生登录（青竹一 / MAP12_TEST） | 200 | 223.8 ms |
| 04 | GET state（13 城 / reachable / bulletin / merit / estate） | 200 | 47.4 ms |
| 05 | 教师 admin-login（teacher） | 200 | 205.5 ms |
| 06 | POST admin/resume（确保 running） | 200 | 20.4 ms |
| 07 | GET state 复核（can_edit=true） | 200 | 60.7 ms |
| 08 | GET hand（4 张 / changes_allowed / orders 空） | 200 | 21.0 ms |
| 09 | POST composition（changes_allowed） | 200 | 22.9 ms |
| 10 | POST hand/redraw（redraw_used） | 200 | 42.5 ms |
| 11 | POST bulletin（选择 scout） | 200, 200 | 85.0 ms |
| 12 | POST order/play × 3（目标汉中） | 200, 200, 200, 200 | 124.9 ms |
| 13 | POST battle/forecast（ready=true / advice） | 200 | 27.6 ms |
| 14 | POST admin/card-settle（教师） | 200 | 33.8 ms |
| 15 | GET me/report（orders / merit / highlight） | 200 | 51.8 ms |
| 16 | GET report（卡牌战报） | 200 | 43.1 ms |
| 17 | GET replay（卡牌战报 changes） | 200 | 37.5 ms |
| 18 | GET estate（军功余额 / 房间） | 200 | 35.9 ms |
| 19 | POST estate/upgrade（200 或 409 均算通过） | 409 | 34.4 ms |
| 20 | GET season（4 阵营 / 长安 / 周次） | 200 | 43.5 ms |
| 21 | GET season/history（第 1 周） | 200 | 26.7 ms |
| 22 | 负例：结算后 order/play → TURN_NOT_OPEN | 409 | 21.1 ms |
| 23 | 负例：学生调 battle/settle → 403 | 403 | 37.9 ms |

汇总：

```text
结果：通过 23 / 23，失败 0，总耗时 3.52 s
服务已停止，8099 已释放。
```

> 耗时为本机冷启动（含每次重建库与启动服务器）的实测值，仅供回归对比；不同机器/磁盘会有波动。

---

## 4. 关键断言明细

### 4.1 state 与 13 城

- `data.game.code = MAP12_TEST`
- `data.map.nodes` 13 个，`data.map.edges` 19 条
- `data.reachable_targets` 同时包含 `hanzhong`、`taiyuan`
- `data.bulletin.options` 2 个（二选一）
- `data.merit.total = 0`
- `data.estate.rooms` 3 个，`home_node.code = liangzhou`
- `data.hand.cards` 4 张
- 本次 seed 局为 `paused`：`can_edit=false`、`edit_block_reason=GAME_PAUSED`；测试对 `paused/running` 两种初始状态都兼容，随后统一 `admin/resume` 到 running

### 4.2 手牌 / 编成 / 邸报 / 出令

- `GET hand`：4 张互不重复，`composition.changes_allowed >= 1`，本回合 `orders=[]`
- `POST composition`：`types=[cav,shield,arc]` 落库，返回 `changes_allowed`
- `POST hand/redraw`：`redraw_used=true`，重抽后仍 4 张
- `POST bulletin`：从邸报实际选项中选一个，返回 `choice` 与提交值一致
- `POST order/play ×3`：分别落 slot 0/1/2，目标均为汉中；再查 hand 可见 3 条令
- 出令时优先选队伍牌（`night_raid / forced_march / fortify / ...`），保证 forecast 至少有一支先锋队；火攻、哨探、疑兵不占队伍位

### 4.3 战前预估与结算

- `POST battle/forecast`：`ready=true`、`role=attack`、`advice` 非空、`attacker.teams >= 1`
- `POST admin/card-settle`：`already_settled=false`，至少 1 场战斗，汉中战斗 `battle_id > 0`
- 本次战斗实录：`hanzhong`，`score=0`、`wall=1015.6`（未破城，因此没有 `assault` 军功）

### 4.4 个人战报 / 战报 / 回放

- `GET me/report`：`orders=3`、`merit.turn_total >= 5`、`highlight` 非空、`battles_joined >= 1`、`turn_no=1`
- `GET report`：`turn.status=settled`、`report.mode=cards`、`report.battles >= 1`、`me.merit.turn_total >= 5`
- `GET replay`：有已结算回合；`changes` 非空且包含 `hanzhong`；每条 change 带 `changed` 字段

### 4.5 小院 / 赛季

- `GET estate`：3 个房间，home=`liangzhou`，`merit_balance = merit_total - merit_spent`，书房 `next_cost=30`
- `POST estate/upgrade`：本次走 **409 `ESTATE_INSUFFICIENT_MERIT`** 分支
  - 本轮军功：`participation 5 + vanguard 20 = 25`
  - 升级书房需要 30，`gap=5`，属于任务允许的正确分支
- `GET season`：`game=MAP12_TEST`、`week=1`、4 个阵营、长安节点存在、`season_over=false`、阵营城数 + 中立城数 = 13
- `GET season/history`：`current_week=1`、第 1 周 `battles>=1`、`standings` 5 行（4 阵营 + 中立）

### 4.6 负例

- 结算后 `POST /api/slice/order/play` → **409 `TURN_NOT_OPEN`**，`details.turn_status=settled`
- 学生 token 调 `POST /api/slice/battle/settle` → **403 `FORBIDDEN`**

---

## 5. 失败点与需要主线程处理的地方

### 5.1 第一次运行：22/23，测试自身断言 bug（已修复）

- 失败步骤：`07 GET state 复核（can_edit=true）`
- 现象：接口实际返回 `edit_block_reason: null`，但测试写成
  `($data['edit_block_reason'] ?? 'x') === null`；PHP 的 `??` 把 `null` 当成“缺失”，误判为 `'x'`。
- 处理：改为 `array_key_exists('edit_block_reason', $data) && $data['edit_block_reason'] === null`。
- 修复后重跑：**23/23 通过**。产品接口无问题。

### 5.2 需要主线程处理

1. **`.gitignore` 加 `server/slice/config.api.php`**
   - 该文件含本地测试口令，目前 untracked。
   - 本次受“只新建 3 个文件”约束，没有直接改 `.gitignore`。

2. **一次性建库 + 授权**
   - `qingzhu_test` 没有 `CREATE DATABASE` 权限，`test_api` 必须由 root 建库并授权（SQL 见 1.2）。
   - 建议写入部署/测试 README，避免新机器直接跑测试失败。

3. **12+1 种子局是 `paused`，且登录必须带 `game_code`**
   - `seed_map12.sql` 把 `MAP12_TEST` 设为 `paused`，所以测试在出令前显式调用了
     `POST /api/slice/admin/resume`；否则 `order/play` / `hand/redraw` 会返回 `GAME_PAUSED`。
   - 同一个测试库里还有 `SLICE_A`（`running`）。`loginStudent` 的排序是
     `FIELD(g.status,"running","paused","finished","draft")`，因此**学生 / 教师登录若不传
     `game_code=MAP12_TEST`，会命中 `SLICE_A` 而不是 12+1 城**。
   - 这是真实客户端联调的高风险点：12+1 城主流程的所有登录请求都必须带
     `game_code: "MAP12_TEST"`。

4. **小院升级在首回合通常只能走 409 分支**
   - 本次首回合军功 25（出令 5 + 先锋 20），书房升级要 30；战斗 `score=0` 没拿到 `assault`。
   - 任务允许 409，因此测试通过。若产品希望“首回合就能升级一次”作为正反馈，需要调整军功额度/升级成本，或在测试种子中预置军功；否则成功分支只能靠后续回合或更强战斗覆盖。

5. **运行后 `test_api` 停留在已结算状态**
   - 这是测试数据，不是缺陷；默认下次运行会重建库。使用 `--skip-setup` 时需自行接受该状态。

---

## 6. 交付文件

| 文件 | 作用 |
|---|---|
| `server/slice/config.api.php` | 隔离库配置（`test_api` / 3307 / `qingzhu_test`） |
| `server/slice/tests/api_http_test.php` | 23 步真实 HTTP 集成测试；自管 8099 与建库脚本 |
| `API_HTTP_REPORT.md` | 本报告 |

未修改 `server/slice/src/`、`schema.sql`、`migrations/`、现有测试；未 commit / push。
