<?php
declare(strict_types=1);

require_once __DIR__ . '/ApiException.php';
require_once __DIR__ . '/Clock.php';
require_once __DIR__ . '/PointsService.php';
require_once __DIR__ . '/HandService.php';
require_once __DIR__ . '/BattleSettlementService.php';
require_once __DIR__ . '/BulletinService.php';
require_once __DIR__ . '/MeritService.php';
require_once __DIR__ . '/EstateService.php';
require_once __DIR__ . '/PlayerReportService.php';
require_once __DIR__ . '/CardSettlementService.php';

final class SliceService
{
    private PDO $pdo;
    private array $config;
    private Clock $clock;
    private PointsService $points;

    public function __construct(PDO $pdo, array $config, ?PointsService $points = null)
    {
        $this->pdo = $pdo;
        $this->config = $config;
        $this->clock = new Clock((string)($config['app']['timezone'] ?? 'Asia/Shanghai'));
        $this->points = $points ?? new PointsService($pdo, $config);
    }

    // ------------------------------------------------------------------
    // 基础
    // ------------------------------------------------------------------

    private function app(string $key, mixed $default = null): mixed
    {
        return $this->config['app'][$key] ?? $default;
    }

    private function encode(array $data): string
    {
        $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        if ($json === false) {
            throw new ApiException('JSON_ENCODE_FAILED', '服务端 JSON 编码失败', 500);
        }
        return $json;
    }

    private function decode(?string $json): array
    {
        if ($json === null || $json === '') {
            return [];
        }
        $data = json_decode($json, true);
        return is_array($data) ? $data : [];
    }

    private function nowSql(): string
    {
        return $this->clock->sql();
    }

    private function deadlinePassed(array $turn): bool
    {
        return $this->nowSql() >= (string)$turn['deadline_at'];
    }

    private function secondsLeft(array $turn): int
    {
        $now = $this->clock->now()->getTimestamp();
        $deadline = $this->clock->fromSql((string)$turn['deadline_at'])->getTimestamp();
        return max(0, $deadline - $now);
    }

    private function audit(int $gameId, ?int $turnId, ?int $playerId, string $action, array $detail = []): void
    {
        $stmt = $this->pdo->prepare(
            'INSERT INTO slice_audit_log (game_id, turn_id, player_id, action, detail_json) VALUES (?, ?, ?, ?, ?)'
        );
        $stmt->execute([$gameId, $turnId, $playerId, $action, $this->encode($detail)]);
    }

    private function loadGame(int $gameId): array
    {
        $stmt = $this->pdo->prepare('SELECT * FROM slice_games WHERE id = ?');
        $stmt->execute([$gameId]);
        $row = $stmt->fetch();
        if (!$row) {
            throw new ApiException('GAME_NOT_FOUND', '测试局不存在', 404);
        }
        return $row;
    }

    private function loadTurnById(int $turnId, bool $forUpdate = false): array
    {
        $sql = 'SELECT * FROM slice_turns WHERE id = ?' . ($forUpdate ? ' FOR UPDATE' : '');
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute([$turnId]);
        $row = $stmt->fetch();
        if (!$row) {
            throw new ApiException('TURN_NOT_FOUND', '回合不存在', 404);
        }
        return $row;
    }

    private function loadCurrentTurn(array $game): array
    {
        if (empty($game['current_turn_id'])) {
            throw new ApiException('TURN_NOT_FOUND', '当前没有进行中的回合', 404);
        }
        $turn = $this->loadTurnById((int)$game['current_turn_id']);
        if ((int)$turn['game_id'] !== (int)$game['id']) {
            throw new ApiException('TURN_NOT_FOUND', '回合不属于当前测试局', 404);
        }
        return $turn;
    }

    private function loadPlayerById(int $playerId): array
    {
        $stmt = $this->pdo->prepare(
            'SELECT p.*, g.code AS game_code, g.name AS game_name, g.status AS game_status,
                    g.rules_version AS game_rules_version, g.turn_seconds AS game_turn_seconds,
                    g.current_turn_id AS game_current_turn_id,
                    f.code AS faction_code, f.name AS faction_name, f.color AS faction_color,
                    s.id AS student_id, s.name AS student_name, s.show_name AS student_show_name,
                    s.class_id AS student_class_id, s.score AS student_score,
                    a.username AS admin_username, a.nickname AS admin_nickname,
                    sp.id AS pet_instance_id, sp.nickname AS pet_nickname, sp.level AS pet_level,
                    sp.hunger AS pet_hunger, sp.current_exp AS pet_exp,
                    pt.code AS pet_template_code, pt.name AS pet_template_name,
                    pt.element AS pet_element, pt.rarity AS pet_rarity,
                    pt.base_hp AS pet_base_hp, pt.base_atk AS pet_base_atk,
                    pt.base_def AS pet_base_def, pt.base_spd AS pet_base_spd
             FROM slice_players p
             JOIN slice_games g ON g.id = p.game_id
             LEFT JOIN slice_factions f ON f.id = p.faction_id
             LEFT JOIN students s ON s.id = p.student_id
             LEFT JOIN admin a ON a.id = p.admin_id
             LEFT JOIN student_pets sp ON sp.student_id = p.student_id
             LEFT JOIN pet_templates pt ON pt.id = sp.pet_template_id
             WHERE p.id = ? AND p.is_active = 1'
        );
        $stmt->execute([$playerId]);
        $row = $stmt->fetch();
        if (!$row) {
            throw new ApiException('UNAUTHORIZED', '账号不存在或已停用', 401);
        }
        return $row;
    }

    private function publicPlayer(array $row): array
    {
        $student = null;
        if ($row['student_id'] !== null) {
            $student = [
                'id' => (int)$row['student_id'],
                'name' => (string)$row['student_name'],
                'show_name' => (string)$row['student_show_name'],
                'class_id' => (int)$row['student_class_id'],
                'score' => (int)$row['student_score'],
            ];
        }
        $admin = null;
        if ($row['admin_id'] !== null) {
            $admin = [
                'id' => (int)$row['admin_id'],
                'username' => (string)$row['admin_username'],
                'nickname' => (string)$row['admin_nickname'],
            ];
        }
        $pet = null;
        if ($row['pet_instance_id'] !== null) {
            $pet = [
                'instance_id' => (int)$row['pet_instance_id'],
                'nickname' => (string)$row['pet_nickname'],
                'level' => (int)$row['pet_level'],
                'hunger' => (int)$row['pet_hunger'],
                'exp' => (int)$row['pet_exp'],
                'template_code' => (string)$row['pet_template_code'],
                'template_name' => (string)$row['pet_template_name'],
                'element' => (string)$row['pet_element'],
                'rarity' => (string)$row['pet_rarity'],
                // 切片统一 1000 兵力；正式 B 阶段再接四维/技能/法宝。
                'power' => 1000,
            ];
        }
        return [
            'id' => (int)$row['id'],
            'nickname' => (string)$row['nickname'],
            'role' => (string)$row['role'],
            'student' => $student,
            'admin' => $admin,
            'pet' => $pet,
            'pet_code' => (string)$row['pet_code'],
            'pet_name' => (string)$row['pet_name'],
            'faction' => $row['faction_id'] === null ? null : [
                'id' => (int)$row['faction_id'],
                'code' => (string)$row['faction_code'],
                'name' => (string)$row['faction_name'],
                'color' => (string)$row['faction_color'],
            ],
            'game' => [
                'id' => (int)$row['game_id'],
                'code' => (string)$row['game_code'],
                'name' => (string)$row['game_name'],
                'status' => (string)$row['game_status'],
                'rules_version' => (string)$row['game_rules_version'],
                'turn_seconds' => (int)$row['game_turn_seconds'],
                'current_turn_id' => $row['game_current_turn_id'] === null ? null : (int)$row['game_current_turn_id'],
            ],
        ];
    }

    private function requireTeacher(array $player): void
    {
        if ((string)$player['role'] !== 'teacher') {
            throw new ApiException('FORBIDDEN', '只有教师可以执行该操作', 403);
        }
    }

    private function assertSameGame(array $player, array $turn): void
    {
        if ((int)$turn['game_id'] !== (int)$player['game_id']) {
            throw new ApiException('FORBIDDEN', '禁止跨测试局读取或下令', 403);
        }
    }

    private function factionPublic(?int $factionId, array $factionsById): ?array
    {
        if ($factionId === null) {
            return null;
        }
        $f = $factionsById[$factionId] ?? null;
        if (!$f) {
            return null;
        }
        return [
            'id' => (int)$f['id'],
            'code' => (string)$f['code'],
            'name' => (string)$f['name'],
            'color' => (string)$f['color'],
        ];
    }

    private function statusLabel(string $status): string
    {
        return match ($status) {
            'open' => '可下令',
            'locked' => '已锁定，待结算',
            'settling' => '结算中',
            'settled' => '已结算',
            'failed' => '结算失败，可重试',
            'cancelled' => '已取消',
            default => $status,
        };
    }

    // ------------------------------------------------------------------
    // 认证
    // ------------------------------------------------------------------

    public function loginStudent(string $name, string $password, ?string $gameCode = null): array
    {
        $name = trim($name);
        if ($name === '' || $password === '') {
            throw new ApiException('BAD_REQUEST', '请输入姓名和密码');
        }

        // 与现有学生登录保持一致：优先 show_name 精确匹配；重名时要求带序号姓名。
        $stmt = $this->pdo->prepare(
            'SELECT id, name, show_name, class_id, password, score FROM students
             WHERE name = ? OR show_name = ? ORDER BY id'
        );
        $stmt->execute([$name, $name]);
        $list = $stmt->fetchAll();
        if ($list === []) {
            throw new ApiException('UNAUTHORIZED', '姓名或密码不正确', 401);
        }
        $student = null;
        foreach ($list as $item) {
            if ((string)$item['show_name'] === $name) {
                $student = $item;
                break;
            }
        }
        if ($student === null && count($list) === 1) {
            $student = $list[0];
        }
        if ($student === null) {
            throw new ApiException('AMBIGUOUS_NAME', '存在同名学生，请使用带序号的显示名登录', 409);
        }
        if (!password_verify($password, (string)$student['password'])) {
            throw new ApiException('UNAUTHORIZED', '姓名或密码不正确', 401);
        }

        $sql = 'SELECT p.id FROM slice_players p
                JOIN slice_games g ON g.id = p.game_id
                WHERE p.student_id = ? AND p.role = "player" AND p.is_active = 1';
        $params = [(int)$student['id']];
        if ($gameCode !== null && $gameCode !== '') {
            $sql .= ' AND g.code = ?';
            $params[] = $gameCode;
        }
        $sql .= ' ORDER BY FIELD(g.status, "running", "paused", "finished", "draft"), g.id DESC LIMIT 1';
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($params);
        $memberId = $stmt->fetchColumn();
        if ($memberId === false) {
            throw new ApiException('NOT_ENROLLED', '该学生不在本局试验名单中', 403);
        }

        $row = $this->loadPlayerById((int)$memberId);
        if ($row['pet_instance_id'] === null) {
            throw new ApiException('PET_REQUIRED', '该学生还没有班宠，请先在班级系统中领取班宠', 403);
        }

        // 同步显示名与班宠快照；不修改 students / student_pets。
        $stmt = $this->pdo->prepare(
            'UPDATE slice_players SET nickname = ?, pet_instance_id = ?, pet_code = ?, pet_name = ? WHERE id = ?'
        );
        $stmt->execute([
            (string)$student['show_name'],
            (int)$row['pet_instance_id'],
            (string)$row['pet_template_code'],
            (string)$row['pet_nickname'],
            (int)$row['id'],
        ]);
        $row = $this->loadPlayerById((int)$row['id']);
        return $this->issueSession($row, 'auth.login.student', $this->points->getWallet((int)$student['id']));
    }

    public function loginAdmin(string $username, string $password, ?string $gameCode = null): array
    {
        $username = trim($username);
        if ($username === '' || $password === '') {
            throw new ApiException('BAD_REQUEST', '请输入管理员账号和密码');
        }
        $stmt = $this->pdo->prepare('SELECT id, username, password, nickname FROM admin WHERE username = ?');
        $stmt->execute([$username]);
        $admin = $stmt->fetch();
        if (!$admin || !password_verify($password, (string)$admin['password'])) {
            throw new ApiException('UNAUTHORIZED', '管理员账号或密码不正确', 401);
        }

        $sql = 'SELECT p.id FROM slice_players p
                JOIN slice_games g ON g.id = p.game_id
                WHERE p.admin_id = ? AND p.role = "teacher" AND p.is_active = 1';
        $params = [(int)$admin['id']];
        if ($gameCode !== null && $gameCode !== '') {
            $sql .= ' AND g.code = ?';
            $params[] = $gameCode;
        }
        $sql .= ' ORDER BY FIELD(g.status, "running", "paused", "finished", "draft"), g.id DESC LIMIT 1';
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($params);
        $memberId = $stmt->fetchColumn();
        if ($memberId === false) {
            throw new ApiException('NOT_ENROLLED', '该管理员不在本局试验名单中', 403);
        }
        $row = $this->loadPlayerById((int)$memberId);
        return $this->issueSession($row, 'auth.login.admin');
    }

    private function issueSession(array $row, string $auditAction, ?array $wallet = null): array
    {
        $token = bin2hex(random_bytes(32));
        $ttl = (int)$this->app('token_ttl_seconds', 43200);
        $expires = $this->clock->now()->modify('+' . $ttl . ' seconds')->format('Y-m-d H:i:s');
        $stmt = $this->pdo->prepare(
            'INSERT INTO slice_sessions (player_id, token_hash, expires_at) VALUES (?, ?, ?)'
        );
        $stmt->execute([(int)$row['id'], hash('sha256', $token), $expires]);
        $stmt = $this->pdo->prepare('UPDATE slice_players SET last_seen_at = ? WHERE id = ?');
        $stmt->execute([$this->nowSql(), (int)$row['id']]);

        $this->audit((int)$row['game_id'], null, (int)$row['id'], $auditAction, [
            'role' => (string)$row['role'],
            'student_id' => $row['student_id'] === null ? null : (int)$row['student_id'],
            'admin_id' => $row['admin_id'] === null ? null : (int)$row['admin_id'],
        ]);

        return [
            'token' => $token,
            'expires_at' => $expires,
            'player' => $this->publicPlayer($row),
            'wallet' => $wallet,
        ];
    }

    public function authenticate(?string $token): array
    {
        if ($token === null || $token === '') {
            throw new ApiException('UNAUTHORIZED', '请先登录', 401);
        }
        $stmt = $this->pdo->prepare(
            'SELECT player_id FROM slice_sessions WHERE token_hash = ? AND expires_at > ? LIMIT 1'
        );
        $stmt->execute([hash('sha256', $token), $this->nowSql()]);
        $session = $stmt->fetch();
        if (!$session) {
            throw new ApiException('UNAUTHORIZED', '登录已过期，请重新登录', 401);
        }
        $player = $this->loadPlayerById((int)$session['player_id']);
        $stmt = $this->pdo->prepare('UPDATE slice_players SET last_seen_at = ? WHERE id = ?');
        $stmt->execute([$this->nowSql(), (int)$player['id']]);
        return $player;
    }

    public function logout(array $player, ?string $token): array
    {
        if ($token !== null && $token !== '') {
            $stmt = $this->pdo->prepare('DELETE FROM slice_sessions WHERE token_hash = ?');
            $stmt->execute([hash('sha256', $token)]);
        }
        $this->audit((int)$player['game_id'], null, (int)$player['id'], 'auth.logout');
        return ['ok' => true];
    }

    // ------------------------------------------------------------------
    // 状态
    // ------------------------------------------------------------------

    public function getState(array $player, ?int $turnId = null): array
    {
        $game = $this->loadGame((int)$player['game_id']);
        $turn = $turnId === null ? $this->loadCurrentTurn($game) : $this->loadTurnById($turnId);
        $this->assertSameGame($player, $turn);

        $stmt = $this->pdo->prepare('SELECT * FROM slice_factions WHERE game_id = ? ORDER BY sort_order, id');
        $stmt->execute([(int)$game['id']]);
        $factionRows = $stmt->fetchAll();
        $factionsById = [];
        $factionsByCode = [];
        foreach ($factionRows as $f) {
            $factionsById[(int)$f['id']] = $f;
            $factionsByCode[(string)$f['code']] = $f;
        }

        $stmt = $this->pdo->prepare('SELECT * FROM slice_nodes WHERE game_id = ? ORDER BY sort_order, id');
        $stmt->execute([(int)$game['id']]);
        $nodeRows = $stmt->fetchAll();
        $nodesByCode = [];
        foreach ($nodeRows as $n) {
            $nodesByCode[(string)$n['node_code']] = $n;
        }

        $stmt = $this->pdo->prepare('SELECT a_node_code, b_node_code FROM slice_edges WHERE game_id = ? ORDER BY id');
        $stmt->execute([(int)$game['id']]);
        $edgeRows = $stmt->fetchAll();
        $adj = [];
        $edges = [];
        foreach ($edgeRows as $e) {
            $a = (string)$e['a_node_code'];
            $b = (string)$e['b_node_code'];
            $adj[$a][] = $b;
            $adj[$b][] = $a;
            $edges[] = [$a, $b];
        }

        $myFactionId = $player['faction_id'] === null ? null : (int)$player['faction_id'];

        $stmt = $this->pdo->prepare(
            'SELECT * FROM slice_orders WHERE turn_id = ? AND player_id = ? AND status = "active" LIMIT 1'
        );
        $stmt->execute([(int)$turn['id'], (int)$player['id']]);
        $myOrderRow = $stmt->fetch();
        $myOrder = $myOrderRow ? $this->orderPublic($myOrderRow, $nodesByCode) : null;

        // Phase 1：学生的手牌 / 编成 / 3 张将令
        $hand = null;
        $composition = null;
        $cardOrders = [];
        $scoutedNodes = [];
        if ((string)$player['role'] === 'player') {
            $handService = new HandService($this->pdo);
            $hand = $handService->getOrCreateHand((int)$game['id'], (int)$turn['id'], (int)$player['id']);
            $composition = $handService->getComposition(
                (int)$game['id'],
                (int)$player['id'],
                Clock::weekOfTurn((int)$turn['turn_no'])
            );
            $cardOrders = $handService->getOrders((int)$turn['id'], (int)$player['id']);
            $stmt = $this->pdo->prepare(
                "SELECT target_node_code FROM slice_order_slots
                 WHERE turn_id = ? AND player_id = ? AND card_code = 'scout' AND status = 'active'"
            );
            $stmt->execute([(int)$turn['id'], (int)$player['id']]);
            $scoutedNodes = array_map('strval', $stmt->fetchAll(PDO::FETCH_COLUMN));

            // 望楼：哨探额外覆盖相邻城
            $extraScout = (new EstateService($this->pdo))->extraScoutNodes(
                (int)$game['id'],
                (int)$player['id']
            );
            if ($extraScout > 0 && $scoutedNodes !== []) {
                $in = implode(',', array_fill(0, count($scoutedNodes), '?'));
                $stmt = $this->pdo->prepare(
                    "SELECT a_node_code, b_node_code FROM slice_edges
                     WHERE game_id = ? AND (a_node_code IN ({$in}) OR b_node_code IN ({$in}))"
                );
                $stmt->execute(array_merge([(int)$game['id']], $scoutedNodes, $scoutedNodes));
                $adjacent = [];
                foreach ($stmt->fetchAll() as $edge) {
                    $a = (string)$edge['a_node_code'];
                    $b = (string)$edge['b_node_code'];
                    $adjacent[] = in_array($a, $scoutedNodes, true) ? $b : $a;
                }
                $adjacent = array_values(array_diff(array_unique($adjacent), $scoutedNodes));
                $limit = $extraScout * count($scoutedNodes);
                foreach (array_slice($adjacent, 0, $limit) as $code) {
                    $scoutedNodes[] = $code;
                }
            }

            $bulletin = (new BulletinService($this->pdo))->summary(
                (int)$game['id'],
                (int)$turn['id'],
                (int)$player['id']
            );
            $merit = (new MeritService($this->pdo))->summary(
                (int)$game['id'],
                (int)$player['id'],
                Clock::weekOfTurn((int)$turn['turn_no'])
            );
            $estate = (new EstateService($this->pdo))->summary(
                (int)$game['id'],
                (int)$player['id'],
                Clock::weekOfTurn((int)$turn['turn_no'])
            );
            if (($bulletin['choice'] ?? null) === 'scout') {
                $stmt = $this->pdo->prepare(
                    'SELECT node_code FROM slice_nodes
                     WHERE game_id = ? AND owner_faction_id IS NOT NULL AND owner_faction_id <> ?'
                );
                $stmt->execute([(int)$game['id'], (int)($player['faction_id'] ?? 0)]);
                foreach ($stmt->fetchAll(PDO::FETCH_COLUMN) as $code) {
                    if (!in_array((string)$code, $scoutedNodes, true)) {
                        $scoutedNodes[] = (string)$code;
                    }
                }
            }
        } else {
            $bulletin = null;
            $merit = null;
            $estate = null;
        }

        $canEdit = (string)$turn['status'] === 'open'
            && (string)$game['status'] === 'running'
            && !$this->deadlinePassed($turn);
        $editBlockReason = null;
        if (!$canEdit) {
            if ((string)$game['status'] === 'paused') {
                $editBlockReason = 'GAME_PAUSED';
            } elseif ((string)$turn['status'] !== 'open') {
                $editBlockReason = 'TURN_' . strtoupper((string)$turn['status']);
            } elseif ($this->deadlinePassed($turn)) {
                $editBlockReason = 'TURN_DEADLINE_PASSED';
            }
        }

        $nodes = [];
        $advanceFrom = [];
        $defendTargets = [];
        $governors = (new EstateService($this->pdo))->currentGovernors(
            (int)$game['id'],
            Clock::weekOfTurn((int)$turn['turn_no'])
        );
        foreach ($nodeRows as $n) {
            $code = (string)$n['node_code'];
            $ownerId = $n['owner_faction_id'] === null ? null : (int)$n['owner_faction_id'];
            $isStart = (string)$n['node_type'] === 'start';
            $isMine = $myFactionId !== null && $ownerId === $myFactionId;
            $targets = [];
            foreach ($adj[$code] ?? [] as $targetCode) {
                $target = $nodesByCode[$targetCode] ?? null;
                if ($target === null) {
                    continue;
                }
                $targetOwner = $target['owner_faction_id'] === null ? null : (int)$target['owner_faction_id'];
                if ((string)$target['node_type'] === 'start' && $targetOwner !== $myFactionId) {
                    continue;
                }
                $targets[] = $targetCode;
            }
            if ($isMine) {
                $advanceFrom[$code] = $targets;
                $defendTargets[] = $code;
            }
            $nodes[] = [
                'code' => $code,
                'name' => (string)$n['name'],
                'x' => (int)$n['x'],
                'y' => (int)$n['y'],
                'type' => (string)$n['node_type'],
                'is_start' => $isStart,
                'morale' => (int)($n['morale'] ?? 0),
                'morale_cap' => BattleSettlementService::cap((string)$n['node_type']),
                'owner' => $this->factionPublic($ownerId, $factionsById),
                'initial_owner' => $this->factionPublic(
                    $n['initial_owner_faction_id'] === null ? null : (int)$n['initial_owner_faction_id'],
                    $factionsById
                ),
                'is_my_faction' => $isMine,
                'can_advance_from' => $isMine,
                'can_defend' => $isMine,
                'governor' => $governors[$code] ?? null,
                'reachable_targets' => $isMine ? $targets : [],
            ];
        }

        $stmt = $this->pdo->prepare(
            'SELECT COUNT(*) AS c FROM slice_orders WHERE turn_id = ? AND status = "active"'
        );
        $stmt->execute([(int)$turn['id']]);
        $confirmed = (int)$stmt->fetchColumn();

        $stmt = $this->pdo->prepare(
            'SELECT COUNT(*) AS c FROM slice_players WHERE game_id = ? AND role = "player" AND is_active = 1'
        );
        $stmt->execute([(int)$game['id']]);
        $participants = (int)$stmt->fetchColumn();

        $factionParticipation = [];
        foreach ($factionRows as $f) {
            $stmt = $this->pdo->prepare(
                'SELECT COUNT(*) AS c FROM slice_orders o
                 JOIN slice_players p ON p.id = o.player_id
                 WHERE o.turn_id = ? AND o.status = "active" AND p.faction_id = ?'
            );
            $stmt->execute([(int)$turn['id'], (int)$f['id']]);
            $confirmedCount = (int)$stmt->fetchColumn();
            $stmt = $this->pdo->prepare(
                'SELECT COUNT(*) AS c FROM slice_players WHERE game_id = ? AND faction_id = ? AND role = "player" AND is_active = 1'
            );
            $stmt->execute([(int)$game['id'], (int)$f['id']]);
            $factionParticipation[] = [
                'faction' => $this->factionPublic((int)$f['id'], $factionsById),
                'confirmed' => $confirmedCount,
                'players' => (int)$stmt->fetchColumn(),
            ];
        }

        $stmt = $this->pdo->prepare(
            'SELECT t.id AS turn_id, t.turn_no, r.result_json FROM slice_turn_results r
             JOIN slice_turns t ON t.id = r.turn_id
             WHERE r.game_id = ? ORDER BY t.turn_no DESC LIMIT 1'
        );
        $stmt->execute([(int)$game['id']]);
        $lastResult = $stmt->fetch();
        $lastReport = null;
        if ($lastResult) {
            $decoded = $this->decode((string)$lastResult['result_json']);
            $headline = (string)($decoded['headline'] ?? '');
            if ($headline === '' && isset($decoded['battles'])) {
                $battles = is_array($decoded['battles']) ? $decoded['battles'] : [];
                $captures = count(array_filter($battles, static fn($b) => !empty($b['captured'])));
                $headline = sprintf(
                    '第 %d 回合：%d 场战斗，%d 城易主',
                    (int)$lastResult['turn_no'],
                    count($battles),
                    $captures
                );
            }
            $lastReport = [
                'turn_id' => (int)$lastResult['turn_id'],
                'turn_no' => (int)$lastResult['turn_no'],
                'headline' => $headline,
            ];
        }

        $nextTurn = null;
        $stmt = $this->pdo->prepare('SELECT * FROM slice_turns WHERE game_id = ? AND turn_no = ? LIMIT 1');
        $stmt->execute([(int)$game['id'], (int)$turn['turn_no'] + 1]);
        $next = $stmt->fetch();
        if ($next) {
            $nextTurn = $this->turnPublic($next);
        }

        $wallet = null;
        if ($player['student_id'] !== null) {
            $wallet = $this->points->getWallet((int)$player['student_id']);
        }

        $reachableTargets = [];
        if ($player['faction_id'] !== null) {
            $stmt = $this->pdo->prepare(
                'SELECT node_code FROM slice_nodes WHERE game_id = ? AND owner_faction_id = ?'
            );
            $stmt->execute([(int)$game['id'], (int)$player['faction_id']]);
            $owned = array_map('strval', $stmt->fetchAll(PDO::FETCH_COLUMN));
            if ($owned !== []) {
                $reachableTargets = $owned;
                $in = implode(',', array_fill(0, count($owned), '?'));
                $stmt = $this->pdo->prepare(
                    "SELECT a_node_code, b_node_code FROM slice_edges
                     WHERE game_id = ? AND (a_node_code IN ({$in}) OR b_node_code IN ({$in}))"
                );
                $stmt->execute(array_merge([(int)$game['id']], $owned, $owned));
                foreach ($stmt->fetchAll() as $edge) {
                    $a = (string)$edge['a_node_code'];
                    $b = (string)$edge['b_node_code'];
                    $reachableTargets[] = in_array($a, $owned, true) ? $b : $a;
                }
                $reachableTargets = array_values(array_unique($reachableTargets));
            }
        }

        return [
            'server_time' => $this->nowSql(),
            'wallet' => $wallet,
            'game' => [
                'id' => (int)$game['id'],
                'code' => (string)$game['code'],
                'name' => (string)$game['name'],
                'status' => (string)$game['status'],
                'rules_version' => (string)$game['rules_version'],
                'turn_seconds' => (int)$game['turn_seconds'],
                'current_turn_no' => (int)$turn['turn_no'],
            ],
            'turn' => $this->turnPublic($turn),
            'me' => $this->publicPlayer($player),
            'map' => [
                'nodes' => $nodes,
                'edges' => $edges,
            ],
            'my_order' => $myOrder,
            'hand' => $hand,
            'composition' => $composition,
            'card_orders' => $cardOrders,
            'scouted_nodes' => $scoutedNodes,
            'bulletin' => $bulletin,
            'merit' => $merit,
            'estate' => $estate,
            'reachable_targets' => $reachableTargets,
            'options' => [
                'advance_from' => $advanceFrom,
                'defend_targets' => $defendTargets,
            ],
            'orders_confirmed' => $confirmed,
            'participants' => $participants,
            'faction_participation' => $factionParticipation,
            'can_edit' => $canEdit,
            'edit_block_reason' => $editBlockReason,
            'last_report' => $lastReport,
            'next_turn' => $nextTurn,
            'rules' => ((string)$game['rules_version'] === 'cards_v1' || count($nodeRows) >= 13)
                ? [
                    '出令：每天 4 张手牌，最多出 3 令；可重抽 1 次。',
                    '队伍牌：同阵营打同一座城，战力前 3 名成为先锋。',
                    '支援：其余出令的同阵营玩家每人 +2%，上限 +30%。',
                    '克制：骑 > 盾 > 弓 > 枪 > 骑；克制 ×1.2，被克 ×0.85。',
                    '攻城：先破墙，再推民心；民心满则易主。长安 5 格，其余 2–3 格。',
                ]
                : [
                    '进军：从己方城派宠到相邻城，计 1 点。',
                    '驻守：在己方城驻守，计 1 点；原归属方另有 1 点基础守备。',
                    '最高分且大于 0 的阵营取得；平局或无人行动，保留原归属。',
                    '敌方起点不可作为进军目标；对向行军各计目标城。',
                    '第三回合后，每座非起点城为归属方计 1 分，同分并列。',
                ],
        ];
    }

    private function turnPublic(array $turn): array
    {
        return [
            'id' => (int)$turn['id'],
            'turn_no' => (int)$turn['turn_no'],
            'status' => (string)$turn['status'],
            'status_label' => $this->statusLabel((string)$turn['status']),
            'opens_at' => (string)$turn['opens_at'],
            'deadline_at' => (string)$turn['deadline_at'],
            'locked_at' => $turn['locked_at'],
            'settled_at' => $turn['settled_at'],
            'seconds_remaining' => $this->secondsLeft($turn),
            'can_edit' => (string)$turn['status'] === 'open' && !$this->deadlinePassed($turn),
            'snapshot_id' => $turn['snapshot_id'] === null ? null : (int)$turn['snapshot_id'],
            'failure_reason' => $turn['failure_reason'],
            'rules_version' => (string)$turn['rules_version'],
        ];
    }

    private function orderPublic(array $order, array $nodesByCode): array
    {
        $target = $nodesByCode[(string)$order['target_node_code']] ?? null;
        $origin = $order['origin_node_code'] !== null ? ($nodesByCode[(string)$order['origin_node_code']] ?? null) : null;
        return [
            'id' => (int)$order['id'],
            'action' => (string)$order['action'],
            'action_label' => (string)$order['action'] === 'advance' ? '进军' : '驻守',
            'origin_node_code' => $order['origin_node_code'],
            'origin_name' => $origin ? (string)$origin['name'] : null,
            'target_node_code' => (string)$order['target_node_code'],
            'target_name' => $target ? (string)$target['name'] : (string)$order['target_node_code'],
            'status' => (string)$order['status'],
            'updated_at' => (string)$order['updated_at'],
        ];
    }

    // ------------------------------------------------------------------
    // 军令
    // ------------------------------------------------------------------

    public function submitOrder(array $player, array $payload): array
    {
        if ((string)$player['role'] !== 'player') {
            throw new ApiException('FORBIDDEN', '教师账号不能下军令', 403);
        }
        $turnId = (int)($payload['turn_id'] ?? 0);
        $action = (string)($payload['action'] ?? '');
        $target = trim((string)($payload['target_node'] ?? ''));
        $origin = trim((string)($payload['origin_node'] ?? ''));
        $requestKey = trim((string)($payload['request_key'] ?? ''));

        if ($turnId <= 0 || !in_array($action, ['advance', 'defend'], true) || $target === '' || $requestKey === '') {
            throw new ApiException('BAD_REQUEST', '缺少 turn_id / action / target_node / request_key');
        }
        if (!preg_match('/^[A-Za-z0-9_-]{8,64}$/', $requestKey)) {
            throw new ApiException('BAD_REQUEST', 'request_key 需为 8–64 位字母、数字、下划线或短横线');
        }
        if ($action === 'defend') {
            $origin = '';
        }
        $payloadHash = hash('sha256', json_encode([
            'action' => $action,
            'origin_node' => $origin,
            'target_node' => $target,
        ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));

        $this->pdo->beginTransaction();
        try {
            $turn = $this->loadTurnById($turnId, true);
            $this->assertSameGame($player, $turn);
            $game = $this->loadGame((int)$turn['game_id']);
            if ((string)$game['status'] !== 'running') {
                throw new ApiException('GAME_PAUSED', '测试局已暂停，暂时不能下令', 409);
            }
            if ((string)$turn['status'] !== 'open') {
                throw new ApiException('TURN_LOCKED', '本回合已锁定，不能再改军令', 409, ['turn_status' => $turn['status']]);
            }
            if ($this->deadlinePassed($turn)) {
                throw new ApiException('TURN_DEADLINE_PASSED', '已过截止时间，军令不再接受', 409);
            }

            $stmt = $this->pdo->prepare(
                'SELECT * FROM slice_order_requests WHERE turn_id = ? AND player_id = ? AND request_key = ? FOR UPDATE'
            );
            $stmt->execute([$turnId, (int)$player['id'], $requestKey]);
            $prior = $stmt->fetch();
            if ($prior) {
                if (!hash_equals((string)$prior['payload_hash'], $payloadHash)) {
                    throw new ApiException('IDEMPOTENCY_CONFLICT', '同一 request_key 不能提交不同军令', 409);
                }
                $this->pdo->commit();
                $response = $this->decode((string)$prior['response_json']);
                $response['idempotent'] = true;
                $response['server_time'] = $this->nowSql();
                return $response;
            }

            $nodesByCode = $this->loadNodesByCode((int)$game['id']);
            $targetNode = $nodesByCode[$target] ?? null;
            if ($targetNode === null) {
                throw new ApiException('INVALID_TARGET', '目标城池不存在');
            }
            $myFactionId = $player['faction_id'] === null ? null : (int)$player['faction_id'];
            if ($myFactionId === null) {
                throw new ApiException('FORBIDDEN', '账号没有阵营，不能下令', 403);
            }
            $targetOwner = $targetNode['owner_faction_id'] === null ? null : (int)$targetNode['owner_faction_id'];
            if ((string)$targetNode['node_type'] === 'start' && $targetOwner !== $myFactionId) {
                throw new ApiException('START_PROTECTED', '敌方起点不可作为进军目标', 422);
            }

            if ($action === 'advance') {
                if ($origin === '') {
                    throw new ApiException('BAD_REQUEST', '进军必须指定出发城');
                }
                $originNode = $nodesByCode[$origin] ?? null;
                if ($originNode === null) {
                    throw new ApiException('INVALID_TARGET', '出发城池不存在');
                }
                if ($originNode['owner_faction_id'] === null || (int)$originNode['owner_faction_id'] !== $myFactionId) {
                    throw new ApiException('NOT_YOUR_CITY', '只能从己方城池进军', 422);
                }
                if (!$this->areAdjacent((int)$game['id'], $origin, $target)) {
                    throw new ApiException('NOT_ADJACENT', '目标与出发城不相邻', 422);
                }
            } else {
                if ($targetOwner === null || $targetOwner !== $myFactionId) {
                    throw new ApiException('NOT_YOUR_CITY', '驻守只能选择己方城池', 422);
                }
            }

            $stmt = $this->pdo->prepare(
                'SELECT * FROM slice_orders WHERE turn_id = ? AND player_id = ? FOR UPDATE'
            );
            $stmt->execute([$turnId, (int)$player['id']]);
            $existing = $stmt->fetch();
            if ($existing) {
                $stmt = $this->pdo->prepare(
                    'UPDATE slice_orders SET action = ?, origin_node_code = ?, target_node_code = ?,
                     status = "active", last_request_key = ?, updated_at = ? WHERE id = ?'
                );
                $stmt->execute([
                    $action,
                    $action === 'advance' ? $origin : null,
                    $target,
                    $requestKey,
                    $this->nowSql(),
                    (int)$existing['id'],
                ]);
                $orderId = (int)$existing['id'];
            } else {
                $stmt = $this->pdo->prepare(
                    'INSERT INTO slice_orders (game_id, turn_id, player_id, action, origin_node_code, target_node_code, status, last_request_key)
                     VALUES (?, ?, ?, ?, ?, ?, "active", ?)'
                );
                $stmt->execute([
                    (int)$game['id'],
                    $turnId,
                    (int)$player['id'],
                    $action,
                    $action === 'advance' ? $origin : null,
                    $target,
                    $requestKey,
                ]);
                $orderId = (int)$this->pdo->lastInsertId();
            }

            $stmt = $this->pdo->prepare('SELECT * FROM slice_orders WHERE id = ?');
            $stmt->execute([$orderId]);
            $orderRow = $stmt->fetch();
            $order = $this->orderPublic($orderRow, $nodesByCode);
            $response = [
                'order' => $order,
                'turn' => [
                    'id' => (int)$turn['id'],
                    'turn_no' => (int)$turn['turn_no'],
                    'status' => (string)$turn['status'],
                    'deadline_at' => (string)$turn['deadline_at'],
                    'can_edit' => true,
                ],
                'idempotent' => false,
                'message' => '军令已确认，可在截止前撤改。',
                'server_time' => $this->nowSql(),
            ];

            $stmt = $this->pdo->prepare(
                'INSERT INTO slice_order_requests (game_id, turn_id, player_id, request_key, payload_hash, response_json)
                 VALUES (?, ?, ?, ?, ?, ?)'
            );
            $stmt->execute([
                (int)$game['id'],
                $turnId,
                (int)$player['id'],
                $requestKey,
                $payloadHash,
                $this->encode($response),
            ]);
            $this->audit((int)$game['id'], $turnId, (int)$player['id'], 'order.submit', [
                'action' => $action,
                'origin' => $origin === '' ? null : $origin,
                'target' => $target,
                'request_key' => $requestKey,
            ]);
            $this->pdo->commit();
            return $response;
        } catch (Throwable $e) {
            if ($this->pdo->inTransaction()) {
                $this->pdo->rollBack();
            }
            throw $e;
        }
    }

    public function withdrawOrder(array $player, array $payload): array
    {
        if ((string)$player['role'] !== 'player') {
            throw new ApiException('FORBIDDEN', '教师账号不能撤令', 403);
        }
        $turnId = (int)($payload['turn_id'] ?? 0);
        $requestKey = trim((string)($payload['request_key'] ?? ''));
        if ($turnId <= 0 || $requestKey === '') {
            throw new ApiException('BAD_REQUEST', '缺少 turn_id / request_key');
        }
        if (!preg_match('/^[A-Za-z0-9_-]{8,64}$/', $requestKey)) {
            throw new ApiException('BAD_REQUEST', 'request_key 格式不正确');
        }
        $payloadHash = hash('sha256', 'withdraw|' . $turnId);

        $this->pdo->beginTransaction();
        try {
            $turn = $this->loadTurnById($turnId, true);
            $this->assertSameGame($player, $turn);
            $game = $this->loadGame((int)$turn['game_id']);
            if ((string)$game['status'] !== 'running') {
                throw new ApiException('GAME_PAUSED', '测试局已暂停，暂时不能撤令', 409);
            }
            if ((string)$turn['status'] !== 'open') {
                throw new ApiException('TURN_LOCKED', '本回合已锁定，不能撤令', 409);
            }
            if ($this->deadlinePassed($turn)) {
                throw new ApiException('TURN_DEADLINE_PASSED', '已过截止时间，不能撤令', 409);
            }

            $stmt = $this->pdo->prepare(
                'SELECT * FROM slice_order_requests WHERE turn_id = ? AND player_id = ? AND request_key = ? FOR UPDATE'
            );
            $stmt->execute([$turnId, (int)$player['id'], $requestKey]);
            $prior = $stmt->fetch();
            if ($prior) {
                if (!hash_equals((string)$prior['payload_hash'], $payloadHash)) {
                    throw new ApiException('IDEMPOTENCY_CONFLICT', '同一 request_key 不能用于不同操作', 409);
                }
                $this->pdo->commit();
                $response = $this->decode((string)$prior['response_json']);
                $response['idempotent'] = true;
                $response['server_time'] = $this->nowSql();
                return $response;
            }

            $stmt = $this->pdo->prepare(
                'SELECT * FROM slice_orders WHERE turn_id = ? AND player_id = ? AND status = "active" FOR UPDATE'
            );
            $stmt->execute([$turnId, (int)$player['id']]);
            $existing = $stmt->fetch();
            $hadOrder = false;
            if ($existing) {
                $hadOrder = true;
                $stmt = $this->pdo->prepare(
                    'UPDATE slice_orders SET status = "withdrawn", last_request_key = ?, updated_at = ? WHERE id = ?'
                );
                $stmt->execute([$requestKey, $this->nowSql(), (int)$existing['id']]);
            }

            $response = [
                'withdrawn' => true,
                'had_order' => $hadOrder,
                'message' => $hadOrder
                    ? '已撤回军令；若截止前不再下令，将按默认驻守己方起点结算。'
                    : '当前没有可撤回的军令；截止前仍可重新下令。',
                'turn' => [
                    'id' => (int)$turn['id'],
                    'turn_no' => (int)$turn['turn_no'],
                    'status' => (string)$turn['status'],
                    'deadline_at' => (string)$turn['deadline_at'],
                    'can_edit' => true,
                ],
                'idempotent' => false,
                'server_time' => $this->nowSql(),
            ];

            $stmt = $this->pdo->prepare(
                'INSERT INTO slice_order_requests (game_id, turn_id, player_id, request_key, payload_hash, response_json)
                 VALUES (?, ?, ?, ?, ?, ?)'
            );
            $stmt->execute([
                (int)$game['id'],
                $turnId,
                (int)$player['id'],
                $requestKey,
                $payloadHash,
                $this->encode($response),
            ]);
            $this->audit((int)$game['id'], $turnId, (int)$player['id'], 'order.withdraw', [
                'had_order' => $hadOrder,
                'request_key' => $requestKey,
            ]);
            $this->pdo->commit();
            return $response;
        } catch (Throwable $e) {
            if ($this->pdo->inTransaction()) {
                $this->pdo->rollBack();
            }
            throw $e;
        }
    }

    private function loadNodesByCode(int $gameId): array
    {
        $stmt = $this->pdo->prepare('SELECT * FROM slice_nodes WHERE game_id = ?');
        $stmt->execute([$gameId]);
        $rows = [];
        foreach ($stmt->fetchAll() as $row) {
            $rows[(string)$row['node_code']] = $row;
        }
        return $rows;
    }

    private function areAdjacent(int $gameId, string $a, string $b): bool
    {
        $stmt = $this->pdo->prepare(
            'SELECT 1 FROM slice_edges WHERE game_id = ? AND
             ((a_node_code = ? AND b_node_code = ?) OR (a_node_code = ? AND b_node_code = ?)) LIMIT 1'
        );
        $stmt->execute([$gameId, $a, $b, $b, $a]);
        return (bool)$stmt->fetchColumn();
    }

    // ------------------------------------------------------------------
    // 锁令与快照
    // ------------------------------------------------------------------

    public function lockTurn(array $teacher, int $turnId, bool $force = false): array
    {
        $this->requireTeacher($teacher);
        if ($force && !$this->app('allow_force_lock', false)) {
            throw new ApiException('FORBIDDEN', '当前环境不允许提前锁令', 403);
        }

        $this->pdo->beginTransaction();
        try {
            $turn = $this->loadTurnById($turnId, true);
            $this->assertSameGame($teacher, $turn);
            $game = $this->loadGame((int)$turn['game_id']);

            if ((string)$turn['status'] === 'settled') {
                $this->pdo->commit();
                return [
                    'already' => true,
                    'settled' => true,
                    'turn' => $this->turnPublic($turn),
                    'message' => '本回合已结算。',
                ];
            }
            if ((string)$turn['status'] === 'locked') {
                $summary = $this->snapshotSummary((int)$turn['snapshot_id']);
                $this->pdo->commit();
                return ['already' => true, 'settled' => false, 'turn' => $this->turnPublic($turn), 'snapshot' => $summary];
            }
            if ((string)$turn['status'] !== 'open') {
                throw new ApiException('TURN_NOT_OPEN', '当前回合状态不能锁令', 409, ['turn_status' => $turn['status']]);
            }
            if (!$force && !$this->deadlinePassed($turn)) {
                throw new ApiException('DEADLINE_NOT_REACHED', '尚未到截止时间，不能锁令', 409, [
                    'deadline_at' => $turn['deadline_at'],
                ]);
            }

            $snapshot = $this->buildSnapshot($game, $turn);
            $now = $this->nowSql();
            $stmt = $this->pdo->prepare(
                'INSERT INTO slice_snapshots (game_id, turn_id, rules_version, map_json, orders_json, content_hash)
                 VALUES (?, ?, ?, ?, ?, ?)'
            );
            $stmt->execute([
                (int)$game['id'],
                $turnId,
                (string)$turn['rules_version'],
                $snapshot['map_json'],
                $snapshot['orders_json'],
                $snapshot['content_hash'],
            ]);
            $snapshotId = (int)$this->pdo->lastInsertId();

            $stmt = $this->pdo->prepare(
                'INSERT INTO slice_snapshot_orders
                 (snapshot_id, player_id, faction_id, faction_code, nickname, pet_name, action, origin_node_code, target_node_code, is_default, sort_order)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
            );
            $sort = 0;
            foreach ($snapshot['orders'] as $o) {
                $sort++;
                $stmt->execute([
                    $snapshotId,
                    (int)$o['player_id'],
                    $o['faction_id'] === null ? null : (int)$o['faction_id'],
                    (string)$o['faction_code'],
                    (string)$o['nickname'],
                    (string)$o['pet_name'],
                    (string)$o['action'],
                    $o['origin_node_code'],
                    (string)$o['target_node_code'],
                    (int)$o['is_default'],
                    $sort,
                ]);
            }

            $stmt = $this->pdo->prepare(
                'UPDATE slice_turns SET status = "locked", locked_at = ?, snapshot_id = ?, failure_reason = NULL WHERE id = ?'
            );
            $stmt->execute([$now, $snapshotId, $turnId]);
            $this->audit((int)$game['id'], $turnId, (int)$teacher['id'], 'turn.lock', [
                'snapshot_id' => $snapshotId,
                'orders' => count($snapshot['orders']),
                'defaults' => $snapshot['default_count'],
                'force' => $force,
            ]);
            $this->pdo->commit();

            $turn['status'] = 'locked';
            $turn['locked_at'] = $now;
            $turn['snapshot_id'] = $snapshotId;
            return [
                'already' => false,
                'settled' => false,
                'turn' => $this->turnPublic($turn),
                'snapshot' => [
                    'snapshot_id' => $snapshotId,
                    'content_hash' => $snapshot['content_hash'],
                    'orders_count' => count($snapshot['orders']),
                    'default_count' => $snapshot['default_count'],
                    'locked_at' => $now,
                ],
                'message' => '已锁定并生成只读快照，接下来可以结算。',
            ];
        } catch (Throwable $e) {
            if ($this->pdo->inTransaction()) {
                $this->pdo->rollBack();
            }
            throw $e;
        }
    }

    private function snapshotSummary(?int $snapshotId): array
    {
        if ($snapshotId === null) {
            return [];
        }
        $stmt = $this->pdo->prepare('SELECT * FROM slice_snapshots WHERE id = ?');
        $stmt->execute([$snapshotId]);
        $row = $stmt->fetch();
        if (!$row) {
            return [];
        }
        $orders = $this->decode((string)$row['orders_json']);
        $defaults = 0;
        foreach ($orders as $o) {
            if (!empty($o['is_default'])) {
                $defaults++;
            }
        }
        return [
            'snapshot_id' => (int)$row['id'],
            'content_hash' => (string)$row['content_hash'],
            'orders_count' => count($orders),
            'default_count' => $defaults,
            'created_at' => (string)$row['created_at'],
        ];
    }

    private function buildSnapshot(array $game, array $turn): array
    {
        $stmt = $this->pdo->prepare('SELECT * FROM slice_factions WHERE game_id = ? ORDER BY sort_order, id');
        $stmt->execute([(int)$game['id']]);
        $factions = $stmt->fetchAll();

        $stmt = $this->pdo->prepare('SELECT * FROM slice_nodes WHERE game_id = ? ORDER BY sort_order, id');
        $stmt->execute([(int)$game['id']]);
        $nodes = $stmt->fetchAll();
        $nodesByCode = [];
        foreach ($nodes as $n) {
            $nodesByCode[(string)$n['node_code']] = $n;
        }

        $stmt = $this->pdo->prepare('SELECT a_node_code, b_node_code FROM slice_edges WHERE game_id = ? ORDER BY id');
        $stmt->execute([(int)$game['id']]);
        $edges = [];
        foreach ($stmt->fetchAll() as $e) {
            $edges[] = [(string)$e['a_node_code'], (string)$e['b_node_code']];
        }

        $stmt = $this->pdo->prepare(
            'SELECT p.id AS player_id, p.nickname,
                    COALESCE(sp.nickname, p.pet_name) AS pet_name, p.faction_id,
                    f.code AS faction_code, f.name AS faction_name, f.start_node_code, f.sort_order AS faction_sort
             FROM slice_players p
             JOIN slice_factions f ON f.id = p.faction_id
             LEFT JOIN student_pets sp ON sp.student_id = p.student_id
             WHERE p.game_id = ? AND p.role = "player" AND p.is_active = 1
             ORDER BY f.sort_order, p.id'
        );
        $stmt->execute([(int)$game['id']]);
        $players = $stmt->fetchAll();

        $stmt = $this->pdo->prepare(
            'SELECT * FROM slice_orders WHERE turn_id = ? AND status = "active"'
        );
        $stmt->execute([(int)$turn['id']]);
        $ordersByPlayer = [];
        foreach ($stmt->fetchAll() as $o) {
            $ordersByPlayer[(int)$o['player_id']] = $o;
        }

        $snapshotOrders = [];
        $defaultCount = 0;
        foreach ($players as $p) {
            $playerId = (int)$p['player_id'];
            if (isset($ordersByPlayer[$playerId])) {
                $o = $ordersByPlayer[$playerId];
                $action = (string)$o['action'];
                $origin = $o['origin_node_code'];
                $target = (string)$o['target_node_code'];
                $isDefault = 0;
            } else {
                $action = 'default_defend';
                $origin = (string)$p['start_node_code'];
                $target = (string)$p['start_node_code'];
                $isDefault = 1;
                $defaultCount++;
                if (!isset($nodesByCode[$target])) {
                    throw new ApiException('SNAPSHOT_INVALID', '默认驻守起点不存在：' . $target, 500);
                }
            }
            $snapshotOrders[] = [
                'player_id' => $playerId,
                'nickname' => (string)$p['nickname'],
                'pet_name' => (string)$p['pet_name'],
                'faction_id' => (int)$p['faction_id'],
                'faction_code' => (string)$p['faction_code'],
                'action' => $action,
                'origin_node_code' => $origin,
                'target_node_code' => $target,
                'is_default' => $isDefault,
            ];
        }

        $mapData = [
            'game_code' => (string)$game['code'],
            'rules_version' => (string)$turn['rules_version'],
            'nodes' => array_map(static function (array $n): array {
                return [
                    'node_code' => (string)$n['node_code'],
                    'name' => (string)$n['name'],
                    'node_type' => (string)$n['node_type'],
                    'x' => (int)$n['x'],
                    'y' => (int)$n['y'],
                    'owner_faction_id' => $n['owner_faction_id'] === null ? null : (int)$n['owner_faction_id'],
                ];
            }, $nodes),
            'edges' => $edges,
            'factions' => array_map(static function (array $f): array {
                return [
                    'id' => (int)$f['id'],
                    'code' => (string)$f['code'],
                    'name' => (string)$f['name'],
                    'color' => (string)$f['color'],
                    'start_node_code' => (string)$f['start_node_code'],
                    'sort_order' => (int)$f['sort_order'],
                ];
            }, $factions),
        ];

        $mapJson = $this->encode($mapData);
        $ordersJson = $this->encode($snapshotOrders);
        return [
            'map_json' => $mapJson,
            'orders_json' => $ordersJson,
            'content_hash' => hash('sha256', $mapJson . "\n" . $ordersJson),
            'orders' => $snapshotOrders,
            'default_count' => $defaultCount,
        ];
    }

    // ------------------------------------------------------------------
    // 结算
    // ------------------------------------------------------------------

    public function settleTurn(array $teacher, int $turnId, array $options = []): array
    {
        $this->requireTeacher($teacher);
        if (!empty($options['inject_failure']) && !$this->app('allow_fault_injection', false)) {
            throw new ApiException('FORBIDDEN', '当前环境不允许故障注入', 403);
        }

        $started = false;
        $turn = null;
        $game = null;
        try {
            $this->pdo->beginTransaction();
            $turn = $this->loadTurnById($turnId, true);
            $this->assertSameGame($teacher, $turn);
            $game = $this->loadGame((int)$turn['game_id']);

            if ((string)$turn['status'] === 'settled') {
                $result = $this->loadResult($turnId);
                $this->pdo->commit();
                return $result;
            }
            if (!in_array((string)$turn['status'], ['locked', 'failed', 'settling'], true)) {
                throw new ApiException('SETTLE_NOT_READY', '请先锁定本回合并生成快照', 409, [
                    'turn_status' => $turn['status'],
                ]);
            }

            $stmt = $this->pdo->prepare('SELECT * FROM slice_snapshots WHERE turn_id = ?');
            $stmt->execute([$turnId]);
            $snapshot = $stmt->fetch();
            if (!$snapshot) {
                throw new ApiException('SETTLE_NOT_READY', '本回合没有快照，不能结算', 409);
            }

            $stmt = $this->pdo->prepare(
                'INSERT IGNORE INTO slice_settlement_jobs (game_id, turn_id, status, attempts) VALUES (?, ?, "pending", 0)'
            );
            $stmt->execute([(int)$game['id'], $turnId]);
            $stmt = $this->pdo->prepare('SELECT * FROM slice_settlement_jobs WHERE turn_id = ? FOR UPDATE');
            $stmt->execute([$turnId]);
            $job = $stmt->fetch();

            if ((string)$job['status'] === 'done') {
                $result = $this->loadResult($turnId);
                $this->pdo->commit();
                return $result;
            }
            if ((string)$job['status'] === 'running' && !empty($job['started_at'])) {
                $age = $this->clock->now()->getTimestamp() - $this->clock->fromSql((string)$job['started_at'])->getTimestamp();
                if ($age < 60) {
                    throw new ApiException('SETTLE_RUNNING', '结算正在进行，请稍后刷新', 409);
                }
            }

            $now = $this->nowSql();
            $stmt = $this->pdo->prepare(
                'UPDATE slice_settlement_jobs SET status = "running", attempts = attempts + 1,
                 started_at = ?, finished_at = NULL, last_error = NULL WHERE id = ?'
            );
            $stmt->execute([$now, (int)$job['id']]);
            $stmt = $this->pdo->prepare(
                'UPDATE slice_turns SET status = "settling", failure_reason = NULL WHERE id = ?'
            );
            $stmt->execute([$turnId]);
            $started = true;

            $map = $this->decode((string)$snapshot['map_json']);
            $orders = $this->decode((string)$snapshot['orders_json']);
            $computed = $this->computeSettlement($map, $orders, $turn, $game);

            if (!empty($options['inject_failure'])) {
                throw new RuntimeException('INJECTED_SETTLEMENT_FAILURE');
            }

            $resultJson = $this->encode($computed);
            $resultHash = hash('sha256', $resultJson);
            $stmt = $this->pdo->prepare(
                'INSERT INTO slice_turn_results (game_id, turn_id, result_json, standings_json, content_hash)
                 VALUES (?, ?, ?, ?, ?)'
            );
            $stmt->execute([
                (int)$game['id'],
                $turnId,
                $resultJson,
                $this->encode($computed['standings'] ?? []),
                $resultHash,
            ]);

            $stmtChange = $this->pdo->prepare(
                'INSERT INTO slice_node_changes
                 (game_id, turn_id, node_code, owner_before_faction_id, owner_after_faction_id, winner_faction_id, score_json, reason)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
            );
            foreach ($computed['node_changes'] as $change) {
                $stmtChange->execute([
                    (int)$game['id'],
                    $turnId,
                    (string)$change['node_code'],
                    $change['owner_before']['id'] ?? null,
                    $change['owner_after']['id'] ?? null,
                    $change['winner']['id'] ?? null,
                    $this->encode([
                        'scores' => $change['scores'],
                        'breakdown' => $change['breakdown'],
                    ]),
                    (string)$change['reason'],
                ]);
            }

            $reports = $this->buildPlayerReports($computed, $map, $orders, $turn);
            $stmtReport = $this->pdo->prepare(
                'INSERT INTO slice_player_reports (game_id, turn_id, player_id, order_json, outcome_json, readable_text)
                 VALUES (?, ?, ?, ?, ?, ?)'
            );
            foreach ($reports as $playerId => $report) {
                $stmtReport->execute([
                    (int)$game['id'],
                    $turnId,
                    (int)$playerId,
                    $this->encode($report['order']),
                    $this->encode($report['outcome']),
                    (string)$report['readable_text'],
                ]);
            }

            $stmtNode = $this->pdo->prepare(
                'UPDATE slice_nodes SET owner_faction_id = ? WHERE game_id = ? AND node_code = ?'
            );
            foreach ($computed['node_changes'] as $change) {
                $stmtNode->execute([
                    $change['owner_after']['id'] ?? null,
                    (int)$game['id'],
                    (string)$change['node_code'],
                ]);
            }

            $stmt = $this->pdo->prepare(
                'UPDATE slice_turns SET status = "settled", settled_at = ?, snapshot_id = ?, failure_reason = NULL WHERE id = ?'
            );
            $stmt->execute([$now, (int)$snapshot['id'], $turnId]);

            if ((int)$turn['turn_no'] >= $this->maxTurnsForGame((int)$game['id'])) {
                $stmt = $this->pdo->prepare('UPDATE slice_games SET status = "finished" WHERE id = ?');
                $stmt->execute([(int)$game['id']]);
            }

            $stmt = $this->pdo->prepare(
                'UPDATE slice_settlement_jobs SET status = "done", finished_at = ?, last_error = NULL WHERE id = ?'
            );
            $stmt->execute([$now, (int)$job['id']]);
            $this->audit((int)$game['id'], $turnId, (int)$teacher['id'], 'turn.settle', [
                'result_hash' => $resultHash,
                'snapshot_id' => (int)$snapshot['id'],
                'attempts' => (int)$job['attempts'] + 1,
            ]);
            $this->pdo->commit();

            return $this->loadResult($turnId);
        } catch (Throwable $e) {
            if ($this->pdo->inTransaction()) {
                $this->pdo->rollBack();
            }
            if ($started && $turn !== null && $game !== null) {
                $this->markSettlementFailed($game, $turn, $e);
                throw new ApiException(
                    'SETTLE_FAILED',
                    '结算失败；快照已保留，可用同一快照重试。',
                    500,
                    [
                        'turn_id' => $turnId,
                        'snapshot_id' => $turn['snapshot_id'] === null ? null : (int)$turn['snapshot_id'],
                        'reason' => $e->getMessage(),
                    ]
                );
            }
            throw $e;
        }
    }

    private function markSettlementFailed(array $game, array $turn, Throwable $e): void
    {
        try {
            $this->pdo->beginTransaction();
            $now = $this->nowSql();
            $stmt = $this->pdo->prepare(
                'INSERT INTO slice_settlement_jobs (game_id, turn_id, status, attempts, last_error, finished_at)
                 VALUES (?, ?, "failed", 1, ?, ?)
                 ON DUPLICATE KEY UPDATE status = "failed", attempts = attempts + 1,
                 last_error = VALUES(last_error), finished_at = VALUES(finished_at)'
            );
            $stmt->execute([(int)$game['id'], (int)$turn['id'], $e->getMessage(), $now]);
            $stmt = $this->pdo->prepare(
                'UPDATE slice_turns SET status = "failed", failure_reason = ? WHERE id = ? AND status <> "settled"'
            );
            $stmt->execute([$e->getMessage(), (int)$turn['id']]);
            $this->audit((int)$game['id'], (int)$turn['id'], null, 'turn.failed', [
                'reason' => $e->getMessage(),
            ]);
            $this->pdo->commit();
        } catch (Throwable $inner) {
            if ($this->pdo->inTransaction()) {
                $this->pdo->rollBack();
            }
            error_log('markSettlementFailed: ' . $inner->getMessage());
        }
    }

    private function loadResult(int $turnId): array
    {
        $stmt = $this->pdo->prepare('SELECT * FROM slice_turn_results WHERE turn_id = ?');
        $stmt->execute([$turnId]);
        $row = $stmt->fetch();
        if (!$row) {
            throw new ApiException('RESULT_NOT_FOUND', '结算结果不存在', 404);
        }
        $result = $this->decode((string)$row['result_json']);
        $result['result_id'] = (int)$row['id'];
        $result['content_hash'] = (string)$row['content_hash'];
        return $result;
    }

    private function computeSettlement(array $map, array $orders, array $turn, array $game): array
    {
        $factionsById = [];
        $factionOrder = [];
        foreach ($map['factions'] as $f) {
            $factionsById[(int)$f['id']] = $f;
            $factionOrder[(int)$f['id']] = (int)($f['sort_order'] ?? 0);
        }
        $nodesByCode = [];
        foreach ($map['nodes'] as $n) {
            $nodesByCode[(string)$n['node_code']] = $n;
        }

        $changes = [];
        $counts = [
            'captured' => 0,
            'defended' => 0,
            'held' => 0,
            'neutral_held' => 0,
            'no_action' => 0,
            'start_protected' => 0,
        ];
        $capturedNames = [];

        foreach ($map['nodes'] as $node) {
            $code = (string)$node['node_code'];
            $nodeName = (string)$node['name'];
            $isStart = (string)$node['node_type'] === 'start';
            $ownerBeforeId = $node['owner_faction_id'] === null ? null : (int)$node['owner_faction_id'];
            $scores = [];
            $breakdown = [];
            foreach ($factionsById as $fid => $f) {
                $scores[(string)$fid] = 0;
                $breakdown[(string)$fid] = ['advance' => 0, 'defend' => 0, 'default_defend' => 0];
            }

            $ordersAtNode = [];
            $orderDetails = [];
            foreach ($orders as $o) {
                if ((string)$o['target_node_code'] !== $code) {
                    continue;
                }
                $fid = (int)$o['faction_id'];
                if (!isset($scores[(string)$fid])) {
                    $scores[(string)$fid] = 0;
                    $breakdown[(string)$fid] = ['advance' => 0, 'defend' => 0, 'default_defend' => 0];
                }
                $action = (string)$o['action'];
                $scores[(string)$fid] += 1;
                if (isset($breakdown[(string)$fid][$action])) {
                    $breakdown[(string)$fid][$action] += 1;
                }
                $ordersAtNode[] = $o;
                $orderDetails[] = [
                    'player_id' => (int)$o['player_id'],
                    'nickname' => (string)$o['nickname'],
                    'pet_name' => (string)$o['pet_name'],
                    'faction' => $this->factionPublic($fid, $factionsById),
                    'action' => $action,
                    'is_default' => (int)$o['is_default'] === 1,
                ];
            }

            if ($ownerBeforeId !== null) {
                if (!isset($scores[(string)$ownerBeforeId])) {
                    $scores[(string)$ownerBeforeId] = 0;
                    $breakdown[(string)$ownerBeforeId] = ['advance' => 0, 'defend' => 0, 'default_defend' => 0];
                }
                $scores[(string)$ownerBeforeId] += 1;
            }

            $max = 0;
            foreach ($scores as $v) {
                if ($v > $max) {
                    $max = $v;
                }
            }
            $top = [];
            foreach ($scores as $fid => $v) {
                if ($v === $max && $max > 0) {
                    $top[] = (int)$fid;
                }
            }

            $winnerId = $ownerBeforeId;
            $reason = 'no_action';
            if ($isStart) {
                $winnerId = $ownerBeforeId;
                $reason = 'start_protected';
                $counts['start_protected']++;
            } elseif ($max <= 0) {
                $winnerId = $ownerBeforeId;
                $reason = 'no_action';
                $counts['no_action']++;
            } elseif (count($top) > 1) {
                $winnerId = $ownerBeforeId;
                $reason = $ownerBeforeId === null ? 'tie_neutral_holds' : 'tie_defender_holds';
                $counts[$ownerBeforeId === null ? 'neutral_held' : 'defended']++;
            } elseif ($top[0] === $ownerBeforeId) {
                $winnerId = $ownerBeforeId;
                $hasEnemy = false;
                foreach ($ordersAtNode as $o) {
                    if ((int)$o['faction_id'] !== $ownerBeforeId) {
                        $hasEnemy = true;
                        break;
                    }
                }
                $reason = $hasEnemy ? 'defended' : 'held';
                $counts[$hasEnemy ? 'defended' : 'held']++;
            } else {
                $winnerId = $top[0];
                $reason = 'captured';
                $counts['captured']++;
                $capturedNames[] = $nodeName;
            }

            $ownerAfterId = $isStart ? $ownerBeforeId : $winnerId;
            $ownerBefore = $this->factionPublic($ownerBeforeId, $factionsById);
            $ownerAfter = $this->factionPublic($ownerAfterId, $factionsById);
            $winner = $this->factionPublic($winnerId, $factionsById);

            $scoreRows = [];
            foreach ($scores as $fid => $points) {
                $f = $factionsById[(int)$fid] ?? null;
                if (!$f) {
                    continue;
                }
                $scoreRows[] = [
                    'faction' => $this->factionPublic((int)$fid, $factionsById),
                    'points' => (int)$points,
                    'sort_order' => $factionOrder[(int)$fid] ?? 0,
                ];
            }
            usort($scoreRows, static function (array $a, array $b): int {
                if ($a['points'] === $b['points']) {
                    return $a['sort_order'] <=> $b['sort_order'];
                }
                return $b['points'] <=> $a['points'];
            });

            $scoreText = [];
            foreach ($scoreRows as $row) {
                if ($row['points'] > 0) {
                    $scoreText[] = $row['faction']['name'] . ' ' . $row['points'];
                }
            }
            $scoreText = $scoreText === [] ? '无军令抵达' : implode('，', $scoreText);

            $reasonText = $this->reasonText(
                $reason,
                $nodeName,
                $ownerBefore,
                $ownerAfter,
                $winner,
                $scoreText
            );

            $changes[] = [
                'node_code' => $code,
                'node_name' => $nodeName,
                'is_start' => $isStart,
                'owner_before' => $ownerBefore,
                'owner_after' => $ownerAfter,
                'winner' => $winner,
                'scores' => array_combine(
                    array_map(static fn(array $row): string => $row['faction']['code'], $scoreRows),
                    array_map(static fn(array $row): int => $row['points'], $scoreRows)
                ),
                'score_rows' => $scoreRows,
                'breakdown' => array_combine(
                    array_map(static fn(array $row): string => $row['faction']['code'], $scoreRows),
                    array_map(static fn(array $row): array => $breakdown[(string)$row['faction']['id']] ?? [], $scoreRows)
                ),
                'order_details' => $orderDetails,
                'reason' => $reason,
                'reason_text' => $reasonText,
                'changed' => $ownerBeforeId !== $ownerAfterId,
            ];
        }

        $ordersPublic = [];
        foreach ($orders as $o) {
            $target = $nodesByCode[(string)$o['target_node_code']] ?? null;
            $origin = $o['origin_node_code'] !== null ? ($nodesByCode[(string)$o['origin_node_code']] ?? null) : null;
            $ordersPublic[] = [
                'player_id' => (int)$o['player_id'],
                'nickname' => (string)$o['nickname'],
                'pet_name' => (string)$o['pet_name'],
                'faction' => $this->factionPublic((int)$o['faction_id'], $factionsById),
                'action' => (string)$o['action'],
                'action_label' => match ((string)$o['action']) {
                    'advance' => '进军',
                    'defend' => '驻守',
                    default => '默认驻守',
                },
                'origin_node_code' => $o['origin_node_code'],
                'origin_name' => $origin ? (string)$origin['name'] : null,
                'target_node_code' => (string)$o['target_node_code'],
                'target_name' => $target ? (string)$target['name'] : (string)$o['target_node_code'],
                'is_default' => (int)$o['is_default'] === 1,
            ];
        }

        $standings = null;
        $isFinal = (int)$turn['turn_no'] >= $this->maxTurnsForGame((int)$game['id']);
        if ($isFinal) {
            $points = [];
            $owned = [];
            foreach ($factionsById as $fid => $f) {
                $points[(string)$fid] = 0;
                $owned[(string)$fid] = [];
            }
            foreach ($changes as $change) {
                if ($change['is_start']) {
                    continue;
                }
                $after = $change['owner_after'];
                if ($after === null) {
                    continue;
                }
                $fid = (string)$after['id'];
                $points[$fid] = ($points[$fid] ?? 0) + 1;
                $owned[$fid][] = $change['node_name'];
            }
            $maxPoints = 0;
            foreach ($points as $v) {
                $maxPoints = max($maxPoints, $v);
            }
            $winners = [];
            $rows = [];
            foreach ($factionsById as $fid => $f) {
                $rows[] = [
                    'faction' => $this->factionPublic((int)$fid, $factionsById),
                    'points' => (int)($points[(string)$fid] ?? 0),
                    'nodes' => $owned[(string)$fid] ?? [],
                ];
                if (($points[(string)$fid] ?? 0) === $maxPoints) {
                    $winners[] = $this->factionPublic((int)$fid, $factionsById);
                }
            }
            usort($rows, static function (array $a, array $b): int {
                return $b['points'] <=> $a['points'];
            });
            $standings = [
                'rows' => $rows,
                'winners' => $winners,
                'is_draw' => count($winners) !== 1,
                'max_points' => $maxPoints,
                'scoring' => '每座非起点城为归属方计 1 分；同分并列。',
            ];
        }

        $headline = '第 ' . (int)$turn['turn_no'] . ' 回合：';
        if ($capturedNames !== []) {
            $shown = array_slice($capturedNames, 0, 3);
            $headline .= implode('、', $shown) . ' 易主';
            if (count($capturedNames) > 3) {
                $headline .= ' 等';
            }
        } elseif ($counts['defended'] > 0 || $counts['neutral_held'] > 0) {
            $headline .= '诸城坚守，归属未变';
        } else {
            $headline .= '无军令抵达，地图保持原状';
        }
        if ($isFinal && $standings !== null) {
            if ($standings['is_draw']) {
                $headline .= '；三回合结束，双方同分并列';
            } else {
                $w = $standings['winners'][0];
                $headline .= '；三回合结束，' . $w['name'] . '阵营以 ' . $standings['max_points'] . ' 分领先';
            }
        }

        return [
            'turn_id' => (int)$turn['id'],
            'turn_no' => (int)$turn['turn_no'],
            'rules_version' => (string)$turn['rules_version'],
            'settled_at' => $this->nowSql(),
            'headline' => $headline,
            'summary' => $counts,
            'node_changes' => $changes,
            'orders' => $ordersPublic,
            'standings' => $standings,
            'is_final_turn' => $isFinal,
            'scoring_note' => '进军 1 点；驻守 1 点；原归属方 +1 基础守备；中立城无基础守备。',
        ];
    }

    private function reasonText(
        string $reason,
        string $nodeName,
        ?array $ownerBefore,
        ?array $ownerAfter,
        ?array $winner,
        string $scoreText
    ): string {
        $beforeName = $ownerBefore['name'] ?? '中立';
        $afterName = $ownerAfter['name'] ?? '中立';
        $winnerName = $winner['name'] ?? '无人';
        return match ($reason) {
            'start_protected' => '【' . $nodeName . '】起点受保护，归属不变。',
            'captured' => '【' . $nodeName . '】' . $scoreText . '；' . $winnerName . '夺取' . $nodeName . '。',
            'defended' => '【' . $nodeName . '】' . $scoreText . '；' . $beforeName . '守住了' . $nodeName . '。',
            'tie_defender_holds' => '【' . $nodeName . '】' . $scoreText . '；平局，原归属方' . $beforeName . '守城成功。',
            'tie_neutral_holds' => '【' . $nodeName . '】' . $scoreText . '；平局，中立城维持中立。',
            'held' => '【' . $nodeName . '】' . $scoreText . '；' . $beforeName . '继续保持' . $nodeName . '。',
            'no_action' => '【' . $nodeName . '】' . $scoreText . '；归属不变（' . $beforeName . '）。',
            default => '【' . $nodeName . '】结算完成，归属由' . $beforeName . '变为' . $afterName . '。',
        };
    }

    private function buildPlayerReports(array $computed, array $map, array $orders, array $turn): array
    {
        $changesByNode = [];
        foreach ($computed['node_changes'] as $change) {
            $changesByNode[(string)$change['node_code']] = $change;
        }
        $nodesByCode = [];
        foreach ($map['nodes'] as $n) {
            $nodesByCode[(string)$n['node_code']] = $n;
        }

        $reports = [];
        foreach ($orders as $o) {
            $playerId = (int)$o['player_id'];
            $targetCode = (string)$o['target_node_code'];
            $change = $changesByNode[$targetCode] ?? null;
            if ($change === null) {
                continue;
            }
            $myFactionId = (int)$o['faction_id'];
            $beforeId = $change['owner_before']['id'] ?? null;
            $afterId = $change['owner_after']['id'] ?? null;
            $isDefault = (int)$o['is_default'] === 1;
            $action = (string)$o['action'];
            $targetName = (string)$change['node_name'];
            $myScore = (int)($change['scores'][(string)($this->factionPublic($myFactionId, $this->indexFactions($map))['code'] ?? '')] ?? 0);

            if ($isDefault) {
                $result = $afterId === $myFactionId ? 'default_held' : 'default_lost';
            } elseif ($action === 'defend') {
                $result = $afterId === $myFactionId ? 'defend_held' : 'defend_lost';
            } else {
                if ($afterId === $myFactionId && $beforeId !== $myFactionId) {
                    $result = 'captured';
                } elseif ($afterId === $myFactionId) {
                    $result = 'reinforced';
                } elseif ($beforeId === null) {
                    $result = 'neutral_held';
                } else {
                    $result = 'failed';
                }
            }

            $text = '';
            if ($isDefault) {
                $text = $result === 'default_held'
                    ? '你未在截止前下令，系统默认驻守【' . $targetName . '】，该城仍由你方保有。'
                    : '你未在截止前下令，系统默认驻守【' . $targetName . '】，但该城本回合易主。';
            } elseif ($action === 'defend') {
                $text = $result === 'defend_held'
                    ? '你的驻守帮助【' . $targetName . '】守住。' . $change['reason_text']
                    : '你的驻守未能守住【' . $targetName . '】。' . $change['reason_text'];
            } elseif ($result === 'captured') {
                $text = '你的进军参与夺取【' . $targetName . '】。' . $change['reason_text'];
            } elseif ($result === 'reinforced') {
                $text = '你的进军增援【' . $targetName . '】，该城仍由你方保有。' . $change['reason_text'];
            } elseif ($result === 'neutral_held') {
                $text = '你的进军未能拿下【' . $targetName . '】，中立城维持中立。' . $change['reason_text'];
            } else {
                $text = '你的进军未能拿下【' . $targetName . '】。' . $change['reason_text'];
            }

            $nextHint = match ($result) {
                'captured', 'reinforced' => '该城现有 1 点基础守备；下回合单人进军只能打平，需要同伴合击。',
                'failed', 'neutral_held' => '目标有守备或双方同分；下回合可集中两路进军，或先驻守己方前沿。',
                'defend_held', 'default_held' => '守住了，但下回合仍可能被两路以上进军针对；可继续驻守或向前推进。',
                default => '查看战报中的分数拆解，再决定下回合进军或驻守。',
            };

            $reports[$playerId] = [
                'order' => [
                    'action' => $action,
                    'action_label' => $isDefault ? '默认驻守' : ($action === 'advance' ? '进军' : '驻守'),
                    'origin_node_code' => $o['origin_node_code'],
                    'target_node_code' => $targetCode,
                    'target_name' => $targetName,
                    'is_default' => $isDefault,
                ],
                'outcome' => [
                    'target_node_code' => $targetCode,
                    'target_name' => $targetName,
                    'owner_before' => $change['owner_before'],
                    'owner_after' => $change['owner_after'],
                    'winner' => $change['winner'],
                    'scores' => $change['scores'],
                    'reason' => $change['reason'],
                    'reason_text' => $change['reason_text'],
                    'result' => $result,
                    'contribution' => 1,
                    'is_default' => $isDefault,
                    'changed' => (bool)$change['changed'],
                    'next_hint' => $nextHint,
                ],
                'readable_text' => $text,
            ];
        }
        return $reports;
    }

    private function indexFactions(array $map): array
    {
        $out = [];
        foreach ($map['factions'] as $f) {
            $out[(int)$f['id']] = $f;
        }
        return $out;
    }

    // ------------------------------------------------------------------
    // 战报 / 历史 / 教师
    // ------------------------------------------------------------------

    public function getReport(array $player, int $turnId): array
    {
        $turn = $this->loadTurnById($turnId);
        $this->assertSameGame($player, $turn);
        if ((string)$turn['status'] !== 'settled') {
            throw new ApiException('REPORT_NOT_READY', '本回合尚未结算', 409, [
                'turn_status' => $turn['status'],
            ]);
        }
        $result = $this->loadResult($turnId);
        $stmt = $this->pdo->prepare(
            'SELECT * FROM slice_player_reports WHERE turn_id = ? AND player_id = ?'
        );
        $stmt->execute([$turnId, (int)$player['id']]);
        $row = $stmt->fetch();
        $me = null;
        if ($row) {
            $me = [
                'order' => $this->decode((string)$row['order_json']),
                'outcome' => $this->decode((string)$row['outcome_json']),
                'readable_text' => (string)$row['readable_text'],
            ];
        }
        $me = $me ?? [];
        $me['merit'] = (new MeritService($this->pdo))->turnSummary($turnId, (int)$player['id']);
        return [
            'turn' => $this->turnPublic($turn),
            'report' => $result,
            'me' => $me,
            'me_report' => (new PlayerReportService($this->pdo))->forTurn(
                (int)$player['game_id'],
                (int)$player['id'],
                $turnId
            ),
        ];
    }

    public function getHistory(array $player, int $limit = 10): array
    {
        $stmt = $this->pdo->prepare(
            'SELECT * FROM slice_turns WHERE game_id = ? ORDER BY turn_no DESC LIMIT ' . max(1, min(30, $limit))
        );
        $stmt->execute([(int)$player['game_id']]);
        $turns = [];
        foreach ($stmt->fetchAll() as $turn) {
            $item = $this->turnPublic($turn);
            $item['headline'] = null;
            $item['my_report'] = null;
            $stmt2 = $this->pdo->prepare('SELECT result_json FROM slice_turn_results WHERE turn_id = ?');
            $stmt2->execute([(int)$turn['id']]);
            $resultJson = $stmt2->fetchColumn();
            if ($resultJson !== false) {
                $decoded = $this->decode((string)$resultJson);
                $item['headline'] = (string)($decoded['headline'] ?? '');
                if ($item['headline'] === '' && isset($decoded['battles'])) {
                    $battles = is_array($decoded['battles']) ? $decoded['battles'] : [];
                    $captures = count(array_filter($battles, static fn($b) => !empty($b['captured'])));
                    $item['headline'] = sprintf(
                        '第 %d 回合：%d 场战斗，%d 城易主',
                        (int)$turn['turn_no'],
                        count($battles),
                        $captures
                    );
                }
            }
            $stmt2 = $this->pdo->prepare(
                'SELECT readable_text FROM slice_player_reports WHERE turn_id = ? AND player_id = ?'
            );
            $stmt2->execute([(int)$turn['id'], (int)$player['id']]);
            $text = $stmt2->fetchColumn();
            if ($text !== false) {
                $item['my_report'] = (string)$text;
            }
            $turns[] = $item;
        }
        return ['turns' => $turns];
    }

    public function adminStatus(array $teacher): array
    {
        $this->requireTeacher($teacher);
        $game = $this->loadGame((int)$teacher['game_id']);
        $stmt = $this->pdo->prepare('SELECT * FROM slice_turns WHERE game_id = ? ORDER BY turn_no');
        $stmt->execute([(int)$game['id']]);
        $turns = [];
        foreach ($stmt->fetchAll() as $turn) {
            $isCard = $this->usesCardRules((int)$game['id'], (int)$turn['id']);
            if ($isCard) {
                $stmt2 = $this->pdo->prepare(
                    'SELECT COUNT(*), COUNT(DISTINCT player_id) FROM slice_order_slots
                     WHERE turn_id = ? AND status = "active"'
                );
                $stmt2->execute([(int)$turn['id']]);
                [$activeOrders, $activePlayers] = array_map('intval', $stmt2->fetch(PDO::FETCH_NUM));
                $stmt2 = $this->pdo->prepare(
                    'SELECT COUNT(*) FROM slice_order_slots WHERE turn_id = ? AND status = "withdrawn"'
                );
                $stmt2->execute([(int)$turn['id']]);
                $withdrawn = (int)$stmt2->fetchColumn();
            } else {
                $stmt2 = $this->pdo->prepare(
                    'SELECT COUNT(*) FROM slice_orders WHERE turn_id = ? AND status = "active"'
                );
                $stmt2->execute([(int)$turn['id']]);
                $activeOrders = (int)$stmt2->fetchColumn();
                $activePlayers = $activeOrders;
                $stmt2 = $this->pdo->prepare(
                    'SELECT COUNT(*) FROM slice_orders WHERE turn_id = ? AND status = "withdrawn"'
                );
                $stmt2->execute([(int)$turn['id']]);
                $withdrawn = (int)$stmt2->fetchColumn();
            }
            $stmt2 = $this->pdo->prepare('SELECT * FROM slice_settlement_jobs WHERE turn_id = ?');
            $stmt2->execute([(int)$turn['id']]);
            $job = $stmt2->fetch();
            $stmt2 = $this->pdo->prepare('SELECT result_json FROM slice_turn_results WHERE turn_id = ?');
            $stmt2->execute([(int)$turn['id']]);
            $resultJson = $stmt2->fetchColumn();
            $headline = null;
            if ($resultJson !== false) {
                $decoded = $this->decode((string)$resultJson);
                $headline = (string)($decoded['headline'] ?? '');
                if ($headline === '' && isset($decoded['battles'])) {
                    $battles = is_array($decoded['battles']) ? $decoded['battles'] : [];
                    $captures = count(array_filter($battles, static fn($b) => !empty($b['captured'])));
                    $headline = sprintf(
                        '第 %d 回合：%d 场战斗，%d 城易主',
                        (int)$turn['turn_no'],
                        count($battles),
                        $captures
                    );
                }
            }
            $turns[] = [
                'turn' => $this->turnPublic($turn),
                'active_orders' => $activeOrders,
                'active_players' => $activePlayers,
                'withdrawn_orders' => $withdrawn,
                'job' => $job === false ? null : [
                    'status' => (string)$job['status'],
                    'attempts' => (int)$job['attempts'],
                    'last_error' => $job['last_error'],
                    'started_at' => $job['started_at'],
                    'finished_at' => $job['finished_at'],
                ],
                'headline' => $headline,
            ];
        }
        $stmt = $this->pdo->prepare(
            'SELECT COUNT(*) FROM slice_players WHERE game_id = ? AND role = "player" AND is_active = 1'
        );
        $stmt->execute([(int)$game['id']]);
        return [
            'game' => [
                'id' => (int)$game['id'],
                'code' => (string)$game['code'],
                'name' => (string)$game['name'],
                'status' => (string)$game['status'],
                'current_turn_id' => $game['current_turn_id'] === null ? null : (int)$game['current_turn_id'],
            ],
            'participants' => (int)$stmt->fetchColumn(),
            'turns' => $turns,
            'server_time' => $this->nowSql(),
        ];
    }

    private function maxTurnsForGame(int $gameId): int
    {
        $stmt = $this->pdo->prepare('SELECT COUNT(*) FROM slice_nodes WHERE game_id = ?');
        $stmt->execute([$gameId]);
        return (int)$stmt->fetchColumn() >= 13 ? 28 : 3;
    }

    private function usesCardRules(int $gameId, int $turnId = 0): bool
    {
        $stmt = $this->pdo->prepare('SELECT rules_version FROM slice_games WHERE id = ?');
        $stmt->execute([$gameId]);
        if ((string)$stmt->fetchColumn() === 'cards_v1') {
            return true;
        }
        $stmt = $this->pdo->prepare('SELECT COUNT(*) FROM slice_nodes WHERE game_id = ?');
        $stmt->execute([$gameId]);
        if ((int)$stmt->fetchColumn() >= 13) {
            return true;
        }
        if ($turnId > 0) {
            $stmt = $this->pdo->prepare(
                'SELECT COUNT(*) FROM slice_order_slots WHERE turn_id = ? AND status = "active"'
            );
            $stmt->execute([$turnId]);
            if ((int)$stmt->fetchColumn() > 0) {
                return true;
            }
        }
        return false;
    }

    public function nextTurn(array $teacher, int $fromTurnId): array
    {        $this->requireTeacher($teacher);
        $this->pdo->beginTransaction();
        try {
            $from = $this->loadTurnById($fromTurnId, true);
            $this->assertSameGame($teacher, $from);
            $game = $this->loadGame((int)$from['game_id']);
            if ((string)$game['status'] === 'finished') {
                throw new ApiException('SEASON_FINISHED', '赛季已结束，不能开启新回合', 409);
            }
            if ((string)$from['status'] !== 'settled') {
                throw new ApiException('SETTLE_NOT_READY', '当前回合尚未结算，不能进入下一回合', 409);
            }
            if ((int)$from['turn_no'] >= $this->maxTurnsForGame((int)$game['id'])) {
                throw new ApiException('SEASON_FINISHED', '赛季已结束；请查看最终战报或重置演示', 409);
            }            $stmt = $this->pdo->prepare('SELECT * FROM slice_turns WHERE game_id = ? AND turn_no = ? LIMIT 1');
            $stmt->execute([(int)$game['id'], (int)$from['turn_no'] + 1]);
            $existing = $stmt->fetch();
            if ($existing) {
                $this->pdo->commit();
                return ['created' => false, 'turn' => $this->turnPublic($existing)];
            }

            $now = $this->clock->now();
            $opens = $now->format('Y-m-d H:i:s');
            $deadline = $now->modify('+' . (int)$game['turn_seconds'] . ' seconds')->format('Y-m-d H:i:s');
            $stmt = $this->pdo->prepare(
                'INSERT INTO slice_turns (game_id, turn_no, status, opens_at, deadline_at, rules_version)
                 VALUES (?, ?, "open", ?, ?, ?)'
            );
            $stmt->execute([
                (int)$game['id'],
                (int)$from['turn_no'] + 1,
                $opens,
                $deadline,
                (string)$game['rules_version'],
            ]);
            $newTurnId = (int)$this->pdo->lastInsertId();
            $newTurnNo = (int)$from['turn_no'] + 1;
            if ($newTurnNo % 7 === 1) {
                (new EstateService($this->pdo))->refreshGovernors(
                    (int)$game['id'],
                    Clock::weekOfTurn($newTurnNo - 1)
                );
            }
            $stmt = $this->pdo->prepare('UPDATE slice_games SET current_turn_id = ? WHERE id = ?');
            $stmt->execute([$newTurnId, (int)$game['id']]);
            $this->audit((int)$game['id'], $newTurnId, (int)$teacher['id'], 'turn.next', [
                'from_turn' => (int)$from['turn_no'],
                'to_turn' => (int)$from['turn_no'] + 1,
                'deadline_at' => $deadline,
            ]);
            $this->pdo->commit();
            $turn = $this->loadTurnById($newTurnId);
            return ['created' => true, 'turn' => $this->turnPublic($turn)];
        } catch (Throwable $e) {
            if ($this->pdo->inTransaction()) {
                $this->pdo->rollBack();
            }
            throw $e;
        }
    }

    public function setGameStatus(array $teacher, string $status): array
    {
        $this->requireTeacher($teacher);
        if (!in_array($status, ['running', 'paused'], true)) {
            throw new ApiException('BAD_REQUEST', '只支持 running / paused');
        }
        $game = $this->loadGame((int)$teacher['game_id']);
        if ((string)$game['status'] === 'finished') {
            throw new ApiException('SEASON_FINISHED', '切片已结束，不能切换暂停状态', 409);
        }
        $stmt = $this->pdo->prepare('UPDATE slice_games SET status = ? WHERE id = ?');
        $stmt->execute([$status, (int)$game['id']]);
        $this->audit((int)$game['id'], null, (int)$teacher['id'], 'game.status', ['status' => $status]);
        return ['status' => $status];
    }

    /**
     * 定时任务：对已过截止时间的回合执行锁令与结算。
     * 仅处理 running 测试局；教师账号只作为审计 actor，不需要登录。
     */
    public function runDueTurns(bool $settle = true): array
    {
        $stmt = $this->pdo->prepare(
            'SELECT t.* FROM slice_turns t
             JOIN slice_games g ON g.id = t.game_id
             WHERE g.status = "running"
               AND t.status IN ("open","locked","failed")
               AND t.deadline_at <= ?
             ORDER BY t.game_id, t.turn_no'
        );
        $stmt->execute([$this->nowSql()]);
        $turns = $stmt->fetchAll();
        $results = [];
        foreach ($turns as $turn) {
            $gameId = (int)$turn['game_id'];
            $stmt = $this->pdo->prepare(
                'SELECT p.id FROM slice_players p
                 WHERE p.game_id = ? AND p.role = "teacher" AND p.is_active = 1
                 ORDER BY p.id LIMIT 1'
            );
            $stmt->execute([$gameId]);
            $teacherId = $stmt->fetchColumn();
            if ($teacherId === false) {
                $results[] = [
                    'turn_id' => (int)$turn['id'],
                    'turn_no' => (int)$turn['turn_no'],
                    'ok' => false,
                    'error' => 'NO_TEACHER_ACTOR',
                ];
                continue;
            }
            try {
                $teacher = $this->loadPlayerById((int)$teacherId);
                $lock = null;
                if ((string)$turn['status'] === 'open') {
                    $lock = $this->lockTurn($teacher, (int)$turn['id'], false);
                }
                $result = null;
                if ($settle) {
                    if ($this->usesCardRules($gameId, (int)$turn['id'])) {
                        $result = (new CardSettlementService($this->pdo))->settle($gameId, (int)$turn['id']);
                        if ((int)$turn['turn_no'] % 7 === 0) {
                            (new EstateService($this->pdo))->refreshGovernors(
                                $gameId,
                                Clock::weekOfTurn((int)$turn['turn_no'])
                            );
                        }
                    } else {
                        $result = $this->settleTurn($teacher, (int)$turn['id']);
                    }
                }
                $results[] = [
                    'turn_id' => (int)$turn['id'],
                    'turn_no' => (int)$turn['turn_no'],
                    'ok' => true,
                    'locked' => $lock !== null,
                    'settled' => $result !== null,
                    'result_id' => $result['result_id'] ?? null,
                    'headline' => $result['headline'] ?? null,
                ];
            } catch (Throwable $e) {
                $results[] = [
                    'turn_id' => (int)$turn['id'],
                    'turn_no' => (int)$turn['turn_no'],
                    'ok' => false,
                    'error' => $e->getMessage(),
                ];
            }
        }
        return [
            'checked_at' => $this->nowSql(),
            'due_turns' => count($turns),
            'results' => $results,
        ];
    }

    /**
     * 正式版 24 小时周期：每天 06:00–09:00 自动开下一回合。
     * 试跑 600 秒短周期不走这里，避免十分钟一回合。
     *
     * @return array{checked_at:string,opened:int,results:array}
     */
    public function autoOpenDailyTurns(?int $hourOverride = null): array
    {
        $hour = $hourOverride ?? (int)$this->clock->now()->format('G');
        if ($hour < 6 || $hour >= 9) {
            return ['checked_at' => $this->nowSql(), 'opened' => 0, 'results' => [], 'skipped' => 'OUTSIDE_WINDOW'];
        }

        $stmt = $this->pdo->prepare(
            'SELECT g.id AS game_id, t.id AS turn_id, t.turn_no, t.status
             FROM slice_games g
             JOIN slice_turns t ON t.id = g.current_turn_id
             WHERE g.status = "running" AND g.turn_seconds >= 3600
               AND t.status = "settled"
             ORDER BY g.id'
        );
        $stmt->execute();
        $results = [];
        foreach ($stmt->fetchAll() as $row) {
            $gameId = (int)$row['game_id'];
            $stmt = $this->pdo->prepare(
                'SELECT id FROM slice_players WHERE game_id = ? AND role = "teacher" AND is_active = 1 ORDER BY id LIMIT 1'
            );
            $stmt->execute([$gameId]);
            $teacherId = (int)$stmt->fetchColumn();
            if ($teacherId <= 0) {
                $results[] = ['game_id' => $gameId, 'ok' => false, 'error' => 'NO_TEACHER_ACTOR'];
                continue;
            }
            try {
                $teacher = $this->loadPlayerById($teacherId);
                $created = $this->nextTurn($teacher, (int)$row['turn_id']);
                $results[] = [
                    'game_id' => $gameId,
                    'ok' => true,
                    'created' => (bool)($created['created'] ?? false),
                    'turn_no' => (int)($created['turn']['turn_no'] ?? 0),
                ];
            } catch (Throwable $e) {
                $results[] = ['game_id' => $gameId, 'ok' => false, 'error' => $e->getMessage()];
            }
        }
        return ['checked_at' => $this->nowSql(), 'opened' => count($results), 'results' => $results];
    }

    /**
     * 战局回放：按回合返回地图归属快照，客户端逐回合播放。
     * 只读已结算回合，不重新计算。
     */
    public function getReplay(array $player): array
    {
        $game = $this->loadGame((int)$player['game_id']);

        $stmt = $this->pdo->prepare('SELECT * FROM slice_factions WHERE game_id = ? ORDER BY sort_order, id');
        $stmt->execute([(int)$game['id']]);
        $factionsById = [];
        foreach ($stmt->fetchAll() as $f) {
            $factionsById[(int)$f['id']] = $f;
        }

        $stmt = $this->pdo->prepare('SELECT * FROM slice_nodes WHERE game_id = ? ORDER BY sort_order, id');
        $stmt->execute([(int)$game['id']]);
        $nodes = [];
        $owners = [];
        $nodeNames = [];
        foreach ($stmt->fetchAll() as $n) {
            $code = (string)$n['node_code'];
            $nodeNames[$code] = (string)$n['name'];
            $nodes[] = [
                'code' => $code,
                'name' => (string)$n['name'],
                'x' => (int)$n['x'],
                'y' => (int)$n['y'],
                'type' => (string)$n['node_type'],
            ];
            $owners[$code] = $this->factionPublic(
                $n['owner_faction_id'] === null ? null : (int)$n['owner_faction_id'],
                $factionsById
            );
        }

        $stmt = $this->pdo->prepare('SELECT a_node_code, b_node_code FROM slice_edges WHERE game_id = ? ORDER BY id');
        $stmt->execute([(int)$game['id']]);
        $edges = [];
        foreach ($stmt->fetchAll() as $e) {
            $edges[] = [(string)$e['a_node_code'], (string)$e['b_node_code']];
        }

        $stmt = $this->pdo->prepare(
            'SELECT t.id AS turn_id, t.turn_no, t.settled_at, r.result_json
             FROM slice_turn_results r
             JOIN slice_turns t ON t.id = r.turn_id
             WHERE r.game_id = ? AND t.status = "settled"
             ORDER BY t.turn_no'
        );
        $stmt->execute([(int)$game['id']]);
        $turns = [];
        foreach ($stmt->fetchAll() as $row) {
            $result = $this->decode((string)$row['result_json']);
            $changeRows = $result['node_changes'] ?? [];
            if ($changeRows === [] && isset($result['battles'])) {
                foreach ((array)$result['battles'] as $battle) {
                    if (empty($battle['battle_id'])) {
                        continue;
                    }
                    $code = (string)($battle['node_code'] ?? '');
                    if ($code === '') {
                        continue;
                    }
                    $before = $battle['owner_before'] ?? null;
                    $after = $battle['owner_after'] ?? null;
                    $changeRows[] = [
                        'node_code' => $code,
                        'node_name' => $nodeNames[$code] ?? $code,
                        'owner_before' => $before === null ? null : $this->factionPublic((int)$before, $factionsById),
                        'owner_after' => $after === null ? null : $this->factionPublic((int)$after, $factionsById),
                        'scores' => ['score' => (int)($battle['score'] ?? 0)],
                        'reason' => (string)($battle['reason'] ?? (!empty($battle['captured']) ? 'captured' : 'hold')),
                        'reason_text' => (string)($battle['reason'] ?? ''),
                        'changed' => $before !== $after,
                    ];
                }
            }
            $changes = [];
            foreach ($changeRows as $change) {
                $code = (string)$change['node_code'];
                $owners[$code] = $change['owner_after'];
                $changes[] = [
                    'node_code' => $code,
                    'node_name' => (string)$change['node_name'],
                    'owner_before' => $change['owner_before'],
                    'owner_after' => $change['owner_after'],
                    'scores' => $change['scores'],
                    'reason' => (string)$change['reason'],
                    'reason_text' => (string)$change['reason_text'],
                    'changed' => (bool)$change['changed'],
                ];
            }
            $headline = (string)($result['headline'] ?? '');
            if ($headline === '' && isset($result['battles'])) {
                $battles = (array)$result['battles'];
                $captures = count(array_filter($battles, static fn($b) => !empty($b['captured'])));
                $headline = sprintf(
                    '第 %d 回合：%d 场战斗，%d 城易主',
                    (int)$row['turn_no'],
                    count($battles),
                    $captures
                );
            }
            $turns[] = [
                'turn_id' => (int)$row['turn_id'],
                'turn_no' => (int)$row['turn_no'],
                'settled_at' => (string)$row['settled_at'],
                'headline' => $headline,
                'changes' => $changes,
                'owners' => $owners,
                'standings' => $result['standings'] ?? null,
            ];
        }

        return [
            'game' => [
                'code' => (string)$game['code'],
                'name' => (string)$game['name'],
            ],
            'nodes' => $nodes,
            'edges' => $edges,
            'turns' => $turns,
        ];
    }

    public function getWalletForPlayer(array $player): array
    {
        if ($player['student_id'] === null) {
            throw new ApiException('FORBIDDEN', '教师账号没有学生积分钱包', 403);
        }
        return $this->points->getWallet((int)$player['student_id']);
    }

    public function rechargePlayer(array $player, int $points, string $requestKey): array
    {
        if ($player['student_id'] === null) {
            throw new ApiException('FORBIDDEN', '教师账号不能兑换学生积分', 403);
        }
        return $this->points->recharge(
            (int)$player['student_id'],
            $points,
            $requestKey,
            (int)$player['game_id'],
            (int)$player['id']
        );
    }

    public function health(): array
    {
        $this->pdo->query('SELECT 1');
        $count = (int)$this->pdo->query('SELECT COUNT(*) FROM slice_games')->fetchColumn();
        return [
            'ok' => true,
            'server_time' => $this->nowSql(),
            'games' => $count,
            'php' => PHP_VERSION,
        ];
    }
}
