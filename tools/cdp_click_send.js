(() => {
  const btn = document.querySelector('[data-testid="send-button"]');
  if (!btn) return { ok: false, reason: 'send button not found' };
  btn.click();
  return { ok: true, aria: btn.getAttribute('aria-label') };
})()
