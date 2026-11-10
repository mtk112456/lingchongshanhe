# Phase 1 战斗资产 · 第一批

由内置 imagegen 生成。图集按实际轮廓分格后等比导出，素材默认朝右，守方可由引擎镜像。三态是单帧姿态。城门位于战场最右端，器械是阵后装备。

| 文件 | 尺寸 | 用途 | 状态 | Prompt |
|---|---|---|---|---|
| cavalry_idle.png | 512×512 RGBA | 骑兵 | 待机 | A 1 行 1 列 |
| cavalry_attack.png | 512×512 RGBA | 骑兵 | 攻击 | A 1 行 2 列 |
| cavalry_hit.png | 512×512 RGBA | 骑兵 | 受击 | A 1 行 3 列 |
| shield_idle.png | 512×512 RGBA | 盾兵 | 待机 | A 2 行 1 列 |
| shield_attack.png | 512×512 RGBA | 盾兵 | 攻击 | A 2 行 2 列 |
| shield_hit.png | 512×512 RGBA | 盾兵 | 受击 | A 2 行 3 列 |
| archer_idle.png | 512×512 RGBA | 弓兵 | 待机 | B 1 行 1 列 |
| archer_attack.png | 512×512 RGBA | 弓兵 | 攻击 | B 1 行 2 列 |
| archer_hit.png | 512×512 RGBA | 弓兵 | 受击 | B 1 行 3 列 |
| spear_idle.png | 512×512 RGBA | 枪兵 | 待机 | B 2 行 1 列 |
| spear_attack.png | 512×512 RGBA | 枪兵 | 攻击 | B 2 行 2 列 |
| spear_hit.png | 512×512 RGBA | 枪兵 | 受击 | B 2 行 3 列 |
| siege_ram_idle.png | 512×512 RGBA | 阵后器械 | 待机，撞木回收 | C 左 |
| siege_ram_wall_attack.png | 512×512 RGBA | 阵后器械 | 攻墙，撞木伸出 | C 右 |
| castle_gate_wall.png | 1024×512 RGBA | 战场右侧城墙层 | 城门关闭 | D |
| preview_64px.png | 384×192 | 小尺寸验收 | 第一行骑／弓，第二行盾／枪，各三态。第三行器械两态及城门 | 以上 PNG 缩略合成 |

## 实际生成提示词

### A

Transparent RGBA sprite atlas, actual alpha, isolated original fictional Chinese storybook battle game art. Muted watercolor paper cut, fine dark ink, compact strong readable silhouettes at 64px, side three-quarter facing right, no blood, no injury, no ground or cast shadows, no text, glyphs, digits, flags or faction colors. Keep full equipment and consistent scale, costume and facing across poses, no dividing lines. Exact 3 columns by 2 rows evenly spaced square cells, centered separate sprite in each, wide gutters. Top row all SAME mounted horse rider, horse dominant, beige cloth: idle standing, attack surging forward, hit recoil horse raises head. Bottom row SAME shield infantry with oversized tall rounded wood shield: idle upright shield, attack stepping forward shield raised, hit leaning back shield tilted. Full silhouettes within cells.

### B

Transparent RGBA sprite atlas, actual alpha, isolated original fictional Chinese storybook battle game art. Muted watercolor paper cut, fine dark ink, compact strong readable silhouettes at 64px, side three-quarter facing right, no blood, no injury, no ground or cast shadows, no text, glyphs, digits, flags or faction colors. Keep full equipment and consistent scale, costume and facing across poses, no dividing lines. Exact 3 columns by 2 rows evenly spaced square cells, centered separate sprite in each, wide gutters. Top row SAME archer with conspicuous oversized curved bow: idle bow held upright, attack full drawn bow aiming right, hit recoil holding lowered bow. Bottom row SAME lancer with oversized clearly straight long spear: idle diagonal upright spear, attack horizontal forward thrust, hit leaning back spear tilted upward. Keep bows and spear tips completely inside cells.

### C

Transparent RGBA sprite atlas, actual alpha, isolated original fictional Chinese storybook battle game art. Muted watercolor paper cut, fine dark ink, compact strong readable silhouettes at 64px, side three-quarter facing right, no blood, no injury, no ground or cast shadows, no text, glyphs, digits, flags or faction colors. Keep full equipment and consistent scale, costume and facing across poses, no dividing lines. Exact 2 columns by 1 row evenly spaced square cells. Same original fictional covered wheeled wooden siege ram, visible cylindrical timber and roof, no operators. Left ram drawn back idle. Right timber extended forward to right in attack pose, no target wall, no debris. Both fully within cells.

### D

Transparent RGBA sprite atlas, actual alpha, isolated original fictional Chinese storybook battle game art. Muted watercolor paper cut, fine dark ink, compact strong readable silhouettes at 64px, side three-quarter facing right, no blood, no injury, no ground or cast shadows, no text, glyphs, digits, flags or faction colors. Keep full equipment and consistent scale, costume and facing across poses, no dividing lines. Single wide 2:1 isolated wall and closed gate game overlay. Chinese gray stone fortress wall stretching horizontally with one wooden arched gate near center, modest charcoal tiled gatehouse roof, crenellations, right-side battle destination viewed in shallow three-quarter perspective, no landscape, no lettering, transparent sky and ground.

第二批等待本批验收。Godot 中需再检查状态切换时的脚底锚点与三路站位。未改客户端或服务端代码。
