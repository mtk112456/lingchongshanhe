# AGENTS.md · 多 Agent 协作规则

> 适用：OpenCode、Google Antigravity、GPT/Codex，以及未来加入的编码 Agent。  
> 目标：同一份代码、明确边界、可验收，不互相覆盖。  
> 治理与裁决：`GOVERNANCE.md`；已定决策：`DECISIONS.md`；最终验收：`ACCEPTANCE_STANDARD.md`；页面施工图：`SCREEN_SPEC.md` / `PAGE_DESIGN.md`；地图规格：`MAP_SPEC.md`。

---

## 1. 当前基线

- 项目：`D:\DeskBox\游戏`
- 里程碑 A：5 节点三回合切片；
- 后端：14 项自动化验收通过；
- 客户端：Godot 4.7.2，登录/军令/战报/战局回放/教师控制；
- APK：`client/build/android/qingzhu_slice.apk`；
- 部署：`deploy/lingchong/`（Docker + Cloudflare Tunnel，未上真实服务器）；
- 交接：`HANDOVER.md`、`Qingzhu_Lingchong_Handover_20261109_dev_full.zip`。

基线命令：

```powershell
php -d extension_dir="<php>\ext" -d extension=pdo_mysql server/slice/tests/run.php
godot --headless --path client res://tests/ClientSmoke.tscn
godot --headless --path client res://tests/ReplaySmoke.tscn
```

期望：

```text
14 passed, 0 failed
CLIENT_SMOKE PASS
REPLAY_SMOKE PASS
```

---

## 2. 三个 Agent 的分工

| Agent | 主责 | 不碰 |
|---|---|---|
| **OpenCode** | 后端、数据库、API、结算、测试、CI、部署、交接 | 不抢前端 UI 和美术 |
| **Antigravity** | Godot 前端、**设计系统/页面视觉/组件规范/动效**、地图/回放/平板可读性、界面整合、截图 | 不改后端/schema |
| **GPT / Codex** | 美术（概念图/UI/城池/图标/班宠）+ 最终审查/QA | 不在未沟通时改核心业务代码 |

一个文件同一时间只能有一个写入者。  
跨区域改动先开 Issue，写清“允许修改的文件”。

### 设计权

- **Antigravity**：设计主责。页面布局、视觉层级、组件规范、设计系统、动效、可读性由它主导。
- **GPT**：美术资产主责。概念图、地形、城池、UI Kit、图标、班宠、卡面。
- **OpenCode**：技术主责。只给技术约束、验收红线、性能/体积/兼容性要求，不逐页指定像素和视觉风格。
- **用户**：最终审美拍板。

> 设计问题先由 Antigravity 判断；OpenCode 不越权做视觉决策，只验收“能不能用、能不能读、能不能跑”。

### 协作链路

```text
GPT 出美术资产 + Brief
        ↓
Antigravity 接入 Godot 前端并做可读性
        ↓
OpenCode 提供/调整后端接口
        ↓
GPT 最终审查（视觉/文档/验收）
        ↓
OpenCode 合并、打包、交接
```

---

## 3. GitHub 协作工具

已加入：

```text
.github/ISSUE_TEMPLATE/agent_task.yml    # Agent 任务模板
.github/pull_request_template.md         # 交付/验收模板
.github/workflows/backend-tests.yml      # PHP + MariaDB CI
.github/CODEOWNERS                       # 文件归属（替换用户名后启用）
COLLAB_ANTIGRAVITY.md                    # 详细协作约定
TASKS_ANTIGRAVITY.md                     # 客户端首批任务
TASKS_GPT.md                             # GPT 审查任务
```

建议启用：

- GitHub Issues + Projects：每个任务一个 Issue；
- 标签：`agent:opencode`、`agent:antigravity`、`agent:gpt`、`area:server`、`area:client`、`area:deploy`；
- 分支保护：`main` 只接受 PR；
- PR 必须过 `backend-tests`；
- `CODEOWNERS` 按目录分配审查人；
- `gh` CLI 用来创建/认领 Issue、开 PR。

当前目录还不是 Git 仓库/没有 remote。  
建好 GitHub 仓库后：

```bash
git init
git add .
git commit -m "baseline: milestone A slice + replay"
git branch -M main
git remote add origin <你的仓库地址>
git push -u origin main
```

---

## 4. 分支策略

```text
main                       # 可运行基线
feature/client-replay-ui   # Antigravity
feature/cloud-rt           # 云实时房间服（后续）
art/gpt-first-batch        # GPT 美术资产
review/final-gpt           # GPT 最终审查
fix/backend-*              # OpenCode 后端修复
```

- 每个 Agent 一个分支；
- 合并前必须跑验收；
- 不直接 push `main`；
- 大改前先开 Issue，避免两个 Agent 同时改同一文件。

---

## 5. 文件边界

| 路径 | 默认负责人 | 规则 |
|---|---|---|
| `server/slice/src/` | OpenCode | GPT 可审查，改动需 PR |
| `server/slice/schema.sql` / `migrations/` | OpenCode | 必须配迁移 + 测试 |
| `server/slice/tests/` | OpenCode + GPT | GPT 可补对抗测试 |
| `client/*.gd` / `*.tscn` | Antigravity | 不改 API 字段 |
| `client/assets/art/` | Antigravity 接入 | 只放 GPT 已验收/后处理的资产 |
| `art_src/gpt/` | GPT | 原始生成图 + prompt，不直接进游戏 |
| `ART_BRIEF_GPT.md` | GPT | 风格、色板、资产清单、验收 |
| `deploy/lingchong/` | OpenCode / 部署 | 不写真实密码 |
| `HANDOVER.md` / `handover/` | OpenCode | GPT 最终审查后更新 |
| `reference/Unciv/` | 只读 | 不提交、不打包、不复制 |
| `.agents/skills/` | 第三方（Apache-2.0） | 只读技能库，不写项目逻辑；升级整目录替换；来源见 `THIRD_PARTY_NOTICES.md` |

---

## 6. 交付格式

每个 Agent 完成后必须写：

```text
改了什么：
改了哪些文件：
跑了什么验收：
结果：
截图/产物：
没做/阻塞：
```

PR 描述直接套 `.github/pull_request_template.md`。

---

## 7. 红线

1. 不反编译商业游戏；
2. 不复制 Unciv 的代码/美术/音频/文案；
3. 不把真实学生数据放进测试库；
4. 不修改 `students.score`；
5. 积分只追加 `shop_orders`；
6. 不公网暴露 MariaDB `3306`；
7. 不在生产库执行 `schema.sql` / `legacy_schema.sql` / `legacy_seed.sql`；
8. 不把 `.env`、数据库密码、服务器凭据提交到 GitHub；
9. 不覆盖其他 Agent 的未提交改动；
10. 不在没有验收命令的情况下声称“完成”。

---

## 8. 下一个共同目标

**8–12 名真实学生跑三回合切片**，记录：

- 第三回合至少一半首轮参与者主动下令；
- 多数人能解释上一条军令的结果；
- 教师无需每天干预；
- 战报/回放是否帮助学生决定下一步。

在此之前：

- **OpenCode**：后端稳定、部署、测试与交接；
- **Antigravity**：前端可读性、地图/回放/平板适配；
- **GPT**：先出第一批美术资产，再做最终审查（视觉一致性、文档、验收）。
