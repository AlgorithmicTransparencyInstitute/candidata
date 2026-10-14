# 2026 Candidate CSV Import Pipeline

## Purpose

Candidata tracks candidates for the 2026 election cycle. Researchers compile candidate data into spreadsheets (exported as CSVs) organized by state. This pipeline cleans the raw CSV data into a standardized format and imports it into the production database, creating Person, Ballot, Contest, Candidate, and SocialMediaAccount records.

## Source

The **canonical source** of 2026 primary spreadsheets is the [Primaries2026 Google Drive folder](https://drive.google.com/drive/folders/1aNZY0rWHRpwwAWMLsXtX0MOK-xBax_12) (owner: `mm11506@nyu.edu`). Each state has its own Excel workbook there. Export each workbook to CSV before placing it in `data/2026_states/<batch-folder>/` for cleaning.

Workflow: when new state data is ready, audit the Drive folder against `data/2026_states/cleaned/` to see which states have already been processed, then pull the missing ones.

## How It Works

### 1. Raw Data Collection

Researchers create spreadsheets with one row per candidate. Each CSV has these columns:

```
CandidateName, Incumbent, Withdrew/Withdrawn, Party, Office, District,
Race, Gender, Website, Twitter, Facebook, Instagram, YouTube, TikTok, BlueSky, Notes
```

Raw CSVs are placed in `data/2026_states/<batch-folder>/` (e.g., `april7-states/`, `april15-states/`). A given batch typically groups multiple states whose data became available together.

### 2. Cleaning

A per-batch Ruby script standardizes the raw data:

- **Names**: Strips quotes, "(Incumbent)" annotations
- **Parties**: Maps variations (e.g., "Democrat" → "Democratic", "R" → "Republican")
- **Offices**: Normalizes to "U.S. House" or "U.S. Senate"
- **Race/Gender**: Standardizes casing and variations (e.g., "white, non-Hispanic" → "White")
- **URLs**: Strips "99" placeholders, "N/A", "see notes" values
- **Incumbent/Withdrew**: Normalizes to "true"/"false"

Cleaned CSVs are written to `data/2026_states/cleaned/{STATE}_candidates_cleaned.csv`.

### 3. Import

The `EnhancedCandidate2026Importer` processes each cleaned CSV:

1. **Person**: Matches existing people by first/last name + state, or creates new records
2. **Ballot**: Creates per-state, per-party primary ballots (links to Election if one exists)
3. **Office**: Finds or creates U.S. House/Senate offices with district linkage
4. **Contest**: Creates primary contest records linking ballot + office + party
5. **Candidate**: Links person to contest with incumbent status and party-at-time
6. **Social Media**: Creates accounts with data from CSV, plus placeholder rows for platforms missing data (so researchers can fill them in later)

Withdrawn candidates are skipped during import (People are still created but no Candidate/Contest records).

The importer handles duplicate social media handles gracefully — if an existing officeholder already has a Twitter account with the same handle, it updates the existing record rather than creating a duplicate.

## Batch History

| Batch | Date | States | Candidates | Rake Task |
|-------|------|--------|------------|-----------|
| 1 | 2026-03 | TX, FL, NY + others | ~870 | `import:candidates_2026` |
| 2 | 2026-03 | AL, IN, LA, MD, NM, OH, WV | 204 | `import:candidates_2026_batch2` |
| 3 | 2026-04-08 | GA, MT, NE, PA | 192 | `import:candidates_2026_april7` |
| 4 | 2026-04-15 | CA, NV, NJ, OR | 430 | `import:candidates_2026_april15` |
| 5 | 2026-06-09 | IA, ME, ND, OK, SC, SD, UT, VA (Senate-only) | 168 | `import:candidates_2026_may` |

## Running an Import

```bash
# Step 1: Clean raw CSVs (generates cleaned files)
bin/rails import:clean_candidates_2026_april15

# Step 2: Import cleaned CSVs into database
bin/rails import:candidates_2026_april15

# Optional: Test with first state only
bin/rails import:test_candidates_2026_april15
```

## Supported Parties

The Ballot and Contest models validate party names. Currently supported:

- Democratic, Republican, Libertarian, Independent, Nonpartisan, Unaffiliated, Constitution, Forward
- Working Class, Legal Marijuana NOW, No Party Preference, Peace and Freedom, Independent American

To add a new party, **create a `Party` record** (its short label — the name minus a trailing `" Party"` — automatically joins `Party.ballot_vocabulary`, which the ballot/contest validations use), and add a mapping in the cleaning script if the source spelling differs. **Watch out:** the importer's outer `rescue => e` block swallows validation failures from missing parties (they're logged to `@stats[:errors]` rather than raised), so the import will appear to succeed while silently dropping candidates whose party isn't in the vocabulary. Cross-check candidate counts against cleaned-CSV counts after every import.

## Key Files

| File | Purpose |
|------|---------|
| `lib/scripts/clean_april7_states_2026.rb` | Cleaner for batch 3 (GA, MT, NE, PA) |
| `lib/scripts/clean_april15_states_2026.rb` | Cleaner for batch 4 (CA, NV, NJ, OR) |
| `lib/scripts/clean_may_states_2026.rb` | Cleaner for batch 5 (IA, ME, ND, OK, SC, SD, UT, VA-Senate) |
| `lib/scripts/clean_new_states_2026.rb` | Cleaner for batch 2 (AL, IN, LA, MD, NM, OH, WV) |
| `lib/tasks/import_april7_states_2026.rake` | Rake tasks for batch 3 |
| `lib/tasks/import_april15_states_2026.rake` | Rake tasks for batch 4 |
| `lib/tasks/import_may_states_2026.rake` | Rake tasks for batch 5 (includes Election-record pre-flight guard) |
| `lib/tasks/import_new_states_2026.rake` | Rake tasks for batch 2 |
| `lib/importers/enhanced_candidate_2026_importer.rb` | Core import logic (shared across batches) |
| `data/2026_states/cleaned/` | Cleaned CSV output (committed to repo) |
| `data/2026_states/*/` | Raw CSV input by batch |

## Adding a New Batch

1. **Audit the [Primaries2026 Drive folder](https://drive.google.com/drive/folders/1aNZY0rWHRpwwAWMLsXtX0MOK-xBax_12)** against `data/2026_states/cleaned/` to identify which states are not yet processed.
2. **Export Drive Excels to CSV** and place them in `data/2026_states/<new-batch-folder>/` — name the folder descriptively (e.g., `june-states/`).
3. **Refresh local DB from production** (`heroku pg:pull`) so testing happens against current prod state.
4. **Copy an existing cleaning script** from `lib/scripts/clean_*_states_2026.rb` and update `STATE_MAP` and any new party/race/office mappings.
5. **Create a new rake task file** under `lib/tasks/import_<batch>_states_2026.rake` following the existing pattern.
6. **Run the cleaner**, inspect the cleaned CSV, then **test the import locally** against the fresh production pull.
7. **Capture a production DB backup** (`heroku pg:backups:capture --app candidata`), commit cleaned CSVs + scripts + rake task, push to Heroku, run on production.

After the production import completes, the `SocialMediaAccount` after_commit hook auto-enqueues any **verified** handles to Junkipedia. (Imports typically create accounts as unverified pending researcher work, so the auto-sync fires later when the verification controller flips `verified` to true — not at import time.) See `docs/JUNKIPEDIA_INTEGRATION.md`.

## 2026 General Elections

General-election imports differ from the primary batches: there is no cleaning step, and the importer builds the whole record chain itself, because general elections didn't exist in the database before them.

### Governors (2026-10-14)

- **Source:** Google Sheet `2026_Gubernatorial_General_Election_Candidates_V3` (owner myra@ncoc.org), 133 candidates in 36 states. Committed as `data/2026_general/governors/governors_general_2026_v3.csv`.
- **Task:** `bin/rails import:governors_general_2026`. It is a **dry run by default** and prints one match decision per candidate. Use `APPLY=1 USER_EMAIL=<admin email>` to write.
- **Code:** `lib/importers/general_governor_2026_importer.rb`.
- **Creates per state:** an `Election` (general, 2026-11-03), a `Ballot` (general, no party), a `Contest` (general, `Governor of <State>`) and a `Candidate` per row. Everything is find-or-create.
- **Writes go through `ElectionEditorSave`**, so imported rows follow the election editor's rules exactly:
  - new social accounts are Campaign / `entered` / **unverified**, so nothing is sent to Junkipedia at import
  - verified accounts are never changed, except that a blank URL gets filled in
  - blank placeholder accounts are created for the six core platforms
  - every row can be edited at `/admin/elections/:id/editor`
- **Person matching**, in order:
  1. A row already imported (same source name on this contest) matches its existing person, so re-runs change nothing.
  2. Hand-reviewed `MATCH_OVERRIDES` (e.g. "Doug Jones" is **not** #192490, a Chambers County commissioner).
  3. `Incumbent` rows must match the state's current governor, otherwise the row is flagged.
  4. Otherwise, the same last name plus a compatible first name (with a nickname table) **in the same state**.
  5. Same-name records in other states are noted but never linked. A same-name record with **no** state is flagged ambiguous.

  The task refuses to write while any row is ambiguous.
- **Social accounts:** each sheet URL is checked against *all* of the person's accounts on that platform (any channel type, any stored handle form, or exact URL for handle-less Facebook `profile.php?id=` links). A channel already on file is reused, not duplicated. See GitHub issue #2 for why exact handle matching isn't enough.
- **Party labels:** a trailing " Party" is dropped ("Libertarian Party" → "Libertarian"). "No Party Affiliation" (FL) and "No Political Party" (NV) are kept whole. New people get a primary `PersonParty` when the label matches a `Party` row.
- **Result:** 43 candidates matched to existing people (all 17 incumbents matched their state's sitting governor), 90 new people, 387 social accounts created and 85 reused.

### U.S. House + Senate (2026-10-14)

- **Source:** the 2026 **primary** data already in the database. There is no CSV.
- **Task:** `bin/rails import:congress_general_2026`. It is a dry run by default (`APPLY=1` writes) and writes a review file, `tmp/congress_general_2026_review.csv`.
- **Code:** `lib/importers/general_congress_2026_builder.rb`.
- **Creates:**
  - a general `Election` and `Ballot` for every state (find-or-create; the 36 governor states already had them)
  - one general `Contest` per seat: 435 House and 35 Senate (33 class II seats plus the FL and OH specials)
- **Nominees carried:** each primary candidate with outcome `won` or `advanced` becomes a `pending` general candidate. Party comes from the primary contest, and the incumbent flag carries over. A fusion candidate (one person on several NY lines) becomes one candidacy under the major party.
- **Held for review, never guessed:**
  - `pending`/`unknown` primary results
  - two or more nominees from the same party. This is allowed only for CA/WA top-two, Alaska's top-four and independent-type labels.

  Each review seat is listed in the CSV. Researched answers go in `SEAT_RESOLUTIONS` (seat label → person ids), then re-run. The run is idempotent.
- **Primary data repairs** (made by the same run):
  - Senate offices are per sitting senator. The WY Republican primary was attached to Barrasso's seat, and the MA Independent/PSL entries to Warren's. Both now point at the seat that's up: Lummis's and Markey's.
  - The ND and SD at-large primaries used district-less duplicate offices (108563/108564). They now point at the real at-large offices.
  - IL office 108558 (no district) has one empty Democratic primary contest. It's ignored.
- **First run result:** 470 contests, 1,003 nominees carried, and 62 seats needing review (11 with no nominee, 15 held, 45 with an unresolved result).
