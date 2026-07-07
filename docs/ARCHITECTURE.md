# Candidata Application Architecture

Complete documentation of controllers, views, services, jobs, and workflows.

## Application Structure

```
app/
├── controllers/           # Request handlers
├── models/               # Business logic, associations, validations
├── views/                # Templates (Rails ERB)
├── services/             # External API clients & orchestration
├── jobs/                 # Background job workers
├── mailers/              # Email templates
└── assets/               # CSS, JS, images
config/
├── routes.rb             # URL routing
└── environments/         # Environment-specific settings
db/
├── schema.rb             # Current schema state
├── seeds.rb              # Initial data
└── migrate/              # Database migrations
docs/                     # Application documentation
lib/
├── importers/            # Data import scripts
└── scripts/              # Utility scripts
```

---

## Controllers & Actions

### Public Controllers

These controllers handle public browsing (no authentication required, or authenticated users only).

#### HomeController (`app/controllers/home_controller.rb`)
Entry point for the application.

| Action | Method | Purpose |
|--------|--------|---------|
| `index` | GET / | Public home page with election map & stats |
| `help` | GET /help | Help & documentation hub |
| `test_charts` | GET /test-charts | Dev-only test page for chart rendering |

**Views:**
- `home/index.html.erb` - Home page with embedded election map
- `home/help.html.erb` - Help hub
- `shared/_elections_map.html.erb` - Interactive US elections map

---

#### PeopleController (`app/controllers/people_controller.rb`)
Browse candidates and officeholders.

| Action | Method | Purpose |
|--------|--------|---------|
| `index` | GET /people | Search & filter people by state, party, role |
| `show` | GET /people/:id | Individual person profile with social accounts |
| `grouped_offices_for_filter` | GET /people/:id/grouped-offices | AJAX: offices grouped by state for person |

**Views:**
- `people/index.html.erb` - Search results with filters
- `people/show.html.erb` - Person profile page
- `shared/_filter_dropdowns.html.erb` - Filter UI

**Features:**
- Full-text search by name
- Filter by state, party, election year
- Display current & former offices
- Link to social media accounts

---

#### ElectionsController (`app/controllers/elections_controller.rb`)
Browse elections and election cycles.

| Action | Method | Purpose |
|--------|--------|---------|
| `index` | GET /elections | Election catalog (by year, state) |
| `show` | GET /elections/:id | Election details with ballots & contests |

**Views:**
- `elections/index.html.erb` - Elections listing
- `elections/show.html.erb` - Election detail page

---

#### ContestsController (`app/controllers/contests_controller.rb`)
Browse individual contests (races).

| Action | Method | Purpose |
|--------|--------|---------|
| `index` | GET /contests | Contest search & filter |
| `show` | GET /contests/:id | Contest details with candidates |

**Views:**
- `contests/index.html.erb` - Contests listing
- `contests/show.html.erb` - Contest detail page

---

#### BallotsController (`app/controllers/ballots_controller.rb`)
Browse ballots (election days by jurisdiction).

| Action | Method | Purpose |
|--------|--------|---------|
| `index` | GET /ballots | Ballots by state & date |
| `show` | GET /ballots/:id | Ballot details with contests |

**Views:**
- `ballots/index.html.erb` - Ballots listing
- `ballots/show.html.erb` - Ballot detail page

---

#### OfficesController (`app/controllers/offices_controller.rb`)
Browse political offices.

| Action | Method | Purpose |
|--------|--------|---------|
| `index` | GET /offices | Offices search (by level, branch, category) |
| `show` | GET /offices/:id | Office detail page |

**Views:**
- `offices/index.html.erb` - Offices listing
- `offices/show.html.erb` - Office detail page

---

#### DistrictsController (`app/controllers/districts_controller.rb`)
Browse electoral districts.

| Action | Method | Purpose |
|--------|--------|---------|
| `index` | GET /districts | Districts search (congressional, state, local) |
| `show` | GET /districts/:id | District detail page |

**Views:**
- `districts/index.html.erb` - Districts listing
- `districts/show.html.erb` - District detail page

---

#### PartiesController (`app/controllers/parties_controller.rb`)
Browse political parties.

| Action | Method | Purpose |
|--------|--------|---------|
| `index` | GET /parties | All parties listing |
| `show` | GET /parties/:id | Party detail page with affiliated people |

**Views:**
- `parties/index.html.erb` - Parties listing
- `parties/show.html.erb` - Party detail page

---

#### BodiesController (`app/controllers/bodies_controller.rb`)
Browse governmental bodies.

| Action | Method | Purpose |
|--------|--------|---------|
| `index` | GET /bodies | Bodies search (federal, state, local) |
| `show` | GET /bodies/:id | Body detail with current members |

**Views:**
- `bodies/index.html.erb` - Bodies listing
- `bodies/show.html.erb` - Body detail page

---

#### StatesController (`app/controllers/states_controller.rb`)
Browse states and territories.

| Action | Method | Purpose |
|--------|--------|---------|
| `index` | GET /states | States & territories listing |
| `show` | GET /states/:id | State detail page |

**Views:**
- `states/index.html.erb` - States listing
- `states/show.html.erb` - State detail page

---

#### AboutController (`app/controllers/about_controller.rb`)
Static pages.

| Action | Method | Purpose |
|--------|--------|---------|
| `index` | GET /about | About Candidata page |

---

#### HelpController (`app/controllers/help_controller.rb`)
Help documentation (embedded in views).

| Action | Method | Purpose |
|--------|--------|---------|
| `index` | GET /help | Help hub |
| `data_sources` | GET /help/data-sources | Data source documentation |
| `data_model` | GET /help/data-model | Explanation of domain model |
| `coverage` | GET /help/coverage | Data coverage by state |
| `researcher_guide` | GET /help/researcher-guide | Guide for researchers |

**Views:**
- `help/index.html.erb` - Help hub
- `help/data_sources.html.erb` - Data sources
- `help/data_model.html.erb` - Domain model explanation
- `help/coverage.html.erb` - Coverage information
- `help/researcher_guide.html.erb` - Researcher workflow guide

---

#### ProfilesController (`app/controllers/profiles_controller.rb`)
User profile management.

| Action | Method | Purpose |
|--------|--------|---------|
| `show` | GET /profile | Current user's profile |
| `edit` | GET /profile/edit | Edit profile form |
| `update` | PATCH /profile | Update profile |

**Views:**
- `profiles/show.html.erb` - Profile display
- `profiles/edit.html.erb` - Profile edit form

---

### Admin Controllers

Admin workspace (`/admin`) — full CRUD on all models.

#### admin/DashboardController
Admin overview and statistics.

| Action | Purpose |
|--------|---------|
| `index` | Admin dashboard with stats, pending tasks, recent activity |

---

#### admin/PeopleController
Manage candidates and officeholders.

| Action | Purpose |
|--------|---------|
| `index` | List all people (searchable, filterable) |
| `show` | Person detail with all relationships |
| `new` | New person form |
| `create` | Create person |
| `edit` | Edit person form |
| `update` | Update person |
| `destroy` | Delete person |
| `assign_researcher` | Assign researcher to person (AJAX) |
| `prepopulate_accounts` | Create social media account stubs |
| `bulk_assign` | Form to bulk-assign researchers |
| `create_bulk_assignments` | Create assignments in bulk |

**Features:**
- Full-text search
- Filter by state, party, status
- Bulk assignment creation
- Auto-prepopulate social media accounts
- View all associated contests, offices, accounts

---

#### admin/SocialMediaAccountsController
Manage social media accounts.

| Action | Purpose |
|--------|---------|
| `index` | List accounts (by platform, status, verification) |
| `show` | Account detail with history |
| `new` | Create account form |
| `create` | Create account |
| `edit` | Edit account form |
| `update` | Update account |
| `destroy` | Delete account |

**Features:**
- Filter by platform, verification status, research status
- View version history (PaperTrail)
- Manual verification controls
- Junkipedia sync status display

---

#### admin/ContestsController, BallotsController, ElectionsController, etc.
Standard CRUD for each entity.

| Controller | Purpose |
|------------|---------|
| `ContestsController` | Manage races |
| `BallotsController` | Manage election ballots |
| `ElectionsController` | Manage election cycles |
| `DistrictsController` | Manage electoral districts |
| `OfficesController` | Manage office positions |
| `PartiesController` | Manage parties |
| `BodiesController` | Manage governmental bodies |
| `CandidatesController` | Manage candidates |
| `OfficeholdersController` | Manage officeholders |

---

#### admin/AssignmentsController
Manage research assignments.

| Action | Purpose |
|--------|---------|
| `index` | List assignments (by status, type, researcher) |
| `show` | Assignment detail |
| `new` | New assignment form |
| `create` | Create assignment |
| `edit` | Edit assignment form |
| `update` | Update assignment |
| `destroy` | Delete assignment |
| `complete` | Mark assignment as complete (admin) |
| `mark_incomplete` | Reopen completed assignment |

**Features:**
- Create data_collection, data_validation, secondary_verification tasks
- Bulk creation from people list
- View researcher progress
- Monitor completion

---

#### admin/UsersController
User administration.

| Action | Purpose |
|--------|---------|
| `index` | List all users |
| `show` | User detail with activity |
| `new` | Create user form |
| `create` | Create user (and send invitation) |
| `edit` | Edit user form |
| `update` | Update user |
| `destroy` | Delete user |
| `resend_invitation` | Resend invitation email |
| `send_reset_password` | Reset user's password |
| `impersonate` | Login as another user (admin debugging) |
| `stop_impersonating` | End impersonation |
| `generate_invitation_link` | Create shareable invitation link |
| `send_assignment_reminder` | Remind user of pending tasks |
| `export_invitations` | Bulk export invitations |

**Features:**
- Create researchers and verifiers
- Manage invitations (email, resend, shareable links)
- Role assignment (admin, researcher, verifier)
- User status tracking
- Impersonation for debugging
- Bulk operations

---

#### admin/ApiTokensController
Manage bearer tokens for the public read API (`/api/v1`).

| Action | Purpose |
|--------|---------|
| `index` | List tokens (name, created by, last used, active/revoked) |
| `new` | New token form |
| `create` | Generate token (plaintext shown once, on the `created` view) |
| `revoke` | Revoke a token (consumers get 401s immediately) |

---

#### admin/JunkipediaController
Junkipedia integration dashboard.

| Action | Purpose |
|--------|---------|
| `index` | Junkipedia sync dashboard with stats |
| `enqueue` | Queue single account for Junkipedia sync |
| `resolve` | Resolve channel ID for single account |
| `enqueue_all` | Queue all pending accounts |
| `resolve_all` | Resolve all unresolved accounts |
| `preflight_resolve_all` | Test resolve operation before bulk run |
| `set_account` | Update account's Junkipedia channel ID (manual) |

**Features:**
- View Junkipedia sync status (pending, enqueued, synced, errored)
- Manual queue/resolve operations
- Bulk sync controls
- Error handling and retry
- Rate limit awareness

---

#### admin/VisitsController
Analytics dashboard.

| Action | Purpose |
|--------|---------|
| `index` | Page visits analytics via Ahoy |

---

#### admin/GuideController
Admin documentation.

| Action | Purpose |
|--------|---------|
| `show` | Embedded admin guide and best practices |

---

### Researcher Controllers

Researcher workspace (`/researcher`) — data entry and assignment tracking.

#### researcher/DashboardController
Researcher dashboard.

| Action | Purpose |
|--------|---------|
| `index` | Overview of assignments, pending work, progress stats |

**Shows:**
- Pending assignments by type
- Progress on current assignment
- Recent completions

---

#### researcher/AssignmentsController
Manage research assignments.

| Action | Purpose |
|--------|---------|
| `index` | List researcher's assignments |
| `show` | Assignment detail (person + their accounts) |
| `start` | Mark assignment as in_progress |
| `complete` | Mark assignment as completed |
| `reopen` | Revert from completed to pending |

**Workflow:**
1. Admin creates assignment
2. Researcher clicks "Start"
3. Researcher enters account data
4. Researcher clicks "Complete"
5. Verifier reviews
6. Admin may create secondary_verification task if needed

---

#### researcher/AccountsController
Data entry for social media accounts.

| Action | Purpose |
|--------|---------|
| `show` | Account data entry form |
| `update` | Update account URL/handle |
| `mark_entered` | Mark account as entered (found) |
| `mark_not_found` | Mark account as not found |
| `reset_status` | Reset status to not_started |
| `toggle_researcher_verified` | Researcher quick-verify flag |
| `update_notes` | Add researcher notes |

**Features:**
- Platform selection UI
- Channel type (Campaign/Official/Personal)
- Handle/URL input with validation
- Account status tracking
- Previous URL history (PaperTrail)

---

#### researcher/QueueController
Queue of accounts to research.

| Action | Purpose |
|--------|---------|
| `index` | List accounts needing research (paginated queue) |

---

#### researcher/GuideController
Researcher documentation.

| Action | Purpose |
|--------|---------|
| `show` | Embedded researcher workflow guide |

---

### Verification Controllers

Verification workspace (`/verification`) — review and approve entered data.

#### verification/DashboardController
Verification overview.

| Action | Purpose |
|--------|---------|
| `index` | Verification dashboard with pending tasks and stats |

---

#### verification/AssignmentsController
Manage verification assignments.

| Action | Purpose |
|--------|---------|
| `index` | List verification assignments |
| `show` | Assignment detail |
| `start` | Mark as in_progress |
| `complete` | Mark as completed |
| `reopen` | Return to pending |

---

#### verification/AccountsController
Verify researcher-entered data.

| Action | Purpose |
|--------|---------|
| `show` | Account review form |
| `create` | Create account (if not found previously) |
| `update` | Update account during verification |
| `edit` | Edit account form |
| `verify_with_changes` | Verify but allow URL/handle changes |
| `mark_entered` | Verifier re-enters data |
| `mark_not_found` | Verifier marks as not found |
| `reset_status` | Reset to not_started |
| `verify` | Approve account (verified = true) |
| `unverify` | Revert to unverified |
| `reject` | Reject account (verified = false) |
| `update_notes` | Add verification notes |

**Workflow:**
1. Verifier reviews researcher-entered data
2. Verifier can:
   - **Verify** — approve as-is (triggers Junkipedia sync)
   - **Revise** — update URL/handle and verify
   - **Reject** — mark as not found / incorrect
3. If researcher modified existing verified data, mark for secondary_verification
4. Verified accounts auto-enqueue to Junkipedia

**Features:**
- Side-by-side display of researcher vs previous data
- Version history from PaperTrail
- Revision notes
- Auto-secondary-verification flag when data modified

---

#### verification/QueueController
Queue of accounts to verify.

| Action | Purpose |
|--------|---------|
| `index` | List accounts needing verification |

---

### Authentication Controllers

#### Devise Controllers (`app/controllers/users/`)
Managed by Devise gem.

| Controller | Purpose |
|------------|---------|
| `OmniauthCallbacksController` | Google OAuth2 & Azure Entra ID callback handling |
| `InvitationsController` | Custom invitation flow |
| `RegistrationsController` | Custom signup with avatar upload |

**Flows:**
- Email/password signup (invite-only)
- Google OAuth2 login
- Microsoft Entra ID login
- Password reset
- Profile editing with avatar

---

### Public API Controllers

Read-only external API (`/api/v1`) — Bearer-token auth via `ApiToken`, separate from the session-authenticated internal `/api/*`. See `docs/PUBLIC_API.md` for the consumer contract.

#### Api::V1::BaseController
Shared auth, rate limiting, pagination, and error handling for all v1 controllers.

| Concern | Purpose |
|---------|---------|
| `authenticate_api_token!` | Bearer token lookup via `ApiToken.authenticate`; 401 `UNAUTHORIZED` if missing/invalid/revoked |
| `enforce_rate_limit!` | Fixed-window throttle, 300 req/min/token (`RATE_LIMIT_PER_MINUTE`); 429 `RATE_LIMITED` |
| `paginate` | `?page=`/`?per_page=` (default 25, max 500 — `MAX_PER_PAGE`) with `meta` envelope |
| `updated_since_param` | Parses `?updated_since=` as ISO8601; 400 `INVALID_PARAM` on bad input |
| `Api::V1::Serializers` (included module) | Hand-rolled JSON shapes (person, office, district, contest) shared by all three controllers |

#### Api::V1::OfficeholdersController
`GET /api/v1/officeholders` — current officeholders by default (`current=false` for historical), filterable by state/level/branch/office_category/body_name/district/chamber/party.

#### Api::V1::CandidatesController
`GET /api/v1/candidates` — filterable by year/state/office_category/district/chamber/party/outcome/winners/incumbent.

#### Api::V1::PeopleController
`GET /api/v1/people` (state/q/updated_since filters) and `GET /api/v1/people/:person_uuid` (stable-ID lookup, 404 `NOT_FOUND` if unknown).

---

## Services (Business Logic Layer)

### AirtableService
HTTP client for Airtable API.

**Purpose:** Fetch and sync data with Airtable bases.

**Key Methods:**
- `fetch_table(table_id, filters:, view_name:)` - Get records from table
- `fetch_records(table_id, options:)` - Fetch paginated records
- `create_record(table_id, fields:)` - Create record
- `update_record(table_id, record_id, fields:)` - Update record
- `delete_record(table_id, record_id)` - Delete record
- `all_records(table_id)` - Fetch all records (handles pagination)

**Used For:**
- Initial data population from Airtable bases
- Legacy import workflows

---

### CandidateImportService
Orchestrates full candidate import pipeline.

**Purpose:** Import candidates and election data from Airtable/CSV.

**Key Methods:**
- `import_2024_candidates` - Import 2024 candidate data
- `import_parties_from_airtable` - Create Party records
- `import_people_from_airtable` - Create Person records
- `import_districts_from_airtable` - Create District records
- `import_offices_from_airtable` - Create Office records
- `import_ballots_from_airtable` - Create Ballot records
- `import_contests_from_airtable` - Create Contest records
- `import_candidates_from_airtable` - Create Candidate records
- `import_officeholders_from_airtable` - Create Officeholder records

**Pipeline:**
1. Create State records (reference table)
2. Create Party records
3. Create Person records
4. Create Body, District, Office records
5. Create Ballot records
6. Create Election records
7. Create Contest records
8. Create Candidate records

---

### JunkipediaService
Junkipedia API v2 client.

**Purpose:** Integrate with Junkipedia for social media channel tracking.

**Key Methods:**
- `create_list(name, description:)` - Create tracking list
- `get_list(list_id)` - Get list details
- `get_lists(limit:)` - Get all lists
- `get_channels(list_id, limit:)` - Get channels in list
- `enqueue_channel(url)` - Submit URL for ingestion (returns job_id)
- `search_channel(handle, platform_code:)` - Find channel by handle
- `add_channels_to_list(list_id, channel_ids:)` - Bulk add to list
- `add_component(list_id, component_id, component_type:)` - Add component to list

**Supported Platforms:**
- Facebook, Twitter, Instagram, YouTube, TikTok, BlueSky, TruthSocial, Gettr, Rumble, Telegram, Threads

**Rate Limiting:**
- Respects `X-RateLimit-*` headers from API
- Exponential backoff on rate limit (429) responses
- Default: 4,500 requests/hour per API token

**Features:**
- Auto-retry with exponential backoff
- Rate limit aware
- Detailed error handling
- Channel format detection (URL → platform code)

---

## Background Jobs (Async Processing)

All jobs use ActiveJob with in-memory async adapter (Heroku Standard-0 limitation).

### EnqueueJunkipediaChannelJob
Trigger: SocialMediaAccount marked as verified

```ruby
EnqueueJunkipediaChannelJob.perform_later(social_media_account_id)
```

**Process:**
1. Load account
2. Build Junkipedia URL from account URL
3. Call `JunkipediaService.enqueue_channel(url)`
4. Store `junkipedia_enqueued_at` timestamp
5. Queue `ResolveJunkipediaChannelIdJob` after ~1 minute delay

**Retries:** Exponential backoff on JunkipediaError (5 max attempts)

**Note:** Jobs are lost on dyno restart; admin Junkipedia dashboard has manual re-queue buttons.

---

### ResolveJunkipediaChannelIdJob
Trigger: Account enqueued to Junkipedia

```ruby
ResolveJunkipediaChannelIdJob.perform_later(social_media_account_id)
```

**Process:**
1. Load account
2. Extract handle from account URL
3. Call `JunkipediaService.search_channel(handle, platform:)`
4. If found, store `junkipedia_channel_id`
5. Store `junkipedia_id_collected_at` timestamp
6. Queue `AddChannelToDefaultListJob`

**Retries:**
- Rate limit (header-driven): 10 attempts
- Other errors: Exponential backoff (5 attempts)

---

### AddChannelToDefaultListJob
Trigger: Channel ID resolved

```ruby
AddChannelToDefaultListJob.perform_later(social_media_account_id)
```

**Process:**
1. Load account
2. Get `JUNKIPEDIA_DEFAULT_LIST_ID` from env
3. Call `JunkipediaService.add_channels_to_list(list_id, [channel_id])`
4. Mark as synced

**Result:** Verified handles are now monitored by Junkipedia

---

## Request Flow Diagrams

### Public User Browsing Election Data

```
GET /elections/2026-NY-Primary
→ home_controller#show
→ Load Election, Ballots, Contests, Candidates
→ Render elections/show.html.erb
```

### Researcher Data Entry Workflow

```
1. Admin creates Assignment (person → researcher)
   POST /admin/assignments → assignments_controller#create

2. Researcher views assignment
   GET /researcher/assignments/:id → researcher/assignments_controller#show

3. Researcher starts assignment
   POST /researcher/assignments/:id/start → researcher/assignments_controller#start
   Updates status: pending → in_progress

4. Researcher enters social media accounts
   GET /researcher/accounts/:id → researcher/accounts_controller#show
   PATCH /researcher/accounts/:id → researcher/accounts_controller#update
   Mark as "entered" with URL/handle

5. Researcher completes assignment
   POST /researcher/assignments/:id/complete → researcher/assignments_controller#complete
   Updates status: in_progress → completed

6. Verifier reviews data
   GET /verification/accounts/:id → verification/accounts_controller#show

7. Verifier approves account
   POST /verification/accounts/:id/verify → verification/accounts_controller#verify
   account.verified = true
   → after_commit: EnqueueJunkipediaChannelJob.perform_later

8. Background job syncs to Junkipedia
   EnqueueJunkipediaChannelJob → ResolveJunkipediaChannelIdJob → AddChannelToDefaultListJob
```

### Admin Bulk Assignment Creation

```
GET /admin/people/:id/bulk_assign
→ Form with researcher selection + quantity

POST /admin/people/:id/create_bulk_assignments
→ Loop: create Assignment for each selected researcher
→ Redirect to dashboard

Researcher receives assignments and begins work
```

### Social Media Account Status Transitions

```
not_started (initial)
    ↓
entered (researcher found account)
    ↓
verified (verifier approved)
    ↓
[if verified] → enqueue_to_junkipedia_on_verification
    ↓
junkipedia_channel_id resolved
    ↓
added to JUNKIPEDIA_DEFAULT_LIST

Alternate flows:
- not_found (researcher couldn't find account)
- revised (verifier updated data)
- rejected (verifier rejected)
```

---

## Authentication & Authorization Matrix

| Workspace | Auth Required | Roles | Can Do |
|-----------|---------------|-------|--------|
| Public (/) | No | Any | Browse elections, people, offices, districts, parties |
| /profile | Yes | Any | View/edit own profile |
| /researcher | Yes | researcher | View assignments, enter social media data |
| /verification | Yes | researcher/admin | Verify accounts, reject/revise |
| /admin | Yes | admin | CRUD all entities, manage users, Junkipedia dashboard |

---

## Views Organization

```
app/views/
├── home/                          # Public home page
├── people/                        # Person browsing (public)
├── elections/                     # Election browsing (public)
├── contests/                      # Contest browsing (public)
├── ballots/                       # Ballot browsing (public)
├── offices/                       # Office browsing (public)
├── districts/                     # District browsing (public)
├── parties/                       # Party browsing (public)
├── bodies/                        # Body browsing (public)
├── states/                        # State browsing (public)
├── profiles/                      # User profile
├── about/                         # About page
├── help/                          # Help documentation
├── layouts/                       # Layout templates
│   ├── application.html.erb       # Main layout
│   ├── admin.html.erb            # Admin layout
│   └── public.html.erb           # Public layout
├── shared/                        # Reusable components
│   ├── _navbar.html.erb          # Navigation
│   ├── _filter_dropdowns.html.erb # Filter UI
│   ├── _elections_map.html.erb   # Map widget
│   └── ...
├── admin/                         # Admin workspace
│   ├── dashboard/
│   ├── people/
│   ├── social_media_accounts/
│   ├── contests/
│   ├── ballots/
│   ├── elections/
│   ├── districts/
│   ├── offices/
│   ├── parties/
│   ├── bodies/
│   ├── candidates/
│   ├── officeholders/
│   ├── assignments/
│   ├── users/
│   ├── junkipedia/
│   └── ...
├── researcher/                    # Researcher workspace
│   ├── dashboard/
│   ├── assignments/
│   ├── accounts/
│   ├── queue/
│   └── guide/
├── verification/                  # Verification workspace
│   ├── dashboard/
│   ├── assignments/
│   ├── accounts/
│   └── queue/
├── devise/                        # Authentication templates
└── user_mailer/                   # Email templates
```

---

## Deployment & Environment

**Development:**
- Local PostgreSQL
- Email via Letter Opener gem (browser preview)
- Active Storage: local file storage

**Production (Heroku):**
- PostgreSQL 17 (Heroku Standard-0)
- Email: SMTP (configured via env vars)
- Active Storage: S3 (Bucketeer add-on)
- Background jobs: async in-memory (loses jobs on restart)

**Environment Variables:**
```
# Auth
GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET
MICROSOFT_ENTRA_ID_CLIENT_ID, MICROSOFT_ENTRA_ID_CLIENT_SECRET

# Data Import
AIRTABLE_API_KEY, AIRTABLE_BASE_ID

# Junkipedia Integration
JUNKIPEDIA_API_TOKEN, JUNKIPEDIA_DEFAULT_LIST_ID

# Email
DEVISE_MAILER_FROM
SMTP_ADDRESS, SMTP_PORT, SMTP_USERNAME, SMTP_PASSWORD

# S3 (Production)
AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, AWS_BUCKET
```

---

## Key Design Patterns

**1. Role-Based Access Control**
- Admin: `/admin/*` — full CRUD
- Researcher: `/researcher/*` — data entry
- Verifier: `/verification/*` — review
- Public: `/` — browsing only

**2. Assignment Workflow**
- Admin creates Assignment (person → researcher)
- Researcher works on assignment (enter data)
- Verifier reviews researcher's work
- If needed, secondary verification via separate assignment

**3. Async Junkipedia Sync**
- Verified account → enqueue job
- Job resolves channel ID
- Job adds to list
- Hand-off to Junkipedia for monitoring

**4. Data Import Pattern**
- Stage data to temp tables
- Analyze and validate
- Import to production with find_or_create_by (idempotent)

**5. Audit Trail**
- PaperTrail versions on all core models
- User tracking (entered_by, verified_by)
- Timestamps (entered_at, verified_at)

