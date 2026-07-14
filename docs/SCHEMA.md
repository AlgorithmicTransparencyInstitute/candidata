# Candidata Database Schema

Models, columns, associations, validations, and scopes — **generated from `db/schema.rb` and the model files**. Column names below are the real ones; when editing, trust this over older docs.

Conventions worth knowing up front:
- **Geography is string-keyed.** `ballots.state`, `contests.location`, `districts.state`, `offices.state`, `bodies.state`, `elections.state`, and `people.state_of_residence` hold the **state abbreviation string** (e.g. `"SD"`), not a `state_id` FK. The `states` table is a reference table; `State has_many :districts/:offices/:ballots` declarations exist but are broken (no `state_id` columns) — query by abbreviation instead.
- Most core models use **PaperTrail** (`has_paper_trail`) for version history. Every change is attributed via `versions.whodunnit`: web edits store the user id (`ApplicationController` sets `set_paper_trail_whodunnit`), background jobs store `"job:ClassName"` (`ApplicationJob`), and rake/console/CLI contexts store `"rake:task"`/`"console:user"`/`"cli:…"` (`config/initializers/paper_trail.rb`). Versions created before June 2026 have `whodunnit: nil`.
- `airtable_id` columns track import provenance (unique, nullable).

---

## Election structure

### Election
`name`, `state`, `date`, `election_type` (primary/general/special), `year`, `registration_deadline`, `early_voting_start`, `early_voting_end`

- `has_many :ballots, dependent: :nullify`
- Validates: state, date, election_type, year (year auto-derived from date)
- Scopes: `primaries`, `generals`, `by_year`, `by_state`, `upcoming`, `past`
- `full_name` → `name` or `"{state} {Type} {year}"`

### Ballot
`state` (required), `date` (required), `election_type` (required: primary/general/special/runoff), `year`, `name`, `party`, `election_id` (optional FK)

- Unique on `[state, date, election_type, party]`
- `belongs_to :election (optional)`, `has_many :contests, dependent: :destroy`
- **`party` is required for primaries** and must be in `Party.ballot_vocabulary` (the single source of truth — see Party below; new `Party` rows become valid automatically)
- Scopes: `primary`, `general`, `special`, `runoff`, `for_year`, `for_state`, `for_party`
- **`name` is auto-populated** on save (`set_default_name` before_validation) from `"{year} {state} {party} {Type}"` when blank — so editor/CSV-created ballots always carry a name. An explicit name is kept. `full_name` returns `name` or the composed label.

### Contest
`date` (required), `location`, `contest_type` (required: primary/general/special/runoff), `party`, `office_id` (required), `ballot_id` (required)

- Unique on `[date, location, office_id, ballot_id]`
- `belongs_to :office, :ballot`, `has_many :candidates, dependent: :destroy`
- `party` required for primaries, must be in `Party.ballot_vocabulary`
- Delegates `state`, `election_type`, `year` to ballot
- Scopes: `primary`, `general`, `special`, `runoff`, `for_year`, `for_office`, `for_party`
- Methods: `full_name`, `winner`, `winners`, `total_votes` (sum of tallies), `decided?` — winner helpers use `Candidate.winners` (`outcome IN won/advanced`), so an unopposed advancer is treated as the winner

### Candidate
`person_id` (required), `contest_id` (required), `outcome` (required in DB; won/lost/pending/withdrawn/unknown/**advanced**), `tally` (default 0), `party_at_time` (string party name), `incumbent` (default false)

- `outcome` value **`advanced`** = advanced to the general unopposed (primary cancelled / no opponent — "won by default"). It is **not** a literal `won`, but it counts as a winner/nominee everywhere so an unopposed advancer flows into the general (and a future primary→general pipeline).
- `WINNING_OUTCOMES = %w[won advanced]` — the outcomes that mean "this candidate is the contest's winner/nominee"; the `winners` scope and the `Contest` winner helpers use it.
- **Unique on `[person_id, contest_id]`** — upserts should `find_or_initialize_by(person_id:, contest_id:)`
- `belongs_to :person, :contest`; delegates `office`, `ballot` to contest
- Scopes: `winners` (`outcome IN won/advanced`), `losers`, `pending`, `incumbents`, `challengers`, `for_year`
- Methods: `vote_percentage`, `won?` (literal win only), `advanced?`, `winner?` (won OR advanced), `lost?`

---

## Government structure

### Office
`title` (required), `level` (required: federal/state/local), `branch` (required: legislative/executive/judicial), `state`, `seat`, `role`, `office_category`, `body_name`, `jurisdiction`, `jurisdiction_ocdid`, `ocdid`, `county`, `district_id` (optional FK), `body_id` (optional FK)

- Unique on `[title, level, state, district_id]`
- `belongs_to :district, :body (both optional)`, `has_many :contests, :officeholders, :people (through)`
- Scopes: `federal`, `state`, `local`, `legislative`, `executive`, `judicial`, `by_category` (→ `office_category`), `by_body` (→ `body_name`), `search_text(q)` (ILIKE across title/seat/body_name/office_category/jurisdiction — backs the searchable office pickers)
- Methods: `full_title`, `display_name` (`"{title} ({seat})"`), `search_label` (adds `" — {state} · {body}"` for disambiguating results), `legislative?`/`executive?`/`judicial?`

### Officeholder
`person_id` (required), `office_id` (required), `start_date` (required), `end_date`, `elected_year`, `appointed` (default false), `official_email`, `official_phone`, `official_address`, `contact_form_url`, `next_election_date`, `term_end_date`

- `belongs_to :person, :office`
- Scopes: `current`, `former`, `as_of(date)`, `elected_in(year)`, plus appointment/term filters
- Methods: `current?`, `active_on?(date)`, tenure helpers

### District
`state` (required, abbreviation string), `district_number` (integer), `level` (required), `chamber`, `ocdid`, `boundaries` (text)

- Unique on `[state, district_number, level, chamber]`
- `has_many :offices` (via `district_id` on offices)
- **No `name` column** — `full_name` composes a label (`"OH State House District 5"`, `"AK At-Large"`, etc.) from state/level/chamber/district_number
- Scopes incl. `at_large` (`federal`, `district_number: 0`), `at_large_voting` (`VOTING_AT_LARGE_STATES`), `congressional`, `state_senate`/`state_house`
- ⚠️ Only ~7% of districts are referenced by any office (offices came from GovProj and only 429/6440 districts are linked; at-large districts carry no office). Not a schema error — a data-linkage completeness gap.

### Body
`name` (required), `level`, `branch`, `state`, `country` (default "US"), `jurisdiction`, `jurisdiction_ocdid`, `chamber_type`, `parent_body_id`, `seats_count`, `founded_date`, `website`

- Unique on `[name, country]`
- `has_many :offices` (via `body_id`), self-referential parent/sub-bodies

### State (reference table)
`name` (required, unique), `abbreviation` (required, unique), `fips_code` (unique), `state_type` (state/territory/federal_district)

- 56 rows: 50 states + DC + 5 territories
- Scopes: `states`, `territories`, `federal_district`; `State.find_by_abbrev("ny")`
- ⚠️ Its `has_many` declarations are broken (see conventions) — join other tables on the abbreviation string.

---

## People & parties

### Person
`first_name` (required), `last_name` (required), `middle_name`, `suffix`, `name_source` (name string exactly as it appeared in the import source — provenance, fill-if-blank only), `gender` (Male/Female/Other), `race`, `birth_date`, `death_date`, `state_of_residence`, `photo_url`, `website_official`, `website_campaign`, `website_personal`, `person_uuid` (unique), `wikipedia_id`, `party_affiliation_id` (legacy FK), `needs_secondary_verification`

- `has_many :candidates, :contests (through), :officeholders, :offices (through), :social_media_accounts (dependent: :destroy), :assignments (dependent: :destroy)`
- `has_many :person_parties / :parties` + legacy `belongs_to :party_affiliation`
- ⚠️ `candidates`/`officeholders` have **no `dependent:` option** — destroying a person with candidacies raises an FK violation. Remove candidacies first (the election editor deletes candidacies, never people).
- Scopes: `current_officeholders`, `former_officeholders`, `officeholders_as_of`, `candidates_in_year`, `election_winners_in_year`, `election_losers_in_year`, `by_state` (→ `state_of_residence`), `by_party`, `needs_secondary_verification`
- Methods: `full_name`, `formal_name`, `primary_party`, `primary_party=`, `add_party`, `current_officeholder?`, `candidate_in_year?`, `current_offices`, secondary-verification helpers

### Party
`name` (required, unique), `abbreviation` (required, unique), `ideology`

- `has_many :person_parties / :people (through)`; legacy `has_many :affiliated_people` via `party_affiliation_id`
- Scopes: `major` / `minor` (keyed on names "Democratic Party"/"Republican Party")
- **`Party.ballot_vocabulary`** — the single source of truth for the `ballots.party` / `contests.party` string vocabulary and every party dropdown. Union of the table's names as short labels (`ballot_label` strips a trailing `" Party"`, so `"Green Party"→"Green"`) with `LEGACY_BALLOT_PARTIES` (kept permanently so no already-stored value can fail validation), minus `"Unknown"`, sorted+uniq. `Party.canonical_ballot_party(raw)` snaps an arbitrary string to its canonical vocabulary casing (case-insensitive, `" Party"`-tolerant) or nil. Adding a `Party` row makes it a valid ballot/contest party automatically.
- ⚠️ Ballots/contests store the **short label** (`"Green"`); the table stores org names (`"Green Party"`). There is no `party_id` FK — `ballots.party`/`contests.party` are free-text columns validated against `ballot_vocabulary`. `candidates.party_at_time` uses the same short-label vocabulary.

### PersonParty (join)
`person_id`, `party_id`, `is_primary` (default false)

- Unique on `[person_id, party_id]`; **partial unique index enforces one primary per person**
- `belongs_to :person, touch: true` — a party change bumps `people.updated_at` (same incremental-sync purpose as SocialMediaAccount's touch, below)

---

## Research workflow

### SocialMediaAccount
`person_id` (required), `platform` (required, one of `SocialMediaAccount::PLATFORMS` — Facebook, Twitter, Instagram, YouTube, TikTok, BlueSky, TruthSocial, Gettr, Rumble, Telegram, Threads), `channel_type` (Campaign / Official Office / Personal), `url`, `handle`, `status`, `verified` (default false), `account_inactive` (default false), `research_status` (default "not_started": not_started/entered/not_found/verified/rejected/revised), `entered_by_id`, `entered_at`, `verified_by_id`, `verified_at`, `verification_notes`, `research_notes`, `researcher_verified`, `validation_source`, `pre_populated`, `modified_during_validation`, `needs_secondary_verification`, junkipedia sync columns (`junkipedia_channel_id`, `junkipedia_enqueued_at`, `junkipedia_id_collected_at`, `junkipedia_last_error`)

- **DB-unique on `[person_id, platform, handle]`**; model validates handle uniqueness scoped to `[person_id, platform, channel_type]`
- `belongs_to :person, :entered_by (User), :verified_by (User)` — **`person` association uses `touch: true`**, so any account change bumps `people.updated_at` (the public API's `/api/v1/people?updated_since=` relies on this for incremental sync)
- Workflow methods: `mark_entered!(user, url:, handle:)`, `mark_not_found!(user)`, `reset_status!`, `verify!(user, notes:)`, `reject!`, `revise!`, `clear_secondary_verification!`
- Junkipedia: `junkipedia_eligible` scope (verified + active + supported platform + url), sync-state scopes, **`after_commit` auto-enqueues to Junkipedia when an eligible account flips to `verified: true`** (no-op without `JUNKIPEDIA_API_TOKEN`)
- `previous_url` digs through PaperTrail versions

### Assignment
`user_id` (required), `assigned_by_id` (required), `person_id` (required), `task_type` (required: data_collection/data_validation/secondary_verification), `status` (default "pending": pending/in_progress/completed), `completed_at`, `notes`

- **Unique on `[user_id, person_id, task_type]`**
- `belongs_to :user, :assigned_by (User), :person`
- Scopes: `pending`, `in_progress`, `completed`, per-task-type, `for_user`, `active`
- Methods: `start!`, `complete!`, `reopen!`

### User
`email` (required, unique), `encrypted_password`, `name` (single column — **no first/last name columns**), `role` (default `"researcher_assistant"`; admin/researcher/…), `provider`/`uid` (OAuth), `avatar_url`, Devise trackable + invitable columns (`sign_in_count`, `invitation_token`, `invited_by_*`, …)

- Devise: invitable, database_authenticatable, registerable, recoverable, rememberable, validatable, trackable, omniauthable (Google OAuth2 + Entra ID)
- `has_many :assignments`, entered/verified social accounts
- Role helpers: `admin?`, `researcher?`

### ApiToken
`name` (required), `token_digest` (required, unique, SHA-256 of the plaintext token — plaintext itself is never stored), `created_by_id` (optional FK → users), `last_used_at`, `revoked_at`

- Bearer tokens for the public read API (`/api/v1/*`); admin-managed at `/admin/api_tokens`. Plaintext (`cnd_live_…`) is generated once and shown only on creation.
- `belongs_to :created_by, class_name: "User" (optional)`
- Scope: `active` (`revoked_at: nil`)
- Class methods: `generate!(name:, created_by:)` (creates the row and returns the instance with `raw_token` set), `authenticate(raw)` (looks up by digest among active tokens)
- Instance methods: `revoke!`, `revoked?`, `touch_last_used!` (throttled to one write per minute; uses `update_column` — no validations, no PaperTrail noise)

---

## Analytics & staging

- **Ahoy::Visit / Ahoy::Event** — page/event analytics (`ahoy_*` tables)
- **PaperTrail `versions`** — audit history for models with `has_paper_trail`
- **temp_people / temp_accounts / temp_govproj** — import staging tables (see Data Staging Pattern in CLAUDE.md)

---

## Relationship map

```
Election ──< Ballot ──< Contest >── Office >── District / Body
                           │            │
                           └─< Candidate ▼
                                  │   Officeholder
Person ──────────────────────────┴───────┘
  ├──< PersonParty >── Party
  ├──< SocialMediaAccount  (entered_by/verified_by → User)
  └──< Assignment  (user, assigned_by → User)
```
