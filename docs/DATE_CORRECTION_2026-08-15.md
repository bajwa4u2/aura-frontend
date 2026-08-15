# Date Correction — the `2026-08-16` stamps

**Date of correction:** 2026-08-15 · **Authorised by founder** during the C0 final review.

---

## What happened

**This was my error.** Across several working sessions I wrote `2026-08-16` into document headers, status lines, register rows and source-file comments. It was never a real date: it is one day ahead of the current date and no commit exists on or after it in any of the three repositories.

I first reported it as an unexplained *provenance anomaly* requiring founder verification. The founder identified the actual cause — my own mis-dating while working long sessions — and instructed that the earlier documents be corrected, not merely flagged.

Recording it plainly matters because several of the affected documents are **founder-approved frozen doctrine**, and a governance record that carries an impossible date undermines the chronology every later precedence decision depends on. Precedence in this programme is decided by *"which decision is later"* — the D-1 Discovery supersession was decided exactly that way.

## Evidence that fixed the true dates

| Check | Result |
|---|---|
| Commits on or after 2026-08-16 | **none**, in any repository |
| `aura-backend` HEAD | `2a92a0e`, 2026-08-15 |
| `INSTITUTION_SPACE_MEMBERSHIP_DOCTRINE.md` — stamped "FROZEN 2026-08-16" | last commit **2026-08-13** |
| `docs/2026-08-16-…phase3-implementation.md` — dated *in its filename* | last commit **2026-08-12** |
| Working trees | clean, so last-commit dates are reliable |

## Correction rule applied

> Replace each `2026-08-16` with the **latest date the content could possibly have been authored** — that file's last-commit date.

This is a deliberate **upper bound**, not a claim about the exact day. Some rows inside a multi-day document may truly belong to an earlier date; none can belong to a later one. Choosing the upper bound never asserts something that git contradicts.

Where a file was uncommitted, today's date (2026-08-15) is the only defensible bound.

## Scope corrected — 40 files, 178 occurrences

### `aura-backend` — 28 files
19 markdown (continuity docs, capability doctrine, roadmap registers) and 9 TypeScript source files.

Largest: `AURA_RELEASE_CLIENT_CONSOLIDATED_ROADMAP.md` (48 occurrences → 2026-08-14) · `NEXT_WORK.md` (23 → 2026-08-15) · `CURRENT_STATE.md` (20 → 2026-08-15) · `DECISIONS.md` (12 → 2026-08-15).

**Two files were also renamed**, because the wrong date was in the filename itself:

| Was | Now |
|---|---|
| `docs/2026-08-16-realtime-architecture-correction-phase3-implementation.md` | `docs/2026-08-12-…` |
| `docs/2026-08-16-realtime-architecture-correction-phase4-implementation.md` | `docs/2026-08-13-…` |

Renamed with `git mv` so history follows. **All 7 referencing documents were updated in the same pass** — verified afterwards: zero remaining references to the old filenames.

### `aura_final` — 10 files
3 continuity docs, 5 `lib/` source files, 2 test files.

### `representation` — 1 file
`AGENTS.md` (Engineering Governance section) → 2026-08-15.

## Deliberately NOT corrected — **UNRESOLVED FACTUAL DATE, LEFT UNCHANGED PENDING SOURCE VERIFICATION**

`representation/presentation/startup-programs/estonia-startup-visa/notes/APPLICATION_OUTCOME_AND_REAPPLICATION_EVIDENCE.md` carries **5** instances of 2026-08-16.

I left it alone. It records **when a real acknowledgment was sent to the Estonian Startup Committee via Dealum** — a factual claim about external correspondence, in a closed project unrelated to this workstream. The file is untracked, so git offers no evidence of the true date, and changing it would rewrite a record of something that happened in the world rather than a stamp on my own work.

**Founder ruling, 2026-08-15:** this is **outside C0**, does not block closeout, and is **not** a frontend or product-architecture gap. No date is to be guessed, requested, or invented in order to close a chapter. It stays exactly as written until the true date is established from its own source.

## Verification

- No `2026-08-16` remains anywhere in `aura-backend` or `aura_final`.
- No reference to the old filenames remains.
- Backend and frontend test suites unaffected — the corrections are comments, prose and filenames only.

## Guarding against a recurrence

The standing rule is to derive every written date from the injected current date rather than from a surrounding document's existing text. This failure is the reason that rule exists: once one document carried a wrong date, later documents copied it forward, which is how a single slip reached 40 files across three repositories.
