<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/bootstrap.php';

$mode = (string)($argv[1] ?? '');
$startAt = (float)($argv[2] ?? 0);
$who = (string)($argv[3] ?? '');
$action = (string)($argv[4] ?? '');
$origin = (string)($argv[5] ?? '');
$target = (string)($argv[6] ?? '');
$requestKey = (string)($argv[7] ?? '');

try {
    [$config, $pdo, $service] = slice_bootstrap();

    if ($mode === 'submit') {
        $login = $service->loginStudent($who, 'slice2026');
        $player = $service->authenticate($login['token']);
    } elseif ($mode === 'lock') {
        $login = $service->loginAdmin($who, 'teacher2026');
        $player = $service->authenticate($login['token']);
    } else {
        throw new RuntimeException('unknown mode: ' . $mode);
    }

    $delay = $startAt - microtime(true);
    if ($delay > 0) {
        usleep((int)round($delay * 1000000));
    }

    if ($mode === 'submit') {
        $result = $service->submitOrder($player, [
            'turn_id' => 1,
            'action' => $action,
            'origin_node' => $origin,
            'target_node' => $target,
            'request_key' => $requestKey,
        ]);
        echo json_encode([
            'ok' => true,
            'mode' => 'submit',
            'player_id' => (int)$player['id'],
            'target' => $result['order']['target_node_code'],
            'idempotent' => (bool)($result['idempotent'] ?? false),
        ], JSON_UNESCAPED_UNICODE), PHP_EOL;
    } else {
        $result = $service->lockTurn($player, 1, true);
        echo json_encode([
            'ok' => true,
            'mode' => 'lock',
            'already' => (bool)($result['already'] ?? false),
            'snapshot_id' => $result['snapshot']['snapshot_id'] ?? ($result['turn']['snapshot_id'] ?? null),
        ], JSON_UNESCAPED_UNICODE), PHP_EOL;
    }
} catch (ApiException $e) {
    echo json_encode([
        'ok' => false,
        'mode' => $mode,
        'code' => $e->errorCode,
        'message' => $e->getMessage(),
        'status' => $e->httpStatus,
    ], JSON_UNESCAPED_UNICODE), PHP_EOL;
} catch (Throwable $e) {
    echo json_encode([
        'ok' => false,
        'mode' => $mode,
        'code' => 'EXCEPTION',
        'message' => $e->getMessage(),
    ], JSON_UNESCAPED_UNICODE), PHP_EOL;
}
