-- 《青竹文房·灵宠山河》里程碑 A：三回合切片
-- 独立测试库专用；禁止在生产库执行。
-- 字符集 utf8mb4；所有业务时点由 PHP 以 Asia/Shanghai 写入。

SET NAMES utf8mb4;
SET time_zone = '+08:00';
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS game_recharge_requests;
DROP TABLE IF EXISTS game_wallet_transactions;
DROP TABLE IF EXISTS game_wallets;
DROP TABLE IF EXISTS slice_battles;
DROP TABLE IF EXISTS slice_order_slots;
DROP TABLE IF EXISTS slice_hands;
DROP TABLE IF EXISTS slice_compositions;
DROP TABLE IF EXISTS slice_audit_log;
DROP TABLE IF EXISTS slice_settlement_jobs;
DROP TABLE IF EXISTS slice_player_reports;
DROP TABLE IF EXISTS slice_node_changes;
DROP TABLE IF EXISTS slice_turn_results;
DROP TABLE IF EXISTS slice_snapshot_orders;
DROP TABLE IF EXISTS slice_snapshots;
DROP TABLE IF EXISTS slice_order_requests;
DROP TABLE IF EXISTS slice_orders;
DROP TABLE IF EXISTS slice_sessions;
DROP TABLE IF EXISTS slice_turns;
DROP TABLE IF EXISTS slice_edges;
DROP TABLE IF EXISTS slice_nodes;
DROP TABLE IF EXISTS slice_players;
DROP TABLE IF EXISTS slice_factions;
DROP TABLE IF EXISTS slice_games;

SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE slice_games (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code VARCHAR(32) NOT NULL,
  name VARCHAR(64) NOT NULL,
  status ENUM('draft','running','paused','finished') NOT NULL DEFAULT 'draft',
  rules_version VARCHAR(16) NOT NULL DEFAULT 'A1',
  turn_seconds INT UNSIGNED NOT NULL DEFAULT 600,
  current_turn_id BIGINT UNSIGNED NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_games_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE slice_factions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  game_id BIGINT UNSIGNED NOT NULL,
  code VARCHAR(16) NOT NULL,
  name VARCHAR(32) NOT NULL,
  color VARCHAR(16) NOT NULL,
  start_node_code VARCHAR(32) NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uk_factions_game_code (game_id, code),
  UNIQUE KEY uk_factions_game_start (game_id, start_node_code),
  CONSTRAINT fk_factions_game FOREIGN KEY (game_id) REFERENCES slice_games(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE slice_nodes (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  game_id BIGINT UNSIGNED NOT NULL,
  node_code VARCHAR(32) NOT NULL,
  name VARCHAR(32) NOT NULL,
  x INT NOT NULL DEFAULT 0,
  y INT NOT NULL DEFAULT 0,
  node_type ENUM('start','neutral') NOT NULL DEFAULT 'neutral',
  owner_faction_id BIGINT UNSIGNED NULL,
  initial_owner_faction_id BIGINT UNSIGNED NULL,
  sort_order INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uk_nodes_game_code (game_id, node_code),
  KEY idx_nodes_game_owner (game_id, owner_faction_id),
  CONSTRAINT fk_nodes_game FOREIGN KEY (game_id) REFERENCES slice_games(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE slice_edges (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  game_id BIGINT UNSIGNED NOT NULL,
  a_node_code VARCHAR(32) NOT NULL,
  b_node_code VARCHAR(32) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_edges_game_pair (game_id, a_node_code, b_node_code),
  CONSTRAINT fk_edges_game FOREIGN KEY (game_id) REFERENCES slice_games(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 玩家身份不复制密码：student_id 指向现有 students.id；教师 admin_id 指向现有 admin.id。
CREATE TABLE slice_players (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  game_id BIGINT UNSIGNED NOT NULL,
  student_id INT UNSIGNED NULL,
  admin_id INT UNSIGNED NULL,
  faction_id BIGINT UNSIGNED NULL,
  nickname VARCHAR(32) NOT NULL,
  role ENUM('player','teacher') NOT NULL DEFAULT 'player',
  pet_instance_id INT NULL,
  pet_code VARCHAR(32) NOT NULL DEFAULT 'bamboo',
  pet_name VARCHAR(32) NOT NULL DEFAULT '小青竹',
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  last_seen_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_players_game_student (game_id, student_id),
  UNIQUE KEY uk_players_game_admin (game_id, admin_id),
  KEY idx_players_game_faction (game_id, faction_id),
  CONSTRAINT fk_players_game FOREIGN KEY (game_id) REFERENCES slice_games(id) ON DELETE CASCADE,
  CONSTRAINT fk_players_faction FOREIGN KEY (faction_id) REFERENCES slice_factions(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE slice_sessions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  player_id BIGINT UNSIGNED NOT NULL,
  token_hash CHAR(64) NOT NULL,
  expires_at DATETIME NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_sessions_token (token_hash),
  KEY idx_sessions_player (player_id),
  CONSTRAINT fk_sessions_player FOREIGN KEY (player_id) REFERENCES slice_players(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE slice_turns (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  game_id BIGINT UNSIGNED NOT NULL,
  turn_no INT UNSIGNED NOT NULL,
  status ENUM('open','locked','settling','settled','failed','cancelled') NOT NULL DEFAULT 'open',
  opens_at DATETIME NOT NULL,
  deadline_at DATETIME NOT NULL,
  locked_at DATETIME NULL,
  settled_at DATETIME NULL,
  rules_version VARCHAR(16) NOT NULL DEFAULT 'A1',
  snapshot_id BIGINT UNSIGNED NULL,
  failure_reason TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_turns_game_no (game_id, turn_no),
  KEY idx_turns_game_status (game_id, status),
  CONSTRAINT fk_turns_game FOREIGN KEY (game_id) REFERENCES slice_games(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE slice_orders (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  game_id BIGINT UNSIGNED NOT NULL,
  turn_id BIGINT UNSIGNED NOT NULL,
  player_id BIGINT UNSIGNED NOT NULL,
  action ENUM('advance','defend') NOT NULL,
  origin_node_code VARCHAR(32) NULL,
  target_node_code VARCHAR(32) NOT NULL,
  status ENUM('active','withdrawn') NOT NULL DEFAULT 'active',
  last_request_key VARCHAR(64) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_orders_turn_player (turn_id, player_id),
  KEY idx_orders_turn_status_target (turn_id, status, target_node_code),
  CONSTRAINT fk_orders_game FOREIGN KEY (game_id) REFERENCES slice_games(id) ON DELETE CASCADE,
  CONSTRAINT fk_orders_turn FOREIGN KEY (turn_id) REFERENCES slice_turns(id) ON DELETE CASCADE,
  CONSTRAINT fk_orders_player FOREIGN KEY (player_id) REFERENCES slice_players(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE slice_order_requests (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  game_id BIGINT UNSIGNED NOT NULL,
  turn_id BIGINT UNSIGNED NOT NULL,
  player_id BIGINT UNSIGNED NOT NULL,
  request_key VARCHAR(64) NOT NULL,
  payload_hash CHAR(64) NOT NULL,
  response_json JSON NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_requests_turn_player_key (turn_id, player_id, request_key),
  CONSTRAINT fk_requests_game FOREIGN KEY (game_id) REFERENCES slice_games(id) ON DELETE CASCADE,
  CONSTRAINT fk_requests_turn FOREIGN KEY (turn_id) REFERENCES slice_turns(id) ON DELETE CASCADE,
  CONSTRAINT fk_requests_player FOREIGN KEY (player_id) REFERENCES slice_players(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE slice_snapshots (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  game_id BIGINT UNSIGNED NOT NULL,
  turn_id BIGINT UNSIGNED NOT NULL,
  rules_version VARCHAR(16) NOT NULL,
  map_json JSON NOT NULL,
  orders_json JSON NOT NULL,
  content_hash CHAR(64) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_snapshots_turn (turn_id),
  KEY idx_snapshots_game (game_id),
  CONSTRAINT fk_snapshots_game FOREIGN KEY (game_id) REFERENCES slice_games(id) ON DELETE CASCADE,
  CONSTRAINT fk_snapshots_turn FOREIGN KEY (turn_id) REFERENCES slice_turns(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE slice_snapshot_orders (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  snapshot_id BIGINT UNSIGNED NOT NULL,
  player_id BIGINT UNSIGNED NOT NULL,
  faction_id BIGINT UNSIGNED NULL,
  faction_code VARCHAR(16) NOT NULL,
  nickname VARCHAR(32) NOT NULL,
  pet_name VARCHAR(32) NOT NULL,
  action ENUM('advance','defend','default_defend') NOT NULL,
  origin_node_code VARCHAR(32) NULL,
  target_node_code VARCHAR(32) NOT NULL,
  is_default TINYINT(1) NOT NULL DEFAULT 0,
  sort_order INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uk_snapshot_orders_player (snapshot_id, player_id),
  KEY idx_snapshot_orders_target (snapshot_id, target_node_code),
  CONSTRAINT fk_snapshot_orders_snapshot FOREIGN KEY (snapshot_id) REFERENCES slice_snapshots(id) ON DELETE CASCADE,
  CONSTRAINT fk_snapshot_orders_player FOREIGN KEY (player_id) REFERENCES slice_players(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE slice_turn_results (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  game_id BIGINT UNSIGNED NOT NULL,
  turn_id BIGINT UNSIGNED NOT NULL,
  result_json JSON NOT NULL,
  standings_json JSON NOT NULL,
  content_hash CHAR(64) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_results_turn (turn_id),
  KEY idx_results_game (game_id),
  CONSTRAINT fk_results_game FOREIGN KEY (game_id) REFERENCES slice_games(id) ON DELETE CASCADE,
  CONSTRAINT fk_results_turn FOREIGN KEY (turn_id) REFERENCES slice_turns(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE slice_node_changes (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  game_id BIGINT UNSIGNED NOT NULL,
  turn_id BIGINT UNSIGNED NOT NULL,
  node_code VARCHAR(32) NOT NULL,
  owner_before_faction_id BIGINT UNSIGNED NULL,
  owner_after_faction_id BIGINT UNSIGNED NULL,
  winner_faction_id BIGINT UNSIGNED NULL,
  score_json JSON NOT NULL,
  reason VARCHAR(32) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_changes_turn_node (turn_id, node_code),
  KEY idx_changes_game (game_id),
  CONSTRAINT fk_changes_game FOREIGN KEY (game_id) REFERENCES slice_games(id) ON DELETE CASCADE,
  CONSTRAINT fk_changes_turn FOREIGN KEY (turn_id) REFERENCES slice_turns(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE slice_player_reports (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  game_id BIGINT UNSIGNED NOT NULL,
  turn_id BIGINT UNSIGNED NOT NULL,
  player_id BIGINT UNSIGNED NOT NULL,
  order_json JSON NOT NULL,
  outcome_json JSON NOT NULL,
  readable_text TEXT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_player_reports_turn_player (turn_id, player_id),
  KEY idx_player_reports_game (game_id),
  CONSTRAINT fk_player_reports_game FOREIGN KEY (game_id) REFERENCES slice_games(id) ON DELETE CASCADE,
  CONSTRAINT fk_player_reports_turn FOREIGN KEY (turn_id) REFERENCES slice_turns(id) ON DELETE CASCADE,
  CONSTRAINT fk_player_reports_player FOREIGN KEY (player_id) REFERENCES slice_players(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE slice_settlement_jobs (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  game_id BIGINT UNSIGNED NOT NULL,
  turn_id BIGINT UNSIGNED NOT NULL,
  status ENUM('pending','running','failed','done') NOT NULL DEFAULT 'pending',
  attempts INT UNSIGNED NOT NULL DEFAULT 0,
  last_error TEXT NULL,
  started_at DATETIME NULL,
  finished_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_jobs_turn (turn_id),
  KEY idx_jobs_game_status (game_id, status),
  CONSTRAINT fk_jobs_game FOREIGN KEY (game_id) REFERENCES slice_games(id) ON DELETE CASCADE,
  CONSTRAINT fk_jobs_turn FOREIGN KEY (turn_id) REFERENCES slice_turns(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE slice_audit_log (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  game_id BIGINT UNSIGNED NOT NULL,
  turn_id BIGINT UNSIGNED NULL,
  player_id BIGINT UNSIGNED NULL,
  action VARCHAR(64) NOT NULL,
  detail_json JSON NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_audit_game_time (game_id, created_at),
  CONSTRAINT fk_audit_game FOREIGN KEY (game_id) REFERENCES slice_games(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 文玉钱包：跨赛季保留；积分扣减仍只发生在现有 shop_orders。
CREATE TABLE game_wallets (
  student_id INT UNSIGNED NOT NULL,
  balance_jade BIGINT UNSIGNED NOT NULL DEFAULT 0,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (student_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE game_wallet_transactions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  student_id INT UNSIGNED NOT NULL,
  shop_order_id INT UNSIGNED NULL,
  points_spent INT UNSIGNED NOT NULL,
  jade_delta BIGINT NOT NULL,
  balance_after BIGINT UNSIGNED NOT NULL,
  reason VARCHAR(32) NOT NULL DEFAULT 'recharge',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_wallet_tx_student (student_id, created_at),
  KEY idx_wallet_tx_order (shop_order_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE game_recharge_requests (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  student_id INT UNSIGNED NOT NULL,
  request_key VARCHAR(64) NOT NULL,
  points_requested INT UNSIGNED NOT NULL,
  response_json JSON NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_recharge_student_key (student_id, request_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Phase 1：3 张将令 + 4 兵种 + 3×2 战斗

CREATE TABLE IF NOT EXISTS slice_compositions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  game_id BIGINT UNSIGNED NOT NULL,
  player_id BIGINT UNSIGNED NOT NULL,
  week_no TINYINT UNSIGNED NOT NULL,
  types_json JSON NOT NULL,
  changed_once TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_comp_player_week (game_id, player_id, week_no),
  CONSTRAINT fk_comp_game FOREIGN KEY (game_id) REFERENCES slice_games(id) ON DELETE CASCADE,
  CONSTRAINT fk_comp_player FOREIGN KEY (player_id) REFERENCES slice_players(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS slice_hands (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  game_id BIGINT UNSIGNED NOT NULL,
  turn_id BIGINT UNSIGNED NOT NULL,
  player_id BIGINT UNSIGNED NOT NULL,
  cards_json JSON NOT NULL,
  redraw_used TINYINT(1) NOT NULL DEFAULT 0,
  hand_seed VARCHAR(64) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_hand_turn_player (turn_id, player_id),
  CONSTRAINT fk_hand_game FOREIGN KEY (game_id) REFERENCES slice_games(id) ON DELETE CASCADE,
  CONSTRAINT fk_hand_turn FOREIGN KEY (turn_id) REFERENCES slice_turns(id) ON DELETE CASCADE,
  CONSTRAINT fk_hand_player FOREIGN KEY (player_id) REFERENCES slice_players(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS slice_order_slots (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  game_id BIGINT UNSIGNED NOT NULL,
  turn_id BIGINT UNSIGNED NOT NULL,
  player_id BIGINT UNSIGNED NOT NULL,
  slot TINYINT UNSIGNED NOT NULL,
  card_code VARCHAR(32) NOT NULL,
  target_node_code VARCHAR(32) NOT NULL,
  lane TINYINT UNSIGNED NULL,
  row_pos ENUM('front','back') NULL,
  status ENUM('active','withdrawn') NOT NULL DEFAULT 'active',
  last_request_key VARCHAR(64) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_slots_turn_player_slot (turn_id, player_id, slot),
  KEY idx_slots_turn_status_target (turn_id, status, target_node_code),
  CONSTRAINT fk_slots_game FOREIGN KEY (game_id) REFERENCES slice_games(id) ON DELETE CASCADE,
  CONSTRAINT fk_slots_turn FOREIGN KEY (turn_id) REFERENCES slice_turns(id) ON DELETE CASCADE,
  CONSTRAINT fk_slots_player FOREIGN KEY (player_id) REFERENCES slice_players(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS slice_battles (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  game_id BIGINT UNSIGNED NOT NULL,
  turn_id BIGINT UNSIGNED NOT NULL,
  node_code VARCHAR(32) NOT NULL,
  att_faction_id INT UNSIGNED NULL,
  def_faction_id INT UNSIGNED NULL,
  attacker_json JSON NOT NULL,
  defender_json JSON NOT NULL,
  log_json JSON NOT NULL,
  result_json JSON NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_battles_turn_node (turn_id, node_code),
  CONSTRAINT fk_battles_game FOREIGN KEY (game_id) REFERENCES slice_games(id) ON DELETE CASCADE,
  CONSTRAINT fk_battles_turn FOREIGN KEY (turn_id) REFERENCES slice_turns(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
