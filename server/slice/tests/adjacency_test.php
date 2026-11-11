<?php
declare(strict_types=1);

require_once __DIR__ . '/../bootstrap.php';
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
$handService = new HandService($pdo);

function tryPlay(HandService $svc, PDO $pdo, int $gameId, int $turnId, int $playerId, string $target): string
{
    $pdo->prepare('DELETE FROM slice_order_slots WHERE turn_id = ? AND player_id = ?')->execute([$turnId, $playerId]);
    $hand = $svc->getOrCreateHand($gameId, $turnId, $playerId);
    try {
        $svc->play(
            $gameId,
            $turnId,
            $playerId,
            0,
            (string)$hand['cards'][0],
            $target,
            1,
            'front',
            'adj_' . bin2hex(random_bytes(4))
        );
        return 'OK';
    } catch (InvalidArgumentException $e) {
        return $e->getMessage();
    } finally {
        $pdo->prepare('DELETE FROM slice_order_slots WHERE turn_id = ? AND player_id = ?')->execute([$turnId, $playerId]);
    }
}

// 5 节点：bi 从 A_START 只能打 N1/N2
$gameId = (int)$pdo->query("SELECT id FROM slice_games WHERE code = 'SLICE_A'")->fetchColumn();
$turnId = (int)$pdo->query("SELECT id FROM slice_turns WHERE game_id = {$gameId} ORDER BY turn_no LIMIT 1")->fetchColumn();
$playerId = (int)$pdo->query(
    "SELECT p.id FROM slice_players p JOIN slice_factions f ON f.id = p.faction_id
     WHERE p.game_id = {$gameId} AND p.role = 'player' AND f.code = 'bi' ORDER BY p.id LIMIT 1"
)->fetchColumn();

check('5 节点：相邻 N2 可打', tryPlay($handService, $pdo, $gameId, $turnId, $playerId, 'N2') === 'OK');
check('5 节点：不相邻 N3 被拒', tryPlay($handService, $pdo, $gameId, $turnId, $playerId, 'N3') === 'NOT_ADJACENT');
check('5 节点：己方 A_START 可驻守', tryPlay($handService, $pdo, $gameId, $turnId, $playerId, 'A_START') === 'OK');

// 12 城：bi 从凉州可打汉中/襄阳/太原（跨区），不能打成都
$gameId = (int)$pdo->query("SELECT id FROM slice_games WHERE code = 'MAP12_TEST'")->fetchColumn();
$pdo->prepare('UPDATE slice_games SET status = "running" WHERE id = ?')->execute([$gameId]);
if ($gameId > 0) {
    $turnId = (int)$pdo->query("SELECT id FROM slice_turns WHERE game_id = {$gameId} ORDER BY turn_no LIMIT 1")->fetchColumn();
    $playerId = (int)$pdo->query(
        "SELECT p.id FROM slice_players p JOIN slice_factions f ON f.id = p.faction_id
         WHERE p.game_id = {$gameId} AND p.role = 'player' AND f.code = 'bi' ORDER BY p.id LIMIT 1"
    )->fetchColumn();

    check('12 城：相邻汉中可打', tryPlay($handService, $pdo, $gameId, $turnId, $playerId, 'hanzhong') === 'OK');
    check('12 城：跨区太原可打', tryPlay($handService, $pdo, $gameId, $turnId, $playerId, 'taiyuan') === 'OK');
    check('12 城：不相邻成都被拒', tryPlay($handService, $pdo, $gameId, $turnId, $playerId, 'chengdu') === 'NOT_ADJACENT');
} else {
    check('12 城：MAP12_TEST 存在', false);
}

echo PHP_EOL;
if ($failed > 0) {
    echo "ADJACENCY FAIL ({$failed})\n";
    exit(1);
}
echo "ADJACENCY PASS\n";
