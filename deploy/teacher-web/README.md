# 教师 Web 控制台接入现有后台

> 目标：不让学生 App 出现教师登录；教师继续用现有后台 `Auth::checkAdmin()`，在后台里锁令/结算/下一回合。  
> 方式：**同源 PHP 代理**。浏览器不接触游戏 API 的教师 Token/服务账号。

---

## 1. 放到现有系统哪里

把本目录两个文件复制到现有班级系统：

```text
admin_lingchong.php      → admin/lingchong.php
api_admin_lingchong.php  → api/admin/lingchong.php
```

现有系统路径示例：

```text
D:\DeskBox\班级量化考核系统\班级量化考核管理系统网页前后端\
  admin\lingchong.php
  api\admin\lingchong.php
```

不覆盖现有文件；这是新增页面。

---

## 2. 环境变量

在现有 Web 容器的 `.env` 或系统环境里加：

```text
LINGCHONG_API_URL=http://lingchong-api
LINGCHONG_ADMIN_USER=teacher
LINGCHONG_ADMIN_PASS=换成服务教师密码
```

- `LINGCHONG_API_URL`：游戏 API 容器内网地址；同机 Docker 可用 `http://lingchong-api`，本机测试可用 `http://127.0.0.1:8090`。
- `LINGCHONG_ADMIN_USER/PASS`：游戏 API 里 `slice_players.role='teacher'` 对应的管理员账号；**不要用真实管理员主账号密码**，建议单独建一个服务教师账号。
- 这三个值只在服务器端，不写入前端 JS，不进公开仓库。

---

## 3. 菜单入口

在现有后台侧边栏 `admin/sidebar.php` 加一项：

```html
<a href="lingchong.php" class="...">
  <i class="ri-sword-line"></i><span>灵宠山河</span>
</a>
```

具体 class 按现有侧边栏样式复制，不要改布局。

---

## 4. 页面能力

`admin/lingchong.php`：

- 继续使用现有 `Auth::checkAdmin()`；
- 复用 `admin/sidebar.php` 和 `admin/css/admin.css`；
- 显示：
  - 当前回合/状态/参与人数；
  - 锁定本回合；
  - 结算；
  - 下一回合；
  - 刷新状态；
- 所有请求走 `api/admin/lingchong.php` 同源代理。

`api/admin/lingchong.php`：

- 校验 `Auth::checkAdmin()`；
- 校验同源请求；
- 服务端登录游戏 API（服务教师账号），缓存 Token；
- 转发 `status / lock / settle / next-turn`；
- 返回原始 JSON 给后台页面；
- 不把 Token 返回浏览器。

---

## 5. 部署顺序

1. 游戏 API 已在家庭实验室/云上跑通；
2. 现有 Web 容器能内网访问 `LINGCHONG_API_URL`；
3. 复制两个文件；
4. 配环境变量；
5. 加侧边栏入口；
6. 打开 `/admin/lingchong.php`，先点“刷新状态”；
7. 用测试局验证锁令/结算/下一回合；
8. 再上生产。

---

## 6. 安全要求

- 游戏 API 管理接口不要直接暴露公网；只让现有后台代理访问；
- 服务教师账号只用于代理，不告诉学生；
- 代理校验 `Auth::checkAdmin()`；
- 代理校验同源 `Origin/Referer`；
- 代理只允许白名单动作，不接受任意 URL；
- 所有锁令/结算/下一回合写审计日志；
- 不在浏览器 localStorage/sessionStorage 保存游戏教师 Token；
- 不在前端 JS 写 `LINGCHONG_ADMIN_PASS`。

---

## 7. 为什么不 iframe `/teacher`

- iframe 会再出现一次教师登录；
- Token 在浏览器里；
- 样式/移动端不统一；
- 现有后台的权限、菜单、审计无法复用。

同源代理是正式版做法；独立 `/teacher` 只保留给本地测试。
