-- 现有班级量化系统的“测试镜像”表结构。
-- 仅用于独立测试库；字段与生产库对齐，生产库不要执行本文件。
-- 生产库的 shop_orders.type 需单独执行 migrations/001_shop_orders_game_recharge.sql。

SET NAMES utf8mb4;
SET time_zone = '+08:00';
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS student_pet_artifacts;
DROP TABLE IF EXISTS student_pet_skills;
DROP TABLE IF EXISTS student_pets;
DROP TABLE IF EXISTS pet_evolutions;
DROP TABLE IF EXISTS pet_templates;
DROP TABLE IF EXISTS shop_orders;
DROP TABLE IF EXISTS students;
DROP TABLE IF EXISTS classes;
DROP TABLE IF EXISTS admin;

SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE classes (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(100) NOT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE students (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_card VARCHAR(18) NOT NULL,
  class_id INT UNSIGNED NOT NULL DEFAULT 1,
  name VARCHAR(50) NOT NULL,
  show_name VARCHAR(50) NOT NULL,
  password VARCHAR(255) NOT NULL,
  position VARCHAR(30) DEFAULT '',
  position_color VARCHAR(20) DEFAULT '#667eea',
  score INT DEFAULT 100,
  perm_score TINYINT DEFAULT 0,
  perm_duty TINYINT DEFAULT 0,
  version INT DEFAULT 1,
  create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_id_card (id_card),
  KEY idx_name (name),
  KEY idx_score (score),
  KEY idx_class (class_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE admin (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  username VARCHAR(50) NOT NULL,
  password VARCHAR(255) NOT NULL,
  nickname VARCHAR(50) NOT NULL DEFAULT '',
  create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE shop_orders (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_no VARCHAR(32) NOT NULL,
  student_id INT NOT NULL,
  class_id INT NOT NULL,
  type ENUM('goods','blind_box','game_recharge') DEFAULT 'goods',
  item_id INT NOT NULL DEFAULT 0,
  item_name VARCHAR(100) NOT NULL,
  spec_name VARCHAR(100) NOT NULL DEFAULT '',
  points_spent INT NOT NULL,
  verify_code VARCHAR(10) NOT NULL,
  status ENUM('pending','completed','cancelled') DEFAULT 'pending',
  create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
  finish_time DATETIME DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY order_no (order_no),
  KEY idx_stu (student_id),
  KEY idx_class (class_id),
  KEY idx_status (status),
  KEY idx_verify_code (verify_code),
  KEY idx_time (create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE pet_templates (
  id INT AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(50) NOT NULL,
  element VARCHAR(20) NOT NULL DEFAULT '翰墨',
  rarity ENUM('N','R','SR','SSR') NOT NULL DEFAULT 'N',
  desc_lore TEXT,
  base_hp INT NOT NULL DEFAULT 100,
  base_atk INT NOT NULL DEFAULT 20,
  base_def INT NOT NULL DEFAULT 15,
  base_spd INT NOT NULL DEFAULT 10,
  growth_rate DECIMAL(4,2) NOT NULL DEFAULT 1.00,
  is_active TINYINT(1) NOT NULL DEFAULT 0,
  shop_price INT NOT NULL DEFAULT 100,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE pet_evolutions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  pet_template_id INT NOT NULL,
  stage TINYINT NOT NULL,
  stage_name VARCHAR(50) NOT NULL,
  req_level INT NOT NULL DEFAULT 1,
  image_path VARCHAR(255) NOT NULL,
  stage_desc VARCHAR(255),
  KEY idx_pet_stage (pet_template_id, stage)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE student_pets (
  id INT AUTO_INCREMENT PRIMARY KEY,
  student_id INT NOT NULL UNIQUE,
  pet_template_id INT NOT NULL,
  nickname VARCHAR(50) NOT NULL,
  level INT NOT NULL DEFAULT 1,
  current_exp INT NOT NULL DEFAULT 0,
  hunger INT NOT NULL DEFAULT 100,
  mood INT NOT NULL DEFAULT 100,
  skill_slot_1 INT DEFAULT NULL,
  skill_slot_2 INT DEFAULT NULL,
  skill_slot_3 INT DEFAULT NULL,
  total_battles INT NOT NULL DEFAULT 0,
  win_battles INT NOT NULL DEFAULT 0,
  status ENUM('normal','selling') NOT NULL DEFAULT 'normal',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  last_fed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  KEY idx_student (student_id),
  KEY idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE student_pet_skills (
  id INT AUTO_INCREMENT PRIMARY KEY,
  student_id INT NOT NULL,
  piece_name VARCHAR(100) NOT NULL,
  skill_name VARCHAR(100) NOT NULL,
  skill_type VARCHAR(50) DEFAULT '文学心法',
  skill_effect VARCHAR(255) DEFAULT '',
  power_val INT DEFAULT 30,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_stu_piece (student_id, piece_name),
  KEY idx_stu (student_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE student_pet_artifacts (
  id INT AUTO_INCREMENT PRIMARY KEY,
  student_id INT NOT NULL,
  book_id INT NOT NULL,
  artifact_code VARCHAR(50) NOT NULL,
  artifact_name VARCHAR(100) NOT NULL,
  book_title VARCHAR(100) NOT NULL,
  effect_desc VARCHAR(255) DEFAULT '',
  power_val INT DEFAULT 50,
  is_equipped TINYINT(1) DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_stu_book (student_id, book_id),
  KEY idx_stu (student_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
