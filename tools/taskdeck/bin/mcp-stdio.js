#!/usr/bin/env node
// stdio <-> HTTP bridge for MCP clients that only launch local commands
// (Claude Desktop). Forwards each JSON-RPC line to the hub's /mcp endpoint.
//
// Claude Desktop config (claude_desktop_config.json):
//   "taskdeck": { "command": "node", "args": ["/path/to/taskdeck/bin/mcp-stdio.js"] }
// Hub URL/token come from ~/.taskdeck/config.json (written by install-hooks.js)
// or TASKDECK_URL / TASKDECK_TOKEN.

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import readline from 'node:readline';

let cfg = {};
try {
  cfg = JSON.parse(fs.readFileSync(path.join(os.homedir(), '.taskdeck', 'config.json'), 'utf8'));
} catch {}
const url = `${(process.env.TASKDECK_URL || cfg.url || 'http://127.0.0.1:4777').replace(/\/$/, '')}/mcp`;
const token = process.env.TASKDECK_TOKEN || cfg.token || '';

const rl = readline.createInterface({ input: process.stdin });
rl.on('line', async (line) => {
  if (!line.trim()) return;
  let msg;
  try {
    msg = JSON.parse(line);
  } catch {
    return;
  }
  try {
    const headers = { 'Content-Type': 'application/json', Accept: 'application/json, text/event-stream' };
    if (token) headers.Authorization = `Bearer ${token}`;
    const res = await fetch(url, { method: 'POST', headers, body: line });
    if (res.status === 202) return;
    const text = await res.text();
    if (!res.ok && msg.id !== undefined) throw new Error(`Hub returned ${res.status}: ${text}`);
    process.stdout.write(text.trim() + '\n');
  } catch (err) {
    if (msg.id === undefined) return;
    process.stdout.write(JSON.stringify({ jsonrpc: '2.0', id: msg.id, error: { code: -32000, message: `Taskdeck hub unreachable at ${url}: ${err.message}` } }) + '\n');
  }
});
