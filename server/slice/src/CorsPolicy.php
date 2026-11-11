<?php
declare(strict_types=1);

/**
 * CORS 白名单策略。
 *
 * 读取 config['app']['allowed_origins']：
 *   - 数组或逗号分隔字符串，元素是完整 origin（scheme + host + port，不带路径）；
 *   - 默认（未配置 / 空数组）不返回任何 Access-Control-Allow-Origin，即拒绝跨域浏览器请求；
 *   - 只有 app.env 是 local / dev / test 等显式开发环境时，字面量 "*" 才生效；
 *     生产、预发、未配置环境都会忽略并记 error_log。
 *
 * 用法（index.php 顶部，输出任何内容之前）：
 *   $cors = CorsPolicy::fromConfig($config);
 *   if ($cors->handlePreflight()) {
 *       exit;
 *   }
 *   $cors->apply();
 */
final class CorsPolicy
{
    /** @var list<string> */
    private array $origins;

    private bool $allowAny;

    private bool $allowCredentials;

    private int $maxAge;

    private string $allowMethods = 'GET, POST, OPTIONS';

    private string $allowHeaders = 'Content-Type, Authorization, X-Auth-Token, X-Request-Id';

    /**
     * @param array<string, mixed> $config 完整配置，或只含 allowed_origins 的 app 配置
     */
    public function __construct(array $config)
    {
        $app = isset($config['app']) && is_array($config['app']) ? $config['app'] : $config;

        $raw = $app['allowed_origins'] ?? [];
        if (is_string($raw)) {
            $raw = preg_split('/[\s,]+/', $raw, -1, PREG_SPLIT_NO_EMPTY) ?: [];
        }
        if (!is_array($raw)) {
            $raw = [];
        }

        $environment = strtolower(trim((string)($app['env'] ?? 'production')));
        $wildcardAllowed = in_array($environment, ['local', 'development', 'dev', 'test', 'testing'], true);

        $origins = [];
        $wildcard = false;
        foreach ($raw as $item) {
            $origin = rtrim(trim((string)$item), '/');
            if ($origin === '') {
                continue;
            }
            if ($origin === '*') {
                $wildcard = true;
                continue;
            }
            if (str_contains($origin, '*')) {
                error_log('[cors] 不支持通配域名，已忽略：' . $origin);
                continue;
            }
            $origins[] = $origin;
        }

        if ($wildcard && !$wildcardAllowed) {
            error_log('[cors] 当前环境不允许 allowed_origins 包含 *，已忽略（env=' . $environment . '）');
            $wildcard = false;
        }

        $this->origins = array_values(array_unique($origins));
        $this->allowAny = $wildcard;
        $this->allowCredentials = (bool)($app['cors_allow_credentials'] ?? false);

        $maxAge = (int)($app['cors_max_age'] ?? 600);
        $this->maxAge = max(0, min(86400, $maxAge));
    }

    /**
     * @param array<string, mixed> $config
     */
    public static function fromConfig(array $config): self
    {
        return new self($config);
    }

    public function isAllowed(string $origin): bool
    {
        $origin = rtrim(trim($origin), '/');
        if ($origin === '') {
            return false;
        }
        if ($this->allowAny) {
            return true;
        }
        foreach ($this->origins as $allowed) {
            if (strcasecmp($allowed, $origin) === 0) {
                return true;
            }
        }
        return false;
    }

    /**
     * 计算当前请求（或指定 origin）应返回的 CORS 头。
     *
     * @return array<string, string>
     */
    public function headers(?string $origin = null): array
    {
        $origin = $origin ?? (string)($_SERVER['HTTP_ORIGIN'] ?? '');
        $origin = rtrim(trim($origin), '/');
        if ($origin === '' || !$this->isAllowed($origin)) {
            return [];
        }

        // 带凭据时不能返回 "*"，必须回显具体 origin；不带凭据时开发环境允许 "*"。
        $allowOrigin = ($this->allowAny && !$this->allowCredentials) ? '*' : $origin;

        $headers = [
            'Access-Control-Allow-Origin' => $allowOrigin,
            'Access-Control-Allow-Methods' => $this->allowMethods,
            'Access-Control-Allow-Headers' => $this->allowHeaders,
            'Access-Control-Max-Age' => (string)$this->maxAge,
        ];

        if ($allowOrigin !== '*') {
            // 同一个 URL 对不同 Origin 返回不同 ACAO，缓存必须按 Origin 区分。
            $headers['Vary'] = 'Origin';
        }
        if ($this->allowCredentials) {
            $headers['Access-Control-Allow-Credentials'] = 'true';
        }

        return $headers;
    }

    /**
     * 输出当前请求的 CORS 头；未命中白名单时不输出任何 ACAO。
     */
    public function apply(): void
    {
        if (headers_sent()) {
            return;
        }
        foreach ($this->headers() as $name => $value) {
            header($name . ': ' . $value, false);
        }
    }

    /**
     * OPTIONS 预检：输出 CORS 头、返回 204 并返回 true；非 OPTIONS 返回 false。
     * 调用方拿到 true 后自行 exit。
     */
    public function handlePreflight(?string $method = null): bool
    {
        $method = strtoupper($method ?? (string)($_SERVER['REQUEST_METHOD'] ?? 'GET'));
        if ($method !== 'OPTIONS') {
            return false;
        }

        $this->apply();
        if (!headers_sent()) {
            http_response_code(204);
        }
        return true;
    }
}
