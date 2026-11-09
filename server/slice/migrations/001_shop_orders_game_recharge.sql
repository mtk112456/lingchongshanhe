-- 生产库迁移：允许灵宠山河用 shop_orders 记录积分兑换。
-- 前置：确认现有 shop_orders.type 的枚举值；本脚本只追加 game_recharge，不删除原值。
-- 执行前备份；禁止在未确认的库上直接执行。

ALTER TABLE `shop_orders`
  MODIFY COLUMN `type` ENUM('goods','blind_box','game_recharge')
  DEFAULT 'goods'
  COMMENT '兑换类型';
