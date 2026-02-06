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
- **SocialMediaAccount** - Social handles linked to Person (10 platforms: Facebook, Twitter, Instagram, YouTube, TikTok, TruthSocial, Gettr, Rumble, Telegram, Threads)
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

## Environment Variables

Required for development:
```
GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET   # OAuth
AIRTABLE_API_KEY, AIRTABLE_BASE_ID       # Data import
DEVISE_MAILER_FROM                        # Email sender address
```

Optional for production:
```
AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, AWS_BUCKET  # S3 storage
SMTP_ADDRESS, SMTP_PORT, SMTP_USERNAME, SMTP_PASSWORD            # Email delivery
```
