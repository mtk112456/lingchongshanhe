<?php
declare(strict_types=1);

require_once __DIR__ . '/ApiException.php';
require_once __DIR__ . '/Clock.php';

/**
 * 对接现有班级量化系统：
 * - 可用积分 = max(0, students.score - 100 - SUM(shop_orders.points_spent WHERE status != 'cancelled'))
 * - 兑换只写 shop_orders（type=game_recharge），绝不更新 students.score
 * - 文玉钱包单独记账，跨赛季保留
 */
final class PointsService
{
    private PDO $pdo;
    private array $config;
    private Clock $clock;

    public function __construct(PDO $pdo, array $config)
    {
        $this->pdo = $pdo;
        $this->config = $config;
        $this->clock = new Clock((string)($config['app']['timezone'] ?? 'Asia/Shanghai'));
    }

    private function nowSql(): string
    {
        return $this->clock->sql();
    }

    private function encode(array $data): string
    {
        $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        if ($json === false) {
            throw new ApiException('JSON_ENCODE_FAILED', '服务端 JSON 编码失败', 500);
        }
        return $json;
    }

    private function decode(?string $json): array
    {
        if ($json === null || $json === '') {
            return [];
        }
        $data = json_decode($json, true);
        return is_array($data) ? $data : [];
    }

    public function getWallet(int $studentId): array
    {
        $stmt = $this->pdo->prepare(
            'SELECT id, name, show_name, class_id, score FROM students WHERE id = ?'
        );
        $stmt->execute([$studentId]);
        $student = $stmt->fetch();
        if (!$student) {
            throw new ApiException('STUDENT_NOT_FOUND', '学生账号不存在', 404);
        }

        $totalScore = (int)$student['score'];
        $baseScore = 100;
        $grossNet = max(0, $totalScore - $baseScore);

        $stmt = $this->pdo->prepare(
            "SELECT COALESCE(SUM(points_spent), 0) AS s FROM shop_orders
             WHERE student_id = ? AND status != 'cancelled'"
        );
        $stmt->execute([$studentId]);
        $spent = (int)$stmt->fetchColumn();

        $stmt = $this->pdo->prepare(
            "SELECT COALESCE(SUM(points_spent), 0) AS s FROM shop_orders
             WHERE student_id = ? AND type = 'game_recharge'
               AND status != 'cancelled' AND DATE(create_time) = ?"
        );
        $stmt->execute([$studentId, $this->clock->now()->format('Y-m-d')]);
        $todayRecharged = (int)$stmt->fetchColumn();

        $stmt = $this->pdo->prepare('SELECT balance_jade FROM game_wallets WHERE student_id = ?');
        $stmt->execute([$studentId]);
        $jade = $stmt->fetchColumn();
        $jade = $jade === false ? 0 : (int)$jade;

        return [
            'student_id' => (int)$student['id'],
            'student_name' => (string)($student['show_name'] ?: $student['name']),
            'class_id' => (int)$student['class_id'],
            'total_score' => $totalScore,
            'base_score' => $baseScore,
            'gross_net' => $grossNet,
            'spent_points' => $spent,
            'available_points' => max(0, $grossNet - $spent),
            'today_recharged_points' => $todayRecharged,
            'daily_cap_points' => 20,
            'remaining_daily_points' => max(0, 20 - $todayRecharged),
            'exchange_rate' => 10,
            'jade_balance' => $jade,
        ];
    }

    public function recharge(int $studentId, int $points, string $requestKey, ?int $gameId = null, ?int $playerId = null): array
    {
        if ($points < 1 || $points > 20) {
            throw new ApiException('BAD_REQUEST', '单次兑换需为 1–20 可用积分');
        }
        if (!preg_match('/^[A-Za-z0-9_-]{8,64}$/', $requestKey)) {
            throw new ApiException('BAD_REQUEST', 'request_key 需为 8–64 位字母、数字、下划线或短横线');
        }

        $this->pdo->beginTransaction();
        try {
            $stmt = $this->pdo->prepare('SELECT id, name, show_name, class_id, score FROM students WHERE id = ? FOR UPDATE');
            $stmt->execute([$studentId]);
            $student = $stmt->fetch();
            if (!$student) {
                throw new ApiException('STUDENT_NOT_FOUND', '学生账号不存在', 404);
            }

            $stmt = $this->pdo->prepare(
                'SELECT * FROM game_recharge_requests WHERE student_id = ? AND request_key = ? FOR UPDATE'
            );
            $stmt->execute([$studentId, $requestKey]);
            $prior = $stmt->fetch();
            if ($prior) {
                if ((int)$prior['points_requested'] !== $points) {
                    throw new ApiException('IDEMPOTENCY_CONFLICT', '同一 request_key 不能兑换不同积分', 409);
                }
                $this->pdo->commit();
                $response = $this->decode((string)$prior['response_json']);
                $response['idempotent'] = true;
                $response['server_time'] = $this->nowSql();
                return $response;
            }

            $wallet = $this->getWallet($studentId);
            if ($points > $wallet['available_points']) {
                throw new ApiException('POINTS_INSUFFICIENT', '可用积分不足', 409, [
                    'requested' => $points,
                    'available_points' => $wallet['available_points'],
                ]);
            }
            if ($wallet['today_recharged_points'] + $points > 20) {
                throw new ApiException('DAILY_CAP_EXCEEDED', '今日兑换已达 20 积分上限', 409, [
                    'today_recharged_points' => $wallet['today_recharged_points'],
                    'remaining_daily_points' => $wallet['remaining_daily_points'],
                ]);
            }

            $orderNo = 'GAME' . $this->clock->now()->format('YmdHis') . bin2hex(random_bytes(4));
            $verifyCode = '';
            for ($attempt = 0; $attempt < 20; $attempt++) {
                $candidate = str_pad((string)random_int(0, 999999), 6, '0', STR_PAD_LEFT);
                $stmt = $this->pdo->prepare('SELECT id FROM shop_orders WHERE verify_code = ? LIMIT 1');
                $stmt->execute([$candidate]);
                if ($stmt->fetchColumn() === false) {
                    $verifyCode = $candidate;
                    break;
                }
            }
            if ($verifyCode === '') {
                throw new ApiException('VERIFY_CODE_FAILED', '兑换核销码生成失败，请重试', 500);
            }

            $now = $this->nowSql();
            $jadeAdded = $points * 10;
            $stmt = $this->pdo->prepare(
                "INSERT INTO shop_orders
                 (order_no, student_id, class_id, type, item_id, item_name, spec_name, points_spent, verify_code, status, finish_time)
                 VALUES (?, ?, ?, 'game_recharge', 0, '灵宠山河·文玉充值', '1 可用积分 = 10 文玉', ?, ?, 'completed', ?)"
            );
            $stmt->execute([
                $orderNo,
                $studentId,
                (int)$student['class_id'],
                $points,
                $verifyCode,
                $now,
            ]);
            $orderId = (int)$this->pdo->lastInsertId();

            $stmt = $this->pdo->prepare(
                'INSERT INTO game_wallets (student_id, balance_jade) VALUES (?, ?)
                 ON DUPLICATE KEY UPDATE balance_jade = balance_jade + VALUES(balance_jade)'
            );
            $stmt->execute([$studentId, $jadeAdded]);
            $stmt = $this->pdo->prepare('SELECT balance_jade FROM game_wallets WHERE student_id = ?');
            $stmt->execute([$studentId]);
            $balanceAfter = (int)$stmt->fetchColumn();

            $stmt = $this->pdo->prepare(
                'INSERT INTO game_wallet_transactions
                 (student_id, shop_order_id, points_spent, jade_delta, balance_after, reason, created_at)
                 VALUES (?, ?, ?, ?, ?, "recharge", ?)'
            );
            $stmt->execute([$studentId, $orderId, $points, $jadeAdded, $balanceAfter, $now]);

            $walletAfter = $this->getWallet($studentId);
            $response = [
                'order_id' => $orderId,
                'order_no' => $orderNo,
                'verify_code' => $verifyCode,
                'points_spent' => $points,
                'jade_added' => $jadeAdded,
                'wallet' => $walletAfter,
                'idempotent' => false,
                'message' => '兑换成功：已写入 shop_orders，未修改 students.score。',
                'server_time' => $now,
            ];

            $stmt = $this->pdo->prepare(
                'INSERT INTO game_recharge_requests (student_id, request_key, points_requested, response_json)
                 VALUES (?, ?, ?, ?)'
            );
            $stmt->execute([$studentId, $requestKey, $points, $this->encode($response)]);

            if ($gameId !== null) {
                $stmt = $this->pdo->prepare(
                    'INSERT INTO slice_audit_log (game_id, turn_id, player_id, action, detail_json)
                     VALUES (?, NULL, ?, "points.recharge", ?)'
                );
                $stmt->execute([
                    $gameId,
                    $playerId,
                    $this->encode([
                        'shop_order_id' => $orderId,
                        'points_spent' => $points,
                        'jade_added' => $jadeAdded,
                    ]),
                ]);
            }

            $this->pdo->commit();
            return $response;
        } catch (Throwable $e) {
            if ($this->pdo->inTransaction()) {
                $this->pdo->rollBack();
            }
            throw $e;
        }
    }
}
