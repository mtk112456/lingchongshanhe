<?php
declare(strict_types=1);

require_once __DIR__ . '/Clock.php';

/**
 * 个人军功：只记录游戏内荣誉，不碰 students.score。
 *
 * 作用：
 *   - 让每个学生每天的行动有可积累的个人目标
 *   - 周榜/赛季榜给称号与存在感，不给战力，避免滚雪球
 */
final class MeritService
{
    public const LABELS = [
        'participation' => '出令',
        'vanguard' => '先锋',
        'support' => '支援',
        'capture' => '破城',
        'capture_support' => '破城支援',
        'assault' => '攻城',
        'garrison' => '驻守',
        'defend' => '守城',
        'scout' => '侦察',
        'fire' => '火攻',
    ];

    private PDO $pdo;

    public function __construct(PDO $pdo)
    {
        $this->pdo = $pdo;
    }

    public function award(
        int $gameId,
        int $turnId,
        int $playerId,
        string $kind,
        int $amount,
        array $detail = []
    ): void {
        if ($amount <= 0) {
            return;
        }
        $stmt = $this->pdo->prepare(
            'INSERT INTO slice_merit_events (game_id, turn_id, player_id, kind, amount, detail_json)
             VALUES (?, ?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE amount = amount + VALUES(amount)'
        );
        $stmt->execute([
            $gameId,
            $turnId,
            $playerId,
            $kind,
            $amount,
            json_encode($detail, JSON_UNESCAPED_UNICODE),
        ]);
    }

    /**
     * @return array{total:int,week:int,week_no:int,rank:int,week_rank:int,breakdown:array<string,int>,recent:array<int,array>}
     */
    public function summary(int $gameId, int $playerId, int $week = 0): array
    {
        $stmt = $this->pdo->prepare(
            'SELECT kind, SUM(amount) AS amount FROM slice_merit_events
             WHERE game_id = ? AND player_id = ? GROUP BY kind ORDER BY amount DESC'
        );
        $stmt->execute([$gameId, $playerId]);
        $breakdown = [];
        $total = 0;
        foreach ($stmt->fetchAll() as $row) {
            $kind = (string)$row['kind'];
            $breakdown[$kind] = (int)$row['amount'];
            $total += (int)$row['amount'];
        }

        if ($week <= 0) {
            $stmt = $this->pdo->prepare(
                'SELECT MAX(t.turn_no) FROM slice_turns t WHERE t.game_id = ? AND t.status = "settled"'
            );
            $stmt->execute([$gameId]);
            $week = Clock::weekOfTurn(max(1, (int)$stmt->fetchColumn()));
        }

        $weekStart = ($week - 1) * 7 + 1;
        $weekEnd = $week * 7;
        $stmt = $this->pdo->prepare(
            'SELECT COALESCE(SUM(m.amount), 0) FROM slice_merit_events m
             JOIN slice_turns t ON t.id = m.turn_id
             WHERE m.game_id = ? AND m.player_id = ? AND t.turn_no BETWEEN ? AND ?'
        );
        $stmt->execute([$gameId, $playerId, $weekStart, $weekEnd]);
        $weekTotal = (int)$stmt->fetchColumn();

        $stmt = $this->pdo->prepare(
            'SELECT m.turn_id, t.turn_no, m.kind, m.amount, m.detail_json
             FROM slice_merit_events m
             JOIN slice_turns t ON t.id = m.turn_id
             WHERE m.game_id = ? AND m.player_id = ?
             ORDER BY t.turn_no DESC, m.id DESC LIMIT 8'
        );
        $stmt->execute([$gameId, $playerId]);
        $recent = [];
        foreach ($stmt->fetchAll() as $row) {
            $recent[] = [
                'turn_no' => (int)$row['turn_no'],
                'kind' => (string)$row['kind'],
                'label' => self::LABELS[(string)$row['kind']] ?? (string)$row['kind'],
                'amount' => (int)$row['amount'],
                'detail' => json_decode((string)($row['detail_json'] ?? '{}'), true) ?: [],
            ];
        }

        return [
            'total' => $total,
            'week' => $weekTotal,
            'week_no' => $week,
            'rank' => $this->rank($gameId, $total),
            'week_rank' => $this->weekRank($gameId, $weekTotal, $weekStart, $weekEnd),
            'roles' => $this->roleRanks($gameId, $playerId, $week, $weekStart, $weekEnd),
            'breakdown' => $breakdown,
            'recent' => $recent,
        ];
    }

    /**
     * @return array{turn_total:int,items:array<int,array{kind:string,label:string,amount:int}>}
     */
    public function turnSummary(int $turnId, int $playerId): array
    {
        $stmt = $this->pdo->prepare(
            'SELECT kind, amount FROM slice_merit_events WHERE turn_id = ? AND player_id = ? ORDER BY id'
        );
        $stmt->execute([$turnId, $playerId]);
        $items = [];
        $total = 0;
        foreach ($stmt->fetchAll() as $row) {
            $items[] = [
                'kind' => (string)$row['kind'],
                'label' => self::LABELS[(string)$row['kind']] ?? (string)$row['kind'],
                'amount' => (int)$row['amount'],
            ];
            $total += (int)$row['amount'];
        }
        return ['turn_total' => $total, 'items' => $items];
    }

    /**
     * @return array<int,array{player_id:int,nickname:string,faction:?string,faction_name:?string,color:?string,total:int}>
     */
    public function top(int $gameId, int $limit = 10): array
    {
        $limit = max(1, min(50, $limit));
        $stmt = $this->pdo->prepare(
            "SELECT p.id AS player_id, p.nickname,
                    f.code AS faction, f.name AS faction_name, f.color,
                    SUM(m.amount) AS total
             FROM slice_merit_events m
             JOIN slice_players p ON p.id = m.player_id
             LEFT JOIN slice_factions f ON f.id = p.faction_id
             WHERE m.game_id = ?
             GROUP BY p.id, p.nickname, f.code, f.name, f.color
             ORDER BY total DESC, p.id
             LIMIT {$limit}"
        );
        $stmt->execute([$gameId]);
        return array_map(static fn($row) => [
            'player_id' => (int)$row['player_id'],
            'nickname' => (string)$row['nickname'],
            'faction' => $row['faction'] === null ? null : (string)$row['faction'],
            'faction_name' => $row['faction_name'] === null ? null : (string)$row['faction_name'],
            'color' => $row['color'] === null ? null : (string)$row['color'],
            'total' => (int)$row['total'],
        ], $stmt->fetchAll());
    }

    /**
     * @return array<int,array{player_id:int,nickname:string,faction:?string,faction_name:?string,color:?string,total:int}>
     */
    public function weekTop(int $gameId, int $week, int $limit = 10): array
    {
        $limit = max(1, min(50, $limit));
        $from = ($week - 1) * 7 + 1;
        $to = $week * 7;
        $stmt = $this->pdo->prepare(
            "SELECT p.id AS player_id, p.nickname,
                    f.code AS faction, f.name AS faction_name, f.color,
                    SUM(m.amount) AS total
             FROM slice_merit_events m
             JOIN slice_players p ON p.id = m.player_id
             JOIN slice_turns t ON t.id = m.turn_id
             LEFT JOIN slice_factions f ON f.id = p.faction_id
             WHERE m.game_id = ? AND t.turn_no BETWEEN ? AND ?
             GROUP BY p.id, p.nickname, f.code, f.name, f.color
             ORDER BY total DESC, p.id
             LIMIT {$limit}"
        );
        $stmt->execute([$gameId, $from, $to]);
        return array_map(static fn($row) => [
            'player_id' => (int)$row['player_id'],
            'nickname' => (string)$row['nickname'],
            'faction' => $row['faction'] === null ? null : (string)$row['faction'],
            'faction_name' => $row['faction_name'] === null ? null : (string)$row['faction_name'],
            'color' => $row['color'] === null ? null : (string)$row['color'],
            'total' => (int)$row['total'],
        ], $stmt->fetchAll());
    }

    /**
     * 本周角色榜：先锋 / 支援 / 侦察 / 守城 / 火攻。
     *
     * @return array<int,array{kind:string,label:string,week:int,rank:int}>
     */
    private function roleRanks(int $gameId, int $playerId, int $week, int $from, int $to): array
    {
        $stmt = $this->pdo->prepare(
            'SELECT m.kind, m.player_id, SUM(m.amount) AS total
             FROM slice_merit_events m
             JOIN slice_turns t ON t.id = m.turn_id
             WHERE m.game_id = ? AND t.turn_no BETWEEN ? AND ?
               AND m.kind IN ("vanguard", "support", "scout", "defend", "fire")
             GROUP BY m.kind, m.player_id'
        );
        $stmt->execute([$gameId, $from, $to]);

        $byKind = [];
        foreach ($stmt->fetchAll() as $row) {
            $kind = (string)$row['kind'];
            $byKind[$kind][(int)$row['player_id']] = (int)$row['total'];
        }

        $roles = [];
        foreach (['vanguard', 'support', 'scout', 'defend', 'fire'] as $kind) {
            $mine = $byKind[$kind][$playerId] ?? 0;
            if ($mine <= 0) {
                continue;
            }
            $rank = 1;
            foreach ($byKind[$kind] as $pid => $total) {
                if ($pid !== $playerId && $total > $mine) {
                    $rank++;
                }
            }
            $roles[] = [
                'kind' => $kind,
                'label' => self::LABELS[$kind] ?? $kind,
                'week' => $week,
                'rank' => $rank,
            ];
        }
        return $roles;
    }

    private function rank(int $gameId, int $total): int
    {
        $stmt = $this->pdo->prepare(
            'SELECT COUNT(*) FROM (
                SELECT player_id, SUM(amount) AS total
                FROM slice_merit_events WHERE game_id = ? GROUP BY player_id
             ) x WHERE x.total > ?'
        );
        $stmt->execute([$gameId, $total]);
        return (int)$stmt->fetchColumn() + 1;
    }

    private function weekRank(int $gameId, int $total, int $from, int $to): int
    {
        $stmt = $this->pdo->prepare(
            'SELECT COUNT(*) FROM (
                SELECT m.player_id, SUM(m.amount) AS total
                FROM slice_merit_events m
                JOIN slice_turns t ON t.id = m.turn_id
                WHERE m.game_id = ? AND t.turn_no BETWEEN ? AND ?
                GROUP BY m.player_id
             ) x WHERE x.total > ?'
        );
        $stmt->execute([$gameId, $from, $to, $total]);
        return (int)$stmt->fetchColumn() + 1;
    }
}
