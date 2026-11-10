<?php
declare(strict_types=1);

/**
 * 100 人 / 300 令结算压测（服务层，不走 HTTP）
 *
 * 做法：
 *   1. 建独立游戏 LOAD100，克隆 MAP12_TEST 的 13 节点 / 19 边 / 4 阵营
 *   2. 造 100 个测试学生 + 班宠 + 玩家（每阵营 25 人）
 *   3. 每人 3 张令，打到 13 座城
 *   4. 计时 21:00 结算
 *
 * 用法：
 *   php server/slice/tests/load100_test.php
 */

require_once __DIR__ . '/../bootstrap.php';
require_once __DIR__ . '/../src/CardSettlementService.php';

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

$sourceGameId = (int)$pdo->query("SELECT id FROM slice_games WHERE code = 'MAP12_TEST'")->fetchColumn();
if ($sourceGameId <= 0) {
    fwrite(STDERR, "缺少 MAP12_TEST，请先跑 setup_map12_db.php\n");
    exit(1);
}

$cleanup = function () use ($pdo): void {
    $stmt = $pdo->prepare("SELECT id FROM slice_games WHERE code = 'LOAD100'");
    $stmt->execute();
    $id = (int)$stmt->fetchColumn();
    if ($id > 0) {
        $pdo->prepare('DELETE FROM slice_games WHERE id = ?')->execute([$id]);
    }
    $ids = $pdo->query("SELECT id FROM students WHERE name LIKE 'LOAD%'")->fetchAll(PDO::FETCH_COLUMN);
    if ($ids !== []) {
        $in = implode(',', array_map('intval', $ids));
        $pdo->exec("DELETE FROM student_pets WHERE student_id IN ({$in})");
        $pdo->exec("DELETE FROM students WHERE id IN ({$in})");
    }
};

$cleanup();

$passwordHash = (string)$pdo->query('SELECT password FROM students ORDER BY id LIMIT 1')->fetchColumn();
$petTemplateId = (int)$pdo->query('SELECT id FROM pet_templates ORDER BY id LIMIT 1')->fetchColumn();
$petCode = (string)$pdo->query('SELECT code FROM pet_templates ORDER BY id LIMIT 1')->fetchColumn();

$pdo->beginTransaction();
try {
    // 1. 游戏
    $pdo->prepare(
        "INSERT INTO slice_games (code, name, status, rules_version, turn_seconds)
         VALUES ('LOAD100', '100 人压测', 'paused', 'cards_v1', 600)"
    )->execute();
    $gameId = (int)$pdo->lastInsertId();

    // 2. 阵营 / 节点 / 边
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

    $factions = $pdo->query("SELECT id, code FROM slice_factions WHERE game_id = {$gameId} ORDER BY sort_order")
        ->fetchAll();
    $nodes = $pdo->query("SELECT node_code FROM slice_nodes WHERE game_id = {$gameId} ORDER BY sort_order")
        ->fetchAll(PDO::FETCH_COLUMN);

    // 3. 100 个学生 + 班宠 + 玩家
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
    for ($i = 0; $i < 100; $i++) {
        $tag = sprintf('LOAD%03d', $i + 1);
        $insertStudent->execute(['LOAD100' . sprintf('%04d', $i + 1), $tag, $tag, $passwordHash]);
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

    // 4. 回合 + 编成
    $pdo->prepare(
        "INSERT INTO slice_turns (game_id, turn_no, status, opens_at, deadline_at, rules_version)
         VALUES (?, 1, 'open', NOW(), DATE_ADD(NOW(), INTERVAL 600 SECOND), 'cards_v1')"
    )->execute([$gameId]);
    $turnId = (int)$pdo->lastInsertId();
    $pdo->prepare('UPDATE slice_games SET current_turn_id = ? WHERE id = ?')->execute([$turnId, $gameId]);

    $insertComp = $pdo->prepare(
        'INSERT INTO slice_compositions (game_id, player_id, week_no, types_json, changed_once)
         VALUES (?, ?, 1, ?, 0)'
    );
    $types = ['cav', 'shield', 'arc', 'spear'];
    foreach ($players as $i => $p) {
        $comp = [$types[$i % 4], $types[($i + 1) % 4], $types[($i + 2) % 4]];
        $insertComp->execute([$gameId, $p['id'], json_encode($comp)]);
    }

    // 5. 300 张令：每人 3 令，按阵营打自己的 3 座城（避免全场平票）
    $cards = CardSettlementService::TEAM_CARDS;
    $factionIndex = [];
    foreach ($factions as $idx => $f) {
        $factionIndex[(string)$f['code']] = (int)$idx;
    }
    $insertOrder = $pdo->prepare(
        'INSERT INTO slice_order_slots
            (game_id, turn_id, player_id, slot, card_code, target_node_code, lane, row_pos, status, last_request_key)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, "active", ?)'
    );
    foreach ($players as $i => $p) {
        $fi = $factionIndex[$p['faction']] ?? 0;
        for ($slot = 0; $slot < 3; $slot++) {
            $node = $nodes[($fi * 3 + $slot) % count($nodes)];
            $card = $cards[($i + $slot) % count($cards)];
            $insertOrder->execute([
                $gameId,
                $turnId,
                $p['id'],
                $slot,
                $card,
                $node,
                $slot + 1,
                $slot === 2 ? 'back' : 'front',
                'load_' . $i . '_' . $slot . '_' . bin2hex(random_bytes(3)),
            ]);
        }
    }

    $pdo->commit();
} catch (Throwable $e) {
    $pdo->rollBack();
    $cleanup();
    fwrite(STDERR, '压测准备失败：' . $e->getMessage() . PHP_EOL);
    exit(1);
}

$orderCount = (int)$pdo->query("SELECT COUNT(*) FROM slice_order_slots WHERE turn_id = {$turnId} AND status = 'active'")->fetchColumn();
check('300 张令入库', $orderCount === 300, 'orders=' . $orderCount);
check('100 名玩家', count($players) === 100, 'players=' . count($players));

$started = microtime(true);
$result = (new CardSettlementService($pdo))->settle($gameId, $turnId);
$elapsedMs = (microtime(true) - $started) * 1000;

check('结算 < 10 秒', $elapsedMs < 10000, sprintf('%.0f ms', $elapsedMs));
check('结算 < 5 秒（目标）', $elapsedMs < 5000, sprintf('%.0f ms', $elapsedMs));
check('产生战斗', count($result['battles']) > 0, 'battles=' . count($result['battles']));
check('战斗数 ≤ 13', count($result['battles']) <= 13, 'battles=' . count($result['battles']));

$teamSizes = [];
foreach ($result['battles'] as $b) {
    if (!empty($b['battle_id'])) {
        $teamSizes[] = count($b['teams'] ?? []);
    }
}
check('每场最多 3 队', $teamSizes !== [] && max($teamSizes) <= 3, 'sizes=' . json_encode($teamSizes));

$battleRows = (int)$pdo->query("SELECT COUNT(*) FROM slice_battles WHERE turn_id = {$turnId}")->fetchColumn();
$battleEntries = count(array_filter($result['battles'], fn($b) => !empty($b['battle_id'])));
check('战斗已入库', $battleRows === $battleEntries, "db={$battleRows} settled={$battleEntries}");

$status = (string)$pdo->query("SELECT status FROM slice_turns WHERE id = {$turnId}")->fetchColumn();
check('回合已结算', $status === 'settled', 'status=' . $status);

$moraleChanged = (int)$pdo->query("SELECT COUNT(*) FROM slice_nodes WHERE game_id = {$gameId} AND morale != 0")->fetchColumn();
check('民心有推进', $moraleChanged > 0, 'nodes=' . $moraleChanged);

echo PHP_EOL;
echo sprintf("LOAD100: %.0f ms, %d battles, %d nodes changed\n", $elapsedMs, count($result['battles']), $moraleChanged);

$cleanup();

if ($failed > 0) {
    echo "LOAD100 FAIL ({$failed})\n";
    exit(1);
}
echo "LOAD100 PASS\n";
