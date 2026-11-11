# 灵宠山河 · 部署包

> 本目录是可交付的 Docker + Cloudflare Tunnel 部署包。  
> **完整步骤、迁移、备份、回滚、红线见 [`../../DEPLOY_RUNBOOK.md`](../../DEPLOY_RUNBOOK.md)。**  
> 家庭实验室与云服务器的分工见 [`CLOUD.md`](CLOUD.md)。

---

## 1. 两种拓扑

| 拓扑 | 文件 | 适用 |
|---|---|---|
| **独立栈**（推荐给新机器） | `docker-compose.yml` | 自带 MariaDB 10.11 + API + cron + cloudflared，一个 compose 文件起完整环境 |
| **接入现有教学库** | `compose.existing-db.yml` | 已有 `teaching-app` 的 MariaDB + Tunnel，只把 API 挂进同一 Docker 网络 |

两者使用同一个镜像（`Dockerfile`，PHP 8.4 + Apache + `pdo_mysql`，文档根 `server/slice/public`）。

---

## 2. 独立栈快速开始

```bash
cd /opt/lingchong
cp deploy/lingchong/.env.example deploy/lingchong/.env
chmod 600 deploy/lingchong/.env
# 编辑 .env：DB_PASS / DB_ROOT_PASS / TUNNEL_TOKEN

docker compose -f deploy/lingchong/docker-compose.yml config
docker compose -f deploy/lingchong/docker-compose.yml up -d db
docker compose -f deploy/lingchong/docker-compose.yml up -d --build api
# 初始化或导入数据 → 见 RUNBOOK §1.4 / §2
docker compose -f deploy/lingchong/docker-compose.yml up -d cron cloudflared
curl -fsS http://127.0.0.1:8080/api/health
```

- 公网入口：Cloudflare Public Hostname → `HTTP` → `api:8080`；
- `api` 只绑 `127.0.0.1:8080`；
- `db` 不映射 3306。

### 迁移（生产）

只用 `server/slice/scripts/apply_migration.php`，按 `001 → 002 → 004 → 005 → 006 → 007` 顺序执行。  
**不要**在生产库执行 `schema.sql` / `legacy_schema.sql` / `legacy_seed.sql` / `seed.sql`（均含 `DROP TABLE`）。命令见 RUNBOOK §2.2。

---

## 3. 接入现有教学库（旧拓扑）

前置：服务器上已有 `teaching-app` 的 `db` 容器和 `teaching-app_default` 网络。

```bash
export TEACHING_ENV_FILE=/opt/home-lab/server-deploy/stacks/teaching-app/.env
mkdir -p deploy/lingchong/logs
# 容器内 cron 以 www-data(33) 运行，宿主机目录要让它可以写
sudo chown -R 33:33 deploy/lingchong/logs
docker compose -f deploy/lingchong/compose.existing-db.yml config
docker compose -f deploy/lingchong/compose.existing-db.yml up -d --build
curl -fsS http://127.0.0.1:8080/api/health
```

- 复用现有 `.env` 里的数据库账号；
- API 端口只绑 `127.0.0.1:8080`，公网仍走原 Tunnel；
- 迁移同样只走 `apply_migration.php`；
- 应用日志落在 `deploy/lingchong/logs/`。

---

## 4. 文件说明

| 文件 | 用途 |
|---|---|
| `Dockerfile` | PHP 8.4 + Apache，监听 8080，生产关闭 `display_errors` / `expose_php` |
| `Dockerfile.dockerignore` | 构建上下文过滤，本机配置和测试库不进镜像 |
| `docker-compose.yml` | 独立栈：`db` + `api` + `cron` + `cloudflared` |
| `compose.existing-db.yml` | 接入现有 teaching-app 数据库 |
| `.env.example` | 密码与 Tunnel Token 占位符（复制为 `.env`，不提交） |
| `config.docker.php` | 容器内配置，全部读环境变量 |
| `cloudflared/config.example.yml` | 自管 Tunnel 配置，ingress → `api:8080` |
| `cloudflared.ingress.example.yml` | 合并到现有 Tunnel 的 ingress 片段（旧方式） |
| `backup/` | 数据库备份落点，`*.sql` 已 git 忽略 |

---

## 5. 客户端

Godot 登录页服务器地址填：

```text
https://game.你的域名
```

学生用现有班级系统账号登录；教师用现有 `admin` 账号登录。  
HTTPS 由 Cloudflare 提供，不需要 `adb reverse`，也不需要明文 HTTP。

教师控制台：`https://game.你的域名/teacher`  
（公网可访问，建议在 Cloudflare 侧加 Access 策略，见 RUNBOOK §6 红线 8。）

---

## 6. 定时任务

`cron` 容器每 60 秒执行：

```bash
php /var/www/html/scripts/cron.php
```

对已过截止时间且 `games.status='running'` 的回合：锁令 → 快照 → 结算；失败保留快照，下一轮重试。  
`next-turn` 不自动执行，仍由教师确认。

---

## 7. 安全红线

1. 3306 不公网；
2. 生产不跑 `schema.sql` / `legacy_*` / `seed.sql`；
3. 密码、Tunnel Token 不进 git、不进镜像；
4. 不改 `students.score`，积分只追加 `shop_orders`；
5. 迁移前先备份；
6. 不用 `docker compose down -v`（会删库卷）。

---

## 8. 实时战斗

家庭实验室 + 云服务器分工、Tailscale 内网调用、域名拆分见 [`CLOUD.md`](CLOUD.md)。  
本包只覆盖异步 API；实时房间服（WebSocket）尚未实现。
