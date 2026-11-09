# 架构与产品决策记录（ADR）

> 只记录已经定下、会影响后续开发的决定。  
> 新决定追加，不覆盖旧决定；被推翻的标注“已废弃”。

---

## ADR-001 引擎与平台

- 决定：Godot 4.7.2，Android 优先，独立 App。
- 放弃：Cocos、微信小游戏/小程序。
- 原因：现有原型可运行，导出链已打通。

## ADR-002 核心玩法

- 决定：班级级轻战争策略；地图 + 每日军令 + 21:00 结算 + 4 周赛季。
- 不做：实时国战、开放世界、抽卡、付费变强。
- 当前里程碑：5 节点三回合切片。

## ADR-003 数据库对接

- 决定：不复制学生账号/班宠/积分。
- 学生：`students`；教师：`admin`；班宠：`student_pets` / `pet_templates`。
- 积分：只读 `students.score` + `shop_orders`；兑换只追加 `shop_orders`（`game_recharge`）。
- 红线：不修改 `students.score`。

## ADR-004 逆向与参考

- 决定：不反编译商业游戏、不复制商业素材。
- 参考：Unciv（MPL-2.0）只读源码，借结构不借代码/素材。
- 已落地：战局回放。

## ADR-005 三个 Agent 的治理

- 产品主心骨：用户。
- 技术主心骨：OpenCode（后端、API、合并、发布、冲突裁决）。
- 前端负责人：Antigravity（Godot 客户端）。
- 美术 + 终审：GPT。
- 单一主干：`main` 受保护，只有技术主心骨合并。
- 详见 `GOVERNANCE.md`。

## ADR-006 部署形态

- 当前：家庭实验室 Docker Compose + MariaDB + Cloudflare Tunnel。
- 异步 API 与数据库同机/同 Docker 网络，不暴露 `3306`。
- 云服务器：实时房间服/Redis，不直连数据库；通过 Tailscale 调家庭 API。
- 生产迁移未执行。

## ADR-007 美术路线

- 风格：Q版纸雕绘本卡通。
- GPT 负责概念图、UI、城池/图标/班宠资产 + 最终视觉审查。
- Antigravity 负责资产接入 Godot。
- 图中不写文字；文字由 Godot 渲染。
- 详见 `ART_BRIEF_GPT.md`。
