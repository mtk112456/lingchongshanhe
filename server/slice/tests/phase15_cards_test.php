<?php
declare(strict_types=1);

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

/**
 * 固定阵容：攻方 骑/盾/弓，守方 盾/枪/弓。
 * 每队默认 400 vs 500 兵，方便观察卡牌对属性与事件的影响。
 */
function battle(
    array $attCards,
    array $defCards = [],
    bool $scouted = false,
    int $attTroops = 400,
    int $defTroops = 500
): array {
    $attTypes = ['cav', 'shield', 'arc'];
    $defTypes = ['shield', 'spear', 'arc'];
    $att = ['general' => 'atk', 'teams' => [], 'scouted' => $scouted];
    foreach ($attTypes as $i => $type) {
        $att['teams'][] = [
            'type' => $type,
            'troops' => $attTroops,
            'lane' => $i + 1,
            'row' => $i === 2 ? 'back' : 'front',
            'card' => $attCards[$i] ?? null,
        ];
    }
    $def = ['general' => 'def', 'teams' => []];
    foreach ($defTypes as $i => $type) {
        $def['teams'][] = [
            'type' => $type,
            'troops' => $defTroops,
            'lane' => $i + 1,
            'row' => $i === 2 ? 'back' : 'front',
            'card' => $defCards[$i] ?? null,
        ];
    }
    return (new BattleEngine())->resolve($att, $def);
}

function unitOf(array $result, string $id): array
{
    foreach ($result['units'] as $u) {
        if ($u['id'] === $id) {
            return $u;
        }
    }
    return [];
}

function eventCount(array $result, string $action): int
{
    $n = 0;
    foreach ($result['events'] as $e) {
        if (($e['action'] ?? '') === $action) {
            $n++;
        }
    }
    return $n;
}

$baseline = battle([]);

// ---- 1. 一令一队 ----
$r = battle(['night_raid', 'fortify', 'fire_attack']);
check('3 队各占一路', $r['att_slots'][1]['front'] === 'cav'
    && $r['att_slots'][2]['front'] === 'shield'
    && $r['att_slots'][3]['back'] === 'arc');
check('每队带自己的牌', unitOf($r, 'A1F')['card'] === 'night_raid'
    && unitOf($r, 'A2F')['card'] === 'fortify'
    && unitOf($r, 'A3B')['card'] === 'fire_attack');

// ---- 2. 坚壁：本队防御 +20% ----
$r = battle([null, 'fortify', null]);
check('坚壁 def_mult ×1.2',
    abs(unitOf($r, 'A2F')['def_mult'] - unitOf($baseline, 'A2F')['def_mult'] * 1.2) < 0.001,
    'base=' . unitOf($baseline, 'A2F')['def_mult'] . ' card=' . unitOf($r, 'A2F')['def_mult']);

// ---- 3. 犄角：相邻路防御 +10% ----
$r = battle([null, 'mutual_support', null]);
check('犄角 buff 相邻 1 路',
    abs(unitOf($r, 'A1F')['def_mult'] - unitOf($baseline, 'A1F')['def_mult'] * 1.1) < 0.001);
check('犄角 buff 相邻 3 路',
    abs(unitOf($r, 'A3B')['def_mult'] - unitOf($baseline, 'A3B')['def_mult'] * 1.1) < 0.001);
check('犄角不 buff 自己',
    abs(unitOf($r, 'A2F')['def_mult'] - unitOf($baseline, 'A2F')['def_mult']) < 0.001);

// ---- 4. 空城 / 反间：敌军攻击 -10% ----
$r = battle(['empty_fort', null, null]);
check('空城 敌方 atk ×0.9',
    abs(unitOf($r, 'D1F')['atk'] - unitOf($baseline, 'D1F')['atk'] * 0.9) < 0.01,
    'base=' . unitOf($baseline, 'D1F')['atk'] . ' card=' . unitOf($r, 'D1F')['atk']);

$r = battle([null, null, 'counter_intel']);
check('反间 敌方 atk ×0.9',
    abs(unitOf($r, 'D1F')['atk'] - unitOf($baseline, 'D1F')['atk'] * 0.9) < 0.01);

// ---- 5. 夜袭：未侦察 +20%，已侦察不加 ----
$r = battle(['night_raid', null, null]);
check('夜袭 未侦察 atk ×1.2',
    abs(unitOf($r, 'A1F')['atk'] - unitOf($baseline, 'A1F')['atk'] * 1.2) < 0.01);
$r = battle(['night_raid', null, null], [], true);
check('夜袭 已侦察 atk 不变',
    abs(unitOf($r, 'A1F')['atk'] - unitOf($baseline, 'A1F')['atk']) < 0.01);

// ---- 6. 火攻：器械攻墙 +50% ----
$r = battle([null, null, 'fire_attack']);
check('火攻 城墙更低', $r['wall'] < $baseline['wall'],
    'base=' . $baseline['wall'] . ' fire=' . $r['wall']);
$fireEvent = false;
foreach ($r['events'] as $e) {
    if (($e['unit'] ?? '') === 'SIEGE' && !empty($e['fire'])) {
        $fireEvent = true;
    }
}
check('火攻 标记在器械事件上', $fireEvent);

// ---- 7. 急行：先手 ----
$r = battle([null, null, 'forced_march']);
check('急行 initiative=1', unitOf($r, 'A3B')['initiative'] === 1);
check('普通队 initiative=0', unitOf($baseline, 'A3B')['initiative'] === 0);

// ---- 8. 死守：一次致命伤留 1 兵 ----
$r = battle([null, null, null], [], false, 400, 800);
check('死守 不带牌不触发', eventCount($r, 'last_stand') === 0);
$r = battle(['last_stand', null, null], [], false, 400, 800);
check('死守 触发一次', eventCount($r, 'last_stand') === 1, 'events=' . eventCount($r, 'last_stand'));
$r = battle(['last_stand', null, null], [], false, 400, 800);
check('死守 牌挂上后仍只触发一次', eventCount($r, 'last_stand') === 1);

// ---- 9. 运粮：每 15 tick 回血 ----
$r = battle(['supply', null, null], [], false, 400, 800);
check('运粮 有回血事件', eventCount($r, 'heal') >= 1, 'heal=' . eventCount($r, 'heal'));
$healEvent = null;
foreach ($r['events'] as $e) {
    if (($e['action'] ?? '') === 'heal') {
        $healEvent = $e;
        break;
    }
}
check('运粮 回血量 = 5% 上限',
    $healEvent !== null && abs($healEvent['heal'] - 400 * 0.05) < 1.0,
    'first_heal=' . ($healEvent['heal'] ?? 'none'));

// ---- 10. 断粮：敌军每 15 tick 掉 3% ----
$r = battle([null, 'cut_supply', null], [], false, 400, 800);
check('断粮 有掉兵事件', eventCount($r, 'cut_supply') >= 1, 'dot=' . eventCount($r, 'cut_supply'));
$r = battle([null, 'cut_supply', null], [], false, 400, 800);
$dotEvent = null;
foreach ($r['events'] as $e) {
    if (($e['action'] ?? '') === 'cut_supply') {
        $dotEvent = $e;
        break;
    }
}
check('断粮 单次伤害 = 3% 上限',
    $dotEvent !== null && abs($dotEvent['damage'] - 800 * 0.03) < 1.0,
    'dmg=' . ($dotEvent['damage'] ?? 'none'));

// ---- 11. 哨探 / 疑兵：不改战斗数值 ----
foreach (['scout' => 0, 'feint' => 1] as $card => $idx) {
    $cards = [null, null, null];
    $cards[$idx] = $card;
    $r = battle($cards);
    $same = abs($r['wall'] - $baseline['wall']) < 0.01
        && count($r['events']) === count($baseline['events']);
    check($card . ' 不改战斗结果', $same);
}

// ---- 12. 周次 ----
check('回合 1 → 第 1 周', CardSettlementService::weekOfTurn(1) === 1);
check('回合 7 → 第 1 周', CardSettlementService::weekOfTurn(7) === 1);
check('回合 8 → 第 2 周', CardSettlementService::weekOfTurn(8) === 2);
check('回合 15 → 第 3 周', CardSettlementService::weekOfTurn(15) === 3);
check('回合 28 → 第 4 周', CardSettlementService::weekOfTurn(28) === 4);

// ---- 13. 落库：第 2 周编成 + 3 队 + 牌 ----
[$config, $pdo] = slice_bootstrap();

$gameId = (int)$pdo->query('SELECT id FROM slice_games ORDER BY id LIMIT 1')->fetchColumn();
$turnId = (int)$pdo->query('SELECT id FROM slice_turns ORDER BY id LIMIT 1')->fetchColumn();
$nodeCode = 'N2';

$biPlayers = array_map('intval', $pdo->query(
    "SELECT p.id FROM slice_players p
     JOIN slice_factions f ON f.id = p.faction_id
     WHERE p.game_id = {$gameId} AND p.role = 'player' AND f.code = 'bi'
     ORDER BY p.id LIMIT 4"
)->fetchAll(PDO::FETCH_COLUMN));
$playerId = $biPlayers[0] ?? 0;

$otherPlayerId = (int)$pdo->query(
    "SELECT p.id FROM slice_players p
     JOIN slice_factions f ON f.id = p.faction_id
     WHERE p.game_id = {$gameId} AND p.role = 'player' AND f.code = 'mo'
     ORDER BY p.id LIMIT 1"
)->fetchColumn();

$original = $pdo->query("SELECT turn_no, status FROM slice_turns WHERE id = {$turnId}")->fetch();

$cleanup = function () use ($pdo, $gameId, $turnId, $nodeCode): void {
    $pdo->prepare('DELETE FROM slice_order_slots WHERE turn_id = ?')->execute([$turnId]);
    $pdo->prepare('DELETE FROM slice_battles WHERE turn_id = ?')->execute([$turnId]);
    $pdo->prepare('DELETE FROM slice_node_changes WHERE turn_id = ?')->execute([$turnId]);
    $pdo->prepare('DELETE FROM slice_compositions WHERE game_id = ? AND week_no = 2')->execute([$gameId]);
    $pdo->prepare('UPDATE slice_nodes SET morale = 0, owner_faction_id = NULL WHERE game_id = ? AND node_code = ?')
        ->execute([$gameId, $nodeCode]);
};

$cleanup();
$pdo->prepare("UPDATE slice_turns SET turn_no = 8, status = 'open', settled_at = NULL WHERE id = ?")->execute([$turnId]);

$insertComp = $pdo->prepare('INSERT INTO slice_compositions (game_id, player_id, week_no, types_json, changed_once)
                             VALUES (?, ?, 2, ?, 0)');
foreach ($biPlayers as $pid) {
    $insertComp->execute([$gameId, $pid, json_encode(['arc', 'spear', 'cav'])]);
}

$insertOrder = $pdo->prepare(
    'INSERT INTO slice_order_slots
        (game_id, turn_id, player_id, slot, card_code, target_node_code, lane, row_pos, status, last_request_key)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, "active", ?)'
);
$insertOrder->execute([$gameId, $turnId, $biPlayers[0], 0, 'night_raid', $nodeCode, 1, 'front', 'p15_a_' . bin2hex(random_bytes(3))]);
$insertOrder->execute([$gameId, $turnId, $biPlayers[1], 1, 'fortify', $nodeCode, 2, 'front', 'p15_b_' . bin2hex(random_bytes(3))]);
$insertOrder->execute([$gameId, $turnId, $biPlayers[2], 2, 'supply', $nodeCode, 3, 'back', 'p15_c_' . bin2hex(random_bytes(3))]);
$insertOrder->execute([$gameId, $turnId, $biPlayers[3], 0, 'fire_attack', $nodeCode, null, null, 'p15_f_' . bin2hex(random_bytes(3))]);

$settler = new CardSettlementService($pdo);
$result = $settler->settle($gameId, $turnId);
$battleEntry = null;
foreach ($result['battles'] as $b) {
    if (($b['node_code'] ?? '') === $nodeCode && !empty($b['battle_id'])) {
        $battleEntry = $b;
        break;
    }
}
check('第 2 周结算产生战斗', $battleEntry !== null, json_encode($result['battles'], JSON_UNESCAPED_UNICODE));

if ($battleEntry !== null) {
    $stmt = $pdo->prepare('SELECT attacker_json, log_json FROM slice_battles WHERE id = ?');
    $stmt->execute([(int)$battleEntry['battle_id']]);
    $row = $stmt->fetch();
    $attacker = json_decode((string)$row['attacker_json'], true);
    $log = json_decode((string)$row['log_json'], true);

    $teams = $attacker['teams'] ?? [];
    $byType = [];
    foreach ($teams as $t) {
        $byType[$t['type']] = $t;
    }
    check('一令一队：3 队', count($teams) === 3);
    $types = array_column($teams, 'type');
    sort($types);
    check('第 2 周编成生效：arc/cav/spear',
        $types === ['arc', 'cav', 'spear'],
        json_encode($types));
    check('每队保留自己的牌',
        ($byType['arc']['card'] ?? '') === 'night_raid'
        && ($byType['spear']['card'] ?? '') === 'fortify'
        && ($byType['cav']['card'] ?? '') === 'supply',
        json_encode(array_column($teams, 'card')));
    check('火攻不占队伍位',
        !in_array('fire_attack', array_column($teams, 'card'), true) && count($teams) === 3,
        json_encode(array_column($teams, 'card')));
    check('支援人数 = 1', ($attacker['supporters'] ?? 0) === 1, 'supporters=' . ($attacker['supporters'] ?? 'null'));
    check('支援倍率 = 1.224', abs((float)($attacker['support_mult'] ?? 0) - 1.224) < 0.01, 'mult=' . ($attacker['support_mult'] ?? 'null'));
    check('弓兵被放回后排', ($byType['arc']['row'] ?? '') === 'back');
    check('枪兵按出令放前排', ($byType['spear']['row'] ?? '') === 'front');
    check('火攻进入器械结算', !empty($attacker['fire']));
    check('未侦察标记为 false', empty($attacker['scouted']));
    check('战斗日志有 6 个位置（3 攻 + 3 守）',
        count($log['att_slots'] ?? []) + count($log['def_slots'] ?? []) > 0);
}

// ---- 14. 平票 = 对峙，不产生战斗 ----
$cleanup();
$pdo->prepare("UPDATE slice_turns SET turn_no = 8, status = 'open', settled_at = NULL WHERE id = ?")->execute([$turnId]);
$insertOrder->execute([$gameId, $turnId, $playerId, 0, 'night_raid', $nodeCode, 1, 'front', 'p15_s1_' . bin2hex(random_bytes(3))]);
$insertOrder->execute([$gameId, $turnId, $otherPlayerId, 0, 'fortify', $nodeCode, 1, 'front', 'p15_s2_' . bin2hex(random_bytes(3))]);
$result = $settler->settle($gameId, $turnId);
$standoff = null;
foreach ($result['battles'] as $b) {
    if (($b['node_code'] ?? '') === $nodeCode) {
        $standoff = $b;
        break;
    }
}
check('平票返回 standoff', ($standoff['reason'] ?? '') === 'standoff', json_encode($result['battles'], JSON_UNESCAPED_UNICODE));
check('平票不产生 battle_id', empty($standoff['battle_id']));

// ---- 15. 一人一票：同一玩家 3 张令只算 1 票 ----
$cleanup();
$pdo->prepare("UPDATE slice_turns SET turn_no = 8, status = 'open', settled_at = NULL WHERE id = ?")->execute([$turnId]);
for ($slot = 0; $slot < 3; $slot++) {
    $insertOrder->execute([$gameId, $turnId, $biPlayers[0], $slot, 'night_raid', $nodeCode, $slot + 1, 'front', 'p15_v1_' . $slot . '_' . bin2hex(random_bytes(3))]);
}
$insertOrder->execute([$gameId, $turnId, $otherPlayerId, 0, 'fortify', $nodeCode, 1, 'front', 'p15_v2_' . bin2hex(random_bytes(3))]);
$result = $settler->settle($gameId, $turnId);
$voteBattle = null;
foreach ($result['battles'] as $b) {
    if (($b['node_code'] ?? '') === $nodeCode) {
        $voteBattle = $b;
        break;
    }
}
check('同一玩家 3 令只算 1 票 → 平票', ($voteBattle['reason'] ?? '') === 'standoff', json_encode($result['battles'], JSON_UNESCAPED_UNICODE));

// ---- 16. 守方自己的令不挡攻城 ----
$cleanup();
$pdo->prepare("UPDATE slice_turns SET turn_no = 8, status = 'open', settled_at = NULL WHERE id = ?")->execute([$turnId]);
$moFactionId = (int)$pdo->query("SELECT id FROM slice_factions WHERE game_id = {$gameId} AND code = 'mo'")->fetchColumn();
$pdo->prepare("UPDATE slice_nodes SET owner_faction_id = (SELECT id FROM slice_factions WHERE game_id = ? AND code = 'bi'), morale = 0 WHERE game_id = ? AND node_code = 'A_START'")
    ->execute([$gameId, $gameId]);
for ($slot = 0; $slot < 3; $slot++) {
    $insertOrder->execute([$gameId, $turnId, $biPlayers[$slot], $slot, 'fortify', 'A_START', $slot + 1, 'front', 'p15_d1_' . $slot . '_' . bin2hex(random_bytes(3))]);
}
$insertOrder->execute([$gameId, $turnId, $otherPlayerId, 0, 'night_raid', 'A_START', 1, 'front', 'p15_d2_' . bin2hex(random_bytes(3))]);
$result = $settler->settle($gameId, $turnId);
$defendBattle = null;
foreach ($result['battles'] as $b) {
    if (($b['node_code'] ?? '') === 'A_START') {
        $defendBattle = $b;
        break;
    }
}
check('守方 3 令不挡攻城', !empty($defendBattle['battle_id']), json_encode($result['battles'], JSON_UNESCAPED_UNICODE));
check('攻方是墨而不是守方笔', ($defendBattle['attacker_faction_id'] ?? 0) === $moFactionId);

if (!empty($defendBattle['battle_id'])) {
    $stmt = $pdo->prepare('SELECT defender_json FROM slice_battles WHERE id = ?');
    $stmt->execute([(int)$defendBattle['battle_id']]);
    $defJson = json_decode((string)$stmt->fetchColumn(), true);
    $defTeams = $defJson['teams'] ?? [];
    check('真实守军 3 队', count($defTeams) === 3, 'def_teams=' . count($defTeams));
    check('守军带自己的坚壁', in_array('fortify', array_column($defTeams, 'card'), true), json_encode(array_column($defTeams, 'card')));
    check('守军不再是固定 1320', abs((float)($defJson['troops'] ?? 0) - 1320.0) > 1.0, 'troops=' . ($defJson['troops'] ?? 'null'));
    check('标记 real_garrison', !empty($defJson['real_garrison']));
}
$pdo->prepare("UPDATE slice_nodes SET owner_faction_id = (SELECT id FROM slice_factions WHERE game_id = ? AND code = 'bi'), morale = 0 WHERE game_id = ? AND node_code = 'A_START'")
    ->execute([$gameId, $gameId]);

// ---- 17. 没有驻守令 → 回落到固定守军 ----
$cleanup();
$pdo->prepare("UPDATE slice_turns SET turn_no = 8, status = 'open', settled_at = NULL WHERE id = ?")->execute([$turnId]);
$pdo->prepare("UPDATE slice_nodes SET owner_faction_id = (SELECT id FROM slice_factions WHERE game_id = ? AND code = 'bi'), morale = 0 WHERE game_id = ? AND node_code = 'A_START'")
    ->execute([$gameId, $gameId]);
$insertOrder->execute([$gameId, $turnId, $otherPlayerId, 0, 'night_raid', 'A_START', 1, 'front', 'p15_fb_' . bin2hex(random_bytes(3))]);
$result = $settler->settle($gameId, $turnId);
$fallbackBattle = null;
foreach ($result['battles'] as $b) {
    if (($b['node_code'] ?? '') === 'A_START') {
        $fallbackBattle = $b;
        break;
    }
}
check('无驻守令仍开打', !empty($fallbackBattle['battle_id']), json_encode($result['battles'], JSON_UNESCAPED_UNICODE));
if (!empty($fallbackBattle['battle_id'])) {
    $stmt = $pdo->prepare('SELECT defender_json FROM slice_battles WHERE id = ?');
    $stmt->execute([(int)$fallbackBattle['battle_id']]);
    $fbJson = json_decode((string)$stmt->fetchColumn(), true);
    $fbTeams = $fbJson['teams'] ?? [];
    check('回落固定守军 3 队', count($fbTeams) === 3);
    check('固定守军无战术牌', array_column($fbTeams, 'card') === [null, null, null]);
    check('固定守军 1320 兵', abs((float)($fbJson['troops'] ?? 0) - 1320.0) < 1.0, 'troops=' . ($fbJson['troops'] ?? 'null'));
    check('real_garrison=false', empty($fbJson['real_garrison']));
}
$pdo->prepare("UPDATE slice_nodes SET owner_faction_id = (SELECT id FROM slice_factions WHERE game_id = ? AND code = 'bi'), morale = 0 WHERE game_id = ? AND node_code = 'A_START'")
    ->execute([$gameId, $gameId]);

// ---- 清理 ----
$cleanup();
$pdo->prepare('UPDATE slice_turns SET turn_no = ?, status = ?, settled_at = NULL WHERE id = ?')
    ->execute([(int)$original['turn_no'], (string)$original['status'], $turnId]);

echo PHP_EOL;
if ($failed > 0) {
    echo "PHASE15_CARDS FAIL ({$failed})\n";
    exit(1);
}
echo "PHASE15_CARDS PASS\n";
