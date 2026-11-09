<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/bootstrap.php';
require_once dirname(__DIR__) . '/src/SqlRunner.php';

final class TestHarness
{
    public PDO $pdo;
    public SliceService $service;
    public PointsService $points;
    public array $config;
    private string $root;

    public function __construct()
    {
        [$this->config, $this->pdo, $this->service] = slice_bootstrap();
        $this->points = new PointsService($this->pdo, $this->config);
        $this->root = dirname(__DIR__);
    }

    public function reset(): void
    {
        SqlRunner::runFiles($this->pdo, [
            $this->root . '/schema.sql',
            $this->root . '/legacy_schema.sql',
            $this->root . '/legacy_seed.sql',
            $this->root . '/seed.sql',
        ]);
    }

    public function login(string $name = '青竹一'): array
    {
        $result = $this->service->loginStudent($name, 'slice2026');
        return $this->service->authenticate($result['token']);
    }

    public function teacher(): array
    {
        $result = $this->service->loginAdmin('teacher', 'teacher2026');
        return $this->service->authenticate($result['token']);
    }

    public function setOwner(string $nodeCode, ?string $factionCode): void
    {
        $factionId = null;
        if ($factionCode !== null) {
            $stmt = $this->pdo->prepare(
                'SELECT f.id FROM slice_factions f JOIN slice_games g ON g.id = f.game_id
                 WHERE g.code = "SLICE_A" AND f.code = ? LIMIT 1'
            );
            $stmt->execute([$factionCode]);
            $factionId = $stmt->fetchColumn();
            if ($factionId === false) {
                throw new RuntimeException('Faction not found: ' . $factionCode);
            }
        }
        $stmt = $this->pdo->prepare(
            'UPDATE slice_nodes n JOIN slice_games g ON g.id = n.game_id
             SET n.owner_faction_id = ? WHERE g.code = "SLICE_A" AND n.node_code = ?'
        );
        $stmt->execute([$factionId === null ? null : (int)$factionId, $nodeCode]);
    }

    public function nodeOwner(string $nodeCode): ?string
    {
        $stmt = $this->pdo->prepare(
            'SELECT f.code FROM slice_nodes n
             JOIN slice_games g ON g.id = n.game_id
             LEFT JOIN slice_factions f ON f.id = n.owner_faction_id
             WHERE g.code = "SLICE_A" AND n.node_code = ? LIMIT 1'
        );
        $stmt->execute([$nodeCode]);
        $row = $stmt->fetch();
        if (!$row) {
            throw new RuntimeException('Node not found: ' . $nodeCode);
        }
        return $row['code'] === null ? null : (string)$row['code'];
    }

    public function setDeadline(int $turnId, string $when): void
    {
        $stmt = $this->pdo->prepare('UPDATE slice_turns SET deadline_at = ? WHERE id = ?');
        $stmt->execute([$when, $turnId]);
    }

    public function turn(int $turnId = 1): array
    {
        $stmt = $this->pdo->prepare('SELECT * FROM slice_turns WHERE id = ?');
        $stmt->execute([$turnId]);
        $row = $stmt->fetch();
        if (!$row) {
            throw new RuntimeException('Turn not found: ' . $turnId);
        }
        return $row;
    }

    public function count(string $table, string $where = '', array $params = []): int
    {
        $stmt = $this->pdo->prepare('SELECT COUNT(*) FROM ' . $table . ($where !== '' ? ' WHERE ' . $where : ''));
        $stmt->execute($params);
        return (int)$stmt->fetchColumn();
    }

    public function fetchOne(string $sql, array $params = []): array|false
    {
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetch();
    }

    public function submit(array $player, string $action, string $target, ?string $origin, string $key, int $turnId = 1): array
    {
        return $this->service->submitOrder($player, [
            'turn_id' => $turnId,
            'action' => $action,
            'origin_node' => $origin,
            'target_node' => $target,
            'request_key' => $key,
        ]);
    }

    public function lock(array $teacher, int $turnId = 1, bool $force = true): array
    {
        return $this->service->lockTurn($teacher, $turnId, $force);
    }

    public function settle(array $teacher, int $turnId = 1, array $options = []): array
    {
        return $this->service->settleTurn($teacher, $turnId, $options);
    }

    public function result(int $turnId = 1): array
    {
        $stmt = $this->pdo->prepare('SELECT * FROM slice_turn_results WHERE turn_id = ?');
        $stmt->execute([$turnId]);
        $row = $stmt->fetch();
        if (!$row) {
            throw new RuntimeException('Result not found for turn ' . $turnId);
        }
        return json_decode((string)$row['result_json'], true);
    }

    public function change(string $nodeCode, int $turnId = 1): array
    {
        $result = $this->result($turnId);
        foreach ($result['node_changes'] as $change) {
            if ($change['node_code'] === $nodeCode) {
                return $change;
            }
        }
        throw new RuntimeException('Change not found: ' . $nodeCode);
    }

    public function assertTrue(bool $condition, string $message): void
    {
        if (!$condition) {
            throw new RuntimeException($message);
        }
    }

    public function assertSame(mixed $expected, mixed $actual, string $message): void
    {
        if ($expected !== $actual) {
            throw new RuntimeException($message . ' (expected=' . var_export($expected, true) . ', actual=' . var_export($actual, true) . ')');
        }
    }

    public function assertApi(callable $fn, string $expectedCode): ApiException
    {
        try {
            $fn();
        } catch (ApiException $e) {
            if ($e->errorCode !== $expectedCode) {
                throw new RuntimeException('Expected API error ' . $expectedCode . ', got ' . $e->errorCode . ': ' . $e->getMessage());
            }
            return $e;
        }
        throw new RuntimeException('Expected API error ' . $expectedCode . ', but call succeeded');
    }

    /**
     * @param array<int, array<string, string>> $specs
     * @return array<int, array<string, mixed>>
     */
    public function spawnWorkers(array $specs): array
    {
        $worker = __DIR__ . '/concurrent_worker.php';
        $procs = [];
        foreach ($specs as $i => $spec) {
            $cmd = [
                PHP_BINARY,
                '-d', 'extension_dir=' . ini_get('extension_dir'),
                '-d', 'extension=pdo_mysql',
                $worker,
            ];
            foreach ($spec as $value) {
                $cmd[] = (string)$value;
            }
            $descriptors = [
                0 => ['pipe', 'r'],
                1 => ['pipe', 'w'],
                2 => ['pipe', 'w'],
            ];
            $proc = proc_open($cmd, $descriptors, $pipes, $this->root, null, ['bypass_shell' => true]);
            if (!is_resource($proc)) {
                throw new RuntimeException('Failed to spawn worker');
            }
            fclose($pipes[0]);
            $procs[$i] = ['proc' => $proc, 'stdout' => $pipes[1], 'stderr' => $pipes[2]];
        }

        $results = [];
        foreach ($procs as $i => $item) {
            $stdout = stream_get_contents($item['stdout']);
            $stderr = stream_get_contents($item['stderr']);
            fclose($item['stdout']);
            fclose($item['stderr']);
            $code = proc_close($item['proc']);
            $parsed = null;
            foreach (array_reverse(preg_split('/\r?\n/', trim((string)$stdout))) as $line) {
                $line = trim($line);
                if ($line !== '' && $line[0] === '{') {
                    $parsed = json_decode($line, true);
                    break;
                }
            }
            $results[$i] = [
                'exit' => $code,
                'stdout' => $stdout,
                'stderr' => $stderr,
                'json' => $parsed,
            ];
        }
        return $results;
    }
}
