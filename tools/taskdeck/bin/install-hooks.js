#!/usr/bin/env node
// Wire this machine's Claude Code into a Taskdeck hub.
//
//   node bin/install-hooks.js                                  # local hub
//   node bin/install-hooks.js --url http://mac-studio.tailnet.ts.net:4777 --token SECRET
//   node bin/install-hooks.js --uninstall
//
// Writes ~/.taskdeck/config.json and merges hook entries into
// ~/.claude/settings.json (existing hooks are preserved; re-running is safe).

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const HOOK = path.join(ROOT, 'hooks', 'taskdeck-hook.js');
const SETTINGS = path.join(os.homedir(), '.claude', 'settings.json');
const CONFIG = path.join(os.homedir(), '.taskdeck', 'config.json');
const EVENTS = ['SessionStart', 'UserPromptSubmit', 'PostToolUse', 'Notification', 'Stop', 'SessionEnd'];
const TOOL_EVENTS = new Set(['PreToolUse', 'PostToolUse']);

const args = process.argv.slice(2);
const flag = (name) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : undefined;
};
const uninstall = args.includes('--uninstall');

const isOurs = (h) => typeof h.command === 'string' && h.command.includes('taskdeck-hook.js');

const settings = fs.existsSync(SETTINGS) ? JSON.parse(fs.readFileSync(SETTINGS, 'utf8')) : {};
settings.hooks ||= {};

// Remove previous Taskdeck entries everywhere, then (re)add.
for (const [event, groups] of Object.entries(settings.hooks)) {
  settings.hooks[event] = groups
    .map((g) => ({ ...g, hooks: (g.hooks || []).filter((h) => !isOurs(h)) }))
    .filter((g) => g.hooks.length);
  if (!settings.hooks[event].length) delete settings.hooks[event];
}

if (!uninstall) {
  const command = `"${process.execPath}" "${HOOK}"`;
  for (const event of EVENTS) {
    const group = { hooks: [{ type: 'command', command, timeout: 5 }] };
    if (TOOL_EVENTS.has(event)) group.matcher = '*';
    (settings.hooks[event] ||= []).push(group);
  }

  const existing = fs.existsSync(CONFIG) ? JSON.parse(fs.readFileSync(CONFIG, 'utf8')) : {};
  const config = {
    ...existing,
    url: flag('url') || existing.url || 'http://127.0.0.1:4777',
    token: flag('token') ?? existing.token ?? '',
    machine: flag('machine') || existing.machine || os.hostname().replace(/\.local$/, ''),
  };
  fs.mkdirSync(path.dirname(CONFIG), { recursive: true });
  fs.writeFileSync(CONFIG, JSON.stringify(config, null, 2), { mode: 0o600 });
  console.log(`Wrote ${CONFIG} (hub ${config.url}, machine "${config.machine}")`);
}

fs.mkdirSync(path.dirname(SETTINGS), { recursive: true });
if (fs.existsSync(SETTINGS)) fs.copyFileSync(SETTINGS, `${SETTINGS}.taskdeck-backup`);
fs.writeFileSync(SETTINGS, JSON.stringify(settings, null, 2));
console.log(uninstall ? `Removed Taskdeck hooks from ${SETTINGS}` : `Installed hooks for ${EVENTS.join(', ')} in ${SETTINGS}`);
console.log('Restart running Claude Code sessions (or run /hooks) to pick up the change.');
