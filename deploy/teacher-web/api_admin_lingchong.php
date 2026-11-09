<?php
/**
 * 教师控制台同源代理。
 * 放置到现有系统：api/admin/lingchong.php
 *
 * 浏览器不接触游戏 API 的教师 Token；服务账号从环境变量读取。
 */
require_once __DIR__ . '/../../common.php';
require_once __DIR__ . '/../../auth.php';

Auth::checkAdmin();
header('Content-Type: application/json; charset=utf-8');

function lc_json(int $status, array $payload): never
{
    http_response_code($status);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function lc_same_origin(): bool
{
    $origin = $_SERVER['HTTP_ORIGIN'] ?? '';
    $host = $_SERVER['HTTP_HOST'] ?? '';
    if ($origin === '' || $host === '') {
        return true; // 同源 fetch 可能不带 Origin；Auth::checkAdmin 仍是主防线
    }
    $originHost = parse_url($origin, PHP_URL_HOST);
    $hostOnly = explode(':', $host)[0];
    return $originHost !== false && strcasecmp($originHost, $hostOnly) === 0;
}

function lc_api(string $method, string $path, ?array $body, string $token = ''): array
{
    $base = rtrim(getenv('LINGCHONG_API_URL') ?: 'http://127.0.0.1:8090', '/');
    $url = $base . $path;
    $headers = ['Content-Type: application/json'];
    if ($token !== '') {
        $headers[] = 'Authorization: Bearer ' . $token;
    }

    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CUSTOMREQUEST => $method,
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_TIMEOUT => 20,
        CURLOPT_CONNECTTIMEOUT => 5,
    ]);
    if ($body !== null) {
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($body, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));
    }
    $raw = curl_exec($ch);
    $status = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $error = curl_error($ch);
    curl_close($ch);

    if ($raw === false) {
        return [0, ['ok' => false, 'error' => ['code' => 'PROXY_NETWORK', 'message' => $error ?: '游戏 API 不可达']]];
    }
    $decoded = json_decode((string)$raw, true);
    if (!is_array($decoded)) {
        return [$status, ['ok' => false, 'error' => ['code' => 'PROXY_BAD_JSON', 'message' => '游戏 API 返回格式错误']]];
    }
    return [$status, $decoded];
}

function lc_token(): string
{
    $cached = $_SESSION['lingchong_token'] ?? null;
    $expires = (int)($_SESSION['lingchong_token_expires'] ?? 0);
    if (is_string($cached) && $cached !== '' && $expires > time() + 30) {
        return $cached;
    }

    $user = (string)(getenv('LINGCHONG_ADMIN_USER') ?: '');
    $pass = (string)(getenv('LINGCHONG_ADMIN_PASS') ?: '');
    if ($user === '' || $pass === '') {
        throw new RuntimeException('未配置 LINGCHONG_ADMIN_USER / LINGCHONG_ADMIN_PASS');
    }

    [$status, $data] = lc_api('POST', '/api/auth/admin-login', [
        'username' => $user,
        'password' => $pass,
    ]);
    if ($status !== 200 || empty($data['ok']) || empty($data['data']['token'])) {
        throw new RuntimeException('服务教师登录失败');
    }

    $token = (string)$data['data']['token'];
    $expiresAt = strtotime((string)($data['data']['expires_at'] ?? '')) ?: (time() + 43200);
    $_SESSION['lingchong_token'] = $token;
    $_SESSION['lingchong_token_expires'] = $expiresAt;
    return $token;
}

if (!lc_same_origin()) {
    lc_json(403, ['ok' => false, 'error' => ['code' => 'CSRF_ORIGIN', 'message' => '来源不合法']]);
}

try {
    $action = (string)($_POST['action'] ?? $_GET['action'] ?? 'status');
    $turnId = (int)($_POST['turn_id'] ?? $_GET['turn_id'] ?? 0);
    $force = (bool)($_POST['force'] ?? false);

    $allowed = ['status', 'lock', 'settle', 'next-turn'];
    if (!in_array($action, $allowed, true)) {
        lc_json(400, ['ok' => false, 'error' => ['code' => 'BAD_ACTION', 'message' => '不支持的操作']]);
    }

    $token = lc_token();
    if ($action === 'status') {
        [$status, $data] = lc_api('GET', '/api/slice/admin/status', null, $token);
    } elseif ($action === 'lock') {
        [$status, $data] = lc_api('POST', '/api/slice/admin/lock', [
            'turn_id' => $turnId,
            'force' => $force,
        ], $token);
    } elseif ($action === 'settle') {
        [$status, $data] = lc_api('POST', '/api/slice/admin/settle', [
            'turn_id' => $turnId,
        ], $token);
    } else {
        [$status, $data] = lc_api('POST', '/api/slice/admin/next-turn', [
            'from_turn_id' => $turnId,
        ], $token);
    }

    if ($status === 401) {
        unset($_SESSION['lingchong_token'], $_SESSION['lingchong_token_expires']);
    }
    lc_json($status > 0 ? $status : 502, $data);
} catch (Throwable $e) {
    lc_json(500, ['ok' => false, 'error' => ['code' => 'PROXY_ERROR', 'message' => $e->getMessage()]]);
}
