<?php
declare(strict_types=1);

require_once __DIR__ . '/ApiException.php';

/**
 * 固定窗口限流：flock + 每 key 一个 JSON 文件，不依赖 APCu / Redis。
 *
 * 文件内容：{"window_start": 1710000000, "count": 3}
 *   - 同一 key 在同一窗口内累加；
 *   - 进入新窗口后从 1 重新计数；
 *   - flock(LOCK_EX) 保证并发请求不丢计数；
 *   - 文件名只含规则名 + key 的 sha256，不把 IP / 玩家名写进文件名。
 *
 * 用法：
 *   $limiter = RateLimiter::fromConfig($config);
 *   $limiter->enforce('login', $limiter->clientIp());          // 10 次/分钟/IP
 *   $limiter->enforce('order', 'player:' . $player['id']);     // 60 次/分钟/玩家
 *
 * 生产注意：
 *   - 只适合单机 / 单容器；多副本部署要换 Redis 或在网关层限流。
 *   - 默认 fail-open：目录不可写时记 error_log 并放行，避免限流器故障拖垮登录；
 *     需要“限流器故障即拒绝”时把 ratelimit.fail_open 设为 false。
 *   - 固定窗口在边界最多放行 2×limit；登录场景可接受，更平滑需滑动窗口。
 */
final class RateLimiter
{
    /**
     * 默认规则：登录 10 次/分钟、出令 60 次/分钟、预估 120 次/分钟。
     *
     * @var array<string, array{limit: int, window: int}>
     */
    public const DEFAULT_RULES = [
        'login' => ['limit' => 10, 'window' => 60],
        'order' => ['limit' => 60, 'window' => 60],
        'forecast' => ['limit' => 120, 'window' => 60],
    ];

    /** 大约每 200 次请求顺手清理一次过期文件。 */
    private const PRUNE_EVERY = 200;
    private const PRUNE_MAX_AGE = 86400;

    private string $dir;

    /** @var array<string, array{limit: int, window: int}> */
    private array $rules;

    private bool $enabled;
    private bool $failOpen;

    /** @var list<string> */
    private array $trustedProxies;

    /** @var Closure(): int */
    private Closure $clock;

    /**
     * @param array<string, array{limit?: int, window?: int}> $rules
     * @param list<string> $trustedProxies 只有这些来源地址才信任 CF-Connecting-IP / X-Forwarded-For
     * @param callable(): int|null $clock 仅测试用；默认 time()
     */
    public function __construct(
        string $dir = '',
        array $rules = [],
        bool $enabled = true,
        bool $failOpen = true,
        ?callable $clock = null,
        array $trustedProxies = []
    ) {
        $dir = trim($dir);
        $this->dir = rtrim($dir !== '' ? $dir : dirname(__DIR__) . '/logs/ratelimit', '/\\');
        $this->rules = self::normalizeRules($rules);
        $this->enabled = $enabled;
        $this->failOpen = $failOpen;
        $this->trustedProxies = array_values(array_map('strval', $trustedProxies));
        $this->clock = $clock === null ? static fn(): int => time() : Closure::fromCallable($clock);
    }

    /**
     * @param array<string, mixed> $config 完整配置（读取 app.ratelimit.*）
     */
    public static function fromConfig(array $config): self
    {
        $app = is_array($config['app'] ?? null) ? $config['app'] : [];
        $options = is_array($app['ratelimit'] ?? null) ? $app['ratelimit'] : [];
        $rules = is_array($options['rules'] ?? null) ? $options['rules'] : [];

        $trusted = $options['trusted_proxies'] ?? [];
        if (is_string($trusted)) {
            $trusted = preg_split('/[\s,]+/', $trusted, -1, PREG_SPLIT_NO_EMPTY) ?: [];
        }
        $trusted = is_array($trusted) ? array_values(array_map('strval', $trusted)) : [];

        return new self(
            (string)($options['dir'] ?? dirname(__DIR__) . '/logs/ratelimit'),
            $rules,
            (bool)($options['enabled'] ?? true),
            (bool)($options['fail_open'] ?? true),
            null,
            $trusted
        );
    }

    public function isEnabled(): bool
    {
        return $this->enabled;
    }

    /**
     * @return array<string, array{limit: int, window: int}>
     */
    public function rules(): array
    {
        return $this->rules;
    }

    /**
     * 计数一次；超过规则上限时抛 429 RATE_LIMITED。
     *
     * @return array{allowed: bool, rule: string, limit: int, remaining: int, window: int, retry_after: int, reset_at: string, degraded?: bool}
     */
    public function enforce(string $rule, string $subject, ?string $route = null): array
    {
        $ruleName = trim($rule) !== '' ? trim($rule) : 'default';
        $subject = trim($subject) !== '' ? trim($subject) : 'unknown';
        $routeName = $route !== null && trim($route) !== '' ? trim($route) : $ruleName;

        $config = $this->rules[$ruleName] ?? ['limit' => 60, 'window' => 60];
        $limit = max(1, (int)$config['limit']);
        $window = max(1, (int)$config['window']);

        $now = (int)($this->clock)();
        $windowStart = intdiv($now, $window) * $window;
        $resetAt = $windowStart + $window;
        $retryAfter = max(1, $resetAt - $now);

        if (!$this->enabled) {
            return $this->decision($ruleName, $limit, $limit, $window, $resetAt);
        }

        $path = $this->pathFor($ruleName, $routeName . '|' . $subject);

        try {
            $count = $this->increment($path, $windowStart);
        } catch (Throwable $e) {
            error_log('[ratelimit] ' . $e->getMessage());
            if ($this->failOpen) {
                $decision = $this->decision($ruleName, $limit, $limit, $window, $resetAt);
                $decision['degraded'] = true;
                return $decision;
            }
            throw new ApiException('RATE_LIMIT_UNAVAILABLE', '限流服务暂不可用，请稍后再试', 503);
        }

        if ($count > $limit) {
            throw new ApiException('RATE_LIMITED', '请求过于频繁，请稍后再试', 429, [
                'retry_after' => $retryAfter,
                'rule' => $ruleName,
                'limit' => $limit,
                'window' => $window,
            ]);
        }

        // 顺手清理一天前的旧 key，避免长期运行后目录膨胀；失败不影响限流。
        try {
            if (random_int(1, self::PRUNE_EVERY) === 1) {
                $this->prune(self::PRUNE_MAX_AGE);
            }
        } catch (Throwable) {
            // ignore
        }

        return $this->decision($ruleName, $limit, max(0, $limit - $count), $window, $resetAt);
    }

    /**
     * 清空某个 key 的计数（运维/测试用）。
     */
    public function reset(string $rule, string $subject, ?string $route = null): void
    {
        $ruleName = trim($rule) !== '' ? trim($rule) : 'default';
        $subject = trim($subject) !== '' ? trim($subject) : 'unknown';
        $routeName = $route !== null && trim($route) !== '' ? trim($route) : $ruleName;
        $path = $this->pathFor($ruleName, $routeName . '|' . $subject);
        if (is_file($path)) {
            @unlink($path);
        }
    }

    /**
     * 删除超过 $maxAgeSeconds 未更新的计数文件。
     */
    public function prune(int $maxAgeSeconds = self::PRUNE_MAX_AGE): int
    {
        $maxAgeSeconds = max(60, $maxAgeSeconds);
        $cutoff = time() - $maxAgeSeconds;
        $deleted = 0;
        foreach (glob($this->dir . DIRECTORY_SEPARATOR . '*.json') ?: [] as $file) {
            $mtime = @filemtime($file);
            if ($mtime !== false && $mtime < $cutoff && @unlink($file)) {
                $deleted++;
            }
        }
        return $deleted;
    }

    /**
     * 当前请求客户端 IP。
     *
     * 只有 REMOTE_ADDR 命中 trusted_proxies 时才读取 CF-Connecting-IP /
     * X-Forwarded-For；否则任何客户端都能伪造请求头绕过限流。
     */
    public function clientIp(?array $server = null): string
    {
        return self::resolveClientIp($server ?? $_SERVER, $this->trustedProxies);
    }

    /**
     * @param array<string, mixed> $server
     * @param list<string> $trustedProxies
     */
    public static function resolveClientIp(?array $server, array $trustedProxies = []): string
    {
        $server ??= [];
        $remote = self::normalizeIp((string)($server['REMOTE_ADDR'] ?? ''));

        $trusted = false;
        if ($remote !== null) {
            foreach ($trustedProxies as $proxy) {
                if (self::proxyMatches($remote, (string)$proxy)) {
                    $trusted = true;
                    break;
                }
            }
        }

        if ($trusted) {
            foreach (['HTTP_CF_CONNECTING_IP', 'HTTP_X_FORWARDED_FOR'] as $header) {
                $value = (string)($server[$header] ?? '');
                if ($value === '') {
                    continue;
                }
                foreach (explode(',', $value) as $part) {
                    $ip = self::normalizeIp(trim($part));
                    if ($ip !== null) {
                        return $ip;
                    }
                }
            }
        }

        return $remote ?? 'unknown';
    }

    /**
     * @param array<string, array{limit?: int, window?: int}> $rules
     * @return array<string, array{limit: int, window: int}>
     */
    private static function normalizeRules(array $rules): array
    {
        $normalized = [];
        foreach (self::DEFAULT_RULES as $name => $default) {
            $custom = isset($rules[$name]) && is_array($rules[$name]) ? $rules[$name] : [];
            $normalized[$name] = [
                'limit' => max(1, (int)($custom['limit'] ?? $default['limit'])),
                'window' => max(1, (int)($custom['window'] ?? $default['window'])),
            ];
        }

        // 允许调用方追加自定义规则，例如 login_account。
        foreach ($rules as $name => $custom) {
            $name = (string)$name;
            if ($name === '' || isset($normalized[$name]) || !is_array($custom)) {
                continue;
            }
            $normalized[$name] = [
                'limit' => max(1, (int)($custom['limit'] ?? 60)),
                'window' => max(1, (int)($custom['window'] ?? 60)),
            ];
        }

        return $normalized;
    }

    /**
     * @return array{allowed: bool, rule: string, limit: int, remaining: int, window: int, retry_after: int, reset_at: string}
     */
    private function decision(
        string $rule,
        int $limit,
        int $remaining,
        int $window,
        int $resetAt
    ): array {
        return [
            'allowed' => true,
            'rule' => $rule,
            'limit' => $limit,
            'remaining' => max(0, $remaining),
            'window' => $window,
            'retry_after' => 0,
            'reset_at' => date('c', $resetAt),
        ];
    }

    private function pathFor(string $rule, string $key): string
    {
        $prefix = preg_replace('/[^A-Za-z0-9_-]+/', '_', $rule);
        if ($prefix === null || $prefix === '') {
            $prefix = 'rule';
        }
        return $this->dir . DIRECTORY_SEPARATOR . $prefix . '-' . hash('sha256', $key) . '.json';
    }

    /**
     * 在独占锁内完成“读 → 判断窗口 → 写回”，返回本次的计数。
     */
    private function increment(string $path, int $windowStart): int
    {
        $this->ensureDir();

        $handle = @fopen($path, 'c+');
        if ($handle === false) {
            throw new RuntimeException('无法打开限流文件：' . $path);
        }

        try {
            if (!flock($handle, LOCK_EX)) {
                throw new RuntimeException('无法锁定限流文件：' . $path);
            }

            $raw = stream_get_contents($handle);
            $state = json_decode((string)$raw, true);
            $count = 0;
            if (is_array($state) && (int)($state['window_start'] ?? 0) === $windowStart) {
                $count = max(0, (int)($state['count'] ?? 0));
            }
            $count++;

            rewind($handle);
            ftruncate($handle, 0);
            fwrite($handle, (string)json_encode([
                'window_start' => $windowStart,
                'count' => $count,
            ]));
            fflush($handle);

            return $count;
        } finally {
            @flock($handle, LOCK_UN);
            fclose($handle);
        }
    }

    private function ensureDir(): void
    {
        if (is_dir($this->dir)) {
            return;
        }
        if (!@mkdir($this->dir, 0775, true) && !is_dir($this->dir)) {
            throw new RuntimeException('无法创建限流目录：' . $this->dir);
        }
    }

    private static function normalizeIp(string $value): ?string
    {
        $value = trim($value);
        if ($value === '') {
            return null;
        }
        $packed = @inet_pton($value);
        if ($packed === false) {
            return null;
        }
        $ip = @inet_ntop($packed);
        return $ip === false ? null : $ip;
    }
}
