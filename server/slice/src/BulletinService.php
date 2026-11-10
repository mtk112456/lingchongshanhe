<?php
declare(strict_types=1);

/**
 * D6 每日邸报：每个学生每天二选一，获得本回合小 buff。
 *
 * 三个备选，每回合每人只出现两个：
 *   grain 粮草先行 — 你的队伍本回合兵力 +5%
 *   ram   攻城器械 — 你的队伍本回合攻城伤害 +25%
 *   scout 斥候密报 — 本回合所有敌城守军可见
 *
 * 选择在结算前可改；结算时按最终选择生效。
 */
final class BulletinService
{
    public const OPTIONS = [
        'grain' => [
            'code' => 'grain',
            'title' => '粮草先行',
            'desc' => '你的队伍本回合兵力 +5%',
            'icon' => '🌾',
        ],
        'ram' => [
            'code' => 'ram',
            'title' => '攻城器械',
            'desc' => '你的队伍本回合攻城伤害 +25%',
            'icon' => '🪵',
        ],
        'scout' => [
            'code' => 'scout',
            'title' => '斥候密报',
            'desc' => '本回合所有敌城守军可见',
            'icon' => '🕵',
        ],
    ];

    private PDO $pdo;

    public function __construct(PDO $pdo)
    {
        $this->pdo = $pdo;
    }

    /**
     * 本回合邸报：选项固定、选择可改。
     *
     * @return array{turn_id:int,options:array<int,array<string,string>>,choice:?string}
     */
    public function summary(int $gameId, int $turnId, int $playerId): array
    {
        $row = $this->row($turnId, $playerId);
        if ($row === null) {
            $options = $this->pickOptions($gameId, $turnId, $playerId);
            $insert = $this->pdo->prepare(
                'INSERT INTO slice_bulletins (game_id, turn_id, player_id, options_json)
                 VALUES (?, ?, ?, ?)
                 ON DUPLICATE KEY UPDATE id = id'
            );
            $insert->execute([$gameId, $turnId, $playerId, json_encode($options, JSON_UNESCAPED_UNICODE)]);
            $row = $this->row($turnId, $playerId);
        }

        $options = json_decode((string)($row['options_json'] ?? '[]'), true);
        if (!is_array($options) || $options === []) {
            $options = $this->pickOptions($gameId, $turnId, $playerId);
        }

        return [
            'turn_id' => $turnId,
            'options' => $options,
            'choice' => $row['choice'] === null || $row['choice'] === '' ? null : (string)$row['choice'],
        ];
    }

    /**
     * @return array{turn_id:int,options:array<int,array<string,string>>,choice:?string}
     */
    public function choose(int $gameId, int $turnId, int $playerId, string $choice): array
    {
        $summary = $this->summary($gameId, $turnId, $playerId);
        $allowed = array_column($summary['options'], 'code');
        if (!in_array($choice, $allowed, true)) {
            throw new ApiException('BAD_REQUEST', '今天的邸报没有这个选项');
        }

        $stmt = $this->pdo->prepare(
            'UPDATE slice_bulletins SET choice = ? WHERE turn_id = ? AND player_id = ?'
        );
        $stmt->execute([$choice, $turnId, $playerId]);

        return $this->summary($gameId, $turnId, $playerId);
    }

    /**
     * 结算用：turn 内所有玩家的选择。
     *
     * @return array<int,string> player_id => choice
     */
    public function choicesForTurn(int $turnId): array
    {
        $stmt = $this->pdo->prepare(
            'SELECT player_id, choice FROM slice_bulletins
             WHERE turn_id = ? AND choice IS NOT NULL AND choice <> ""'
        );
        $stmt->execute([$turnId]);
        $map = [];
        foreach ($stmt->fetchAll() as $row) {
            $map[(int)$row['player_id']] = (string)$row['choice'];
        }
        return $map;
    }

    /**
     * 本回合某玩家是否侦察全图。
     */
    public function revealsAll(int $turnId, int $playerId): bool
    {
        $row = $this->row($turnId, $playerId);
        return $row !== null && (string)$row['choice'] === 'scout';
    }

    public static function teamMultiplier(?string $choice): float
    {
        return $choice === 'grain' ? 1.05 : 1.0;
    }

    public static function siegeMultiplier(?string $choice): float
    {
        return $choice === 'ram' ? 1.25 : 1.0;
    }

    /**
     * @return array<int,array<string,string>>
     */
    private function pickOptions(int $gameId, int $turnId, int $playerId): array
    {
        $codes = array_keys(self::OPTIONS);
        $seed = crc32('bulletin:' . $gameId . ':' . $turnId . ':' . $playerId);
        $first = $seed % count($codes);
        $second = ($first + 1 + intdiv($seed >> 8, 7) % (count($codes) - 1)) % count($codes);
        if ($second === $first) {
            $second = ($first + 1) % count($codes);
        }
        return [self::OPTIONS[$codes[$first]], self::OPTIONS[$codes[$second]]];
    }

    private function row(int $turnId, int $playerId): ?array
    {
        $stmt = $this->pdo->prepare(
            'SELECT options_json, choice FROM slice_bulletins WHERE turn_id = ? AND player_id = ?'
        );
        $stmt->execute([$turnId, $playerId]);
        $row = $stmt->fetch();
        return $row === false ? null : $row;
    }
}
