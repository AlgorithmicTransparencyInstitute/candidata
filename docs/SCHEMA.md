# Candidata Database Schema

Complete documentation of all models, relationships, validations, and scopes.

## Core Domain Models

### Person

Central entity representing any individual (candidate, officeholder, or person in research pipeline).

**Attributes:**
- `first_name` (string, required) - First name
- `last_name` (string, required) - Last name  
- `middle_name` (string) - Middle name
- `suffix` (string) - Name suffix (Jr., Sr., II, III, etc.)
- `gender` (string) - Male, Female, Other
- `date_of_birth` (date) - Birth date
- `place_of_birth` (string) - Birthplace
- `bio` (text) - Biography or background info
- `website` (string) - Personal/campaign website
- `state_of_residence` (string) - Primary state
- `person_uuid` (string, unique) - External UUID tracking
- `airtable_id` (string, unique) - Airtable source ID
- `needs_secondary_verification` (boolean) - Flag for secondary verification workflow

**Associations:**
- `has_many :candidates` - Races this person ran in
- `has_many :contests` - Contests through candidates
- `has_many :officeholders` - Government positions held
- `has_many :offices` - Offices through officeholders
- `has_many :social_media_accounts` - Linked social handles (cascading delete)
- `has_many :assignments` - Research/verification tasks assigned to this person
- `has_many :assigned_researchers` - Users assigned to research this person
- `has_many :person_parties` - Political party affiliations (many-to-many)
- `has_many :parties` - Parties through person_parties
- `belongs_to :party_affiliation` (optional) - Legacy single-party field (backwards compatibility)

**Validations:**
- First and last names are required
- `person_uuid` and `airtable_id` must be unique (allow nil)
- `gender` must be in [Male, Female, Other] if present

**Scopes:**
- `current_officeholders` - People currently holding elected/appointed office
- `former_officeholders` - People who held office but don't now
- `officeholders_as_of(date)` - People holding office on a specific date
- `candidates_in_year(year)` - People who ran for office in a given year
- `election_winners_in_year(year)` - People who won elections in a given year
- `election_losers_in_year(year)` - People who lost elections in a given year
- `by_state(state)` - Filter by state of residence
- `by_party(party_id)` - Filter by party affiliation
- `needs_secondary_verification` - People marked for secondary verification

**Key Instance Methods:**
- `full_name` - Returns "FirstName LastName"
- `formal_name` - Returns "FirstName LastName, Suffix" formatted for formal use
- `primary_party` - Returns current primary party (or legacy party_affiliation)
- `primary_party=(party)` - Set primary party (clears other primaries)
- `add_party(party, is_primary: false)` - Add party affiliation
- `current_officeholder?` - Is currently holding office?
- `officeholder_on?(date)` - Was holding office on specific date?
- `candidate_in_year?(year)` - Ran in given year?
- `won_election_in_year?(year)` - Won election in given year?
- `current_offices` - All offices currently held
- `offices_held_on(date)` - Offices held on specific date
- `mark_for_secondary_verification_if_needed!` - Mark for secondary verification if accounts were modified
- `clear_secondary_verification!` - Clear secondary verification flag

**Audit Trail:**
- Uses PaperTrail for version history

---

### Candidate

A person running in a specific election contest.

**Attributes:**
- `person_id` (integer, required) - Reference to Person
- `contest_id` (integer, required) - Reference to Contest
- `outcome` (string) - Result: won, lost, pending, withdrawn, unknown
- `tally` (integer) - Votes received
- `incumbent` (boolean) - Was candidate the incumbent?
- `party_at_time` (string) - Party affiliation at time of election

**Associations:**
- `belongs_to :person` - The candidate
- `belongs_to :contest` - The race they ran in

**Validations:**
- Person and contest are required
- Outcome must be in [won, lost, pending, withdrawn, unknown]

**Scopes:**
- `winners` - Candidates with outcome = won
- `losers` - Candidates with outcome = lost
- `pending` - Candidates with outcome = pending
- `incumbents` - Current office holders running for re-election
- `challengers` - Non-incumbent candidates
- `for_year(year)` - Candidates in contests from given year

**Key Instance Methods:**
- `won?` - Did candidate win?
- `lost?` - Did candidate lose?
- `vote_percentage` - Calculate percentage of votes in contest

---

### Contest

A single race on a ballot (e.g., "Governor", "U.S. Senate District 1").

**Attributes:**
- `office_id` (integer, required) - Position being contested
- `ballot_id` (integer, required) - Ballot this contest appears on
- `contest_type` (string) - primary, general, special, runoff
- `description` (text) - Contest description
- `total_votes` (integer) - Total votes cast in this contest
- `number_of_seats` (integer) - Seats available (default 1)

**Associations:**
- `belongs_to :office` - Position being contested
- `belongs_to :ballot` - Ballot containing this contest
- `has_many :candidates` - People running in this contest (cascading delete)
- `has_many :people` - People through candidates

**Validations:**
- Office and ballot are required

**Scopes:**
- `primary` - Primary election contests
- `general` - General election contests
- `special` - Special election contests
- `runoff` - Runoff contests
- `for_year(year)` - Contests from given year
- `for_office(office_id)` - Contests for specific office
- `for_party(party)` - Contests won by given party

**Key Instance Methods:**
- `full_name` - Returns formatted contest name
- `winner` - Candidate with outcome = won
- `winners` - All candidates with outcome = won
- `total_votes` - Sum of candidate tallies
- `decided?` - Has outcome been determined?

---

### Officeholder

A person holding an elected or appointed government position.

**Attributes:**
- `person_id` (integer, required) - Person holding office
- `office_id` (integer, required) - Office being held
- `start_date` (date, required) - When term began
- `end_date` (date) - When term ends/ended
- `elected_year` (integer) - Year of election (if elected)
- `appointed` (boolean) - Was this an appointment vs election?
- `term_length_years` (integer) - Expected term length

**Associations:**
- `belongs_to :person` - The office holder
- `belongs_to :office` - The position held

**Validations:**
- Start date is required
- End date must be >= start date if present

**Scopes:**
- `current` - Currently active (no end_date or end_date in future)
- `former` - No longer in office (end_date in past)
- `as_of(date)` - Active on specific date
- `elected_in(year)` - Elected in given year
- `appointed` - Appointed positions
- `elected` - Elected positions
- `term_ending_before(date)` - Terms ending before date
- `up_for_election_before(date)` - Elections coming up before date

**Key Instance Methods:**
- `current?` - Is officeholder currently active?
- `active_on?(date)` - Was in office on specific date?
- `tenure_length` - Duration in office
- `tenure_years` - Duration in years

---

### Office

A government position (e.g., "U.S. Senator", "City Councilor").

**Attributes:**
- `district_id` (integer) - Electoral district (optional)
- `body_id` (integer) - Governmental body (optional)
- `ocd_id` (string) - Open Civic Data ID for jurisdiction/district
- `category` (string) - Specific office type (e.g., "State Representative")
- `level` (string) - federal, state, local
- `branch` (string) - legislative, executive, judicial
- `role` (string) - Standard role code
- `body_name` (string) - Name of legislative body

**Associations:**
- `belongs_to :district` (optional) - Electoral district
- `belongs_to :body` (optional) - Governmental body
- `has_many :contests` - Races for this office
- `has_many :officeholders` - People holding this office
- `has_many :people` - People through officeholders

**Validations:**
- Category is required

**Scopes:**
- `federal` - Federal offices
- `state` - State-level offices
- `local` - Local offices
- `legislative` - Legislative branch
- `executive` - Executive branch
- `judicial` - Judicial branch
- `by_category(category)` - Filter by category
- `by_body(body_id)` - Filter by body

**Key Instance Methods:**
- `full_title` - Formatted office name
- `display_name` - Short display name
- `legislative?` - Is legislative branch?
- `executive?` - Is executive branch?
- `judicial?` - Is judicial branch?

---

### Ballot

A list of contests voting on a single day in a jurisdiction.

**Attributes:**
- `election_id` (integer) - Election this ballot is part of
- `state_id` (integer, required) - State/territory
- `ballot_type` (string) - primary, general, special, runoff
- `ballot_date` (date, required) - When election occurs
- `year` (integer, required) - Election year

**Associations:**
- `belongs_to :election` (optional) - Parent election
- `belongs_to :state` - Jurisdiction
- `has_many :contests` - Races on this ballot (cascading delete)
- `has_many :offices` - Offices through contests

**Validations:**
- State, ballot_date, and year are required

**Scopes:**
- `primary` - Primary elections
- `general` - General elections
- `special` - Special elections
- `runoff` - Runoff elections
- `for_year(year)` - Ballots from given year
- `for_state(state_id)` - Ballots in given state
- `for_party(party)` - Ballots with contests won by party

**Key Instance Methods:**
- `full_name` - Formatted ballot name with state and date

---

### Election

A grouping of ballots for a single year (primary + general).

**Attributes:**
- `year` (integer, required) - Election year
- `election_type` (string) - primary, general, special
- `description` (text) - Notes about election

**Associations:**
- `has_many :ballots` - All ballots for this election (cascading delete)

**Validations:**
- Year is required

**Scopes:**
- `primaries` - Primary elections
- `generals` - General elections
- `by_year(year)` - Elections in given year
- `by_state(state)` - Elections in given state
- `upcoming` - Future elections
- `past` - Past elections

**Key Instance Methods:**
- `full_name` - Formatted name (e.g., "2026 General Election")

---

### District

Electoral districts (congressional, state legislative, local).

**Attributes:**
- `state_id` (integer, required) - State
- `ocd_id` (string) - Open Civic Data ID
- `district_type` (string) - federal, state_senate, state_house, local
- `number` (string) - District number (e.g., "3", or "at-large")
- `chamber` (string) - upper (Senate), lower (House), single
- `description` (text) - District description

**Associations:**
- `belongs_to :state` - State containing district
- `has_many :offices` - Offices in this district (cascading delete)

**Validations:**
- State is required

**Scopes:**
- `federal` - Congressional districts
- `state_level` - State legislative districts
- `local` - Local districts
- `upper_chamber` - State senates
- `lower_chamber` - State houses
- `congressional` - U.S. House districts
- `at_large` - At-large districts (single representative per state)
- `state_senate` - State senate districts
- `state_house` - State house districts
- `voting_members(count)` - Districts with specified number of seats

**Key Instance Methods:**
- `full_name` - Formatted district name (e.g., "CA-12 (Congressional)")

---

### Body

Governmental body (e.g., "U.S. House of Representatives", "California Senate").

**Attributes:**
- `name` (string, required) - Body name
- `abbreviation` (string) - Short abbreviation
- `level` (string) - federal, state, local
- `branch` (string) - legislative, executive, judicial
- `country` (string) - Country code
- `state_code` (string) - State code (for state/local bodies)
- `parent_body_id` (integer) - Parent body (optional, for sub-bodies)
- `ocd_id` (string) - Open Civic Data ID

**Associations:**
- `has_many :offices` - Offices in this body (cascading delete)
- `has_many :sub_bodies` - Child bodies (cascading delete)
- `belongs_to :parent_body` (optional) - Parent body

**Validations:**
- Name is required

**Scopes:**
- `federal` - Federal bodies
- `state_level` - State bodies
- `local` - Local bodies
- `legislative` - Legislative branch
- `executive` - Executive branch
- `judicial` - Judicial branch
- `by_country(country)` - Filter by country
- `by_state(state)` - Filter by state

**Key Instance Methods:**
- `current_members` - Officeholders currently in this body
- `current_officeholders` - Unique people currently in this body
- `display_name` - Formatted name

---

### State

US states and territories (reference table).

**Attributes:**
- `name` (string, required) - Full name
- `abbreviation` (string, required) - 2-letter code (CA, NY, PR, etc.)
- `state_type` (string) - state, territory, federal_district
- `fips_code` (integer) - FIPS numeric code
- `country` (string) - Country code (always US)
- `status` (string) - Current political status

**Associations:**
- `has_many :districts` - Electoral districts
- `has_many :offices` - Government offices
- `has_many :ballots` - Ballots/elections
- `has_many :bodies` - Governmental bodies

**Validations:**
- Name and abbreviation are required and must be unique

**Scopes:**
- `states` - US states (50)
- `territories` - US territories (PR, GU, VI, AS, MP)
- `federal_district` - DC (Washington DC)

**Key Instance Methods:**
- `territory?` - Is a territory?
- `federal_district?` - Is DC?
- `self.find_by_abbrev(code)` - Find state by abbreviation

---

### Party

Political party (e.g., Democratic, Republican, Green, etc.).

**Attributes:**
- `name` (string, required, unique) - Party name
- `abbreviation` (string, unique) - Short code (D, R, G, I, etc.)
- `ideology` (string) - left, center, right, other
- `description` (text) - Party description

**Associations:**
- `has_many :person_parties` - Affiliations with people
- `has_many :people` - People through person_parties
- `has_many :affiliated_people` - Legacy single-party affiliations

**Validations:**
- Name and abbreviation are required and unique

**Scopes:**
- `major` - Democratic and Republican parties
- `minor` - All other parties

---

### PersonParty

Join table for many-to-many person-party relationship.

**Attributes:**
- `person_id` (integer, required) - Person
- `party_id` (integer, required) - Party
- `is_primary` (boolean) - Is this the primary party affiliation?
- `status` (string) - active, former, pending
- `started_at` (date) - When affiliation began
- `ended_at` (date) - When affiliation ended

**Associations:**
- `belongs_to :person` - The person
- `belongs_to :party` - The party

**Validations:**
- Person and party are required
- Only one primary party per person per status

**Scopes:**
- `primary` - Primary party affiliation

---

## Research & Verification Models

### Assignment

Work task assigned to researchers/verifiers.

**Attributes:**
- `user_id` (integer, required) - Researcher/verifier assigned
- `person_id` (integer, required) - Person to research
- `assigned_by_id` (integer, required) - Admin who created assignment
- `assignment_type` (string) - data_collection, data_validation, secondary_verification
- `status` (string) - pending, in_progress, completed
- `started_at` (datetime) - When researcher started
- `completed_at` (datetime) - When researcher completed
- `notes` (text) - Task notes/instructions

**Associations:**
- `belongs_to :user` - Assigned researcher/verifier
- `belongs_to :person` - Person being researched
- `belongs_to :assigned_by` - Admin who assigned

**Validations:**
- User, person, and assigned_by are required
- Assignment type is required

**Scopes:**
- `pending` - Not started
- `in_progress` - Currently being worked
- `completed` - Finished
- `data_collection` - Data entry tasks
- `data_validation` - Verification tasks
- `secondary_verification` - Secondary review tasks
- `active` - Pending or in_progress

**Key Instance Methods:**
- `start!` - Mark as in_progress
- `complete!` - Mark as completed
- `reopen!` - Return to pending
- `has_validation_assignment?` - Is there a matching validation task?
- `pending?` - Is pending?
- `in_progress?` - Is in_progress?
- `completed?` - Is completed?

---

### SocialMediaAccount

A social media handle linked to a person.

**Attributes:**
- `person_id` (integer, required) - Account owner
- `platform` (string, required) - Facebook, Twitter, Instagram, YouTube, TikTok, BlueSky, TruthSocial, Gettr, Rumble, Telegram, Threads
- `handle` (string) - Username/handle (e.g., "jdoe123")
- `url` (string) - Full URL to account
- `channel_type` (string) - Campaign, Official Office, Personal
- `account_inactive` (boolean) - Account no longer active?
- `pre_populated` (boolean) - Pre-filled from import?
- `research_status` (string) - not_started, entered, not_found, verified, rejected, revised
- `verified` (boolean) - Passed verification?
- `entered_by_id` (integer) - Researcher who entered data
- `entered_at` (datetime) - When data was entered
- `verified_by_id` (integer) - Verifier who verified
- `verified_at` (datetime) - When verified
- `verification_notes` (text) - Verification notes
- `modified_during_validation` (boolean) - Was modified after entry?
- `needs_secondary_verification` (boolean) - Needs secondary review?
- `junkipedia_channel_id` (string) - Junkipedia internal ID
- `junkipedia_enqueued_at` (datetime) - When sent to Junkipedia
- `junkipedia_id_collected_at` (datetime) - When Junkipedia ID resolved
- `junkipedia_last_error` (text) - Last Junkipedia sync error

**Associations:**
- `belongs_to :person` - Account owner
- `belongs_to :entered_by` (class_name: 'User', optional) - Data entry researcher
- `belongs_to :verified_by` (class_name: 'User', optional) - Verifier

**Validations:**
- Platform is required and must be in PLATFORMS list
- Channel type must be in CHANNEL_TYPES
- Handle must be unique per (person, platform, channel_type)
- Research status must be in RESEARCH_STATUSES

**Scopes:**
- `active` - Non-inactive accounts
- `inactive` - Inactive accounts
- `verified` - Verified accounts
- `unverified` - Unverified accounts
- `by_platform(platform)` - Filter by social platform
- `campaign` - Campaign accounts
- `official` - Official office accounts
- `personal` - Personal accounts
- `pre_populated` - Pre-filled accounts
- `needs_research` - Pre-populated but not started
- `needs_verification` - Entered/not_found/revised, awaiting verification
- `needs_secondary_verification` - Marked for secondary review
- `core_platforms` - Major platforms (Facebook, Twitter, Instagram, YouTube, TikTok, BlueSky)
- `fringe_platforms` - Alternative platforms (TruthSocial, Gettr, Rumble, Telegram, Threads)
- `junkipedia_eligible` - Verified, active, on supported platforms, has URL
- `junkipedia_pending` - Eligible but not yet queued
- `junkipedia_unresolved` - Queued but no ID yet
- `junkipedia_synced` - Has channel ID
- `junkipedia_errored` - Had sync error

**Key Instance Methods:**
- `active?` - Is account active?
- `display_name` - "@handle" or URL
- `mark_entered!(user, url:, handle:)` - Researcher entered data
- `mark_not_found!(user)` - Account not found
- `reset_status!(user)` - Clear status, return to not_started
- `verify!(user, notes:)` - Verifier approved
- `reject!(user, notes:)` - Verifier rejected
- `revise!(user, url:, handle:, notes:)` - Verifier revised
- `needs_verification?` - Awaiting verification?
- `clear_secondary_verification!` - Clear secondary flag
- `version_count` - Number of edits (via PaperTrail)
- `has_revisions?` - Has been edited?
- `junkipedia_eligible?` - Eligible for Junkipedia sync?
- `junkipedia_sync_status` - :pending, :enqueued, or :synced
- `previous_url` - Last URL before cleared (from version history)

**Hooks:**
- `after_commit :enqueue_to_junkipedia_on_verification` - Auto-queue when verified

**Class Methods:**
- `prepopulate_for_person!(person, platforms:, channel_type:)` - Create account stubs

**Audit Trail:**
- PaperTrail tracks all changes (create, update, destroy)

---

## User Management Models

### User

Platform user (researcher, verifier, admin).

**Attributes:**
- `email` (string, required, unique) - Login email
- `encrypted_password` (string) - Devise password hash
- `first_name` (string) - First name
- `last_name` (string) - Last name
- `role` (string) - admin, researcher, verifier
- `invitation_token` (string) - Devise invitation token
- `invitation_accepted_at` (datetime) - When invitation was accepted
- `provider` (string) - OAuth provider (google_oauth2, azure_ad)
- `uid` (string) - OAuth user ID
- `avatar_url` (string) - Avatar image
- `phone` (string) - Phone number
- `status` (string) - active, inactive, suspended
- `last_sign_in_at` (datetime) - Last login
- `sign_in_count` (integer) - Number of logins
- `invited_by_id` (integer) - Admin who invited this user

**Devise Settings:**
- invitable - Invitation-only registration
- database_authenticatable - Email/password auth
- registerable - Self-registration
- recoverable - Password reset
- rememberable - Remember login
- validatable - Email/password validation
- trackable - Login tracking
- omniauthable - OAuth (Google, Entra ID)

**Associations:**
- `has_many :assignments` - Tasks assigned to this user
- `has_many :assigned_people` - People through assignments
- `has_many :entered_accounts` - Accounts this user entered data for
- `has_many :verified_accounts` - Accounts this user verified

**Validations:**
- Email is required and unique
- Password present on creation

**Scopes:**
- `admin` - Admins
- `researcher` - Researchers
- `verifier` - Verifiers
- `active` - Active users
- `inactive` - Inactive users
- `pending_invitations` - Users who haven't accepted invite

**Key Instance Methods:**
- `admin?` - Is admin?
- `researcher?` - Is researcher?
- `verifier?` - Is verifier?
- `can_manage_users?` - Can create/edit users?
- `can_assign_tasks?` - Can create assignments?
- `pending_assignments` - Unstarted assignments for this user
- `from_omniauth(auth_data)` - Create/update from OAuth
- `attach_avatar_from_url(url)` - Download and attach avatar
- `full_name` - First + last name

---

## Analytics Models

### Ahoy::Visit

Page visit tracking via Ahoy analytics gem.

**Attributes:**
- `user_id` (integer) - Visiting user (optional)
- `visit_token` (string) - Visit identifier
- `visitor_token` (string) - Visitor identifier (cookie)
- `ip` (string) - IP address
- `user_agent` (string) - Browser user agent
- `referrer` (string) - HTTP referrer
- `landing_page` (string) - First page visited

**Used for:** Page view analytics and user behavior tracking

---

### Ahoy::Event

Event tracking (page views, button clicks, etc.).

**Attributes:**
- `visit_id` (integer) - Associated visit
- `user_id` (integer) - Associated user
- `name` (string) - Event type
- `properties` (jsonb) - Event-specific data
- `time` (datetime) - When event occurred

**Used for:** Detailed user interaction tracking and analytics

---

## Temporary Staging Models

Used for data import pipelines.

### TempPerson
Temporary table for imported person data from Airtable.

### TempAccount
Temporary table for imported account data.

### TempGovProj
Temporary table for imported GovProj officeholder data.

These tables allow validation and analysis before importing to production tables.

---

## Schema Relationships Diagram

```
Person
├── has_many Candidates
├── has_many Contests (through Candidates)
├── has_many Officeholders
├── has_many Offices (through Officeholders)
├── has_many SocialMediaAccounts
├── has_many Assignments
└── has_many PersonParties → Parties

Candidate
├── belongs_to Person
└── belongs_to Contest

Contest
├── belongs_to Office
├── belongs_to Ballot
└── has_many Candidates

Officeholder
├── belongs_to Person
└── belongs_to Office

Office
├── belongs_to District
├── belongs_to Body
├── has_many Contests
└── has_many Officeholders

Ballot
├── belongs_to Election
├── belongs_to State
└── has_many Contests

Election
└── has_many Ballots

District
├── belongs_to State
└── has_many Offices

Body
├── has_many Offices
└── has_many SubBodies

State
├── has_many Districts
├── has_many Ballots
└── has_many Bodies

SocialMediaAccount
├── belongs_to Person
├── belongs_to EnteredBy (User)
└── belongs_to VerifiedBy (User)

Assignment
├── belongs_to User
├── belongs_to Person
└── belongs_to AssignedBy (User)

User
├── has_many Assignments
├── has_many EnteredAccounts (SocialMediaAccount)
└── has_many VerifiedAccounts (SocialMediaAccount)
```

---

## Key Features by Model

| Feature | Models Involved |
|---------|-----------------|
| Candidate tracking | Person, Candidate, Contest, Ballot, Office |
| Officeholder tracking | Person, Officeholder, Office, District, Body |
| Social media research | Person, SocialMediaAccount, Assignment, User |
| Election management | Election, Ballot, Contest, Office, District |
| Party affiliation | Person, Party, PersonParty |
| User roles | User, Assignment |
| Data verification | SocialMediaAccount, User (verified_by) |
| Audit trail | PaperTrail on all core models |
| Analytics | Ahoy::Visit, Ahoy::Event |

