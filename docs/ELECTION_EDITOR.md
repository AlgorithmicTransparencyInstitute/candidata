# Election Editor

Work-in-progress bulk candidate entry interface for managing elections, contests, and candidates with integrated social media handles.

## Current Status (WIP)

**UI/UX:** ✅ Complete  
**API Integration:** ⏳ In Progress  
**Data Persistence:** ⏳ Pending  

---

## What's Been Built

### Architecture

- **Route:** `/admin/elections/:id/editor`
- **Controller:** `admin/elections_controller.rb` → `:editor` action
- **View:** `app/views/admin/elections/editor.html.erb`
- **Layout:** `app/views/layouts/election_editor.html.erb` (minimal, no site chrome)
- **JavaScript:** `app/javascript/controllers/election_editor_controller.js` (Stimulus controller)

### UI Components

**Spreadsheet Table:**
```
┌─────────┬────────┬─────────┬───────────┬──────────┬─────────┬───────────┬─────────────┐
│ Name    │ Party  │ Outcome │ Incumbent │ Facebook │ Twitter │ Instagram │ ... + 8 more│
├─────────┼────────┼─────────┼───────────┼──────────┼─────────┼───────────┼─────────────┤
│ [Input] │ [Drop] │ [Drop]  │ [Check]   │ [@input] │ [@input]│ [@input]  │ [@input]    │
├─────────┼────────┼─────────┼───────────┼──────────┼─────────┼───────────┼─────────────┤
│ [Input] │ [Drop] │ [Drop]  │ [Check]   │ [@input] │ [@input]│ [@input]  │ [@input]    │
└─────────┴────────┴─────────┴───────────┴──────────┴─────────┴───────────┴─────────────┘
```

**11 Social Media Platforms:**
- Facebook, Twitter, Instagram, YouTube, TikTok
- BlueSky, TruthSocial, Gettr, Rumble, Telegram, Threads

**Control Flow:**
1. **State Selector** → Choose state/jurisdiction
2. **Ballot Type Selector** → Choose primary/general/special/runoff
3. **Contest Selector** → Choose race (office/position)
4. **Spreadsheet Table** → Edit candidate details inline
5. **Add Row Button** → Add new candidate
6. **Delete Button** → Remove candidate from entry
7. **Save Button** → Submit all changes

### Input Types

| Column | Type | Component |
|--------|------|-----------|
| Name | Text | `<input type="text">` |
| Party | Select | `<select>` with all parties |
| Outcome | Select | Dropdown: Won/Lost/Pending/Withdrawn |
| Incumbent | Checkbox | `<input type="checkbox">` |
| Social Media | Text | `<input type="text">` with @handle placeholder |

---

## Current Functionality (Stimulus Controller)

### Working Features

✅ **Add Row**
- Click "+ Add Candidate Row" to add editable row
- Auto-focus on name field
- Placeholder disappears when first row added

✅ **Delete Row**
- Click "Delete" button on any row
- Confirmation dialog to prevent accidents
- Updates row count

✅ **Form Data Collection**
- Collects all field values from table
- Handles text inputs, dropdowns, checkboxes
- Maps social media handles to platform names
- Returns structured candidate object with nested socialMedia

✅ **Row Counter**
- Shows "X candidates" at bottom of table
- Updates when rows added/deleted

---

## What's Not Yet Done (Next Phase)

### 1. API Integration for Selections

**Status:** ⏳ Pending

**What's needed:**
```javascript
onContestChange(event) {
  const contestId = event.target.value
  
  // TODO: Fetch existing candidates from API
  // GET /api/contests/:id/candidates
  // Populate table with existing candidates
  
  // TODO: Pre-fill social media accounts for each candidate
  // GET /api/people/:person_id/social_media_accounts
}
```

**Endpoint to build:**
- `GET /api/contests/:id` — Return contest with candidates, people, social accounts pre-loaded

### 2. Save/Persist Data to Database

**Status:** ⏳ Pending

**What's needed:**
```javascript
async saveAll(event) {
  // TODO: For each candidate row:
  
  // If new candidate:
  //   POST /api/candidates
  //   POST /api/social_media_accounts (11 per candidate)
  
  // If existing candidate:
  //   PATCH /api/candidates/:id
  //   PATCH /api/social_media_accounts/:id (for each platform)
  
  // Return success/error feedback
}
```

**API Endpoints Needed:**
- `POST /api/candidates` — Create candidate
- `PATCH /api/candidates/:id` — Update candidate
- `POST /api/social_media_accounts` — Create account
- `PATCH /api/social_media_accounts/:id` — Update account

**Current Status:** API controllers exist but save logic not wired to Stimulus controller

### 3. Error Handling & Validation

**Status:** ⏳ Pending

**Needs:**
- Required field validation (name, party, outcome)
- Social media handle validation (must start with @, be valid format)
- API error feedback (show which rows failed, why)
- Duplicate candidate detection
- Loading state during save
- Success notification

### 4. Load Existing Candidates

**Status:** ⏳ Pending

**Needs:**
- When contest selected, fetch all candidates for that contest
- Populate table with existing data
- Mark rows with existing candidate IDs (not new-xxxxx)
- Fetch social media accounts per candidate
- Display existing handles in social media columns

**Implementation:**
```javascript
async loadCandidates(contestId) {
  const response = await fetch(`/api/contests/${contestId}`)
  const { data } = await response.json()
  
  // Clear table
  this.clearTable()
  
  // For each candidate in data:
  // - Clone row template
  // - Populate fields from candidate object
  // - Add social media handles from linked accounts
  // - Mark with candidate.id (not new-xxx)
}
```

### 5. Keyboard Shortcuts

**Status:** ⏳ Pending

**Nice-to-have:**
- `Tab` → Move to next field (already works in HTML)
- `Shift+Tab` → Move to previous field (already works)
- `Enter` in last column → Add new row
- `Cmd/Ctrl+S` → Save (prevent page unload)
- `Delete` key → Delete current row (risky, needs confirmation)

### 6. Performance Optimization

**Status:** ⏳ Pending

**For large contests (100+ candidates):**
- Virtualization (render only visible rows)
- Debounced saves (save as user types, not on every keystroke)
- Batch API requests (POST 50 candidates at once instead of 50 requests)

### 7. Social Media Handle Validation

**Status:** ⏳ Pending

**Needs:**
- Validate handle format per platform
  - Twitter/BlueSky: no @, alphanumeric + underscore
  - TikTok: alphanumeric + underscore, 2-24 chars
  - Instagram: alphanumeric + underscore + period, 1-30 chars
  - YouTube: can be channel name or ID
  - Telegram: alphanumeric + underscore, 5-32 chars
  - etc.
- Show validation error inline on blur
- Highlight invalid fields

---

## Data Model (What Gets Saved)

When user clicks "Save All Changes", the Stimulus controller collects:

```javascript
{
  candidates: [
    {
      id: null,                    // new row
      contest_id: 123,
      name: "Jane Smith",
      party_id: 1,
      outcome: "won",
      incumbent: true,
      socialMedia: {
        facebook: "janesmith",
        twitter: "jane_smith",
        instagram: "@janesmith",
        youtube: "JaneSmith",
        tiktok: "janesmith",
        bluesky: "jane.smith",
        truthsocial: "janesmith",
        gettr: "janesmith",
        rumble: "janesmith",
        telegram: "janesmith",
        threads: "janesmith"
      }
    }
  ]
}
```

**For each candidate, needs to:**
1. Find or create Person (by name)
2. Create/update Candidate (person + contest)
3. Create/update 11 SocialMediaAccount records (one per platform)

---

## File Structure

```
app/
├── views/
│   ├── layouts/
│   │   └── election_editor.html.erb          [Minimal layout, no site chrome]
│   └── admin/elections/
│       └── editor.html.erb                   [Spreadsheet table + selectors]
├── controllers/
│   └── admin/
│       └── elections_controller.rb           [editor action]
├── javascript/
│   └── controllers/
│       └── election_editor_controller.js     [Stimulus: add/delete/save]
```

---

## Next Steps (Recommended Order)

1. **Wire Selection to Load Data** (1-2 hours)
   - Implement `onContestChange` to fetch and populate existing candidates
   - Update loadCandidates() to create row elements from API response

2. **Implement Save to API** (1-2 hours)
   - Add fetch calls in `saveAll()` to POST/PATCH candidates and social media accounts
   - Add error handling and success feedback
   - Test with actual data persistence

3. **Add Validation** (1 hour)
   - Required field checks
   - Social media handle format validation
   - Show inline error messages

4. **Handle Existing Data** (30 min)
   - Differentiate between new rows (new-xxx) and existing (has ID)
   - Update PATCH vs POST logic

5. **Keyboard Shortcuts** (30 min)
   - Add key handlers for Tab, Enter, Cmd+S

6. **Performance** (2-3 hours, if needed)
   - Add virtualization for 100+ row contests
   - Batch saves

---

## Testing

**Manual Testing Checklist:**
- [ ] Navigate to `/admin/elections/1/editor`
- [ ] Select state, ballot type, contest from dropdowns
- [ ] Click "+ Add Candidate Row" — row appears, name field focused
- [ ] Enter candidate data across all columns
- [ ] Click "Delete" on a row — confirmation, row removed
- [ ] Add multiple rows, verify row count updates
- [ ] Click "Save All Changes" — data logs to console
- [ ] Refresh page — verify data persisted (once API wired)

---

## Related Documentation

- `docs/API_PLAN.md` — API endpoints (search for "elections", "candidates", "social_media_accounts")
- `docs/ARCHITECTURE.md` — Admin election controller details
- `docs/SCHEMA.md` — Candidate, SocialMediaAccount, Person models

