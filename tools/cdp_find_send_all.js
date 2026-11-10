(() => {
  const all = [...document.querySelectorAll('[data-testid], [aria-label], [title]')];
  return all.map(e => {
    const r = e.getBoundingClientRect();
    return {
      tag: e.tagName,
      testid: e.getAttribute('data-testid'),
      aria: e.getAttribute('aria-label'),
      title: e.getAttribute('title'),
      visible: r.width > 2 && r.height > 2,
      x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height),
      text: (e.innerText || '').trim().slice(0, 40)
    };
  }).filter(x => /send|submit/i.test((x.testid || '') + ' ' + (x.aria || '') + ' ' + (x.title || '')));
})()
