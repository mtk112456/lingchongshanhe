<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/bootstrap.php';
require_once dirname(__DIR__) . '/src/SqlRunner.php';

try {
    [$config, $pdo] = slice_bootstrap();
    SqlRunner::runFile($pdo, dirname(__DIR__) . '/seed_map12.sql');

    $stmt = $pdo->prepare('SELECT id, code, name, status, rules_version FROM slice_games WHERE code = ?');
    $stmt->execute(['MAP12_TEST']);
    $game = $stmt->fetch();
    if (!$game) {
        throw new RuntimeException('MAP12_TEST 未创建');
    }

    $gameId = (int)$game['id'];
    $counts = [
        'game' => $game['code'],
        'status' => $game['status'],
        'rules_version' => $game['rules_version'],
        'nodes' => (int)$pdo->query("SELECT COUNT(*) FROM slice_nodes WHERE game_id = {$gameId}")->fetchColumn(),
        'edges' => (int)$pdo->query("SELECT COUNT(*) FROM slice_edges WHERE game_id = {$gameId}")->fetchColumn(),
        'factions' => (int)$pdo->query("SELECT COUNT(*) FROM slice_factions WHERE game_id = {$gameId}")->fetchColumn(),
        'players' => (int)$pdo->query("SELECT COUNT(*) FROM slice_players WHERE game_id = {$gameId} AND role = 'player'")->fetchColumn(),
        'turns' => (int)$pdo->query("SELECT COUNT(*) FROM slice_turns WHERE game_id = {$gameId}")->fetchColumn(),
    ];

    echo '完成：' . json_encode($counts, JSON_UNESCAPED_UNICODE) . PHP_EOL;
    echo "教师控制台：http://127.0.0.1:8080/teacher" . PHP_EOL;
} catch (Throwable $e) {
    fwrite(STDERR, '初始化失败：' . $e->getMessage() . PHP_EOL);
    exit(1);
}
