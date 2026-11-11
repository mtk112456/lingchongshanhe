# SECURITY_HARDENING.md · 安全中间件接入指南

- 状态：**中间件已新增，`index.php` 尚未接入**（主线程正在改 `index.php`，本文只给接入点，避免冲突）
- 本次新增：
  - `server/slice/src/RateLimiter.php` — flock 固定窗口限流
  - `server/slice/src/CorsPolicy.php` — CORS 白名单
  - `server/slice/tests/rate_limiter_test.php` — 独立测试（不连数据库）
- 关联审计：`SECURITY_AUDIT.md` 的 **S-03（默认口令 + CORS `*`）**、**S-09（无限速）**
- 不涉及：数据库 schema、`students.score`、`bootstrap.php`、现有测试

---

## 1. 接入点一：CORS（`public/index.php` 顶部）

### 1.1 删除旧的通配配置

当前 `index.php` 里有：

```php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Auth-Token, X-Request-Id');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');

if ($method === 'OPTIONS') {
    http_response_code(204);
    exit;
}
```

**这 4 段必须整体删除**，否则会和新中间件同时输出两个 `Access-Control-Allow-Origin`，浏览器会直接拒绝响应（多个 ACAO 值无效）。

### 1.2 在解析 `$path` 之后、任何输出之前接入

推荐在 `$path` 规范化之后、`/teacher` 与 `/` 路由之前：

```php
require_once dirname(__DIR__) . '/src/CorsPolicy.php';

// 提前读取配置：预检请求不应因为数据库暂时不可用而失败。
$configPath = getenv('SLICE_CONFIG') ?: dirname(__DIR__) . '/config.local.php';
$earlyConfig = is_file($configPath) ? require $configPath : [];

$cors = CorsPolicy::fromConfig($earlyConfig);
if ($cors->handlePreflight()) {
    exit; // OPTIONS 已输出 204 和允许头
}
$cors->apply();

header('Content-Type: application/json; charset=utf-8');
```

说明：

- `handlePreflight()` 只处理 `OPTIONS`：命中白名单时返回允许头 + 204；未命中时也返回 204，但不带 ACAO，浏览器会自行拦截。
- `apply()` 对普通请求只输出允许头；没有 `Origin`（Godot 原生客户端、curl）时**不输出任何 CORS 头**，不影响 App。
- 白名单只认完整 origin：`scheme://host[:port]`，不要带路径。
- 只有 `app.env` 是 `local` / `dev` / `development` / `test` / `testing` 时，配置里的 `*` 才生效；`production`、`staging`、未配置等都会忽略并写 `error_log`。
- 带 cookie/凭据时不能返回 `*`，类会自动回显具体 origin；本项目用 `Authorization` 头，建议 `cors_allow_credentials = false`。

### 1.3 配置语义

```php
'app' => [
    'env' => 'production',
    'allowed_origins' => [
        // 只有“浏览器直连 API”的页面才需要列在这里
        // 'https://qingzhu.example.com',
    ],
    'cors_allow_credentials' => false,
    'cors_max_age' => 600,
],
```

- `allowed_origins` 为空 = **拒绝所有跨域浏览器请求**（同源页面、App、服务端代理不受影响）。
- 教师控制台如果由 `deploy/teacher-web` 的服务端代理转发，不需要把教师站加进白名单；只有浏览器 JS 直接 `fetch` API 才需要。
- 本地联调建议写明确的 `http://127.0.0.1:8081`、`http://localhost:8081`，不要用 `*`。
- `CorsPolicy` 不改变“谁能调用 API”——它只限制浏览器能否读取响应；curl/脚本不受 CORS 约束，真正的门禁仍是 token + 限流。

---

## 2. 接入点二：登录限流（10 次/分钟/IP）

### 2.1 初始化

在 `index.php` 顶部 require：

```php
require_once dirname(__DIR__) . '/src/RateLimiter.php';
```

当前 bootstrap 解构丢弃了配置：

```php
try {
    [, $pdo, $service] = slice_bootstrap();
} catch (Throwable $e) {
```

要改成保留 `$config`：

```php
try {
    [$config, $pdo, $service] = slice_bootstrap();
} catch (Throwable $e) {
```

然后在 bootstrap 成功后、进入路由 `try` 之前初始化：

```php
$limiter = RateLimiter::fromConfig($config);
```

`RateLimiter::fromConfig()` 读取 `app.ratelimit.*`；目录默认 `server/slice/logs/ratelimit`（相对 `src/` 的上一级）。

### 2.2 学生登录

在 `POST /api/auth/login` 分支内，**在 `jsonBody()` 和密码校验之前**加：

```php
if ($method === 'POST' && $path === '/api/auth/login') {
    $limiter->enforce('login', $limiter->clientIp(), '/api/auth/login');

    $body = jsonBody();
    success($service->loginStudent(
        (string)($body['name'] ?? $body['nickname'] ?? ''),
        (string)($body['password'] ?? ''),
        isset($body['game_code']) ? (string)$body['game_code'] : null
    ));
}
```

教师登录同样加一行（路由不同，计数独立）：

```php
if ($method === 'POST' && $path === '/api/auth/admin-login') {
    $limiter->enforce('login', $limiter->clientIp(), '/api/auth/admin-login');

    $body = jsonBody();
    // ...
}
```

第 11 次会抛：

```json
{
  "ok": false,
  "error": {
    "code": "RATE_LIMITED",
    "message": "请求过于频繁，请稍后再试",
    "details": {
      "retry_after": 37,
      "rule": "login",
      "limit": 10,
      "window": 60
    }
  }
}
```

HTTP 状态为 `429`。建议在 `failure()` 里补 `Retry-After` 响应头：

```php
function failure(ApiException $e): never
{
    if ($e->errorCode === 'RATE_LIMITED') {
        header('Retry-After: ' . max(1, (int)($e->details['retry_after'] ?? 60)));
    }
    respond($e->httpStatus, [
        // 原样保留
    ]);
}
```

### 2.3 教室共用出口 IP 的注意点

默认规则是严格的 **10 次/分钟/IP**。如果 12 个学生通过同一间教室 Wi-Fi / 同一个公网 NAT 登录，前 10 个之后会有 2 个收到 429。两种处理方式，二选一：

**A. 提高阈值（推荐试跑）**

```php
'login' => ['limit' => 30, 'window' => 60],
```

**B. 把姓名并入 key（按“IP + 账号”计数）**

```php
$body = jsonBody();
$loginName = strtolower(trim((string)($body['name'] ?? $body['nickname'] ?? '')));
$limiter->enforce('login', $limiter->clientIp() . '|' . $loginName, '/api/auth/login');
```

B 能避免同班互相挤占，但对“换 IP 撞同一个账号”的分布式爆破更弱。公开互联网部署建议保持 IP 维度，并再加一条按账号的规则：

```php
'login_account' => ['limit' => 10, 'window' => 300],
```

```php
$limiter->enforce('login_account', 'name:' . $loginName, 'auth.login.account');
```

### 2.4 反向代理 / Cloudflare Tunnel

`cloudflared` 连到本机时，`REMOTE_ADDR` 通常是 `127.0.0.1`。如果直接按 IP 限流，**全校会共用一个计数器**。必须配置：

```php
'ratelimit' => [
    'trusted_proxies' => ['127.0.0.1', '::1'],
],
```

只有 `REMOTE_ADDR` 命中 `trusted_proxies` 时，`clientIp()` 才读取 `CF-Connecting-IP`，其次 `X-Forwarded-For`。如果 API 端口同时直接暴露在公网/局域网，不要信任这些头，否则攻击者可以伪造 IP 绕过限流。通用反代必须**覆盖**而不是追加 `X-Forwarded-For`。

---

## 3. 接入点三：出令 / 预估限流（60、120 次/分钟/玩家）

这两类必须放在 `requireAuth($service)` **之后**，用玩家 id 做 key（不要用 IP，避免同班共用 IP 互相影响）。

### 3.1 出令：60 次/分钟/玩家

两套出令入口都加，第三参数用同一个逻辑路由名，让它们共享 60 次配额：

```php
if ($method === 'POST' && $path === '/api/slice/orders') {
    $player = requireAuth($service);
    $limiter->enforce('order', 'player:' . $player['id'], 'slice.orders');
    success($service->submitOrder($player, jsonBody()), 200);
}
```

```php
if ($method === 'POST' && $path === '/api/slice/order/play') {
    $player = requireAuth($service);
    $limiter->enforce('order', 'player:' . $player['id'], 'slice.orders');
    $body = jsonBody();
    // ...
}
```

如果希望两个入口各自 60 次，把第三参数分别写成 `/api/slice/orders` 和 `/api/slice/order/play` 即可。

### 3.2 预估：120 次/分钟/玩家

```php
if ($method === 'POST' && $path === '/api/slice/battle/forecast') {
    $player = requireAuth($service);
    $limiter->enforce('forecast', 'player:' . $player['id'], 'slice.battle.forecast');
    $body = jsonBody();
    // ...
}
```

### 3.3 可选：演示战斗 / 充值

`battle/demo` 是审计 S-01/S-09 的高风险接口，建议同样限流（例如 `demo` 10 次/分钟/玩家）或直接下线；`recharge` 建议加 `recharge` 规则。它们不属于本次三个必接点，按主线程排期处理。

---

## 4. 生产配置示例

把下面合并进 `config.local.php` / `config.docker.php`（`config.example.php` 也建议同步）：

```php
<?php
return [
    'db' => [
        // 保持现有配置
    ],
    'app' => [
        'env' => 'production',
        'timezone' => 'Asia/Shanghai',
        'token_ttl_seconds' => 43200,
        'turn_seconds' => 600,

        // 生产安全开关
        'allow_fault_injection' => false,
        'allow_force_lock' => false,
        'expose_error_details' => false,
        'log_path' => __DIR__ . '/logs/api.log',

        // CORS：留空 = 不允许任何跨域浏览器直连；只列真实前端 origin
        'allowed_origins' => [
            // 'https://qingzhu.example.com',
        ],
        'cors_allow_credentials' => false,
        'cors_max_age' => 600,

        'ratelimit' => [
            'enabled' => true,
            'dir' => __DIR__ . '/logs/ratelimit', // 不要放在 public/ 下
            'fail_open' => true,                  // 目录故障时优先保可用；严格模式改 false
            // cloudflared / 本机 Nginx 反代；端口未直接暴露时才可信任
            'trusted_proxies' => ['127.0.0.1', '::1'],
            'rules' => [
                // 公网生产 10；教室共用出口 IP 的试跑建议 30，或按 2.3 B 方案把姓名并入 key
                'login' => ['limit' => 10, 'window' => 60],
                'order' => ['limit' => 60, 'window' => 60],
                'forecast' => ['limit' => 120, 'window' => 60],

                // 可选：按账号的分布式爆破保护
                // 'login_account' => ['limit' => 10, 'window' => 300],
            ],
        ],
    ],
];
```

生产检查：

- 生产填 `production` / `prod`；只有 `local` / `dev` / `test` 等显式开发环境才允许配置 `*`，其他值（含 `staging`）会忽略 `*`。
- `allowed_origins` 不要出现 `*`；确需临时放开时，用明确的 `https://host:port`。
- `logs/ratelimit` 已在 `.gitignore` 的 `logs/` 下，不会入库；不要把它映射到 Web 根目录。
- 单机/单容器才用文件限流；多副本（横向扩容）必须换 Redis 或把限流放到 Cloudflare / Nginx / API 网关。
- 容器文件系统若每次发布重置，计数会清零；这是可接受的降级，但不要把它当持久审计。

---

## 5. 默认口令、CORS `*`、登录爆破的处置建议

### 5.1 默认口令（审计 S-03，优先级最高）

现状：`GET /` 直接展示 `slice2026`，教师页预填 `teacher` / 占位 `teacher2026`，`legacy_seed.sql` 与试跑手册也公开同一组口令；8 个学生共用同一个 bcrypt hash。限流只能减慢爆破，**不能修复公开口令**。

处置顺序：

1. **从公开位置删除口令**：`index.php` 根路径说明页、`teacher.html`、`legacy_seed.sql`、`TRIAL_RUNBOOK.md`、`DEPLOY_RUNBOOK.md`、交接包中的日志（`logs/login.json`、`logs/login.out`）。
2. **每个学生独立随机口令**：优先用现有班级管理系统的重置密码功能；不要继续共用一个 hash，也不要把新口令写回种子文件。
3. 必须用脚本重置时，只在维护窗口、备份后执行；`students.score` 不动：

   ```php
   $hash = password_hash($newPassword, PASSWORD_BCRYPT);
   $stmt = $pdo->prepare('UPDATE students SET password = ? WHERE id = ?');
   $stmt->execute([$hash, $studentId]);
   ```

   教师账号同理：

   ```php
   $hash = password_hash($newPassword, PASSWORD_BCRYPT);
   $stmt = $pdo->prepare('UPDATE admin SET password = ? WHERE username = ?');
   $stmt->execute([$hash, 'teacher']);
   ```

4. **改密后清掉旧 token**：`slice_sessions` 里已有 token 不会因改密自动失效。试跑前可整体清空；定向失效用：

   ```sql
   -- 全部踢下线（维护窗口）
   TRUNCATE TABLE slice_sessions;

   -- 或只踢学生 / 只踢教师
   DELETE s FROM slice_sessions s
   JOIN slice_players p ON p.id = s.player_id
   JOIN students st ON st.id = p.student_id;

   DELETE s FROM slice_sessions s
   JOIN slice_players p ON p.id = s.player_id
   WHERE p.role = 'teacher';
   ```

5. **重命名/停用默认 `teacher`**：不要保留可从公网猜到的管理员用户名；教师控制台放到 SSO、内网或 IP allowlist 后面。
6. 口令只进密码哈希，不进日志、URL、错误信息；不要把 `password` 写进 `slice_log()` 的 context。

### 5.2 CORS `*`（审计 S-03 / S-09）

- 删除 `index.php` 的 `Access-Control-Allow-Origin: *`，改为第 1 节的白名单。
- 只把真实前端 origin 加进 `allowed_origins`；教师站如果是服务端代理，不需要加。
- 生产不要出现 `*`，更不要 `*` + `Access-Control-Allow-Credentials: true`。
- 不要把 CORS 当认证：它只阻止浏览器读取响应，脚本/curl 仍可调用；真正的控制是 token、限流、教师接口隔离。
- 教师控制台建议：独立域名 + SSO/内网 + IP allowlist + 二次确认；至少不要和学生 App 共用同一个公开 origin。

### 5.3 登录爆破（审计 S-03 / S-09）

分层处理，单靠应用限流不够：

1. **网关层**：Cloudflare Rate Limiting / WAF 对 `/api/auth/*` 做 IP + 路径限速；这是抗分布式爆破的第一层。
2. **应用层**：本中间件，登录 10 次/分钟/IP；教室 NAT 场景按 2.3 调整。
3. **账号维度**：对同一账号跨 IP 的失败做计数（`login_account` 规则或独立失败表），例如 10 次失败/5 分钟锁 15 分钟；要提供教师解锁入口，避免全班共用弱口令时集体锁死。
4. **审计**：对 401 / 429 记录 `request_id`、IP、账号名、路由、时间；**不要记录密码**。对 401 突增、单 IP 多账号、单账号多 IP 设告警。
5. **错误信息**：学生登录对“用户不存在”和“密码错误”保持同一个 `UNAUTHORIZED` 文案（当前实现已如此），不要新增可枚举账号的提示。
6. **教师入口**：独立路径/域名、禁用默认账号、强制强口令、优先 SSO；教师 token 权限大，不要和学生登录共用同一爆破面。
7. **传输**：只走 HTTPS（Cloudflare Tunnel 已提供）；HBuilder/Godot 客户端不要关闭证书校验。
8. **收尾**：完成 5.1 的公开口令清理后，再观察 401 日志；否则限流只是给公开口令加了一层减速带。

---

## 6. 运维与已知边界

- **单机限定**：文件锁只在同一台主机/同一个容器内有效；多副本会各自计数。
- **固定窗口**：窗口边界最多放行 2×limit（例如 10 次/分钟在 59 秒和 61 秒各打 10 次）。登录场景可接受；需要平滑改用滑动窗口/令牌桶。
- **fail-open**：默认目录不可写时放行并写 `error_log`，避免磁盘故障导致全员无法登录；要高安全改 `fail_open => false`（此时返回 503 `RATE_LIMIT_UNAVAILABLE`）。
- **目录清理**：每 200 次请求有约 1 次机会清理 1 天前的 key；也可在 cron 里调用 `$limiter->prune(86400)`。目录按 key 数量增长，不按请求数增长。
- **隐私**：文件名是 `规则名 + sha256(route|subject)`，不落 IP/玩家名明文；不要把限流目录提交到 Git 或暴露为静态目录。
- **磁盘 DoS**：大量随机 IP 仍可能产生很多小文件；公网部署必须配合网关限流/WAF。
- **CORS 不是 CSRF 防护**：本项目用 `Authorization` 头而非 cookie，CSRF 风险较低；但白名单 origin 上的 XSS 仍能读 token，前端仍需转义与 CSP。

---

## 7. 验收

本次中间件可独立验收，不依赖数据库：

```powershell
php server/slice/tests/rate_limiter_test.php
# 期望最后一行：RATE_LIMITER PASS
```

主线程接入 `index.php` 后，追加回归：

```powershell
php -d extension_dir="<php>\ext" -d extension=pdo_mysql server/slice/tests/run.php
# 期望：14 passed, 0 failed
```

手工检查（接入后）：

```powershell
# 1) 预检：白名单 origin 应返回 204 + Access-Control-Allow-Origin
curl.exe -i -X OPTIONS http://127.0.0.1:8081/api/auth/login `
  -H "Origin: http://127.0.0.1:8081" `
  -H "Access-Control-Request-Method: POST"

# 2) 非白名单 origin 不应返回 Access-Control-Allow-Origin
curl.exe -i -X OPTIONS http://127.0.0.1:8081/api/auth/login `
  -H "Origin: https://evil.example"

# 3) 登录第 11 次应为 429，且带 Retry-After
1..11 | ForEach-Object {
  curl.exe -s -o NUL -w "%{http_code}\n" -X POST http://127.0.0.1:8081/api/auth/login `
    -H "Content-Type: application/json" `
    -d '{"name":"青竹一","password":"wrong"}'
}
```

接入检查清单：

- [ ] 删除旧的 `Access-Control-Allow-Origin: *` 与旧 `OPTIONS` 分支
- [ ] `CorsPolicy` 在 `$path` 解析后、任何输出前调用
- [ ] `allowed_origins` 生产为空或明确白名单，无 `*`
- [ ] `RateLimiter::fromConfig($config)` 在 bootstrap 后初始化
- [ ] 登录两个入口（学生/教师）在 `jsonBody()` 前限流
- [ ] 出令两个入口（`/orders`、`/order/play`）在 `requireAuth` 后限流，共享 `slice.orders`
- [ ] 预估 `/battle/forecast` 在 `requireAuth` 后限流
- [ ] `failure()` 对 `RATE_LIMITED` 输出 `Retry-After`
- [ ] cloudflared/反代场景配置 `trusted_proxies`，且源站端口未直接暴露
- [ ] 默认口令已轮换、公开页面/种子/手册已删除口令、旧 session 已清理
- [ ] 现有 14 项后端测试仍通过
