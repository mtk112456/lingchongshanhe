(() => {
  const els = [...document.querySelectorAll('button, [role="button"]')];
  return els.map((e, i) => {
    const r = e.getBoundingClientRect();
    return {
      i,
      aria: e.getAttribute('aria-label'),
      title: e.getAttribute('title'),
      testid: e.getAttribute('data-testid'),
      disabled: e.disabled ?? e.getAttribute('aria-disabled'),
      visible: r.width > 2 && r.height > 2,
      x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height),
      text: (e.innerText || '').trim().slice(0, 60)
    };
  }).filter(x => x.visible && (
    /send|submit|arrow|paper/i.test((x.aria || '') + ' ' + (x.title || '') + ' ' + (x.testid || '') + ' ' + x.text)
    || x.y > 850
  ));
})()
