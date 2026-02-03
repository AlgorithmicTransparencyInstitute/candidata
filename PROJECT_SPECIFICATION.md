# Candidata - Project Specification

A comprehensive database system for managing elected officials, candidates, elections, and social media presence for social listening research.

---

## Overview

Candidata is a Ruby on Rails application that serves as:

1. **Political Data Repository** - Database of elected officials and candidates with demographic/biographical metadata
2. **Election Records System** - Tracks offices, ballots, contests, election outcomes, and officeholder history
3. **Social Listening Platform** - Manages social media accounts linked to political figures for research
4. **Research Workflow Tool** - Enables researchers to assign data collection and validation tasks to research assistants

---

## Domain Model

### Core Entities (Implemented)

| Model | Description | Status |
|-------|-------------|--------|
| **State** | US states, territories, DC (name, abbreviation, FIPS, type) | ✅ Complete |
| **Party** | Political parties (name, abbreviation, ideology) | ✅ Complete |
| **PersonParty** | Many-to-many join for Person↔Party with is_primary flag | ✅ Complete |
| **Person** | Individuals with extended fields (uuid, gender, websites, etc.) | ✅ Complete |
| **District** | Electoral districts (state, level, boundaries) | ✅ Complete |
| **Office** | Political offices with category, body_name, role, OCD-IDs | ✅ Complete |
| **Ballot** | Election ballots (state, date, type) | ✅ Complete |
| **Contest** | Individual races on a ballot | ✅ Complete |
| **Candidate** | Person running in a Contest (outcome, tally) | ✅ Complete |
| **Officeholder** | Person holding an Office (with term dates) | ✅ Complete |
| **SocialMediaAccount** | Social handles linked to Person (10 platforms supported) | ✅ Complete |

### Entities To Build

| Model | Description | Status |
|-------|-------------|--------|
| **User** | System users (researchers, research assistants) | ✅ Complete |
| **Role** | User roles (admin, researcher, researcher_assistant) | ✅ Complete (in User model) |
| **Task** | Work assignments (data gathering, validation) | ⬜ Not started |
| **DataSource** | Track provenance of imported/entered data | ⬜ Not started |

---

## Feature Areas

### 1. Political Data Management
- [x] Core models for people, offices, elections
- [x] Airtable import service for 2024 election data
- [x] Extended Person metadata fields (uuid, gender, race, websites, airtable_id)
- [x] Extended Office fields (category, body_name, role, OCD-IDs)
- [x] State reference table (50 states + DC + 5 territories)
- [x] Party many-to-many with primary party support (58 parties extracted)
- [ ] Historical data import from existing database
- [ ] Reference metadata import

### 2. Social Media Tracking
- [x] SocialMediaAccount model (platform, handle, URL, verification status)
- [x] Link accounts to Person records
- [x] Platform types: Facebook, Twitter, Instagram, YouTube, TikTok, TruthSocial, Gettr, Rumble, Telegram, Threads
- [x] Channel types: Campaign, Official Office, Personal
- [ ] Social listening integration (TBD)

### 3. User & Authentication System
- [x] Basic session-based login (stub) - replaced by Devise
- [x] Real user authentication (Devise + OmniAuth Google)
- [x] User model with roles (admin, researcher, researcher_assistant)
- [x] Role helper methods (admin?, researcher?, can_assign_tasks?, etc.)
- [ ] Role-based access control (restrict admin features)
- [ ] Airtable users table integration (optional)

### 4. Research Workflow & Task Management
- [ ] Task model for work assignments
- [ ] Task types: Data Gathering, Data Validation/Verification
- [ ] Assignment queue per user
- [ ] Task status tracking (pending, in_progress, completed, reviewed)
- [ ] Research assistant dashboard (see assigned work)
- [ ] Researcher dashboard (assign work, review completions)

### 5. Admin Interface
- [x] Dashboard with statistics
- [x] Parties CRUD
- [ ] People CRUD (controller exists, needs completion)
- [ ] Districts CRUD
- [ ] Offices CRUD
- [ ] Ballots CRUD
- [ ] Contests CRUD
- [ ] Candidates CRUD
- [ ] Officeholders CRUD
- [ ] SocialMediaAccounts CRUD

### 6. Data Import & Provenance
- [x] Airtable API service
- [x] 2024 candidate import service
- [ ] Historical database import pipeline
- [ ] Track data source/provenance on records
- [ ] Audit trail for edits

---

## Task List

### Phase 1: Foundation
| Task | Status |
|------|--------|
| Review existing codebase | ✅ Complete |
| Create DEVELOPMENT_RULES.md | ✅ Complete |
| Create PROJECT_SPECIFICATION.md | ✅ Complete |
| Define full domain model | ⬜ In discussion |

### Phase 2: Social Media & Extended Data
| Task | Status |
|------|--------|
| Create SocialMediaAccount model | ✅ Complete |
| Add social media admin CRUD | ⬜ Not started |
| Extend Person model with additional metadata | ✅ Complete |
| Analyze Airtable CSV data structure | ✅ Complete |
| Create temp tables for data staging | ✅ Complete |
| Extract and seed Party records (58 parties) | ✅ Complete |
| Create State reference table (56 states/territories) | ✅ Complete |
| Add temporal query scopes to models | ✅ Complete |

### Phase 3: User System
| Task | Status |
|------|--------|
| Implement User model with authentication | ✅ Complete |
| Add Devise with email/password login | ✅ Complete |
| Add Google OAuth2 login | ✅ Complete |
| Add role system (admin, researcher, RA) | ✅ Complete |
| Role-based access control | ⬜ Not started |

### Phase 4: Task Management
| Task | Status |
|------|--------|
| Create Task model | ⬜ Not started |
| Task assignment interface | ⬜ Not started |
| RA work queue dashboard | ⬜ Not started |
| Task review workflow | ⬜ Not started |

### Phase 5: Data Import
| Task | Status |
|------|--------|
| Historical database schema analysis | ⬜ Not started |
| Import pipeline for historical data | ⬜ Not started |
| Reference metadata import | ⬜ Not started |

### Phase 6: Complete Admin CRUD
| Task | Status |
|------|--------|
| People controller/views | ⬜ Not started |
| Districts controller/views | ⬜ Not started |
| Offices controller/views | ⬜ Not started |
| Ballots controller/views | ⬜ Not started |
| Contests controller/views | ⬜ Not started |
| Candidates controller/views | ⬜ Not started |
| Officeholders controller/views | ⬜ Not started |

---

## Airtable Data Analysis (2026-02-02)

### Data Sources

CSV exports from two Airtable bases:
- **Federal Base** (`apphqUuOFKhgrrYLF`): Federal politicians
- **State Base**: State-level politicians

| File | Records |
|------|---------|
| `Federal_People.csv` | 2,610 |
| `Federal_Accounts.csv` | 18,576 |
| `State_People.csv` | 15,311 |
| `State_Accounts.csv` | 47,460 |

**Total**: 17,921 people records, 66,036 social media accounts

### Temporary Tables for Analysis

Created `temp_people` and `temp_accounts` tables to stage and analyze data before import:

```ruby
# Rake tasks created:
rails import_csv:all          # Import all CSVs to temp tables
rails import_csv:analyze      # Analyze grouped data
rails extract:parties         # List unique parties
rails extract:create_parties  # Create Party records
rails extract:states          # Seed State records
rails extract:analyze_offices # Analyze office categories
```

### Party Data Findings

**76 unique party strings** in source data, many containing fusion tickets (e.g., "Republican Party, Conservative Party"). Split into **58 individual parties**.

| Ideology | Count |
|----------|-------|
| Other/Unknown | 24 |
| Centrist/Independent | 13 |
| Left/Center-left | 11 |
| Right/Center-right | 6 |
| Libertarian | 1 |
| PR-specific | 3 |

**Notable parties**: Democratic, Republican, Libertarian, Green, Constitution, Working Families, plus Puerto Rico parties (PNP, PPD, PIP, MVC, Proyecto Dignidad).

### Office Data Findings

**23 Office Categories:**

| Category | Count | Role | Branch |
|----------|-------|------|--------|
| State Representative | 10,636 | legislatorLowerBody | legislative |
| State Senator | 3,515 | legislatorUpperBody | legislative |
| U.S. Representative | 2,175 | legislatorLowerBody | legislative |
| State Supreme Court Justice | 366 | highestCourtJudge | judicial |
| U.S. Senator | 359 | legislatorUpperBody | legislative |
| Governor | 180 | headOfGovernment | executive |
| Lieutenant Governor | 95 | deputyHeadOfGovernment | executive |
| Attorney General | 89 | governmentOfficer | executive |
| Secretary of State | 74 | governmentOfficer | executive |
| State Treasurer | 70 | governmentOfficer | executive |
| U.S. President | 54 | headOfGovernment | executive |
| State Auditor | 52 | governmentOfficer | executive |
| + 11 more categories | | | |

**7 Roles mapped to 3 Branches:**

| Role | Branch | Count |
|------|--------|-------|
| legislatorLowerBody | legislative | 12,814 |
| legislatorUpperBody | legislative | 3,877 |
| governmentOfficer | executive | 387 |
| highestCourtJudge | judicial | 366 |
| headOfGovernment | executive | 232 |
| schoolBoard | executive | 122 |
| deputyHeadOfGovernment | executive | 95 |

**Level Mapping (Airtable → Candidata):**

| Airtable Level | Candidata Level | Count |
|----------------|-----------------|-------|
| country | federal | 2,593 |
| administrativeArea1 | state | 15,290 |
| administrativeArea2 | local | 11 |
| locality | local | 2 |

**172 unique Body Names** (e.g., "U.S. House of Representatives", "TX State House", "NY State Assembly")

### Election Status Data

| Status Flag | Count |
|-------------|-------|
| 2024 Candidates | 14,359 |
| Incumbents | 4,721 |
| 2024 Office Holders | 1,165 |

**Key insight**: Many records are candidates who did not win, so they have Candidate records but no Officeholder records. The system must track both statuses independently.

---

## Schema Changes (2026-02-02)

### New Tables

| Table | Purpose |
|-------|---------|
| `states` | Reference table: 50 states + DC + 5 territories with FIPS codes |
| `person_parties` | Join table for Person↔Party many-to-many with `is_primary` flag |
| `social_media_accounts` | Social handles linked to Person (10 platforms) |
| `temp_people` | Staging table for Airtable People CSV import |
| `temp_accounts` | Staging table for Airtable Accounts CSV import |

### Extended Fields

**Person** (new fields):
- `person_uuid` - Unique identifier from source
- `middle_name`, `suffix` - Name components
- `gender`, `race` - Demographics
- `photo_url` - Reference to photo
- `website_official`, `website_campaign`, `website_personal` - URLs
- `airtable_id` - Source record ID

**Office** (new fields):
- `office_category` - One of 23 categories (e.g., "State Representative")
- `body_name` - Legislative body name (e.g., "TX State House")
- `seat` - District/seat identifier
- `role` - One of 7 roles (e.g., "legislatorLowerBody")
- `jurisdiction`, `jurisdiction_ocdid` - Jurisdiction info
- `ocdid` - Open Civic Data ID for electoral district
- `airtable_id` - Source record ID

**Ballot** (new fields):
- `year` - Election year (auto-set from date)
- `name` - Optional display name

**Candidate** (new fields):
- `party_at_time` - Party affiliation when running
- `incumbent` - Was incumbent when running
- `airtable_id` - Source record ID
- Outcome now allows: `won`, `lost`, `pending`, `withdrawn`, `unknown`

**Officeholder** (new fields):
- `elected_year` - Year elected to office
- `appointed` - True if appointed (not elected)
- `airtable_id` - Source record ID

### New Scopes for Temporal Queries

**Officeholder:**
```ruby
Officeholder.current           # Currently in office
Officeholder.former            # No longer in office
Officeholder.as_of(date)       # In office on specific date
Officeholder.elected_in(year)  # Elected in specific year
```

**Person:**
```ruby
Person.current_officeholders           # People currently holding office
Person.former_officeholders            # People who held office but don't now
Person.officeholders_as_of(date)       # People holding office on specific date
Person.candidates_in_year(year)        # People who ran in specific year
Person.election_winners_in_year(year)  # People who won in specific year
Person.election_losers_in_year(year)   # People who lost in specific year
```

**Person instance methods:**
```ruby
person.current_officeholder?           # Is currently in office?
person.officeholder_on?(date)          # Was in office on date?
person.candidate_in_year?(year)        # Ran for office in year?
person.won_election_in_year?(year)     # Won election in year?
person.current_offices                 # Offices currently held
person.offices_held_on(date)           # Offices held on specific date
```

---

## Open Questions

1. ~~What social media platforms need to be tracked?~~ **ANSWERED**: Facebook, Twitter, Instagram, YouTube, TikTok, TruthSocial, Gettr, Rumble, Telegram, Threads
2. ~~What additional metadata fields are needed on Person?~~ **ANSWERED**: uuid, middle_name, suffix, gender, race, photo_url, websites, airtable_id
3. What is the schema of the existing historical database?
4. What specific task types exist for RAs? (examples of work items)
5. Should RAs have read-only access to all data, or only their assignments?
6. **NEW**: How should we handle encoding issues with Puerto Rico party names (UTF-8 artifacts)?
7. **NEW**: Should we create separate OfficeCategory or LegislativeBody reference tables?

---

## Technical Decisions

- **Framework**: Ruby on Rails 7.2
- **Database**: PostgreSQL
- **Styling**: Tailwind CSS
- **JavaScript**: Hotwire (Turbo + Stimulus)
- **External APIs**: Airtable for data sync
- **Authentication**: Devise + OmniAuth (Google OAuth2)
- **Data Import Strategy**: CSV export → temp tables → analyze → seed production tables

---

## Files Created/Modified (2026-02-02)

### Migrations
- `db/migrate/20260203022404_create_temp_airtable_tables.rb`
- `db/migrate/20260203024521_create_person_parties.rb`
- `db/migrate/20260203030008_create_states.rb`
- `db/migrate/20260203030013_add_fields_to_people.rb`
- `db/migrate/20260203030017_add_fields_to_offices.rb`
- `db/migrate/20260203030021_create_social_media_accounts.rb`
- `db/migrate/20260203031231_add_fields_to_ballots.rb`
- `db/migrate/20260203031233_add_fields_to_candidates.rb`
- `db/migrate/20260203031237_add_fields_to_officeholders.rb`

### Models
- `app/models/state.rb` (new)
- `app/models/person_party.rb` (new)
- `app/models/social_media_account.rb` (new)
- `app/models/temp_person.rb` (new)
- `app/models/temp_account.rb` (new)
- `app/models/person.rb` (updated)
- `app/models/party.rb` (updated)
- `app/models/office.rb` (updated)
- `app/models/ballot.rb` (updated)
- `app/models/contest.rb` (updated)
- `app/models/candidate.rb` (updated)
- `app/models/officeholder.rb` (updated)

### Rake Tasks
- `lib/tasks/import_csv.rake` - Import CSVs to temp tables
- `lib/tasks/extract_parties.rake` - Extract and create Party records
- `lib/tasks/extract_states.rake` - Seed State records
- `lib/tasks/extract_offices.rake` - Analyze office data

---

*Last updated: 2026-02-02*
