<?php
declare(strict_types=1);

require_once __DIR__ . '/../bootstrap.php';
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

$gameId = (int)$pdo->query('SELECT id FROM slice_games LIMIT 1')->fetchColumn();
$turnId = (int)$pdo->query('SELECT id FROM slice_turns ORDER BY id LIMIT 1')->fetchColumn();
$factionId = (int)$pdo->query('SELECT id FROM slice_factions ORDER BY id LIMIT 1')->fetchColumn();
$nodeCode = 'N1';

check('有测试局/回合/阵营', $gameId > 0 && $turnId > 0 && $factionId > 0);

// 重置
$pdo->prepare('UPDATE slice_nodes SET morale = 0, owner_faction_id = NULL WHERE game_id = ? AND node_code = ?')
    ->execute([$gameId, $nodeCode]);
$pdo->prepare('DELETE FROM slice_node_changes WHERE turn_id = ? AND node_code = ?')
    ->execute([$turnId, $nodeCode]);

$service = new BattleSettlementService($pdo);

// 1. 第一次 +1
$r1 = $service->apply($gameId, $turnId, $nodeCode, $factionId, 1);
check('第一次 +1 未易主', $r1['morale_after'] === 1 && $r1['captured'] === false, json_encode($r1, JSON_UNESCAPED_UNICODE));

// 2. 第二次 +1 满格易主
$r2 = $service->apply($gameId, $turnId, $nodeCode, $factionId, 1);
check('第二次满格易主', $r2['captured'] === true && $r2['owner_after'] === $factionId && $r2['morale_after'] === 0, json_encode($r2, JSON_UNESCAPED_UNICODE));

// 3. 失败 -1 不扣到负
$r3 = $service->apply($gameId, $turnId, $nodeCode, $factionId, -1);
check('失败不扣到负', $r3['morale_after'] === 0, json_encode($r3, JSON_UNESCAPED_UNICODE));

// 4. 上限
check('长安上限 5', BattleSettlementService::cap('king') === 5);
check('关隘上限 3', BattleSettlementService::cap('pass') === 3);
check('普通城上限 2', BattleSettlementService::cap('neutral') === 2);

// 5. 记录
$stmt = $pdo->prepare('SELECT COUNT(*) FROM slice_node_changes WHERE turn_id = ? AND node_code = ?');
$stmt->execute([$turnId, $nodeCode]);
check('写入城池变化记录', (int)$stmt->fetchColumn() === 1);

// 清理
$pdo->prepare('UPDATE slice_nodes SET morale = 0, owner_faction_id = NULL WHERE game_id = ? AND node_code = ?')
    ->execute([$gameId, $nodeCode]);
$pdo->prepare('DELETE FROM slice_node_changes WHERE turn_id = ? AND node_code = ?')
    ->execute([$turnId, $nodeCode]);

echo PHP_EOL;
if ($failed > 0) {
    echo "BATTLE_SETTLEMENT FAIL ({$failed})\n";
    exit(1);
}
echo "BATTLE_SETTLEMENT PASS\n";
