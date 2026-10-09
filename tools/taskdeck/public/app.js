import { taskHeat, agentHeat, agentNeedsAction, effectiveStatus, isStale, heatColor, heatBand } from './heat.js';

// ---- icons -----------------------------------------------------------------
const svg = (d) => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;
const ICONS = {
  focus: svg('<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="4"/>'),
  agents: svg('<rect x="4" y="7" width="16" height="12" rx="3"/><path d="M12 3v4M9 12h.01M15 12h.01M9 16h6"/>'),
  email: svg('<rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3 7 9 6 9-6"/>'),
  slack: svg('<path d="M9 3a2 2 0 0 0 0 4h2V5a2 2 0 0 0-2-2ZM3 9a2 2 0 0 0 2 2h6V9a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2ZM15 21a2 2 0 0 0 0-4h-2v2a2 2 0 0 0 2 2ZM21 15a2 2 0 0 0-2-2h-6v2a2 2 0 0 0 2 2h4a2 2 0 0 0 2-2Z"/>'),
  chat: svg('<path d="M21 12a8 8 0 0 1-11.6 7.1L4 20l1-4.6A8 8 0 1 1 21 12Z"/>'),
  report: svg('<path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8Z"/><path d="M14 3v5h5M9 13h6M9 17h4"/>'),
  manual: svg('<path d="M9 11l3 3 8-8"/><path d="M20 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/>'),
  waiting: svg('<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>'),
  snoozed: svg('<path d="M21 13A9 9 0 1 1 11 3a7 7 0 0 0 10 10Z"/>'),
  done: svg('<path d="m5 12 5 5L20 7"/>'),
  agent: svg('<rect x="4" y="7" width="16" height="12" rx="3"/><path d="M12 3v4"/>'),
};
const SOURCE_LABEL = { email: 'Email', slack: 'Slack', chat: 'Claude chat', report: 'Report', agent: 'Agent', manual: 'Other' };

// ---- views (left tabs) -----------------------------------------------------
const VIEWS = [
  { id: 'focus', name: 'Up next', group: null, sub: 'Everything that needs you, hottest first' },
  { id: 'agents', name: 'Agents', group: 'Sources', sub: 'Claude Code sessions and chat agents across your machines' },
  { id: 'email', name: 'Email', group: 'Sources', sources: ['email'], sub: 'Emails to send or answer' },
  { id: 'slack', name: 'Slack', group: 'Sources', sources: ['slack'], sub: 'Requests for action in Slack' },
  { id: 'chat', name: 'Claude chats', group: 'Sources', sources: ['chat', 'report'], sub: 'Drafts and reports Claude produced for you' },
  { id: 'manual', name: 'Other', group: 'Sources', sources: ['manual', 'agent'], sub: 'Everything else' },
  { id: 'waiting', name: 'Waiting on others', group: 'Later', status: 'waiting', sub: 'Ball is in someone else\'s court' },
  { id: 'snoozed', name: 'Snoozed', group: 'Later', status: 'snoozed', sub: 'Comes back automatically' },
  { id: 'done', name: 'Done', group: 'Later', status: 'done', sub: 'Completed in the last 30 days' },
];

// ---- state -----------------------------------------------------------------
const state = {
  tasks: [],
  agents: [],
  view: localGet('taskdeck.view') || 'focus',
  selected: null,
  token: new URLSearchParams(location.search).get('token') || localGet('taskdeck.token') || '',
  connected: false,
};
if (new URLSearchParams(location.search).get('token')) {
  localSet('taskdeck.token', state.token);
  history.replaceState(null, '', location.pathname);
}
let lastAlerted = new Map(); // id -> status we already alerted on

function localGet(k) { try { return localStorage.getItem(k); } catch { return null; } }
function localSet(k, v) { try { localStorage.setItem(k, v); } catch {} }

// ---- helpers ---------------------------------------------------------------
const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
function ago(iso) {
  if (!iso) return '';
  const s = (Date.now() - Date.parse(iso)) / 1000;
  if (s < 60) return 'just now';
  if (s < 3600) return `${Math.floor(s / 60)}m ago`;
  if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
  return `${Math.floor(s / 86400)}d ago`;
}
function when(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  const diff = (d - Date.now()) / 36e5;
  const label = d.toLocaleString([], { weekday: 'short', month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' });
  if (diff < 0) return `overdue (${label})`;
  return label;
}
const toLocalInput = (iso) => {
  if (!iso) return '';
  const d = new Date(iso);
  return new Date(d.getTime() - d.getTimezoneOffset() * 6e4).toISOString().slice(0, 16);
};
function toast(msg) {
  const el = document.createElement('div');
  el.className = 'toast';
  el.textContent = msg;
  document.body.append(el);
  setTimeout(() => el.remove(), 1800);
}

// ---- API -------------------------------------------------------------------
async function api(method, path, body) {
  const headers = { 'Content-Type': 'application/json' };
  if (state.token) headers.Authorization = `Bearer ${state.token}`;
  const res = await fetch(path, { method, headers, body: body ? JSON.stringify(body) : undefined });
  if (res.status === 401) return askToken();
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    toast(err.error || `Request failed (${res.status})`);
    throw new Error(err.error);
  }
  return res.status === 204 ? null : res.json();
}
const patchTask = (id, patch) => api('PATCH', `/api/tasks/${id}`, patch);
const patchAgent = (id, patch) => api('PATCH', `/api/agents/${encodeURIComponent(id)}`, patch);

function askToken() {
  const dlg = $('#token-dialog');
  if (!dlg.open) dlg.showModal();
}
$('#token-form').addEventListener('submit', () => {
  state.token = $('#token-input').value.trim();
  localSet('taskdeck.token', state.token);
  connect();
});

// ---- live stream -----------------------------------------------------------
let es;
function connect() {
  es?.close();
  const qs = state.token ? `?token=${encodeURIComponent(state.token)}` : '';
  es = new EventSource(`/api/stream${qs}`);
  es.addEventListener('state', (e) => {
    const data = JSON.parse(e.data);
    state.tasks = data.tasks;
    state.agents = data.agents;
    setConn(true);
    maybeAlert();
    render();
  });
  es.onerror = async () => {
    setConn(false);
    // EventSource hides status codes; probe once to detect a bad token.
    const res = await fetch(`/api/state${qs}`).catch(() => null);
    if (res?.status === 401) {
      es.close();
      askToken();
    }
  };
}
function setConn(live) {
  state.connected = live;
  const el = $('#conn');
  el.className = `conn ${live ? 'live' : 'down'}`;
  el.querySelector('.label').textContent = live ? `Live · ${machines().length} machine${machines().length === 1 ? '' : 's'}` : 'Reconnecting…';
}
const machines = () => [...new Set(state.agents.filter((a) => a.status !== 'ended').map((a) => a.machine).filter(Boolean))];

// ---- item model ------------------------------------------------------------
function taskItem(t) {
  const status = effectiveStatus(t);
  return { kind: 'task', id: t.id, ref: t, heat: taskHeat(t), status, needs: status === 'open', ts: t.created_at };
}
function agentItem(a) {
  return { kind: 'agent', id: a.id, ref: a, heat: agentHeat(a), status: a.status, needs: agentNeedsAction(a), ts: a.updated_at };
}

function itemsFor(viewId) {
  const view = VIEWS.find((v) => v.id === viewId);
  const tasks = state.tasks.map(taskItem);
  const agents = state.agents.map(agentItem);
  let items;
  if (viewId === 'focus') items = [...agents.filter((i) => i.needs), ...tasks.filter((i) => i.needs)];
  else if (viewId === 'agents') {
    const order = { waiting: 0, review: 1, running: 2, idle: 3, ended: 4 };
    return agents.sort((a, b) => order[a.status] - order[b.status] || b.heat - a.heat || Date.parse(b.ts) - Date.parse(a.ts));
  } else if (view.status) {
    items = tasks.filter((i) => i.status === view.status);
    if (view.status === 'done') return items.sort((a, b) => Date.parse(b.ref.completed_at || 0) - Date.parse(a.ref.completed_at || 0));
    if (view.status === 'snoozed') return items.sort((a, b) => Date.parse(a.ref.snooze_until || 0) - Date.parse(b.ref.snooze_until || 0));
  } else items = tasks.filter((i) => view.sources.includes(i.ref.source) && i.status === 'open');
  return items.sort((a, b) => b.heat - a.heat || Date.parse(a.ts) - Date.parse(b.ts));
}

function tabStats(viewId) {
  const view = VIEWS.find((v) => v.id === viewId);
  const items = itemsFor(viewId);
  if (view.status) return { count: items.length, heat: 0, muted: true };
  const needing = items.filter((i) => i.needs);
  return { count: needing.length, heat: Math.max(0, ...needing.map((i) => i.heat)), muted: false };
}

// ---- rendering -------------------------------------------------------------
function render() {
  renderTabs();
  renderList();
  renderDetail();
  const total = itemsFor('focus').length;
  document.title = total ? `(${total}) Taskdeck` : 'Taskdeck';
  if ('setAppBadge' in navigator) (total ? navigator.setAppBadge(total) : navigator.clearAppBadge()).catch(() => {});
}

function renderTabs() {
  let html = '';
  let group;
  for (const v of VIEWS) {
    if (v.group !== group) {
      group = v.group;
      if (group) html += `<div class="tab-group">${esc(group)}</div>`;
    }
    const s = tabStats(v.id);
    const dot = s.heat > 0 ? `<span class="heat-dot ${s.heat >= 85 ? 'pulse' : ''}" style="background:${heatColor(s.heat)}" title="Hottest: ${s.heat}"></span>` : '';
    const badge = s.count
      ? s.muted
        ? `<span class="badge muted">${s.count}</span>`
        : `<span class="badge ${s.heat >= 65 ? 'hot' : ''}" style="${s.heat >= 65 ? `background:${heatColor(s.heat)}` : ''}">${s.count}</span>`
      : '';
    html += `<button class="tab" data-view="${v.id}" aria-current="${state.view === v.id}">${ICONS[v.id]}<span class="name">${esc(v.name)}</span>${dot}${badge}</button>`;
  }
  $('#tabs').innerHTML = html;
}

function renderHeatbar(items) {
  const bands = [
    ['critical', 92, 'Critical'],
    ['high', 75, 'High'],
    ['medium', 52, 'Medium'],
    ['low', 30, 'Low'],
  ];
  const counts = Object.fromEntries(bands.map(([b]) => [b, 0]));
  for (const i of items) if (i.needs && counts[heatBand(i.heat)] !== undefined) counts[heatBand(i.heat)] += 1;
  const total = Object.values(counts).reduce((a, b) => a + b, 0);
  $('#heatbar').innerHTML = total
    ? bands.filter(([b]) => counts[b]).map(([b, h, label]) => `<span style="flex:${counts[b]};background:${heatColor(h)}" title="${label}: ${counts[b]}"></span>`).join('')
    : '';
  $('#heatbar').hidden = !total;
}

function rowHtml(item) {
  const heat = item.heat;
  const color = heatColor(heat);
  const cold = heat === 0;
  const sel = state.selected === item.id;
  if (item.kind === 'agent') {
    const a = item.ref;
    const stale = isStale(a);
    const pill = stale ? '<span class="pill stale">quiet 20m+</span>' : agentPill(a.status);
    const excerpt = a.status === 'waiting' ? a.message : a.last_message || a.last_prompt;
    return `<li class="row ${a.status === 'ended' ? 'dim' : ''}" role="option" data-id="${esc(item.id)}" aria-selected="${sel}">
      <span class="bar" style="background:${cold ? 'transparent' : color}"></span>
      <span class="score ${cold ? 'cold' : ''}" style="background:${color}">${cold ? '–' : heat}</span>
      <div style="min-width:0">
        <div class="title">${esc(a.title || a.project || 'Untitled session')}</div>
        <div class="meta"><span class="src">${ICONS.agent}${esc(a.kind === 'claude-code' ? 'Claude Code' : 'Chat agent')}</span>${a.project ? `<span class="sep">·</span>${esc(a.project)}${a.git_branch ? ` (${esc(a.git_branch)})` : ''}` : ''}${a.machine ? `<span class="sep">·</span>${esc(a.machine)}` : ''}<span class="sep">·</span>${ago(a.status_since)}</div>
        ${excerpt ? `<div class="excerpt">${esc(excerpt.split('\n').find((l) => l.trim()) || '')}</div>` : ''}
      </div>
      ${pill}
    </li>`;
  }
  const t = item.ref;
  const status = item.status;
  const right = status === 'snoozed' ? `<span class="pill">until ${esc(when(t.snooze_until))}</span>`
    : status === 'done' ? `<span class="pill">done ${ago(t.completed_at)}</span>`
    : status === 'waiting' ? '<span class="pill">waiting</span>'
    : t.due ? `<span class="pill ${Date.parse(t.due) < Date.now() ? 'waiting' : ''}">due ${esc(when(t.due))}</span>`
    : t.draft ? '<span class="pill review">draft ready</span>' : '';
  return `<li class="row ${status === 'done' ? 'dim' : ''}" role="option" data-id="${esc(item.id)}" aria-selected="${sel}">
    <span class="bar" style="background:${cold ? 'transparent' : color}"></span>
    <span class="score ${cold ? 'cold' : ''}" style="background:${color}">${cold ? '–' : heat}</span>
    <div style="min-width:0">
      <div class="title">${esc(t.title)}</div>
      <div class="meta"><span class="src">${ICONS[t.source] || ICONS.manual}${esc(SOURCE_LABEL[t.source] || t.source)}</span>${t.from ? `<span class="sep">·</span>${esc(t.from)}` : ''}<span class="sep">·</span>P${t.priority}<span class="sep">·</span>${ago(t.created_at)}</div>
      ${t.notes ? `<div class="excerpt">${esc(t.notes.split('\n')[0])}</div>` : ''}
    </div>
    ${right}
  </li>`;
}

function agentPill(status) {
  const map = { waiting: 'Needs you', review: 'Ready for review', running: 'Working', idle: 'Idle', ended: 'Ended' };
  return `<span class="pill ${status}">${map[status] || status}</span>`;
}

const EMPTY = {
  focus: ['Nothing needs you right now.', 'Blocked agents, finished agent turns, and open tasks land here, hottest first.'],
  agents: ['No agents reporting yet.', 'Run bin/install-hooks.js on each Mac, then start a Claude Code session.'],
  waiting: ['Nothing waiting on others.', 'Press w on a task to park it here.'],
  snoozed: ['Nothing snoozed.', 'Press s on a task to snooze it until tomorrow morning.'],
  done: ['Nothing completed yet.', ''],
};

function renderList() {
  const view = VIEWS.find((v) => v.id === state.view) || VIEWS[0];
  const items = itemsFor(view.id);
  $('#view-title').textContent = view.name;
  $('#view-sub').textContent = view.sub;
  renderHeatbar(view.id === 'focus' ? items : items.filter((i) => i.kind === 'task' || i.needs));
  $('#list').innerHTML = items.map(rowHtml).join('');
  const [title, hint] = EMPTY[view.id] || ['All clear.', 'Nothing open here.'];
  $('#empty').hidden = items.length > 0;
  $('#empty').innerHTML = `<strong>${esc(title)}</strong>${esc(hint)}`;
  $('#quickadd').hidden = view.id === 'agents' || view.status === 'done';
  if (view.sources) $('#qa-source').value = view.sources[0];
}

function findItem(id) {
  const t = state.tasks.find((x) => x.id === id);
  if (t) return taskItem(t);
  const a = state.agents.find((x) => x.id === id);
  return a ? agentItem(a) : null;
}

function renderDetail() {
  const el = $('#detail');
  // Don't clobber a field the user is typing in when a live update arrives.
  if (el.contains(document.activeElement) && ['INPUT', 'TEXTAREA', 'SELECT'].includes(document.activeElement.tagName) && el.dataset.id === state.selected) return;
  const item = state.selected && findItem(state.selected);
  el.classList.toggle('open', Boolean(item));
  el.dataset.id = item ? item.id : '';
  if (!item) {
    el.innerHTML = '<p class="placeholder">Select an item to see details.</p>';
    return;
  }
  el.innerHTML = item.kind === 'agent' ? agentDetail(item) : taskDetail(item);
}

function heatHead(item, extra) {
  const color = heatColor(item.heat);
  return `<div class="heat-head"><span class="heat-chip" style="background:${color}">${item.heat}</span><span>heat · ${heatBand(item.heat)}</span>${extra ? `<span>·</span>${extra}` : ''}</div>`;
}

function taskDetail(item) {
  const t = item.ref;
  const s = item.status;
  const prio = [5, 4, 3, 2, 1].map((p) => `<button type="button" data-prio="${p}" aria-pressed="${t.priority === p}" style="${t.priority === p ? `background:${heatColor(p * 18)}` : ''}">P${p}</button>`).join('');
  return `
    <input class="title-input" data-field="title" value="${esc(t.title)}" aria-label="Title">
    ${heatHead(item, `${esc(SOURCE_LABEL[t.source])}${t.from ? ` from ${esc(t.from)}` : ''}`)}
    <div class="actions">
      ${s !== 'done' ? '<button class="primary" data-act="done" style="background:var(--ok);color:#fff">Done</button>' : '<button data-act="reopen">Reopen</button>'}
      ${s === 'open' ? '<button data-act="waiting">Waiting on others</button>' : ''}
      ${s === 'waiting' || s === 'snoozed' ? '<button data-act="reopen">Back to open</button>' : ''}
      ${s !== 'done' ? '<button data-act="snooze-3h">Snooze 3h</button><button data-act="snooze-tomorrow">Tomorrow</button><button data-act="snooze-week">Next week</button>' : ''}
      ${t.link ? `<a class="btn" href="${esc(t.link)}" target="_blank" rel="noopener">Open source ↗</a>` : ''}
      <button class="danger" data-act="delete">Delete</button>
    </div>
    <div class="field"><span class="label">Priority</span><div class="seg">${prio}</div></div>
    <div class="field"><label for="f-due">Due</label><input id="f-due" type="datetime-local" data-field="due" value="${toLocalInput(t.due)}"></div>
    ${t.draft !== undefined && t.draft !== null && t.draft !== '' || t.source === 'chat' || t.source === 'email' || t.source === 'slack' ? `
    <div class="field"><label for="f-draft">Draft ${t.draft ? '<button type="button" class="link-btn" data-act="copy-draft" style="float:right;text-transform:none;letter-spacing:0">Copy</button>' : ''}</label>
      <textarea id="f-draft" class="draft" data-field="draft" placeholder="Drafted reply or deliverable…">${esc(t.draft || '')}</textarea></div>` : ''}
    <div class="field"><label for="f-notes">Notes</label><textarea id="f-notes" data-field="notes" placeholder="Context, asks, links…">${esc(t.notes || '')}</textarea></div>
    <div class="field"><label for="f-link">Link</label><input id="f-link" data-field="link" value="${esc(t.link || '')}" placeholder="https://mail.google.com/…" style="width:100%"></div>
    <dl class="kv"><dt>Created</dt><dd>${new Date(t.created_at).toLocaleString()}</dd>${t.external_id ? `<dt>Source id</dt><dd>${esc(t.external_id)}</dd>` : ''}</dl>`;
}

function agentDetail(item) {
  const a = item.ref;
  const resume = a.kind === 'claude-code' && a.cwd ? `cd ${shellQuote(a.cwd)} && claude --resume ${a.id}` : '';
  return `
    <h2>${esc(a.title || a.project || 'Untitled session')}</h2>
    ${heatHead(item, agentPill(a.status))}
    <div class="actions">
      ${agentNeedsAction(a) ? '<button class="primary" data-act="ack" style="background:var(--accent);color:#fff">Handled</button>' : ''}
      ${a.status !== 'ended' ? '<button data-act="end">Mark ended</button>' : ''}
      ${a.link ? `<a class="btn" href="${esc(a.link)}" target="_blank" rel="noopener">Open ↗</a>` : ''}
      <button data-act="make-task">Make follow-up task</button>
      <button class="danger" data-act="remove-agent">Remove</button>
    </div>
    ${a.status === 'waiting' && a.message ? `<div class="field"><span class="label">Needs</span><div class="pre">${esc(a.message)}</div></div>` : ''}
    <dl class="kv">
      ${a.machine ? `<dt>Machine</dt><dd>${esc(a.machine)}</dd>` : ''}
      ${a.cwd ? `<dt>Directory</dt><dd>${esc(a.cwd)}</dd>` : ''}
      ${a.git_branch ? `<dt>Branch</dt><dd>${esc(a.git_branch)}</dd>` : ''}
      ${a.permission_mode ? `<dt>Mode</dt><dd>${esc(a.permission_mode)}</dd>` : ''}
      <dt>Status since</dt><dd>${new Date(a.status_since).toLocaleString()}</dd>
      <dt>Last event</dt><dd>${esc(a.last_event || '–')} · ${ago(a.updated_at)}</dd>
    </dl>
    ${resume ? `<div class="field"><span class="label">Resume</span><div class="code"><span>${esc(resume)}</span><button class="link-btn" data-act="copy-resume">Copy</button></div></div>` : ''}
    ${a.last_message ? `<div class="field"><span class="label">Latest from agent</span><div class="pre">${esc(a.last_message)}</div></div>` : ''}
    ${a.last_prompt ? `<div class="field"><span class="label">Your last prompt</span><div class="pre">${esc(a.last_prompt)}</div></div>` : ''}`;
}
const shellQuote = (s) => (/^[\w./~-]+$/.test(s) ? s : `'${s.replace(/'/g, `'\\''`)}'`);

// ---- interactions ----------------------------------------------------------
function select(id) {
  state.selected = id;
  renderList();
  renderDetail();
  document.querySelector(`.row[data-id="${CSS.escape(id)}"]`)?.scrollIntoView({ block: 'nearest' });
}

$('#tabs').addEventListener('click', (e) => {
  const tab = e.target.closest('.tab');
  if (!tab) return;
  state.view = tab.dataset.view;
  localSet('taskdeck.view', state.view);
  state.selected = null;
  render();
});

$('#list').addEventListener('click', (e) => {
  const row = e.target.closest('.row');
  if (row) select(row.dataset.id);
});

$('#quickadd').addEventListener('submit', async (e) => {
  e.preventDefault();
  const title = $('#qa-title').value.trim();
  if (!title) return;
  const task = await api('POST', '/api/tasks', { title, source: $('#qa-source').value, priority: Number($('#qa-priority').value) });
  $('#qa-title').value = '';
  if (task) state.selected = task.id;
});

const nextMorning = (days) => {
  const d = new Date();
  d.setDate(d.getDate() + days);
  d.setHours(8, 30, 0, 0);
  return d.toISOString();
};
const nextMonday = () => {
  const d = new Date();
  return nextMorning(((8 - d.getDay()) % 7) || 7);
};

async function act(action) {
  const item = state.selected && findItem(state.selected);
  if (!item) return;
  const id = item.id;
  const advance = () => {
    // Keep flow: after clearing an item, move selection to the next one.
    const ids = itemsFor(state.view).map((i) => i.id);
    const idx = ids.indexOf(id);
    state.selected = ids[idx + 1] || ids[idx - 1] || null;
  };
  switch (action) {
    case 'done': advance(); await patchTask(id, { status: 'done' }); toast('Done'); break;
    case 'reopen': await patchTask(id, { status: 'open' }); break;
    case 'waiting': advance(); await patchTask(id, { status: 'waiting' }); toast('Moved to Waiting on others'); break;
    case 'snooze-3h': advance(); await patchTask(id, { status: 'snoozed', snooze_until: new Date(Date.now() + 3 * 36e5).toISOString() }); toast('Snoozed 3 hours'); break;
    case 'snooze-tomorrow': advance(); await patchTask(id, { status: 'snoozed', snooze_until: nextMorning(1) }); toast('Snoozed until tomorrow'); break;
    case 'snooze-week': advance(); await patchTask(id, { status: 'snoozed', snooze_until: nextMonday() }); toast('Snoozed until Monday'); break;
    case 'delete': if (confirm('Delete this task?')) { advance(); await api('DELETE', `/api/tasks/${id}`); } break;
    case 'copy-draft': await navigator.clipboard.writeText(item.ref.draft || ''); toast('Draft copied'); break;
    case 'ack': advance(); await patchAgent(id, { status: 'idle' }); break;
    case 'end': await patchAgent(id, { status: 'ended' }); break;
    case 'remove-agent': advance(); await api('DELETE', `/api/agents/${encodeURIComponent(id)}`); break;
    case 'copy-resume': await navigator.clipboard.writeText(document.querySelector('.code span').textContent); toast('Resume command copied'); break;
    case 'make-task': {
      const a = item.ref;
      const task = await api('POST', '/api/tasks', { title: `Follow up: ${a.title || a.project}`, source: 'agent', priority: 3, notes: `${a.machine || ''} ${a.cwd || ''}`.trim(), link: a.link });
      state.view = 'manual';
      state.selected = task.id;
      render();
      break;
    }
  }
}

$('#detail').addEventListener('click', (e) => {
  const btn = e.target.closest('[data-act]');
  if (btn) return act(btn.dataset.act);
  const prio = e.target.closest('[data-prio]');
  if (prio) patchTask(state.selected, { priority: Number(prio.dataset.prio) });
});

$('#detail').addEventListener('change', (e) => {
  const field = e.target.dataset.field;
  if (!field || !state.selected) return;
  let value = e.target.value;
  if (field === 'due') value = value ? new Date(value).toISOString() : null;
  patchTask(state.selected, { [field]: value }).then(() => renderDetail());
});

document.addEventListener('keydown', (e) => {
  if (e.metaKey || e.ctrlKey || e.altKey) return;
  const typing = ['INPUT', 'TEXTAREA', 'SELECT'].includes(document.activeElement?.tagName);
  if (e.key === 'Escape') {
    if (typing) document.activeElement.blur();
    else { state.selected = null; renderList(); renderDetail(); }
    return;
  }
  if (typing) return;
  const ids = itemsFor(state.view).map((i) => i.id);
  const idx = ids.indexOf(state.selected);
  const item = state.selected && findItem(state.selected);
  switch (e.key) {
    case 'j': case 'ArrowDown': if (ids.length) select(ids[Math.min(ids.length - 1, idx + 1)]); break;
    case 'k': case 'ArrowUp': if (ids.length) select(ids[Math.max(0, idx - 1)]); break;
    case 'n': e.preventDefault(); $('#qa-title').focus(); break;
    case 'e': if (item?.kind === 'task') act('done'); else if (item?.kind === 'agent') act('ack'); break;
    case 'w': if (item?.kind === 'task') act('waiting'); break;
    case 's': if (item?.kind === 'task') act('snooze-tomorrow'); break;
    case '1': case '2': case '3': case '4': case '5':
      if (item?.kind === 'task') patchTask(item.id, { priority: Number(e.key) });
      break;
    default: {
      // Jump between tabs with [ and ].
      const vi = VIEWS.findIndex((v) => v.id === state.view);
      if (e.key === ']' || e.key === '[') {
        state.view = VIEWS[(vi + (e.key === ']' ? 1 : VIEWS.length - 1)) % VIEWS.length].id;
        state.selected = null;
        localSet('taskdeck.view', state.view);
        render();
      }
    }
  }
});

// ---- desktop alerts --------------------------------------------------------
const alertsBtn = $('#alerts');
if ('Notification' in window && Notification.permission === 'default') {
  alertsBtn.hidden = false;
  alertsBtn.addEventListener('click', async () => {
    await Notification.requestPermission();
    alertsBtn.hidden = Notification.permission !== 'default';
  });
}
let primed = false;
function maybeAlert() {
  const fresh = new Map();
  const toAlert = [];
  for (const a of state.agents) {
    if (!agentNeedsAction(a)) continue;
    fresh.set(a.id, a.status);
    if (primed && lastAlerted.get(a.id) !== a.status) toAlert.push({ title: a.status === 'waiting' ? 'Agent needs you' : 'Agent finished', body: `${a.title || a.project} · ${a.machine || ''}\n${a.message || a.last_message || ''}`.slice(0, 200), id: a.id });
  }
  for (const t of state.tasks) {
    const item = taskItem(t);
    if (!item.needs || item.heat < 70) continue;
    fresh.set(t.id, 'hot');
    if (primed && !lastAlerted.has(t.id)) toAlert.push({ title: `New ${SOURCE_LABEL[t.source]} task`, body: t.title, id: t.id });
  }
  lastAlerted = fresh;
  primed = true;
  if (!('Notification' in window) || Notification.permission !== 'granted') return;
  for (const a of toAlert.slice(0, 3)) {
    const n = new Notification(a.title, { body: a.body, tag: a.id, icon: '/icon.svg' });
    n.onclick = () => { window.focus(); select(a.id); };
  }
}

// Heat changes with time (ageing asks, due dates, snoozes waking up).
setInterval(render, 30000);

if ('serviceWorker' in navigator) navigator.serviceWorker.register('/sw.js').catch(() => {});

render();
connect();
