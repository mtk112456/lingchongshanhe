(() => {
  const el = document.querySelector('[aria-label="Message input"]');
  return { length: el ? (el.textContent || '').length : -1, htmlLength: el ? (el.innerHTML || '').length : -1 };
})()
