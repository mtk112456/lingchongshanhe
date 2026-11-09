(() => {
  const input = document.querySelector('[aria-label="Message input"]');
  if (!input) return { found: false };
  const form = input.closest('form');
  const sendLike = [...document.querySelectorAll('[aria-label*="Send"], [data-testid*="send"], button[type="submit"]')]
    .map(e => {
      const r = e.getBoundingClientRect();
      return { tag: e.tagName, aria: e.getAttribute('aria-label'), testid: e.getAttribute('data-testid'), type: e.getAttribute('type'), visible: r.width > 5 && r.height > 5, rect: { x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) } };
    });
  return {
    found: true,
    inputTag: input.tagName,
    contenteditable: input.getAttribute('contenteditable'),
    role: input.getAttribute('role'),
    form: !!form,
    parentTags: [...input.parentElement.children].map(e => e.tagName + ':' + (e.getAttribute('aria-label') || '')),
    sendLike,
  };
})()
