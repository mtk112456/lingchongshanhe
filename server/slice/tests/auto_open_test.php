<?php
declare(strict_types=1);

require_once __DIR__ . '/../bootstrap.php';
require_once __DIR__ . '/../src/SqlRunner.php';

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
$seed = dirname(__DIR__) . '/seed.sql';
$pdo->exec("DELETE FROM slice_games WHERE code = 'SLICE_A'");
SqlRunner::runFile($pdo, $seed);

$gameId = (int)$pdo->query("SELECT id FROM slice_games WHERE code = 'SLICE_A'")->fetchColumn();
$turnId = (int)$pdo->query("SELECT id FROM slice_turns WHERE game_id = {$gameId} ORDER BY turn_no LIMIT 1")->fetchColumn();

try {
    // 24 小时正式节奏：已结算的第 1 回合，07:00 应自动开第 2 回合
    $pdo->prepare('UPDATE slice_games SET turn_seconds = 86400, status = "running" WHERE id = ?')->execute([$gameId]);
    $pdo->prepare('UPDATE slice_turns SET status = "settled", settled_at = NOW() WHERE id = ?')->execute([$turnId]);

    $morning = $service->autoOpenDailyTurns(7);
    check('07:00 自动开新回合', ($morning['opened'] ?? 0) === 1, json_encode($morning));
    $newTurn = $pdo->query("SELECT turn_no, status FROM slice_turns WHERE game_id = {$gameId} ORDER BY turn_no DESC LIMIT 1")->fetch();
    check('新回合=2 且 open', (int)$newTurn['turn_no'] === 2 && (string)$newTurn['status'] === 'open');

    $again = $service->autoOpenDailyTurns(7);
    check('已有 open 回合不重复开', ($again['opened'] ?? -1) === 0, json_encode($again));

    $noon = $service->autoOpenDailyTurns(12);
    check('非早晨窗口跳过', ($noon['skipped'] ?? '') === 'OUTSIDE_WINDOW');

    // 600 秒试跑节奏：不自动开
    $pdo->exec("DELETE FROM slice_games WHERE code = 'SLICE_A'");
    SqlRunner::runFile($pdo, $seed);
    $gameId = (int)$pdo->query("SELECT id FROM slice_games WHERE code = 'SLICE_A'")->fetchColumn();
    $turnId = (int)$pdo->query("SELECT id FROM slice_turns WHERE game_id = {$gameId} ORDER BY turn_no LIMIT 1")->fetchColumn();
    $pdo->prepare('UPDATE slice_games SET turn_seconds = 600, status = "running" WHERE id = ?')->execute([$gameId]);
    $pdo->prepare('UPDATE slice_turns SET status = "settled", settled_at = NOW() WHERE id = ?')->execute([$turnId]);
    $trial = $service->autoOpenDailyTurns(7);
    check('600 秒试跑不自动开', ($trial['opened'] ?? -1) === 0, json_encode($trial));
} finally {
    $pdo->exec("DELETE FROM slice_games WHERE code = 'SLICE_A'");
    SqlRunner::runFile($pdo, $seed);
}

echo PHP_EOL;
if ($failed > 0) {
    echo "AUTO_OPEN FAIL ({$failed})\n";
    exit(1);
}
echo "AUTO_OPEN PASS\n";
