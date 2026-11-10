<?php
declare(strict_types=1);

require_once __DIR__ . '/../bootstrap.php';
require_once __DIR__ . '/../src/SqlRunner.php';
require_once __DIR__ . '/../src/BattleSettlementService.php';

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
SqlRunner::runFile($pdo, dirname(__DIR__) . '/seed_map12.sql');

$stmt = $pdo->prepare('SELECT id FROM slice_games WHERE code = ?');
$stmt->execute(['MAP12_TEST']);
$gameId = (int)$stmt->fetchColumn();
check('MAP12_TEST 存在', $gameId > 0);

$nodes = $pdo->query("SELECT node_code, node_type, owner_faction_id, morale FROM slice_nodes WHERE game_id = {$gameId} ORDER BY sort_order")->fetchAll();
check('13 个节点', count($nodes) === 13, 'nodes=' . count($nodes));

$byType = [];
foreach ($nodes as $n) {
    $byType[$n['node_type']] = ($byType[$n['node_type']] ?? 0) + 1;
}
check('1 王城', ($byType['king'] ?? 0) === 1);
check('4 大营', ($byType['camp'] ?? 0) === 4);
check('3 关隘', ($byType['pass'] ?? 0) === 3);
check('1 渡口', ($byType['ferry'] ?? 0) === 1);
check('3 文脉', ($byType['culture'] ?? 0) === 3);
check('1 水乡', ($byType['water'] ?? 0) === 1);

$changan = null;
foreach ($nodes as $n) {
    if ($n['node_code'] === 'changan') {
        $changan = $n;
        break;
    }
}
check('长安是中立的王城', $changan !== null && $changan['node_type'] === 'king' && $changan['owner_faction_id'] === null);

$edges = (int)$pdo->query("SELECT COUNT(*) FROM slice_edges WHERE game_id = {$gameId}")->fetchColumn();
check('16 条边', $edges === 16, 'edges=' . $edges);

$factions = $pdo->query("SELECT code, start_node_code FROM slice_factions WHERE game_id = {$gameId} ORDER BY sort_order")->fetchAll();
check('4 个阵营', count($factions) === 4, json_encode($factions, JSON_UNESCAPED_UNICODE));
$starts = array_column($factions, 'start_node_code');
check('起点是凉州/邺城/成都/建业', $starts === ['liangzhou', 'yecheng', 'chengdu', 'jianye'], implode(',', $starts));

$players = (int)$pdo->query("SELECT COUNT(*) FROM slice_players WHERE game_id = {$gameId} AND role = 'player'")->fetchColumn();
check('8 名学生', $players === 8, 'players=' . $players);

$turns = $pdo->query("SELECT status, rules_version FROM slice_turns WHERE game_id = {$gameId} ORDER BY turn_no LIMIT 1")->fetch();
check('回合 open / cards_v1', $turns !== false && $turns['status'] === 'open' && $turns['rules_version'] === 'cards_v1');

check('王城民心上限 5', BattleSettlementService::cap('king') === 5);
check('大营民心上限 3', BattleSettlementService::cap('camp') === 3);
check('关隘民心上限 3', BattleSettlementService::cap('pass') === 3);
check('渡口民心上限 3', BattleSettlementService::cap('ferry') === 3);
check('文脉民心上限 3', BattleSettlementService::cap('culture') === 3);
check('水乡民心上限 3', BattleSettlementService::cap('water') === 3);

echo PHP_EOL;
if ($failed > 0) {
    echo "MAP12_SEED FAIL ({$failed})\n";
    exit(1);
}
echo "MAP12_SEED PASS\n";
