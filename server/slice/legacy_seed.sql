-- 现有积分/班宠系统的测试镜像数据。仅用于独立测试库。
-- 学生密码：slice2026；教师账号：teacher / teacher2026。

SET NAMES utf8mb4;
SET time_zone = '+08:00';

INSERT INTO classes (id, name) VALUES (1, '初一（1）班·切片测试');

-- 8 名试验学生；分数用于验证“可用积分 = max(0, score - 100 - 已花费)”。
INSERT INTO students (id, id_card, class_id, name, show_name, password, position, position_color, score, perm_score, perm_duty, version) VALUES
  (1, '110101201201010001', 1, '试验青竹一', '青竹一', '$2y$12$JcwXAhlGd6eaxIHjLBPx3.kBkALH4OhnMJSWv3/huy7BJDt.p3Fwa', '军师', '#3498db', 140, 1, 0, 1),
  (2, '110101201201010002', 1, '试验青竹二', '青竹二', '$2y$12$JcwXAhlGd6eaxIHjLBPx3.kBkALH4OhnMJSWv3/huy7BJDt.p3Fwa', '将军', '#e74c3c', 136, 1, 0, 1),
  (3, '110101201201010003', 1, '试验青竹三', '青竹三', '$2y$12$JcwXAhlGd6eaxIHjLBPx3.kBkALH4OhnMJSWv3/huy7BJDt.p3Fwa', '粮官', '#27ae60', 132, 0, 0, 1),
  (4, '110101201201010004', 1, '试验青竹四', '青竹四', '$2y$12$JcwXAhlGd6eaxIHjLBPx3.kBkALH4OhnMJSWv3/huy7BJDt.p3Fwa', '斥候', '#9b59b6', 128, 0, 0, 1),
  (5, '110101201201010005', 1, '试验墨点一', '墨点一', '$2y$12$JcwXAhlGd6eaxIHjLBPx3.kBkALH4OhnMJSWv3/huy7BJDt.p3Fwa', '将军', '#e74c3c', 124, 1, 0, 1),
  (6, '110101201201010006', 1, '试验墨点二', '墨点二', '$2y$12$JcwXAhlGd6eaxIHjLBPx3.kBkALH4OhnMJSWv3/huy7BJDt.p3Fwa', '军师', '#3498db', 120, 0, 0, 1),
  (7, '110101201201010007', 1, '试验墨点三', '墨点三', '$2y$12$JcwXAhlGd6eaxIHjLBPx3.kBkALH4OhnMJSWv3/huy7BJDt.p3Fwa', '粮官', '#27ae60', 116, 0, 0, 1),
  (8, '110101201201010008', 1, '试验墨点四', '墨点四', '$2y$12$JcwXAhlGd6eaxIHjLBPx3.kBkALH4OhnMJSWv3/huy7BJDt.p3Fwa', '斥候', '#9b59b6', 112, 0, 0, 1);

INSERT INTO admin (id, username, password, nickname) VALUES
  (1, 'teacher', '$2y$12$78ZJ./xRDdbfyK3.C7N/VegjxKMe77Cjo96Z5K7acYVh6Eaibqbe6', '先生');

INSERT INTO pet_templates (id, code, name, element, rarity, desc_lore, base_hp, base_atk, base_def, base_spd, growth_rate, is_active, shop_price) VALUES
  (1, 'pet_bamboo_01', '小青竹', '诗词', 'N', '青竹化灵，陪学子读书。', 1000, 100, 100, 100, 1.00, 1, 0),
  (2, 'pet_inkdrop_01', '墨点精', '翰墨', 'N', '砚池墨点滴落成精，机灵好动。', 1000, 100, 100, 100, 1.00, 1, 0);

INSERT INTO pet_evolutions (pet_template_id, stage, stage_name, req_level, image_path, stage_desc) VALUES
  (1, 1, '青竹童子', 1, 'res://pets/bamboo_stage1.png', '初化人形'),
  (2, 1, '墨点童子', 1, 'res://pets/inkdrop_stage1.png', '初化人形');

-- 班宠实例：每人一只，切片阶段统一 1000 兵力、同等四维。
INSERT INTO student_pets (id, student_id, pet_template_id, nickname, level, current_exp, hunger, mood, status) VALUES
  (1, 1, 1, '小青竹·一', 10, 0, 90, 100, 'normal'),
  (2, 2, 1, '小青竹·二', 10, 0, 90, 100, 'normal'),
  (3, 3, 1, '小青竹·三', 10, 0, 90, 100, 'normal'),
  (4, 4, 1, '小青竹·四', 10, 0, 90, 100, 'normal'),
  (5, 5, 2, '墨点精·一', 10, 0, 90, 100, 'normal'),
  (6, 6, 2, '墨点精·二', 10, 0, 90, 100, 'normal'),
  (7, 7, 2, '墨点精·三', 10, 0, 90, 100, 'normal'),
  (8, 8, 2, '墨点精·四', 10, 0, 90, 100, 'normal');
