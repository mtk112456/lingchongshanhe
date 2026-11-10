<?php
declare(strict_types=1);

require_once __DIR__ . '/../src/BattleEngine.php';

$failed = 0;

function check(string $name, bool $ok, string $detail = ''): void
{
    global $failed;
    echo ($ok ? '[PASS] ' : '[FAIL] ') . $name . ($detail !== '' ? ' — ' . $detail : '') . PHP_EOL;
    if (!$ok) {
        $failed++;
    }
}

$engine = new BattleEngine();

$att = [
    'general' => 'def',
    'troops' => 1088,
    'composition' => ['cav', 'shield', 'arc'],
    'fire' => false,
];
$def = [
    'general' => 'atk',
    'troops' => 1200,
    'composition' => ['shield', 'spear', 'arc'],
];

// 1. 确定性
$r1 = $engine->resolve($att, $def);
$r2 = $engine->resolve($att, $def);
check(
    '同部署同结果',
    $r1['wall'] === $r2['wall'] && $r1['score'] === $r2['score'] && $r1['ticks'] === $r2['ticks'],
    'wall=' . $r1['wall'] . ' score=' . $r1['score']
);

// 2. 克制
check('骑克盾 ×1.2', abs(BattleEngine::counter('cav', 'shield') - 1.2) < 1e-9);
check('骑被枪克 ×0.85', abs(BattleEngine::counter('cav', 'spear') - 0.85) < 1e-9);
check('盾克弓 ×1.2', abs(BattleEngine::counter('shield', 'arc') - 1.2) < 1e-9);
check('弓克枪 ×1.2', abs(BattleEngine::counter('arc', 'spear') - 1.2) < 1e-9);
check('枪克骑 ×1.2', abs(BattleEngine::counter('spear', 'cav') - 1.2) < 1e-9);

// 3. 站位
$slots = BattleEngine::place(['cav', 'arc', 'shield']);
check('3 个兵种放进 3 路', count($slots) === 3);
check('盾在前排', ($slots[1]['front'] ?? '') === 'shield', json_encode($slots[1], JSON_UNESCAPED_UNICODE));
check('弓在后排', ($slots[1]['back'] ?? '') === 'arc', json_encode($slots[1], JSON_UNESCAPED_UNICODE));

// 4. 器械保护：有前排 vs 无前排
$noFront = $engine->resolve(
    ['general' => 'def', 'troops' => 1088, 'composition' => ['arc', 'arc', 'arc'], 'fire' => false],
    ['general' => 'def', 'troops' => 1200, 'composition' => ['shield', 'shield', 'shield']]
);
$withFront = $engine->resolve(
    ['general' => 'def', 'troops' => 1088, 'composition' => ['shield', 'arc', 'arc'], 'fire' => false],
    ['general' => 'def', 'troops' => 1200, 'composition' => ['shield', 'shield', 'shield']]
);
check(
    '有前排时器械能攻墙',
    $withFront['wall'] < $noFront['wall'],
    'withFront=' . $withFront['wall'] . ' noFront=' . $noFront['wall']
);

// 5. 火攻 +50%
$fire = $engine->resolve(
    ['general' => 'def', 'troops' => 1088, 'composition' => ['shield', 'arc', 'arc'], 'fire' => true],
    ['general' => 'def', 'troops' => 1200, 'composition' => ['shield', 'shield', 'shield']]
);
check(
    '火攻让城墙掉得更多',
    $fire['wall'] < $withFront['wall'],
    'fire=' . $fire['wall'] . ' normal=' . $withFront['wall']
);

// 6. 结果映射
$strong = $engine->resolve(
    ['general' => 'atk', 'troops' => 6000, 'composition' => ['cav', 'cav', 'cav'], 'fire' => true],
    ['general' => 'def', 'troops' => 100, 'composition' => ['arc', 'arc', 'arc']]
);
check('强攻破墙 = +2', $strong['score'] === 2, 'score=' . $strong['score'] . ' wall=' . $strong['wall']);

$weak = $engine->resolve(
    ['general' => 'def', 'troops' => 100, 'composition' => ['arc', 'arc', 'arc'], 'fire' => false],
    ['general' => 'def', 'troops' => 6000, 'composition' => ['shield', 'shield', 'shield']]
);
check('弱攻被挡 = -1', $weak['score'] === -1, 'score=' . $weak['score'] . ' wall=' . $weak['wall']);

// 7. 事件可回放
check('事件非空', count($r1['events']) > 0, 'events=' . count($r1['events']));
check('包含器械攻墙事件', count(array_filter($r1['events'], fn($e) => ($e['unit'] ?? '') === 'SIEGE')) > 0);
check('包含兵种攻击事件', count(array_filter($r1['events'], fn($e) => ($e['action'] ?? '') === 'attack')) > 0);

echo PHP_EOL;
if ($failed > 0) {
    echo "BATTLE_ENGINE FAIL ({$failed})\n";
    exit(1);
}
echo "BATTLE_ENGINE PASS\n";
