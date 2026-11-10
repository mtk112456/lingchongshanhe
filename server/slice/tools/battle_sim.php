<?php
declare(strict_types=1);

/**
 * 自动战斗原型 · 确定性模拟
 *
 * 用法：
 *   php battle_sim.php          跑 4096 组合，输出平衡矩阵
 *   php battle_sim.php demo     输出一场示例战斗的 JSON 回放
 *
 * 设计：
 *   - 3 路，每路 1 攻 1 守；
 *   - 攻方从 0 出发，守方固定在 4，城门在 5；
 *   - 60 tick，无随机数，同部署同结果；
 *   - 服务端算结果，客户端只回放事件。
 */

const TICK_MAX = 60;
const GATE_HP = 16;

const UNIT_TYPES = [
    'atk' => ['name' => '攻', 'hp' => 6,  'atk' => 4, 'interval' => 4, 'range' => 1],
    'def' => ['name' => '守', 'hp' => 12, 'atk' => 1, 'interval' => 5, 'range' => 1, 'armor' => 1],
    'tac' => ['name' => '谋', 'hp' => 4,  'atk' => 1, 'interval' => 4, 'range' => 2, 'debuff' => 1],
    'sup' => ['name' => '运', 'hp' => 7,  'atk' => 2, 'interval' => 5, 'range' => 1, 'heal' => 4],
];

function makeUnit(string $id, string $side, int $lane, string $type): array
{
    $t = UNIT_TYPES[$type];
    return [
        'id' => $id,
        'side' => $side,
        'lane' => $lane,
        'type' => $type,
        'hp' => $t['hp'],
        'max_hp' => $t['hp'],
        'atk' => $t['atk'],
        'interval' => $t['interval'],
        'range' => ($side === 'def' && $type === 'def') ? 2 : $t['range'],
        'armor' => $t['armor'] ?? 0,
        'debuff' => $t['debuff'] ?? 0,
        'heal' => $t['heal'] ?? 0,
        'pos' => $side === 'att' ? 0 : 4,
        'alive' => true,
        'debuff_until' => 0,
    ];
}

function act(string $uid, array &$units, int $lane, int $tick, int &$gate, array &$events): void
{
    $u = &$units[$uid];
    if (!$u['alive']) {
        unset($u);
        return;
    }

    // 运：优先治疗同路残血友军
    if ($u['heal'] > 0) {
        $ally = null;
        $ratio = 0.7;
        foreach ($units as $aid => &$a) {
            if ($a['side'] !== $u['side'] || $a['lane'] !== $lane || !$a['alive'] || $aid === $uid) {
                continue;
            }
            $r = $a['hp'] / $a['max_hp'];
            if ($r < $ratio) {
                $ratio = $r;
                $ally = $aid;
            }
        }
        unset($a);
        if ($ally !== null) {
            $before = $units[$ally]['hp'];
            $units[$ally]['hp'] = min($units[$ally]['max_hp'], $before + $u['heal']);
            $buffed = false;
            if (($units[$ally]['buffs'] ?? 0) < 2) {
                $units[$ally]['atk'] += 1;
                $units[$ally]['buffs'] = ($units[$ally]['buffs'] ?? 0) + 1;
                $buffed = true;
            }
            $events[] = [
                't' => $tick, 'lane' => $lane, 'unit' => $uid, 'action' => 'heal',
                'target' => $ally, 'amount' => $units[$ally]['hp'] - $before,
                'target_hp' => $units[$ally]['hp'], 'buffed' => $buffed,
            ];
            unset($u);
            return;
        }
    }

    // 找同路最近的敌人
    $enemy = null;
    $bestDist = PHP_INT_MAX;
    foreach ($units as $eid => &$e) {
        if ($e['side'] === $u['side'] || $e['lane'] !== $lane || !$e['alive']) {
            continue;
        }
        $d = abs($e['pos'] - $u['pos']);
        if ($d < $bestDist) {
            $bestDist = $d;
            $enemy = $eid;
        }
    }
    unset($e);

    if ($enemy !== null) {
        if ($bestDist <= $u['range']) {
            $dmg = $u['atk'] - $units[$enemy]['armor'];
            if ($u['debuff_until'] >= $tick) {
                $dmg -= 1;
            }
            $dmg = max(1, $dmg);
            $units[$enemy]['hp'] -= $dmg;
            $killed = $units[$enemy]['hp'] <= 0;
            if ($killed) {
                $units[$enemy]['hp'] = 0;
                $units[$enemy]['alive'] = false;
            }
            $events[] = [
                't' => $tick, 'lane' => $lane, 'unit' => $uid, 'action' => 'attack',
                'target' => $enemy, 'damage' => $dmg,
                'target_hp' => $units[$enemy]['hp'], 'killed' => $killed,
            ];
            if ($u['debuff'] > 0 && !$killed) {
                $units[$enemy]['debuff_until'] = $tick + 3;
            }
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

    // 同路没有敌人
    if ($u['side'] === 'att') {
        if ($u['pos'] < 5) {
            $from = $u['pos'];
            $u['pos'] = min(5, $u['pos'] + 1);
            $events[] = [
                't' => $tick, 'lane' => $lane, 'unit' => $uid, 'action' => 'move',
                'from' => $from, 'to' => $u['pos'],
            ];
        } else {
            $dmg = max(1, $u['atk'] - ($u['debuff_until'] >= $tick ? 1 : 0));
            $gate -= $dmg;
            $events[] = [
                't' => $tick, 'lane' => $lane, 'unit' => $uid, 'action' => 'gate',
                'damage' => $dmg, 'gate_hp' => max(0, $gate),
            ];
        }
    }
    unset($u);
}

function gateTurret(array &$units, int $tick, array &$events): void
{
    $target = null;
    $best = -1;
    foreach ($units as $uid => $u) {
        if ($u['side'] !== 'att' || !$u['alive'] || $u['pos'] < 2) {
            continue;
        }
        if ($u['pos'] > $best) {
            $best = $u['pos'];
            $target = $uid;
        }
    }
    if ($target === null) {
        return;
    }
    $dmg = 1;
    $units[$target]['hp'] -= $dmg;
    $killed = $units[$target]['hp'] <= 0;
    if ($killed) {
        $units[$target]['hp'] = 0;
        $units[$target]['alive'] = false;
    }
    $events[] = [
        't' => $tick, 'lane' => $units[$target]['lane'], 'unit' => 'GATE', 'action' => 'turret',
        'target' => $target, 'damage' => $dmg,
        'target_hp' => $units[$target]['hp'], 'killed' => $killed,
    ];
}

function runBattle(array $att, array $def): array
{
    $units = [];
    foreach ([1, 2, 3] as $lane) {
        $units["A$lane"] = makeUnit("A$lane", 'att', $lane, $att[$lane]);
        $units["D$lane"] = makeUnit("D$lane", 'def', $lane, $def[$lane]);
    }
    $gate = GATE_HP;
    $events = [];
    $tick = 0;

    for ($tick = 1; $tick <= TICK_MAX; $tick++) {
        if ($gate > 0 && $tick % 8 === 0) {
            $gate = min(GATE_HP, $gate + 1);
        }
        if ($gate > 0 && $tick % 4 === 0) {
            gateTurret($units, $tick, $events);
        }
        foreach ([1, 2, 3] as $lane) {
            foreach (["A$lane", "D$lane"] as $uid) {
                act($uid, $units, $lane, $tick, $gate, $events);
                if ($gate <= 0) {
                    break 3;
                }
            }
        }
    }

    if ($gate <= 0) {
        $score = 2;
    } elseif ($gate <= 3) {
        $score = 1;
    } elseif ($gate <= 7) {
        $score = 0;
    } else {
        $score = -1;
    }

    return [
        'att' => $att,
        'def' => $def,
        'gate_hp' => max(0, $gate),
        'score' => $score,
        'ticks' => $tick,
        'events' => $events,
        'units' => $units,
    ];
}

function compositions(): array
{
    $types = array_keys(UNIT_TYPES);
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

function demo(): void
{
    $att = [1 => 'atk', 2 => 'tac', 3 => 'sup'];
    $def = [1 => 'def', 2 => 'atk', 3 => 'def'];
    $r = runBattle($att, $def);
    echo json_encode([
        'tick_max' => TICK_MAX,
        'gate_hp' => GATE_HP,
        'att' => $att,
        'def' => $def,
        'result' => [
            'gate_hp' => $r['gate_hp'],
            'score' => $r['score'],
            'ticks' => $r['ticks'],
        ],
        'events' => $r['events'],
    ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT) . PHP_EOL;
}

function matrix(): void
{
    $comps = compositions();
    $rows = [];
    $typeScores = [];
    $typeWins = [];
    $typeCounts = [];

    foreach ($comps as $att) {
        $key = implode('-', $att);
        $rows[$key] = ['scores' => [], 'gates' => [], 'ticks' => [], 'wins' => 0];

        foreach ($comps as $def) {
            $r = runBattle($att, $def);
            $rows[$key]['scores'][] = $r['score'];
            $rows[$key]['gates'][] = $r['gate_hp'];
            $rows[$key]['ticks'][] = $r['ticks'];
            if ($r['score'] >= 1) {
                $rows[$key]['wins']++;
            }
            foreach ($att as $t) {
                $typeScores[$t][] = $r['score'];
                $typeWins[$t][] = $r['score'] >= 1 ? 1 : 0;
                $typeCounts[$t] = ($typeCounts[$t] ?? 0) + 1;
            }
        }
    }

    uasort($rows, fn($a, $b) => avg($b['scores']) <=> avg($a['scores']));

    echo "== 攻方组合排名（对全部 64 种守方）==\n";
    printf("%-14s %8s %8s %8s %8s\n", '组合', '均分', '胜率', '平均城门', '平均tick');
    $i = 0;
    foreach ($rows as $key => $d) {
        if ($i++ >= 12) {
            break;
        }
        printf(
            "%-14s %8.2f %7.1f%% %8.1f %8.1f\n",
            $key,
            avg($d['scores']),
            $d['wins'] / 64 * 100,
            avg($d['gates']),
            avg($d['ticks'])
        );
    }

    echo "\n== 单位类型平均表现 ==\n";
    printf("%-6s %8s %8s %8s\n", '类型', '均分', '胜率', '样本');
    foreach (['atk', 'def', 'tac', 'sup'] as $t) {
        printf(
            "%-6s %8.2f %7.1f%% %8d\n",
            UNIT_TYPES[$t]['name'],
            avg($typeScores[$t] ?? [0]),
            avg($typeWins[$t] ?? [0]) * 100,
            $typeCounts[$t] ?? 0
        );
    }

    $allScores = [];
    $allGates = [];
    foreach ($rows as $d) {
        $allScores = array_merge($allScores, $d['scores']);
        $allGates = array_merge($allGates, $d['gates']);
    }
    echo "\n== 总体 ==\n";
    printf("对局数：%d\n", count($allScores));
    printf("平均分：%.2f\n", avg($allScores));
    printf("平均城门：%.1f\n", avg($allGates));
    printf("攻方胜率（分>=1）：%.1f%%\n", count(array_filter($allScores, fn($s) => $s >= 1)) / count($allScores) * 100);
}

$mode = $argv[1] ?? 'matrix';
if ($mode === 'demo') {
    demo();
} else {
    matrix();
}

