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
- **Candidate** - Person running in a Contest (outcome, tally, incumbent status, party_at_time)
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
- **Rate limit**: Junkipedia caps API calls at **5,000 / hour** (Pro tier). Response headers expose `x-ratelimit-remaining` and `x-ratelimit-reset` — `JunkipediaService` caches these and `RateLimitError#seconds_until_reset` returns precise back-off durations.
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
