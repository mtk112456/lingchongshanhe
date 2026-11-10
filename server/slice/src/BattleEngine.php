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
    public const WALL_BASE = 1000;
    public const SIEGE_INTERVAL = 6;
    public const SIEGE_MULT = 1.5;

    public const TYPES = [
        'cav'    => ['name' => '骑', 'atk' => 1.15, 'def' => 0.85, 'interval' => 4, 'row' => 'front'],
        'shield' => ['name' => '盾', 'atk' => 0.85, 'def' => 1.25, 'interval' => 5, 'row' => 'front'],
        'arc'    => ['name' => '弓', 'atk' => 1.45, 'def' => 0.80, 'interval' => 5, 'row' => 'back'],
        'spear'  => ['name' => '枪', 'atk' => 1.05, 'def' => 1.00, 'interval' => 5, 'row' => 'front'],
    ];

    public const GENERALS = [
        'atk' => ['name' => '攻将', 'atk' => 1.10, 'def' => 1.00],
        'def' => ['name' => '守将', 'atk' => 1.00, 'def' => 1.10],
        'tac' => ['name' => '谋将', 'atk' => 1.00, 'def' => 1.00, 'enemy_atk' => 0.95],
        'sup' => ['name' => '运将', 'atk' => 1.00, 'def' => 1.00, 'heal' => 0.05],
    ];

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
     * @param array{general:string,troops:int|float,composition:array,fire?:bool} $attacker
     * @param array{general:string,troops:int|float,composition:array} $defender
     */
    public function resolve(array $attacker, array $defender): array
    {
        $attSlots = self::place($attacker['composition']);
        $defSlots = self::place($defender['composition']);

        $units = [];
        foreach ([1, 2, 3] as $lane) {
            foreach (['front', 'back'] as $row) {
                if (isset($attSlots[$lane][$row])) {
                    $id = "A{$lane}" . ($row === 'front' ? 'F' : 'B');
                    $units[$id] = $this->makeUnit(
                        $id,
                        'att',
                        $lane,
                        $row,
                        $attSlots[$lane][$row],
                        $attacker['general'],
                        (float)$attacker['troops'] / 3
                    );
                }
                if (isset($defSlots[$lane][$row])) {
                    $id = "D{$lane}" . ($row === 'front' ? 'F' : 'B');
                    $units[$id] = $this->makeUnit(
                        $id,
                        'def',
                        $lane,
                        $row,
                        $defSlots[$lane][$row],
                        $defender['general'],
                        (float)$defender['troops'] / 3
                    );
                }
            }
        }

        // 谋将：敌方攻击 -5%
        foreach ($units as &$u) {
            if ($attacker['general'] === 'tac' && $u['side'] === 'def') {
                $u['atk'] *= 0.95;
            }
            if ($defender['general'] === 'tac' && $u['side'] === 'att') {
                $u['atk'] *= 0.95;
            }
        }
        unset($u);

        $initialUnits = array_values(array_map(fn($u) => [
            'id' => $u['id'],
            'side' => $u['side'],
            'lane' => $u['lane'],
            'row' => $u['row'],
            'type' => $u['type'],
            'troops' => round($u['troops'], 1),
            'max_troops' => round($u['max_troops'], 1),
        ], $units));

        $wall = (float)self::WALL_BASE;
        $events = [];
        $siegeAtk = ((float)$attacker['troops'] / 3 * 0.05 + 10) * self::SIEGE_MULT;
        if (!empty($attacker['fire'])) {
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
                    ];
                }
            }

            foreach (array_keys($units) as $uid) {
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

        return [
            'wall' => max(0, round($wall, 1)),
            'score' => $score,
            'ticks' => $tick,
            'att_slots' => $attSlots,
            'def_slots' => $defSlots,
            'units' => $initialUnits,
            'events' => $events,
        ];
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
            $dmg /= max(0.5, $target['def_mult']);
            $this->damage($units, $target['id'], $dmg, $tick, $events, $uid);
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

    private function damage(array &$units, string $targetId, float $dmg, int $tick, array &$events, string $sourceId): void
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
            'damage' => round($dmg, 1),
            'target_troops' => round($units[$targetId]['troops'], 1),
            'killed' => $killed,
        ];
    }
}
