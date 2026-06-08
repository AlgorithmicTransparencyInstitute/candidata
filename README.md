# Candidata

A Ruby on Rails 8 application that serves as a comprehensive database for managing US elected officials, candidates, elections, and their social media presence. Built for social-listening research: researchers gather and validate handles, then those handles are pushed to [Junkipedia](https://www.junkipedia.org) for ongoing post collection.

## Overview

Three workspaces in one app:
- **Admin** (`/admin`) — full CRUD over people, offices, elections, ballots, candidates, social accounts; bulk assignment creation; Junkipedia sync dashboard.
- **Researcher** (`/researcher`) — guided data entry on assigned social media accounts.
- **Verification** (`/verification`) — review and verify researcher-entered data; verification transitions auto-enqueue handles to Junkipedia.

Notable scale (as of the latest production pull):
- ~44k people, ~55k social media accounts across 11 platforms, 1.5k+ 2026 candidates, 42k+ officeholders.
- Junkipedia integration auto-syncs verified handles to a shared list ("Candidata Imports", list id 10929).

## Tech Stack

- **Ruby on Rails 8.0** (Ruby 3.3)
- **PostgreSQL 17** (Heroku Standard-0)
- **Tailwind CSS** — styling
- **Devise + omniauth** — Google OAuth2 + Microsoft Entra ID + invitation-only registration
- **PaperTrail** — audit log on `SocialMediaAccount`
- **HTTParty** — HTTP client for Airtable and Junkipedia
- **Active Storage + S3** (Bucketeer add-on) for uploads in production
- **Letter Opener** — email previews in development

## Setup

### Prerequisites
- Ruby 3.1+
- PostgreSQL
- Airtable account with API access

### Installation

```bash
# Install dependencies
bundle install

# Create database
bin/rails db:create db:migrate

# Start the development server
bin/dev
```

### Environment Variables

Required for development (typically lives in `.env`, gitignored):

```
# OAuth
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...

# Airtable (legacy import path)
AIRTABLE_API_KEY=...
AIRTABLE_BASE_ID=...

# Junkipedia auto-sync (no-op if not set)
JUNKIPEDIA_API_TOKEN=...
JUNKIPEDIA_DEFAULT_LIST_ID=10929  # "Candidata Imports" list on production

# Devise mailer
DEVISE_MAILER_FROM=...
```

### Data Import Pipelines

Several import pipelines feed Candidata. The main one in active use is the **2026 candidate CSV import** — see [`docs/CANDIDATE_CSV_IMPORT.md`](docs/CANDIDATE_CSV_IMPORT.md) for the full standard operating procedure.

Brief command reference:

```bash
# 2026 candidate CSV (per batch)
bin/rails import:clean_candidates_2026_<batch>
bin/rails import:candidates_2026_<batch>

# Legacy Airtable / GovProj imports
bin/rails import_csv:all       # Stage Airtable CSVs into temp_* tables
bin/rails govproj:download     # Pull GovProj officeholder data
bin/rails import:airtable      # Full Airtable import

# Junkipedia sync (bulk match against existing channels — rate-limit aware)
bin/rails junkipedia:match_pending
```

## Documentation

- [`CLAUDE.md`](CLAUDE.md) — repo guide and standard operating procedures (also read by Claude Code when working in this repo)
- [`docs/CANDIDATE_CSV_IMPORT.md`](docs/CANDIDATE_CSV_IMPORT.md) — 2026 candidate CSV import pipeline (cleaning, importing, batch history). Source spreadsheets live in the [Primaries2026 Google Drive folder](https://drive.google.com/drive/folders/1aNZY0rWHRpwwAWMLsXtX0MOK-xBax_12).
- [`docs/JUNKIPEDIA_INTEGRATION.md`](docs/JUNKIPEDIA_INTEGRATION.md) — auto-sync architecture, admin dashboard, rate limits, bulk backfill rake tasks.
- [`docs/2026_CANDIDATE_MANAGEMENT_PLAN.md`](docs/2026_CANDIDATE_MANAGEMENT_PLAN.md) — admin/researcher workflow design.
- [`docs/TEMP_DATA_ANALYSIS.md`](docs/TEMP_DATA_ANALYSIS.md) — staging-table analysis of 2024 election data.
- [`docs/RAILS_8_UPGRADE.md`](docs/RAILS_8_UPGRADE.md) — Rails 7.2 → 8.0 upgrade notes.
- [`docs/TESTING_PLAN.md`](docs/TESTING_PLAN.md) — test coverage strategy.

## Development

```bash
# Run the server with Tailwind CSS watching
bin/dev
```

## Project Structure

- `app/controllers/home_controller.rb` - Handles login and main page
- `app/controllers/sessions_controller.rb` - Session management (to be added)
- `app/services/airtable_service.rb` - Airtable API integration (to be added)

## Deployment

### Heroku

```bash
# Create Heroku app
heroku create candidata

# Add PostgreSQL
heroku addons:create heroku-postgresql:essential-0

# Set environment variables
heroku config:set AIRTABLE_API_KEY=your_api_key
heroku config:set AIRTABLE_BASE_ID=your_base_id

# Deploy
git push heroku main

# Run migrations
heroku run rails db:migrate
```

### Custom Domain

```bash
# Add domain to Heroku
heroku domains:add your-domain.com

# Configure DNS with your registrar:
# CNAME record pointing to your-app.herokuapp.com
```
