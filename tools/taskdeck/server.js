#!/usr/bin/env node
// Taskdeck hub: REST API + live stream + MCP endpoint + the web UI.
// Zero dependencies. Run one hub; point every Mac's hooks at it.
//
//   node server.js                     # http://127.0.0.1:4777
//   HOST=0.0.0.0 TASKDECK_TOKEN=... node server.js   # reachable from other machines

import http from 'node:http';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { Store } from './lib/store.js';
import { handleMcp } from './lib/mcp.js';

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const PUBLIC = path.join(ROOT, 'public');
const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.webmanifest': 'application/manifest+json',
  '.json': 'application/json',
};
const MAX_BODY = 1024 * 1024;

const isLoopback = (h) => ['127.0.0.1', 'localhost', '::1'].includes(h);

export function createServer({ store, token = '' }) {
  const clients = new Set();

  const broadcast = () => {
    const payload = `event: state\ndata: ${JSON.stringify(store.snapshot())}\n\n`;
    for (const res of clients) res.write(payload);
  };
  store.on('change', broadcast);

  const send = (res, status, body, headers = {}) => {
    if (body === undefined || body === null) {
      res.writeHead(status, headers);
      return res.end();
    }
    res.writeHead(status, { 'Content-Type': 'application/json', ...headers });
    res.end(JSON.stringify(body));
  };

  const authorized = (req, url) => {
    if (!token) return true;
    const header = req.headers.authorization || '';
    const given = header.startsWith('Bearer ') ? header.slice(7) : url.searchParams.get('token') || '';
    const a = Buffer.from(given);
    const b = Buffer.from(token);
    return a.length === b.length && crypto.timingSafeEqual(a, b);
  };

  const readJson = (req) =>
    new Promise((resolve, reject) => {
      let size = 0;
      const chunks = [];
      req.on('data', (c) => {
        size += c.length;
        if (size > MAX_BODY) {
          reject(Object.assign(new Error('Body too large'), { status: 413 }));
          req.destroy();
        } else chunks.push(c);
      });
      req.on('end', () => {
        if (!chunks.length) return resolve({});
        try {
          resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));
        } catch {
          reject(Object.assign(new Error('Invalid JSON'), { status: 400 }));
        }
      });
      req.on('error', reject);
    });

  const serveStatic = (res, pathname) => {
    const rel = pathname === '/' ? 'index.html' : pathname.slice(1);
    const file = path.normalize(path.join(PUBLIC, rel));
    if (!file.startsWith(PUBLIC + path.sep) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
      return send(res, 404, { error: 'Not found' });
    }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-cache' });
    fs.createReadStream(file).pipe(res);
  };

  const routes = async (req, res, url) => {
    const { pathname } = url;
    const m = req.method;
    let match;

    if (pathname === '/api/health') return send(res, 200, { ok: true, hub: os.hostname() });

    if (!pathname.startsWith('/api/') && pathname !== '/mcp') return serveStatic(res, pathname);
    if (!authorized(req, url)) return send(res, 401, { error: 'Unauthorized' });

    if (pathname === '/mcp') {
      if (m !== 'POST') return send(res, 405, { error: 'Use POST' }, { Allow: 'POST' });
      const out = handleMcp(store, await readJson(req));
      return out ? send(res, 200, out) : send(res, 202, null);
    }

    if (pathname === '/api/state' && m === 'GET') return send(res, 200, store.snapshot());

    if (pathname === '/api/stream' && m === 'GET') {
      res.writeHead(200, { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', Connection: 'keep-alive' });
      res.write(`event: state\ndata: ${JSON.stringify(store.snapshot())}\n\n`);
      clients.add(res);
      req.on('close', () => clients.delete(res));
      return;
    }

    // Tasks
    if ((pathname === '/api/tasks' || pathname === '/api/ingest') && m === 'POST') {
      const { task, created } = store.upsertTask(await readJson(req));
      return send(res, created ? 201 : 200, task);
    }
    if ((match = pathname.match(/^\/api\/tasks\/([\w-]+)$/))) {
      if (m === 'PATCH') {
        const task = store.updateTask(match[1], await readJson(req));
        return task ? send(res, 200, task) : send(res, 404, { error: 'Not found' });
      }
      if (m === 'DELETE') return store.deleteTask(match[1]) ? send(res, 204, null) : send(res, 404, { error: 'Not found' });
    }

    // Agents
    if (pathname === '/api/agents/event' && m === 'POST') return send(res, 200, store.recordHookEvent(await readJson(req)));
    if (pathname === '/api/agents/report' && m === 'POST') return send(res, 200, store.reportAgent(await readJson(req)));
    if ((match = pathname.match(/^\/api\/agents\/(.+)$/))) {
      const id = decodeURIComponent(match[1]);
      if (m === 'PATCH') {
        const agent = store.updateAgent(id, await readJson(req));
        return agent ? send(res, 200, agent) : send(res, 404, { error: 'Not found' });
      }
      if (m === 'DELETE') return store.deleteAgent(id) ? send(res, 204, null) : send(res, 404, { error: 'Not found' });
    }

    return send(res, 404, { error: 'Not found' });
  };

  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, 'http://localhost');
    try {
      await routes(req, res, url);
    } catch (err) {
      if (!res.headersSent) send(res, err.status || 422, { error: err.message });
      else res.end();
    }
  });

  // Keep SSE connections alive through proxies.
  const ping = setInterval(() => {
    for (const res of clients) res.write(': ping\n\n');
  }, 25000);
  server.on('close', () => {
    clearInterval(ping);
    store.off('change', broadcast);
  });
  return server;
}

// ---- CLI entry -------------------------------------------------------------

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  const host = process.env.HOST || '127.0.0.1';
  const port = Number(process.env.PORT || 4777);
  const token = process.env.TASKDECK_TOKEN || '';
  const dataFile = process.env.TASKDECK_DATA || path.join(os.homedir(), '.taskdeck', 'data.json');

  if (!isLoopback(host) && !token) {
    console.error('Refusing to listen on a non-loopback address without TASKDECK_TOKEN set.');
    process.exit(1);
  }

  const store = new Store(dataFile);
  store.prune();
  setInterval(() => store.prune(), 60 * 60 * 1000);
  const server = createServer({ store, token });
  server.listen(port, host, () => {
    console.log(`Taskdeck hub on http://${host}:${port}  (data: ${dataFile})`);
  });
  const shutdown = () => {
    store.flush();
    process.exit(0);
  };
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}
