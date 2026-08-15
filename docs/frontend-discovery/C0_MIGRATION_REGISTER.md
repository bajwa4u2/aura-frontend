# C0 — Cross-Cutting Foundations: Migration Register

**Chapter:** C0 (first authorized implementation chapter)
**Date:** 2026-08-15
**Status:** ✅ **COMPLETE / FOUNDER APPROVED / LOCALLY CERTIFIED** — closed 2026-08-15

> Produced **before** broad edits, per the chapter instruction, so that mass
> replacement cannot serve completion. Every number below is measured from the
> repository, not estimated.

---

## 1. What C0 built

Three authorities in `lib/core/product/`:

| Authority | File | Owns |
|---|---|---|
| **Product Language** | `product_language.dart` | canonical nouns, semantic actions, canonical labels, the four stop/undo families |
| **Product State Presentation** | `product_state.dart` + `product_state_view.dart` | the 15 governed states, each state's behavioural meaning, and one rendering adapter |
| **Human Temporal Presentation** | `temporal.dart` | event semantics, humanized formatting, calendar/exact time, timezone, aging, sorting semantics |

None of them is a redesign. `AuraProductState` composes the **existing**
`AuraLoadingState` / `AuraEmptyState` / `AuraErrorState`; `AuraTemporal`
replaces three hand-rolled formatters with one. No screen was redesigned.

---

## 2. Classification that governed the work

The raw counts from discovery were misleading, and acting on them directly
would have produced exactly the mass replacement the chapter forbids.

| Raw signal | Raw count | After classification |
|---|---|---|
| `CircularProgressIndicator` | 122 | **26 full-surface** · 91 legitimate inline · 3 manual |
| `.difference()` | 69 | **41 human-facing** · 28 internal TTL/cooldown/debounce *(legitimate)* |
| `.sort()` | 26 | **10 temporal** · 16 non-temporal *(out of scope)* |

Two specific corrections came out of this and are recorded because they change
what "complete" means:

- `incoming_live_overlay.dart:466` is `prevSet.difference(nextSet)` — a **Set**
  operation. A false positive; not temporal drift at all.
- Inline progress is **not** drift. A send button's own spinner is correct
  local behaviour. Only the 26 full-surface sites were ever candidates.

---

## 3. Consumers actually migrated

| Migration | Sites | Effect |
|---|---|---|
| `'Try again'` → `ProductLabels.of(ProductAction.retry)` | **33 sites / 30 files** | one word for one action |
| `'Refresh'` used as an error-recovery action (`updates_screen.dart`) | 1 | recovery position now says Retry |
| `relative_time.dart` → forwards to `AuraTemporal` | 3 functions, **9 transitive consumers** | one implementation of humanized time |
| `local_timezone.dart` → reached via `AuraTemporal.zoneId` | 3 consumers | the authority owns the timezone question |
| `CommLoadingState` / `CommErrorState` → `AuraProductState` | 2 widgets | the shared communication state layer |

### Two deliberate behaviour changes

Both are corrections, and both are visible — flagged here for founder review
rather than buried:

1. **Older timestamps now read `Aug 12` / `Aug 12, 2025`, not `2026-08-12`.**
   A raw ISO date in a feed card is precisely the "machines store precise time,
   people experience meaningful time" defect.
2. **Future instants no longer render as `now`.** `formatRelative` previously
   took a negative difference through its `inSeconds < 60` branch, so a
   scheduled item read as if it had already happened. This was a real bug.

### A premise of my own that was wrong

My first draft listed `Refresh` and `Reload` as prohibited synonyms of Retry.
That was over-reach. `saved_screen.dart` legitimately carries **both** — a
header `Refresh` on the loaded list and a recovery action on the error state —
and the update gate's `Reload` means reload the application. They are separate
canonical actions (`ProductAction.refresh`, `ProductAction.reload`).

The gate governs them **positionally** instead: a recovery action must say
Retry. Only `try again` / `retry operation` / `try once more` are banned
outright, because they carry no meaning Retry does not already own.

---

## 4. What C0 deliberately did NOT migrate

Frozen in `test/product/c0_drift_baseline.txt` and mechanically enforced.

| Rule | Files | Sites | Why frozen |
|---|---|---|---|
| **G2** local humanized elapsed time | 6 | 24 | screen-level, owned by later chapters |
| **G3** local `toLocal()` | 35 | 47 | ditto; 16 sites are Meetings |
| **G4** full-surface spinner | 20 | 26 | **14 of 26 are Meetings** |
| **G5** direct state-primitive construction | 72 | 181 | the AuraProductState burn-down |
| **G7** time formatter declared on a screen | 14 | 17 | ditto |

> **Meetings is a PROTECTED CERTIFIED SURFACE.** C0 has no authority to modify
> it and did not. Freezing those sites is the correct outcome; rewriting them
> for a tidier number would have been a violation.

**G5 is the honest answer to "is this authority actually consumed?"** Rather
than claim the state authority is adopted, the 181 bypassing sites are counted
and ratcheted. The number can only fall.

---

## 5. Anti-drift enforcement (FD-13)

`test/product/c0_anti_drift_gate_test.dart` — **hard build failure**, 18 tests.

**Zero-tolerance rules** (any occurrence fails):
- no prohibited action synonym used as a whole label
- no two canonical actions render the same label
- the deprecated shim holds no formatting logic of its own
- an ordering cannot be obtained without declaring what it means
- **Add member / Invite person / Manage invites stay distinguishable**, and the generic `invite` is not a synonym for either specific one
- **Person and Member are not flattened**, and FD-11's five identity concepts remain five
- **Correspondence carries one meaning** — never merged with Space, Thread or Message
- **"trusted discovery" is not reintroduced** as current canonical language
- **no generic `Verified`** closes the layered-verification map
- **`connect` / `connection` / `works` never enter the vocabulary**
- Representation-backed nouns keep their canonical terms

**Ratchets** (G2/G3/G4/G5/G7): a new file may never appear and a count may
never rise — *and when a count falls the gate also fails* until the baseline is
updated, so the register can never overstate remaining debt.

The gate strips comments before matching. Every rule governs **code, not
prose** — the same principle the Product Language Authority itself holds. This
was found the hard way: the first run failed on a doc comment that was
*explaining* a rule.

### The gate was proven to fail

A gate that has never failed is decoration. Each rule was verified by
introducing a deliberate violation into `lib/widgets/note_card.dart` and
confirming the specific rule fired:

| Rule | Probe | Fired |
|---|---|---|
| Product Language | `const _probe = 'Try again';` | ✅ |
| G2 elapsed time | `.difference(...)` + `"$x ago"` | ✅ new-file drift |
| G3 toLocal | `d.toLocal()` | ✅ new-file drift |
| G4 surface spinner | `Center(child: CircularProgressIndicator())` | ✅ new-file drift |
| G7 local formatter | `String formatWhen(DateTime d)` | ✅ `1 -> 2` increase |

The probe file was restored; `git diff` on it is empty.

---

## 6. Verification

| Check | Result |
|---|---|
| `flutter analyze lib/ test/` | **No issues found** |
| `flutter test` (full suite) | **463 passed**, 1 skipped, 0 failed |
| New C0 tests | **52** (34 authority + 18 gate) |
| `aura-backend` (after date corrections) | `tsc` clean · **171 suites / 2197 tests passed** |
| Pre-C0 suite | 411 passing — **no regressions** |

---

## 7. Open items — NOT decided here

1. **G5 burn-down execution.** All 181 sites are now **assigned** — see
   `C0_G5_OWNERSHIP_MATRIX.md`. Execution belongs to each owning chapter, which
   must re-verify its `J`-basis assignments against actual reconstruction scope
   before migrating.
2. **Meetings debt.** Zero G5 sites; its protected debt is G3 (16) and G4 (14),
   held for C6's controlled convergence boundary. Not scheduled here.
3. **`@Deprecated` produces no analyzer signal** in this project, so the
   annotation on `relative_time.dart` documents intent but does not enforce it.
   The hard gate is the enforcement.

---

## 7b. Founder adjudication applied — 2026-08-15

| Matter | Ruling | Applied |
|---|---|---|
| Membership operations (E-1) | Add in C0 | `addMember` / `invitePerson` / `manageInvites` + gate |
| Person vs Member (E-2) | **Person = canonical human identity; Member = contextual status** | both nouns documented + gate |
| Correspondence (E-3) | **One canonical meaning**; umbrella = legacy naming drift | authority + Representation reconciled; **C7 obligation recorded** |
| Discovery directive (E-4) | Supersession authorised | applied in Representation, original struck through not deleted |
| Connect / Works (E-5) | Finding accepted | gate-enforced absent |
| Authority chain | Correction accepted | recorded in the alignment artifact |
| Date stamps | **My authoring error** | 40 files / 178 occurrences corrected — see `docs/DATE_CORRECTION_2026-08-15.md` |
| G5 matrix | Accepted as continuity evidence | R/J verification rule recorded |
| Meetings G5 = 0 | Measured correction accepted | protected debt stays under G3/G4 |

**Representation files changed (3, all founder-authorised):** `AURA_REPRESENTATION_MODULE_INVENTORY.md` (3 reconciliation notes) · `MODULE_ANALYSIS_AURA_INSTITUTIONAL_COMMUNICATION.md` (1 cross-reference) · `AGENTS.md` (date only). No frozen status, type, feature list or framing directive was altered; no historical text was deleted.

---

## 8. Boundaries respected

- **C1 not begun.**
- **No screen redesigned.** No layout, spacing, or visual treatment changed.
- **Meetings untouched.**
- **Notification preferences not implemented** — recorded for C4 in
  `NOTIFICATION_PREFERENCE_AUTHORITY_OBLIGATION.md`, C4 not started.
- Nothing committed. Nothing pushed.
