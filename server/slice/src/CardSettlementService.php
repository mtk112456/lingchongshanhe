<?php
declare(strict_types=1);

require_once __DIR__ . '/BattleService.php';
require_once __DIR__ . '/BattleSettlementService.php';

/**
 * 21:00 卡牌结算：把 slice_order_slots 按城聚合，打一场，推民心。
 *
 * 规则（Phase 1.5）：
 *   - 每座城只打一场；
 *   - 攻方 = 该城令数最多的阵营；并列则对峙，不结算；
 *   - 先锋 = 该阵营贡献前 3 名学生，各出 1 只班宠 + 1 支队伍；
 *   - 一令 = 一队：兵种取该玩家本周编成的对应位，位置与战术取该令自己的；
 *   - 其余支援 +2%/人，上限 +30%；
 *   - 守方 = 城归属方（Phase 1 仍是固定守军）；
 *   - 结果写入 slice_battles，民心写入 slice_nodes。
 */
final class CardSettlementService
{
    /**
     * 只有这些牌会带一支队伍上场。
     * 火攻挂器械；哨探/疑兵只出情报，都不占队伍位。
     */
    public const TEAM_CARDS = [
        'night_raid', 'forced_march', 'fortify', 'mutual_support', 'empty_fort',
        'last_stand', 'counter_intel', 'supply', 'cut_supply',
    ];

    public static function isTeamCard(string $card): bool
    {
        return in_array($card, self::TEAM_CARDS, true);
    }

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
        $weekNo = self::weekOfTurn((int)$turn['turn_no']);
        foreach ($byCity as $nodeCode => $cityOrders) {
            $battle = $this->settleCity($gameId, $turnId, $nodeCode, $cityOrders, $weekNo);
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

    private function settleCity(int $gameId, int $turnId, string $nodeCode, array $orders, int $weekNo): ?array
    {
        $stmt = $this->pdo->prepare('SELECT * FROM slice_nodes WHERE game_id = ? AND node_code = ?');
        $stmt->execute([$gameId, $nodeCode]);
        $node = $stmt->fetch();
        if (!$node) {
            return null;
        }

        // 哪个阵营令最多：一名学生一票，守方自己的令不算进攻
        $ownerFactionId = $node['owner_faction_id'] === null ? null : (int)$node['owner_faction_id'];
        $votes = [];
        foreach ($orders as $order) {
            $fid = $order['faction_id'] === null ? 0 : (int)$order['faction_id'];
            if ($fid <= 0) {
                continue;
            }
            if ($ownerFactionId !== null && $fid === $ownerFactionId) {
                continue;
            }
            $votes[$fid][(int)$order['player_id']] = true;
        }
        $counts = array_map('count', $votes);
        arsort($counts);
        $factionIds = array_keys($counts);
        if ($counts === []) {
            return ['node_code' => $nodeCode, 'battle_id' => null, 'reason' => 'already_owned'];
        }
        if (count($factionIds) > 1 && $counts[$factionIds[0]] === $counts[$factionIds[1]]) {
            return ['node_code' => $nodeCode, 'battle_id' => null, 'reason' => 'standoff'];
        }
        $attackerFactionId = (int)$factionIds[0];
        if ($attackerFactionId <= 0) {
            return ['node_code' => $nodeCode, 'battle_id' => null, 'reason' => 'no_faction'];
        }

        // 先锋：该阵营贡献前 3 名（按宠物战力，一名玩家只带 1 队）
        $factionOrders = array_values(array_filter(
            $orders,
            fn($o) => (int)($o['faction_id'] ?? 0) === $attackerFactionId
        ));

        // 只有队伍牌能带兵；火攻/哨探/疑兵不占队伍位
        $teamOrders = array_values(array_filter(
            $factionOrders,
            fn($o) => self::isTeamCard((string)$o['card_code'])
        ));
        usort($teamOrders, function ($a, $b) {
            return BattleService::petPower($b) <=> BattleService::petPower($a);
        });

        $vanguard = [];
        $seen = [];
        foreach ($teamOrders as $order) {
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

        $supporters = max(0, count(array_unique(array_column($factionOrders, 'player_id'))) - count($vanguard));
        $supportMult = BattleService::supportMultiplier($supporters) * 1.20;

        // 一令 = 一队：兵种取该玩家本周编成的对应位，位置与牌取该令自己的
        $teams = $this->teamsFromOrders($vanguard, $gameId, $weekNo, $supportMult);

        $scouted = false;
        $fire = false;
        foreach ($factionOrders as $order) {
            if ((string)$order['card_code'] === 'scout') {
                $scouted = true;
            }
            if ((string)$order['card_code'] === 'fire_attack') {
                $fire = true;
            }
        }

        $attacker = [
            'general' => $this->generalOf((string)($vanguard[0]['pet_code'] ?? '')),
            'teams' => $teams,
            'troops' => array_sum(array_column($teams, 'troops')),
            'scouted' => $scouted,
            'fire' => $fire,
        ];

        // 守军：城归属方的驻守令（打自己城 = 驻守）优先；没有才用固定守军。
        $defTeams = [];
        $defGeneral = 'def';
        $defTroops = 0.0;
        $realGarrison = false;
        if ($ownerFactionId !== null) {
            $defenderOrders = [];
            foreach ($orders as $order) {
                if ((int)($order['faction_id'] ?? 0) === $ownerFactionId
                    && self::isTeamCard((string)$order['card_code'])) {
                    $defenderOrders[] = $order;
                }
            }
            usort($defenderOrders, fn($a, $b) => BattleService::petPower($b) <=> BattleService::petPower($a));

            $defVanguard = [];
            $seenDef = [];
            foreach ($defenderOrders as $order) {
                $pid = (int)$order['player_id'];
                if (isset($seenDef[$pid])) {
                    continue;
                }
                $seenDef[$pid] = true;
                $defVanguard[] = $order;
                if (count($defVanguard) >= 3) {
                    break;
                }
            }
            if ($defVanguard !== []) {
                $defSupporters = max(0, count(array_unique(array_column($defenderOrders, 'player_id'))) - count($defVanguard));
                $defTeams = $this->teamsFromOrders(
                    $defVanguard,
                    $gameId,
                    $weekNo,
                    BattleService::supportMultiplier($defSupporters)
                );
                $defGeneral = $this->generalOf((string)($defVanguard[0]['pet_code'] ?? ''));
                $defTroops = array_sum(array_column($defTeams, 'troops'));
                $realGarrison = true;
            }
        }

        if ($defTeams === []) {
            // 固定守军：中立 990 / 归属城 1320
            $defTroops = ($ownerFactionId === null ? 900.0 : 1200.0) * 1.10;
            $defComp = $ownerFactionId === null
                ? ['shield', 'shield', 'arc']
                : ['shield', 'spear', 'arc'];
            foreach ($defComp as $i => $type) {
                $defTeams[] = [
                    'type' => $type,
                    'troops' => $defTroops / 3,
                    'lane' => $i + 1,
                    'row' => BattleEngine::TYPES[$type]['row'],
                    'card' => null,
                ];
            }
        }
        $defender = [
            'general' => $defGeneral,
            'teams' => $defTeams,
            'troops' => $defTroops,
            'real_garrison' => $realGarrison,
        ];

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
            'scouted' => $scouted,
            'fire' => $fire,
            'teams' => $teams,
            'defender_teams' => $defTeams,
            'real_garrison' => $realGarrison,
        ];
    }

    /**
     * 把 3 个先锋令转成 3 支队伍（攻守共用）。
     *
     * @param array<int,array> $vanguard
     * @return array<int,array{type:string,troops:float,lane:int,row:string,card:string}>
     */
    private function teamsFromOrders(array $vanguard, int $gameId, int $weekNo, float $mult): array
    {
        $teams = [];
        foreach ($vanguard as $i => $order) {
            $slot = max(0, min(2, (int)$order['slot']));
            $composition = $this->compositionOf((int)$order['player_id'], $gameId, $weekNo);
            $type = $composition[$slot] ?? $composition[$i] ?? 'shield';
            $lane = $order['lane'] === null ? $i + 1 : (int)$order['lane'];
            $row = (string)($order['row_pos'] ?? '');
            if (!in_array($row, ['front', 'back'], true)) {
                $row = BattleEngine::TYPES[$type]['row'];
            }
            if ($type === 'arc') {
                $row = 'back';
            }
            $teams[] = [
                'type' => $type,
                'troops' => BattleService::petPower($order) / 3 * $mult,
                'lane' => $lane,
                'row' => $row,
                'card' => (string)$order['card_code'],
                'player_id' => (int)$order['player_id'],
            ];
        }
        return $teams;
    }

    /**
     * 4 周赛季，每周 7 个回合。
     */
    public static function weekOfTurn(int $turnNo): int
    {
        return Clock::weekOfTurn($turnNo);
    }

    private function compositionOf(int $playerId, int $gameId, int $weekNo): array
    {
        $stmt = $this->pdo->prepare(
            'SELECT types_json FROM slice_compositions WHERE game_id = ? AND player_id = ? AND week_no = ?'
        );
        $stmt->execute([$gameId, $playerId, $weekNo]);
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
}
