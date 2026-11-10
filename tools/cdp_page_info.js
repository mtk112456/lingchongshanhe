JSON.stringify({
  href: location.href,
  title: document.title,
  text: (document.body.innerText || '').slice(0, 4000),
  buttons: [...document.querySelectorAll('button, [role="button"], a')].slice(0, 40).map(e => ({
    tag: e.tagName,
    text: (e.innerText || e.getAttribute('aria-label') || '').trim().slice(0, 80),
    href: e.getAttribute('href') || ''
  }))
})
