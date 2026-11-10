<?php
declare(strict_types=1);

/**
 * 将 · 兵 · 种 · 械 · 3 路 × 2 排
 *
 * 4 个兵种：骑 / 盾 / 弓 / 枪
 * 循环：骑 > 盾 > 弓 > 枪 > 骑
 * 器械：攻城装备，不是兵种，不参与克制；不占兵种位
 * 器械被保护时攻墙；前排全灭则器械失效
 *
 * 用法：
 *   php battle_sim.php          4 兵种 × 2（带/不带器械）矩阵
 *   php battle_sim.php demo     示例回放 JSON
 */

const TICK_MAX = 60;
const WALL_BASE = 900;

const PET_BASE_HP = 1000;
const PET_BASE_ATK = 100;
const PET_BASE_DEF = 100;
const PET_BASE_SPD = 100;
const PET_GROWTH = 1.00;
const PET_LEVEL = 10;

const TROOP_TYPES = [
    'cav'    => ['name' => '骑', 'atk' => 1.15, 'def' => 0.85, 'interval' => 4, 'row' => 'front'],
    'shield' => ['name' => '盾', 'atk' => 0.85, 'def' => 1.25, 'interval' => 5, 'row' => 'front'],
    'arc'    => ['name' => '弓', 'atk' => 1.45, 'def' => 0.80, 'interval' => 5, 'row' => 'back'],
    'spear'  => ['name' => '枪', 'atk' => 1.05, 'def' => 1.00, 'interval' => 5, 'row' => 'front'],
];

const SIEGE = ['interval' => 6, 'wall_mult' => 1.5];

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
    $map = [
        'cav'    => ['shield' => 1.2, 'spear' => 0.85],
        'shield' => ['arc' => 1.2, 'cav' => 0.85],
        'arc'    => ['spear' => 1.2, 'shield' => 0.85],
        'spear'  => ['cav' => 1.2, 'arc' => 0.85],
    ];
    return $map[$attacker][$defender] ?? 1.0;
}

function place(array $comp): array
{
    $front = [];
    $back = [];
    foreach ($comp as $type) {
        if (TROOP_TYPES[$type]['row'] === 'front') {
            $front[] = $type;
        } else {
            $back[] = $type;
        }
    }

    $slots = [1 => [], 2 => [], 3 => []];
    usort($front, fn($a, $b) => TROOP_TYPES[$b]['def'] <=> TROOP_TYPES[$a]['def']);
    $lane = 1;
    foreach ($front as $type) {
        if ($lane > 3) break;
        $slots[$lane]['front'] = $type;
        $lane++;
    }

    foreach ($back as $type) {
        $placed = false;
        for ($l = 1; $l <= 3; $l++) {
            if (!empty($slots[$l]['front']) && empty($slots[$l]['back'])) {
                $slots[$l]['back'] = $type;
                $placed = true;
                break;
            }
        }
        if (!$placed) {
            for ($l = 1; $l <= 3; $l++) {
                if (empty($slots[$l]['front']) && empty($slots[$l]['back'])) {
                    $slots[$l]['back'] = $type;
                    break;
                }
            }
        }
    }

    return $slots;
}

function makeUnit(string $id, string $side, int $lane, string $row, string $type, string $general): array
{
    $t = TROOP_TYPES[$type];
    $g = GENERALS[$general];
    $troops = petPower() / 3;
    if ($side === 'def') {
        $troops *= 1.10;
    } else {
        $troops *= 1.20;
    }
    $baseAtk = $troops * 0.05 + 10;

    return [
        'id' => $id,
        'side' => $side,
        'lane' => $lane,
        'row' => $row,
        'type' => $type,
        'general' => $general,
        'troops' => $troops,
        'max_troops' => $troops,
        'atk' => $baseAtk * $t['atk'] * ($g['atk'] ?? 1.0),
        'def_mult' => $t['def'] * ($g['def'] ?? 1.0),
        'interval' => $t['interval'],
        'pos' => $side === 'att' ? ($row === 'front' ? 1 : 0) : ($row === 'front' ? 3 : 4),
        'alive' => true,
    ];
}

function unitAt(array &$units, string $side, int $lane, string $row): ?array
{
    $id = ($side === 'att' ? 'A' : 'D') . $lane . ($row === 'front' ? 'F' : 'B');
    if (!isset($units[$id]) || !$units[$id]['alive']) {
        return null;
    }
    return $units[$id];
}

function damageTo(array &$units, string $targetId, float $dmg, int $tick, array &$events, string $sourceId): void
{
    $units[$targetId]['troops'] -= $dmg;
    $killed = $units[$targetId]['troops'] <= 0;
    if ($killed) {
        $units[$targetId]['troops'] = 0;
        $units[$targetId]['alive'] = false;
    }
    $events[] = [
        't' => $tick,
        'lane' => $units[$targetId]['lane'],
        'unit' => $sourceId,
        'action' => 'attack',
        'target' => $targetId,
        'damage' => round($dmg),
        'target_troops' => round($units[$targetId]['troops']),
        'killed' => $killed,
    ];
}

function act(string $uid, array &$units, int $tick, float &$wall, array &$events): void
{
    $u = &$units[$uid];
    if (!$u['alive'] || $tick % $u['interval'] !== 0) {
        unset($u);
        return;
    }

    $side = $u['side'];
    $enemySide = $side === 'att' ? 'def' : 'att';
    $lane = $u['lane'];

    // 近战在后排：前排没死就待命；前排死了就补位
    if ($u['row'] === 'back' && in_array($u['type'], ['cav', 'shield', 'spear'], true)) {
        $front = unitAt($units, $side, $lane, 'front');
        if ($front !== null) {
            unset($u);
            return;
        }
        $u['row'] = 'front';
        $u['pos'] = $side === 'att' ? 1 : 3;
        $events[] = [
            't' => $tick, 'lane' => $lane, 'unit' => $uid,
            'action' => 'advance_row', 'row' => 'front',
        ];
    }

    // 选目标：敌前 > 敌后 > 墙
    $target = unitAt($units, $enemySide, $lane, 'front');
    if ($target === null) {
        $target = unitAt($units, $enemySide, $lane, 'back');
    }

    if ($target !== null) {
        $dmg = $u['atk'] * counter($u['type'], $target['type']);
        $dmg /= max(0.5, $target['def_mult']);
        damageTo($units, $target['id'], $dmg, $tick, $events, $uid);
        unset($u);
        return;
    }

    if ($side === 'att') {
        $dmg = $u['atk'];
        $wall -= $dmg;
        $events[] = [
            't' => $tick, 'lane' => $lane, 'unit' => $uid, 'action' => 'wall',
            'damage' => round($dmg), 'wall' => max(0, round($wall)),
        ];
    }
    unset($u);
}

function runBattle(array $attComp, string $attGeneral, array $defComp, string $defGeneral, bool $attSiege = false, ?float $wall = null): array
{
    $wall = $wall ?? WALL_BASE;
    $attSlots = place($attComp);
    $defSlots = place($defComp);

    $units = [];
    foreach ([1, 2, 3] as $lane) {
        foreach (['front', 'back'] as $row) {
            if (isset($attSlots[$lane][$row])) {
                $id = "A{$lane}" . ($row === 'front' ? 'F' : 'B');
                $units[$id] = makeUnit($id, 'att', $lane, $row, $attSlots[$lane][$row], $attGeneral);
            }
            if (isset($defSlots[$lane][$row])) {
                $id = "D{$lane}" . ($row === 'front' ? 'F' : 'B');
                $units[$id] = makeUnit($id, 'def', $lane, $row, $defSlots[$lane][$row], $defGeneral);
            }
        }
    }

    // 谋将：敌方攻击 -5%
    foreach ($units as &$u) {
        if ($attGeneral === 'tac' && $u['side'] === 'def') $u['atk'] *= 0.95;
        if ($defGeneral === 'tac' && $u['side'] === 'att') $u['atk'] *= 0.95;
    }
    unset($u);

    $events = [];
    $siegeAtk = (petPower() / 3 * 0.05 + 10) * SIEGE['wall_mult'];
    $tick = 0;

    for ($tick = 1; $tick <= TICK_MAX; $tick++) {
        // 器械：攻方还有任意前排存活，就安全攻墙
        if ($attSiege && $tick % SIEGE['interval'] === 0) {
            $hasFront = false;
            foreach ($units as $u) {
                if ($u['side'] === 'att' && $u['alive'] && $u['row'] === 'front') {
                    $hasFront = true;
                    break;
                }
            }
            if ($hasFront) {
                $wall -= $siegeAtk;
                $events[] = [
                    't' => $tick, 'unit' => 'SIEGE', 'action' => 'wall',
                    'damage' => round($siegeAtk), 'wall' => max(0, round($wall)),
                ];
            }
        }

        foreach (array_keys($units) as $uid) {
            if ($wall <= 0) break 2;
            act($uid, $units, $tick, $wall, $events);
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
        'att_siege' => $attSiege,
        'att_slots' => $attSlots,
        'def_slots' => $defSlots,
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
    $siegeStats = [
        'with' => ['scores' => [], 'wins' => 0, 'n' => 0],
        'without' => ['scores' => [], 'wins' => 0, 'n' => 0],
    ];
    $allScores = [];
    $allWalls = [];
    $allTicks = [];

    foreach ($comps as $att) {
        foreach ([false, true] as $siege) {
            $key = implode('-', $att) . ($siege ? '+械' : '');
            $rows[$key] = ['scores' => [], 'walls' => [], 'ticks' => [], 'wins' => 0];

            foreach ($comps as $def) {
                $r = runBattle($att, 'def', $def, 'def', $siege);
                $rows[$key]['scores'][] = $r['score'];
                $rows[$key]['walls'][] = $r['wall'];
                $rows[$key]['ticks'][] = $r['ticks'];
                $rows[$key]['wins'] += $r['score'] >= 1 ? 1 : 0;

                $bucket = $siege ? 'with' : 'without';
                $siegeStats[$bucket]['scores'][] = $r['score'];
                $siegeStats[$bucket]['wins'] += $r['score'] >= 1 ? 1 : 0;
                $siegeStats[$bucket]['n']++;

                $allScores[] = $r['score'];
                $allWalls[] = $r['wall'];
                $allTicks[] = $r['ticks'];

                foreach ($att as $t) {
                    $typeScores[$t][] = $r['score'];
                    $typeWins[$t][] = $r['score'] >= 1 ? 1 : 0;
                }
            }
        }
    }

    uasort($rows, fn($a, $b) => avg($b['scores']) <=> avg($a['scores']));

    echo "== 攻方编成排名（4 兵种 × 带/不带器械，双方守将）==\n";
    printf("%-16s %8s %8s %8s %8s\n", '编成', '均分', '胜率', '平均城墙', '平均tick');
    $i = 0;
    foreach ($rows as $key => $d) {
        if ($i++ >= 12) break;
        printf("%-16s %8.2f %7.1f%% %8.0f %8.1f\n", $key, avg($d['scores']), $d['wins'] / count($comps) * 100, avg($d['walls']), avg($d['ticks']));
    }

    echo "\n== 带器械 vs 不带 ==\n";
    foreach (['without' => '不带', 'with' => '带器械'] as $k => $label) {
        $s = $siegeStats[$k];
        printf("%-8s 均分 %.2f  胜率 %.1f%%  样本 %d\n", $label, avg($s['scores']), $s['wins'] / max(1, $s['n']) * 100, $s['n']);
    }

    echo "\n== 兵种平均表现 ==\n";
    printf("%-6s %8s %8s\n", '兵种', '均分', '胜率');
    foreach (['cav', 'shield', 'arc', 'spear'] as $t) {
        printf("%-6s %8.2f %7.1f%%\n", $t, avg($typeScores[$t] ?? [0]), avg($typeWins[$t] ?? [0]) * 100);
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

function demo(): void
{
    $r = runBattle(
        [1 => 'cav', 2 => 'shield', 3 => 'arc'],
        'def',
        [1 => 'shield', 2 => 'spear', 3 => 'arc'],
        'atk',
        true
    );
    echo json_encode([
        'tick_max' => TICK_MAX,
        'pet_power' => round(petPower()),
        'troops_per_lane' => round(petPower() / 3),
        'wall_base' => WALL_BASE,
        'att' => $r['att'],
        'att_general' => $r['att_general'],
        'att_siege' => $r['att_siege'],
        'att_slots' => $r['att_slots'],
        'def' => $r['def'],
        'def_general' => $r['def_general'],
        'def_slots' => $r['def_slots'],
        'result' => ['wall' => $r['wall'], 'score' => $r['score'], 'ticks' => $r['ticks']],
        'events' => array_slice($r['events'], 0, 40),
    ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT) . PHP_EOL;
}

$mode = $argv[1] ?? 'matrix';
if ($mode === 'demo') {
    demo();
} else {
    matrix();
}
