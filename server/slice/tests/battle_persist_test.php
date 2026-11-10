<?php
declare(strict_types=1);

require_once __DIR__ . '/../bootstrap.php';
require_once __DIR__ . '/../src/BattleService.php';

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
$service = new BattleService(null, $pdo);

$gameId = (int)$pdo->query('SELECT id FROM slice_games LIMIT 1')->fetchColumn();
$turnId = (int)$pdo->query('SELECT id FROM slice_turns ORDER BY id LIMIT 1')->fetchColumn();
$factions = $pdo->query('SELECT id FROM slice_factions ORDER BY id LIMIT 2')->fetchAll(PDO::FETCH_COLUMN);
$attFactionId = isset($factions[0]) ? (int)$factions[0] : null;
$defFactionId = isset($factions[1]) ? (int)$factions[1] : null;

check('有测试局和阵营', $gameId > 0 && $turnId > 0 && $attFactionId !== null && $defFactionId !== null);

$attacker = [
    'general' => 'def',
    'troops' => 1088,
    'composition' => ['cav', 'shield', 'arc'],
    'fire' => false,
];
$defender = [
    'general' => 'atk',
    'troops' => 1200,
    'composition' => ['shield', 'spear', 'arc'],
];

$result = $service->resolve($attacker, $defender);
check('战斗有结果', isset($result['score'], $result['wall'], $result['ticks']));

$battleId = $service->saveBattle(
    $gameId,
    $turnId,
    'hanzhong',
    $attFactionId,
    $defFactionId,
    $attacker,
    $defender,
    $result
);
check('战斗已入库', $battleId > 0, 'id=' . $battleId);

$battle = $service->getBattle($battleId);
check('能读回战斗', $battle !== null);
check('节点正确', ($battle['node_code'] ?? '') === 'hanzhong');
check('攻方配置正确', ($battle['attacker']['composition'] ?? []) === ['cav', 'shield', 'arc']);
check('守方配置正确', ($battle['defender']['composition'] ?? []) === ['shield', 'spear', 'arc']);
check('结果摘要正确', ($battle['result']['score'] ?? null) === $result['score']);
check('完整 log 有事件', count($battle['log']['events'] ?? []) > 0, 'events=' . count($battle['log']['events'] ?? []));
check('完整 log 有单位', count($battle['log']['units'] ?? []) > 0, 'units=' . count($battle['log']['units'] ?? []));

// 清理
$pdo->prepare('DELETE FROM slice_battles WHERE id = ?')->execute([$battleId]);

echo PHP_EOL;
if ($failed > 0) {
    echo "BATTLE_PERSIST FAIL ({$failed})\n";
    exit(1);
}
echo "BATTLE_PERSIST PASS\n";
