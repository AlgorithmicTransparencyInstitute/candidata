# 2026 Candidate Management System - Implementation Plan

**Created:** February 4, 2026  
**Status:** Implementation Phase

## Overview

Build an authenticated admin/researcher interface for managing 2026 election candidates, their social media accounts, and verification workflows.

---

## Existing Infrastructure

### User Roles (Already Defined)
- **admin** - Full system access, can assign tasks
- **researcher** - Can assign tasks, primary data entry
- **researcher_assistant** - Data entry (scope TBD)

### Existing Models
- **Person** - Candidate/officeholder records
- **Contest** - Election contests (date, location, type, office_id, ballot_id)
- **Ballot** - Elections (state, date, election_type, year, name)
- **Candidate** - Links Person to Contest (outcome, tally, party_at_time, incumbent)
- **SocialMediaAccount** - Linked to Person (platform, channel_type, url, handle, status, verified, account_inactive)

### TempAccount Fields (Reference for New Schema)
- source_type, url, platform, channel_type, status
- state, office_name, level, office_category
- people_name, party_roll_up
- account_inactive, verified, raw_data

---

## Implementation Tasks

### Phase 1: Foundation (Audit Trail & Schema Updates)

- [ ] **1.1** Add `paper_trail` gem for version history tracking
- [ ] **1.2** Add audit fields to key models (created_by, updated_by)
- [ ] **1.3** Update SocialMediaAccount with additional fields from TempAccount schema
- [ ] **1.4** Create Assignment model for task management

### Phase 2: Assignment & Workflow System

- [ ] **2.1** Design Assignment model (user, assignable, task_type, status, due_date)
- [ ] **2.2** Create AssignmentBatch for bulk assignments
- [ ] **2.3** Build admin assignment interface
- [ ] **2.4** Create researcher task queue/dashboard

### Phase 3: Candidate Management (Admin)

- [ ] **3.1** Create 2026 ballots (primaries + general)
- [ ] **3.2** Build contest creation interface
- [ ] **3.3** Build candidate entry interface (link Person to Contest)
- [ ] **3.4** Handle incumbent detection (existing Person lookup)
- [ ] **3.5** Handle new person creation

### Phase 4: Social Media Account Entry (Researcher)

- [ ] **4.1** Researcher dashboard showing assigned people
- [ ] **4.2** Account entry form for each person
- [ ] **4.3** Support multiple accounts per person
- [ ] **4.4** Mark account as "not found" / "does not exist"
- [ ] **4.5** Submit for verification workflow

### Phase 5: Verification Workflow

- [ ] **5.1** Verification queue for assigned verifiers
- [ ] **5.2** Verification interface (confirm/reject/edit)
- [ ] **5.3** Track verification status per account
- [ ] **5.4** Handle disputes/re-verification

### Phase 6: Reporting & Admin Tools

- [ ] **6.1** Progress dashboard (accounts entered, verified, pending)
- [ ] **6.2** Researcher performance metrics
- [ ] **6.3** Export functionality
- [ ] **6.4** Bulk operations

### Phase 7: Documentation

- [ ] **7.1** Admin user guide
- [ ] **7.2** Researcher user guide
- [ ] **7.3** Verification workflow guide
- [ ] **7.4** System overview documentation

---

## Confirmed Requirements

### Workflow

1. **Assignment Granularity**: Admins assign **individual people** to researchers
2. **Verification Model**: Researchers cannot self-verify (different person must verify), but system allows admin exceptions when needed
3. **"Not Found" Handling**: Pre-create empty rows (one per platform per candidate). Researcher either enters account URL or marks "no account found". This records that someone looked.

### Data Scope

4. **Account Types**: 
   - Focus on **campaign accounts** for this exercise
   - Support personal accounts (can add later)
   - Incumbents' official accounts shown but not main focus

5. **Platform Scope (Core - Phase 1)**:
   - Facebook
   - X/Twitter  
   - Instagram
   - YouTube
   - TikTok
   - **BlueSky**
   
   Fringe platforms (Phase 2): TruthSocial, Gettr, Rumble, Telegram, Threads

### Access Control

6. **Roles**: Just **admin** and **researcher** (removed researcher_assistant)
7. **Permissions**:
   - Admins: Full access to everything
   - Researchers: Only see their assigned work

---

## Proposed Schema Changes

### New: Assignment Model
```ruby
create_table :assignments do |t|
  t.references :user, null: false, foreign_key: true  # Assigned to
  t.references :assigned_by, null: false, foreign_key: { to_table: :users }
  t.references :person, null: false, foreign_key: true  # Person to research
  t.string :task_type, null: false           # 'research', 'verification'
  t.string :status, default: 'pending'       # pending, in_progress, completed
  t.datetime :completed_at
  t.text :notes
  t.timestamps
end
```

### Updated: SocialMediaAccount
```ruby
# Add fields for workflow tracking
t.references :entered_by, foreign_key: { to_table: :users }
t.references :verified_by, foreign_key: { to_table: :users }
t.datetime :entered_at
t.datetime :verified_at
t.string :research_status    # not_started, entered, not_found, verified, rejected
t.text :verification_notes
t.boolean :pre_populated, default: false  # True if auto-created for research
```

### Core Platforms Constant
```ruby
SOCIAL_MEDIA_PLATFORMS = {
  core: %w[facebook twitter instagram youtube tiktok bluesky],
  fringe: %w[truthsocial gettr rumble telegram threads]
}.freeze
```

---

## Next Steps

1. ✅ Requirements confirmed
2. Add paper_trail gem for audit history
3. Create migrations for Assignment model and SocialMediaAccount updates
4. Build admin assignment interface
5. Build researcher dashboard and entry interface
6. Build verification workflow

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-04 | Initial plan created |
