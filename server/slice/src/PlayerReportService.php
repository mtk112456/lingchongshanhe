<?php
declare(strict_types=1);

require_once __DIR__ . '/ApiException.php';
require_once __DIR__ . '/MeritService.php';

/**
 * 个人战报：把一回合里“我做了什么、贡献多少、拿了多少军功”拼成一张账单。
 */
final class PlayerReportService
{
    private PDO $pdo;

    public function __construct(PDO $pdo)
    {
        $this->pdo = $pdo;
    }

    /**
     * @return array<string,mixed>
     */
    public function forTurn(int $gameId, int $playerId, int $turnId): array
    {
        $stmt = $this->pdo->prepare(
            'SELECT id, turn_no, status, settled_at, deadline_at
             FROM slice_turns WHERE id = ? AND game_id = ?'
        );
        $stmt->execute([$turnId, $gameId]);
        $turn = $stmt->fetch();
        if (!$turn) {
            throw new ApiException('TURN_NOT_FOUND', '回合不存在', 404);
        }
        if ((string)$turn['status'] !== 'settled') {
            throw new ApiException('REPORT_NOT_READY', '本回合尚未结算', 409);
        }

        $stmt = $this->pdo->prepare(
            'SELECT slot, card_code, target_node_code, lane, row_pos
             FROM slice_order_slots
             WHERE turn_id = ? AND player_id = ? AND status = "active"
             ORDER BY slot'
        );
        $stmt->execute([$turnId, $playerId]);
        $orders = $stmt->fetchAll();

        $stmt = $this->pdo->prepare(
            'SELECT result_json FROM slice_turn_results WHERE turn_id = ?'
        );
        $stmt->execute([$turnId]);
        $result = json_decode((string)($stmt->fetchColumn() ?: '{}'), true) ?: [];
        $battles = [];
        foreach (($result['battles'] ?? []) as $battle) {
            if (($battle['node_code'] ?? '') !== '') {
                $battles[(string)$battle['node_code']] = $battle;
            }
        }

        $stmt = $this->pdo->prepare(
            'SELECT node_code, name FROM slice_nodes WHERE game_id = ?'
        );
        $stmt->execute([$gameId]);
        $nodeNames = [];
        foreach ($stmt->fetchAll() as $row) {
            $nodeNames[(string)$row['node_code']] = (string)$row['name'];
        }

        $items = [];
        $totalDamage = 0.0;
        $totalWall = 0.0;
        $totalLost = 0.0;
        $battlesJoined = 0;
        foreach ($orders as $order) {
            $node = (string)$order['target_node_code'];
            $card = (string)$order['card_code'];
            $battle = $battles[$node] ?? null;
            $role = $this->roleOf($card, $playerId, $battle);
            $contribution = $battle['contribution'][$playerId]
                ?? $battle['contribution'][(string)$playerId]
                ?? null;
            if ($contribution !== null) {
                $totalDamage += (float)$contribution['damage'];
                $totalWall += (float)$contribution['wall_damage'];
                $totalLost += (float)$contribution['troops_lost'];
                $battlesJoined++;
            }
            $items[] = [
                'slot' => (int)$order['slot'],
                'card' => $card,
                'node_code' => $node,
                'node_name' => $nodeNames[$node] ?? $node,
                'lane' => $order['lane'] === null ? null : (int)$order['lane'],
                'row' => $order['row_pos'] === null ? null : (string)$order['row_pos'],
                'role' => $role,
                'damage' => $contribution === null ? 0.0 : (float)$contribution['damage'],
                'wall_damage' => $contribution === null ? 0.0 : (float)$contribution['wall_damage'],
                'troops_lost' => $contribution === null ? 0.0 : (float)$contribution['troops_lost'],
                'contribution' => $contribution === null ? 0.0 : (float)$contribution['contribution'],
                'captured' => (bool)($battle['captured'] ?? false),
            ];
        }

        $merit = (new MeritService($this->pdo))->turnSummary($turnId, $playerId);
        $highlight = $this->highlight($items, $merit['turn_total']);

        return [
            'turn_no' => (int)$turn['turn_no'],
            'settled_at' => $turn['settled_at'],
            'orders' => $items,
            'battles_joined' => $battlesJoined,
            'damage' => round($totalDamage, 1),
            'wall_damage' => round($totalWall, 1),
            'troops_lost' => round($totalLost, 1),
            'merit' => $merit,
            'highlight' => $highlight,
        ];
    }

    private function roleOf(string $card, int $playerId, ?array $battle): string
    {
        if ($card === 'scout') {
            return 'scout';
        }
        if ($card === 'fire_attack') {
            return 'fire';
        }
        if ($card === 'feint') {
            return 'feint';
        }
        if ($battle === null) {
            return 'reserve';
        }
        foreach (($battle['teams'] ?? []) as $team) {
            if ((int)($team['player_id'] ?? 0) === $playerId) {
                return 'vanguard';
            }
        }
        foreach (($battle['defender_teams'] ?? []) as $team) {
            if ((int)($team['player_id'] ?? 0) === $playerId) {
                return 'garrison';
            }
        }
        return 'support';
    }

    /**
     * @param array<int,array<string,mixed>> $items
     */
    private function highlight(array $items, int $merit): string
    {
        foreach ($items as $item) {
            if (!empty($item['captured']) && (float)$item['contribution'] > 0) {
                return sprintf(
                    '你的队伍参与了 %s 的破城，贡献 %d%%',
                    $item['node_name'],
                    (int)round((float)$item['contribution'] * 100)
                );
            }
        }
        $best = null;
        foreach ($items as $item) {
            if ($best === null || (float)$item['damage'] > (float)$best['damage']) {
                $best = $item;
            }
        }
        if ($best !== null && (float)$best['damage'] > 0) {
            return sprintf(
                '你在 %s 打出 %s 伤害，贡献 %d%%',
                $best['node_name'],
                number_format((float)$best['damage']),
                (int)round((float)$best['contribution'] * 100)
            );
        }
        if ($merit > 0) {
            return sprintf('你今天获得 %d 军功', $merit);
        }
        return '今天没有出战，明天还有机会';
    }
}
