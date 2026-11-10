<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/bootstrap.php';
require_once dirname(__DIR__) . '/src/HandService.php';
require_once dirname(__DIR__) . '/src/BattleService.php';
require_once dirname(__DIR__) . '/src/BattleSettlementService.php';
require_once dirname(__DIR__) . '/src/CardSettlementService.php';

$started = microtime(true);
$requestId = $_SERVER['HTTP_X_REQUEST_ID'] ?? bin2hex(random_bytes(6));
$method = strtoupper((string)($_SERVER['REQUEST_METHOD'] ?? 'GET'));
$path = (string)parse_url((string)($_SERVER['REQUEST_URI'] ?? '/'), PHP_URL_PATH);
$path = '/' . trim($path, '/');
if ($path === '/index.php') {
    $path = '/';
}

// 教师控制台：独立 Web 页面，学生 App 不提供教师登录。
if ($method === 'GET' && ($path === '/teacher' || $path === '/teacher.html')) {
    header('Content-Type: text/html; charset=utf-8');
    readfile(__DIR__ . '/teacher.html');
    exit;
}

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Auth-Token, X-Request-Id');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');

if ($method === 'OPTIONS') {
    http_response_code(204);
    exit;
}

function respond(int $status, array $payload): never
{
    http_response_code($status);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function success(mixed $data, int $status = 200, array $extra = []): never
{
    respond($status, array_merge([
        'ok' => true,
        'data' => $data,
        'server_time' => date('Y-m-d H:i:s'),
    ], $extra));
}

function failure(ApiException $e): never
{
    respond($e->httpStatus, [
        'ok' => false,
        'error' => [
            'code' => $e->errorCode,
            'message' => $e->getMessage(),
            'details' => $e->details,
        ],
        'server_time' => date('Y-m-d H:i:s'),
    ]);
}

function jsonBody(): array
{
    $raw = file_get_contents('php://input');
    if ($raw === false || trim($raw) === '') {
        return $_POST;
    }
    $data = json_decode($raw, true);
    if (!is_array($data)) {
        throw new ApiException('BAD_JSON', '请求体不是合法 JSON', 400);
    }
    return $data;
}

function bearerToken(): ?string
{
    $header = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (preg_match('/^\s*Bearer\s+(.+)\s*$/i', $header, $m)) {
        return trim($m[1]);
    }
    $alt = $_SERVER['HTTP_X_AUTH_TOKEN'] ?? '';
    return $alt !== '' ? trim($alt) : null;
}

function requireAuth(SliceService $service): array
{
    return $service->authenticate(bearerToken());
}

try {
    [, $pdo, $service] = slice_bootstrap();
} catch (Throwable $e) {
    slice_log('bootstrap.failed', ['error' => $e->getMessage()]);
    respond(500, [
        'ok' => false,
        'error' => ['code' => 'BOOTSTRAP_FAILED', 'message' => '服务启动失败', 'details' => []],
        'server_time' => date('Y-m-d H:i:s'),
    ]);
}

try {
    if ($method === 'GET' && $path === '/api/health') {
        success($service->health());
    }

    if ($method === 'POST' && $path === '/api/auth/login') {
        $body = jsonBody();
        success($service->loginStudent(
            (string)($body['name'] ?? $body['nickname'] ?? ''),
            (string)($body['password'] ?? ''),
            isset($body['game_code']) ? (string)$body['game_code'] : null
        ));
    }

    if ($method === 'POST' && $path === '/api/auth/admin-login') {
        $body = jsonBody();
        success($service->loginAdmin(
            (string)($body['username'] ?? ''),
            (string)($body['password'] ?? ''),
            isset($body['game_code']) ? (string)$body['game_code'] : null
        ));
    }

    if ($method === 'POST' && $path === '/api/auth/logout') {
        $player = requireAuth($service);
        success($service->logout($player, bearerToken()));
    }

    if ($method === 'GET' && $path === '/api/slice/state') {
        $player = requireAuth($service);
        $turnId = isset($_GET['turn_id']) ? (int)$_GET['turn_id'] : null;
        success($service->getState($player, $turnId));
    }

    if ($method === 'POST' && $path === '/api/slice/orders') {
        $player = requireAuth($service);
        success($service->submitOrder($player, jsonBody()), 200);
    }

    if ($method === 'POST' && $path === '/api/slice/orders/withdraw') {
        $player = requireAuth($service);
        success($service->withdrawOrder($player, jsonBody()), 200);
    }

    // ---- Phase 1：编成 / 手牌 / 3 张将令 / 战斗 ----

    if ($method === 'GET' && $path === '/api/slice/hand') {
        $player = requireAuth($service);
        $turnId = isset($_GET['turn_id']) ? (int)$_GET['turn_id'] : (int)($player['game_current_turn_id'] ?? 0);
        if ($turnId <= 0) {
            throw new ApiException('BAD_REQUEST', '缺少 turn_id');
        }
        $handService = new HandService($pdo);
        success([
            'turn_id' => $turnId,
            'hand' => $handService->getOrCreateHand((int)$player['game_id'], $turnId, (int)$player['id']),
            'composition' => $handService->getComposition((int)$player['game_id'], (int)$player['id'], 1),
            'orders' => $handService->getOrders($turnId, (int)$player['id']),
        ]);
    }

    if ($method === 'POST' && $path === '/api/slice/hand/redraw') {
        $player = requireAuth($service);
        $body = jsonBody();
        $turnId = isset($body['turn_id']) ? (int)$body['turn_id'] : (int)($player['game_current_turn_id'] ?? 0);
        if ($turnId <= 0) {
            throw new ApiException('BAD_REQUEST', '缺少 turn_id');
        }
        success((new HandService($pdo))->redraw((int)$player['game_id'], $turnId, (int)$player['id']));
    }

    if ($method === 'GET' && $path === '/api/slice/composition') {
        $player = requireAuth($service);
        $weekNo = (int)($_GET['week_no'] ?? 1);
        success((new HandService($pdo))->getComposition((int)$player['game_id'], (int)$player['id'], $weekNo));
    }

    if ($method === 'POST' && $path === '/api/slice/composition') {
        $player = requireAuth($service);
        $body = jsonBody();
        $weekNo = (int)($body['week_no'] ?? 1);
        success((new HandService($pdo))->setComposition(
            (int)$player['game_id'],
            (int)$player['id'],
            $weekNo,
            is_array($body['types'] ?? null) ? $body['types'] : []
        ));
    }

    if ($method === 'POST' && $path === '/api/slice/order/play') {
        $player = requireAuth($service);
        $body = jsonBody();
        $turnId = isset($body['turn_id']) ? (int)$body['turn_id'] : (int)($player['game_current_turn_id'] ?? 0);
        if ($turnId <= 0) {
            throw new ApiException('BAD_REQUEST', '缺少 turn_id');
        }
        success((new HandService($pdo))->play(
            (int)$player['game_id'],
            $turnId,
            (int)$player['id'],
            (int)($body['slot'] ?? 0),
            (string)($body['card_code'] ?? ''),
            (string)($body['target_node_code'] ?? ''),
            isset($body['lane']) ? (int)$body['lane'] : null,
            isset($body['row_pos']) ? (string)$body['row_pos'] : null,
            (string)($body['request_key'] ?? '')
        ));
    }

    if ($method === 'POST' && $path === '/api/slice/order/withdraw') {
        $player = requireAuth($service);
        $body = jsonBody();
        $turnId = isset($body['turn_id']) ? (int)$body['turn_id'] : (int)($player['game_current_turn_id'] ?? 0);
        if ($turnId <= 0) {
            throw new ApiException('BAD_REQUEST', '缺少 turn_id');
        }
        success(['withdrawn' => (new HandService($pdo))->withdraw($turnId, (int)$player['id'], (int)($body['slot'] ?? 0))]);
    }

    if ($method === 'POST' && $path === '/api/slice/battle/demo') {
        $player = requireAuth($service);
        $body = jsonBody();
        $turnId = isset($body['turn_id']) ? (int)$body['turn_id'] : (int)($player['game_current_turn_id'] ?? 0);
        if ($turnId <= 0) {
            throw new ApiException('BAD_REQUEST', '缺少 turn_id');
        }
        $stmt = $pdo->prepare(
            'SELECT sp.level, pt.base_hp, pt.base_atk, pt.base_def, pt.base_spd,
                    pt.growth_rate, pt.element, pt.code
             FROM slice_players p
             JOIN student_pets sp ON sp.student_id = p.student_id
             JOIN pet_templates pt ON pt.id = sp.pet_template_id
             WHERE p.id = ?'
        );
        $stmt->execute([(int)$player['id']]);
        $pet = $stmt->fetch();
        if (!$pet) {
            throw new ApiException('PET_NOT_FOUND', '没有班宠数据', 404);
        }
        $handService = new HandService($pdo);
        $composition = $handService->getComposition((int)$player['game_id'], (int)$player['id'], 1);
        $general = (string)$pet['code'] === 'pet_inkdrop_01' ? 'tac' : 'def';
        $attacker = [
            'general' => $general,
            'troops' => BattleService::petPower($pet) * 1.20,
            'composition' => $composition['types'],
            'fire' => (bool)($body['fire'] ?? false),
        ];
        $defender = [
            'general' => 'atk',
            'troops' => 1200.0 * 1.10,
            'composition' => ['shield', 'spear', 'arc'],
        ];
        $battleService = new BattleService(null, $pdo);
        $result = $battleService->resolve($attacker, $defender);
        $battleId = $battleService->saveBattle(
            (int)$player['game_id'],
            $turnId,
            (string)($body['node_code'] ?? 'hanzhong'),
            $player['faction_id'] !== null ? (int)$player['faction_id'] : null,
            null,
            $attacker,
            $defender,
            $result
        );
        success([
            'battle_id' => $battleId,
            'attacker' => $attacker,
            'defender' => $defender,
            'log' => array_merge($result, [
                'result' => [
                    'wall' => $result['wall'],
                    'score' => $result['score'],
                    'ticks' => $result['ticks'],
                    'headline' => BattleService::scoreLabel((int)$result['score']),
                ],
            ]),
        ]);
    }

    if ($method === 'GET' && $path === '/api/slice/battle') {
        $player = requireAuth($service);
        $battleId = (int)($_GET['id'] ?? 0);
        $battle = (new BattleService(null, $pdo))->getBattle($battleId);
        if ($battle === null || (int)$battle['game_id'] !== (int)$player['game_id']) {
            throw new ApiException('NOT_FOUND', '战斗不存在', 404);
        }
        success($battle);
    }

    if ($method === 'POST' && $path === '/api/slice/battle/settle') {
        $player = requireAuth($service);
        $body = jsonBody();
        $battleId = (int)($body['battle_id'] ?? 0);
        $battle = (new BattleService(null, $pdo))->getBattle($battleId);
        if ($battle === null || (int)$battle['game_id'] !== (int)$player['game_id']) {
            throw new ApiException('NOT_FOUND', '战斗不存在', 404);
        }
        success((new BattleSettlementService($pdo))->apply(
            (int)$player['game_id'],
            (int)$battle['turn_id'],
            (string)$battle['node_code'],
            $battle['att_faction_id'],
            (int)($battle['result']['score'] ?? 0)
        ));
    }

    if ($method === 'GET' && $path === '/api/slice/report') {
        $player = requireAuth($service);
        $turnId = (int)($_GET['turn_id'] ?? 0);
        if ($turnId <= 0) {
            throw new ApiException('BAD_REQUEST', '缺少 turn_id');
        }
        success($service->getReport($player, $turnId));
    }

    if ($method === 'GET' && $path === '/api/slice/history') {
        $player = requireAuth($service);
        success($service->getHistory($player, (int)($_GET['limit'] ?? 10)));
    }

    if ($method === 'GET' && $path === '/api/slice/replay') {
        $player = requireAuth($service);
        success($service->getReplay($player));
    }

    if ($method === 'GET' && $path === '/api/slice/wallet') {
        $player = requireAuth($service);
        success($service->getWalletForPlayer($player));
    }

    if ($method === 'POST' && $path === '/api/slice/recharge') {
        $player = requireAuth($service);
        $body = jsonBody();
        success($service->rechargePlayer(
            $player,
            (int)($body['points'] ?? 0),
            (string)($body['request_key'] ?? '')
        ));
    }

    if ($method === 'GET' && $path === '/api/slice/admin/status') {
        $player = requireAuth($service);
        success($service->adminStatus($player));
    }

    if ($method === 'POST' && $path === '/api/slice/admin/lock') {
        $player = requireAuth($service);
        $body = jsonBody();
        success($service->lockTurn($player, (int)($body['turn_id'] ?? 0), (bool)($body['force'] ?? false)));
    }

    if ($method === 'POST' && $path === '/api/slice/admin/settle') {
        $player = requireAuth($service);
        $body = jsonBody();
        success($service->settleTurn($player, (int)($body['turn_id'] ?? 0), [
            'inject_failure' => (bool)($body['inject_failure'] ?? false),
        ]));
    }

    if ($method === 'POST' && $path === '/api/slice/admin/card-settle') {
        $player = requireAuth($service);
        if ((string)$player['role'] !== 'teacher') {
            throw new ApiException('FORBIDDEN', '只有教师可以结算', 403);
        }
        $body = jsonBody();
        $turnId = (int)($body['turn_id'] ?? 0);
        if ($turnId <= 0) {
            throw new ApiException('BAD_REQUEST', '缺少 turn_id');
        }
        success((new CardSettlementService($pdo))->settle((int)$player['game_id'], $turnId));
    }

    if ($method === 'POST' && $path === '/api/slice/admin/next-turn') {
        $player = requireAuth($service);
        $body = jsonBody();
        success($service->nextTurn($player, (int)($body['from_turn_id'] ?? $body['turn_id'] ?? 0)));
    }

    if ($method === 'POST' && $path === '/api/slice/admin/pause') {
        $player = requireAuth($service);
        success($service->setGameStatus($player, 'paused'));
    }

    if ($method === 'POST' && $path === '/api/slice/admin/resume') {
        $player = requireAuth($service);
        success($service->setGameStatus($player, 'running'));
    }

    throw new ApiException('NOT_FOUND', '接口不存在：' . $method . ' ' . $path, 404);
} catch (InvalidArgumentException $e) {
    failure(new ApiException('BAD_REQUEST', $e->getMessage(), 400));
} catch (ApiException $e) {
    slice_log('api.error', [
        'request_id' => $requestId,
        'method' => $method,
        'path' => $path,
        'code' => $e->errorCode,
        'status' => $e->httpStatus,
        'ms' => (int)round((microtime(true) - $started) * 1000),
    ]);
    failure($e);
} catch (Throwable $e) {
    slice_log('api.exception', [
        'request_id' => $requestId,
        'method' => $method,
        'path' => $path,
        'error' => $e->getMessage(),
        'ms' => (int)round((microtime(true) - $started) * 1000),
    ]);
    $configPath = getenv('SLICE_CONFIG') ?: dirname(__DIR__) . '/config.local.php';
    $config = is_file($configPath) ? require $configPath : [];
    $details = !empty($config['app']['expose_error_details'])
        ? ['exception' => $e->getMessage()]
        : [];
    respond(500, [
        'ok' => false,
        'error' => ['code' => 'INTERNAL', 'message' => '服务器内部错误', 'details' => $details],
        'server_time' => date('Y-m-d H:i:s'),
    ]);
}
