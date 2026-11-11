<?php
declare(strict_types=1);

require_once __DIR__ . '/../bootstrap.php';
require_once __DIR__ . '/../src/SqlRunner.php';
require_once __DIR__ . '/../src/HandService.php';

$failed = 0;
function check(string $name, bool $ok, string $detail = ''): void
{
    global $failed;
    echo ($ok ? '[PASS] ' : '[FAIL] ') . $name . ($detail !== '' ? ' — ' . $detail : '') . PHP_EOL;
    if (!$ok) {
        $failed++;
    }
}

[$config, $pdo] = slice_bootstrap();
$seed = dirname(__DIR__) . '/seed.sql';
$pdo->exec("DELETE FROM slice_games WHERE code = 'SLICE_A'");
SqlRunner::runFile($pdo, $seed);

$gameId = (int)$pdo->query("SELECT id FROM slice_games WHERE code = 'SLICE_A'")->fetchColumn();
$turnId = (int)$pdo->query("SELECT id FROM slice_turns WHERE game_id = {$gameId} ORDER BY turn_no LIMIT 1")->fetchColumn();
$playerId = (int)$pdo->query("SELECT id FROM slice_players WHERE game_id = {$gameId} AND role = 'player' ORDER BY id LIMIT 1")->fetchColumn();
$service = new HandService($pdo);
$hand = $service->getOrCreateHand($gameId, $turnId, $playerId);
$card = (string)($hand['cards'][0] ?? 'night_raid');

$play = function (string $key) use ($service, $gameId, $turnId, $playerId, $card): string {
    try {
        $service->play($gameId, $turnId, $playerId, 0, $card, 'N1', 1, 'front', $key);
        return 'OK';
    } catch (ApiException $e) {
        return $e->errorCode;
    }
};

try {
    check('开放回合可出令', $play('guard_open_0001') === 'OK');

    $pdo->prepare("UPDATE slice_turns SET status = 'settled' WHERE id = ?")->execute([$turnId]);
    check('结算后出令被拒', $play('guard_settled_0001') === 'TURN_NOT_OPEN');
    $threw = false;
    try {
        $service->withdraw($turnId, $playerId, 0);
    } catch (ApiException $e) {
        $threw = $e->errorCode === 'TURN_NOT_OPEN';
    }
    check('结算后撤令被拒', $threw);

    $pdo->prepare("UPDATE slice_turns SET status = 'open' WHERE id = ?")->execute([$turnId]);
    $pdo->prepare("UPDATE slice_games SET status = 'paused' WHERE id = ?")->execute([$gameId]);
    check('暂停游戏出令被拒', $play('guard_paused_0001') === 'GAME_PAUSED');

    $pdo->prepare("UPDATE slice_games SET status = 'running' WHERE id = ?")->execute([$gameId]);
    $pdo->prepare('UPDATE slice_turns SET deadline_at = DATE_SUB(NOW(), INTERVAL 1 MINUTE) WHERE id = ?')->execute([$turnId]);
    check('过截止出令被拒', $play('guard_late_0001') === 'TURN_DEADLINE_PASSED');

    $pdo->prepare('UPDATE slice_turns SET deadline_at = DATE_ADD(NOW(), INTERVAL 10 MINUTE) WHERE id = ?')->execute([$turnId]);
    $wrongGame = 999999;
    $bad = false;
    try {
        $service->play($wrongGame, $turnId, $playerId, 0, $card, 'N1', 1, 'front', 'guard_wrong_0001');
    } catch (ApiException $e) {
        $bad = $e->errorCode === 'WRONG_GAME';
    }
    check('跨游戏出令被拒', $bad);
} finally {
    $pdo->exec("DELETE FROM slice_games WHERE code = 'SLICE_A'");
    SqlRunner::runFile($pdo, $seed);
}

echo PHP_EOL;
if ($failed > 0) {
    echo "TURN_GUARD FAIL ({$failed})\n";
    exit(1);
}
echo "TURN_GUARD PASS\n";
