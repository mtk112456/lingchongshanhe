<?php
declare(strict_types=1);

/**
 * 12+1 城赛季规则测试：
 *   - 长安第 3 周才开放
 *   - 第 4 周只能打长安或长安邻城
 *   - 5 节点切片不受影响（由 phase15 / run.php 覆盖）
 */

require_once __DIR__ . '/../bootstrap.php';
require_once __DIR__ . '/../src/HandService.php';
require_once __DIR__ . '/../src/SqlRunner.php';

$failed = 0;
function check(string $name, bool $ok, string $detail = ''): void
{
    global $failed;
    echo ($ok ? '[PASS] ' : '[FAIL] ') . $name . ($detail !== '' ? ' — ' . $detail : '') . PHP_EOL;
    if (!$ok) {
        $failed++;
    }
}

[$config, $pdo] = slice_bootstrap();
SqlRunner::runFile($pdo, dirname(__DIR__) . '/seed_map12.sql');
$pdo->exec("UPDATE slice_games SET status = 'running' WHERE code = 'MAP12_TEST'");

$gameId = (int)$pdo->query("SELECT id FROM slice_games WHERE code = 'MAP12_TEST'")->fetchColumn();
if ($gameId <= 0) {
    fwrite(STDERR, "缺少 MAP12_TEST，请先跑 setup_map12_db.php\n");
    exit(1);
}
$turnId = (int)$pdo->query("SELECT id FROM slice_turns WHERE game_id = {$gameId} ORDER BY turn_no LIMIT 1")->fetchColumn();
$turnNo = (int)$pdo->query("SELECT turn_no FROM slice_turns WHERE id = {$turnId}")->fetchColumn();
$playerId = (int)$pdo->query(
    "SELECT id FROM slice_players WHERE game_id = {$gameId} AND role = 'player' ORDER BY id LIMIT 1"
)->fetchColumn();
if ($turnId <= 0 || $playerId <= 0) {
    fwrite(STDERR, "MAP12_TEST 缺少回合或玩家\n");
    exit(1);
}

$pdo->prepare("UPDATE slice_nodes SET owner_faction_id = (SELECT faction_id FROM slice_players WHERE id = ?) WHERE game_id = ? AND node_code = 'hanzhong'")->execute([$playerId, $gameId]);

$handService = new HandService($pdo);
$hand = $handService->getOrCreateHand($gameId, $turnId, $playerId);
$card = (string)$hand['cards'][0];

$clearOrders = function () use ($pdo, $turnId, $playerId): void {
    $pdo->prepare('DELETE FROM slice_order_slots WHERE turn_id = ? AND player_id = ?')->execute([$turnId, $playerId]);
};

$setWeek = function (int $week) use ($pdo, $turnId): void {
    // 每 7 回合一周：week 1 => 1, week 3 => 15, week 4 => 22
    $turnNo = ($week - 1) * 7 + 1;
    $pdo->prepare('UPDATE slice_turns SET turn_no = ? WHERE id = ?')->execute([$turnNo, $turnId]);
};

$tryPlay = function (string $target) use ($handService, $gameId, $turnId, $playerId, $card, $clearOrders): string {
    $clearOrders();
    try {
        $handService->play(
            $gameId,
            $turnId,
            $playerId,
            0,
            $card,
            $target,
            1,
            'front',
            'season_' . bin2hex(random_bytes(4))
        );
        return 'OK';
    } catch (InvalidArgumentException $e) {
        return $e->getMessage();
    } finally {
        $clearOrders();
    }
};

try {
    $setWeek(1);
    check('第 1 周可打普通城', $tryPlay('hanzhong') === 'OK', 'target=hanzhong');
    check('第 1 周长安锁定', $tryPlay('changan') === 'CHANGAN_LOCKED');

    $setWeek(2);
    check('第 2 周长安仍锁定', $tryPlay('changan') === 'CHANGAN_LOCKED');

    $setWeek(3);
    check('第 3 周长安开放', $tryPlay('changan') === 'OK');

    $setWeek(4);
    check('第 4 周不能打后方凉州', $tryPlay('liangzhou') === 'SEASON_FINAL_WEEK');
    check('第 4 周可打长安邻城汉中', $tryPlay('hanzhong') === 'OK');
    check('第 4 周可打长安', $tryPlay('changan') === 'OK');
} finally {
    $clearOrders();
    $pdo->prepare('UPDATE slice_turns SET turn_no = ? WHERE id = ?')->execute([$turnNo, $turnId]);
}

echo PHP_EOL;
if ($failed > 0) {
    echo "SEASON_RULES FAIL ({$failed})\n";
    exit(1);
}
echo "SEASON_RULES PASS\n";
