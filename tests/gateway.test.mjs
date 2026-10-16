import { test } from 'node:test';
import assert from 'node:assert/strict';
import net from 'node:net';
import { once } from 'node:events';
import { WebSocket } from 'ws';
import { createGateway } from '../tools/gateway.mjs';

const origin = 'http://localhost:8080';
async function setup(t, handler = s => s.pipe(s), options = {}) {
  const peers = new Set();
  const backend = net.createServer(s => { peers.add(s); s.on('close', () => peers.delete(s)); handler(s); });
  backend.listen(0, '127.0.0.1'); await once(backend, 'listening');
  const gateway = createGateway({ targetPort: backend.address().port, origins: [origin], ...options });
  gateway.server.listen(0, '127.0.0.1'); await once(gateway.server, 'listening');
  t.after(async () => {
    await gateway.close(); for (const s of peers) s.destroy();
    await new Promise(resolve => backend.close(resolve));
  });
  return { gateway, url: `ws://127.0.0.1:${gateway.server.address().port}` };
}
async function connect(url, options = {}) {
  const ws = new WebSocket(url, 'binary', { origin, ...options });
  await once(ws, 'open'); return ws;
}
async function receiveBytes(ws, size) {
  const chunks = []; let length = 0;
  return new Promise((resolve, reject) => {
    const onData = (data, binary) => {
      assert.equal(binary, true); chunks.push(data); length += data.length;
      if (length >= size) { ws.off('message', onData); ws.off('error', reject); resolve(Buffer.concat(chunks)); }
    };
    ws.on('error', reject); ws.on('message', onData);
  });
}
test('two simultaneous WebSockets preserve distinct binary TCP streams', { timeout: 5000 }, async t => {
  const { url } = await setup(t);
  const clients = await Promise.all([connect(url), connect(url)]);
  await Promise.all(clients.map(async (ws, index) => {
    assert.equal(ws.protocol, 'binary');
    const payload = Buffer.from([0, 255, index, 13, 10, 0, 128]);
    const received = receiveBytes(ws, payload.length);
    ws.send(payload.subarray(0, 2)); ws.send(payload.subarray(2));
    assert.deepEqual(await received, payload);
  }));
});
test('rejects untrusted origin, missing origin, wrong protocol and arbitrary paths', { timeout: 5000 }, async t => {
  const { url } = await setup(t);
  for (const [suffix, protocols, options] of [
    ['', 'binary', { origin: 'https://evil.invalid' }], ['', 'binary', {}],
    ['', 'text', { origin }], ['/target/secret', 'binary', { origin }]
  ]) {
    const ws = new WebSocket(url + suffix, protocols, options);
    await assert.rejects(once(ws, 'open'), /403/);
  }
});
test('text frames are rejected and backend is closed', { timeout: 5000 }, async t => {
  const { url } = await setup(t); const ws = await connect(url);
  const closed = once(ws, 'close'); ws.send('not a Tibia packet');
  assert.equal((await closed)[0], 1003);
});
test('backend disconnect closes websocket', { timeout: 5000 }, async t => {
  const { url } = await setup(t, s => s.on('data', () => s.end()));
  const ws = await connect(url); const closed = once(ws, 'close'); ws.send(Buffer.from([1]));
  assert.equal((await closed)[0], 1000);
});
test('limits connections and queued bytes', { timeout: 5000 }, async t => {
  const { url } = await setup(t, () => {}, { maxConnections: 1, maxBuffered: 16 });
  const ws = await connect(url);
  await assert.rejects(connect(url), /403/);
  const closed = once(ws, 'close'); ws.send(Buffer.alloc(17));
  assert.equal((await closed)[0], 1009);
});
test('configuration cannot create an arbitrary open proxy', () => {
  assert.throws(() => createGateway({ targetPort: 7171, origins: ['*'] }));
  assert.throws(() => createGateway({ targetPort: 0, origins: [origin] }));
});
