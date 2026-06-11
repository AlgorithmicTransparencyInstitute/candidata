# Candidata Internal API Plan

Design document for internal API endpoints supporting the React frontend and future public API.

---

## API Architecture

### Workspace-Scoped Endpoints

All APIs are scoped to specific workspaces:

- `/api/admin/*` — Admin workspace APIs (full CRUD)
- `/api/researcher/*` — Researcher workspace APIs (data entry)
- `/api/verification/*` — Verification workspace APIs (review & approve)
- `/api/public/*` — Public-facing APIs (eventually)

### Authentication

All endpoints require authentication via session cookie or Bearer token (future).

**Current:** Devise session-based
**Future:** JWT Bearer tokens for public API

### Response Format

All endpoints return JSON.

**Success Response (200, 201, etc.):**
```json
{
  "data": { /* resource(s) */ },
  "meta": { /* pagination, counts, etc. */ }
}
```

**Error Response (4xx, 5xx):**
```json
{
  "error": "Error message",
  "errors": { /* field-specific errors */ },
  "code": "ERROR_CODE"
}
```

---

## Core Resource APIs

### People API

#### List People
```
GET /api/admin/people
Query Params:
  - query (string) - Full-text search
  - state (string) - Filter by state
  - party_id (integer) - Filter by party
  - status (string) - all, candidates, officeholders
  - page (integer) - Pagination
  - per_page (integer) - Page size

Response:
  {
    "data": [
      {
        "id": 123,
        "first_name": "John",
        "last_name": "Doe",
        "full_name": "John Doe",
        "state_of_residence": "NY",
        "primary_party": { "id": 1, "name": "Democratic" },
        "needs_secondary_verification": false,
        "current_offices": [
          { "id": 1, "category": "U.S. Senator" }
        ],
        "social_media_accounts_count": 11,
        "candidates_count": 3
      }
    ],
    "meta": {
      "total": 44142,
      "page": 1,
      "per_page": 20,
      "total_pages": 2208
    }
  }
```

#### Get Person Detail
```
GET /api/admin/people/:id

Response:
  {
    "data": {
      "id": 123,
      "first_name": "John",
      "last_name": "Doe",
      "middle_name": "Michael",
      "suffix": null,
      "full_name": "John Michael Doe",
      "gender": "Male",
      "date_of_birth": "1965-03-15",
      "place_of_birth": "New York, NY",
      "bio": "...",
      "website": "https://...",
      "state_of_residence": "NY",
      "person_uuid": "...",
      "airtable_id": "...",
      "needs_secondary_verification": false,
      "primary_party": {
        "id": 1,
        "name": "Democratic",
        "abbreviation": "D"
      },
      "parties": [
        { "id": 1, "name": "Democratic", "is_primary": true },
        { "id": 2, "name": "Working Families", "is_primary": false }
      ],
      "current_offices": [
        {
          "id": 1,
          "category": "U.S. Senator",
          "state": "NY",
          "officeholder_id": 456,
          "start_date": "2021-01-03",
          "end_date": null
        }
      ],
      "former_offices": [
        {
          "id": 2,
          "category": "U.S. Representative",
          "state": "NY",
          "start_date": "2011-01-03",
          "end_date": "2021-01-03"
        }
      ],
      "candidates": [
        {
          "id": 789,
          "contest_id": 1,
          "contest_name": "NY U.S. Senate 2024 General",
          "outcome": "won",
          "tally": 3450000,
          "incumbent": true
        }
      ],
      "social_media_accounts": [
        {
          "id": 1,
          "platform": "Twitter",
          "handle": "johndoe",
          "url": "https://twitter.com/johndoe",
          "channel_type": "Official Office",
          "verified": true,
          "verified_at": "2024-06-01T10:00:00Z"
        }
      ],
      "assignments": [
        {
          "id": 1,
          "user_id": 10,
          "assignment_type": "data_collection",
          "status": "completed",
          "started_at": "2024-06-01T10:00:00Z",
          "completed_at": "2024-06-02T10:00:00Z"
        }
      ]
    }
  }
```

#### Create Person
```
POST /api/admin/people

Body:
  {
    "person": {
      "first_name": "Jane",
      "last_name": "Smith",
      "middle_name": "Marie",
      "suffix": null,
      "gender": "Female",
      "date_of_birth": "1970-05-20",
      "place_of_birth": "Chicago, IL",
      "state_of_residence": "IL",
      "website": "https://...",
      "bio": "...",
      "primary_party_id": 1,
      "person_uuid": null,
      "airtable_id": null
    }
  }

Response: 201 Created
  { "data": { /* new person */ } }
```

#### Update Person
```
PATCH /api/admin/people/:id

Body: { "person": { /* partial fields */ } }

Response: 200 OK
  { "data": { /* updated person */ } }
```

#### Delete Person
```
DELETE /api/admin/people/:id

Response: 204 No Content
```

#### Bulk Assign Researchers
```
POST /api/admin/people/:id/bulk_assign

Body:
  {
    "assignment": {
      "user_id": 5,
      "assignment_type": "data_collection",
      "notes": "Find social media handles for 2026 campaign"
    }
  }

Response: 201 Created
  {
    "data": {
      "id": 123,
      "assignment_type": "data_collection",
      "user_id": 5,
      "person_id": 456,
      "status": "pending"
    }
  }
```

---

### Social Media Accounts API

#### List Accounts (per Person)
```
GET /api/researcher/people/:person_id/accounts
Query Params:
  - platform (string) - Filter by platform
  - status (string) - Filter by research_status
  - channel_type (string) - Filter by channel_type
  - page, per_page

Response:
  {
    "data": [
      {
        "id": 1,
        "person_id": 123,
        "platform": "Twitter",
        "handle": null,
        "url": null,
        "channel_type": "Campaign",
        "research_status": "not_started",
        "verified": false,
        "account_inactive": false,
        "pre_populated": true,
        "entered_by": null,
        "verified_by": null,
        "version_count": 0,
        "junkipedia_eligible": false
      }
    ],
    "meta": { "total": 11 }
  }
```

#### Get Account Detail
```
GET /api/researcher/accounts/:id

Response:
  {
    "data": {
      "id": 1,
      "person_id": 123,
      "person_name": "John Doe",
      "platform": "Twitter",
      "handle": "johndoe",
      "url": "https://twitter.com/johndoe",
      "channel_type": "Campaign",
      "research_status": "entered",
      "verified": false,
      "account_inactive": false,
      "entered_by": { "id": 5, "email": "researcher@example.com" },
      "entered_at": "2024-06-01T10:00:00Z",
      "verified_by": null,
      "verification_notes": null,
      "needs_secondary_verification": false,
      "previous_url": "https://twitter.com/johndoe_old", // if exists
      "version_count": 2,
      "junkipedia_channel_id": null,
      "junkipedia_sync_status": "pending",
      "junkipedia_enqueued_at": null,
      "versions": [ // PaperTrail history
        {
          "event": "update",
          "changed_at": "2024-06-01T15:00:00Z",
          "changed_by": "researcher@example.com",
          "changes": { "url": ["...", "..."], "handle": ["...", "..."] }
        }
      ]
    }
  }
```

#### Mark Account as Entered (Researcher)
```
POST /api/researcher/accounts/:id/mark_entered

Body:
  {
    "account": {
      "url": "https://twitter.com/johndoe",
      "handle": "johndoe"
    }
  }

Response: 200 OK
  { "data": { /* updated account */ } }
```

#### Mark Account as Not Found (Researcher)
```
POST /api/researcher/accounts/:id/mark_not_found

Response: 200 OK
  { "data": { /* updated account */ } }
```

#### Verify Account (Verifier)
```
POST /api/verification/accounts/:id/verify

Body:
  {
    "account": {
      "verification_notes": "Confirmed via campaign website"
    }
  }

Response: 200 OK
  { "data": { /* updated account */ } }

Side Effect: If verified, triggers EnqueueJunkipediaChannelJob
```

#### Verify & Revise (Verifier can update data while verifying)
```
POST /api/verification/accounts/:id/verify_with_changes

Body:
  {
    "account": {
      "url": "https://twitter.com/johndoe_updated",
      "handle": "johndoe_updated",
      "verification_notes": "Corrected handle from campaign website"
    }
  }

Response: 200 OK
  { "data": { /* updated account */ } }

Note: If modifying previously verified data, auto-flags for secondary verification
```

#### Reject Account (Verifier)
```
POST /api/verification/accounts/:id/reject

Body:
  {
    "account": {
      "verification_notes": "Account does not exist"
    }
  }

Response: 200 OK
  { "data": { /* updated account */ } }
```

#### Reset Account Status
```
POST /api/verification/accounts/:id/reset_status

Response: 200 OK
  { "data": { /* updated account */ } }
```

---

### Assignments API

#### List Assignments (Researcher)
```
GET /api/researcher/assignments
Query Params:
  - status (string) - pending, in_progress, completed
  - page, per_page

Response:
  {
    "data": [
      {
        "id": 1,
        "person_id": 123,
        "person_name": "John Doe",
        "assignment_type": "data_collection",
        "status": "in_progress",
        "notes": "Find social media handles",
        "started_at": "2024-06-01T10:00:00Z",
        "completed_at": null,
        "accounts_to_research": 11,
        "accounts_entered": 8,
        "accounts_pending": 3
      }
    ],
    "meta": { "total": 5 }
  }
```

#### Get Assignment Detail
```
GET /api/researcher/assignments/:id

Response:
  {
    "data": {
      "id": 1,
      "person_id": 123,
      "person": {
        "id": 123,
        "first_name": "John",
        "last_name": "Doe",
        "full_name": "John Doe"
      },
      "assignment_type": "data_collection",
      "status": "in_progress",
      "notes": "Find social media handles for 2026 campaign",
      "started_at": "2024-06-01T10:00:00Z",
      "completed_at": null,
      "accounts": [
        {
          "id": 1,
          "platform": "Twitter",
          "status": "entered",
          "progress": "8 of 11"
        }
      ]
    }
  }
```

#### Start Assignment
```
POST /api/researcher/assignments/:id/start

Response: 200 OK
  { "data": { "status": "in_progress", "started_at": "..." } }
```

#### Complete Assignment
```
POST /api/researcher/assignments/:id/complete

Response: 200 OK
  { "data": { "status": "completed", "completed_at": "..." } }
```

#### Reopen Assignment
```
POST /api/researcher/assignments/:id/reopen

Response: 200 OK
  { "data": { "status": "pending", "completed_at": null } }
```

---

### Elections & Contests API

#### List Elections
```
GET /api/public/elections
Query Params:
  - year (integer)
  - state (string)
  - page, per_page

Response:
  {
    "data": [
      {
        "id": 1,
        "year": 2026,
        "election_type": "primary",
        "ballots_count": 56,
        "description": "2026 Primary Elections"
      }
    ]
  }
```

#### Get Election Detail
```
GET /api/public/elections/:id

Response:
  {
    "data": {
      "id": 1,
      "year": 2026,
      "election_type": "primary",
      "ballots": [
        {
          "id": 1,
          "state": "NY",
          "ballot_type": "primary",
          "ballot_date": "2026-04-28",
          "contests_count": 15
        }
      ]
    }
  }
```

#### Get Contest Detail
```
GET /api/public/contests/:id

Response:
  {
    "data": {
      "id": 1,
      "office_id": 100,
      "office_name": "U.S. Senator",
      "ballot_id": 50,
      "contest_type": "primary",
      "total_votes": 1000000,
      "candidates": [
        {
          "id": 1,
          "person_id": 123,
          "person_name": "John Doe",
          "outcome": "won",
          "tally": 450000,
          "incumbent": false
        }
      ]
    }
  }
```

---

### Search API

#### Global Search
```
GET /api/public/search
Query Params:
  - q (string) - Search query
  - type (string) - people, offices, elections, all
  - page, per_page

Response:
  {
    "data": {
      "people": [ /* matching people */ ],
      "offices": [ /* matching offices */ ],
      "elections": [ /* matching elections */ ]
    },
    "meta": { "total": 42 }
  }
```

---

### Junkipedia API

#### Get Junkipedia Status
```
GET /api/admin/junkipedia/status

Response:
  {
    "data": {
      "total_eligible": 55813,
      "pending_queue": 1200,
      "enqueued": 1000,
      "synced": 52000,
      "errored": 613,
      "rate_limit": {
        "remaining": 4000,
        "reset_at": "2024-06-15T10:00:00Z"
      }
    }
  }
```

#### Enqueue Account for Junkipedia
```
POST /api/admin/social_media_accounts/:id/enqueue_junkipedia

Response: 200 OK
  { "data": { "junkipedia_enqueued_at": "..." } }
```

#### Resolve Junkipedia Channel ID
```
POST /api/admin/social_media_accounts/:id/resolve_junkipedia

Response: 200 OK
  { "data": { "junkipedia_channel_id": "...", "junkipedia_id_collected_at": "..." } }
```

#### Bulk Enqueue
```
POST /api/admin/junkipedia/bulk_enqueue

Body:
  {
    "account_ids": [1, 2, 3, ...] // Optional; if omitted, all pending
  }

Response: 200 OK
  {
    "data": {
      "queued": 1200,
      "skipped": 50,
      "errors": 10
    }
  }
```

#### Bulk Resolve
```
POST /api/admin/junkipedia/bulk_resolve

Body:
  {
    "account_ids": [1, 2, 3, ...] // Optional; if omitted, all unresolved
  }

Response: 200 OK
  {
    "data": {
      "resolved": 800,
      "failed": 100,
      "rate_limited": 0
    }
  }
```

---

## Error Handling

### Standard Error Responses

**Unauthorized (401)**
```json
{
  "error": "Unauthorized",
  "code": "UNAUTHORIZED"
}
```

**Forbidden (403)**
```json
{
  "error": "Forbidden",
  "code": "FORBIDDEN"
}
```

**Validation Error (422)**
```json
{
  "error": "Validation failed",
  "code": "VALIDATION_ERROR",
  "errors": {
    "email": ["has already been taken"],
    "password": ["is too short (minimum is 8 characters)"]
  }
}
```

**Not Found (404)**
```json
{
  "error": "Resource not found",
  "code": "NOT_FOUND"
}
```

**Server Error (500)**
```json
{
  "error": "Internal server error",
  "code": "INTERNAL_ERROR"
}
```

---

## Pagination

All list endpoints support cursor or offset-based pagination.

**Request:**
```
GET /api/admin/people?page=2&per_page=20
```

**Response:**
```json
{
  "data": [ /* results */ ],
  "meta": {
    "total": 44142,
    "page": 2,
    "per_page": 20,
    "total_pages": 2208,
    "has_next_page": true,
    "has_previous_page": true,
    "next_page": 3,
    "previous_page": 1
  }
}
```

---

## Rate Limiting

All endpoints subject to rate limiting (future).

**Headers:**
```
X-RateLimit-Limit: 5000
X-RateLimit-Remaining: 4999
X-RateLimit-Reset: 1434949200
```

---

## Implementation Roadmap

### Phase 1: Admin APIs (High Priority)
- [x] People CRUD
- [x] Social media accounts CRUD
- [x] Assignments CRUD
- [x] Elections/Ballots/Contests CRUD
- [x] Users CRUD
- [x] Junkipedia management

### Phase 2: Researcher/Verification APIs (Medium Priority)
- [ ] Assignments list & detail
- [ ] Account data entry (mark_entered, mark_not_found)
- [ ] Account verification (verify, reject, revise)

### Phase 3: Public APIs (Future)
- [ ] Search
- [ ] Elections browsing
- [ ] People browsing
- [ ] Offices browsing

### Phase 4: Advanced Features (Future)
- [ ] Real-time updates via WebSocket
- [ ] Bulk operations with job status tracking
- [ ] Advanced filtering & sorting
- [ ] CSV export

