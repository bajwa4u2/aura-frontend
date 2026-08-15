# Aura Release Client — Current State

**Last updated: 2026-08-15**

---

## Status

| Track | State |
|---|---|
| **Backend construction baseline** | ✅ **FROZEN** (aura-backend, commit `2a92a0e`) |
| **Frontend product-architecture adjudication** | ✅ **COMPLETE / FROZEN** |
| **Final frontend reconstruction roadmap** | ✅ **FOUNDER APPROVED / FROZEN** |
| **C0 — Cross-Cutting Foundations** | ✅ **COMPLETE / FOUNDER APPROVED / LOCALLY CERTIFIED** (2026-08-15) |
| **C1 — Acting Context & Capability** | ⛔ **READY / NOT STARTED / NOT YET AUTHORIZED** |
| **Frontend implementation (C2–C11)** | ⛔ **NOT STARTED** |
| **Item 17 — Release Gate** | ⛔ **OPEN, NOT STARTED** |

## What is frozen

**Founder Decision Register — fully adjudicated.** FD-1 … FD-13 all RESOLVED/FROZEN, plus five named cross-product freezes: Capability-Adaptive Experience · Task/Domain-Oriented Adaptive Navigation + Canonical Product Language Authority · Threads/Spaces Product Model · Content Intake & Resolution Authority · Human Temporal Presentation Authority.

**Final roadmap — 12 chapters (C0–C11)**, organised by product authority and dependency, governed by **AUTHORITIES BEFORE SURFACES**.

## Where things live

| Area | Location |
|---|---|
| All frozen decisions, audits, matrices, roadmap | `docs/frontend-discovery/` (41 documents) |
| Final roadmap | `docs/frontend-discovery/FINAL_FRONTEND_RECONSTRUCTION_ROADMAP.md` |
| Dependency graph | `docs/frontend-discovery/FRONTEND_RECONSTRUCTION_DEPENDENCY_GRAPH.md` |
| Founder Decision Register | `docs/frontend-discovery/FOUNDER_DECISION_REGISTER.md` |
| Superseded draft (retained) | `docs/frontend-discovery/DRAFT_FRONTEND_RECONSTRUCTION_ROADMAP.md` |

## Codebase facts (measured 2026-08-15)

189,134 lines · 544 Dart files · 171 routes · 27 redirects · 136 screen classes · 37 feature directories.

**Known reconstruction territory:** 8 attention surfaces · 6 composers · 11 upload pipelines · 40 mirrored institution routes · 3 profile implementations · 3 thread screens · 3 live-room implementations · 83 raw spinners vs 63 shared · 68 blank empty states · 52 hand-rolled `.difference()` · 29 role checks + 20 `canX` · **0 drag-and-drop implementations**.

## C0 — Cross-Cutting Foundations (implemented 2026-08-15)

Three authorities now exist in `lib/core/product/`:

| Authority | File |
|---|---|
| Product Language | `product_language.dart` |
| Product State Presentation | `product_state.dart` · `product_state_view.dart` |
| Human Temporal Presentation | `temporal.dart` |

**Migrated:** 33 `'Try again'` labels across 30 files → canonical `ProductAction.retry`; one `Refresh` sitting in a recovery position; `relative_time.dart` now forwards to `AuraTemporal` (9 transitive consumers); `local_timezone.dart` reached via `AuraTemporal.zoneId`; `CommLoadingState` / `CommErrorState` → `AuraProductState`.

**Two deliberate visible changes:** older timestamps read `Aug 12` rather than the machine form `2026-08-12`, and future instants no longer render as `now` (a real pre-existing bug — `formatRelative` took a negative difference through its `inSeconds < 60` branch).

**Enforcement:** `test/product/c0_anti_drift_gate_test.dart` — hard build failure. Four zero-tolerance rules plus five ratchets (G2/G3/G4/G5/G7) frozen in `test/product/c0_drift_baseline.txt`. Each rule was verified to actually fail by introducing a deliberate violation.

**Not migrated, frozen as measured debt:** 24 local elapsed-time sites · 47 `toLocal()` · 26 full-surface spinners (**14 in Meetings**) · 181 direct state-primitive constructions · 17 screen-declared time formatters. Meetings is a **PROTECTED CERTIFIED SURFACE** and was not touched.

**Founder review, 2026-08-15 — FULLY ADJUDICATED.** Approved and applied: the two temporal changes · the future-time bug correction · the G5 ownership doctrine · the baseline/ratchet approach · `addMember`/`invitePerson`/`manageInvites` added to the language authority · **Person = canonical human identity, Member = contextual status** · **Correspondence = one meaning**, umbrella sense retired to a C7 obligation · the Discovery "trusted discovery" directive marked superseded in Representation · Connect/Works gate-enforced absent.

**Date correction.** The `2026-08-16` stamps were my own authoring error, not a provenance mystery. **40 files / 178 occurrences** corrected across three repositories to each file's git-evidenced date, plus two file renames. One file deliberately left alone pending a founder answer — see `docs/DATE_CORRECTION_2026-08-15.md`.

**G5 ownership: all 181 sites assigned, zero unassigned** — C1 42 · C2 21 · C3 44 · C4 26 · C5 16 · C7 26 · C8 3 · C9 3. **Meetings holds zero G5 sites** (its protected sites are G3/G4). 74 sites assigned from roadmap text, **107 from labelled judgment** — because the approved roadmap never names an owner for platform admin, institution admin, public directory, search/saves/updates or auth surfaces.

**Representation alignment pass (read-only) complete.** Nothing in Representation was edited. Found: `Add Member`/`Invite Person`/`Manage Invites` is a FROZEN doctrine the Product Language Authority cannot currently express (HIGH); the Discovery module's “trusted discovery” directive is banned by two later canons; “Correspondence” carries two governance meanings; `Connect` and `Works` have no canonical existence anywhere and are now gate-enforced absent.

Registers: `C0_MIGRATION_REGISTER.md` · `C0_G5_OWNERSHIP_MATRIX.md` · `C0_PRODUCT_LANGUAGE_VOCABULARY.md` · `REPRESENTATION_CANONICAL_FRONTEND_ALIGNMENT.md` · `REPRESENTATION_FRONTEND_REDESIGN_INPUTS.md`.

**Verification:** `flutter analyze lib/ test/` clean · `flutter test` **458 passed / 1 skipped / 0 failed** (411 pre-C0, +47 new — no regressions).

## What has NOT been touched

No routes · no screens redesigned · no layout or visual treatment changed · Meetings untouched · no backend · no Representation. **Nothing committed.**
