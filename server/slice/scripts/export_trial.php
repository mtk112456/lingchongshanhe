<?php
declare(strict_types=1);

/**
 * 试跑数据导出：CSV + summary.json + observation.md
 *
 * 用法：
 *   $env:SLICE_CONFIG = "...\config.trial.php"
 *   php server/slice/scripts/export_trial.php
 *
 * 输出：
 *   trial_results/YYYYMMDD_HHMMSS/
 */

require_once dirname(__DIR__) . '/bootstrap.php';

try {
    [$config, $pdo] = slice_bootstrap();
} catch (Throwable $e) {
    fwrite(STDERR, '初始化失败：' . $e->getMessage() . PHP_EOL);
    exit(1);
}

$root = dirname(__DIR__, 3);
$stamp = date('Ymd_His');
$dir = $root . '/trial_results/' . $stamp;
if (!is_dir($dir) && !mkdir($dir, 0775, true) && !is_dir($dir)) {
    fwrite(STDERR, '无法创建目录：' . $dir . PHP_EOL);
    exit(1);
}

$tables = [
    'orders' => 'slice_order_slots',
    'battles' => 'slice_battles',
    'changes' => 'slice_node_changes',
    'turns' => 'slice_turns',
    'nodes' => 'slice_nodes',
    'compositions' => 'slice_compositions',
];

$counts = [];
foreach ($tables as $name => $table) {
    $stmt = $pdo->query("SELECT * FROM {$table}");
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    $counts[$name] = count($rows);

    $fh = fopen($dir . '/' . $name . '.csv', 'wb');
    if ($fh === false) {
        fwrite(STDERR, '无法写入 ' . $name . ".csv\n");
        exit(1);
    }
    // Excel 识别中文
    fwrite($fh, "\xEF\xBB\xBF");
    if ($rows !== []) {
        fputcsv($fh, array_keys($rows[0]), ',', '"', '');
        foreach ($rows as $row) {
            fputcsv($fh, array_values($row), ',', '"', '');
        }
    }
    fclose($fh);
}

$game = $pdo->query('SELECT code, name, status FROM slice_games ORDER BY id LIMIT 1')->fetch();
$turn = $pdo->query('SELECT turn_no, status FROM slice_turns ORDER BY turn_no DESC LIMIT 1')->fetch();

$summary = [
    'exported_at' => date('c'),
    'game' => $game === false ? null : $game,
    'latest_turn' => $turn === false ? null : $turn,
    'rows' => $counts,
    'students' => (int)$pdo->query('SELECT COUNT(*) FROM students')->fetchColumn(),
    'captures' => (int)$pdo->query("SELECT COUNT(*) FROM slice_node_changes WHERE reason = 'captured'")->fetchColumn(),
    'battles' => (int)$pdo->query('SELECT COUNT(*) FROM slice_battles')->fetchColumn(),
];
file_put_contents(
    $dir . '/summary.json',
    json_encode($summary, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES)
);

$observation = "# 试跑观察表\n\n"
    . "导出时间：" . date('Y-m-d H:i:s') . "\n\n"
    . "## 数据\n\n"
    . "```text\n"
    . "orders: {$counts['orders']}\n"
    . "battles: {$counts['battles']}\n"
    . "changes: {$counts['changes']}\n"
    . "captures: {$summary['captures']}\n"
    . "```\n\n"
    . "## 学生观察\n\n"
    . "| 学生 | 回合 1 出令 | 回合 2 出令 | 回合 3 出令 | 能解释结果 | 想再来 | 备注 |\n"
    . "|---|---|---|---|---|---|---|\n"
    . "| 青竹一 |  |  |  |  |  |  |\n"
    . "| 青竹二 |  |  |  |  |  |  |\n"
    . "| 青竹三 |  |  |  |  |  |  |\n"
    . "| 青竹四 |  |  |  |  |  |  |\n"
    . "| 墨点一 |  |  |  |  |  |  |\n"
    . "| 墨点二 |  |  |  |  |  |  |\n"
    . "| 墨点三 |  |  |  |  |  |  |\n"
    . "| 墨点四 |  |  |  |  |  |  |\n\n"
    . "## 教师记录\n\n"
    . "```text\n学生总时长：\n教师总时长：\n最常问的问题：\n最卡的一步：\n有没有人中途放弃：\n```\n";
file_put_contents($dir . '/observation.md', $observation);

echo '导出完成：' . $dir . PHP_EOL;
echo 'orders=' . $counts['orders']
    . ' battles=' . $counts['battles']
    . ' changes=' . $counts['changes']
    . ' captures=' . $summary['captures'] . PHP_EOL;
