// Heat scoring: one number (0-100) answering "what should I tackle first?".
// Shared by the hub (server.js imports it) and the browser UI, so the sort
// order and colours are identical everywhere.

const HOUR = 36e5;
const DAY = 864e5;
const MIN = 6e4;

const clamp = (n, lo, hi) => Math.max(lo, Math.min(hi, n));

// A snoozed task whose snooze time has passed is open again.
export function effectiveStatus(task, now = Date.now()) {
  if (task.status === 'snoozed' && task.snooze_until && Date.parse(task.snooze_until) <= now) return 'open';
  return task.status;
}

export function taskHeat(task, now = Date.now()) {
  const status = effectiveStatus(task, now);
  if (status === 'done' || status === 'snoozed') return 0;

  let h = clamp(task.priority ?? 3, 1, 5) * 14; // 14..70

  if (task.due) {
    const hrs = (Date.parse(task.due) - now) / HOUR;
    if (hrs < 0) h += 30;
    else if (hrs < 24) h += 20;
    else if (hrs < 72) h += 10;
  }

  // Someone is waiting on you: email/slack asks get hotter the longer they sit.
  if (status === 'open' && (task.source === 'email' || task.source === 'slack')) {
    const ageDays = (now - Date.parse(task.created_at)) / DAY;
    h += Math.min(15, Math.max(0, ageDays) * 3);
  }

  // A drafted reply is a quick win: nudge it up.
  if (status === 'open' && task.draft) h += 5;

  // Ball is in someone else's court.
  if (status === 'waiting') h *= 0.4;

  return Math.round(clamp(h, 0, 100));
}

// Agents: blocked agents are the hottest thing on the board (idle compute,
// and usually a 2-second decision). Finished turns waiting on review are next.
export function agentNeedsAction(agent) {
  return agent.status === 'waiting' || agent.status === 'review';
}

export function agentHeat(agent, now = Date.now()) {
  const since = agent.status_since ? (now - Date.parse(agent.status_since)) / MIN : 0;
  switch (agent.status) {
    case 'waiting': return Math.round(clamp(80 + since / 2, 80, 98));
    case 'review': return Math.round(clamp(55 + since / 6, 55, 78));
    default: return 0;
  }
}

export function isStale(agent, now = Date.now()) {
  return agent.status === 'running' && now - Date.parse(agent.updated_at) > 20 * MIN;
}

// Colour ramp: grey (cold) -> yellow -> orange -> red (hot).
export function heatColor(h) {
  if (h <= 0) return 'hsl(220 10% 55%)';
  if (h < 25) return 'hsl(210 25% 60%)';
  const t = (clamp(h, 25, 100) - 25) / 75; // 0..1
  const hue = 52 - 52 * t; // 52 (yellow) -> 0 (red)
  const sat = 80 + 10 * t;
  const light = 52 - 6 * t;
  return `hsl(${hue.toFixed(0)} ${sat.toFixed(0)}% ${light.toFixed(0)}%)`;
}

export function heatBand(h) {
  if (h >= 85) return 'critical';
  if (h >= 65) return 'high';
  if (h >= 40) return 'medium';
  if (h > 0) return 'low';
  return 'none';
}
