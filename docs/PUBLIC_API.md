# Candidata Public API (v1)

Read-only JSON API for external services that need ground truth about
candidates, election winners, and current officeholders.

Base URL: `https://candidata.space/api/v1`

**Machine-readable spec:** `https://candidata.space/api/v1/openapi.json` (OpenAPI 3.1,
no auth required) — point client generators, Postman, or AI tools at it. Canonical
source: `docs/openapi.yaml` in this repo; keep it in sync with any endpoint change.

## Authentication

Every request needs a bearer token (issued by a Candidata admin at
`/admin/api_tokens` — one token per consumer service):

```bash
curl -H "Authorization: Bearer cnd_live_..." \
  "https://candidata.space/api/v1/officeholders?state=TX&district=14&office_category=U.S.+Representative"
```

Missing/invalid/revoked token → `401 {"error": …, "code": "UNAUTHORIZED"}`.
Rate limit: 300 requests/minute per token (429 `RATE_LIMITED` beyond that).

## Conventions

- Success: `{"data": …, "meta": …}`. Errors: `{"error": …, "code": "NOT_FOUND" | "INVALID_PARAM" | "UNAUTHORIZED" | "RATE_LIMITED"}`.
- Pagination on every list: `?page=` (default 1) and `?per_page=` (default 25, max 500).
  `meta`: `total`, `page`, `per_page`, `total_pages`, `has_next_page`, `has_previous_page`.
  Rows are ordered by `id` — stable across pages.
- Incremental sync: every list accepts `?updated_since=<ISO8601>` and returns
  rows whose own `updated_at` is at or after that time.
- People are identified by `person_uuid` (stable). Numeric `id`s appear in
  payloads for reference but `person_uuid` is the key to store.
- Social media accounts in payloads are **verified, active accounts only**
  (Candidata's human verification workflow) — that's the ground-truth guarantee.
  Every account returned has a URL; internally, Candidata also verifies *absences*
  ("this candidate has no TikTok"), and those records never appear here.
- All filters on a request combine with **AND** — e.g. `winners=true&outcome=lost`
  yields an empty set (a candidate can't be both a winner and `lost`).
- The officeholders `party` filter is an **exact, case-sensitive match** against
  the officeholder's primary party name or abbreviation (`DEM`, `Democratic Party`;
  `dem` or `democratic party` will not match).

## Endpoints

### `GET /api/v1/officeholders`

Who holds office. **Returns current officeholders by default**; pass
`current=false` to include historical rows.

| Param | Meaning |
|---|---|
| `state` | Office state, e.g. `TX` |
| `level` | `federal` / `state` / `local` |
| `branch` | `executive` / `legislative` / `judicial` |
| `office_category` | e.g. `U.S. Senator`, `U.S. Representative`, `Governor`, `State Representative` |
| `body_name` | e.g. `U.S. House of Representatives` |
| `district` | District number (combine with `chamber` and/or `office_category` to disambiguate) |
| `chamber` | District chamber, e.g. `upper` / `lower` |
| `party` | Officeholder's primary party, by name or abbreviation (`Democratic Party` or `DEM`) |
| `current` | `false` to include former officeholders |
| `updated_since` | ISO8601 |

Row shape:

```json
{
  "id": 123,
  "start_date": "2025-01-03", "end_date": null,
  "elected_year": 2024, "appointed": false, "current": true,
  "updated_at": "2026-06-01T12:00:00Z",
  "person": { … see Person shape … },
  "office": {
    "id": 45, "title": "U.S. Representative",
    "level": "federal", "branch": "legislative", "role": "legislatorLowerBody",
    "office_category": "U.S. Representative", "body_name": "U.S. House of Representatives",
    "state": "TX", "seat": "District 14", "county": null, "jurisdiction": "United States", "ocdid": "…",
    "district": {"state": "TX", "district_number": 14, "chamber": null, "level": "federal", "ocdid": "…"}
  }
}
```

Examples:

```bash
# Who is the TX-14 U.S. rep?
…/officeholders?state=TX&office_category=U.S.+Representative&district=14

# Both current U.S. senators from New York
…/officeholders?state=NY&office_category=U.S.+Senator

# All current Democratic state legislators in Georgia
…/officeholders?state=GA&level=state&branch=legislative&party=DEM
```

### `GET /api/v1/candidates`

Who is running / ran / won.

| Param | Meaning |
|---|---|
| `year` | Contest year, e.g. `2026` |
| `state` | Ballot state |
| `office_category` | As above |
| `district` / `chamber` | Via the contest's office district |
| `party` | Matches the candidate's `party_at_time` (exact string, e.g. `Democratic`) |
| `outcome` | `won` / `lost` / `pending` / `withdrawn` / `unknown` / `advanced` |
| `winners` | `true` → outcome is `won` OR `advanced` (advanced = unopposed advancement to the general; Candidata counts it as a winning outcome) |
| `incumbent` | `true` = incumbents running; `false` = challengers |
| `updated_since` | ISO8601 |

Row shape: `{id, outcome, winner, incumbent, party_at_time, tally, updated_at,
person: {…}, contest: {id, name, contest_type, party, date, office: {…office shape…},
ballot: {id, state, date, election_type, party, year, election: {id, state, date, election_type, year}}}}`.

```bash
# All 2026 GA primary winners
…/candidates?year=2026&state=GA&winners=true

# Republican challengers in TX house districts
…/candidates?state=TX&party=Republican&incumbent=false&chamber=lower
```

### `GET /api/v1/people` and `GET /api/v1/people/:person_uuid`

The bulk-sync backbone and stable-ID lookup.

| Param (index) | Meaning |
|---|---|
| `state` | `state_of_residence` |
| `q` | Name search (space-separated terms, each matched against first/middle/last) |
| `updated_since` | ISO8601 — **includes social-account and party changes** (they touch the person) |

Person shape (also embedded in officeholders/candidates rows, minus
`current_offices`/`candidacies` which only the people endpoints include):

```json
{
  "id": 9876, "person_uuid": "6f0c…",
  "first_name": "Kathy", "middle_name": null, "last_name": "Hochul", "suffix": null,
  "full_name": "Kathy Hochul", "state_of_residence": "NY",
  "gender": "Female", "race": "White",
  "photo_url": "…", "wikipedia_id": "Kathy_Hochul",
  "websites": {"official": "…", "campaign": "…", "personal": null},
  "party": {"name": "Democratic Party", "abbreviation": "DEM"},
  "parties": [{"name": "Democratic Party", "abbreviation": "DEM", "is_primary": true}],
  "social_media_accounts": [
    {"platform": "Twitter", "handle": "GovKathyHochul",
     "url": "https://twitter.com/GovKathyHochul", "channel_type": "Official Office"}
  ],
  "updated_at": "2026-06-01T12:00:00Z",
  "current_offices": [{…office shape…, "start_date": "2021-08-24", "elected_year": null}],
  "candidacies": [{"id": 4, "outcome": "won", "winner": true, "incumbent": true,
                   "party_at_time": "Democratic", "tally": null,
                   "contest": {"id": 7, "name": "…", "contest_type": "primary",
                                "party": "Democratic", "date": "2026-06-23"}}]
}
```

## Mirroring the dataset (sync recipe)

Initial load — page through each list with `per_page=500`:

```
GET /api/v1/people?per_page=500&page=1..N
GET /api/v1/officeholders?per_page=500&page=1..N        (current only)
GET /api/v1/candidates?per_page=500&page=1..N
```

Then on a schedule (store the timestamp you started each sync at, reuse it as
the next `updated_since` — overlap is fine, the sync is idempotent by id):

```
GET /api/v1/people?updated_since=<last_sync>&per_page=500
GET /api/v1/officeholders?updated_since=<last_sync>&per_page=500&current=false
GET /api/v1/candidates?updated_since=<last_sync>&per_page=500
```

Person-level changes (new verified social, party change, demographic fix)
surface via `/people`'s `updated_since`. Officeholder/candidate `updated_since`
covers changes to those rows themselves (outcomes, end dates). Pass
`current=false` on the officeholders delta so you see terms that *ended*.

## Guarantees & caveats

- v1 shapes only change additively; breaking changes mean `/api/v2`.
- Socials: verified + active + has a URL. If an account is unverified, inactive,
  awaiting review, or is a verified *absence* record (a confirmed "no account on
  this platform", which carries no URL), it is absent from this API.
- `advanced` outcomes count as winners (see `winners=true`) — an unopposed
  primary advancement is a nomination.
- Data completeness varies by state and cycle; see `/help/coverage` in-app.
- Every person has a `person_uuid`. After importing new people, run
  `bin/rails public_api:backfill_person_uuids` if an importer created rows
  without one.
