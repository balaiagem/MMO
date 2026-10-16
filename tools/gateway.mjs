import http from 'node:http';
import net from 'node:net';
import { pathToFileURL } from 'node:url';
import { WebSocketServer, WebSocket } from 'ws';

// Opaque byte transport: TFS retains packet framing, RSA/XTEA and authentication.
// The browser cannot choose a destination. Run one listener for each TFS service.
export function createGateway({ targetHost = '127.0.0.1', targetPort,
  origins, maxConnections = 100, maxBuffered = 1024 * 1024,
  connectTimeout = 5000, heartbeatMs = 30000 } = {}) {
  if (!Number.isInteger(targetPort) || targetPort < 1 || targetPort > 65535)
    throw new Error('A fixed targetPort is required');
  if (!Array.isArray(origins) || !origins.length || origins.includes('*'))
    throw new Error('Explicit allowed browser origins are required');
  const allowed = new Set(origins);
  const server = http.createServer((req, res) => {
    res.writeHead(req.url === '/healthz' ? 200 : 404, { 'Content-Type': 'text/plain' });
    res.end(req.url === '/healthz' ? 'gateway alive; backend not probed\n' : 'Not found\n');
  });
  const sockets = new Set();
  const wss = new WebSocketServer({ noServer: true, maxPayload: 65536,
    perMessageDeflate: false, handleProtocols: p => p.has('binary') ? 'binary' : false });
  server.on('upgrade', (req, socket, head) => {
    const protocols = String(req.headers['sec-websocket-protocol'] || '').split(',').map(s => s.trim());
    if (req.url !== '/' || !allowed.has(req.headers.origin) || !protocols.includes('binary') || wss.clients.size >= maxConnections) {
      socket.end('HTTP/1.1 403 Forbidden\r\nConnection: close\r\nContent-Length: 0\r\n\r\n');
      return;
    }
    wss.handleUpgrade(req, socket, head, ws => wss.emit('connection', ws));
  });
  wss.on('connection', ws => {
    const tcp = net.createConnection({ host: targetHost, port: targetPort });
    sockets.add(tcp);
    tcp.setNoDelay(true);
    let connected = false, queued = [], queuedBytes = 0, alive = true;
    const fail = (code = 1011, reason = 'Backend unavailable') => {
      tcp.destroy();
      queued = [];
      if (ws.readyState === WebSocket.OPEN) ws.close(code, reason);
    };
    const timeout = setTimeout(() => fail(), connectTimeout);
    ws.on('pong', () => { alive = true; });
    const heartbeat = setInterval(() => {
      if (!alive) { ws.terminate(); tcp.destroy(); return; }
      alive = false;
      ws.ping();
    }, heartbeatMs);
    heartbeat.unref();
    tcp.once('connect', () => {
      clearTimeout(timeout);
      connected = true;
      for (const chunk of queued) tcp.write(chunk);
      queued = [];
      queuedBytes = 0;
    });
    ws.on('message', (data, binary) => {
      if (!binary) return fail(1003, 'Binary packets required');
      if (queuedBytes + tcp.writableLength + data.length > maxBuffered)
        return fail(1009, 'Buffer limit exceeded');
      if (connected) tcp.write(data);
      else { queued.push(data); queuedBytes += data.length; }
    });
    tcp.on('data', data => {
      if (ws.readyState !== WebSocket.OPEN) return;
      if (ws.bufferedAmount + data.length > maxBuffered)
        return fail(1009, 'Buffer limit exceeded');
      ws.send(data, { binary: true }, error => { if (error) fail(); });
    });
    tcp.on('error', () => fail());
    tcp.on('close', () => {
      clearTimeout(timeout);
      sockets.delete(tcp);
      if (ws.readyState === WebSocket.OPEN) ws.close(1000, 'Backend disconnected');
    });
    ws.on('error', () => tcp.destroy());
    ws.on('close', () => {
      clearInterval(heartbeat); clearTimeout(timeout);
      queued = []; tcp.destroy();
    });
  });
  return { server, wss, async close() {
    for (const ws of wss.clients) ws.terminate();
    for (const tcp of sockets) tcp.destroy();
    await new Promise(resolve => wss.close(resolve));
    if (server.listening) await new Promise(resolve => server.close(resolve));
  }};
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const origins = (process.env.ALLOWED_ORIGINS || 'http://localhost:8080').split(',');
  const gateway = createGateway({ targetHost: process.env.TFS_HOST || '127.0.0.1',
    targetPort: Number(process.env.TFS_PORT || 7171), origins });
  const port = Number(process.env.PORT || 8081);
  gateway.server.listen(port, process.env.BIND || '127.0.0.1', () => {
    console.log(`Binary gateway listening on ${gateway.server.address().address}:${port}`);
  });
  for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, async () => {
    await gateway.close(); process.exit(0);
  });
}
