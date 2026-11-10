<?php
declare(strict_types=1);

/**
 * 将 · 兵 · 种 · 令 · 确定性模拟
 *
 * 兵力 = 班宠战力（四维 + 等级 + 成长）
 * 3 张将令 = 3 支队伍，平分兵力
 * 兵种 = 步/骑/弓/器，修正攻防，不改兵力
 *
 * 用法：
 *   php battle_sim.php          64×64 兵种组合矩阵
 *   php battle_sim.php general  4×4 将军角色矩阵
 *   php battle_sim.php demo     一场示例战斗的回放 JSON
 */

const TICK_MAX = 60;
const WALL_BASE = 2400;

// 班宠四维（对应 pet_templates）
const PET_BASE_HP = 1000;
const PET_BASE_ATK = 100;
const PET_BASE_DEF = 100;
const PET_BASE_SPD = 100;
const PET_GROWTH = 1.00;
const PET_LEVEL = 10;

const TROOP_TYPES = [
    'inf'   => ['name' => '步', 'atk' => 1.0, 'def' => 1.1, 'interval' => 5, 'range' => 1, 'tactic' => 'hold'],
    'cav'   => ['name' => '骑', 'atk' => 1.0, 'def' => 0.85, 'interval' => 4, 'range' => 1, 'tactic' => 'raid'],
    'arc'   => ['name' => '弓', 'atk' => 1.1, 'def' => 0.75, 'interval' => 5, 'range' => 2, 'tactic' => 'scout'],
    'siege' => ['name' => '器', 'atk' => 1.0, 'def' => 1.0, 'interval' => 5, 'range' => 1, 'tactic' => 'fire'],
];

const GENERALS = [
    'atk' => ['name' => '攻将', 'atk' => 1.10, 'def' => 1.00],
    'def' => ['name' => '守将', 'atk' => 1.00, 'def' => 1.10],
    'tac' => ['name' => '谋将', 'atk' => 1.00, 'def' => 1.00, 'enemy_atk' => 0.95],
    'sup' => ['name' => '运将', 'atk' => 1.00, 'def' => 1.00, 'heal' => 0.05],
];

function petPower(): float
{
    $base = (PET_BASE_HP + PET_BASE_ATK * 2 + PET_BASE_DEF * 2 + PET_BASE_SPD) / 2;
    return $base * (1 + 0.05 * (PET_LEVEL - 1)) * PET_GROWTH;
}

function counter(string $attacker, string $defender): float
{
    if ($attacker === 'siege') {
        return 0.7;
    }
    if ($defender === 'siege') {
        return 1.2;
    }
    $map = [
        'inf' => ['arc' => 1.2, 'cav' => 0.8],
        'cav' => ['inf' => 1.2, 'arc' => 0.8],
        'arc' => ['cav' => 1.2, 'inf' => 0.8],
    ];
    return $map[$attacker][$defender] ?? 1.0;
}

function makeUnit(string $id, string $side, int $lane, string $type, string $general): array
{
    $t = TROOP_TYPES[$type];
    $g = GENERALS[$general];
    $total = petPower();
    $troops = $total / 3;
    if ($side === 'def') {
        $troops *= 1.10;
    }
    $baseAtk = $troops * 0.05 + 10;

    return [
        'id' => $id,
        'side' => $side,
        'lane' => $lane,
        'type' => $type,
        'general' => $general,
        'troops' => $troops,
        'max_troops' => $troops,
        'atk' => $baseAtk * $t['atk'] * ($g['atk'] ?? 1.0),
        'def_mult' => $t['def'] * ($g['def'] ?? 1.0),
        'interval' => $t['interval'],
        'range' => $side === 'def' ? max($t['range'], 2) : $t['range'],
        'tactic' => $t['tactic'],
        'pos' => $side === 'att' ? 0 : 4,
        'alive' => true,
    ];
}

function attackMultiplier(array $u, int $tick, string $targetType): float
{
    $m = 1.0;
    if ($u['tactic'] === 'raid' && $tick <= 10) {
        $m *= 1.2;
    }
    return $m * counter($u['type'], $targetType);
}

function act(string $uid, array &$units, int $lane, int $tick, float &$wall, array &$events): void
{
    $u = &$units[$uid];
    if (!$u['alive']) {
        unset($u);
        return;
    }

    // 运将光环：每 15 tick 回 5%
    if ($u['general'] === 'sup' && $tick % 15 === 0) {
        $heal = $u['max_troops'] * 0.05;
        $before = $u['troops'];
        $u['troops'] = min($u['max_troops'], $u['troops'] + $heal);
        $events[] = [
            't' => $tick, 'lane' => $lane, 'unit' => $uid, 'action' => 'general_heal',
            'amount' => round($u['troops'] - $before), 'troops' => round($u['troops']),
        ];
    }

    $enemy = null;
    $best = PHP_INT_MAX;
    foreach ($units as $eid => &$e) {
        if ($e['side'] === $u['side'] || $e['lane'] !== $lane || !$e['alive']) {
            continue;
        }
        $d = abs($e['pos'] - $u['pos']);
        if ($d < $best) {
            $best = $d;
            $enemy = $eid;
        }
    }
    unset($e);

    if ($enemy !== null) {
        if ($best <= $u['range']) {
            $dmg = $u['atk'] * attackMultiplier($u, $tick, $units[$enemy]['type']);
            $dmg /= max(0.5, $units[$enemy]['def_mult']);
            $units[$enemy]['troops'] -= $dmg;
            $killed = $units[$enemy]['troops'] <= 0;
            if ($killed) {
                $units[$enemy]['troops'] = 0;
                $units[$enemy]['alive'] = false;
            }
            $events[] = [
                't' => $tick, 'lane' => $lane, 'unit' => $uid, 'action' => 'attack',
                'target' => $enemy, 'damage' => round($dmg),
                'target_troops' => round($units[$enemy]['troops']), 'killed' => $killed,
            ];
        } elseif ($u['side'] === 'att') {
            $next = min($units[$enemy]['pos'] - 1, $u['pos'] + 1);
            if ($next > $u['pos']) {
                $from = $u['pos'];
                $u['pos'] = $next;
                $events[] = [
                    't' => $tick, 'lane' => $lane, 'unit' => $uid, 'action' => 'move',
                    'from' => $from, 'to' => $next,
                ];
            }
        }
        unset($u);
        return;
    }

    if ($u['side'] === 'att') {
        if ($u['pos'] < 5) {
            $from = $u['pos'];
            $u['pos'] = min(5, $u['pos'] + 1);
            $events[] = [
                't' => $tick, 'lane' => $lane, 'unit' => $uid, 'action' => 'move',
                'from' => $from, 'to' => $u['pos'],
            ];
        } else {
            $m = $u['type'] === 'siege' ? 2.0 : 1.0;
            if ($u['tactic'] === 'fire') {
                $m *= 1.5;
            }
            $dmg = $u['atk'] * $m;
            $wall -= $dmg;
            $events[] = [
                't' => $tick, 'lane' => $lane, 'unit' => $uid, 'action' => 'wall',
                'damage' => round($dmg), 'wall' => max(0, round($wall)),
            ];
        }
    }
    unset($u);
}

function runBattle(array $attComp, string $attGeneral, array $defComp, string $defGeneral, ?float $wall = null): array
{
    $wall = $wall ?? WALL_BASE;
    $units = [];
    foreach ([1, 2, 3] as $lane) {
        $units["A$lane"] = makeUnit("A$lane", 'att', $lane, $attComp[$lane], $attGeneral);
        $units["D$lane"] = makeUnit("D$lane", 'def', $lane, $defComp[$lane], $defGeneral);
    }

    // 谋将：敌方全军攻击 -5%
    if ($attGeneral === 'tac') {
        foreach ($units as &$u) {
            if ($u['side'] === 'def') $u['atk'] *= 0.95;
        }
        unset($u);
    }
    if ($defGeneral === 'tac') {
        foreach ($units as &$u) {
            if ($u['side'] === 'att') $u['atk'] *= 0.95;
        }
        unset($u);
    }

    $events = [];
    $tick = 0;
    for ($tick = 1; $tick <= TICK_MAX; $tick++) {
        foreach ([1, 2, 3] as $lane) {
            foreach (["D$lane", "A$lane"] as $uid) {
                act($uid, $units, $lane, $tick, $wall, $events);
                if ($wall <= 0) {
                    break 3;
                }
            }
        }
    }

    $ratio = $wall / WALL_BASE;
    if ($wall <= 0) {
        $score = 2;
    } elseif ($ratio < 0.5) {
        $score = 1;
    } elseif ($ratio < 0.8) {
        $score = 0;
    } else {
        $score = -1;
    }

    return [
        'att' => $attComp,
        'att_general' => $attGeneral,
        'def' => $defComp,
        'def_general' => $defGeneral,
        'wall' => max(0, round($wall)),
        'score' => $score,
        'ticks' => $tick,
        'events' => $events,
    ];
}

function compositions(): array
{
    $types = array_keys(TROOP_TYPES);
    $out = [];
    foreach ($types as $a) {
        foreach ($types as $b) {
            foreach ($types as $c) {
                $out[] = [1 => $a, 2 => $b, 3 => $c];
            }
        }
    }
    return $out;
}

function avg(array $xs): float
{
    return count($xs) === 0 ? 0.0 : array_sum($xs) / count($xs);
}

function matrix(): void
{
    $comps = compositions();
    $rows = [];
    $typeScores = [];
    $typeWins = [];
    $allScores = [];
    $allWalls = [];
    $allTicks = [];

    foreach ($comps as $att) {
        $key = implode('-', array_map(fn($t) => TROOP_TYPES[$t]['name'], $att));
        $rows[$key] = ['scores' => [], 'walls' => [], 'ticks' => [], 'wins' => 0];
        foreach ($comps as $def) {
            $r = runBattle($att, 'def', $def, 'def');
            $rows[$key]['scores'][] = $r['score'];
            $rows[$key]['walls'][] = $r['wall'];
            $rows[$key]['ticks'][] = $r['ticks'];
            $rows[$key]['wins'] += $r['score'] >= 1 ? 1 : 0;
            $allScores[] = $r['score'];
            $allWalls[] = $r['wall'];
            $allTicks[] = $r['ticks'];
            foreach ($att as $t) {
                $typeScores[$t][] = $r['score'];
                $typeWins[$t][] = $r['score'] >= 1 ? 1 : 0;
            }
        }
    }

    uasort($rows, fn($a, $b) => avg($b['scores']) <=> avg($a['scores']));

    echo "== 攻方编成排名（对全部 64 种守方，双方守将）==\n";
    printf("%-10s %8s %8s %8s %8s\n", '编成', '均分', '胜率', '平均城墙', '平均tick');
    $i = 0;
    foreach ($rows as $key => $d) {
        if ($i++ >= 12) break;
        printf("%-10s %8.2f %7.1f%% %8.0f %8.1f\n", $key, avg($d['scores']), $d['wins'] / 64 * 100, avg($d['walls']), avg($d['ticks']));
    }

    echo "\n== 兵种平均表现 ==\n";
    printf("%-6s %8s %8s\n", '兵种', '均分', '胜率');
    foreach (['inf', 'cav', 'arc', 'siege'] as $t) {
        printf("%-6s %8.2f %7.1f%%\n", TROOP_TYPES[$t]['name'], avg($typeScores[$t] ?? [0]), avg($typeWins[$t] ?? [0]) * 100);
    }

    echo "\n== 总体 ==\n";
    printf("宠物战力：%.0f（%.1f 级）\n", petPower(), PET_LEVEL);
    printf("每队兵力：%.0f\n", petPower() / 3);
    printf("对局数：%d\n", count($allScores));
    printf("平均分：%.2f\n", avg($allScores));
    printf("平均城墙：%.0f / %d\n", avg($allWalls), WALL_BASE);
    printf("平均时长：%.1f tick\n", avg($allTicks));
    printf("攻方胜率（分>=1）：%.1f%%\n", count(array_filter($allScores, fn($s) => $s >= 1)) / count($allScores) * 100);
}

function generalMatrix(): void
{
    $comp = [1 => 'inf', 2 => 'cav', 3 => 'arc'];
    $roles = array_keys(GENERALS);
    echo "== 将军角色矩阵（固定 步-骑-弓 编成，各 200 局）==\n";
    printf("%-8s", '攻\\守');
    foreach ($roles as $r) printf("%8s", GENERALS[$r]['name']);
    echo "\n";
    foreach ($roles as $a) {
        printf("%-8s", GENERALS[$a]['name']);
        foreach ($roles as $d) {
            $wins = 0;
            $n = 200;
            for ($i = 0; $i < $n; $i++) {
                $r = runBattle($comp, $a, $comp, $d);
                $wins += $r['score'] >= 1 ? 1 : 0;
            }
            printf("%7.1f%%", $wins / $n * 100);
        }
        echo "\n";
    }
}

function demo(): void
{
    $r = runBattle(
        [1 => 'cav', 2 => 'inf', 3 => 'siege'],
        'def',
        [1 => 'inf', 2 => 'inf', 3 => 'arc'],
        'atk'
    );
    echo json_encode([
        'tick_max' => TICK_MAX,
        'pet_power' => round(petPower()),
        'troops_per_lane' => round(petPower() / 3),
        'wall_base' => WALL_BASE,
        'att' => $r['att'],
        'att_general' => $r['att_general'],
        'def' => $r['def'],
        'def_general' => $r['def_general'],
        'result' => ['wall' => $r['wall'], 'score' => $r['score'], 'ticks' => $r['ticks']],
        'events' => $r['events'],
    ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT) . PHP_EOL;
}

$mode = $argv[1] ?? 'matrix';
if ($mode === 'demo') {
    demo();
} elseif ($mode === 'general') {
    generalMatrix();
} else {
    matrix();
}
