<?php
declare(strict_types=1);

require_once __DIR__ . '/../src/ApiException.php';
require_once __DIR__ . '/../src/RateLimiter.php';

/**
 * 独立限流测试：不加载 bootstrap、不连数据库。
 * 用注入时钟模拟窗口过期，避免真实 sleep。
 */

$failed = 0;

function check(string $name, bool $ok, string $detail = ''): void
{
    global $failed;
    echo ($ok ? '[PASS] ' : '[FAIL] ') . $name . ($detail !== '' ? ' — ' . $detail : '') . PHP_EOL;
    if (!$ok) {
        $failed++;
    }
}

$dir = sys_get_temp_dir() . '/qingzhu_ratelimit_' . bin2hex(random_bytes(4));
register_shutdown_function(static function () use ($dir): void {
    foreach (glob($dir . '/*.json') ?: [] as $file) {
        @unlink($file);
    }
    @rmdir($dir);
});

$now = 1_700_000_000;
$clock = static function () use (&$now): int {
    return $now;
};

// 短窗口（2 秒），limit 仍为登录默认的 10 次。
$limiter = new RateLimiter(
    $dir,
    ['login' => ['limit' => 10, 'window' => 2]],
    true,
    true,
    $clock
);

$ip = '203.0.113.7';
$route = '/api/auth/login';

$allowed = 0;
for ($i = 1; $i <= 10; $i++) {
    $result = $limiter->enforce('login', $ip, $route);
    if (($result['allowed'] ?? false) === true) {
        $allowed++;
    }
}
check('同一 key 前 10 次放行', $allowed === 10, 'allowed=' . $allowed);

$exception = null;
try {
    $limiter->enforce('login', $ip, $route);
} catch (ApiException $e) {
    $exception = $e;
}

check(
    '第 11 次被拒且错误码为 RATE_LIMITED',
    $exception !== null && $exception->errorCode === 'RATE_LIMITED',
    $exception === null ? '未抛异常' : $exception->errorCode
);
check(
    '限流异常返回 HTTP 429',
    $exception !== null && $exception->httpStatus === 429,
    $exception === null ? '未抛异常' : (string)$exception->httpStatus
);

$retryAfter = $exception === null ? 0 : (int)($exception->details['retry_after'] ?? 0);
check('details.retry_after 在 1..2 秒内', $retryAfter >= 1 && $retryAfter <= 2, 'retry_after=' . $retryAfter);

// 不同 IP：不受影响。
$otherIp = $limiter->enforce('login', '203.0.113.8', $route);
check('不同 key（换 IP）不受影响', $otherIp['remaining'] === 9, 'remaining=' . $otherIp['remaining']);

// 同一 IP、不同路由：key 含 route，互不影响。
$otherRoute = $limiter->enforce('login', $ip, '/api/auth/admin-login');
check('不同路由不受影响', $otherRoute['remaining'] === 9, 'remaining=' . $otherRoute['remaining']);

// 不同规则：order 是独立的 60 次/分钟。
$order = $limiter->enforce('order', 'player:1');
check('不同规则独立计数', $order['limit'] === 60 && $order['remaining'] === 59, json_encode($order, JSON_UNESCAPED_UNICODE));

// 窗口过期：时钟前进 2 秒后同一 key 恢复。
$now += 2;
$recovered = $limiter->enforce('login', $ip, $route);
check('窗口过期后恢复', $recovered['allowed'] === true && $recovered['remaining'] === 9, 'remaining=' . $recovered['remaining']);

// 默认规则：登录 10/60、出令 60/60、预估 120/60。
$defaults = RateLimiter::fromConfig(['app' => []])->rules();
check('默认登录 10 次/分钟', $defaults['login'] === ['limit' => 10, 'window' => 60], json_encode($defaults['login']));
check('默认出令 60 次/分钟', $defaults['order'] === ['limit' => 60, 'window' => 60], json_encode($defaults['order']));
check('默认预估 120 次/分钟', $defaults['forecast'] === ['limit' => 120, 'window' => 60], json_encode($defaults['forecast']));

// 客户端 IP：未信任代理时忽略可伪造的头。
$spoofed = RateLimiter::resolveClientIp([
    'REMOTE_ADDR' => '198.51.100.9',
    'HTTP_X_FORWARDED_FOR' => '1.2.3.4',
    'HTTP_CF_CONNECTING_IP' => '5.6.7.8',
], []);
check('未信任代理时忽略 X-Forwarded-For', $spoofed === '198.51.100.9', $spoofed);

$proxied = RateLimiter::resolveClientIp([
    'REMOTE_ADDR' => '127.0.0.1',
    'HTTP_CF_CONNECTING_IP' => '2001:db8::1',
], ['127.0.0.1']);
check('信任代理时读取 CF-Connecting-IP 并规范化 IPv6', $proxied === '2001:db8::1', $proxied);

echo PHP_EOL;
if ($failed > 0) {
    echo 'RATE_LIMITER FAIL (' . $failed . ')' . PHP_EOL;
    exit(1);
}
echo 'RATE_LIMITER PASS' . PHP_EOL;
exit(0);
