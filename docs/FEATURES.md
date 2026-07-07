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

Researcher overview and task management.

**Shows:**
- Pending assignments (how many)
- Currently in-progress assignment
- Completed assignments count
- Quick stats on work progress

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

## Verifier Features

**Workspace:** `/verification`
**Role:** Can be researcher or admin

### 1. Verification Dashboard
**Path:** `/verification`

Overview of verification tasks.

**Shows:**
- Pending verification assignments (count)
- In-progress (count)
- Completed (count)
- Recent activities
- Accounts needing secondary verification

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
- Create ballots (per state, per date)
- Create contests (races)
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
- Edit user info (name, email, role)
- Reset password
- View user activity (last login, sign-in count)
- Delete users
- **Impersonate users** (for debugging)
- Send task reminders

**Role Assignment:**
- **admin** — Full system access
- **researcher** — Data entry workspace
- **verifier** — Verification workspace (can also be combined with researcher)

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
| Manage system | Admin Dashboard | `/admin` |
| Monitor Junkipedia | Junkipedia Dashboard | `/admin/junkipedia` |
| Track changes | View version history | Any account detail (admin/verification) |

