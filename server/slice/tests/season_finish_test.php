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

try {
    SqlRunner::runFile($pdo, $seed);
    $gameId = (int)$pdo->query("SELECT id FROM slice_games WHERE code = 'MAP12_TEST'")->fetchColumn();
    $turnId = (int)$pdo->query("SELECT id FROM slice_turns WHERE game_id = {$gameId} ORDER BY turn_no LIMIT 1")->fetchColumn();
    $pdo->prepare(
        "UPDATE slice_nodes SET owner_faction_id = (SELECT id FROM slice_factions WHERE game_id = ? AND code = 'bi')
         WHERE game_id = ? AND node_code = 'changan'"
    )->execute([$gameId, $gameId]);
    (new CardSettlementService($pdo))->settle($gameId, $turnId);
    $status = (string)$pdo->query("SELECT status FROM slice_games WHERE id = {$gameId}")->fetchColumn();
    check('占长安后游戏结束', $status === 'finished', 'status=' . $status);

    SqlRunner::runFile($pdo, $seed);
    $gameId = (int)$pdo->query("SELECT id FROM slice_games WHERE code = 'MAP12_TEST'")->fetchColumn();
    $pdo->prepare(
        "INSERT INTO slice_turns (game_id, turn_no, status, opens_at, deadline_at, rules_version)
         VALUES (?, 28, 'open', NOW(), DATE_ADD(NOW(), INTERVAL 600 SECOND), 'cards_v1')"
    )->execute([$gameId]);
    $turn28 = (int)$pdo->lastInsertId();
    $pdo->prepare('UPDATE slice_games SET current_turn_id = ? WHERE id = ?')->execute([$turn28, $gameId]);
    (new CardSettlementService($pdo))->settle($gameId, $turn28);
    $status = (string)$pdo->query("SELECT status FROM slice_games WHERE id = {$gameId}")->fetchColumn();
    check('第 28 回合后游戏结束', $status === 'finished', 'status=' . $status);
} finally {
    SqlRunner::runFile($pdo, $seed);
}

echo PHP_EOL;
if ($failed > 0) {
    echo "SEASON_FINISH FAIL ({$failed})\n";
    exit(1);
}
echo "SEASON_FINISH PASS\n";
