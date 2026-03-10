# Candidata — Sprint Plan (2026-03-10)

## Phase 1: Environment Setup

- [x] **1.1 Sync code from GitHub** — Pull latest `main` from origin (also fixed .DS_Store gitignore)
- [x] **1.2 Pull production database** — Captured fresh backup (b003) and restored to local `candidata_development`

## Phase 2: Data Ingestion — 7 New States

- [ ] **2.1 Receive new state CSVs** — Get raw candidate/handle data for 7 new states from Cameron
- [ ] **2.2 Clean & normalize** — Run/update `lib/scripts/clean_2026_candidates.rb` to merge new states into `2026_candidates_cleaned.csv`
- [ ] **2.3 Validate data** — Spot-check cleaned output (column alignment, party names, office formats, handle formats)
- [ ] **2.4 Test import** — Run `bin/rails import:test_2026` with a small sample
- [ ] **2.5 Full import** — Run `bin/rails import:candidates_2026` to import all new candidates + social handles
- [ ] **2.6 Verify in app** — Confirm new people, candidates, and social media accounts appear correctly

## Phase 3: Features & Bugfixes

- [ ] **3.x** — Items TBD from user feedback list (Cameron to provide)

---

### Current State Reference

- **Heroku app**: `candidata` (PostgreSQL essential-0, 530 MB, PG 17.6)
- **Local DB version**: `20260211131957`
- **States already in cleaned CSV**: AR, IL, KY, MS, NC, TX (6 states)
- **Import pipeline**: Raw CSV → `clean_2026_candidates.rb` → cleaned CSV → `Importers::Candidate2026Importer`
