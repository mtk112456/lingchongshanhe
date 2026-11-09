# GPT / Codex 审查任务

> 角色：独立审查者 + 对抗测试，不是第二个主开发者。  
> 分支：`review/gpt-slice`  
> 基线：`AGENTS.md`

---

## 任务 1：结算/并发对抗测试

允许修改：

```text
server/slice/tests/
```

不允许修改：

```text
server/slice/src/
server/slice/schema.sql
server/slice/migrations/
client/
```

目标：

- 补边界用例：截止瞬间提交、重复 request_key、锁令后提交、结算失败重试、平局/无行动；
- 尝试找出“同一回合两个结算任务”“快照被实时数据污染”“积分重复入账”等问题；
- 只加测试，不改业务逻辑；发现 bug 先写 Issue。

验收：

```powershell
php -d extension_dir="<php>\ext" -d extension=pdo_mysql server/slice/tests/run.php
```

期望：全部通过（14+，新增用例计入）。

---

## 任务 2：积分/权限安全审查

只读审查：

```text
server/slice/src/PointsService.php
server/slice/src/SliceService.php
server/slice/schema.sql
server/slice/INTEGRATION.md
```

检查：

- 是否存在修改 `students.score` 的路径；
- 是否可能重复写 `shop_orders`；
- 是否可能跨局读取/下令；
- 教师/学生权限是否混用；
- 积分日上限是否按北京时间；
- 是否有 SQL 注入/密钥泄漏风险。

输出：

```text
发现：
  - 文件:行 问题 严重级别
建议：
  - ...
未验证：
  - ...
```

---

## 任务 3：文档/契约校对

只读：

```text
DEVELOP_SPEC.md
HANDOVER.md
server/slice/INTEGRATION.md
deploy/lingchong/README.md
deploy/lingchong/CLOUD.md
```

检查：

- 文档与代码是否一致（14 项测试、接口、迁移、部署路径）；
- 有没有把“未实现”写成“已实现”；
- 有没有生产库危险命令；
- 有没有缺失的回滚/备份步骤。

输出一份差异清单，不直接改文件。

---

## 交付格式

```text
审查范围：
发现：
  - [严重级别] 文件:行 问题
建议：
新增测试：
验收结果：
未验证/假设：
```

不要：

- 不改 `students.score`；
- 不跑生产库；
- 不把真实学生数据放进测试；
- 不复制商业游戏代码/素材。
