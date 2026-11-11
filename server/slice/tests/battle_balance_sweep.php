<?php
declare(strict_types=1);

require_once __DIR__ . '/../src/BattleEngine.php';

/**
 * 战斗数值扫描（无数据库）
 *
 * 目的：在 8–12 人试跑前回答四个问题
 *   1. 城防是否过脆：不同兵力优势下攻方破墙率有多高
 *   2. 支援是否过强：1.20（无支援）→ 1.38 / 1.50 / 1.56（满支援）后破墙率涨多少
 *   3. 克制是否影响过小：×1.2 / ×0.85 在实战伤害里还剩多少
 *   4. 混编 +5% 是否值得：混编与三种专精的差距
 *
 * 直接 new BattleEngine()，不连数据库、不写库、不改引擎。
 *
 * 组合：
 *   攻方兵力 900 / 1200 / 1500 / 1800
 *   守方兵力 800 / 1320 / 1500
 *   攻方编成 混编 / 3骑 / 3弓 / 3盾
 *   守方编成 盾枪弓 / 3盾 / 3弓 / 3骑
 *   火攻 无 / 有
 *   支援 1.20 / 1.38 / 1.50 / 1.56
 *   = 4×3×4×4×2×4 = 1536 格，每格 100 次 = 153600 局
 *
 * 每格的 100 次不是重复同一输入（引擎确定性，跑 1 次就够），而是用固定
 * seed 生成 100 种合法变体：
 *   - 分兵：三队兵力在均分基础上 ±18% 抖动，总和不变（模拟三只班宠战力不同）
 *   - 站位：换路；混编额外 50% 走"弓躲盾后 + 空一路"（两种都是真实出令能摆出的）
 * 同一 PHP 版本 + 同一 seed ⇒ 完全可复现。
 *
 * 用法：
 *   php server/slice/tests/battle_balance_sweep.php
 */

const SWEEP_SAMPLES = 100;
const SWEEP_SEED = 20261111;

const SWEEP_ATT_TROOPS = [900, 1200, 1500, 1800];
const SWEEP_DEF_TROOPS = [800, 1320, 1500];

const SWEEP_ATT_COMPS = [
    '混编' => ['cav', 'shield', 'arc'],
    '3骑' => ['cav', 'cav', 'cav'],
    '3弓' => ['arc', 'arc', 'arc'],
    '3盾' => ['shield', 'shield', 'shield'],
];

const SWEEP_DEF_COMPS = [
    '盾枪弓' => ['shield', 'spear', 'arc'],
    '3盾' => ['shield', 'shield', 'shield'],
    '3弓' => ['arc', 'arc', 'arc'],
    '3骑' => ['cav', 'cav', 'cav'],
];

const SWEEP_SUPPORTS = [
    '1.20' => 1.20, // 无支援（仅集中兵力 ×1.20）
    '1.38' => 1.38, // 支援 +15%（1.20 × 1.15），候选上限
    '1.50' => 1.50, // 约 12–13 人支援（+25%）
    '1.56' => 1.56, // 支援 +30% 满（1.20 × 1.30）
];

const SWEEP_GENERAL = 'def'; // 双方都用守将（+10% 防），与现有报告口径一致

const SWEEP_ATT_LABEL = [
    'cav' => '骑',
    'shield' => '盾',
    'arc' => '弓',
    'spear' => '枪',
];

// ---------------------------------------------------------------------------
// 结算容器
// ---------------------------------------------------------------------------

function sweepBucket(): array
{
    return [
        'n' => 0,
        'break' => 0,
        'scores' => [2 => 0, 1 => 0, 0 => 0, -1 => 0],
        'wall' => 0.0,
        'ticks' => 0.0,
        'margin' => [0, 0, 0, 0, 0, 0, 0],
        'idle' => 0,          // 守军有兵、攻方空路的路数
        'full_ticks' => 0,    // 打满 60 回合的局数
        'siege_hits' => 0,    // 器械攻墙次数
        'siege_dmg' => 0.0,
        'siege_zero' => 0,    // 整局没有一次器械攻墙
        'unit_wall_dmg' => 0.0, // 单位直接砍墙
        'typed' => 0,         // 有来源/目标兵种的攻击次数
        'damage' => 0.0,      // 这些攻击造成的总伤害
        'counter' => 0,       // 克制命中（×1.2）次数
        'counter_dmg' => 0.0,
        'pairs' => [],        // 克制命中：pair => hits
        'pair_dmg' => [],     // 克制伤害：pair => damage
        'typed_pairs' => [],  // 全部类型攻击：pair => [hits, dmg]
    ];
}

function sweepMerge(array $a, array $b): array
{
    $a['n'] += $b['n'];
    $a['break'] += $b['break'];
    foreach ($b['scores'] as $k => $v) {
        $a['scores'][$k] += $v;
    }
    $a['wall'] += $b['wall'];
    $a['ticks'] += $b['ticks'];
    foreach ($b['margin'] as $i => $v) {
        $a['margin'][$i] += $v;
    }
    $a['idle'] += $b['idle'];
    $a['full_ticks'] += $b['full_ticks'];
    $a['siege_hits'] += $b['siege_hits'];
    $a['siege_dmg'] += $b['siege_dmg'];
    $a['siege_zero'] += $b['siege_zero'];
    $a['unit_wall_dmg'] += $b['unit_wall_dmg'];
    $a['typed'] += $b['typed'];
    $a['damage'] += $b['damage'];
    $a['counter'] += $b['counter'];
    $a['counter_dmg'] += $b['counter_dmg'];
    foreach ($b['pairs'] as $k => $v) {
        $a['pairs'][$k] = ($a['pairs'][$k] ?? 0) + $v;
    }
    foreach ($b['pair_dmg'] as $k => $v) {
        $a['pair_dmg'][$k] = ($a['pair_dmg'][$k] ?? 0.0) + $v;
    }
    foreach ($b['typed_pairs'] as $k => $v) {
        if (!isset($a['typed_pairs'][$k])) {
            $a['typed_pairs'][$k] = ['hits' => 0, 'dmg' => 0.0];
        }
        $a['typed_pairs'][$k]['hits'] += $v['hits'];
        $a['typed_pairs'][$k]['dmg'] += $v['dmg'];
    }
    return $a;
}

function sweepMarginBin(float $wall): int
{
    if ($wall <= 0) {
        return 0;
    }
    $ratio = $wall / BattleEngine::WALL_BASE;
    if ($ratio < 0.10) {
        return 1;
    }
    if ($ratio < 0.20) {
        return 2;
    }
    if ($ratio < 0.30) {
        return 3;
    }
    if ($ratio < 0.50) {
        return 4;
    }
    if ($ratio < 0.80) {
        return 5;
    }
    return 6;
}



/**
 * 锚点画像：攻墙伤害直方图（150 一档）+ 破城时点分布。
 * 非破城局打满 60 tick，D=1500−残余墙 精确；破城局的 D 被截断，统一并入 ≥1500。
 *
 * @return array{dmg:array<int,float>,break_ticks:array<int,int>,break:int,n:int}
 */
function sweepAnchorProfile(
    BattleEngine $engine,
    int $attTroops,
    int $defTroops,
    array $attComp,
    array $defComp,
    float $suppMult,
    int $samples,
    string $seedKey
): array {
    mt_srand((int)(crc32($seedKey) ^ SWEEP_SEED));
    $hist = array_fill(0, 24, 0.0);
    $breakTicks = [0, 0, 0, 0, 0, 0];
    $breaks = 0;
    for ($s = 0; $s < $samples; $s++) {
        $result = $engine->resolve(
            [
                'general' => SWEEP_GENERAL,
                'teams' => sweepTeams($attComp, $attTroops * $suppMult),
                'troops' => $attTroops * $suppMult,
                'fire' => false,
            ],
            [
                'general' => SWEEP_GENERAL,
                'teams' => sweepTeams($defComp, (float)$defTroops),
                'troops' => (float)$defTroops,
            ]
        );
        $damage = 0.0;
        foreach ($result['events'] as $event) {
            if ((string)($event['unit'] ?? '') === 'SIEGE' || ($event['action'] ?? '') === 'wall') {
                $damage += (float)($event['damage'] ?? 0);
            }
        }
        $hist[min(23, (int)floor($damage / 150))]++;

        if ($result['wall'] <= 0) {
            $breaks++;
            $tick = (int)$result['ticks'];
            $index = $tick <= 30 ? 0 : ($tick <= 40 ? 1 : ($tick <= 50 ? 2 : ($tick <= 55 ? 3 : ($tick <= 59 ? 4 : 5))));
            $breakTicks[$index]++;
        }
    }
    return ['dmg' => $hist, 'break_ticks' => $breakTicks, 'break' => $breaks, 'n' => $samples];
}

/**
 * 3 队各占一路；混编 50% 走"弓躲盾后 + 空一路"。
 * 兵力在均分上 ±18% 抖动，总和不变。
 *
 * @param array<int,string> $composition
 * @return array<int,array{type:string,troops:float,lane:int,row:string,card:?string}>
 */
function sweepTeams(array $composition, float $troops, ?string $pattern = null): array
{
    $fronts = [];
    $backs = [];
    foreach ($composition as $type) {
        if (BattleEngine::TYPES[$type]['row'] === 'front') {
            $fronts[] = $type;
        } else {
            $backs[] = $type;
        }
    }

    $lanes = [1, 2, 3];
    shuffle($lanes);

    $placed = [];
    if ($backs === []) {
        foreach ($fronts as $i => $type) {
            $placed[] = ['type' => $type, 'lane' => $lanes[$i], 'row' => 'front'];
        }
    } elseif ($fronts === []) {
        foreach ($backs as $i => $type) {
            $placed[] = ['type' => $type, 'lane' => $lanes[$i], 'row' => 'back'];
        }
    } elseif (count($fronts) === 2 && count($backs) === 1) {
        // 混编：2 前排 + 1 弓
        $frontLanes = [$lanes[0], $lanes[1]];
        foreach ($fronts as $i => $type) {
            $placed[] = ['type' => $type, 'lane' => $frontLanes[$i], 'row' => 'front'];
        }
        $backLane = $pattern === 'stack'
            ? $frontLanes[mt_rand(0, 1)]        // 叠盾：弓躲在前排后面，第三路空
            : ($pattern === 'spread'
                ? $lanes[2]                      // 分路：弓单守一路（后排暴露）
                : (mt_rand(0, 1) === 1 ? $frontLanes[mt_rand(0, 1)] : $lanes[2]));
        $placed[] = ['type' => $backs[0], 'lane' => $backLane, 'row' => 'back'];
    } else {
        // 兜底：按顺序铺路，交给引擎的占位顺延
        $all = array_merge($fronts, $backs);
        foreach ($all as $i => $type) {
            $placed[] = [
                'type' => $type,
                'lane' => $lanes[$i % 3],
                'row' => BattleEngine::TYPES[$type]['row'],
            ];
        }
    }

    $weights = [];
    $totalWeight = 0.0;
    foreach ($placed as $i => $_) {
        $weights[$i] = 1.0 + mt_rand(-180, 180) / 1000;
        $totalWeight += $weights[$i];
    }

    $teams = [];
    foreach ($placed as $i => $slot) {
        $teams[] = [
            'type' => $slot['type'],
            'troops' => $troops * $weights[$i] / $totalWeight,
            'lane' => $slot['lane'],
            'row' => $slot['row'],
            'card' => null,
        ];
    }

    return $teams;
}

function sweepAvg(array $b, string $field): float
{
    return $b['n'] === 0 ? 0.0 : $b[$field] / $b['n'];
}

function sweepPct(int $hits, int $n): float
{
    return $n === 0 ? 0.0 : $hits / $n * 100;
}

function sweepAgg(array $rows, callable $where): array
{
    $acc = sweepBucket();
    foreach ($rows as $row) {
        if (!$where($row)) {
            continue;
        }
        $acc = sweepMerge($acc, $row['b']);
    }
    return $acc;
}

function sweepTypeName(string $type): string
{
    return SWEEP_ATT_LABEL[$type] ?? $type;
}

// ---------------------------------------------------------------------------
// 扫描
// ---------------------------------------------------------------------------

$engine = new BattleEngine();

// 确定性自检
$probeAtt = ['general' => SWEEP_GENERAL, 'troops' => 1200, 'composition' => ['cav', 'shield', 'arc']];
$probeDef = ['general' => SWEEP_GENERAL, 'troops' => 1320, 'composition' => ['shield', 'spear', 'arc']];
$probe1 = $engine->resolve($probeAtt, $probeDef);
$probe2 = $engine->resolve($probeAtt, $probeDef);
$deterministic = $probe1['wall'] === $probe2['wall']
    && $probe1['score'] === $probe2['score']
    && $probe1['ticks'] === $probe2['ticks'];

$rows = [];
$started = microtime(true);

foreach (SWEEP_ATT_TROOPS as $attTroops) {
    foreach (SWEEP_DEF_TROOPS as $defTroops) {
        foreach (SWEEP_ATT_COMPS as $attName => $attComp) {
            foreach (SWEEP_DEF_COMPS as $defName => $defComp) {
                foreach ([0, 1] as $fire) {
                    foreach (SWEEP_SUPPORTS as $supKey => $supMult) {
                        $key = $attTroops . '|' . $defTroops . '|' . $attName . '|' . $defName . '|' . $fire . '|' . $supKey;
                        mt_srand((int)(crc32($key) ^ SWEEP_SEED));

                        $bucket = sweepBucket();
                        for ($s = 0; $s < SWEEP_SAMPLES; $s++) {
                            $attTeams = sweepTeams($attComp, $attTroops * $supMult);
                            $defTeams = sweepTeams($defComp, (float)$defTroops);

                            $result = $engine->resolve(
                                [
                                    'general' => SWEEP_GENERAL,
                                    'teams' => $attTeams,
                                    'troops' => $attTroops * $supMult,
                                    'fire' => $fire === 1,
                                ],
                                [
                                    'general' => SWEEP_GENERAL,
                                    'teams' => $defTeams,
                                    'troops' => (float)$defTroops,
                                ]
                            );

                            $bucket['n']++;
                            $bucket['break'] += $result['score'] === 2 ? 1 : 0;
                            $bucket['scores'][$result['score']]++;
                            $bucket['wall'] += (float)$result['wall'];
                            $bucket['ticks'] += (float)$result['ticks'];
                            $bucket['full_ticks'] += $result['ticks'] >= BattleEngine::TICK_MAX + 1 ? 1 : 0;
                            $bucket['margin'][sweepMarginBin((float)$result['wall'])]++;

                            $idle = 0;
                            foreach ([1, 2, 3] as $lane) {
                                if (!empty($result['def_slots'][$lane]) && empty($result['att_slots'][$lane])) {
                                    $idle++;
                                }
                            }
                            $bucket['idle'] += $idle;

                            $sampleSiege = 0;
                            foreach ($result['events'] as $event) {
                                $unit = (string)($event['unit'] ?? '');
                                if ($unit === 'SIEGE') {
                                    $sampleSiege++;
                                    $bucket['siege_hits']++;
                                    $bucket['siege_dmg'] += (float)($event['damage'] ?? 0);
                                    continue;
                                }
                                if (($event['action'] ?? '') === 'wall') {
                                    $bucket['unit_wall_dmg'] += (float)($event['damage'] ?? 0);
                                    continue;
                                }
                                if (($event['action'] ?? '') !== 'attack') {
                                    continue;
                                }
                                $sourceType = $event['source_type'] ?? null;
                                $targetType = $event['target_type'] ?? null;
                                if ($sourceType === null || $targetType === null) {
                                    continue;
                                }
                                $pair = $sourceType . '>' . $targetType;
                                $damage = (float)($event['damage'] ?? 0);
                                $bucket['typed']++;
                                $bucket['damage'] += $damage;
                                if (!isset($bucket['typed_pairs'][$pair])) {
                                    $bucket['typed_pairs'][$pair] = ['hits' => 0, 'dmg' => 0.0];
                                }
                                $bucket['typed_pairs'][$pair]['hits']++;
                                $bucket['typed_pairs'][$pair]['dmg'] += $damage;
                            }

                            foreach ($result['counters'] as $pair => $hits) {
                                $bucket['counter'] += (int)$hits;
                                $bucket['pairs'][$pair] = ($bucket['pairs'][$pair] ?? 0) + (int)$hits;
                            }
                            foreach ($result['counter_damage'] as $pair => $damage) {
                                $bucket['counter_dmg'] += (float)$damage;
                                $bucket['pair_dmg'][$pair] = ($bucket['pair_dmg'][$pair] ?? 0.0) + (float)$damage;
                            }
                            if ($sampleSiege === 0) {
                                $bucket['siege_zero']++;
                            }
                        }

                        $rows[] = [
                            'att' => $attTroops,
                            'def' => $defTroops,
                            'ac' => $attName,
                            'dc' => $defName,
                            'fire' => $fire,
                            'sup' => $supKey,
                            'b' => $bucket,
                        ];
                    }
                }
            }
        }
    }
}

$elapsed = microtime(true) - $started;
$totalBattles = 0;
foreach ($rows as $row) {
    $totalBattles += $row['b']['n'];
}

// ---------------------------------------------------------------------------
// 输出
// ---------------------------------------------------------------------------

echo "# Battle Balance Sweep · 原始输出\n\n";
printf("对局总数：%d（%d 格 × %d 次）\n", $totalBattles, count($rows), SWEEP_SAMPLES);
printf("耗时：%.1f 秒\n", $elapsed);
printf("确定性自检：%s（wall=%.1f score=%d ticks=%d 连续两次一致）\n\n",
    $deterministic ? 'PASS' : 'FAIL',
    $probe1['wall'],
    $probe1['score'],
    $probe1['ticks']
);

echo "口径：攻兵是投入兵力（名义值），实际进场 = 攻兵 × 支援系数；1.20 = 无支援但含集中兵力 ×1.20。\n";
echo "守方 1320 / 1500 已含城防 ×1.10。下表兵力比一律按实际进场兵力算。\n\n";

$baseline = fn(array $r): bool => $r['fire'] === 0 && $r['sup'] === '1.20';

// --- 1. 兵力 × 攻方编成（基线，守方编成混合） ------------------------------
echo "## 1. 基线：无火攻 / 支援 1.20 / 守方四编成混合\n\n";
echo "| 攻兵 | 守兵 | 兵力比 | 攻方编成 | 破墙率 | 平均墙 | 平均墙% | 平均 tick |\n";
echo "|---:|---:|---:|---|---:|---:|---:|---:|\n";
foreach (SWEEP_ATT_TROOPS as $attTroops) {
    foreach (SWEEP_DEF_TROOPS as $defTroops) {
        foreach (array_keys(SWEEP_ATT_COMPS) as $attName) {
            $b = sweepAgg($rows, fn(array $r): bool => $baseline($r)
                && $r['att'] === $attTroops
                && $r['def'] === $defTroops
                && $r['ac'] === $attName);
            printf(
                "| %d | %d | %.2f | %s | %.1f%% | %.0f | %.0f%% | %.1f |\n",
                $attTroops,
                $defTroops,
                $attTroops * 1.20 / $defTroops,
                $attName,
                sweepPct($b['break'], $b['n']),
                sweepAvg($b, 'wall'),
                sweepAvg($b, 'wall') / BattleEngine::WALL_BASE * 100,
                sweepAvg($b, 'ticks')
            );
        }
    }
}

// --- 2. 攻方编成总表（基线） ----------------------------------------------
echo "\n## 2. 攻方编成（基线，12 种兵力组合 × 4 种守方编成合并）\n\n";
echo "| 攻方编成 | 破墙率 | 平均墙 | 平均 tick | +2 | +1 | 0 | -1 | 器械攻墙/局 | 器械伤害/局 | 单位砍墙/局 |\n";
echo "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n";
foreach (array_keys(SWEEP_ATT_COMPS) as $attName) {
    $b = sweepAgg($rows, fn(array $r): bool => $baseline($r) && $r['ac'] === $attName);
    printf(
        "| %s | %.1f%% | %.0f | %.1f | %.1f%% | %.1f%% | %.1f%% | %.1f%% | %.1f | %.0f | %.0f |\n",
        $attName,
        sweepPct($b['break'], $b['n']),
        sweepAvg($b, 'wall'),
        sweepAvg($b, 'ticks'),
        sweepPct($b['scores'][2], $b['n']),
        sweepPct($b['scores'][1], $b['n']),
        sweepPct($b['scores'][0], $b['n']),
        sweepPct($b['scores'][-1], $b['n']),
        $b['siege_hits'] / max(1, $b['n']),
        $b['siege_dmg'] / max(1, $b['n']),
        $b['unit_wall_dmg'] / max(1, $b['n'])
    );
}

// --- 3. 守方编成总表（基线） ----------------------------------------------
echo "\n## 3. 守方编成（基线，12 种兵力组合 × 4 种攻方编成合并）\n\n";
echo "| 守方编成 | 攻方破墙率 | 平均墙 | 平均 tick | +2 | +1 | 0 | -1 |\n";
echo "|---|---:|---:|---:|---:|---:|---:|---:|\n";
foreach (array_keys(SWEEP_DEF_COMPS) as $defName) {
    $b = sweepAgg($rows, fn(array $r): bool => $baseline($r) && $r['dc'] === $defName);
    printf(
        "| %s | %.1f%% | %.0f | %.1f | %.1f%% | %.1f%% | %.1f%% | %.1f%% |\n",
        $defName,
        sweepPct($b['break'], $b['n']),
        sweepAvg($b, 'wall'),
        sweepAvg($b, 'ticks'),
        sweepPct($b['scores'][2], $b['n']),
        sweepPct($b['scores'][1], $b['n']),
        sweepPct($b['scores'][0], $b['n']),
        sweepPct($b['scores'][-1], $b['n'])
    );
}

// --- 4. 兵力比与分数分布（基线） ------------------------------------------
echo "\n## 4. 兵力比与分数分布（基线，四种攻方编成 × 四种守方编成合并）\n\n";
echo "| 攻 vs 守 | 兵力比 | 破墙率 | 平均墙 | 平均 tick | +2 | +1 | 0 | -1 |\n";
echo "|---|---:|---:|---:|---:|---:|---:|---:|---:|\n";
foreach (SWEEP_ATT_TROOPS as $attTroops) {
    foreach (SWEEP_DEF_TROOPS as $defTroops) {
        $b = sweepAgg($rows, fn(array $r): bool => $baseline($r)
            && $r['att'] === $attTroops
            && $r['def'] === $defTroops);
        printf(
            "| %d vs %d | %.2f | %.1f%% | %.0f | %.1f | %.1f%% | %.1f%% | %.1f%% | %.1f%% |\n",
            $attTroops,
            $defTroops,
            $attTroops * 1.20 / $defTroops,
            sweepPct($b['break'], $b['n']),
            sweepAvg($b, 'wall'),
            sweepAvg($b, 'ticks'),
            sweepPct($b['scores'][2], $b['n']),
            sweepPct($b['scores'][1], $b['n']),
            sweepPct($b['scores'][0], $b['n']),
            sweepPct($b['scores'][-1], $b['n'])
        );
    }
}

// --- 4.5 锚点：混编 vs 盾枪弓 ---------------------------------------------
echo "\n## 4.5 锚点：混编攻 vs 盾枪弓守（最接近正式出令的默认组合）\n\n";
echo "| 攻 vs 守 | 兵力比 | 破墙率 | 平均墙 | 平均 tick | +2 | +1 | 0 | -1 |\n";
echo "|---|---:|---:|---:|---:|---:|---:|---:|---:|\n";
foreach (SWEEP_ATT_TROOPS as $attTroops) {
    foreach (SWEEP_DEF_TROOPS as $defTroops) {
        $b = sweepAgg($rows, fn(array $r): bool => $baseline($r)
            && $r['att'] === $attTroops
            && $r['def'] === $defTroops
            && $r['ac'] === '混编'
            && $r['dc'] === '盾枪弓');
        printf(
            "| %d vs %d | %.2f | %.1f%% | %.0f | %.1f | %.1f%% | %.1f%% | %.1f%% | %.1f%% |\n",
            $attTroops,
            $defTroops,
            $attTroops * 1.20 / $defTroops,
            sweepPct($b['break'], $b['n']),
            sweepAvg($b, 'wall'),
            sweepAvg($b, 'ticks'),
            sweepPct($b['scores'][2], $b['n']),
            sweepPct($b['scores'][1], $b['n']),
            sweepPct($b['scores'][0], $b['n']),
            sweepPct($b['scores'][-1], $b['n'])
        );
    }
}

// --- 4.7 站位敏感性 --------------------------------------------------------
echo "\n## 4.7 站位敏感性：混编 vs 盾枪弓（无火攻，支援 1.20，500 次/格）\n\n";
echo "叠盾 = 弓躲在前排后、第三路空；铺开 = 三路各一队、弓暴露。\n";
echo "这是本次扫描最大的单一变量：守方空一路，攻方那一路就直接砍墙。\n\n";
echo "| 攻 vs 守 | 攻方站位 | 守方站位 | 破墙率 | 平均墙 | 平均 tick |\n";
echo "|---|---|---|---:|---:|---:|\n";
foreach ([1305 => '1305×1.2=1566（1.19×）', 1500 => '1500×1.2=1800（1.36×）'] as $attTroops => $matchLabel) {
    $placements = [
        ['stack', '叠盾+空一路'],
        ['spread', '三路铺开'],
    ];
    foreach ($placements as [$attPattern, $attLabel]) {
        foreach ($placements as [$defPattern, $defLabel]) {
            mt_srand((int)(crc32('place|' . $attTroops . '|' . $attPattern . '|' . $defPattern) ^ SWEEP_SEED));
            $bucket = sweepBucket();
            for ($s = 0; $s < 500; $s++) {
                $result = $engine->resolve(
                    [
                        'general' => SWEEP_GENERAL,
                        'teams' => sweepTeams(SWEEP_ATT_COMPS['混编'], $attTroops * 1.20, $attPattern),
                        'troops' => $attTroops * 1.20,
                        'fire' => false,
                    ],
                    [
                        'general' => SWEEP_GENERAL,
                        'teams' => sweepTeams(SWEEP_DEF_COMPS['盾枪弓'], (float)$defTroops, $defPattern),
                        'troops' => (float)$defTroops,
                    ]
                );
                $bucket['n']++;
                $bucket['break'] += $result['score'] === 2 ? 1 : 0;
                $bucket['wall'] += (float)$result['wall'];
                $bucket['ticks'] += (float)$result['ticks'];
            }
            printf(
                "| %s | %s | %s | %.1f%% | %.0f | %.1f |\n",
                $matchLabel,
                $attLabel,
                $defLabel,
                sweepPct($bucket['break'], $bucket['n']),
                sweepAvg($bucket, 'wall'),
                sweepAvg($bucket, 'ticks')
            );
        }
    }
}

// --- 5. 火攻 ---------------------------------------------------------------
echo "\n## 5. 火攻（支援 1.20，全部兵力/编成合并）\n\n";
echo "| 火攻 | 破墙率 | 平均墙 | 平均 tick | 器械伤害/局 |\n";
echo "|---|---:|---:|---:|---:|\n";
foreach ([0 => '无火攻', 1 => '火攻'] as $fire => $label) {
    $b = sweepAgg($rows, fn(array $r): bool => $r['fire'] === $fire && $r['sup'] === '1.20');
    printf(
        "| %s | %.1f%% | %.0f | %.1f | %.0f |\n",
        $label,
        sweepPct($b['break'], $b['n']),
        sweepAvg($b, 'wall'),
        sweepAvg($b, 'ticks'),
        $b['siege_dmg'] / max(1, $b['n'])
    );
}

echo "\n### 5.1 火攻 × 攻方兵力（破墙率）\n\n";
echo "| 攻兵 | 无火攻 | 火攻 | 差 |\n";
echo "|---:|---:|---:|---:|\n";
foreach (SWEEP_ATT_TROOPS as $attTroops) {
    $off = sweepAgg($rows, fn(array $r): bool => $r['fire'] === 0 && $r['sup'] === '1.20' && $r['att'] === $attTroops);
    $on = sweepAgg($rows, fn(array $r): bool => $r['fire'] === 1 && $r['sup'] === '1.20' && $r['att'] === $attTroops);
    printf(
        "| %d | %.1f%% | %.1f%% | %+.1f |\n",
        $attTroops,
        sweepPct($off['break'], $off['n']),
        sweepPct($on['break'], $on['n']),
        sweepPct($on['break'], $on['n']) - sweepPct($off['break'], $off['n'])
    );
}

// --- 6. 支援 ---------------------------------------------------------------
echo "\n## 6. 支援（无火攻，全部兵力/编成合并）\n\n";
echo "| 攻方兵力系数 | 破墙率 | 平均墙 | 平均 tick | 相对 1.20 破墙率 |\n";
echo "|---|---:|---:|---:|---:|\n";
$baseBreak = 0.0;
foreach (SWEEP_SUPPORTS as $supKey => $supMult) {
    $b = sweepAgg($rows, fn(array $r): bool => $r['fire'] === 0 && $r['sup'] === $supKey);
    $breakRate = sweepPct($b['break'], $b['n']);
    if ($supKey === '1.20') {
        $baseBreak = $breakRate;
    }
    printf(
        "| %s | %.1f%% | %.0f | %.1f | %+.1f 点 |\n",
        $supKey,
        $breakRate,
        sweepAvg($b, 'wall'),
        sweepAvg($b, 'ticks'),
        $breakRate - $baseBreak
    );
}

echo "\n### 6.1 支援 × 兵力组合（破墙率）\n\n";
echo "| 攻 vs 守 | 兵力比 | 1.20 | 1.38 | 1.50 | 1.56 | 1.50−1.20 |\n";
echo "|---|---:|---:|---:|---:|---:|---:|\n";
foreach (SWEEP_ATT_TROOPS as $attTroops) {
    foreach (SWEEP_DEF_TROOPS as $defTroops) {
        $cells = [];
        foreach (array_keys(SWEEP_SUPPORTS) as $supKey) {
            $b = sweepAgg($rows, fn(array $r): bool => $r['fire'] === 0
                && $r['sup'] === $supKey
                && $r['att'] === $attTroops
                && $r['def'] === $defTroops);
            $cells[$supKey] = sweepPct($b['break'], $b['n']);
        }
        printf(
            "| %d vs %d | %.2f | %.1f%% | %.1f%% | %.1f%% | %.1f%% | %+.1f 点 |\n",
            $attTroops,
            $defTroops,
            $attTroops * 1.20 / $defTroops,
            $cells['1.20'],
            $cells['1.38'],
            $cells['1.50'],
            $cells['1.56'],
            $cells['1.50'] - $cells['1.20']
        );
    }
}

// --- 7. 克制 ---------------------------------------------------------------
echo "\n## 7. 克制（全部 1536 格合并）\n\n";
$all = sweepAgg($rows, fn(array $r): bool => true);
printf("有类型攻击：%d 次，伤害 %.0f\n", $all['typed'], $all['damage']);
printf(
    "克制命中（×1.2）：%d 次（%.1f%% 的攻击），伤害 %.0f（%.1f%% 的总伤害）\n\n",
    $all['counter'],
    sweepPct($all['counter'], $all['typed']),
    $all['counter_dmg'],
    $all['counter_dmg'] / max(1.0, $all['damage']) * 100
);

echo "| 攻击 → 目标 | 设计倍率 | 目标防御 | 有效倍率 | 命中次数 | 每次均伤 |\n";
echo "|---|---:|---:|---:|---:|---:|\n";
ksort($all['typed_pairs']);
foreach ($all['typed_pairs'] as $pair => $stat) {
    [$src, $tgt] = explode('>', $pair);
    $mult = BattleEngine::counter($src, $tgt);
    $defMult = BattleEngine::TYPES[$tgt]['def'];
    printf(
        "| %s → %s | ×%.2f | %.2f | ×%.2f | %d | %.2f |\n",
        sweepTypeName($src),
        sweepTypeName($tgt),
        $mult,
        $defMult,
        $mult / $defMult,
        $stat['hits'],
        $stat['dmg'] / max(1, $stat['hits'])
    );
}

echo "\n### 7.1 克制命中明细\n\n";
echo "| 克制对 | 命中次数 | 每局次数 | 克制伤害 | 每局伤害 | 伤害占比 |\n";
echo "|---|---:|---:|---:|---:|---:|\n";
ksort($all['pairs']);
foreach ($all['pairs'] as $pair => $hits) {
    [$src, $tgt] = explode('>', $pair);
    $damage = $all['pair_dmg'][$pair] ?? 0.0;
    printf(
        "| %s → %s | %d | %.2f | %.0f | %.0f | %.1f%% |\n",
        sweepTypeName($src),
        sweepTypeName($tgt),
        $hits,
        $hits / max(1, $all['n']),
        $damage,
        $damage / max(1, $all['n']),
        $damage / max(1.0, $all['counter_dmg']) * 100
    );
}

// --- 8. 城墙余量 -----------------------------------------------------------
echo "\n## 8. 城墙余量分布（基线，全部合并）\n\n";
echo "| 残余墙 | 局数占比 |\n";
echo "|---|---:|\n";
$marginLabels = [
    0 => '0（破城）',
    1 => '1–10%（0–150）',
    2 => '10–20%（150–300）',
    3 => '20–30%（300–450）',
    4 => '30–50%（450–750）',
    5 => '50–80%（750–1200）',
    6 => '80–100%（1200–1500）',
];
$marginTotal = array_sum($all['margin']);
foreach ($marginLabels as $i => $label) {
    printf("| %s | %.1f%% |\n", $label, sweepPct($all['margin'][$i], $marginTotal));
}

echo "\n### 8.1 锚点攻墙伤害分布（1000 次/场景，精确值）\n\n";
echo "非破城局打满 60 tick，攻墙伤害 = 1500 − 残余墙，是精确值；只有破城局的伤害被截断，全部并入「≥1500」。\n";
echo "「1350–1500」= 再加 150 墙（+10%）就一定翻掉的对局。\n\n";
$anchors = [
    '1500×1.2 vs 1500（1.20×）' => [1500, 1500, SWEEP_ATT_COMPS['混编'], SWEEP_DEF_COMPS['盾枪弓']],
    '1200×1.2 vs 1320（1.09×）' => [1200, 1320, SWEEP_ATT_COMPS['混编'], SWEEP_DEF_COMPS['盾枪弓']],
];
$anchorHists = [];
$anchorProfiles = [];
foreach ($anchors as $label => $cfg) {
    [$attTroops, $defTroops, $attComp, $defComp] = $cfg;
    $profile = sweepAnchorProfile($engine, $attTroops, $defTroops, $attComp, $defComp, 1.20, 1000, 'cf|' . $label);
    $anchorHists[$label] = $profile['dmg'];
    $anchorProfiles[$label] = $profile;
}
echo '| 攻墙伤害 | ' . implode(' | ', array_keys($anchorHists)) . " |\n";
echo "|---|---:|---:|\n";
$damageRanges = [
    [0, 750, '<750（不到一半）'],
    [750, 1200, '750–1200'],
    [1200, 1350, '1200–1350'],
    [1350, 1500, '1350–1500（差 ≤10% 墙）'],
    [1500, 999999, '≥1500（破城）'],
];
foreach ($damageRanges as [$lo, $hi, $label]) {
    echo '| ' . $label . ' |';
    foreach ($anchorHists as $hist) {
        $count = 0.0;
        foreach ($hist as $i => $c) {
            $from = $i * 150;
            if ($from >= $lo && $from < $hi) {
                $count += $c;
            }
        }
        printf(' %.1f%% |', sweepPct((int)$count, (int)array_sum($hist)));
    }
    echo "\n";
}

echo "\n### 8.2 破城时点（破城样本，说明还留多少回合）\n\n";
echo '| 破城 tick | ' . implode(' | ', array_keys($anchorProfiles)) . " |\n";
echo "|---|---:|---:|\n";
$tickRanges = [
    [0, '≤30（余 30+ 回合，加墙也难挡）'],
    [1, '31–40'],
    [2, '41–50'],
    [3, '51–55'],
    [4, '56–59'],
    [5, '60（刚好压线）'],
];
foreach ($tickRanges as [$index, $label]) {
    echo '| ' . $label . ' |';
    foreach ($anchorProfiles as $profile) {
        printf(' %.1f%% |', sweepPct($profile['break_ticks'][$index], max(1, $profile['break'])));
    }
    echo "\n";
}
echo "\n破城率：" . implode('，', array_map(
    fn(string $label, array $profile): string => sprintf('%s %.1f%%', $label, sweepPct($profile['break'], $profile['n'])),
    array_keys($anchorProfiles),
    array_values($anchorProfiles)
)) . "\n";

// --- 9. 将军敏感性 ---------------------------------------------------------
echo "\n## 9. 将军敏感性（1200×1.2 vs 1320，混编 vs 盾枪弓，无火攻，支援 1.20，100 次）\n\n";
echo "| 攻将 / 守将 | 破墙率 | 平均墙 | 平均 tick |\n";
echo "|---|---:|---:|---:|\n";
foreach ([['def', 'def'], ['tac', 'tac'], ['atk', 'def']] as [$attGeneral, $defGeneral]) {
    mt_srand((int)(crc32('general|' . $attGeneral . '|' . $defGeneral) ^ SWEEP_SEED));
    $b = sweepBucket();
    for ($s = 0; $s < SWEEP_SAMPLES; $s++) {
        $result = $engine->resolve(
            [
                'general' => $attGeneral,
                'teams' => sweepTeams(SWEEP_ATT_COMPS['混编'], 1200 * 1.20),
                'troops' => 1200 * 1.20,
                'fire' => false,
            ],
            [
                'general' => $defGeneral,
                'teams' => sweepTeams(SWEEP_DEF_COMPS['盾枪弓'], 1320),
                'troops' => 1320,
            ]
        );
        $b['n']++;
        $b['break'] += $result['score'] === 2 ? 1 : 0;
        $b['wall'] += (float)$result['wall'];
        $b['ticks'] += (float)$result['ticks'];
    }
    printf(
        "| %s / %s | %.1f%% | %.0f | %.1f |\n",
        $attGeneral,
        $defGeneral,
        sweepPct($b['break'], $b['n']),
        sweepAvg($b, 'wall'),
        sweepAvg($b, 'ticks')
    );
}

// --- 9.1 器械保底 ----------------------------------------------------------
echo "\n### 9.1 器械保底伤害（混编，无火攻，支援 1.20）\n\n";
echo "「被挡」= 攻墙伤害 ≤20% 城墙。若器械保底已越过 20%，守方最多只能拿到「对峙」。\n\n";
echo "| 攻兵 | 器械伤害/局 | 占 1500 墙 | 占 1800 墙 | 1500 的 20% 线 |\n";
echo "|---:|---:|---:|---:|---|\n";
foreach (SWEEP_ATT_TROOPS as $attTroops) {
    $b = sweepAgg($rows, fn(array $r): bool => $baseline($r) && $r['ac'] === '混编' && $r['att'] === $attTroops);
    $siege = $b['siege_dmg'] / max(1, $b['n']);
    printf(
        "| %d | %.0f | %.1f%% | %.1f%% | %s |\n",
        $attTroops,
        $siege,
        $siege / 1500 * 100,
        $siege / 1800 * 100,
        $siege > 300 ? '满器械已越过' : '未越过'
    );
}

// --- 10. 关键数字 ----------------------------------------------------------
$parity = sweepAgg($rows, fn(array $r): bool => $baseline($r) && $r['att'] === 1200 && $r['def'] === 1320);
$thin = sweepAgg($rows, fn(array $r): bool => $baseline($r) && $r['att'] === 1500 && $r['def'] === 1320);
$overwhelm = sweepAgg($rows, fn(array $r): bool => $baseline($r) && $r['att'] === 1800 && $r['def'] === 1320);
$under = sweepAgg($rows, fn(array $r): bool => $baseline($r) && $r['att'] === 900 && $r['def'] === 1320);
$anchor = sweepAgg($rows, fn(array $r): bool => $baseline($r)
    && $r['att'] === 1500
    && $r['def'] === 1500
    && $r['ac'] === '混编'
    && $r['dc'] === '盾枪弓');
$troop1500 = sweepAgg($rows, fn(array $r): bool => $baseline($r) && $r['att'] === 1500 && $r['ac'] === '混编');
$sup120 = sweepAgg($rows, fn(array $r): bool => $r['fire'] === 0 && $r['sup'] === '1.20');
$sup138 = sweepAgg($rows, fn(array $r): bool => $r['fire'] === 0 && $r['sup'] === '1.38');
$sup150 = sweepAgg($rows, fn(array $r): bool => $r['fire'] === 0 && $r['sup'] === '1.50');
$sup156 = sweepAgg($rows, fn(array $r): bool => $r['fire'] === 0 && $r['sup'] === '1.56');

echo "\n## 10. KEY NUMBERS\n\n";
printf("KEY break_900_vs_1320 = %.1f%%\n", sweepPct($under['break'], $under['n']));
printf("KEY break_1200_vs_1320 = %.1f%%\n", sweepPct($parity['break'], $parity['n']));
printf("KEY break_1500_vs_1320 = %.1f%%\n", sweepPct($thin['break'], $thin['n']));
printf("KEY break_1800_vs_1320 = %.1f%%\n", sweepPct($overwhelm['break'], $overwhelm['n']));
printf("KEY anchor_1500v1500_mixed_vs_shieldSpearArc = %.1f%%\n", sweepPct($anchor['break'], $anchor['n']));
printf("KEY siege_damage_mixed_1500 = %.0f (%.0f%% of wall)\n",
    $troop1500['siege_dmg'] / max(1, $troop1500['n']),
    $troop1500['siege_dmg'] / max(1, $troop1500['n']) / BattleEngine::WALL_BASE * 100);
printf("KEY wall_1200_vs_1320 = %.0f (%.0f%% of base)\n",
    sweepAvg($parity, 'wall'), sweepAvg($parity, 'wall') / BattleEngine::WALL_BASE * 100);
printf("KEY break_support_1.20 = %.1f%%\n", sweepPct($sup120['break'], $sup120['n']));
printf("KEY break_support_1.38 = %.1f%%\n", sweepPct($sup138['break'], $sup138['n']));
printf("KEY break_support_1.50 = %.1f%%\n", sweepPct($sup150['break'], $sup150['n']));
printf("KEY break_support_1.56 = %.1f%%\n", sweepPct($sup156['break'], $sup156['n']));
printf("KEY support_delta_1.20_to_1.38 = %+.1f points\n",
    sweepPct($sup138['break'], $sup138['n']) - sweepPct($sup120['break'], $sup120['n']));
printf("KEY support_delta_1.20_to_1.50 = %+.1f points\n",
    sweepPct($sup150['break'], $sup150['n']) - sweepPct($sup120['break'], $sup120['n']));
printf("KEY support_delta_1.20_to_1.56 = %+.1f points\n",
    sweepPct($sup156['break'], $sup156['n']) - sweepPct($sup120['break'], $sup120['n']));
printf("KEY counter_hit_share = %.1f%%\n", sweepPct($all['counter'], $all['typed']));
printf("KEY counter_damage_share = %.1f%%\n", $all['counter_dmg'] / max(1.0, $all['damage']) * 100);
printf("KEY full_ticks_share = %.1f%%\n", sweepPct($all['full_ticks'], $all['n']));
printf("KEY siege_zero_share = %.1f%%\n", sweepPct($all['siege_zero'], $all['n']));
printf("KEY idle_def_lanes_avg = %.2f\n", $all['idle'] / max(1, $all['n']));
