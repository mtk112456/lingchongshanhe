<?php
declare(strict_types=1);

require dirname(__DIR__) . '/server/slice/bootstrap.php';
[$config, $pdo, $service] = slice_bootstrap();
require dirname(__DIR__) . '/server/slice/src/SqlRunner.php';

SqlRunner::runFiles($pdo, [
    dirname(__DIR__) . '/server/slice/legacy_schema.sql',
    dirname(__DIR__) . '/server/slice/legacy_seed.sql',
    dirname(__DIR__) . '/server/slice/schema.sql',
    dirname(__DIR__) . '/server/slice/seed.sql',
]);

// 预置第 1 回合青竹一包含 scout、night_raid、fortify、supply 四类全齐牌面
$pdo->exec("
    INSERT INTO slice_hands (game_id, turn_id, player_id, cards_json, redraw_used, hand_seed)
    VALUES (1, 1, 1, '[\"night_raid\",\"fortify\",\"scout\",\"supply\"]', 0, 'seed_p15_test')
    ON DUPLICATE KEY UPDATE cards_json = '[\"night_raid\",\"fortify\",\"scout\",\"supply\"]'
");

echo "PREPARE_P15_CARDS_OK\n";
