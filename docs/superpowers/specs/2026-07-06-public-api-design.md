# Public Read API (v1) — Design

**Date:** 2026-07-06
**Status:** Approved (brainstorming session with Cameron)

## Purpose

External services need Candidata as ground truth for:
- Who are the candidates in a given district/state (and who won)
- Who currently holds an office (who is the senator/rep for a state/district)
- Mirroring the dataset locally (bulk + incremental sync)

Both consumption patterns are in scope: **bulk sync** (paginated pulls with
`updated_since`) and **direct lookup** (filtered queries).

## Decisions Made

| Question | Decision |
|---|---|
| Consumption pattern | Both bulk sync and query endpoints |
| Auth | DB-backed `ApiToken` model, `Authorization: Bearer`, admin-managed |
| Person data scope | Verified socials only; demographics (gender, race); websites/bio fields |
| Architecture | Separate versioned `/api/v1` namespace, read-only, own serializers |

## Architecture

- New `Api::V1::BaseController` under `app/controllers/api/v1/`, routed at `/api/v1/*`.
- **Read-only**: index/show only. No mutations in v1.
- Reuses the internal API's conventions (`{data, meta}` envelope, error codes,
  pagination shape) but with **its own serializers** — the public contract must not
  drift when internal `/api` changes for the React frontend.
- No session/CSRF machinery; auth is header-only. Devise is not involved.

### Authentication: ApiToken

New model `ApiToken`:

| Column | Notes |
|---|---|
| `name` | which consumer service (required) |
| `token_digest` | SHA-256 of the token; plaintext never stored |
| `created_by_id` | FK → users |
| `last_used_at` | touched on authenticated requests, at most once per minute (avoids write amplification) |
| `revoked_at` | null = active |

- Token format: `cnd_live_<24 random chars>` (SecureRandom). Shown **once** at creation.
- Lookup by digest with timing-safe comparison.
- Missing/malformed/unknown/revoked token → 401 `UNAUTHORIZED`.
- Admin UI at `/admin/api_tokens`: create (displays token once), list with
  last-used, revoke. Admin-only. Per-consumer revocation without affecting others.

### Rate limiting

Rails 8 built-in `rate_limit` on the base controller, keyed by token, generous
(300 req/min) — never bothers a legitimate sync job, stops runaway loops. 429 on
exceed.

## Endpoints

All endpoints: paginated (`page`, `per_page` default 25 / **max 500**), support
`updated_since=<ISO8601>` for incremental sync, sorted by `id` for stable paging.

### 1. `GET /api/v1/officeholders` — "who holds this office"

- Default scope: **current** officeholders (`Officeholder.current`);
  `current=false` includes historical.
- Filters: `state`, `level` (federal/state/local), `branch`, `office_category`,
  `body_name`, `district` (number), `chamber`, `updated_since`.
- Example: `?state=TX&office_category=U.S.+Representative&district=14` → the
  TX-14 rep with embedded person and office/district.

### 2. `GET /api/v1/candidates` — "who is running / who won"

- Filters: `year`, `state`, `office_category`, `district`, `party`, `outcome`,
  `incumbent`, `updated_since`.
- `winners=true` convenience filter → `outcome IN Candidate::WINNING_OUTCOMES`
  (`won` + `advanced`), matching in-app winner logic.
- Embeds: person summary, contest → ballot → election chain (dates, type,
  primary party), office + district.

### 3. `GET /api/v1/people` — bulk-sync backbone

- Filters: `state`, `q` (name search), `updated_since`.
- Embeds: primary party + all parties, **verified** social accounts (platform,
  handle, url), websites, gender/race, photo_url, wikipedia_id, current offices,
  candidacies with outcomes.

### 4. `GET /api/v1/people/:person_uuid` — stable-ID lookup

- `person_uuid` is the public identifier; numeric `id` also included in payloads
  for reference.

### Deliberate omissions (YAGNI)

No separate elections/contests/offices endpoints in v1 — that structure arrives
embedded in candidates/officeholders. Additive later within v1 if needed.

### Incremental-sync correctness

`updated_since` on people must catch association changes: add `touch: true` to
the `SocialMediaAccount → person` and `PersonParty → person` associations so a
social-account or party-affiliation edit bumps the person's `updated_at`.

## Payload Shape

Same envelope as internal API. Officeholder example:

```json
{
  "data": [{
    "id": 123,
    "start_date": "2025-01-03", "end_date": null,
    "elected_year": 2024, "appointed": false, "current": true,
    "person": {
      "person_uuid": "…", "full_name": "…", "first_name": "…", "last_name": "…",
      "party": {"name": "Republican", "abbreviation": "R"},
      "gender": "…", "race": "…",
      "websites": {"official": "…", "campaign": "…", "personal": "…"},
      "photo_url": "…", "wikipedia_id": "…",
      "social_media_accounts": [{"platform": "twitter", "handle": "…", "url": "…"}]
    },
    "office": {
      "title": "…", "level": "federal", "branch": "legislative",
      "office_category": "U.S. Representative",
      "body_name": "U.S. House of Representatives",
      "state": "TX", "ocdid": "…",
      "district": {"state": "TX", "district_number": 14, "chamber": "lower", "ocdid": "…"}
    }
  }],
  "meta": {"total": 1, "page": 1, "per_page": 25, "total_pages": 1,
           "has_next_page": false, "has_previous_page": false}
}
```

Public serializers expose **no workflow fields**: no `research_status`,
`entered_by`, verification metadata, or Junkipedia columns. Socials are
verified-only.

## Error Handling

Same convention as internal API:

| Status | Code | When |
|---|---|---|
| 401 | `UNAUTHORIZED` | missing/bad/revoked token |
| 404 | `NOT_FOUND` | unknown person_uuid etc. |
| 400 | `PARAM_MISSING` / `INVALID_PARAM` | e.g. malformed `updated_since` |
| 429 | `RATE_LIMITED` | rate limit exceeded |

## Testing

- **RSpec request specs** (repo's established pattern, keep green):
  token accept/reject/revoke, each filter, verified-only socials enforcement,
  pagination caps, `updated_since` incl. social-account touch behavior,
  no-workflow-fields assertion on payloads.
- `lib/scripts/public_api_verify.rb` integration script against the dev DB,
  following the `api_verify.rb` convention.

## Documentation Deliverables

- `docs/PUBLIC_API.md` — consumer-facing: auth, endpoints, examples, bulk +
  incremental sync recipe.
- `docs/API_PLAN.md` — public phase → implemented, link to PUBLIC_API.md.
- `docs/SCHEMA.md` — ApiToken model.
- `docs/ARCHITECTURE.md` — new controllers/namespace.
- Admin guide (`app/views/admin/guide/show.html.erb`) — token management section.
