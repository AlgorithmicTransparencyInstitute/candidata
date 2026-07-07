export type SocialCellPayload = {
  accountId: number | null
  handle: string | null
  url: string | null
  verified: boolean
}

export type RowPayload = {
  candidateId: number | null
  personId: number | null
  contestId: number | null
  firstName: string
  middleName: string | null
  lastName: string
  suffix: string | null
  party: string | null
  outcome: string | null
  incumbent: boolean
  gender: string | null
  race: string | null
  website: string | null
  nameSource: string | null
  socials: Record<string, SocialCellPayload>
}

export type ContestOption = {
  id: number
  label: string
  ballotLabel: string
  party: string | null
  partyCode: string | null
}

export type PartyOption = {
  value: string
  code: string
}

export type Payload = {
  election: { id: number; label: string; state: string; year: number; type: string; date: string }
  urls: { save: string; people: string; offices: string; contests: string; import: string; back: string }
  contests: ContestOption[]
  parties: PartyOption[]
  contestParties: string[]
  platforms: string[]
  platformIcons: Record<string, string>
  outcomes: string[]
  genders: string[]
  races: string[]
  rows: RowPayload[]
}

export type SocialCellState = {
  accountId: number | null
  value: string
  url: string | null
  verified: boolean
}

export type RowState = {
  key: string
  candidateId: number | null
  personId: number | null
  contestId: number | null
  firstName: string
  middleName: string
  lastName: string
  suffix: string
  party: string
  outcome: string
  incumbent: boolean
  gender: string
  race: string
  website: string
  nameSource: string
  socials: Record<string, SocialCellState>
  baseline: string
  errors: string[]
  warnings: string[]
  justSaved: boolean
}

export type PersonResult = {
  id: number
  firstName: string
  middleName: string | null
  lastName: string
  suffix: string | null
  fullName: string
  state: string | null
  party: string | null
  gender: string | null
  race: string | null
  website: string | null
  inThisElection: boolean
  socials: Record<string, SocialCellPayload>
}

export type OfficeResult = {
  id: number
  label: string
  level: string
  branch: string
  body: string | null
}

export type SaveRowResult = {
  key: string
  ok: boolean
  candidateId?: number
  personId?: number
  socials?: Record<string, SocialCellPayload | null>
  errors?: string[]
  warnings?: string[]
}

export type SaveResponse = {
  results: SaveRowResult[]
  deleted: number[]
}

// ---------- CSV import ----------

export type ImportSocialCell = {
  accountId: number | null
  value: string
  url: string | null
  verified: boolean
}

// Values the CSV itself provided (vs. prefill from a matched person) — used
// when merging an import into an already-loaded grid row. gender/race/
// middleName/suffix apply to BLANK cells only (DB wins); the rest replace.
export type ImportCsvValues = {
  party?: string | null
  outcome?: string | null
  incumbent?: boolean
  gender?: string | null
  race?: string | null
  middleName?: string | null
  suffix?: string | null
  website?: string | null
  nameSource?: string | null
  socials: Record<string, string>
}

export type ImportRow = {
  index: number
  firstName: string
  middleName: string | null
  lastName: string
  suffix: string | null
  party: string | null
  outcome: string
  incumbent: boolean
  withdrawn: boolean
  gender: string | null
  race: string | null
  website: string | null
  nameSource: string | null
  contestKey: string | null
  contestId: number | null
  personId: number | null
  personLabel: string | null
  mergeCandidateId: number | null
  socials: Record<string, ImportSocialCell>
  csv: ImportCsvValues
  issues: string[]
  warnings: string[]
}

export type ImportContestGroup = {
  key: string
  label: string
  party: string | null
  contestId: number | null
  officeId: number | null
  officeLabel: string | null
  status: "matched" | "create" | "unresolved"
  note: string | null
  rowCount: number
}

export type ImportMappingEntry = { header: string; field: string | null }

export type ImportSummary = {
  total: number
  withIssues?: number
  linked?: number
  newPeople?: number
  updates?: number
  withdrawn?: number
  contestsMatched?: number
  contestsToCreate?: number
  contestsUnresolved?: number
}

export type ImportPreview = {
  fields: { id: string; label: string }[]
  mapping: ImportMappingEntry[]
  rows: ImportRow[]
  contestGroups: ImportContestGroup[]
  summary: ImportSummary
  errors: string[]
}

// A previewed row bound to its final contest id (resolved or just created).
export type StagedImportRow = {
  row: ImportRow
  contestId: number
}
