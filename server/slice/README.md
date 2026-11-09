# 三回合切片服务端

这是《青竹文房·灵宠山河》里程碑 A 的独立测试服务端，已对接现有班级量化系统的学生、教师、班宠和积分表。

完整对接说明见 [INTEGRATION.md](INTEGRATION.md)。

## 已实现

- 学生用现有 `students` 姓名/密码登录；教师用现有 `admin` 登录；
- 班宠从 `student_pets` / `pet_templates` 读取，切片统一 1000 兵力；
- 5 节点、2 个对称起点、3 个中立争夺点；
- 每人每回合 1 个可改写军令；
- 提交/撤改/锁令使用同一回合锁，截止时间在锁内检查；
- 锁令生成只读快照，结算只读快照；
- 结算失败保留快照，可重试；结果/战报/回合状态一次提交；
- 21:00 定时任务可锁令并结算；
- 积分兑换只写 `shop_orders`（`game_recharge`），1 积分 = 10 文玉，每日上限 20 分；
- 14 项自动化验收：并发、超时重发、失败补算、三类冲突、积分对接、战局回放等。

## 快速开始

```powershell
# MariaDB（测试数据目录 server/testdb/data，端口 3307）
pwsh server/slice/start_mariadb.ps1

# 第一次或重置测试库
pwsh server/slice/setup.ps1

# API
pwsh server/slice/start_api.ps1
```

API：`http://127.0.0.1:8080/api/health`  
教师控制台：`http://127.0.0.1:8080/teacher`（独立 Web，学生 App 不提供教师登录）

测试账号：

- 学生：`青竹一` / `slice2026`
- 教师：`teacher` / `teacher2026`

## 验收

```powershell
$php = (Get-Command php).Source
$dir = Split-Path $php -Parent
& $php -d "extension_dir=$dir\ext" -d extension=pdo_mysql tests\run.php
```

## 定时任务

```powershell
php server/slice/scripts/cron.php
```

每 1 分钟执行一次；对已过截止时间的回合锁令并结算。`next-turn` 由教师确认，不自动推进。

## 配置

复制 `config.example.php` 为 `config.local.php`，填写测试库连接。  
`config.local.php` 含本机测试密码，不要放入交接包或提交到仓库。

## 上云 / 家庭实验室 Docker

现成教学系统是 Docker Compose + Cloudflare Tunnel 时，按  
[`deploy/lingchong/README.md`](../../deploy/lingchong/README.md) 部署：

- 游戏 API 加入 `teaching-app_default` 网络，内网连 `db:3306`；
- Cloudflare 增加 `game.你的域名` → `localhost:8090`；
- 数据库不暴露公网；
- `cron` 容器每 60 秒锁令/结算。
