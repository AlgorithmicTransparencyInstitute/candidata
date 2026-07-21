# Secondary Verification — UX Gap & Proposed Fix

**Status: FIXED (July 2026)** — implemented as a variant of proposed fix #2
plus the #1 guidance banner:

- Each flagged account now shows a red **Confirm Verified** button
  (`Verification::AccountsController#confirm_secondary`) that clears that
  account's `needs_secondary_verification` flag. Confirming IS the
  re-verification: an unverified flagged account is `verify!`d and unflagged
  in one step (no second validation cycle). Four-eyes applies (the enterer/
  modifier can't confirm their own account; admins exempt) — such accounts
  never block completion; they hand off, still flagged, to the next
  secondary cycle.
- **Complete Secondary Verification** (renamed from "Mark Complete" on
  secondary tasks) is disabled with a remaining-count until every flagged
  account is individually confirmed; completing clears the person-level flag.
- A banner on in-progress secondary assignments explains the flow.
- Pinned by `spec/requests/verification_flow_spec.rb` ("secondary verification
  tasks" describe block). Fix #3 (guard unlock) remains unimplemented.

Original diagnosis below, kept for the design record.

---

**Status:** diagnosed, not yet fixed. Written from investigating assignment
`/verification/assignments/2609` (a `secondary_verification` task for Amanda
Pusczek). No code changes made yet.

## Symptom (as reported)

On a secondary-verification assignment, some accounts show a purple
**"Needs Secondary Verification"** badge. The verifier expects to click a
per-account "verify" control to clear it, but there isn't one. They can click
the **unlock** (padlock) button and then the **checkmark**, but the badge never
clears — "it doesn't actually enable the function."

## Root cause

The `needs_secondary_verification` badge is **assignment-level state**, cleared
in exactly one place — completing the secondary-verification assignment — but
the verifier is trying to clear it with **per-account** buttons that don't
control it.

### How the flag is set and cleared

| Action | Effect on `needs_secondary_verification` |
|---|---|
| Complete a **data_validation** task with self-entered leftovers, or accounts modified during validation | **Set → true** (`AssignmentsController#complete_data_validation`, `app/controllers/verification/assignments_controller.rb:59-64`; `Person#mark_for_secondary_verification_if_needed!`, `app/models/person.rb:127-130`) |
| Complete the **secondary_verification** task | **Cleared → false** for all the person's accounts (`AssignmentsController#complete_secondary_verification` → `Person#clear_secondary_verification!`, `assignments_controller.rb:74-85`, `person.rb:135-137`) |
| Per-account **verify** checkmark (`SocialMediaAccount#verify!`, `social_media_account.rb:120`) | **No effect** — sets `verified`/`verified_by`/`research_status` only |
| Per-account **unlock** (`AccountsController#unverify`, `accounts_controller.rb:136`) | **No effect** — flips `verified`→false / `research_status`→`entered`, leaves the flag set |

There is **no per-account control that calls `clear_secondary_verification!`**.

### Why the unlock → checkmark dance fails

In `app/views/verification/accounts/_account_row.html.erb:57-79`, the per-account
action button depends on `is_verified = (research_status == 'verified')`:

- **verified** account → shows the **lock/unverify** button (no checkmark).
- **unverified** account, verifiable by this user → shows the **verify checkmark**.
- **unverified** account you entered → shows "Awaiting another verifier" (four-eyes).

The flagged accounts on 2609 are all **already verified** (see case data below),
so they render a lock, not a checkmark. Then:

1. **Unlock** → `research_status: 'entered'`, `verified: false`, but
   `needs_secondary_verification` **stays true**. Badge unchanged; account is now
   unverified.
2. **Checkmark** → `verify!` re-verifies it → back to verified, flag still true.
   Net change to the badge: **zero**.
3. Worse: if an account is left unlocked, it is now in `needs_verification`
   (`entered`/`not_found`/`revised`), which **blocks** Mark Complete —
   `complete_secondary_verification` refuses while any flagged account is
   unresolved (`assignments_controller.rb:75-80`).

### Case data (assignment 2609, prod, read-only)

`secondary_verification`, in_progress, assignee user 23 (myra), person 235310
(Amanda Pusczek), `person.needs_secondary_verification = true`.

| Platform | status | verified | needs_secondary | modified_during_validation | entered_by | verified_by |
|---|---|---|---|---|---|---|
| BlueSky | verified | ✓ | — | — | (nil) | 39 |
| Facebook | verified | ✓ | **✓** | ✓ | 39 | 23 |
| Instagram | verified | ✓ | **✓** | ✓ | 39 | 39 |
| TikTok | verified | ✓ | **✓** | ✓ | 39 | 39 |
| Twitter | verified | ✓ | — | — | 39 | 39 |
| YouTube | verified | ✓ | — | — | (nil) | 39 |

All three flagged accounts are already `verified`, flagged because they were
`modified_during_validation` in the earlier data-validation pass. Nothing is in
`needs_verification`, so `complete_secondary_verification` would clear them
immediately.

## Immediate workaround (no code change)

Because all flagged accounts are already verified (nothing unresolved), the
verifier just clicks **"Mark Complete"** on the assignment. That runs
`complete_secondary_verification` → `clear_secondary_verification!` → clears all
three flags and finishes the task. Caveat: if any account was left *unlocked*
from experimenting, re-verify it first or Mark Complete is blocked.

## Proposed fixes (pick when prioritized)

1. **Guidance-only (lowest risk, recommended first).** On a
   `secondary_verification` assignment, show a banner explaining the model
   ("Review each flagged account; when satisfied, click Mark Complete to finish
   secondary verification") and make the completion confirm text
   secondary-specific instead of the generic "Are you sure all accounts have
   been verified?" (`assignments/show.html.erb:94`). De-emphasize or hide the
   "unlock" affordance for flagged, already-verified accounts.
2. **Per-account confirm.** Add a "Confirm" action shown only on
   `secondary_verification` tasks that calls `clear_secondary_verification!` for
   a single account, so verifiers can clear individually. Must keep four-eyes:
   the secondary verifier should differ from the account's `verified_by`
   (Instagram/TikTok here were entered *and* verified by user 39, so a different
   secondary reviewer is exactly the point).
3. **Guard unlock.** Warn (or block) when unlocking a flagged, verified account,
   since it re-opens the account and can block completion — the main way a
   verifier paints themselves into a corner today.

Recommendation: **#1 + #3** first (clears the confusion and removes the
foot-gun); add **#2** if per-account granularity is wanted.

## Key references

- `app/controllers/verification/assignments_controller.rb` — `complete_data_validation` (sets flag), `complete_secondary_verification` (clears flag)
- `app/controllers/verification/accounts_controller.rb` — `verify`/`unverify`/`enforce_four_eyes!`
- `app/models/social_media_account.rb` — `verify!`, `verifiable_by?`, `clear_secondary_verification!`, `needs_secondary_verification` scope
- `app/models/person.rb` — `mark_for_secondary_verification_if_needed!`, `clear_secondary_verification!`
- `app/views/verification/accounts/_account_row.html.erb` — per-account action buttons
- `app/views/verification/assignments/show.html.erb:94` — the "Mark Complete" button
- See also `docs/VERIFICATION_WORKFLOW.md` for the broader state machine.
