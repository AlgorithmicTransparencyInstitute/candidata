// JSON-file store for tasks and agent sessions. Small data, so the whole
// state lives in memory and is written atomically (tmp + rename) on change.

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { EventEmitter } from 'node:events';

export const SOURCES = ['email', 'slack', 'chat', 'report', 'agent', 'manual'];
export const TASK_STATUSES = ['open', 'waiting', 'snoozed', 'done'];
export const AGENT_STATUSES = ['idle', 'running', 'waiting', 'review', 'ended'];

const TASK_FIELDS = ['title', 'source', 'priority', 'status', 'from', 'link', 'notes', 'draft', 'due', 'snooze_until', 'external_id'];
const now = () => new Date().toISOString();
const truncate = (s, n) => (typeof s === 'string' && s.length > n ? s.slice(0, n - 1) + '…' : s);

export class Store extends EventEmitter {
  constructor(file) {
    super();
    this.file = file;
    this.data = { tasks: [], agents: [] };
    if (file && fs.existsSync(file)) {
      const parsed = JSON.parse(fs.readFileSync(file, 'utf8'));
      this.data.tasks = parsed.tasks || [];
      this.data.agents = parsed.agents || [];
    }
    this.saveTimer = null;
  }

  snapshot() {
    return { tasks: this.data.tasks, agents: this.data.agents, server_time: now() };
  }

  changed() {
    this.emit('change');
    if (!this.file) return;
    clearTimeout(this.saveTimer);
    this.saveTimer = setTimeout(() => this.flush(), 150);
  }

  flush() {
    if (!this.file) return;
    clearTimeout(this.saveTimer);
    fs.mkdirSync(path.dirname(this.file), { recursive: true });
    const tmp = `${this.file}.tmp`;
    fs.writeFileSync(tmp, JSON.stringify(this.data, null, 2));
    fs.renameSync(tmp, this.file);
  }

  // ---- tasks -------------------------------------------------------------

  sanitizeTask(input) {
    const out = {};
    for (const k of TASK_FIELDS) if (input[k] !== undefined) out[k] = input[k];
    if (out.source !== undefined && !SOURCES.includes(out.source)) throw new Error(`source must be one of ${SOURCES.join(', ')}`);
    if (out.status !== undefined && !TASK_STATUSES.includes(out.status)) throw new Error(`status must be one of ${TASK_STATUSES.join(', ')}`);
    if (out.priority !== undefined) {
      const p = Number(out.priority);
      if (!Number.isInteger(p) || p < 1 || p > 5) throw new Error('priority must be an integer 1-5');
      out.priority = p;
    }
    for (const k of ['due', 'snooze_until']) {
      if (out[k] === '' || out[k] === null) out[k] = null;
      else if (out[k] !== undefined && Number.isNaN(Date.parse(out[k]))) throw new Error(`${k} must be an ISO date`);
    }
    if (out.title !== undefined) out.title = truncate(String(out.title).trim(), 300);
    return out;
  }

  // Create, or merge into an existing task with the same source+external_id.
  // external_id lets inbox sweeps re-run without creating duplicates.
  upsertTask(input) {
    const fields = this.sanitizeTask(input);
    if (fields.external_id) {
      const existing = this.data.tasks.find((t) => t.external_id === fields.external_id && t.source === (fields.source || 'manual'));
      if (existing) {
        // Re-sweeps refresh content (title, notes, draft, link) but never
        // override triage decisions made on the board. Status changes go
        // through updateTask; a due date is only filled in if missing.
        for (const k of ['priority', 'status', 'snooze_until']) delete fields[k];
        if (existing.due) delete fields.due;
        Object.assign(existing, fields, { updated_at: now() });
        this.changed();
        return { task: existing, created: false };
      }
    }
    if (!fields.title) throw new Error('title is required');
    const task = {
      id: crypto.randomUUID(),
      source: 'manual',
      priority: 3,
      status: 'open',
      created_at: now(),
      ...fields,
      updated_at: now(),
    };
    if (task.status === 'done') task.completed_at = now();
    this.data.tasks.push(task);
    this.changed();
    return { task, created: true };
  }

  getTask(id) {
    return this.data.tasks.find((t) => t.id === id);
  }

  updateTask(id, patch) {
    const task = this.getTask(id);
    if (!task) return null;
    const fields = this.sanitizeTask(patch);
    if (fields.status === 'done' && task.status !== 'done') fields.completed_at = now();
    if (fields.status && fields.status !== 'done') fields.completed_at = null;
    if (fields.status && fields.status !== 'snoozed') fields.snooze_until = null;
    Object.assign(task, fields, { updated_at: now() });
    this.changed();
    return task;
  }

  deleteTask(id) {
    const before = this.data.tasks.length;
    this.data.tasks = this.data.tasks.filter((t) => t.id !== id);
    if (this.data.tasks.length !== before) this.changed();
    return this.data.tasks.length !== before;
  }

  // ---- agents ------------------------------------------------------------

  getAgent(id) {
    return this.data.agents.find((a) => a.id === id);
  }

  setAgentStatus(agent, status) {
    if (agent.status !== status) {
      agent.status = status;
      agent.status_since = now();
    }
  }

  // Ingest a Claude Code hook event (see hooks/taskdeck-hook.js).
  recordHookEvent(evt) {
    if (!evt.session_id) throw new Error('session_id is required');
    let agent = this.getAgent(evt.session_id);
    if (!agent) {
      agent = {
        id: evt.session_id,
        kind: 'claude-code',
        status: 'idle',
        status_since: now(),
        created_at: now(),
        events: 0,
      };
      this.data.agents.push(agent);
    }
    for (const k of ['machine', 'cwd', 'git_branch', 'transcript_path', 'permission_mode']) {
      if (evt[k]) agent[k] = evt[k];
    }
    if (evt.cwd && !agent.project) agent.project = path.basename(evt.cwd);
    agent.events += 1;
    agent.last_event = evt.hook_event_name;
    agent.updated_at = now();

    switch (evt.hook_event_name) {
      case 'SessionStart':
        if (agent.status === 'ended') this.setAgentStatus(agent, 'idle');
        break;
      case 'UserPromptSubmit':
        if (evt.prompt) {
          agent.last_prompt = truncate(evt.prompt, 2000);
          if (!agent.title) agent.title = truncate(evt.prompt.split('\n')[0], 120);
        }
        agent.message = null;
        this.setAgentStatus(agent, 'running');
        break;
      case 'PreToolUse':
      case 'PostToolUse':
        // Tool activity after a permission prompt means you approved it.
        if (agent.status !== 'ended') this.setAgentStatus(agent, 'running');
        break;
      case 'Notification': {
        const type = evt.notification_type || '';
        const msg = evt.message || '';
        const idle = type === 'idle_prompt' || /waiting for your input/i.test(msg);
        if (type === 'auth_success') break;
        agent.message = truncate(msg, 500);
        // The 60s idle reminder after a finished turn is not a new blocker.
        if (idle && agent.status === 'review') break;
        this.setAgentStatus(agent, idle ? 'review' : 'waiting');
        break;
      }
      case 'Stop':
        if (evt.last_message) agent.last_message = truncate(evt.last_message, 4000);
        agent.message = null;
        this.setAgentStatus(agent, 'review');
        break;
      case 'SessionEnd':
        this.setAgentStatus(agent, 'ended');
        break;
      default:
        break;
    }
    this.changed();
    return agent;
  }

  // Non-Claude-Code agents (claude.ai chats, Claude Desktop, scripts) report
  // their own status through MCP or the REST API.
  reportAgent({ key, title, status, summary, link, machine, kind }) {
    if (!key) throw new Error('key is required');
    if (status && !AGENT_STATUSES.includes(status)) throw new Error(`status must be one of ${AGENT_STATUSES.join(', ')}`);
    const id = `ext:${key}`;
    let agent = this.getAgent(id);
    if (!agent) {
      agent = { id, kind: kind || 'chat', status: 'running', status_since: now(), created_at: now(), events: 0 };
      this.data.agents.push(agent);
    }
    if (title) agent.title = truncate(title, 200);
    if (summary) agent.last_message = truncate(summary, 4000);
    if (link) agent.link = link;
    agent.machine = machine || agent.machine || 'claude.ai';
    if (status) this.setAgentStatus(agent, status);
    agent.events += 1;
    agent.updated_at = now();
    this.changed();
    return agent;
  }

  updateAgent(id, patch) {
    const agent = this.getAgent(id);
    if (!agent) return null;
    if (patch.status) {
      if (!AGENT_STATUSES.includes(patch.status)) throw new Error(`status must be one of ${AGENT_STATUSES.join(', ')}`);
      this.setAgentStatus(agent, patch.status);
    }
    if (patch.title !== undefined) agent.title = truncate(String(patch.title), 200);
    if (patch.pinned !== undefined) agent.pinned = Boolean(patch.pinned);
    agent.updated_at = now();
    this.changed();
    return agent;
  }

  deleteAgent(id) {
    const before = this.data.agents.length;
    this.data.agents = this.data.agents.filter((a) => a.id !== id);
    if (this.data.agents.length !== before) this.changed();
    return this.data.agents.length !== before;
  }

  // Housekeeping: drop ended sessions after a day, finished tasks after 30.
  prune(nowMs = Date.now()) {
    const agentsBefore = this.data.agents.length;
    const tasksBefore = this.data.tasks.length;
    this.data.agents = this.data.agents.filter((a) => a.pinned || a.status !== 'ended' || nowMs - Date.parse(a.updated_at) < 864e5);
    this.data.tasks = this.data.tasks.filter((t) => t.status !== 'done' || nowMs - Date.parse(t.completed_at || t.updated_at) < 30 * 864e5);
    if (this.data.agents.length !== agentsBefore || this.data.tasks.length !== tasksBefore) this.changed();
  }
}
