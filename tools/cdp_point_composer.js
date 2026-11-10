(() => {
  const pts = [];
  for (const y of [860, 880, 900, 920, 940, 950]) {
    for (const x of [1180, 1200, 1220, 1240]) pts.push([x, y]);
  }
  return pts.map(([x,y]) => {
    const els = document.elementsFromPoint(x,y).slice(0,3).map(e => ({
      tag: e.tagName,
      cls: (e.className && e.className.toString ? e.className.toString() : '').slice(0,60),
      aria: e.getAttribute('aria-label'),
      testid: e.getAttribute('data-testid'),
      text: (e.innerText || '').trim().slice(0,20)
    }));
    return { x, y, els };
  });
})()
