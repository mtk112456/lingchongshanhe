<?php
declare(strict_types=1);

require_once __DIR__ . '/HandDeck.php';
require_once __DIR__ . '/BattleEngine.php';

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
            return [
                'cards' => is_array($cards) ? array_values($cards) : [],
                'redraw_used' => (bool)$row['redraw_used'],
                'seed' => (string)$row['hand_seed'],
            ];
        }

        $seed = $this->seed($gameId, $turnId, $playerId);
        $cards = HandDeck::draw($seed);
        $stmt = $this->pdo->prepare(
            'INSERT INTO slice_hands (game_id, turn_id, player_id, cards_json, redraw_used, hand_seed)
             VALUES (?, ?, ?, ?, 0, ?)'
        );
        $stmt->execute([$gameId, $turnId, $playerId, $this->encode($cards), $seed]);

        return ['cards' => $cards, 'redraw_used' => false, 'seed' => $seed];
    }

    /**
     * @return array{cards:string[],redraw_used:bool,seed:string}
     */
    public function redraw(int $gameId, int $turnId, int $playerId): array
    {
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

        return ['cards' => $cards, 'redraw_used' => true, 'seed' => $newSeed];
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
        $stmt = $this->pdo->prepare(
            "UPDATE slice_order_slots SET status = 'withdrawn'
             WHERE turn_id = ? AND player_id = ? AND slot = ? AND status = 'active'"
        );
        $stmt->execute([$turnId, $playerId, $slot]);
        return $stmt->rowCount() > 0;
    }

    /**
     * @return array{types:string[],changed_once:bool}
     */
    public function getComposition(int $gameId, int $playerId, int $weekNo): array
    {
        $stmt = $this->pdo->prepare(
            'SELECT types_json, changed_once FROM slice_compositions
             WHERE game_id = ? AND player_id = ? AND week_no = ?'
        );
        $stmt->execute([$gameId, $playerId, $weekNo]);
        $row = $stmt->fetch();
        if (!$row) {
            return ['types' => ['cav', 'shield', 'arc'], 'changed_once' => false];
        }
        $types = json_decode((string)$row['types_json'], true);
        return [
            'types' => is_array($types) ? array_values($types) : ['cav', 'shield', 'arc'],
            'changed_once' => (bool)$row['changed_once'],
        ];
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
            'SELECT changed_once FROM slice_compositions
             WHERE game_id = ? AND player_id = ? AND week_no = ?'
        );
        $stmt->execute([$gameId, $playerId, $weekNo]);
        $row = $stmt->fetch();
        if ($row && (bool)$row['changed_once']) {
            throw new RuntimeException('COMPOSITION_LOCKED');
        }

        $stmt = $this->pdo->prepare(
            'INSERT INTO slice_compositions (game_id, player_id, week_no, types_json, changed_once)
             VALUES (?, ?, ?, ?, 0)
             ON DUPLICATE KEY UPDATE types_json = VALUES(types_json), changed_once = 1'
        );
        $stmt->execute([$gameId, $playerId, $weekNo, $this->encode(array_values($types))]);

        return ['types' => array_values($types), 'changed_once' => $row !== false];
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
