<?php
declare(strict_types=1);

require_once __DIR__ . '/src/ApiException.php';
require_once __DIR__ . '/src/Clock.php';
require_once __DIR__ . '/src/Db.php';
require_once __DIR__ . '/src/PointsService.php';
require_once __DIR__ . '/src/SliceService.php';

/**
 * @return array{0: array, 1: PDO, 2: SliceService}
 */
function slice_bootstrap(): array
{
    $configPath = getenv('SLICE_CONFIG') ?: __DIR__ . '/config.local.php';
    if (!is_file($configPath)) {
        throw new RuntimeException('缺少配置：' . $configPath . '，请从 config.example.php 复制');
    }
    $config = require $configPath;
    $timezone = (string)($config['app']['timezone'] ?? 'Asia/Shanghai');
    date_default_timezone_set($timezone);

    $logPath = (string)($config['app']['log_path'] ?? __DIR__ . '/logs/api.log');
    $logDir = dirname($logPath);
    if (!is_dir($logDir)) {
        @mkdir($logDir, 0775, true);
    }

    $pdo = Db::connect($config['db']);
    $service = new SliceService($pdo, $config);
    return [$config, $pdo, $service];
}

function slice_log(string $message, array $context = []): void
{
    try {
        $configPath = getenv('SLICE_CONFIG') ?: __DIR__ . '/config.local.php';
        $config = is_file($configPath) ? require $configPath : [];
        $path = (string)($config['app']['log_path'] ?? __DIR__ . '/logs/api.log');
        $dir = dirname($path);
        if (!is_dir($dir)) {
            @mkdir($dir, 0775, true);
        }
        $line = json_encode([
            'ts' => date('c'),
            'message' => $message,
            'context' => $context,
        ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        @file_put_contents($path, $line . PHP_EOL, FILE_APPEND | LOCK_EX);
    } catch (Throwable $e) {
        error_log($message);
    }
}
