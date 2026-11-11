-- 个人军功：只记录游戏内荣誉，不修改 students.score
CREATE TABLE IF NOT EXISTS slice_merit_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  game_id BIGINT UNSIGNED NOT NULL,
  turn_id BIGINT UNSIGNED NOT NULL,
  player_id BIGINT UNSIGNED NOT NULL,
  kind VARCHAR(24) NOT NULL,
  amount INT NOT NULL,
  detail_json JSON NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_merit_turn_player_kind (turn_id, player_id, kind),
  KEY idx_merit_game_player (game_id, player_id),
  KEY idx_merit_game_turn (game_id, turn_id),
  CONSTRAINT fk_merit_game FOREIGN KEY (game_id) REFERENCES slice_games(id) ON DELETE CASCADE,
  CONSTRAINT fk_merit_turn FOREIGN KEY (turn_id) REFERENCES slice_turns(id) ON DELETE CASCADE,
  CONSTRAINT fk_merit_player FOREIGN KEY (player_id) REFERENCES slice_players(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
