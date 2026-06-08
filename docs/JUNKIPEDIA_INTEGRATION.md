# Junkipedia Integration

## Purpose

Candidata maintains a comprehensive database of social media accounts for US elected officials, candidates, and political figures across 11 platforms (Facebook, Twitter, Instagram, YouTube, TikTok, BlueSky, TruthSocial, Gettr, Rumble, Telegram, Threads). [Junkipedia](https://www.junkipedia.org) is a social listening platform that collects and archives posts from public social media accounts for research purposes.

The integration pushes validated social media accounts from Candidata into Junkipedia as monitored channels, then stores the resulting Junkipedia channel id back on the Candidata record so the link is durable. Validated handles auto-sync — no manual push for normal day-to-day data flow.

## Architecture

```
SocialMediaAccount#verified flips false → true
        │
        ▼
after_commit hook (app/models/social_media_account.rb)
        │
        ▼
EnqueueJunkipediaChannelJob ──► POST /api/v2/channels { url: ... }
                                       │
                                       ▼
                                Junkipedia ingests the URL (async on their side)
                                       │
                                       ▼
ResolveJunkipediaChannelIdJob ──► GET /api/v2/channels/search?handle=…&platform=…
                                       │
                                       ▼
                                channel_id captured on the SocialMediaAccount
                                       │
                                       ▼
AddChannelToDefaultListJob ───► POST /api/v2/lists/{id}/add_channels
```

Background jobs run via Rails' `:async` adapter in production (in-memory thread pool — no worker dyno). Jobs lost on dyno restart are recoverable via the admin Junkipedia dashboard.

### Tracking columns on `social_media_accounts`

| Column | Purpose |
|--------|---------|
| `junkipedia_channel_id` | The Junkipedia channel id once resolved |
| `junkipedia_enqueued_at` | When the POST /channels (or successful search match) happened |
| `junkipedia_id_collected_at` | When the channel id was first stored |
| `junkipedia_last_error` | Most recent failure message (cleared on success) |

## Configuration

Environment variables:

| Variable | Where | Purpose |
|----------|-------|---------|
| `JUNKIPEDIA_API_TOKEN` | dev `.env` + Heroku config | API auth; auto-sync hook is a no-op without it |
| `JUNKIPEDIA_DEFAULT_LIST_ID` | dev `.env` (optional) + Heroku config | Junkipedia list id resolved channels are added to. Production: `10929` ("Candidata Imports") |

API tokens are generated in Junkipedia under User Account > Manage API Keys.

```bash
# Heroku production setup (one-time)
heroku config:set JUNKIPEDIA_API_TOKEN=... --app candidata
heroku run --app candidata 'bin/rails "junkipedia:create_list[Candidata Imports,Auto-synced from candidata.space when a handle is validated]"'
# (the rake task prints a list id — capture it)
heroku config:set JUNKIPEDIA_DEFAULT_LIST_ID=<id> --app candidata
```

## Platform Mapping

| Candidata | Junkipedia |
|-----------|------------|
| Facebook | Facebook |
| Twitter | Twitter |
| Instagram | Instagram |
| YouTube | YouTube |
| TikTok | TikTok |
| BlueSky | Bluesky |
| TruthSocial | TruthSocial |
| Gettr | GETTR |
| Rumble | Rumble |
| Telegram | Telegram |
| Threads | Threads |

## Admin Dashboard

`https://candidata.space/admin/junkipedia` shows status counts and provides re-queue / re-resolve buttons:

- **Pending** — eligible (verified, active, supported platform, URL present) but `junkipedia_enqueued_at IS NULL`
- **Enqueued (no ID)** — enqueued but no `junkipedia_channel_id` yet (waiting on resolve)
- **Synced** — `junkipedia_channel_id` populated
- **Errored** — `junkipedia_last_error` non-blank
- **Total eligible** — universe of accounts that should sync

Buttons:
- **Match existing channels** — bulk preflight resolve (search-only, no POST /channels). Best to use the rake task instead for large counts (see below).
- **Enqueue all pending** — POST /channels for every pending record.
- **Resolve missing IDs** — GET /channels/search for enqueued-but-unresolved records.
- Per-row **Re-enqueue** and **Re-resolve** for one-off retries.

The dashboard shows an amber warning when `pending > 1000` directing admins to the throttled rake task.

## Rate Limit

Junkipedia caps API calls at **5,000 requests / hour** on the Pro tier. The service:

- Reads `x-ratelimit-limit`, `x-ratelimit-remaining`, `x-ratelimit-reset` from every response and caches the most recent values on `JunkipediaService.rate_limit_remaining` / `.rate_limit_reset`.
- Raises `JunkipediaService::RateLimitError` on HTTP 429 with `seconds_until_reset` computed from the headers.
- `ResolveJunkipediaChannelIdJob` catches RateLimitError and reschedules via `set(wait:)` so the retry lands after the window resets — it does not burn polynomial retries during a 429 storm.

## Rake Tasks

### `junkipedia:match_pending` — the canonical bulk backfill

Throttled, rate-limit aware. Searches Junkipedia for each pending account; matches get marked synced with no POST /channels round trip.

```bash
# Default rate: 1.2 req/sec (≈4320/hour, under the 5000/hour cap)
heroku run --app candidata bin/rails junkipedia:match_pending

# Tuning
RATE=1.5         # target req/sec (capped by per-call latency)
FLOOR=0.3        # minimum req/sec (floor when remaining is low)
BUFFER=50        # pause when x-ratelimit-remaining drops below this
STATE=IL         # restrict to one state's accounts
LIMIT=500        # process at most N records
INCLUDE_ERRORED=0  # skip records with prior errors (default: include them)
```

The task watches `x-ratelimit-remaining` after every request and, when within `BUFFER`, sleeps until `x-ratelimit-reset` plus a small grace.

### `junkipedia:clear_errors`

Wipes `junkipedia_last_error` so retries start clean.

```bash
heroku run --app candidata bin/rails junkipedia:clear_errors
```

### Legacy / per-state tasks

Earlier per-state push tasks pre-date the auto-sync architecture. Still functional but not the recommended path for new work.

```bash
# Push one state into a freshly created list
bin/rails 'junkipedia:push_state[TX]'

# Push all states, reusing existing "Candidata - {STATE} Officials" lists
bin/rails junkipedia:push_all_idempotent

# Show channels in a Junkipedia list
bin/rails 'junkipedia:list_channels[10929]'

# Show all lists visible to the API token
bin/rails junkipedia:lists
```

### Preview

```bash
# What would be pushed if we enqueued everything pending right now
bin/rails junkipedia:preview
STATE=TX bin/rails junkipedia:preview
```

## API Notes

### `GET /api/v2/channels/search`

Accepts **`handle`** (+ optional `platform`), **`uid`**, or **`channel_ids`** as the identifier. Does **NOT** accept `url` — sending only `url` returns HTTP 422.

Candidata uses `JunkipediaService.handle_from(account)` to extract a usable handle. It prefers `account.handle` when present and not itself a URL; otherwise it pattern-matches against `account.url` per-platform:

| Platform | URL → handle |
|----------|--------------|
| Twitter | `twitter.com/USER` or `x.com/USER` → `USER` |
| Facebook | `facebook.com/USER` → `USER` (skip `profile.php?id=…`) |
| Instagram | `instagram.com/USER/` → `USER` |
| YouTube | `youtube.com/@HANDLE` or `/channel/UC...` or `/c/...` or `/user/...` → terminal segment |
| TikTok | `tiktok.com/@USER` → `USER` |
| BlueSky | `bsky.app/profile/USER` → `USER` |
| TruthSocial | `truthsocial.com/@USER` → `USER` |
| Telegram | `t.me/USER` → `USER` |
| Threads | `threads.net/@USER` → `USER` |
| Rumble | `rumble.com/user/USER` or `rumble.com/c/USER` → `USER` |
| Gettr | `gettr.com/user/USER` → `USER` |

Facebook `profile.php?id=...` URLs return `nil` from `handle_from` — those would need uid lookup, which is not yet wired.

### `POST /api/v2/channels`

Accepts `{ url: … }`. Junkipedia ingests the URL asynchronously; the response may or may not include a usable channel id immediately. For URLs Junkipedia hasn't seen before, the channel id is resolved on a later `/channels/search` round trip.

### `POST /api/v2/lists/{id}/add_channels`

Accepts `{ channel_ids: [...] }`. Used to add resolved channels into the default list (`JUNKIPEDIA_DEFAULT_LIST_ID`).

## Key Files

| File | Purpose |
|------|---------|
| `app/services/junkipedia_service.rb` | API client (enqueue, search, add_channels, list management). Caches rate-limit headers. Provides `handle_from(account)` extractor. |
| `app/jobs/enqueue_junkipedia_channel_job.rb` | POST /channels for one account |
| `app/jobs/resolve_junkipedia_channel_id_job.rb` | GET /channels/search → store channel id |
| `app/jobs/add_channel_to_default_list_job.rb` | POST /lists/:id/add_channels |
| `app/models/social_media_account.rb` | after_commit hook + scopes (`junkipedia_pending`, `junkipedia_unresolved`, `junkipedia_synced`, `junkipedia_errored`) |
| `app/controllers/admin/junkipedia_controller.rb` | Admin dashboard + bulk actions |
| `lib/tasks/junkipedia.rake` | `match_pending`, `clear_errors`, `create_list`, `push_state`, `push_all_idempotent`, etc. |

## Operational History

| Date | Action | Outcome |
|------|--------|---------|
| 2026-03-13 | Texas pushed via per-state rake task | List `10591`, ~2,328 channels |
| 2026-03-17 | Illinois pushed (partial) | List `10599`, ~1,326 channels |
| 2026-05-21 | Per-state push attempted for all 56 states/territories | ~25 successful adds/min via API (≈29h ETA); ~17.6% HTTP 500 rate; killed mid-run after 13 states. Pivoted to bulk-uploader .txt files. |
| 2026-06-01 | Auto-sync architecture deployed | after_commit hook + admin dashboard + jobs. Default list `10929` created on production. |
| 2026-06-03 | Bulk preflight rolled out | Initial run hit 5000/hour rate limit (~21k records errored), revealed `url` was an invalid search param. |
| 2026-06-04 | Search fixed to use `handle` extracted from URL; rate-limit aware throttled rake task `match_pending` shipped. Probe at `LIMIT=30` showed 87% match rate. |

## Known Issues

- **Facebook `profile.php?id=…`** URLs cannot be resolved via handle search. They need `uid` lookup, which is not yet wired in `JunkipediaService.search_channel`.
- **Dirty handles** — Some `social_media_accounts.handle` values contain URL query parameters (e.g., `?lang=en`) or non-handle strings (`highlights`). The extractor handles common cases but new variants surface periodically.
- **Async adapter durability** — Jobs are in-memory and lost on dyno restart. The admin dashboard's re-enqueue and re-resolve buttons (and the rake task) recover from this.
- **First-time URLs not in Junkipedia** — POST /channels enqueues for ingestion, but Junkipedia may take time to process. The Resolve job may need to be retried via the dashboard after Junkipedia has had time to index.
