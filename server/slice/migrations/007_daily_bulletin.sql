-- D6 每日邸报：每个学生每天二选一，获得本回合小 buff
-- 只新增表，不改旧表，可在试跑库直接执行。

CREATE TABLE IF NOT EXISTS slice_bulletins (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  game_id BIGINT UNSIGNED NOT NULL,
  turn_id BIGINT UNSIGNED NOT NULL,
  player_id BIGINT UNSIGNED NOT NULL,
  options_json JSON NOT NULL,
  choice VARCHAR(24) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_bulletin_turn_player (turn_id, player_id),
  KEY idx_bulletin_game_turn (game_id, turn_id),
  CONSTRAINT fk_bulletin_game FOREIGN KEY (game_id) REFERENCES slice_games(id) ON DELETE CASCADE,
  CONSTRAINT fk_bulletin_turn FOREIGN KEY (turn_id) REFERENCES slice_turns(id) ON DELETE CASCADE,
  CONSTRAINT fk_bulletin_player FOREIGN KEY (player_id) REFERENCES slice_players(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
