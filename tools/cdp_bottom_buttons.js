(() => {
  const el = document.querySelector('[aria-label="Message input"]');
  const r = el ? el.getBoundingClientRect() : null;
  const btns = [...document.querySelectorAll('button, [role="button"]')].map((e, i) => {
    const b = e.getBoundingClientRect();
    return { i, aria: e.getAttribute('aria-label'), testid: e.getAttribute('data-testid'), disabled: e.disabled ?? e.getAttribute('aria-disabled'), x: Math.round(b.x), y: Math.round(b.y), w: Math.round(b.width), h: Math.round(b.height), text: (e.innerText || '').trim().slice(0, 40) };
  }).filter(b => b.w > 2 && b.h > 2 && b.x > 700 && b.y > 700);
  return { input: r ? { x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) } : null, scrollY: window.scrollY, innerHeight: window.innerHeight, buttons: btns };
})()
