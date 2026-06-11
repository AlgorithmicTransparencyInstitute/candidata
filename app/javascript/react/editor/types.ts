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
  lastName: string
  party: string | null
  outcome: string | null
  incumbent: boolean
  gender: string | null
  race: string | null
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
  urls: { save: string; people: string; offices: string; contests: string; back: string }
  contests: ContestOption[]
  parties: PartyOption[]
  contestParties: string[]
  platforms: string[]
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
  lastName: string
  party: string
  outcome: string
  incumbent: boolean
  gender: string
  race: string
  socials: Record<string, SocialCellState>
  baseline: string
  errors: string[]
  warnings: string[]
  justSaved: boolean
}

export type PersonResult = {
  id: number
  firstName: string
  lastName: string
  fullName: string
  state: string | null
  party: string | null
  gender: string | null
  race: string | null
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
