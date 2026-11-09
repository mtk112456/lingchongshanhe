-- 三回合切片测试种子：5 节点、2 个对称起点、3 个中立争夺点、8 名试验玩家 + 1 名教师。
-- 仅用于独立测试库。密码均为测试密码，不得用于生产。

SET NAMES utf8mb4;
SET time_zone = '+08:00';

INSERT INTO slice_games (code, name, status, rules_version, turn_seconds)
VALUES ('SLICE_A', '三回合切片·云麓试锋', 'running', 'A1', 600);
SET @game_id = LAST_INSERT_ID();

INSERT INTO slice_factions (game_id, code, name, color, start_node_code, sort_order) VALUES
  (@game_id, 'bi', '笔', '#B83B32', 'A_START', 1),
  (@game_id, 'mo', '墨', '#1E3A5F', 'B_START', 2);
SET @bi = (SELECT id FROM slice_factions WHERE game_id = @game_id AND code = 'bi');
SET @mo = (SELECT id FROM slice_factions WHERE game_id = @game_id AND code = 'mo');

INSERT INTO slice_nodes (game_id, node_code, name, x, y, node_type, owner_faction_id, initial_owner_faction_id, sort_order) VALUES
  (@game_id, 'A_START', '云麓关', 150, 320, 'start',   @bi, @bi, 1),
  (@game_id, 'N1',      '松风渡', 350, 160, 'neutral', NULL, NULL, 2),
  (@game_id, 'N2',      '落霞原', 500, 360, 'neutral', NULL, NULL, 3),
  (@game_id, 'N3',      '听雨台', 650, 160, 'neutral', NULL, NULL, 4),
  (@game_id, 'B_START', '雁回关', 850, 320, 'start',   @mo, @mo, 5);

-- 无向边；A↔N1,N2；B↔N2,N3；N1↔N2,N3；N2↔N3。
INSERT INTO slice_edges (game_id, a_node_code, b_node_code) VALUES
  (@game_id, 'A_START', 'N1'),
  (@game_id, 'A_START', 'N2'),
  (@game_id, 'B_START', 'N2'),
  (@game_id, 'B_START', 'N3'),
  (@game_id, 'N1', 'N2'),
  (@game_id, 'N1', 'N3'),
  (@game_id, 'N2', 'N3');

-- 玩家身份直接指向现有 students.id；教师指向现有 admin.id。不复制密码。
SET @stu1 = (SELECT id FROM students WHERE show_name = '青竹一');
SET @stu2 = (SELECT id FROM students WHERE show_name = '青竹二');
SET @stu3 = (SELECT id FROM students WHERE show_name = '青竹三');
SET @stu4 = (SELECT id FROM students WHERE show_name = '青竹四');
SET @stu5 = (SELECT id FROM students WHERE show_name = '墨点一');
SET @stu6 = (SELECT id FROM students WHERE show_name = '墨点二');
SET @stu7 = (SELECT id FROM students WHERE show_name = '墨点三');
SET @stu8 = (SELECT id FROM students WHERE show_name = '墨点四');
SET @admin = (SELECT id FROM admin WHERE username = 'teacher');

INSERT INTO slice_players
  (game_id, student_id, admin_id, faction_id, nickname, role, pet_instance_id, pet_code, pet_name, is_active)
VALUES
  (@game_id, @stu1, NULL,   @bi, '青竹一', 'player', (SELECT id FROM student_pets WHERE student_id = @stu1), 'pet_bamboo_01',  '小青竹·一', 1),
  (@game_id, @stu2, NULL,   @bi, '青竹二', 'player', (SELECT id FROM student_pets WHERE student_id = @stu2), 'pet_bamboo_01',  '小青竹·二', 1),
  (@game_id, @stu3, NULL,   @bi, '青竹三', 'player', (SELECT id FROM student_pets WHERE student_id = @stu3), 'pet_bamboo_01',  '小青竹·三', 1),
  (@game_id, @stu4, NULL,   @bi, '青竹四', 'player', (SELECT id FROM student_pets WHERE student_id = @stu4), 'pet_bamboo_01',  '小青竹·四', 1),
  (@game_id, @stu5, NULL,   @mo, '墨点一', 'player', (SELECT id FROM student_pets WHERE student_id = @stu5), 'pet_inkdrop_01', '墨点精·一', 1),
  (@game_id, @stu6, NULL,   @mo, '墨点二', 'player', (SELECT id FROM student_pets WHERE student_id = @stu6), 'pet_inkdrop_01', '墨点精·二', 1),
  (@game_id, @stu7, NULL,   @mo, '墨点三', 'player', (SELECT id FROM student_pets WHERE student_id = @stu7), 'pet_inkdrop_01', '墨点精·三', 1),
  (@game_id, @stu8, NULL,   @mo, '墨点四', 'player', (SELECT id FROM student_pets WHERE student_id = @stu8), 'pet_inkdrop_01', '墨点精·四', 1),
  (@game_id, NULL,   @admin, NULL, '先生', 'teacher', NULL, 'mentor', '先生', 1);

INSERT INTO slice_turns (game_id, turn_no, status, opens_at, deadline_at, rules_version)
VALUES (@game_id, 1, 'open', NOW(), DATE_ADD(NOW(), INTERVAL 600 SECOND), 'A1');
SET @turn_id = LAST_INSERT_ID();

UPDATE slice_games SET current_turn_id = @turn_id WHERE id = @game_id;

INSERT INTO slice_audit_log (game_id, turn_id, action, detail_json)
VALUES (@game_id, @turn_id, 'seed', JSON_OBJECT('game', 'SLICE_A', 'nodes', 5, 'players', 8, 'turn_seconds', 600));
