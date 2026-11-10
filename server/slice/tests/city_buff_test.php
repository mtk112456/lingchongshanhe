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

/**
 * @return array{battle:?array,attacker:?array,defender:?array}
 */
function runScenario(PDO $pdo, string $seed, string $node, ?string $ownerCode): array
{
    SqlRunner::runFile($pdo, $seed);
    $gameId = (int)$pdo->query("SELECT id FROM slice_games WHERE code = 'MAP12_TEST'")->fetchColumn();
    $turnId = (int)$pdo->query("SELECT id FROM slice_turns WHERE game_id = {$gameId} ORDER BY turn_no LIMIT 1")->fetchColumn();
    $players = array_map('intval', $pdo->query(
        "SELECT p.id FROM slice_players p JOIN slice_factions f ON f.id = p.faction_id
         WHERE p.game_id = {$gameId} AND p.role = 'player' AND f.code = 'bi' ORDER BY p.id LIMIT 3"
    )->fetchAll(PDO::FETCH_COLUMN));

    if ($ownerCode !== null) {
        $pdo->prepare(
            "UPDATE slice_nodes SET owner_faction_id = (SELECT id FROM slice_factions WHERE game_id = ? AND code = ?)
             WHERE game_id = ? AND node_code = ?"
        )->execute([$gameId, $ownerCode, $gameId, $node]);
    }

    $insert = $pdo->prepare(
        'INSERT INTO slice_order_slots
            (game_id, turn_id, player_id, slot, card_code, target_node_code, lane, row_pos, status, last_request_key)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, "active", ?)'
    );
    foreach ($players as $i => $pid) {
        $insert->execute([$gameId, $turnId, $pid, 0, 'fortify', $node, $i + 1, 'front', 'buff_' . $i . '_' . bin2hex(random_bytes(3))]);
    }

    $result = (new CardSettlementService($pdo))->settle($gameId, $turnId);
    $battle = null;
    foreach ($result['battles'] as $entry) {
        if (($entry['node_code'] ?? '') === $node && !empty($entry['battle_id'])) {
            $battle = $entry;
            break;
        }
    }
    if ($battle === null) {
        return ['battle' => null, 'attacker' => null, 'defender' => null];
    }

    $stmt = $pdo->prepare('SELECT attacker_json, defender_json FROM slice_battles WHERE id = ?');
    $stmt->execute([(int)$battle['battle_id']]);
    $row = $stmt->fetch();
    return [
        'battle' => $battle,
        'attacker' => json_decode((string)$row['attacker_json'], true),
        'defender' => json_decode((string)$row['defender_json'], true),
    ];
}

try {
    $camp = runScenario($pdo, $seed, 'hanzhong', null);
    check('大营战产生', $camp['battle'] !== null);
    if ($camp['battle'] !== null) {
        check('大营 +5% 生效', !empty($camp['attacker']['camp_bonus']));
        $troops = array_sum(array_column($camp['attacker']['teams'] ?? [], 'troops'));
        check('大营后总兵力 > 900', $troops > 900, 'troops=' . $troops);
    }

    $pass = runScenario($pdo, $seed, 'hanzhong', 'mo');
    check('关隘战产生', $pass['battle'] !== null);
    if ($pass['battle'] !== null) {
        check('关隘 +10% 生效', !empty($pass['defender']['pass_bonus']));
        check('关隘守军 > 1320', (float)($pass['defender']['troops'] ?? 0) > 1320, 'def=' . ($pass['defender']['troops'] ?? 0));
    }
} finally {
    SqlRunner::runFile($pdo, $seed);
}

echo PHP_EOL;
if ($failed > 0) {
    echo "CITY_BUFF FAIL ({$failed})\n";
    exit(1);
}
echo "CITY_BUFF PASS\n";
