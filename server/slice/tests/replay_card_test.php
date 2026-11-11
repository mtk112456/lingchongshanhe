<?php
declare(strict_types=1);

require_once __DIR__ . '/../bootstrap.php';
require_once __DIR__ . '/../src/SqlRunner.php';
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

[$config, $pdo, $service] = slice_bootstrap();
$seed = dirname(__DIR__) . '/seed.sql';
$pdo->exec("DELETE FROM slice_games WHERE code = 'SLICE_A'");
SqlRunner::runFile($pdo, $seed);

$gameId = (int)$pdo->query("SELECT id FROM slice_games WHERE code = 'SLICE_A'")->fetchColumn();
$players = array_map('intval', $pdo->query(
    "SELECT p.id FROM slice_players p JOIN slice_factions f ON f.id = p.faction_id
     WHERE p.game_id = {$gameId} AND p.role = 'player' AND f.code = 'bi' ORDER BY p.id LIMIT 3"
)->fetchAll(PDO::FETCH_COLUMN));

$insert = $pdo->prepare(
    'INSERT INTO slice_order_slots
        (game_id, turn_id, player_id, slot, card_code, target_node_code, lane, row_pos, status, last_request_key)
     VALUES (?, ?, ?, 0, "night_raid", "N1", ?, "front", "active", ?)'
);
$settler = new CardSettlementService($pdo);
try {
    for ($no = 1; $no <= 2; $no++) {
        $stmt = $pdo->prepare('SELECT id FROM slice_turns WHERE game_id = ? AND turn_no = ?');
        $stmt->execute([$gameId, $no]);
        $turnId = (int)$stmt->fetchColumn();
        if ($turnId <= 0) {
            $pdo->prepare(
                "INSERT INTO slice_turns (game_id, turn_no, status, opens_at, deadline_at, rules_version)
                 VALUES (?, ?, 'open', NOW(), DATE_ADD(NOW(), INTERVAL 600 SECOND), 'cards_v1')"
            )->execute([$gameId, $no]);
            $turnId = (int)$pdo->lastInsertId();
        }
        foreach ($players as $i => $pid) {
            $insert->execute([$gameId, $turnId, $pid, $i + 1, 'replay_' . $no . '_' . $i . '_' . bin2hex(random_bytes(3))]);
        }
        $settler->settle($gameId, $turnId);
    }

    $login = $service->loginStudent('青竹一', 'slice2026');
    $player = $service->authenticate($login['token']);
    $replay = $service->getReplay($player);
    check('回放有已结算回合', count($replay['turns'] ?? []) >= 2, 'turns=' . count($replay['turns'] ?? []));
    $allChanges = [];
    foreach ($replay['turns'] as $turn) {
        foreach ($turn['changes'] as $change) {
            $allChanges[] = $change;
        }
    }
    check('卡牌战报生成 node_changes', $allChanges !== [], json_encode($allChanges));
    $codes = array_column($allChanges, 'node_code');
    check('回放包含 N1', in_array('N1', $codes, true), json_encode($codes));
    $first = $allChanges[0] ?? [];
    check('回放带 owner_after', array_key_exists('owner_after', $first));
} finally {
    $pdo->exec("DELETE FROM slice_games WHERE code = 'SLICE_A'");
    SqlRunner::runFile($pdo, $seed);
}

echo PHP_EOL;
if ($failed > 0) {
    echo "REPLAY_CARD FAIL ({$failed})\n";
    exit(1);
}
echo "REPLAY_CARD PASS\n";
