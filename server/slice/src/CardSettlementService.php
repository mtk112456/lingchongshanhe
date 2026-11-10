<?php
declare(strict_types=1);

require_once __DIR__ . '/BattleService.php';
require_once __DIR__ . '/BattleSettlementService.php';

/**
 * 21:00 卡牌结算：把 slice_order_slots 按城聚合，打一场，推民心。
 *
 * 简化规则（Phase 1）：
 *   - 每座城只打一场；
 *   - 攻方 = 该城令数最多的阵营；并列则对峙，不结算；
 *   - 先锋 = 该阵营贡献前 3 名学生，各出 1 只班宠；
 *   - 其余支援 +2%/人，上限 +30%；
 *   - 守方 = 城归属方（固定守军）；中立城用中立守军；
 *   - 结果写入 slice_battles，民心写入 slice_nodes。
 */
final class CardSettlementService
{
    private PDO $pdo;
    private BattleService $battleService;
    private BattleSettlementService $settlement;

    public function __construct(PDO $pdo)
    {
        $this->pdo = $pdo;
        $this->battleService = new BattleService(null, $pdo);
        $this->settlement = new BattleSettlementService($pdo);
    }

    /**
     * @return array{turn_id:int,already_settled:bool,battles:array}
     */
    public function settle(int $gameId, int $turnId): array
    {
        $stmt = $this->pdo->prepare('SELECT * FROM slice_turns WHERE id = ? AND game_id = ?');
        $stmt->execute([$turnId, $gameId]);
        $turn = $stmt->fetch();
        if (!$turn) {
            throw new RuntimeException('TURN_NOT_FOUND');
        }
        if ((string)$turn['status'] === 'settled') {
            return ['turn_id' => $turnId, 'already_settled' => true, 'battles' => []];
        }

        $stmt = $this->pdo->prepare(
            'SELECT o.id, o.player_id, o.slot, o.card_code, o.target_node_code, o.lane, o.row_pos,
                    p.faction_id, p.student_id,
                    sp.level, pt.base_hp, pt.base_atk, pt.base_def, pt.base_spd,
                    pt.growth_rate, pt.code AS pet_code
             FROM slice_order_slots o
             JOIN slice_players p ON p.id = o.player_id
             LEFT JOIN student_pets sp ON sp.student_id = p.student_id
             LEFT JOIN pet_templates pt ON pt.id = sp.pet_template_id
             WHERE o.turn_id = ? AND o.status = "active"
             ORDER BY o.target_node_code, o.slot'
        );
        $stmt->execute([$turnId]);
        $orders = $stmt->fetchAll();

        $byCity = [];
        foreach ($orders as $order) {
            $byCity[(string)$order['target_node_code']][] = $order;
        }

        $battles = [];
        foreach ($byCity as $nodeCode => $cityOrders) {
            $battle = $this->settleCity($gameId, $turnId, $nodeCode, $cityOrders);
            if ($battle !== null) {
                $battles[] = $battle;
            }
        }

        $stmt = $this->pdo->prepare(
            'UPDATE slice_turns SET status = "settled", settled_at = NOW()
             WHERE id = ? AND game_id = ? AND status != "settled"'
        );
        $stmt->execute([$turnId, $gameId]);

        return ['turn_id' => $turnId, 'already_settled' => false, 'battles' => $battles];
    }

    private function settleCity(int $gameId, int $turnId, string $nodeCode, array $orders): ?array
    {
        $stmt = $this->pdo->prepare('SELECT * FROM slice_nodes WHERE game_id = ? AND node_code = ?');
        $stmt->execute([$gameId, $nodeCode]);
        $node = $stmt->fetch();
        if (!$node) {
            return null;
        }

        // 哪個阵营令最多
        $counts = [];
        foreach ($orders as $order) {
            $fid = $order['faction_id'] === null ? 0 : (int)$order['faction_id'];
            $counts[$fid] = ($counts[$fid] ?? 0) + 1;
        }
        arsort($counts);
        $factionIds = array_keys($counts);
        if (count($factionIds) > 1 && $counts[$factionIds[0]] === $counts[$factionIds[1]]) {
            return ['node_code' => $nodeCode, 'battle_id' => null, 'reason' => 'standoff'];
        }
        $attackerFactionId = (int)$factionIds[0];
        if ($attackerFactionId <= 0) {
            return ['node_code' => $nodeCode, 'battle_id' => null, 'reason' => 'no_faction'];
        }
        $ownerFactionId = $node['owner_faction_id'] === null ? null : (int)$node['owner_faction_id'];
        if ($ownerFactionId === $attackerFactionId) {
            return ['node_code' => $nodeCode, 'battle_id' => null, 'reason' => 'already_owned'];
        }

        // 先锋：该阵营贡献前 3 名（按宠物战力），其余支援
        $factionOrders = array_values(array_filter(
            $orders,
            fn($o) => (int)($o['faction_id'] ?? 0) === $attackerFactionId
        ));
        usort($factionOrders, function ($a, $b) {
            return BattleService::petPower($b) <=> BattleService::petPower($a);
        });

        $vanguard = [];
        $seen = [];
        foreach ($factionOrders as $order) {
            $pid = (int)$order['player_id'];
            if (isset($seen[$pid])) {
                continue;
            }
            $seen[$pid] = true;
            $vanguard[] = $order;
            if (count($vanguard) >= 3) {
                break;
            }
        }
        if ($vanguard === []) {
            return ['node_code' => $nodeCode, 'battle_id' => null, 'reason' => 'no_vanguard'];
        }

        $troops = 0.0;
        foreach ($vanguard as $order) {
            $troops += BattleService::petPower($order);
        }
        $supporters = max(0, count($factionOrders) - count($vanguard));
        $troops *= BattleService::supportMultiplier($supporters) * 1.20;

        $composition = $this->compositionOf((int)$vanguard[0]['player_id'], $gameId);
        $general = $this->generalOf((string)($vanguard[0]['pet_code'] ?? ''));

        $attacker = [
            'general' => $general,
            'troops' => $troops,
            'composition' => $composition,
            'fire' => $this->hasFire($factionOrders),
        ];

        if ($ownerFactionId === null) {
            $defender = [
                'general' => 'def',
                'troops' => 1000.0 * 1.10,
                'composition' => ['shield', 'shield', 'arc'],
            ];
        } else {
            $defender = [
                'general' => 'def',
                'troops' => 1200.0 * 1.10,
                'composition' => ['shield', 'spear', 'arc'],
            ];
        }

        $result = $this->battleService->resolve($attacker, $defender);
        $battleId = $this->battleService->saveBattle(
            $gameId,
            $turnId,
            $nodeCode,
            $attackerFactionId,
            $ownerFactionId,
            $attacker,
            $defender,
            $result
        );
        $change = $this->settlement->apply(
            $gameId,
            $turnId,
            $nodeCode,
            $attackerFactionId,
            (int)$result['score']
        );

        return [
            'node_code' => $nodeCode,
            'battle_id' => $battleId,
            'score' => $result['score'],
            'wall' => $result['wall'],
            'attacker_faction_id' => $attackerFactionId,
            'owner_before' => $change['owner_before'],
            'owner_after' => $change['owner_after'],
            'captured' => $change['captured'],
            'morale_before' => $change['morale_before'],
            'morale_after' => $change['morale_after'],
            'reason' => $change['reason'],
        ];
    }

    private function compositionOf(int $playerId, int $gameId): array
    {
        $stmt = $this->pdo->prepare(
            'SELECT types_json FROM slice_compositions WHERE game_id = ? AND player_id = ? AND week_no = 1'
        );
        $stmt->execute([$gameId, $playerId]);
        $json = $stmt->fetchColumn();
        if ($json === false) {
            return ['cav', 'shield', 'arc'];
        }
        $types = json_decode((string)$json, true);
        if (!is_array($types) || count($types) !== 3) {
            return ['cav', 'shield', 'arc'];
        }
        return array_values($types);
    }

    private function generalOf(string $petCode): string
    {
        return match ($petCode) {
            'pet_inkdrop_01' => 'tac',
            'pet_bamboo_01' => 'def',
            default => 'def',
        };
    }

    private function hasFire(array $orders): bool
    {
        foreach ($orders as $order) {
            if ((string)($order['card_code'] ?? '') === 'fire_attack') {
                return true;
            }
        }
        return false;
    }
}
