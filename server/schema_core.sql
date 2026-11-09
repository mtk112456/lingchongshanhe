-- ============================================================
-- 《青竹文房·灵宠山河》第一期核心数据表
-- 数据库：沿用现有 class_manager（MySQL/MariaDB）
-- 原则：
--   1. 不改现有 students / shop_orders / pet_* 表结构
--   2. 新表统一 game_war_ 前缀
--   3. 所有写入走服务端，客户端不直接写库
-- ============================================================

SET NAMES utf8mb4;

-- 1. 赛季
CREATE TABLE IF NOT EXISTS `game_war_seasons` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `class_id` INT UNSIGNED NOT NULL COMMENT '班级ID',
  `name` VARCHAR(50) NOT NULL COMMENT '赛季名，如 S1 九州争霸',
  `map_code` VARCHAR(30) NOT NULL DEFAULT 'jiuzhou_12' COMMENT '地图代码',
  `phase` TINYINT NOT NULL DEFAULT 1 COMMENT '玩法期数 1/2/3',
  `start_date` DATE NOT NULL,
  `end_date` DATE NOT NULL,
  `settle_time` TIME NOT NULL DEFAULT '21:00:00' COMMENT '每日结算时间',
  `status` ENUM('draft','active','settled','archived') NOT NULL DEFAULT 'draft',
  `config_json` LONGTEXT NULL COMMENT '赛季配置JSON',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_class_status` (`class_id`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='战争赛季';

-- 2. 阵营
CREATE TABLE IF NOT EXISTS `game_war_factions` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `season_id` INT UNSIGNED NOT NULL,
  `code` VARCHAR(20) NOT NULL COMMENT 'bi/mo/zhi/yan',
  `name` VARCHAR(30) NOT NULL COMMENT '笔/墨/纸/砚',
  `color` VARCHAR(20) NOT NULL DEFAULT '#1e3a5f',
  `capital_province_id` INT UNSIGNED NULL,
  `food` INT NOT NULL DEFAULT 500,
  `wood` INT NOT NULL DEFAULT 500,
  `iron` INT NOT NULL DEFAULT 500,
  `victory_points` INT NOT NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_season_code` (`season_id`,`code`),
  KEY `idx_season` (`season_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='战争阵营';

-- 3. 地图节点
CREATE TABLE IF NOT EXISTS `game_war_provinces` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `season_id` INT UNSIGNED NOT NULL,
  `code` VARCHAR(30) NOT NULL COMMENT 'changan/luoyang/...',
  `name` VARCHAR(30) NOT NULL,
  `terrain` VARCHAR(20) NOT NULL DEFAULT 'plain' COMMENT 'plain/mountain/river/pass',
  `resource_type` VARCHAR(20) NOT NULL DEFAULT 'food' COMMENT 'food/wood/iron/horse',
  `victory_points` TINYINT NOT NULL DEFAULT 1,
  `owner_faction_id` INT UNSIGNED NULL,
  `neutral_garrison` INT NOT NULL DEFAULT 0 COMMENT '中立守军',
  `wall_level` TINYINT NOT NULL DEFAULT 1,
  `farm_level` TINYINT NOT NULL DEFAULT 1,
  `barracks_level` TINYINT NOT NULL DEFAULT 1,
  `watchtower_level` TINYINT NOT NULL DEFAULT 0,
  `x` SMALLINT NOT NULL DEFAULT 0,
  `y` SMALLINT NOT NULL DEFAULT 0,
  `adjacency_json` VARCHAR(500) NOT NULL DEFAULT '[]' COMMENT '相邻节点code数组',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_season_code` (`season_id`,`code`),
  KEY `idx_season_owner` (`season_id`,`owner_faction_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='地图节点';

-- 4. 将军（每个学生一只班宠）
CREATE TABLE IF NOT EXISTS `game_war_generals` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `season_id` INT UNSIGNED NOT NULL,
  `student_id` INT UNSIGNED NOT NULL,
  `faction_id` INT UNSIGNED NOT NULL,
  `pet_instance_id` INT UNSIGNED NOT NULL COMMENT 'student_pets.id',
  `display_name` VARCHAR(50) NOT NULL,
  `role` VARCHAR(20) NOT NULL DEFAULT 'general' COMMENT 'general/strategist/quartermaster/scout',
  `role_week` TINYINT NOT NULL DEFAULT 1,
  `troops` INT NOT NULL DEFAULT 1000,
  `troop_type` VARCHAR(10) NOT NULL DEFAULT 'infantry' COMMENT 'infantry/cavalry/archer',
  `province_id` INT UNSIGNED NULL,
  `morale` TINYINT NOT NULL DEFAULT 80,
  `supply_days` TINYINT NOT NULL DEFAULT 3,
  `status` ENUM('active','defeated','retired') NOT NULL DEFAULT 'active',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_season_student` (`season_id`,`student_id`),
  KEY `idx_season_faction` (`season_id`,`faction_id`),
  KEY `idx_season_province` (`season_id`,`province_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='将军';

-- 5. 每日回合
CREATE TABLE IF NOT EXISTS `game_war_turns` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `season_id` INT UNSIGNED NOT NULL,
  `turn_date` DATE NOT NULL,
  `status` ENUM('open','settling','settled','failed') NOT NULL DEFAULT 'open',
  `settled_at` DATETIME NULL,
  `error_text` VARCHAR(255) NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_season_date` (`season_id`,`turn_date`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='每日回合/结算状态';

-- 6. 军令
CREATE TABLE IF NOT EXISTS `game_war_orders` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `season_id` INT UNSIGNED NOT NULL,
  `turn_date` DATE NOT NULL,
  `general_id` INT UNSIGNED NOT NULL,
  `student_id` INT UNSIGNED NOT NULL,
  `order_slot` TINYINT NOT NULL COMMENT '1/2/3，每天最多3道',
  `order_type` VARCHAR(20) NOT NULL COMMENT 'recruit/march/defend/build/scout/transport',
  `target_province_id` INT UNSIGNED NULL,
  `payload_json` LONGTEXT NULL,
  `status` ENUM('pending','settled','cancelled','failed') NOT NULL DEFAULT 'pending',
  `idempotency_key` VARCHAR(64) NOT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `settled_at` DATETIME NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_general_date_slot` (`general_id`,`turn_date`,`order_slot`),
  UNIQUE KEY `uk_general_idem` (`general_id`,`idempotency_key`),
  KEY `idx_season_date_status` (`season_id`,`turn_date`,`status`),
  KEY `idx_student` (`student_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='每日军令';

-- 7. 战斗记录
CREATE TABLE IF NOT EXISTS `game_war_battles` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `season_id` INT UNSIGNED NOT NULL,
  `turn_date` DATE NOT NULL,
  `province_id` INT UNSIGNED NOT NULL,
  `attacker_general_id` INT UNSIGNED NOT NULL,
  `defender_general_id` INT UNSIGNED NULL,
  `attacker_faction_id` INT UNSIGNED NOT NULL,
  `defender_faction_id` INT UNSIGNED NULL,
  `result` ENUM('attacker_win','defender_win','draw') NOT NULL,
  `battle_json` LONGTEXT NOT NULL COMMENT '战报/公式/回放数据',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_season_turn` (`season_id`,`turn_date`),
  KEY `idx_province` (`province_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='战斗记录';

-- 8. 建造/筑城记录
CREATE TABLE IF NOT EXISTS `game_war_build_orders` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `season_id` INT UNSIGNED NOT NULL,
  `turn_date` DATE NOT NULL,
  `province_id` INT UNSIGNED NOT NULL,
  `faction_id` INT UNSIGNED NOT NULL,
  `building_type` VARCHAR(20) NOT NULL COMMENT 'farm/barracks/wall/watchtower',
  `target_level` TINYINT NOT NULL,
  `status` ENUM('pending','done','failed') NOT NULL DEFAULT 'pending',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_season_turn` (`season_id`,`turn_date`),
  KEY `idx_province` (`province_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='建造记录';

-- 9. 战争日报
CREATE TABLE IF NOT EXISTS `game_war_reports` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `season_id` INT UNSIGNED NOT NULL,
  `student_id` INT UNSIGNED NOT NULL,
  `report_date` DATE NOT NULL,
  `report_json` LONGTEXT NOT NULL COMMENT '头条/地图变化/最佳战报/MVP/传闻',
  `read_at` DATETIME NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_season_student_date` (`season_id`,`student_id`,`report_date`),
  KEY `idx_student_date` (`student_id`,`report_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='战争日报';

-- 10. 悬赏
CREATE TABLE IF NOT EXISTS `game_war_bounties` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `season_id` INT UNSIGNED NOT NULL,
  `faction_id` INT UNSIGNED NULL COMMENT 'NULL=全班悬赏',
  `title` VARCHAR(100) NOT NULL,
  `bounty_type` VARCHAR(30) NOT NULL COMMENT 'capture/defend/scout/transport/build/battle',
  `target_json` LONGTEXT NULL,
  `reward_json` LONGTEXT NULL,
  `status` ENUM('active','completed','expired') NOT NULL DEFAULT 'active',
  `expires_at` DATETIME NOT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_season_status` (`season_id`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='悬赏';

-- 11. 战功/贡献流水
CREATE TABLE IF NOT EXISTS `game_war_contributions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `season_id` INT UNSIGNED NOT NULL,
  `student_id` INT UNSIGNED NOT NULL,
  `faction_id` INT UNSIGNED NOT NULL,
  `source` VARCHAR(30) NOT NULL COMMENT 'battle/defend/scout/transport/build/participation',
  `amount` INT NOT NULL,
  `ref_type` VARCHAR(30) NOT NULL DEFAULT '',
  `ref_id` VARCHAR(64) NOT NULL DEFAULT '',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_season_student` (`season_id`,`student_id`),
  KEY `idx_season_faction` (`season_id`,`faction_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='战功/贡献流水';

-- 12. 赛季配置
CREATE TABLE IF NOT EXISTS `game_war_config` (
  `season_id` INT UNSIGNED NOT NULL,
  `config_key` VARCHAR(50) NOT NULL,
  `config_value` VARCHAR(500) NOT NULL,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`season_id`,`config_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='赛季配置';

-- 13. 天气
CREATE TABLE IF NOT EXISTS `game_war_weather` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `season_id` INT UNSIGNED NOT NULL,
  `week_no` TINYINT NOT NULL,
  `weather_code` VARCHAR(20) NOT NULL COMMENT 'sunny/rain/snow/flood/harvest/fog',
  `effects_json` LONGTEXT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_season_week` (`season_id`,`week_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='每周天气';

-- 14. 角色历史
CREATE TABLE IF NOT EXISTS `game_war_role_history` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `season_id` INT UNSIGNED NOT NULL,
  `student_id` INT UNSIGNED NOT NULL,
  `role` VARCHAR(20) NOT NULL,
  `week_no` TINYINT NOT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_season_student_week` (`season_id`,`student_id`,`week_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='角色历史';

-- ============================================================
-- 第二期/第三期表（后续按需新增，不破坏第一期）
-- 第二期：game_war_treaties / game_war_spies / game_war_predictions /
--         game_war_neutrals / game_war_combos
-- 第三期：game_war_sieges / game_war_wonders / game_war_cross_wars
-- ============================================================
