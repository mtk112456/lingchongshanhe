<?php
declare(strict_types=1);

/**
 * 在试跑库创建 12+1 城游戏，并把 5 节点切片暂停。
 *
 * 用法：
 *   $env:SLICE_CONFIG = "server/slice/config.trial.php"
 *   php server/slice/scripts/setup_trial_map12.php
 */
require_once dirname(__DIR__) . '/bootstrap.php';
require_once dirname(__DIR__) . '/src/SqlRunner.php';

[$config, $pdo] = slice_bootstrap();

$source = dirname(__DIR__) . '/seed_map12.sql';
$sql = file_get_contents($source);
if ($sql === false) {
    fwrite(STDERR, "读取 seed_map12.sql 失败\n");
    exit(1);
}
$sql = str_replace("'MAP12_TEST'", "'MAP12_TRIAL'", $sql);
$sql = str_replace("'12+1 城·九州测试'", "'12+1 城·青竹试锋'", $sql);

$tmp = tempnam(sys_get_temp_dir(), 'map12_trial_') . '.sql';
file_put_contents($tmp, $sql);
try {
    SqlRunner::runFile($pdo, $tmp);
} finally {
    @unlink($tmp);
}

$pdo->exec("UPDATE slice_games SET status = 'running' WHERE code = 'MAP12_TRIAL'");
$pdo->exec("UPDATE slice_games SET status = 'paused' WHERE code = 'SLICE_A'");

$stmt = $pdo->prepare('SELECT id, code, name, status FROM slice_games WHERE code = ?');
$stmt->execute(['MAP12_TRIAL']);
$game = $stmt->fetch();
if (!$game) {
    fwrite(STDERR, "MAP12_TRIAL 创建失败\n");
    exit(1);
}
$gameId = (int)$game['id'];
printf(
    "OK %s | %s | nodes=%d edges=%d players=%d\n",
    $game['code'],
    $game['status'],
    (int)$pdo->query("SELECT COUNT(*) FROM slice_nodes WHERE game_id = {$gameId}")->fetchColumn(),
    (int)$pdo->query("SELECT COUNT(*) FROM slice_edges WHERE game_id = {$gameId}")->fetchColumn(),
    (int)$pdo->query("SELECT COUNT(*) FROM slice_players WHERE game_id = {$gameId}")->fetchColumn()
);
