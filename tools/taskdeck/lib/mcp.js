// Minimal MCP server (JSON-RPC 2.0, Streamable HTTP with JSON responses).
// Lets any Claude surface (Claude Code, Claude Desktop, claude.ai custom
// connectors) put work on the board and report its own status.

import { taskHeat, effectiveStatus, agentHeat } from '../public/heat.js';
import { SOURCES, TASK_STATUSES, AGENT_STATUSES } from './store.js';

const VERSION = '0.1.0';

const INSTRUCTIONS = `Taskdeck is the user's central task board. Use it to:
- Log follow-ups you discover (emails to answer, Slack requests, things to send) with taskdeck_add_task. Always pass external_id (Gmail thread id, Slack permalink) when there is one so repeat runs update instead of duplicating.
- When you draft an email/Slack reply or produce a report for the user, add or update a task with the draft text in "draft" and source "chat" or "report", so it is waiting for them in one place.
- For longer jobs, call taskdeck_report_status at the start (status "running") and when you finish ("review") or get blocked ("waiting").
Priority: 5 = drop everything, 4 = today, 3 = this week, 2 = when possible, 1 = someday.`;

const TASK_PROPS = {
  title: { type: 'string', description: 'Short imperative summary, e.g. "Reply to Dana re: Q3 budget"' },
  source: { type: 'string', enum: SOURCES, description: 'Where the task came from' },
  priority: { type: 'integer', minimum: 1, maximum: 5, description: '5 = urgent/critical, 3 = normal, 1 = someday' },
  from: { type: 'string', description: 'Person or channel the request came from' },
  link: { type: 'string', description: 'URL back to the email thread, Slack message, chat, or document' },
  notes: { type: 'string', description: 'Context: what is being asked, key details' },
  draft: { type: 'string', description: 'Drafted reply or deliverable text, ready to copy/send' },
  due: { type: 'string', description: 'ISO 8601 due date/time' },
  external_id: { type: 'string', description: 'Stable id from the source (Gmail thread id, Slack permalink) for de-duplication' },
};

export const TOOLS = [
  {
    name: 'taskdeck_add_task',
    description: 'Add a task to the user\'s Taskdeck board. If a task with the same source + external_id exists, its title/notes/draft/link are refreshed but the user\'s priority and status are kept (use taskdeck_update_task to change status).',
    inputSchema: { type: 'object', properties: TASK_PROPS, required: ['title'] },
  },
  {
    name: 'taskdeck_list_tasks',
    description: 'List tasks on the board, hottest (most important) first.',
    inputSchema: {
      type: 'object',
      properties: {
        source: { type: 'string', enum: SOURCES },
        status: { type: 'string', enum: [...TASK_STATUSES, 'active'], description: '"active" (default) = open + waiting + snoozed' },
        limit: { type: 'integer', minimum: 1, maximum: 200 },
      },
    },
  },
  {
    name: 'taskdeck_update_task',
    description: 'Update a task (status, priority, draft, notes, due, snooze). Use status "done" to complete, "waiting" when the ball is in someone else\'s court.',
    inputSchema: {
      type: 'object',
      properties: {
        id: { type: 'string' },
        status: { type: 'string', enum: TASK_STATUSES },
        snooze_until: { type: 'string', description: 'ISO date; use with status "snoozed"' },
        ...TASK_PROPS,
      },
      required: ['id'],
    },
  },
  {
    name: 'taskdeck_report_status',
    description: 'Register or update this agent/chat on the Agents tab so the user can see what you are working on and when you need them.',
    inputSchema: {
      type: 'object',
      properties: {
        key: { type: 'string', description: 'Stable identifier for this agent/chat (reuse it on every call)' },
        title: { type: 'string', description: 'What you are working on' },
        status: { type: 'string', enum: AGENT_STATUSES, description: 'running = working; waiting = blocked on the user; review = finished, needs the user to look; ended = done and dismissed' },
        summary: { type: 'string', description: 'Latest progress or result' },
        link: { type: 'string', description: 'URL to the chat or output' },
      },
      required: ['key', 'status'],
    },
  },
];

function summarizeTask(t) {
  return { id: t.id, title: t.title, source: t.source, status: effectiveStatus(t), priority: t.priority, heat: taskHeat(t), from: t.from, link: t.link, due: t.due, has_draft: Boolean(t.draft), external_id: t.external_id };
}

function callTool(store, name, args = {}) {
  switch (name) {
    case 'taskdeck_add_task': {
      const { task, created } = store.upsertTask(args);
      return { created, task: summarizeTask(task) };
    }
    case 'taskdeck_list_tasks': {
      const status = args.status || 'active';
      let tasks = store.data.tasks.filter((t) => {
        const s = effectiveStatus(t);
        return status === 'active' ? s !== 'done' : s === status;
      });
      if (args.source) tasks = tasks.filter((t) => t.source === args.source);
      tasks = tasks.map(summarizeTask).sort((a, b) => b.heat - a.heat).slice(0, args.limit || 50);
      const agents = store.data.agents
        .filter((a) => a.status === 'waiting' || a.status === 'review')
        .map((a) => ({ id: a.id, title: a.title || a.project, status: a.status, machine: a.machine, heat: agentHeat(a) }));
      return { tasks, agents_needing_attention: agents };
    }
    case 'taskdeck_update_task': {
      const { id, ...patch } = args;
      const task = store.updateTask(id, patch);
      if (!task) throw new Error(`No task with id ${id}`);
      return { task: summarizeTask(task) };
    }
    case 'taskdeck_report_status': {
      const agent = store.reportAgent(args);
      return { agent: { id: agent.id, status: agent.status } };
    }
    default:
      throw Object.assign(new Error(`Unknown tool: ${name}`), { rpcCode: -32602 });
  }
}

function handleOne(store, msg) {
  const isNotification = msg.id === undefined || msg.id === null;
  const reply = (result) => (isNotification ? null : { jsonrpc: '2.0', id: msg.id, result });
  const fail = (code, message) => (isNotification ? null : { jsonrpc: '2.0', id: msg.id, error: { code, message } });

  if (msg.jsonrpc !== '2.0' || typeof msg.method !== 'string') return fail(-32600, 'Invalid Request');

  switch (msg.method) {
    case 'initialize':
      return reply({
        protocolVersion: msg.params?.protocolVersion || '2025-06-18',
        capabilities: { tools: { listChanged: false } },
        serverInfo: { name: 'taskdeck', version: VERSION },
        instructions: INSTRUCTIONS,
      });
    case 'ping':
      return reply({});
    case 'tools/list':
      return reply({ tools: TOOLS });
    case 'tools/call':
      try {
        const result = callTool(store, msg.params?.name, msg.params?.arguments);
        return reply({ content: [{ type: 'text', text: JSON.stringify(result, null, 2) }], structuredContent: result });
      } catch (err) {
        if (err.rpcCode) return fail(err.rpcCode, err.message);
        return reply({ content: [{ type: 'text', text: `Error: ${err.message}` }], isError: true });
      }
    default:
      if (msg.method.startsWith('notifications/')) return null;
      return fail(-32601, `Method not found: ${msg.method}`);
  }
}

// Returns the JSON-RPC response body (object/array), or null for
// notification-only payloads (caller answers 202 Accepted).
export function handleMcp(store, payload) {
  if (Array.isArray(payload)) {
    const out = payload.map((m) => handleOne(store, m)).filter(Boolean);
    return out.length ? out : null;
  }
  return handleOne(store, payload);
}
