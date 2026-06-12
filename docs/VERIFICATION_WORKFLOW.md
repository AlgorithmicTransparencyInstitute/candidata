# Verification Workflow — Current State & Redesign Proposal

Written 2026-06-12 while investigating the **completion deadlock**: a verifier who adds
a new account during a validation task cannot complete the task, because the account
they added needs verification, and policy says they can't verify their own entry.

Everything in "Current state" below was read from the code and checked against
production data (fresh pull). This is what the system *actually does*, including the
parts that differ from what we believed.

---

## Current state

### Actors and task types

- **Roles** (`User::ROLES`): `admin`, `researcher`. Both can access the researcher and
  verification workspaces; admin additionally has `/admin`.
- **Assignment** (`task_type` × `status`): `data_collection` / `data_validation` /
  `secondary_verification`, each `pending → in_progress → completed`. Unique per
  `[user, person, task_type]`. Created by admins (`/admin/assignments/new`, with
  people filters; or per-person actions). Production right now: 1,272 completed
  validations, 62 active, **one `secondary_verification` assignment ever created
  (still pending)**.

### Account state machine (`SocialMediaAccount`)

`research_status`: `not_started → entered | not_found → verified | rejected | revised`
plus independent flags: `verified` (boolean), `researcher_verified` (researcher's own
"I checked this on Google" flag), `account_inactive`, `modified_during_validation`,
`needs_secondary_verification`, and `channel_type` (Campaign / Official Office / Personal).

Transitions (all in `SocialMediaAccount`):

| Method | Sets | Called from |
|---|---|---|
| `prepopulate_for_person!` | creates `not_started` Campaign stubs for 6 core platforms | admin assignment creation (data_collection only) |
| `mark_entered!(user, url:, handle:)` | `entered`, stamps `entered_by/at`; sets `modified_during_validation` if "modification" (see quirk #1) | researcher + verification workspaces |
| `mark_not_found!(user)` | `not_found`, clears url/handle; modification flag if it had data | both workspaces |
| `verify!(user, notes:)` | `verified` + `verified: true`, stamps `verified_by/at` → **triggers Junkipedia auto-enqueue** | verification workspace |
| `reject!(user, notes:)` | `rejected` | verification workspace |
| `revise!(user, …)` | `revised`, `verified: false` — "needs re-verification by someone else" | verification update when url/handle changed |
| `reset_status!` | back to `not_started` | both workspaces |
| `clear_secondary_verification!` | clears the two flags | `Person#clear_secondary_verification!` (no UI calls this today) |

Key scope: **`needs_verification` = status in `[entered, not_found, revised]`** — this
is the verification queue definition *and* the completion gate.

### The three workspaces

**Researcher** (`/researcher`, `Researcher::*`): works `data_collection` only
(`set_assignment` scopes to it). Shows **Campaign + core-platform** accounts. Complete
gate: zero `needs_research` AND all accounts `researcher_verified` — *scoped to
campaign/core accounts only*.

**Verification** (`/verification`, `Verification::*`): works `data_validation` only.
Shows ALL accounts grouped by channel type. Per-account actions: Verify ✓, Unverify,
Edit (→ `mark_entered!` = re-enter), Not Found, Reset, notes; verifiers can also **add
a brand-new account** (`Verification::AccountsController#create` → built directly with
`research_status: 'entered'`, `entered_by: current_user`). Complete gate
(`Verification::AssignmentsController#complete`):

```ruby
incomplete = @assignment.person.social_media_accounts.needs_verification.count
# blocks completion if > 0 — counts EVERY account on the person, all channel types & platforms
```

On successful completion it calls `person.mark_for_secondary_verification_if_needed!`,
which flags the person + any accounts with `modified_during_validation: true` as
`needs_secondary_verification`.

**Admin**: creates assignments (any type), can filter people by
`needs_secondary_verification` and by has/lacks secondary_verification assignments;
`Admin::AssignmentsController#complete` force-completes **bypassing all gates** (the
current manual escape hatch for stuck users).

### The deadlock (exact trace)

1. Verifier has a `data_validation` assignment for person P.
2. P has a blank platform; verifier finds the account and adds it → new account,
   `research_status: 'entered'`, `entered_by: verifier`.
3. Policy: the person who entered data must not verify it ("four-eyes" rule).
4. Verifier finishes everything else; clicks **Mark Complete** →
   `needs_verification.count` ≥ 1 (their own addition) → blocked:
   *"1 accounts still need verification."*
5. Nothing the verifier is allowed to do resolves this → assignment stuck in
   `in_progress` forever (or an admin force-completes, losing the follow-up trail).

Production scale: 32 `entered` accounts have `entered_by` set (workspace entries —
the population that can strand tasks); 23 validation assignments are `in_progress`.

### Quirks & gaps found during this review (all verified in code/data)

1. **The four-eyes rule is not enforced anywhere in code.** The Verify button renders
   for any unverified account with no `entered_by` check, and
   `Verification::AccountsController#verify` / `verify!` have no guard. It's pure team
   policy. (Older `.backup` views displayed "entered by X" context; live views don't.)
2. **`mark_entered!` sets `modified_during_validation` on FIRST entry**, not just
   modification: `persisted? && (self.url != url || …)` is true when a prepopulated
   blank stub gets its first URL. Consequence: researcher first-entries during *data
   collection* are flagged "modified during validation," and when the later validation
   completes, the person is flagged for secondary verification even if every account
   verified cleanly. Production: 874 flagged accounts / 496 flagged people / 1,272
   completed validations — the flag is noisy with false positives.
3. **`secondary_verification` assignments cannot be worked.** Admin can create them,
   but `Verification::AssignmentsController` scopes strictly to `data_validation` and
   `Researcher::AssignmentsController` to `data_collection`; the researcher index even
   links them to the data_collection path → `RecordNotFound`. Only one was ever
   created.
4. **Asymmetric completion gates.** Researcher completion checks campaign+core
   accounts only; verification completion checks *every* account on the person (all
   channel types, all 11 platforms). A verifier who adds a Personal/fringe account
   widens their own gate.
5. **Verified accounts added through the election editor** enter as
   `entered`/unverified (by design) — every editor-populated person will hit the
   verification queue with many `entered` accounts. Fine, but it means the
   needs_verification population is about to grow a lot.
6. **No automated tests exist** (no `test/` or `spec/`; `docs/TESTING_PLAN.md` is an
   unstarted RSpec+FactoryBot plan). Any change here ships untested unless we build
   the harness first.

---

## Proposed directions (no changes made yet)

The design goal: **keep the four-eyes guarantee** — no URL counts as verified without
a second person checking it — while letting people finish the work they're allowed to
finish.

**A. Enforce the four-eyes rule in code.** `verify!` (and `verify_with_changes`)
refuses when `account.entered_by == verifying user` (server-side; hide/disable the
button in the UI with an explanatory tooltip). Turns policy into invariant — every
other piece can then rely on it. Decide: does it bind admins too?

**B. Soften the completion gate to "nothing left that YOU can act on."** Completion is
blocked only by `needs_verification` accounts the completer is *allowed* to verify
(i.e. entered by someone else). Accounts the completer entered themselves don't block —
instead, completing the assignment marks them (and the person) `needs_secondary_verification`,
which routes them into the existing admin finder. The four-eyes guarantee holds: those
accounts are still unverified; they're just someone else's queue now.

**C. Make secondary_verification tasks workable.** Extend the Verification workspace to
serve both `data_validation` and `secondary_verification` task types (same UI; the
secondary view highlights flagged accounts). Its completion gate: all flagged accounts
resolved (verified/rejected/not_found) — with rule A guaranteeing the resolver differs
from the enterer. Completing clears `needs_secondary_verification` via the existing
`Person#clear_secondary_verification!`.

**D. Fix the `modified_during_validation` false positives.** First entry into a blank
stub should not count as a "modification" (require the account to have had a previous
value, or previously-verified status). Optionally backfill: clear the flag on accounts
whose only "modification" was first entry. This makes the secondary-verification queue
mean what admins think it means.

**E. Admin finder for the new case.** Cameron specifically wants admins to find people
with *some verified accounts + some newly-added unverified ones*. With B in place this
is exactly `needs_secondary_verification: true` people — already a filter in
`/admin/assignments/new`. Add a guard so the secondary task can't be assigned to the
user who entered the pending accounts.

Recommended package: **A + B + C + E**, with **D** strongly suggested alongside (it
determines whether the secondary queue is trustworthy). B is the deadlock fix; A makes
B safe; C makes the hand-off real instead of a dead end; E closes the admin loop.

### Test plan (prerequisite work)

There is no test infrastructure. Per `docs/TESTING_PLAN.md` intent: install RSpec +
FactoryBot, factories for User/Person/Assignment/SocialMediaAccount, then request +
model specs pinning each scenario **before** changing behavior:

1. Verifier verifies an account entered by someone else → allowed (baseline)
2. Verifier attempts to verify their own entry → blocked (A)
3. Completion with all accounts resolved → completes (baseline)
4. Completion with unverified account entered by *someone else* → still blocked (baseline kept)
5. Completion with unverified account entered by *the completer* → completes + flags
   person/account for secondary verification (B)
6. Secondary verification task: visible/workable in verification workspace; complete
   clears flags (C)
7. Secondary task completion blocked while flagged accounts unresolved (C)
8. First entry into blank stub does NOT set `modified_during_validation`; genuine
   edit of existing/verified data does (D)
9. Admin assigning secondary task to the enterer of pending accounts → prevented (E)
10. `verify!` Junkipedia enqueue still fires exactly on verified transitions (regression)

---

## Open questions (answer before implementation)

1. Should the four-eyes rule bind **admins** too, or can admins self-verify as an
   escape hatch?
2. Is it acceptable to **reuse `needs_secondary_verification`** for "new entry awaiting
   first peer review," or should that be distinct from "verified data was modified"?
   (Reuse = one queue, one admin flow; distinct = cleaner semantics, more machinery.)
3. When a completion strands self-entered accounts, should the system **auto-create**
   the secondary_verification assignment (needs an assignee-picking rule) or leave
   creation to admins via the existing filter (recommended: manual, admins balance
   workloads)?
4. For **D**, do we also backfill (clear flags set by first-entries), or fix
   go-forward only? Backfill changes what admins currently see in the
   needs-secondary-verification queue (496 people today).
5. Test framework: confirm **RSpec + FactoryBot** (per TESTING_PLAN.md) vs Rails
   default Minitest. The verification flow specs above are the starting suite either way.
