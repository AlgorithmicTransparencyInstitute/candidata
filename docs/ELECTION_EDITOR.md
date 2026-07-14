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
| CSV import preview service | `app/services/election_editor_csv_import.rb` |
| Shared handle/URL logic | `app/services/social_handles.rb` |
| Shared per-platform account picker | `app/services/election_editor_socials.rb` |
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
editor/ImportCsvDialog.tsx # CSV upload → mapping/preview → stage rows into grid
```

## Endpoints (admin-only)

| Route | Purpose |
|---|---|
| `GET .../editor` | Page with **all data embedded as JSON** (election, contests grouped by ballot, parties, platform list, gender/race vocab, candidate rows with socials) — no fetch on load. |
| `POST .../editor/save` | Bulk upsert `{rows, deletedCandidateIds}` → per-row results keyed by client row key. |
| `GET .../editor/people?q=` | Person typeahead (dup guard; returns demographics + socials for prefill). |
| `GET .../editor/offices?q=` | Office search (shared `Office.search_text`). Defaults to the election's state; falls back to all states when `all=1` or there's no in-state match (`allStates` flag in the response). Returns `state` + `searchLabel` for cross-state disambiguation. |
| `POST .../editor/contests` | Find-or-create party ballot (state/date/type from the election) + contest. |
| `POST .../editor/import` | **Read-only CSV preview**: parse, map columns, validate values, match offices/contests/people. Body: `{csv, mapping?}` (mapping = `{header: fieldId}` overrides). 2 MB / 2,000-row cap. Writes nothing — the dialog creates contests via `POST .../contests` and stages rows for the normal save. |

## Save semantics (`ElectionEditorSave`)

One transaction **per row** — a bad row reports errors without losing the sheet.

1. **Person** — `personId` present → update names (first/middle/last/suffix),
   gender/race, and `website_campaign`; absent → create (`state_of_residence`
   from the election). `name_source` (the name string exactly as an import
   file had it) is **fill-if-blank only** — provenance is never overwritten.
   The typeahead is the dup guard; no fuzzy matching on save.
2. **Candidate** — `find_or_initialize_by(person, contest)` (DB unique index), sets
   `outcome` (default pending), `party_at_time`, `incumbent`. Contest must belong to the election.
   The outcome dropdown includes **"Advanced (unopposed)"** (`outcome: "advanced"`) for a
   candidate who advances to the general because their primary was cancelled/unopposed —
   stored value is `advanced`, which counts as a primary winner (see `Candidate::WINNING_OUTCOMES`).
3. **Socials** — one cell per platform; accepts `handle`, `@handle`, or full URL
   (normalized both directions via `SocialHandles`, which prefers `@segments`,
   knows per-platform path markers, and ignores subpage suffixes like
   `/reels/`, `/videos`; `facebook.com/profile.php?id=…` yields no handle):
   - no account + value → create (`Campaign` / `entered` / **unverified** — never triggers
     the Junkipedia auto-enqueue). Fills a blank pre-populated stub for that
     platform if one exists rather than duplicating.
   - **Placeholder slots**: after each saved row, `SocialMediaAccount.prepopulate_for_person!`
     gives the person the standard blank per-platform account slots (the 6
     `CORE_PLATFORMS`, `Campaign`/`pre_populated`) that the rest of the app creates
     on research assignment — so accounts later verified already have a row.
     Idempotent; the freshly-created stubs are bound back into the grid so a later
     edit fills them in place.

     Editor stubs are created as **`not_found`**, not `not_started`: the source
     data *was* consulted and listed no account for that platform. That is a claim
     a verifier can confirm, so the row shows up in the verification queue with a
     "Needs Verification" badge and a one-click verify (which sets `verified` with
     a blank URL — a confirmed absence). `not_started` would mean "nobody looked",
     which renders as an unbadged row that the queue neither counts nor blocks
     completion on. Stubs carry **no `entered_by`**, so `verifiable_by?` is true
     for everyone and the four-eyes rule never strands them. A researcher who
     wants to enter data anyway hits "Undo" on the row (`reset_status!`).

     Verified blank accounts are excluded from the public API (`verified_socials`
     requires a URL) and never reach Junkipedia (`junkipedia_eligible?` requires a
     URL).
   - account + **same handle** (case-, `@`- and URL-form-insensitive) → unchanged.
     Cosmetic URL variants (x.com vs twitter.com, `?lang=`, trailing slash) never
     unverify. A blank URL gets filled in; a real URL change applies only to
     unverified accounts. Re-sending an account's own exact URL when the stored
     handle is derived-data garbage (old extractor bugs like `"videos"`) repairs
     the handle without touching verification.
   - account + **different handle** → update; verified accounts get `verified: false` +
     `research_status: revised` + a warning (re-verification flow)
   - account + cleared → destroy **only if unverified**; verified accounts are never
     destroyed from the grid (warning, value restored)

Row deletion removes **only the candidacy** — person and socials are kept.

### Client save flow — reliability note

`EditorApp.save()` computes the list of rows to send (`valid`/`skipped`) and the
result counts (`saved`/`failed`/`warnings`) **synchronously** — from `rowsRef.current`
and the save response — *before* any `setRows`. Do **not** collect these by pushing into
an array inside a `setRows` updater: React may defer the updater, so the values are read
empty and the save silently no-ops (this was the "Save button does nothing / only one row
saves" bug). `setRows` is only ever used here for pure UI state (errors, applied results).
Covered by `spec/requests/election_editor_save_spec.rb` (server contract) — the client
timing itself has no unit harness, so keep the synchronous shape when editing `save()`.

## Grid features

- Flat table: status dot · contest (grouped dropdown) · first/middle/last name +
  suffix · party · incumbent · outcome · gender · race · campaign website ·
  11 platform columns · delete. Sticky header + the six leftmost columns
  (through suffix). Website writes `Person#website_campaign`.
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

## CSV import ("Import CSV" toolbar button)

Upload a spreadsheet of candidates and stage it into the grid. Design principle:
**the preview endpoint writes nothing** — all record creation flows through the
already-tested paths (`POST .../contests` for ballots+contests on confirm,
`ElectionEditorSave` when the user reviews the staged rows and hits Save).

Flow: pick file → server parses + auto-maps columns → dialog shows editable
column mapping, contest resolution list, and validation summary → confirm →
missing ballots/contests are created, rows land in the grid as unsaved (dirty)
rows → review → Save.

**Column mapping** (`ElectionEditorCsvImport::HEADER_ALIASES`): recognizes both
the cleaned-batch format (`candidate_name,is_incumbent,withdrew,party,office,
district,race,gender,twitter,…`) and the raw workbook exports
(`CandidateName`, `Primary contestant?`, bare `House`/`Senate` office names).
Unrecognized headers can be mapped manually in the dialog (re-previews live).
A name column (full or first+last) and Office are required; Party is required
for primaries.

**Validation / normalization**
- Party: `"Democrat"→"Democratic"`, `"GOP"→"Republican"`, trailing `" Party"`
  stripped (`"Unity Party"→"Unity"`), then snapped to `Party.ballot_vocabulary`
  (case-insensitive) so minor parties like `"Green"`/`"Conservative"` resolve
  automatically; must be in that vocabulary for a primary. Adding a `Party` row
  is now enough — no `PARTIES` code change needed.
- `withdrew` truthy → outcome `withdrawn`; rows can be skipped via a checkbox
  (default on). `Primary contestant? = No` on a primary imports the row with
  outcome **`advanced`** (unopposed — advances to the general); an explicit
  Outcome column always wins.
- Social/website cells: placeholder values researchers type (`x`, `n/a`,
  `none`, …) are treated as empty, as are `Not sure`-style race placeholders;
  URLs/handles pass through to save-time normalization.
- Wrong-state rows, unknown outcomes/genders, and in-file duplicates
  (same name + contest) are flagged per row.
- **DB-wins demographics**: for matched people, first/last come from the DB
  and middle/suffix/gender/race only fill blanks — a spreadsheet's vocabulary
  never overwrites curated values (merge rows apply the same blank-only rule
  client-side). Campaign website takes the CSV value (cycle-specific).
- `name_source` records the raw source name string on create / fill-if-blank.

**Contest matching** (per unique office+district+party group):
1. existing contest in this election → rows bind to it;
2. else a matching state `Office` → "will create contest" (federal shorthand:
   `U.S. House`/`House` + district → `U.S. Representative` seat `District N`,
   `Senate` → `U.S. Senator`; statewide + state-legislature title conventions);
   several textually identical offices (a state's two Senate seats) narrow via
   the election's existing contests, or via a linked incumbent's current
   `Officeholder` office (propagated to the other party's group);
3. else unresolved → inline office search in the dialog binds it manually
   (rows in unresolved groups are skipped).

**Person matching** — same policy as the batch importer: exact first+last
(case-insensitive) within the election's state; single match links (and
prefills demographics + socials with account bindings), incumbents may take
the first of several matches, otherwise ambiguity is a warning and the row
stays unlinked. A linked person already candidate in the same contest becomes
an **update** merged into their existing grid row (only CSV-provided values
overwrite).

**Verified-account protection**: a CSV social value whose handle *differs*
from the person's existing account is staged **unbound**, so save creates a
separate `Campaign` account instead of overwriting (the workbooks usually
carry campaign accounts while the DB holds verified official-office ones).

Caps: 2 MB file, 2,000 rows. See `spec/requests/election_editor_import_spec.rb`.

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
   note: the server already extracts canonical handles (`SocialHandles.handle_from_url`)
   — display can derive from `cell.url` vs `cell.handle` without new parsing.

3. **Multiple accounts per platform (Campaign / Official Office / Personal).**
   Current behavior (documented so the next pass starts informed):
   - *Loading*: `socials_map` (`ElectionEditorSocials.map`) shows ONE account per
     platform, picked **content-first** — an account with a handle/URL beats a
     blank pre-populated stub — then by channel priority Campaign > Official
     Office > Personal > nil. (Content-first stops a blank Campaign stub from
     shadowing a real handle on another channel.) Other accounts stay invisible.
   - *Creating*: handles entered in the grid create accounts with
     `channel_type: "Campaign"`.
   - *Editing*: edits apply to whichever account the cell is bound to (`accountId`).
   Needed: a design for displaying/editing more than one account per platform —
   options to consider: a channel-type row-expander per candidate, a badge/count on
   the cell with a popover editor, or a channel-type toggle on the toolbar that
   switches which account tier the whole grid shows.

4. **Collect user-testing feedback** and fold their feature requests into this list
   before scheduling the pass.

### Candidate-creation gaps (surfaced 2026-06-17 reviewing what "add a name" does)

Two creation paths exist. **Path 1** — type a name and pick a typeahead match: links
the existing Person (no dup), auto-fills gender/race/party into *empty* cells only, and
populates empty social cells from that person's real accounts (bound to account ids,
verified ✓ preserved). **Path 2** — type a name and never pick a suggestion: on save
the server creates a fresh Person (name + gender/race; `state_of_residence` from the
election), Candidate (`outcome` default "pending", party → `party_at_time`, incumbent),
and a `Campaign` social account per filled platform cell (unverified — no Junkipedia).
Gaps to decide on next pass:

5. **Duplicate risk (Path 2).** The typeahead is the ONLY dedup guard — there is no
   server-side name matching on save. Ignore the dropdown and you get a second
   "Tom Cotton". Consider: a soft on-save duplicate check/confirm, or a stronger
   "did you mean an existing person?" nudge. (Was a deliberate no-fuzzy-match choice;
   revisit now that real users are entering data.)

6. **No person↔party link.** Party only lands on the candidacy (`party_at_time`); the
   `PersonParty` association is never written, so an editor-created person shows no
   party on their profile page. Decide whether grid party entry should also set the
   person's primary party.

7. **Stubs are created for all 6 core platforms, on every saved row.** Including
   rows for people who already existed and were merely touched in the editor, and
   including platforms the source never covers. Every one becomes a `not_found` row
   a verifier must confirm — so a broad edit pass can inflate the verification
   queue. If that becomes noisy, scope stub creation to editor-*created* people, or
   to the platforms the import source actually had columns for.

8. **No assignments created.** Editor-entered people enter the verification pipeline
   only when an admin later assigns a data_validation task. Consider an optional
   "queue for verification" affordance from the editor.

## Known limitations / future work

- No row virtualization (fine to ~1k rows); no multi-cell Excel paste (the
  in-editor CSV import covers bulk spreadsheets).
