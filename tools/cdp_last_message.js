(() => {
  const t = document.body.innerText || '';
  const keys = ['布局复核', 'LAYOUT_REVIEW', '正在', 'Working', 'Worked for'];
  let idx = -1;
  for (const k of keys) {
    idx = Math.max(idx, t.lastIndexOf(k));
  }
  return idx >= 0 ? t.slice(Math.max(0, idx - 400), idx + 7000) : t.slice(-4000);
})()
