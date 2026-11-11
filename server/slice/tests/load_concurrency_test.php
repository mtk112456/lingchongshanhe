<?php
declare(strict_types=1);

/**
 * 100 人 × 3 令 / 同一 request_key 重复 / 教师双击结算 并发安全压测
 *
 * 隔离：
 *   - 仅使用 config.load.php → test_load @ 127.0.0.1:3307
 *   - 仅操作本脚本创建的 LOAD_CC 游戏与 LC001–LC101 学生
 *   - 端口：8098 主实例 + 8108–8116 辅助实例（PHP 内置服务器单线程，
 *     单端口无法制造真并发，所以用多进程分摊请求，全部指向同一 test_load）
 *
 * 用法：
 *   set SLICE_CONFIG=D:\DeskBox\游戏\server\slice\config.load.php
 *   php -d extension_dir=<php>\ext -d extension=pdo_mysql tests\load_concurrency_test.php
 *
 * 前置（一次性，root）：
 *   CREATE DATABASE test_load CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
 *   GRANT ALL PRIVILEGES ON test_load.* TO 'qingzhu_test'@'127.0.0.1';
 */

$ROOT = dirname(__DIR__);
$CONFIG_PATH = $ROOT . DIRECTORY_SEPARATOR . 'config.load.php';
$PUBLIC_DIR = $ROOT . DIRECTORY_SEPARATOR . 'public';
$ROUTER = $PUBLIC_DIR . DIRECTORY_SEPARATOR . 'index.php';
$PHP = PHP_BINARY;
$EXT_DIR = dirname(PHP_BINARY) . DIRECTORY_SEPARATOR . 'ext';

const PRIMARY_PORT = 8098;
const HELPER_PORTS = [8108, 8109, 8110, 8111, 8112, 8113, 8114, 8115, 8116];
const GAME_CODE = 'LOAD_CC';
const PLAYER_COUNT = 100;
const PROBE_NAME = 'LC101';
const STUDENT_PASSWORD = 'slice2026';
const TEACHER_NAME = 'teacher';
const TEACHER_PASSWORD = 'teacher2026';

putenv('SLICE_CONFIG=' . $CONFIG_PATH);
$_ENV['SLICE_CONFIG'] = $CONFIG_PATH;

require_once $ROOT . '/bootstrap.php';
require_once $ROOT . '/src/SqlRunner.php';

$GLOBALS['failed'] = 0;
$GLOBALS['findings'] = 0;
$GLOBALS['races'] = 0;
$GLOBALS['servers'] = [];

register_shutdown_function('stop_all_servers');

// ---------------------------------------------------------------------------
// 输出 / 断言
// ---------------------------------------------------------------------------

function line(string $text = ''): void
{
    fwrite(STDOUT, $text . PHP_EOL);
}

function check(string $name, bool $ok, string $detail = ''): bool
{
    line(($ok ? '[PASS] ' : '[FAIL] ') . $name . ($detail !== '' ? ' — ' . $detail : ''));
    if (!$ok) {
        $GLOBALS['failed']++;
    }
    return $ok;
}

function finding(string $name, string $detail = ''): void
{
    line('[FIND] ' . $name . ($detail !== '' ? ' — ' . $detail : ''));
    $GLOBALS['findings']++;
}

function race(string $name, string $detail = ''): void
{
    line('[RACE] ' . $name . ($detail !== '' ? ' — ' . $detail : ''));
    $GLOBALS['races']++;
}

function pct(array $values, float $p): float
{
    $n = count($values);
    if ($n === 0) {
        return 0.0;
    }
    sort($values, SORT_NUMERIC);
    $idx = (int)ceil($p / 100.0 * $n) - 1;
    $idx = max(0, min($n - 1, $idx));
    return (float)$values[$idx];
}

function ms_text(array $values): string
{
    if ($values === []) {
        return 'n=0';
    }
    return sprintf(
        'n=%d p50=%.1fms p95=%.1fms max=%.1fms',
        count($values),
        pct($values, 50),
        pct($values, 95),
        max($values)
    );
}

// ---------------------------------------------------------------------------
// 基础设施
// ---------------------------------------------------------------------------

function is_port_open(int $port): bool
{
    $fp = @fsockopen('127.0.0.1', $port, $errno, $errstr, 0.3);
    if (is_resource($fp)) {
        fclose($fp);
        return true;
    }
    return false;
}

function php_env(): array
{
    global $CONFIG_PATH;
    $env = getenv();
    if (!is_array($env)) {
        $env = [];
    }
    $env['SLICE_CONFIG'] = $CONFIG_PATH;
    return $env;
}

/**
 * @return array{exit:int,out:string,err:string,ms:float}
 */
function run_php_script(string $script, array $args = []): array
{
    global $PHP, $EXT_DIR, $ROOT;

    $cmd = array_merge(
        [$PHP, '-d', 'extension_dir=' . $EXT_DIR, '-d', 'extension=pdo_mysql', $script],
        $args
    );
    $descriptors = [
        0 => ['file', 'NUL', 'r'],
        1 => ['pipe', 'w'],
        2 => ['pipe', 'w'],
    ];
    $started = microtime(true);
    $proc = @proc_open($cmd, $descriptors, $pipes, $ROOT, php_env(), ['bypass_shell' => true]);
    if (!is_resource($proc)) {
        return ['exit' => -1, 'out' => '', 'err' => 'proc_open 失败', 'ms' => 0.0];
    }
    $out = (string)stream_get_contents($pipes[1]);
    $err = (string)stream_get_contents($pipes[2]);
    fclose($pipes[1]);
    fclose($pipes[2]);
    $exit = proc_close($proc);
    return [
        'exit' => $exit,
        'out' => trim($out),
        'err' => trim($err),
        'ms' => (microtime(true) - $started) * 1000,
    ];
}

function start_api(int $port): mixed
{
    global $PHP, $EXT_DIR, $ROOT, $PUBLIC_DIR, $ROUTER;

    if (is_port_open($port)) {
        throw new RuntimeException("端口 {$port} 已被占用，拒绝启动/杀未知进程");
    }
    $log = sys_get_temp_dir() . DIRECTORY_SEPARATOR . "slice_load_{$port}.log";
    @unlink($log);
    $cmd = [
        $PHP,
        '-d',
        'extension_dir=' . $EXT_DIR,
        '-d',
        'extension=pdo_mysql',
        '-S',
        '127.0.0.1:' . $port,
        '-t',
        $PUBLIC_DIR,
        $ROUTER,
    ];
    $proc = @proc_open(
        $cmd,
        [
            0 => ['file', 'NUL', 'r'],
            1 => ['file', $log, 'a'],
            2 => ['file', $log, 'a'],
        ],
        $pipes,
        $ROOT,
        php_env(),
        ['bypass_shell' => true]
    );
    if (!is_resource($proc)) {
        throw new RuntimeException("API {$port} 启动失败");
    }
    return $proc;
}

function proc_running(mixed $proc): bool
{
    if (!is_resource($proc)) {
        return false;
    }
    $status = proc_get_status($proc);
    return (bool)($status['running'] ?? false);
}

function stop_all_servers(): void
{
    foreach ($GLOBALS['servers'] as $port => $proc) {
        if (!is_resource($proc)) {
            continue;
        }
        $status = proc_get_status($proc);
        if (($status['running'] ?? false) === true) {
            @proc_terminate($proc, 9);
        }
        $deadline = microtime(true) + 5.0;
        while (microtime(true) < $deadline && proc_running($proc)) {
            usleep(100000);
        }
        $status = proc_get_status($proc);
        if (($status['running'] ?? false) === true && PHP_OS_FAMILY === 'Windows') {
            @exec('taskkill /F /PID ' . (int)($status['pid'] ?? 0) . ' >NUL 2>&1');
        }
        @proc_close($proc);
        unset($GLOBALS['servers'][$port]);
    }
}

function http_simple(string $method, string $url, ?array $body = null, ?string $token = null, int $timeout = 5): array
{
    $headers = "Content-Type: application/json\r\n";
    if ($token !== null && $token !== '') {
        $headers .= 'Authorization: Bearer ' . $token . "\r\n";
    }
    $opts = [
        'http' => [
            'method' => $method,
            'timeout' => $timeout,
            'ignore_errors' => true,
            'header' => $headers,
        ],
    ];
    if ($body !== null) {
        $opts['http']['content'] = json_encode($body, JSON_UNESCAPED_UNICODE);
    }
    $raw = @file_get_contents($url, false, stream_context_create($opts));
    $code = 0;
    if (isset($http_response_header[0]) && preg_match('#\s(\d{3})\s#', $http_response_header[0], $m)) {
        $code = (int)$m[1];
    }
    return ['code' => $code, 'raw' => (string)$raw, 'json' => json_decode((string)$raw, true)];
}

// ---------------------------------------------------------------------------
// 无 curl 的并发 HTTP 客户端（stream_socket_client + stream_select）
// ---------------------------------------------------------------------------

final class ConcurrentHttp
{
    /**
     * @param array<int,array{port:int,method:string,path:string,body?:mixed,token?:?string,start_at?:float,meta?:mixed}> $requests
     * @return array<int,array{code:int,body:string,json:?array,ms:float,meta:mixed,error:?string}>
     */
    public static function run(array $requests, int $maxInFlight = 120, float $timeout = 30.0): array
    {
        $maxInFlight = max(1, $maxInFlight);
        $queue = [];
        $now = microtime(true);
        foreach ($requests as $idx => $req) {
            $req['_idx'] = $idx;
            $req['_start_at'] = (float)($req['start_at'] ?? $now);
            $queue[] = $req;
        }
        usort($queue, static fn(array $a, array $b): int => $a['_start_at'] <=> $b['_start_at']);

        $active = [];
        $results = [];

        while ($queue !== [] || $active !== []) {
            while ($queue !== [] && count($active) < $maxInFlight) {
                $wait = $queue[0]['_start_at'] - microtime(true);
                if ($wait > 0.0005) {
                    break;
                }
                $req = array_shift($queue);
                $state = self::begin($req);
                if ($state['error'] !== null && !is_resource($state['sock'])) {
                    $results[$state['idx']] = self::finish($state, $state['error']);
                    continue;
                }
                $active[] = $state;
            }

            if ($active === []) {
                $wait = max(0.0005, min(0.2, $queue[0]['_start_at'] - microtime(true)));
                usleep((int)round($wait * 1000000));
                continue;
            }

            $read = [];
            foreach ($active as $k => $state) {
                if (is_resource($state['sock'])) {
                    $read[$k] = $state['sock'];
                }
            }
            $write = null;
            $except = null;

            $sec = 0;
            $usec = 200000;
            if ($queue !== []) {
                $until = $queue[0]['_start_at'] - microtime(true);
                if ($until > 0 && $until < 0.2) {
                    $usec = max(1000, (int)round($until * 1000000));
                } elseif ($until <= 0) {
                    $usec = 1000;
                }
            }

            $ready = @stream_select($read, $write, $except, $sec, $usec);
            if ($ready === false) {
                // 被信号打断：继续下一轮，超时逻辑兜底
                $read = [];
            }

            foreach ($read as $k => $sock) {
                if (!isset($active[$k])) {
                    continue;
                }
                $chunk = @fread($sock, 65536);
                if ($chunk === false) {
                    $results[$active[$k]['idx']] = self::finish($active[$k], 'read failed');
                    @fclose($sock);
                    unset($active[$k]);
                    continue;
                }
                if ($chunk !== '') {
                    $active[$k]['buf'] .= $chunk;
                }
                if (feof($sock) || self::isComplete($active[$k]['buf'])) {
                    $results[$active[$k]['idx']] = self::finish($active[$k], null);
                    @fclose($sock);
                    unset($active[$k]);
                }
            }

            $now = microtime(true);
            foreach ($active as $k => $state) {
                if ($now - $state['started'] > $timeout) {
                    $results[$state['idx']] = self::finish($state, 'timeout');
                    if (is_resource($state['sock'])) {
                        @fclose($state['sock']);
                    }
                    unset($active[$k]);
                }
            }
        }

        ksort($results);
        return $results;
    }

    private static function begin(array $req): array
    {
        $port = (int)$req['port'];
        $errno = 0;
        $errstr = '';
        $sock = @stream_socket_client('tcp://127.0.0.1:' . $port, $errno, $errstr, 3.0);
        $state = [
            'idx' => $req['_idx'],
            'port' => $port,
            'method' => strtoupper((string)$req['method']),
            'path' => (string)$req['path'],
            'meta' => $req['meta'] ?? null,
            'sock' => $sock,
            'buf' => '',
            'started' => microtime(true),
            'error' => null,
        ];
        if (!is_resource($sock)) {
            $state['error'] = 'connect: ' . $errstr;
            return $state;
        }

        $body = '';
        if ($req['method'] !== 'GET' && array_key_exists('body', $req)) {
            $body = json_encode($req['body'], JSON_UNESCAPED_UNICODE);
            if ($body === false) {
                $body = '{}';
            }
        }
        $host = '127.0.0.1:' . $port;
        $head = $state['method'] . ' ' . $state['path'] . " HTTP/1.1\r\n"
            . 'Host: ' . $host . "\r\n"
            . "Connection: close\r\n"
            . "Accept: application/json\r\n";
        if (!empty($req['token'])) {
            $head .= 'Authorization: Bearer ' . $req['token'] . "\r\n";
        }
        if ($state['method'] !== 'GET') {
            $head .= "Content-Type: application/json\r\n"
                . 'Content-Length: ' . strlen($body) . "\r\n";
        }
        $payload = $head . "\r\n" . $body;

        stream_set_blocking($sock, true);
        $written = 0;
        $total = strlen($payload);
        $deadline = microtime(true) + 3.0;
        while ($written < $total && microtime(true) < $deadline) {
            $n = @fwrite($sock, substr($payload, $written));
            if ($n === false || $n === 0) {
                break;
            }
            $written += $n;
        }
        stream_set_blocking($sock, false);
        if ($written < $total) {
            $state['error'] = 'write: ' . $written . '/' . $total;
        }
        return $state;
    }

    private static function isComplete(string $buf): bool
    {
        $sep = strpos($buf, "\r\n\r\n");
        if ($sep === false) {
            return false;
        }
        $head = substr($buf, 0, $sep);
        if (preg_match('/^Content-Length:\s*(\d+)/mi', $head, $m)) {
            return strlen($buf) - ($sep + 4) >= (int)$m[1];
        }
        return false;
    }

    private static function finish(array $state, ?string $error): array
    {
        $ms = (microtime(true) - $state['started']) * 1000;
        $buf = $state['buf'];
        $code = 0;
        $body = '';
        $sep = strpos($buf, "\r\n\r\n");
        if ($sep !== false) {
            $head = substr($buf, 0, $sep);
            $body = substr($buf, $sep + 4);
            if (preg_match('#^HTTP/\d\.\d\s+(\d{3})#', $head, $m)) {
                $code = (int)$m[1];
            }
            if (preg_match('/^Transfer-Encoding:\s*chunked/mi', $head)) {
                $body = self::decodeChunked($body);
            }
        } elseif ($buf !== '') {
            $error = $error ?? 'no http header';
        }

        return [
            'code' => $code,
            'body' => $body,
            'json' => $body !== '' ? json_decode($body, true) : null,
            'ms' => $ms,
            'meta' => $state['meta'],
            'error' => $state['error'] ?? $error,
        ];
    }

    private static function decodeChunked(string $body): string
    {
        $out = '';
        $pos = 0;
        $len = strlen($body);
        while ($pos < $len) {
            $lineEnd = strpos($body, "\r\n", $pos);
            if ($lineEnd === false) {
                break;
            }
            $sizeLine = trim(substr($body, $pos, $lineEnd - $pos));
            $size = (int)hexdec(explode(';', $sizeLine)[0]);
            if ($size <= 0) {
                break;
            }
            $out .= substr($body, $lineEnd + 2, $size);
            $pos = $lineEnd + 2 + $size + 2;
        }
        return $out;
    }
}

// ---------------------------------------------------------------------------
// 数据库
// ---------------------------------------------------------------------------

function scalar(PDO $pdo, string $sql, array $params = []): mixed
{
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    return $stmt->fetchColumn();
}

function rows(PDO $pdo, string $sql, array $params = []): array
{
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    return $stmt->fetchAll();
}

function cleanup_load_game(PDO $pdo): void
{
    $gameId = (int)scalar($pdo, 'SELECT id FROM slice_games WHERE code = ?', [GAME_CODE]);
    if ($gameId > 0) {
        $pdo->prepare('DELETE FROM slice_games WHERE id = ?')->execute([$gameId]);
    }
    $ids = $pdo->query("SELECT id FROM students WHERE name REGEXP '^LC[0-9]{3}$'")->fetchAll(PDO::FETCH_COLUMN);
    if ($ids !== []) {
        $in = implode(',', array_map('intval', $ids));
        $pdo->exec("DELETE FROM student_pets WHERE student_id IN ({$in})");
        $pdo->exec("DELETE FROM students WHERE id IN ({$in})");
    }
}

/**
 * @return array{game_id:int,turn_id:int,players:array,probe:array,teacher_player_id:int,factions:array,targets:array,node_snapshot:array}
 */
function prepare_load_game(PDO $pdo): array
{
    $sourceGameId = (int)scalar($pdo, "SELECT id FROM slice_games WHERE code = 'MAP12_TEST'");
    if ($sourceGameId <= 0) {
        throw new RuntimeException('缺少 MAP12_TEST，请先运行 setup_map12_db.php');
    }

    cleanup_load_game($pdo);

    $passwordHash = (string)scalar($pdo, 'SELECT password FROM students ORDER BY id LIMIT 1');
    $pet = rows($pdo, 'SELECT id, code FROM pet_templates ORDER BY id LIMIT 1')[0] ?? null;
    if ($passwordHash === '' || $pet === null) {
        throw new RuntimeException('测试库缺少 students / pet_templates 种子');
    }
    $petTemplateId = (int)$pet['id'];
    $petCode = (string)$pet['code'];

    $pdo->beginTransaction();
    try {
        $pdo->prepare(
            "INSERT INTO slice_games (code, name, status, rules_version, turn_seconds)
             VALUES (?, '100 人并发压测', 'running', 'cards_v1', 600)"
        )->execute([GAME_CODE]);
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
             SET n.owner_faction_id = nf.id, n.initial_owner_faction_id = nf.id
             WHERE n.game_id = ?'
        )->execute([$sourceGameId, $gameId]);

        $pdo->prepare(
            'INSERT INTO slice_edges (game_id, a_node_code, b_node_code)
             SELECT ?, a_node_code, b_node_code FROM slice_edges WHERE game_id = ?'
        )->execute([$gameId, $sourceGameId]);

        $factions = rows($pdo, 'SELECT id, code FROM slice_factions WHERE game_id = ? ORDER BY sort_order, id', [$gameId]);

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
        $probe = [];
        for ($i = 0; $i <= PLAYER_COUNT; $i++) {
            $tag = $i === PLAYER_COUNT ? PROBE_NAME : sprintf('LC%03d', $i + 1);
            $insertStudent->execute(['LCC' . sprintf('%04d', $i + 1), $tag, $tag, $passwordHash]);
            $studentId = (int)$pdo->lastInsertId();
            $insertPet->execute([$studentId, $petTemplateId, $tag]);
            $petId = (int)$pdo->lastInsertId();
            $faction = $factions[$i % count($factions)];
            $insertPlayer->execute([$gameId, $studentId, (int)$faction['id'], $tag, $petId, $petCode, $tag]);
            $row = [
                'index' => $i,
                'id' => (int)$pdo->lastInsertId(),
                'name' => $tag,
                'faction_id' => (int)$faction['id'],
                'faction_code' => (string)$faction['code'],
            ];
            if ($i === PLAYER_COUNT) {
                $probe = $row;
            } else {
                $players[] = $row;
            }
        }

        $pdo->prepare(
            "INSERT INTO slice_turns (game_id, turn_no, status, opens_at, deadline_at, rules_version)
             VALUES (?, 1, 'open', NOW(), DATE_ADD(NOW(), INTERVAL 3600 SECOND), 'cards_v1')"
        )->execute([$gameId]);
        $turnId = (int)$pdo->lastInsertId();
        $pdo->prepare('UPDATE slice_games SET current_turn_id = ? WHERE id = ?')->execute([$turnId, $gameId]);

        $adminId = (int)scalar($pdo, "SELECT id FROM admin WHERE username = 'teacher'");
        if ($adminId <= 0) {
            throw new RuntimeException('测试库缺少 teacher 管理员');
        }
        $pdo->prepare(
            'INSERT INTO slice_players
                (game_id, student_id, admin_id, faction_id, nickname, role, pet_instance_id, pet_code, pet_name, is_active)
             VALUES (?, NULL, ?, NULL, "先生", "teacher", NULL, "mentor", "先生", 1)'
        )->execute([$gameId, $adminId]);
        $teacherPlayerId = (int)$pdo->lastInsertId();

        $insertComp = $pdo->prepare(
            'INSERT INTO slice_compositions (game_id, player_id, week_no, types_json, changed_once)
             VALUES (?, ?, 1, ?, 0)'
        );
        $types = ['cav', 'shield', 'arc', 'spear'];
        foreach (array_merge($players, [$probe]) as $i => $p) {
            $comp = [$types[$i % 4], $types[($i + 1) % 4], $types[($i + 2) % 4]];
            $insertComp->execute([$gameId, (int)$p['id'], json_encode($comp)]);
        }

        $pdo->commit();
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        cleanup_load_game($pdo);
        throw $e;
    }

    $nodeSnapshot = rows(
        $pdo,
        'SELECT id, owner_faction_id, morale FROM slice_nodes WHERE game_id = ? ORDER BY id',
        [$gameId]
    );

    // 每个阵营相邻的中立城（排除长安），用于构造合法进攻目标。
    $targets = [];
    $allNodes = rows($pdo, 'SELECT node_code, node_type, owner_faction_id, sort_order FROM slice_nodes WHERE game_id = ? ORDER BY sort_order', [$gameId]);
    $ownerByCode = [];
    foreach ($allNodes as $n) {
        $ownerByCode[(string)$n['node_code']] = $n['owner_faction_id'] === null ? null : (int)$n['owner_faction_id'];
    }
    foreach ($factions as $f) {
        $fid = (int)$f['id'];
        $owned = [];
        foreach ($allNodes as $n) {
            if ($n['owner_faction_id'] !== null && (int)$n['owner_faction_id'] === $fid) {
                $owned[] = (string)$n['node_code'];
            }
        }
        $adjacent = [];
        if ($owned !== []) {
            $in = implode(',', array_fill(0, count($owned), '?'));
            $edges = rows(
                $pdo,
                "SELECT a_node_code, b_node_code FROM slice_edges
                 WHERE game_id = ? AND (a_node_code IN ({$in}) OR b_node_code IN ({$in}))",
                array_merge([$gameId], $owned, $owned)
            );
            foreach ($edges as $edge) {
                $a = (string)$edge['a_node_code'];
                $b = (string)$edge['b_node_code'];
                $other = in_array($a, $owned, true) ? $b : $a;
                if (in_array($other, $owned, true)) {
                    continue;
                }
                $adjacent[$other] = true;
            }
        }
        $neutral = [];
        foreach ($allNodes as $n) {
            $code = (string)$n['node_code'];
            if (isset($adjacent[$code])
                && $n['owner_faction_id'] === null
                && (string)$n['node_type'] !== 'king'
            ) {
                $neutral[] = $code;
            }
        }
        if ($neutral === []) {
            throw new RuntimeException('阵营 ' . $f['code'] . ' 没有可攻中立城');
        }
        $targets[$fid] = array_slice($neutral, 0, 2);
    }
    foreach ($players as &$p) {
        $p['targets'] = $targets[(int)$p['faction_id']] ?? [];
    }
    unset($p);
    $probe['targets'] = $targets[(int)$probe['faction_id']] ?? [];

    return [
        'game_id' => $gameId,
        'turn_id' => $turnId,
        'players' => $players,
        'probe' => $probe,
        'teacher_player_id' => $teacherPlayerId,
        'factions' => $factions,
        'targets' => $targets,
        'node_snapshot' => $nodeSnapshot,
    ];
}

function reset_turn_state(PDO $pdo, int $gameId, int $turnId, array $nodeSnapshot): void
{
    $pdo->prepare('DELETE FROM slice_battles WHERE turn_id = ?')->execute([$turnId]);
    $pdo->prepare('DELETE FROM slice_merit_events WHERE turn_id = ?')->execute([$turnId]);
    $pdo->prepare('DELETE FROM slice_node_changes WHERE turn_id = ?')->execute([$turnId]);
    $pdo->prepare('DELETE FROM slice_turn_results WHERE turn_id = ?')->execute([$turnId]);
    $pdo->prepare('DELETE FROM slice_player_reports WHERE turn_id = ?')->execute([$turnId]);
    $pdo->prepare('DELETE FROM slice_settlement_jobs WHERE turn_id = ?')->execute([$turnId]);

    $stmt = $pdo->prepare('UPDATE slice_nodes SET owner_faction_id = ?, morale = ? WHERE id = ?');
    foreach ($nodeSnapshot as $node) {
        $stmt->execute([
            $node['owner_faction_id'] === null ? null : (int)$node['owner_faction_id'],
            (int)$node['morale'],
            (int)$node['id'],
        ]);
    }

    $pdo->prepare("UPDATE slice_turns SET status = 'open', settled_at = NULL WHERE id = ?")->execute([$turnId]);
    $pdo->prepare("UPDATE slice_games SET status = 'running' WHERE id = ?")->execute([$gameId]);
}

function settle_state(PDO $pdo, int $turnId, int $gameId): array
{
    return [
        'turn_status' => (string)scalar($pdo, 'SELECT status FROM slice_turns WHERE id = ?', [$turnId]),
        'game_status' => (string)scalar($pdo, 'SELECT status FROM slice_games WHERE id = ?', [$gameId]),
        'battles' => (int)scalar($pdo, 'SELECT COUNT(*) FROM slice_battles WHERE turn_id = ?', [$turnId]),
        'battle_nodes' => (int)scalar($pdo, 'SELECT COUNT(DISTINCT node_code) FROM slice_battles WHERE turn_id = ?', [$turnId]),
        'max_battles_per_node' => (int)scalar(
            $pdo,
            'SELECT COALESCE(MAX(c), 0) FROM (SELECT node_code, COUNT(*) c FROM slice_battles WHERE turn_id = ? GROUP BY node_code) x',
            [$turnId]
        ),
        'merit_rows' => (int)scalar($pdo, 'SELECT COUNT(*) FROM slice_merit_events WHERE turn_id = ?', [$turnId]),
        'merit_sum' => (int)scalar($pdo, 'SELECT COALESCE(SUM(amount), 0) FROM slice_merit_events WHERE turn_id = ?', [$turnId]),
        'node_changes' => (int)scalar($pdo, 'SELECT COUNT(*) FROM slice_node_changes WHERE turn_id = ?', [$turnId]),
        'turn_results' => (int)scalar($pdo, 'SELECT COUNT(*) FROM slice_turn_results WHERE turn_id = ?', [$turnId]),
    ];
}

// ---------------------------------------------------------------------------
// 主流程
// ---------------------------------------------------------------------------

[$config, $pdo] = slice_bootstrap();
$dbName = (string)($config['db']['name'] ?? '');
if ($dbName !== 'test_load') {
    fwrite(STDERR, "拒绝运行：config.load.php 必须指向 test_load，当前 {$dbName}\n");
    exit(2);
}
if (realpath((string)getenv('SLICE_CONFIG')) !== realpath($CONFIG_PATH)) {
    fwrite(STDERR, "拒绝运行：SLICE_CONFIG 必须指向 config.load.php\n");
    exit(2);
}

line('=== 0. 隔离检查 ===');
check('配置指向 test_load', $dbName === 'test_load', $dbName);
check('端口 8098 空闲', !is_port_open(PRIMARY_PORT), '8098');
foreach (HELPER_PORTS as $port) {
    check('辅助端口 ' . $port . ' 空闲', !is_port_open($port));
}

line();
line('=== 1. 重建 test_load 并造数 ===');
$setup1 = run_php_script($ROOT . '/scripts/setup_test_db.php', ['--force']);
check('setup_test_db.php', $setup1['exit'] === 0, $setup1['out'] !== '' ? $setup1['out'] : $setup1['err']);
$setup2 = run_php_script($ROOT . '/scripts/setup_map12_db.php');
check('setup_map12_db.php', $setup2['exit'] === 0, $setup2['out'] !== '' ? $setup2['out'] : $setup2['err']);
if ($setup1['exit'] !== 0 || $setup2['exit'] !== 0) {
    exit(1);
}

$ctx = prepare_load_game($pdo);
$gameId = (int)$ctx['game_id'];
$turnId = (int)$ctx['turn_id'];
$players = $ctx['players'];
$probe = $ctx['probe'];
check('独立游戏 LOAD_CC', $gameId > 0, 'game_id=' . $gameId);
check('100 名玩家 + 1 名探针 + 教师', count($players) === 100 && $probe['id'] > 0, 'players=' . count($players));
check('回合 open / 游戏 running', (string)scalar($pdo, 'SELECT status FROM slice_turns WHERE id = ?', [$turnId]) === 'open');

line();
line('=== 2. 启动 API（8098 + 8108–8116） ===');
$ports = array_merge([PRIMARY_PORT], HELPER_PORTS);
try {
    foreach ($ports as $port) {
        $GLOBALS['servers'][$port] = start_api($port);
    }
    $ready = 0;
    foreach ($ports as $port) {
        $ok = false;
        for ($i = 0; $i < 60; $i++) {
            $h = http_simple('GET', "http://127.0.0.1:{$port}/api/health", null, null, 1);
            if ($h['code'] === 200) {
                $ok = true;
                break;
            }
            usleep(100000);
        }
        if ($ok) {
            $ready++;
        }
    }
    check('10 个 API 实例就绪', $ready === count($ports), "ready={$ready}");
    if ($ready !== count($ports)) {
        throw new RuntimeException('API 未全部就绪');
    }

    line();
    line('=== 3. 101 人并发登录 ===');
    $loginReqs = [];
    foreach (array_merge($players, [$probe]) as $i => $p) {
        $loginReqs[] = [
            'port' => $ports[$i % count($ports)],
            'method' => 'POST',
            'path' => '/api/auth/login',
            'body' => ['name' => $p['name'], 'password' => STUDENT_PASSWORD, 'game_code' => GAME_CODE],
            'meta' => $i,
        ];
    }
    $loginResults = ConcurrentHttp::run($loginReqs, 101, 30);
    $tokens = [];
    $loginMs = [];
    $loginErrors = [];
    foreach ($loginResults as $idx => $r) {
        $loginMs[] = $r['ms'];
        $token = (string)($r['json']['data']['token'] ?? '');
        if ($r['code'] === 200 && $token !== '') {
            $tokens[$idx] = $token;
        } else {
            $loginErrors[] = '#' . $idx . ' HTTP ' . $r['code'] . ' ' . substr($r['body'], 0, 120);
        }
    }
    check('101 人登录成功', count($tokens) === 101, ms_text($loginMs));
    if ($loginErrors !== []) {
        line('  登录失败：' . implode(' | ', array_slice($loginErrors, 0, 3)));
    }
    if (count($tokens) !== 101) {
        throw new RuntimeException('登录失败，无法继续');
    }
    $probeToken = $tokens[PLAYER_COUNT];

    line();
    line('=== 4. 手牌：并发创建 / 100 人取牌 ===');
    // 4.1 同一玩家并发 GET /hand：验证 slice_hands 唯一键竞态（重复 5 轮，放大偶发窗口）
    $handRaceCodes = [];
    $handRaceError = '';
    $handRaceRounds = 5;
    $handRacePerRound = 16;
    for ($round = 0; $round < $handRaceRounds; $round++) {
        $pdo->prepare('DELETE FROM slice_hands WHERE turn_id = ? AND player_id = ?')->execute([$turnId, (int)$probe['id']]);
        $handRaceReqs = [];
        for ($i = 0; $i < $handRacePerRound; $i++) {
            $handRaceReqs[] = [
                'port' => $ports[$i % count($ports)],
                'method' => 'GET',
                'path' => '/api/slice/hand?turn_id=' . $turnId,
                'token' => $probeToken,
                'meta' => [$round, $i],
            ];
        }
        $handRace = ConcurrentHttp::run($handRaceReqs, $handRacePerRound, 30);
        foreach ($handRace as $r) {
            $handRaceCodes[$r['code']] = ($handRaceCodes[$r['code']] ?? 0) + 1;
            if ($r['code'] >= 500 && $handRaceError === '') {
                $handRaceError = (string)($r['json']['error']['details']['exception'] ?? substr($r['body'], 0, 200));
            }
        }
    }
    $probeHandRows = (int)scalar($pdo, 'SELECT COUNT(*) FROM slice_hands WHERE turn_id = ? AND player_id = ?', [$turnId, (int)$probe['id']]);
    $handRaceOk = ($handRaceCodes[500] ?? 0) === 0;
    check(
        '同一玩家并发取手牌无 5xx',
        $handRaceOk,
        $handRaceRounds . '×' . $handRacePerRound . ' 并发 codes=' . json_encode($handRaceCodes) . ' hand_rows=' . $probeHandRows
    );
    if (!$handRaceOk) {
        race(
            'slice_hands 并发创建重复键',
            $handRaceRounds . '×' . $handRacePerRound . ' 并发 GET /hand 出现 ' . ($handRaceCodes[500] ?? 0) . ' 个 500；库里仍只有 ' . $probeHandRows . ' 行；' . $handRaceError
        );
    }

    // 4.2 100 人各取一次手牌
    $handReqs = [];
    foreach ($players as $i => $p) {
        $handReqs[] = [
            'port' => $ports[$i % count($ports)],
            'method' => 'GET',
            'path' => '/api/slice/hand?turn_id=' . $turnId,
            'token' => $tokens[$i],
            'meta' => $i,
        ];
    }
    $handResults = ConcurrentHttp::run($handReqs, 100, 30);
    $hands = [];
    $handMs = [];
    $handErrors = [];
    foreach ($handResults as $idx => $r) {
        $handMs[] = $r['ms'];
        $cards = $r['json']['data']['hand']['cards'] ?? null;
        if ($r['code'] === 200 && is_array($cards) && count($cards) === 4) {
            $hands[$idx] = array_values($cards);
        } else {
            $handErrors[] = '#' . $idx . ' HTTP ' . $r['code'] . ' ' . substr($r['body'], 0, 120);
        }
    }
    check('100 人取到 4 张手牌', count($hands) === 100, ms_text($handMs));
    if ($handErrors !== []) {
        line('  取牌失败：' . implode(' | ', array_slice($handErrors, 0, 3)));
    }
    if (count($hands) !== 100) {
        throw new RuntimeException('取手牌失败，无法继续');
    }
    $probeHand = http_simple('GET', 'http://127.0.0.1:' . PRIMARY_PORT . '/api/slice/hand?turn_id=' . $turnId, null, $probeToken, 10);
    $probeCards = $probeHand['json']['data']['hand']['cards'] ?? [];
    check('探针玩家手牌可用', $probeHand['code'] === 200 && count($probeCards) === 4, 'code=' . $probeHand['code']);

    line();
    line('=== 5. 100 人 × 3 令并发提交（300 请求） ===');
    $playReqs = [];
    $expectedKeys = [];
    foreach ($players as $i => $p) {
        $cards = $hands[$i];
        $targets = $p['targets'];
        for ($slot = 0; $slot < 3; $slot++) {
            $target = $targets[($i + $slot) % count($targets)];
            $key = sprintf('load_%03d_%d_%s', $i, $slot, bin2hex(random_bytes(4)));
            $expectedKeys[$i . ':' . $slot] = $key;
            $playReqs[] = [
                'port' => $ports[($i * 3 + $slot) % count($ports)],
                'method' => 'POST',
                'path' => '/api/slice/order/play',
                'token' => $tokens[$i],
                'body' => [
                    'turn_id' => $turnId,
                    'slot' => $slot,
                    'card_code' => $cards[$slot],
                    'target_node_code' => $target,
                    'lane' => $slot + 1,
                    'row_pos' => $slot === 2 ? 'back' : 'front',
                    'request_key' => $key,
                ],
                'meta' => [$i, $slot],
            ];
        }
    }
    $playStarted = microtime(true);
    $playResults = ConcurrentHttp::run($playReqs, 120, 30);
    $playElapsed = (microtime(true) - $playStarted) * 1000;
    $playMs = [];
    $playCodes = [];
    $playErrorCodes = [];
    foreach ($playResults as $r) {
        $playMs[] = $r['ms'];
        $playCodes[$r['code']] = ($playCodes[$r['code']] ?? 0) + 1;
        if ($r['code'] !== 200) {
            $ec = (string)($r['json']['error']['code'] ?? 'NO_CODE');
            $playErrorCodes[$ec] = ($playErrorCodes[$ec] ?? 0) + 1;
        }
    }
    $playOk = (int)($playCodes[200] ?? 0);
    check('300 个 play 全部 200', $playOk === 300, 'ok=' . $playOk . ' codes=' . json_encode($playCodes));
    if ($playErrorCodes !== []) {
        line('  错误码：' . json_encode($playErrorCodes, JSON_UNESCAPED_UNICODE));
    }
    check('提交总耗时 < 10s', $playElapsed < 10000, sprintf('%.0f ms', $playElapsed));
    line('  响应时间：' . ms_text($playMs));

    $active = (int)scalar($pdo, "SELECT COUNT(*) FROM slice_order_slots WHERE turn_id = ? AND status = 'active'", [$turnId]);
    $activePlayers = (int)scalar($pdo, "SELECT COUNT(DISTINCT player_id) FROM slice_order_slots WHERE turn_id = ? AND status = 'active'", [$turnId]);
    $badSlotCount = (int)scalar(
        $pdo,
        "SELECT COUNT(*) FROM (
            SELECT player_id, COUNT(*) c FROM slice_order_slots
            WHERE turn_id = ? AND status = 'active' GROUP BY player_id HAVING c <> 3
         ) x",
        [$turnId]
    );
    check('库里 300 条 active 令', $active === 300, 'active=' . $active);
    check('100 名玩家各 3 条', $activePlayers === 100 && $badSlotCount === 0, 'players=' . $activePlayers . ' bad=' . $badSlotCount);

    $keyRows = rows($pdo, "SELECT player_id, slot, last_request_key FROM slice_order_slots WHERE turn_id = ? AND status = 'active'", [$turnId]);
    $idToIndex = [];
    foreach ($players as $pi => $pp) {
        $idToIndex[(int)$pp['id']] = $pi;
    }
    $keyMismatch = 0;
    foreach ($keyRows as $row) {
        $idx = $idToIndex[(int)$row['player_id']] ?? null;
        if ($idx === null) {
            continue;
        }
        $expect = $expectedKeys[$idx . ':' . (int)$row['slot']] ?? '';
        if ($expect !== '' && !hash_equals($expect, (string)$row['last_request_key'])) {
            $keyMismatch++;
        }
    }
    check('request_key 正确落库', $keyMismatch === 0, 'mismatch=' . $keyMismatch);

    line();
    line('=== 6. 同一 request_key 并发重复 20 次 ===');
    $p0 = $players[0];
    $idemKey = 'idem_' . bin2hex(random_bytes(6));
    $idemBody = [
        'turn_id' => $turnId,
        'slot' => 0,
        'card_code' => $hands[0][0],
        'target_node_code' => $p0['targets'][0],
        'lane' => 1,
        'row_pos' => 'front',
        'request_key' => $idemKey,
    ];
    $idemReqs = [];
    for ($i = 0; $i < 20; $i++) {
        $idemReqs[] = [
            'port' => $ports[$i % count($ports)],
            'method' => 'POST',
            'path' => '/api/slice/order/play',
            'token' => $tokens[0],
            'body' => $idemBody,
            'meta' => $i,
        ];
    }
    $idemResults = ConcurrentHttp::run($idemReqs, 20, 30);
    $idemCodes = [];
    $idemMs = [];
    foreach ($idemResults as $r) {
        $idemCodes[$r['code']] = ($idemCodes[$r['code']] ?? 0) + 1;
        $idemMs[] = $r['ms'];
    }
    $idemRows = (int)scalar(
        $pdo,
        "SELECT COUNT(*) FROM slice_order_slots WHERE turn_id = ? AND player_id = ? AND last_request_key = ? AND status = 'active'",
        [$turnId, (int)$p0['id'], $idemKey]
    );
    $activeAfterIdem = (int)scalar($pdo, "SELECT COUNT(*) FROM slice_order_slots WHERE turn_id = ? AND status = 'active'", [$turnId]);
    check('20 次同 key 全部 200', (int)($idemCodes[200] ?? 0) === 20, 'codes=' . json_encode($idemCodes));
    check('同 key 同 slot 只有 1 条 active 令', $idemRows === 1 && $activeAfterIdem === 300, 'rows=' . $idemRows . ' active=' . $activeAfterIdem);
    line('  响应时间：' . ms_text($idemMs));

    // 同一 key 换 slot：验证 request_key 是否真的是幂等键
    $crossSlot = http_simple('POST', 'http://127.0.0.1:' . PRIMARY_PORT . '/api/slice/order/play', [
        'turn_id' => $turnId,
        'slot' => 1,
        'card_code' => $hands[0][1],
        'target_node_code' => $p0['targets'][1 % count($p0['targets'])],
        'lane' => 2,
        'row_pos' => 'front',
        'request_key' => $idemKey,
    ], $tokens[0], 10);
    $sameKeyRows = (int)scalar(
        $pdo,
        "SELECT COUNT(*) FROM slice_order_slots WHERE turn_id = ? AND player_id = ? AND last_request_key = ? AND status = 'active'",
        [$turnId, (int)$p0['id'], $idemKey]
    );
    if ($crossSlot['code'] === 200 && $sameKeyRows > 1) {
        finding(
            'request_key 不是幂等键',
            '同一 key 先后落到 slot 0 / slot 1，返回 200 且产生 ' . $sameKeyRows . ' 条 active 令；slice_order_requests 唯一键未被使用'
        );
    } else {
        check('同一 key 跨 slot 被拒绝或去重', false, 'code=' . $crossSlot['code'] . ' rows=' . $sameKeyRows);
    }
    // 还原 slot 1
    http_simple('POST', 'http://127.0.0.1:' . PRIMARY_PORT . '/api/slice/order/play', [
        'turn_id' => $turnId,
        'slot' => 1,
        'card_code' => $hands[0][1],
        'target_node_code' => $p0['targets'][(0 + 1) % count($p0['targets'])],
        'lane' => 2,
        'row_pos' => 'front',
        'request_key' => $expectedKeys['0:1'],
    ], $tokens[0], 10);

    line();
    line('=== 7. 教师双击结算（同一 turn 2/4 请求并发） ===');
    $teacherLogin = http_simple('POST', 'http://127.0.0.1:' . PRIMARY_PORT . '/api/auth/admin-login', [
        'username' => TEACHER_NAME,
        'password' => TEACHER_PASSWORD,
        'game_code' => GAME_CODE,
    ], null, 10);
    check('教师登录', $teacherLogin['code'] === 200, substr($teacherLogin['raw'], 0, 160));
    $teacherToken = (string)($teacherLogin['json']['data']['token'] ?? '');
    if ($teacherToken === '') {
        throw new RuntimeException('教师登录失败');
    }

    // 基线：单请求结算
    reset_turn_state($pdo, $gameId, $turnId, $ctx['node_snapshot']);
    $single = ConcurrentHttp::run([[
        'port' => PRIMARY_PORT,
        'method' => 'POST',
        'path' => '/api/slice/admin/card-settle',
        'token' => $teacherToken,
        'body' => ['turn_id' => $turnId],
        'meta' => 'single',
    ]], 1, 60)[0];
    $singleJson = $single['json'] ?? [];
    $singleAlready = $singleJson['data']['already_settled'] ?? null;
    $singleBattles = 0;
    $singleSkipped = [];
    foreach (($singleJson['data']['battles'] ?? []) as $entry) {
        if (!empty($entry['battle_id'])) {
            $singleBattles++;
        } else {
            $singleSkipped[] = (string)($entry['node_code'] ?? '?') . ':' . (string)($entry['reason'] ?? '?');
        }
    }
    $baseline = settle_state($pdo, $turnId, $gameId);
    $baselineMs = $single['ms'];
    check('基线单次结算成功', $single['code'] === 200 && $singleAlready === false, 'HTTP ' . $single['code'] . ' ms=' . round($baselineMs, 1));
    check(
        '基线战斗入库一致',
        $baseline['battles'] === $singleBattles && $baseline['battle_nodes'] === $baseline['battles'],
        'db=' . $baseline['battles'] . ' resp=' . $singleBattles . ' nodes=' . $baseline['battle_nodes']
    );
    if ($singleSkipped !== []) {
        finding(
            '结算响应包含非战斗条目',
            'data.battles 有 ' . count($singleSkipped) . ' 条 battle_id=null（' . implode(',', $singleSkipped) . '）；客户端必须过滤，不能按数组长度统计战斗'
        );
    }
    line(sprintf(
        '  基线：%.1fms，battles=%d，merit_rows=%d，merit_sum=%d，node_changes=%d',
        $baselineMs,
        $baseline['battles'],
        $baseline['merit_rows'],
        $baseline['merit_sum'],
        $baseline['node_changes']
    ));

    $racePorts = [PRIMARY_PORT, HELPER_PORTS[0], HELPER_PORTS[1], HELPER_PORTS[2]];
    $delaysMs = [0, 2, 4, 6, 8, 10, 12, 14, 16, 20, 24, 28, 32, 36, 40, 45, 50, 60, 70, 80];
    foreach ([0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0] as $f) {
        $delaysMs[] = round($baselineMs * $f, 1);
    }
    for ($i = 0; $i < 12; $i++) {
        $delaysMs[] = round(mt_rand(0, (int)max(1, $baselineMs + 20)), 1);
    }

    $roundStats = [
        'rounds' => 0,
        'real_success' => 0,
        'already' => 0,
        'busy' => 0,
        'other' => 0,
        'double_real' => 0,
        'battle_dup' => 0,
        'merit_dup' => 0,
        'battle_mismatch' => 0,
        'merit_mismatch' => 0,
        'invalid' => 0,
        'game_bad' => 0,
        'turn_result_bad' => 0,
    ];
    $anomalies = [];
    $settleMs = [];
    $settleMsByKind = ['real' => [], 'already' => [], 'busy' => [], 'other' => []];
    $roundPatterns = [];
    $roundRows = [];
    $busyMessage = '';

    $runRound = function (array $delays, array $portsForRound) use (
        $pdo,
        $gameId,
        $turnId,
        $ctx,
        $teacherToken,
        $baseline,
        &$roundStats,
        &$anomalies,
        &$settleMs,
        &$settleMsByKind,
        &$roundPatterns,
        &$roundRows,
        &$busyMessage
    ): void {
        reset_turn_state($pdo, $gameId, $turnId, $ctx['node_snapshot']);
        $now = microtime(true);
        $reqs = [];
        foreach ($delays as $k => $delay) {
            $reqs[] = [
                'port' => $portsForRound[$k % count($portsForRound)],
                'method' => 'POST',
                'path' => '/api/slice/admin/card-settle',
                'token' => $teacherToken,
                'body' => ['turn_id' => $turnId],
                'start_at' => $now + ($delay / 1000.0),
                'meta' => $delay,
            ];
        }
        $results = ConcurrentHttp::run($reqs, count($reqs), 60);
        usleep(30000);

        $real = 0;
        $already = 0;
        $busy = 0;
        $other = 0;
        $invalid = 0;
        $details = [];
        foreach ($results as $r) {
            $settleMs[] = $r['ms'];
            $json = $r['json'] ?? [];
            if ($r['code'] === 200 && array_key_exists('already_settled', $json['data'] ?? [])) {
                if ($json['data']['already_settled'] === false) {
                    $real++;
                    $settleMsByKind['real'][] = $r['ms'];
                } else {
                    $already++;
                    $settleMsByKind['already'][] = $r['ms'];
                }
                $details[] = '200/' . ($json['data']['already_settled'] ? 'already' : 'real');
            } elseif ($r['code'] === 409 && (string)($json['error']['code'] ?? '') === 'SETTLE_BUSY') {
                $busy++;
                $settleMsByKind['busy'][] = $r['ms'];
                if ($busyMessage === '') {
                    $busyMessage = (string)($json['error']['message'] ?? '');
                }
                $details[] = '409/busy';
            } else {
                $other++;
                $invalid++;
                $settleMsByKind['other'][] = $r['ms'];
                $details[] = ($r['code'] ?: 'ERR') . '/' . (string)($json['error']['code'] ?? $r['error'] ?? 'unknown');
            }
        }

        $state = settle_state($pdo, $turnId, $gameId);
        $roundStats['rounds']++;
        $roundStats['real_success'] += $real;
        $roundStats['already'] += $already;
        $roundStats['busy'] += $busy;
        $roundStats['other'] += $other;
        if ($real > 1) {
            $roundStats['double_real']++;
        }
        if ($state['battles'] > $baseline['battles'] || $state['max_battles_per_node'] > 1) {
            $roundStats['battle_dup']++;
        }
        if ($state['merit_sum'] > $baseline['merit_sum']) {
            $roundStats['merit_dup']++;
        }
        if ($state['battles'] !== $baseline['battles']
            || $state['battle_nodes'] !== $baseline['battle_nodes']
            || $state['max_battles_per_node'] !== 1
        ) {
            $roundStats['battle_mismatch']++;
        }
        if ($state['merit_sum'] !== $baseline['merit_sum'] || $state['merit_rows'] !== $baseline['merit_rows']) {
            $roundStats['merit_mismatch']++;
        }
        if ($invalid > 0) {
            $roundStats['invalid']++;
        }
        if ($state['game_status'] !== 'running') {
            $roundStats['game_bad']++;
        }
        if ($state['turn_results'] !== 1) {
            $roundStats['turn_result_bad']++;
        }

        $pattern = 'real=' . $real . ',already=' . $already . ',busy=' . $busy . ',other=' . $other;
        $roundPatterns[$pattern] = ($roundPatterns[$pattern] ?? 0) + 1;
        $roundRows[] = [
            'delays_ms' => $delays,
            'real' => $real,
            'already' => $already,
            'busy' => $busy,
            'other' => $other,
            'state_battles' => $state['battles'],
            'state_merit_sum' => $state['merit_sum'],
        ];

        $anomaly = $real > 1
            || $state['battles'] !== $baseline['battles']
            || $state['battle_nodes'] !== $baseline['battle_nodes']
            || $state['max_battles_per_node'] !== 1
            || $state['merit_sum'] !== $baseline['merit_sum']
            || $state['merit_rows'] !== $baseline['merit_rows']
            || $state['turn_results'] !== 1
            || $state['game_status'] !== 'running'
            || $state['turn_status'] !== 'settled';
        if ($anomaly) {
            $anomalies[] = [
                'delays' => $delays,
                'details' => $details,
                'real' => $real,
                'already' => $already,
                'busy' => $busy,
                'state' => $state,
                'baseline' => $baseline,
            ];
        }
    };

    foreach ($delaysMs as $delay) {
        $runRound([0.0, (float)$delay], $racePorts);
    }
    for ($i = 0; $i < 8; $i++) {
        $runRound([0.0, round($baselineMs / 3, 1), round($baselineMs * 2 / 3, 1), (float)$baselineMs], $racePorts);
    }

    $rounds = $roundStats['rounds'];
    check(
        '没有出现两次真实结算',
        $roundStats['double_real'] === 0,
        'double_real=' . $roundStats['double_real'] . '/' . $rounds
    );
    check(
        'slice_battles 无重复',
        $roundStats['battle_dup'] === 0,
        'dup_rounds=' . $roundStats['battle_dup'] . ' baseline=' . $baseline['battles']
    );
    check(
        'slice_merit_events 金额未翻倍',
        $roundStats['merit_dup'] === 0,
        'dup_rounds=' . $roundStats['merit_dup'] . ' baseline=' . $baseline['merit_sum']
    );
    check(
        '每轮战斗数与基线完全一致',
        $roundStats['battle_mismatch'] === 0,
        'mismatch=' . $roundStats['battle_mismatch'] . ' baseline=' . $baseline['battles']
    );
    check(
        '每轮军功行数/金额与基线完全一致',
        $roundStats['merit_mismatch'] === 0,
        'mismatch=' . $roundStats['merit_mismatch'] . ' baseline=' . $baseline['merit_sum']
    );
    check(
        'slice_turn_results / turn 状态唯一稳定',
        $roundStats['invalid'] === 0 && $roundStats['other'] === 0 && $roundStats['turn_result_bad'] === 0,
        'invalid=' . $roundStats['invalid'] . ' other=' . $roundStats['other'] . ' turn_result_bad=' . $roundStats['turn_result_bad']
    );
    check(
        'slice_games 状态未被重复结算改写',
        $roundStats['game_bad'] === 0,
        'game_bad=' . $roundStats['game_bad']
    );
    line(sprintf(
        '  %d 轮：real=%d already=%d busy=%d other=%d；double_real=%d battle_dup=%d merit_dup=%d battle_mismatch=%d merit_mismatch=%d game_bad=%d turn_result_bad=%d',
        $rounds,
        $roundStats['real_success'],
        $roundStats['already'],
        $roundStats['busy'],
        $roundStats['other'],
        $roundStats['double_real'],
        $roundStats['battle_dup'],
        $roundStats['merit_dup'],
        $roundStats['battle_mismatch'],
        $roundStats['merit_mismatch'],
        $roundStats['game_bad'],
        $roundStats['turn_result_bad']
    ));
    ksort($roundPatterns);
    line('  每轮结果组合：' . json_encode($roundPatterns));
    line('  结算响应：' . ms_text($settleMs));
    line('  真实结算耗时：' . ms_text($settleMsByKind['real']));
    line('  SETTLE_BUSY 耗时：' . ms_text($settleMsByKind['busy']));
    line('  already_settled 耗时：' . ms_text($settleMsByKind['already']));
    if ($busyMessage !== '') {
        if (preg_match('/^\?+$/', $busyMessage) === 1) {
            finding('SETTLE_BUSY 错误文案损坏', '接口返回 message="' . $busyMessage . '"，教师端无法理解');
        } else {
            line('  SETTLE_BUSY message：' . $busyMessage);
        }
    }
    line('  [RISK] CardSettlementService 在 GET_LOCK 之前检查 turn.status，锁内未复查；');
    line('         若请求在 SELECT 与 GET_LOCK 之间被 OS 抢占，仍可能二次结算（本次 ' . $rounds . ' 轮未复现）。');
    if ($anomalies !== []) {
        $first = $anomalies[0];
        race(
            '教师并发结算产生重复数据',
            json_encode([
                'delays' => $first['delays'],
                'details' => $first['details'],
                'state' => $first['state'],
                'baseline' => $first['baseline'],
            ], JSON_UNESCAPED_UNICODE)
        );
    }

    line();
    line('=== 8. 结算过程中出令（快照后写入） ===');
    $lateAttempts = [];
    $lateConfirmed = 0;
    if ($probeCards === []) {
        check('探针手牌可用', false, '跳过结算中出令');
    } else {
        $probeTarget = $probe['targets'][0] ?? '';
        $lateDelays = [
            round($baselineMs * 0.35, 1),
            round($baselineMs * 0.50, 1),
            round($baselineMs * 0.65, 1),
        ];
        foreach ($lateDelays as $delay) {
            reset_turn_state($pdo, $gameId, $turnId, $ctx['node_snapshot']);
            $pdo->prepare('DELETE FROM slice_order_slots WHERE turn_id = ? AND player_id = ?')->execute([$turnId, (int)$probe['id']]);

            $now = microtime(true);
            $batch = ConcurrentHttp::run([
                [
                    'port' => PRIMARY_PORT,
                    'method' => 'POST',
                    'path' => '/api/slice/admin/card-settle',
                    'token' => $teacherToken,
                    'body' => ['turn_id' => $turnId],
                    'start_at' => $now,
                    'meta' => 'settle',
                ],
                [
                    'port' => HELPER_PORTS[0],
                    'method' => 'POST',
                    'path' => '/api/slice/order/play',
                    'token' => $probeToken,
                    'body' => [
                        'turn_id' => $turnId,
                        'slot' => 0,
                        'card_code' => $probeCards[0],
                        'target_node_code' => $probeTarget,
                        'lane' => 1,
                        'row_pos' => 'front',
                        'request_key' => 'late_' . bin2hex(random_bytes(5)),
                    ],
                    'start_at' => $now + ($delay / 1000.0),
                    'meta' => 'play',
                ],
            ], 2, 60);

            $settleResp = $batch[0];
            $playResp = $batch[1];
            usleep(30000);

            $state = settle_state($pdo, $turnId, $gameId);
            $probeOrders = (int)scalar(
                $pdo,
                "SELECT COUNT(*) FROM slice_order_slots WHERE turn_id = ? AND player_id = ? AND status = 'active'",
                [$turnId, (int)$probe['id']]
            );
            $probeMerit = (int)scalar(
                $pdo,
                'SELECT COUNT(*) FROM slice_merit_events WHERE turn_id = ? AND player_id = ?',
                [$turnId, (int)$probe['id']]
            );
            $probeInBattle = false;
            foreach (rows($pdo, 'SELECT result_json FROM slice_battles WHERE turn_id = ?', [$turnId]) as $battleRow) {
                $decoded = json_decode((string)$battleRow['result_json'], true);
                if (is_array($decoded) && isset($decoded['players'][(string)$probe['id']])) {
                    $probeInBattle = true;
                    break;
                }
            }

            $attempt = [
                'delay_ms' => $delay,
                'settle_code' => $settleResp['code'],
                'settle_ms' => round($settleResp['ms'], 1),
                'play_code' => $playResp['code'],
                'play_error' => $playResp['json']['error']['code'] ?? null,
                'play_ms' => round($playResp['ms'], 1),
                'turn_status' => $state['turn_status'],
                'probe_orders' => $probeOrders,
                'probe_merit_rows' => $probeMerit,
                'probe_in_battle' => $probeInBattle,
            ];
            $lateAttempts[] = $attempt;

            $confirmed = $playResp['code'] === 200
                && $state['turn_status'] === 'settled'
                && $probeOrders === 1
                && $probeMerit === 0
                && !$probeInBattle;
            if ($confirmed) {
                $lateConfirmed++;
            }
            line(sprintf(
                '  delay=%.1fms settle=%d/%.1fms play=%d/%s orders=%d merit=%d in_battle=%s',
                $delay,
                $settleResp['code'],
                $settleResp['ms'],
                $playResp['code'],
                (string)($playResp['json']['error']['code'] ?? '-'),
                $probeOrders,
                $probeMerit,
                $probeInBattle ? 'yes' : 'no'
            ));
        }

        check('结算中出令未被静默接受', $lateConfirmed === 0, 'confirmed=' . $lateConfirmed . '/' . count($lateDelays));
        if ($lateConfirmed > 0) {
            race(
                '结算快照后仍可出令',
                $lateConfirmed . '/' . count($lateDelays) . ' 次返回 200 且令未被结算：turn 已 settled，令仍 active，无 participation 军功、未进 battle players'
            );
        }
    }

    line();
    line('=== 9. 错误码分布 ===');
    line('  login: ' . json_encode($loginResults ? array_count_values(array_map(static fn($r) => $r['code'], $loginResults)) : []));
    line('  hand:  ' . json_encode($handResults ? array_count_values(array_map(static fn($r) => $r['code'], $handResults)) : []));
    line('  play:  ' . json_encode($playCodes) . ' errors=' . json_encode($playErrorCodes));
    line('  idem:  ' . json_encode($idemCodes));
    line('  settle real/already/busy/other: ' . $roundStats['real_success'] . '/' . $roundStats['already'] . '/' . $roundStats['busy'] . '/' . $roundStats['other']);

    $summary = [
        'game_id' => $gameId,
        'turn_id' => $turnId,
        'players' => count($players),
        'play_requests' => count($playResults),
        'play_ok' => $playOk,
        'play_ms' => [
            'p50' => round(pct($playMs, 50), 1),
            'p95' => round(pct($playMs, 95), 1),
            'max' => round(max($playMs), 1),
        ],
        'active_orders' => $active,
        'idempotent_rows' => $idemRows,
        'same_key_cross_slot_rows' => $sameKeyRows,
        'settle_baseline_ms' => round($baselineMs, 1),
        'settle_baseline' => $baseline,
        'settle_rounds' => $roundStats,
        'settle_round_patterns' => $roundPatterns,
        'settle_busy_message' => $busyMessage,
        'settle_ms_by_kind' => [
            'real' => [
                'p50' => round(pct($settleMsByKind['real'], 50), 1),
                'p95' => round(pct($settleMsByKind['real'], 95), 1),
                'max' => $settleMsByKind['real'] === [] ? 0 : round(max($settleMsByKind['real']), 1),
            ],
            'busy' => [
                'p50' => round(pct($settleMsByKind['busy'], 50), 1),
                'p95' => round(pct($settleMsByKind['busy'], 95), 1),
                'max' => $settleMsByKind['busy'] === [] ? 0 : round(max($settleMsByKind['busy']), 1),
            ],
            'already' => [
                'p50' => round(pct($settleMsByKind['already'], 50), 1),
                'p95' => round(pct($settleMsByKind['already'], 95), 1),
                'max' => $settleMsByKind['already'] === [] ? 0 : round(max($settleMsByKind['already']), 1),
            ],
        ],
        'hand_race' => [
            'codes' => $handRaceCodes,
            'error' => $handRaceError,
            'hand_rows' => $probeHandRows,
        ],
        'late_order' => [
            'attempts' => $lateAttempts,
            'confirmed' => $lateConfirmed,
        ],
        'failed' => $GLOBALS['failed'],
        'findings' => $GLOBALS['findings'],
        'races' => $GLOBALS['races'],
    ];
    line();
    line('RESULT_JSON: ' . json_encode($summary, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));
} catch (Throwable $e) {
    line('[FATAL] ' . $e->getMessage());
    line($e->getTraceAsString());
    $GLOBALS['failed']++;
} finally {
    line();
    line('=== 10. 清理 ===');
    stop_all_servers();
    $released = true;
    foreach ($ports as $port) {
        if (is_port_open($port)) {
            $released = false;
            line('  [WARN] 端口仍被占用：' . $port);
        }
    }
    check('8098/8108–8116 已释放', $released);
    try {
        cleanup_load_game($pdo);
        check('LOAD_CC / LC* 临时数据已清理', (int)scalar($pdo, "SELECT COUNT(*) FROM slice_games WHERE code = ?", [GAME_CODE]) === 0);
    } catch (Throwable $e) {
        check('临时数据清理', false, $e->getMessage());
    }
}

line();
if ($GLOBALS['failed'] > 0) {
    line('LOAD_CONCURRENCY FAIL (' . $GLOBALS['failed'] . ' failed, ' . $GLOBALS['races'] . ' races, ' . $GLOBALS['findings'] . ' findings)');
    exit(1);
}
if ($GLOBALS['races'] > 0) {
    line('LOAD_CONCURRENCY RACE_FOUND (' . $GLOBALS['races'] . ' races, ' . $GLOBALS['findings'] . ' findings)');
    exit(1);
}
line('LOAD_CONCURRENCY PASS (' . $GLOBALS['findings'] . ' findings)');
exit(0);
