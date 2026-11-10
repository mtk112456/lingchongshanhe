<?php
declare(strict_types=1);

/**
 * 给试跑库补 4 名学生，凑成 12 人自测。
 * 只用于 qingzhu_slice_trial，不碰生产库。
 */

require_once dirname(__DIR__) . '/bootstrap.php';

[$config, $pdo] = slice_bootstrap();

$stmt = $pdo->prepare("SELECT id FROM slice_games WHERE code = 'SLICE_A' LIMIT 1");
$stmt->execute();
$gameId = (int)$stmt->fetchColumn();
if ($gameId <= 0) {
    fwrite(STDERR, "SLICE_A 不存在，请先重建试跑库\n");
    exit(1);
}

$factionStmt = $pdo->prepare('SELECT id, code FROM slice_factions WHERE game_id = ?');
$factionStmt->execute([$gameId]);
$factions = [];
foreach ($factionStmt->fetchAll() as $f) {
    $factions[(string)$f['code']] = (int)$f['id'];
}

$password = (string)$pdo->query('SELECT password FROM students ORDER BY id LIMIT 1')->fetchColumn();
$petTemplateId = (int)$pdo->query('SELECT id FROM pet_templates ORDER BY id LIMIT 1')->fetchColumn();
$petCode = (string)$pdo->query('SELECT code FROM pet_templates ORDER BY id LIMIT 1')->fetchColumn();

$extra = [
    ['青竹五', 'bi'],
    ['青竹六', 'bi'],
    ['墨点五', 'mo'],
    ['墨点六', 'mo'],
];

$insertStudent = $pdo->prepare(
    "INSERT INTO students (id_card, class_id, name, show_name, password, score)
     VALUES (?, 1, ?, ?, ?, 100)"
);
$insertPet = $pdo->prepare(
    'INSERT INTO student_pets (student_id, pet_template_id, nickname, level, hunger, mood)
     VALUES (?, ?, ?, 10, 100, 100)'
);
$insertPlayer = $pdo->prepare(
    'INSERT INTO slice_players
        (game_id, student_id, admin_id, faction_id, nickname, role, pet_instance_id, pet_code, pet_name, is_active)
     VALUES (?, ?, NULL, ?, ?, "player", ?, ?, ?, 1)'
);

foreach ($extra as $i => [$name, $faction]) {
    $stmt = $pdo->prepare('SELECT id FROM students WHERE show_name = ? OR name = ? LIMIT 1');
    $stmt->execute([$name, $name]);
    $studentId = (int)$stmt->fetchColumn();
    if ($studentId <= 0) {
        $insertStudent->execute(['TRIAL12' . sprintf('%02d', $i + 1), $name, $name, $password]);
        $studentId = (int)$pdo->lastInsertId();
        $insertPet->execute([$studentId, $petTemplateId, $name]);
        $petId = (int)$pdo->lastInsertId();
        $insertPlayer->execute([
            $gameId,
            $studentId,
            $factions[$faction] ?? 0,
            $name,
            $petId,
            $petCode,
            $name,
        ]);
        echo "added {$name} ({$faction}) student={$studentId}\n";
    } else {
        echo "exists {$name} student={$studentId}\n";
    }
}

echo 'players=' . $pdo->query("SELECT COUNT(*) FROM slice_players WHERE game_id = {$gameId} AND role = 'player'")->fetchColumn() . PHP_EOL;
