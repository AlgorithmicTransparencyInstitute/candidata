# Demographic Research

The fourth assignment type. Researchers collect, confirm and annotate
demographic metadata about a person — race, gender, date of birth, marital and
parental status, education, military service — and record **where each answer
came from**.

Added August 2026. Live at `/demographics`.

---

## The idea in one rule

**A blank field is not an answer.**

Every other part of this app treats "no value" as "not done yet". That breaks
down for demographics, because plenty of candidates simply have no public
record of their marital status or date of birth. If blank meant unfinished,
those people would sit in the queue forever and researchers would be pushed
toward guessing.

So a field is *settled* in one of two ways:

| Determination | Meaning |
|---|---|
| **Verified** | You found the answer and can cite where. Requires a value **and** a source or note. |
| **Not publicly documented** | You looked and it isn't available. A real answer. No value required. |
| **Sources conflict** | Sources disagree. Does **not** settle the field — it's a request for a second opinion, and it keeps the person short of "complete". |

This is why `DemographicField`'s option lists contain no "Unknown" entry. An
"Unknown" *value* would collapse "nobody looked" and "we looked, it isn't
public" into the same state, and those are the two states an admin most needs
to tell apart.

---

## Data model

Values live on `people`. Evidence lives in `demographic_verifications`.

```
people                          demographic_verifications
├─ gender                       ├─ person_id + field_key   (unique together)
├─ race            ←── values   ├─ status                  verified/unknown/disputed
├─ birth_date                   ├─ value_snapshot
├─ marital_status               ├─ source_url    ←── evidence
├─ …                            ├─ notes
├─ demographics_status ←─ rollup├─ verified_by_id / verified_at
└─ demographics_reviewed_at     └─ assignment_id
```

Keeping values on `people` means the election editor, admin person form,
public API serializers and every existing query keep reading one place. A
separate `person_demographics` table would have split the record in half for
no gain.

Keeping evidence in its own table is the point of the feature: the question
"who determined this, when, and from what source" has to be answerable per
field, and one notes blob covering twelve fields would not be.

### Race is multi-value

`people.race` is a single string column holding a comma-joined list. That
convention was already in the imported data (`"Multiracial, Hispanic or
Latino, White"`), so the multi-select round-trips through it rather than
requiring a schema change. `Person#race_values` / `#race_values=` and
`DemographicField::RaceValue` are the only places that convention is encoded.

`race` is **not** inclusion-validated: production holds 31 free-text variants
(`"WHhite"`, `"black"`, `"-"`, `"Not sure"`), and validating would make those
records unsaveable from the election editor. The new UI constrains race
through `DemographicField::RACES`; legacy values stay readable. Normalizing
the existing 1,759 values is a separate, opt-in cleanup that has not been run.

**Legacy values round-trip.** 462 people carry a race token outside the
controlled list. Those tokens render as their own pre-ticked checkbox (styled
amber, labelled "non-standard") rather than being dropped. This matters
because the multi-select always submits `values[race]` — without it, a
researcher recording an unrelated field would silently blank that person's
race. Removing a legacy value is now an explicit untick. Single selects do the
same thing: an out-of-vocabulary stored value is carried as its own option.

### The registry

`app/models/demographic_field.rb` defines every field: key, label, kind,
options, hint, group, dependency, and whether it counts toward "complete".
The researcher form, admin filters, permitted params, completeness rollup and
specs all derive from it.

**Adding a field is one registry entry plus a column on `people`.** Nothing
else needs to change.

Dependent fields (`children_count`, `military_branch`) declare `depends_on`
and stay hidden — and are never counted as missing — until the parent answer
makes them meaningful. Changing the parent away from its trigger value clears
the dependent value *and* deletes its verification row, so a person can't keep
a branch after "Never served".

---

## Completion gate

`Demographics::AssignmentsController#complete` blocks unless
`person.unsettled_demographic_fields` is empty — every **core** field that is
**relevant** to that person has a settled determination. The alert names the
outstanding fields.

Note the two qualifiers. Optional fields (`birth_year`, `children_count`,
`education_institution`, `military_branch`) never block. Irrelevant dependents
never block.

Completing refreshes `people.demographics_status` to `complete`.

Unlike the social-account workflow there is **no four-eyes rule here yet** —
demographic research is single-pass. The `disputed` status is the escalation
route: it survives completion attempts and shows up in the admin filter.

---

## Admin: finding people to assign

`/admin/assignments/new` gained a **Demographic Data** dropdown filtering on
two deliberately independent axes:

| Axis | Param | Values |
|---|---|---|
| Review status | `demographics_status` | not_started / in_progress / complete / incomplete |
| Value presence | `demographic_presence` | any_present / none_present / any_missing / all_present |
| One named field | `missing_demographic_field` | any `DemographicField` key |
| Conflicts | `demographics_disputed` | `1` |

They are separate because the most useful population is usually the
intersection: **"has imported values, but nobody ever checked them"**
(`demographic_presence=any_present` + `demographics_status=not_started`).
Neither axis alone can express that. On the 2026 candidate pool that
combination currently finds ~1,905 of 2,627 people.

⚠️ Use `any_present`, not `all_present`, for that recipe. Six of the eight core
columns are new and NULL for every existing row, so `all_present` matches
**zero** people until the feature has been worked — it becomes useful later,
not now.

Each person row shows a coverage badge: `n/8` values present, plus a `DR`
pill for review state (grey = not started, teal ◐ = in progress, green ✓ =
complete).

The existing dropdown labelled "Demographics" — which only ever held State and
Party — was renamed **Location & Party**.

---

## Researcher UI

`/demographics/assignments/:id`. Two columns:

- **Left** — the form, grouped into Identity / Family / Education / Service.
  Each field row carries a value control, a determination select, a source URL
  and an evidence note. Rows are tinted by determination status (green
  verified, slate not-documented, amber conflict, red error) so a
  half-finished person reads at a glance. One submit saves the whole person;
  a per-field save would multiply page loads by twelve.
- **Right** (sticky) — everything needed to source an answer without leaving
  the page: campaign/official/personal sites, the Wikipedia article, every
  active social account with its handle (verified ones sorted first), and
  prefilled Google / Ballotpedia / Wikipedia searches.

Validation is all-or-nothing per submission (`DemographicsReview` wraps it in
a transaction): a person is never left with values saved but evidence lost,
which would look like verified data nobody can trace.

Rejected submissions:
- `verified` with neither source nor note
- `verified` with no value (the error points at "Not publicly documented")
- `disputed` with neither source nor note
- a `source_url` that isn't `http(s)://` — it is rendered into an `href` an
  admin clicks, so `javascript:` is refused at the model and again at render
  (`DemographicsHelper#safe_source_url`)

A field left blank in a submission leaves any existing determination alone —
the researcher simply hasn't ruled on it in this pass.

When a submission is rejected, the form redisplays **what the researcher
typed** — both values (which survive on the rolled-back in-memory Person) and
evidence (overlaid from `@submitted_evidence`). Fixing one bad field never
costs them the other eleven rows of work.

A determination echoed back for a field the same submission just made
irrelevant ("Veteran" → "Never served") is dropped rather than validated or
written — otherwise the researcher would be blocked by an error on a row the
page no longer shows.

---

## Key code

| Path | Role |
|---|---|
| `app/models/demographic_field.rb` | The registry. Start here. |
| `app/models/demographic_verification.rb` | Evidence row; status vocabulary; `SETTLED_STATUSES` |
| `app/models/person.rb` | Values, demographic scopes, `refresh_demographics_status!` |
| `app/services/demographics_review.rb` | Transactional save: values → evidence → rollup |
| `app/controllers/demographics/assignments_controller.rb` | Queue, form, save, completion gate |
| `app/views/demographics/assignments/` | `index`, `show`, `_field_row` |
| `app/helpers/demographics_helper.rb` | Value controls by field kind; status tints |
| `app/helpers/assignment_helper.rb` | Task-type label/colour/route for all four types |
| `spec/requests/demographic_research_spec.rb` | 25 examples pinning the flow, incl. a `regressions` block |
| `spec/requests/admin_demographic_filters_spec.rb` | 8 examples pinning the filters |
| `spec/requests/admin_destroy_paths_spec.rb` | the FK/`dependent:` behaviour below |
| `spec/mailers/user_mailer_spec.rb` | mailer helper availability, all four task types |

### Deletion behaviour

`demographic_verifications` holds the first foreign keys in the schema pointing
at `assignments` and at `users`, both NO ACTION. The Rails side must match or
the destroy 500s:

| Parent | Behaviour | Why |
|---|---|---|
| `Person` | `dependent: :destroy` | the evidence is about that person |
| `Assignment` | `dependent: :nullify` | evidence outlives the work ticket that prompted it |
| `User` (`verified_by`) | `dependent: :nullify` | determination stands; PaperTrail keeps the history |

Without the two nullifies, any researcher who had recorded a determination
could never be deleted, and their assignments could never be cleaned up.

---

## Public API

The new demographic fields are **not** exposed on `/api/v1`. `gender` and
`race` were already public and remain so; the rest are internal for now. The
v1 serializers are strict allowlists, so the payload shape is unchanged and
`public_api_verify.rb` passes untouched.

One behavioural note: `Person::GENDERS` now includes **Non-binary**, so
`gender` can return a value external consumers haven't seen before. The
OpenAPI type (`[string, "null"]`) is unaffected.

Exposing the remaining fields would be an additive v1 change — a product and
privacy decision, not a technical blocker.

---

## Not built yet

- **Four-eyes / secondary review for demographics.** `disputed` is the only
  escalation path today.
- **Admin resolution queue for disputed fields.** The filter finds them; there
  is no dedicated work-list.
- **Race normalization.** 31 legacy variants remain. A cleanup would need to
  run against production data and change values external API consumers see, so
  it is deliberately opt-in and unrun.
- **Age display.** `birth_date` / `birth_year` are collected but nothing
  derives or displays an age yet.
- **Bulk demographic import.** Everything is hand-researched.
