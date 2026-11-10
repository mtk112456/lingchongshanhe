<?php
declare(strict_types=1);

/**
 * 对指定配置库执行一个迁移文件（只新增表/字段）。
 *
 * 用法：
 *   php server/slice/scripts/apply_migration.php config.trial.php migrations/007_daily_bulletin.sql
 */
require_once dirname(__DIR__) . '/bootstrap.php';
require_once dirname(__DIR__) . '/src/SqlRunner.php';
require_once dirname(__DIR__) . '/src/Db.php';

$configName = $argv[1] ?? '';
$migration = $argv[2] ?? '';
if ($configName === '' || $migration === '') {
    fwrite(STDERR, "用法：php apply_migration.php <config.xxx.php> <migrations/xxx.sql>\n");
    exit(1);
}

$configPath = str_starts_with($configName, '/') || preg_match('/^[A-Za-z]:/', $configName)
    ? $configName
    : dirname(__DIR__) . '/' . $configName;
$migrationPath = str_starts_with($migration, '/') || preg_match('/^[A-Za-z]:/', $migration)
    ? $migration
    : dirname(__DIR__) . '/' . $migration;

if (!is_file($configPath) || !is_file($migrationPath)) {
    fwrite(STDERR, "配置或迁移文件不存在\n");
    exit(1);
}

$config = require $configPath;
$pdo = Db::connect($config['db']);
printf("DB: %s\n", $config['db']['name']);
SqlRunner::runFile($pdo, $migrationPath);
printf("OK: %s\n", basename($migrationPath));
