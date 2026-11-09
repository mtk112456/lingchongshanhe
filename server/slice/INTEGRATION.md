# 与现有班级量化系统对接说明

> 适用：里程碑 A（三回合切片）  
> 原则：**不复制学生账号、不复制班宠、不把积分搬进游戏库；游戏只读写必要的现有表。**

---

## 1. 结论先看

| 数据 | 来源/去向 | 游戏是否写入 |
|---|---|---|
| 学生身份、显示名、班级、当前分数 | `students` | ❌ 只读 |
| 学生登录密码 | `students.password` | ❌ 只读校验 |
| 教师身份 | `admin` | ❌ 只读校验 |
| 班宠实例、昵称、等级、饱食度 | `student_pets` | ❌ 只读 |
| 班宠模板、四维、稀有度 | `pet_templates` | ❌ 只读 |
| 可用积分 | `students.score` + `shop_orders` | ❌ 不修改 `students.score` |
| 积分兑换订单 | `shop_orders`（`type='game_recharge'`） | ✅ 只追加订单 |
| 文玉钱包 | `game_wallets` / `game_wallet_transactions` | ✅ 游戏新增表 |
| 兑换幂等 | `game_recharge_requests` | ✅ 游戏新增表 |
| 切片战局 | `slice_*` | ✅ 游戏新增表 |

**红线：**

1. 不改 `students.score`；
2. 不改 `student_pets` / `pet_templates` / 技能 / 法宝；
3. 不把真实学生数据复制进测试库；
4. 不在生产库执行 `legacy_schema.sql` / `legacy_seed.sql` / `schema.sql`。

---

## 2. 登录对接

### 学生登录

`POST /api/auth/login`

```json
{"name":"青竹一","password":"slice2026","game_code":"SLICE_A"}
```

- 按 `students.name` 或 `students.show_name` 查找；同名时优先 `show_name` 精确匹配，否则要求带序号显示名；
- 用 `password_verify()` 校验 `students.password`；
- 在 `slice_players` 中查 `student_id` 对应的本局试验成员；
- 查 `student_pets`：没有班宠返回 `PET_REQUIRED`；
- 只返回本局 Bearer Token，不影响现有网页 Session / Remember Cookie。

### 教师登录

`POST /api/auth/admin-login`

```json
{"username":"teacher","password":"teacher2026"}
```

- 按 `admin.username` 查找并校验 `admin.password`；
- 在 `slice_players` 中查 `admin_id` 对应的教师成员；
- 教师只能锁令、结算、看状态，不能下军令。

### 测试账号

测试库镜像数据（仅测试）：

- 学生：`青竹一` / `slice2026`（另有青竹二~四、墨点一~四）
- 教师：`teacher` / `teacher2026`

正式接入时，学生用自己现有班级系统密码；教师用现有管理员账号。

---

## 3. 积分对接

### 3.1 可用积分公式（与现有商城一致）

```text
gross_net = max(0, students.score - 100)
spent     = SUM(shop_orders.points_spent) WHERE student_id=? AND status != 'cancelled'
available = max(0, gross_net - spent)
```

### 3.2 兑换规则

- 1 可用积分 = 10 文玉；
- 每人每日最多兑换 20 积分；
- 单次 1–20 积分；
- 只写 `shop_orders`，`type='game_recharge'`；
- `students.score` 永远不变；
- 订单 `status='completed'`，`finish_time=NOW()`，因为文玉是即时到账的虚拟物品；
- 订单写入与 `game_wallets` 加玉在同一事务内；
- `game_recharge_requests` 用 `(student_id, request_key)` 唯一键保证重复请求不重复扣分。

### 3.3 生产库迁移

先确认现有 `shop_orders.type` 的实际枚举值，再执行：

```sql
-- server/slice/migrations/001_shop_orders_game_recharge.sql
ALTER TABLE `shop_orders`
  MODIFY COLUMN `type` ENUM('goods','blind_box','game_recharge')
  DEFAULT 'goods' COMMENT '兑换类型';
```

```sql
-- server/slice/migrations/002_apply_points_schema.sql
-- 新增 game_wallets / game_wallet_transactions / game_recharge_requests
```

> `001` 会重建列定义；如果生产库的 `type` 已有其他枚举值，必须把它们一起写进 ENUM，否则会被截断。执行前备份，先在测试库演练。

### 3.4 测试镜像

`legacy_schema.sql` 按现有系统的关键列建镜像表，`legacy_seed.sql` 插入 8 名试验学生、8 只班宠、1 名教师。  
镜像表只用于测试；生产环境直接使用现有表。

---

## 4. 班宠对接

切片阶段只读：

```sql
SELECT sp.id, sp.nickname, sp.level, sp.hunger, sp.current_exp,
       pt.code, pt.name, pt.element, pt.rarity,
       pt.base_hp, pt.base_atk, pt.base_def, pt.base_spd
FROM student_pets sp
JOIN pet_templates pt ON pt.id = sp.pet_template_id
WHERE sp.student_id = ?
```

- 战报显示班宠昵称与模板；
- 切片统一 1000 兵力、关闭技能/法宝，避免等级/饱食度形成压倒性优势；
- 正式 B 阶段再接 `PetHelper::calcPetUnifiedPower()` / `PetBattleEngine::fight()`，并且只读班宠数据。

---

## 5. 游戏新增表

### 切片表

- `slice_games` / `slice_factions` / `slice_nodes` / `slice_edges`
- `slice_players`（`student_id` 或 `admin_id`，不存密码）
- `slice_sessions`（Bearer Token）
- `slice_turns` / `slice_orders` / `slice_order_requests`
- `slice_snapshots` / `slice_snapshot_orders`
- `slice_turn_results` / `slice_node_changes` / `slice_player_reports`
- `slice_settlement_jobs` / `slice_audit_log`

### 积分/钱包表

- `game_wallets`：学生文玉余额，跨赛季保留；
- `game_wallet_transactions`：每次加玉流水；
- `game_recharge_requests`：兑换幂等键。

---

## 6. 接口清单

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/api/health` | 健康检查 |
| POST | `/api/auth/login` | 学生登录（现有 students） |
| POST | `/api/auth/admin-login` | 教师登录（现有 admin） |
| POST | `/api/auth/logout` | 注销 Bearer Token |
| GET | `/api/slice/state` | 回合、地图、己方军令、钱包、合法目标 |
| POST | `/api/slice/orders` | 提交/改写军令（幂等键） |
| POST | `/api/slice/orders/withdraw` | 撤回军令 |
| GET | `/api/slice/report?turn_id=` | 战报 + 个人复盘 |
| GET | `/api/slice/replay` | 战局回放：逐回合归属快照与变化 |
| GET | `/api/slice/history` | 历史回合 |
| GET | `/api/slice/wallet` | 可用积分/文玉/日上限 |
| POST | `/api/slice/recharge` | 积分兑换文玉（只写 shop_orders） |
| GET | `/api/slice/admin/status` | 教师查看回合/任务状态 |
| POST | `/api/slice/admin/lock` | 锁令 + 只读快照 |
| POST | `/api/slice/admin/settle` | 结算（失败可重试） |
| POST | `/api/slice/admin/next-turn` | 下一回合 |
| POST | `/api/slice/admin/pause` / `resume` | 暂停/恢复 |

所有写接口带 `turn_id` + `request_key`；重复请求返回已确认结果，不同内容返回 `IDEMPOTENCY_CONFLICT`。

---

## 7. 21:00 定时任务

```bash
php server/slice/scripts/cron.php
```

- 找到 `deadline_at <= 当前北京时间` 且 `games.status='running'` 的 `open/locked/failed` 回合；
- 对 `open` 回合先锁令并生成快照；
- 对 `locked/failed` 回合结算；
- 结算使用同一快照重试，结果/战报/回合状态一次提交；
- 重复执行是幂等的（已结算回合不再处理）。

建议每 1 分钟执行一次，或 20:59 / 21:00 / 21:05 各执行一次。  
`next-turn` 不自动执行；由教师确认后进入下一回合，避免失败时自动推进。

---

## 8. 本地测试环境

```powershell
# 1. 便携 MariaDB（端口 3307，仅本机）
pwsh server/slice/start_mariadb.ps1

# 2. 建测试库 + 镜像现有表 + 种子
pwsh server/slice/setup.ps1

# 3. 启 API（0.0.0.0:8080）
pwsh server/slice/start_api.ps1

# 4. 验收
php -d extension_dir="<php>\ext" -d extension=pdo_mysql server/slice/tests/run.php
```

Android 真机联调：

```bash
adb reverse tcp:8080 tcp:8080
# 登录页点“本机转发 127.0.0.1”
```

或让平板与电脑在同一局域网，登录页填电脑局域网 IP。

---

## 9. 数据安全

- 测试库名 `qingzhu_slice_test`，端口 3307，不连接生产库；
- 测试学生均为“试验…”昵称；
- 交接包不包含真实学生数据、数据库密码、服务器凭据；
- `config.local.php` 只存在本机，不放入交接包；
- 正式上线前另做隐私、账号、地图审图号、教师后台权限评估。
