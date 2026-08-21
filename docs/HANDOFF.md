# Aura Release Client — Handoff

**2026-08-15, dated facts refreshed 2026-08-21.** For any agent or engineer picking this up.

> **Read `CURRENT_STATE.md` first.** The doctrine in this file is still correct; the
> repository picture below was written on 2026-08-15 and is refreshed at the bottom.

---

## Read these first, in order

1. `docs/CURRENT_STATE.md` — where everything stands
2. `docs/DECISIONS.md` — what is frozen
3. `docs/frontend-discovery/FINAL_FRONTEND_RECONSTRUCTION_ROADMAP.md` — the approved plan (C0–C11)
4. `docs/frontend-discovery/FRONTEND_RECONSTRUCTION_DEPENDENCY_GRAPH.md` — why chapters run in this order
5. `docs/NEXT_WORK.md` — the next executable chapter

## Non-negotiables

> **AUTHORITIES BEFORE SURFACES.**

- **Aura is PUBLIC-FIRST, not institution-first.** People are the originating force; institutional identity is accountability infrastructure, not the acquisition premise. Canonical source: `representation/inventory/AURA_PUBLIC_FIRST_CAUSAL_DOCTRINE.md`. Read `aura/AGENTS.md` → *Aura Public-First Causal Doctrine* for the pre-flight and drift rules. **It is a clarification, not a pivot** — do not treat older institution-first wording as product truth just because it is older.

- **Nothing may begin without explicit founder authorisation.** Roadmap approval ≠ chapter authorisation.
- **FD-13 definition of done:** a chapter is complete only with *authority + consumer migration + hard anti-drift gate + narrow reviewable exceptions + regression + certification*. **Code compiling is not completion.**
- **No standalone enforcement chapter.** Gates ship with the authority they protect.
- **Enforce the invariant, not the filename.** A gate that cannot be trusted becomes a recorded obligation — **never a downgraded warning**.
- **LIVE MUST NOT CREATE TEMPORARY VERSIONS OF AUTHORITIES ALREADY SCHEDULED FOR RECONSTRUCTION.**
- **Meetings is a protected certified surface** — presentation converges slice-by-slice with regression after each slice; the lifecycle is never rewritten.
- **Demolition ≠ data deletion.** Every rebuild preserves valid data, state, drafts and deep links.
- **Representation:** discover conflict → founder if semantic → resolve → update both repositories → enforce. **Never silently choose between repositories.**
- **Do not invent founder policy.** Open checkpoints are listed in `NEXT_WORK.md`; bring them forward rather than deciding them.

## Things that will surprise you

- **`PUBLIC_STAGE`, participant roles, hand-raise and per-track publish state already exist in the backend** — but `PUBLIC_STAGE` is unconsumed. *The vocabulary exists; the mechanism does not.*
- **Drag-and-drop exists in zero files**, while MSIX is a governed release target.
- **`conversations_screen.dart`** (1,033 lines) is unreachable and approved for retirement — **in C4, not opportunistically**.
- **`LoginScreen` looks dead to grep and is not.** Static reference count is not a reachability authority.
- **The frontend had no enforcement gates** while the backend had 14 plus migration-safety gates. That asymmetry was the root cause of most findings. **C0 closed the first part of it**: `test/product/c0_anti_drift_gate_test.dart` is now a hard build failure (4 zero-tolerance rules + 5 ratchets).
- **Raw discovery counts over-state drift.** 122 spinner uses are 26 real full-surface states; 69 `.difference()` calls include 28 legitimate internal TTL/cooldown uses and one `Set.difference` false positive. Classify before migrating — the roadmap's original C0 figures were wrong in both directions.
- **`Refresh` and `Reload` are NOT synonyms of `Retry`.** `saved_screen.dart` legitimately carries both. The gate governs the *position* (a recovery action must say Retry), not the word.
- **The C0 gate strips comments before matching.** Its first run failed on a doc comment that was explaining one of its own rules.
- **Representation is not upstream of product truth.** Its own Constitution says it *"cannot originate a fact about a product — it can only cite one."* `PRODUCT_IDENTITY_CANON` is centrally authoritative for exactly four sections (Identity, Purpose, Governing Philosophy, Scope); capability and implementation stay product-owned. Read `REPRESENTATION_CANONICAL_FRONTEND_ALIGNMENT.md` before citing Representation as authority.
- **A frozen Representation record can be stale.** The Discovery module's binding directive mandated a phrase two later canons ban. Chronology decides — later founder-frozen decisions win.
- **`Connect` and `Works` do not exist** anywhere in the canonical body or the codebase, and are gate-enforced absent. Do not reach for them.
- **Dates: derive from the injected current date, never from surrounding document text.** A single mis-dating of mine propagated to 40 files across three repositories before it was caught — see `docs/DATE_CORRECTION_2026-08-15.md`.
- The AppModule smoke boot **cannot run on Windows/ARM64** (no Prisma engine) — this is environmental, documented, and not a regression.

## Repositories

| Repo | State (2026-08-21) |
|---|---|
| `aura-backend` | the `2a92a0e` construction baseline is **historical**. Much has shipped since: CH-12 examination, governed media delivery, the release cutover. One uncommitted file — see below |
| `aura_final` | **committed and pushed.** `main` at `4420602`; certification branch `realtime-negotiation-certification` pushed. *"Nothing committed"* below was true on 2026-08-15 and is not true now |
| Representation | **3 founder-authorised reconciliation edits** (2026-08-15): Discovery directive superseded · Person-vs-Member note · Correspondence umbrella note. No frozen status, type, features or framing directive altered; no historical text deleted. |

## Current git state

`aura_final`: **C0 modified source.** New: `lib/core/product/` (4 files), `test/product/` (5 files incl. the frozen drift baseline). Modified: `lib/core/utils/relative_time.dart` (now a forwarding shim), 30 files whose `'Try again'` labels became `ProductAction.retry`, `lib/features/updates/presentation/updates_screen.dart`, `lib/features/communications/presentation/widgets/communication_empty_error_states.dart`, `lib/features/public/presentation/thread_screen.dart` (one `const` removed). **Nothing committed.**

**Meetings, routes, layout and visual treatment were not touched.**

---

## 2026-08-21 — what a new reader most needs to know

**Canonical accounting is current.** `RECONSTRUCTION_REGISTER.md` was regenerated through its
own generator; nothing was lost and fifteen already-recorded items became visible. Accounting
is unchanged at **143 findings + 308 obligations = 451 units across 17 chapters**.

**Read the register's distribution table correctly.** It is the **STAGE-0 RATIFIED BASELINE**
of 2026-08-18, not a live count — Stage-0 evidence is never rewritten. Later movement lives in
**LIVE CERTIFICATIONS**, **TERMINAL CLOSURES** and **RECORDED NON-TERMINAL TRANSITIONS** further
down the same file. Reading the table alone understates what has been done. `17/17` is chapter
*accounting coverage*, never completion — **no chapter has closed**. `138` is a historical
checkpoint and is not a live counter.

**Meetings realtime is PARKED** by founder ruling. Production reverted at `4420602`; one-way
media can still occur; **leave/rejoin remains the working workaround**. `9815742` FAILED
founder production certification — historical evidence, never a repair to reapply. Do not
reopen the investigation. See `docs/2026-08-21-meetings-realtime-certification-disposition.md`.

**`lib/rtc_harness/` is not product.** A separate entrypoint, unreachable from `lib/main.dart`
and `router.dart`, absent from every release bundle. It must stay outside the release surface.

**One uncommitted backend file**, deliberately: `aura-backend/src/media/media-payload-urls.spec.ts`
carries 24 lines whose narrative is right and whose assertions are tautologies — they assert on
locally declared constants and would pass even if the production behaviour were deleted. Not
committed, not deleted, reported in `NEXT_WORK.md`.

---

## 2026-08-18 — Wave 1 Parts 1 & 2 complete; what is next

**Done (nothing closed).** W1-000 PBCR 7+8 discharged · W1-A CH-17 governance mechanism (both repos) ·
W1-B CH-01 ratchets, 11/11 proven ENFORCING by seeded failure · W1-F 335-consumer identity audit ·
W1-C/D/E the CH-02 keystone S1–S3 with the PD-2 seam published and gated.

**Owed before CH-02 can close — none of it is optional:**

1. **F065 LIVE REFRESH PROOF.** The chapter's own first gate. A live authenticated session that
   survives a browser refresh without dropping to unauthenticated. Requires a running app and
   **PB-11 founder observation** of the authentication behaviour change. Until it passes, no
   downstream continuity finding may be claimed closed.
2. **Live signed-out probe** for the route-classification contract (S2). Fail-closedness is proven by
   gate, not yet on a live browser.
3. **F103 / F104** remain `OPEN`, gated by F065.
4. **CH-02 S4** (draft identity/ownership contract) still refused — it consumes CH-03's conformance
   gate, which is W2.

**Blocked on a founder decision:** W1-X1 (CH-11) needs the **RC-C5 scope ratification** — does the
BIFURCATED ruling answer CH-11's recorded scope question? Fail-closed default is *treat as gated*, so
CH-11 has not been started.

**Assigned but not scheduled:** DEFECT-1 — `realtime_room_golden_test.dart` is skipped for
pre-existing rot, so realtime *rendered* presentation has no automated visual proof. Assigned to
CH-04, not waived; restoration/replacement is a CH-04 closure requirement. The 333-pass realtime suite
must never be represented as covering it.
