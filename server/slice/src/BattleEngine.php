<?php
declare(strict_types=1);

/**
 * 3 路 × 2 排 · 4 兵种 + 器械 · 确定性战斗引擎
 *
 * 输入：
 *   attacker = [
 *     'general' => 'atk|def|tac|sup',
 *     'troops'  => 1088,                 // 总兵力，调用方先算好所有加成
 *     'composition' => ['cav','shield','arc'], // 3 个兵种，可重复
 *     'fire' => false,                   // 火攻：器械攻墙 +50%
 *   ]
 *   defender = 同上，但没有 fire
 *
 * 输出：
 *   [
 *     'wall' => 300, 'score' => 1, 'ticks' => 61,
 *     'att_slots' => [...], 'def_slots' => [...],
 *     'units' => [...], 'events' => [...],
 *   ]
 *
 * 规则：
 *   - 骑 > 盾 > 弓 > 枪 > 骑；克制 ×1.2，被克 ×0.85
 *   - 前排：骑/盾/枪；后排：弓
 *   - 前排没死，后排不被近战攻击
 *   - 器械不占兵种位；攻方有任意前排存活时每 6 tick 攻墙
 *   - 60 tick，无随机，同输入同输出
 */
final class BattleEngine
{
    public const TICK_MAX = 60;
    public const WALL_BASE = 1500;
    public const SIEGE_INTERVAL = 6;
    public const SIEGE_MULT = 1.2;

    public const TYPES = [
        'cav'    => ['name' => '骑', 'atk' => 1.10, 'def' => 0.85, 'interval' => 4, 'row' => 'front'],
        'shield' => ['name' => '盾', 'atk' => 0.85, 'def' => 1.25, 'interval' => 5, 'row' => 'front'],
        'arc'    => ['name' => '弓', 'atk' => 1.90, 'def' => 0.85, 'interval' => 5, 'row' => 'back'],
        'spear'  => ['name' => '枪', 'atk' => 1.05, 'def' => 1.00, 'interval' => 5, 'row' => 'front'],
    ];

    public const GENERALS = [
        'atk' => ['name' => '攻将', 'atk' => 1.10, 'def' => 1.00],
        'def' => ['name' => '守将', 'atk' => 1.00, 'def' => 1.10],
        'tac' => ['name' => '谋将', 'atk' => 1.00, 'def' => 1.00, 'enemy_atk' => 0.95],
        'sup' => ['name' => '运将', 'atk' => 1.00, 'def' => 1.00, 'heal' => 0.05],
    ];

    /**
     * 阵容羁绊：
     *   - 3 队不同兵种：混编，攻防 +5%
     *   - 3 队同兵种：专精，攻击 +8%、防御 -8%
     *   - 2+1：无加成
     */
    public static function formation(array $teams): string
    {
        $types = [];
        foreach ($teams as $t) {
            $types[(string)($t['type'] ?? '')] = true;
        }
        $count = count($types);
        if ($count >= 3) {
            return 'mixed';
        }
        if ($count === 1) {
            return 'same';
        }
        return 'standard';
    }

    public static function counter(string $attacker, string $defender): float
    {
        $map = [
            'cav'    => ['shield' => 1.2, 'spear' => 0.85],
            'shield' => ['arc' => 1.2, 'cav' => 0.85],
            'arc'    => ['spear' => 1.2, 'shield' => 0.85],
            'spear'  => ['cav' => 1.2, 'arc' => 0.85],
        ];
        return $map[$attacker][$defender] ?? 1.0;
    }

    /**
     * 把 3 个兵种放进 3 路 × 2 排。
     * 前排按防御从高到低；后排优先躲在前排后面。
     */
    public static function place(array $composition): array
    {
        $front = [];
        $back = [];
        foreach ($composition as $type) {
            if (!isset(self::TYPES[$type])) {
                throw new InvalidArgumentException('UNKNOWN_UNIT_TYPE: ' . $type);
            }
            if (self::TYPES[$type]['row'] === 'front') {
                $front[] = $type;
            } else {
                $back[] = $type;
            }
        }

        $slots = [1 => [], 2 => [], 3 => []];
        usort($front, fn($a, $b) => self::TYPES[$b]['def'] <=> self::TYPES[$a]['def']);

        $lane = 1;
        foreach ($front as $type) {
            if ($lane > 3) {
                break;
            }
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

    /**
     * 输入二选一：
     *   - composition + troops：旧接口，按兵种自动排 3 路（测试/演示仍在用）
     *   - teams：每队自带 type/troops/lane/row/card（正式结算）
     *
     * card 是这一队带的战术；12 张牌的效果见 applyCards()。
     *
     * @param array{general:string,troops?:int|float,composition?:array,teams?:array,fire?:bool,scouted?:bool} $attacker
     * @param array{general:string,troops?:int|float,composition?:array,teams?:array,scouted?:bool} $defender
     */
    public function resolve(array $attacker, array $defender): array
    {
        $attTeams = $this->teamsOf($attacker);
        $defTeams = $this->teamsOf($defender);
        $attFormation = self::formation($attTeams);
        $defFormation = self::formation($defTeams);
        $attSlots = self::slotsOf($attTeams);
        $defSlots = self::slotsOf($defTeams);

        $units = [];
        foreach ($attTeams as $t) {
            $id = self::unitId('att', $t);
            $units[$id] = $this->makeUnit(
                $id,
                'att',
                $t['lane'],
                $t['row'],
                $t['type'],
                (string)$attacker['general'],
                $t['troops']
            );
            $units[$id]['card'] = $t['card'];
        }
        foreach ($defTeams as $t) {
            $id = self::unitId('def', $t);
            $units[$id] = $this->makeUnit(
                $id,
                'def',
                $t['lane'],
                $t['row'],
                $t['type'],
                (string)$defender['general'],
                $t['troops']
            );
            $units[$id]['card'] = $t['card'];
        }

        $this->applyCards($units, $attTeams, $defTeams, $attacker, $defender);
        $this->applyFormation($units, 'att', $attFormation);
        $this->applyFormation($units, 'def', $defFormation);

        $initialUnits = array_values(array_map(fn($u) => [
            'id' => $u['id'],
            'side' => $u['side'],
            'lane' => $u['lane'],
            'row' => $u['row'],
            'type' => $u['type'],
            'card' => $u['card'] ?? null,
            'atk' => round($u['atk'], 2),
            'def_mult' => round($u['def_mult'], 3),
            'initiative' => (int)($u['initiative'] ?? 0),
            'troops' => round($u['troops'], 1),
            'max_troops' => round($u['max_troops'], 1),
        ], $units));

        $wall = (float)self::WALL_BASE;
        $events = [];
        $totalTroops = array_sum(array_column($attTeams, 'troops'));
        $siegeAtk = ($totalTroops / 3 * 0.05 + 10) * self::SIEGE_MULT * (float)($attacker['siege_mult'] ?? 1.0);
        $fire = !empty($attacker['fire']) || in_array('fire_attack', array_column($attTeams, 'card'), true);
        if ($fire) {
            $siegeAtk *= 1.5;
        }

        $tick = 0;
        for ($tick = 1; $tick <= self::TICK_MAX; $tick++) {
            // 器械：攻方还有任意前排存活，就安全攻墙
            if ($tick % self::SIEGE_INTERVAL === 0) {
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
                        't' => $tick,
                        'unit' => 'SIEGE',
                        'action' => 'wall',
                        'damage' => round($siegeAtk, 1),
                        'wall' => max(0, round($wall, 1)),
                        'fire' => $fire,
                    ];
                }
            }

            // 15 tick：运粮回血、断粮掉兵
            if ($tick % 15 === 0) {
                $this->upkeep($units, $tick, $events);
            }

            // 急行先手：本 tick 内先行动，其余按固定 id 顺序
            $order = array_keys($units);
            usort($order, function (string $a, string $b) use ($units): int {
                $ia = (int)($units[$a]['initiative'] ?? 0);
                $ib = (int)($units[$b]['initiative'] ?? 0);
                return $ia === $ib ? strcmp($a, $b) : $ib <=> $ia;
            });

            foreach ($order as $uid) {
                if ($wall <= 0) {
                    break 2;
                }
                $this->act($uid, $units, $tick, $wall, $events);
            }
        }

        $ratio = $wall / self::WALL_BASE;
        if ($wall <= 0) {
            $score = 2;
        } elseif ($ratio < 0.5) {
            $score = 1;
        } elseif ($ratio < 0.8) {
            $score = 0;
        } else {
            $score = -1;
        }

        $finalUnits = array_values(array_map(fn($u) => [
            'id' => $u['id'],
            'side' => $u['side'],
            'lane' => $u['lane'],
            'row' => $u['row'],
            'type' => $u['type'],
            'card' => $u['card'] ?? null,
            'troops' => round($u['troops'], 1),
            'alive' => $u['alive'],
        ], $units));

        return [
            'wall' => max(0, round($wall, 1)),
            'score' => $score,
            'ticks' => $tick,
            'att_slots' => $attSlots,
            'def_slots' => $defSlots,
            'att_formation' => $attFormation,
            'def_formation' => $defFormation,
            'units' => $initialUnits,
            'final_units' => $finalUnits,
            'events' => $events,
        ];
    }

    /**
     * 把输入统一成 3 支队伍。
     *
     * @return array<int,array{type:string,troops:float,lane:int,row:string,card:?string}>
     */
    private function teamsOf(array $config): array
    {
        if (!empty($config['teams']) && is_array($config['teams'])) {
            $teams = [];
            $used = [];
            foreach (array_values($config['teams']) as $i => $t) {
                $type = (string)($t['type'] ?? '');
                if (!isset(self::TYPES[$type])) {
                    throw new InvalidArgumentException('UNKNOWN_UNIT_TYPE: ' . $type);
                }
                $lane = (int)($t['lane'] ?? 0);
                if ($lane < 1 || $lane > 3) {
                    $lane = min(3, $i + 1);
                }
                $row = (string)($t['row'] ?? '');
                if (!in_array($row, ['front', 'back'], true)) {
                    $row = self::TYPES[$type]['row'];
                }
                if ($type === 'arc') {
                    $row = 'back';
                }
                // 同一格重复时顺延到最近的空位，保证 6 个位置不互相覆盖
                if (isset($used[$lane . '|' . $row])) {
                    foreach ([1, 2, 3] as $l) {
                        foreach (['front', 'back'] as $r) {
                            if (!isset($used[$l . '|' . $r])) {
                                $lane = $l;
                                $row = $r;
                                break 2;
                            }
                        }
                    }
                }
                $used[$lane . '|' . $row] = true;
                $card = isset($t['card']) && $t['card'] !== '' ? (string)$t['card'] : null;
                $teams[] = [
                    'type' => $type,
                    'troops' => (float)($t['troops'] ?? 0),
                    'lane' => $lane,
                    'row' => $row,
                    'card' => $card,
                ];
                if (count($teams) >= 3) {
                    break;
                }
            }
            return $teams;
        }

        $slots = self::place($config['composition'] ?? []);
        $troops = (float)($config['troops'] ?? 0);
        $count = max(1, count($config['composition'] ?? []));
        $teams = [];
        foreach ([1, 2, 3] as $lane) {
            foreach (['front', 'back'] as $row) {
                if (isset($slots[$lane][$row])) {
                    $teams[] = [
                        'type' => $slots[$lane][$row],
                        'troops' => $troops / $count,
                        'lane' => $lane,
                        'row' => $row,
                        'card' => null,
                    ];
                }
            }
        }
        return $teams;
    }

    /**
     * @param array<int,array{type:string,lane:int,row:string}> $teams
     * @return array<int,array<string,string>>
     */
    private static function slotsOf(array $teams): array
    {
        $slots = [];
        foreach ($teams as $t) {
            $slots[$t['lane']][$t['row']] = $t['type'];
        }
        return $slots;
    }

    private static function unitId(string $side, array $team): string
    {
        return ($side === 'att' ? 'A' : 'D') . $team['lane'] . ($team['row'] === 'front' ? 'F' : 'B');
    }

    private function applyFormation(array &$units, string $side, string $formation): void
    {
        foreach ($units as &$u) {
            if ($u['side'] !== $side) {
                continue;
            }
            if ($formation === 'mixed') {
                $u['atk'] *= 1.05;
                $u['def_mult'] *= 1.05;
            } elseif ($formation === 'same') {
                $u['atk'] *= 1.08;
                $u['def_mult'] *= 0.92;
            }
        }
        unset($u);
    }

    /**
     * 12 张战术的结算顺序：
     *   1. 将军光环（谋将 -5% 敌军攻击）
     *   2. 敌方全场牌：空城、反间（我军攻击 -10%）
     *   3. 本队牌：坚壁、夜袭、死守、运粮、断粮、急行
     *   4. 邻接牌：犄角（相邻路防御 +10%）
     *   5. 器械：火攻在 resolve() 里单独加成
     *
     * 哨探、疑兵不改战斗数值，只影响情报接口。
     */
    private function applyCards(array &$units, array $attTeams, array $defTeams, array $attacker, array $defender): void
    {
        $cards = [
            'att' => array_values(array_filter(array_column($attTeams, 'card'))),
            'def' => array_values(array_filter(array_column($defTeams, 'card'))),
        ];
        $scouted = [
            'att' => !empty($attacker['scouted']),
            'def' => !empty($defender['scouted']),
        ];

        foreach ($units as &$u) {
            $side = $u['side'];
            $enemy = $side === 'att' ? 'def' : 'att';

            // 1. 谋将：敌方攻击 -5%
            $enemyGeneral = $side === 'att' ? $defender['general'] : $attacker['general'];
            if ($enemyGeneral === 'tac') {
                $u['atk'] *= 0.95;
            }

            // 2. 敌方全场牌
            if (in_array('empty_fort', $cards[$enemy], true)) {
                $u['atk'] *= 0.9;
            }
            if (in_array('counter_intel', $cards[$enemy], true)) {
                $u['atk'] *= 0.9;
            }

            // 3. 本队牌
            $card = $u['card'] ?? null;
            if ($card === 'fortify') {
                $u['def_mult'] *= 1.2;
            }
            if ($card === 'night_raid' && !$scouted[$side]) {
                $u['atk'] *= 1.2;
            }
            if ($card === 'last_stand') {
                $u['last_stand'] = true;
            }
            if ($card === 'supply') {
                $u['heal'] = 0.05;
            }
            if ($card === 'cut_supply') {
                $u['cut_supply'] = true;
            }
            if ($card === 'forced_march') {
                $u['initiative'] = 1;
                $u['dot_immune'] = true;
            }
        }
        unset($u);

        // 4. 犄角：相邻路的友军防御 +10%
        foreach ($units as $u) {
            if (($u['card'] ?? null) !== 'mutual_support' || !$u['alive']) {
                continue;
            }
            foreach ($units as &$v) {
                if ($v['side'] === $u['side'] && abs($v['lane'] - $u['lane']) === 1) {
                    $v['def_mult'] *= 1.1;
                }
            }
            unset($v);
        }
    }

    /**
     * 每 15 tick：运粮回血，断粮掉兵。
     */
    private function upkeep(array &$units, int $tick, array &$events): void
    {
        foreach ($units as &$u) {
            if (!$u['alive'] || empty($u['heal'])) {
                continue;
            }
            $before = $u['troops'];
            $u['troops'] = min($u['max_troops'], $u['troops'] + $u['max_troops'] * (float)$u['heal']);
            if ($u['troops'] > $before) {
                $events[] = [
                    't' => $tick,
                    'lane' => $u['lane'],
                    'unit' => $u['id'],
                    'action' => 'heal',
                    'heal' => round($u['troops'] - $before, 1),
                    'troops' => round($u['troops'], 1),
                ];
            }
        }
        unset($u);

        foreach ($units as $src) {
            if (!$src['alive'] || empty($src['cut_supply'])) {
                continue;
            }
            foreach ($units as $target) {
                if ($target['side'] === $src['side'] || !$target['alive'] || !empty($target['dot_immune'])) {
                    continue;
                }
                $dmg = $target['max_troops'] * 0.03;
                $this->damage($units, $target['id'], $dmg, $tick, $events, 'CUT_SUPPLY', 'cut_supply');
            }
        }
    }

    private function makeUnit(
        string $id,
        string $side,
        int $lane,
        string $row,
        string $type,
        string $general,
        float $troops
    ): array {
        $t = self::TYPES[$type];
        $g = self::GENERALS[$general] ?? self::GENERALS['def'];
        $baseAtk = $troops * 0.05 + 10;

        return [
            'id' => $id,
            'side' => $side,
            'lane' => $lane,
            'row' => $row,
            'type' => $type,
            'troops' => $troops,
            'max_troops' => $troops,
            'atk' => $baseAtk * $t['atk'] * ($g['atk'] ?? 1.0),
            'def_mult' => $t['def'] * ($g['def'] ?? 1.0),
            'interval' => $t['interval'],
            'alive' => true,
            'attacks' => 0,
        ];
    }

    private function unitAt(array &$units, string $side, int $lane, string $row): ?array
    {
        $id = ($side === 'att' ? 'A' : 'D') . $lane . ($row === 'front' ? 'F' : 'B');
        if (!isset($units[$id]) || !$units[$id]['alive']) {
            return null;
        }
        return $units[$id];
    }

    private function act(string $uid, array &$units, int $tick, float &$wall, array &$events): void
    {
        $u = &$units[$uid];
        if (!$u['alive'] || $tick % $u['interval'] !== 0) {
            unset($u);
            return;
        }

        $side = $u['side'];
        $enemySide = $side === 'att' ? 'def' : 'att';
        $lane = $u['lane'];

        // 近战在后排：前排没死就待命；前排死了补位
        if ($u['row'] === 'back' && $u['type'] !== 'arc') {
            $front = $this->unitAt($units, $side, $lane, 'front');
            if ($front !== null) {
                unset($u);
                return;
            }
            $u['row'] = 'front';
            $events[] = [
                't' => $tick, 'lane' => $lane, 'unit' => $uid,
                'action' => 'advance_row', 'row' => 'front',
            ];
        }

        // 目标：敌前 > 敌后 > 墙
        $target = $this->unitAt($units, $enemySide, $lane, 'front');
        if ($target === null) {
            $target = $this->unitAt($units, $enemySide, $lane, 'back');
        }

        if ($target !== null) {
            $dmg = $u['atk'] * self::counter($u['type'], $target['type']);
            if ($u['type'] === 'arc' && ($u['attacks'] ?? 0) < 3) {
                $dmg *= 1.3; // 先手射击：前 3 次 +30%
            }
            if ($target['row'] === 'back' && $this->unitAt($units, $enemySide, $lane, 'front') === null) {
                $dmg *= 1.3; // 后排暴露：没有前排保护
            }
            $dmg /= max(0.5, $target['def_mult']);
            $this->damage($units, $target['id'], $dmg, $tick, $events, $uid);
            $u['attacks'] = ($u['attacks'] ?? 0) + 1;
            unset($u);
            return;
        }

        if ($side === 'att') {
            $wall -= $u['atk'];
            $events[] = [
                't' => $tick, 'lane' => $lane, 'unit' => $uid, 'action' => 'wall',
                'damage' => round($u['atk'], 1), 'wall' => max(0, round($wall, 1)),
            ];
        }
        unset($u);
    }

    private function damage(
        array &$units,
        string $targetId,
        float $dmg,
        int $tick,
        array &$events,
        string $sourceId,
        string $action = 'attack'
    ): void {
        $units[$targetId]['troops'] -= $dmg;
        $killed = $units[$targetId]['troops'] <= 0;

        // 死守：本队第一次致命伤留 1 兵
        if ($killed && !empty($units[$targetId]['last_stand'])) {
            $units[$targetId]['troops'] = 1.0;
            $units[$targetId]['alive'] = true;
            $units[$targetId]['last_stand'] = false;
            $killed = false;
            $events[] = [
                't' => $tick,
                'lane' => $units[$targetId]['lane'],
                'unit' => $sourceId,
                'action' => 'last_stand',
                'target' => $targetId,
            ];
        }

        if ($killed) {
            $units[$targetId]['troops'] = 0;
            $units[$targetId]['alive'] = false;
        }
        $events[] = [
            't' => $tick,
            'lane' => $units[$targetId]['lane'],
            'unit' => $sourceId,
            'action' => $action,
            'target' => $targetId,
            'damage' => round($dmg, 1),
            'target_troops' => round($units[$targetId]['troops'], 1),
            'killed' => $killed,
        ];
    }
}
