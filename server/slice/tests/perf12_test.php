<?php
declare(strict_types=1);

/**
 * 12+1 城 × 100 人 × 7 回合性能测试
 *
 * 目标：在真实规模（13 节点 / 19 边 / 4 阵营 / 100 名玩家 / 每回合 300 令）下，
 * 连续结算 7 个回合，记录每回合 settlement 墙钟时间与 PHP 内存峰值。
 *
 * 做法：
 *   1. 运行 seed_map12.sql 重置 MAP12_TEST；
 *   2. 克隆 MAP12_TEST 的 13 节点 / 19 边 / 4 阵营到独立游戏 PERF12；
 *   3. 造 100 个测试学生 + 班宠 + 玩家（每阵营 25 人，与 season100 一致）；
 *   4. 每回合写入 300 条令（每人 3 令），编成 / 邸报 / 卡牌 / 目标均随机混合；
 *   5. 计时 CardSettlementService::settle()，共 7 回合；
 *   6. 断言：无 SQL/结算异常，p95 < 500ms，max < 1500ms。
 *
 * 只连接性能专用库 test_perf（config.perf.php，由 SLICE_CONFIG 指定），
 * 按种子重置 MAP12_TEST；性能数据只写 PERF12 / PERF12xxx，结束时清理。
 * 不连接、不修改 qingzhu_slice_test 或其他既有库。
 *
 * 用法（PowerShell）：
 *   $env:SLICE_CONFIG = "D:\DeskBox\游戏\server\slice\config.perf.php"
 *   php server/slice/tests/perf12_test.php
 */

require_once __DIR__ . '/../bootstrap.php';
require_once __DIR__ . '/../src/SqlRunner.php';
require_once __DIR__ . '/../src/HandService.php';
require_once __DIR__ . '/../src/BulletinService.php';
require_once __DIR__ . '/../src/CardSettlementService.php';

const PERF_GAME_CODE = 'PERF12';
const PERF_PLAYER_COUNT = 100;
const PERF_ROUNDS = 7;
const PERF_ORDERS_PER_TURN = 300;
const PERF_P95_LIMIT_MS = 500.0;
const PERF_MAX_LIMIT_MS = 1500.0;
const PERF_RANDOM_SEED = 121213;

$failed = 0;
function check(string $name, bool $ok, string $detail = ''): void
{
    global $failed;
    echo ($ok ? '[PASS] ' : '[FAIL] ') . $name . ($detail !== '' ? ' — ' . $detail : '') . PHP_EOL;
    if (!$ok) {
        $failed++;
    }
}

/**
 * 最近秩百分位（latency 常用口径）。
 *
 * @param float[] $values
 */
function percentile(array $values, float $p): float
{
    $n = count($values);
    if ($n === 0) {
        return 0.0;
    }
    sort($values);
    $rank = (int)ceil(($p / 100.0) * $n) - 1;
    $rank = max(0, min($n - 1, $rank));
    return (float)$values[$rank];
}

/**
 * 随机编成：4 兵种取 3，不重复。
 *
 * @return string[]
 */
function randomComposition(): array
{
    $types = ['cav', 'shield', 'arc', 'spear'];
    shuffle($types);
    return array_slice($types, 0, 3);
}

mt_srand(PERF_RANDOM_SEED);

[$config, $pdo] = slice_bootstrap();

// 硬隔离：只允许性能专用库，避免误跑回归库
$dbName = (string)($config['db']['name'] ?? '');
if ($dbName !== 'test_perf') {
    fwrite(STDERR, "perf12_test 只允许连接 test_perf，当前：{$dbName}\n");
    fwrite(STDERR, "请设置 SLICE_CONFIG=D:\\DeskBox\\游戏\\server\\slice\\config.perf.php\n");
    exit(1);
}
echo "DB: {$dbName}\n";

$seedPath = dirname(__DIR__) . '/seed_map12.sql';
SqlRunner::runFile($pdo, $seedPath);

$sourceGameId = (int)$pdo->query("SELECT id FROM slice_games WHERE code = 'MAP12_TEST'")->fetchColumn();
if ($sourceGameId <= 0) {
    fwrite(STDERR, "缺少 MAP12_TEST，请先跑 setup_map12_db.php\n");
    exit(1);
}

$cleanup = function () use ($pdo): void {
    $stmt = $pdo->prepare('SELECT id FROM slice_games WHERE code = ?');
    $stmt->execute([PERF_GAME_CODE]);
    $id = (int)$stmt->fetchColumn();
    if ($id > 0) {
        $pdo->prepare('DELETE FROM slice_games WHERE id = ?')->execute([$id]);
    }
    $ids = $pdo->query("SELECT id FROM students WHERE name REGEXP '^PERF12[0-9]{3}$'")->fetchAll(PDO::FETCH_COLUMN);
    if ($ids !== []) {
        $in = implode(',', array_map('intval', $ids));
        $pdo->exec("DELETE FROM student_pets WHERE student_id IN ({$in})");
        $pdo->exec("DELETE FROM students WHERE id IN ({$in})");
    }
};
$cleanup();

$seedStats = [
    'nodes' => (int)$pdo->query("SELECT COUNT(*) FROM slice_nodes WHERE game_id = {$sourceGameId}")->fetchColumn(),
    'edges' => (int)$pdo->query("SELECT COUNT(*) FROM slice_edges WHERE game_id = {$sourceGameId}")->fetchColumn(),
    'factions' => (int)$pdo->query("SELECT COUNT(*) FROM slice_factions WHERE game_id = {$sourceGameId}")->fetchColumn(),
];
check('MAP12_TEST 已重置为 12+1 城', $seedStats['nodes'] === 13, 'nodes=' . $seedStats['nodes']);
check('MAP12_TEST 4 阵营 / 19 边', $seedStats['factions'] === 4 && $seedStats['edges'] === 19,
    'factions=' . $seedStats['factions'] . ' edges=' . $seedStats['edges']);

$passwordHash = (string)$pdo->query('SELECT password FROM students ORDER BY id LIMIT 1')->fetchColumn();
$petTemplateId = (int)$pdo->query('SELECT id FROM pet_templates ORDER BY id LIMIT 1')->fetchColumn();
$petCode = (string)$pdo->query('SELECT code FROM pet_templates ORDER BY id LIMIT 1')->fetchColumn();

$pdo->beginTransaction();
try {
    // 1. 独立性能局，避免污染 MAP12_TEST
    $pdo->prepare(
        "INSERT INTO slice_games (code, name, status, rules_version, turn_seconds)
         VALUES (?, '12+1 城 100 人性能测试', 'paused', 'cards_v1', 600)"
    )->execute([PERF_GAME_CODE]);
    $gameId = (int)$pdo->lastInsertId();

    // 2. 克隆阵营 / 节点 / 边
    $pdo->prepare(
        'INSERT INTO slice_factions (game_id, code, name, color, start_node_code, sort_order)
         SELECT ?, code, name, color, start_node_code, sort_order
         FROM slice_factions WHERE game_id = ?'
    )->execute([$gameId, $sourceGameId]);

    $pdo->prepare(
        'INSERT INTO slice_nodes
            (game_id, node_code, name, x, y, node_type, owner_faction_id, initial_owner_faction_id, morale, sort_order)
         SELECT ?, node_code, name, x, y, node_type, NULL, NULL, 0, sort_order
         FROM slice_nodes WHERE game_id = ?'
    )->execute([$gameId, $sourceGameId]);

    $pdo->prepare(
        'UPDATE slice_nodes n
         JOIN slice_nodes o ON o.game_id = ? AND o.node_code = n.node_code
         JOIN slice_factions of ON of.id = o.owner_faction_id
         JOIN slice_factions nf ON nf.game_id = n.game_id AND nf.code = of.code
         SET n.owner_faction_id = nf.id
         WHERE n.game_id = ?'
    )->execute([$sourceGameId, $gameId]);

    $pdo->prepare(
        'INSERT INTO slice_edges (game_id, a_node_code, b_node_code)
         SELECT ?, a_node_code, b_node_code FROM slice_edges WHERE game_id = ?'
    )->execute([$gameId, $sourceGameId]);

    $factions = $pdo->query("SELECT id, code, start_node_code FROM slice_factions WHERE game_id = {$gameId} ORDER BY sort_order")
        ->fetchAll();
    $nodes = $pdo->query("SELECT node_code FROM slice_nodes WHERE game_id = {$gameId} ORDER BY sort_order")
        ->fetchAll(PDO::FETCH_COLUMN);

    $factionStart = [];
    foreach ($factions as $f) {
        $factionStart[(string)$f['code']] = (string)$f['start_node_code'];
    }

    // 3. 100 名学生 + 班宠 + 玩家（每阵营 25 人）
    $insertStudent = $pdo->prepare(
        "INSERT INTO students (id_card, class_id, name, show_name, password, score)
         VALUES (?, 1, ?, ?, ?, 100)"
    );
    $insertPet = $pdo->prepare(
        'INSERT INTO student_pets (student_id, pet_template_id, nickname, level, hunger, mood)
         VALUES (?, ?, ?, 10, 100, 100)'
    );
    $insertPlayer = $pdo->prepare(
        'INSERT INTO slice_players
            (game_id, student_id, admin_id, faction_id, nickname, role, pet_instance_id, pet_code, pet_name, is_active)
         VALUES (?, ?, NULL, ?, ?, "player", ?, ?, ?, 1)'
    );

    $players = [];
    for ($i = 0; $i < PERF_PLAYER_COUNT; $i++) {
        $tag = sprintf('PERF12%03d', $i + 1);
        $insertStudent->execute(['PERF12' . sprintf('%04d', $i + 1), $tag, $tag, $passwordHash]);
        $studentId = (int)$pdo->lastInsertId();
        $insertPet->execute([$studentId, $petTemplateId, $tag]);
        $petId = (int)$pdo->lastInsertId();
        $faction = $factions[$i % 4];
        $insertPlayer->execute([$gameId, $studentId, (int)$faction['id'], $tag, $petId, $petCode, $tag]);
        $players[] = [
            'id' => (int)$pdo->lastInsertId(),
            'faction' => (string)$faction['code'],
        ];
    }

    // 4. 第 1 回合 + 第 1 周随机编成
    $pdo->prepare(
        "INSERT INTO slice_turns (game_id, turn_no, status, opens_at, deadline_at, rules_version)
         VALUES (?, 1, 'open', NOW(), DATE_ADD(NOW(), INTERVAL 600 SECOND), 'cards_v1')"
    )->execute([$gameId]);
    $turnId = (int)$pdo->lastInsertId();
    $pdo->prepare('UPDATE slice_games SET current_turn_id = ? WHERE id = ?')->execute([$turnId, $gameId]);

    $handService = new HandService($pdo);
    foreach ($players as $p) {
        $handService->setComposition($gameId, (int)$p['id'], 1, randomComposition());
    }

    $pdo->commit();
} catch (Throwable $e) {
    $pdo->rollBack();
    $cleanup();
    fwrite(STDERR, '性能测试准备失败：' . $e->getMessage() . PHP_EOL);
    exit(1);
}

check('100 名玩家就绪', count($players) === PERF_PLAYER_COUNT, 'players=' . count($players));

$settler = new CardSettlementService($pdo);
$bulletinService = new BulletinService($pdo);
$insertOrders = $pdo->prepare(
    'INSERT INTO slice_order_slots
        (game_id, turn_id, player_id, slot, card_code, target_node_code, lane, row_pos, status, last_request_key)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, "active", ?)'
);
$insertTurn = $pdo->prepare(
    "INSERT INTO slice_turns (game_id, turn_no, status, opens_at, deadline_at, rules_version)
     VALUES (?, ?, 'open', NOW(), DATE_ADD(NOW(), INTERVAL 600 SECOND), 'cards_v1')"
);
$updateCurrentTurn = $pdo->prepare('UPDATE slice_games SET current_turn_id = ? WHERE id = ?');

$tactics = array_keys(HandDeck::TACTICS);
$teamCards = CardSettlementService::TEAM_CARDS;
$bulletinCodes = ['grain', 'ram', 'scout'];
$preferredBulletin = array_fill_keys($bulletinCodes, 0);

$times = [];
$turnStats = [];
$orderCounts = [];
$errors = [];
$battleTotal = 0;
$captureTotal = 0;
$meritTotal = 0;
$settledTurns = 0;

try {
    for ($round = 1; $round <= PERF_ROUNDS; $round++) {
        if ($round > 1) {
            $insertTurn->execute([$gameId, $round]);
            $turnId = (int)$pdo->lastInsertId();
            $updateCurrentTurn->execute([$turnId, $gameId]);
        }

        // 第 4 回合：一半玩家周中改一次编成，覆盖 changed_once 分支
        if ($round === 4) {
            foreach ($players as $i => $p) {
                if ($i % 2 === 0) {
                    $handService->setComposition($gameId, (int)$p['id'], 1, randomComposition());
                }
            }
        }

        // 每回合 300 令：随机卡牌 / 随机目标 / 随机位次
        $orderCount = 0;
        foreach ($players as $p) {
            $factionCode = (string)$p['faction'];
            $regionNodes = CardSettlementService::REGION_NODES[$factionCode] ?? $nodes;
            $startNode = $factionStart[$factionCode] ?? $nodes[0];

            // 每人 3 张不重复战术牌，保证至少 1 张能带队伍的牌
            shuffle($tactics);
            $cards = array_slice($tactics, 0, 3);
            if (array_intersect($cards, $teamCards) === []) {
                $cards[0] = $teamCards[array_rand($teamCards)];
            }

            for ($slot = 0; $slot < 3; $slot++) {
                $roll = mt_rand(1, 100);
                if ($roll <= 10) {
                    $target = $startNode; // 10% 驻守 / 反攻出生城
                } elseif ($roll <= 30) {
                    $target = $regionNodes[array_rand($regionNodes)]; // 20% 本区
                } else {
                    $target = $nodes[array_rand($nodes)]; // 70% 全图
                }

                $insertOrders->execute([
                    $gameId,
                    $turnId,
                    (int)$p['id'],
                    $slot,
                    $cards[$slot],
                    $target,
                    mt_rand(1, 3),
                    mt_rand(0, 1) === 0 ? 'front' : 'back',
                    'perf12_' . $round . '_' . $p['id'] . '_' . $slot,
                ]);
                $orderCount++;
            }
        }
        $orderCounts[$round] = $orderCount;

        // 邸报：在服务给出的两个选项里选；按轮次轮换 grain/ram/scout，缺项时选出现较少的
        foreach ($players as $i => $p) {
            $summary = $bulletinService->summary($gameId, $turnId, (int)$p['id']);
            $available = array_column($summary['options'], 'code');
            $preferred = $bulletinCodes[$i % 3];
            if (!in_array($preferred, $available, true)) {
                usort($available, fn(string $a, string $b): int => $preferredBulletin[$a] <=> $preferredBulletin[$b]);
                $preferred = $available[0];
            }
            $bulletinService->choose($gameId, $turnId, (int)$p['id'], $preferred);
            $preferredBulletin[$preferred]++;
        }

        if (function_exists('memory_reset_peak_usage')) {
            memory_reset_peak_usage();
        }
        $startedAt = hrtime(true);
        try {
            $result = $settler->settle($gameId, $turnId);
        } catch (Throwable $e) {
            $errors[] = '回合 ' . $round . '：' . get_class($e) . ': ' . $e->getMessage();
            break;
        }
        $elapsedMs = (hrtime(true) - $startedAt) / 1_000_000;
        $peakMb = memory_get_peak_usage(true) / 1048576;
        $times[] = $elapsedMs;

        $battles = 0;
        $captures = 0;
        $meritItems = PERF_PLAYER_COUNT; // 每人 1 条 participation
        foreach ($result['battles'] as $b) {
            foreach (($b['merit'] ?? []) as $m) {
                $meritItems += count($m['items'] ?? []);
            }
            if (empty($b['battle_id'])) {
                continue;
            }
            $battles++;
            if (!empty($b['captured'])) {
                $captures++;
            }
        }
        $battleTotal += $battles;
        $captureTotal += $captures;
        $meritTotal += $meritItems;
        $settledTurns++;

        $turnStats[] = [
            'turn' => $round,
            'orders' => $orderCount,
            'battles' => $battles,
            'captures' => $captures,
            'merit_items' => $meritItems,
            'ms' => $elapsedMs,
            'peak_mb' => $peakMb,
            'already_settled' => (bool)($result['already_settled'] ?? false),
        ];

        printf(
            "round %d: orders=%d battles=%2d captures=%2d merit=%3d settle=%7.1f ms peak=%5.1f MB\n",
            $round,
            $orderCount,
            $battles,
            $captures,
            $meritItems,
            $elapsedMs,
            $peakMb
        );
    }
} finally {
    $cleanup();
}

$allOrders300 = $orderCounts !== [] && count(array_filter($orderCounts, fn(int $n): bool => $n === PERF_ORDERS_PER_TURN)) === count($orderCounts);
$maxBattlesOk = true;
foreach ($turnStats as $stat) {
    if ($stat['battles'] > 13) {
        $maxBattlesOk = false;
    }
}
$alreadySettled = array_filter($turnStats, fn(array $s): bool => $s['already_settled']);

$p50 = percentile($times, 50);
$p95 = percentile($times, 95);
$max = $times === [] ? 0.0 : max($times);
$avg = $times === [] ? 0.0 : array_sum($times) / count($times);
$maxPeak = $turnStats === [] ? 0.0 : max(array_column($turnStats, 'peak_mb'));

echo PHP_EOL;
check('7 回合全部结算', $settledTurns === PERF_ROUNDS, 'settled=' . $settledTurns);
check('每回合 300 令', $allOrders300, 'orders=' . json_encode($orderCounts));
check('无 SQL/结算异常', $errors === [], $errors === [] ? 'errors=0' : implode(' | ', $errors));
check('结算幂等标记正常', $alreadySettled === [], 'already=' . count($alreadySettled));
check('产生战斗', $battleTotal > 0, 'battles=' . $battleTotal);
check('每回合战斗数 ≤ 13', $maxBattlesOk,
    'per_turn=' . json_encode(array_column($turnStats, 'battles')));
check('邸报三种选择都出现', count(array_filter($preferredBulletin, fn(int $n): bool => $n > 0)) === 3,
    json_encode($preferredBulletin));
check(sprintf('p95 < %.0f ms', PERF_P95_LIMIT_MS), $p95 < PERF_P95_LIMIT_MS, sprintf('p95=%.1f ms', $p95));
check(sprintf('max < %.0f ms', PERF_MAX_LIMIT_MS), $max < PERF_MAX_LIMIT_MS, sprintf('max=%.1f ms', $max));

echo PHP_EOL;
printf("PERF12: %d turns, %d orders/turn, %d players, %d nodes, %d battles, %d captures, %d merit rows\n",
    $settledTurns, PERF_ORDERS_PER_TURN, PERF_PLAYER_COUNT, count($nodes), $battleTotal, $captureTotal, $meritTotal);
printf("p50=%.1f ms  p95=%.1f ms  max=%.1f ms  avg=%.1f ms\n", $p50, $p95, $max, $avg);
printf("memory peak (max of rounds): %.1f MB\n", $maxPeak);
echo 'bulletin choices: ' . json_encode($preferredBulletin) . PHP_EOL;

if ($failed > 0) {
    echo "PERF12 FAIL ({$failed})\n";
    exit(1);
}
echo "PERF12 PASS\n";
