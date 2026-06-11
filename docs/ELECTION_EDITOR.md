# Election Editor

Spreadsheet-style bulk candidate entry for a single election: create, review, and edit
candidates — with party, outcome, demographics, and one social handle per platform —
in a flat grid. Built for fast first-pass data entry before the full handle
collection/verification workflow runs.

**Status: functional end-to-end** (load → edit → save → reload), server-tested.

---

## Where everything lives

| Piece | Path |
|---|---|
| Page (grid) | `GET /admin/elections/:id/editor` |
| Controller | `app/controllers/admin/election_editor_controller.rb` |
| Save service | `app/services/election_editor_save.rb` |
| View | `app/views/admin/election_editor/show.html.erb` |
| Layout (chromeless) | `app/views/layouts/election_editor.html.erb` |
| JS grid | `app/javascript/controllers/election_editor_controller.js` (Stimulus) |
| Routes | `config/routes.rb` → `admin` namespace, `election_editor` block |

Entry points: "Editor" link on `/admin/elections` rows and the election show page.

## Endpoints

All admin-only (`Admin::BaseController` → `require_admin`).

| Route | Purpose |
|---|---|
| `GET  .../editor` | Full page. **All data embedded as JSON** in the page (election, contests grouped by ballot, parties, platforms, gender/race vocab, candidate rows with socials) — no fetch on load. |
| `POST .../editor/save` | Bulk upsert. Body: `{rows: [...], deletedCandidateIds: [...]}`. Returns per-row results keyed by client row key. |
| `GET  .../editor/people?q=` | Person typeahead (links rows to existing Person records; returns their socials for prefill). |
| `GET  .../editor/offices?q=` | Office typeahead for the new-contest dialog (scoped to the election's state). |
| `POST .../editor/contests` | Find-or-create ballot (state/date/type/party) + contest for an office. |

## Save semantics (`ElectionEditorSave`)

One transaction **per row** — a bad row reports errors without losing the rest.

Per row:
1. **Person** — `personId` present → load + update (name/gender/race); absent → create
   (`state_of_residence` defaults from the election). The typeahead is the dup guard;
   no fuzzy matching happens on save.
2. **Candidate** — `find_or_initialize_by(person, contest)` (matches the DB unique
   index), sets `outcome` (default `pending`), `party_at_time` (party name string),
   `incumbent`. Contest must belong to this election.
3. **Socials** — one cell per platform, accepts `handle`, `@handle`, or full URL
   (normalized both ways: handle ⇄ canonical URL via per-platform templates):
   - no account + value → create (`channel_type: Campaign`, `research_status: entered`,
     `entered_by`/`entered_at` stamped, **`verified: false`** — never triggers the
     Junkipedia auto-enqueue hook)
   - account + changed value → update; if it was verified → `verified: false`,
     `research_status: revised` + warning (existing re-verification flow)
   - account + cleared value → destroy **only if unverified**; verified accounts are
     never destroyed from the grid (warning returned, cell restored client-side)

Deletions remove the **candidacy only** — person and social accounts are kept.

Response per row: `{key, ok, candidateId, personId, socials: {Platform: {accountId, handle, url, verified}}, errors, warnings}` — the grid binds new ids so re-saving is idempotent.

## Grid features (JS)

- Flat table: status dot · Contest (grouped dropdown) · First/Last · Party · Incumbent ·
  Outcome · Gender · Race · 11 platform columns · delete. Sticky header + sticky first
  four columns; rows render via one `innerHTML` pass + event delegation (fast at scale).
- **Dirty tracking** per row via baseline snapshots: blue=new, amber=modified,
  green=just saved, red=error (tooltip carries messages), gray=clean. Save button shows
  pending count; `beforeunload` guard; toast feedback.
- **Person typeahead** on name cells (new rows only): linking fills demographics +
  existing socials (with accountIds, verified flags) for review; shows
  "already in this election" badge.
- **Social cells**: show handle (URL in tooltip), accept pasted URLs, charset warning
  styling, green ✓ on verified accounts.
- **Keyboard**: Enter/Shift+Enter move down/up a column, Enter on last row adds a row,
  ⌘S/Ctrl+S saves, Esc closes the typeahead.
- **Filter bar**: contest dropdown + name search (client-side); new rows inherit the
  filtered contest.
- **New contest dialog**: office typeahead + party select (required for primaries);
  creates the ballot if needed and refreshes every contest dropdown in place.

## Testing

Service tested end-to-end via `rails runner` in a rolled-back transaction (new
person/candidate/socials with all three input forms; idempotent re-save; clear-destroys-
unverified; verified-clear refused; verified-edit → revised; per-row validation errors;
existing-candidate edit; delete keeps person). Re-run pattern: see git history for the
runner script, or test in browser at `/admin/elections/22/editor` (SD 2026 primary,
2 contests, 3 candidates).

## Known limitations / future work

- One social account shown per platform (Campaign > Official Office > Personal priority);
  people with multiple accounts per platform edit the priority one.
- No middle name / suffix columns (full name visible in typeahead results).
- No row virtualization — fine for hundreds of rows; revisit past ~1k.
- No multi-cell paste from Excel (deliberate: this is the clean-entry UI; CSV import
  pipeline handles bulk spreadsheets).
- The generic `/api/*` controllers (earlier scaffold) have schema drift and are not used
  by the editor — see note in `docs/API_PLAN.md`.
