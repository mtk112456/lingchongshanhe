<?php
declare(strict_types=1);

require_once __DIR__ . '/../bootstrap.php';
require_once __DIR__ . '/../src/SqlRunner.php';
require_once __DIR__ . '/../src/CardSettlementService.php';
require_once __DIR__ . '/../src/MeritService.php';

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
$vanguardIds = array_slice($players, 0, 3);
$supporterId = $players[3];
$scoreBefore = (int)$pdo->query('SELECT score FROM students WHERE id = (SELECT student_id FROM slice_players WHERE id = ' . $vanguardIds[0] . ')')->fetchColumn();

// 两回合：第一回合推民心，第二回合破城
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
        foreach ($vanguardIds as $i => $pid) {
            $insert->execute([
                $gameId, $turnIds[$no], $pid, 0, 'night_raid', 'N1', $i + 1, 'front',
                'merit_' . $no . '_' . $i . '_' . bin2hex(random_bytes(3)),
            ]);
        }
        $insert->execute([
            $gameId, $turnIds[$no], $supporterId, 0, 'scout', 'N1', 1, 'front',
            'merit_scout_' . $no . '_' . bin2hex(random_bytes(3)),
        ]);
        $result = $settler->settle($gameId, $turnIds[$no]);
        $battle = null;
        foreach ($result['battles'] as $entry) {
            if (($entry['node_code'] ?? '') === 'N1') {
                $battle = $entry;
                break;
            }
        }
        check("第 {$no} 回合产生战斗", $battle !== null && !empty($battle['battle_id']));
        if ($no === 1) {
            check('第 1 回合未破城', empty($battle['captured']));
            check('先锋本场 30 军功', ($battle['merit'][$vanguardIds[0]]['total'] ?? 0) === 30, json_encode($battle['merit'] ?? []));
            check('支援本场 18 军功', ($battle['merit'][$supporterId]['total'] ?? 0) === 18, json_encode($battle['merit'] ?? []));
        } else {
            check('第 2 回合破城', !empty($battle['captured']));
            check('破城先锋本场 60 军功', ($battle['merit'][$vanguardIds[0]]['total'] ?? 0) === 60, json_encode($battle['merit'] ?? []));
            check('破城支援本场 33 军功', ($battle['merit'][$supporterId]['total'] ?? 0) === 33, json_encode($battle['merit'] ?? []));
        }
    }

    $merit = new MeritService($pdo);
    $summary = $merit->summary($gameId, $vanguardIds[0], 1);
    check('两回合先锋累计 100 军功', $summary['total'] === 100, 'total=' . $summary['total']);
    check('周军功 100', $summary['week'] === 100, 'week=' . $summary['week']);
    check('军功有分类明细', isset($summary['breakdown']['vanguard'], $summary['breakdown']['capture']));
    check('军功榜第 1', $summary['rank'] === 1, 'rank=' . $summary['rank']);

    $supportSummary = $merit->summary($gameId, $supporterId, 1);
    check('支援者累计 61 军功', $supportSummary['total'] === 61, 'total=' . $supportSummary['total']);
    check('支援者没有先锋军功', !isset($supportSummary['breakdown']['vanguard']));

    $top = $merit->top($gameId, 10);
    check('军功榜有 4 人', count($top) === 4, 'top=' . count($top));
    check('军功榜按总分降序', $top[0]['total'] >= $top[1]['total']);
    check('军功榜带昵称和阵营', isset($top[0]['nickname'], $top[0]['faction']));

    $weekTop = $merit->weekTop($gameId, 1, 10);
    check('周榜有 4 人', count($weekTop) === 4);

    $turnSummary = $merit->turnSummary($turnIds[2], $vanguardIds[0]);
    check('单回合战报军功 65', $turnSummary['turn_total'] === 65, 'turn=' . $turnSummary['turn_total']);

    // 不修改 students.score 是红线
    $scoreAfter = (int)$pdo->query('SELECT score FROM students WHERE id = (SELECT student_id FROM slice_players WHERE id = ' . $vanguardIds[0] . ')')->fetchColumn();
    check('不修改 students.score', $scoreAfter === $scoreBefore, "before={$scoreBefore} after={$scoreAfter}");

    // state 与战报都要带上军功
    $pdo->prepare('UPDATE slice_games SET current_turn_id = ? WHERE id = ?')->execute([$turnIds[2], $gameId]);
    $login = slice_bootstrap()[2]->loginStudent('青竹一', 'slice2026');
    $player = slice_bootstrap()[2]->authenticate($login['token']);
    $state = slice_bootstrap()[2]->getState($player, $turnIds[2]);
    $stateTotal = $state['merit']['total'] ?? null;
    check('state 带军功总分', is_int($stateTotal), 'total=' . var_export($stateTotal, true));
    $report = slice_bootstrap()[2]->getReport($player, $turnIds[2]);
    check('战报带本回合军功', ($report['me']['merit']['turn_total'] ?? 0) > 0, 'turn=' . ($report['me']['merit']['turn_total'] ?? 'null'));
} finally {
    $pdo->exec("DELETE FROM slice_games WHERE code = 'SLICE_A'");
    SqlRunner::runFile($pdo, $seed);
}

echo PHP_EOL;
if ($failed > 0) {
    echo "MERIT FAIL ({$failed})\n";
    exit(1);
}
echo "MERIT PASS\n";
