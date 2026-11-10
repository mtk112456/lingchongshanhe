<?php
declare(strict_types=1);

require_once __DIR__ . '/../bootstrap.php';
require_once __DIR__ . '/../src/HandService.php';
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

[$config, $pdo] = slice_bootstrap();

$gameId = (int)$pdo->query('SELECT id FROM slice_games LIMIT 1')->fetchColumn();
$turnId = (int)$pdo->query('SELECT id FROM slice_turns ORDER BY id LIMIT 1')->fetchColumn();
$playerId = (int)$pdo->query('SELECT id FROM slice_players ORDER BY id LIMIT 1')->fetchColumn();
$nodeCode = 'N2';

check('有测试局', $gameId > 0 && $turnId > 0 && $playerId > 0);

// 清理
$pdo->prepare('UPDATE slice_turns SET status = "open", settled_at = NULL WHERE id = ?')->execute([$turnId]);
$pdo->prepare('UPDATE slice_nodes SET morale = 0, owner_faction_id = NULL WHERE game_id = ? AND node_code = ?')->execute([$gameId, $nodeCode]);
$pdo->prepare('DELETE FROM slice_battles WHERE turn_id = ?')->execute([$turnId]);
$pdo->prepare('DELETE FROM slice_node_changes WHERE turn_id = ?')->execute([$turnId]);
$pdo->prepare('DELETE FROM slice_order_slots WHERE turn_id = ? AND player_id = ?')->execute([$turnId, $playerId]);
$pdo->prepare('DELETE FROM slice_hands WHERE turn_id = ? AND player_id = ?')->execute([$turnId, $playerId]);
$pdo->prepare('DELETE FROM slice_compositions WHERE game_id = ? AND player_id = ? AND week_no = 1')->execute([$gameId, $playerId]);

$handService = new HandService($pdo);
$hand = $handService->getOrCreateHand($gameId, $turnId, $playerId);
for ($i = 0; $i < 3; $i++) {
    $handService->play(
        $gameId,
        $turnId,
        $playerId,
        $i,
        $hand['cards'][$i],
        $nodeCode,
        $i + 1,
        'front',
        'cs_test_' . $i . '_' . bin2hex(random_bytes(4))
    );
}
check('3 张令已出', count($handService->getOrders($turnId, $playerId)) === 3);

$settler = new CardSettlementService($pdo);
$r = $settler->settle($gameId, $turnId);
check('结算未重复', $r['already_settled'] === false);
check('产生战斗', count($r['battles']) >= 1, json_encode($r['battles'], JSON_UNESCAPED_UNICODE));

$b = $r['battles'][0] ?? [];
check('战斗有 id', ($b['battle_id'] ?? 0) > 0, json_encode($b, JSON_UNESCAPED_UNICODE));
check('战斗有分数', isset($b['score']), 'score=' . ($b['score'] ?? 'null'));

$stmt = $pdo->prepare('SELECT morale, owner_faction_id FROM slice_nodes WHERE game_id = ? AND node_code = ?');
$stmt->execute([$gameId, $nodeCode]);
$node = $stmt->fetch();
check('城池民心/归属已更新', $node !== false, json_encode($node, JSON_UNESCAPED_UNICODE));

$status = $pdo->query('SELECT status FROM slice_turns WHERE id = ' . $turnId)->fetchColumn();
check('回合已结算', (string)$status === 'settled', 'status=' . $status);

$r2 = $settler->settle($gameId, $turnId);
check('重复结算幂等', $r2['already_settled'] === true);

// 清理
$pdo->prepare('UPDATE slice_turns SET status = "open", settled_at = NULL WHERE id = ?')->execute([$turnId]);
$pdo->prepare('UPDATE slice_nodes SET morale = 0, owner_faction_id = NULL WHERE game_id = ? AND node_code = ?')->execute([$gameId, $nodeCode]);
$pdo->prepare('DELETE FROM slice_battles WHERE turn_id = ?')->execute([$turnId]);
$pdo->prepare('DELETE FROM slice_node_changes WHERE turn_id = ?')->execute([$turnId]);
$pdo->prepare('DELETE FROM slice_order_slots WHERE turn_id = ? AND player_id = ?')->execute([$turnId, $playerId]);
$pdo->prepare('DELETE FROM slice_hands WHERE turn_id = ? AND player_id = ?')->execute([$turnId, $playerId]);
$pdo->prepare('DELETE FROM slice_compositions WHERE game_id = ? AND player_id = ? AND week_no = 1')->execute([$gameId, $playerId]);

echo PHP_EOL;
if ($failed > 0) {
    echo "CARD_SETTLEMENT FAIL ({$failed})\n";
    exit(1);
}
echo "CARD_SETTLEMENT PASS\n";
