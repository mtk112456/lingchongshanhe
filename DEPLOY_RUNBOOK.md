# 灵宠山河 · Docker + Cloudflare Tunnel 部署 Runbook

> 适用：`server/slice` 异步 API、教师控制台、21:00 定时结算。  
> 目标机器：Linux + Docker Engine 24+ / Docker Compose 2.20+，2C2G 起步。  
> 配套文件：`deploy/lingchong/docker-compose.yml`、`Dockerfile`、`.env.example`、`cloudflared/config.example.yml`。

---

## 0. 拓扑与边界

```text
学生 App / 浏览器
        │ HTTPS
        ▼
Cloudflare DNS + Tunnel
        │  http://api:8080（Docker 内网）
        ▼
┌──────────────────────────────┐
│ lingchong 项目                │
│  cloudflared ──► api:8080     │
│                    │          │
│                    ▼          │
│                  db:3306      │  不映射到宿主机
└──────────────────────────────┘
```

- 公网只有 Cloudflare Tunnel 一个入口，不需要在路由器/云安全组开放 8080 或 3306；
- `api` 只绑定 `127.0.0.1:8080`，供本机 `curl` 自检；
- `db` 没有任何 `ports`，只能被同一 Docker 网络内的 `api` / `cron` 访问；
- 密码和 Tunnel Token 只存在 `deploy/lingchong/.env`（`chmod 600`，git 已忽略）。

部署包文件：

| 文件 | 用途 |
|---|---|
| `Dockerfile` | PHP 8.4 + Apache + `pdo_mysql`，文档根 `server/slice/public`，生产关闭错误回显 |
| `docker-compose.yml` | 独立栈：`db` + `api` + `cron` + `cloudflared` |
| `.env.example` | 数据库密码、Tunnel Token 占位符 |
| `cloudflared/config.example.yml` | 自管 Tunnel 配置，ingress 指向 `api:8080` |
| `compose.existing-db.yml` | 旧拓扑：接入现有 teaching-app 的 MariaDB（可选） |
| `config.docker.php` | 容器内配置，全部从环境变量读取，`expose_error_details=false` |

---

## 1. 首次部署

### 1.1 放置代码

```bash
sudo mkdir -p /opt/lingchong
sudo chown "$USER":"$USER" /opt/lingchong
# 用 git clone 或 rsync 把仓库放到 /opt/lingchong，至少需要 server/ 和 deploy/
cd /opt/lingchong
ls server/slice/public/index.php deploy/lingchong/docker-compose.yml
```

### 1.2 生成 `.env`

```bash
cd /opt/lingchong
cp deploy/lingchong/.env.example deploy/lingchong/.env
chmod 600 deploy/lingchong/.env
```

编辑 `.env`，至少替换：

- `DB_PASS`、`DB_ROOT_PASS`：两条不同的随机强密码；
- `TUNNEL_TOKEN`：稍后从 Cloudflare Zero Trust 复制。

生成密码可用：

```bash
openssl rand -base64 32
```

> `.env` 不进 git、不进镜像。`docker compose config` 会展开变量，不要把它贴到公开日志里。

### 1.3 先只启数据库

```bash
cd /opt/lingchong
docker compose -f deploy/lingchong/docker-compose.yml config
docker compose -f deploy/lingchong/docker-compose.yml up -d db
docker compose -f deploy/lingchong/docker-compose.yml ps
```

等 `db` 显示 `healthy`：

```bash
docker compose -f deploy/lingchong/docker-compose.yml ps --format 'table {{.Name}}\t{{.Status}}'
```

首次启动会自动创建 `DB_NAME` 库和 `DB_USER` 用户。**卷已存在时再改 `.env` 密码不会改库内密码**，见 §4.5。

### 1.4 初始化数据库（二选一）

#### A. 接入现有教学库（生产推荐）

在旧机器导出（不要带 `--databases`，避免 dump 里的 `USE` 覆盖目标库）：

```bash
# 旧机器
mysqldump -u<用户> -p --single-transaction --quick --routines --events \
  --default-character-set=utf8mb4 <现有库名> > class_manager_before_lingchong.sql
```

传到新机器后导入：

```bash
cd /opt/lingchong
docker compose -f deploy/lingchong/docker-compose.yml exec -T db sh -c \
  'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb -uroot "$MARIADB_DATABASE"' \
  < class_manager_before_lingchong.sql
```

导入后**必须**按 §2 执行 `001`、`002`、`004`、`005`、`006`、`007`。  
**不要**执行 `schema.sql`、`legacy_schema.sql`、`legacy_seed.sql`：前两个会 `DROP TABLE`，会清掉生产数据。

> 源库若是 MySQL 8，先在临时库演练一次导入；排序规则/字符集不兼容会在这里暴露，而不是在学生上课时。

#### B. 一次性验收/演示库（禁止用于生产）

空库、无真实学生数据时，才可以用测试镜像：

```bash
cd /opt/lingchong
docker compose -f deploy/lingchong/docker-compose.yml up -d --build api
docker compose -f deploy/lingchong/docker-compose.yml exec -T api \
  php /var/www/html/scripts/setup_test_db.php
```

它会依次执行 `legacy_schema.sql`、`schema.sql`、`legacy_seed.sql`、`seed.sql`，创建测试账号：

- 学生：`青竹一` / `slice2026`
- 教师：`teacher` / `teacher2026`

> 这四份 SQL 含 `DROP TABLE`，只允许对**新建的空库**执行。已有数据的库一律走 A + §2。

### 1.5 启动 API 并本机自检

```bash
cd /opt/lingchong
docker compose -f deploy/lingchong/docker-compose.yml up -d api
docker compose -f deploy/lingchong/docker-compose.yml logs -f api
```

另开终端：

```bash
curl -fsS http://127.0.0.1:8080/api/health
# {"ok":true,"data":{"ok":true,"server_time":"...","games":1,"php":"8.4.x"},"server_time":"..."}

curl -fsS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8080/teacher
# 200
```

`/api/health` 会查 `slice_games`，所以要等 §1.4 完成后才返回 200；在此之前返回 500 是正常的。

### 1.6 配置 Cloudflare Tunnel

**方式一：token 模式（默认，推荐）**

1. Zero Trust → Networks → Tunnels → 创建/选择 Tunnel；
2. Install connector 页面复制 token，写入 `.env` 的 `TUNNEL_TOKEN`；
3. Public Hostname 添加：
   - Subdomain：`game`
   - Domain：你的域名
   - Type：`HTTP`
   - URL：`api:8080`（**不要写 localhost**，cloudflared 在容器里，回源走 Docker 服务名）
4. 启动并看日志：

```bash
cd /opt/lingchong
docker compose -f deploy/lingchong/docker-compose.yml up -d cloudflared
docker compose -f deploy/lingchong/docker-compose.yml logs -f cloudflared
```

看到 `Registered tunnel connection` 即成功。外网验证：

```bash
curl -fsS https://game.你的域名/api/health
```

**方式二：自管 config.yml（可选）**

```bash
cd /opt/lingchong
cp deploy/lingchong/cloudflared/config.example.yml deploy/lingchong/cloudflared/config.yml
# 编辑 config.yml：填 tunnel UUID；把 <UUID>.json 凭据放到 deploy/lingchong/cloudflared/
cat > deploy/lingchong/docker-compose.override.yml <<'YAML'
services:
  cloudflared:
    command: ["tunnel", "--no-autoupdate", "--config", "/etc/cloudflared/config.yml", "run"]
YAML

# 显式合并 override（compose 的自动 override 只在未指定 -f 时生效）
export COMPOSE_FILE=deploy/lingchong/docker-compose.yml:deploy/lingchong/docker-compose.override.yml
docker compose up -d cloudflared
```

`COMPOSE_FILE` 只对当前 shell 生效；新开终端要重新 `export`。  
`config.yml` 和 `*.json` 已被 `deploy/lingchong/.gitignore` 忽略。  
凭据 JSON 需要容器内 `nonroot`（UID 65532）可读：至少 `chmod 644`，并确保所在目录不是 world-writable。

### 1.7 启动定时任务

```bash
cd /opt/lingchong
docker compose -f deploy/lingchong/docker-compose.yml up -d cron
docker compose -f deploy/lingchong/docker-compose.yml logs -f cron
```

`cron` 每 60 秒执行一次 `php /var/www/html/scripts/cron.php`，负责截止锁令 + 结算；`next-turn` 仍由教师确认。

### 1.8 首次验收清单

```bash
# 1. 所有容器状态
docker compose -f deploy/lingchong/docker-compose.yml ps

# 2. 3306 没有发布到宿主机（应无输出）
ss -lntp | grep ':3306' || true

# 3. 8080 只绑回环
ss -lntp | grep ':8080'

# 4. 健康检查与教师页
curl -fsS http://127.0.0.1:8080/api/health
curl -fsS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8080/teacher

# 5. 外网
curl -fsS https://game.你的域名/api/health
```

浏览器打开 `https://game.你的域名/teacher`，用教师账号登录，确认能看到战局。

---

## 2. 生产库迁移（只走 apply_migration.php）

> 红线：生产库**不执行** `schema.sql` / `legacy_schema.sql` / `legacy_seed.sql` / `seed.sql`。  
> 迁移前先备份（§4）。迁移脚本只新增表/字段，不改 `students.score`、不改班宠数据。

### 2.1 迁移前预检

确认 `shop_orders.type` 现有枚举：

```bash
cd /opt/lingchong
docker compose -f deploy/lingchong/docker-compose.yml exec -T db sh -c \
  'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb -uroot "$MARIADB_DATABASE" \
   -e "SHOW COLUMNS FROM shop_orders LIKE '\''type'\'';"'
```

把结果记下来：

- 如果只有 `goods`、`blind_box`，`001` 可直接执行；
- 如果还有别的值，先把这些值补进 `server/slice/migrations/001_shop_orders_game_recharge.sql` 的 ENUM，再执行，避免旧订单被截断成空值。

### 2.2 按顺序执行

```bash
cd /opt/lingchong

for f in \
  001_shop_orders_game_recharge.sql \
  002_apply_points_schema.sql \
  004_phase1_cards_battle.sql \
  005_city_morale.sql \
  006_map12_nodes.sql \
  007_daily_bulletin.sql
do
  echo "==> $f"
  docker compose -f deploy/lingchong/docker-compose.yml exec -T api \
    php /var/www/html/scripts/apply_migration.php \
      /var/www/html/config.docker.php \
      "/var/www/html/migrations/$f" || exit 1
done
```

说明：

- 没有 `003`，编号不连续是正常的；
- `apply_migration.php` 用 `config.docker.php` 读容器环境变量连 `db:3306`，不要传 `config.local.php`；
- 每条成功输出 `DB: <库名>` 和 `OK: <文件名>`；
- 迁移是前向的，重复执行 `002/004/005/006/007` 多为 `IF NOT EXISTS` 幂等，但 `001` 的 ENUM 修改仍应先备份。

### 2.3 迁移后验证

```bash
docker compose -f deploy/lingchong/docker-compose.yml exec -T db sh -c \
  'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb -uroot "$MARIADB_DATABASE" -e "
    SHOW COLUMNS FROM shop_orders LIKE '\''type'\'';
    SHOW COLUMNS FROM slice_nodes LIKE '\''morale'\'';
    SHOW TABLES LIKE '\''game_%'\'';
    SHOW TABLES LIKE '\''slice_bulletins'\'';
  "'
```

期望：

- `shop_orders.type` 包含 `game_recharge`；
- `slice_nodes.morale` 存在；
- `game_wallets`、`game_wallet_transactions`、`game_recharge_requests` 存在；
- `slice_bulletins` 存在。

再跑一次健康检查，确认 `games` 数量与预期一致。

---

## 3. 健康检查、日志与日常运维

### 3.1 检查点

| 检查 | 命令 | 期望 |
|---|---|---|
| API 进程 | `docker compose ... ps api` | `healthy` |
| 数据库 | `docker compose ... ps db` | `healthy` |
| 业务健康 | `curl -fsS http://127.0.0.1:8080/api/health` | `ok:true` |
| 教师页 | `curl -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/teacher` | `200` |
| Tunnel | `docker compose ... logs cloudflared` | `Registered tunnel connection` |
| 定时任务 | `docker compose ... logs --tail 50 cron` | 有执行输出、无持续报错 |

`curl` 返回 500 时先看：

```bash
docker compose -f deploy/lingchong/docker-compose.yml logs --tail 100 api
docker compose -f deploy/lingchong/docker-compose.yml logs --tail 100 db
```

常见原因：`DB_PASS` 与卷内密码不一致、迁移没跑、`slice_games` 为空。

### 3.2 日志位置

- 容器标准输出：`docker compose logs -f api|cron|cloudflared|db`
- 应用日志：`api_logs` 卷内的 `/var/www/html/logs/api.log`
- 查看应用日志：

```bash
docker compose -f deploy/lingchong/docker-compose.yml exec api \
  tail -n 100 /var/www/html/logs/api.log
```

Docker 日志已限制为每容器 3 × 10MB，避免塞满磁盘。

### 3.3 重启与升级

```bash
# 重启单个服务
docker compose -f deploy/lingchong/docker-compose.yml restart api

# 升级代码（先备份、再迁移、最后换镜像）
cd /opt/lingchong
git fetch --tags
git checkout <新版本 tag>
API_TAG=<新版本 tag> docker compose -f deploy/lingchong/docker-compose.yml build api
API_TAG=<新版本 tag> docker compose -f deploy/lingchong/docker-compose.yml up -d api cron
```

镜像标签用日期或 git 短哈希，例如 `API_TAG=20261111`；`API_TAG` 也写进 `.env` 便于重启后保持一致。

---

## 4. 备份与恢复

### 4.1 备份（建议每天 + 每次迁移前）

```bash
cd /opt/lingchong
docker compose -f deploy/lingchong/docker-compose.yml exec -T db sh -c \
  'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb-dump -uroot \
     --single-transaction --quick --routines --events \
     --default-character-set=utf8mb4 "$MARIADB_DATABASE" \
     > /backup/class_manager_$(date +%F_%H%M).sql'
```

备份文件落在宿主机 `deploy/lingchong/backup/`（容器内 `/backup`）。  
建议再用 `scp`/`rclone` 复制到另一台机器；同机备份挡不住磁盘损坏。  
备份含学生姓名/密码哈希等真实数据：目录设 `chmod 700`，不要放公开网盘，也不要提交到 git。

### 4.2 验证备份可用

```bash
cd /opt/lingchong
ls -lh deploy/lingchong/backup/
wc -l deploy/lingchong/backup/xxx.sql
grep -c '^CREATE TABLE' deploy/lingchong/backup/xxx.sql
```

至少确认：文件非空、`CREATE TABLE` 数量合理、能看到 `students` 和 `slice_games`。

### 4.3 恢复

```bash
cd /opt/lingchong
# 1) 停写入，保留 db
docker compose -f deploy/lingchong/docker-compose.yml stop cron api cloudflared

# 2) 导入（会覆盖同名表，先确认备份文件正确）
docker compose -f deploy/lingchong/docker-compose.yml exec -T db sh -c \
  'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb -uroot "$MARIADB_DATABASE"' \
  < deploy/lingchong/backup/class_manager_2026-11-11_2100.sql

# 3) 恢复服务
docker compose -f deploy/lingchong/docker-compose.yml up -d api cron cloudflared
curl -fsS http://127.0.0.1:8080/api/health
```

恢复后核对：学生数、`slice_games` 数、最近回合状态、`shop_orders` 是否有重复。

### 4.4 数据库整卷备份（可选）

```bash
cd /opt/lingchong
docker compose -f deploy/lingchong/docker-compose.yml stop db
docker run --rm \
  -v lingchong_db_data:/data:ro \
  -v "$PWD/deploy/lingchong/backup:/backup" \
  alpine tar czf /backup/db_volume_$(date +%F).tgz -C /data .
docker compose -f deploy/lingchong/docker-compose.yml start db
```

卷名默认是 `lingchong_db_data`（由 `name: lingchong` 决定）。

### 4.5 忘记数据库密码

`.env` 只影响新卷初始化。卷已存在时：

1. 用 `DB_ROOT_PASS` 以 root 进库；
2. `ALTER USER 'lingchong_api'@'%' IDENTIFIED BY '<新密码>';`
3. 同步修改 `.env` 的 `DB_PASS`；
4. `docker compose up -d --force-recreate api cron`。

---

## 5. 回滚

### 5.1 应用回滚（数据库结构不变）

```bash
cd /opt/lingchong
git checkout <上一个版本 tag>
API_TAG=<上一个版本 tag> docker compose -f deploy/lingchong/docker-compose.yml build api
API_TAG=<上一个版本 tag> docker compose -f deploy/lingchong/docker-compose.yml up -d api cron
curl -fsS http://127.0.0.1:8080/api/health
```

迁移都是新增表/字段，旧代码通常能在新结构上运行；不确定时先恢复数据库备份。

### 5.2 数据库回滚

优先用 §4.3 的整库备份恢复，这是最可靠的回滚方式。

`001` 的 ENUM 回滚**只在没有任何 `game_recharge` 订单时**才允许：

```sql
-- 先查：必须为 0
SELECT COUNT(*) FROM shop_orders WHERE type = 'game_recharge';

-- 把 <迁移前记录的枚举> 换成 §2.1 记下的原值
ALTER TABLE shop_orders
  MODIFY COLUMN type ENUM(<迁移前记录的枚举>) DEFAULT 'goods' COMMENT '兑换类型';
```

`002/004/005/006/007` 是新增表/列，不要手工 `DROP` 生产表；需要撤销就恢复备份。

### 5.3 服务整体回滚

```bash
cd /opt/lingchong
docker compose -f deploy/lingchong/docker-compose.yml down   # 不删卷
git checkout <旧版本 tag>
docker compose -f deploy/lingchong/docker-compose.yml up -d --build
```

> 永远不要用 `docker compose down -v`：`-v` 会删除 `db_data` 卷，等于删库。

---

## 6. 红线

1. **3306 不公网**：`db` 不写 `ports`，路由器/云安全组也不放行 3306；只允许 Docker 内网。
2. **生产不跑 schema.sql**：`schema.sql`、`legacy_schema.sql`、`legacy_seed.sql`、`seed.sql` 都含 `DROP TABLE`，只用于一次性空库演练；生产迁移只用 `apply_migration.php`。
3. **密码不进 git**：`.env`、`cloudflared/config.yml`、`*.json` 凭据都在 `.gitignore`；提交前 `git status` 确认。
4. **不修改 `students.score`**：积分只追加 `shop_orders`；不改班宠/技能/法宝。
5. **不把真实学生数据放进测试库**。
6. **迁移前必须备份**，并确认备份可读。
7. 生产保持 `ALLOW_FORCE_LOCK=0`、`expose_error_details=false`、`allow_fault_injection=false`。
8. `/teacher` 目前是公网可访问的登录页，建议在 Cloudflare 侧加 Access 策略或 WAF 规则，只允许教师邮箱/固定 IP 访问 `/teacher*`。
9. Tunnel Token 等同密码；泄露后立即在 Zero Trust 轮换，并 `docker compose up -d --force-recreate cloudflared`。

---

## 7. 已知缺口（交付时未做）

- 本机没有 Docker，`docker compose config` 未在真实 Docker 上执行，只做了静态 YAML/变量校验；首次上线请在服务器执行 §1.3 的 `config` 和 `ps`。
- 没有在真实 Cloudflare Tunnel / 真实域名上跑过；`game.你的域名` 是占位符。
- 没有配置 Cloudflare Access（教师页目前只有应用层登录）。
- 没有异地备份自动化、监控告警、数据库慢查询/连接数调优。
- 密码通过容器环境变量注入（`docker inspect` 可见）；需要更强隔离时可改用 Docker secrets 或外部密钥管理。
- `mariadb:10.11` 和 `cloudflared:latest` 未固定到 digest；生产可按需固定版本。
- 实时房间服（WebSocket）不在本包内，见 `CLOUD.md`。
- 迁移没有 down 脚本；回滚依赖备份（设计如此）。
