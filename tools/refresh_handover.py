from pathlib import Path
import shutil

ROOT = Path(r"D:\DeskBox\游戏")
H = ROOT / "handover"

# 1. Add a dated status block to HANDOVER.md (idempotent).
handover_md = H / "HANDOVER.md"
text = handover_md.read_text(encoding="utf-8")
marker = "2026-11-10 增量更新"
section = """> **2026-11-10 增量更新**：
> - 美术回到用户确认的 C 原版：横屏 `map_c.png`、竖屏 `map_c_portrait.png`、v2 五城地标（去掉红金边框）；
> - 手机竖屏主地图已接 C 原画；S02 城池抽屉补“城池小传”，并修手机端按钮裁切；
> - 教师控制台新增现有后台同源代理 `deploy/teacher-web/`，学生 App 不出现教师登录；
> - 自动验收巡检 `tools/watch_acceptance.ps1` 已安装为 Windows 计划任务，每 30 分钟一次；2026-11-10 01:04 全量 PASS；
> - APK 81.8 MB，含 C 横屏/竖屏地图与 v2 地标；
> - 仍未执行：生产库迁移、真实服务器部署、8–12 名学生三回合试跑。

"""
if marker not in text:
    text = text.replace("## 0. 审核人先看什么", section + "## 0. 审核人先看什么", 1)
    handover_md.write_text(text, encoding="utf-8")

# 2. Root docs.
docs = H / "docs"
docs.mkdir(parents=True, exist_ok=True)
for p in ROOT.glob("*.md"):
    shutil.copy2(p, docs / p.name)

# 3. Server slice (no secrets / logs / test DB).
server_dst = H / "server" / "slice"
if server_dst.exists():
    shutil.rmtree(server_dst)
def ignore_server(dir_path, names):
    blocked = {"config.local.php", "logs", "testdb", "__pycache__"}
    return [n for n in names if n in blocked]
shutil.copytree(ROOT / "server" / "slice", server_dst, ignore=ignore_server)

# 4. Teacher same-origin proxy.
deploy_dst = H / "deploy" / "teacher-web"
if deploy_dst.exists():
    shutil.rmtree(deploy_dst)
shutil.copytree(ROOT / "deploy" / "teacher-web", deploy_dst)

# 5. Client source, tests and art assets.
client_dst = H / "client"
client_dst.mkdir(parents=True, exist_ok=True)
for name in [
    "project.godot", "export_presets.cfg", "icon.svg",
    "Api.gd", "Slice.gd", "SliceMap.gd", "ReplayMap.gd", "Slice.tscn",
    "Main.gd", "Main.tscn", "Map.gd", "MapCanvas.gd", "MapOverlay.gd", "Map.tscn",
]:
    src = ROOT / "client" / name
    if src.is_file():
        shutil.copy2(src, client_dst / name)

tests_dst = client_dst / "tests"
tests_dst.mkdir(parents=True, exist_ok=True)
for p in (ROOT / "client" / "tests").glob("*"):
    if p.is_file() and p.suffix in {".gd", ".tscn"}:
        shutil.copy2(p, tests_dst / p.name)

art_dst = client_dst / "assets" / "art"
if art_dst.exists():
    shutil.rmtree(art_dst)
shutil.copytree(ROOT / "client" / "assets" / "art", art_dst)

# 6. Latest screenshots with stable names.
shots = H / "screenshots"
shots.mkdir(parents=True, exist_ok=True)
shot_map = {
    "screenshot_login_keyart.png": "03_slice_login.png",
    "screenshot_tablet_s01_map.png": "04_slice_game.png",
    "screenshot_tablet_s04_war_report.png": "06_slice_report.png",
    "screenshot_tablet_s05_battle_replay.png": "07_slice_replay.png",
    "screenshot_phone_portrait_s01_map.png": "08_phone_map.png",
    "screenshot_phone_portrait_s02_drawer.png": "09_phone_drawer.png",
    "screenshot_tablet_s10_season.png": "10_tablet_season.png",
    "screenshot_tablet_s02_drawer.png": "11_tablet_drawer.png",
}
for src_name, dst_name in shot_map.items():
    src = ROOT / "client" / "tests" / src_name
    if src.is_file():
        shutil.copy2(src, shots / dst_name)

# 7. APK.
build_dst = H / "build"
build_dst.mkdir(parents=True, exist_ok=True)
apk = ROOT / "client" / "build" / "android" / "qingzhu_slice.apk"
if apk.is_file():
    shutil.copy2(apk, build_dst / "qingzhu_slice.apk")

# 8. Watcher scripts.
tools_dst = H / "tools"
tools_dst.mkdir(parents=True, exist_ok=True)
for name in [
    "watch_acceptance.ps1", "watch_probe.py", "watch_report.py", "install_acceptance_watch.ps1",
]:
    src = ROOT / "tools" / name
    if src.is_file():
        shutil.copy2(src, tools_dst / name)

print("handover refreshed")
