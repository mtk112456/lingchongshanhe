<?php
declare(strict_types=1);

/**
 * 每日手牌 · 12 张战术，4 抽 3，1 次重抽
 *
 * 纯逻辑，不碰数据库。服务端用种子保证同一天同一玩家手牌固定。
 */
final class HandDeck
{
    public const TACTICS = [
        'night_raid'   => ['name' => '夜袭', 'desc' => '目标未侦察，伤害 +20%'],
        'forced_march' => ['name' => '急行', 'desc' => '首轮先手，无视断连'],
        'fire_attack'  => ['name' => '火攻', 'desc' => '器械攻墙 +50%'],
        'fortify'      => ['name' => '坚壁', 'desc' => '本队防御 +20%'],
        'mutual_support' => ['name' => '犄角', 'desc' => '相邻队防御 +10%'],
        'empty_fort'   => ['name' => '空城', 'desc' => '敌军攻击 -10%'],
        'last_stand'   => ['name' => '死守', 'desc' => '本队免疫一次破城'],
        'scout'        => ['name' => '哨探', 'desc' => '开战前显示敌方一路'],
        'counter_intel' => ['name' => '反间', 'desc' => '敌军攻击 -10%'],
        'feint'        => ['name' => '疑兵', 'desc' => '显示假兵力'],
        'supply'       => ['name' => '运粮', 'desc' => '每 15 tick 回复 5%'],
        'cut_supply'   => ['name' => '断粮', 'desc' => '敌军每 15 tick 损失 3%'],
    ];

    public const HAND_SIZE = 4;
    public const PLAY_LIMIT = 3;

    /**
     * 确定性抽牌：同一 seed 同一结果，刷新页面不变。
     *
     * @return string[] 4 个战术 code，无重复
     */
    public static function draw(string $seed, int $count = self::HAND_SIZE): array
    {
        $keys = array_keys(self::TACTICS);
        usort($keys, function (string $a, string $b) use ($seed): int {
            $ha = hash('sha256', $seed . ':' . $a);
            $hb = hash('sha256', $seed . ':' . $b);
            return $ha <=> $hb;
        });
        return array_slice($keys, 0, min($count, count($keys)));
    }

    public static function redraw(string $seed, int $count = self::HAND_SIZE): array
    {
        return self::draw($seed . ':redraw', $count);
    }

    /**
     * 校验一张牌能不能出。
     *
     * @param string[] $hand 当前手牌
     * @param string[] $played 已出的牌
     */
    public static function validatePlay(array $hand, string $card, array $played): void
    {
        if (!isset(self::TACTICS[$card])) {
            throw new InvalidArgumentException('UNKNOWN_TACTIC: ' . $card);
        }
        if (!in_array($card, $hand, true)) {
            throw new InvalidArgumentException('CARD_NOT_IN_HAND: ' . $card);
        }
        if (in_array($card, $played, true)) {
            throw new InvalidArgumentException('CARD_ALREADY_PLAYED: ' . $card);
        }
        if (count($played) >= self::PLAY_LIMIT) {
            throw new InvalidArgumentException('PLAY_LIMIT_REACHED');
        }
    }

    public static function label(string $card): string
    {
        return self::TACTICS[$card]['name'] ?? $card;
    }
}
