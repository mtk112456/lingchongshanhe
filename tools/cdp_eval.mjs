// 通过本地 CDP 执行一组只读 DOM 查询/输入操作。
// 用法：node tools/cdp_eval.mjs <conversation-id> <expression-file>
import fs from 'node:fs';

const match = process.argv[2];
const expressionFile = process.argv[3];
if (!match || !expressionFile) {
  console.error('usage: node cdp_eval.mjs <conversation-id> <expression-file>');
  process.exit(2);
}

const targets = await (await fetch('http://127.0.0.1:16165/json/list')).json();
const target = targets.find(t => t.url && t.url.includes(match));
if (!target) {
  console.error('CDP target not found');
  process.exit(3);
}

const expression = fs.readFileSync(expressionFile, 'utf8');
const ws = new WebSocket(target.webSocketDebuggerUrl);
const timeout = setTimeout(() => {
  console.error('CDP timeout');
  process.exit(4);
}, 10000);

ws.addEventListener('open', () => {
  ws.send(JSON.stringify({
    id: 1,
    method: 'Runtime.evaluate',
    params: { expression, returnByValue: true, awaitPromise: true },
  }));
});

ws.addEventListener('message', event => {
  const msg = JSON.parse(event.data);
  if (msg.id !== 1) return;
  clearTimeout(timeout);
  if (msg.error) {
    console.error(JSON.stringify(msg.error));
    process.exit(5);
  }
  console.log(JSON.stringify(msg.result?.result?.value ?? msg.result, null, 2));
  ws.close();
  process.exit(0);
});

ws.addEventListener('error', err => {
  clearTimeout(timeout);
  console.error('CDP websocket error:', err.message || err);
  process.exit(6);
});
