<?php
declare(strict_types=1);

require_once __DIR__ . '/../bootstrap.php';

$failed = 0;
function check(string $name, bool $ok, string $detail = ''): void
{
    global $failed;
    echo ($ok ? '[PASS] ' : '[FAIL] ') . $name . ($detail !== '' ? ' — ' . $detail : '') . PHP_EOL;
    if (!$ok) {
        $failed++;
    }
}

$same = [['type' => 'cav'], ['type' => 'cav'], ['type' => 'cav']];
$mixed = [['type' => 'cav'], ['type' => 'shield'], ['type' => 'arc']];
$two = [['type' => 'cav'], ['type' => 'cav'], ['type' => 'shield']];
check('3 同兵种 = same', BattleEngine::formation($same) === 'same');
check('3 不同兵种 = mixed', BattleEngine::formation($mixed) === 'mixed');
check('2+1 = standard', BattleEngine::formation($two) === 'standard');

function battle(array $attTypes, array $defTypes): array
{
    $a = ['general' => 'atk', 'teams' => []];
    foreach ($attTypes as $i => $t) {
        $a['teams'][] = ['type' => $t, 'troops' => 300, 'lane' => $i + 1, 'row' => $i === 2 ? 'back' : 'front'];
    }
    $d = ['general' => 'def', 'teams' => []];
    foreach ($defTypes as $i => $t) {
        $d['teams'][] = ['type' => $t, 'troops' => 300, 'lane' => $i + 1, 'row' => $i === 2 ? 'back' : 'front'];
    }
    return (new BattleEngine())->resolve($a, $d);
}

$r = battle(['cav', 'cav', 'cav'], ['cav', 'cav', 'cav']);
check('同兵种双方标记', $r['att_formation'] === 'same' && $r['def_formation'] === 'same');

$r = battle(['cav', 'shield', 'arc'], ['shield', 'spear', 'arc']);
check('混编双方标记', $r['att_formation'] === 'mixed' && $r['def_formation'] === 'mixed');

$r = battle(['cav', 'cav', 'shield'], ['shield', 'spear', 'arc']);
check('2+1 无标记', $r['att_formation'] === 'standard');

echo PHP_EOL;
if ($failed > 0) {
    echo "FORMATION FAIL ({$failed})\n";
    exit(1);
}
echo "FORMATION PASS\n";
