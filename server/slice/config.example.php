<?php
// 复制为 config.local.php 后填写。生产环境必须关闭 allow_fault_injection / expose_error_details。
return [
    'db' => [
        'host' => '127.0.0.1',
        'port' => 3307,
        'name' => 'qingzhu_slice_test',
        'user' => 'qingzhu_test',
        'pass' => 'change_me',
        'charset' => 'utf8mb4',
    ],
    'app' => [
        'timezone' => 'Asia/Shanghai',
        'token_ttl_seconds' => 43200,
        'turn_seconds' => 600,
        // 仅测试环境：允许注入一次结算失败，用于验收“失败补算”。
        'allow_fault_injection' => false,
        // 仅测试环境：允许教师在截止前强制锁令。
        'allow_force_lock' => false,
        // 仅测试环境：API 返回异常细节。
        'expose_error_details' => false,
        'log_path' => __DIR__ . '/logs/api.log',
    ],
];
