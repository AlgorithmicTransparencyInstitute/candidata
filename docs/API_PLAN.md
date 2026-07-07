# Candidata Internal API

JSON API under `/api/*` for the React frontend (and eventually a public API).
**Status: implemented and integration-verified** — every endpoint below is exercised by
`lib/scripts/api_verify.rb` (52 checks: CRUD, member actions, filters, pagination,
validation errors, authorization). Run it after API changes:

```bash
bin/rails runner lib/scripts/api_verify.rb   # creates temp records via real requests, cleans up after itself
```

## Conventions

**Auth** — Devise session (same login as the site). Reads need a signed-in user;
**mutations need an admin** and a CSRF token:

```js
fetch("/api/people", {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
  },
  body: JSON.stringify({ person: { … } })
})
```

There is deliberately **no unauthenticated mode** — the dev database holds production
data. For curl/scripting against the internal API there is no bypass; the **public
read API** (below) uses token auth (`Authorization: Bearer`).

**Responses** — `{ "data": …, "meta": … }` on success. Errors:
`{ "error": …, "code": "NOT_FOUND" | "VALIDATION_ERROR" (+ "errors": {field: […]}) | "FORBIDDEN" | "PARAM_MISSING" }`
with 404 / 422 / 403 / 400. Unauthenticated → 401.

**Pagination** — all index endpoints: `?page=` & `?per_page=` (default 25, max 100).
`meta`: `total`, `page`, `per_page`, `total_pages`, `has_next_page`, `has_previous_page`.

## Endpoints

| Resource | Routes | Filters (index) | Notes |
|---|---|---|---|
| **people** | index, show, create, update, `POST bulk_assign` | `q` (name search), `state`, `party_id` | show includes parties, current offices, candidacies, social accounts, assignments. create/update accept `primary_party_id`. **No destroy** (FK hazard via candidacies). |
| **elections** | full CRUD | `year`, `state`, `election_type` | show embeds ballots with contest counts. `year` auto-derives from `date`. |
| **ballots** | full CRUD | `election_id`, `state`, `election_type`, `year`, `party` | show embeds contests. Party required for primaries. |
| **contests** | full CRUD | `ballot_id`, `office_id`, `contest_type`, `party`, `year` | show embeds office, ballot, candidates with tallies. |
| **candidates** | full CRUD | `contest_id`, `person_id`, `outcome`, `incumbent` | `outcome` defaults to `pending` on create. Unique per (person, contest). |
| **social_media_accounts** | full CRUD + `POST :id/mark_entered`, `mark_not_found`, `verify`, `reject` | `person_id`, `platform`, `research_status`, `verified`, `channel_type`, `junkipedia` (pending/unresolved/synced/errored) | Workflow actions stamp `current_user`. **`verify` triggers the Junkipedia auto-enqueue** when the account is eligible (by design). |
| **offices** | index, show, create, update | `q`, `level`, `branch`, `state`, `office_category`, `body_name` | show embeds current officeholders. |
| **parties** | index, show | `ideology` | show adds `people_count`. |
| **states** | index, show | `state_type` | show adds district/office/ballot counts (string-keyed by abbreviation). |

`POST /api/people/bulk_assign` — `{ person_ids: [], user_id:, task_type: "data_collection", notes: }` →
creates Assignments; duplicates (same user+person+task_type) are reported in `meta.skipped_details`, not errors.

## Election editor endpoints (separate, view-specific)

The spreadsheet editor uses dedicated endpoints under `/admin/elections/:id/editor/*`
(aggregate load/save shaped for the grid) — see `docs/ELECTION_EDITOR.md`.

## Public API (implemented)

`/api/v1/*` — read-only, Bearer-token auth (`ApiToken` model, admin-managed at
`/admin/api_tokens`), 300 req/min/token. Endpoints: officeholders, candidates,
people (+ show by `person_uuid`); all paginated (max 500) with `updated_since`
incremental sync. Full consumer docs: `docs/PUBLIC_API.md`. Verified by
`bin/rails runner lib/scripts/public_api_verify.rb`.

## Future phases

- Researcher/verification workspace APIs (assignments lifecycle, queues)
- Admin ops APIs (users, Junkipedia dashboard ops)
- CSV export, websockets for live updates
