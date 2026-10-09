import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { Store } from '../lib/store.js';
import { createServer } from '../server.js';
import { taskHeat, agentHeat, effectiveStatus } from '../public/heat.js';

let server;
let base;
let store;
const TOKEN = 'secret-token';

before(async () => {
  store = new Store(null);
  server = createServer({ store, token: TOKEN });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  base = `http://127.0.0.1:${server.address().port}`;
});
after(() => server.close());

const call = async (method, path, body, token = TOKEN) => {
  const res = await fetch(base + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  return { status: res.status, body: text ? JSON.parse(text) : null };
};
const rpc = (method, params, id = 1) => call('POST', '/mcp', { jsonrpc: '2.0', id, method, params });

test('rejects requests without the token, serves UI and health without it', async () => {
  assert.equal((await call('GET', '/api/state', undefined, '')).status, 401);
  assert.equal((await call('GET', '/api/health', undefined, '')).status, 200);
  const ui = await fetch(base + '/');
  assert.equal(ui.status, 200);
  assert.match(await ui.text(), /Taskdeck/);
  assert.equal((await fetch(base + '/../server.js')).status, 404);
});

test('task upsert de-duplicates on source + external_id and never resurrects done tasks', async () => {
  const a = await call('POST', '/api/tasks', { title: 'Reply to Dana', source: 'email', external_id: 'thread-1', priority: 4 });
  assert.equal(a.status, 201);
  await call('PATCH', `/api/tasks/${a.body.id}`, { priority: 2 });
  const b = await call('POST', '/api/tasks', { title: 'Reply to Dana (updated)', source: 'email', external_id: 'thread-1', priority: 5 });
  assert.equal(b.status, 200);
  assert.equal(b.body.id, a.body.id);
  assert.equal(b.body.title, 'Reply to Dana (updated)');
  assert.equal(b.body.priority, 2, 're-sweep must not override a priority set on the board');

  await call('PATCH', `/api/tasks/${a.body.id}`, { status: 'done' });
  const c = await call('POST', '/api/tasks', { title: 'Reply to Dana', source: 'email', external_id: 'thread-1' });
  assert.equal(c.body.status, 'done');
  assert.ok(c.body.completed_at);
});

test('validates task input', async () => {
  assert.equal((await call('POST', '/api/tasks', { source: 'email' })).status, 422);
  assert.equal((await call('POST', '/api/tasks', { title: 'x', priority: 9 })).status, 422);
  assert.equal((await call('POST', '/api/tasks', { title: 'x', source: 'fax' })).status, 422);
});

test('hook events drive the agent state machine', async () => {
  const sid = 'sess-123';
  const ev = (hook_event_name, extra = {}) => call('POST', '/api/agents/event', { session_id: sid, hook_event_name, cwd: '/Users/c/code/candidata', machine: 'mbp', ...extra });

  assert.equal((await ev('SessionStart')).body.status, 'idle');
  let r = await ev('UserPromptSubmit', { prompt: 'Fix the importer\nmore detail' });
  assert.equal(r.body.status, 'running');
  assert.equal(r.body.title, 'Fix the importer');
  assert.equal(r.body.project, 'candidata');

  r = await ev('Notification', { message: 'Claude needs your permission to use Bash', notification_type: 'permission_prompt' });
  assert.equal(r.body.status, 'waiting');
  assert.ok(agentHeat(r.body) >= 80);

  assert.equal((await ev('PostToolUse')).body.status, 'running');

  r = await ev('Stop', { last_message: 'Done. Importer fixed.' });
  assert.equal(r.body.status, 'review');
  assert.equal(r.body.last_message, 'Done. Importer fixed.');

  // Idle reminder after a finished turn does not turn review into "blocked".
  r = await ev('Notification', { message: 'Claude is waiting for your input', notification_type: 'idle_prompt' });
  assert.equal(r.body.status, 'review');

  r = await call('PATCH', `/api/agents/${sid}`, { status: 'idle' });
  assert.equal(r.body.status, 'idle');
  assert.equal((await ev('SessionEnd')).body.status, 'ended');
});

test('MCP: initialize, list tools, add/list/update tasks, report status', async () => {
  const init = await rpc('initialize', { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 't', version: '1' } });
  assert.equal(init.body.result.serverInfo.name, 'taskdeck');

  const notif = await call('POST', '/mcp', { jsonrpc: '2.0', method: 'notifications/initialized' });
  assert.equal(notif.status, 202);

  const tools = await rpc('tools/list');
  assert.deepEqual(tools.body.result.tools.map((t) => t.name).sort(), ['taskdeck_add_task', 'taskdeck_list_tasks', 'taskdeck_report_status', 'taskdeck_update_task']);

  const add = await rpc('tools/call', { name: 'taskdeck_add_task', arguments: { title: 'Send board report', source: 'report', priority: 5, draft: 'Hi all,' } });
  const created = add.body.result.structuredContent.task;
  assert.equal(created.has_draft, true);

  const list = await rpc('tools/call', { name: 'taskdeck_list_tasks', arguments: { source: 'report' } });
  assert.equal(list.body.result.structuredContent.tasks[0].id, created.id);

  const upd = await rpc('tools/call', { name: 'taskdeck_update_task', arguments: { id: created.id, status: 'waiting' } });
  assert.equal(upd.body.result.structuredContent.task.status, 'waiting');

  const bad = await rpc('tools/call', { name: 'taskdeck_update_task', arguments: { id: 'nope' } });
  assert.equal(bad.body.result.isError, true);

  const rep = await rpc('tools/call', { name: 'taskdeck_report_status', arguments: { key: 'chat-42', title: 'Drafting grant report', status: 'review' } });
  assert.equal(rep.body.result.structuredContent.agent.status, 'review');
  assert.equal(store.getAgent('ext:chat-42').machine, 'claude.ai');

  assert.equal((await rpc('nope/method')).body.error.code, -32601);
});

test('heat ranking: overdue and blocked outrank routine work; waiting/snoozed cool off', () => {
  const now = Date.parse('2026-10-07T12:00:00Z');
  const base = { status: 'open', source: 'manual', created_at: '2026-10-07T11:00:00Z' };
  const routine = taskHeat({ ...base, priority: 3 }, now);
  const overdue = taskHeat({ ...base, priority: 3, due: '2026-10-06T12:00:00Z' }, now);
  const oldEmail = taskHeat({ ...base, priority: 3, source: 'email', created_at: '2026-10-02T12:00:00Z' }, now);
  const waiting = taskHeat({ ...base, priority: 3, status: 'waiting' }, now);
  assert.ok(overdue > routine);
  assert.ok(oldEmail > routine);
  assert.ok(waiting < routine);
  assert.equal(taskHeat({ ...base, status: 'snoozed', snooze_until: '2026-10-08T00:00:00Z' }, now), 0);
  assert.equal(effectiveStatus({ status: 'snoozed', snooze_until: '2026-10-07T00:00:00Z' }, now), 'open');
  assert.ok(agentHeat({ status: 'waiting', status_since: '2026-10-07T11:59:00Z' }, now) > taskHeat({ ...base, priority: 5 }, now));
});
