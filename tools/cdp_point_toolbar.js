(() => {
  const pts = [[1120,968],[1160,968],[1185,968],[1210,968],[1230,968],[1240,968]];
  return pts.map(([x,y]) => {
    const els = document.elementsFromPoint(x,y).slice(0,4).map(e => ({
      tag: e.tagName,
      cls: (e.className && e.className.toString ? e.className.toString() : '').slice(0,80),
      aria: e.getAttribute('aria-label'),
      testid: e.getAttribute('data-testid'),
      text: (e.innerText || '').trim().slice(0,30)
    }));
    return { x, y, els };
  });
})()
