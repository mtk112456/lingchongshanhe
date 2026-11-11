<?php
declare(strict_types=1);

/**
 * 100 人 × 28 回合（4 周）完整赛季模拟：军功 / 太守 / 文房小院
 *
 * 与 season100_test 的区别：
 *   - 每回合随机编成、卡牌、目标（不再固定 3 城），模拟真实学生乱打
 *   - 每 7 回合结算上周太守（EstateService::refreshGovernors）
 *   - 每回合让本周军功前 10 名按房间轮换尝试升级小院
 *   - 只跑在独立库 test_sim（SLICE_CONFIG=config.sim.php）
 *
 * 断言：28 回合全结算、易主 ≥ 20、军功行 > 0、太守行 > 0、小院升级 ≥ 10。
 */

require_once __DIR__ . '/../bootstrap.php';
require_once __DIR__ . '/../src/CardSettlementService.php';
require_once __DIR__ . '/../src/EstateService.php';
require_once __DIR__ . '/../src/MeritService.php';
require_once __DIR__ . '/../src/SeasonService.php';

$failed = 0;
function check(string $name, bool $ok, string $detail = ''): void
{
    global $failed;
    echo ($ok ? '[PASS] ' : '[FAIL] ') . $name . ($detail !== '' ? ' — ' . $detail : '') . PHP_EOL;
    if (!$ok) {
        $failed++;
    }
}

$configPath = getenv('SLICE_CONFIG') ?: '';
if ($configPath === '' || !str_contains(basename($configPath), 'sim')) {
    fwrite(STDERR, "请设置 SLICE_CONFIG=config.sim.php 后再跑（当前：{$configPath}）\n");
    exit(1);
}

$seed = (int)(getenv('SIM_SEED') ?: 20261111);
mt_srand($seed);

[$config, $pdo] = slice_bootstrap();
echo 'db=' . ($config['db']['name'] ?? '?') . ' seed=' . $seed . PHP_EOL;

$sourceGameId = (int)$pdo->query("SELECT id FROM slice_games WHERE code = 'MAP12_TEST'")->fetchColumn();
if ($sourceGameId <= 0) {
    fwrite(STDERR, "缺少 MAP12_TEST，请先跑 setup_map12_db.php\n");
    exit(1);
}

/**
 * 清理本模拟产生的一切数据；同时清掉 season100_test 的残留。
 */
$cleanup = function () use ($pdo): void {
    $pdo->exec("DELETE FROM slice_games WHERE code IN ('SEASON_SIM', 'SEASON100')");
    $stmt = $pdo->query("SELECT id FROM students WHERE name LIKE 'SIM%' OR name LIKE 'S100%'");
    $ids = $stmt->fetchAll(PDO::FETCH_COLUMN);
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

$gameId = 0;
$players = [];
$nodes = [];
$factionCodes = [];
$nodeOwner = [];
$adj = [];

$pdo->beginTransaction();
try {
    $pdo->prepare(
        "INSERT INTO slice_games (code, name, status, rules_version, turn_seconds)
         VALUES ('SEASON_SIM', '100 人完整赛季模拟', 'running', 'cards_v1', 600)"
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
    foreach ($factions as $f) {
        $factionCodes[(int)$f['id']] = (string)$f['code'];
    }
    foreach ($pdo->query("SELECT node_code, owner_faction_id FROM slice_nodes WHERE game_id = {$gameId}")->fetchAll() as $n) {
        $nodeOwner[(string)$n['node_code']] = $n['owner_faction_id'] === null ? null : (int)$n['owner_faction_id'];
    }
    foreach ($pdo->query("SELECT a_node_code, b_node_code FROM slice_edges WHERE game_id = {$gameId} ORDER BY id")->fetchAll() as $e) {
        $adj[(string)$e['a_node_code']][] = (string)$e['b_node_code'];
        $adj[(string)$e['b_node_code']][] = (string)$e['a_node_code'];
    }

    $insertStudent = $pdo->prepare("INSERT INTO students (id_card, class_id, name, show_name, password, score) VALUES (?, 1, ?, ?, ?, 100)");
    $insertPet = $pdo->prepare('INSERT INTO student_pets (student_id, pet_template_id, nickname, level, hunger, mood) VALUES (?, ?, ?, ?, 100, 100)');
    $insertPlayer = $pdo->prepare(
        'INSERT INTO slice_players
            (game_id, student_id, admin_id, faction_id, nickname, role, pet_instance_id, pet_code, pet_name, is_active)
         VALUES (?, ?, NULL, ?, ?, "player", ?, ?, ?, 1)'
    );

    for ($i = 0; $i < 100; $i++) {
        $tag = sprintf('SIM%03d', $i + 1);
        $insertStudent->execute(['SEASON_SIM' . sprintf('%04d', $i + 1), $tag, $tag, $passwordHash]);
        $studentId = (int)$pdo->lastInsertId();
        $insertPet->execute([$studentId, $petTemplateId, $tag, 6 + ($i % 25)]);
        $petId = (int)$pdo->lastInsertId();
        $faction = $factions[$i % 4];
        $insertPlayer->execute([$gameId, $studentId, (int)$faction['id'], $tag, $petId, $petCode, $tag]);
        $players[] = [
            'id' => (int)$pdo->lastInsertId(),
            'faction_id' => (int)$faction['id'],
            'faction' => (string)$faction['code'],
        ];
    }

    $pdo->prepare(
        "INSERT INTO slice_turns (game_id, turn_no, status, opens_at, deadline_at, rules_version)
         VALUES (?, 1, 'open', NOW(), DATE_ADD(NOW(), INTERVAL 600 SECOND), 'cards_v1')"
    )->execute([$gameId]);
    $turnId = (int)$pdo->lastInsertId();
    $pdo->prepare('UPDATE slice_games SET current_turn_id = ? WHERE id = ?')->execute([$turnId, $gameId]);

    $pdo->commit();
} catch (Throwable $e) {
    $pdo->rollBack();
    $cleanup();
    fwrite(STDERR, '准备失败：' . $e->getMessage() . PHP_EOL);
    exit(1);
}

$settler = new CardSettlementService($pdo);
$estateService = new EstateService($pdo);
$meritService = new MeritService($pdo);
$seasonService = new SeasonService($pdo);

$insertComp = $pdo->prepare(
    'INSERT INTO slice_compositions (game_id, player_id, week_no, types_json, changed_once)
     VALUES (?, ?, ?, ?, 0)
     ON DUPLICATE KEY UPDATE types_json = VALUES(types_json)'
);
$insertOrders = $pdo->prepare(
    'INSERT INTO slice_order_slots
        (game_id, turn_id, player_id, slot, card_code, target_node_code, lane, row_pos, status, last_request_key)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, "active", ?)'
);

$teamCards = CardSettlementService::TEAM_CARDS;
$roomCodes = array_keys(EstateService::ROOMS);
$types = ['cav', 'shield', 'arc', 'spear'];

$settledTurns = 0;
$totalBattles = 0;
$totalCaptures = 0;
$capturesByWeek = [1 => 0, 2 => 0, 3 => 0, 4 => 0];
$battlesByWeek = [1 => 0, 2 => 0, 3 => 0, 4 => 0];
$governorCounts = [];
$governorMissing = [];
$upgradeCount = 0;
$upgradeByRoom = ['study' => 0, 'drill' => 0, 'tower' => 0];
$upgradeErrors = [];
$captureLog = [];
$capturesByNode = [];
$changanLog = [];
$scoreCounts = [];
$realGarrisonBattles = 0;
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

        // 每周第一次：全体随机换编成（真实规则：每周只能改编，一次改到位）
        if (($round - 1) % 7 === 0) {
            foreach ($players as $p) {
                $deck = $types;
                shuffle($deck);
                $insertComp->execute([$gameId, $p['id'], $week, json_encode(array_slice($deck, 0, 3))]);
            }
        }

        // 每阵营本周两个主攻方向：80% 从边境（与己方城相邻）里挑，否则全图
        $focus = [];
        foreach ($factions as $f) {
            $fid = (int)$f['id'];
            $owned = [];
            $frontier = [];
            $candidates = [];
            foreach ($nodes as $code) {
                $owner = $nodeOwner[$code] ?? null;
                if ($owner === $fid) {
                    $owned[$code] = true;
                    continue;
                }
                $candidates[] = $code;
            }
            foreach ($owned as $code => $_) {
                foreach ($adj[$code] ?? [] as $nb) {
                    if (($nodeOwner[$nb] ?? null) !== $fid) {
                        $frontier[$nb] = true;
                    }
                }
            }
            $frontier = array_keys($frontier);
            $pool = ($frontier !== [] && mt_rand(1, 100) <= 80) ? $frontier : $candidates;
            if ($pool === []) {
                $pool = $nodes;
            }
            $first = $pool[array_rand($pool)];
            $secondPool = array_values(array_diff($pool, [$first]));
            if ($secondPool === []) {
                $secondPool = array_values(array_diff($candidates, [$first]));
            }
            $second = $secondPool === [] ? $first : $secondPool[array_rand($secondPool)];
            $focus[$fid] = [$first, $second, $candidates, array_keys($owned)];
        }

        $pdo->beginTransaction();
        foreach ($players as $i => $p) {
            $fid = $p['faction_id'];
            [$f0, $f1, $candidates, $owned] = $focus[$fid];

            for ($slot = 0; $slot < 3; $slot++) {
                if ($slot === 0) {
                    $target = $f0;
                } elseif ($slot === 1) {
                    $target = $f1;
                } else {
                    // 第三令：18% 回防自家城，42% 跟主攻，其余随机撒
                    $roll = mt_rand(1, 100);
                    if ($roll <= 18 && $owned !== []) {
                        $target = $owned[array_rand($owned)];
                    } elseif ($roll <= 60) {
                        $target = mt_rand(0, 1) === 0 ? $f0 : $f1;
                    } elseif ($candidates !== []) {
                        $target = $candidates[array_rand($candidates)];
                    } else {
                        $target = $nodes[array_rand($nodes)];
                    }
                }

                $cardRoll = mt_rand(1, 100);
                if ($cardRoll <= 82) {
                    $card = $teamCards[array_rand($teamCards)];
                } elseif ($cardRoll <= 91) {
                    $card = 'scout';
                } else {
                    $card = 'fire_attack';
                }

                $insertOrders->execute([
                    $gameId,
                    $turnId,
                    $p['id'],
                    $slot,
                    $card,
                    $target,
                    mt_rand(1, 3),
                    mt_rand(1, 100) <= 25 ? 'back' : 'front',
                    'sim_' . $round . '_' . $i . '_' . $slot,
                ]);
            }
        }
        $pdo->commit();

        $result = $settler->settle($gameId, $turnId);
        if (!empty($result['already_settled'])) {
            throw new RuntimeException('turn ' . $round . ' already settled');
        }
        $settledTurns++;

        foreach ($result['battles'] as $b) {
            if (empty($b['battle_id'])) {
                continue;
            }
            $totalBattles++;
            $battlesByWeek[$week]++;
            $score = (int)($b['score'] ?? 0);
            $scoreCounts[$score] = ($scoreCounts[$score] ?? 0) + 1;
            if (!empty($b['real_garrison'])) {
                $realGarrisonBattles++;
            }
            $nodeCode = (string)$b['node_code'];
            $nodeOwner[$nodeCode] = $b['owner_after'] === null ? null : (int)$b['owner_after'];
            if (!empty($b['captured'])) {
                $totalCaptures++;
                $capturesByWeek[$week]++;
                $capturesByNode[$nodeCode] = ($capturesByNode[$nodeCode] ?? 0) + 1;
                $entry = [
                    'turn' => $round,
                    'node' => $nodeCode,
                    'from' => $b['owner_before'] === null ? '-' : ($factionCodes[(int)$b['owner_before']] ?? '?'),
                    'to' => $b['owner_after'] === null ? '-' : ($factionCodes[(int)$b['owner_after']] ?? '?'),
                    'score' => (int)($b['score'] ?? 0),
                ];
                if ($nodeCode === 'changan') {
                    $changanLog[] = $entry;
                }
                if (count($captureLog) < 20) {
                    $captureLog[] = $entry;
                }
            }
        }

        // 每 7 回合：算这一周的太守
        if ($round % 7 === 0) {
            $governorCounts[$week] = $estateService->refreshGovernors($gameId, $week);
            $ownedNow = $pdo->query(
                "SELECT node_code FROM slice_nodes WHERE game_id = {$gameId} AND owner_faction_id IS NOT NULL"
            )->fetchAll(PDO::FETCH_COLUMN);
            $govMap = $estateService->governorsForWeek($gameId, $week);
            $governorMissing[$week] = array_values(array_diff($ownedNow, array_keys($govMap)));
        }

        // 每回合：本周军功前 10 名尝试升级小院，房间按回合轮换
        $top = $meritService->weekTop($gameId, $week, 10);
        foreach ($top as $rank => $row) {
            $room = $roomCodes[($round + $rank) % 3];
            try {
                $estateService->upgrade($gameId, (int)$row['player_id'], $room);
                $upgradeCount++;
                $upgradeByRoom[$room]++;
            } catch (ApiException $e) {
                $code = (string)$e->errorCode;
                $upgradeErrors[$code] = ($upgradeErrors[$code] ?? 0) + 1;
            }
        }

        if ($round % 7 === 0 || $round === 1) {
            printf(
                "turn %2d (week %d): battles=%d captures=%d total_captures=%d upgrades=%d\n",
                $round,
                $week,
                $result['battles'] === [] ? 0 : count(array_filter($result['battles'], fn($b) => !empty($b['battle_id']))),
                $capturesByWeek[$week],
                $totalCaptures,
                $upgradeCount
            );
        }
    }

    $seasonMs = (microtime(true) - $seasonStarted) * 1000;

    // === 结果汇总 ===
    $season = $seasonService->summary($gameId);
    $meritTop = $meritService->top($gameId, 10);
    $meritRows = (int)$pdo->query("SELECT COUNT(*) FROM slice_merit_events WHERE game_id = {$gameId}")->fetchColumn();
    $meritPlayers = (int)$pdo->query("SELECT COUNT(DISTINCT player_id) FROM slice_merit_events WHERE game_id = {$gameId}")->fetchColumn();
    $meritTotal = (int)$pdo->query("SELECT COALESCE(SUM(amount),0) FROM slice_merit_events WHERE game_id = {$gameId}")->fetchColumn();
    $playerTotals = array_map('intval', $pdo->query(
        "SELECT COALESCE(SUM(m.amount), 0) AS total
         FROM slice_players p LEFT JOIN slice_merit_events m
             ON m.player_id = p.id AND m.game_id = p.game_id
         WHERE p.game_id = {$gameId} AND p.role = 'player'
         GROUP BY p.id ORDER BY total"
    )->fetchAll(PDO::FETCH_COLUMN));
    $meritStats = ['min' => 0, 'p25' => 0, 'median' => 0, 'p75' => 0, 'max' => 0];
    if ($playerTotals !== []) {
        $pick = static fn(int $q): int => $playerTotals[(int)floor(($q / 100) * (count($playerTotals) - 1))];
        $meritStats = [
            'min' => $playerTotals[0],
            'p25' => $pick(25),
            'median' => $pick(50),
            'p75' => $pick(75),
            'max' => $playerTotals[count($playerTotals) - 1],
        ];
    }
    $canMaxEstate = count(array_filter($playerTotals, static fn(int $t): bool => $t >= 330));
    $canFirstUpgrade = count(array_filter($playerTotals, static fn(int $t): bool => $t >= 30));
    $meritByKind = $pdo->query(
        "SELECT kind, SUM(amount) total, COUNT(*) n FROM slice_merit_events
         WHERE game_id = {$gameId} GROUP BY kind ORDER BY total DESC"
    )->fetchAll();

    $governorRows = (int)$pdo->query("SELECT COUNT(*) FROM slice_city_governors WHERE game_id = {$gameId}")->fetchColumn();
    $governorPlayers = (int)$pdo->query("SELECT COUNT(DISTINCT player_id) FROM slice_city_governors WHERE game_id = {$gameId}")->fetchColumn();
    $governorByWeek = $pdo->query(
        "SELECT week_no, COUNT(*) c, COUNT(DISTINCT player_id) players
         FROM slice_city_governors WHERE game_id = {$gameId} GROUP BY week_no ORDER BY week_no"
    )->fetchAll();

    $estates = $pdo->query(
        "SELECT study_level, drill_level, tower_level, spent_merit FROM slice_estates WHERE game_id = {$gameId}"
    )->fetchAll();
    $estateRows = count($estates);
    $estateSpent = 0;
    $levelDist = ['study' => [1 => 0, 2 => 0, 3 => 0], 'drill' => [1 => 0, 2 => 0, 3 => 0], 'tower' => [1 => 0, 2 => 0, 3 => 0]];
    $maxedRooms = 0;
    foreach ($estates as $row) {
        $estateSpent += (int)$row['spent_merit'];
        foreach (['study', 'drill', 'tower'] as $room) {
            $level = (int)$row[$room . '_level'];
            $levelDist[$room][$level] = ($levelDist[$room][$level] ?? 0) + 1;
            if ($level >= EstateService::MAX_LEVEL) {
                $maxedRooms++;
            }
        }
    }

    $meritByFaction = $pdo->query(
        "SELECT f.code, COUNT(DISTINCT p.id) players, COALESCE(SUM(m.amount), 0) total
         FROM slice_factions f
         LEFT JOIN slice_players p ON p.faction_id = f.id AND p.role = 'player'
         LEFT JOIN slice_merit_events m ON m.player_id = p.id AND m.game_id = f.game_id
         WHERE f.game_id = {$gameId}
         GROUP BY f.code, f.sort_order ORDER BY total DESC"
    )->fetchAll();
    $estateByFaction = $pdo->query(
        "SELECT f.code, COUNT(e.id) estates, COALESCE(SUM(e.spent_merit), 0) spent
         FROM slice_factions f
         LEFT JOIN slice_players p ON p.faction_id = f.id AND p.role = 'player'
         LEFT JOIN slice_estates e ON e.player_id = p.id AND e.game_id = f.game_id
         WHERE f.game_id = {$gameId}
         GROUP BY f.code, f.sort_order ORDER BY f.sort_order"
    )->fetchAll();

    $finalNodes = $pdo->query(
        "SELECT n.node_code, n.name, n.node_type, n.morale, f.code AS owner
         FROM slice_nodes n LEFT JOIN slice_factions f ON f.id = n.owner_faction_id
         WHERE n.game_id = {$gameId} ORDER BY n.sort_order"
    )->fetchAll();

    $scoreChanged = (int)$pdo->query(
        "SELECT COUNT(*) FROM students s JOIN slice_players p ON p.student_id = s.id
         WHERE p.game_id = {$gameId} AND s.score <> 100"
    )->fetchColumn();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    $cleanup();
    fwrite(STDERR, '模拟失败：' . $e->getMessage() . PHP_EOL);
    fwrite(STDERR, $e->getTraceAsString() . PHP_EOL);
    exit(1);
}

// === 输出 ===
echo PHP_EOL . '== 赛季结果 ==' . PHP_EOL;
printf("turns=%d battles=%d captures=%d 用时=%.0fms\n", $settledTurns, $totalBattles, $totalCaptures, $seasonMs);
echo 'week battles: ' . json_encode($battlesByWeek) . PHP_EOL;
echo 'week captures: ' . json_encode($capturesByWeek) . PHP_EOL;
echo 'scores: ' . json_encode($scoreCounts) . ' real_garrison_battles=' . $realGarrisonBattles . '/' . $totalBattles . PHP_EOL;

echo PHP_EOL . '== 阵营 ==' . PHP_EOL;
foreach ($season['factions'] as $f) {
    printf("  %-3s %-4s cities=%d morale=%d\n", $f['code'], $f['name'], $f['cities'], $f['morale']);
}
echo 'neutral=' . $season['neutral_cities'] . PHP_EOL;
echo 'changan=' . json_encode($season['changan'], JSON_UNESCAPED_UNICODE) . PHP_EOL;
echo 'winner=' . json_encode($season['winner'], JSON_UNESCAPED_UNICODE) . PHP_EOL;
foreach ($finalNodes as $n) {
    printf("  %-10s %-6s %-8s owner=%-4s morale=%d\n", $n['node_code'], $n['name'], $n['node_type'], $n['owner'] ?? '-', (int)$n['morale']);
}

echo PHP_EOL . '== 军功 ==' . PHP_EOL;
printf("rows=%d players=%d total=%d\n", $meritRows, $meritPlayers, $meritTotal);
foreach ($meritByKind as $row) {
    printf("  %-14s total=%-6d n=%d\n", $row['kind'], (int)$row['total'], (int)$row['n']);
}
echo 'by faction: ' . json_encode($meritByFaction, JSON_UNESCAPED_UNICODE) . PHP_EOL;
echo 'per-player: ' . json_encode($meritStats) . ' can_first_upgrade(>=30)=' . $canFirstUpgrade . ' can_max_3rooms(>=330)=' . $canMaxEstate . PHP_EOL;
echo 'top10:' . PHP_EOL;
foreach ($meritTop as $i => $row) {
    printf("  #%d %-8s %-3s total=%d\n", $i + 1, $row['nickname'], $row['faction'] ?? '-', $row['total']);
}

echo PHP_EOL . '== 太守 ==' . PHP_EOL;
printf("rows=%d players=%d\n", $governorRows, $governorPlayers);
echo 'by week: ' . json_encode($governorByWeek) . PHP_EOL;
echo 'missing cities: ' . json_encode($governorMissing) . PHP_EOL;

echo PHP_EOL . '== 小院 ==' . PHP_EOL;
printf("estates=%d upgrades=%d spent=%d maxed_rooms=%d\n", $estateRows, $upgradeCount, $estateSpent, $maxedRooms);
echo 'by room: ' . json_encode($upgradeByRoom) . PHP_EOL;
echo 'by faction: ' . json_encode($estateByFaction, JSON_UNESCAPED_UNICODE) . PHP_EOL;
echo 'errors: ' . json_encode($upgradeErrors) . PHP_EOL;
foreach ($levelDist as $room => $dist) {
    echo "  {$room}: " . json_encode($dist) . PHP_EOL;
}

echo PHP_EOL . '== 易主样本（前 20）==' . PHP_EOL;
foreach ($captureLog as $c) {
    printf("  turn %2d %-9s %-4s -> %-4s score=%d\n", $c['turn'], $c['node'], $c['from'], $c['to'], $c['score']);
}
echo 'by node: ' . json_encode($capturesByNode, JSON_UNESCAPED_UNICODE) . PHP_EOL;
echo 'changan flips: ' . json_encode($changanLog, JSON_UNESCAPED_UNICODE) . PHP_EOL;

// 断言
echo PHP_EOL;
check('28 回合全部结算', $settledTurns === 28, 'settled=' . $settledTurns);
check('至少 20 次易主', $totalCaptures >= 20, 'captures=' . $totalCaptures);
check('军功行 > 0', $meritRows > 0, 'rows=' . $meritRows);
check('太守行 > 0', $governorRows > 0, 'rows=' . $governorRows);
check('至少 10 次小院升级', $upgradeCount >= 10, 'upgrades=' . $upgradeCount);
check('产生战斗', $totalBattles > 0, 'battles=' . $totalBattles);
check('students.score 未被修改', $scoreChanged === 0, 'changed=' . $scoreChanged);

$cleanup();

echo PHP_EOL;
if ($failed > 0) {
    echo "SEASON_SIM FAIL ({$failed})" . PHP_EOL;
    exit(1);
}
echo 'SEASON_SIM PASS' . PHP_EOL;
