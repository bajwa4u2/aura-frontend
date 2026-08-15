# Frontend Reconstruction — Dependency Graph

**Derived from the complete frozen decision set.** Chapter order is a consequence of these dependencies, not a preference.

---

## The founder-readable graph

```
C0  CROSS-CUTTING FOUNDATIONS
    (Product Language · Product State · Temporal Presentation)
        │  surface-agnostic; nothing depends on unstable authorities
        ▼
C1  ACTING CONTEXT & CAPABILITY PROJECTION
        │  "who is acting, and what may they do"
        │  ── blocks all institutional work and all route demolition
        ├──────────────┐
        ▼              ▼
C2  IDENTITY,       C3  NAVIGATION & IA
    PRESENCE,           (route demolition, surface reachability,
    PROFILE              deep-link migration)
    (+ People &          │
      Participation      │
      Selection)         │
        └──────┬─────────┘
               ▼
        ┌──────┴───────┬──────────────┐
        ▼              ▼              ▼
C4  ATTENTION     C5  COMPOSITION   C6  REALTIME
    (retires 8        INTAKE &          PRESENTATION
     hubs)            ATTACHMENTS       CONVERGENCE
        |              |                 |
        +------+-------+                 +-------------+
               |                         |             |
               |                  C7  THREADS,    C8  INSTITUTION
               |                      SPACES &        ROOM
               |                      CORRESPONDENCE  |
               |                         +------+-----+
               |                                |
   C9  CROSS-PLATFORM                           |
       (MSIX / mobile / web)                    |
       may OVERLAP C10 construction             |
               |                                v
               |                C10  LIVE  (CROSS-REPOSITORY)
               |                     consumes C0-C8 AUTHORITIES
               |                     backend construction + client
               |                                |
               +----------------+---------------+
                                v
     C9 platform certification + C10 Live certification
                                v
                 C11  ITEM 17 - RELEASE GATE
```

---

## Why each edge exists

| Edge | Reason |
|---|---|
| **C0 → everything** | Every surface renders state and time. Building surfaces first means rebuilding them when the authority lands. C0 touches no product semantics, so it is safe to run first. |
| **C1 → C3** | FD-9: mirrored institution routes may not be reconstructed before acting context exists — otherwise the mirroring is rebuilt, not removed. |
| **C1 → C2** | FD-11: **person identity ≠ acting context**. Identity cannot be modelled correctly while context is still carried by the route. |
| **C1 → C5** | FD-6: composition consumes acting context for **representation**. Building composers first reproduces per-composer "post as institution" selectors. |
| **C2 → C4** | Attention items reference people and institutions; they must project canonical identity, not invent it. |
| **C2 → C6** | FD-4/FD-11: participant presentation consumes canonical identity — no realtime-specific identity model. |
| **C2 → C5** | Mentions, recipients and people pickers consume identity projections. |
| **C3 → C4** | FD-1 requires deep routing to the **exact owning context**. That needs canonical navigation actions to exist. |
| **C3 → C5** | Navigation §10: composition originates from the context where communication belongs — entry points depend on the IA. |
| **C4 + C5 → C9** | Native notification presentation needs the attention authority; desktop drag/drop needs the content-intake authority. |
| **C6 → C7** | Threads/Spaces own their realtime; convergence must exist before their surfaces consume it. |
| **C6 → C8** | FD-5/DR2: Institution Room rebuilds on converged realtime primitives, not on the untyped-session screen. |
| **C6 → C10** | FD-5 §29: **staging approved** — convergence first, Live after. A fourth live surface on three unconverged ones repeats the documented failure. |
| **C3 → C10** | Live is a state of its owning Thread/Space; it must consume canonical navigation, contextual ownership, deep links and surface ownership. **No temporary Live navigation.** |
| **C4 → C10** | FD-5 freezes Live attention behaviour; it must consume the canonical Attention Authority. **No temporary Live notification path.** |
| **C5 → C10** | Live questions, surrounding discussion and replay relationships must not be built on composers already authorised for demolition. |
| **C7 + C8 → C10** | Live is a **mode of a Thread/Space**; the owning contexts must be reconstructed first. |
| **all → C11** | Item 17 is an integrated release gate, not a construction chapter. |

---

## Two kinds of prerequisite — do not conflate them

> **CORRECTED 2026-08-15 (founder review).** An earlier version of this document stated that *"C3, C4, C5 and C9 are not on the critical path to Live."* **That statement was too permissive and is withdrawn.** It conflated an engineering build order with a product-architecture dependency, and could later have been read as authorisation for Live to invent its own navigation, attention or composition.

| Prerequisite type | Meaning |
|---|---|
| **ENGINEERING PREREQUISITE** | must exist before this work can technically proceed |
| **PRODUCT-ARCHITECTURE / COMPLETION PREREQUISITE** | governs what the product **is**; the chapter cannot be correct or complete without consuming it |

### GOVERNING INVARIANT (FROZEN)

> **LIVE MUST NOT CREATE TEMPORARY VERSIONS OF AUTHORITIES ALREADY SCHEDULED FOR RECONSTRUCTION.**

### C3, C4 and C5 are PRODUCT dependencies of Live

| Chapter | Why Live must consume it |
|---|---|
| **C3 — Navigation / IA** | Live is a governed **state of its owning Thread/Space**, so it must consume canonical navigation, contextual ownership, deep-link behaviour, surface ownership and acting-context navigation. **C10 may not invent temporary Live navigation.** |
| **C4 — Attention** | FD-5 freezes Live attention behaviour: ordinary audience eligibility **does not ring**; invited speakers/active participants may be interrupted; actionable Live invitations must resolve; **Live attention belongs to its originating Thread/Space**; **no generic Calls/Live inbox**. **C10 may not build a temporary Live notification/attention implementation.** |
| **C5 — Composition / Intake** | Live includes governed questions, continuing Thread/Space discussion, replay/content relationships and surrounding contextual communication. **These must not be built against composer/attachment systems already authorised for demolition.** |

## Critical path (corrected)

```
C0 → C1 → {C2 ∥ C3} → {C4 ∥ C5 ∥ C6} → {C7 ∥ C8} → C10 → C11
```

**Live construction is eligible to begin only once every Live-consumed authority is stable** — C0, C1, C2, **C3**, **C4**, **C5**, C6, C7, C8.

## C9 / C10 relationship — overlap permitted, completion is not

C9 is **different in kind** from C3/C4/C5. It does not have to finish before C10 construction begins.

| Distinction | Rule |
|---|---|
| **C10 CONSTRUCTION ENTRY** | requires the Live-consumed **authorities** (C0–C8) to be stable. **C9 need not be complete.** |
| **C10 CROSS-PLATFORM COMPLETION / CERTIFICATION** | **requires the relevant C9 platform contracts to be proven** — MSIX native notification behaviour, desktop lifecycle, realtime foreground/background continuity, responsive presentation, deep links, platform media behaviour, semantic mobile/web/MSIX parity, real-device behaviour |

**C9 may execute and overlap with C10 wherever its own dependencies permit.**

```
C9 REQUIRED PLATFORM CERTIFICATION + C10 LIVE CERTIFICATION → C11 ITEM 17
```

**Item 17** requires C0–C9 complete, plus C10 complete or explicitly excluded from the release candidate by founder decision.

---

## Parallel-safe branches

| After | Parallel branches | Shared risk | Reconciliation point |
|---|---|---|---|
| **C0 start** | Product Language ∥ Product State ∥ Temporal | none — three independent authorities | end of C0 |
| **C1 complete** | **C2** ∥ **C3** | both touch shells and route-adjacent surfaces | **route ownership handoff** — C3 owns route definitions; C2 consumes them |
| **C2 + C3 complete** | **C4** ∥ **C5** ∥ **C6** | all consume identity/navigation (frozen by then) | integration checkpoint before C7 |
| **C4 + C5 complete** | **C9** ∥ continue C6 | C9 needs both attention and intake | before C11 |
| **C6 complete** | **C7** ∥ **C8** | both consume realtime primitives (frozen by then) | before C10 |
| **After semantic wording is frozen** | **Representation alignment** ∥ frontend implementation | product language must already be founder-frozen | per-chapter language checkpoint |

> **Do not parallelise work that shares an unstable authority.** Every branch above starts only after its shared dependency is frozen and enforced.

---

## What must NOT start early

| Work | Blocked until | Why |
|---|---|---|
| Mirrored route removal | **C1** | would rebuild mirroring instead of removing it (FD-9) |
| Any composer replacement | **C5 authority** | reproduces six composers (FD-6) |
| Institution Room rebuild | **C6** | would rebuild on unconverged primitives (DR2) |
| **Live — client or backend** | **C0–C8 (all Live-consumed authorities)** | FD-5 §29 staging **plus** the frozen invariant: Live must not create temporary versions of authorities already scheduled for reconstruction. **C3/C4/C5 are product dependencies, not optional.** |
| Retiring the 8 attention hubs | **C4 authority** | leaves users with no replacement |
| Retiring `conversations_screen` | **C4** | it belongs to attention territory (FD-12) |
| Item 17 | **all chapters** | it is a gate, not a dumping ground |
| Representation edits | founder-frozen wording | FD-10/§25 — never race ahead of unresolved language |
