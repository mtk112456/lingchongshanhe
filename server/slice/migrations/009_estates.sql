-- 文房小院（个人封地）：不产兵、不产资源，只记录个人成长
CREATE TABLE IF NOT EXISTS slice_estates (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  game_id BIGINT UNSIGNED NOT NULL,
  player_id BIGINT UNSIGNED NOT NULL,
  home_node_code VARCHAR(32) NOT NULL,
  study_level TINYINT UNSIGNED NOT NULL DEFAULT 1,
  drill_level TINYINT UNSIGNED NOT NULL DEFAULT 1,
  tower_level TINYINT UNSIGNED NOT NULL DEFAULT 1,
  spent_merit INT UNSIGNED NOT NULL DEFAULT 0,
  banner VARCHAR(32) NOT NULL DEFAULT '',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_estate_player (game_id, player_id),
  KEY idx_estate_game (game_id),
  CONSTRAINT fk_estate_game FOREIGN KEY (game_id) REFERENCES slice_games(id) ON DELETE CASCADE,
  CONSTRAINT fk_estate_player FOREIGN KEY (player_id) REFERENCES slice_players(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 每周每城贡献第一 = 太守
CREATE TABLE IF NOT EXISTS slice_city_governors (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  game_id BIGINT UNSIGNED NOT NULL,
  node_code VARCHAR(32) NOT NULL,
  week_no TINYINT UNSIGNED NOT NULL,
  player_id BIGINT UNSIGNED NOT NULL,
  merit INT UNSIGNED NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_governor_city_week (game_id, node_code, week_no),
  KEY idx_governor_player (game_id, player_id),
  CONSTRAINT fk_governor_game FOREIGN KEY (game_id) REFERENCES slice_games(id) ON DELETE CASCADE,
  CONSTRAINT fk_governor_player FOREIGN KEY (player_id) REFERENCES slice_players(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 练兵场：记录本周已改编成次数（首次设置不计数）
ALTER TABLE slice_compositions
  ADD COLUMN IF NOT EXISTS changes_used TINYINT UNSIGNED NOT NULL DEFAULT 0;
