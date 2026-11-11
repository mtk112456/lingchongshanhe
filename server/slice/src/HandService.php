<?php
declare(strict_types=1);

require_once __DIR__ . '/HandDeck.php';
require_once __DIR__ . '/BattleEngine.php';
require_once __DIR__ . '/ApiException.php';

/**
 * 每日手牌 / 每周编成 / 3 个出牌位的持久化服务。
 *
 * 表：
 *   slice_hands         每日 4 张手牌、是否重抽、种子
 *   slice_order_slots   3 个出牌位
 *   slice_compositions  每周编成
 */
final class HandService
{
    private PDO $pdo;

    public function __construct(PDO $pdo)
    {
        $this->pdo = $pdo;
    }

    public function seed(int $gameId, int $turnId, int $playerId): string
    {
        // 48 字符，留出 ":redraw" 后缀也不超过 VARCHAR(64)
        return substr(hash('sha256', "game:{$gameId}:turn:{$turnId}:player:{$playerId}"), 0, 48);
    }

    /**
     * @return array{cards:string[],redraw_used:bool,seed:string}
     */
    public function getOrCreateHand(int $gameId, int $turnId, int $playerId): array
    {
        $stmt = $this->pdo->prepare(
            'SELECT cards_json, redraw_used, hand_seed FROM slice_hands WHERE turn_id = ? AND player_id = ?'
        );
        $stmt->execute([$turnId, $playerId]);
        $row = $stmt->fetch();
        if ($row) {
            $cards = json_decode((string)$row['cards_json'], true);
            $seed = (string)$row['hand_seed'];
            return [
                'cards' => is_array($cards) ? array_values($cards) : [],
                'redraw_used' => (bool)$row['redraw_used'],
                'seed' => $seed,
                'preview' => $this->previewCards($seed, $gameId, $playerId),
            ];
        }

        $seed = $this->seed($gameId, $turnId, $playerId);
        $cards = HandDeck::draw($seed);
        $stmt = $this->pdo->prepare(
            'INSERT INTO slice_hands (game_id, turn_id, player_id, cards_json, redraw_used, hand_seed)
             VALUES (?, ?, ?, ?, 0, ?)'
        );
        $stmt->execute([$gameId, $turnId, $playerId, $this->encode($cards), $seed]);

        return [
            'cards' => $cards,
            'redraw_used' => false,
            'seed' => $seed,
            'preview' => $this->previewCards($seed, $gameId, $playerId),
        ];
    }

    /**
     * 书房：预读接下来 N 张牌（不改变手牌，只是提前看到）。
     *
     * @return string[]
     */
    private function previewCards(string $seed, int $gameId, int $playerId): array
    {
        $count = $this->studyLevel($gameId, $playerId);
        if ($count <= 0) {
            return [];
        }
        $all = HandDeck::draw($seed, HandDeck::HAND_SIZE + $count);
        return array_slice($all, HandDeck::HAND_SIZE, $count);
    }

    private function studyLevel(int $gameId, int $playerId): int
    {
        $stmt = $this->pdo->prepare(
            'SELECT study_level FROM slice_estates WHERE game_id = ? AND player_id = ?'
        );
        $stmt->execute([$gameId, $playerId]);
        $level = $stmt->fetchColumn();
        return max(0, $level === false ? 0 : (int)$level);
    }

    /**
     * @return array{cards:string[],redraw_used:bool,seed:string}
     */
    public function redraw(int $gameId, int $turnId, int $playerId): array
    {
        $this->assertTurnEditable($turnId, $playerId, $gameId);
        $hand = $this->getOrCreateHand($gameId, $turnId, $playerId);
        if ($hand['redraw_used']) {
            throw new RuntimeException('REDRAW_USED');
        }

        $cards = HandDeck::redraw($hand['seed']);
        $newSeed = $hand['seed'] . ':redraw';
        $stmt = $this->pdo->prepare(
            'UPDATE slice_hands SET cards_json = ?, redraw_used = 1, hand_seed = ?
             WHERE turn_id = ? AND player_id = ?'
        );
        $stmt->execute([$this->encode($cards), $newSeed, $turnId, $playerId]);

        return [
            'cards' => $cards,
            'redraw_used' => true,
            'seed' => $newSeed,
            'preview' => $this->previewCards($newSeed, $gameId, $playerId),
        ];
    }

    /**
     * @return array<int,array> active orders
     */
    public function getOrders(int $turnId, int $playerId): array
    {
        $stmt = $this->pdo->prepare(
            "SELECT slot, card_code, target_node_code, lane, row_pos, last_request_key
             FROM slice_order_slots
             WHERE turn_id = ? AND player_id = ? AND status = 'active'
             ORDER BY slot"
        );
        $stmt->execute([$turnId, $playerId]);
        return $stmt->fetchAll() ?: [];
    }

    /**
     * @return array{slot:int,card_code:string,target_node_code:string,lane:?int,row_pos:?string}
     */
    public function play(
        int $gameId,
        int $turnId,
        int $playerId,
        int $slot,
        string $card,
        string $targetNodeCode,
        ?int $lane,
        ?string $row,
        string $requestKey
    ): array {
        if ($slot < 0 || $slot > 2) {
            throw new InvalidArgumentException('BAD_SLOT');
        }
        if ($targetNodeCode === '') {
            throw new InvalidArgumentException('EMPTY_TARGET');
        }
        if ($lane !== null && ($lane < 1 || $lane > 3)) {
            throw new InvalidArgumentException('BAD_LANE');
        }
        if ($row !== null && !in_array($row, ['front', 'back'], true)) {
            throw new InvalidArgumentException('BAD_ROW');
        }
        if ($requestKey === '' || !preg_match('/^[A-Za-z0-9_-]{8,64}$/', $requestKey)) {
            throw new InvalidArgumentException('BAD_REQUEST_KEY');
        }

        $this->assertTurnEditable($turnId, $playerId, $gameId);
        $this->assertSeasonTarget($gameId, $turnId, $targetNodeCode);
        $this->assertAdjacentTarget($gameId, $playerId, $targetNodeCode);

        $hand = $this->getOrCreateHand($gameId, $turnId, $playerId);
        $orders = $this->getOrders($turnId, $playerId);

        $existingSlot = null;
        foreach ($orders as $order) {
            if ((int)$order['slot'] === $slot) {
                $existingSlot = $order;
                break;
            }
        }

        $played = [];
        foreach ($orders as $order) {
            if ((int)$order['slot'] !== $slot) {
                $played[] = (string)$order['card_code'];
            }
        }

        HandDeck::validatePlay($hand['cards'], $card, $played);

        if ($existingSlot === null && count($orders) >= HandDeck::PLAY_LIMIT) {
            throw new RuntimeException('PLAY_LIMIT_REACHED');
        }

        $stmt = $this->pdo->prepare(
            'INSERT INTO slice_order_slots
                (game_id, turn_id, player_id, slot, card_code, target_node_code, lane, row_pos, status, last_request_key)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, "active", ?)
             ON DUPLICATE KEY UPDATE
                card_code = VALUES(card_code),
                target_node_code = VALUES(target_node_code),
                lane = VALUES(lane),
                row_pos = VALUES(row_pos),
                status = "active",
                last_request_key = VALUES(last_request_key)'
        );
        $stmt->execute([$gameId, $turnId, $playerId, $slot, $card, $targetNodeCode, $lane, $row, $requestKey]);

        return [
            'slot' => $slot,
            'card_code' => $card,
            'target_node_code' => $targetNodeCode,
            'lane' => $lane,
            'row_pos' => $row,
        ];
    }

    public function withdraw(int $turnId, int $playerId, int $slot): bool
    {
        $this->assertTurnEditable($turnId, $playerId);
        $stmt = $this->pdo->prepare(
            "UPDATE slice_order_slots SET status = 'withdrawn'
             WHERE turn_id = ? AND player_id = ? AND slot = ? AND status = 'active'"
        );
        $stmt->execute([$turnId, $playerId, $slot]);
        return $stmt->rowCount() > 0;
    }

    /**
     * @return array{types:string[],changed_once:bool,changes_used:int,changes_allowed:int}
     */
    public function getComposition(int $gameId, int $playerId, int $weekNo): array
    {
        $stmt = $this->pdo->prepare(
            'SELECT types_json, changed_once, changes_used FROM slice_compositions
             WHERE game_id = ? AND player_id = ? AND week_no = ?'
        );
        $stmt->execute([$gameId, $playerId, $weekNo]);
        $row = $stmt->fetch();
        $allowed = $this->allowedCompositionChanges($gameId, $playerId);
        if (!$row) {
            return [
                'types' => ['cav', 'shield', 'arc'],
                'changed_once' => false,
                'changes_used' => 0,
                'changes_allowed' => $allowed,
            ];
        }
        $types = json_decode((string)$row['types_json'], true);
        return [
            'types' => is_array($types) ? array_values($types) : ['cav', 'shield', 'arc'],
            'changed_once' => (bool)$row['changed_once'],
            'changes_used' => (int)($row['changes_used'] ?? 0),
            'changes_allowed' => $allowed,
        ];
    }

    private function allowedCompositionChanges(int $gameId, int $playerId): int
    {
        $stmt = $this->pdo->prepare(
            'SELECT drill_level FROM slice_estates WHERE game_id = ? AND player_id = ?'
        );
        $stmt->execute([$gameId, $playerId]);
        $level = $stmt->fetchColumn();
        return max(1, $level === false ? 1 : (int)$level);
    }

    /**
     * 第一次设置 = 本周编成；第二次 = 周中改一次；第三次拒绝。
     *
     * @param string[] $types
     * @return array{types:string[],changed_once:bool}
     */
    public function setComposition(int $gameId, int $playerId, int $weekNo, array $types): array
    {
        if (count($types) !== 3) {
            throw new InvalidArgumentException('NEEDS_3_TYPES');
        }
        foreach ($types as $type) {
            if (!isset(BattleEngine::TYPES[$type])) {
                throw new InvalidArgumentException('UNKNOWN_UNIT_TYPE: ' . $type);
            }
        }

        $current = $this->getComposition($gameId, $playerId, $weekNo);
        $stmt = $this->pdo->prepare(
            'SELECT changed_once, changes_used FROM slice_compositions
             WHERE game_id = ? AND player_id = ? AND week_no = ?'
        );
        $stmt->execute([$gameId, $playerId, $weekNo]);
        $row = $stmt->fetch();
        $allowed = $this->allowedCompositionChanges($gameId, $playerId);
        if ($row && (int)($row['changes_used'] ?? 0) >= $allowed) {
            throw new RuntimeException('COMPOSITION_LOCKED');
        }

        $stmt = $this->pdo->prepare(
            'INSERT INTO slice_compositions
                (game_id, player_id, week_no, types_json, changed_once, changes_used)
             VALUES (?, ?, ?, ?, 0, 0)
             ON DUPLICATE KEY UPDATE
                types_json = VALUES(types_json),
                changed_once = 1,
                changes_used = changes_used + 1'
        );
        $stmt->execute([$gameId, $playerId, $weekNo, $this->encode(array_values($types))]);

        return [
            'types' => array_values($types),
            'changed_once' => $row !== false,
            'changes_used' => $row === false ? 0 : (int)($row['changes_used'] ?? 0) + 1,
            'changes_allowed' => $allowed,
        ];
    }

    /**
     * 出令/撤令/重抽前校验：回合属于本局、游戏运行中、回合开放、未过截止。
     */
    private function assertTurnEditable(int $turnId, int $playerId, ?int $gameId = null): void
    {
        $stmt = $this->pdo->prepare(
            'SELECT t.id, t.game_id, t.status, t.deadline_at, g.status AS game_status
             FROM slice_turns t JOIN slice_games g ON g.id = t.game_id
             WHERE t.id = ?'
        );
        $stmt->execute([$turnId]);
        $turn = $stmt->fetch();
        if (!$turn) {
            throw new ApiException('TURN_NOT_FOUND', '回合不存在', 404);
        }
        if ($gameId !== null && (int)$turn['game_id'] !== $gameId) {
            throw new ApiException('WRONG_GAME', '这个回合不属于当前游戏', 403);
        }
        $stmt = $this->pdo->prepare('SELECT 1 FROM slice_players WHERE id = ? AND game_id = ?');
        $stmt->execute([$playerId, (int)$turn['game_id']]);
        if ($stmt->fetchColumn() === false) {
            throw new ApiException('NOT_IN_GAME', '你不在这个游戏里', 403);
        }
        if ((string)$turn['game_status'] !== 'running') {
            throw new ApiException('GAME_PAUSED', '游戏已暂停，暂时不能出令', 409);
        }
        if ((string)$turn['status'] !== 'open') {
            throw new ApiException('TURN_NOT_OPEN', '本回合已锁定或结算，不能再改令', 409, [
                'turn_status' => (string)$turn['status'],
            ]);
        }
        if (strtotime((string)$turn['deadline_at']) <= time()) {
            throw new ApiException('TURN_DEADLINE_PASSED', '本回合已过截止时间', 409, [
                'deadline_at' => (string)$turn['deadline_at'],
            ]);
        }
    }

    /**
     * 只能打己方领土相邻的城；打自己城 = 驻守。
     * 没有任何领土时放行（避免新局锁死）。
     */
    private function assertAdjacentTarget(int $gameId, int $playerId, string $target): void
    {
        $stmt = $this->pdo->prepare('SELECT faction_id FROM slice_players WHERE id = ? AND game_id = ?');
        $stmt->execute([$playerId, $gameId]);
        $factionId = $stmt->fetchColumn();
        if ($factionId === false || $factionId === null) {
            return;
        }
        $factionId = (int)$factionId;

        $stmt = $this->pdo->prepare(
            'SELECT node_type, owner_faction_id FROM slice_nodes WHERE game_id = ? AND node_code = ?'
        );
        $stmt->execute([$gameId, $target]);
        $targetNode = $stmt->fetch();
        if ($targetNode !== false
            && (string)$targetNode['node_type'] === 'start'
            && $targetNode['owner_faction_id'] !== null
            && (int)$targetNode['owner_faction_id'] !== $factionId
        ) {
            throw new InvalidArgumentException('ENEMY_START');
        }

        $stmt = $this->pdo->prepare(
            'SELECT 1 FROM slice_nodes WHERE game_id = ? AND node_code = ? AND owner_faction_id = ? LIMIT 1'
        );
        $stmt->execute([$gameId, $target, $factionId]);
        if ($stmt->fetchColumn() !== false) {
            return;
        }

        $stmt = $this->pdo->prepare(
            'SELECT node_code FROM slice_nodes WHERE game_id = ? AND owner_faction_id = ?'
        );
        $stmt->execute([$gameId, $factionId]);
        $owned = array_map('strval', $stmt->fetchAll(PDO::FETCH_COLUMN));
        if ($owned === []) {
            throw new InvalidArgumentException('NO_TERRITORY');
        }

        $in = implode(',', array_fill(0, count($owned), '?'));
        $sql = "SELECT 1 FROM slice_edges
                WHERE game_id = ?
                  AND ((a_node_code = ? AND b_node_code IN ({$in}))
                    OR (b_node_code = ? AND a_node_code IN ({$in})))
                LIMIT 1";
        $params = array_merge([$gameId, $target], $owned, [$target], $owned);
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($params);
        if ($stmt->fetchColumn() === false) {
            throw new InvalidArgumentException('NOT_ADJACENT');
        }
    }

    /**
     * 12+1 城赛季规则：
     *   - 长安第 3 周才开放；
     *   - 第 4 周只能打长安或长安邻城。
     * 5 节点切片没有 king 节点，直接跳过。
     */
    private function assertSeasonTarget(int $gameId, int $turnId, string $target): void
    {
        $stmt = $this->pdo->prepare('SELECT turn_no FROM slice_turns WHERE id = ? AND game_id = ?');
        $stmt->execute([$turnId, $gameId]);
        $turnNo = $stmt->fetchColumn();
        if ($turnNo === false) {
            return;
        }
        $week = Clock::weekOfTurn((int)$turnNo);

        $stmt = $this->pdo->prepare('SELECT node_type FROM slice_nodes WHERE game_id = ? AND node_code = ?');
        $stmt->execute([$gameId, $target]);
        $nodeType = $stmt->fetchColumn();
        if ($nodeType === false) {
            throw new InvalidArgumentException('UNKNOWN_TARGET');
        }

        $stmt = $this->pdo->prepare(
            "SELECT node_code FROM slice_nodes WHERE game_id = ? AND node_type = 'king' LIMIT 1"
        );
        $stmt->execute([$gameId]);
        $kingCode = $stmt->fetchColumn();
        if ($kingCode === false) {
            return;
        }
        $kingCode = (string)$kingCode;

        if ($week < 3 && $target === $kingCode) {
            throw new InvalidArgumentException('CHANGAN_LOCKED');
        }

        if ($week >= 4) {
            $allowed = [$kingCode];
            $stmt = $this->pdo->prepare(
                'SELECT a_node_code, b_node_code FROM slice_edges
                 WHERE game_id = ? AND (a_node_code = ? OR b_node_code = ?)'
            );
            $stmt->execute([$gameId, $kingCode, $kingCode]);
            foreach ($stmt->fetchAll() as $edge) {
                $allowed[] = (string)$edge['a_node_code'] === $kingCode
                    ? (string)$edge['b_node_code']
                    : (string)$edge['a_node_code'];
            }
            if (!in_array($target, $allowed, true)) {
                throw new InvalidArgumentException('SEASON_FINAL_WEEK');
            }
        }
    }

    private function encode(array $data): string
    {
        $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        if ($json === false) {
            throw new RuntimeException('JSON_ENCODE_FAILED');
        }
        return $json;
    }
}
