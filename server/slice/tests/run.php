<?php
declare(strict_types=1);

require_once __DIR__ . '/TestHarness.php';

$h = new TestHarness();
$passed = 0;
$failed = 0;
$failures = [];

function testCase(string $name, callable $fn): void
{
    global $h, $passed, $failed, $failures;
    $h->reset();
    try {
        $fn($h);
        $passed++;
        echo "[PASS] {$name}\n";
    } catch (Throwable $e) {
        $failed++;
        $failures[] = [$name, $e->getMessage()];
        echo "[FAIL] {$name}: {$e->getMessage()}\n";
    }
}

function reportResult(TestHarness $h, array $player, int $turnId, string $expected): void
{
    $report = $h->service->getReport($player, $turnId);
    $h->assertTrue($report['me'] !== null, 'personal report missing');
    $h->assertSame($expected, $report['me']['outcome']['result'], 'personal report result mismatch');
}

echo "== Milestone A slice tests ==\n";

testCase('auth + existing students/admin/pets integration', function (TestHarness $h): void {
    $login = $h->service->loginStudent('青竹一', 'slice2026');
    $h->assertSame(64, strlen($login['token']), 'token length');
    $player = $h->service->authenticate($login['token']);
    $h->assertSame(1, (int)$player['student_id'], 'student id link');
    $h->assertSame('bi', (string)$player['faction_code'], 'faction');
    $h->assertSame('小青竹·一', (string)$player['pet_nickname'], 'pet from student_pets');
    $h->assertSame(1000, (int)$player['pet_base_hp'], 'pet base hp from pet_templates');

    $wallet = $h->points->getWallet(1);
    $h->assertSame(40, $wallet['available_points'], 'available points from students.score');
    $h->assertSame(0, $wallet['jade_balance'], 'initial jade');

    $h->assertApi(fn() => $h->service->loginStudent('青竹一', 'wrong-password'), 'UNAUTHORIZED');
    $admin = $h->service->loginAdmin('teacher', 'teacher2026');
    $h->assertSame('teacher', (string)$admin['player']['role'], 'admin login role');

    $hash = password_hash('slice2026', PASSWORD_BCRYPT);
    $h->pdo->prepare(
        "INSERT INTO students (id,id_card,class_id,name,show_name,password,score) VALUES (99,'TEST00000000000099',1,'未编入','未编入',?,120)"
    )->execute([$hash]);
    $h->assertApi(fn() => $h->service->loginStudent('未编入', 'slice2026'), 'NOT_ENROLLED');

    $h->pdo->prepare(
        "INSERT INTO students (id,id_card,class_id,name,show_name,password,score) VALUES (98,'TEST00000000000098',1,'无班宠','无班宠',?,120)"
    )->execute([$hash]);
    $h->pdo->prepare(
        "INSERT INTO slice_players (game_id,student_id,faction_id,nickname,role,pet_code,pet_name,is_active)
         VALUES (1,98,1,'无班宠','player','none','无',1)"
    )->execute();
    $h->assertApi(fn() => $h->service->loginStudent('无班宠', 'slice2026'), 'PET_REQUIRED');
});

testCase('order lifecycle: submit / idempotency / rewrite / withdraw / deadline', function (TestHarness $h): void {
    $p = $h->login('青竹一');
    $teacher = $h->teacher();
    $state = $h->service->getState($p);
    $h->assertSame('open', $state['turn']['status'], 'turn open');
    $h->assertSame([0 => 'N1', 1 => 'N2'], $state['options']['advance_from']['A_START'], 'legal advance targets');
    $h->assertSame(['A_START'], $state['options']['defend_targets'], 'legal defend targets');
    $h->assertSame(40, $state['wallet']['available_points'], 'state wallet');

    $r1 = $h->submit($p, 'advance', 'N2', 'A_START', 'lifecycle_key_0001');
    $h->assertSame('N2', $r1['order']['target_node_code'], 'order target');
    $h->assertSame(1, $h->count('slice_orders', 'turn_id = 1'), 'one order slot');

    $r2 = $h->submit($p, 'advance', 'N2', 'A_START', 'lifecycle_key_0001');
    $h->assertTrue((bool)$r2['idempotent'], 'same key is idempotent');
    $h->assertSame(1, $h->count('slice_order_requests', 'turn_id = 1'), 'idempotent does not duplicate request');
    $h->assertApi(fn() => $h->submit($p, 'advance', 'N1', 'A_START', 'lifecycle_key_0001'), 'IDEMPOTENCY_CONFLICT');

    $r3 = $h->submit($p, 'defend', 'A_START', null, 'lifecycle_key_0002');
    $h->assertSame('defend', $r3['order']['action'], 'rewrite action');
    $h->assertSame(1, $h->count('slice_orders', 'turn_id = 1'), 'rewrite keeps one row');

    $w = $h->service->withdrawOrder($p, ['turn_id' => 1, 'request_key' => 'lifecycle_key_0003']);
    $h->assertTrue((bool)$w['had_order'], 'withdraw had order');
    $state = $h->service->getState($p);
    $h->assertSame(null, $state['my_order'], 'withdraw clears my_order');

    $h->assertApi(fn() => $h->submit($p, 'advance', 'B_START', 'A_START', 'lifecycle_key_0004'), 'START_PROTECTED');
    $h->assertApi(fn() => $h->submit($p, 'advance', 'N2', 'B_START', 'lifecycle_key_0005'), 'NOT_YOUR_CITY');
    $h->assertApi(fn() => $h->submit($p, 'advance', 'N3', 'A_START', 'lifecycle_key_0006'), 'NOT_ADJACENT');

    $h->setDeadline(1, date('Y-m-d H:i:s', time() - 60));
    $h->assertApi(fn() => $h->submit($p, 'advance', 'N2', 'A_START', 'lifecycle_key_0007'), 'TURN_DEADLINE_PASSED');
    $h->assertApi(
        fn() => $h->service->withdrawOrder($p, ['turn_id' => 1, 'request_key' => 'lifecycle_key_0008']),
        'TURN_DEADLINE_PASSED'
    );

    $lock = $h->lock($teacher, 1, false);
    $h->assertSame('locked', $lock['turn']['status'], 'locked after deadline');
    $h->assertSame(8, $lock['snapshot']['orders_count'], 'all players materialized');
    $h->assertSame(8, $lock['snapshot']['default_count'], 'withdrawn order becomes default');
    $h->assertSame(1, $h->count('slice_snapshots'), 'one snapshot');
    $again = $h->lock($teacher, 1, false);
    $h->assertTrue((bool)$again['already'], 'second lock is idempotent');
    $h->assertSame(1, $h->count('slice_snapshots'), 'still one snapshot');
    $h->assertApi(fn() => $h->submit($p, 'advance', 'N2', 'A_START', 'lifecycle_key_0009'), 'TURN_LOCKED');
});

testCase('conflict 1: two attackers vs one defender -> 2:2 defender holds', function (TestHarness $h): void {
    $h->setOwner('N2', 'bi');
    $a = $h->login('青竹一');
    $b1 = $h->login('墨点一');
    $b2 = $h->login('墨点二');
    $teacher = $h->teacher();

    $h->submit($a, 'defend', 'N2', null, 'conflict1_a_defend');
    $h->submit($b1, 'advance', 'N2', 'B_START', 'conflict1_b1_advance');
    $h->submit($b2, 'advance', 'N2', 'B_START', 'conflict1_b2_advance');
    $h->lock($teacher);
    $h->settle($teacher);

    $change = $h->change('N2');
    $h->assertSame('bi', $change['owner_after']['code'], 'defender keeps city');
    $h->assertSame('tie_defender_holds', $change['reason'], 'tie reason');
    $h->assertSame(2, $change['scores']['bi'], 'bi score');
    $h->assertSame(2, $change['scores']['mo'], 'mo score');
    reportResult($h, $a, 1, 'defend_held');
    reportResult($h, $b1, 1, 'failed');
});

testCase('conflict 2: two attackers vs zero defenders -> 2:1 capture', function (TestHarness $h): void {
    $h->setOwner('N2', 'bi');
    $b1 = $h->login('墨点一');
    $b2 = $h->login('墨点二');
    $teacher = $h->teacher();

    $h->submit($b1, 'advance', 'N2', 'B_START', 'conflict2_b1_advance');
    $h->submit($b2, 'advance', 'N2', 'B_START', 'conflict2_b2_advance');
    $h->lock($teacher);
    $h->settle($teacher);

    $change = $h->change('N2');
    $h->assertSame('mo', $change['owner_after']['code'], 'attacker captures');
    $h->assertSame('captured', $change['reason'], 'capture reason');
    $h->assertSame(2, $change['scores']['mo'], 'mo score');
    $h->assertSame(1, $change['scores']['bi'], 'base defense only');
    reportResult($h, $b1, 1, 'captured');
});

testCase('conflict 3: one vs one on neutral -> 1:1 neutral holds', function (TestHarness $h): void {
    $a = $h->login('青竹一');
    $b = $h->login('墨点一');
    $teacher = $h->teacher();

    $h->submit($a, 'advance', 'N2', 'A_START', 'conflict3_a_advance');
    $h->submit($b, 'advance', 'N2', 'B_START', 'conflict3_b_advance');
    $h->lock($teacher);
    $h->settle($teacher);

    $change = $h->change('N2');
    $h->assertSame(null, $change['owner_after'], 'neutral remains neutral');
    $h->assertSame('tie_neutral_holds', $change['reason'], 'neutral tie reason');
    $h->assertSame(1, $change['scores']['bi'], 'bi score');
    $h->assertSame(1, $change['scores']['mo'], 'mo score');
    reportResult($h, $a, 1, 'neutral_held');
    reportResult($h, $b, 1, 'neutral_held');
});

testCase('opposite march: both sides capture, no en-route cancellation', function (TestHarness $h): void {
    $h->setOwner('N1', 'bi');
    $h->setOwner('N3', 'mo');
    $a1 = $h->login('青竹一');
    $a2 = $h->login('青竹二');
    $b1 = $h->login('墨点一');
    $b2 = $h->login('墨点二');
    $teacher = $h->teacher();

    $h->submit($a1, 'advance', 'N3', 'N1', 'opposite_a1');
    $h->submit($a2, 'advance', 'N3', 'N1', 'opposite_a2');
    $h->submit($b1, 'advance', 'N1', 'N3', 'opposite_b1');
    $h->submit($b2, 'advance', 'N1', 'N3', 'opposite_b2');
    $h->lock($teacher);
    $h->settle($teacher);

    $n1 = $h->change('N1');
    $n3 = $h->change('N3');
    $h->assertSame('mo', $n1['owner_after']['code'], 'N1 flips to mo');
    $h->assertSame('bi', $n3['owner_after']['code'], 'N3 flips to bi');
    $h->assertSame(2, $n1['scores']['mo'], 'N1 mo score');
    $h->assertSame(1, $n1['scores']['bi'], 'N1 bi base');
    $h->assertSame(2, $n3['scores']['bi'], 'N3 bi score');
    $h->assertSame(1, $n3['scores']['mo'], 'N3 mo base');
    reportResult($h, $a1, 1, 'captured');
    reportResult($h, $b1, 1, 'captured');
});

testCase('snapshot is read-only: live map/order changes after lock do not affect settlement', function (TestHarness $h): void {
    $a = $h->login('青竹一');
    $teacher = $h->teacher();
    $h->submit($a, 'advance', 'N2', 'A_START', 'snapshot_a_advance');
    $lock = $h->lock($teacher);
    $h->assertSame(1, (int)$lock['snapshot']['snapshot_id'], 'snapshot id');

    // 锁令后直接篡改实时地图与实时军令；结算只能读快照。
    $h->setOwner('N2', 'mo');
    $h->pdo->exec('DELETE FROM slice_orders WHERE turn_id = 1');
    $h->pdo->prepare(
        "INSERT INTO slice_orders (game_id,turn_id,player_id,action,origin_node_code,target_node_code,status,last_request_key)
         VALUES (1,1,5,'advance','B_START','N2','active','live_after_lock')"
    )->execute();

    $h->settle($teacher);
    $change = $h->change('N2');
    $h->assertSame('bi', $change['owner_after']['code'], 'settlement uses snapshot, not live map');
    $h->assertSame(1, $change['scores']['bi'], 'snapshot order counted');
    $h->assertSame(0, $change['scores']['mo'], 'live order ignored');
    $h->assertSame(8, count($h->result()['orders']), 'snapshot order count');
});

testCase('failure retry: same snapshot, no partial results, idempotent settled result', function (TestHarness $h): void {
    $a = $h->login('青竹一');
    $teacher = $h->teacher();
    $h->submit($a, 'advance', 'N2', 'A_START', 'failure_a_advance');
    $h->lock($teacher);

    $h->assertApi(fn() => $h->settle($teacher, 1, ['inject_failure' => true]), 'SETTLE_FAILED');
    $h->assertSame('failed', $h->turn(1)['status'], 'turn failed');
    $h->assertSame(0, $h->count('slice_turn_results'), 'no result after failure');
    $h->assertSame(0, $h->count('slice_node_changes'), 'no node changes after failure');
    $h->assertSame(0, $h->count('slice_player_reports'), 'no player reports after failure');
    $job = $h->fetchOne('SELECT * FROM slice_settlement_jobs WHERE turn_id = 1');
    $h->assertSame('failed', $job['status'], 'job failed');

    $first = $h->settle($teacher);
    $h->assertTrue((bool)$first['result_id'], 'retry result id');
    $h->assertSame('settled', $h->turn(1)['status'], 'turn settled after retry');
    $h->assertSame('bi', $h->nodeOwner('N2'), 'retry applied result');
    $h->assertSame(1, $h->count('slice_turn_results'), 'one result');
    $h->assertSame(8, $h->count('slice_player_reports'), 'all personal reports');

    $second = $h->settle($teacher);
    $h->assertSame((int)$first['result_id'], (int)$second['result_id'], 'second settle returns same result');
    $h->assertSame(1, $h->count('slice_turn_results'), 'still one result');
    $job = $h->fetchOne('SELECT * FROM slice_settlement_jobs WHERE turn_id = 1');
    $h->assertSame('done', $job['status'], 'job done');
    $h->assertTrue((int)$job['attempts'] >= 2, 'attempts recorded');
});

testCase('points integration: shop_orders only, 1:10, daily cap, idempotency', function (TestHarness $h): void {
    $a = $h->login('青竹一');
    $h->assertSame(40, $h->points->getWallet(1)['available_points'], 'initial available');

    $h->pdo->prepare(
        "INSERT INTO shop_orders (order_no,student_id,class_id,type,item_id,item_name,points_spent,verify_code,status)
         VALUES ('TESTGOODS0001',1,1,'goods',1,'测试商品',5,'111111','completed')"
    )->execute();
    $h->assertSame(35, $h->points->getWallet(1)['available_points'], 'goods order lowers available');

    $h->pdo->prepare(
        "INSERT INTO shop_orders (order_no,student_id,class_id,type,item_id,item_name,points_spent,verify_code,status)
         VALUES ('TESTCANCEL0001',1,1,'goods',1,'已撤销',100,'222222','cancelled')"
    )->execute();
    $h->assertSame(35, $h->points->getWallet(1)['available_points'], 'cancelled order excluded');

    $beforeScore = (int)$h->pdo->query('SELECT score FROM students WHERE id = 1')->fetchColumn();
    $r = $h->points->recharge(1, 5, 'recharge_key_0001', 1, (int)$a['id']);
    $h->assertSame(5, $r['points_spent'], 'points spent');
    $h->assertSame(50, $r['jade_added'], 'jade added 1:10');
    $h->assertSame(30, $r['wallet']['available_points'], 'available after recharge');
    $h->assertSame(50, $r['wallet']['jade_balance'], 'jade balance');
    $h->assertSame(5, $r['wallet']['today_recharged_points'], 'today recharge');
    $h->assertSame($beforeScore, (int)$h->pdo->query('SELECT score FROM students WHERE id = 1')->fetchColumn(), 'students.score untouched');

    $order = $h->fetchOne('SELECT * FROM shop_orders WHERE order_no = ?', [$r['order_no']]);
    $h->assertSame('game_recharge', $order['type'], 'shop_orders type');
    $h->assertSame('completed', $order['status'], 'shop order completed');
    $h->assertSame(1, $h->count('shop_orders', "type = 'game_recharge'"), 'one recharge order');

    $r2 = $h->points->recharge(1, 5, 'recharge_key_0001');
    $h->assertTrue((bool)$r2['idempotent'], 'recharge idempotent');
    $h->assertSame(50, $r2['wallet']['jade_balance'], 'idempotent no double credit');
    $h->assertSame(1, $h->count('shop_orders', "type = 'game_recharge'"), 'still one recharge order');
    $h->assertApi(fn() => $h->points->recharge(1, 6, 'recharge_key_0001'), 'IDEMPOTENCY_CONFLICT');

    $h->assertApi(fn() => $h->points->recharge(1, 16, 'recharge_key_0002'), 'DAILY_CAP_EXCEEDED');
    $r3 = $h->points->recharge(1, 15, 'recharge_key_0003');
    $h->assertSame(20, $r3['wallet']['today_recharged_points'], 'daily cap reached');
    $h->assertSame(200, $r3['wallet']['jade_balance'], 'total jade');
    $h->assertSame(15, $r3['wallet']['available_points'], 'available after 5 goods + 20 recharge');
    $h->assertApi(fn() => $h->points->recharge(1, 1, 'recharge_key_0004'), 'DAILY_CAP_EXCEEDED');

    $m = $h->login('墨点四');
    $h->assertSame(12, $h->points->getWallet((int)$m['student_id'])['available_points'], 'low balance student');
    $h->assertApi(fn() => $h->points->recharge((int)$m['student_id'], 13, 'recharge_key_0005'), 'POINTS_INSUFFICIENT');

    $scores = $h->pdo->query('SELECT id, score FROM students ORDER BY id')->fetchAll();
    $expected = [1 => 140, 2 => 136, 3 => 132, 4 => 128, 5 => 124, 6 => 120, 7 => 116, 8 => 112];
    foreach ($scores as $row) {
        if (isset($expected[(int)$row['id']])) {
            $h->assertSame($expected[(int)$row['id']], (int)$row['score'], 'students.score unchanged for ' . $row['id']);
        }
    }
});

testCase('cron: due turn locks and settles, second run is a no-op', function (TestHarness $h): void {
    $a = $h->login('青竹一');
    $h->submit($a, 'advance', 'N2', 'A_START', 'cron_a_advance');
    $h->setDeadline(1, date('Y-m-d H:i:s', time() - 5));
    $first = $h->service->runDueTurns(true);
    $h->assertSame(1, $first['due_turns'], 'one due turn');
    $h->assertTrue((bool)$first['results'][0]['ok'], 'cron lock/settle ok');
    $h->assertSame('settled', $h->turn(1)['status'], 'turn settled by cron');
    $h->assertSame('bi', $h->nodeOwner('N2'), 'cron applied result');
    $second = $h->service->runDueTurns(true);
    $h->assertSame(0, $second['due_turns'], 'no due turn after settlement');
});

testCase('replay: settled turn exposes owners and map changes', function (TestHarness $h): void {
    $a = $h->login('青竹一');
    $teacher = $h->teacher();
    $h->submit($a, 'advance', 'N2', 'A_START', 'replay_a_advance');
    $h->lock($teacher);
    $h->settle($teacher);

    $replay = $h->service->getReplay($a);
    $h->assertSame(1, count($replay['turns']), 'one settled replay turn');
    $h->assertSame(5, count($replay['nodes']), 'five replay nodes');
    $h->assertSame(1, (int)$replay['turns'][0]['turn_no'], 'turn number');
    $h->assertSame('bi', $replay['turns'][0]['owners']['N2']['code'], 'replay owner snapshot');
    $n2 = null;
    foreach ($replay['turns'][0]['changes'] as $change) {
        if ($change['node_code'] === 'N2') {
            $n2 = $change;
            break;
        }
    }
    $h->assertTrue($n2 !== null && (bool)$n2['changed'], 'N2 change marked');
});

testCase('permissions: player cannot settle, teacher cannot order, cross-game denied', function (TestHarness $h): void {
    $p = $h->login('青竹一');
    $t = $h->teacher();
    $h->assertApi(fn() => $h->service->lockTurn($p, 1, true), 'FORBIDDEN');
    $h->assertApi(fn() => $h->service->settleTurn($p, 1), 'FORBIDDEN');
    $h->assertApi(fn() => $h->service->adminStatus($p), 'FORBIDDEN');
    $h->assertApi(fn() => $h->submit($t, 'defend', 'A_START', null, 'teacher_order_0001'), 'FORBIDDEN');

    $h->pdo->prepare(
        "INSERT INTO slice_games (code,name,status,rules_version,turn_seconds,current_turn_id)
         VALUES ('OTHER','其他测试局','running','A1',600,NULL)"
    )->execute();
    $otherGameId = (int)$h->pdo->lastInsertId();
    $h->pdo->prepare(
        "INSERT INTO slice_turns (game_id,turn_no,status,opens_at,deadline_at,rules_version)
         VALUES (?,1,'open',NOW(),DATE_ADD(NOW(), INTERVAL 600 SECOND),'A1')"
    )->execute([$otherGameId]);
    $otherTurnId = (int)$h->pdo->lastInsertId();
    $h->assertApi(fn() => $h->service->getState($p, $otherTurnId), 'FORBIDDEN');
    $h->assertApi(fn() => $h->service->lockTurn($t, $otherTurnId, true), 'FORBIDDEN');
});

testCase('concurrency: 8 simultaneous submissions for one player -> one slot, all requests logged', function (TestHarness $h): void {
    $start = microtime(true) + 1.2;
    $specs = [];
    for ($i = 1; $i <= 8; $i++) {
        $specs[] = [
            'submit',
            sprintf('%.6f', $start),
            '青竹一',
            'defend',
            '',
            'A_START',
            'conc_key_' . str_pad((string)$i, 4, '0', STR_PAD_LEFT),
        ];
    }
    $results = $h->spawnWorkers($specs);
    foreach ($results as $i => $result) {
        $h->assertTrue($result['json'] !== null, 'worker ' . $i . ' JSON; stderr=' . $result['stderr'] . ' stdout=' . $result['stdout']);
        $h->assertTrue((bool)$result['json']['ok'], 'worker ' . $i . ' failed: ' . json_encode($result['json'], JSON_UNESCAPED_UNICODE));
    }
    $h->assertSame(1, $h->count('slice_orders', 'turn_id = 1'), 'one order row');
    $h->assertSame(8, $h->count('slice_order_requests', 'turn_id = 1'), 'all request keys recorded');
    $order = $h->fetchOne('SELECT * FROM slice_orders WHERE turn_id = 1');
    $h->assertSame('active', $order['status'], 'final order active');
    $h->assertSame('defend', $order['action'], 'final action');
});

testCase('concurrency: 6 simultaneous locks -> exactly one snapshot', function (TestHarness $h): void {
    $start = microtime(true) + 1.2;
    $specs = [];
    for ($i = 1; $i <= 6; $i++) {
        $specs[] = ['lock', sprintf('%.6f', $start), 'teacher', '', '', '', ''];
    }
    $results = $h->spawnWorkers($specs);
    foreach ($results as $i => $result) {
        $h->assertTrue($result['json'] !== null, 'lock worker ' . $i . ' JSON; stderr=' . $result['stderr'] . ' stdout=' . $result['stdout']);
        $h->assertTrue((bool)$result['json']['ok'], 'lock worker ' . $i . ' failed: ' . json_encode($result['json'], JSON_UNESCAPED_UNICODE));
    }
    $h->assertSame(1, $h->count('slice_snapshots', 'turn_id = 1'), 'one snapshot');
    $h->assertSame('locked', $h->turn(1)['status'], 'turn locked');
    $h->assertSame(8, $h->count('slice_snapshot_orders'), 'eight materialized orders');
});

echo "\n== Summary: {$passed} passed, {$failed} failed ==\n";
if ($failed > 0) {
    foreach ($failures as [$name, $message]) {
        echo "FAILED: {$name} -> {$message}\n";
    }
    exit(1);
}
exit(0);
