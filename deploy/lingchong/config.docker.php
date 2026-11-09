<?php
// Docker 环境配置：只从容器环境变量读取，不把密码写进镜像。
$env = static function (string $key, mixed $default = null): mixed {
    $value = getenv($key);
    return ($value !== false && $value !== '') ? $value : $default;
};

return [
    'db' => [
        'host' => $env('DB_HOST', 'db'),
        'port' => (int)$env('DB_PORT', 3306),
        'name' => $env('DB_NAME', $env('TEACHING_DB_NAME', 'class_manager')),
        'user' => $env('DB_USER', $env('TEACHING_DB_USER', 'class')),
        'pass' => $env('DB_PASS', $env('TEACHING_DB_PASSWORD', '')),
        'charset' => $env('DB_CHARSET', 'utf8mb4'),
    ],
    'app' => [
        'timezone' => 'Asia/Shanghai',
        'token_ttl_seconds' => 43200,
        'turn_seconds' => (int)$env('TURN_SECONDS', 600),
        'allow_fault_injection' => false,
        'allow_force_lock' => $env('ALLOW_FORCE_LOCK', '0') === '1',
        'expose_error_details' => false,
        'log_path' => '/var/www/html/logs/api.log',
    ],
];
