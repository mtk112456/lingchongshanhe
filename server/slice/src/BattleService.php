<?php
declare(strict_types=1);

require_once __DIR__ . '/BattleEngine.php';

/**
 * 战斗服务：把班宠、支援、民心换算成引擎输入。
 */
final class BattleService
{
    private BattleEngine $engine;

    public function __construct(?BattleEngine $engine = null)
    {
        $this->engine = $engine ?? new BattleEngine();
    }

    /**
     * 班宠战力 → 总兵力。
     * 直接读 pet_templates 的四维 + student_pets.level + growth_rate。
     */
    public static function petPower(array $pet): float
    {
        $base = ((float)($pet['base_hp'] ?? 0)
            + (float)($pet['base_atk'] ?? 0) * 2
            + (float)($pet['base_def'] ?? 0) * 2
            + (float)($pet['base_spd'] ?? 0)) / 2;
        $level = max(1, (int)($pet['level'] ?? 1));
        $growth = (float)($pet['growth_rate'] ?? 1.0);
        $equipment = (float)($pet['equipment_power'] ?? 0);

        return $base * (1 + 0.05 * ($level - 1)) * $growth + $equipment;
    }

    /**
     * 支援加成：每多 1 人 +2%，上限 +30%。
     */
    public static function supportMultiplier(int $supporters): float
    {
        return 1 + min(0.30, max(0, $supporters) * 0.02);
    }

    /**
     * 战斗分数 → 民心变化（-1 / 0 / +1 / +2）。
     */
    public static function moraleDelta(int $score): int
    {
        return max(-1, min(2, $score));
    }

    /**
     * @param array{general:string,troops:int|float,composition:array,fire?:bool} $attacker
     * @param array{general:string,troops:int|float,composition:array} $defender
     */
    public function resolve(array $attacker, array $defender): array
    {
        if (count($attacker['composition'] ?? []) !== 3) {
            throw new InvalidArgumentException('ATTACKER_NEEDS_3_UNITS');
        }
        if (count($defender['composition'] ?? []) !== 3) {
            throw new InvalidArgumentException('DEFENDER_NEEDS_3_UNITS');
        }
        if (!isset(BattleEngine::GENERALS[$attacker['general'] ?? ''])) {
            throw new InvalidArgumentException('UNKNOWN_ATTACKER_GENERAL');
        }
        if (!isset(BattleEngine::GENERALS[$defender['general'] ?? ''])) {
            throw new InvalidArgumentException('UNKNOWN_DEFENDER_GENERAL');
        }
        return $this->engine->resolve($attacker, $defender);
    }

    /**
     * 主攻聚合：先锋 3 人 + 支援者，算出总兵力。
     *
     * @param array<int,array> $vanguard 3 个班宠（含 base_* / level / growth_rate）
     * @param int $supporters 支援人数
     * @return float
     */
    public function aggregateTroops(array $vanguard, int $supporters): float
    {
        $sum = 0.0;
        foreach ($vanguard as $pet) {
            $sum += self::petPower($pet) / 3;
        }
        return $sum * self::supportMultiplier($supporters);
    }
}
