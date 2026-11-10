<?php
declare(strict_types=1);

/**
 * 战斗结果 → 民心 → 易主。
 *
 * 民心上限：
 *   普通城/中立 2、关隘/大营/渡口/文脉/水乡 3、长安 5。
 *
 * 战斗分数：
 *   破墙 +2、城墙<50% +1、50–80% 0、>80% -1。
 */
final class BattleSettlementService
{
    private PDO $pdo;

    public function __construct(PDO $pdo)
    {
        $this->pdo = $pdo;
    }

    public static function cap(string $nodeType): int
    {
        return match ($nodeType) {
            'king' => 5,
            'camp', 'pass', 'ferry', 'culture', 'water' => 3,
            default => 2,
        };
    }

    /**
     * @return array{
     *   node_code:string,cap:int,morale_before:int,morale_after:int,
     *   owner_before:?int,owner_after:?int,captured:bool,reason:string
     * }
     */
    public function apply(
        int $gameId,
        int $turnId,
        string $nodeCode,
        ?int $attackerFactionId,
        int $score
    ): array {
        $this->pdo->beginTransaction();
        try {
            $stmt = $this->pdo->prepare(
                'SELECT id, node_type, owner_faction_id, morale
                 FROM slice_nodes WHERE game_id = ? AND node_code = ? FOR UPDATE'
            );
            $stmt->execute([$gameId, $nodeCode]);
            $node = $stmt->fetch();
            if (!$node) {
                throw new RuntimeException('NODE_NOT_FOUND');
            }

            $cap = self::cap((string)$node['node_type']);
            $before = (int)$node['morale'];
            $ownerBefore = $node['owner_faction_id'] === null ? null : (int)$node['owner_faction_id'];
            $delta = max(-1, min(2, $score));
            $after = max(0, min($cap, $before + $delta));
            $captured = false;
            $ownerAfter = $ownerBefore;

            if ($after >= $cap) {
                if ($attackerFactionId !== null && $ownerBefore !== $attackerFactionId) {
                    $ownerAfter = $attackerFactionId;
                    $after = 0;
                    $captured = true;
                } else {
                    $after = $cap;
                }
            }

            $stmt = $this->pdo->prepare(
                'UPDATE slice_nodes SET owner_faction_id = ?, morale = ? WHERE id = ?'
            );
            $stmt->execute([$ownerAfter, $after, (int)$node['id']]);

            $reason = $captured
                ? 'captured'
                : ($delta > 0 ? 'morale_push' : ($delta < 0 ? 'morale_recede' : 'hold'));

            $scoreJson = json_encode([
                'score' => $score,
                'morale_before' => $before,
                'morale_after' => $after,
                'cap' => $cap,
            ], JSON_UNESCAPED_UNICODE);

            $stmt = $this->pdo->prepare(
                'INSERT INTO slice_node_changes
                    (game_id, turn_id, node_code, owner_before_faction_id, owner_after_faction_id,
                     winner_faction_id, score_json, reason)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                 ON DUPLICATE KEY UPDATE
                    owner_before_faction_id = VALUES(owner_before_faction_id),
                    owner_after_faction_id = VALUES(owner_after_faction_id),
                    winner_faction_id = VALUES(winner_faction_id),
                    score_json = VALUES(score_json),
                    reason = VALUES(reason)'
            );
            $stmt->execute([
                $gameId,
                $turnId,
                $nodeCode,
                $ownerBefore,
                $ownerAfter,
                $attackerFactionId,
                $scoreJson,
                $reason,
            ]);

            $this->pdo->commit();

            return [
                'node_code' => $nodeCode,
                'cap' => $cap,
                'morale_before' => $before,
                'morale_after' => $after,
                'owner_before' => $ownerBefore,
                'owner_after' => $ownerAfter,
                'captured' => $captured,
                'reason' => $reason,
            ];
        } catch (Throwable $e) {
            if ($this->pdo->inTransaction()) {
                $this->pdo->rollBack();
            }
            throw $e;
        }
    }
}
