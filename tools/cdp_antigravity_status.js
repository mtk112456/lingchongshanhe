(() => {
  const t = document.body.innerText || '';
  const keys = ['布局修改任务', 'P0', 'LAYOUT_FIX_REPORT', '正在', 'Working', 'Worked for'];
  let idx = -1;
  for (const k of keys) idx = Math.max(idx, t.lastIndexOf(k));
  return idx >= 0 ? t.slice(Math.max(0, idx - 300), idx + 5000) : t.slice(-3000);
})()
