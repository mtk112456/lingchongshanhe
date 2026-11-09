# 项目治理 · 单主心骨

> 三个 Agent 可以同时开发，但必须只有一个技术主心骨、一个主干、一个合并入口。  
> 否则一定会出现接口冲突、重复改同一文件、谁都说“我改好了”。

---

## 1. 谁说了算

| 角色 | 人/Agent | 决策范围 |
|---|---|---|
| **产品主心骨** | 你 | 做什么、不做什么、优先级、预算、最终验收 |
| **技术主心骨** | OpenCode | 架构、API 契约、数据库、合并、发布、冲突裁决 |
| **前端负责人** | Antigravity | Godot 客户端、地图/回放/平板可读性 |
| **美术 + 终审** | GPT | 风格、资产、视觉一致性、最终审查 |

一句话：

> **你定方向，我定技术，Antigravity 定前端实现，GPT 定美术和终审。**

如果技术主心骨和前端/美术意见冲突：

- API/数据库/架构 → 技术主心骨拍板；
- 产品范围/优先级 → 你拍板；
- 视觉风格 → GPT + 你拍板；
- 前端具体实现 → Antigravity 拍板。

---

## 1.5 外部 Agent 会话怎么桥接

OpenCode、Antigravity、GPT/Codex 的对话上下文**不互通**，也不能靠互相 @ 来同步。

做法：

1. 你保存三个会话 ID（只放本地 `.agents.local.md`，不要提交公开仓库）；
2. 每次切换 Agent 时，让它先读：
   - `AGENTS.md`
   - `GOVERNANCE.md`
   - `DECISIONS.md`
   - 当前 Issue/PR
3. 所有结论写回 GitHub Issue/PR，不写在聊天里；
4. 合并/发布只由技术主心骨做；
5. 需要跨 Agent 决策时，由你把问题贴到对应会话，再把结论写进 Issue。

**会话 ID 属于本地协作信息，不进入公开仓库。**

---

## 2. 单一主干

```text
main                  # 唯一可运行分支，受保护
  ↑ PR
feature/*             # 功能分支
fix/*                 # 修复分支
art/*                 # GPT 美术资产
review/*              # GPT 终审
```

规则：

- 任何人/Agent 不直接 push `main`；
- 只有技术主心骨可以合并到 `main`；
- 合并前必须过 CI；
- 合并后再统一打包、更新交接包；
- 大改前先开 Issue，写清“允许修改的文件”。

---

## 3. 三个人怎么同时开发

不是三个人改同一个目录，而是三个独立工作区：

```bash
# 主工作区：技术主心骨
git worktree add ../lingchong-antigravity feature/client-replay-ui

# 美术工作区：GPT
git worktree add ../lingchong-gpt-art art/gpt-first-batch

# 终审工作区：GPT 只读/测试
git worktree add ../lingchong-review review/final-gpt
```

每个 Agent 只在自己的 worktree 改文件，通过 PR 回合。

如果 Antigravity/GPT 不在同一台机器：

- 用 GitHub 仓库 + 分支；
- 不要用网盘同步同一个工作目录；
- 不要互相覆盖未提交文件。

---

## 4. 并行开发的三个契约

### 4.1 API 契约

- 后端接口以 `server/slice/INTEGRATION.md` 为准；
- 前端不得私自改字段名；
- 需要新增字段 → 技术主心骨先改契约 + 测试，再通知前端；
- 前端可以先 mock，但不能把 mock 字段带进正式接口。

### 4.2 文件契约

- 一个文件同一时间只有一个写入者；
- `server/slice/src/` 归技术主心骨；
- `client/*.gd` / `*.tscn` 归 Antigravity；
- `art_src/gpt/` 归 GPT；
- `client/assets/art/` 只放 GPT 已交付、Antigravity 已接入的资产；
- `HANDOVER.md` / `handover/` 只在合并后由技术主心骨更新。

### 4.3 美术契约

- 风格/色板/尺寸/命名以 `ART_BRIEF_GPT.md` 为准；
- GPT 先交 `art_src/gpt/` 原图 + prompt；
- Antigravity 负责后处理和 Godot 接入；
- 图里不能有文字，文字由 Godot 渲染；
- 不复制 Unciv 或商业游戏素材。

---

## 5. 任务流

```text
你/技术主心骨写 Issue
  → Agent 认领
  → 开分支
  → 实现
  → 跑验收
  → 开 PR
  → CI
  → GPT 终审（视觉/文档）
  → 技术主心骨合并
  → 技术主心骨打包/更新交接
```

Issue 必须包含：

- 负责人；
- 允许修改的文件；
- 验收命令；
- 禁止事项。

模板：`.github/ISSUE_TEMPLATE/agent_task.yml`。

---

## 6. 冲突裁决

| 冲突 | 裁决人 |
|---|---|
| 接口字段/数据库结构 | 技术主心骨 |
| 功能优先级/是否砍掉 | 产品主心骨（你） |
| 视觉风格/资产验收 | GPT + 你 |
| 前端交互实现 | Antigravity |
| 两个 Agent 都说自己对 | 技术主心骨写 ADR，必要时你拍板 |

ADR（架构决策记录）放在 `DECISIONS.md`。

---

## 7. 完成标准

一个任务只有同时满足以下条件才算完成：

- 代码/资产已提交；
- 验收命令通过；
- 没有修改禁区；
- 没有提交密钥/真实学生数据；
- PR 描述完整；
- 需要时附截图；
- 技术主心骨已合并。

“我改好了”不算完成。

---

## 8. 当前三个人的第一批任务

### OpenCode（技术主心骨）

- 把本地仓库接到 GitHub；
- 保护 `main`；
- 维护 14 项后端验收；
- 提供稳定 API；
- 合并 PR、打包、更新交接。

### Antigravity（前端）

- 战局回放 UI 打磨；
- 平板/手机可读性；
- 加载/断线/空状态；
- 接入 GPT 资产；
- 每次 PR 附截图。

### GPT（美术 + 终审）

- 先出 3 张风格锁定图；
- 再出主视觉、UI Kit、5 城池标记、2 个班宠；
- 最终审查视觉一致性、文档、验收；
- 不直接改核心业务代码。

---

## 9. 现在最重要的一件事

不是继续加功能，而是：

> **把 `main` 保护起来，把三个人的任务拆成 Issue，把每次合并都跑一遍验收。**

否则三个 Agent 同时改，最后一定互相覆盖。
