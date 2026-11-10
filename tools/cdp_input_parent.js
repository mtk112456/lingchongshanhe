(() => {
  const el = document.querySelector('[aria-label="Message input"]');
  if (!el) return { ok: false, reason: 'no input' };
  let p = el;
  for (let i = 0; i < 4 && p.parentElement; i++) p = p.parentElement;
  return {
    ok: true,
    textLength: (el.textContent || '').length,
    html: p.outerHTML.slice(0, 8000)
  };
})()
