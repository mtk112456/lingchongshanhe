<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/bootstrap.php';

try {
    [$config, $pdo, $service] = slice_bootstrap();
    $result = $service->runDueTurns(true);
    echo json_encode($result, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES), PHP_EOL;
    exit(0);
} catch (Throwable $e) {
    fwrite(STDERR, 'cron failed: ' . $e->getMessage() . PHP_EOL);
    exit(1);
}
