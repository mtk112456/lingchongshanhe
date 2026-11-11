<?php
declare(strict_types=1);

require_once __DIR__ . '/../bootstrap.php';
require_once __DIR__ . '/../src/SqlRunner.php';
require_once __DIR__ . '/../src/CardSettlementService.php';
require_once __DIR__ . '/../src/EstateService.php';
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

[$config, $pdo] = slice_bootstrap();
$seed = dirname(__DIR__) . '/seed.sql';
$pdo->exec("DELETE FROM slice_games WHERE code = 'SLICE_A'");
SqlRunner::runFile($pdo, $seed);

$gameId = (int)$pdo->query("SELECT id FROM slice_games WHERE code = 'SLICE_A'")->fetchColumn();
$players = array_map('intval', $pdo->query(
    "SELECT p.id FROM slice_players p JOIN slice_factions f ON f.id = p.faction_id
     WHERE p.game_id = {$gameId} AND p.role = 'player' AND f.code = 'bi' ORDER BY p.id LIMIT 4"
)->fetchAll(PDO::FETCH_COLUMN));
$me = $players[0];

// 两回合攻城，先攒军功
$turnIds = [];
for ($no = 1; $no <= 2; $no++) {
    $stmt = $pdo->prepare('SELECT id FROM slice_turns WHERE game_id = ? AND turn_no = ?');
    $stmt->execute([$gameId, $no]);
    $id = (int)$stmt->fetchColumn();
    if ($id <= 0) {
        $pdo->prepare(
            "INSERT INTO slice_turns (game_id, turn_no, status, opens_at, deadline_at, rules_version)
             VALUES (?, ?, 'open', NOW(), DATE_ADD(NOW(), INTERVAL 600 SECOND), 'cards_v1')"
        )->execute([$gameId, $no]);
        $id = (int)$pdo->lastInsertId();
    }
    $turnIds[$no] = $id;
}

$insert = $pdo->prepare(
    'INSERT INTO slice_order_slots
        (game_id, turn_id, player_id, slot, card_code, target_node_code, lane, row_pos, status, last_request_key)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, "active", ?)'
);
$settler = new CardSettlementService($pdo);
try {
    foreach ([1, 2] as $no) {
        foreach (array_slice($players, 0, 3) as $i => $pid) {
            $insert->execute([
                $gameId, $turnIds[$no], $pid, 0, 'night_raid', 'N1', $i + 1, 'front',
                'est_' . $no . '_' . $i . '_' . bin2hex(random_bytes(3)),
            ]);
        }
        $settler->settle($gameId, $turnIds[$no]);
    }
    $pdo->prepare('UPDATE slice_games SET current_turn_id = ? WHERE id = ?')
        ->execute([$turnIds[2], $gameId]);

    $service = new EstateService($pdo);
    $summary = $service->summary($gameId, $me, 1);
    check('小院自动建成', ($summary['home_node']['code'] ?? '') !== '');
    check('三个房间', count($summary['rooms']) === 3);
    check('初始都是 1 级', array_sum(array_column($summary['rooms'], 'level')) === 3);
    check('军功总额 > 0', $summary['merit_total'] > 0, 'total=' . $summary['merit_total']);
    check('可用军功 = 总额 - 已花', $summary['merit_balance'] === $summary['merit_total'] - $summary['merit_spent']);

    $hand = (new HandService($pdo))->getOrCreateHand($gameId, $turnIds[2], $me);
    check('书房预读 1 张', count($hand['preview'] ?? []) === 1, json_encode($hand['preview'] ?? []));
    if (($hand['preview'] ?? []) !== []) {
        check('预读牌不在手牌里', !in_array($hand['preview'][0], $hand['cards'], true));
    }

    $study = $summary['rooms'][0];
    $upgraded = $service->upgrade($gameId, $me, 'study');
    check('书房升到 2 级', ($upgraded['rooms'][0]['level'] ?? 0) === 2);
    check('扣除 30 军功', ($upgraded['merit_spent'] ?? 0) === 30, 'spent=' . ($upgraded['merit_spent'] ?? '?'));
    check('升级返回 upgraded', ($upgraded['upgraded']['room'] ?? '') === 'study');

    $bad = false;
    try {
        $service->upgrade($gameId, $me, 'kitchen');
    } catch (ApiException $e) {
        $bad = true;
    }
    check('非法房间被拒绝', $bad);

    // 直接补军功，测满级
    $bonus = $pdo->prepare(
        'INSERT INTO slice_merit_events (game_id, turn_id, player_id, kind, amount, detail_json)
         VALUES (?, ?, ?, "bonus", 1000, JSON_OBJECT("node_code", "N1"))'
    );
    $bonus->execute([$gameId, $turnIds[2], $me]);
    $service->upgrade($gameId, $me, 'study');
    check('书房升到 3 级', $service->summary($gameId, $me, 1)['rooms'][0]['level'] === 3);
    $maxed = false;
    try {
        $service->upgrade($gameId, $me, 'study');
    } catch (ApiException $e) {
        $maxed = $e->errorCode === 'ESTATE_MAX_LEVEL';
    }
    check('满级拒绝再升级', $maxed);

    $influence = $service->influence($gameId, $me);
    check('势力足迹包含 N1', in_array('N1', array_column($influence, 'code'), true), json_encode($influence));

    // 太守：给 bi 的 N1 一个贡献者
    $pdo->prepare(
        "UPDATE slice_nodes SET owner_faction_id = (SELECT id FROM slice_factions WHERE game_id = ? AND code = 'bi')
         WHERE game_id = ? AND node_code = 'N1'"
    )->execute([$gameId, $gameId]);
    $count = $service->refreshGovernors($gameId, 1);
    check('太守计算至少 1 城', $count >= 1, 'count=' . $count);
    $governors = $service->governorsForWeek($gameId, 1);
    check('N1 有太守', isset($governors['N1']), json_encode($governors));
    check('太守带昵称', ($governors['N1']['nickname'] ?? '') !== '');

    // 练兵场：2 级可改 2 次
    $drill = $service->upgrade($gameId, $me, 'drill');
    check('练兵场 2 级', $drill['rooms'][1]['level'] === 2);
    $hands = new HandService($pdo);
    $hands->setComposition($gameId, $me, 1, ['cav', 'shield', 'arc']);
    $second = $hands->setComposition($gameId, $me, 1, ['shield', 'spear', 'arc']);
    check('练兵场允许第 2 次改编成', $second['changed_once'] === true && $second['changes_allowed'] === 2);
    $third = $hands->setComposition($gameId, $me, 1, ['arc', 'cav', 'shield']);
    check('练兵场允许第 3 次设置', $third['changes_used'] === 2 && $third['changes_allowed'] === 2);
    $locked = false;
    try {
        $hands->setComposition($gameId, $me, 1, ['spear', 'arc', 'cav']);
    } catch (RuntimeException $e) {
        $locked = $e->getMessage() === 'COMPOSITION_LOCKED';
    }
    check('超过允许次数被拒', $locked);

    // 望楼：3 级侦察覆盖相邻城
    $pdo->prepare('UPDATE slice_estates SET tower_level = 3 WHERE game_id = ? AND player_id = ?')
        ->execute([$gameId, $me]);
    $pdo->prepare('DELETE FROM slice_order_slots WHERE turn_id = ? AND player_id = ?')
        ->execute([$turnIds[1], $me]);
    $pdo->prepare(
        'INSERT INTO slice_order_slots
            (game_id, turn_id, player_id, slot, card_code, target_node_code, lane, row_pos, status, last_request_key)
         VALUES (?, ?, ?, 0, "scout", "N1", 1, "front", "active", ?)'
    )->execute([$gameId, $turnIds[1], $me, 'est_scout_' . bin2hex(random_bytes(3))]);
    $login = slice_bootstrap()[2]->loginStudent('青竹一', 'slice2026');
    $player = slice_bootstrap()[2]->authenticate($login['token']);
    $state = slice_bootstrap()[2]->getState($player, $turnIds[1]);
    check('望楼侦察覆盖 >1 城', count($state['scouted_nodes']) > 1, json_encode($state['scouted_nodes']));
    check('state 带小院', isset($state['estate']['rooms']) && count($state['estate']['rooms']) === 3);

    $scoreBefore = (int)$pdo->query('SELECT score FROM students WHERE id = (SELECT student_id FROM slice_players WHERE id = ' . $me . ')')->fetchColumn();
    check('小院不修改 students.score', $scoreBefore === 140, 'score=' . $scoreBefore);
} finally {
    $pdo->exec("DELETE FROM slice_games WHERE code = 'SLICE_A'");
    SqlRunner::runFile($pdo, $seed);
}

echo PHP_EOL;
if ($failed > 0) {
    echo "ESTATE FAIL ({$failed})\n";
    exit(1);
}
echo "ESTATE PASS\n";
