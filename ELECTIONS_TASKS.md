# Elections Import & Management Tasks

## Overview

This document describes the rake tasks for managing elections data in production and development.

## Quick Start (Production)

**For first-time setup or after updating the CSV:**

```bash
# On Heroku
heroku run bin/rails elections:setup -a candidata

# Locally
bin/rails elections:setup
```

This single command will:
1. Import/update all elections from the CSV file
2. Automatically link existing ballots to their elections
3. Provide a summary report

## Available Tasks

### 1. `elections:setup` (RECOMMENDED)

**Full automated setup** - Imports elections and links ballots in one command.

```bash
bin/rails elections:setup
```

**What it does:**
- Imports elections from `data/2026 Election Calendar - clean_state_election_dates.csv`
- Links all existing ballots to their corresponding elections
- Provides comprehensive summary with statistics
- Shows any ballots that couldn't be linked (and why)

**Safe to run multiple times:** Yes - fully idempotent

**Use this when:**
- Setting up elections for the first time in production
- After updating the CSV with new/changed election dates
- After adding new ballots that need to be linked

---

### 2. `import:elections`

**Import elections only** - Does NOT link ballots.

```bash
bin/rails import:elections
```

**What it does:**
- Reads `data/2026 Election Calendar - clean_state_election_dates.csv`
- Creates new elections or updates existing ones (by state + type + year)
- Updates dates and registration deadlines

**Safe to run multiple times:** Yes - uses `find_or_initialize_by`

**Use this when:**
- You only want to update election dates without touching ballots
- Testing CSV changes before linking

**Output example:**
```
✅ Created: KY Primary - May 19, 2026
🔄 Updated: TX Primary - March 03, 2026
```

---

### 3. `elections:link_ballots`

**Link ballots only** - Does NOT import elections.

```bash
bin/rails elections:link_ballots
```

**What it does:**
- Finds all ballots where `election_id` is NULL
- Matches each ballot to an election by: state, election_type, year
- Links matched ballots (sets `election_id`)
- Reports ballots that couldn't be matched

**Safe to run multiple times:** Yes - only processes unlinked ballots

**Use this when:**
- New ballots were added and need to be linked
- Elections were just imported and ballots need linking
- You want to see which ballots don't have matching elections

---

### 4. `elections:rebuild` (DESTRUCTIVE)

**Complete reset** - Deletes all elections and re-imports everything.

```bash
bin/rails elections:rebuild
```

⚠️ **WARNING:** This will:
- Delete ALL election records
- Unlink ALL ballots (sets election_id to NULL)
- Re-import from CSV
- Re-link all ballots

**Requires confirmation:** Yes - prompts before proceeding

**Use this when:**
- You need a clean slate (rare)
- Testing the full import process
- Recovering from data corruption

**DO NOT USE** for normal updates - use `elections:setup` instead.

---

## Data File Requirements

**File location:** `data/2026 Election Calendar - clean_state_election_dates.csv`

**Required columns:**
- `State` - Full state name (e.g., "Kentucky", "Texas")
- `Election Date` - Format: M/D/YYYY (e.g., "5/19/2026")
- `Filing Deadline` - Format: MM/DD/YYYY (e.g., "01/09/2026") - optional

**Example:**
```csv
State,Ballotpedia Page,State Page,Election Date,Filing Deadline
Kentucky,https://...,https://...,5/19/2026,01/09/2026
Texas,https://...,https://...,3/3/2026,12/08/2025
```

## Production Deployment Checklist

When deploying to production for the first time:

- [ ] Ensure CSV file is in `data/` directory and committed
- [ ] Run database migrations: `heroku run bin/rails db:migrate -a candidata`
- [ ] Run elections setup: `heroku run bin/rails elections:setup -a candidata`
- [ ] Verify in admin: Visit `/admin/elections` and check data
- [ ] Verify on frontend: Visit `/elections` and test links

## Updating Election Data

### Scenario 1: Changing an election date

1. Edit the CSV file with new date(s)
2. Run: `bin/rails elections:setup`
3. ✅ Elections will be updated, ballots remain linked

### Scenario 2: Adding a new state's election

1. Add new row to CSV
2. Run: `bin/rails elections:setup`
3. ✅ New election created, existing data unchanged

### Scenario 3: New ballots added after elections imported

1. Ballots created (through admin or import)
2. Run: `bin/rails elections:link_ballots`
3. ✅ New ballots linked automatically

## Troubleshooting

### "No election found for: TX primary 2026"

**Problem:** Ballot exists but no matching election

**Solution:**
- Check if election exists in CSV for that state/type/year
- Run `bin/rails import:elections` to import missing election
- Run `bin/rails elections:link_ballots` to link the ballot

### "State not found: Kentcky"

**Problem:** Typo in CSV state name

**Solution:**
- Fix the typo in the CSV file
- Re-run `bin/rails import:elections`

### Ballots showing wrong election

**Problem:** Ballot linked to incorrect election

**Solution:**
```ruby
# In Rails console
ballot = Ballot.find(123)
ballot.update(election_id: correct_election_id)
```

Or unlink and re-link:
```bash
# Unlink specific ballot
bin/rails runner "Ballot.find(123).update(election_id: nil)"

# Re-link
bin/rails elections:link_ballots
```

## Database Schema

### Elections Table
```ruby
create_table :elections do |t|
  t.string :state              # State abbreviation (e.g., "KY")
  t.date :date                 # Election day
  t.string :election_type      # "primary", "general", "special"
  t.integer :year              # Election year
  t.date :registration_deadline
  t.date :early_voting_start
  t.date :early_voting_end
  t.string :name               # Optional custom name
  t.timestamps
end
```

### Ballots → Elections Relationship
```ruby
# Ballot model
belongs_to :election, optional: true

# Election model
has_many :ballots, dependent: :nullify
```

**Matching logic:**
```ruby
Election.find_by(
  state: ballot.state,
  election_type: ballot.election_type,
  year: ballot.year
)
```

## Task Dependencies

```
elections:setup
├── import:elections (step 1)
└── elections:link_ballots (step 2)

elections:rebuild
├── Delete all elections
├── Unlink all ballots
└── elections:setup
    ├── import:elections
    └── elections:link_ballots
```

## Notes

- All tasks are **idempotent** - safe to run multiple times
- Tasks use `find_or_initialize_by` to avoid duplicates
- Elections are uniquely identified by: state + election_type + year
- The `elections:setup` task is the **recommended production command**
- CSV file must be present in `data/` directory for imports
