// 通过本地 CDP 向 Antigravity 会话输入框发送一条消息。
// 用法：node tools/cdp_send_message.mjs <conversation-id> <message-file>
import fs from 'node:fs';

const match = process.argv[2];
const messageFile = process.argv[3];
if (!match || !messageFile) {
  console.error('usage: node cdp_send_message.mjs <conversation-id> <message-file>');
  process.exit(2);
}
const message = fs.readFileSync(messageFile, 'utf8');

const targets = await (await fetch('http://127.0.0.1:16165/json/list')).json();
const target = targets.find(t => t.url && t.url.includes(match));
if (!target) {
  console.error('CDP target not found');
  process.exit(3);
}

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

ws.addEventListener('message', event => {
  const msg = JSON.parse(event.data);
  const p = pending.get(msg.id);
  if (!p) return;
  pending.delete(msg.id);
  if (msg.error) p.reject(new Error(JSON.stringify(msg.error)));
  else p.resolve(msg.result);
});

ws.addEventListener('open', async () => {
  try {
    const inserted = await call('Runtime.evaluate', {
      expression: `(() => {
        const el = document.querySelector('[aria-label="Message input"]');
        if (!el) return { ok: false, error: 'message input not found' };
        el.focus();
        const sel = window.getSelection();
        sel.selectAllChildren(el);
        sel.collapseToEnd();
        document.execCommand('insertText', false, ${JSON.stringify(message)});
        el.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText', data: ${JSON.stringify(message)} }));
        return { ok: true, length: (el.textContent || '').length };
      })()`,
      returnByValue: true,
      awaitPromise: true,
    });

    const sendCandidate = await call('Runtime.evaluate', {
      expression: `(() => {
        const els = [...document.querySelectorAll('button, [role="button"]')];
        return els.map(e => {
          const r = e.getBoundingClientRect();
          return {
            aria: e.getAttribute('aria-label'),
            title: e.getAttribute('title'),
            testid: e.getAttribute('data-testid'),
            visible: r.width > 5 && r.height > 5,
            x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height)
          };
        }).filter(x => x.visible && /send|submit/i.test((x.aria || '') + ' ' + (x.title || '') + ' ' + (x.testid || '')));
      })()`,
      returnByValue: true,
      awaitPromise: true,
    });

    const candidates = sendCandidate?.result?.value ?? [];
    if (candidates.length > 0) {
      const c = candidates[0];
      await call('Runtime.evaluate', {
        expression: `(() => {
          const el = document.elementFromPoint(${c.x + Math.floor(c.w / 2)}, ${c.y + Math.floor(c.h / 2)});
          if (el) el.click();
          return true;
        })()`,
        returnByValue: true,
      });
    } else {
      // 没有 send 按钮时，用 CDP 发可信 Enter。
      await call('Input.dispatchKeyEvent', { type: 'keyDown', key: 'Enter', code: 'Enter', windowsVirtualKeyCode: 13, nativeVirtualKeyCode: 13 });
      await call('Input.dispatchKeyEvent', { type: 'keyUp', key: 'Enter', code: 'Enter', windowsVirtualKeyCode: 13, nativeVirtualKeyCode: 13 });
    }

    await new Promise(r => setTimeout(r, 1200));
    const after = await call('Runtime.evaluate', {
      expression: `(() => {
        const el = document.querySelector('[aria-label="Message input"]');
        return { length: el ? (el.textContent || '').length : -1 };
      })()`,
      returnByValue: true,
    });
    console.log(JSON.stringify({
      inserted: inserted?.result?.value,
      sendButtons: candidates,
      after: after?.result?.value,
    }, null, 2));
    ws.close();
    process.exit(0);
  } catch (err) {
    console.error('CDP send failed:', err.message || err);
    process.exit(4);
  }
});
