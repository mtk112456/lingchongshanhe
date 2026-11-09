-- ============================================================
-- 《青竹文房·灵宠山河》第一期测试种子：九州 12 节点
-- 用法：在测试库执行（不要在生产库直接跑）
-- 班级ID 默认 1，按需修改
-- ============================================================

SET NAMES utf8mb4;

-- 1. 赛季
INSERT INTO `game_war_seasons`
(`class_id`,`name`,`map_code`,`phase`,`start_date`,`end_date`,`settle_time`,`status`,`config_json`)
VALUES
(1,'S1 九州争霸','jiuzhou_12',1,'2026-11-10','2026-12-08','21:00:00','active','{"max_orders":3,"season_weeks":4}');

SET @season_id = LAST_INSERT_ID();

-- 2. 四阵营
INSERT INTO `game_war_factions` (`season_id`,`code`,`name`,`color`,`food`,`wood`,`iron`,`victory_points`)
VALUES (@season_id,'bi','笔','#b83b32',500,500,500,0);
SET @bi = LAST_INSERT_ID();

INSERT INTO `game_war_factions` (`season_id`,`code`,`name`,`color`,`food`,`wood`,`iron`,`victory_points`)
VALUES (@season_id,'mo','墨','#1e3a5f',500,500,500,0);
SET @mo = LAST_INSERT_ID();

INSERT INTO `game_war_factions` (`season_id`,`code`,`name`,`color`,`food`,`wood`,`iron`,`victory_points`)
VALUES (@season_id,'zhi','纸','#cf8325',500,500,500,0);
SET @zhi = LAST_INSERT_ID();

INSERT INTO `game_war_factions` (`season_id`,`code`,`name`,`color`,`food`,`wood`,`iron`,`victory_points`)
VALUES (@season_id,'yan','砚','#276f57',500,500,500,0);
SET @yan = LAST_INSERT_ID();

-- 3. 12 个节点
-- 初始归属：笔=长安；墨=太原/邺城；纸=建业/会稽；砚=成都/江陵；其余中立
INSERT INTO `game_war_provinces`
(`season_id`,`code`,`name`,`terrain`,`resource_type`,`victory_points`,`owner_faction_id`,`neutral_garrison`,
 `wall_level`,`farm_level`,`barracks_level`,`watchtower_level`,`x`,`y`,`adjacency_json`)
VALUES
(@season_id,'changan','长安','plain','food',3,@bi,0,2,2,2,1,1,2,'["luoyang","hanzhong","taiyuan"]'),
(@season_id,'luoyang','洛阳','plain','food',2,NULL,800,1,1,1,0,3,2,'["changan","yecheng","shouchun","xiangyang"]'),
(@season_id,'chengdu','成都','mountain','food',3,@yan,0,2,2,2,1,1,6,'["hanzhong","jiangling"]'),
(@season_id,'hanzhong','汉中','pass','wood',1,NULL,600,2,1,1,0,2,4,'["changan","chengdu","xiangyang"]'),
(@season_id,'jiangling','江陵','river','food',2,@yan,0,1,2,2,1,3,5,'["chengdu","xiangyang","changsha","jianye"]'),
(@season_id,'xiangyang','襄阳','pass','iron',2,NULL,900,2,1,1,0,4,4,'["luoyang","hanzhong","jiangling","shouchun","changsha"]'),
(@season_id,'jianye','建业','river','food',3,@zhi,0,2,2,2,1,7,4,'["jiangling","shouchun","kuaiji"]'),
(@season_id,'kuaiji','会稽','forest','wood',1,@zhi,0,1,2,1,0,8,6,'["jianye"]'),
(@season_id,'taiyuan','太原','mountain','iron',2,@mo,0,2,1,2,1,3,0,'["changan","yecheng"]'),
(@season_id,'yecheng','邺城','plain','food',2,@mo,0,1,2,2,0,5,1,'["taiyuan","luoyang","shouchun"]'),
(@season_id,'shouchun','寿春','plain','food',1,NULL,500,1,2,1,0,6,3,'["luoyang","yecheng","xiangyang","jianye"]'),
(@season_id,'changsha','长沙','forest','wood',1,NULL,500,1,1,1,0,5,6,'["jiangling","xiangyang"]');

-- 4. 回填首都
UPDATE `game_war_factions` SET `capital_province_id` =
  (SELECT `id` FROM `game_war_provinces` WHERE `season_id`=@season_id AND `code`='changan')
  WHERE `season_id`=@season_id AND `code`='bi';

UPDATE `game_war_factions` SET `capital_province_id` =
  (SELECT `id` FROM `game_war_provinces` WHERE `season_id`=@season_id AND `code`='taiyuan')
  WHERE `season_id`=@season_id AND `code`='mo';

UPDATE `game_war_factions` SET `capital_province_id` =
  (SELECT `id` FROM `game_war_provinces` WHERE `season_id`=@season_id AND `code`='jianye')
  WHERE `season_id`=@season_id AND `code`='zhi';

UPDATE `game_war_factions` SET `capital_province_id` =
  (SELECT `id` FROM `game_war_provinces` WHERE `season_id`=@season_id AND `code`='chengdu')
  WHERE `season_id`=@season_id AND `code`='yan';

-- 5. 第一周天气
INSERT INTO `game_war_weather` (`season_id`,`week_no`,`weather_code`,`effects_json`)
VALUES (@season_id,1,'sunny','{"name":"晴","effects":{}}');

-- 6. 赛季配置
INSERT INTO `game_war_config` (`season_id`,`config_key`,`config_value`) VALUES
(@season_id,'max_orders','3'),
(@season_id,'settle_time','21:00'),
(@season_id,'season_weeks','4'),
(@season_id,'normalize_pet_power','1'),
(@season_id,'underdog_threshold','0.25'),
(@season_id,'underdog_bonus','0.10');

-- 7. 示例悬赏
INSERT INTO `game_war_bounties`
(`season_id`,`faction_id`,`title`,`bounty_type`,`target_json`,`reward_json`,`status`,`expires_at`)
VALUES
(@season_id,NULL,'侦察洛阳','scout','{"province":"luoyang"}','{"merit":20,"coin":10}','active',DATE_ADD(NOW(), INTERVAL 1 DAY)),
(@season_id,NULL,'拿下襄阳','capture','{"province":"xiangyang"}','{"merit":100,"coin":50}','active',DATE_ADD(NOW(), INTERVAL 1 DAY)),
(@season_id,NULL,'运粮到前线','transport','{"amount":200}','{"merit":50,"coin":20}','active',DATE_ADD(NOW(), INTERVAL 1 DAY));

-- 完成
SELECT @season_id AS season_id;
