-- 生产库迁移：文玉钱包与兑换幂等记录。
-- 只新增 game_* 表，不改 students.score，不改班宠数据。

CREATE TABLE IF NOT EXISTS game_wallets (
  student_id INT UNSIGNED NOT NULL,
  balance_jade BIGINT UNSIGNED NOT NULL DEFAULT 0,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (student_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS game_wallet_transactions (
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

CREATE TABLE IF NOT EXISTS game_recharge_requests (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  student_id INT UNSIGNED NOT NULL,
  request_key VARCHAR(64) NOT NULL,
  points_requested INT UNSIGNED NOT NULL,
  response_json JSON NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_recharge_student_key (student_id, request_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
