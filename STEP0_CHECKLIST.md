# Step 0：Godot 三端管线验证清单（不做小程序）

> 目标：在写玩法之前，先证明 Godot 能导出 Android APK，并能跑中文 UI  
> 引擎：Godot 4.7.2 stable（MIT）  
> 当前日期：2026-11-09

---

## 一、本机环境

| 工具 | 状态 | 路径/说明 |
|---|---|---|
| Godot 4.7.2 | ✅ 已下载并校验 | `D:\DeskBox\游戏\tools\Godot_v4.7.2-stable\Godot_v4.7.2-stable_win64.exe` |
| Godot 控制台版 | ✅ | `...\Godot_v4.7.2-stable_win64_console.exe` |
| Node.js | ✅ | `C:\Program Files\nodejs\node.exe` |
| Java | ✅ | `C:\Program Files\Microsoft\jdk-21.0.13.21-hotspot` |
| adb | ✅ | `E:\scrcpy\adb.exe` |
| Android SDK | ✅ | `C:\Users\MTK\AppData\Local\Android\Sdk` |
| 微信开发者工具 | ✅ 已装但暂不使用 | `E:\微信web开发者工具\微信开发者工具.exe` |
| Cocos Creator | ❌ 已放弃 | 不做小程序，不再使用 |
| D 盘空间 | ✅ 497 GB | 项目/导出模板放 D 盘 |
| 测试设备 | ✅ | OPD2405 / Android 16 / 2000×2800 |

> Godot 版本验证：`4.7.2.stable.official.ed1daf0bf`

---

## 二、还需要下载

### 1. Godot 导出模板（必须）

Android/Web 导出需要 `Godot_v4.7.2-stable_export_templates.tpz`（约 1.2 GB）。

- 官方地址：  
  `https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz`
- 如果 GitHub 下载慢，用镜像：  
  `https://gh-proxy.com/https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz`
- 下载后校验 SHA256（见 GitHub release 的 digest）。

安装方式：

1. 打开 Godot；
2. 菜单 `Editor → Manage Export Templates`；
3. 点 `Install from File`；
4. 选择 `.tpz` 文件；
5. 安装完成后，Android/Web 导出模板可用。

### 2. Android SDK 环境变量

```text
ANDROID_HOME = C:\Users\MTK\AppData\Local\Android\Sdk
ANDROID_SDK_ROOT = C:\Users\MTK\AppData\Local\Android\Sdk
```

Godot 里：

- `Editor → Editor Settings → Export → Android`
- `Android SDK Path`：`C:\Users\MTK\AppData\Local\Android\Sdk`
- `Java SDK Path`：`C:\Program Files\Microsoft\jdk-21.0.13.21-hotspot`
- 如果 JDK 21 不兼容，安装 JDK 17 并指向 JDK 17。

### 3. Android 调试签名

Godot 首次导出 Android 调试包会自动生成 debug keystore；正式发布再配 release keystore。

---

## 三、Step 0 验证步骤

### 1. 新建 Godot 项目

- 路径：`D:\DeskBox\游戏\client`
- 渲染器：**Compatibility**（低端安卓/2D 更稳）
- 项目名：`青竹文房：灵宠山河`

### 2. 最小场景

- `Main.tscn`
- 一个 `Label`：文字“青竹文房”
- 一个 `Button`：文字“开始”
- Button 的 `pressed` 信号打印 `开始` 到控制台

### 3. 编辑器内运行

- 按 F6/F5；
- 能看到中文 Label/Button；
- 点 Button 控制台有输出。

### 4. 导出 Android APK

- `Project → Export → Android`
- 添加 Android 预设；
- 导出 debug APK；
- 安装到安卓手机/模拟器；
- 打开能看到 Label/Button，能点。

### 5. 导出 Web（可选）

- `Project → Export → Web`
- 导出到 `build/web`；
- 用本地 HTTP 服务打开（不要直接 file://）；
- 能看到 Label/Button。

> 不做微信小游戏，Web 只用于老师大屏/本地测试，可选。

---

## 四、验收记录

| 项目 | 目标 | 实际 | 通过 |
|---|---|---|---|
| Godot 编辑器启动 | 正常 | 4.7.2 | ☑ |
| 导出模板 | 已安装 | 4.7.2.stable | ☑ |
| 无头运行 | 输出“青竹文房 启动” | 成功 | ☑ |
| 中文字体 | 已导入 Noto Serif CJK SC | 24.5MB | ☑ |
| Android APK | 能生成、签名 | 50.1MB，已签名 | ☑ |
| APK 包名 | `com.qingzhu.lingchongshanhe` | 已核对 | ☑ |
| 真机安装 | 能安装、能打开 | OPD2405 / Android 16 | ☑ |
| 中文显示 | 不乱码 | 截图 `client/build/android/screenshot5.png` | ☑ |
| Android 点击 | Button 有响应 | Godot 日志输出“开始” | ☑ |
| Web 构建 | 能打开（可选） | 待填 | ☐ |
| 首屏时间 | <3 秒 | 待填 | ☐ |
| 低端安卓帧率 | ≥30fps | 待填 | ☐ |

---

## 五、Step 0 不通过怎么办

| 问题 | 处理 |
|---|---|
| 中文乱码 | 项目设置里加中文字体（思源宋体/Noto Serif SC） |
| Android 导出失败 | 检查 SDK/JDK 路径、导出模板是否安装 |
| APK 装不上 | 检查 minSdk/架构（arm64-v8a） |
| Web 打不开 | 用 `python -m http.server` 或 Node 静态服务，不要 file:// |
| 帧率低 | 先确认空项目；空项目低就是设备/渲染器问题 |
| 包体大 | 先看空项目基线；后面再压资源 |

---

## 六、下一步

Step 0 通过后，进入 Step 1：

- 12 节点地图；
- 4 阵营；
- 3 军令；
- 21:00 结算模拟；
- 接 PHP/MySQL 的 `game_war_*` 表。

> 在 Step 0 通过前，不写卡牌、不写经营、不写 13 个玩法。
