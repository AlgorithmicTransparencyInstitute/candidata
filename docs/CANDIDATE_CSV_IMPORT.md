# 2026 Candidate CSV Import Pipeline

## Purpose

Candidata tracks candidates for the 2026 election cycle. Researchers compile candidate data into spreadsheets (exported as CSVs) organized by state. This pipeline cleans the raw CSV data into a standardized format and imports it into the production database, creating Person, Ballot, Contest, Candidate, and SocialMediaAccount records.

## How It Works

### 1. Raw Data Collection

Researchers create spreadsheets with one row per candidate. Each CSV has these columns:

```
CandidateName, Incumbent, Withdrew/Withdrawn, Party, Office, District,
Race, Gender, Website, Twitter, Facebook, Instagram, YouTube, TikTok, BlueSky, Notes
```

Raw CSVs are placed in `data/2026_states/<batch-folder>/` (e.g., `april7-states/`, `april15-states/`).

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

- Democratic, Republican, Libertarian, Independent, Nonpartisan, Unaffiliated
- Working Class, Legal Marijuana NOW, No Party Preference, Peace and Freedom

To add a new party, update the `PARTIES` constant in both `app/models/ballot.rb` and `app/models/contest.rb`, and add a mapping in the cleaning script.

## Key Files

| File | Purpose |
|------|---------|
| `lib/scripts/clean_april7_states_2026.rb` | Cleaner for batch 3 (GA, MT, NE, PA) |
| `lib/scripts/clean_april15_states_2026.rb` | Cleaner for batch 4 (CA, NV, NJ, OR) |
| `lib/scripts/clean_new_states_2026.rb` | Cleaner for batch 2 (AL, IN, LA, MD, NM, OH, WV) |
| `lib/tasks/import_april7_states_2026.rake` | Rake tasks for batch 3 |
| `lib/tasks/import_april15_states_2026.rake` | Rake tasks for batch 4 |
| `lib/tasks/import_new_states_2026.rake` | Rake tasks for batch 2 |
| `lib/importers/enhanced_candidate_2026_importer.rb` | Core import logic (shared across batches) |
| `data/2026_states/cleaned/` | Cleaned CSV output (committed to repo) |
| `data/2026_states/*/` | Raw CSV input by batch |

## Adding a New Batch

1. Place raw CSVs in `data/2026_states/<new-batch-folder>/`
2. Copy an existing cleaning script and update `STATE_MAP` and any new party/race/office mappings
3. Create a new rake task file following the existing pattern
4. Run the cleaner, then test locally against a fresh production database pull
5. Commit cleaned CSVs + scripts + rake task, push to Heroku, run on production
