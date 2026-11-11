<?php
declare(strict_types=1);

require_once __DIR__ . '/../bootstrap.php';
require_once __DIR__ . '/../src/SqlRunner.php';

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
$turnId = (int)$pdo->query("SELECT id FROM slice_turns WHERE game_id = {$gameId} ORDER BY turn_no LIMIT 1")->fetchColumn();
$players = array_map('intval', $pdo->query(
    "SELECT p.id FROM slice_players p JOIN slice_factions f ON f.id = p.faction_id
     WHERE p.game_id = {$gameId} AND p.role = 'player' AND f.code = 'bi' ORDER BY p.id LIMIT 3"
)->fetchAll(PDO::FETCH_COLUMN));

$insert = $pdo->prepare(
    'INSERT INTO slice_order_slots
        (game_id, turn_id, player_id, slot, card_code, target_node_code, lane, row_pos, status, last_request_key)
     VALUES (?, ?, ?, 0, "night_raid", "N1", ?, "front", "active", ?)'
);
foreach ($players as $i => $pid) {
    $insert->execute([$gameId, $turnId, $pid, $i + 1, 'cron_' . $i . '_' . bin2hex(random_bytes(3))]);
}
$pdo->prepare('UPDATE slice_turns SET deadline_at = DATE_SUB(NOW(), INTERVAL 1 MINUTE) WHERE id = ?')
    ->execute([$turnId]);

try {
    $result = $service->runDueTurns(true);
    check('cron 找到到期回合', ($result['due_turns'] ?? 0) >= 1, 'due=' . ($result['due_turns'] ?? 0));
    $entry = $result['results'][0] ?? [];
    check('cron 卡牌结算成功', ($entry['ok'] ?? false) === true, json_encode($entry));
    check('cron 标记已结算', ($entry['settled'] ?? false) === true);
    $status = (string)$pdo->query("SELECT status FROM slice_turns WHERE id = {$turnId}")->fetchColumn();
    check('回合状态=settled', $status === 'settled', 'status=' . $status);
    $battles = (int)$pdo->query("SELECT COUNT(*) FROM slice_battles WHERE turn_id = {$turnId}")->fetchColumn();
    check('cron 写入卡牌战斗', $battles > 0, 'battles=' . $battles);
    $results = (int)$pdo->query("SELECT COUNT(*) FROM slice_turn_results WHERE turn_id = {$turnId}")->fetchColumn();
    check('cron 写入回合结果', $results === 1, 'results=' . $results);
    $merit = (int)$pdo->query("SELECT COUNT(*) FROM slice_merit_events WHERE turn_id = {$turnId}")->fetchColumn();
    check('cron 写入军功', $merit > 0, 'merit=' . $merit);
} finally {
    $pdo->exec("DELETE FROM slice_games WHERE code = 'SLICE_A'");
    SqlRunner::runFile($pdo, $seed);
}

echo PHP_EOL;
if ($failed > 0) {
    echo "CRON_CARD FAIL ({$failed})\n";
    exit(1);
}
echo "CRON_CARD PASS\n";
