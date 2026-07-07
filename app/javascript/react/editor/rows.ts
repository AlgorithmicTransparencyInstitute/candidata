import type { ImportRow, Payload, PersonResult, RowPayload, RowState, SaveRowResult } from "./types"

let rowSeq = 0

export function makeRow(payload: Partial<RowPayload>, platforms: string[]): RowState {
  const socials: RowState["socials"] = {}
  for (const platform of platforms) {
    const cell = payload.socials?.[platform]
    socials[platform] = {
      accountId: cell?.accountId ?? null,
      value: cell?.url || cell?.handle || "",
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
    middleName: payload.middleName ?? "",
    lastName: payload.lastName ?? "",
    suffix: payload.suffix ?? "",
    party: payload.party ?? "",
    outcome: payload.outcome || "pending",
    incumbent: !!payload.incumbent,
    gender: payload.gender ?? "",
    race: payload.race ?? "",
    website: payload.website ?? "",
    nameSource: payload.nameSource ?? "",
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
    row.contestId, row.firstName, row.middleName, row.lastName, row.suffix,
    row.party, row.outcome, row.incumbent, row.gender, row.race,
    row.website, row.nameSource,
    platforms.map(p => row.socials[p].value.trim())
  ])
}

export function isDirty(row: RowState, platforms: string[]): boolean {
  return snapshot(row, platforms) !== row.baseline
}

export function isBlankNewRow(row: RowState, platforms: string[]): boolean {
  return !row.candidateId && !row.personId &&
    !row.firstName.trim() && !row.middleName.trim() && !row.lastName.trim() && !row.suffix.trim() &&
    !row.website.trim() &&
    platforms.every(p => !row.socials[p].value.trim())
}

export function linkPerson(row: RowState, person: PersonResult, platforms: string[]): RowState {
  const next: RowState = { ...row, socials: { ...row.socials } }
  next.personId = person.id
  next.firstName = person.firstName
  next.middleName = person.middleName ?? ""
  next.lastName = person.lastName
  next.suffix = person.suffix ?? ""
  if (!next.gender && person.gender) next.gender = person.gender
  if (!next.race && person.race) next.race = person.race
  if (!next.party && person.party) next.party = person.party
  if (!next.website && person.website) next.website = person.website
  for (const platform of platforms) {
    const existing = person.socials[platform]
    if (existing && !next.socials[platform].value.trim()) {
      next.socials[platform] = {
        accountId: existing.accountId,
        value: existing.url || existing.handle || "",
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
      ? { accountId: cell.accountId, value: cell.url || cell.handle || "", url: cell.url, verified: !!cell.verified }
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
    middleName: row.middleName,
    lastName: row.lastName,
    suffix: row.suffix,
    party: row.party,
    outcome: row.outcome,
    incumbent: row.incumbent,
    gender: row.gender,
    race: row.race,
    website: row.website,
    nameSource: row.nameSource,
    socials
  }
}

export function initialRows(payload: Payload): RowState[] {
  return payload.rows.map(r => makeRow(r, payload.platforms))
}

// A CSV-imported row staged into the grid. baseline stays "" so the row is
// always dirty until saved (applySaveResult recomputes a real baseline).
// Social cells carry the accountId binding of a matched person's existing
// account so saving updates that account instead of creating a duplicate.
export function makeImportedRow(imp: ImportRow, contestId: number, platforms: string[]): RowState {
  const row = makeRow({
    personId: imp.personId,
    contestId,
    firstName: imp.firstName,
    middleName: imp.middleName,
    lastName: imp.lastName,
    suffix: imp.suffix,
    party: imp.party,
    outcome: imp.outcome,
    incumbent: imp.incumbent,
    gender: imp.gender,
    race: imp.race,
    website: imp.website,
    nameSource: imp.nameSource
  }, platforms)
  for (const platform of platforms) {
    const cell = imp.socials[platform]
    if (cell) {
      row.socials[platform] = {
        accountId: cell.accountId,
        value: cell.value,
        url: cell.url,
        verified: cell.verified
      }
    }
  }
  row.warnings = imp.warnings
  row.baseline = ""
  return row
}

// Merge a CSV import into an existing grid row (the person is already a
// candidate in this contest). Only values the CSV actually provided are
// applied — absent columns never clobber current data — and demographics/
// name parts follow the DB-wins policy: they fill BLANK cells only, so a
// spreadsheet's vocabulary never overwrites curated values. Website, socials,
// and candidacy fields (party/outcome/incumbent) take the CSV value. Normal
// dirty tracking picks up whatever actually changed.
export function mergeImportIntoRow(row: RowState, imp: ImportRow, platforms: string[]): RowState {
  const csv = imp.csv
  const next: RowState = { ...row, socials: { ...row.socials }, justSaved: false }
  if (csv.party != null) next.party = csv.party
  if (csv.outcome != null) next.outcome = csv.outcome
  if (csv.incumbent != null) next.incumbent = csv.incumbent
  if (csv.gender != null && !next.gender) next.gender = csv.gender
  if (csv.race != null && !next.race) next.race = csv.race
  if (csv.middleName != null && !next.middleName.trim()) next.middleName = csv.middleName
  if (csv.suffix != null && !next.suffix.trim()) next.suffix = csv.suffix
  if (csv.website != null) next.website = csv.website
  if (csv.nameSource != null && !next.nameSource) next.nameSource = csv.nameSource
  for (const platform of platforms) {
    const value = csv.socials?.[platform]
    if (value) next.socials[platform] = { ...next.socials[platform], value }
  }
  return next
}

// Loose charset check for handle-looking values (URLs are exempt — the server
// parses those). Warn-only: unusual handles still save.
export function suspiciousHandle(value: string): boolean {
  const trimmed = value.trim()
  if (!trimmed || /^https?:\/\//i.test(trimmed)) return false
  return /[^A-Za-z0-9._\-@]/.test(trimmed)
}
