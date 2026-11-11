<?php
declare(strict_types=1);

/**
 * 12+1 城城主流程 · 真实 HTTP 集成测试
 *
 * 隔离约定：
 *   - 独立数据库：test_api（server/slice/config.api.php）
 *   - 独立端口：127.0.0.1:8099（不碰 8080/8081）
 *   - 只通过 HTTP 调 API；不 require 业务源码、不直接读写业务表
 *   - 默认先重置 test_api（setup_test_db + setup_map12_db），再启动/关闭内置服务器
 *
 * 用法：
 *   php -d extension_dir=<php>\ext -d extension=pdo_mysql tests/api_http_test.php
 *   php ... tests/api_http_test.php --skip-setup   # 保留当前 test_api 数据
 *
 * 前置：
 *   test_api 库必须已存在，且 qingzhu_test 有 ALL 权限：
 *     CREATE DATABASE IF NOT EXISTS test_api CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
 *     GRANT ALL PRIVILEGES ON test_api.* TO 'qingzhu_test'@'127.0.0.1';
 */

const API_HOST = '127.0.0.1';
const API_PORT = 8099;
const GAME_CODE = 'MAP12_TEST';
const STUDENT_NAME = '青竹一';
const STUDENT_PASSWORD = 'slice2026';
const TEACHER_NAME = 'teacher';
const TEACHER_PASSWORD = 'teacher2026';

$ROOT = dirname(__DIR__);
$PHP = PHP_BINARY;
$EXT_DIR = dirname(PHP_BINARY) . DIRECTORY_SEPARATOR . 'ext';
$CONFIG = $ROOT . DIRECTORY_SEPARATOR . 'config.api.php';
$PUBLIC_DIR = $ROOT . DIRECTORY_SEPARATOR . 'public';
$ROUTER = $PUBLIC_DIR . DIRECTORY_SEPARATOR . 'index.php';
$BASE_URL = 'http://' . API_HOST . ':' . API_PORT;
$SERVER_LOG = sys_get_temp_dir() . DIRECTORY_SEPARATOR . 'qingzhu_api_http_8099.log';

$serverProc = null;
$results = [];
$suiteStarted = microtime(true);
$skipSetup = in_array('--skip-setup', $argv, true);

if (in_array('--help', $argv, true) || in_array('-h', $argv, true)) {
    fwrite(STDOUT, <<<TEXT
12+1 城城主流程 HTTP 集成测试（独立库 test_api / 独立端口 8099）

  php -d extension_dir=<php>\\ext -d extension=pdo_mysql tests/api_http_test.php
  php ... tests/api_http_test.php --skip-setup   保留现有 test_api 数据

默认会重置 test_api，再启动 127.0.0.1:8099 的内置服务器，跑完自动停止。

TEXT);
    exit(0);
}

register_shutdown_function('stop_server');

// ---------------------------------------------------------------------------
// 基础设施
// ---------------------------------------------------------------------------

function stop_server(): void
{
    global $serverProc;

    if (!is_resource($serverProc)) {
        return;
    }

    $status = proc_get_status($serverProc);
    if (($status['running'] ?? false) === true) {
        @proc_terminate($serverProc, 9);
    }

    $deadline = microtime(true) + 5.0;
    while (microtime(true) < $deadline) {
        $status = proc_get_status($serverProc);
        if (($status['running'] ?? false) !== true) {
            break;
        }
        usleep(100000);
    }

    $status = proc_get_status($serverProc);
    if (($status['running'] ?? false) === true && PHP_OS_FAMILY === 'Windows') {
        @exec('taskkill /F /PID ' . (int)($status['pid'] ?? 0) . ' >NUL 2>&1');
    }

    @proc_close($serverProc);
    $serverProc = null;
}

function is_port_open(string $host, int $port): bool
{
    error_clear_last();
    $fp = @fsockopen($host, $port, $errno, $errstr, 0.3);
    if (is_resource($fp)) {
        fclose($fp);
        return true;
    }
    return false;
}

function proc_running(mixed $proc): bool
{
    if (!is_resource($proc)) {
        return false;
    }
    $status = proc_get_status($proc);
    return (bool)($status['running'] ?? false);
}

/**
 * 用当前 PHP 二进制跑一个 CLI 脚本，继承 SLICE_CONFIG。
 *
 * @return array{exit:int,out:string,err:string,ms:float}
 */
function run_php_script(string $script): array
{
    global $PHP, $EXT_DIR, $ROOT;

    $cmd = [
        $PHP,
        '-d',
        'extension_dir=' . $EXT_DIR,
        '-d',
        'extension=pdo_mysql',
        $script,
    ];
    $descriptors = [
        0 => ['file', 'NUL', 'r'],
        1 => ['pipe', 'w'],
        2 => ['pipe', 'w'],
    ];

    $started = microtime(true);
    $proc = @proc_open($cmd, $descriptors, $pipes, $ROOT, null, ['bypass_shell' => true]);
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

function start_server(): mixed
{
    global $PHP, $EXT_DIR, $ROOT, $PUBLIC_DIR, $ROUTER, $SERVER_LOG;

    if (is_port_open(API_HOST, API_PORT)) {
        return null;
    }

    @unlink($SERVER_LOG);
    $cmd = [
        $PHP,
        '-d',
        'extension_dir=' . $EXT_DIR,
        '-d',
        'extension=pdo_mysql',
        '-S',
        API_HOST . ':' . API_PORT,
        '-t',
        $PUBLIC_DIR,
        $ROUTER,
    ];
    $descriptors = [
        0 => ['file', 'NUL', 'r'],
        1 => ['file', $SERVER_LOG, 'a'],
        2 => ['file', $SERVER_LOG, 'a'],
    ];

    $proc = @proc_open($cmd, $descriptors, $pipes, $ROOT, null, ['bypass_shell' => true]);
    return is_resource($proc) ? $proc : null;
}

function server_log_tail(int $bytes = 2000): string
{
    global $SERVER_LOG;
    if (!is_file($SERVER_LOG)) {
        return '（无服务器日志）';
    }
    $raw = (string)@file_get_contents($SERVER_LOG);
    return $raw === '' ? '（服务器日志为空）' : substr($raw, -$bytes);
}

/**
 * @return array{status:int,json:?array,raw:string,ms:float,error:?string,headers:array<int,string>}
 */
function api(string $method, string $path, ?array $body = null, ?string $token = null): array
{
    global $BASE_URL;

    $headers = [
        'Accept: application/json',
        'Connection: close',
    ];
    $content = '';
    if ($body !== null) {
        $content = (string)json_encode($body, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        $headers[] = 'Content-Type: application/json';
    }
    if ($token !== null && $token !== '') {
        $headers[] = 'Authorization: Bearer ' . $token;
    }

    $context = stream_context_create([
        'http' => [
            'method' => $method,
            'header' => implode("\r\n", $headers),
            'content' => $content,
            'ignore_errors' => true,
            'timeout' => 20,
            'protocol_version' => 1.1,
        ],
    ]);

    error_clear_last();
    $started = microtime(true);
    $raw = @file_get_contents($BASE_URL . $path, false, $context);
    $ms = (microtime(true) - $started) * 1000;
    $lastError = error_get_last();
    $responseHeaders = $http_response_header ?? [];

    $status = 0;
    foreach ($responseHeaders as $line) {
        if (preg_match('#^HTTP/\S+\s+(\d{3})#', (string)$line, $m) === 1) {
            $status = (int)$m[1];
            break;
        }
    }

    $json = null;
    if (is_string($raw) && $raw !== '') {
        $decoded = json_decode($raw, true);
        if (is_array($decoded)) {
            $json = $decoded;
        }
    }

    $error = null;
    if ($raw === false) {
        $error = (string)($lastError['message'] ?? 'HTTP 请求失败');
    } elseif ($json === null) {
        $error = '响应不是 JSON：' . substr((string)$raw, 0, 200);
    }

    return [
        'status' => $status,
        'json' => $json,
        'raw' => is_string($raw) ? $raw : '',
        'ms' => $ms,
        'error' => $error,
        'headers' => $responseHeaders,
    ];
}

function begin_step(): array
{
    return ['t' => microtime(true), 'checks' => [], 'http' => []];
}

function expect(array &$step, string $label, bool $ok, string $extra = ''): void
{
    $extra = trim((string)preg_replace('/\s+/u', ' ', $extra));
    if (function_exists('mb_strlen')) {
        if (mb_strlen($extra) > 240) {
            $extra = mb_substr($extra, 0, 240) . '…';
        }
    } elseif (strlen($extra) > 480) {
        $extra = substr($extra, 0, 480) . '…';
    }
    $step['checks'][] = ['label' => $label, 'ok' => $ok, 'extra' => $extra];
}

function call_api(array &$step, string $method, string $path, ?array $body = null, ?string $token = null): array
{
    $response = api($method, $path, $body, $token);
    $step['http'][] = [
        'method' => $method,
        'path' => $path,
        'status' => $response['status'],
        'ms' => round($response['ms'], 1),
    ];
    return $response;
}

function error_code(array $response): string
{
    return (string)($response['json']['error']['code'] ?? '');
}

function error_detail(array $response, string $key): mixed
{
    return $response['json']['error']['details'][$key] ?? null;
}

function finish_step(string $name, array $step): bool
{
    global $results;

    $failed = array_values(array_filter($step['checks'], static fn(array $c): bool => !$c['ok']));
    $ok = $failed === [];
    $elapsed = (microtime(true) - $step['t']) * 1000;
    $statusList = implode(',', array_map(
        static fn(array $h): string => $h['method'] === 'CLI'
            ? 'cli:' . $h['status']
            : (string)$h['status'],
        $step['http']
    ));

    $index = count($results) + 1;
    printf(
        "[%02d] %-4s %s  [HTTP %s | %.1f ms]\n",
        $index,
        $ok ? 'PASS' : 'FAIL',
        $name,
        $statusList === '' ? '-' : $statusList,
        $elapsed
    );
    foreach ($failed as $failure) {
        $suffix = $failure['extra'] === '' ? '' : ' — ' . $failure['extra'];
        printf("       × %s%s\n", $failure['label'], $suffix);
    }

    $results[] = [
        'name' => $name,
        'ok' => $ok,
        'ms' => $elapsed,
        'http' => $step['http'],
        'checks' => $step['checks'],
    ];
    return $ok;
}

function print_summary(): int
{
    global $results, $suiteStarted;

    $passed = count(array_filter($results, static fn(array $r): bool => $r['ok']));
    $failed = count($results) - $passed;
    $elapsed = microtime(true) - $suiteStarted;

    echo "\n";
    if ($failed > 0) {
        echo "失败步骤：\n";
        foreach ($results as $item) {
            if (!$item['ok']) {
                echo '  - ' . $item['name'] . "\n";
            }
        }
        echo "\n";
    }
    printf("结果：通过 %d / %d，失败 %d，总耗时 %.2f s\n", $passed, count($results), $failed, $elapsed);
    return $failed === 0 ? 0 : 1;
}

function bail(string $reason): never
{
    fwrite(STDERR, "\n中止：{$reason}\n");
    if (is_file($GLOBALS['SERVER_LOG'])) {
        fwrite(STDERR, "服务器日志尾部：\n" . server_log_tail() . "\n");
    }
    stop_server();
    $code = print_summary();
    exit($code === 0 ? 1 : $code);
}

// ---------------------------------------------------------------------------
// 环境检查
// ---------------------------------------------------------------------------

if (!is_file($CONFIG)) {
    fwrite(STDERR, "缺少配置：{$CONFIG}\n");
    exit(2);
}
if (!is_file($ROUTER)) {
    fwrite(STDERR, "缺少路由：{$ROUTER}\n");
    exit(2);
}
if (is_port_open(API_HOST, API_PORT)) {
    fwrite(STDERR, '端口 ' . API_PORT . " 已被占用；本测试不会杀未知进程，请先确认并释放。\n");
    exit(2);
}

$previousConfig = getenv('SLICE_CONFIG');
putenv('SLICE_CONFIG=' . $CONFIG);

try {
    // -----------------------------------------------------------------------
    // 1. 重置隔离库
    // -----------------------------------------------------------------------
    $step = begin_step();
    if ($skipSetup) {
        expect($step, '按 --skip-setup 跳过数据库重置', true);
    } else {
        foreach (['scripts/setup_test_db.php', 'scripts/setup_map12_db.php'] as $script) {
            $run = run_php_script($script);
            $step['http'][] = [
                'method' => 'CLI',
                'path' => $script,
                'status' => $run['exit'],
                'ms' => round($run['ms'], 1),
            ];
            $detail = trim($run['out'] . ($run['err'] !== '' ? "\n" . $run['err'] : ''));
            expect($step, basename($script) . ' 退出码 0', $run['exit'] === 0, $detail);
        }
    }
    $setupOk = finish_step('重置 test_api（setup_test_db + setup_map12_db）', $step);
    if (!$setupOk && !$skipSetup) {
        bail('数据库初始化失败；先确认 test_api 已创建并授权给 qingzhu_test。');
    }

    // -----------------------------------------------------------------------
    // 2. 启动 8099 并等待健康检查
    // -----------------------------------------------------------------------
    $serverProc = start_server();
    if (!is_resource($serverProc)) {
        fwrite(STDERR, "无法启动 127.0.0.1:" . API_PORT . "（端口占用或 proc_open 失败）。\n");
        exit(2);
    }

    $step = begin_step();
    $health = null;
    $deadline = microtime(true) + 20.0;
    while (microtime(true) < $deadline) {
        if (!proc_running($serverProc)) {
            break;
        }
        $probe = api('GET', '/api/health');
        if ($probe['status'] === 200) {
            $health = $probe;
            break;
        }
        usleep(150000);
    }
    $step['http'][] = [
        'method' => 'GET',
        'path' => '/api/health',
        'status' => $health['status'] ?? 0,
        'ms' => round($health['ms'] ?? 0.0, 1),
    ];
    expect($step, '内置服务器已启动（8099）', $health !== null, '启动超时或进程退出');
    if ($health !== null) {
        expect($step, 'health.ok = true', ($health['json']['data']['ok'] ?? false) === true);
        expect($step, '健康检查能读到 seed 库（games >= 2）', (int)($health['json']['data']['games'] ?? 0) >= 2);
    }
    $healthOk = finish_step('启动 127.0.0.1:8099 并做健康检查', $step);
    if (!$healthOk || $health === null) {
        bail('服务器未能就绪。日志尾部：' . server_log_tail());
    }

    // -----------------------------------------------------------------------
    // 3. 学生登录
    // -----------------------------------------------------------------------
    $step = begin_step();
    $login = call_api($step, 'POST', '/api/auth/login', [
        'name' => STUDENT_NAME,
        'password' => STUDENT_PASSWORD,
        'game_code' => GAME_CODE,
    ]);
    $studentToken = null;
    $loginData = is_array($login['json']['data'] ?? null) ? $login['json']['data'] : [];
    expect($step, 'HTTP 200', $login['status'] === 200, '实际 ' . $login['status'] . ' / ' . error_code($login));
    expect($step, 'ok = true', ($login['json']['ok'] ?? false) === true);
    expect($step, '签发 token', is_string($loginData['token'] ?? null) && $loginData['token'] !== '');
    expect($step, 'role = player', ($loginData['player']['role'] ?? '') === 'player');
    expect($step, '昵称 = 青竹一', ($loginData['player']['nickname'] ?? '') === STUDENT_NAME);
    if (is_string($loginData['token'] ?? null) && $loginData['token'] !== '') {
        $studentToken = $loginData['token'];
    }
    finish_step('学生登录（青竹一 / MAP12_TEST）', $step);
    if ($studentToken === null) {
        bail('学生登录失败，无法继续。');
    }

    // -----------------------------------------------------------------------
    // 4. 学生 state：13 城 / 可达 / 邸报 / 军功 / 小院
    // -----------------------------------------------------------------------
    $step = begin_step();
    $state = call_api($step, 'GET', '/api/slice/state', null, $studentToken);
    $stateData = is_array($state['json']['data'] ?? null) ? $state['json']['data'] : [];
    $nodes = is_array($stateData['map']['nodes'] ?? null) ? $stateData['map']['nodes'] : [];
    $edges = is_array($stateData['map']['edges'] ?? null) ? $stateData['map']['edges'] : [];
    $reachable = is_array($stateData['reachable_targets'] ?? null) ? $stateData['reachable_targets'] : [];
    $bulletinOptions = is_array($stateData['bulletin']['options'] ?? null) ? $stateData['bulletin']['options'] : [];
    $estateRooms = is_array($stateData['estate']['rooms'] ?? null) ? $stateData['estate']['rooms'] : [];
    $handStateCards = is_array($stateData['hand']['cards'] ?? null) ? $stateData['hand']['cards'] : [];
    $turnId = (int)($stateData['turn']['id'] ?? 0);

    expect($step, 'HTTP 200', $state['status'] === 200, '实际 ' . $state['status'] . ' / ' . error_code($state));
    expect($step, '游戏为 MAP12_TEST', ($stateData['game']['code'] ?? '') === GAME_CODE);
    expect($step, '地图 13 城', count($nodes) === 13, '实际 ' . count($nodes));
    expect($step, '邻接 19 条', count($edges) === 19, '实际 ' . count($edges));
    expect($step, '可达目标含汉中/太原', in_array('hanzhong', $reachable, true) && in_array('taiyuan', $reachable, true), implode(',', $reachable));
    expect($step, '邸报 2 选 1', count($bulletinOptions) === 2, '实际 ' . count($bulletinOptions));
    expect($step, '军功初始 total = 0', (int)($stateData['merit']['total'] ?? -1) === 0);
    expect($step, '小院 3 个房间', count($estateRooms) === 3, '实际 ' . count($estateRooms));
    expect($step, '小院位于凉州', ($stateData['estate']['home_node']['code'] ?? '') === 'liangzhou');
    expect($step, '手牌 4 张', count($handStateCards) === 4, '实际 ' . count($handStateCards));
    $seedGameStatus = (string)($stateData['game']['status'] ?? '');
    $seedCanEdit = $stateData['can_edit'] ?? null;
    $seedBlockReason = $stateData['edit_block_reason'] ?? 'missing';
    expect($step, '游戏状态为 paused/running', in_array($seedGameStatus, ['paused', 'running'], true), 'status=' . $seedGameStatus);
    if ($seedGameStatus === 'paused') {
        expect(
            $step,
            '暂停时 can_edit=false / GAME_PAUSED',
            $seedCanEdit === false && $seedBlockReason === 'GAME_PAUSED',
            'can_edit=' . var_export($seedCanEdit, true) . ', reason=' . var_export($seedBlockReason, true)
        );
    } else {
        expect(
            $step,
            '运行时 can_edit=true',
            $seedCanEdit === true,
            'can_edit=' . var_export($seedCanEdit, true)
        );
    }
    expect($step, '拿到 turn_id', $turnId > 0, 'turn_id=' . $turnId);
    if (count($bulletinOptions) > 0) {
        $bulletinChoice = (string)($bulletinOptions[0]['code'] ?? '');
    }
    finish_step('GET state（13 城 / reachable / bulletin / merit / estate）', $step);
    if ($turnId <= 0) {
        bail('state 未返回 turn_id。');
    }

    // -----------------------------------------------------------------------
    // 5. 教师登录
    // -----------------------------------------------------------------------
    $step = begin_step();
    $adminLogin = call_api($step, 'POST', '/api/auth/admin-login', [
        'username' => TEACHER_NAME,
        'password' => TEACHER_PASSWORD,
        'game_code' => GAME_CODE,
    ]);
    $adminData = is_array($adminLogin['json']['data'] ?? null) ? $adminLogin['json']['data'] : [];
    $teacherToken = null;
    expect($step, 'HTTP 200', $adminLogin['status'] === 200, '实际 ' . $adminLogin['status'] . ' / ' . error_code($adminLogin));
    expect($step, 'role = teacher', ($adminData['player']['role'] ?? '') === 'teacher');
    expect($step, '管理员账号 = teacher', ($adminData['player']['admin']['username'] ?? '') === TEACHER_NAME);
    expect($step, '签发教师 token', is_string($adminData['token'] ?? null) && $adminData['token'] !== '');
    if (is_string($adminData['token'] ?? null) && $adminData['token'] !== '') {
        $teacherToken = $adminData['token'];
    }
    finish_step('教师 admin-login（teacher）', $step);
    if ($teacherToken === null) {
        bail('教师登录失败，无法继续。');
    }

    // -----------------------------------------------------------------------
    // 6. 恢复 running（seed 默认 paused，否则无法出令）
    // -----------------------------------------------------------------------
    $step = begin_step();
    $resume = call_api($step, 'POST', '/api/slice/admin/resume', [], $teacherToken);
    expect($step, 'HTTP 200', $resume['status'] === 200, '实际 ' . $resume['status'] . ' / ' . error_code($resume));
    expect($step, '游戏状态 = running', ($resume['json']['data']['status'] ?? '') === 'running');
    $resumeOk = finish_step('POST admin/resume（确保 running）', $step);
    if (!$resumeOk) {
        bail('无法恢复 running，后续出令会被 GAME_PAUSED 拦截。');
    }

    // -----------------------------------------------------------------------
    // 7. state 复核：可编辑
    // -----------------------------------------------------------------------
    $step = begin_step();
    $state2 = call_api($step, 'GET', '/api/slice/state?turn_id=' . $turnId, null, $studentToken);
    $state2Data = is_array($state2['json']['data'] ?? null) ? $state2['json']['data'] : [];
    expect($step, 'HTTP 200', $state2['status'] === 200, '实际 ' . $state2['status']);
    expect($step, 'game.status = running', ($state2Data['game']['status'] ?? '') === 'running');
    expect($step, 'turn.status = open', ($state2Data['turn']['status'] ?? '') === 'open');
    expect($step, 'can_edit = true', ($state2Data['can_edit'] ?? false) === true);
    expect(
        $step,
        'edit_block_reason = null',
        array_key_exists('edit_block_reason', $state2Data) && $state2Data['edit_block_reason'] === null,
        '实际 ' . var_export($state2Data['edit_block_reason'] ?? 'missing', true)
    );
    finish_step('GET state 复核（can_edit=true）', $step);

    // -----------------------------------------------------------------------
    // 8. GET hand
    // -----------------------------------------------------------------------
    $step = begin_step();
    $hand = call_api($step, 'GET', '/api/slice/hand?turn_id=' . $turnId, null, $studentToken);
    $handData = is_array($hand['json']['data'] ?? null) ? $hand['json']['data'] : [];
    $handCards = is_array($handData['hand']['cards'] ?? null) ? $handData['hand']['cards'] : [];
    $orders = is_array($handData['orders'] ?? null) ? $handData['orders'] : [];
    expect($step, 'HTTP 200', $hand['status'] === 200, '实际 ' . $hand['status'] . ' / ' . error_code($hand));
    expect($step, 'turn_id 对齐', (int)($handData['turn_id'] ?? 0) === $turnId);
    expect($step, '手牌 4 张', count($handCards) === 4, '实际 ' . count($handCards));
    expect($step, '4 张互不重复', count(array_unique($handCards)) === count($handCards));
    expect($step, '编成 changes_allowed >= 1', (int)($handData['composition']['changes_allowed'] ?? 0) >= 1);
    expect($step, '本回合尚无令', $orders === [], '实际 ' . count($orders) . ' 条');
    finish_step('GET hand（4 张 / changes_allowed / orders 空）', $step);
    if (count($handCards) !== 4) {
        bail('手牌异常，无法继续出 3 令。');
    }

    // -----------------------------------------------------------------------
    // 9. POST composition
    // -----------------------------------------------------------------------
    $step = begin_step();
    $compositionTypes = ['cav', 'shield', 'arc'];
    $composition = call_api($step, 'POST', '/api/slice/composition', [
        'week_no' => 1,
        'types' => $compositionTypes,
    ], $studentToken);
    $compositionData = is_array($composition['json']['data'] ?? null) ? $composition['json']['data'] : [];
    expect($step, 'HTTP 200', $composition['status'] === 200, '实际 ' . $composition['status'] . ' / ' . error_code($composition));
    expect($step, '编成落库 = cav/shield/arc', ($compositionData['types'] ?? []) === $compositionTypes, implode(',', $compositionData['types'] ?? []));
    expect($step, '返回 changes_allowed', isset($compositionData['changes_allowed']), 'changes_allowed=' . ($compositionData['changes_allowed'] ?? 'missing'));
    expect($step, 'changes_allowed >= 1', (int)($compositionData['changes_allowed'] ?? 0) >= 1);
    finish_step('POST composition（changes_allowed）', $step);

    // -----------------------------------------------------------------------
    // 10. POST hand/redraw
    // -----------------------------------------------------------------------
    $step = begin_step();
    $redraw = call_api($step, 'POST', '/api/slice/hand/redraw', ['turn_id' => $turnId], $studentToken);
    $redrawData = is_array($redraw['json']['data'] ?? null) ? $redraw['json']['data'] : [];
    $redrawnCards = is_array($redrawData['cards'] ?? null) ? $redrawData['cards'] : [];
    expect($step, 'HTTP 200', $redraw['status'] === 200, '实际 ' . $redraw['status'] . ' / ' . error_code($redraw));
    expect($step, 'redraw_used = true', ($redrawData['redraw_used'] ?? false) === true);
    expect($step, '重抽后仍 4 张', count($redrawnCards) === 4, '实际 ' . count($redrawnCards));
    if (count($redrawnCards) === 4) {
        $handCards = array_values($redrawnCards);
    }
    finish_step('POST hand/redraw（redraw_used）', $step);

    // -----------------------------------------------------------------------
    // 11. POST bulletin 选一个
    // -----------------------------------------------------------------------
    $bulletinChoice = '';
    $step = begin_step();
    $bulletinGet = call_api($step, 'GET', '/api/slice/bulletin?turn_id=' . $turnId, null, $studentToken);
    $bulletinGetData = is_array($bulletinGet['json']['data'] ?? null) ? $bulletinGet['json']['data'] : [];
    $liveOptions = is_array($bulletinGetData['options'] ?? null) ? $bulletinGetData['options'] : [];
    if (count($liveOptions) > 0) {
        $bulletinChoice = (string)($liveOptions[0]['code'] ?? '');
    }
    expect($step, 'GET bulletin 200', $bulletinGet['status'] === 200, '实际 ' . $bulletinGet['status']);
    expect($step, '邸报有 2 个选项', count($liveOptions) === 2, '实际 ' . count($liveOptions));
    expect($step, '能确定选项 code', $bulletinChoice !== '', 'choice=' . $bulletinChoice);
    if ($bulletinChoice !== '') {
        $bulletin = call_api($step, 'POST', '/api/slice/bulletin', [
            'turn_id' => $turnId,
            'choice' => $bulletinChoice,
        ], $studentToken);
        $bulletinData = is_array($bulletin['json']['data'] ?? null) ? $bulletin['json']['data'] : [];
        expect($step, 'POST bulletin 200', $bulletin['status'] === 200, '实际 ' . $bulletin['status'] . ' / ' . error_code($bulletin));
        expect($step, 'choice 已记录', ($bulletinData['choice'] ?? '') === $bulletinChoice);
    }
    finish_step('POST bulletin（选择 ' . $bulletinChoice . '）', $step);

    // -----------------------------------------------------------------------
    // 12. POST order/play × 3
    // -----------------------------------------------------------------------
    $step = begin_step();
    // 队伍牌优先，保证 forecast 至少有一支先锋队（火攻/哨探/疑兵不占队伍位）。
    $teamCards = [
        'night_raid', 'forced_march', 'fortify', 'mutual_support', 'empty_fort',
        'last_stand', 'counter_intel', 'supply', 'cut_supply',
    ];
    $orderedCards = [];
    foreach ($handCards as $card) {
        if (in_array($card, $teamCards, true)) {
            $orderedCards[] = $card;
        }
    }
    foreach ($handCards as $card) {
        if (!in_array($card, $teamCards, true)) {
            $orderedCards[] = $card;
        }
    }
    $playCards = array_slice($orderedCards, 0, 3);
    $targetNode = 'hanzhong';
    $playFailures = 0;

    foreach ($playCards as $slot => $card) {
        $play = call_api($step, 'POST', '/api/slice/order/play', [
            'turn_id' => $turnId,
            'slot' => $slot,
            'card_code' => $card,
            'target_node_code' => $targetNode,
            'lane' => $slot + 1,
            'row_pos' => $slot === 2 ? 'back' : 'front',
            'request_key' => 'http-' . bin2hex(random_bytes(6)),
        ], $studentToken);
        $playData = is_array($play['json']['data'] ?? null) ? $play['json']['data'] : [];
        $ok = $play['status'] === 200 && (int)($playData['slot'] ?? -1) === $slot;
        if (!$ok) {
            $playFailures++;
        }
        expect(
            $step,
            '第 ' . ($slot + 1) . ' 令（' . $card . '）落位',
            $ok,
            'status=' . $play['status'] . ', code=' . error_code($play)
        );
        expect(
            $step,
            '第 ' . ($slot + 1) . ' 令目标 = 汉中',
            ($playData['target_node_code'] ?? '') === $targetNode,
            '实际 ' . ($playData['target_node_code'] ?? '-')
        );
    }

    $handAfter = call_api($step, 'GET', '/api/slice/hand?turn_id=' . $turnId, null, $studentToken);
    $handAfterData = is_array($handAfter['json']['data'] ?? null) ? $handAfter['json']['data'] : [];
    $ordersAfter = is_array($handAfterData['orders'] ?? null) ? $handAfterData['orders'] : [];
    expect($step, '3 条令都在手牌接口可见', count($ordersAfter) === 3, '实际 ' . count($ordersAfter));
    expect($step, '3 条令均指向汉中', count(array_filter(
        $ordersAfter,
        static fn(array $o): bool => ($o['target_node_code'] ?? '') === $targetNode
    )) === 3);
    finish_step('POST order/play × 3（目标汉中）', $step);
    if ($playFailures > 0) {
        bail('出令失败，无法继续结算流程。');
    }

    // -----------------------------------------------------------------------
    // 13. POST battle/forecast
    // -----------------------------------------------------------------------
    $step = begin_step();
    $forecast = call_api($step, 'POST', '/api/slice/battle/forecast', [
        'turn_id' => $turnId,
        'node' => $targetNode,
    ], $studentToken);
    $forecastData = is_array($forecast['json']['data'] ?? null) ? $forecast['json']['data'] : [];
    $advice = is_array($forecastData['advice'] ?? null) ? $forecastData['advice'] : [];
    $teams = is_array($forecastData['attacker']['teams'] ?? null) ? $forecastData['attacker']['teams'] : [];
    expect($step, 'HTTP 200', $forecast['status'] === 200, '实际 ' . $forecast['status'] . ' / ' . error_code($forecast));
    expect($step, 'ready = true', ($forecastData['ready'] ?? false) === true, 'reason=' . ($forecastData['reason'] ?? '-'));
    expect($step, 'role = attack', ($forecastData['role'] ?? '') === 'attack');
    expect($step, 'advice 非空', $advice !== [], '实际 ' . count($advice) . ' 条');
    expect($step, '攻方至少 1 队', count($teams) >= 1, '实际 ' . count($teams));
    expect($step, 'forecast.verdict 有值', (string)($forecastData['forecast']['verdict'] ?? '') !== '');
    finish_step('POST battle/forecast（ready=true / advice）', $step);

    // -----------------------------------------------------------------------
    // 14. POST admin/card-settle
    // -----------------------------------------------------------------------
    $step = begin_step();
    $settle = call_api($step, 'POST', '/api/slice/admin/card-settle', ['turn_id' => $turnId], $teacherToken);
    $settleData = is_array($settle['json']['data'] ?? null) ? $settle['json']['data'] : [];
    $battles = is_array($settleData['battles'] ?? null) ? $settleData['battles'] : [];
    $battleId = 0;
    $targetBattle = null;
    foreach ($battles as $battle) {
        if (($battle['node_code'] ?? '') === $targetNode) {
            $targetBattle = $battle;
            $battleId = (int)($battle['battle_id'] ?? 0);
            break;
        }
    }
    expect($step, 'HTTP 200', $settle['status'] === 200, '实际 ' . $settle['status'] . ' / ' . error_code($settle));
    expect($step, 'not already_settled', ($settleData['already_settled'] ?? true) === false);
    expect($step, '至少 1 场战斗', count($battles) >= 1, '实际 ' . count($battles));
    expect($step, '汉中产生战斗', $targetBattle !== null && $battleId > 0, 'battle_id=' . $battleId);
    finish_step('POST admin/card-settle（教师）', $step);
    if ($battleId <= 0) {
        bail('结算未产生汉中战斗，后续战报断言无意义。');
    }

    // -----------------------------------------------------------------------
    // 15. GET me/report
    // -----------------------------------------------------------------------
    $step = begin_step();
    $myReport = call_api($step, 'GET', '/api/slice/me/report?turn_id=' . $turnId, null, $studentToken);
    $myReportData = is_array($myReport['json']['data'] ?? null) ? $myReport['json']['data'] : [];
    $myOrders = is_array($myReportData['orders'] ?? null) ? $myReportData['orders'] : [];
    $myMerit = is_array($myReportData['merit'] ?? null) ? $myReportData['merit'] : [];
    expect($step, 'HTTP 200', $myReport['status'] === 200, '实际 ' . $myReport['status'] . ' / ' . error_code($myReport));
    expect($step, 'orders 3 条', count($myOrders) === 3, '实际 ' . count($myOrders));
    expect($step, 'merit.turn_total >= 5', (int)($myMerit['turn_total'] ?? 0) >= 5, '实际 ' . ($myMerit['turn_total'] ?? 0));
    expect($step, 'highlight 非空', is_string($myReportData['highlight'] ?? null) && $myReportData['highlight'] !== '');
    expect($step, 'battles_joined >= 1', (int)($myReportData['battles_joined'] ?? 0) >= 1, '实际 ' . ($myReportData['battles_joined'] ?? 0));
    expect($step, 'turn_no = 1', (int)($myReportData['turn_no'] ?? 0) === 1);
    finish_step('GET me/report（orders / merit / highlight）', $step);

    // -----------------------------------------------------------------------
    // 16. GET report
    // -----------------------------------------------------------------------
    $step = begin_step();
    $report = call_api($step, 'GET', '/api/slice/report?turn_id=' . $turnId, null, $studentToken);
    $reportData = is_array($report['json']['data'] ?? null) ? $report['json']['data'] : [];
    $resultBattles = is_array($reportData['report']['battles'] ?? null) ? $reportData['report']['battles'] : [];
    $reportMerit = is_array($reportData['me']['merit'] ?? null) ? $reportData['me']['merit'] : [];
    expect($step, 'HTTP 200', $report['status'] === 200, '实际 ' . $report['status'] . ' / ' . error_code($report));
    expect($step, 'turn.status = settled', ($reportData['turn']['status'] ?? '') === 'settled');
    expect($step, 'report.mode = cards', ($reportData['report']['mode'] ?? '') === 'cards');
    expect($step, '卡牌战报有 battles', count($resultBattles) >= 1, '实际 ' . count($resultBattles));
    expect($step, 'report.me.merit.turn_total >= 5', (int)($reportMerit['turn_total'] ?? 0) >= 5);
    finish_step('GET report（卡牌战报）', $step);

    // -----------------------------------------------------------------------
    // 17. GET replay
    // -----------------------------------------------------------------------
    $step = begin_step();
    $replay = call_api($step, 'GET', '/api/slice/replay', null, $studentToken);
    $replayData = is_array($replay['json']['data'] ?? null) ? $replay['json']['data'] : [];
    $replayTurns = is_array($replayData['turns'] ?? null) ? $replayData['turns'] : [];
    $firstReplayTurn = $replayTurns[0] ?? null;
    $changes = is_array($firstReplayTurn['changes'] ?? null) ? $firstReplayTurn['changes'] : [];
    $changeNodes = array_map(
        static fn(array $c): string => (string)($c['node_code'] ?? ''),
        $changes
    );
    expect($step, 'HTTP 200', $replay['status'] === 200, '实际 ' . $replay['status'] . ' / ' . error_code($replay));
    expect($step, 'replay 有已结算回合', count($replayTurns) >= 1, '实际 ' . count($replayTurns));
    expect($step, 'changes 非空', $changes !== [], '实际 ' . count($changes));
    expect($step, 'changes 含汉中', in_array($targetNode, $changeNodes, true), implode(',', $changeNodes));
    expect($step, 'change 带 changed 字段', $changes !== [] && array_key_exists('changed', $changes[0]));
    finish_step('GET replay（卡牌战报 changes）', $step);

    // -----------------------------------------------------------------------
    // 18. GET estate
    // -----------------------------------------------------------------------
    $step = begin_step();
    $estate = call_api($step, 'GET', '/api/slice/estate?turn_id=' . $turnId, null, $studentToken);
    $estateData = is_array($estate['json']['data'] ?? null) ? $estate['json']['data'] : [];
    $estateRoomList = is_array($estateData['rooms'] ?? null) ? $estateData['rooms'] : [];
    $studyRoom = null;
    foreach ($estateRoomList as $room) {
        if (($room['code'] ?? '') === 'study') {
            $studyRoom = $room;
            break;
        }
    }
    expect($step, 'HTTP 200', $estate['status'] === 200, '实际 ' . $estate['status'] . ' / ' . error_code($estate));
    expect($step, '3 个房间', count($estateRoomList) === 3, '实际 ' . count($estateRoomList));
    expect($step, 'home = 凉州', ($estateData['home_node']['code'] ?? '') === 'liangzhou');
    expect(
        $step,
        'merit_balance = total - spent',
        (int)($estateData['merit_balance'] ?? -1) === (int)($estateData['merit_total'] ?? 0) - (int)($estateData['merit_spent'] ?? 0)
    );
    expect($step, '书房 next_cost = 30', (int)($studyRoom['next_cost'] ?? 0) === 30);
    finish_step('GET estate（军功余额 / 房间）', $step);

    // -----------------------------------------------------------------------
    // 19. POST estate/upgrade（200 或 409 都是正确分支）
    // -----------------------------------------------------------------------
    $step = begin_step();
    $upgrade = call_api($step, 'POST', '/api/slice/estate/upgrade', ['room' => 'study'], $studentToken);
    if ($upgrade['status'] === 200) {
        $upgradeData = is_array($upgrade['json']['data'] ?? null) ? $upgrade['json']['data'] : [];
        $upgradedStudy = null;
        foreach ((array)($upgradeData['rooms'] ?? []) as $room) {
            if (($room['code'] ?? '') === 'study') {
                $upgradedStudy = $room;
                break;
            }
        }
        expect($step, '走 200 升级分支', true);
        expect($step, 'upgraded.room = study', ($upgradeData['upgraded']['room'] ?? '') === 'study');
        expect($step, '书房升到 2 级', (int)($upgradedStudy['level'] ?? 0) === 2, '实际 ' . ($upgradedStudy['level'] ?? 0));
        expect($step, 'merit_spent >= 30', (int)($upgradeData['merit_spent'] ?? 0) >= 30);
    } else {
        expect($step, '走 409 余额不足分支', $upgrade['status'] === 409, '实际 ' . $upgrade['status']);
        expect($step, 'error.code = ESTATE_INSUFFICIENT_MERIT', error_code($upgrade) === 'ESTATE_INSUFFICIENT_MERIT', error_code($upgrade));
        expect($step, 'details.cost = 30', (int)error_detail($upgrade, 'cost') === 30);
        expect($step, 'details.gap > 0', (int)error_detail($upgrade, 'gap') > 0);
    }
    finish_step('POST estate/upgrade（200 或 409 均算通过）', $step);

    // -----------------------------------------------------------------------
    // 20. GET season
    // -----------------------------------------------------------------------
    $step = begin_step();
    $season = call_api($step, 'GET', '/api/slice/season', null, $studentToken);
    $seasonData = is_array($season['json']['data'] ?? null) ? $season['json']['data'] : [];
    $seasonFactions = is_array($seasonData['factions'] ?? null) ? $seasonData['factions'] : [];
    expect($step, 'HTTP 200', $season['status'] === 200, '实际 ' . $season['status'] . ' / ' . error_code($season));
    expect($step, 'game = MAP12_TEST', ($seasonData['game'] ?? '') === GAME_CODE);
    expect($step, 'week = 1', (int)($seasonData['week'] ?? 0) === 1);
    expect($step, '4 个阵营', count($seasonFactions) === 4, '实际 ' . count($seasonFactions));
    expect($step, '长安节点存在', ($seasonData['changan']['node_code'] ?? '') === 'changan');
    expect($step, 'season_over = false', ($seasonData['season_over'] ?? true) === false);
    $seasonCitySum = (int)($seasonData['neutral_cities'] ?? 0);
    foreach ($seasonFactions as $faction) {
        $seasonCitySum += (int)($faction['cities'] ?? 0);
    }
    expect($step, '阵营 + 中立城数 = 13', $seasonCitySum === 13, '实际 ' . $seasonCitySum);
    finish_step('GET season（4 阵营 / 长安 / 周次）', $step);

    // -----------------------------------------------------------------------
    // 21. GET season/history
    // -----------------------------------------------------------------------
    $step = begin_step();
    $history = call_api($step, 'GET', '/api/slice/season/history', null, $studentToken);
    $historyData = is_array($history['json']['data'] ?? null) ? $history['json']['data'] : [];
    $weeks = is_array($historyData['weeks'] ?? null) ? $historyData['weeks'] : [];
    $week1 = $weeks[0] ?? null;
    expect($step, 'HTTP 200', $history['status'] === 200, '实际 ' . $history['status'] . ' / ' . error_code($history));
    expect($step, 'game = MAP12_TEST', ($historyData['game'] ?? '') === GAME_CODE);
    expect($step, 'current_week = 1', (int)($historyData['current_week'] ?? 0) === 1);
    expect($step, '有第 1 周条目', $week1 !== null && (int)($week1['week'] ?? 0) === 1);
    expect($step, '第 1 周 battle >= 1', (int)($week1['battles'] ?? 0) >= 1, '实际 ' . ($week1['battles'] ?? 0));
    expect($step, '第 1 周 standings 5 行', count((array)($week1['standings'] ?? [])) === 5);
    finish_step('GET season/history（第 1 周）', $step);

    // -----------------------------------------------------------------------
    // 22. 负例：结算后 order/play → TURN_NOT_OPEN
    // -----------------------------------------------------------------------
    $step = begin_step();
    $latePlay = call_api($step, 'POST', '/api/slice/order/play', [
        'turn_id' => $turnId,
        'slot' => 0,
        'card_code' => 'night_raid',
        'target_node_code' => $targetNode,
        'lane' => 1,
        'row_pos' => 'front',
        'request_key' => 'http-late-' . bin2hex(random_bytes(5)),
    ], $studentToken);
    expect($step, 'HTTP 409', $latePlay['status'] === 409, '实际 ' . $latePlay['status']);
    expect($step, 'error.code = TURN_NOT_OPEN', error_code($latePlay) === 'TURN_NOT_OPEN', error_code($latePlay));
    expect($step, 'details.turn_status = settled', error_detail($latePlay, 'turn_status') === 'settled');
    finish_step('负例：结算后 order/play → TURN_NOT_OPEN', $step);

    // -----------------------------------------------------------------------
    // 23. 负例：学生调 battle/settle → 403
    // -----------------------------------------------------------------------
    $step = begin_step();
    $studentSettle = call_api($step, 'POST', '/api/slice/battle/settle', [
        'battle_id' => $battleId,
    ], $studentToken);
    expect($step, 'HTTP 403', $studentSettle['status'] === 403, '实际 ' . $studentSettle['status']);
    expect($step, 'error.code = FORBIDDEN', error_code($studentSettle) === 'FORBIDDEN', error_code($studentSettle));
    finish_step('负例：学生调 battle/settle → 403', $step);

    // -----------------------------------------------------------------------
    // 收尾
    // -----------------------------------------------------------------------
    stop_server();
    $released = false;
    for ($i = 0; $i < 50; $i++) {
        if (!is_port_open(API_HOST, API_PORT)) {
            $released = true;
            break;
        }
        usleep(100000);
    }
    echo $released
        ? "服务已停止，" . API_PORT . " 已释放。\n"
        : "警告：" . API_PORT . " 仍被占用，" . "请手动检查。\n";

    exit(print_summary());
} finally {
    stop_server();
    if ($previousConfig === false) {
        putenv('SLICE_CONFIG');
    } else {
        putenv('SLICE_CONFIG=' . $previousConfig);
    }
}
