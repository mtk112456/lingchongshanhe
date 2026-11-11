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
$seed = dirname(__DIR__) . '/seed.sql';
$pdo->exec("DELETE FROM slice_games WHERE code = 'SLICE_A'");
SqlRunner::runFile($pdo, $seed);

$gameId = (int)$pdo->query("SELECT id FROM slice_games WHERE code = 'SLICE_A'")->fetchColumn();
$turnId = (int)$pdo->query("SELECT id FROM slice_turns WHERE game_id = {$gameId} ORDER BY turn_no LIMIT 1")->fetchColumn();
$players = array_map('intval', $pdo->query(
    "SELECT p.id FROM slice_players p JOIN slice_factions f ON f.id = p.faction_id
     WHERE p.game_id = {$gameId} AND p.role = 'player' AND f.code = 'bi' ORDER BY p.id LIMIT 3"
)->fetchAll(PDO::FETCH_COLUMN));
$me = $players[0];

$insert = $pdo->prepare(
    'INSERT INTO slice_order_slots
        (game_id, turn_id, player_id, slot, card_code, target_node_code, lane, row_pos, status, last_request_key)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, "active", ?)'
);
foreach ($players as $i => $pid) {
    $insert->execute([$gameId, $turnId, $pid, 0, 'night_raid', 'N1', $i + 1, 'front', 'fc_' . $i . '_' . bin2hex(random_bytes(3))]);
}

$service = new CardSettlementService($pdo);
try {
    $battlesBefore = (int)$pdo->query('SELECT COUNT(*) FROM slice_battles')->fetchColumn();
    $forecast = $service->forecast($gameId, $turnId, $me, 'N1');
    check('预估可出结果', ($forecast['ready'] ?? false) === true);
    check('角色=进攻', ($forecast['role'] ?? '') === 'attack');
    check('中立城守军可见', ($forecast['intel_known'] ?? false) === true);
    check('攻方兵力 > 0', ($forecast['attacker']['troops'] ?? 0) > 0);
    check('守军兵力 > 0', ($forecast['defender']['troops'] ?? 0) > 0);
    check('城墙 0–1500', ($forecast['forecast']['wall'] ?? -1) >= 0 && ($forecast['forecast']['wall'] ?? 9999) <= 1500);
    check('有胜负判断', in_array($forecast['forecast']['verdict'] ?? '', ['优势', '均势', '劣势'], true));
    check('有建议', ($forecast['advice'] ?? []) !== []);
    check('有克制统计', is_array($forecast['counters'] ?? null));

    // 预估不写战斗、不改回合状态
    $battlesAfter = (int)$pdo->query('SELECT COUNT(*) FROM slice_battles')->fetchColumn();
    check('预估不写战斗记录', $battlesAfter === $battlesBefore);
    $turnStatus = (string)$pdo->query("SELECT status FROM slice_turns WHERE id = {$turnId}")->fetchColumn();
    check('预估不改回合状态', $turnStatus === 'open');

    // 未侦察的敌城：隐藏守军细节
    $pdo->prepare(
        "UPDATE slice_nodes SET owner_faction_id = (SELECT id FROM slice_factions WHERE game_id = ? AND code = 'mo')
         WHERE game_id = ? AND node_code = 'N1'"
    )->execute([$gameId, $gameId]);
    $hidden = $service->forecast($gameId, $turnId, $me, 'N1');
    check('未侦察敌城：intel_known=false', ($hidden['intel_known'] ?? true) === false);
    check('未侦察敌城：不显示守军队伍', ($hidden['defender']['teams'] ?? []) === []);
    check('未侦察敌城：给兵力区间', is_array($hidden['defender']['troops_range'] ?? null));

    // 己方城：不模拟进攻
    $pdo->prepare(
        "UPDATE slice_nodes SET owner_faction_id = (SELECT id FROM slice_factions WHERE game_id = ? AND code = 'bi')
         WHERE game_id = ? AND node_code = 'N1'"
    )->execute([$gameId, $gameId]);
    $defend = $service->forecast($gameId, $turnId, $me, 'N1');
    check('己方城：role=defend', ($defend['role'] ?? '') === 'defend');
    check('己方城：不返回进攻预估', ($defend['ready'] ?? true) === false && ($defend['reason'] ?? '') === 'DEFEND_CITY');

    // 没有出令：提示先出令
    $noOrder = $service->forecast($gameId, $turnId, $me, 'N2');
    check('未出令：提示 NO_ORDERS', ($noOrder['ready'] ?? true) === false && ($noOrder['reason'] ?? '') === 'NO_ORDERS');
} finally {
    $pdo->exec("DELETE FROM slice_games WHERE code = 'SLICE_A'");
    SqlRunner::runFile($pdo, $seed);
}

echo PHP_EOL;
if ($failed > 0) {
    echo "FORECAST FAIL ({$failed})\n";
    exit(1);
}
echo "FORECAST PASS\n";
