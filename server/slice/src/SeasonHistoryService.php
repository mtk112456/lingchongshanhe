<?php
declare(strict_types=1);

require_once __DIR__ . '/Clock.php';

/**
 * D8 赛季史书：把 28 个回合按周聚合成 4 期刊。
 *
 * 每期给出：
 *   - 本周战役数、易主城
 *   - 本周关键战役（按战果分、回合数排序）
 *   - 周末各阵营城数/民心
 *   - 一句话头条
 */
final class SeasonHistoryService
{
    private PDO $pdo;

    public function __construct(PDO $pdo)
    {
        $this->pdo = $pdo;
    }

    public function history(int $gameId): array
    {
        $stmt = $this->pdo->prepare('SELECT id, code, name FROM slice_games WHERE id = ?');
        $stmt->execute([$gameId]);
        $game = $stmt->fetch();
        if (!$game) {
            throw new RuntimeException('GAME_NOT_FOUND');
        }

        $stmt = $this->pdo->prepare(
            'SELECT MAX(t.turn_no) FROM slice_turns t WHERE t.game_id = ? AND t.status = "settled"'
        );
        $stmt->execute([$gameId]);
        $settledMax = (int)$stmt->fetchColumn();
        $stmt = $this->pdo->prepare(
            'SELECT t.turn_no FROM slice_games g JOIN slice_turns t ON t.id = g.current_turn_id WHERE g.id = ?'
        );
        $stmt->execute([$gameId]);
        $currentTurnNo = (int)$stmt->fetchColumn();
        $maxTurn = max(1, $settledMax, $currentTurnNo);
        $currentWeek = Clock::weekOfTurn($maxTurn);

        // 阵营
        $stmt = $this->pdo->prepare(
            'SELECT id, code, name, color FROM slice_factions WHERE game_id = ? ORDER BY sort_order'
        );
        $stmt->execute([$gameId]);
        $factions = [];
        foreach ($stmt->fetchAll() as $row) {
            $factions[(int)$row['id']] = [
                'code' => (string)$row['code'],
                'name' => (string)$row['name'],
                'color' => (string)$row['color'],
            ];
        }

        // 城：名字 + 初始归属
        $stmt = $this->pdo->prepare(
            'SELECT node_code, name, initial_owner_faction_id FROM slice_nodes WHERE game_id = ?'
        );
        $stmt->execute([$gameId]);
        $nodeNames = [];
        $owners = [];
        foreach ($stmt->fetchAll() as $row) {
            $nodeNames[(string)$row['node_code']] = (string)$row['name'];
            $owners[(string)$row['node_code']] = $row['initial_owner_faction_id'] === null
                ? null
                : (int)$row['initial_owner_faction_id'];
        }

        // 全部易主记录
        $stmt = $this->pdo->prepare(
            'SELECT t.turn_no, c.node_code, c.owner_before_faction_id, c.owner_after_faction_id, c.reason
             FROM slice_node_changes c
             JOIN slice_turns t ON t.id = c.turn_id
             WHERE c.game_id = ?
             ORDER BY t.turn_no, c.id'
        );
        $stmt->execute([$gameId]);
        $changes = $stmt->fetchAll();

        // 全部战斗
        $stmt = $this->pdo->prepare(
            'SELECT t.turn_no, b.node_code, b.att_faction_id, b.def_faction_id, b.result_json
             FROM slice_battles b
             JOIN slice_turns t ON t.id = b.turn_id
             WHERE b.game_id = ?
             ORDER BY t.turn_no, b.id'
        );
        $stmt->execute([$gameId]);
        $battles = $stmt->fetchAll();

        $weeks = [];
        for ($week = 1; $week <= $currentWeek; $week++) {
            $from = ($week - 1) * 7 + 1;
            $to = $week * 7;
            $weekBattles = array_values(array_filter(
                $battles,
                fn($b) => (int)$b['turn_no'] >= $from && (int)$b['turn_no'] <= $to
            ));
            $weekChanges = array_values(array_filter(
                $changes,
                fn($c) => (int)$c['turn_no'] >= $from && (int)$c['turn_no'] <= $to
            ));

            // 周末归属：初始归属 + 截至本周末的易主
            foreach ($changes as $change) {
                if ((int)$change['turn_no'] > $to) {
                    break;
                }
                $owners[(string)$change['node_code']] = $change['owner_after_faction_id'] === null
                    ? null
                    : (int)$change['owner_after_faction_id'];
            }

            $captures = [];
            foreach ($weekChanges as $change) {
                $before = $change['owner_before_faction_id'] === null ? null : (int)$change['owner_before_faction_id'];
                $after = $change['owner_after_faction_id'] === null ? null : (int)$change['owner_after_faction_id'];
                if ($after === null || $before === $after) {
                    continue;
                }
                $captures[] = [
                    'turn_no' => (int)$change['turn_no'],
                    'node_code' => (string)$change['node_code'],
                    'node_name' => $nodeNames[(string)$change['node_code']] ?? (string)$change['node_code'],
                    'winner' => $factions[$after] ?? null,
                ];
            }

            $keyBattle = null;
            foreach ($weekBattles as $battle) {
                $result = json_decode((string)$battle['result_json'], true) ?: [];
                $score = (int)($result['score'] ?? 0);
                if ($score <= 0) {
                    continue;
                }
                $candidate = [
                    'turn_no' => (int)$battle['turn_no'],
                    'node_code' => (string)$battle['node_code'],
                    'node_name' => $nodeNames[(string)$battle['node_code']] ?? (string)$battle['node_code'],
                    'headline' => (string)($result['headline'] ?? ''),
                    'score' => $score,
                    'wall' => (float)($result['wall'] ?? 0),
                    'ticks' => (int)($result['ticks'] ?? 0),
                    'attacker' => $factions[(int)$battle['att_faction_id']] ?? null,
                    'defender' => $battle['def_faction_id'] === null
                        ? null
                        : ($factions[(int)$battle['def_faction_id']] ?? null),
                ];
                if ($keyBattle === null
                    || $candidate['score'] > $keyBattle['score']
                    || ($candidate['score'] === $keyBattle['score'] && $candidate['ticks'] > $keyBattle['ticks'])) {
                    $keyBattle = $candidate;
                }
            }

            $standings = [];
            $neutral = 0;
            foreach ($owners as $owner) {
                if ($owner === null) {
                    $neutral++;
                }
            }
            foreach ($factions as $factionId => $faction) {
                $cities = 0;
                foreach ($owners as $owner) {
                    if ($owner === $factionId) {
                        $cities++;
                    }
                }
                $standings[] = [
                    'code' => $faction['code'],
                    'name' => $faction['name'],
                    'color' => $faction['color'],
                    'cities' => $cities,
                ];
            }
            usort($standings, fn($a, $b) => $b['cities'] <=> $a['cities']);
            $leader = $standings[0];
            $standings[] = [
                'code' => 'neutral',
                'name' => '中立',
                'color' => '#7a7066',
                'cities' => $neutral,
            ];

            $headline = sprintf('第 %d 周：%s %d 城领先', $week, $leader['name'], $leader['cities']);
            if ($captures !== []) {
                $headline .= sprintf('，%d 城易主', count($captures));
            }

            $weeks[] = [
                'week' => $week,
                'turn_from' => $from,
                'turn_to' => min($to, $maxTurn),
                'complete' => $maxTurn >= $to,
                'battles' => count($weekBattles),
                'captures' => $captures,
                'key_battle' => $keyBattle,
                'standings' => $standings,
                'headline' => $headline,
            ];
        }

        return [
            'game' => (string)$game['code'],
            'name' => (string)$game['name'],
            'current_week' => $currentWeek,
            'max_turn' => $maxTurn,
            'weeks' => $weeks,
        ];
    }
}
