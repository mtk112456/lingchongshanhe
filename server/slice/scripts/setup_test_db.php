<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/bootstrap.php';
require_once dirname(__DIR__) . '/src/SqlRunner.php';

try {
    [$config, $pdo] = slice_bootstrap();
} catch (Throwable $e) {
    fwrite(STDERR, "初始化失败：{$e->getMessage()}\n");
    exit(1);
}

$root = dirname(__DIR__);
$dbName = (string)($config['db']['name'] ?? '');
$force = in_array('--force', $argv, true);
if (!$force && !preg_match('/(test|trial)/i', $dbName)) {
    fwrite(STDERR, "拒绝执行：setup_test_db.php 会 DROP 表，只允许库名含 test/trial 的库；当前库 {$dbName}\n");
    fwrite(STDERR, "如确认是演练库，请加 --force。\n");
    exit(1);
}

$files = [
    'legacy_schema.sql',
    'schema.sql',
    'legacy_seed.sql',
    'seed.sql',
];

try {
    // DDL 在 MySQL/MariaDB 中会隐式提交，不能把建表包在一个事务里。
    foreach ($files as $file) {
        SqlRunner::runFile($pdo, $root . '/' . $file);
        echo "OK  {$file}\n";
    }

    $counts = [
        'games' => (int)$pdo->query('SELECT COUNT(*) FROM slice_games')->fetchColumn(),
        'players' => (int)$pdo->query('SELECT COUNT(*) FROM slice_players')->fetchColumn(),
        'students' => (int)$pdo->query('SELECT COUNT(*) FROM students')->fetchColumn(),
        'pets' => (int)$pdo->query('SELECT COUNT(*) FROM student_pets')->fetchColumn(),
        'nodes' => (int)$pdo->query('SELECT COUNT(*) FROM slice_nodes')->fetchColumn(),
        'turns' => (int)$pdo->query('SELECT COUNT(*) FROM slice_turns')->fetchColumn(),
    ];
    echo "完成：", json_encode($counts, JSON_UNESCAPED_UNICODE), "\n";
    echo "登录：青竹一 / slice2026；教师：teacher / teacher2026\n";
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    fwrite(STDERR, "初始化失败：" . $e->getMessage() . "\n");
    exit(1);
}

