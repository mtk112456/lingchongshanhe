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

echo "DB_RESET_OK\n";
