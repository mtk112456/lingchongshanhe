// Press Enter in the Antigravity composer via CDP.
const match = process.argv[2] || '7d5f557a-96d2-4559-8c9a-8cd4315aa3fa';
const targets = await (await fetch('http://127.0.0.1:16165/json/list')).json();
const target = targets.find(t => t.url && t.url.includes(match));
if (!target) { console.error('target not found'); process.exit(3); }
const ws = new WebSocket(target.webSocketDebuggerUrl);
let seq = 0;
const pending = new Map();
function call(method, params = {}) {
  return new Promise((resolve, reject) => {
    const id = ++seq;
    pending.set(id, { resolve, reject });
    ws.send(JSON.stringify({ id, method, params }));
  });
}
ws.addEventListener('message', e => {
  const m = JSON.parse(e.data);
  const p = pending.get(m.id);
  if (!p) return;
  pending.delete(m.id);
  m.error ? p.reject(new Error(JSON.stringify(m.error))) : p.resolve(m.result);
});
await new Promise(r => ws.addEventListener('open', r));
await call('Runtime.evaluate', {
  expression: `document.querySelector('[aria-label="Message input"]')?.focus()`,
  awaitPromise: true,
});
for (const type of ['keyDown', 'keyUp']) {
  await call('Input.dispatchKeyEvent', {
    type,
    key: 'Enter',
    code: 'Enter',
    windowsVirtualKeyCode: 13,
    nativeVirtualKeyCode: 13,
  });
}
await new Promise(r => setTimeout(r, 800));
const state = await call('Runtime.evaluate', {
  expression: `(() => { const el = document.querySelector('[aria-label="Message input"]'); return { length: (el?.textContent || '').length }; })()`,
  returnByValue: true,
});
console.log(JSON.stringify(state.result?.value ?? state));
ws.close();
