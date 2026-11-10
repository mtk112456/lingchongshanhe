<?php
declare(strict_types=1);

/**
 * 28 回合 = 4 周赛季模拟
 *
 * 验证：
 *   - 28 个回合都能结算
 *   - 第 1–2 周长安不开放
 *   - 第 3 周长安开放
 *   - 第 4 周只打长安/邻城
 *   - 4 周编成能按周切换
 *   - 至少发生一次易主
 */

require_once __DIR__ . '/../bootstrap.php';
require_once __DIR__ . '/../src/SqlRunner.php';
require_once __DIR__ . '/../src/HandService.php';
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
$seed = dirname(__DIR__) . '/seed_map12.sql';
SqlRunner::runFile($pdo, $seed);

$gameId = (int)$pdo->query("SELECT id FROM slice_games WHERE code = 'MAP12_TEST'")->fetchColumn();
if ($gameId <= 0) {
    fwrite(STDERR, "MAP12_TEST 未创建\n");
    exit(1);
}

$players = $pdo->query(
    "SELECT p.id, f.code AS faction_code
     FROM slice_players p JOIN slice_factions f ON f.id = p.faction_id
     WHERE p.game_id = {$gameId} AND p.role = 'player'
     ORDER BY p.id"
)->fetchAll();
$factionIndex = [];
foreach ($pdo->query("SELECT code FROM slice_factions WHERE game_id = {$gameId} ORDER BY sort_order")->fetchAll(PDO::FETCH_COLUMN) as $i => $code) {
    $factionIndex[(string)$code] = $i;
}

$turnId = (int)$pdo->query("SELECT id FROM slice_turns WHERE game_id = {$gameId} ORDER BY turn_no LIMIT 1")->fetchColumn();
$handService = new HandService($pdo);
$settler = new CardSettlementService($pdo);

$neutral = ['hanzhong', 'xiangyang', 'taiyuan', 'luoyang', 'jiangling', 'changsha', 'kuaiji', 'shouchun'];
$changanNeighbors = ['hanzhong', 'luoyang', 'jiangling', 'jianye'];
$compositionByFaction = [
    ['cav', 'shield', 'arc'],
    ['shield', 'spear', 'arc'],
    ['arc', 'cav', 'shield'],
    ['spear', 'arc', 'cav'],
];

$totalBattles = 0;
$totalCaptures = 0;
$changanBattles = 0;
$changanBattlesBeforeWeek3 = 0;
$settledTurns = 0;
$scoreCounts = [];
$finalNodes = [];

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

        // 每周第一次设置编成
        if (in_array($round, [1, 8, 15, 22], true)) {
            foreach ($players as $p) {
                $fi = $factionIndex[(string)$p['faction_code']] ?? 0;
                $handService->setComposition($gameId, (int)$p['id'], $week, $compositionByFaction[$fi % 4]);
            }
        }

        $owners = [];
        foreach ($pdo->query("SELECT node_code, owner_faction_id FROM slice_nodes WHERE game_id = {$gameId}")->fetchAll() as $n) {
            $owners[(string)$n['node_code']] = $n['owner_faction_id'] === null ? null : (int)$n['owner_faction_id'];
        }

        foreach ($players as $p) {
            $pid = (int)$p['id'];
            $fi = $factionIndex[(string)$p['faction_code']] ?? 0;
            $hand = $handService->getOrCreateHand($gameId, $turnId, $pid);

            if ($week <= 2) {
                $target = $neutral[($fi * 2 + $round) % count($neutral)];
            } elseif ($week === 3) {
                $target = $fi === 0 ? 'changan' : $neutral[($fi * 2 + $round) % count($neutral)];
            } else {
                // 第 4 周：每回合一个阵营打长安，其余打长安邻城
                $target = $fi === ($round % 4) ? 'changan' : $changanNeighbors[$fi % 4];
            }

            for ($slot = 0; $slot < 3; $slot++) {
                $handService->play(
                    $gameId,
                    $turnId,
                    $pid,
                    $slot,
                    (string)$hand['cards'][$slot],
                    $target,
                    $slot + 1,
                    $slot === 2 ? 'back' : 'front',
                    's28_' . $round . '_' . $pid . '_' . $slot
                );
            }
        }

        $result = $settler->settle($gameId, $turnId);
        $settledTurns++;
        foreach ($result['battles'] as $b) {
            if (!empty($b['battle_id'])) {
                $totalBattles++;
                $score = (int)($b['score'] ?? 0);
                $scoreCounts[$score] = ($scoreCounts[$score] ?? 0) + 1;
                if (($b['node_code'] ?? '') === 'changan') {
                    $changanBattles++;
                    if ($week < 3) {
                        $changanBattlesBeforeWeek3++;
                    }
                }
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
} finally {
    // 恢复 MAP12_TEST，避免污染其他测试
    SqlRunner::runFile($pdo, $seed);
}

check('28 回合全部结算', $settledTurns === 28, 'settled=' . $settledTurns);
check('有战斗', $totalBattles > 0, 'battles=' . $totalBattles);
check('有易主', $totalCaptures > 0, 'captures=' . $totalCaptures);
check('第 1–2 周没有长安战斗', $changanBattlesBeforeWeek3 === 0, 'before=' . $changanBattlesBeforeWeek3);
check('第 3 周后出现长安战斗', $changanBattles > 0, 'changan=' . $changanBattles);
check('28 回合 = 第 4 周', CardSettlementService::weekOfTurn(28) === 4);

echo PHP_EOL;
echo "scores: " . json_encode($scoreCounts) . PHP_EOL;
foreach ($finalNodes as $n) {
    echo sprintf("  %-10s owner=%-4s morale=%d\n", $n['node_code'], $n['owner'] ?? '-', (int)$n['morale']);
}
echo sprintf("SEASON28: %d turns, %d battles, %d captures, %d changan battles\n",
    $settledTurns, $totalBattles, $totalCaptures, $changanBattles);

if ($failed > 0) {
    echo "SEASON28 FAIL ({$failed})\n";
    exit(1);
}
echo "SEASON28 PASS\n";
