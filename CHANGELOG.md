# Changelog

A chronological record of substantial changes to candidata. Newer entries on top. For architectural detail, follow the doc links — this file is a navigation index, not a substitute.

## 2026-06-09 — Batch 5: May states import (168 candidates)

States imported to production: **IA, ME, ND, OK, SC, SD, UT, VA** (Senate-only file). Production 2026 candidate total: 1,489 → 1,657. Release v79.

- New cleaner `lib/scripts/clean_may_states_2026.rb` — handles the ND `Democract` typo, lowercase race variants (`black`, `hispanic`), trailing-`#` on Facebook profile.php URLs, and blank Incumbent/Withdrew columns (treated as false).
- New rake task `lib/tasks/import_may_states_2026.rake` — adds a pre-flight guard that aborts if any state in the batch lacks a 2026 primary `Election` record, so the importer can never silently fall back to the `2026-03-04` default for this batch.
- `PARTIES` constants in `app/models/ballot.rb` and `app/models/contest.rb` extended with **Constitution**, **Forward**, **Independent American** — required by Utah candidates.
- Raw source CSVs committed to `data/2026_states/may_states/`, cleaned outputs to `data/2026_states/cleaned/`.
- Drive source folder: [Primaries2026](https://drive.google.com/drive/folders/1aNZY0rWHRpwwAWMLsXtX0MOK-xBax_12).
- Doc: [`docs/CANDIDATE_CSV_IMPORT.md`](docs/CANDIDATE_CSV_IMPORT.md) batch history table updated.
- Commits: `8d4798d`, `3b7c26a`.

**Discovered during this batch:** the `EnhancedCandidate2026Importer`'s outer `rescue => e` swallows `ActiveRecord::RecordInvalid` from missing PARTIES — the import looks successful but silently drops candidates whose party isn't in the constant. UT was short 4 candidates and the gap was only visible by cross-checking cleaned-CSV row counts against DB candidate counts after the import. The CSV doc now warns about this.

## 2026-06-08 — Documentation + memory refresh

Refresh of the foundational docs to reflect everything built since the last touch. No code change.

- `CLAUDE.md` — new "Standard Operating Procedures" table, "Production DB refresh" recipe, "Junkipedia Auto-Sync" section, env-var additions, platform count fix (10 → 11), JunkipediaService and background-jobs listings.
- `README.md` — rewrote the badly stale top-level Overview (still claimed the app was an Airtable login). Refreshed Tech Stack. Trimmed legacy Airtable command examples. Expanded docs index.
- [`docs/CANDIDATE_CSV_IMPORT.md`](docs/CANDIDATE_CSV_IMPORT.md) — new "Source" section pointing at the Primaries2026 Drive folder. "Adding a New Batch" now starts with the Drive audit and ends with a note about Junkipedia auto-sync firing later on verification.
- [`docs/JUNKIPEDIA_INTEGRATION.md`](docs/JUNKIPEDIA_INTEGRATION.md) — full rewrite covering the auto-sync architecture, the three jobs, the dashboard, the rate-limit headers, the throttled rake task, the URL→handle extraction per platform, and an operational history table.
- Commit: `4486b8d`.

## 2026-06-04 — Junkipedia: handle-based search + throttled bulk match

Fixed two issues that surfaced during the prior day's preflight attempt.

- **Search shape was wrong.** Junkipedia's `/api/v2/channels/search` rejects `url=` with HTTP 422 and only accepts `handle`, `platform`, `uid`, or `channel_ids`. `JunkipediaService#search_channel` now takes `handle:` only. The 2,209 successful records on 2026-06-03 worked accidentally because we also sent `handle=` (which for some rows was a real handle, by luck).
- **`JunkipediaService.handle_from(account)`** — extracts a Junkipedia-style handle from `account.handle` (if not itself a URL) or from `account.url` via per-platform regex. Facebook `profile.php?id=…` URLs return `nil` (would need uid-based lookup, not yet wired).
- **`RateLimitError`** — `JunkipediaService` now parses `x-ratelimit-remaining`/`x-ratelimit-reset` headers from every response and caches them. `RateLimitError#seconds_until_reset` returns a precise back-off duration. `ResolveJunkipediaChannelIdJob` catches `RateLimitError` and reschedules via `job.set(wait: …).perform_later(…)` so a 429 storm doesn't burn polynomial retries.
- **New rake task `junkipedia:match_pending`** — the canonical bulk backfill path. Throttled, watches `x-ratelimit-remaining`, pauses until the window resets when within the safety buffer. Env vars: `RATE`, `FLOOR`, `BUFFER`, `STATE`, `LIMIT`, `INCLUDE_ERRORED`. Default rate 1.2 req/sec (~4,320/hour, under the 5,000/hour cap).
- **New rake task `junkipedia:clear_errors`** — wipes `junkipedia_last_error` so retries start clean.
- Dashboard banner appears when pending > 1000, pointing admins at the rake task instead of the dashboard buttons.
- Doc: [`docs/JUNKIPEDIA_INTEGRATION.md`](docs/JUNKIPEDIA_INTEGRATION.md).
- Commit: `bc17778`.

## 2026-06-03 — Junkipedia preflight match (initial attempt — exposed two issues)

Added the "Match existing channels" button on `/admin/junkipedia` and ran it against the 28,770 pending accounts on production.

- Result: 2,209 matched, 21,572 errored. Errors were HTTP 429 ("API rate limit exceeded. Current limit: 5000 requests per hour (Pro tier)").
- Diagnosis revealed the wrong search-shape (see 2026-06-04 entry above).
- Junkipedia rate-limit headers (`x-ratelimit-*`) discovered during error-message inspection — used in the next day's fix.
- Commits: `efd0ab3`, `aef0da1`.

## 2026-06-01 — Junkipedia auto-sync architecture

End-to-end auto-sync replaces the prior manual per-state rake-task push. When a `SocialMediaAccount#verified` flips false → true, an after_commit hook enqueues a job chain that POSTs the URL to Junkipedia, later resolves the channel id via search, and adds the resolved channel to a shared list.

- **Migration**: `social_media_accounts` gains `junkipedia_channel_id`, `junkipedia_enqueued_at`, `junkipedia_id_collected_at`, `junkipedia_last_error` with indexes on the first two. (`db/migrate/20260601152936_*`.)
- **`JunkipediaService` extensions**: `enqueue_channel(url:)` for POST `/channels`, `search_channel(...)` for GET `/channels/search`, `add_channels_to_list(...)` for POST `/lists/:id/add_channels`. Plus `extract_channel_id(response)` and `first_channel_id(response)` parsers tolerating JSON:API and flat shapes.
- **Jobs**: `EnqueueJunkipediaChannelJob`, `ResolveJunkipediaChannelIdJob`, `AddChannelToDefaultListJob` (all with `retry_on` polynomial backoff for network errors).
- **Model hook** (`app/models/social_media_account.rb`): `after_commit on: [:create, :update]` fires `EnqueueJunkipediaChannelJob.perform_later(id)` when `saved_change_to_verified?` and verified and eligible and not already enqueued. No-op when `JUNKIPEDIA_API_TOKEN` is absent so dev environments without the token work unchanged.
- **Scopes**: `junkipedia_eligible`, `junkipedia_pending`, `junkipedia_unresolved`, `junkipedia_synced`, `junkipedia_errored` on `SocialMediaAccount`.
- **Admin dashboard** at `/admin/junkipedia` (`app/controllers/admin/junkipedia_controller.rb`, `app/views/admin/junkipedia/index.html.erb`) — status counts, filterable table, per-row + bulk re-enqueue / re-resolve buttons.
- **Production queue adapter** switched from `:inline` to `:async` (`config/environments/production.rb`) so HTTP-bound jobs don't block the verify request. Jobs lost on dyno restart are recoverable via the dashboard buttons.
- **Default list "Candidata Imports"** created on Junkipedia (list_id `10929`) via `junkipedia:create_list`. Heroku config: `JUNKIPEDIA_DEFAULT_LIST_ID=10929` (release v76); `JUNKIPEDIA_API_TOKEN` was already set in release v71.
- Decisions locked in by user during planning: one global list (not per-state), `:async` adapter (not solid_queue / inline), no auto-backfill of the 39k existing verified accounts on deploy (admin pushes the button).
- Doc: [`docs/JUNKIPEDIA_INTEGRATION.md`](docs/JUNKIPEDIA_INTEGRATION.md).
- Commits: `5688f67`, `aef0da1`.

## Earlier (pre-session-series) — Junkipedia push experiments

For context, the prior manual per-state push approach is still callable but no longer the recommended path. Operational notes from those runs:

- Texas push: list `10591`, ~2,328 channels added (2026-03-13).
- Illinois push (partial): list `10599`, ~1,326 channels added (2026-03-17).
- Bulk push attempted across all 56 states/territories on 2026-05-21 — ran at ~25 successful adds/min via API (~29h ETA), ~17.6% HTTP 500 rate, killed mid-run. Pivoted to bulk-uploader `.txt` files in `tmp/junkipedia/urls/` (uncommitted; intended for the Junkipedia UI uploader).

## Outstanding items (not yet deployed / known gaps)

### Kevin Ryan (IL) misattributed accounts — local fix only, NOT applied to production

Local development DB had Kevin Ryan (person_id 234785, IL) with 104 social media accounts attached, of which 98 belonged to 39 other candidates. The 98 misattributed records were created in a 2-second burst at 2026-02-08 03:00:03 from `temp_accounts` data (`data/Federal_Accounts.csv` is the source). Six legitimate accounts created earlier at 01:42:13 were preserved.

- The 98 were deleted from the **local** database only (no `airtable_id`, no researcher activity → safe to remove).
- **Production still has the 98 misattributed accounts.** Same delete query needs to run against prod after a backup. The exact code path that caused the misattribution was not fully confirmed — likely the older import path in `lib/tasks/merge_temp_data.rake#find_person_by_name`, which matches on `first_name = parts.first, last_name = parts.last` with no state filter. The `EnhancedCandidate2026Importer` does state-filter; whether the May batch is still vulnerable is unconfirmed.

### Importer: silently swallowed validation failures

`EnhancedCandidate2026Importer`'s outer `rescue => e` (lines ~80-83) catches `ActiveRecord::RecordInvalid` from missing PARTIES constants and logs to `@stats[:errors]` instead of raising. The import looks successful, but candidates with party not in the constant are silently dropped.

- Workaround: cross-check candidate counts against cleaned-CSV row counts after every import. Now documented in [`docs/CANDIDATE_CSV_IMPORT.md`](docs/CANDIDATE_CSV_IMPORT.md).
- Hardening (if wanted): change the rescue to re-raise on `RecordInvalid`, or add a specific `rescue ActiveRecord::RecordInvalid => e` branch that aborts the whole import.

### Junkipedia Facebook `profile.php?id=...` URLs not synced

`JunkipediaService.handle_from` returns `nil` for these URLs — they're skipped by the auto-sync match path. Would need a `uid`-based lookup, but the API probe for `uid: <numeric_id>, platform: Facebook` returned HTTP 422; the expected uid format isn't documented in our notes.

### Junkipedia bulk backfill not yet completed

As of 2026-06-04 the throttled rake task was probed (`LIMIT=30`, 87% match rate, no errors) but the full ~28k backfill was not run. To resume: `heroku run --app candidata bin/rails junkipedia:match_pending`. ETA ~6-12 hours at the default rate.

### `:async` queue adapter durability

Jobs are in-memory and lost on dyno restart. Acceptable for the current volume (occasional verifications produce 1 job each), but for the bulk backfill, prefer the rake task (which is synchronous) over the dashboard's bulk buttons.

## How to navigate

- **First time picking this back up:** read `CLAUDE.md` (instructions to Claude Code, but useful for humans too — has the SOPs and architecture pointers).
- **CSV import workflow detail:** [`docs/CANDIDATE_CSV_IMPORT.md`](docs/CANDIDATE_CSV_IMPORT.md).
- **Junkipedia integration detail:** [`docs/JUNKIPEDIA_INTEGRATION.md`](docs/JUNKIPEDIA_INTEGRATION.md).
- **Source of new state spreadsheets:** the [Primaries2026 Google Drive folder](https://drive.google.com/drive/folders/1aNZY0rWHRpwwAWMLsXtX0MOK-xBax_12) (owner: mm11506@nyu.edu, shared with cameron@ncoc.org).
- **Live Junkipedia sync status:** [`/admin/junkipedia`](https://candidata.space/admin/junkipedia) on production.
