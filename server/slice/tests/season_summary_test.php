<?php
declare(strict_types=1);

require_once __DIR__ . '/../bootstrap.php';
require_once __DIR__ . '/../src/SqlRunner.php';
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

[$config, $pdo] = slice_bootstrap();
$seed = dirname(__DIR__) . '/seed_map12.sql';
SqlRunner::runFile($pdo, $seed);

$gameId = (int)$pdo->query("SELECT id FROM slice_games WHERE code = 'MAP12_TEST'")->fetchColumn();
$service = new SeasonService($pdo);

try {
    $s = $service->summary($gameId);
    check('赛季周次 = 第 1 周', $s['week'] === 1);
    check('4 个阵营', count($s['factions']) === 4);
    check('9 座中立城', $s['neutral_cities'] === 9, 'neutral=' . $s['neutral_cities']);
    check('长安初始中立', $s['changan']['owner'] === null);
    check('尚未决出胜负', $s['winner'] === null && $s['season_over'] === false);

    $pdo->prepare(
        "UPDATE slice_nodes SET owner_faction_id = (SELECT id FROM slice_factions WHERE game_id = ? AND code = 'bi')
         WHERE game_id = ? AND node_code = 'changan'"
    )->execute([$gameId, $gameId]);
    $s = $service->summary($gameId);
    check('占长安直接获胜', ($s['winner']['code'] ?? '') === 'bi' && ($s['winner']['reason'] ?? '') === 'changan');
    check('赛季结束', $s['season_over'] === true);

    SqlRunner::runFile($pdo, $seed);
    $gameId = (int)$pdo->query("SELECT id FROM slice_games WHERE code = 'MAP12_TEST'")->fetchColumn();

    $pdo->prepare(
        "UPDATE slice_nodes SET owner_faction_id = (SELECT id FROM slice_factions WHERE game_id = ? AND code = 'bi')
         WHERE game_id = ? AND node_code = 'xiangyang'"
    )->execute([$gameId, $gameId]);
    $pdo->prepare("UPDATE slice_turns SET turn_no = 28 WHERE game_id = ?")->execute([$gameId]);
    $pdo->prepare("UPDATE slice_games SET status = 'finished' WHERE id = ?")->execute([$gameId]);

    $s = $service->summary($gameId);
    check('无长安时按城数获胜', ($s['winner']['code'] ?? '') === 'bi' && ($s['winner']['reason'] ?? '') === 'cities');
    check('胜者城数 = 2', ($s['winner']['cities'] ?? 0) === 2, 'cities=' . ($s['winner']['cities'] ?? 0));
    check('第 28 回合 days_left = 0', $s['days_left'] === 0);
} finally {
    SqlRunner::runFile($pdo, $seed);
}

echo PHP_EOL;
if ($failed > 0) {
    echo "SEASON_SUMMARY FAIL ({$failed})\n";
    exit(1);
}
echo "SEASON_SUMMARY PASS\n";
