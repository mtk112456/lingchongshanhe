<?php
declare(strict_types=1);

require_once __DIR__ . '/Clock.php';

/**
 * 4 周赛季总览：周次、各阵营城数/民心、长安归属、胜负。
 */
final class SeasonService
{
    private PDO $pdo;

    public function __construct(PDO $pdo)
    {
        $this->pdo = $pdo;
    }

    public function summary(int $gameId): array
    {
        $stmt = $this->pdo->prepare('SELECT id, code, name, status, rules_version FROM slice_games WHERE id = ?');
        $stmt->execute([$gameId]);
        $game = $stmt->fetch();
        if (!$game) {
            throw new RuntimeException('GAME_NOT_FOUND');
        }

        $stmt = $this->pdo->prepare(
            'SELECT id, turn_no, status FROM slice_turns WHERE game_id = ? ORDER BY turn_no DESC LIMIT 1'
        );
        $stmt->execute([$gameId]);
        $turn = $stmt->fetch();
        $turnNo = $turn === false ? 0 : (int)$turn['turn_no'];
        $week = Clock::weekOfTurn(max(1, $turnNo));

        $stmt = $this->pdo->prepare(
            'SELECT f.id, f.code, f.name, f.color,
                    COUNT(n.id) AS cities,
                    COALESCE(SUM(n.morale), 0) AS morale
             FROM slice_factions f
             LEFT JOIN slice_nodes n ON n.game_id = f.game_id AND n.owner_faction_id = f.id
             WHERE f.game_id = ?
             GROUP BY f.id, f.code, f.name, f.color, f.sort_order
             ORDER BY f.sort_order'
        );
        $stmt->execute([$gameId]);
        $factions = [];
        foreach ($stmt->fetchAll() as $row) {
            $factions[] = [
                'code' => (string)$row['code'],
                'name' => (string)$row['name'],
                'color' => (string)$row['color'],
                'cities' => (int)$row['cities'],
                'morale' => (int)$row['morale'],
            ];
        }

        $stmt = $this->pdo->prepare(
            "SELECT n.node_code, n.name, n.node_type, n.morale, f.code AS owner_code, f.name AS owner_name
             FROM slice_nodes n
             LEFT JOIN slice_factions f ON f.id = n.owner_faction_id
             WHERE n.game_id = ? AND n.node_type = 'king' LIMIT 1"
        );
        $stmt->execute([$gameId]);
        $king = $stmt->fetch();
        $changan = $king === false ? null : [
            'node_code' => (string)$king['node_code'],
            'name' => (string)$king['name'],
            'owner' => $king['owner_code'] === null ? null : (string)$king['owner_code'],
            'owner_name' => $king['owner_name'] === null ? null : (string)$king['owner_name'],
            'morale' => (int)$king['morale'],
            'morale_cap' => (string)$king['node_type'] === 'king' ? 5 : 2,
        ];

        $neutral = (int)$this->pdo->query(
            "SELECT COUNT(*) FROM slice_nodes WHERE game_id = {$gameId} AND owner_faction_id IS NULL"
        )->fetchColumn();

        $winner = null;
        if ($changan !== null && $changan['owner'] !== null) {
            $winner = [
                'code' => $changan['owner'],
                'name' => $changan['owner_name'],
                'reason' => 'changan',
                'cities' => 0,
                'morale' => 0,
            ];
        } elseif ($turnNo >= 28 || (string)$game['status'] === 'finished') {
            $best = null;
            $tie = false;
            foreach ($factions as $f) {
                if ($best === null
                    || $f['cities'] > $best['cities']
                    || ($f['cities'] === $best['cities'] && $f['morale'] > $best['morale'])) {
                    $best = $f;
                    $tie = false;
                } elseif ($f['cities'] === $best['cities'] && $f['morale'] === $best['morale']) {
                    $tie = true;
                }
            }
            if ($best !== null && !$tie) {
                $winner = [
                    'code' => $best['code'],
                    'name' => $best['name'],
                    'reason' => 'cities',
                    'cities' => $best['cities'],
                    'morale' => $best['morale'],
                ];
            }
        }

        if ($winner !== null) {
            foreach ($factions as $f) {
                if ($f['code'] === $winner['code']) {
                    $winner['cities'] = $f['cities'];
                    $winner['morale'] = $f['morale'];
                    break;
                }
            }
        }

        return [
            'game' => (string)$game['code'],
            'week' => $week,
            'turn_no' => $turnNo,
            'days_left' => max(0, 28 - $turnNo),
            'season_over' => $winner !== null || $turnNo >= 28,
            'factions' => $factions,
            'neutral_cities' => $neutral,
            'changan' => $changan,
            'winner' => $winner,
        ];
    }
}
