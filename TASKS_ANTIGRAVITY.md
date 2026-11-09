# Antigravity 第一批任务

> 基线：`COLLAB_ANTIGRAVITY.md`  
> 目标：只改客户端，不改后端/数据库。

---

## 任务 1：战局回放 UI 打磨

文件：

```text
client/Slice.gd
client/ReplayMap.gd
```

要求：

- 回放弹窗在 1400×1000 和平板比例下不溢出；
- 回合下拉、上一回合/下一回合可点；
- 变化城池高亮明显，但不遮挡旗标/城名；
- 无已结算回合时显示空状态，不弹空窗；
- 不改变 `GET /api/slice/replay` 的字段。

验收：

```powershell
godot --headless --path client res://tests/ReplaySmoke.tscn
```

期望：`REPLAY_SMOKE PASS`。

---

## 任务 2：加载/断线/错误态

文件：

```text
client/Slice.gd
client/Api.gd
```

要求：

- 登录失败显示服务器返回的中文错误；
- 请求超时显示“无法连接服务器”，不白屏；
- Token 过期自动回登录页；
- 提交军令时按钮不重复触发；
- 不修改后端错误码。

验收：

```powershell
godot --headless --path client res://tests/ClientSmoke.tscn
```

期望：`CLIENT_SMOKE PASS`。

---

## 任务 3：地图可读性

文件：

```text
client/SliceMap.gd
client/ReplayMap.gd
```

要求：

- 5 个节点在手机/平板上不重叠；
- 选中环、归属色、中立色可区分；
- 起点和普通城有明确标识；
- 不引入新美术依赖，先用代码绘制。

验收：

- 真机截图 1 张；
- 不改变 `SliceService` 返回的坐标字段。

---

## 交付格式

```text
改了什么：
改了哪些文件：
跑了什么验收：
结果：
截图：
阻塞：
```

不要改：

```text
server/slice/src/
server/slice/schema.sql
server/slice/migrations/
deploy/lingchong/
HANDOVER.md
```
