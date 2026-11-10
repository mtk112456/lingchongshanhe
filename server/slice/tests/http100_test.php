<?php
declare(strict_types=1);

/**
 * HTTP 层 100 人 / 300 令并发提交压测
 *
 * 说明：
 *   PHP 内置服务器是单线程的，所以这里起 4 个实例分摊请求，
 *   近似并发；真实部署应换 php-fpm / Apache。
 *
 * 流程：
 *   1. 建 LOAD100 游戏 + 100 学生/玩家
 *   2. 起 4 个 API（8131–8134）
 *   3. 100 人并发登录 + 取手牌
 *   4. 300 个 play 并发提交，计时
 *   5. 教师登录 + 结算，计时
 *
 * 用法：
 *   php server/slice/tests/http100_test.php
 */

require_once __DIR__ . '/../bootstrap.php';
require_once __DIR__ . '/../src/CardSettlementService.php';

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
        CURLOPT_TIMEOUT => 20,
    ]);
    if ($body !== null) {
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($body, JSON_UNESCAPED_UNICODE));
    }
    $raw = curl_exec($ch);
    $code = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    return ['code' => $code, 'json' => json_decode((string)$raw, true), 'raw' => (string)$raw];
}

/**
 * 一次性发一批请求，返回 [成功数, 错误列表, 耗时 ms, 每个句柄的响应]。
 *
 * @param array<int,array{url:string,body?:array,token?:?string,meta?:mixed}> $requests
 */
function multiPost(array $requests, int $concurrency = 40): array
{
    $started = microtime(true);
    $mh = curl_multi_init();
    $handles = [];
    $results = [];
    $queue = array_values($requests);

    $addNext = function () use (&$queue, $mh, &$handles): void {
        while (count($handles) < 40 && $queue !== []) {
            $req = array_shift($queue);
            $ch = curl_init($req['url']);
            $headers = ['Content-Type: application/json'];
            if (!empty($req['token'])) {
                $headers[] = 'Authorization: Bearer ' . $req['token'];
            }
            curl_setopt_array($ch, [
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_POST => true,
                CURLOPT_POSTFIELDS => json_encode($req['body'] ?? [], JSON_UNESCAPED_UNICODE),
                CURLOPT_HTTPHEADER => $headers,
                CURLOPT_TIMEOUT => 20,
            ]);
            curl_multi_add_handle($mh, $ch);
            $handles[spl_object_id($ch)] = ['ch' => $ch, 'meta' => $req['meta'] ?? null];
        }
    };

    $addNext();
    do {
        do {
            $status = curl_multi_exec($mh, $running);
        } while ($status === CURLM_CALL_MULTI_PERFORM);

        while ($info = curl_multi_info_read($mh)) {
            $ch = $info['handle'];
            $key = spl_object_id($ch);
            $code = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
            $results[] = [
                'code' => $code,
                'body' => curl_multi_getcontent($ch),
                'meta' => $handles[$key]['meta'] ?? null,
            ];
            curl_multi_remove_handle($mh, $ch);
            curl_close($ch);
            unset($handles[$key]);
        }

        $addNext();
        if ($running > 0) {
            usleep(1000);
        }
    } while ($running > 0 || $handles !== [] || $queue !== []);

    curl_multi_close($mh);
    return [$results, (microtime(true) - $started) * 1000];
}

[$config, $pdo] = slice_bootstrap();

$sourceGameId = (int)$pdo->query("SELECT id FROM slice_games WHERE code = 'MAP12_TEST'")->fetchColumn();
if ($sourceGameId <= 0) {
    fwrite(STDERR, "缺少 MAP12_TEST，请先跑 setup_map12_db.php\n");
    exit(1);
}

$cleanupGame = function () use ($pdo): void {
    $stmt = $pdo->prepare("SELECT id FROM slice_games WHERE code = 'LOAD100'");
    $stmt->execute();
    $id = (int)$stmt->fetchColumn();
    if ($id > 0) {
        $pdo->prepare('DELETE FROM slice_games WHERE id = ?')->execute([$id]);
    }
    $ids = $pdo->query("SELECT id FROM students WHERE name LIKE 'LOAD%'")->fetchAll(PDO::FETCH_COLUMN);
    if ($ids !== []) {
        $in = implode(',', array_map('intval', $ids));
        $pdo->exec("DELETE FROM student_pets WHERE student_id IN ({$in})");
        $pdo->exec("DELETE FROM students WHERE id IN ({$in})");
    }
};

$cleanupGame();

$passwordHash = (string)$pdo->query('SELECT password FROM students ORDER BY id LIMIT 1')->fetchColumn();
$petTemplateId = (int)$pdo->query('SELECT id FROM pet_templates ORDER BY id LIMIT 1')->fetchColumn();
$petCode = (string)$pdo->query('SELECT code FROM pet_templates ORDER BY id LIMIT 1')->fetchColumn();

$pdo->beginTransaction();
try {
    $pdo->prepare(
        "INSERT INTO slice_games (code, name, status, rules_version, turn_seconds)
         VALUES ('LOAD100', '100 人并发压测', 'paused', 'cards_v1', 600)"
    )->execute();
    $gameId = (int)$pdo->lastInsertId();

    $pdo->prepare(
        'INSERT INTO slice_factions (game_id, code, name, color, start_node_code, sort_order)
         SELECT ?, code, name, color, start_node_code, sort_order
         FROM slice_factions WHERE game_id = ?'
    )->execute([$gameId, $sourceGameId]);

    $pdo->prepare(
        'INSERT INTO slice_nodes
            (game_id, node_code, name, x, y, node_type, owner_faction_id, initial_owner_faction_id, morale, sort_order)
         SELECT ?, node_code, name, x, y, node_type, NULL, NULL, 0, sort_order
         FROM slice_nodes WHERE game_id = ?'
    )->execute([$gameId, $sourceGameId]);

    $pdo->prepare(
        'UPDATE slice_nodes n
         JOIN slice_nodes o ON o.game_id = ? AND o.node_code = n.node_code
         JOIN slice_factions of ON of.id = o.owner_faction_id
         JOIN slice_factions nf ON nf.game_id = n.game_id AND nf.code = of.code
         SET n.owner_faction_id = nf.id
         WHERE n.game_id = ?'
    )->execute([$sourceGameId, $gameId]);

    $pdo->prepare(
        'INSERT INTO slice_edges (game_id, a_node_code, b_node_code)
         SELECT ?, a_node_code, b_node_code FROM slice_edges WHERE game_id = ?'
    )->execute([$gameId, $sourceGameId]);

    $factions = $pdo->query("SELECT id, code FROM slice_factions WHERE game_id = {$gameId} ORDER BY sort_order")
        ->fetchAll();
    $nodes = $pdo->query("SELECT node_code FROM slice_nodes WHERE game_id = {$gameId} ORDER BY sort_order")
        ->fetchAll(PDO::FETCH_COLUMN);
    $factionIndex = [];
    foreach ($factions as $idx => $f) {
        $factionIndex[(string)$f['code']] = (int)$idx;
    }

    $insertStudent = $pdo->prepare(
        "INSERT INTO students (id_card, class_id, name, show_name, password, score)
         VALUES (?, 1, ?, ?, ?, 100)"
    );
    $insertPet = $pdo->prepare(
        'INSERT INTO student_pets (student_id, pet_template_id, nickname, level, hunger, mood)
         VALUES (?, ?, ?, 10, 100, 100)'
    );
    $insertPlayer = $pdo->prepare(
        'INSERT INTO slice_players
            (game_id, student_id, admin_id, faction_id, nickname, role, pet_instance_id, pet_code, pet_name, is_active)
         VALUES (?, ?, NULL, ?, ?, "player", ?, ?, ?, 1)'
    );

    $players = [];
    for ($i = 0; $i < 100; $i++) {
        $tag = sprintf('LOAD%03d', $i + 1);
        $insertStudent->execute(['LOAD100' . sprintf('%04d', $i + 1), $tag, $tag, $passwordHash]);
        $studentId = (int)$pdo->lastInsertId();
        $insertPet->execute([$studentId, $petTemplateId, $tag]);
        $petId = (int)$pdo->lastInsertId();
        $faction = $factions[$i % 4];
        $insertPlayer->execute([$gameId, $studentId, (int)$faction['id'], $tag, $petId, $petCode, $tag]);
        $players[] = [
            'id' => (int)$pdo->lastInsertId(),
            'faction' => (string)$faction['code'],
            'name' => $tag,
        ];
    }

    $pdo->prepare(
        "INSERT INTO slice_turns (game_id, turn_no, status, opens_at, deadline_at, rules_version)
         VALUES (?, 1, 'open', NOW(), DATE_ADD(NOW(), INTERVAL 600 SECOND), 'cards_v1')"
    )->execute([$gameId]);
    $turnId = (int)$pdo->lastInsertId();
    $pdo->prepare('UPDATE slice_games SET current_turn_id = ? WHERE id = ?')->execute([$turnId, $gameId]);

    // 教师席位：否则 admin-login 会落到 SLICE_A
    $adminId = (int)$pdo->query("SELECT id FROM admin WHERE username = 'teacher'")->fetchColumn();
    $pdo->prepare(
        'INSERT INTO slice_players
            (game_id, student_id, admin_id, faction_id, nickname, role, pet_instance_id, pet_code, pet_name, is_active)
         VALUES (?, NULL, ?, NULL, "先生", "teacher", NULL, "mentor", "先生", 1)'
    )->execute([$gameId, $adminId]);

    $insertComp = $pdo->prepare(
        'INSERT INTO slice_compositions (game_id, player_id, week_no, types_json, changed_once)
         VALUES (?, ?, 1, ?, 0)'
    );
    $types = ['cav', 'shield', 'arc', 'spear'];
    foreach ($players as $i => $p) {
        $comp = [$types[$i % 4], $types[($i + 1) % 4], $types[($i + 2) % 4]];
        $insertComp->execute([$gameId, $p['id'], json_encode($comp)]);
    }

    $pdo->commit();
} catch (Throwable $e) {
    $pdo->rollBack();
    $cleanupGame();
    fwrite(STDERR, '准备失败：' . $e->getMessage() . PHP_EOL);
    exit(1);
}

$php = PHP_BINARY;
$ext = dirname($php) . DIRECTORY_SEPARATOR . 'ext';
$public = dirname(__DIR__) . '/public';
$ports = [];
$candidate = 8200;
while (count($ports) < 4 && $candidate < 8400) {
    $sock = @fsockopen('127.0.0.1', $candidate, $errno, $errstr, 0.2);
    if ($sock === false) {
        $ports[] = $candidate;
    } else {
        fclose($sock);
    }
    $candidate++;
}
$servers = [];
$logDir = sys_get_temp_dir();

try {
    foreach ($ports as $port) {
        $log = $logDir . DIRECTORY_SEPARATOR . "slice_http100_{$port}.log";
        $descriptors = [
            ['pipe', 'r'],
            ['file', $log, 'a'],
            ['file', $log, 'a'],
        ];
        $proc = proc_open(
            [$php, '-d', "extension_dir=$ext", '-d', 'extension=pdo_mysql', '-S', "127.0.0.1:$port", '-t', $public],
            $descriptors,
            $pipes,
            dirname(__DIR__)
        );
        if (!is_resource($proc)) {
            throw new RuntimeException("API {$port} 启动失败");
        }
        fclose($pipes[0]);
        $servers[$port] = $proc;
    }

    $ready = 0;
    foreach ($ports as $port) {
        for ($i = 0; $i < 40; $i++) {
            $h = httpJson('GET', "http://127.0.0.1:{$port}/api/health");
            if ($h['code'] === 200) {
                $ready++;
                break;
            }
            usleep(250000);
        }
    }
    check('4 个 API 就绪', $ready === 4, "ready={$ready}");

    // 100 人并发登录
    $loginRequests = [];
    foreach ($players as $idx => $p) {
        $port = $ports[$idx % 4];
        $loginRequests[] = [
            'url' => "http://127.0.0.1:{$port}/api/auth/login",
            'body' => ['name' => $p['name'], 'password' => 'slice2026'],
            'meta' => $idx,
        ];
    }
    [$loginResults, $loginMs] = multiPost($loginRequests, 50);
    $tokens = [];
    foreach ($loginResults as $r) {
        $json = json_decode((string)$r['body'], true);
        if ($r['code'] === 200 && !empty($json['data']['token'])) {
            $tokens[(int)$r['meta']] = (string)$json['data']['token'];
        }
    }
    check('100 人登录成功', count($tokens) === 100, sprintf('ok=%d %.0f ms', count($tokens), $loginMs));

    // 100 人取手牌
    $handRequests = [];
    foreach ($tokens as $idx => $token) {
        $port = $ports[$idx % 4];
        $handRequests[] = [
            'url' => "http://127.0.0.1:{$port}/api/slice/hand?turn_id={$turnId}",
            'body' => [],
            'token' => $token,
            'meta' => $idx,
        ];
    }
    // GET 不能用 multiPost 的 POST，这里复用 curl_multi 的简版：逐个取也足够快
    $hands = [];
    $handStarted = microtime(true);
    foreach ($handRequests as $req) {
        $ch = curl_init($req['url']);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER => ['Authorization: Bearer ' . $req['token']],
            CURLOPT_TIMEOUT => 20,
        ]);
        $raw = curl_exec($ch);
        $code = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        $json = json_decode((string)$raw, true);
        if ($code === 200 && !empty($json['data']['hand']['cards'])) {
            $hands[(int)$req['meta']] = $json['data']['hand']['cards'];
        }
    }
    $handMs = (microtime(true) - $handStarted) * 1000;
    check('100 人取到手牌', count($hands) === 100, sprintf('ok=%d %.0f ms', count($hands), $handMs));

    // 300 个 play 并发
    $playRequests = [];
    foreach ($players as $idx => $p) {
        if (!isset($tokens[$idx], $hands[$idx])) {
            continue;
        }
        $port = $ports[$idx % 4];
        $fi = $factionIndex[$p['faction']] ?? 0;
        for ($slot = 0; $slot < 3; $slot++) {
            $node = $nodes[($fi * 3 + $slot) % count($nodes)];
            $playRequests[] = [
                'url' => "http://127.0.0.1:{$port}/api/slice/order/play",
                'token' => $tokens[$idx],
                'body' => [
                    'turn_id' => $turnId,
                    'slot' => $slot,
                    'card_code' => $hands[$idx][$slot],
                    'target_node_code' => $node,
                    'lane' => $slot + 1,
                    'row_pos' => $slot === 2 ? 'back' : 'front',
                    'request_key' => 'h100_' . $idx . '_' . $slot . '_' . bin2hex(random_bytes(4)),
                ],
                'meta' => [$idx, $slot],
            ];
        }
    }
    [$playResults, $playMs] = multiPost($playRequests, 60);
    $okCount = 0;
    $errors = [];
    foreach ($playResults as $r) {
        if ($r['code'] === 200) {
            $okCount++;
        } else {
            $errors[] = 'HTTP ' . $r['code'] . ' ' . substr((string)$r['body'], 0, 120);
        }
    }
    check('300 个 play 全部 200', $okCount === 300, sprintf('ok=%d %.0f ms', $okCount, $playMs));
    check('提交 < 5 秒', $playMs < 5000, sprintf('%.0f ms', $playMs));
    if ($errors !== []) {
        echo '  ' . implode(' | ', array_slice($errors, 0, 3)) . PHP_EOL;
    }

    $active = (int)$pdo->query("SELECT COUNT(*) FROM slice_order_slots WHERE turn_id = {$turnId} AND status = 'active'")->fetchColumn();
    check('库里 300 条 active 令', $active === 300, 'active=' . $active);

    // 教师结算
    $teacherPort = $ports[0];
    $teacher = httpJson('POST', "http://127.0.0.1:{$teacherPort}/api/auth/admin-login", [
        'username' => 'teacher',
        'password' => 'teacher2026',
        'game_code' => 'LOAD100',
    ]);
    check('教师登录', $teacher['code'] === 200, substr($teacher['raw'], 0, 200));
    $teacherToken = (string)($teacher['json']['data']['token'] ?? '');
    $settleStarted = microtime(true);
    $settle = httpJson('POST', "http://127.0.0.1:{$teacherPort}/api/slice/admin/card-settle", ['turn_id' => $turnId], $teacherToken);
    $settleMs = (microtime(true) - $settleStarted) * 1000;
    check('教师结算 200', $settle['code'] === 200, substr($settle['raw'], 0, 300));
    check('结算 < 10 秒', $settleMs < 10000, sprintf('%.0f ms', $settleMs));
    $battles = $settle['json']['data']['battles'] ?? [];
    $battleEntries = count(array_filter($battles, fn($b) => !empty($b['battle_id'])));
    check('产生战斗', $battleEntries > 0, 'battles=' . $battleEntries . ' entries=' . count($battles));
    $dbBattles = (int)$pdo->query("SELECT COUNT(*) FROM slice_battles WHERE turn_id = {$turnId}")->fetchColumn();
    check('战斗入库', $dbBattles === $battleEntries, "db={$dbBattles} settled={$battleEntries}");

    echo PHP_EOL;
    echo sprintf(
        "HTTP100: login %.0f ms, hand %.0f ms, submit %.0f ms, settle %.0f ms, battles %d\n",
        $loginMs,
        $handMs,
        $playMs,
        $settleMs,
        $battleEntries
    );
} finally {
    foreach ($servers as $proc) {
        if (is_resource($proc)) {
            proc_terminate($proc);
            proc_close($proc);
        }
    }
    $cleanupGame();
}

if ($failed > 0) {
    echo "HTTP100 FAIL ({$failed})\n";
    exit(1);
}
echo "HTTP100 PASS\n";
