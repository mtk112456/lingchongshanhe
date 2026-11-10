<?php
declare(strict_types=1);

require_once __DIR__ . '/../src/BattleEngine.php';

/**
 * 4 兵种 × 3 路 × 带/不带火攻，全部编成矩阵。
 *
 * 用法：php server/slice/tools/battle_matrix.php
 */

const ATT_TROOPS = 1087.5 * 1.20; // 攻方集中兵力
const DEF_TROOPS = 1200.0 * 1.10; // 守方城防加成

$types = array_keys(BattleEngine::TYPES);
$comps = [];
foreach ($types as $a) {
    foreach ($types as $b) {
        foreach ($types as $c) {
            $comps[] = [$a, $b, $c];
        }
    }
}

$engine = new BattleEngine();
$rows = [];
$typeScores = [];
$typeWins = [];
$overall = ['scores' => [], 'walls' => [], 'ticks' => []];
$fireStats = [
    'off' => ['scores' => [], 'wins' => 0, 'n' => 0],
    'on' => ['scores' => [], 'wins' => 0, 'n' => 0],
];

foreach ($comps as $att) {
    foreach ([false, true] as $fire) {
        $key = implode('-', $att) . ($fire ? '+火' : '');
        $rows[$key] = ['scores' => [], 'walls' => [], 'ticks' => [], 'wins' => 0];
        foreach ($comps as $def) {
            $r = $engine->resolve(
                ['general' => 'def', 'troops' => ATT_TROOPS, 'composition' => $att, 'fire' => $fire],
                ['general' => 'def', 'troops' => DEF_TROOPS, 'composition' => $def]
            );
            $rows[$key]['scores'][] = $r['score'];
            $rows[$key]['walls'][] = $r['wall'];
            $rows[$key]['ticks'][] = $r['ticks'];
            $rows[$key]['wins'] += $r['score'] >= 1 ? 1 : 0;

            $overall['scores'][] = $r['score'];
            $overall['walls'][] = $r['wall'];
            $overall['ticks'][] = $r['ticks'];

            $bucket = $fire ? 'on' : 'off';
            $fireStats[$bucket]['scores'][] = $r['score'];
            $fireStats[$bucket]['wins'] += $r['score'] >= 1 ? 1 : 0;
            $fireStats[$bucket]['n']++;

            foreach ($att as $t) {
                $typeScores[$t][] = $r['score'];
                $typeWins[$t][] = $r['score'] >= 1 ? 1 : 0;
            }
        }
    }
}

function avg(array $xs): float
{
    return count($xs) === 0 ? 0.0 : array_sum($xs) / count($xs);
}

uasort($rows, fn($a, $b) => avg($b['scores']) <=> avg($a['scores']));

echo "== 攻方编成排名（4 兵种 × 3 路，全部 64 种守方）==\n";
printf("%-18s %8s %8s %8s %8s\n", '编成', '均分', '胜率', '平均城墙', '平均tick');
$i = 0;
foreach ($rows as $key => $d) {
    if ($i++ >= 10) break;
    printf("%-18s %8.2f %7.1f%% %8.0f %8.1f\n", $key, avg($d['scores']), $d['wins'] / count($comps) * 100, avg($d['walls']), avg($d['ticks']));
}

echo "\n== 攻方编成垫底 ==\n";
printf("%-18s %8s %8s %8s %8s\n", '编成', '均分', '胜率', '平均城墙', '平均tick');
$i = 0;
foreach (array_reverse($rows, true) as $key => $d) {
    if ($i++ >= 5) break;
    printf("%-18s %8.2f %7.1f%% %8.0f %8.1f\n", $key, avg($d['scores']), $d['wins'] / count($comps) * 100, avg($d['walls']), avg($d['ticks']));
}

echo "\n== 兵种平均表现 ==\n";
printf("%-6s %8s %8s\n", '兵种', '均分', '胜率');
foreach (['cav', 'shield', 'arc', 'spear'] as $t) {
    printf("%-6s %8.2f %7.1f%%\n", $t, avg($typeScores[$t] ?? [0]), avg($typeWins[$t] ?? [0]) * 100);
}

echo "\n== 火攻 ==\n";
foreach (['off' => '不带', 'on' => '带火攻'] as $k => $label) {
    $s = $fireStats[$k];
    printf("%-8s 均分 %.2f  胜率 %.1f%%  样本 %d\n", $label, avg($s['scores']), $s['wins'] / max(1, $s['n']) * 100, $s['n']);
}

$wins = count(array_filter($overall['scores'], fn($s) => $s >= 1));
echo "\n== 总体 ==\n";
printf("对局数：%d\n", count($overall['scores']));
printf("平均分：%.2f\n", avg($overall['scores']));
printf("平均城墙：%.0f / %d\n", avg($overall['walls']), BattleEngine::WALL_BASE);
printf("平均时长：%.1f tick\n", avg($overall['ticks']));
printf("攻方胜率（分>=1）：%.1f%%\n", $wins / count($overall['scores']) * 100);
printf("+2 比例：%.1f%%\n", count(array_filter($overall['scores'], fn($s) => $s === 2)) / count($overall['scores']) * 100);
printf(" 0 比例：%.1f%%\n", count(array_filter($overall['scores'], fn($s) => $s === 0)) / count($overall['scores']) * 100);
printf("-1 比例：%.1f%%\n", count(array_filter($overall['scores'], fn($s) => $s === -1)) / count($overall['scores']) * 100);
