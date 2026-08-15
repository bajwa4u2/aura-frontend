# Frontend Product Architecture Discovery

**2026-08-15. Investigation only — no code was modified.** Index and executive layer for the 40 companion documents in this directory.

---

## Executive finding

The current frontend's problem is **not** that it has too many capabilities. It is that it has **too many implementations of too few defined concepts**.

Measured: 189,134 lines across 544 files, 171 routes, 136 screens, 37 features — containing 3 live-room implementations, 3 profile implementations, 3 thread screens, 6 composers, 8 attention surfaces and 11 upload pipelines. Almost none of that multiplicity corresponds to a product distinction anyone chose. It corresponds to *the order in which features arrived*.

The founder's description of the failure mode is confirmed exactly:

> problem appears → patch local screen → another feature arrives → another patch → another module interprets the same behaviour differently → shared authority arrives later → incomplete migration → drift

The clearest single proof: **`AuraLoadingState` is used in 63 files while raw `CircularProgressIndicator` persists in 83.** The shared authority exists, arrived late, and adoption was never finished. The same pattern recurs for realtime (transport shared, presentation not), for attention (`module_attention` exists, six older hubs ignore it), and for capability (a backend authority exists, 29 files still compare roles locally).

**Therefore the reconstruction thesis is not "rebuild the screens".** It is:

> **Establish client authorities, enforce their consumers, and let surfaces become thin.**

The backend chapter just proved this works: drift stopped recurring there only once structural gates made it impossible. The frontend has no equivalent mechanism, which is the root cause of most findings in this discovery.

---

## What is genuinely good and must survive

- **Realtime transport and recovery** — `realtime_controller`, media service, event parser, reconciliation, orphaned-session handling. The best-engineered area in the client.
- **Session continuity across navigation** — `floating_call_widget`, `incoming_live_overlay`, `thread_call_lifecycle_host`. This already matches where the market converged.
- **The visual design system** — sound; the failure is adoption, not design.
- **Meetings lifecycle** — certified, with real product stages (`prep`, `waiting`, `summary`) that are not drift.
- **The product capabilities themselves** — the breadth is an asset. Nothing in this discovery recommends removing capability.

---

## The four structural faults

1. **No client authorities.** Composition, attachment, attention, participant, capability and identity have no owner, so each surface owns a private version.
2. **Context encoded as address space.** 40 mirrored `/institution/:institutionId/...` routes make "acting as an institution" a URL prefix instead of an actor identity — contradicting frozen backend doctrine.
3. **Undefined product semantics.** Realtime means something different in DM, Thread, Space, Meeting and Institution Room, and this has never been written down — so the client generalises and Meetings becomes "the special one".
4. **No enforcement.** Nothing prevents the next divergence. Every fault above is a *recurrence*, not a first occurrence.

---

## Backend/frontend gap opened by the freeze

The backend baseline froze capabilities the client cannot express at all:

| Frozen backend capability | Client state |
|---|---|
| Institution Room (participants, invitation, ring policy) | absent — a different concept is shown |
| D2 mid-call device transfer | absent |
| D1 preferred-device routing / stagger | invisible |
| Layered verification (3 independent layers) | collapsed to one "Verified" |
| E_OFFICIAL designation + institutional approval floor | no product language |
| Account lifecycle / disposition states | no vocabulary |

This is **new construction against frozen authority**, not drift, and must not be confused with cleanup.

**Live (FD-5) adds a further backend gap — corrected evidence:** `PUBLIC_STAGE`, participant roles (HOST/CO_HOST/MODERATOR/SPEAKER/PARTICIPANT/LISTENER/OBSERVER), hand-raise and per-track publish state **are already modelled**; an earlier claim that no speaker/audience model existed is **withdrawn**. But `PUBLIC_STAGE` is **declared and unconsumed**, and go-live authority, public observation, audience scale, Live attention/interaction and replay-as-product are **missing**. **FD-5 is a cross-repository chapter, not a frontend phase.**

---

## Document index

| # | Document | Contains |
|---|---|---|
| 1 | this file | executive layer, thesis, index |
| 2 | `FRONTEND_SURFACE_INVENTORY.md` | measured scale, hotspots, duplicated families, dead surfaces |
| 3 | `FRONTEND_AUTHORITY_CONSUMER_MATRIX.md` | 14 proposed authorities, shadow governance, enforcement |
| 4 | `REALTIME_PRODUCT_MODEL_AUDIT.md` | R1–R6, per-context semantics table |
| 5 | `COMPOSER_MESSAGING_ATTACHMENT_AUDIT.md` | C1–C3, capability matrix, 11 upload paths |
| 6 | `LIVE_THREAD_SPACE_ARCHITECTURE_OPTIONS.md` | 3 options, Meetings distinction, 8 sub-decisions |
| 7 | `PROFILE_PRESENCE_IDENTITY_AUDIT.md` | P1–P3, six meanings of "presence" |
| 8 | `INBOX_ATTENTION_AUDIT.md` | A1–A3, 8 surfaces, attention vocabulary |
| 9 | `CTA_TERMINOLOGY_DRIFT_AUDIT.md` | T1–T3, CTA semantic map |
| 10 | `NAVIGATION_IA_AUDIT.md` | N1–N6, route mirroring |
| 11 | `DESIGN_PRODUCT_SYSTEM_AUDIT.md` | D1–D4, visual vs product system |
| 12 | `DEMOLITION_REBUILD_CANDIDATES.md` | DR1–DR4 with salvage lists |
| 13 | `REPRESENTATION_COPY_DRIFT_REGISTER.md` | terminology register (nothing edited) |
| 14 | `GLOBAL_PRODUCT_PATTERN_RESEARCH.md` | market patterns and implications |
| 15 | `DRAFT_FRONTEND_RECONSTRUCTION_ROADMAP.md` | **DRAFT** F0–F10 with Items 1–17 traceability |
| 16 | `FOUNDER_DECISION_REGISTER.md` | FD-1…FD-13 with dependency order |
| 17 | `FD3_REALTIME_SEMANTICS_FROZEN.md` | **FROZEN** realtime semantics + UX reconstruction mandate + anti-drift guard |
| 18 | `FD9_ACTING_CONTEXT_FROZEN.md` | **FROZEN** Contextual Acting Authority + route-tree test + anti-drift guard |
| 19 | `FD1_ATTENTION_HUB_FROZEN.md` | **FROZEN** One Governed Attention Hub + Actionable Attention + anti-drift guard |
| 20 | `CANONICAL_COMPOSITION_SYSTEM_FROZEN.md` | **FROZEN** Canonical Composition System (register FD-6) + numbering reconciliation |
| 21 | `CAPABILITY_ADAPTIVE_EXPERIENCE_FROZEN.md` | **FROZEN** cross-product experience principle + anti-drift guard |
| 22 | `CANONICAL_IDENTITY_PRESENTATION_FROZEN.md` | **FROZEN** Canonical Identity Presentation + Contextual Projection (register FD-11) |
| 23 | `NAVIGATION_IA_PRODUCT_LANGUAGE_FROZEN.md` | **FROZEN** Task/Domain-Oriented Adaptive Navigation + Contextual Depth + Canonical Product Language Authority |
| 24 | `THREADS_SPACES_PRODUCT_MODEL_FROZEN.md` | **FROZEN** Threads/Spaces — distinct but composable |
| 25 | `CONTENT_INTAKE_RESOLUTION_AUTHORITY_FROZEN.md` | **FROZEN** Content Intake & Resolution Authority *(founder-surfaced)* |
| 26 | `HUMAN_TEMPORAL_PRESENTATION_AUTHORITY_FROZEN.md` | **FROZEN** Human Temporal Presentation Authority *(founder-surfaced)* |
| 27 | `FD2_ATTENTION_VOCABULARY_FROZEN.md` | **FROZEN** FD-2 Attention Vocabulary — Obligation Badge |
| 28 | `FD4_REALTIME_PRESENTATION_CONVERGENCE_FROZEN.md` | **FROZEN** FD-4 Realtime Presentation Convergence |
| 29 | `FD7_ATTACHMENT_SEND_MODEL_FROZEN.md` | **FROZEN** FD-7 Attachment Send Model — Upload on Selection |
| 30 | `FD8_OFFICIAL_DESIGNATION_MOMENT_FROZEN.md` | **FROZEN** FD-8 Official Designation — Pre-Publication Only |
| 31 | `FD12_SURFACE_DISPOSITION_FROZEN.md` | **FROZEN** FD-12 Surface Disposition — Proven-Dead Retirement Only |
| 32 | `FD13_ENFORCEMENT_MECHANISMS_FROZEN.md` | **FROZEN** FD-13 Enforcement — Gates Ship With Their Authority |
| 33 | `FD10_TERMINOLOGY_FROZEN.md` | **FROZEN** FD-10 Terminology — Canonical Semantic Vocabulary |
| 34 | `FD5_LIVE_THREAD_SPACE_FROZEN.md` | **FROZEN** FD-5 Live — Governed Mode of a Thread/Space |
| **35** | **`FINAL_FRONTEND_RECONSTRUCTION_ROADMAP.md`** | **FINAL roadmap — C0–C11 — FOUNDER APPROVED / FROZEN** |
| 36 | `FRONTEND_RECONSTRUCTION_DEPENDENCY_GRAPH.md` | dependency graph, critical path, parallel branches, what must not start early |
| 37 | `FRONTEND_RECONSTRUCTION_TRACEABILITY_MATRIX.md` | Items 1–17, extended scope, FD-1–13, five freezes, demolition, discoveries |
| 38 | `FRONTEND_RECONSTRUCTION_DEMOLITION_MATRIX.md` | per-domain classification, survives/dies, migration risk |
| 39 | `FRONTEND_AUTHORITY_FINAL_MAP.md` | 16 authorities + authorities deliberately not created |
| 40 | `FRONTEND_CERTIFICATION_AND_FOUNDER_GATES.md` | certification layers, 16 founder checkpoints, 9 open checkpoints |
| 41 | `FRONTEND_ROADMAP_OLD_TO_NEW_RECONCILIATION.md` | F0–F10 → C0–C11 mapping and rationale |

---

## Discovery is not closed

Two frozen obligations — **Content Intake & Resolution** and **Human Temporal Presentation** — were **surfaced by the founder after this audit completed**. The audit measured composer *capability* but never tested intake *quality*, and never examined temporal presentation or sorting semantics at all.

Recording them produced a further measured discovery neither party had: **drag-and-drop is implemented in zero files**, despite Windows/MSIX being a governed release target.

**The roadmap is therefore not limited to the original FD list or audit categories.** Newly exposed systemic drift, missing authorities or duplicated product concepts must be brought forward — never buried, silently deferred, or forced into an unrelated decision to complete a checklist.

## Status

**ADJUDICATION COMPLETE / FROZEN. FINAL ROADMAP FOUNDER APPROVED / FROZEN (2026-08-15). IMPLEMENTATION NOT STARTED.**

The complete frozen decision set has been reconstructed into **12 chapters (C0–C11)** organised by product authority and dependency — **not** by screen, route or folder. The old F0–F10 draft is **superseded and retained for history**.

**Register closure is not roadmap approval, and roadmap review is not implementation authorisation.**

| Decision | Status |
|---|---|
| **FD-3 realtime product semantics** | ✅ **FROZEN — founder approved 2026-08-15** |
| **FD-9 — Contextual Acting Authority** | ✅ **FROZEN — founder approved 2026-08-15** |
| **FD-1 — One Governed Attention Hub + Actionable Attention** | ✅ **FROZEN — founder approved 2026-08-15** |
| **FD-2 — Attention Vocabulary: Obligation Badge** | ✅ **FROZEN — founder approved 2026-08-15** |
| **FD-4 — Realtime Presentation Convergence** | ✅ **FROZEN — founder approved 2026-08-15** |
| **FD-7 — Attachment Send Model: Upload on Selection** | ✅ **FROZEN — founder approved 2026-08-15** |
| **FD-8 — Official Designation: Pre-Publication Only** | ✅ **FROZEN — founder approved 2026-08-15** |
| **FD-12 — Surface Disposition: Proven-Dead Retirement Only** | ✅ **FROZEN — founder approved 2026-08-15** |
| **FD-13 — Enforcement: Gates Ship With Their Authority** | ✅ **FROZEN — founder approved 2026-08-15** |
| **FD-10 — Terminology: Canonical Semantic Vocabulary** | ✅ **FROZEN — founder approved 2026-08-15** |
| **FD-5 — Live: Governed Mode of a Thread/Space** | ✅ **FROZEN — founder approved 2026-08-15** |
| **FD-6 — Canonical Composition System** | ✅ **FROZEN — founder approved 2026-08-15** |
| **Capability-Adaptive Experience** *(cross-product principle)* | ✅ **FROZEN — founder approved 2026-08-15** |
| **Task/Domain-Oriented Adaptive Navigation + Canonical Product Language Authority** *(named; navigation half had no register entry)* | ✅ **FROZEN — founder approved 2026-08-15** |
| **Threads/Spaces Product Model** *(named)* | ✅ **FROZEN — founder approved 2026-08-15** |
| **Content Intake & Resolution Authority** *(named, cross-product)* | ✅ **FROZEN — founder-surfaced 2026-08-15** |
| **Human Temporal Presentation Authority** *(named, cross-product)* | ✅ **FROZEN — founder-surfaced 2026-08-15** |
| **FD-11 — Canonical Identity Presentation + Contextual Projection** | ✅ **FROZEN — founder approved 2026-08-15** |
| *(none)* | **THE FOUNDER DECISION REGISTER IS FULLY ADJUDICATED** | (FD-7 constrained by FD-6; **FD-10 constrained by FD-11 and governed in method by the Product Language Authority — but still undecided**) |

> **⚠ Numbering caution.** Founder instructions have twice used a number differing from the register — *Contextual Acting Authority* was labelled "FD-9 Option C" (a rejected option), and *Canonical Composition System* was labelled "FD-2" (register FD-2 is Attention vocabulary, still open). **Decisions are authoritative by NAME.**

No implementation has begun. The roadmap remains **DRAFT — PENDING FOUNDER ADJUDICATION**. Items 1–17 traceability is preserved; Item 17 remains open at full scope.

**FD-3 in one line:** distinct product semantics are frozen *and* the creation/participation UX is frozen as **to be reconstructed** — semantic separation is not permission to preserve UX fragmentation, and UX convergence is not permission to collapse product semantics.

**FD-9 in one line:** one Release Client with one coherent navigation architecture and first-class **Acting Context** — person is the default actor, institutional acting is entered deliberately and stays attributable, backend defines eligibility, and mirrored route trees fall **only** where their sole purpose was acting-context duplication.

**Canonical Composition System in one line:** one composition system and one attachment/media lifecycle, with **composition ≠ representation ≠ delivery/publication**, owning domains keeping their communication semantics, and a default composer that exposes only the immediate act.

**Canonical Identity Presentation in one line:** one identity experience projecting context onto canonical Person/Institution — **person ≠ institution ≠ membership ≠ acting context ≠ presence**, a member is a person with a relationship, identity comes first and metadata last, and technical connectivity never silently becomes social presence.

**Task/Domain-Oriented Adaptive Navigation in one line:** one information architecture where **people navigate to objects and intentions, not backend modules** — few stable primary destinations, objects owning their own depth, deep links landing exactly where they should, and a Canonical Product Language Authority that converges synonyms while preserving genuine distinctions. *Exact destinations deliberately not frozen.*

**Capability-Adaptive Experience in one line:** one coherent product where **roles change available capability, not the product** — context reveals capability, authority reveals actions, complexity appears only when needed, and the client decides presentation hierarchy while the backend decides permission.

Together these now address all **four structural faults**: *undefined product semantics* (FD-3), *context encoded as address space* (FD-9 + Navigation freeze), *no client authorities* (FD-1, FD-6, FD-11, Capability-Adaptive Experience), and *no enforcement* (**FD-13, now FROZEN**: hard-failing source-level gates and architecture tests that **ship with each authority**, with no end-stage enforcement chapter). **All four structural faults now have frozen answers.**
