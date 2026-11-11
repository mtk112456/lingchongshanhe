<?php
declare(strict_types=1);

require_once __DIR__ . '/ApiException.php';
require_once __DIR__ . '/Clock.php';

/**
 * 文房小院：个人封地。
 *
 * 设计红线：
 *   - 不产兵、不产资源、不产文玉
 *   - 升级只消耗军功余额，只给便利和外观
 *   - 不改变 13 城归属
 */
final class EstateService
{
    public const MAX_LEVEL = 3;
    public const COSTS = [2 => 30, 3 => 80];

    public const ROOMS = [
        'study' => ['name' => '书房', 'icon' => '📜', 'column' => 'study_level'],
        'drill' => ['name' => '练兵场', 'icon' => '⚔', 'column' => 'drill_level'],
        'tower' => ['name' => '望楼', 'icon' => '🔭', 'column' => 'tower_level'],
    ];

    private PDO $pdo;

    public function __construct(PDO $pdo)
    {
        $this->pdo = $pdo;
    }

    /**
     * @return array<string,mixed>
     */
    public function ensure(int $gameId, int $playerId): array
    {
        $stmt = $this->pdo->prepare('SELECT * FROM slice_estates WHERE game_id = ? AND player_id = ?');
        $stmt->execute([$gameId, $playerId]);
        $row = $stmt->fetch();
        if ($row !== false) {
            return $row;
        }

        $stmt = $this->pdo->prepare(
            'SELECT f.start_node_code
             FROM slice_players p JOIN slice_factions f ON f.id = p.faction_id
             WHERE p.id = ? AND p.game_id = ?'
        );
        $stmt->execute([$playerId, $gameId]);
        $home = $stmt->fetchColumn();
        if ($home === false || $home === null || $home === '') {
            throw new ApiException('ESTATE_NO_HOME', '找不到你的阵营起始城', 409);
        }

        $stmt = $this->pdo->prepare(
            'INSERT INTO slice_estates (game_id, player_id, home_node_code)
             VALUES (?, ?, ?)
             ON DUPLICATE KEY UPDATE id = id'
        );
        $stmt->execute([$gameId, $playerId, (string)$home]);

        $stmt = $this->pdo->prepare('SELECT * FROM slice_estates WHERE game_id = ? AND player_id = ?');
        $stmt->execute([$gameId, $playerId]);
        return $stmt->fetch();
    }

    /**
     * @return array<string,mixed>
     */
    public function summary(int $gameId, int $playerId, int $week): array
    {
        $estate = $this->ensure($gameId, $playerId);

        $stmt = $this->pdo->prepare(
            'SELECT COALESCE(SUM(amount), 0) FROM slice_merit_events WHERE game_id = ? AND player_id = ?'
        );
        $stmt->execute([$gameId, $playerId]);
        $meritTotal = (int)$stmt->fetchColumn();
        $spent = (int)$estate['spent_merit'];
        $balance = max(0, $meritTotal - $spent);

        $rooms = [];
        $overall = 1;
        foreach (self::ROOMS as $code => $meta) {
            $level = (int)$estate[$meta['column']];
            $overall = max($overall, $level);
            $rooms[] = [
                'code' => $code,
                'name' => $meta['name'],
                'icon' => $meta['icon'],
                'level' => $level,
                'max_level' => self::MAX_LEVEL,
                'effect' => $this->effectText($code, $level),
                'next_effect' => $level >= self::MAX_LEVEL ? null : $this->effectText($code, $level + 1),
                'next_cost' => $level >= self::MAX_LEVEL ? null : self::COSTS[$level + 1],
            ];
        }

        $stmt = $this->pdo->prepare('SELECT name FROM slice_nodes WHERE game_id = ? AND node_code = ?');
        $stmt->execute([$gameId, (string)$estate['home_node_code']]);
        $homeName = $stmt->fetchColumn();

        return [
            'home_node' => [
                'code' => (string)$estate['home_node_code'],
                'name' => $homeName === false ? (string)$estate['home_node_code'] : (string)$homeName,
            ],
            'level' => $overall,
            'banner' => (string)$estate['banner'],
            'merit_total' => $meritTotal,
            'merit_spent' => $spent,
            'merit_balance' => $balance,
            'next_level_at' => $overall >= self::MAX_LEVEL ? null : $overall * 150,
            'rooms' => $rooms,
            'influence' => $this->influence($gameId, $playerId),
            'governorships' => $this->governorships($gameId, $playerId, $week),
        ];
    }

    /**
     * @return array<string,mixed>
     */
    public function upgrade(int $gameId, int $playerId, string $room): array
    {
        if (!isset(self::ROOMS[$room])) {
            throw new ApiException('ESTATE_BAD_ROOM', '没有这个房间', 400);
        }

        $this->pdo->beginTransaction();
        try {
            $stmt = $this->pdo->prepare(
                'SELECT * FROM slice_estates WHERE game_id = ? AND player_id = ? FOR UPDATE'
            );
            $stmt->execute([$gameId, $playerId]);
            $estate = $stmt->fetch();
            if ($estate === false) {
                $this->pdo->commit();
                $estate = $this->ensure($gameId, $playerId);
                $this->pdo->beginTransaction();
                $stmt = $this->pdo->prepare(
                    'SELECT * FROM slice_estates WHERE game_id = ? AND player_id = ? FOR UPDATE'
                );
                $stmt->execute([$gameId, $playerId]);
                $estate = $stmt->fetch();
            }

            $column = self::ROOMS[$room]['column'];
            $level = (int)$estate[$column];
            if ($level >= self::MAX_LEVEL) {
                throw new ApiException('ESTATE_MAX_LEVEL', '这个房间已经满级了', 409);
            }
            $cost = self::COSTS[$level + 1];

            $stmt = $this->pdo->prepare(
                'SELECT COALESCE(SUM(amount), 0) FROM slice_merit_events WHERE game_id = ? AND player_id = ?'
            );
            $stmt->execute([$gameId, $playerId]);
            $balance = (int)$stmt->fetchColumn() - (int)$estate['spent_merit'];
            if ($balance < $cost) {
                throw new ApiException('ESTATE_INSUFFICIENT_MERIT', '军功不够', 409, [
                    'balance' => $balance,
                    'cost' => $cost,
                    'gap' => $cost - $balance,
                ]);
            }

            $stmt = $this->pdo->prepare(
                "UPDATE slice_estates
                 SET {$column} = {$column} + 1, spent_merit = spent_merit + ?
                 WHERE id = ?"
            );
            $stmt->execute([$cost, (int)$estate['id']]);

            $this->pdo->commit();
        } catch (Throwable $e) {
            if ($this->pdo->inTransaction()) {
                $this->pdo->rollBack();
            }
            throw $e;
        }

        $week = Clock::weekOfTurn(max(1, $this->currentTurnNo($gameId)));
        $summary = $this->summary($gameId, $playerId, $week);
        $summary['upgraded'] = [
            'room' => $room,
            'level' => $this->roomLevel($summary, $room),
            'spent' => self::COSTS[$this->roomLevel($summary, $room)],
        ];
        return $summary;
    }

    /**
     * 最近 7 个回合，我在哪些城留下过军功。
     *
     * @return array<int,array{code:string,name:string,count:int,merit:int}>
     */
    public function influence(int $gameId, int $playerId): array
    {
        $stmt = $this->pdo->prepare(
            'SELECT MAX(t.turn_no) FROM slice_turns t WHERE t.game_id = ?'
        );
        $stmt->execute([$gameId]);
        $maxTurn = max(1, (int)$stmt->fetchColumn());
        $from = max(1, $maxTurn - 6);

        $stmt = $this->pdo->prepare(
            "SELECT n.node_code AS code, n.name,
                    COUNT(DISTINCT m.turn_id) AS days,
                    SUM(m.amount) AS merit
             FROM slice_merit_events m
             JOIN slice_turns t ON t.id = m.turn_id
             JOIN slice_nodes n ON n.game_id = m.game_id
                 AND n.node_code = JSON_UNQUOTE(JSON_EXTRACT(m.detail_json, '$.node_code'))
             WHERE m.game_id = ? AND m.player_id = ? AND t.turn_no BETWEEN ? AND ?
               AND JSON_EXTRACT(m.detail_json, '$.node_code') IS NOT NULL
             GROUP BY n.node_code, n.name
             ORDER BY days DESC, merit DESC
             LIMIT 5"
        );
        $stmt->execute([$gameId, $playerId, $from, $maxTurn]);
        return array_map(static fn($row) => [
            'code' => (string)$row['code'],
            'name' => (string)$row['name'],
            'count' => (int)$row['days'],
            'merit' => (int)$row['merit'],
        ], $stmt->fetchAll());
    }

    /**
     * @return array<int,array{code:string,name:string,week:int,merit:int}>
     */
    public function governorships(int $gameId, int $playerId, int $week): array
    {
        $stmt = $this->pdo->prepare(
            'SELECT g.node_code AS code, n.name, g.week_no AS week, g.merit
             FROM slice_city_governors g
             JOIN slice_nodes n ON n.game_id = g.game_id AND n.node_code = g.node_code
             WHERE g.game_id = ? AND g.player_id = ? AND g.week_no = ?
             ORDER BY g.merit DESC'
        );
        $stmt->execute([$gameId, $playerId, $week]);
        return array_map(static fn($row) => [
            'code' => (string)$row['code'],
            'name' => (string)$row['name'],
            'week' => (int)$row['week'],
            'merit' => (int)$row['merit'],
        ], $stmt->fetchAll());
    }

    /**
     * 每周开始时算上周太守。
     */
    public function refreshGovernors(int $gameId, int $week): int
    {
        $from = ($week - 1) * 7 + 1;
        $to = $week * 7;

        $stmt = $this->pdo->prepare(
            "SELECT n.node_code, n.owner_faction_id, m.player_id, SUM(m.amount) AS merit
             FROM slice_nodes n
             JOIN slice_merit_events m ON m.game_id = n.game_id
                 AND JSON_UNQUOTE(JSON_EXTRACT(m.detail_json, '$.node_code')) = n.node_code
             JOIN slice_turns t ON t.id = m.turn_id
             JOIN slice_players p ON p.id = m.player_id
             WHERE n.game_id = ? AND n.owner_faction_id IS NOT NULL
               AND t.turn_no BETWEEN ? AND ?
               AND p.faction_id = n.owner_faction_id
             GROUP BY n.node_code, n.owner_faction_id, m.player_id
             ORDER BY n.node_code, merit DESC"
        );
        $stmt->execute([$gameId, $from, $to]);

        $picked = [];
        foreach ($stmt->fetchAll() as $row) {
            $node = (string)$row['node_code'];
            if (isset($picked[$node])) {
                continue;
            }
            $picked[$node] = [
                'player_id' => (int)$row['player_id'],
                'merit' => (int)$row['merit'],
            ];
        }

        $upsert = $this->pdo->prepare(
            'INSERT INTO slice_city_governors (game_id, node_code, week_no, player_id, merit)
             VALUES (?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE
                player_id = VALUES(player_id),
                merit = VALUES(merit)'
        );
        foreach ($picked as $node => $info) {
            $upsert->execute([$gameId, $node, $week, $info['player_id'], $info['merit']]);
        }
        return count($picked);
    }

    /**
     * @return array<string,array{player_id:int,nickname:string,faction:?string,color:?string,merit:int}>
     */
    public function governorsForWeek(int $gameId, int $week): array
    {
        $stmt = $this->pdo->prepare(
            'SELECT g.node_code, g.player_id, g.merit, p.nickname,
                    f.code AS faction, f.color
             FROM slice_city_governors g
             JOIN slice_players p ON p.id = g.player_id
             LEFT JOIN slice_factions f ON f.id = p.faction_id
             WHERE g.game_id = ? AND g.week_no = ?'
        );
        $stmt->execute([$gameId, $week]);
        $map = [];
        foreach ($stmt->fetchAll() as $row) {
            $map[(string)$row['node_code']] = [
                'player_id' => (int)$row['player_id'],
                'nickname' => (string)$row['nickname'],
                'faction' => $row['faction'] === null ? null : (string)$row['faction'],
                'color' => $row['color'] === null ? null : (string)$row['color'],
                'merit' => (int)$row['merit'],
            ];
        }
        return $map;
    }

    public function effectText(string $room, int $level): string
    {
        return match ($room) {
            'study' => "每日可预读 {$level} 张未抽到的牌",
            'drill' => "每周可改 {$level} 次编成",
            'tower' => "侦察时多看 {$level} 座邻城",
            default => '',
        };
    }

    /**
     * 练兵场加成：每周可改编成次数 = 1 + (level - 1)
     */
    public function compositionChanges(int $gameId, int $playerId): int
    {
        $estate = $this->ensure($gameId, $playerId);
        return max(1, (int)$estate['drill_level']);
    }

    /**
     * 望楼加成：侦察额外覆盖的邻城数 = level
     */
    public function extraScoutNodes(int $gameId, int $playerId): int
    {
        $estate = $this->ensure($gameId, $playerId);
        return max(0, (int)$estate['tower_level']);
    }

    private function currentTurnNo(int $gameId): int
    {
        $stmt = $this->pdo->prepare(
            'SELECT t.turn_no FROM slice_games g JOIN slice_turns t ON t.id = g.current_turn_id WHERE g.id = ?'
        );
        $stmt->execute([$gameId]);
        return (int)$stmt->fetchColumn();
    }

    private function roomLevel(array $summary, string $room): int
    {
        foreach ($summary['rooms'] as $item) {
            if ($item['code'] === $room) {
                return (int)$item['level'];
            }
        }
        return 1;
    }
}
