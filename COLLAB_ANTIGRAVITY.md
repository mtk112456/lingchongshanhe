# 与 Antigravity / GPT 共同开发约定

> 适用：Google Antigravity、GPT/Codex，或另一个能读写本目录的编码 Agent。  
> 多 Agent 总规则见 `AGENTS.md`。  
> 目标：多个 Agent 不互相覆盖、不破坏接口，按文件边界和验收命令协作。

---

## 1. 协作方式

推荐按优先级选：

1. **同一工作区**：Antigravity 直接打开 `D:\DeskBox\游戏`，按本文件分工；
2. **Git 分支**：`main` 保持可运行，各自在 `feature/*` 分支改；
3. **文件交接**：不能共享目录时，用交接包 + 变更说明 + 验收命令。

不建议两个 Agent 同时改同一个文件。  
不要直接改对方的未提交工作；先看 `git status` / 变更说明。

---

## 2. 当前基线

- 里程碑 A：5 节点三回合切片；
- 后端 14 项自动化验收全部通过；
- Godot 客户端：登录、地图、军令、战报、战局回放、教师控制；
- APK：`client/build/android/qingzhu_slice.apk`；
- 数据库：独立测试库，镜像现有 `students` / `admin` / `shop_orders` / `student_pets`；
- 部署文件：`deploy/lingchong/`（未上真实服务器）；
- 交接包：`Qingzhu_Lingchong_Handover_20261109_dev_full.zip` / `..._dev_docs.zip`。

基线验收命令：

```powershell
# 后端
php -d extension_dir="<php>\ext" -d extension=pdo_mysql server/slice/tests/run.php
# 期望：14 passed, 0 failed

# 客户端
godot --headless --path client res://tests/ClientSmoke.tscn
godot --headless --path client res://tests/ReplaySmoke.tscn
# 期望：CLIENT_SMOKE PASS / REPLAY_SMOKE PASS
```

---

## 3. 分工建议

### A. 后端 / 数据库（当前 Agent 负责）

文件：

```text
server/slice/src/
server/slice/public/
server/slice/schema.sql
server/slice/migrations/
server/slice/tests/
```

职责：

- API、事务、锁令、快照、结算、战报、回放；
- 积分/班宠对接；
- 数据库迁移和测试；
- 任何 schema 变化必须配迁移 + 验收用例。

### B. Godot 客户端（建议 Antigravity 负责）

文件：

```text
client/Slice.gd
client/SliceMap.gd
client/ReplayMap.gd
client/Api.gd
client/Slice.tscn
client/project.godot
client/export_presets.cfg
```

职责：

- 手机/平板布局、触控、可读性；
- 战局回放视觉、加载/断线/错误态；
- 不改变 API 字段和结算规则；
- 每次改动跑 `ClientSmoke` / `ReplaySmoke`。

### C. 部署 / 实时（可共同负责）

文件：

```text
deploy/lingchong/
server-deploy（在班级系统目录，非本仓库）
```

职责：

- Docker / Cloudflare Tunnel / 云服务器；
- 实时 WebSocket 房间服（尚未实现）；
- 生产迁移前必须先备份、测试库演练。

### D. 验收 / 交接（当前 Agent 负责）

- 维护 `HANDOVER.md` 和交接包；
- 检查多个 Agent 的改动是否互相冲突；
- 统一版本号和验收结果。

### E. GPT / Codex（独立审查）

- 只读审查后端、积分、权限、文档；
- 在 `server/slice/tests/` 补对抗测试；
- 不改核心业务逻辑，发现 bug 先开 Issue；
- 详细任务见 `TASKS_GPT.md`。

---

## 4. 文件边界

| 范围 | 默认负责人 | 规则 |
|---|---|---|
| `server/slice/src/` | 后端 | 客户端 Agent 不改 |
| `server/slice/schema.sql` / `migrations/` | 后端 | 改前先沟通，必须带迁移和测试 |
| `client/*.gd` / `*.tscn` | 客户端 | 后端 Agent 不改 UI 布局 |
| `deploy/lingchong/` | 部署 | 不写入真实密码 |
| `HANDOVER.md` / `handover/` | 交接 | 只在合并后更新 |
| `reference/Unciv/` | 参考 | 不提交、不打包、不复制代码 |

---

## 5. API 契约

当前接口：

```text
POST /api/auth/login
POST /api/auth/admin-login
GET  /api/slice/state
POST /api/slice/orders
POST /api/slice/orders/withdraw
GET  /api/slice/report?turn_id=
GET  /api/slice/replay
GET  /api/slice/history
GET  /api/slice/wallet
POST /api/slice/recharge
GET  /api/slice/admin/status
POST /api/slice/admin/lock
POST /api/slice/admin/settle
POST /api/slice/admin/next-turn
```

规则：

- 改字段必须同步 `server/slice/INTEGRATION.md` 和客户端；
- 写接口必须带 `turn_id` + `request_key`；
- 不得修改 `students.score`；
- 积分只追加 `shop_orders`（`game_recharge`）；
- 不得把数据库密码写进代码或镜像。

---

## 6. Git 建议

如果还不是 Git 仓库，建议先：

```bash
git init
git add .
git commit -m "baseline: milestone A slice + replay"
```

分支：

```text
main                      # 可运行基线
feature/client-replay-ui  # Antigravity 客户端
feature/cloud-rt          # 云实时房间服
feature/backend-fixes     # 后端修复
```

提交格式：

```text
feat(client): improve replay map readability
fix(server): handle empty advance_from for teacher
test(slice): add replay owner snapshot case
docs(handover): update deployment status
```

---

## 7. 每次交付格式

每个 Agent 完成后发一段：

```text
改了什么：
  - ...
改了哪些文件：
  - ...
跑了什么验收：
  - ...
结果：
  - 通过 / 失败
截图/产物：
  - ...
没做什么/阻塞：
  - ...
```

不要只说“改好了”。

---

## 8. 第一批可分配任务

### 给 Antigravity

1. 客户端 5 节点地图/回放弹窗视觉打磨；
2. Android 平板可读性和触控检查；
3. 加载、断线、空战报、回放空状态；
4. 不改后端、不改 schema；
5. 完成后跑 `ClientSmoke` + `ReplaySmoke`，附截图。

### 给当前 Agent

1. 维护后端 14 项验收；
2. 生产迁移演练脚本；
3. 云实时房间服骨架（WebSocket + 内部鉴权）；
4. 合并 Antigravity 的客户端改动并重打包。

---

## 9. 禁区

1. 不反编译商业游戏；
2. 不复制 Unciv 代码/素材；
3. 不把真实学生数据放进测试库；
4. 不修改 `students.score`；
5. 不公网暴露 `3306`；
6. 不在生产库执行 `schema.sql` / `legacy_schema.sql` / `legacy_seed.sql`；
7. 不覆盖对方的未提交改动；
8. 不把 `.env`、数据库密码、服务器凭据写入仓库或交接包。
