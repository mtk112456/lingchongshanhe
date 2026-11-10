<?php
declare(strict_types=1);

require_once __DIR__ . '/../src/HandDeck.php';
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

// 1. 发牌
$seed = 'turn:1:player:1';
$hand = HandDeck::draw($seed);
check('手牌 4 张', count($hand) === 4, implode(',', $hand));
check('手牌不重复', count(array_unique($hand)) === 4);
check('同种子同手牌', $hand === HandDeck::draw($seed));

$redraw = HandDeck::redraw($seed);
check('重抽 4 张', count($redraw) === 4, implode(',', $redraw));
check('重抽可复现', $redraw === HandDeck::redraw($seed));
check('重抽种子不同', $hand !== $redraw);

// 2. 出牌校验
$ok = true;
try {
    HandDeck::validatePlay($hand, $hand[0], []);
} catch (Throwable $e) {
    $ok = false;
}
check('合法牌可以出', $ok);

$ok = false;
try {
    HandDeck::validatePlay($hand, $hand[0], [$hand[0]]);
} catch (Throwable $e) {
    $ok = true;
}
check('同一张牌不能出两次', $ok);

$ok = false;
try {
    HandDeck::validatePlay($hand, 'not_a_card', []);
} catch (Throwable $e) {
    $ok = true;
}
check('不存在的牌不能出', $ok);

$ok = false;
try {
    HandDeck::validatePlay($hand, $hand[0], [$hand[0], $hand[1], $hand[2]]);
} catch (Throwable $e) {
    $ok = true;
}
check('超过 3 张不能出', $ok);

// 3. 战力
$pet = [
    'base_hp' => 1000,
    'base_atk' => 100,
    'base_def' => 100,
    'base_spd' => 100,
    'level' => 10,
    'growth_rate' => 1.00,
];
$power = BattleService::petPower($pet);
check('小青竹 10 级战力 1088', abs($power - 1087.5) < 0.01, 'power=' . $power);

$pet20 = $pet;
$pet20['level'] = 20;
check('20 级战力 1462', abs(BattleService::petPower($pet20) - 1462.5) < 0.01, 'power=' . BattleService::petPower($pet20));

// 4. 支援
check('0 支援 = 1.0', abs(BattleService::supportMultiplier(0) - 1.0) < 1e-9);
check('5 支援 = 1.10', abs(BattleService::supportMultiplier(5) - 1.10) < 1e-9);
check('15 支援 = 1.30', abs(BattleService::supportMultiplier(15) - 1.30) < 1e-9);
check('50 支援仍 1.30', abs(BattleService::supportMultiplier(50) - 1.30) < 1e-9);

// 5. 民心
check('分数 -1', BattleService::moraleDelta(-1) === -1);
check('分数 0', BattleService::moraleDelta(0) === 0);
check('分数 2', BattleService::moraleDelta(2) === 2);
check('分数 5 封顶 2', BattleService::moraleDelta(5) === 2);

// 6. 聚合
$service = new BattleService();
$troops = $service->aggregateTroops([$pet, $pet, $pet], 0);
check('3 先锋总兵力 1088', abs($troops - 1087.5) < 0.01, 'troops=' . $troops);

$troops10 = $service->aggregateTroops([$pet, $pet, $pet], 10);
check('10 支援 = 1305', abs($troops10 - 1305.0) < 0.01, 'troops=' . $troops10);

// 7. 战斗服务
$r = $service->resolve(
    ['general' => 'def', 'troops' => 1088, 'composition' => ['cav', 'shield', 'arc'], 'fire' => false],
    ['general' => 'atk', 'troops' => 1200, 'composition' => ['shield', 'spear', 'arc']]
);
check('战斗返回城墙', isset($r['wall']), 'wall=' . ($r['wall'] ?? 'null'));
check('战斗返回分数', isset($r['score']), 'score=' . ($r['score'] ?? 'null'));
check('战斗返回事件', count($r['events']) > 0, 'events=' . count($r['events']));

echo PHP_EOL;
if ($failed > 0) {
    echo "HAND_BATTLE FAIL ({$failed})\n";
    exit(1);
}
echo "HAND_BATTLE PASS\n";
