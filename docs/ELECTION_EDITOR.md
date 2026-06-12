# Election Editor

Spreadsheet-style bulk candidate entry for a single election: create, review, and edit
candidates — party, outcome, incumbent, demographics (gender/race), and one social
handle per platform — in one flat grid. Built for fast first-pass entry before the full
handle collection/verification workflow.

**Status: functional end-to-end, React-based.** Server save logic and page delivery are
integration-tested; the grid is the app's first React + shadcn-pattern feature.

---

## Architecture

| Piece | Path |
|---|---|
| Page | `GET /admin/elections/:id/editor` (chromeless layout) |
| Controller | `app/controllers/admin/election_editor_controller.rb` |
| Save service | `app/services/election_editor_save.rb` |
| View (mount point + grid CSS) | `app/views/admin/election_editor/show.html.erb` |
| Layout | `app/views/layouts/election_editor.html.erb` |
| **React app** | `app/javascript/react/` — entry `election_editor.tsx` |
| Built bundle (committed) | `app/assets/builds/election_editor.js` |

### React build pipeline

- **esbuild** bundles `app/javascript/react/election_editor.tsx` → `app/assets/builds/`
  (already linked in the Sprockets manifest). `yarn build` (minified) / `yarn build:watch`
  (dev; runs as the `js:` process in `Procfile.dev` under `bin/dev`).
- **TypeScript/TSX** with `@/` path alias (`tsconfig.json`); esbuild strips types (no typecheck step).
- **Tailwind v4** auto-scans `.tsx` — utility classes in React compile with zero config.
- **The bundle is committed to git** so Heroku deploys need no Node build step. After
  editing React code, run `yarn build` and commit the updated bundle.
- shadcn-pattern components in `app/javascript/react/components/ui/` (button, input,
  native-select, badge, dialog on Radix, toast) using `cn()` (clsx + tailwind-merge) and
  cva variants, styled to the app's existing palette. Grid cells use styled **native**
  inputs/selects for spreadsheet performance.

React layout within `app/javascript/react/`:
```
election_editor.tsx        # mount: reads #editor-data JSON, renders EditorApp
lib/utils.ts               # cn()
components/ui/*.tsx        # shadcn-pattern primitives
editor/types.ts            # payload/row/result types
editor/rows.ts             # row state, baseline-snapshot dirty tracking, save payloads
editor/api.ts              # fetch helpers with CSRF
editor/EditorApp.tsx       # toolbar, grid, save flow, keyboard nav, typeahead orchestration
editor/GridRow.tsx         # memoized row (re-renders only on its own edits)
editor/PersonTypeahead.tsx # floating person-match menu
editor/NewContestDialog.tsx# office search + party → create ballot/contest
```

## Endpoints (admin-only)

| Route | Purpose |
|---|---|
| `GET .../editor` | Page with **all data embedded as JSON** (election, contests grouped by ballot, parties, platform list, gender/race vocab, candidate rows with socials) — no fetch on load. |
| `POST .../editor/save` | Bulk upsert `{rows, deletedCandidateIds}` → per-row results keyed by client row key. |
| `GET .../editor/people?q=` | Person typeahead (dup guard; returns demographics + socials for prefill). |
| `GET .../editor/offices?q=` | Office search scoped to the election's state (new-contest dialog). |
| `POST .../editor/contests` | Find-or-create party ballot (state/date/type from the election) + contest. |

## Save semantics (`ElectionEditorSave`)

One transaction **per row** — a bad row reports errors without losing the sheet.

1. **Person** — `personId` present → update names/gender/race; absent → create
   (`state_of_residence` from the election). The typeahead is the dup guard; no fuzzy
   matching on save.
2. **Candidate** — `find_or_initialize_by(person, contest)` (DB unique index), sets
   `outcome` (default pending), `party_at_time`, `incumbent`. Contest must belong to the election.
3. **Socials** — one cell per platform; accepts `handle`, `@handle`, or full URL
   (normalized both directions via per-platform URL templates):
   - no account + value → create (`Campaign` / `entered` / **unverified** — never triggers
     the Junkipedia auto-enqueue)
   - account + changed value → update; verified accounts get `verified: false` +
     `research_status: revised` + a warning (re-verification flow)
   - account + cleared → destroy **only if unverified**; verified accounts are never
     destroyed from the grid (warning, value restored)

Row deletion removes **only the candidacy** — person and socials are kept.

## Grid features

- Flat table: status dot · contest (grouped dropdown) · first/last name · party ·
  incumbent · outcome · gender · race · 11 platform columns · delete. Sticky header +
  first four columns.
- Status dots: blue=new, amber=modified, green=just saved, red=error (messages in
  tooltip), gray=clean. Save button shows pending count; `beforeunload` guard; toasts.
- **Person typeahead** on name cells (new rows): links existing People, prefills
  demographics + socials, flags "already in this election".
- Social cells show the handle (URL in tooltip), accept pasted URLs, warn on unusual
  characters, mark verified accounts with ✓.
- Keyboard: Enter/Shift+Enter move down/up a column (skips filtered rows), Enter on the
  last row adds a row, ⌘S saves, Esc closes the typeahead.
- Contest filter + name search (client-side); new rows inherit the filtered contest.
- New-contest dialog (shadcn Dialog): office typeahead + party select; refreshes all
  contest dropdowns in place.

## Testing

- **Save service**: exercised via `rails runner` in a rolled-back transaction — create
  with all three social input forms, idempotent re-save, clear-destroys-unverified,
  verified-clear refused, verified-edit → revised, per-row validation errors,
  existing-candidate edit, delete keeps person.
- **Page delivery**: authenticated integration request asserts 200, mount node, embedded
  JSON payload, and that the digested bundle serves.
- Browser sanity check: `/admin/elections/31/editor` (UT 2026 primary — 16 contests,
  40 candidates) or any SD/small state for a lighter page.

## Next pass — TODOs (queued 2026-06-12, after first user testing round)

The tool is deployed and users are testing it. Collect their feedback before starting;
these are the known items from Cameron's first review:

1. **Cell readability.** Individual items (race, party, outcome, etc.) are hard to
   read at current sizing — improve visibility/typography of the dropdown cells
   (larger/darker text, possibly wider columns or higher-contrast selected values).

2. **Social cell display: truncate to the handle part.** Cells show the full URL but
   columns are too narrow to see the handle. Plan: display a truncated form that
   strips the platform root (e.g. `facebook.com/` → show `tomcottonar`,
   `youtube.com/@x` → `@x`), and reveal the full URL on click/focus for editing.
   The external-link icon already opens the real URL; keep that. Implementation
   note: the server already extracts canonical handles (`ElectionEditorSave#handle_from_url`)
   — display can derive from `cell.url` vs `cell.handle` without new parsing.

3. **Multiple accounts per platform (Campaign / Official Office / Personal).**
   Current behavior (documented so the next pass starts informed):
   - *Loading*: `socials_map` shows ONE account per platform, picked by channel-type
     priority Campaign > Official Office > Personal > nil; other accounts on that
     platform are invisible in the grid.
   - *Creating*: handles entered in the grid create accounts with
     `channel_type: "Campaign"`.
   - *Editing*: edits apply to whichever account the cell is bound to (`accountId`).
   Needed: a design for displaying/editing more than one account per platform —
   options to consider: a channel-type row-expander per candidate, a badge/count on
   the cell with a popover editor, or a channel-type toggle on the toolbar that
   switches which account tier the whole grid shows.

4. **Collect user-testing feedback** and fold their feature requests into this list
   before scheduling the pass.

## Known limitations / future work

- No middle name/suffix columns; no row virtualization (fine to ~1k rows); no
  multi-cell Excel paste (CSV import pipeline covers bulk spreadsheets).
