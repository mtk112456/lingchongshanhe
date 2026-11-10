<?php
declare(strict_types=1);

/**
 * 8 人 × 3 令并发压测
 *
 * 启动独立 API（8098）→ 8 人登录 → 24 个 play 同时发 → 教师结算 → 校验。
 *
 * 用法：
 *   php server/slice/tests/card_concurrency_test.php
 */

require_once __DIR__ . '/../bootstrap.php';

$failed = 0;
function check(string $name, bool $ok, string $detail = ''): void
{
    global $failed;
    echo ($ok ? '[PASS] ' : '[FAIL] ') . $name . ($detail !== '' ? ' — ' . $detail : '') . PHP_EOL;
    if (!$ok) {
        $failed++;
    }
}

function httpJson(string $method, string $url, ?array $body = null, ?string $token = null): array
{
    $ch = curl_init($url);
    $headers = ['Content-Type: application/json'];
    if ($token !== null) {
        $headers[] = 'Authorization: Bearer ' . $token;
    }
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CUSTOMREQUEST => $method,
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_TIMEOUT => 15,
    ]);
    if ($body !== null) {
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($body, JSON_UNESCAPED_UNICODE));
    }
    $raw = curl_exec($ch);
    $code = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    return ['code' => $code, 'json' => json_decode((string)$raw, true), 'raw' => (string)$raw];
}

$port = 8098;
$base = "http://127.0.0.1:$port";
$php = PHP_BINARY;
$ext = dirname($php) . DIRECTORY_SEPARATOR . 'ext';
$public = dirname(__DIR__) . '/public';
$logFile = sys_get_temp_dir() . '/slice_cc_api.log';

$players = [
    ['name' => '青竹一', 'faction' => 'bi'],
    ['name' => '青竹二', 'faction' => 'bi'],
    ['name' => '青竹三', 'faction' => 'bi'],
    ['name' => '青竹四', 'faction' => 'bi'],
    ['name' => '墨点一', 'faction' => 'mo'],
    ['name' => '墨点二', 'faction' => 'mo'],
    ['name' => '墨点三', 'faction' => 'mo'],
    ['name' => '墨点四', 'faction' => 'mo'],
];

// 重置测试状态
[$config, $pdo] = slice_bootstrap();
$gameId = (int)$pdo->query('SELECT id FROM slice_games LIMIT 1')->fetchColumn();
$turnId = (int)$pdo->query('SELECT id FROM slice_turns WHERE turn_no = 1 LIMIT 1')->fetchColumn();
check('测试局存在', $gameId > 0 && $turnId > 0, "game=$gameId turn=$turnId");

$pdo->prepare('UPDATE slice_turns SET status = "open", settled_at = NULL WHERE id = ?')->execute([$turnId]);
$pdo->prepare('DELETE FROM slice_battles WHERE turn_id = ?')->execute([$turnId]);
$pdo->prepare('DELETE FROM slice_node_changes WHERE turn_id = ?')->execute([$turnId]);
$pdo->prepare('DELETE FROM slice_order_slots WHERE turn_id = ?')->execute([$turnId]);
$pdo->prepare('DELETE FROM slice_hands WHERE turn_id = ?')->execute([$turnId]);
$pdo->prepare('DELETE FROM slice_compositions WHERE game_id = ? AND week_no = 1')->execute([$gameId]);
$pdo->prepare('UPDATE slice_nodes SET morale = 0, owner_faction_id = NULL WHERE game_id = ? AND node_code IN ("N1","N2")')->execute([$gameId]);

// 启动 API
$descriptors = [
    ['pipe', 'r'],
    ['file', $logFile, 'a'],
    ['file', $logFile, 'a'],
];
$proc = proc_open(
    [$php, '-d', "extension_dir=$ext", '-d', 'extension=pdo_mysql', '-S', "127.0.0.1:$port", '-t', $public],
    $descriptors,
    $pipes,
    dirname(__DIR__)
);
if (!is_resource($proc)) {
    fwrite(STDERR, "API 启动失败\n");
    exit(1);
}

try {
    $ready = false;
    for ($i = 0; $i < 40; $i++) {
        usleep(250000);
        $h = httpJson('GET', "$base/api/health");
        if ($h['code'] === 200) {
            $ready = true;
            break;
        }
    }
    check('API 就绪', $ready);
    if (!$ready) {
        throw new RuntimeException('api not ready');
    }

    // 8 人登录 + 取手牌
    $sessions = [];
    foreach ($players as $idx => $p) {
        $login = httpJson('POST', "$base/api/auth/login", [
            'name' => $p['name'],
            'password' => 'slice2026',
        ]);
        if ($login['code'] !== 200) {
            check('登录 ' . $p['name'], false, $login['raw']);
            continue;
        }
        $token = (string)($login['json']['data']['token'] ?? '');
        $hand = httpJson('GET', "$base/api/slice/hand", null, $token);
        $cards = $hand['json']['data']['hand']['cards'] ?? [];
        $sessions[$idx] = [
            'token' => $token,
            'faction' => $p['faction'],
            'cards' => $cards,
        ];
    }
    check('8 人全部登录并发好手牌', count($sessions) === 8, 'sessions=' . count($sessions));

    // 24 个 play 同时发
    $mh = curl_multi_init();
    $handles = [];
    foreach ($sessions as $idx => $s) {
        $target = $s['faction'] === 'bi' ? 'N2' : 'N1';
        for ($slot = 0; $slot < 3; $slot++) {
            $body = json_encode([
                'turn_id' => $turnId,
                'slot' => $slot,
                'card_code' => $s['cards'][$slot],
                'target_node_code' => $target,
                'lane' => $slot + 1,
                'row_pos' => $slot === 2 ? 'back' : 'front',
                'request_key' => 'cc_' . $turnId . '_' . $idx . '_' . $slot . '_' . bin2hex(random_bytes(4)),
            ], JSON_UNESCAPED_UNICODE);
            $ch = curl_init("$base/api/slice/order/play");
            curl_setopt_array($ch, [
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_POST => true,
                CURLOPT_POSTFIELDS => $body,
                CURLOPT_HTTPHEADER => [
                    'Content-Type: application/json',
                    'Authorization: Bearer ' . $s['token'],
                ],
                CURLOPT_TIMEOUT => 15,
            ]);
            curl_multi_add_handle($mh, $ch);
            $handles[] = ['ch' => $ch, 'idx' => $idx, 'slot' => $slot];
        }
    }

    $running = 0;
    do {
        curl_multi_exec($mh, $running);
        if ($running > 0) {
            curl_multi_select($mh, 0.2);
        }
    } while ($running > 0);

    $okCount = 0;
    $errors = [];
    foreach ($handles as $h) {
        $code = (int)curl_getinfo($h['ch'], CURLINFO_HTTP_CODE);
        if ($code === 200) {
            $okCount++;
        } else {
            $errors[] = "player{$h['idx']} slot{$h['slot']} HTTP {$code} " . curl_multi_getcontent($h['ch']);
        }
        curl_multi_remove_handle($mh, $h['ch']);
        curl_close($h['ch']);
    }
    curl_multi_close($mh);

    check('24 个并发 play 全部 200', $okCount === 24, "ok={$okCount} errors=" . implode(' | ', array_slice($errors, 0, 3)));

    $stmt = $pdo->prepare('SELECT COUNT(*) FROM slice_order_slots WHERE turn_id = ? AND status = "active"');
    $stmt->execute([$turnId]);
    $active = (int)$stmt->fetchColumn();
    check('库里 24 条 active 令', $active === 24, 'active=' . $active);

    // 教师结算
    $teacher = httpJson('POST', "$base/api/auth/admin-login", [
        'username' => 'teacher',
        'password' => 'teacher2026',
    ]);
    check('教师登录', $teacher['code'] === 200, $teacher['raw']);
    $teacherToken = (string)($teacher['json']['data']['token'] ?? '');
    $settle = httpJson('POST', "$base/api/slice/admin/card-settle", ['turn_id' => $turnId], $teacherToken);
    check('结算成功', $settle['code'] === 200, substr($settle['raw'], 0, 300));
    $battles = $settle['json']['data']['battles'] ?? [];
    check('产生 2 场战斗', count($battles) === 2, 'battles=' . count($battles) . ' ' . json_encode($battles, JSON_UNESCAPED_UNICODE));

    $stmt = $pdo->prepare('SELECT COUNT(*) FROM slice_battles WHERE turn_id = ?');
    $stmt->execute([$turnId]);
    check('战斗已入库', (int)$stmt->fetchColumn() === 2);

    $stmt = $pdo->prepare('SELECT node_code, morale, owner_faction_id FROM slice_nodes WHERE game_id = ? AND node_code IN ("N1","N2") ORDER BY node_code');
    $stmt->execute([$gameId]);
    $nodes = $stmt->fetchAll();
    check('两座城都有民心变化', count($nodes) === 2 && (int)$nodes[0]['morale'] + (int)$nodes[1]['morale'] > 0, json_encode($nodes, JSON_UNESCAPED_UNICODE));

    echo PHP_EOL;
    if ($failed > 0) {
        echo "CARD_CONCURRENCY FAIL ({$failed})\n";
        exit(1);
    }
    echo "CARD_CONCURRENCY PASS\n";
} finally {
    if (is_resource($proc)) {
        proc_terminate($proc);
        proc_close($proc);
    }
}
