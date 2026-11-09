(() => {
  const els = [...document.querySelectorAll('button, [role="button"]')];
  return els.map((e, i) => {
    const r = e.getBoundingClientRect();
    return {
      i,
      aria: e.getAttribute('aria-label'),
      title: e.getAttribute('title'),
      disabled: e.disabled || e.getAttribute('aria-disabled'),
      visible: r.width > 10 && r.height > 10,
      rect: { x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) }
    };
  }).filter(x => x.visible && x.rect.y > 650);
})()
