-- 12+1 城测试种子：4 阵营、13 节点、16 条邻接、8 名学生（每阵营 2 人）。
-- 仅用于独立测试库；游戏状态 paused，不抢 5 节点切片的登录。

SET NAMES utf8mb4;
SET time_zone = '+08:00';

DELETE FROM slice_games WHERE code = 'MAP12_TEST';

INSERT INTO slice_games (code, name, status, rules_version, turn_seconds)
VALUES ('MAP12_TEST', '12+1 城·九州测试', 'paused', 'cards_v1', 600);
SET @game_id = LAST_INSERT_ID();

INSERT INTO slice_factions (game_id, code, name, color, start_node_code, sort_order) VALUES
  (@game_id, 'bi',  '笔', '#B83B32', 'liangzhou', 1),
  (@game_id, 'mo',  '墨', '#1E3A5F', 'yecheng',   2),
  (@game_id, 'yan', '砚', '#276F57', 'chengdu',   3),
  (@game_id, 'zhi', '纸', '#C9A227', 'jianye',    4);
SET @bi  = (SELECT id FROM slice_factions WHERE game_id = @game_id AND code = 'bi');
SET @mo  = (SELECT id FROM slice_factions WHERE game_id = @game_id AND code = 'mo');
SET @yan = (SELECT id FROM slice_factions WHERE game_id = @game_id AND code = 'yan');
SET @zhi = (SELECT id FROM slice_factions WHERE game_id = @game_id AND code = 'zhi');

INSERT INTO slice_nodes
  (game_id, node_code, name, x, y, node_type, owner_faction_id, initial_owner_faction_id, morale, sort_order)
VALUES
  (@game_id, 'liangzhou', '凉州',   688,  461, 'camp',    @bi,  @bi,  0, 1),
  (@game_id, 'hanzhong',  '汉中',  1229,  654, 'pass',    @bi,  @bi,  0, 2),
  (@game_id, 'xiangyang', '襄阳',   946, 1038, 'pass',    @bi,  @bi,  0, 3),
  (@game_id, 'yecheng',   '邺城',  2679,  488, 'camp',    @mo,  @mo,  0, 4),
  (@game_id, 'taiyuan',   '太原',  3449,  685, 'culture', @mo,  @mo,  0, 5),
  (@game_id, 'luoyang',   '洛阳',  3019, 1032, 'culture', @mo,  @mo,  0, 6),
  (@game_id, 'chengdu',   '成都',   733, 1908, 'camp',    @yan, @yan, 0, 7),
  (@game_id, 'jiangling', '江陵',  1094, 2107, 'ferry',   @yan, @yan, 0, 8),
  (@game_id, 'changsha',  '长沙',   905, 2451, 'culture', @yan, @yan, 0, 9),
  (@game_id, 'jianye',    '建业',  3285, 1908, 'camp',    @zhi, @zhi, 0, 10),
  (@game_id, 'kuaiji',    '会稽',  3060, 2239, 'water',   @zhi, @zhi, 0, 11),
  (@game_id, 'shouchun',  '寿春',  2884, 2559, 'pass',    @zhi, @zhi, 0, 12),
  (@game_id, 'changan',   '长安',  2048, 1536, 'king',    NULL, NULL, 0, 13);

-- 4 个区域三角 + 4 条主城通长安 = 16 条
INSERT INTO slice_edges (game_id, a_node_code, b_node_code) VALUES
  (@game_id, 'liangzhou', 'hanzhong'),
  (@game_id, 'hanzhong',  'xiangyang'),
  (@game_id, 'xiangyang', 'liangzhou'),
  (@game_id, 'yecheng',   'taiyuan'),
  (@game_id, 'taiyuan',   'luoyang'),
  (@game_id, 'luoyang',   'yecheng'),
  (@game_id, 'chengdu',   'jiangling'),
  (@game_id, 'jiangling', 'changsha'),
  (@game_id, 'changsha',  'chengdu'),
  (@game_id, 'jianye',    'kuaiji'),
  (@game_id, 'kuaiji',    'shouchun'),
  (@game_id, 'shouchun',  'jianye'),
  (@game_id, 'hanzhong',  'changan'),
  (@game_id, 'luoyang',   'changan'),
  (@game_id, 'jiangling', 'changan'),
  (@game_id, 'jianye',    'changan');

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
  (@game_id, @stu1, NULL, @bi,  '青竹一', 'player',
    (SELECT id FROM student_pets WHERE student_id = @stu1),
    (SELECT pt.code FROM student_pets sp JOIN pet_templates pt ON pt.id = sp.pet_template_id WHERE sp.student_id = @stu1),
    (SELECT nickname FROM student_pets WHERE student_id = @stu1), 1),
  (@game_id, @stu2, NULL, @bi,  '青竹二', 'player',
    (SELECT id FROM student_pets WHERE student_id = @stu2),
    (SELECT pt.code FROM student_pets sp JOIN pet_templates pt ON pt.id = sp.pet_template_id WHERE sp.student_id = @stu2),
    (SELECT nickname FROM student_pets WHERE student_id = @stu2), 1),
  (@game_id, @stu3, NULL, @mo,  '青竹三', 'player',
    (SELECT id FROM student_pets WHERE student_id = @stu3),
    (SELECT pt.code FROM student_pets sp JOIN pet_templates pt ON pt.id = sp.pet_template_id WHERE sp.student_id = @stu3),
    (SELECT nickname FROM student_pets WHERE student_id = @stu3), 1),
  (@game_id, @stu4, NULL, @mo,  '青竹四', 'player',
    (SELECT id FROM student_pets WHERE student_id = @stu4),
    (SELECT pt.code FROM student_pets sp JOIN pet_templates pt ON pt.id = sp.pet_template_id WHERE sp.student_id = @stu4),
    (SELECT nickname FROM student_pets WHERE student_id = @stu4), 1),
  (@game_id, @stu5, NULL, @yan, '墨点一', 'player',
    (SELECT id FROM student_pets WHERE student_id = @stu5),
    (SELECT pt.code FROM student_pets sp JOIN pet_templates pt ON pt.id = sp.pet_template_id WHERE sp.student_id = @stu5),
    (SELECT nickname FROM student_pets WHERE student_id = @stu5), 1),
  (@game_id, @stu6, NULL, @yan, '墨点二', 'player',
    (SELECT id FROM student_pets WHERE student_id = @stu6),
    (SELECT pt.code FROM student_pets sp JOIN pet_templates pt ON pt.id = sp.pet_template_id WHERE sp.student_id = @stu6),
    (SELECT nickname FROM student_pets WHERE student_id = @stu6), 1),
  (@game_id, @stu7, NULL, @zhi, '墨点三', 'player',
    (SELECT id FROM student_pets WHERE student_id = @stu7),
    (SELECT pt.code FROM student_pets sp JOIN pet_templates pt ON pt.id = sp.pet_template_id WHERE sp.student_id = @stu7),
    (SELECT nickname FROM student_pets WHERE student_id = @stu7), 1),
  (@game_id, @stu8, NULL, @zhi, '墨点四', 'player',
    (SELECT id FROM student_pets WHERE student_id = @stu8),
    (SELECT pt.code FROM student_pets sp JOIN pet_templates pt ON pt.id = sp.pet_template_id WHERE sp.student_id = @stu8),
    (SELECT nickname FROM student_pets WHERE student_id = @stu8), 1),
  (@game_id, NULL, @admin, NULL, '先生', 'teacher', NULL, 'mentor', '先生', 1);

INSERT INTO slice_turns (game_id, turn_no, status, opens_at, deadline_at, rules_version)
VALUES (@game_id, 1, 'open', NOW(), DATE_ADD(NOW(), INTERVAL 600 SECOND), 'cards_v1');
SET @turn_id = LAST_INSERT_ID();

UPDATE slice_games SET current_turn_id = @turn_id WHERE id = @game_id;

INSERT INTO slice_audit_log (game_id, turn_id, action, detail_json)
VALUES (@game_id, @turn_id, 'seed',
  JSON_OBJECT('game', 'MAP12_TEST', 'nodes', 13, 'edges', 16, 'factions', 4, 'players', 8));
