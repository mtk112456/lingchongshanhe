# 灵宠山河 · 家庭实验室 Docker 部署

> 面向现有 `server-deploy/stacks/teaching-app`（MariaDB + Web + Cloudflare Tunnel）的部署方式。  
> 游戏 API 作为同机容器接入现有数据库网络，**不把 3306 暴露公网**。

---

## 1. 拓扑

```text
Cloudflare DNS
  game.yourdomain.com
        │
        ▼
Cloudflare Tunnel（已有）
        │  http://localhost:8090
        ▼
lingchong-api 容器（PHP 8.3 + Apache）
        │  teaching-app_default 内网
        ▼
teaching-app 的 db 容器（MariaDB）
        ├─ students / admin / shop_orders / student_pets
        └─ slice_* / game_wallets / ...
```

- `lingchong-api` 只绑定宿主机 `127.0.0.1:8090`；
- 公网只走 Cloudflare Tunnel，不需要开路由器端口；
- 数据库不开公网，游戏容器通过 Docker 内网访问 `db:3306`；
- HTTPS 由 Cloudflare 提供，Android 不再需要明文 HTTP；
- `cron` 容器每 60 秒执行一次 `scripts/cron.php`，负责 21:00 锁令/结算。

---

## 2. 前置确认

在服务器上确认现有教学系统正常运行：

```bash
docker ps
docker network ls | grep teaching-app_default
```

应能看到 `teaching-app` 的 `db` 和 `web` 容器，以及 `teaching-app_default` 网络。

确认教学库 `.env` 路径（默认）：

```bash
ls -l /opt/home-lab/server-deploy/stacks/teaching-app/.env
```

如果不在这个路径，部署时设置：

```bash
export TEACHING_ENV_FILE=/你的实际路径/.env
```

---

## 3. 放置代码

建议把游戏仓库放到：

```text
/opt/home-lab/lingchong
```

至少需要：

```text
lingchong/
  server/slice/          # API 源码
  deploy/lingchong/      # 本目录
  client/                # 可选，服务器不需要
```

---

## 4. 构建并启动

```bash
cd /opt/home-lab/lingchong

# 检查 Compose 配置
docker compose -f deploy/lingchong/compose.yml config

# 构建并启动 api + cron
docker compose -f deploy/lingchong/compose.yml up -d --build

# 查看状态
docker compose -f deploy/lingchong/compose.yml ps
docker compose -f deploy/lingchong/compose.yml logs -f api
```

本机检查：

```bash
curl -fsS http://127.0.0.1:8090/api/health
```

应返回 `{"ok":true,...}`。

---

## 5. 生产库迁移

> 先备份。生产库只执行 `001`、`002`，不要执行 `legacy_schema.sql` / `schema.sql` / `legacy_seed.sql`。

备份：

```bash
docker compose -f /opt/home-lab/server-deploy/stacks/teaching-app/compose.yml exec -T db \
  sh -c 'mysqldump -u"$MARIADB_USER" -p"$MARIADB_PASSWORD" "$MARIADB_DATABASE"' \
  > /data/backup/class_manager_before_lingchong_$(date +%F_%H%M).sql
```

先核对 `shop_orders.type` 的现有枚举：

```bash
docker compose -f /opt/home-lab/server-deploy/stacks/teaching-app/compose.yml exec -T db \
  sh -c 'mysql -u"$MARIADB_USER" -p"$MARIADB_PASSWORD" "$MARIADB_DATABASE" -e "SHOW COLUMNS FROM shop_orders LIKE '\''type'\'';"'
```

如果现有 ENUM 里还有 `goods/blind_box` 之外的值，先把它们补进 `001_shop_orders_game_recharge.sql` 再执行，避免被截断。

执行迁移：

```bash
cd /opt/home-lab/lingchong

docker compose -f /opt/home-lab/server-deploy/stacks/teaching-app/compose.yml exec -T db \
  sh -c 'mysql -u"$MARIADB_USER" -p"$MARIADB_PASSWORD" "$MARIADB_DATABASE"' \
  < server/slice/migrations/001_shop_orders_game_recharge.sql

docker compose -f /opt/home-lab/server-deploy/stacks/teaching-app/compose.yml exec -T db \
  sh -c 'mysql -u"$MARIADB_USER" -p"$MARIADB_PASSWORD" "$MARIADB_DATABASE"' \
  < server/slice/migrations/002_apply_points_schema.sql
```

迁移后验证：

```bash
docker compose -f /opt/home-lab/server-deploy/stacks/teaching-app/compose.yml exec -T db \
  sh -c 'mysql -u"$MARIADB_USER" -p"$MARIADB_PASSWORD" "$MARIADB_DATABASE" -e "SHOW COLUMNS FROM shop_orders LIKE '\''type'\''; SHOW TABLES LIKE '\''game_%'\'';"'
```

> 如果这是第一次上线，建议先在**测试库副本**演练一遍，再操作生产库。

---

## 6. Cloudflare Tunnel

在 Cloudflare Zero Trust：

```text
Networks → Tunnels → 现有 Tunnel → Public Hostname → Add
Subdomain: game
Domain:    yourdomain.com
Type:      HTTP
URL:       localhost:8090
```

保存后访问：

```text
https://game.yourdomain.com/api/health
```

不需要在路由器上开 8090；Tunnel 会从本机回源。

如果使用本地 `cloudflared` 配置文件，参考 `cloudflared.ingress.example.yml`，**合并**到现有 ingress，不要覆盖其他域名。

---

## 7. 客户端

Godot 登录页服务器地址填：

```text
https://game.yourdomain.com
```

不再需要 `adb reverse`，也不需要明文 HTTP。  
学生用现有班级系统账号登录；教师用现有 `admin` 账号登录。

---

## 8. 定时任务

`cron` 容器已经启动，每 60 秒执行：

```bash
php /var/www/html/scripts/cron.php
```

它会对已过截止时间且 `games.status='running'` 的回合执行：

1. 锁令并生成快照；
2. 结算；
3. 失败保留快照，下一轮重试。

查看日志：

```bash
docker compose -f deploy/lingchong/compose.yml logs -f cron
```

`next-turn` 不自动执行，仍由教师确认。

---

## 9. 实时战斗怎么加

> 家庭实验室 + 云服务器的分工、Tailscale 内网调用和域名拆分，见 [CLOUD.md](CLOUD.md)。

### 推荐顺序

1. 先跑通当前异步切片（本部署）；
2. 加“战斗回放”动画：服务器仍 21:00 结算，客户端播放结果；
3. 如果要做实时，优先做**周五同步回合制**；
4. 最后才考虑真·实时操作。

### 周五同步回合制

在同一 Docker 网络加一个 WebSocket 房间服务（Node.js/Go）：

```text
Godot → wss://rt.yourdomain.com → rt 容器 → db / Redis
```

- Cloudflare Tunnel 支持 WebSocket；
- 房间服务只读 `slice_sessions` 校验 Token，或调用游戏 API 校验；
- 战斗结果写回 MySQL；
- 建议空闲 30 秒发 ping，避免 Cloudflare 100 秒空闲断开；
- 缺席玩家默认防御，不能因为一个人没上线就卡住全班。

### 真·实时操作

不建议放在家庭宽带 + Cloudflare Tunnel 上做核心玩法：

- Cloudflare 适合 HTTP/WebSocket，不适合低延迟 UDP；
- 真·实时操作需要公网 VPS + UDP/ENet/WebTransport、客户端预测、服务器权威、断线重连；
- 40 人规模服务器不是瓶颈，**同时在线和公平性才是**。

如果确实要做，把实时房间服放云服务器，通过 Tailscale 私有网络访问家庭实验室数据库；不要公网开 3306。

---

## 10. 安全与回滚

- `.env` 不提交、不放入镜像；
- 数据库只在 Docker 内网；
- 迁移前必须备份；
- 回滚 `001` 前先确认没有 `game_recharge` 订单；
- 游戏容器只挂载 `logs`，不挂载源码和数据库目录；
- 正式版 `ALLOW_FORCE_LOCK` 改为 `0`，只由 cron 在截止时锁定；
- 生产环境不要开启 `allow_fault_injection` / `expose_error_details`。
