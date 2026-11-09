# GitHub 工具与插件建议

> 目标：让 OpenCode / Antigravity / GPT 三个会话通过 GitHub 协作，而不是互相聊天。  
> 原则：先用 GitHub 自带功能，再装少量插件；不要装一堆会互相打架的机器人。

---

## 1. 先用自带的

| 功能 | 用途 |
|---|---|
| Issues | 每个任务一个 Issue，带负责人/文件/验收 |
| Projects | Kanban：待做 / 进行中 / 待审 / 完成 |
| Pull Requests | 所有改动走 PR，不直接 push `main` |
| CODEOWNERS | 按目录指定审查人 |
| Branch protection | `main` 必须过 CI + 审查 |
| Actions | 后端测试、Godot 检查、APK 构建 |
| Releases | 发 APK/交接包 |
| Discussions | 长讨论/设计决策，不塞进 Issue |
| Secret scanning | 防止数据库密码/Tokens 进仓库 |

---

## 2. 推荐加的工具

### 2.1 GitHub MCP Server

仓库：`github/github-mcp-server`

用途：

- 让 Agent 通过 MCP 读写 Issue、PR、Actions；
- 比让 Agent 猜 `gh` 命令更稳；
- 适合 Antigravity / Codex / OpenCode 接同一套 GitHub 工作流。

注意：

- 用 fine-grained PAT，只给需要的仓库权限；
- 不要把 token 写进代码；
- 只读审查 Agent 不需要写权限。

### 2.2 Git LFS

GPT 的美术资产会越来越大，普通 Git 仓库不适合塞 PSD/大 PNG。

```bash
git lfs install
git lfs track "art_src/**/*.png"
git lfs track "art_src/**/*.psd"
git lfs track "client/assets/art/**/*.png"
```

注意：

- 只对大图/PSD 用 LFS；
- 图标/小图不必；
- 交接包仍单独打包，不依赖 LFS。

### 2.3 calibreapp/image-actions

用途：PR 里自动压缩 PNG/JPG，避免 GPT 原图把仓库撑大。

- Marketplace 搜 `Image Actions`；
- 只压缩，不改构图；
- 对透明 UI 资产要检查是否损失边缘。

### 2.4 Release Drafter + action-gh-release

用途：

- 自动生成 Release Notes；
- 上传 `qingzhu_slice.apk`；
- 每个里程碑一个 release。

### 2.5 Dependabot

用途：

- 自动升级 GitHub Actions 版本；
- 不碰业务依赖；
- 每周一次即可。

### 2.6 Godot 检查/导出 Action

可选：

- `firebelley/godot-export`；
- `chickensoft-games/setup-godot`；
- `barichello/godot-ci` Docker 镜像。

用途：

- headless 导入项目；
- `--check-only` 检查 GDScript；
- 构建 APK 并上传 artifact。

注意：Godot 版本必须固定（当前 4.7.2），不要把 `latest` 写进 CI。

### 2.7 GDScript lint

- `gdtoolkit` 的 `gdlint` / `gdformat`；
- 只检查格式/明显错误，不自动改 UI 逻辑。

### 2.8 PHP 静态检查

- `phpstan/phpstan`；
- `PHP-CS-Fixer`；
- 先只对 `server/slice/src/` 开低级别规则，避免一上来几百条。

### 2.9 PR 自动化（可选）

- `reviewdog`：把 lint 结果贴到 PR 行内；
- `Danger JS`：检查 PR 描述/验收；
- `actions/labeler`：按路径自动打 `area:client` / `area:server` 标签。

---

## 3. 本项目最小组合

只装这 5 个：

1. **Projects + Issues**（自带）
2. **Actions**：`backend-tests`（已有）+ Godot 检查 + APK 构建
3. **Git LFS**：GPT 美术资产
4. **GitHub MCP Server**：三个 Agent 读写 Issue/PR
5. **Release Drafter**：发 APK/交接包

可选再加：

- `image-actions`（图片压缩）
- `Dependabot`（Actions 版本）
- `reviewdog`（PR 行内 lint）

不要一开始装：

- 自动 merge 机器人；
- 自动改代码的“AI PR 机器人”；
- 多个重复的 label/board 机器人；
- 需要宽权限的第三方 App。

---

## 4. 三个 Agent 怎么用这些工具

### OpenCode（技术主心骨）

- 读 Issue；
- 改后端；
- 跑 `backend-tests`；
- 合并 PR；
- 发 Release。

### Antigravity（前端）

- 读 `area:client` Issue；
- 改 Godot 客户端；
- 跑 `ClientSmoke` / `ReplaySmoke`；
- PR 里附截图。

### GPT（美术 + 终审）

- 在 `art/gpt-first-batch` 分支交资产；
- 用 LFS 存大图；
- 审 PR 的视觉一致性和文档；
- 不直接改核心代码。

---

## 5. 权限建议

| 工具 | 权限 |
|---|---|
| GitHub MCP（OpenCode） | Issues/PR 读写、Actions 读 |
| GitHub MCP（Antigravity） | Issues/PR 读写、Contents 读写 |
| GitHub MCP（GPT 审查） | Issues/PR 读、Contents 读 |
| Actions | `contents: read` 起步，发布时再给 `contents: write` |
| 第三方 App | 最小仓库、最小权限 |

---

## 6. 不要做的事

- 不要把数据库密码、`.env`、真实学生数据放进 GitHub；
- 不要让第三方 App 拥有所有仓库权限；
- 不要让多个机器人同时改 label/assignee；
- 不要让 CI 自动 push `main`；
- 不要用 `pull_request_target` 跑不可信 PR 的代码；
- 不要把 GPT 原图不压缩直接塞进 Git 历史。
