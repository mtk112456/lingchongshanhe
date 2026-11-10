# 8 人并发出令压测报告

> 目的：验证 8 名学生同时出 3 张令时，`slice_order_slots` 的唯一键、幂等和结算不会出错。
> 脚本：`server/slice/tests/card_concurrency_test.php`

---

## 1. 方法

```text
独立 API：127.0.0.1:8098
8 个学生：青竹一~四（bi）、墨点一~四（mo）
每人 3 张令：24 个 POST /api/slice/order/play 同时发
curl_multi 并发
教师 card-settle
```

---

## 2. 结果

```text
[PASS] 测试局存在
[PASS] API 就绪
[PASS] 8 人全部登录并发好手牌
[PASS] 24 个并发 play 全部 200
[PASS] 库里 24 条 active 令
[PASS] 教师登录
[PASS] 结算成功
[PASS] 产生 2 场战斗
[PASS] 战斗已入库
[PASS] 两座城都有民心变化

CARD_CONCURRENCY PASS
```

结算明细：

```text
N1：score 1，城墙 522.8，民心 0 → 1
N2：score 1，城墙 308.8，民心 0 → 1
```

---

## 3. 结论

- 24 个并发出令没有唯一键冲突；
- 没有重复扣令、没有 500；
- 2 场战斗按城聚合正确；
- 民心推进正确。

---

## 4. 还没压的

```text
100 人 / 300 令
21:00 集中结算
教师批量操作
断线/重试
```

8 人并发是 Phase 1 的验收线；100 人要等 12 城版本。

---

## 5. 复现

```powershell
php server/slice/tests/card_concurrency_test.php
```
