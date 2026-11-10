(() => {
  const el = document.querySelector('[aria-label="Message input"]');
  if (!el) return { ok: false };
  let card = el;
  for (let i = 0; i < 8 && card.parentElement; i++) {
    card = card.parentElement;
    if ((card.className || '').toString().includes('surface-composer-card')) break;
  }
  const buttons = [...card.querySelectorAll('button, [role="button"]')].map((e, i) => {
    const r = e.getBoundingClientRect();
    return { i, tag: e.tagName, aria: e.getAttribute('aria-label'), testid: e.getAttribute('data-testid'), visible: r.width > 2 && r.height > 2, x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height), text: (e.innerText || '').trim().slice(0, 30) };
  });
  return { cls: (card.className || '').toString(), htmlTail: card.outerHTML.slice(-4000), buttons };
})()
