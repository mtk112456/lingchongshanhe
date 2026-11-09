# 游戏后端（第一期）

> 目录：`D:\DeskBox\游戏\server`  
> 目标：先做不依赖 Cocos 的数据库/API 基础，等 Cocos 装好再接客户端。

---

## 文件

| 文件 | 内容 |
|---|---|
| `schema_core.sql` | 第一期核心表：赛季/阵营/地图/将军/回合/军令/战斗/建造/日报/悬赏/战功/配置/天气/角色 |
| `seed_jiuzhou_12.sql` | 九州 12 节点测试种子：4 阵营、12 节点、相邻关系、初始归属、胜利点、天气、悬赏 |
| `API_CONTRACT.md` | 第一期 API 契约：登录、地图、军令、日报、悬赏、角色、老师后台、21:00 结算 |

---

## 怎么用

### 1. 先备份

```powershell
# 示例：按你现有备份方式备份 class_manager
```

### 2. 在测试库执行

```sql
SOURCE D:/DeskBox/游戏/server/schema_core.sql;
SOURCE D:/DeskBox/游戏/server/seed_jiuzhou_12.sql;
```

> 不要直接在生产库跑。  
> 先 `SHOW COLUMNS FROM students;` / `SHOW COLUMNS FROM shop_orders;` 核实现有结构。

### 3. 验证

```sql
SELECT id,name,map_code,status FROM game_war_seasons;
SELECT code,name,color,food,wood,iron FROM game_war_factions;
SELECT code,name,terrain,victory_points,owner_faction_id FROM game_war_provinces;
```

---

## 设计约束

1. 不改现有 `students` / `shop_orders` / `pet_*` 表结构；
2. 积分只写 `shop_orders`（`type='game_recharge'`）；
3. 不写 `students.score`；
4. 游戏结果只写 `game_war_*`；
5. 服务端权威，客户端只提交军令；
6. 测试用独立测试班/测试库。

---

## 下一步

1. 写 `/api/game/auth/login` 的 Token 版；
2. 写 `/api/game/war/bootstrap`；
3. 写 `/api/game/war/map`；
4. 写 `/api/game/war/orders`；
5. 写 21:00 结算任务；
6. 用种子数据跑一天模拟。

> 等 Cocos 装好，再接客户端三端验证。
