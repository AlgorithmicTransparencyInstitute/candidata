#!/usr/bin/env node
// Claude Code hook -> Taskdeck hub. Installed by bin/install-hooks.js.
// Reads the hook payload on stdin, adds machine/branch/last-message context,
// and posts it to the hub. Always exits 0 quickly so it never slows or
// blocks Claude Code, even when the hub is down.

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

function loadConfig() {
  const file = path.join(os.homedir(), '.taskdeck', 'config.json');
  let cfg = {};
  try {
    cfg = JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {}
  return {
    url: process.env.TASKDECK_URL || cfg.url || 'http://127.0.0.1:4777',
    token: process.env.TASKDECK_TOKEN || cfg.token || '',
    machine: process.env.TASKDECK_MACHINE || cfg.machine || os.hostname().replace(/\.local$/, ''),
  };
}

function readStdin() {
  try {
    return JSON.parse(fs.readFileSync(0, 'utf8') || '{}');
  } catch {
    return {};
  }
}

// Last assistant text in the transcript (JSONL). Reads only the tail.
function lastAssistantText(file) {
  try {
    const fd = fs.openSync(file, 'r');
    const size = fs.fstatSync(fd).size;
    const len = Math.min(size, 512 * 1024);
    const buf = Buffer.alloc(len);
    fs.readSync(fd, buf, 0, len, size - len);
    fs.closeSync(fd);
    const lines = buf.toString('utf8').split('\n').reverse();
    for (const line of lines) {
      if (!line.includes('"assistant"')) continue;
      try {
        const entry = JSON.parse(line);
        if (entry.type !== 'assistant') continue;
        const content = entry.message?.content;
        const text = Array.isArray(content)
          ? content.filter((c) => c.type === 'text').map((c) => c.text).join('\n').trim()
          : typeof content === 'string' ? content.trim() : '';
        if (text) return text.slice(0, 4000);
      } catch {}
    }
  } catch {}
  return undefined;
}

function gitBranch(cwd) {
  try {
    return execFileSync('git', ['rev-parse', '--abbrev-ref', 'HEAD'], { cwd, timeout: 500, stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim();
  } catch {
    return undefined;
  }
}

async function main() {
  const cfg = loadConfig();
  const input = readStdin();
  if (!input.session_id) return;

  const event = {
    session_id: input.session_id,
    hook_event_name: input.hook_event_name,
    cwd: input.cwd,
    transcript_path: input.transcript_path,
    permission_mode: input.permission_mode,
    machine: cfg.machine,
    prompt: input.prompt,
    message: input.message,
    notification_type: input.notification_type,
  };
  if (input.hook_event_name === 'SessionStart' || input.hook_event_name === 'UserPromptSubmit') {
    event.git_branch = gitBranch(input.cwd);
  }
  if (input.hook_event_name === 'Stop') {
    event.last_message = input.last_assistant_message || lastAssistantText(input.transcript_path);
  }

  const headers = { 'Content-Type': 'application/json' };
  if (cfg.token) headers.Authorization = `Bearer ${cfg.token}`;
  await fetch(`${cfg.url.replace(/\/$/, '')}/api/agents/event`, {
    method: 'POST',
    headers,
    body: JSON.stringify(event),
    signal: AbortSignal.timeout(1500),
  });
}

main().catch(() => {}).finally(() => process.exit(0));
