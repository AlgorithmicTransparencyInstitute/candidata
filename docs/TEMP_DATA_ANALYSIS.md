# Temp Data Analysis Report

**Date:** February 4, 2026  
**Status:** Pending decision on merge strategy

## Overview

This document summarizes the analysis of temporary staging tables (`temp_people` and `temp_accounts`) containing 2024 election cycle data, compared against the main application tables (`people` and `social_media_accounts`).

## Data Sources

### Temp Tables (Pre-Election 2024 Data)
- **TempPerson**: 17,909 records
- **TempAccount**: 64,837 records
- **Source breakdown**: Federal (2,598 people) + State (15,311 people)
- **Loaded**: February 3, 2026

### Main Tables (Post-Election 2025 Data)
- **Person**: 42,725 records
- **SocialMediaAccount**: 31,788 records
- **Contains**: 19,090 officeholders with 2025 start dates (including 119th Congress)

---

## Key Finding: Main DB is More Current

The main database has already been updated with **post-election 2025 data**, while the temp tables contain **pre-election 2024 candidate data**. This makes most of the temp data stale or superseded.

### Evidence
- Main DB has Andy Kim as **U.S. Senator** (won 2024 election)
- Temp data has Andy Kim as **U.S. Representative** (his previous role)
- Main DB has 15 Senators and 82 Representatives with 2025 start dates

---

## UUID Overlap Analysis

| Category | Count |
|----------|-------|
| TempPerson unique UUIDs | 17,629 |
| Main People UUIDs | 42,725 |
| **Overlap (in both)** | 8,619 |
| Only in Temp (new) | 9,010 |
| Only in Main | 34,106 |

---

## "New" Records Analysis (9,010 records)

### By Election Status
| Category | Count | Notes |
|----------|-------|-------|
| 2024 Office Holders | 114 | Mostly outgoing members |
| General Election Winners | 56 | |
| Incumbents | 431 | |
| **Lost Election** | 1,799 | Candidates who ran and lost |
| Unknown Status | 6,738 | Mostly candidates with no outcome recorded |

### By Source
| Source | Count |
|--------|-------|
| State | 7,062 |
| Federal | 1,952 |

### Duplicate Check
Of the 9,010 "new" records:
- **654 match existing people by name** (likely duplicates with different UUIDs, or different people with same name)
- **8,341 truly new** (mostly losing 2024 candidates)

### Sample "New" Records (2024 Office Holders)
These are actually **outgoing Congress members**, not new officials:
- Abigail Spanberger (VA) - Did not run for re-election
- Anna Eshoo (CA) - Retired
- Barbara Lee (CA) - Ran for Senate, lost primary
- Ben Cardin (MD) - Retired
- Andy Kim (NJ) - **Already in main DB as Senator**

---

## Overlapping Records Analysis (8,619 records)

### Field-by-Field Comparison

| Field | Same Value | Temp Has, Main Missing | Main Has, Temp Missing | Conflicts | Both Missing |
|-------|------------|------------------------|------------------------|-----------|--------------|
| **race** | 0 | **445** | 0 | 0 | 8,174 |
| **gender** | 0 | **446** | 0 | 0 | 8,173 |
| **photo_url** | 7,678 | 22 | 111 | 433 | 375 |
| **website_official** | 8,220 | 0 | 355 | 41 | 3 |

### Merge Opportunity
- **race**: Can fill in 445 missing values
- **gender**: Can fill in 446 missing values
- **photo_url**: 22 can be filled, but 433 have conflicts (different URLs)

---

## Social Media Accounts Analysis

### TempAccount Summary
| Metric | Value |
|--------|-------|
| Total records | 64,837 |
| With URL | 39,751 |
| Unique URLs | 39,079 |

### Platform Breakdown
| Platform | Count |
|----------|-------|
| Facebook | 17,157 |
| Twitter | 13,518 |
| Instagram | 13,019 |
| YouTube | 11,787 |
| TikTok | 3,277 |
| TruthSocial | 903 |
| Gettr | 901 |
| Rumble | 894 |
| Telegram | 888 |
| Threads | 209 |

### Channel Type Breakdown
| Type | Count | Percentage |
|------|-------|------------|
| Campaign Account | 50,826 | 78% |
| Official Office Account | 11,886 | 18% |
| Personal Account | 1,947 | 3% |

### URL Overlap with Main DB
| Category | Count |
|----------|-------|
| Unique URLs in Temp | 39,079 |
| Unique URLs in Main | 21,868 |
| **Already exist (overlap)** | 7,607 |
| **New URLs to add** | 31,472 |

### Person Matching Challenge
From a sample of 5,000 accounts:
- Matched to existing Person: 1,364 (27%)
- Could not match: 3,636 (73%)

Many unmatched accounts belong to people in TempPerson who aren't in the main People table (mostly losing candidates).

---

## Recommendations

### Option 1: Minimal Merge (Recommended)
Only merge data that fills gaps in existing records:
- Race data for 445 people
- Gender data for 446 people
- Skip new people (mostly stale or losing candidates)
- Skip most accounts (many for people not in DB)

### Option 2: Skip Entirely
Since main DB is more current, the temp data may not add significant value.

### Option 3: Full Historical Import
If tracking all 2024 candidates (including losers) is valuable:
- Import all new people from temp
- Import all accounts
- Would add ~8,000+ candidate records

---

## Merge Task Location

A rake task has been prepared at:
```
lib/tasks/merge_temp_data.rake
```

Tasks available:
- `rails merge:people` - Merge temp_people into People
- `rails merge:accounts` - Merge temp_accounts into SocialMediaAccounts
- `rails merge:all` - Run both in sequence

**Note:** The task should be updated based on the chosen merge strategy before running.

---

## Next Steps

1. Decide on merge strategy (minimal, skip, or full)
2. Update merge task if needed
3. Run merge locally and verify
4. Deploy to Heroku and run in production
5. Clean up temp tables after successful merge
