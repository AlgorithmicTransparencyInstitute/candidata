# Candidata User-Facing Features

Complete documentation of features available to different user roles.

---

## Public Features (No Login Required)

### 1. Browse Elections
**Path:** `/elections`

Discover elections by year and state.

**Capabilities:**
- List all elections (primary, general, special)
- Filter by year and state
- View election details with ballot information
- See all contests in each election

**Use Case:** Researchers discovering which elections are available in the system.

---

### 2. Search People
**Path:** `/people`

Search for candidates and officeholders.

**Capabilities:**
- Full-text search by first/last name
- Filter by state of residence
- Filter by party affiliation
- Filter by role (candidate, officeholder, both)
- Filter by election year
- Sort by relevance, name, or recent activity

**Shows for Each Person:**
- Current offices held
- Past offices held (with years)
- Races they've run in
- Party affiliations
- Social media accounts
- Contact information (if available)

**Use Case:** Finding a specific person and viewing their public record.

---

### 3. View Offices & Positions
**Path:** `/offices`

Browse government positions.

**Capabilities:**
- Filter by level (federal, state, local)
- Filter by branch (legislative, executive, judicial)
- Filter by category (e.g., "Governor", "U.S. Senator")
- View office holders and election history
- See jurisdiction and OCD-ID

**Use Case:** Understanding government structure and who holds what positions.

---

### 4. Explore Electoral Districts
**Path:** `/districts`

View electoral districts.

**Capabilities:**
- Filter by type (Congressional, state legislative, local)
- Filter by state
- View offices in each district
- See current representatives

**Use Case:** Finding which representatives cover a specific geographic area.

---

### 5. Browse Parties
**Path:** `/parties`

View all political parties in the system.

**Capabilities:**
- List all parties with ideologies
- View affiliated people per party
- See party descriptions

**Use Case:** Understanding party composition and support.

---

### 6. View Contests
**Path:** `/contests`

Browse individual election contests (races).

**Capabilities:**
- Search and filter contests
- View all candidates in a contest
- See voting outcomes
- View race details (office, date, type)

**Use Case:** Analyzing specific races and results.

---

### 7. Read Documentation
**Path:** `/help`

Access documentation about the app.

**Sections:**
- **Data Sources** — Where data comes from
- **Data Model** — How the data is organized
- **Coverage** — What states/offices are included
- **Researcher Guide** — Instructions for researchers

**Use Case:** Understanding how to use Candidata and what data is available.

---

## Researcher Features

**Workspace:** `/researcher`
**Role:** Assigned by admin

### 1. View Dashboard
**Path:** `/researcher`

Researcher overview and task management. One card per task type — **Data
Collection**, **Data Validation**, **Secondary Verification** and
**Demographics** (teal) — each listing the user's active assignments with a
Start/Continue button. Secondary verification assignments link into the
verification workspace (`/verification/assignments/:id`), which owns that
flow; demographic research links into `/demographics/assignments/:id`. The
sidebar carries a matching fourth item, **Demographics**, with a count badge
of active demographic assignments.

**Shows:**
- Pending assignments (how many, per task type)
- Currently in-progress assignments
- Completed assignments count
- Quick stats on work progress (pending/in-progress per task type)

**Actions:**
- Start an assignment
- Jump to assignment detail

---

### 2. Manage Assignments
**Path:** `/researcher/assignments`

View tasks assigned by admin.

**Capabilities:**
- See all assigned people
- Filter by status (pending, in_progress, completed)
- View assignment notes from admin
- Start/complete assignments

**Status Lifecycle:**
1. **Pending** - Not yet started
2. **In Progress** - Researcher is actively working
3. **Completed** - Researcher finished, awaiting verification

**Actions:**
- Click to start assignment (changes status to in_progress)
- View all social media accounts to research
- Click to complete (changes status to completed)

---

### 3. Enter Social Media Data
**Path:** `/researcher/assignments/:id` → Accounts section

Core workflow: finding and entering social media handles.

**For Each Account:**

1. **Account Information**
   - Person's name and photo
   - Platform (Facebook, Twitter, Instagram, YouTube, TikTok, BlueSky, TruthSocial, Gettr, Rumble, Telegram, Threads)
   - Account type (Campaign, Official Office, Personal)
   - Current status

2. **Data Entry Options**
   - **Found Account** → Enter URL and handle
   - **Not Found** → Account doesn't exist / couldn't locate
   - **Skip** → Mark as pending verification (leave for verifier to review)

3. **Version History** (if applicable)
   - If account was previously verified, show previous URL
   - Allows researcher to understand what was known before

4. **Research Status States**
   - `not_started` — No research done yet
   - `entered` — Researcher found and entered URL/handle
   - `not_found` — Researcher searched but couldn't locate account
   - `verified` — Verifier approved (researcher sees this for reference)
   - `rejected` — Verifier rejected
   - `revised` — Verifier updated the data

---

### 4. Research Queue
**Path:** `/researcher/queue`

Linear queue of accounts needing research (pagination support).

**Useful for:** Quickly moving through accounts one-by-one.

**Shows:**
- List of accounts by priority/order
- Click to start researching
- Progress indicator

---

### 5. Submit Work
**Workflow:**
1. Start assignment
2. Enter all social media accounts (or mark not_found)
3. Click "Complete Assignment"
4. Verifier will review your work

---

### 6. Demographic Research
**Path:** `/demographics`

Collect, confirm and source demographic metadata about a person — gender,
race/ethnicity, date of birth, marital and parental status, education, military
service — and record **where each answer came from**.

**The governing rule: a blank field is not an answer.**

Everywhere else in the app, "no value" means "not done yet". That breaks down
here, because plenty of candidates simply have no public record of their
marital status or date of birth. If blank meant unfinished, those people would
sit in the queue forever and researchers would be pushed toward guessing. So
**"Not publicly documented" is a real, finished answer** — you looked, it isn't
available, and you say so. That is why the value dropdowns contain no
"Unknown" option: an "Unknown" *value* would collapse "nobody looked" and "we
looked, it isn't public" into one state, and those are exactly the two states
an admin needs to tell apart.

**The Queue** (`/demographics`)

- One row per assigned person: photo, name, state, party
- An `n/n determined` counter and progress bar showing how many required fields already have a determination
- Pending / In progress pill, and a **Start** or **Continue** button
- Your last 10 completed demographic assignments below

**The Research Page** (`/demographics/assignments/:id`)

Two columns:

- **Left — the form.** Fields grouped into **Identity** (gender, race/ethnicity, date of birth, birth year), **Family** (marital status, children, number of children), **Education** (highest level, institution type, institution name) and **Service** (military service, branch). Every row carries a value control, a determination select, a source URL and an evidence note. Rows are tinted by determination — green verified, slate not-documented, amber conflict, red error — so a half-finished person reads at a glance. One **Save Progress** button saves the whole person at once.
- **Right (sticky) — sourcing.** Everything needed to source an answer without leaving the page: the person's campaign / official / personal sites, their Wikipedia article, every active social account with its handle, and prefilled **Google**, **Ballotpedia** and **Wikipedia** searches for their name.

Detail fields stay hidden until they mean something: "Number of children"
appears only after "Has children", "Branch" only after a military service
answer other than "Never served". Changing the parent answer clears the detail
*and* its evidence, so nobody keeps a branch after "Never served".

**The Three Determinations**

| Determination | Meaning | Evidence |
|---------------|---------|----------|
| **Verified** | You found the answer and can cite where | Requires a value **and** a source URL or note |
| **Not publicly documented** | You looked and it isn't available — a real answer | No value and no source required |
| **Sources conflict** | Sources disagree — a request for a second opinion | Requires a source URL or note |

Leaving a field's determination blank is allowed: it just means you haven't
ruled on that field in this pass, and any existing determination is left alone.

**Evidence Requirement**

A determination that asserts a fact has to say where the fact came from. The
save is rejected — with **nothing** written — if you:

- mark a field **Verified** or **Sources conflict** with neither a source link nor a note
- mark a field **Verified** without entering a value (the error points you at "Not publicly documented")

The whole submission succeeds or fails together, so a person is never left
with values saved but their evidence lost.

**Completion Gate**

"Complete Demographic Research" stays disabled until every field **this
assignment requires** that applies to this person has a *settled*
determination — Verified or Not publicly documented. **Sources conflict does
not settle a field**; it is an escalation, and it keeps the person short of
complete. Fields outside the assignment's scope never block completion, and
neither do detail fields that don't apply. The page and the queue both name
exactly which fields are outstanding.

**Scoped assignments.** An admin can narrow a task to a subset of fields —
often just race and gender. When they do, the page says which fields the task
covers and every row is badged **required** or **optional**. The optional rows
stay fully editable: a researcher who spots a date of birth while sourcing race
should record it, it just won't hold up the assignment.

Finishing a narrowed task does **not** mark the person demographically
complete — their other fields genuinely haven't been researched, so they stay
*In progress* and remain findable in the admin filters. The completion message
spells this out: *"Demographic research completed for Gender and Race /
ethnicity. 6 other fields on this person remain unresearched."*

**Workflow:**
1. Open `/demographics` and click Start on an assigned person
2. Work down the form, using the sourcing panel on the right
3. For each required field: enter a value and mark it **Verified** with a source, or mark it **Not publicly documented**, or flag **Sources conflict**
4. Click "Save Progress" (as often as you like — the banner tells you what still needs a determination)
5. When every required field is settled, click "Complete Demographic Research"

---

## Verifier Features

**Workspace:** `/verification`
**Role:** Can be researcher or admin

### 1. Verification Dashboard
**Path:** `/verification`

Overview of verification tasks (both data_validation and
secondary_verification). Each row is styled by task type: validation rows
(purple, "N accounts to verify") vs secondary rows (red, "N accounts
flagged for re-review").

**Shows:**
- Pending verification assignments (count)
- In-progress (count)
- Completed (count)
- Recent activities
- Accounts needing secondary verification

### 1b. Verification Queue
**Path:** `/verification/queue`

The queue page splits the two task types into separate sections —
**Data Validation** (`#validation`) and **Secondary Verification**
(`#secondary`) — with per-type pending counts in the stats row.

**Canonical task vocabulary** (used everywhere: sidebar, dashboards, queues,
guides): **Data Collection** (blue), **Data Validation** (purple),
**Secondary Verification** (red) — always presented in that workflow order.
The researcher-layout sidebar uses the single-word forms **Collection /
Validation / Verification** top-to-bottom, each with its own count badge
(blue / purple / red); the latter two link to the queue section anchors.
Page headings and cards use the full names. Start buttons follow the same
naming: "Start Collection", "Start Validation", "Start Review".

---

### 2. Review Assignments
**Path:** `/verification/assignments`

List of accounts to verify.

**Capabilities:**
- Filter by status
- View researcher who entered data
- Start/complete verification

---

### 3. Verify Social Media Accounts
**Path:** `/verification/accounts/:id`

Core verification workflow.

**For Each Account:**

1. **Show Researcher's Entry**
   - Researcher-entered URL
   - Researcher-entered handle
   - Researcher notes
   - Date entered

2. **Show Previous Data** (if exists)
   - URL from before (if this was previously verified)
   - When it was last verified
   - Who verified it

3. **Verification Actions**
   - **Verify** → Approve as-is (verified = true)
   - **Verify & Revise** → Update URL/handle, then verify
   - **Reject** → Mark as not found / incorrect
   - **Mark Not Found** → Overwrite as not found
   - **Reset** → Clear entry, return to not_started

4. **Add Verification Notes**
   - Explain your verification decision
   - Flag issues or concerns

**Key Features:**
- View version history (all previous changes via PaperTrail)
- Compare researcher entry vs previous data
- Easy platform validation
- Add detailed notes

**Auto-Secondary-Verification:**
- If verifier modifies previously-verified data → auto-flag person for secondary verification
- Secondary verification assignment created automatically

---

### 4. Verification Queue
**Path:** `/verification/queue`

Linear queue of accounts to verify.

**Shows:**
- Accounts in order
- Filter options
- Progress through queue

---

### 5. Secondary Verification
**Path:** `/verification`

Additional review for modified accounts.

**Workflow:**
1. Original data entered by researcher
2. Verified by verifier
3. Later, account modified by verifier (URL changed, handle updated)
4. Secondary verification assignment created
5. Verifier (or admin) reviews again to confirm change is correct

**Use Case:** Preventing accidental corruption of verified data.

---

## Admin Features

**Workspace:** `/admin`
**Role:** admin only

### 1. Admin Dashboard
**Path:** `/admin`

System overview and key metrics.

**Shows:**
- Total people, candidates, offices, districts
- Social media accounts (verified vs unverified)
- Junkipedia sync status
- User activity
- Pending assignments
- Recent data changes

---

### 2. Manage People
**Path:** `/admin/people`

Full CRUD on candidates and officeholders.

**Capabilities:**
- Search by name
- Create new person
- Edit person info (name, party, location, bio, etc.)
- Assign researchers to collect social media data
- Bulk-assign researchers to multiple people
- Pre-populate social media account stubs
- View all associated candidates, offices, social accounts
- Delete people (with cascade)

**Bulk Operations:**
- Select multiple people
- Create assignments for each to specific researcher
- Auto-create social media account stubs for new people

---

### 3. Manage Social Media Accounts
**Path:** `/admin/social_media_accounts`

Full CRUD on social media accounts.

**Capabilities:**
- Create accounts for people
- Edit URL, handle, platform, channel type
- Filter by:
  - Platform (Facebook, Twitter, etc.)
  - Status (not_started, entered, verified, etc.)
  - Verification (verified vs unverified)
  - Junkipedia sync status
- View complete version history (all edits)
- Manual verification controls
- Deactivate/activate accounts
- View research and verification timeline

---

### 4. Create & Manage Elections
**Path:** `/admin/elections`

Full CRUD on elections, ballots, and contests.

**Capabilities:**
- Create elections (primaries, generals, special)
- **Add ballots from the election page** — an "Add ballots" panel find-or-creates ballots for the election (idempotent, auto-linked). For primaries it pre-selects the parties that candidates run under but which lack a ballot, so you can fill coverage gaps in one click.
- Create contests (races) with a **search-as-you-type office picker** covering every office in the database (no longer a capped list); party is chosen from the shared party vocabulary.
- Filter the **Ballots** list by state, year (fixed), and party
- Add candidates to contests
- Set election outcomes
- View full election tree

**Structure:**
```
Election (e.g., "2026 Election")
  └── Ballot (e.g., "NY 2026 Primary", "NY 2026 General")
      └── Contests (e.g., "Governor", "U.S. Senate")
          └── Candidates (people running)
```

---

### 5. Manage Offices & Districts
**Path:** `/admin/offices`, `/admin/districts`

Manage government positions and electoral districts.

**Offices:**
- Create office positions
- Set level (federal, state, local)
- Set branch (legislative, executive, judicial)
- Link to districts and bodies
- View current office holders

**Districts:**
- Create electoral districts
- Link to state
- Set type (congressional, state legislative, local)
- Add offices

**Navigation across records:** every admin list (districts, offices, contests, ballots, elections) supports filtering by its key attributes and displays the related records inline; list rows and detail pages link to their related records (contest → office/district/ballot/election, office → district, ballot → election, etc.) so you can move through the data model directly.

---

### 6. Manage Parties
**Path:** `/admin/parties`

Create and edit political parties.

**Capabilities:**
- Create party
- Set name, abbreviation, ideology
- View affiliated people
- Edit party info

---

### 7. Manage Users
**Path:** `/admin/users`

User administration and access control.

**Capabilities:**
- Create new users (researchers, verifiers, admins)
- Send invitations via email
- Generate shareable invitation links
- Resend invitations
- Edit user info (name, email, role, cohort)
- Reset password
- View user activity (last login, sign-in count)
- **Deactivate / reactivate** users, individually or a whole cohort at once
- Delete users (rarely the right move — see below)
- **Impersonate users** (for debugging)
- Send task reminders

**Role Assignment:**
- **admin** — Full system access
- **researcher** — Data entry workspace
- **verifier** — Verification workspace (can also be combined with researcher)

#### Deactivating researchers

Researchers come and go in cohorts. **Deactivate, don't delete.** A deactivated
user keeps every record they entered or verified attributed to them; they just
stop appearing anywhere a person is being chosen, and they can no longer sign
in — including any session they already had open. Deleting a researcher who has
done real work fails outright (their entered/verified records reference them),
and the app now says so and points at deactivation instead.

- The user list **defaults to Active**, with Deactivated / All toggles and a count on each.
- A **Cohort** label (free text, e.g. "Fall 2026") groups a batch. Tick a group and use **Deactivate selected** to retire the whole cohort in one action. Your own account is always left active.
- Deactivating someone with open assignments warns you how many are now **stranded**; those rows are flagged in the list so they can be reassigned.
- **Reassign** an assignment from `/admin/assignments/:id` → *Reassign / Edit*. The dropdown offers active researchers plus the current holder, so a deactivated assignee is visible rather than silently swapped out.
- Reminder-email and impersonate buttons disappear for deactivated users — neither does anything useful for someone who can't sign in.

Every picker is filtered to active researchers: the assignment builder, the
per-person assign form, and bulk assign. The server refuses a deactivated
assignee on all three paths (and on `POST /api/people/bulk_assign`) in case a
stale form posts one anyway.

---

### 8. Assign Researchers to People
**Path:** `/admin/people/:id` or bulk form

Assign data collection tasks.

**Workflow:**
1. Select person
2. Select researcher(s) to assign
3. System creates Assignment record
4. Researcher sees task in their dashboard
5. Researcher enters data
6. Verifier reviews
7. Admin marks assignment complete or creates secondary verification task

**Bulk Assignment:**
1. Go to `/admin/people` and select multiple people
2. Click "Bulk Assign"
3. Select researcher
4. System creates assignment for each person

**Task Types:** the assignment builder (`/admin/assignments/new`) offers four
cards — Data Collection, Data Validation, Secondary Verification, and
**Demographic Research** ("Research and source candidate demographics", teal).

**Fields to research.** Selecting Demographic Research reveals a field picker
with a checkbox per demographic field and quick presets (*All fields*, *Race &
gender*, *Identity*). Ticking a subset narrows the task: it completes once
those fields are settled. Leaving everything unticked requires all core fields,
which is the default. The whole batch created in one submission shares the same
field list. See the completion-gate note above for why a narrowed task
deliberately leaves the person at *In progress*.

**Finding people who need demographic research.** The person finder has a
**Demographic Data** dropdown filtering on two deliberately independent axes:

| Filter | Options | Answers |
|--------|---------|---------|
| **Review status** | Not started / In progress / Complete / Not yet complete | Has anyone worked this person? |
| **Data present** | Has any demographic data / Has none at all / Missing at least one required field / All required fields have a value | Is there a value in the column at all? |
| **Missing a specific field** | Any single demographic field | Who has no date of birth? |
| **Sources conflict** | checkbox | Who has a field a researcher flagged as disputed? |

Presence and review are different things, and the most useful population is
usually the *intersection*: **"has imported values, but nobody ever checked
them"** — Data present = *Has any demographic data* plus Review status
= *Not started*. On the 2026 candidate pool that finds ~1,905 of 2,627 people.

⚠️ Use *Has any demographic data*, not *All required fields have a value*, for
that recipe. Most demographic columns are new and empty for every existing
person, so *All required fields* matches nobody until researchers have worked
through a batch. There are also
**No Demographic Research** / **Has Demographic Research** options in the
assignment-status filter for people without or with an existing task.

**Coverage badge.** Every person row in the finder shows two signals side by
side: an `n/8` count of how many required demographic fields have a **value**,
and a **DR** review pill — grey (not started), teal ◐ (in progress), green ✓
(complete). Filled-but-unreviewed rows are exactly the population these
assignments exist to work through.

The dropdown previously labelled "Demographics" — which only ever held State
and Party — is now called **Location & Party**.

---

### 9. Junkipedia Integration Dashboard
**Path:** `/admin/junkipedia`

Manage Junkipedia sync of verified social media accounts.

**Overview Stats:**
- Total Junkipedia-eligible accounts
- Pending queue (ready to sync)
- Enqueued (sent to Junkipedia, awaiting ID)
- Synced (have channel IDs)
- Errored (sync failed)

**Features:**
1. **Manual Queue**
   - Single account: Click "Enqueue" to send to Junkipedia
   - All pending: Click "Enqueue All" bulk operation

2. **Manual Resolve**
   - Single account: Click "Resolve" to look up channel ID
   - All unresolved: Click "Resolve All" bulk operation
   - Preflight: Test before running bulk

3. **Error Handling**
   - View last error for failed accounts
   - Retry individual accounts
   - Bulk retry operation

4. **Manual Overrides**
   - Manually set account's Junkipedia channel ID
   - Useful for fixing sync errors

**Under the Hood:**
- Enqueue calls `JunkipediaService.enqueue_channel(url)`
- Resolve calls `JunkipediaService.search_channel(handle, platform:)`
- Respects Junkipedia rate limits
- Auto-retry with exponential backoff

---

### 10. Analytics Dashboard
**Path:** `/admin/visits`

User behavior and page view analytics.

**Shows:**
- Page views over time
- User visits
- Popular pages
- User sessions
- Geographic information (IP)

**Powered by:** Ahoy analytics gem

---

### 11. Data Import & Export
**Path:** Command line (rake tasks)

Bulk data operations.

**Commands:**
```bash
# 2026 candidate CSV import
bin/rails import:clean_candidates_2026_<batch>
bin/rails import:candidates_2026_<batch>

# Junkipedia bulk operations
bin/rails junkipedia:match_pending
```

---

### 12. Manage Bodies & Offices
**Path:** `/admin/bodies`

Manage governmental bodies (Congress, state legislatures, city councils, etc.).

**Capabilities:**
- Create body (name, level, branch)
- Create sub-bodies (e.g., committees under Congress)
- Link offices to body
- View current members
- Manage hierarchy

---

### 13. API Token Management
**Path:** `/admin/api_tokens`

Create and revoke bearer tokens for the public read API (`/api/v1`) — the external, token-authenticated counterpart to the internal `/api`.

**Capabilities:**
- Create a token per consumer service; the plaintext token is shown once, at creation, and never again
- Monitor last-used time and active/revoked status per token
- Revoke a token — consumers using it get `401` immediately; other tokens are unaffected

---

## Audit & Transparency

### Version History
Every change to social media accounts is tracked via PaperTrail.

**Available for:**
- SocialMediaAccount — all create/update/delete

**Shows:**
- Change timestamp
- What changed (before/after values)
- Who made the change (user email)
- Change type (create, update, delete)

**Access:**
- Verifier: Can see version history when reviewing
- Admin: Can see all versions via account detail page

---

### Audit Trail
User tracking on all data entry and verification.

**Tracked:**
- Researcher who entered data (entered_by, entered_at)
- Verifier who approved (verified_by, verified_at)
- Assignment workflow (created_by, timestamps)
- Verification notes

---

## Summary of Workflows

### Researcher Workflow

```
1. Open /researcher
2. See pending assignments
3. Click assignment → view person + accounts
4. For each account:
   a. Search for social media handle
   b. Click "Found" and enter URL + handle
   c. OR click "Not Found"
   d. OR click "Skip" if unsure
5. Complete assignment
6. Verifier reviews your work
```

### Verifier Workflow

```
1. Open /verification
2. See pending verification tasks
3. Click account to review
4. Compare researcher entry vs previous data
5. Either:
   a. Click "Verify" (approve as-is)
   b. Click "Verify & Revise" (fix URL/handle, then verify)
   c. Click "Reject" (mark as not found / incorrect)
6. If verified: Account auto-queues to Junkipedia
7. If data modified: Secondary verification auto-created
```

### Demographic Research Workflow

```
1. Open /demographics
2. See assigned people with an n/n "determined" progress bar
3. Click Start → two-column research page
4. For each required field, using the sourcing panel on the right:
   a. Enter a value + source/note → "Verified"
   b. OR "Not publicly documented" (a real answer — blank is not)
   c. OR "Sources conflict" (escalation; does NOT settle the field)
5. Save Progress (whole person saves at once; all-or-nothing)
6. When every required field is settled → "Complete Demographic Research"
```

### Admin Workflow

```
1. Open /admin
2. Manage elections, people, offices
3. Create assignments (assign people to researchers)
4. Monitor researcher progress via assignments list
5. Monitor Junkipedia sync via dashboard
6. Manage users (invitations, roles)
7. View analytics
```

---

## Key Features by Use Case

| Use Case | Feature | Path |
|----------|---------|------|
| Find a candidate | Search People | `/people` |
| See election results | View Elections/Contests | `/elections`, `/contests` |
| Understand structure | Browse Offices/Bodies/Districts | `/offices`, `/bodies`, `/districts` |
| Research handles | Researcher Dashboard | `/researcher` |
| Verify entries | Verification Dashboard | `/verification` |
| Source a candidate's demographics | Demographic Research | `/demographics` |
| Manage system | Admin Dashboard | `/admin` |
| Monitor Junkipedia | Junkipedia Dashboard | `/admin/junkipedia` |
| Track changes | View version history | Any account detail (admin/verification) |

