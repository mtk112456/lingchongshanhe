# 指挥台自动化

> 目标：你只给 OpenCode 发指令；OpenCode 拆任务、发给 Antigravity / GPT/Codex、跑验收、合并。
> 现状：GPT/Codex 有官方 CLI；Antigravity 没有官方 CLI，通过本地 CDP 桥接，属于半自动。

---

## 1. 当前可用的通道

| 目标 | 方式 | 状态 |
|---|---|---|
| GPT / Codex | `codex queue --thread <uuid> --message "..."` | ✅ 已验证 |
| GPT / Codex（新任务） | `codex exec ...` | ✅ CLI 可用 |
| Antigravity | 本地 CDP `http://127.0.0.1:16165` + `tools/cdp_send_message.mjs` | ✅ 已验证 |
| GitHub | `git` + REST API；`gh` 未安装 | 🟡 需要时可装 `gh` |
| 人工兜底 | 把 `tools/message_antigravity.txt` 贴进会话 | ✅ 始终可用 |

---

## 2. 发消息给 Antigravity

前提：

- Antigravity 正在运行；
- 对应会话已打开；
- 本地调试端口 `16165` 可访问。

```powershell
node tools/cdp_send_message.mjs <conversation-id> tools/message_antigravity.txt
```

如果返回 `after.length > 0`，说明消息还在输入框，未发送；再执行：

```powershell
node tools/cdp_eval.mjs <conversation-id> tools/cdp_click_send.js
```

确认输入框清空：

```powershell
node tools/cdp_eval.mjs <conversation-id> tools/cdp_composer_state.js
```

注意：

- 只操作输入框和发送按钮，不读取页面正文；
- 不把会话 ID、服务器信息写进公开仓库；
- Antigravity 更新后 DOM 可能变化，选择器失效就改 `tools/cdp_*`；
- 这不是官方 API，只用于当前机器上的协作。

---

## 3. 发消息给 GPT / Codex

```powershell
codex queue --thread 01a1bfd0-2f92-73d0-ae9f-fb003d92c616 --message "..."
```

非交互任务：

```powershell
codex exec --sandbox workspace-write "按 AGENTS.md 完成任务 ..."
```

注意：

- 不要让它直接 push `main`；
- 让它开分支/PR；
- 完成后 OpenCode 跑验收并合并。

---

## 4. 标准指挥流程

```text
你 → OpenCode
  → 写任务/验收
  → 发 Antigravity（前端）
  → 发 GPT/Codex（美术/审查）
  → 收 PR
  → 跑 ClientSmoke / ReplaySmoke / PHP 14 项
  → 合并 main
  → 打 APK / 更新交接
```

## 5. 当前限制

- Antigravity 没有官方 headless API，CDP 桥接是半自动；
- GPT/Codex 的 `queue` 只能发消息，读回复仍要看它的会话/PR；
- 两个 Agent 不能直接互相对话，必须通过仓库和 OpenCode 转译；
- 全自动合并/发布不建议开启，保留人工/技术主心骨最后一道闸。
