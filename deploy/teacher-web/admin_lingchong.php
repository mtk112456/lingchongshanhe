<?php
/**
 * 教师控制台页面。
 * 放置到现有系统：admin/lingchong.php
 */
require_once __DIR__ . '/../assets/version.php';
require_once __DIR__ . '/../common.php';
require_once __DIR__ . '/../auth.php';
Auth::checkAdmin();
?>
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
    <title>灵宠山河 · 教师控制台</title>
    <script src="<?= auto_ver('../assets/js/theme_loader.js') ?>"></script>
    <link rel="stylesheet" href="<?= auto_ver('css/admin.css') ?>">
    <link rel="stylesheet" href="<?= auto_ver('../assets/remixicon/remixicon.css') ?>">
</head>
<body>
<div class="layout">
    <?php require_once __DIR__ . '/sidebar.php'; ?>
    <div class="main">
        <div class="header">
            <div class="header-title">灵宠山河 · 教师控制台</div>
            <div class="header-right">
                <span>管理员：<span id="adminName"><?= htmlspecialchars(Auth::adminName()) ?></span></span>
                <a class="logout" href="login.php" onclick="logout(); return false;">退出登录</a>
            </div>
        </div>
        <div class="content">
            <div class="card" style="padding:18px;border-radius:14px;background:var(--card-bg,#fff);margin-bottom:18px;">
                <h3 style="margin:0 0 6px;">回合控制</h3>
                <p style="color:#777;font-size:13px;margin:0 0 14px;">
                    学生 App 不提供教师登录；此处复用现有后台权限，锁令/结算/下一回合。
                </p>
                <label>回合 ID
                    <input id="turnId" type="number" min="1" value="1" style="width:120px;padding:8px;margin-left:8px;">
                </label>
                <div style="margin-top:14px;">
                    <button class="btn btn-primary" id="btnStatus">刷新状态</button>
                    <button class="btn btn-primary" id="btnLock">锁定本回合</button>
                    <button class="btn btn-primary" id="btnSettle">结算</button>
                    <button class="btn btn-primary" id="btnNext">下一回合</button>
                </div>
                <div id="msg" style="margin-top:12px;color:#b83b32;font-size:13px;"></div>
            </div>
            <div class="card" style="padding:18px;border-radius:14px;background:var(--card-bg,#fff);">
                <h3 style="margin:0 0 10px;">接口返回</h3>
                <pre id="out" style="white-space:pre-wrap;word-break:break-word;font-size:12px;color:#333;background:#f7f4ee;padding:14px;border-radius:8px;min-height:260px;">等待操作…</pre>
            </div>
        </div>
    </div>
</div>
<script>
(() => {
    const $ = id => document.getElementById(id);
    function setMsg(t) { $('msg').textContent = t; }
    function show(d) { $('out').textContent = JSON.stringify(d, null, 2); }

    async function call(action, extra = {}) {
        setMsg('请求中…');
        const body = new URLSearchParams({ action, turn_id: $('turnId').value, ...extra });
        const res = await fetch('../api/admin/lingchong.php', {
            method: 'POST',
            credentials: 'same-origin',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'X-Lingchong-Request': '1' },
            body
        });
        const data = await res.json();
        show(data);
        setMsg(data.ok ? '完成' : ((data.error && data.error.message) || '失败'));
    }

    $('btnStatus').onclick = () => call('status');
    $('btnLock').onclick = () => call('lock', { force: '1' });
    $('btnSettle').onclick = () => call('settle');
    $('btnNext').onclick = () => call('next-turn');
})();
</script>
</body>
</html>
