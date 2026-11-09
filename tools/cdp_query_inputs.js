(() => {
  const els = [...document.querySelectorAll('textarea, [contenteditable="true"], input')];
  return els.map((e, i) => {
    const r = e.getBoundingClientRect();
    return {
      i,
      tag: e.tagName,
      type: e.getAttribute('type'),
      aria: e.getAttribute('aria-label'),
      placeholder: e.getAttribute('placeholder'),
      role: e.getAttribute('role'),
      visible: r.width > 20 && r.height > 10,
      rect: { x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) }
    };
  });
})()
