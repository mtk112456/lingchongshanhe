-- Phase 1：城池民心条
-- 只加一列，不改现有归属/初始归属。

ALTER TABLE `slice_nodes`
  ADD COLUMN IF NOT EXISTS `morale` TINYINT UNSIGNED NOT NULL DEFAULT 0
  AFTER `initial_owner_faction_id`;
