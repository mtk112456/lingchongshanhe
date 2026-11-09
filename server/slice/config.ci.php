<?php
// GitHub Actions / CI 配置：只从环境变量读取，不包含真实密码。
return [
    'db' => [
        'host' => getenv('DB_HOST') ?: '127.0.0.1',
        'port' => (int)(getenv('DB_PORT') ?: 3306),
        'name' => getenv('DB_NAME') ?: 'qingzhu_slice_test',
        'user' => getenv('DB_USER') ?: 'qingzhu_test',
        'pass' => getenv('DB_PASS') ?: 'slice_dev_only_2026',
        'charset' => 'utf8mb4',
    ],
    'app' => [
        'timezone' => 'Asia/Shanghai',
        'token_ttl_seconds' => 43200,
        'turn_seconds' => 600,
        // CI 要验证“结算失败补算”，测试配置允许故障注入。
        'allow_fault_injection' => true,
        'allow_force_lock' => true,
        'expose_error_details' => true,
        'log_path' => dirname(__DIR__) . '/logs/api.log',
    ],
];
