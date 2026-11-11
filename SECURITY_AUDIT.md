# SECURITY_AUDIT.md · `server/slice` 安全与健壮性审计

- 审计日期：2026-11-11
- 审计范围：`server/slice`（`public/index.php`、`src/*.php`、`scripts/*.php`、`config.*.php`、`schema.sql` / `legacy_schema.sql`），以及 `deploy/lingchong`、`deploy/teacher-web` 中与本服务直接相关的配置
- 审计方式：只读代码审计 + `php -l` 语法检查 + 本地确定性战斗计算；**未启动服务、未连接数据库、未修改代码、未提交**
- 审计快照：2026-11-11 当前工作区；审计过程中 `HandService.php`/`SliceService.php` 等已有其他 Agent 的未提交改动，行号以本报告落盘时为准。**S-02 已按最新工作区标为“已修复（待回归）”**，其初稿证据保留在对照说明中。
- 结论：**18 项**（严重 1 / 高 2 / 中 7 / 低 6 / 信息 1 / 已修复 1）

> 说明：本报告只列有明确代码证据、可复现或可沿代码路径推导的问题。标注“条件”的条目依赖试跑库默认配置或运维误操作，不代表当前生产配置一定命中，但代码路径真实存在。

---

## 1. 结论摘要

最危险的三条：

1. **任何学生都能绕过“下令 → 锁令 → 教师结算”，直接改地图归属。** `POST /api/slice/battle/demo` 会落一条战斗记录，`POST /api/slice/battle/settle` 会把该战果直接写入 `slice_nodes` 与 `slice_node_changes`；接口只校验“战斗属于本局”，不校验调用者是否是该战斗的参与者、回合是否锁定、目标是否为起点，也没有“同一场战斗只能结算一次”的幂等约束。同一 `battle_id` 可反复结算，直到把任意城（含敌方起点）刷成自己阵营。还会因 `slice_node_changes` 唯一键冲突，让教师之后的正式结算永久失败。
2. **默认口令公开且全员共用，登录无速率限制（S-03/S-09）。** API 根路径直接写“学生账号 … / `slice2026`”；教师页预填 `teacher`、占位符 `teacher2026`；`legacy_seed.sql` 与试跑手册也公开同一组口令。再加上 `Access-Control-Allow-Origin: *` 和零登录限速，任何能访问 API 的人都能冒名学生或教师。
3. **卡牌结算不是事务，军功是累加（S-05）；另有生产库误删风险（S-04）。** 结算中途失败后重试会重复发 `participation +5`、重复推民心；`setup_test_db.php` 又可以直接在 `class_manager` 上执行 `DROP TABLE students/admin/shop_orders`。这两条都不需要高深攻击，一次重试或一次误操作即可触发。

---

## 2. 问题清单

| ID | 严重度 | 位置（file:line） | 问题 | 利用方式 | 修复建议 |
|---|---|---|---|---|---|
| **S-01** | **严重** | `server/slice/public/index.php:484-547`（demo）、`:559-574`（settle）<br>`server/slice/src/BattleSettlementService.php:37-77`、`:90-111`<br>`server/slice/src/BattleService.php:105-141`<br>`server/slice/schema.sql:248`<br>`client/Slice.gd:1849`、`:4577-4604` | 任何已登录学生可创建“演示战斗”并结算，直接改 `slice_nodes` 归属/民心；无参与者校验、无回合状态/截止校验、无起点保护、无“一场只能结算一次”的幂等约束；`apply()` 用 `ON DUPLICATE KEY UPDATE` 覆盖 `slice_node_changes`，而正式 `settleTurn()` 用普通 `INSERT` 写同一唯一键 `(turn_id,node_code)` | ① 学生登录后 `GET /api/slice/state` 取当前 `turn.id` 与节点 code；② 把本周编成改为 `shield,shield,spear` 等克制固定守军的组合（以 `pet_bamboo_01`、general=def 为例），`POST /api/slice/battle/demo {turn_id, node_code:"B_START", fire:true}`；本地计算该组合对 1320 固定守军 `score=1`（`wall≈718.9`）；③ 对同一 `battle_id` 连续 `POST /api/slice/battle/settle` 两次，民心 0→1→2 触发易主；若 `score=2` 一次即易主；`king` 城重复 5 次；④ 同一 `turn_id` 下任意节点都留下 `slice_node_changes` 行，教师之后 `/api/slice/admin/settle` 在 `SliceService.php:1438-1447` 普通 INSERT 时触发唯一键冲突，回合被标记 failed，cron 每分钟重试仍失败；⑤ 传另一局的 `turn_id` 给 demo，`saveBattle()` 不校验回合归属，`/battle/settle` 又只校验 `battle.game_id`，可把 `(turn_id=B,node)` 的变更行写进 A 局并撞掉 B 局结算 | 演示战斗改为只读（只返回日志，不落 `slice_battles`、不调 `apply`）；若必须保留“演武改地图”，只允许教师调用，并校验参与者、回合 `locked`、目标非 `start`、游戏 `running`；新增 `battle_settlements(battle_id UNIQUE)` 或 `slice_battles.settled_at`，同一 battle 只允许 apply 一次；`settleTurn()` 的 `slice_node_changes` 改为 `INSERT ... ON DUPLICATE KEY UPDATE` 或先删后写；所有地图写入记 `slice_audit_log`（含 player_id/来源 IP） |
| **S-02** | **已修复（工作区，待回归；原高）** | `server/slice/src/HandService.php:96-98`、`:165-167`、`:216-218`、`:317-350`<br>`server/slice/src/CardSettlementService.php:73-85`<br>`server/slice/src/BulletinService.php:78-92`<br>`server/slice/src/HandService.php:33-57` | 审计初稿时 `play/withdraw/redraw` 不校验游戏状态、回合状态、截止时间，也不校验 `turn_id` 属于玩家所在局；**审计过程中工作区已新增 `assertTurnEditable()`**：校验回合存在、`game_id` 匹配、玩家属于该局、`game.status='running'`、`turn.status='open'`、未过截止。核心问题已闭合。残留：`CardSettlementService` 的 slot 查询仍只按 `turn_id`、不按 `game_id`（防御纵深）；`BulletinService::choose()` 和 `getOrCreateHand()` 仍可对任意 `turn_id` 建行（当前只影响自己的数据，低风险）；`assertTurnEditable()` 未限制 `role='player'`（教师可出牌，教师本身可信） | 回归：锁令/结算后 `POST /api/slice/order/play` 应 409 `TURN_NOT_OPEN`；外局 `turn_id` 应 403 `WRONG_GAME`；跑新增的 `tests/turn_guard_test.php`。若回归通过，本项关闭 | 卡结算所有 slot 查询补 `o.game_id = ?`；公告/手牌同样校验 `turn_id` 归属；`assertTurnEditable()` 增加 `role='player'` 条件（若教师不应出牌） |
| **S-03** | **高** | `server/slice/public/index.php:46`<br>`server/slice/public/teacher.html:93-97`<br>`server/slice/legacy_seed.sql:2`、`:12-17`、`:20-21`<br>`server/slice/src/SliceService.php:261-361`<br>`server/slice/public/index.php:51-54`<br>`TRIAL_RUNBOOK.md:143-144`、`DEPLOY_RUNBOOK.md:134-135` | 试跑默认口令公开且全员共用：8 名学生共用 `slice2026` 的同一 bcrypt hash，管理员 `teacher/teacher2026` 在种子文件、教师页占位符和手册中公开；`/teacher` 与 `/` 公网可达；登录接口无失败计数、无锁定、无验证码；CORS 为 `*`，任意网站可读取登录响应中的 token | ① 打开 `GET /` 直接看到学生口令；打开 `/teacher` 看到用户名预填 `teacher`、密码占位符 `teacher2026`；② `POST /api/auth/login {"name":"青竹二","password":"slice2026"}` 即可冒名任意学生（口令相同）；③ 若试跑库沿用 `legacy_seed.sql`，`POST /api/auth/admin-login {"username":"teacher","password":"teacher2026"}` 直接拿教师 token，可锁令/结算/下一回合/强制失败；④ 恶意网页因 `Access-Control-Allow-Origin: *` 可跨站发起登录并读取 token；⑤ 无速率限制，可对全部姓名穷举 | 真实学生每人独立随机口令并强制首登修改；从 `/`、教师页、seed、手册删除真实口令；禁用/重命名默认 `teacher`，教师控制台放到 SSO/内网/IP allowlist 后；登录加 IP+账号双维度限速、失败锁定、审计；CORS 改为 App 实际 origin 白名单，不使用 `*` |
| **S-04** | **高** | `server/slice/scripts/setup_test_db.php:19-32`<br>`server/slice/schema.sql:9-35`<br>`server/slice/legacy_schema.sql:9-17`<br>`server/slice/Dockerfile`（`deploy/lingchong/Dockerfile:63-65`）<br>`deploy/lingchong/compose.existing-db.yml:12-13` | 破坏性初始化脚本没有库名/环境保护，直接执行 `legacy_schema.sql` + `schema.sql`；两者开头是 `DROP TABLE students/admin/shop_orders` 和全部 `slice_*` 表。生产镜像又把 `scripts/`、`schema.sql`、`legacy_schema.sql` 一起 COPY 进去；`compose.existing-db.yml` 明确复用现有教学库（`class_manager`） | 运维误设 `SLICE_CONFIG=config.docker.php`（或 `DB_NAME=class_manager`）后执行 `php scripts/setup_test_db.php` / `docker exec lingchong-api php scripts/setup_test_db.php`，会直接删除生产 `students`、`admin`、`shop_orders` 与全部游戏表；这不是远程漏洞，但一次误操作即触发红线 #7“不在生产库执行 schema.sql/legacy_schema.sql” | 脚本启动时校验 `$config['db']['name']` 必须以 `_test`/`_trial` 结尾，否则拒绝并要求 `--force`；生产镜像不 COPY `scripts/setup_*`、`schema.sql`、`legacy_seed.sql`；迁移只保留 `apply_migration.php`；数据库账号去掉 `DROP` 权限；上线前强制备份 |
| **S-05** | **中** | `server/slice/src/CardSettlementService.php:61-128`、`:88-102`、`:119-123`<br>`server/slice/src/MeritService.php:46-59` | 卡牌结算没有事务：先给所有参与者 `participation +5`，再逐城打、逐城 `apply()`（每次 apply 自己提交），最后才把回合置 `settled`；`slice_merit_events` 的 `ON DUPLICATE KEY UPDATE amount = amount + VALUES(amount)` 是累加，不是幂等覆盖 | 教师 `POST /api/slice/admin/card-settle`，若在“已发 participation、尚未置 settled”之间某城抛错（例如 S-02 带入的未知阵营、DB 错误、S-01 造成的唯一键问题），回合仍是 `open/locked`；教师重试会再次 `+5`，城市军功也重复累加，`apply()` 还会再次推进民心/易主。重试次数越多，军功与地图越失真 | 整个 `settle` 包在一个事务里；用 `slice_settlement_jobs`（或 `(turn_id)` 唯一结算记录）做幂等；`MeritService::award` 改为“按 (turn,player,kind) 只插一次/绝对值覆盖”，或先删本回合该玩家该 kind 再插；只在全部写完后置 `settled` |
| **S-06** | **中** | `server/slice/src/CardSettlementService.php:349-357`、`:393-430`<br>`server/slice/public/index.php:468-482` | `forecast` 即使 `intel_known=false`，仍用真实守军完整跑一遍战斗，并返回精确的 `forecast.score/wall/morale_after/capture_estimate` 与 `counters`（counter key 会暴露守军兵种）；`defender.troops/teams` 被隐藏只是表面 | 学生先对本城出一张任意牌（或蹭同阵营的令），再 `POST /api/slice/battle/forecast {turn_id, node}`；在未派“哨探”的情况下反复读 `forecast.score`、`morale_after`、`capture_estimate`，并可换编成枚举最优解；`counters` 还能反推守军兵种。哨探/斥候体系被绕过 | `intelKnown=false` 时不要用真实守军做精确模拟；只返回区间/未知，或直接要求 scout 才能 forecast；隐藏 `counters`/`counter_damage`；把“是否侦察”作为服务端硬条件，不只控制展示字段 |
| **S-07** | **中** | `server/slice/src/SliceService.php:767`、`:1512-1520`、`:1528-1545`<br>`server/slice/config.trial.php:18`<br>`deploy/teacher-web/api_admin_lingchong.php:134` | 原始异常信息会进入用户可见字段：`markSettlementFailed()` 把 `$e->getMessage()` 写入 `slice_turns.failure_reason`，`turnPublic()` 又把它返回给所有学生；`settleTurn()` 的 `SETTLE_FAILED.details.reason` 同样是原始异常；试跑配置 `expose_error_details=true` 让任意 500 返回 `exception`；教师 Web 代理也直接把 `$e->getMessage()` 回给浏览器 | 触发任意 500（S-01 的唯一键冲突、`types` 嵌套数组、demo 传非法 node_code 等），学生 `GET /api/slice/state` 或 `/history` 就能看到 `Duplicate entry ... for key 'uk_changes_turn_node'`、表名/索引名；试跑环境还能看到完整 SQLSTATE/文件路径。为后续 SQL/结构探测提供信息 | 用户可见字段只放错误码 + 请求 id；原始异常只进服务端日志；`failure_reason` 改为稳定文案；`SETTLE_FAILED.details` 不返回 `reason`；教师代理同样脱敏；生产/试跑都保持 `expose_error_details=false` |
| **S-08** | **中** | `server/slice/public/index.php:402-414`<br>`server/slice/src/EstateService.php:128-196`、`:173-178`<br>`client/Api.gd:255` | 小院升级没有幂等键/期望等级：`FOR UPDATE` 只防止丢失更新，不防止“同一意图提交两次”；客户端只传 `room` | 快速双击/重放两次 `POST /api/slice/estate/upgrade {room:"study"}`；第一次 1→2 扣 30 军功，第二次读到 2 再 2→3 扣 80，共扣 110；玩家只想升一级却连升两级、双倍消耗（军功不足时第二次才会被余额挡住） | 接受 `request_key`（与订单一致）或 `expected_level`；使用条件更新 `UPDATE ... SET level=level+1 WHERE id=? AND level=?`，受影响行数为 0 返回 409；客户端按钮在请求中禁用 |
| **S-09** | **中** | `server/slice/public/index.php:51-54`、`:148-164`、`:484-547`<br>`server/slice/src/SliceService.php:261-361` | 全站没有速率限制/失败计数/锁定：登录、`battle/demo`、`battle/settle`、`recharge` 都可无限调用；CORS 为 `*`；`battle/demo` 每次插一条 `slice_battles`，可被刷爆表 | 脚本对 `/api/auth/login` 按根页公布的姓名 + `slice2026` 批量尝试；或登录后循环 demo 生成海量 `slice_battles`/日志；恶意网页可跨站调用登录并读取 token（无需 cookie） | 在网关（Cloudflare/WAF）和应用层同时限速；登录按 IP+账号计数、指数退避/锁定；`battle/demo` 每玩家每回合限 1 次或直接下线；CORS 白名单；对写接口加请求体大小/频率上限 |
| **S-10** | **中** | `server/slice/src/HandService.php:165-167`、`:356-411`、`:403-450`<br>`server/slice/src/CardSettlementService.php:472-694`（`settleCity` / `apply`）<br>`server/slice/src/BattleSettlementService.php:44-77`<br>对照 `server/slice/src/SliceService.php:1656-1660` | 卡牌路径缺少“起点保护”：`submitOrder` 明确禁止敌方起点，但 `HandService::play` 只检查“存在 + 相邻 + 赛季规则”，`settleCity`/`apply` 也不检查 `node_type='start'`；另外阵营没有任何城时 `assertAdjacentTarget()` 直接放行，任意节点都可被打 | 学生把卡牌目标设为与己方领土相邻的敌方起点（`B_START`/`A_START`），卡结算时 `settleCity` 正常开战，`apply` 在民心满后直接把起点易主；若阵营已丢光所有城，`assertAdjacentTarget()` 在 `$owned===[]` 时 `return`，可对全图任意节点出牌 | 卡牌路径复用 `submitOrder` 的起点/相邻/归属校验；`settleCity` 和 `apply` 对 `node_type='start'` 直接拒绝易主；无领土时只允许“默认驻守”或拒绝出牌，不放开全图 |
| **S-11** | **低** | `server/slice/src/HandService.php:34-58`、`:96-101`、`:190`<br>`server/slice/public/index.php:434`、`:659-688` | 多个正常操作会抛未映射的 `RuntimeException`/`PDOException`/`TypeError`，被兜底成 500：并发首次取手牌 duplicate key；重复重抽 `REDRAW_USED`；第 4 张牌 `PLAY_LIMIT_REACHED`；`types` 里传数组触发 `isset($array[$array])` TypeError | 两个标签页同时 `GET /api/slice/hand` → 500；连点重抽 → 500；出第 4 张牌 → 500；`POST /api/slice/composition {"types":[["x"],"cav","shield"]}` → 500。用户看到“服务器内部错误”，且试跑配置会回显异常 | `getOrCreateHand` 用 `INSERT ... ON DUPLICATE KEY UPDATE id=id` 后重查；业务异常统一用 `ApiException`（409/400）；`setComposition` 先校验每个元素是 scalar string；兜底 catch 不要把 `Throwable` 直接当 500 业务错误 |
| **S-12** | **低** | `server/slice/src/HandService.php:272-308`、`:287-299` | 每周编成修改次数是“先读后写”，没有事务/`FOR UPDATE`；两次并发请求都能通过 `changes_used < allowed` 检查 | 学生同时发两个 `POST /api/slice/composition`（不同 types）；两次都读到 `changes_used=0`、`allowed=1`，`ON DUPLICATE KEY UPDATE changes_used=changes_used+1` 把值写成 2，等于多改一次 | 用事务 + `SELECT ... FOR UPDATE`，或条件更新 `UPDATE ... WHERE changes_used < ?` 并检查 rowCount；把 `changed_once/changes_used` 与实际允许次数在一条 SQL 里原子判断 |
| **S-13** | **低** | `server/slice/src/PointsService.php:149-162`、`:166-178`<br>`server/slice/legacy_schema.sql:68`、`:73`、`:77` | 核销码是“先查不存在再插入”，但 `shop_orders.verify_code` 只有普通索引 `idx_verify_code`，没有 UNIQUE；不同学生并发兑换可能生成同一个 6 位码 | 两名学生在同一秒兑换，双方的 `SELECT ... WHERE verify_code=?` 都查不到，随后各自插入相同 6 位码；概率约 1/10^6/对，但真实存在。后续按核销码核销时可能匹配到错误订单 | 给 `shop_orders.verify_code` 加 UNIQUE（先清理历史重复），插入冲突时重试；或改用更长随机码 + 唯一约束；把“生成 + 插入”放在同一事务/重试循环 |
| **S-14** | **中** | `server/slice/logs/login.json:1`<br>`server/slice/logs/login.out:1`<br>`server/slice/config.sim.php:9`、`:18`（`git status` 显示未跟踪且未被 `.gitignore` 忽略）<br>`server/slice/start_api.ps1:2`<br>`server/slice/config.local.php:16-18`（`allow_fault_injection/allow_force_lock/expose_error_details` 均为 true） | 开发机残留凭据：`logs/login.json` 明文 `slice2026`，`logs/login.out` 含 Bearer token；`config.sim.php` 未忽略且含 DB 密码 + `expose_error_details=true`；`start_api.ps1` 默认绑定 `0.0.0.0`，会把带“异常回显/故障注入/强制锁令”的开发配置暴露到整个局域网 | 拿到开发机/交接包/误提交仓库的人可直接读明文口令/token；同一 Wi-Fi 下任何人访问 `http://<开发机>:8080` 即可用默认教师口令登录并触发故障注入/提前锁令 | 删除 `logs/*.json`、`logs/*.out` 并轮换试跑口令；把 `config.sim.php` 加入 `.gitignore` 或删除；`start_api.ps1` 默认 `127.0.0.1`；开发配置默认关闭 `expose_error_details`/`allow_fault_injection`；交接包排除 `logs/`、`testdb/`、`config.*` |
| **S-15** | **低** | `client/Slice.gd:4807`、`:4787`<br>`server/slice/public/index.php:642-646`<br>`server/slice/src/SliceService.php:2190-2195`、`:1094-1099`<br>`deploy/lingchong/config.docker.php:22` | 教师端客户端与服务端契约不一致：`_teacher_next()` 只发 `{"game_id": ...}`，服务端只读 `from_turn_id ?? turn_id ?? 0`，于是 `loadTurnById(0)` → 404；“锁定”固定发 `force:true`，生产 `allow_force_lock=false` 时必然 403 | 教师在 App 里点“下一回合”永远失败；点“锁定本回合”在生产环境永远 403。功能不可用会被误判为“已完成/已锁定” | 客户端改发 `from_turn_id`（当前 turn id）；服务端可兼容 `game_id`（解析 `current_turn_id`）；`force` 由配置/按钮显式控制，不要硬编码 true |
| **S-16** | **低** | `server/slice/public/index.php:144-146`<br>`server/slice/src/SliceService.php:2377-2387` | `/api/health` 无认证返回 PHP 版本、游戏数量、DB 可达性；`NOT_FOUND` 还会回显 method/path | `curl /api/health` 得到 `PHP 8.4.x` + `games` 数量，辅助指纹识别/版本探测 | 对外只返回 `{"ok":true}`；详细健康检查放内网/带 token；移除 `php` 字段；404 不回显原始 path |
| **S-17** | **低** | `deploy/teacher-web/api_admin_lingchong.php:21-31`、`:97-99`、`:134` | 教师 Web 代理的 CSRF 防护只有 `Origin` 检查：无 Origin 直接放行；比较时只取 `HTTP_HOST` 冒号前的主机名，忽略 scheme/port，且没有 CSRF token | 同一主机另一端口上的页面（或某些不带 Origin 的跨站表单）可向 `api/admin/lingchong.php` 发 POST，借教师后台 cookie 执行 lock/settle/next-turn；异常时还会回显内部错误消息 | 严格校验 `Origin`/`Referer` 的 scheme+host+port，缺失时拒绝；加 CSRF token（双提交/同步 token）；破坏性动作要求二次确认/重新认证；异常只返回通用文案 |
| **S-18** | **信息** | `server/slice/src/CardSettlementService.php:193-195`<br>`server/slice/src/SeasonService.php:74-76`<br>`server/slice/src/MeritService.php:155-166`、`:184-198`<br>`server/slice/scripts/setup_map12_db.php:35-40`<br>`server/slice/scripts/export_trial.php:43` | 少量 SQL 字符串拼接，但参数均为 `int` 强类型或常量白名单：`$turnId`、`$gameId`、`LIMIT` 经 `max/min` 夹紧、`$table` 来自固定数组。**未发现可利用 SQL 注入**；列在这里是为了避免后续把参数改成字符串时变成真漏洞 | 当前不可利用。若未来把 `$turnId/$gameId` 改成 `string`、或把 `$table` 改成用户输入，就会成为注入点 | 统一改为预处理参数（`LIMIT ?` 在 MySQL 原生预处理下也可用，或继续白名单夹紧）；表名/列名只允许常量映射；加静态检查禁止 `query()` 拼接 |

---

## 3. 关键复现链（只读推导，未执行）

### 3.1 S-01：学生直接改地图 + 让结算永久失败

```text
1. 学生登录（默认口令即可）→ token
2. GET /api/slice/state → turn.id、节点 code（如 B_START）
3. POST /api/slice/battle/demo
   {"turn_id": <current>, "node_code": "B_START", "fire": true}
   → data.battle_id
4. 同一 battle_id 连续 POST /api/slice/battle/settle
   {"battle_id": <id>}
   → 每次 BattleSettlementService::apply() 都会推进 morale/易主
5. 重复 3-4 覆盖所有节点
6. 教师 POST /api/slice/admin/settle
   → SliceService.php:1438 普通 INSERT 撞 uk_changes_turn_node
   → 回合 failed；cron 每分钟重试仍失败
```

代码证据链：

- `index.php:524-533` 用请求体里的 `node_code` 保存战斗；没有校验该节点、没有校验回合归属、没有校验调用者是否参战。
- `index.php:559-574` 只校验 `battle.game_id === player.game_id`，没有校验 `turn.status`、没有校验 battle 是否已结算、没有校验调用者。
- `BattleSettlementService.php:64-72` 只要 `after >= cap` 且 `attackerFactionId !== ownerBefore` 就易主；`start` 节点也走同一分支（`cap()` 默认 2）。
- `BattleSettlementService.php:90-111` 对 `slice_node_changes` 做 `ON DUPLICATE KEY UPDATE`；`schema.sql:248` 唯一键是 `(turn_id,node_code)`，不含 `game_id`。
- `SliceService.php:1438-1447` 正式结算用普通 `INSERT` 写同一张表 → 冲突。
- `client/Slice.gd:1849` 的“战斗”按钮 → `:4577` demo → `:4604` 自动 settle，说明该路径不是纯内部测试接口。

本地战斗计算（只调用 `BattleEngine::resolve`，不连服务）：

```text
attacker: general=def, troops=1305.0, composition=cav/shield/arc, fire=true
defender: general=atk, troops=1320.0, composition=shield/spear/arc
→ wall=1042.8, score=0

attacker: general=def, troops=1305.0, composition=shield/shield/spear, fire=false
→ wall=718.9, score=1
```

（上面以 `pet_bamboo_01` 的 general=def 为例；`pet_inkdrop_01` 的 general=tac 可用其他编成/多结算几次，结论不变。）

因此：`score=1` 时同一 battle 结算两次即可把 cap=2 的城从 0 推到 2；`score=2` 时一次即可；`king` cap=5 重复 5 次。

### 3.2 S-02：锁令后改牌 / 跨局写 slot（工作区已修复，待回归）

审计初稿时 `HandService::play/withdraw/redraw` 没有状态/归属校验；当前工作区已在 `HandService.php:317-350` 增加 `assertTurnEditable()`，并在 `play`（`:165-167`）、`withdraw`（`:216-218`）、`redraw`（`:96-98`）入口调用。下面步骤现在应用作**回归用例**，预期全部被拒绝：

```text
1. 教师锁令（turn.status=locked）或回合已 settled
2. POST /api/slice/order/play
   {"turn_id": <locked/settled>, "slot": 0, "card_code": "<手牌>",
    "target_node_code": "<己方城>", "request_key": "<8-64位>"}
   预期：409 TURN_NOT_OPEN（修复前为 200，并会改掉已锁/已结算回合的卡牌）
3. POST /api/slice/order/withdraw {turn_id:<settled>, slot:0}
   预期：409 TURN_NOT_OPEN
4. 跨局：turn_id 用另一局存在的 id
   预期：403 WRONG_GAME（play/redraw）或 403 NOT_IN_GAME（withdraw）
   修复前：assertSeasonTarget 查不到本局回合会直接 return，slot 以 game_id=A、turn_id=B 写入
```

残留（非高危）：`CardSettlementService.php:73-85` 的 slot 查询仍只按 `turn_id`，不按 `game_id`；`BulletinService::choose()` 与 `getOrCreateHand()` 仍可对任意 `turn_id` 建行。由于写入口已收紧，这些目前只影响自己的数据/防御纵深，建议一并补 `game_id` 条件。

### 3.3 S-03：默认口令 + 无速率限制

```text
GET /                      → 页面直接写 “学生账号 … / slice2026”
GET /teacher               → username 预填 teacher，password 占位符 teacher2026
POST /api/auth/login       {"name":"青竹二","password":"slice2026"} → token
POST /api/auth/admin-login {"username":"teacher","password":"teacher2026"} → teacher token（试跑种子库）
```

`legacy_seed.sql:12-17` 的 8 个学生共用同一 bcrypt hash；`:20-21` 的管理员 hash 已本地验证 `password_verify('teacher2026', ...) === true`；学生 hash 已验证 `password_verify('slice2026', ...) === true`。`SliceService.php:260-360` 没有任何失败计数/锁定；`index.php:51-54` 的 `Access-Control-Allow-Origin: *` 让恶意页面可以跨站读取登录响应。

---

## 4. 专项核验结果

### 4.1 认证 / 授权

| 检查项 | 结论 | 证据 |
|---|---|---|
| 学生 token 校验 | 通过 | `SliceService.php:388-405`：`token_hash = sha256(token)` + `expires_at > now` + `is_active=1`；token 32 字节随机，库内只存 hash |
| 教师 token | 通过（同一套 session，role 来自 DB） | `loginAdmin()` 只选 `p.role='teacher'`；`publicPlayer()` 返回 role；无客户端可伪造字段 |
| admin 接口是否都 `requireTeacher` | **通过** | `admin/status` → `SliceService.php:2073`；`admin/lock` → `:1096`；`admin/settle` → `:1351`；`admin/next-turn` → `:2191`；`admin/pause`、`admin/resume` → `:2252`；`admin/card-settle` 在路由层 `index.php:631-633` 校验 |
| 跨游戏读取 | 通过（主要读接口） | `getState` `:426`、`getReport` `:1996`、`lockTurn` `:1104`、`settleTurn` `:1362`、`nextTurn` `:2195` 都调 `assertSameGame()`；`getHistory` 按 `player.game_id`（`:2030-2033`）；`getReplay` 按 `player.game_id`（`:2350`）；`GET /battle` 校验 `battle.game_id` |
| 跨游戏写入 | **不通过（已收敛）** | S-01：demo 的 `turn_id`/`saveBattle`/`battle/settle` 未校验回合归属；S-02 的卡牌路径已在工作区加 `assertTurnEditable()`（待回归）；S-10 仍可打敌方起点/无领土全图出牌 |
| 学生能否调用教师接口 | 通过 | `requireTeacher` 在服务层；`role` 来自 `slice_players`，学生登录只选 `role='player'` |
| 教师能否读学生钱包/积分 | 通过 | `getWalletForPlayer()`/`rechargePlayer()` 在 `student_id===null` 时 403 |

### 4.2 SQL

| 检查项 | 结论 | 证据 |
|---|---|---|
| 用户输入拼接 | 未发现可利用注入 | 所有 `$_GET/$_POST/body` 进入 SQL 前均为 `prepare()+execute()`；`PDO::ATTR_EMULATE_PREPARES=false`（`Db.php:19-21`） |
| `IN` 占位符 | 通过 | 由 `array_fill(0,count($arr),'?')` 生成，值绑定：`SliceService.php:498`、`:685`；`HandService.php:386-387` |
| `LIKE` | 无 | 全库未发现用户可控 `LIKE` |
| 排序字段 | 无用户可控 `ORDER BY` | `ORDER BY` 均为常量；`LIMIT` 由 `max/min` 夹紧：`SliceService.php:2033`、`MeritService.php:166/198` |
| `JSON_EXTRACT` | 通过 | 路径固定 `'$.node_code'`（`EstateService.php:214/216/263`），节点 code 来自服务端写入的 JSON，不是用户拼进 path |
| 字符串拼接 | 有代码异味，但当前不可注入 | S-18：`CardSettlementService.php:193-195`、`SeasonService.php:74-76` 的参数是 `int`；`export_trial.php:43` 是常量表白名单 |
| 二次注入 | 未发现 | 写库值（node_code/nickname/choice）均来自白名单或服务端查询结果；读回时仍走预处理 |

### 4.3 输入校验

| 输入 | 现状 | 结论 |
|---|---|---|
| `turn_id` | 大多数路由 `(int)`，部分服务校验 `>0`；`getState/report` 校验同局 | 读路径通过；卡牌路径已加 `assertTurnEditable()`（S-02 待回归）；`bulletin`/`demo` 仍未校验同局（S-01 及低风险残留） |
| `card_code` | `HandDeck::validatePlay()` 白名单 + 手牌成员 + 重复检查（`HandDeck.php:56-70`） | 通过 |
| `slot` | `0..2`（`HandService.php:147-149`） | 通过 |
| `lane` | `1..3`（`:153-155`） | 通过 |
| `row_pos` | `front/back`（`:156-158`） | 通过 |
| `request_key` | `^[A-Za-z0-9_-]{8,64}$`（`:159-161`、`SliceService.php:798-800`、`PointsService.php:106-108`） | 通过 |
| `room` | `EstateService::ROOMS` 白名单（`:126-128`），`$column` 来自常量 | 通过（无注入） |
| `choice` | `BulletinService::choose()` 对 `summary.options` 白名单（`:80-84`） | 通过 |
| `points` | `1..20`（`PointsService.php:103-105`） | 通过 |
| `week/week_no` | `week` 夹紧 1..4；`week_no` 未夹紧 | 低风险：可写任意 week 的编成行 |
| `types` | 数量=3 + 每项 `isset(BattleEngine::TYPES[$type])`；但 `$type` 为数组时 `isset($array[$array])` 触发 TypeError | 不通过（S-11） |
| `node_code` | `submitOrder` 查 `slice_nodes`；卡牌查存在/相邻；demo 完全不查 | demo 不通过（S-01） |
| 空 body / 非 JSON | `jsonBody()` 抛 `BAD_JSON` 400 | 通过 |

### 4.4 幂等 / 并发

| 场景 | 结论 | 证据 |
|---|---|---|
| `submitOrder` 重复提交 | 通过 | `slice_order_requests` + `(turn_id,player_id,request_key)` 唯一键 + `payload_hash` 比对 + 回合行 `FOR UPDATE`；`:835-946` |
| `withdrawOrder` 重复提交 | 通过 | 同上；`:997-1049` |
| 充值重复提交 | 通过 | `game_recharge_requests` 唯一键 + `students` 行 `FOR UPDATE`；`PointsService.php:119-133` |
| 锁令重复 | 通过 | 回合行 `FOR UPDATE`；`locked/settled` 直接返回 already；`:1105-1118` |
| 结算重复 | 通过 | `slice_settlement_jobs` 状态机 + `settled` 返回已有结果；`:1391-1400` |
| 下一回合重复 | 通过 | `(game_id,turn_no)` 唯一键 + 已存在返回；`:2200-2208` |
| 卡牌结算重复 | **不通过** | 无事务、军功累加、`apply()` 每次提交（S-05） |
| 小院升级双击 | **不通过** | 无 request_key/expected_level（S-08） |
| 编成并发 | **不通过** | 先读后写无锁（S-12） |
| 首次取手牌并发 | **不通过** | `INSERT` 无 `ON DUPLICATE`（S-11） |
| 兑换核销码并发 | **不通过** | 无 UNIQUE（S-13） |

### 4.5 错误泄露

| 检查项 | 结论 | 证据 |
|---|---|---|
| 生产 500 是否回显异常 | 基本通过，但有旁路 | `config.docker.php:23` `expose_error_details=false`；`index.php:671-688` 只返回通用 `INTERNAL`。但 `failure_reason` 被 `turnPublic()` 原样返回（S-07） |
| 日志是否含 token/密码 | 应用日志通过；开发残留不通过 | `slice_log()` 的 `api.error/api.exception` 不含 header/body；但 `logs/login.json`/`login.out` 有明文口令/token（S-14） |
| `SETTLE_FAILED` | 不通过 | `SliceService.php:1504-1513` 把 `$e->getMessage()` 放进 `details.reason` 返回给教师 |
| 试跑配置 | 不通过 | `config.trial.php:18` `expose_error_details=true` |
| 教师 Web 代理 | 不通过 | `api_admin_lingchong.php:134` 直接回显 `$e->getMessage()` |
| 审计日志是否记录敏感值 | 通过 | `audit()` 只记 action/ids/target/request_key，不记 token/密码（`:73-79`） |

### 4.6 速率 / 滥用

| 检查项 | 结论 | 证据 |
|---|---|---|
| 登录爆破 | **无防护** | `loginStudent/loginAdmin` 无失败计数、无锁定、无延迟；`SliceService.php:260-360` |
| 重复提交 | 订单/充值有幂等；demo/升级/编成没有 | S-01/S-08/S-12 |
| 大量请求 | **无全局限速** | 未发现 `rate/throttle/attempt` 逻辑；`battle/demo` 可无限插 `slice_battles` |
| CORS | **过宽** | `index.php:51-54` `Access-Control-Allow-Origin: *`，允许任意站点读取登录响应/token |
| 资源放大 | 存在 | `battle/demo` 每次完整跑战斗 + 写 JSON 日志；可被脚本放大 |

### 4.7 数据红线

| 红线 | 结论 | 证据 |
|---|---|---|
| 不修改 `students.score` | **通过** | 全库未发现 `UPDATE students ... score`；`PointsService.php:9-11` 只读；`tests/run.php:277-284`、`estate_test.php:159` 有回归断言 |
| 积分只追加 `shop_orders` | **通过** | 唯一写 `shop_orders` 的是 `PointsService.php:167` 的 `INSERT`；无 `UPDATE/DELETE shop_orders`；`game_wallets`/`game_wallet_transactions` 是新表，不动学生分数 |
| 试跑/生产配置隔离 | 部分通过 | `config.local.php`/`config.trial.php`/`config.perf.php`/`config.merit.php` 均被 `.gitignore`；`config.docker.php` 从环境变量读；但 S-04 的破坏性脚本/镜像没有库名保护，`compose.existing-db.yml` 可直连生产教学库 |
| 生产库不执行 `schema.sql`/`legacy_*` | 文档要求明确，但代码无强制 | `schema.sql:2`、`legacy_schema.sql:2` 注释；`DEPLOY_RUNBOOK`/`README` 明确；但脚本不拦（S-04） |
| 学生真实数据不进测试库 | 通过（当前） | `legacy_seed.sql` 是“试验青竹/墨点”假数据；`trial_data/`/`trial_results/` 已忽略；`testdb/` 已忽略/已 dockerignore |

### 4.8 文件 / 部署

| 检查项 | 结论 | 证据 |
|---|---|---|
| `.env` 是否提交 | 通过 | 根 `.gitignore` + `deploy/lingchong/.gitignore`；仓库无 `.env`，只有 `.env.example` 占位符 |
| `config.local.php`/`config.trial.php` | 通过（未跟踪） | `git check-ignore` 命中；`config.sim.php` 是例外（S-14） |
| Docker 端口 | 通过 | `docker-compose.yml:75` API 绑 `127.0.0.1`；db 无 `ports`（`:49` 注释明确） |
| 生产错误显示 | 通过 | `Dockerfile` 关闭 `display_errors`/`expose_php`；`config.docker.php:23` |
| 文档根 | 通过 | Docker 只把 `public/` 设为 docroot；`server/slice` 其余源码/SQL 不在 web 根 |
| 日志/测试库进镜像 | 通过 | `Dockerfile.dockerignore` 排除 `server/slice/logs`、`server/slice/testdb`、`config.*`、`tests` |
| 开发启动脚本 | **不通过** | `start_api.ps1:2` 默认 `0.0.0.0`，配 `config.local.php`（异常回显/故障注入/强制锁令） |

---

## 5. Top 5 优先修复

### P0-1（S-01）关闭“学生直接改地图”的路径

- 立即：把 `/api/slice/battle/demo` 改为只读预览（不写 `slice_battles`、不返回可结算 id），或仅允许教师调用；`/api/slice/battle/settle` 增加“调用者是该战斗参与者/教师”“回合 `locked`”“目标非 `start`”“游戏 `running`”四项校验。
- 幂等：新增 `battle_settlements(battle_id UNIQUE)` 或 `slice_battles.settled_at`，同一个 battle 只允许 apply 一次；`apply()` 先检查再写。
- 防冲突：`SliceService::settleTurn()` 写 `slice_node_changes` 改为 `INSERT ... ON DUPLICATE KEY UPDATE`，或先按 `(game_id,turn_id)` 删除再插入；所有地图写入记审计（player_id/来源）。
- 验收：玩家 token 调 demo/settle 返回 403（或 demo 只读）；同一 battle 重复 settle 不再改变民心；敌方起点不可易主；先 demo 再教师 settle 不报唯一键错误。

### P0-2（S-03 + S-09）默认口令与撞库/暴力破解

- 试跑库立即改掉所有学生/教师默认口令，改为每人独立随机口令并强制首登修改；从 `/`、`/teacher`、`seed`、手册中删除真实口令。
- 教师控制台不要直接公网暴露：放到现有后台 SSO/内网/IP allowlist 后；默认 `teacher` 账号禁用或改名。
- 登录/写接口加 IP+账号限速、失败锁定、审计；CORS 改为 App 实际 origin 白名单。
- 验收：根页/教师页不再出现任何真实口令；连续失败 N 次返回 429/锁定；跨站 origin 无法读取登录响应。

### P1-3（S-05）卡牌结算事务化 + 军功幂等

- `CardSettlementService::settle()` 整个包在事务中；用 `slice_settlement_jobs` 或 `(turn_id)` 唯一记录做幂等；失败整体回滚，不允许“已发军功但回合未 settled”。
- `MeritService::award()` 改为按 `(turn,player,kind)` 只插一次或绝对值覆盖；重试不能累加。
- 验收：模拟第 2 座城抛错，重试后 `slice_merit_events` 中同一 `(turn,player,kind)` 总额不变；回合要么完整 settled，要么完全回滚。

### P1-4（S-10）卡牌路径补“起点保护 + 无领土限制”

- `HandService::play` 复用 `submitOrder` 的规则：目标为敌方 `start` 直接 422 `START_PROTECTED`；阵营没有任何城时不允许对任意节点出牌，只能默认驻守或拒绝。
- `CardSettlementService::settleCity`/`BattleSettlementService::apply` 对 `node_type='start'` 拒绝易主，避免“卡结算绕过旧结算的起点保护”。
- 验收：卡牌打敌方起点被拒；丢光城的阵营不能全图出牌；起点归属在卡结算后保持不变。

### P1-5（S-04）破坏性脚本与生产库隔离

- `setup_test_db.php`/`setup_map12_db.php` 启动时校验 `db.name` 含 `_test`/`_trial`，否则拒绝并要求显式 `--force`；`apply_migration.php` 只允许 `migrations/` 下文件。
- 生产镜像不 COPY `scripts/setup_*`、`schema.sql`、`legacy_seed.sql`；只保留 `apply_migration.php` + `migrations/`。
- 生产 DB 账号去掉 `DROP`/`ALTER` 权限（迁移用单独账号）；上线前强制备份；`compose.existing-db.yml` 增加“禁止执行 schema.sql”的启动检查。
- 验收：`DB_NAME=class_manager` 执行 setup 脚本必须拒绝；生产容器内不存在 `schema.sql`/`legacy_schema.sql`；误执行不会 DROP `students`。

> S-02 已在工作区加入 `assertTurnEditable()`，请跑 `tests/turn_guard_test.php` 回归后关闭；紧随其后建议处理 S-07（错误信息脱敏）与 S-06（forecast 情报泄露），两者改动小、收益直接。

---

## 6. 已确认通过的控制（避免误伤/重复排查）

1. **学生/教师身份来源**：`role` 只从 `slice_players` 读取；学生登录 SQL 固定 `p.role='player'`，教师登录固定 `p.role='teacher'`；没有请求体可覆盖 role。
2. **token 存储**：DB 只存 `sha256(token)`，不存明文；token 32 字节随机；TTL 12h；`logout` 按 hash 删除。
3. **admin 路由**：`admin/status/lock/settle/next-turn/pause/resume` 全部在服务层 `requireTeacher`；`admin/card-settle` 在路由层再校验一次。
4. **跨局读取**：`getState/getReport/lockTurn/settleTurn/nextTurn` 都有 `assertSameGame`；`getHistory/getReplay/season*` 都按 `player.game_id`；`GET /battle` 校验 `battle.game_id`。
5. **订单幂等**：`submitOrder/withdrawOrder` 有 request 表、payload hash、回合行锁；`recharge` 有 request 表 + 学生行锁；`lock/settle/next-turn` 有状态机/唯一键。
6. **SQL 注入**：未发现可利用点；`PDO::ATTR_EMULATE_PREPARES=false`；`IN` 占位符按数组长度生成；无用户可控 `LIKE/ORDER BY`；`JSON_EXTRACT` 路径为常量。
7. **`students.score` 只读**：未发现 `UPDATE students`；积分只通过 `INSERT shop_orders` 追加；`getWallet` 只做 `score - 100 - SUM(points_spent)`。
8. **生产部署**：MariaDB 不映射 3306；API 只绑 `127.0.0.1`；Docker 关闭 `display_errors`/`expose_php`；docroot 只到 `public/`；`.env`、`config.local/trial`、`logs/`、`testdb/` 均被忽略或 dockerignore。
9. **试跑/生产配置**：`config.local.php`（test 库）、`config.trial.php`（trial 库）、`config.docker.php`（环境变量）分开；`config.ci.php` 只从 CI 环境变量读；未把真实密码写进仓库。

---

## 7. 审计限制

- 未启动 API、未连数据库，未做运行时 DAST/并发实测；S-01 的 score=1 来自本地 `BattleEngine::resolve()` 计算，实际宠物数值可能不同，但“同一 battle 可重复 settle”与“无起点保护”是确定的代码事实。
- S-03/S-13/S-17 的部分影响依赖试跑默认配置、并发窗口或浏览器 Origin 行为，报告已标注条件；不代表生产配置一定命中，但代码路径和默认值真实存在。
- 审计期间工作区有其他 Agent 的未提交改动（`HandService.php` 的 `assertTurnEditable()`、`SliceService.php` 的赛季/统计改动等）；行号与状态以本报告落盘时为准，合并前请重新跑一遍 `grep`/回归。S-02 已按最新工作区标为“已修复（待回归）”。
- 未审计班级量化主系统（`deploy/teacher-web` 依赖的 `common.php/auth.php`）、Cloudflare 面板、Godot 客户端全部逻辑；只覆盖与本服务直接相关的接口/配置。
- `php -l` 已对 `server/slice/src/*.php`、`public/index.php`、`bootstrap.php`、`scripts/*.php` 执行，未发现语法错误。

---

## 8. 交付摘要

- 文件：`SECURITY_AUDIT.md`
- 问题数：**18 项**（严重 1 / 高 2 / 中 7 / 低 6 / 信息 1 / 已修复 1）
- 已修复：S-02（工作区新增 `HandService::assertTurnEditable()`，待跑 `tests/turn_guard_test.php` 回归）
- Top 5（开放项）：S-01（学生直改地图/结算 DoS）、S-03+S-09（默认口令/无速率限制）、S-05（卡结算非事务/军功重复）、S-10（卡牌打敌方起点/无领土全图出牌）、S-04（破坏性脚本无库名保护）
- 未改动任何代码、未写数据库、未 commit；工作区中其他 Agent 的未提交改动未被本报告修改。
