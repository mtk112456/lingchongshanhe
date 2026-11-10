# 第三方技能库

## awesome-gamedev-agent-skills

- **来源**：https://github.com/gamedev-skills/awesome-gamedev-agent-skills
- **版本**：commit `4cce500ce1a779b12fdd824be581c7d2ab4e7ba2`（2026-11-10 拉取）
- **许可**：Apache-2.0，原文见 `.agents/skills/_meta/LICENSE` 与 `.agents/skills/_meta/NOTICE`
- **位置**：`.agents/skills/`（77 个技能 + `router`）
- **用途**：给 OpenCode / Codex / Antigravity 共用的游戏开发技能库，只在被调用时读取，不参与构建，不进 APK。

### 本项目的改动

只改了 33 个非 Godot 引擎技能的 frontmatter，加了两行：

```yaml
metadata:
  opencode/autoinvoke: false
```

涉及：Unity 8、Unreal 6、Ebitengine 1、Phaser/PixiJS/three.js 6、Bevy/pygame/LÖVE/Defold/Roblox 12。

效果是这些技能不再出现在模型可用列表里（本机 OpenCode 实测也无法再按 ID 加载）。文件内容本身未改。

恢复：

```powershell
powershell -File tools/prune_gamedev_skills.ps1 -Root ".agents/skills" -Undo
```

或直接：

```powershell
git checkout -- .agents/skills
```

### 维护约定

- `.agents/skills/` 是第三方只读区，不在这里写项目逻辑；
- 升级时整目录替换，不要手改正文；
- 项目自己的规范仍以 `AGENTS.md`、`GAMEPLAY_DESIGN.md`、`MAP_SPEC.md` 为准，技能库只是参考资料。
