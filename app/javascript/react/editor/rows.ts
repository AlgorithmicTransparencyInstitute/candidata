import type { Payload, PersonResult, RowPayload, RowState, SaveRowResult } from "./types"

let rowSeq = 0

export function makeRow(payload: Partial<RowPayload>, platforms: string[]): RowState {
  const socials: RowState["socials"] = {}
  for (const platform of platforms) {
    const cell = payload.socials?.[platform]
    socials[platform] = {
      accountId: cell?.accountId ?? null,
      value: cell?.handle || cell?.url || "",
      url: cell?.url ?? null,
      verified: !!cell?.verified
    }
  }
  const row: RowState = {
    key: `r${++rowSeq}`,
    candidateId: payload.candidateId ?? null,
    personId: payload.personId ?? null,
    contestId: payload.contestId ?? null,
    firstName: payload.firstName ?? "",
    lastName: payload.lastName ?? "",
    party: payload.party ?? "",
    outcome: payload.outcome || "pending",
    incumbent: !!payload.incumbent,
    gender: payload.gender ?? "",
    race: payload.race ?? "",
    socials,
    baseline: "",
    errors: [],
    warnings: [],
    justSaved: false
  }
  row.baseline = snapshot(row, platforms)
  return row
}

export function snapshot(row: RowState, platforms: string[]): string {
  return JSON.stringify([
    row.contestId, row.firstName, row.lastName, row.party, row.outcome,
    row.incumbent, row.gender, row.race,
    platforms.map(p => row.socials[p].value.trim())
  ])
}

export function isDirty(row: RowState, platforms: string[]): boolean {
  return snapshot(row, platforms) !== row.baseline
}

export function isBlankNewRow(row: RowState, platforms: string[]): boolean {
  return !row.candidateId && !row.personId &&
    !row.firstName.trim() && !row.lastName.trim() &&
    platforms.every(p => !row.socials[p].value.trim())
}

export function linkPerson(row: RowState, person: PersonResult, platforms: string[]): RowState {
  const next: RowState = { ...row, socials: { ...row.socials } }
  next.personId = person.id
  next.firstName = person.firstName
  next.lastName = person.lastName
  if (!next.gender && person.gender) next.gender = person.gender
  if (!next.race && person.race) next.race = person.race
  if (!next.party && person.party) next.party = person.party
  for (const platform of platforms) {
    const existing = person.socials[platform]
    if (existing && !next.socials[platform].value.trim()) {
      next.socials[platform] = {
        accountId: existing.accountId,
        value: existing.handle || existing.url || "",
        url: existing.url,
        verified: !!existing.verified
      }
    }
  }
  return next
}

export function applySaveResult(row: RowState, result: SaveRowResult, platforms: string[]): RowState {
  const next: RowState = { ...row, socials: { ...row.socials } }
  next.candidateId = result.candidateId ?? row.candidateId
  next.personId = result.personId ?? row.personId
  next.errors = []
  next.warnings = result.warnings ?? []
  for (const [platform, cell] of Object.entries(result.socials ?? {})) {
    next.socials[platform] = cell
      ? { accountId: cell.accountId, value: cell.handle || cell.url || "", url: cell.url, verified: !!cell.verified }
      : { accountId: null, value: "", url: null, verified: false }
  }
  next.baseline = snapshot(next, platforms)
  next.justSaved = true
  return next
}

export function rowPayload(row: RowState, platforms: string[]) {
  const socials: Record<string, { accountId: number | null; value: string }> = {}
  for (const platform of platforms) {
    const cell = row.socials[platform]
    if (cell.accountId || cell.value.trim()) {
      socials[platform] = { accountId: cell.accountId, value: cell.value.trim() }
    }
  }
  return {
    key: row.key,
    candidateId: row.candidateId,
    personId: row.personId,
    contestId: row.contestId,
    firstName: row.firstName,
    lastName: row.lastName,
    party: row.party,
    outcome: row.outcome,
    incumbent: row.incumbent,
    gender: row.gender,
    race: row.race,
    socials
  }
}

export function initialRows(payload: Payload): RowState[] {
  return payload.rows.map(r => makeRow(r, payload.platforms))
}

// Loose charset check for handle-looking values (URLs are exempt — the server
// parses those). Warn-only: unusual handles still save.
export function suspiciousHandle(value: string): boolean {
  const trimmed = value.trim()
  if (!trimmed || /^https?:\/\//i.test(trimmed)) return false
  return /[^A-Za-z0-9._\-@]/.test(trimmed)
}
