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

[$config, $pdo] = slice_bootstrap();
$seed = dirname(__DIR__) . '/seed_map12.sql';

function regionBattle(PDO $pdo, string $seed, array $extraOwned, string $target): array
{
    SqlRunner::runFile($pdo, $seed);
    $gameId = (int)$pdo->query("SELECT id FROM slice_games WHERE code = 'MAP12_TEST'")->fetchColumn();
    $turnId = (int)$pdo->query("SELECT id FROM slice_turns WHERE game_id = {$gameId} ORDER BY turn_no LIMIT 1")->fetchColumn();
    $players = array_map('intval', $pdo->query(
        "SELECT p.id FROM slice_players p JOIN slice_factions f ON f.id = p.faction_id
         WHERE p.game_id = {$gameId} AND p.role = 'player' AND f.code = 'bi' ORDER BY p.id LIMIT 3"
    )->fetchAll(PDO::FETCH_COLUMN));

    foreach ($extraOwned as $node) {
        $pdo->prepare(
            "UPDATE slice_nodes SET owner_faction_id = (SELECT id FROM slice_factions WHERE game_id = ? AND code = 'bi')
             WHERE game_id = ? AND node_code = ?"
        )->execute([$gameId, $gameId, $node]);
    }

    $insert = $pdo->prepare(
        'INSERT INTO slice_order_slots
            (game_id, turn_id, player_id, slot, card_code, target_node_code, lane, row_pos, status, last_request_key)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, "active", ?)'
    );
    foreach ($players as $i => $pid) {
        $insert->execute([$gameId, $turnId, $pid, 0, 'fortify', $target, $i + 1, 'front', 'reg_' . $i . '_' . bin2hex(random_bytes(3))]);
    }

    $result = (new CardSettlementService($pdo))->settle($gameId, $turnId);
    foreach ($result['battles'] as $entry) {
        if (($entry['node_code'] ?? '') === $target && !empty($entry['battle_id'])) {
            $stmt = $pdo->prepare('SELECT attacker_json FROM slice_battles WHERE id = ?');
            $stmt->execute([(int)$entry['battle_id']]);
            return json_decode((string)$stmt->fetchColumn(), true);
        }
    }
    return [];
}

try {
    $before = regionBattle($pdo, $seed, [], 'taiyuan');
    check('未控全区：region_bonus=false', empty($before['region_bonus']));
    $beforeTroops = array_sum(array_column($before['teams'] ?? [], 'troops'));

    $after = regionBattle($pdo, $seed, ['hanzhong', 'xiangyang'], 'taiyuan');
    check('控全区：region_bonus=true', !empty($after['region_bonus']));
    $afterTroops = array_sum(array_column($after['teams'] ?? [], 'troops'));
    check('区域 +5% 生效', $afterTroops > $beforeTroops * 1.03, sprintf('before=%.1f after=%.1f', $beforeTroops, $afterTroops));
} finally {
    SqlRunner::runFile($pdo, $seed);
}

echo PHP_EOL;
if ($failed > 0) {
    echo "REGION_BONUS FAIL ({$failed})\n";
    exit(1);
}
echo "REGION_BONUS PASS\n";
