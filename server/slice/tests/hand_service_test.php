<?php
declare(strict_types=1);

require_once __DIR__ . '/../bootstrap.php';
require_once __DIR__ . '/../src/HandService.php';

$failed = 0;

function check(string $name, bool $ok, string $detail = ''): void
{
    global $failed;
    echo ($ok ? '[PASS] ' : '[FAIL] ') . $name . ($detail !== '' ? ' — ' . $detail : '') . PHP_EOL;
    if (!$ok) {
        $failed++;
    }
}

function throws(callable $fn): bool
{
    try {
        $fn();
        return false;
    } catch (Throwable $e) {
        return true;
    }
}

[$config, $pdo] = slice_bootstrap();
$service = new HandService($pdo);

$gameId = (int)$pdo->query('SELECT id FROM slice_games LIMIT 1')->fetchColumn();
$turnId = (int)$pdo->query('SELECT id FROM slice_turns ORDER BY id LIMIT 1')->fetchColumn();
$playerId = (int)$pdo->query('SELECT id FROM slice_players ORDER BY id LIMIT 1')->fetchColumn();
$weekNo = 1;

check('有测试局', $gameId > 0 && $turnId > 0 && $playerId > 0, "game={$gameId} turn={$turnId} player={$playerId}");

// 清理
$pdo->prepare('DELETE FROM slice_hands WHERE turn_id = ? AND player_id = ?')->execute([$turnId, $playerId]);
$pdo->prepare('DELETE FROM slice_order_slots WHERE turn_id = ? AND player_id = ?')->execute([$turnId, $playerId]);
$pdo->prepare('DELETE FROM slice_compositions WHERE game_id = ? AND player_id = ? AND week_no = ?')->execute([$gameId, $playerId, $weekNo]);

// 1. 手牌
$hand = $service->getOrCreateHand($gameId, $turnId, $playerId);
check('手牌 4 张', count($hand['cards']) === 4, implode(',', $hand['cards']));
check('首次未重抽', $hand['redraw_used'] === false);

$hand2 = $service->getOrCreateHand($gameId, $turnId, $playerId);
check('刷新后手牌不变', $hand['cards'] === $hand2['cards']);

// 2. 重抽
$redraw = $service->redraw($gameId, $turnId, $playerId);
check('重抽 4 张', count($redraw['cards']) === 4, implode(',', $redraw['cards']));
check('重抽标记', $redraw['redraw_used'] === true);
check('第二次重抽被拒', throws(fn() => $service->redraw($gameId, $turnId, $playerId)));

// 3. 出牌
$cards = $redraw['cards'];
$order = $service->play($gameId, $turnId, $playerId, 0, $cards[0], 'hanzhong', 1, 'front', 'req_test_001');
check('出牌成功', $order['card_code'] === $cards[0]);
check('订单 1 条', count($service->getOrders($turnId, $playerId)) === 1);

// 4. 同一张牌不能出两次
check(
    '同一张牌不能出两次',
    throws(fn() => $service->play($gameId, $turnId, $playerId, 1, $cards[0], 'hanzhong', 2, 'front', 'req_test_002'))
);

// 5. 同一槽位可以改目标
$order2 = $service->play($gameId, $turnId, $playerId, 0, $cards[0], 'xiangyang', 2, 'back', 'req_test_003');
check('同一槽位可改目标', $order2['target_node_code'] === 'xiangyang');
check('订单仍 1 条', count($service->getOrders($turnId, $playerId)) === 1);

// 6. 填满 3 个槽位
$service->play($gameId, $turnId, $playerId, 1, $cards[1], 'hanzhong', 1, 'back', 'req_test_004');
$service->play($gameId, $turnId, $playerId, 2, $cards[2], 'hanzhong', 3, 'front', 'req_test_005');
check('3 个槽位满', count($service->getOrders($turnId, $playerId)) === 3);

// 7. 撤回
$service->withdraw($turnId, $playerId, 1);
check('撤回后 2 条', count($service->getOrders($turnId, $playerId)) === 2);
check('重复撤回返回 false', $service->withdraw($turnId, $playerId, 1) === false);

// 8. 编成
$comp = $service->getComposition($gameId, $playerId, $weekNo);
check('默认编成 3 个', count($comp['types']) === 3, implode(',', $comp['types']));

$set1 = $service->setComposition($gameId, $playerId, $weekNo, ['cav', 'cav', 'shield']);
check('第一次编成成功', $set1['types'] === ['cav', 'cav', 'shield']);
check('第一次未改过', $set1['changed_once'] === false);

$set2 = $service->setComposition($gameId, $playerId, $weekNo, ['arc', 'arc', 'spear']);
check('周中改一次成功', $set2['types'] === ['arc', 'arc', 'spear']);
check('第二次标记改过', $set2['changed_once'] === true);

check(
    '第三次编成被锁',
    throws(fn() => $service->setComposition($gameId, $playerId, $weekNo, ['cav', 'shield', 'arc']))
);

// 清理
$pdo->prepare('DELETE FROM slice_hands WHERE turn_id = ? AND player_id = ?')->execute([$turnId, $playerId]);
$pdo->prepare('DELETE FROM slice_order_slots WHERE turn_id = ? AND player_id = ?')->execute([$turnId, $playerId]);
$pdo->prepare('DELETE FROM slice_compositions WHERE game_id = ? AND player_id = ? AND week_no = ?')->execute([$gameId, $playerId, $weekNo]);

echo PHP_EOL;
if ($failed > 0) {
    echo "HAND_SERVICE FAIL ({$failed})\n";
    exit(1);
}
echo "HAND_SERVICE PASS\n";
