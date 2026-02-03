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
| **Party** | Political parties (name, abbreviation, ideology) | ✅ Complete |
| **Person** | Individuals - candidates and officeholders | ✅ Complete |
| **District** | Electoral districts (state, level, boundaries) | ✅ Complete |
| **Office** | Political offices (title, level, branch) | ✅ Complete |
| **Ballot** | Election ballots (state, date, type) | ✅ Complete |
| **Contest** | Individual races on a ballot | ✅ Complete |
| **Candidate** | Person running in a Contest (outcome, tally) | ✅ Complete |
| **Officeholder** | Person holding an Office (with term dates) | ✅ Complete |

### Entities To Build

| Model | Description | Status |
|-------|-------------|--------|
| **SocialMediaAccount** | Social handles linked to Person (platform, handle, URL, verified) | ⬜ Not started |
| **User** | System users (researchers, research assistants) | ✅ Complete |
| **Role** | User roles (admin, researcher, researcher_assistant) | ✅ Complete (in User model) |
| **Task** | Work assignments (data gathering, validation) | ⬜ Not started |
| **DataSource** | Track provenance of imported/entered data | ⬜ Not started |

---

## Feature Areas

### 1. Political Data Management
- [x] Core models for people, offices, elections
- [x] Airtable import service for 2024 election data
- [ ] Extended Person metadata fields
- [ ] Historical data import from existing database
- [ ] Reference metadata import

### 2. Social Media Tracking
- [ ] SocialMediaAccount model (platform, handle, URL, verification status)
- [ ] Link accounts to Person records
- [ ] Platform types: Twitter/X, Facebook, Instagram, YouTube, TikTok, etc.
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
| Create SocialMediaAccount model | ⬜ Not started |
| Add social media admin CRUD | ⬜ Not started |
| Extend Person model with additional metadata | ⬜ Not started |

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

## Open Questions

1. What social media platforms need to be tracked?
2. What additional metadata fields are needed on Person?
3. What is the schema of the existing historical database?
4. What specific task types exist for RAs? (examples of work items)
5. Should RAs have read-only access to all data, or only their assignments?

---

## Technical Decisions

- **Framework**: Ruby on Rails 7.2
- **Database**: PostgreSQL
- **Styling**: Tailwind CSS
- **JavaScript**: Hotwire (Turbo + Stimulus)
- **External APIs**: Airtable for data sync
- **Authentication**: Devise + OmniAuth (Google OAuth2)

---

*Last updated: 2026-02-02*
