<?php
declare(strict_types=1);

require_once __DIR__ . '/BattleService.php';
require_once __DIR__ . '/BattleSettlementService.php';
require_once __DIR__ . '/BulletinService.php';
require_once __DIR__ . '/MeritService.php';
require_once __DIR__ . '/ApiException.php';

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

    public const REGION_NODES = [
        'bi' => ['liangzhou', 'hanzhong', 'xiangyang'],
        'mo' => ['yecheng', 'taiyuan', 'luoyang'],
        'yan' => ['chengdu', 'jiangling', 'changsha'],
        'zhi' => ['jianye', 'kuaiji', 'shouchun'],
    ];

    public static function isTeamCard(string $card): bool
    {
        return in_array($card, self::TEAM_CARDS, true);
    }

    private PDO $pdo;
    private BattleService $battleService;
    private BattleSettlementService $settlement;
    private MeritService $meritService;

    public function __construct(PDO $pdo)
    {
        $this->pdo = $pdo;
        $this->battleService = new BattleService(null, $pdo);
        $this->settlement = new BattleSettlementService($pdo);
        $this->meritService = new MeritService($pdo);
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

        // 出令本身就有军功：让“今天来了、下了令”被看见
        $participantsThisTurn = array_values(array_unique(array_map(
            'intval',
            array_column($orders, 'player_id')
        )));
        foreach ($participantsThisTurn as $participantId) {
            $this->meritService->award(
                $gameId,
                $turnId,
                $participantId,
                'participation',
                5,
                ['turn_no' => (int)$turn['turn_no']]
            );
        }

        $byCity = [];
        foreach ($orders as $order) {
            $byCity[(string)$order['target_node_code']][] = $order;
        }

        $battles = [];
        $weekNo = self::weekOfTurn((int)$turn['turn_no']);
        $bulletins = (new BulletinService($this->pdo))->choicesForTurn($turnId);
        foreach ($byCity as $nodeCode => $cityOrders) {
            $battle = $this->settleCity($gameId, $turnId, $nodeCode, $cityOrders, $weekNo, $bulletins);
            if ($battle !== null) {
                $battles[] = $battle;
            }
        }

        $stmt = $this->pdo->prepare(
            'UPDATE slice_turns SET status = "settled", settled_at = NOW()
             WHERE id = ? AND game_id = ? AND status != "settled"'
        );
        $stmt->execute([$turnId, $gameId]);

        $this->saveTurnResult($gameId, $turnId, $battles);
        $this->finishSeasonIfNeeded($gameId, (int)$turn['turn_no']);

        return ['turn_id' => $turnId, 'already_settled' => false, 'battles' => $battles];
    }

    /**
     * 占长安直接获胜；第 28 回合（5 节点为第 3 回合）结算后也结束。
     */
    private function finishSeasonIfNeeded(int $gameId, int $turnNo): void
    {
        $stmt = $this->pdo->prepare(
            "SELECT COUNT(*) FROM slice_nodes
             WHERE game_id = ? AND node_type = 'king' AND owner_faction_id IS NOT NULL"
        );
        $stmt->execute([$gameId]);
        $kingOwned = (int)$stmt->fetchColumn() > 0;

        $stmt = $this->pdo->prepare('SELECT COUNT(*) FROM slice_nodes WHERE game_id = ?');
        $stmt->execute([$gameId]);
        $maxTurns = (int)$stmt->fetchColumn() >= 13 ? 28 : 3;

        if ($kingOwned || $turnNo >= $maxTurns) {
            $stmt = $this->pdo->prepare('UPDATE slice_games SET status = "finished" WHERE id = ?');
            $stmt->execute([$gameId]);
        }
    }

    /**
     * 战前预估：用当前已出的令，模拟一次不落库的战斗。
     *
     * @return array<string,mixed>
     */
    public function forecast(int $gameId, int $turnId, int $playerId, string $nodeCode): array
    {
        $stmt = $this->pdo->prepare('SELECT * FROM slice_nodes WHERE game_id = ? AND node_code = ?');
        $stmt->execute([$gameId, $nodeCode]);
        $node = $stmt->fetch();
        if (!$node) {
            throw new ApiException('NODE_NOT_FOUND', '城不存在', 404);
        }

        $stmt = $this->pdo->prepare('SELECT faction_id FROM slice_players WHERE id = ? AND game_id = ?');
        $stmt->execute([$playerId, $gameId]);
        $myFactionId = $stmt->fetchColumn();
        if ($myFactionId === false || $myFactionId === null) {
            throw new ApiException('NO_FACTION', '你还没有加入阵营', 409);
        }
        $myFactionId = (int)$myFactionId;
        $ownerFactionId = $node['owner_faction_id'] === null ? null : (int)$node['owner_faction_id'];

        $stmt = $this->pdo->prepare(
            'SELECT o.id, o.player_id, o.slot, o.card_code, o.target_node_code, o.lane, o.row_pos,
                    p.faction_id, p.student_id,
                    sp.level, pt.base_hp, pt.base_atk, pt.base_def, pt.base_spd,
                    pt.growth_rate, pt.code AS pet_code
             FROM slice_order_slots o
             JOIN slice_players p ON p.id = o.player_id
             LEFT JOIN student_pets sp ON sp.student_id = p.student_id
             LEFT JOIN pet_templates pt ON pt.id = sp.pet_template_id
             WHERE o.turn_id = ? AND o.target_node_code = ? AND o.status = "active"
             ORDER BY o.slot'
        );
        $stmt->execute([$turnId, $nodeCode]);
        $allOrders = $stmt->fetchAll();

        $myOrders = array_values(array_filter(
            $allOrders,
            fn($o) => (int)$o['player_id'] === $playerId
        ));
        if ($ownerFactionId !== null && $ownerFactionId === $myFactionId) {
            return [
                'node_code' => $nodeCode,
                'node_name' => (string)$node['name'],
                'role' => 'defend',
                'ready' => false,
                'reason' => 'DEFEND_CITY',
                'advice' => ['这是己方城，出令 = 驻守；战前预估只用于进攻。'],
            ];
        }
        if ($myOrders === []) {
            return [
                'node_code' => $nodeCode,
                'node_name' => (string)$node['name'],
                'role' => $ownerFactionId === $myFactionId ? 'defend' : 'attack',
                'ready' => false,
                'reason' => 'NO_ORDERS',
                'advice' => ['先给这座城出一张令，再来预估。'],
            ];
        }

        $weekNo = self::weekOfTurn((int)$this->pdo->query(
            'SELECT turn_no FROM slice_turns WHERE id = ' . $turnId
        )->fetchColumn());

        $factionOrders = array_values(array_filter(
            $allOrders,
            fn($o) => (int)($o['faction_id'] ?? 0) === $myFactionId
        ));
        $teamOrders = array_values(array_filter(
            $factionOrders,
            fn($o) => self::isTeamCard((string)$o['card_code'])
        ));
        $this->sortByPower($teamOrders);

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
            return [
                'node_code' => $nodeCode,
                'node_name' => (string)$node['name'],
                'role' => $ownerFactionId === $myFactionId ? 'defend' : 'attack',
                'ready' => false,
                'reason' => 'NO_VANGUARD',
                'advice' => ['队伍牌才能进战场；火攻/侦察/疑兵不占队伍位。'],
            ];
        }

        $supporters = max(0, count(array_unique(array_column($factionOrders, 'player_id'))) - count($vanguard));
        $supportMult = BattleService::supportMultiplier($supporters) * 1.20;
        $bulletins = (new BulletinService($this->pdo))->choicesForTurn($turnId);
        $teams = $this->teamsFromOrders($vanguard, $gameId, $weekNo, $supportMult, $bulletins);

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
            'supporters' => $supporters,
            'support_mult' => round($supportMult, 3),
        ];
        $siegeMult = 1.0;
        foreach ($vanguard as $order) {
            $siegeMult += BulletinService::siegeMultiplier($bulletins[(int)$order['player_id']] ?? null) - 1.0;
        }
        $attacker['siege_mult'] = round($siegeMult, 3);

        if ($this->factionOwnsNodeType($gameId, $myFactionId, 'camp')) {
            foreach ($teams as &$t) {
                $t['troops'] *= 1.05;
            }
            unset($t);
            $attacker['teams'] = $teams;
            $attacker['troops'] = array_sum(array_column($teams, 'troops'));
            $attacker['camp_bonus'] = true;
        } else {
            $attacker['camp_bonus'] = false;
        }
        if ($this->factionOwnsRegion($gameId, $myFactionId)) {
            foreach ($teams as &$t) {
                $t['troops'] *= 1.05;
            }
            unset($t);
            $attacker['teams'] = $teams;
            $attacker['troops'] = array_sum(array_column($teams, 'troops'));
            $attacker['region_bonus'] = true;
        } else {
            $attacker['region_bonus'] = false;
        }

        $defTeams = [];
        $defGeneral = 'def';
        $defSupporters = 0;
        $defSupportMult = 1.0;
        $realGarrison = false;
        if ($ownerFactionId !== null) {
            $defenderOrders = array_values(array_filter(
                $allOrders,
                fn($o) => (int)($o['faction_id'] ?? 0) === $ownerFactionId
                    && self::isTeamCard((string)$o['card_code'])
            ));
            $this->sortByPower($defenderOrders);
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
                $defSupportMult = BattleService::supportMultiplier($defSupporters);
                $defTeams = $this->teamsFromOrders($defVanguard, $gameId, $weekNo, $defSupportMult, $bulletins);
                $defGeneral = $this->generalOf((string)($defVanguard[0]['pet_code'] ?? ''));
                $realGarrison = true;
            }
        }
        if ($defTeams === []) {
            $fixed = ($ownerFactionId === null ? 730.0 : 1200.0) * 1.10;
            $comp = $ownerFactionId === null ? ['shield', 'shield', 'arc'] : ['shield', 'spear', 'arc'];
            foreach ($comp as $i => $type) {
                $defTeams[] = [
                    'type' => $type,
                    'troops' => $fixed / 3,
                    'lane' => $i + 1,
                    'row' => BattleEngine::TYPES[$type]['row'],
                    'card' => null,
                    'player_id' => null,
                ];
            }
        }
        $passBonus = $ownerFactionId !== null && $this->factionOwnsNodeType($gameId, $ownerFactionId, 'pass');
        if ($passBonus) {
            foreach ($defTeams as &$dt) {
                $dt['troops'] *= 1.10;
            }
            unset($dt);
        }
        $defender = [
            'general' => $defGeneral,
            'teams' => $defTeams,
            'troops' => array_sum(array_column($defTeams, 'troops')),
            'real_garrison' => $realGarrison,
            'pass_bonus' => $passBonus,
            'supporters' => $defSupporters,
            'support_mult' => round($defSupportMult, 3),
        ];

        $result = $this->battleService->resolve($attacker, $defender);

        $intelKnown = $ownerFactionId === null
            || $ownerFactionId === $myFactionId
            || $scouted
            || (new BulletinService($this->pdo))->revealsAll($turnId, $playerId);
        $cap = BattleSettlementService::cap((string)$node['node_type']);
        $moraleBefore = (int)$node['morale'];
        $moraleAfter = max(0, min($cap, $moraleBefore + (int)$result['score']));
        $captureEstimate = $moraleAfter >= $cap && $ownerFactionId !== $myFactionId;

        $defTroops = (float)$defender['troops'];
        $attTroops = (float)$attacker['troops'];
        $verdict = '均势';
        if ($attTroops >= $defTroops * 1.15 && (float)$result['wall'] <= 700) {
            $verdict = '优势';
        } elseif ($attTroops < $defTroops * 0.85 || (float)$result['wall'] > 1100) {
            $verdict = '劣势';
        }

        $advice = [];
        if (!$intelKnown) {
            $advice[] = '守军未知，先派哨探或接受风险。';
        } else {
            $defTypes = array_count_values(array_column($defTeams, 'type'));
            arsort($defTypes);
            $counterMap = ['cav' => 'shield', 'shield' => 'arc', 'arc' => 'spear', 'spear' => 'cav'];
            foreach ($defTypes as $defType => $count) {
                $best = array_search($defType, $counterMap, true);
                if ($best !== false) {
                    $advice[] = sprintf('敌 %s ×%d，建议带 %s。', BattleEngine::TYPES[$defType]['name'], $count, BattleEngine::TYPES[$best]['name']);
                }
            }
        }
        if (!$fire && (float)$result['wall'] > 400) {
            $advice[] = '带火攻可让器械攻墙 +50%。';
        }
        if ($supporters === 0 && count($factionOrders) < 3) {
            $advice[] = '叫同阵营支援，每人 +2%，上限 +30%。';
        }
        if (count($advice) === 0) {
            $advice[] = '阵容均衡，可以直接出令。';
        }

        return [
            'node_code' => $nodeCode,
            'node_name' => (string)$node['name'],
            'role' => $ownerFactionId === $myFactionId ? 'defend' : 'attack',
            'ready' => true,
            'intel_known' => $intelKnown,
            'attacker' => [
                'faction_id' => $myFactionId,
                'troops' => round($attTroops, 1),
                'teams' => $attacker['teams'],
                'supporters' => $supporters,
                'support_mult' => $attacker['support_mult'],
                'camp_bonus' => $attacker['camp_bonus'],
                'region_bonus' => $attacker['region_bonus'],
            ],
            'defender' => [
                'known' => $intelKnown,
                'faction_id' => $ownerFactionId,
                'troops' => $intelKnown ? round($defTroops, 1) : null,
                'troops_range' => $intelKnown ? null : [round($defTroops * 0.7), round($defTroops * 1.3)],
                'teams' => $intelKnown ? $defender['teams'] : [],
                'real_garrison' => $realGarrison,
                'pass_bonus' => $passBonus,
            ],
            'forecast' => [
                'wall' => (float)$result['wall'],
                'score' => (int)$result['score'],
                'ticks' => (int)$result['ticks'],
                'morale_before' => $moraleBefore,
                'morale_after' => $moraleAfter,
                'morale_cap' => $cap,
                'capture_estimate' => $captureEstimate,
                'verdict' => $verdict,
            ],
            'counters' => $result['counters'] ?? [],
            'counter_damage' => $result['counter_damage'] ?? [],
            'advice' => $advice,
        ];
    }

    /**
     * 卡牌结算也写一份 turn_result，保证 /api/slice/report 和战报页可用。
     */
    private function saveTurnResult(int $gameId, int $turnId, array $battles): void
    {
        $resultJson = json_encode([
            'mode' => 'cards',
            'battles' => $battles,
        ], JSON_UNESCAPED_UNICODE);

        $stmt = $this->pdo->prepare(
            'SELECT f.code, f.name, COUNT(n.id) AS cities, COALESCE(SUM(n.morale), 0) AS morale
             FROM slice_factions f
             LEFT JOIN slice_nodes n ON n.game_id = f.game_id AND n.owner_faction_id = f.id
             WHERE f.game_id = ?
             GROUP BY f.id, f.code, f.name, f.sort_order
             ORDER BY f.sort_order'
        );
        $stmt->execute([$gameId]);
        $standings = array_map(static fn($row) => [
            'code' => (string)$row['code'],
            'name' => (string)$row['name'],
            'cities' => (int)$row['cities'],
            'morale' => (int)$row['morale'],
        ], $stmt->fetchAll());
        $standingsJson = json_encode($standings, JSON_UNESCAPED_UNICODE);
        $hash = hash('sha256', (string)$resultJson . (string)$standingsJson);

        $stmt = $this->pdo->prepare(
            'INSERT INTO slice_turn_results (game_id, turn_id, result_json, standings_json, content_hash)
             VALUES (?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE
                result_json = VALUES(result_json),
                standings_json = VALUES(standings_json),
                content_hash = VALUES(content_hash)'
        );
        $stmt->execute([$gameId, $turnId, $resultJson, $standingsJson, $hash]);
    }

    private function settleCity(int $gameId, int $turnId, string $nodeCode, array $orders, int $weekNo, array $bulletins = []): ?array
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
        $this->sortByPower($teamOrders);

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
        $teams = $this->teamsFromOrders($vanguard, $gameId, $weekNo, $supportMult, $bulletins);

        // 邸报「攻城器械」：先锋每有一人选，攻城伤害 +25%，最多 +75%
        $siegeMult = 1.0;
        foreach ($vanguard as $order) {
            $siegeMult += BulletinService::siegeMultiplier($bulletins[(int)$order['player_id']] ?? null) - 1.0;
        }

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
            'supporters' => $supporters,
            'support_mult' => round($supportMult, 3),
            'siege_mult' => round($siegeMult, 3),
        ];

        // 大营：阵营拥有任意大营，进攻 +5% 兵力
        $campBonus = $this->factionOwnsNodeType($gameId, $attackerFactionId, 'camp');
        if ($campBonus) {
            foreach ($teams as &$t) {
                $t['troops'] *= 1.05;
            }
            unset($t);
            $attacker['teams'] = $teams;
            $attacker['troops'] = array_sum(array_column($teams, 'troops'));
            $attacker['camp_bonus'] = true;
        } else {
            $attacker['camp_bonus'] = false;
        }

        // 区域：阵营拿下本区 3 城，全军 +5%
        $regionBonus = $this->factionOwnsRegion($gameId, $attackerFactionId);
        if ($regionBonus) {
            foreach ($teams as &$t) {
                $t['troops'] *= 1.05;
            }
            unset($t);
            $attacker['teams'] = $teams;
            $attacker['troops'] = array_sum(array_column($teams, 'troops'));
            $attacker['region_bonus'] = true;
        } else {
            $attacker['region_bonus'] = false;
        }

        // 守军：城归属方的驻守令（打自己城 = 驻守）优先；没有才用固定守军。
        $defTeams = [];
        $defGeneral = 'def';
        $defTroops = 0.0;
        $realGarrison = false;
        $defSupporters = 0;
        $defSupportMult = 1.0;
        if ($ownerFactionId !== null) {
            $defenderOrders = [];
            foreach ($orders as $order) {
                if ((int)($order['faction_id'] ?? 0) === $ownerFactionId
                    && self::isTeamCard((string)$order['card_code'])) {
                    $defenderOrders[] = $order;
                }
            }
            $this->sortByPower($defenderOrders);

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
                $defSupportMult = BattleService::supportMultiplier($defSupporters);
                $defTeams = $this->teamsFromOrders(
                    $defVanguard,
                    $gameId,
                    $weekNo,
                    $defSupportMult,
                    $bulletins
                );
                $defGeneral = $this->generalOf((string)($defVanguard[0]['pet_code'] ?? ''));
                $defTroops = array_sum(array_column($defTeams, 'troops'));
                $realGarrison = true;
            }
        }

        if ($defTeams === []) {
            // 固定守军：中立 990 / 归属城 1320
            // 固定守军：中立 803 / 归属城 1320
            $defTroops = ($ownerFactionId === null ? 730.0 : 1200.0) * 1.10;
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
        // 关隘：守方拥有任意关隘，守军 +10%
        $passBonus = $ownerFactionId !== null && $this->factionOwnsNodeType($gameId, $ownerFactionId, 'pass');
        if ($passBonus) {
            foreach ($defTeams as &$dt) {
                $dt['troops'] *= 1.10;
            }
            unset($dt);
        }
        $defTroops = array_sum(array_column($defTeams, 'troops'));

        $defender = [
            'general' => $defGeneral,
            'teams' => $defTeams,
            'troops' => $defTroops,
            'real_garrison' => $realGarrison,
            'pass_bonus' => $passBonus,
            'supporters' => $defSupporters,
            'support_mult' => round($defSupportMult, 3),
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

        // 个人军功：按本场角色发放，只影响荣誉榜，不影响战力
        $meritAwarded = [];
        $grant = function (int $pid, string $kind, int $amount, string $role) use (
            &$meritAwarded,
            $gameId,
            $turnId,
            $nodeCode
        ): void {
            $this->meritService->award(
                $gameId,
                $turnId,
                $pid,
                $kind,
                $amount,
                ['node_code' => $nodeCode, 'role' => $role]
            );
            $meritAwarded[$pid]['total'] = ($meritAwarded[$pid]['total'] ?? 0) + $amount;
            $meritAwarded[$pid]['items'][] = [
                'kind' => $kind,
                'label' => MeritService::LABELS[$kind] ?? $kind,
                'amount' => $amount,
            ];
        };

        $vanguardIds = array_values(array_unique(array_map('intval', array_column($vanguard, 'player_id'))));
        $attackerIds = array_values(array_unique(array_map('intval', array_column($factionOrders, 'player_id'))));
        $supportIds = array_values(array_diff($attackerIds, $vanguardIds));

        foreach ($vanguardIds as $pid) {
            $grant($pid, 'vanguard', 20, 'vanguard');
            if ($change['captured']) {
                $grant($pid, 'capture', 40, 'vanguard');
            } elseif ((int)$result['score'] > 0) {
                $grant($pid, 'assault', 10, 'vanguard');
            }
        }
        foreach ($supportIds as $pid) {
            $grant($pid, 'support', 10, 'support');
            if ($change['captured']) {
                $grant($pid, 'capture_support', 15, 'support');
            }
        }
        foreach ($factionOrders as $order) {
            $pid = (int)$order['player_id'];
            $card = (string)$order['card_code'];
            if ($card === 'scout') {
                $grant($pid, 'scout', 8, 'scout');
            } elseif ($card === 'fire_attack') {
                $grant($pid, 'fire', 10, 'fire');
            }
        }
        if ($realGarrison) {
            $defIds = array_values(array_unique(array_map(
                'intval',
                array_column($defVanguard, 'player_id')
            )));
            foreach ($defIds as $pid) {
                $grant($pid, 'garrison', 15, 'defender');
                if (!$change['captured']) {
                    $grant($pid, 'defend', 30, 'defender');
                }
            }
        }

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
            'merit' => $meritAwarded,
            'contribution' => $result['players'] ?? [],
            'counters' => $result['counters'] ?? [],
            'counter_damage' => $result['counter_damage'] ?? [],
        ];
    }

    private function sortByPower(array &$orders): void
    {
        usort($orders, function ($a, $b) {
            $cmp = BattleService::petPower($b) <=> BattleService::petPower($a);
            if ($cmp !== 0) {
                return $cmp;
            }
            return (int)($a['player_id'] ?? 0) <=> (int)($b['player_id'] ?? 0);
        });
    }

    private function factionOwnsRegion(int $gameId, int $factionId): bool
    {
        $stmt = $this->pdo->prepare('SELECT code FROM slice_factions WHERE id = ? AND game_id = ?');
        $stmt->execute([$factionId, $gameId]);
        $code = (string)$stmt->fetchColumn();
        $nodes = self::REGION_NODES[$code] ?? [];
        if ($nodes === []) {
            return false;
        }
        $in = implode(',', array_fill(0, count($nodes), '?'));
        $stmt = $this->pdo->prepare(
            "SELECT COUNT(*) FROM slice_nodes
             WHERE game_id = ? AND owner_faction_id = ? AND node_code IN ({$in})"
        );
        $stmt->execute(array_merge([$gameId, $factionId], $nodes));
        return (int)$stmt->fetchColumn() === count($nodes);
    }

    private function factionOwnsNodeType(int $gameId, int $factionId, string $nodeType): bool
    {
        $stmt = $this->pdo->prepare(
            'SELECT 1 FROM slice_nodes
             WHERE game_id = ? AND owner_faction_id = ? AND node_type = ? LIMIT 1'
        );
        $stmt->execute([$gameId, $factionId, $nodeType]);
        return $stmt->fetchColumn() !== false;
    }

    /**
     * 把 3 个先锋令转成 3 支队伍（攻守共用）。
     *
     * @param array<int,array> $vanguard
     * @return array<int,array{type:string,troops:float,lane:int,row:string,card:string}>
     */
    private function teamsFromOrders(array $vanguard, int $gameId, int $weekNo, float $mult, array $bulletins = []): array
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
            $playerId = (int)$order['player_id'];
            $bulletinChoice = $bulletins[$playerId] ?? null;
            $teams[] = [
                'type' => $type,
                'troops' => BattleService::petPower($order) / 3 * $mult * BulletinService::teamMultiplier($bulletinChoice),
                'lane' => $lane,
                'row' => $row,
                'card' => (string)$order['card_code'],
                'player_id' => $playerId,
                'bulletin' => $bulletinChoice,
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
