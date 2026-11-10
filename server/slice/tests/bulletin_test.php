<?php
declare(strict_types=1);

require_once __DIR__ . '/../bootstrap.php';
require_once __DIR__ . '/../src/SqlRunner.php';
require_once __DIR__ . '/../src/BulletinService.php';
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
$seed = dirname(__DIR__) . '/seed.sql';

/**
 * 3 名 bi 玩家对 N1 各出一令，可选地写入邸报选择。
 *
 * @param array<int,?string> $choices ??????????
 * @return array{attacker:array,result:array,player_ids:array<int,int>}
 */
function runWithBulletins(PDO $pdo, string $seed, array $choices): array
{
    $pdo->exec("DELETE FROM slice_games WHERE code = 'SLICE_A'");
    SqlRunner::runFile($pdo, $seed);
    $gameId = (int)$pdo->query("SELECT id FROM slice_games WHERE code = 'SLICE_A'")->fetchColumn();
    $turnId = (int)$pdo->query("SELECT id FROM slice_turns WHERE game_id = {$gameId} ORDER BY turn_no LIMIT 1")->fetchColumn();
    $players = array_map('intval', $pdo->query(
        "SELECT p.id FROM slice_players p JOIN slice_factions f ON f.id = p.faction_id
         WHERE p.game_id = {$gameId} AND p.role = 'player' AND f.code = 'bi' ORDER BY p.id LIMIT 3"
    )->fetchAll(PDO::FETCH_COLUMN));

    $insert = $pdo->prepare(
        'INSERT INTO slice_order_slots
            (game_id, turn_id, player_id, slot, card_code, target_node_code, lane, row_pos, status, last_request_key)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, "active", ?)'
    );
    foreach ($players as $i => $pid) {
        $insert->execute([$gameId, $turnId, $pid, 0, 'night_raid', 'N1', $i + 1, 'front', 'bul_' . $i . '_' . bin2hex(random_bytes(3))]);
    }

    $bulletinInsert = $pdo->prepare(
        'INSERT INTO slice_bulletins (game_id, turn_id, player_id, options_json, choice)
         VALUES (?, ?, ?, ?, ?)'
    );
    foreach ($players as $i => $pid) {
        $choice = $choices[$i] ?? null;
        if ($choice === null) {
            continue;
        }
        $bulletinInsert->execute([$gameId, $turnId, $pid, json_encode(['x']), $choice]);
    }

    $result = (new CardSettlementService($pdo))->settle($gameId, $turnId);
    $battle = null;
    foreach ($result['battles'] as $entry) {
        if (($entry['node_code'] ?? '') === 'N1' && !empty($entry['battle_id'])) {
            $battle = $entry;
            break;
        }
    }
    $attacker = [];
    if ($battle !== null) {
        $stmt = $pdo->prepare('SELECT attacker_json FROM slice_battles WHERE id = ?');
        $stmt->execute([(int)$battle['battle_id']]);
        $attacker = json_decode((string)$stmt->fetchColumn(), true) ?? [];
    }
    return ['attacker' => $attacker, 'result' => $battle ?? [], 'player_ids' => $players];
}

try {
    // --- 选项生成 ---
    $gameId = (int)$pdo->query("SELECT id FROM slice_games WHERE code = 'SLICE_A'")->fetchColumn();
    $turnId = (int)$pdo->query("SELECT id FROM slice_turns WHERE game_id = {$gameId} ORDER BY turn_no LIMIT 1")->fetchColumn();
    $pid = (int)$pdo->query("SELECT id FROM slice_players WHERE game_id = {$gameId} ORDER BY id LIMIT 1")->fetchColumn();

    $service = new BulletinService($pdo);
    $summary = $service->summary($gameId, $turnId, $pid);
    check('邸报返回 2 个选项', count($summary['options']) === 2);
    check('两个选项不重复', $summary['options'][0]['code'] !== $summary['options'][1]['code']);
    check('初始未选择', $summary['choice'] === null);

    $again = $service->summary($gameId, $turnId, $pid);
    check('重复读取选项稳定', array_column($again['options'], 'code') === array_column($summary['options'], 'code'));

    $picker = new BulletinService($pdo);
    $bad = false;
    try {
        $picker->choose($gameId, $turnId, $pid, 'not_in_list');
    } catch (ApiException $e) {
        $bad = true;
    }
    check('非法选项被拒绝', $bad);

    $picked = $service->choose($gameId, $turnId, $pid, $summary['options'][0]['code']);
    check('选择已保存', $picked['choice'] === $summary['options'][0]['code']);

    $changed = $service->choose($gameId, $turnId, $pid, $summary['options'][1]['code']);
    check('结算前可改选', $changed['choice'] === $summary['options'][1]['code']);

    // --- 粮草：兵力 +5% ---
    $base = runWithBulletins($pdo, $seed, []);
    $baseTroops = array_sum(array_column($base['attacker']['teams'] ?? [], 'troops'));
    check('无邸报：siege_mult=1', abs((float)($base['attacker']['siege_mult'] ?? 0) - 1.0) < 0.001);
    check('无邸报：队伍无 bulletin 标记', ($base['attacker']['teams'][0]['bulletin'] ?? null) === null);

    $grain = runWithBulletins($pdo, $seed, ['grain', 'grain', 'grain']);
    $grainTroops = array_sum(array_column($grain['attacker']['teams'] ?? [], 'troops'));
    check('粮草：兵力 +5%', abs($grainTroops - $baseTroops * 1.05) < 1.0, sprintf('base=%.1f grain=%.1f', $baseTroops, $grainTroops));
    check('粮草：队伍带 bulletin=grain', ($grain['attacker']['teams'][0]['bulletin'] ?? null) === 'grain');

    // --- 器械：3 人叠到 1.75 倍攻城 ---
    $ram = runWithBulletins($pdo, $seed, ['ram', 'ram', 'ram']);
    check('器械：siege_mult=1.75', abs((float)($ram['attacker']['siege_mult'] ?? 0) - 1.75) < 0.001, 'mult=' . ($ram['attacker']['siege_mult'] ?? 'null'));

    // --- 斥候：本回合敌城全可见 ---
    $login = slice_bootstrap()[2]->loginStudent('青竹一', 'slice2026');
    $player = slice_bootstrap()[2]->authenticate($login['token']);
    $pdo->prepare('DELETE FROM slice_bulletins WHERE turn_id = ? AND player_id = ?')
        ->execute([(int)$player['game_current_turn_id'], (int)$player['id']]);
    (new BulletinService($pdo))->choose(
        (int)$player['game_id'],
        (int)$player['game_current_turn_id'],
        (int)$player['id'],
        'scout'
    );
    $state = slice_bootstrap()[2]->getState($player, (int)$player['game_current_turn_id']);
    $gameId = (int)$player['game_id'];
    $pid = (int)$player['id'];
    $enemyNodes = $pdo->query(
        "SELECT COUNT(*) FROM slice_nodes WHERE game_id = {$gameId}
         AND owner_faction_id IS NOT NULL
         AND owner_faction_id <> (SELECT faction_id FROM slice_players WHERE id = {$pid})"
    )->fetchColumn();
    $covered = 0;
    foreach ($state['scouted_nodes'] as $code) {
        $stmt = $pdo->prepare('SELECT COUNT(*) FROM slice_nodes WHERE game_id = ? AND node_code = ? AND owner_faction_id IS NOT NULL AND owner_faction_id <> (SELECT faction_id FROM slice_players WHERE id = ?)');
        $stmt->execute([$gameId, $code, $pid]);
        $covered += (int)$stmt->fetchColumn();
    }
    check('斥候：敌城全部进入 scouted_nodes', (int)$enemyNodes > 0 && $covered === (int)$enemyNodes, "enemy={$enemyNodes} covered={$covered}");
    check('斥候：state 带 bulletin', ($state['bulletin']['choice'] ?? null) === 'scout');
} finally {
    $pdo->exec("DELETE FROM slice_games WHERE code = 'SLICE_A'");
    SqlRunner::runFile($pdo, $seed);
}

echo PHP_EOL;
if ($failed > 0) {
    echo "BULLETIN FAIL ({$failed})\n";
    exit(1);
}
echo "BULLETIN PASS\n";
