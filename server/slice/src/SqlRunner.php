<?php
declare(strict_types=1);

final class SqlRunner
{
    public static function runFile(PDO $pdo, string $path): void
    {
        if (!is_file($path)) {
            throw new RuntimeException('SQL 文件不存在：' . $path);
        }
        $sql = file_get_contents($path);
        if ($sql === false) {
            throw new RuntimeException('SQL 读取失败：' . $path);
        }
        // 去掉行注释后按分号切分；本项目的 SQL 不含存储过程/触发器。
        $sql = preg_replace('/^\s*--.*$/m', '', $sql);
        foreach (preg_split('/;\s*(?:\r?\n|$)/', $sql) as $statement) {
            $statement = trim($statement);
            if ($statement === '') {
                continue;
            }
            $pdo->exec($statement);
        }
    }

    /**
     * @param string[] $files
     */
    public static function runFiles(PDO $pdo, array $files): void
    {
        foreach ($files as $file) {
            self::runFile($pdo, $file);
        }
    }
}
