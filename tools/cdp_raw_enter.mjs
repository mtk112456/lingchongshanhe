const match = process.argv[2] || '3347a502-c119-4d47-9821-e7e844bb2c82';
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
const rect = await call('Runtime.evaluate', {
  expression: `(() => { const el = document.querySelector('[aria-label="Message input"]'); if (!el) return null; const r = el.getBoundingClientRect(); return {x:r.x + r.width/2, y:r.y + Math.min(r.height/2, 100)}; })()`,
  returnByValue: true,
});
const pos = rect.result?.value;
if (!pos) { console.error('input not found'); process.exit(4); }
await call('Input.dispatchMouseEvent', { type: 'mousePressed', x: pos.x, y: pos.y, button: 'left', clickCount: 1 });
await call('Input.dispatchMouseEvent', { type: 'mouseReleased', x: pos.x, y: pos.y, button: 'left', clickCount: 1 });
await new Promise(r => setTimeout(r, 200));
await call('Input.dispatchKeyEvent', { type: 'rawKeyDown', key: 'Enter', code: 'Enter', windowsVirtualKeyCode: 13, nativeVirtualKeyCode: 13, text: '\r', unmodifiedText: '\r' });
await call('Input.dispatchKeyEvent', { type: 'char', key: 'Enter', code: 'Enter', text: '\r', unmodifiedText: '\r' });
await call('Input.dispatchKeyEvent', { type: 'keyUp', key: 'Enter', code: 'Enter', windowsVirtualKeyCode: 13, nativeVirtualKeyCode: 13 });
await new Promise(r => setTimeout(r, 1200));
const state = await call('Runtime.evaluate', {
  expression: `(() => { const el = document.querySelector('[aria-label="Message input"]'); return { length: (el?.textContent || '').length }; })()`,
  returnByValue: true,
});
console.log(JSON.stringify(state.result?.value ?? state));
ws.close();
