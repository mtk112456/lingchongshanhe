<?php
declare(strict_types=1);

require_once __DIR__ . '/../bootstrap.php';
require_once __DIR__ . '/../src/SqlRunner.php';
require_once __DIR__ . '/../src/CardSettlementService.php';
require_once __DIR__ . '/../src/SeasonHistoryService.php';

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
SqlRunner::runFile($pdo, $seed);

$gameId = (int)$pdo->query("SELECT id FROM slice_games WHERE code = 'MAP12_TEST'")->fetchColumn();
$turns = [];
for ($no = 1; $no <= 4; $no++) {
    $stmt = $pdo->prepare('SELECT id, turn_no FROM slice_turns WHERE game_id = ? AND turn_no = ?');
    $stmt->execute([$gameId, $no]);
    $row = $stmt->fetch();
    if ($row === false) {
        $pdo->prepare(
            "INSERT INTO slice_turns (game_id, turn_no, status, opens_at, deadline_at, rules_version)
             VALUES (?, ?, 'open', NOW(), DATE_ADD(NOW(), INTERVAL 600 SECOND), 'cards_v1')"
        )->execute([$gameId, $no]);
        $row = ['id' => (int)$pdo->lastInsertId(), 'turn_no' => $no];
    }
    $turns[] = $row;
}
$players = array_map('intval', $pdo->query(
    "SELECT p.id FROM slice_players p JOIN slice_factions f ON f.id = p.faction_id
     WHERE p.game_id = {$gameId} AND p.role = 'player' AND f.code = 'bi' ORDER BY p.id LIMIT 3"
)->fetchAll(PDO::FETCH_COLUMN));

try {
    $empty = (new SeasonHistoryService($pdo))->history($gameId);
    check('空赛季：1 周', $empty['current_week'] === 1);
    check('空赛季：周 1 无战斗', $empty['weeks'][0]['battles'] === 0);
    check('空赛季：头条可读', str_contains($empty['weeks'][0]['headline'], '第 1 周'));
    check('空赛季：13 城计入', array_sum(array_column($empty['weeks'][0]['standings'], 'cities')) === 13);

    $targets = ['hanzhong', 'hanzhong', 'hanzhong', 'xiangyang'];
    $insert = $pdo->prepare(
        'INSERT INTO slice_order_slots
            (game_id, turn_id, player_id, slot, card_code, target_node_code, lane, row_pos, status, last_request_key)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, "active", ?)'
    );
    foreach ($turns as $i => $turn) {
        foreach ($players as $j => $pid) {
            $insert->execute([
                $gameId,
                (int)$turn['id'],
                $pid,
                0,
                'night_raid',
                $targets[$i],
                $j + 1,
                'front',
                'hist_' . $i . '_' . $j . '_' . bin2hex(random_bytes(3)),
            ]);
        }
        (new CardSettlementService($pdo))->settle($gameId, (int)$turn['id']);
    }
    $pdo->prepare('UPDATE slice_games SET current_turn_id = ? WHERE id = ?')
        ->execute([(int)$turns[3]['id'], $gameId]);

    $history = (new SeasonHistoryService($pdo))->history($gameId);
    check('4 回合后：当前周 1', $history['current_week'] === 1);
    check('4 回合后：max_turn=4', $history['max_turn'] === 4);
    $week = $history['weeks'][0];
    check('周 1 记录 4 场战斗', $week['battles'] === 4, 'battles=' . $week['battles']);
    check('周 1 至少 1 城易主', count($week['captures']) >= 1, 'captures=' . count($week['captures']));
    check('易主带城名与胜方', isset($week['captures'][0]['node_name'], $week['captures'][0]['winner']['code']));
    check('关键战役存在', $week['key_battle'] !== null && $week['key_battle']['score'] > 0);
    check('关键战役带双方', $week['key_battle']['attacker']['code'] === 'bi');
    check('13 城仍守恒', array_sum(array_column($week['standings'], 'cities')) === 13);
    check('头条含易主数', str_contains($week['headline'], '易主'), $week['headline']);

    // 第 2 周应显示为进行中/空周
    if ($history['current_week'] >= 2) {
        check('周 2 存在', isset($history['weeks'][1]));
    } else {
        check('未开始的周不提前生成', count($history['weeks']) === 1);
    }
} finally {
    SqlRunner::runFile($pdo, $seed);
}

echo PHP_EOL;
if ($failed > 0) {
    echo "SEASON_HISTORY FAIL ({$failed})\n";
    exit(1);
}
echo "SEASON_HISTORY PASS\n";
