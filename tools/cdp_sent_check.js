(() => {
  const t = document.body.innerText || '';
  const needles = ['【横屏-only 改造】', '【12 城布局独立评审', '用户决定：这款游戏只横屏玩', '只判断，不改代码'];
  const counts = {};
  for (const n of needles) {
    counts[n] = t.split(n).length - 1;
  }
  return { counts, tail: t.slice(-1200) };
})()
