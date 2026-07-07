# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Candidata is a Ruby on Rails 8.0.4 application that serves as a comprehensive database system for managing elected officials, candidates, elections, and social media presence for social listening research. It enables researchers to assign data collection and validation tasks to research assistants.

## Development Commands

```bash
# Setup
bundle install
bin/rails db:create db:migrate

# Development server (with Tailwind CSS watching)
bin/dev

# Database operations
bin/rails db:migrate
bin/rails db:rollback
bin/rails db:seed
```

## Data Import Commands

```bash
# Airtable import workflow
bin/rails import_csv:all          # Import CSVs to temp staging tables
bin/rails import_csv:analyze      # Analyze staged data
bin/rails extract:create_parties  # Create Party records from staged data
bin/rails extract:states          # Seed State records

# GovProj import workflow
bin/rails govproj:download         # Download current officeholders data
bin/rails govproj:load_temp        # Load into temp_govproj table
bin/rails govproj:analyze_temp     # Analyze before import

# Production import
bin/rails import:airtable          # Full Airtable import
```

## Architecture

### Domain Model

The application centers around political data entities:

- **Person** - Individuals (candidates, officials) with demographics, websites, and UUID tracking
- **Party** - Political parties with ideology classification
- **PersonParty** - Many-to-many join with `is_primary` flag (people can have multiple party affiliations)
- **Office** - Political offices with category, body_name, role, jurisdiction, and OCD-IDs
- **District** - Electoral districts (Congressional, state legislative, local)
- **State** - US states and territories reference table (FIPS codes)
- **Ballot** - Election ballots (state, date, type, year)
- **Contest** - Individual races on a ballot
- **Candidate** - Person running in a Contest (outcome, tally, incumbent status, party_at_time). `outcome` is one of won/lost/pending/withdrawn/unknown/`advanced`; `advanced` = advanced to the general unopposed (cancelled/uncontested primary), counted as a winner via `Candidate::WINNING_OUTCOMES` so it feeds winner lists + a future primary→general pipeline.
- **Officeholder** - Person holding an Office (with term dates, elected_year, appointed flag)
- **SocialMediaAccount** - Social handles linked to Person (11 platforms: Facebook, Twitter, Instagram, YouTube, TikTok, BlueSky, TruthSocial, Gettr, Rumble, Telegram, Threads). Tracks Junkipedia sync state via `junkipedia_channel_id`, `junkipedia_enqueued_at`, `junkipedia_id_collected_at`, `junkipedia_last_error`.
- **User** - System users with roles (admin, researcher)
- **Assignment** - Work assignments for data gathering/validation

### Temporal Query Scopes

Models support temporal queries for historical analysis:

```ruby
# Officeholder scopes
Officeholder.current                    # Currently in office
Officeholder.former                     # No longer in office
Officeholder.as_of(date)                # In office on specific date
Officeholder.elected_in(year)           # Elected in specific year

# Person scopes
Person.current_officeholders            # People currently holding office
Person.officeholders_as_of(date)        # People holding office on specific date
Person.candidates_in_year(year)         # People who ran in specific year
Person.election_winners_in_year(year)   # People who won in specific year

# Person instance methods
person.current_officeholder?            # Is currently in office?
person.officeholder_on?(date)           # Was in office on date?
person.candidate_in_year?(year)         # Ran for office in year?
person.current_offices                  # Offices currently held
```

### Three-Tier Workflow

The application has three distinct user workspaces:

1. **Admin** (`/admin`) - Full CRUD on all models, user management, bulk assignment creation
2. **Researcher** (`/researcher`) - Data entry workspace for social media accounts, view and complete assignments
3. **Verification** (`/verification`) - Review and verify researcher-entered data

### Data Staging Pattern

Data imports use a staging table pattern:
1. Export CSVs from external sources (Airtable, GovProj)
2. Load into `temp_*` tables (`temp_people`, `temp_accounts`, `temp_govproj`)
3. Analyze and validate staged data using rake tasks
4. Import into production tables with `find_or_create_by!` for idempotency
5. Track provenance via `airtable_id` fields

This allows safe analysis of data quality and duplication before committing to production tables.

### Authentication System

Uses Devise with multiple authentication strategies:
- Email/password (traditional)
- Google OAuth2 (`omniauth-google-oauth2`)
- Microsoft Entra ID (`omniauth-entra-id`)
- Invitation-only registration (`devise_invitable`)

User roles control access:
- `admin?` - Full system access
- `researcher?` - Data entry and assignment completion

### Assignment Workflow

Researchers assign data gathering tasks to users via the Assignment model:
- Admin creates assignments in bulk (e.g., "Find social media for 50 people")
- Researcher views assigned work, enters data, marks assignments complete
- Status tracking: `pending`, `in_progress`, `completed`

## Key Services

- **AirtableService** (`app/services/airtable_service.rb`) - HTTP client for Airtable API integration
- **CandidateImportService** (`app/services/candidate_import_service.rb`) - Orchestrates candidate data import
- **JunkipediaService** (`app/services/junkipedia_service.rb`) - Junkipedia API v2 client (channels, search, lists). Handles rate-limit headers and exposes `handle_from(account)` to extract a Junkipedia-style handle from a SocialMediaAccount URL.

## Background Jobs

- `EnqueueJunkipediaChannelJob` — posts a URL to Junkipedia's `/channels` endpoint when a SocialMediaAccount is verified
- `ResolveJunkipediaChannelIdJob` — searches Junkipedia for a channel id after enqueue
- `AddChannelToDefaultListJob` — adds a resolved channel to `JUNKIPEDIA_DEFAULT_LIST_ID`
- Production queue adapter: `:async` (in-memory thread pool, no worker dyno). Jobs lost on dyno restart — admin Junkipedia dashboard exposes re-queue buttons for recovery.

## Important Files

- **PROJECT_SPECIFICATION.md** - Comprehensive feature checklist, domain model documentation, data analysis results
- **DEVELOPMENT_RULES.md** - Code style preferences, documentation requirements
- **README.md** - Setup instructions, deployment guide

## Election Editor

**Spreadsheet-style bulk candidate entry, functional end-to-end — the app's first React feature.** `/admin/elections/:id/editor` (chromeless layout, linked from the admin elections list/show pages).

One flat grid per election: rows are candidates; columns are contest (grouped dropdown), first/middle/last/suffix name fields (typeahead on first/last links existing People and prefills their socials), party, incumbent, outcome, gender, race, campaign website, and one cell per social platform (accepts `handle`, `@handle`, or full URL — normalized both ways). Dirty tracking, per-row save status/errors, Enter/⌘S keyboard flow, contest filter, inline new-contest dialog (find-or-creates ballot + contest), and an **Import CSV** dialog (upload → column mapping → validation/matching preview → stages rows into the grid as unsaved rows; creates missing ballots/contests on confirm; handles both the cleaned-batch CSV format and raw state workbook exports).

Key code:
- `app/controllers/admin/election_editor_controller.rb` — page + save/people/offices/contests endpoints (all data embedded on load, no fetch)
- `app/services/election_editor_save.rb` — per-row transactional upsert (Person → Candidate → SocialMediaAccounts). Editor-created accounts are `Campaign`/`entered`/**unverified** (never triggers Junkipedia auto-enqueue). Verified accounts: same-handle resubmissions (x.com vs twitter.com, `@`/case/URL-form differences) are no-ops that never unverify; only a genuine handle change flags `revised`+unverified with a warning; clearing is refused.
- `app/services/election_editor_csv_import.rb` — read-only CSV preview (parse/map/validate, office→contest matching, person matching); `app/services/social_handles.rb` — shared handle/URL normalization. See `docs/ELECTION_EDITOR.md` § CSV import.
- `app/javascript/react/` — React app (entry `election_editor.tsx`, grid in `editor/`, shadcn-pattern primitives in `components/ui/`)
- `app/views/admin/election_editor/show.html.erb`, `app/views/layouts/election_editor.html.erb`

See `docs/ELECTION_EDITOR.md` for save semantics, endpoint contracts, and known limitations.

## Frontend Build (React + esbuild)

The app is importmap + Stimulus for classic pages, **plus** an esbuild-bundled React island for complex UI (currently the election editor):

- React/TSX source: `app/javascript/react/` (`@/` alias via `tsconfig.json`); shadcn-pattern components in `components/ui/`
- Build: `yarn build` (minified) → `app/assets/builds/election_editor.js` (Sprockets serves it; the layout uses `javascript_include_tag "election_editor"`). `bin/dev` runs `yarn build:watch` via Procfile.dev.
- **The built bundle is committed to git** — Heroku deploys need no Node build step. After changing React code: `yarn build`, commit the bundle with the source.
- Tailwind v4 auto-scans `.tsx` files — no config needed for new classes.
- New React features: add an entrypoint in `app/javascript/react/`, extend the esbuild script in `package.json` to include it, mount from a view with an embedded-JSON payload (see the election editor pattern).

## Change Tracking (PaperTrail)

All core models are versioned, and **every change is attributed** via `versions.whodunnit`: user id for web edits (`set_paper_trail_whodunnit` in ApplicationController), `"job:ClassName"` for background jobs (ApplicationJob `around_perform`), `"rake:task"`/`"console:user"`/`"cli:…"` for everything else (`config/initializers/paper_trail.rb`). Versions before June 2026 are unattributed (`nil`). The accounts API exposes `last_change` (at/event/by, with user ids resolved to names).

## Internal API (`/api/*`)

Session-authenticated JSON API (reads: any signed-in user; mutations: admin + `X-CSRF-Token`). All endpoints documented in `docs/API_PLAN.md` and verified by `bin/rails runner lib/scripts/api_verify.rb` (52 checks, self-cleaning) — **run it after changing API controllers**. No unauthenticated mode (local DB holds production data); the public read API at `/api/v1` uses token auth (see below).

The **public read API** lives at `/api/v1/*` (Bearer-token auth via ApiToken, admin-managed; see `docs/PUBLIC_API.md`); verify with `bin/rails runner lib/scripts/public_api_verify.rb`.

## Application Documentation

Comprehensive documentation covering schema, architecture, features, and APIs. **Always update these docs when you make changes to keep them in sync with the codebase.**

| File | Purpose |
|------|---------|
| **docs/SCHEMA.md** | Complete database schema with all models, attributes, associations, validations, and scopes |
| **docs/ARCHITECTURE.md** | Controllers, views, services, background jobs, request flows, and design patterns |
| **docs/FEATURES.md** | User-facing features organized by role (public, researcher, verifier, admin) and workflow |
| **docs/API_PLAN.md** | Planned internal/public APIs with request/response examples and status |
| **docs/VERIFICATION_WORKFLOW.md** | The data collection → validation → secondary verification system: state machine, completion gates, four-eyes rule, design record |
| **docs/ELECTION_EDITOR.md** | Spreadsheet bulk candidate entry: architecture, endpoints, save semantics, next-pass TODOs |

## Tests

RSpec + FactoryBot (`spec/`). Run with `bundle exec rspec` (test DB: `candidata_test`, create via `RAILS_ENV=test bin/rails db:create db:schema:load`). The verification workflow (four-eyes rule, completion gates, secondary verification) is pinned by request/model specs — **keep these green** and add specs when changing workflow behavior. The `/api` layer has a separate integration check: `bin/rails runner lib/scripts/api_verify.rb` (runs against the dev DB).

### Documentation Maintenance Practice

When implementing any changes—new models, controller actions, features, or APIs—update the relevant doc files:

**When adding/changing a model:**
- Update `docs/SCHEMA.md` with attributes, associations, validations, scopes, and instance methods

**When adding/changing controllers or views:**
- Update `docs/ARCHITECTURE.md` with new actions, purpose, and view mappings
- Update `docs/FEATURES.md` if user-facing functionality changes

**When building new features:**
- Describe the workflow in `docs/FEATURES.md` (user perspective)
- Document the technical implementation in `docs/ARCHITECTURE.md`

**When building APIs:**
- Document endpoints, request/response format, and parameters in `docs/API_PLAN.md`

**When user-facing functionality changes, ALSO update the in-app user guides:**
- `app/views/admin/guide/show.html.erb` — admin guide (`/admin/guide`): assignments, record management, election editor, change history. Keep the table of contents + section numbering in sync.
- `app/views/researcher/guide/show.html.erb` + `app/views/shared/_researcher_guide_content.html.erb` — researcher workflow guide
- `app/views/shared/_verification_guide.html.erb` — verification workflow guide
- `app/views/help/*.html.erb` — public help pages (data model, sources, coverage)

**Before committing feature work:**
1. Implement the feature in code
2. Update relevant repo doc file(s) AND the in-app guide(s) if the change is user-facing
3. Commit code, repo docs, and guide updates together

This keeps the docs authoritative and prevents drift between implementation, repo documentation, and what users are told in the app.

## Office Categorization System

Offices use a structured hierarchy:
- **Level**: `federal`, `state`, `local` (mapped from OCD-ID administrativeArea levels)
- **Branch**: `executive`, `legislative`, `judicial`
- **Role**: 7 standard roles (e.g., `legislatorUpperBody`, `governmentOfficer`, `highestCourtJudge`)
- **Category**: 23+ specific categories (e.g., "State Representative", "Governor", "U.S. Senator")
- **Body Name**: Legislative body (e.g., "U.S. House of Representatives", "TX State House")
- **OCD-ID**: Open Civic Data ID for jurisdictions and districts

## File Storage

Active Storage with environment-specific backends:
- **Development**: Local storage
- **Production**: S3 via Bucketeer add-on (Heroku)
- **Validations**: Content type and 5MB size limit on avatars

## Email Previews

In development, use `letter_opener` to preview emails in browser instead of sending them. Check `tmp/letter_opener/` after triggering email actions.

## Notable Data

- **58 Political Parties** - Including major parties plus regional (e.g., Puerto Rico: PNP, PPD, PIP, MVC, Proyecto Dignidad)
- **56 States/Territories** - All 50 states + DC + 5 territories (PR, GU, VI, AS, MP) with FIPS codes
- **17,921 People** - From Airtable federal/state bases
- **42,780 Officeholders** - From GovProj current officials dataset
- **66,036 Social Media Accounts** - Tracked across 10 platforms

## Standard Operating Procedures

Recurring multi-step workflows. Follow the linked SOP doc for full detail.

| SOP | Trigger | Steps (high level) | Reference |
|-----|---------|--------------------|-----------|
| **2026 candidate CSV import** | New state data arrives in the Drive folder | Pull from Drive → clean → test locally → deploy → run on prod | `docs/CANDIDATE_CSV_IMPORT.md` |
| **Junkipedia bulk backfill** | Many unsynced verified handles | `junkipedia:clear_errors` then `junkipedia:match_pending` (throttled) | `docs/JUNKIPEDIA_INTEGRATION.md` |
| **Production DB refresh** | Need fresh prod data locally to develop against | Backup local → drop → `heroku pg:pull` | section below |

### Production DB refresh (local dev)

Always do this before testing import-style work against current production state:

```bash
mkdir -p tmp/backups
PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH" pg_dump candidata_development -Fc \
  -f "tmp/backups/candidata_development_$(date +%Y%m%d_%H%M%S).dump"
dropdb candidata_development
PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH" heroku pg:pull DATABASE_URL candidata_development --app candidata
```

- pg:pull errors about `transaction_timeout` and `_heroku` schema are normal — data imports fine
- Local pg14 vs Heroku pg17 — must use `PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH"` prefix

### Production safety

Always run `heroku pg:backups:capture --app candidata` before any `heroku run` command that writes to the database. This is a strict requirement — never skip.

## 2026 Candidate CSV Import Workflow

**Source**: Google Drive folder [Primaries2026](https://drive.google.com/drive/folders/1aNZY0rWHRpwwAWMLsXtX0MOK-xBax_12) (owner: mm11506@nyu.edu). Each state has an Excel workbook there. Export to CSV before processing.

The import pipeline is:

1. **Export from Drive**: download each state's Excel as CSV into `data/2026_states/<batch-folder>/` (e.g., `april15-states/`, `june-states/`). One file per state.
2. **Cleaning script** (`lib/scripts/clean_<batch>_states_2026.rb`) standardizes parties, names, URLs, race, gender into `data/2026_states/cleaned/{STATE}_candidates_cleaned.csv`. Copy an existing cleaner from `lib/scripts/clean_*_states_2026.rb` and update `STATE_MAP`/party mappings for new variations.
3. **Rake task** (`lib/tasks/import_<batch>_states_2026.rake`) runs the `EnhancedCandidate2026Importer` on cleaned CSVs. Copy from an existing batch and adjust state filter.
4. **Test locally** against fresh production data before deploying (see "Production DB refresh" above).
5. **Deploy and run on production** (see commands below).

After import, the `SocialMediaAccount` after_commit hook will **auto-enqueue verified handles** to Junkipedia — no manual push needed for new data. Use the admin dashboard at `/admin/junkipedia` to monitor.

```bash
# Local testing workflow (run after a fresh prod pull)
bin/rails import:clean_candidates_2026_<batch>
bin/rails import:candidates_2026_<batch>

# Production deployment
git push origin main && git push heroku main
heroku pg:backups:capture --app candidata     # ALWAYS backup first
heroku run bin/rails import:candidates_2026_<batch> --app candidata
```

Key gotchas:
- New parties must be added to `PARTIES` in both `app/models/ballot.rb` and `app/models/contest.rb`
- Source spreadsheets vary in conventions ("Withdrew" vs "Withdrawn", "Democrat" vs "Democratic", "99"/"see notes"/"N/A" as placeholders, lowercase race values). The cleaner is the place to absorb new variants.
- See `docs/CANDIDATE_CSV_IMPORT.md` for full documentation including batch history

## Junkipedia Auto-Sync

When a `SocialMediaAccount` transitions to `verified = true` (via `verify!` or any path that flips the column), an `after_commit` hook enqueues `EnqueueJunkipediaChannelJob`, which `POST /channels` to Junkipedia. A separate `ResolveJunkipediaChannelIdJob` calls `GET /channels/search` (using the extracted handle + platform) to retrieve the channel id; the resolved id is stored on the account and the channel is added to the default list (`JUNKIPEDIA_DEFAULT_LIST_ID=10929`, "Candidata Imports").

Key facts:
- **Rate limit**: Junkipedia raised our cap to **1,000,000 / hour** in June 2026 (was 5,000/hour Pro tier — throttled rake defaults still assume the old cap). Response headers expose `x-ratelimit-remaining` and `x-ratelimit-reset` — `JunkipediaService` caches these and `RateLimitError#seconds_until_reset` returns precise back-off durations.
- **Channel creation**: `POST /channels` requires **`channel_url`** (not `url`) and can return HTTP 200 with a body-level `errors` array (e.g. org lacks channel-creation permission / daily limit reached — currently the case as of June 2026). See "Channel Creation Gotchas" in `docs/JUNKIPEDIA_INTEGRATION.md`.
- **Search shape**: `/channels/search` accepts `handle` (+ optional `platform`). It does **NOT** accept `url`. Use `JunkipediaService.handle_from(account)` to extract a usable handle.
- **For bulk backfills** (more than a few hundred records), use the throttled rake task `junkipedia:match_pending` — not the dashboard buttons. The task watches rate-limit headers and pauses when within the safety buffer.

```bash
# Throttled bulk match: searches for each pending account, marks synced if found
heroku run --app candidata bin/rails junkipedia:match_pending
# Optional: RATE=1.2 STATE=IL LIMIT=500 INCLUDE_ERRORED=0

# Clear stale errors before retrying
heroku run --app candidata bin/rails junkipedia:clear_errors

# Admin dashboard for status + per-row re-queue
# https://candidata.space/admin/junkipedia
```

See `docs/JUNKIPEDIA_INTEGRATION.md` for full architecture and history.

## Environment Variables

Required for development:
```
GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET   # OAuth
AIRTABLE_API_KEY, AIRTABLE_BASE_ID       # Data import
DEVISE_MAILER_FROM                        # Email sender address
JUNKIPEDIA_API_TOKEN                      # Junkipedia API v2 (auto-sync no-op without it)
```

Optional:
```
JUNKIPEDIA_DEFAULT_LIST_ID               # Junkipedia list to add resolved channels to (production: 10929)
AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, AWS_BUCKET  # S3 storage
SMTP_ADDRESS, SMTP_PORT, SMTP_USERNAME, SMTP_PASSWORD            # Email delivery
```
