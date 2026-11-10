<?php
declare(strict_types=1);

/**
 * 100 人 × 28 回合（4 周）赛季模拟
 *
 * 与 season28_test 的区别：每阵营 25 人，3 先锋 + 22 支援（+30% 封顶）。
 * 目的：看真实规模下普通城/中立城的易主节奏。
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
    $stmt = $pdo->prepare("SELECT id FROM slice_games WHERE code = 'SEASON100'");
    $stmt->execute();
    $id = (int)$stmt->fetchColumn();
    if ($id > 0) {
        $pdo->prepare('DELETE FROM slice_games WHERE id = ?')->execute([$id]);
    }
    $ids = $pdo->query("SELECT id FROM students WHERE name LIKE 'S100%'")->fetchAll(PDO::FETCH_COLUMN);
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
    $pdo->prepare(
        "INSERT INTO slice_games (code, name, status, rules_version, turn_seconds)
         VALUES ('SEASON100', '100 人赛季模拟', 'paused', 'cards_v1', 600)"
    )->execute();
    $gameId = (int)$pdo->lastInsertId();

    $pdo->prepare(
        'INSERT INTO slice_factions (game_id, code, name, color, start_node_code, sort_order)
         SELECT ?, code, name, color, start_node_code, sort_order FROM slice_factions WHERE game_id = ?'
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

    $factions = $pdo->query("SELECT id, code FROM slice_factions WHERE game_id = {$gameId} ORDER BY sort_order")->fetchAll();
    $nodes = $pdo->query("SELECT node_code FROM slice_nodes WHERE game_id = {$gameId} ORDER BY sort_order")->fetchAll(PDO::FETCH_COLUMN);
    $factionIndex = [];
    foreach ($factions as $i => $f) {
        $factionIndex[(string)$f['code']] = $i;
    }

    $insertStudent = $pdo->prepare("INSERT INTO students (id_card, class_id, name, show_name, password, score) VALUES (?, 1, ?, ?, ?, 100)");
    $insertPet = $pdo->prepare('INSERT INTO student_pets (student_id, pet_template_id, nickname, level, hunger, mood) VALUES (?, ?, ?, 10, 100, 100)');
    $insertPlayer = $pdo->prepare(
        'INSERT INTO slice_players
            (game_id, student_id, admin_id, faction_id, nickname, role, pet_instance_id, pet_code, pet_name, is_active)
         VALUES (?, ?, NULL, ?, ?, "player", ?, ?, ?, 1)'
    );

    $players = [];
    for ($i = 0; $i < 100; $i++) {
        $tag = sprintf('S100%03d', $i + 1);
        $insertStudent->execute(['SEASON100' . sprintf('%04d', $i + 1), $tag, $tag, $passwordHash]);
        $studentId = (int)$pdo->lastInsertId();
        $insertPet->execute([$studentId, $petTemplateId, $tag]);
        $petId = (int)$pdo->lastInsertId();
        $faction = $factions[$i % 4];
        $insertPlayer->execute([$gameId, $studentId, (int)$faction['id'], $tag, $petId, $petCode, $tag]);
        $players[] = ['id' => (int)$pdo->lastInsertId(), 'faction' => (string)$faction['code']];
    }

    $pdo->prepare(
        "INSERT INTO slice_turns (game_id, turn_no, status, opens_at, deadline_at, rules_version)
         VALUES (?, 1, 'open', NOW(), DATE_ADD(NOW(), INTERVAL 600 SECOND), 'cards_v1')"
    )->execute([$gameId]);
    $turnId = (int)$pdo->lastInsertId();
    $pdo->prepare('UPDATE slice_games SET current_turn_id = ? WHERE id = ?')->execute([$turnId, $gameId]);

    $insertComp = $pdo->prepare(
        'INSERT INTO slice_compositions (game_id, player_id, week_no, types_json, changed_once)
         VALUES (?, ?, ?, ?, 0)
         ON DUPLICATE KEY UPDATE types_json = VALUES(types_json)'
    );
    $types = ['cav', 'shield', 'arc', 'spear'];
    $insertOrders = $pdo->prepare(
        'INSERT INTO slice_order_slots
            (game_id, turn_id, player_id, slot, card_code, target_node_code, lane, row_pos, status, last_request_key)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, "active", ?)'
    );
    $cards = CardSettlementService::TEAM_CARDS;

    $pdo->commit();
} catch (Throwable $e) {
    $pdo->rollBack();
    $cleanup();
    fwrite(STDERR, '准备失败：' . $e->getMessage() . PHP_EOL);
    exit(1);
}

$settler = new CardSettlementService($pdo);
$settledTurns = 0;
$totalBattles = 0;
$totalCaptures = 0;
$scoreCounts = [];
$finalNodes = [];
$firstBattle = null;
$seasonStarted = microtime(true);

try {
    for ($round = 1; $round <= 28; $round++) {
        $week = intdiv($round - 1, 7) + 1;
        if ($round > 1) {
            $pdo->prepare(
                "INSERT INTO slice_turns (game_id, turn_no, status, opens_at, deadline_at, rules_version)
                 VALUES (?, ?, 'open', NOW(), DATE_ADD(NOW(), INTERVAL 600 SECOND), 'cards_v1')"
            )->execute([$gameId, $round]);
            $turnId = (int)$pdo->lastInsertId();
            $pdo->prepare('UPDATE slice_games SET current_turn_id = ? WHERE id = ?')->execute([$turnId, $gameId]);
        }

        foreach ($players as $i => $p) {
            $k = intdiv($i, 4);
            $comp = [$types[$k % 4], $types[($k + 1) % 4], $types[($k + 2) % 4]];
            $insertComp->execute([$gameId, $p['id'], $week, json_encode($comp)]);

            $fi = $factionIndex[$p['faction']] ?? 0;
            for ($slot = 0; $slot < 3; $slot++) {
                $node = $nodes[($fi * 3 + (($slot + $i) % 3)) % count($nodes)];
                $lane = (($i + $slot) % 3) + 1;
                $insertOrders->execute([
                    $gameId,
                    $turnId,
                    $p['id'],
                    $slot,
                    $cards[($i + $slot) % count($cards)],
                    $node,
                    $lane,
                    $slot === 2 ? 'back' : 'front',
                    's100_' . $round . '_' . $i . '_' . $slot,
                ]);
            }
        }

        $result = $settler->settle($gameId, $turnId);
        $settledTurns++;
        foreach ($result['battles'] as $b) {
            if (!empty($b['battle_id'])) {
                $totalBattles++;
                if ($firstBattle === null) {
                    $firstBattle = $b;
                }
                $score = (int)($b['score'] ?? 0);
                $scoreCounts[$score] = ($scoreCounts[$score] ?? 0) + 1;
                if (!empty($b['captured'])) {
                    $totalCaptures++;
                }
            }
        }
    }

    $finalNodes = $pdo->query(
        "SELECT n.node_code, n.morale, f.code AS owner
         FROM slice_nodes n LEFT JOIN slice_factions f ON f.id = n.owner_faction_id
         WHERE n.game_id = {$gameId} ORDER BY n.sort_order"
    )->fetchAll();
    $seasonMs = (microtime(true) - $seasonStarted) * 1000;
} finally {
    $cleanup();
}

check('28 回合全部结算', $settledTurns === 28, 'settled=' . $settledTurns);
check('产生战斗', $totalBattles > 0, 'battles=' . $totalBattles);
check('产生易主', $totalCaptures > 0, 'captures=' . $totalCaptures);

$owned = [];
foreach ($finalNodes as $n) {
    $owned[$n['owner'] ?? '-'] = ($owned[$n['owner'] ?? '-'] ?? 0) + 1;
}

echo PHP_EOL;
echo 'scores: ' . json_encode($scoreCounts) . PHP_EOL;
if ($firstBattle !== null) {
    echo 'first battle: ' . json_encode([
        'node' => $firstBattle['node_code'] ?? '',
        'score' => $firstBattle['score'] ?? null,
        'teams' => $firstBattle['teams'] ?? [],
        'defender' => $firstBattle['defender_teams'] ?? [],
    ], JSON_UNESCAPED_UNICODE) . PHP_EOL;
}
echo 'owners: ' . json_encode($owned) . PHP_EOL;
foreach ($finalNodes as $n) {
    echo sprintf("  %-10s owner=%-4s morale=%d\n", $n['node_code'], $n['owner'] ?? '-', (int)$n['morale']);
}
echo sprintf("SEASON100: %d turns, %d battles, %d captures\n", $settledTurns, $totalBattles, $totalCaptures);
echo sprintf("season time: %.0f ms\n", $seasonMs);

if ($failed > 0) {
    echo "SEASON100 FAIL ({$failed})\n";
    exit(1);
}
echo "SEASON100 PASS\n";
