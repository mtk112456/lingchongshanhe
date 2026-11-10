-- Phase 1：3 张将令 + 4 兵种 + 3×2 战斗
-- 只新增表，不改 students.score，不改 student_pets，不改 legacy slice_orders。
-- 旧 14 项测试继续走 slice_orders（v1）；新玩法走 slice_order_slots（cards_v1）。

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
