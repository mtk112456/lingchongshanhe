<?php
declare(strict_types=1);

require_once __DIR__ . '/../bootstrap.php';

$failed = 0;
function check(string $name, bool $ok, string $detail = ''): void
{
    global $failed;
    echo ($ok ? '[PASS] ' : '[FAIL] ') . $name . ($detail !== '' ? ' — ' . $detail : '') . PHP_EOL;
    if (!$ok) {
        $failed++;
    }
}

[$config, $pdo, $service] = slice_bootstrap();
$login = $service->loginStudent('青竹一', 'slice2026');
$player = $service->authenticate($login['token']);
$turnId = (int)$player['game_current_turn_id'];

$pdo->prepare('DELETE FROM slice_order_slots WHERE turn_id = ? AND player_id = ?')->execute([$turnId, (int)$player['id']]);
$insert = $pdo->prepare(
    'INSERT INTO slice_order_slots
        (game_id, turn_id, player_id, slot, card_code, target_node_code, lane, row_pos, status, last_request_key)
     VALUES (?, ?, ?, 0, "scout", "N2", 1, "front", "active", ?)'
);
$insert->execute([(int)$player['game_id'], $turnId, (int)$player['id'], 'scout_state_' . bin2hex(random_bytes(4))]);

try {
    $state = $service->getState($player, $turnId);
    check('state 返回 scouted_nodes', array_key_exists('scouted_nodes', $state));
    check('N2 已侦察', in_array('N2', $state['scouted_nodes'] ?? [], true), json_encode($state['scouted_nodes'] ?? []));
    check('reachable_targets 含 N2', in_array('N2', $state['reachable_targets'] ?? [], true), json_encode($state['reachable_targets'] ?? []));
    check('reachable_targets 含己方 A_START', in_array('A_START', $state['reachable_targets'] ?? [], true));
} finally {
    $pdo->prepare('DELETE FROM slice_order_slots WHERE turn_id = ? AND player_id = ?')->execute([$turnId, (int)$player['id']]);
}

echo PHP_EOL;
if ($failed > 0) {
    echo "SCOUT_STATE FAIL ({$failed})\n";
    exit(1);
}
echo "SCOUT_STATE PASS\n";
