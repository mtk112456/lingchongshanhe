import fs from 'node:fs';

const match = process.argv[2];
const messageFile = process.argv[3];
if (!match || !messageFile) { console.error('usage: node cdp_type_and_send.mjs <conversation-id> <message-file>'); process.exit(2); }
const message = fs.readFileSync(messageFile, 'utf8');

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

// Clear existing composer text through the editor.
await call('Runtime.evaluate', {
  expression: `(() => {
    const el = document.querySelector('[aria-label="Message input"]');
    if (!el) return false;
    el.focus();
    const sel = window.getSelection();
    const range = document.createRange();
    range.selectNodeContents(el);
    sel.removeAllRanges();
    sel.addRange(range);
    document.execCommand('delete');
    return (el.textContent || '').length;
  })()`,
  returnByValue: true,
});
await new Promise(r => setTimeout(r, 200));

// Trusted text input so Lexical updates its state and shows the send button.
await call('Input.insertText', { text: message });
await new Promise(r => setTimeout(r, 800));

const send = await call('Runtime.evaluate', {
  expression: `(() => {
    const els = [...document.querySelectorAll('button, [role="button"]')];
    const btn = els.find(e => {
      const s = ((e.getAttribute('aria-label') || '') + ' ' + (e.getAttribute('data-testid') || '') + ' ' + (e.getAttribute('title') || '')).toLowerCase();
      return s.includes('send') || s.includes('submit');
    });
    if (btn) { btn.click(); return { clicked: true, aria: btn.getAttribute('aria-label'), testid: btn.getAttribute('data-testid') }; }
    return { clicked: false };
  })()`,
  returnByValue: true,
});
await new Promise(r => setTimeout(r, 800));

let state = await call('Runtime.evaluate', {
  expression: `(() => { const el = document.querySelector('[aria-label="Message input"]'); return { length: (el?.textContent || '').length }; })()`,
  returnByValue: true,
});
console.log(JSON.stringify({ send: send.result?.value, state: state.result?.value }));
ws.close();
