# Verification Workflow — Current State & Redesign Proposal

> **Status: IMPLEMENTED 2026-06-12** (branch `feature/verification-four-eyes`). The
> "Final implementation plan" below was built test-first — see `spec/requests/
> verification_flow_spec.rb`, `spec/requests/admin_secondary_assignment_spec.rb`,
> `spec/models/social_media_account_spec.rb` (25 examples). Run `bundle exec rspec`
> before changing this flow. The "Current state" sections below describe the system
> BEFORE this change and remain as the design record; quirks #1–#4 are now fixed.

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
| `clear_secondary_verification!` | clears the two flags | per-account **Confirm Verified** button on secondary tasks (`AccountsController#confirm_secondary`); `Person#clear_secondary_verification!` on assignment completion |

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

> **Update (July 2026): per-account sign-off.** The C completion gate was upgraded
> from "all flagged accounts resolved" to an explicit per-account confirmation:
> each flagged account shows a red **Confirm Verified** button
> (`Verification::AccountsController#confirm_secondary`, four-eyes enforced)
> that clears its own `needs_secondary_verification` flag. **Confirming IS the
> re-verification**: if the flagged account is unverified (entered/revised/
> not_found — i.e. it was changed during validation), confirming calls
> `verify!` and clears the flag in one step — flagged accounts never require a
> separate "validate again" pass. The assignment's
> **Complete Secondary Verification** button stays disabled (with a
> remaining-count) until every flagged account has been individually confirmed;
> completing then clears the person-level flag. Pinned by
> `spec/requests/verification_flow_spec.rb` ("secondary verification tasks").
>
> **The completion gate applies rule B recursively (deadlock fix).** Only
> flagged accounts the completer *may* act on (`verifiable_by?`) block
> completion. Flagged accounts the completer entered or modified themselves —
> a mid-review edit makes the account their own entry — can never be
> verified/confirmed by them, so they don't block: completing hands them off,
> still flagged (person flag kept too), to a fresh secondary task for another
> user via the admin finder. The cycle terminates when a reviewer confirms
> without editing anything. Rows show "Awaiting another reviewer" for these
> hand-off accounts.
>
> **Row styling is task-aware.** The red "Needs Secondary Verification"
> treatment (row background + badge + Confirm button) only appears when the
> account is viewed through a `secondary_verification` assignment — where
> clearing it is the user's job. Viewed through a `data_validation` assignment,
> the same account renders by research status (verifying turns it green) with a
> muted "Flagged for secondary review" pill, since the flag belongs to a
> different task/user.
>
> **Deactivated accounts are exempt from all completion gates (July 2026).**
> Marking an account deactivated (`account_inactive: true`, URL kept) is a
> terminal disposition — it resolves the account. Both `complete_data_validation`
> and `complete_secondary_verification` scope their blocking sets with
> `.active`, `mark_for_secondary_verification_if_needed!` skips inactive
> accounts, and the row partial drops the "Needs Verification" / red-flag
> framing (the ⊘ Deactivated badge carries the state). This fixed the
> assignment-2893 bug where a validator couldn't complete because the gate
> demanded verification of an account they had just marked deactivated.

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

## Decisions (Cameron, 2026-06-12)

1. **Four-eyes rule: admins exempt.** Researchers cannot verify accounts they entered;
   admins can verify anything (escape hatch, visible in the audit trail).
2. **Reuse `needs_secondary_verification`** for "new entry awaiting first peer review" —
   one flag, one admin filter, one task type.
3. **Manual assignment**: completion flags the person; admins find them via the
   existing needs-secondary-verification filter and choose the assignee. No auto-create.
4. **Flag fix is go-forward only** — no backfill of the 496 currently-flagged people.
5. Test framework: **RSpec + FactoryBot** (matches `docs/TESTING_PLAN.md` intent).

## Final implementation plan

1. **Test infrastructure first**: rspec-rails + factory_bot_rails, factories for
   User/Person/Assignment/SocialMediaAccount, request specs pinning the full scenario
   matrix above (target behavior) before changing code.
2. **A′ — enforce four-eyes (admins exempt)**: `SocialMediaAccount#verifiable_by?(user)`
   (`user.admin? || entered_by_id != user.id`); guard `verify`/`verify_with_changes`
   server-side; hide the Verify button with an explanatory badge in the row partial.
3. **B — completion gate**: block only on `needs_verification` accounts the completer
   is allowed to verify. On completion, any leftover self-entered pending accounts get
   `needs_secondary_verification: true` (account + person) and the flash explains the
   hand-off.
4. **C — secondary tasks workable**: Verification workspace (dashboard/queue/index/
   show/accounts guard) serves `data_validation` + `secondary_verification`; researcher
   index routes secondary tasks to the verification namespace; secondary completion
   gate = no flagged-account still `needs_verification` (same verifiable-by logic);
   completing calls `Person#clear_secondary_verification!`.
5. **D — go-forward flag fix**: `mark_entered!` counts a modification only when the
   account had a previous URL or was verified (first entry into a blank stub no longer
   flags `modified_during_validation`).
6. **E — admin guard**: creating a `secondary_verification` assignment skips people
   whose pending flagged accounts were entered by the chosen assignee (reported in the
   flash as skipped).
7. Docs + in-app guides updated (this doc, admin guide §6, verification guide partial).
