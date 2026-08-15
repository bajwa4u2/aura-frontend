# DRAFT — Frontend Reconstruction Roadmap

# ⛔ SUPERSEDED 2026-08-15 — RETAINED FOR HISTORY

> **This draft is superseded by `FINAL_FRONTEND_RECONSTRUCTION_ROADMAP.md` (chapters C0–C11).**
>
> It was written **before any founder decision was frozen**, then had frozen inputs bolted on as adjudication progressed. **Its evidence remains valid; its sequencing logic does not.**
>
> Mapping and rationale: `FRONTEND_ROADMAP_OLD_TO_NEW_RECONCILIATION.md`. **Do not execute from this document.**

Structure is derived from dependency and authority, not from screens. **No chapter may start before the decisions it depends on are adjudicated.**

The governing sequencing rule discovered by this audit:

> **AUTHORITIES BEFORE SURFACES.** Attention, composition and IA all depend on knowing who is acting and what they may do. Rebuilding surfaces first rebuilds them twice.

**Governing enforcement rule (FD-13, FROZEN, applies to every chapter):** every chapter that rebuilds an authority must also **migrate its consumers**, **add the minimum hard-failing gate(s) preventing bypass**, and **run regression/certification** before that authority is called complete. **There is no separate enforcement chapter.** Each chapter records: frozen invariant, canonical owner, migrated consumers, prohibited competing pattern, enforcement mechanism, legitimate exceptions, regression evidence.

**Governing experience principle (FROZEN, applies to every chapter):** **CAPABILITY-ADAPTIVE EXPERIENCE** — one coherent product; context reveals capability; authority reveals actions; complexity appears only when needed; management object-local where practical; progressive disclosure required; presentation hierarchy is the client's, permission is the backend's. Today's role-fragmented experience must **not** be reconstructed with prettier components.

---

## Chapter F0 — Product & UX Architecture Freeze *(no code)*

Adjudicate `FOUNDER_DECISION_REGISTER.md`. Freeze realtime semantics per context, attention model, terminology, IA direction.

**Progress:**
- **FD-3 ✅ FROZEN 2026-08-15** — realtime product semantics + reconstruction mandate for creation/participation UX. See `FD3_REALTIME_SEMANTICS_FROZEN.md`.
- **FD-9 ✅ FROZEN 2026-08-15** — **Contextual Acting Authority**. See `FD9_ACTING_CONTEXT_FROZEN.md`.
- **FD-1 ✅ FROZEN 2026-08-15** — **One Governed Attention Hub + Actionable Attention**. See `FD1_ATTENTION_HUB_FROZEN.md`.
- **FD-2 ✅ FROZEN 2026-08-15** — **Obligation Badge** (attention vocabulary/exposure). See `FD2_ATTENTION_VOCABULARY_FROZEN.md`.
- **FD-5 ✅ FROZEN 2026-08-15** — **Live as a governed mode of a Thread/Space**; cross-repository chapter. See `FD5_LIVE_THREAD_SPACE_FROZEN.md`.
- **FD-10 ✅ FROZEN 2026-08-15** — **Canonical semantic vocabulary** (Correspondence distinct; Post canonical; Presence retained; Follow ≠ Connect; layered verification; Retry canonical; four CTA families). See `FD10_TERMINOLOGY_FROZEN.md`.
- **FD-13 ✅ FROZEN 2026-08-15** — **Gates ship with the authority they protect**; hard failure; no end-stage enforcement chapter. See `FD13_ENFORCEMENT_MECHANISMS_FROZEN.md`.
- **FD-12 ✅ FROZEN 2026-08-15** — **Proven-dead retirement only**; surface reachability principle approved, mechanism deferred to FD-13. See `FD12_SURFACE_DISPOSITION_FROZEN.md`.
- **FD-8 ✅ FROZEN 2026-08-15** — **Pre-publication official designation only**. See `FD8_OFFICIAL_DESIGNATION_MOMENT_FROZEN.md`.
- **FD-7 ✅ FROZEN 2026-08-15** — **Upload on selection** (attachment send model). See `FD7_ATTACHMENT_SEND_MODEL_FROZEN.md`.
- **FD-4 ✅ FROZEN 2026-08-15** — **Shared realtime presentation primitives, Meetings lifecycle untouched**. See `FD4_REALTIME_PRESENTATION_CONVERGENCE_FROZEN.md`.
- **FD-6 ✅ FROZEN 2026-08-15** — **Canonical Composition System + Context-Governed Experience** *(founder instruction labelled it "FD-2"; register FD-2 is a different, still-open decision)*. See `CANONICAL_COMPOSITION_SYSTEM_FROZEN.md`.
- **FD-11 ✅ FROZEN 2026-08-15** — **Canonical Identity Presentation + Contextual Projection**. See `CANONICAL_IDENTITY_PRESENTATION_FROZEN.md`.
- **TASK/DOMAIN-ORIENTED ADAPTIVE NAVIGATION + CONTEXTUAL DEPTH + CANONICAL PRODUCT LANGUAGE AUTHORITY ✅ FROZEN 2026-08-15** — *(navigation half had no register entry; language half governed the method; **FD-10 vocabulary is now FROZEN**)*. See `NAVIGATION_IA_PRODUCT_LANGUAGE_FROZEN.md`.
- **THREADS/SPACES PRODUCT MODEL ✅ FROZEN 2026-08-15** — distinct but composable. See `THREADS_SPACES_PRODUCT_MODEL_FROZEN.md`.
- **CONTENT INTAKE & RESOLUTION AUTHORITY ✅ FROZEN 2026-08-15** — cross-product, founder-surfaced. See `CONTENT_INTAKE_RESOLUTION_AUTHORITY_FROZEN.md`.
- **HUMAN TEMPORAL PRESENTATION AUTHORITY ✅ FROZEN 2026-08-15** — cross-product, founder-surfaced. See `HUMAN_TEMPORAL_PRESENTATION_AUTHORITY_FROZEN.md`.
- **CAPABILITY-ADAPTIVE EXPERIENCE ✅ FROZEN 2026-08-15** — cross-product principle constraining **every** chapter below. See `CAPABILITY_ADAPTIVE_EXPERIENCE_FROZEN.md`.

All other decisions remain open. The roadmap as a whole is **NOT approved**.

| Field | Value |
|---|---|
| Original items | — (governance) |
| Backend dependency | none |
| Blocks | everything |
| Certification | none |

---

## Chapter F1 — Client Authority Foundation

Identity/acting context · capability projection · navigation actions · state language · consumer enforcement gates.

**FD-13 (FROZEN):** F1 **establishes the enforcement pattern** — the first hard-failing architecture gates ship here, alongside the authorities they protect. Later chapters own their own.

**FD-3 input:** the People & Participation selection primitive belongs to this chapter's authority work — eligibility is resolved by backend authority, never re-derived in the client (reinforces Finding M1).

**FD-9 input (FROZEN):** **Acting Context becomes an explicit client authority** in this chapter. Person is the default actor; institutional context is entered deliberately and remains attributable; **person identity ≠ acting context ≠ institution profile**. The authority maintains, presents and propagates context — it must **never become shadow authorization** (backend decides eligibility and permission).

| Field | Value |
|---|---|
| Original items | 4 (Identity Foundation) |
| Extended scope | fail-closed auth projection, layered verification |
| Drift findings | M1 shadow governance (29+20 files), N2 route-mirroring, D3 no state language |
| New obligation | client capability projection; enforcement gates |
| Backend dependency | identity, verification, capability authorities (frozen) |
| Certification | Cross-System |

## Chapter F2 — Navigation & Information Architecture

**Governed by FD-9 — Contextual Acting Authority (FROZEN).**

One Release Client, one coherent navigation architecture. Navigation expresses **what the user is trying to do**, not which historical route tree the user is inside. Acting context is state/authority and must not duplicate the IA.

Work: one destination tree; canonical navigation actions; preserve session continuity and deep links; and apply the per-route test to all ~40 mirrored institution routes — **(A)** genuinely different institution-owned product semantic → preserve; **(B)** same capability under a different acting context → demolish/converge; ambiguous → return for adjudication.

**Explicitly rejected by FD-9:** a permanent global Personal/Institution toggle as the organising principle; separate mirrored applications; invisible representational switching. **Nothing is merged mechanically, and FD-9 authorizes recommendation — not deletion.**

| Field | Value |
|---|---|
| Original items | 11 (legacy overlay cleanup) |
| Drift findings | N1–N4, N6 |
| Backend dependency | institution capability (frozen) |
| Certification | Product-Behavior |

## Chapter F3 — Attention & Inbox

**Governed by FD-1 — One Governed Attention Hub + Actionable Attention (FROZEN).**

One governed Hub projecting attention across domains through a small set of semantic views (Conversations · Activity · Invitations · Actions). Attention is a **projection, never a new owner** of domain objects; actionable items expose **domain-owned** resolvable actions (`ATTENTION → CONTEXT → ACTION → RESOLUTION → CONTINUITY`), resolvable directly where safe, with deep routing to the exact owning context.

Work: Attention Authority with explicit state model (`UNREAD` is not universal); owning-domain clearing semantics; deterministic reconciliation so no dead CTAs survive; noise reduction (aggregation, deduplication, prioritisation, grouping, suppression); retire the dead surface (**FD-12: `conversations_screen` authorised for retirement**); cross-device read state.

**Badge contract (FD-2, FROZEN):** primary badge = **unresolved actionable obligations** (`ACTION_REQUIRED`, `INVITED`, `MISSED`, plus mentions representing unresolved attention). **Passive unread never contributes**; unread stays contextual. Internal lifecycle states remain behavioural, with contextual explanation of expired/dismissed permitted. Truncation `99+`. Expect the badge count to **drop sharply** — that is the intended correction.

**Constraints:** no mirrored institutional inbox (FD-9); realtime attention keeps its owning product semantics — **no generic "Calls" domain** (FD-3).

| Field | Value |
|---|---|
| Original items | 3 (Notification Delivery), 6 (Timeline) |
| Extended scope | Windows/WNS + mobile native presentation |
| Drift findings | A1 (8 surfaces), A2 (vocabulary), A3 (cross-device) |
| Backend dependency | notification delivery, attention, timeline (frozen) |
| Certification | Product-Behavior, Real-Boundary |

## Chapter F4 — Identity, Profile & Presence

**Governed by FD-11 — Canonical Identity Presentation + Contextual Projection (FROZEN).**

**PERSON ≠ INSTITUTION ≠ MEMBERSHIP ≠ ACTING CONTEXT ≠ PRESENCE**, never collapsed, yet one coherent identity experience. A **member is a Person + relationship — not a third identity type**. Institution is a **first-class identity**, not a company-shaped user.

Frozen hierarchy: **IDENTITY FIRST · CONTEXT SECOND · ACTIONS THIRD · METADATA ON DEMAND**, exposing the smallest useful current action set.

Work: canonical identity / relationship / presence / verification / action projections; contextual projection rather than per-context profile products; **three verification layers independently expressible** (no boolean flattening, no enum leakage, no badge clutter); presence as a permitted contextual projection where **technical connectivity ≠ social presence**.

**Constraints:** profile switching must never substitute for acting authority (FD-9); composers, realtime and attention **consume** these projections (FD-6, FD-3, FD-1). **FD-10 ✅ FROZEN:** Presence survives as the domain concept (not renamed to Availability); UI expresses the meaningful human state; verification keeps layered meaning with no generic "Verified" label. **Presence privacy/visibility policy and exact presentation copy remain OPEN.** Public/member profile is **DR5** — planning permission only.

| Field | Value |
|---|---|
| Original items | 4 |
| Drift findings | P1 (six meanings), P2 (3 implementations), P3 (weight), Representation "Verified" |
| Backend dependency | person identity projection, layered verification (frozen) |
| Certification | Product-Behavior |

## Chapter F5 — Composition & Attachments

**Governed by the frozen Canonical Composition System (register FD-6).**

One canonical composition system + shared attachment/media lifecycle + context-governed semantics + capability-adaptive presentation. **Composition ≠ representation ≠ delivery/publication.** Owning domains retain communication semantics — no forcing every surface to say Send or Publish. Attachment lifecycle stays distinct from communication/publication lifecycle. Default composer exposes only the immediate act; advanced formatting, media, audience, institutional and publication controls are progressive disclosure.

Work: canonical composition authority; shared attachment/media lifecycle (`SELECT/DROP/PASTE → VALIDATE → PREVIEW → UPLOAD → PROGRESS → CANCEL → RETRY → ATTACH → SEND/PUBLISH → RENDER/OPEN`) with **context policy** rather than duplicated mechanics; explicit voice/authority selection via acting context.

**Official designation (FD-8, FROZEN):** expressed **in the publish flow only** — never in writing. **No post-publication elevation.** Withdrawal object-local with provenance. **Any content change after approval invalidates it.** The approval-floor consequence must be legible **before** commitment (`DESIGNATE AS OFFICIAL -> SUBMIT FOR APPROVAL`), never an error at Publish. Client consumes eligibility and approval state; it never computes institutional authority.

**FD-7 (send model) ✅ FROZEN — UPLOAD ON SELECTION.** Upload begins on select/paste/drop; Send/Publish stays a separate deliberate act; uncommitted attachments belong to the **draft**; **explicit discard → immediate release**, uncontrolled abandonment → backend orphan cleanup; **attachment readiness is part of composition readiness** with **no silent queued-send**; no hybrid size/type timing; no internal lifecycle vocabulary in ordinary UI. **Carry-forward:** review backend orphan windows against the canonical draft lifetime — bring conflicts forward, do not change backend policy unilaterally. See `FD7_ATTACHMENT_SEND_MODEL_FROZEN.md`.

**Also in F5 — Content Intake & Resolution (FROZEN):** a governed input/resolution layer feeding canonical composition — rich paste preserving supported structure (**preserve richness, never invent it**), pasted images/files resolving as attachments, governed link previews consuming backend link intelligence, predictable mixed-content handling, and **drag-and-drop, which does not exist today (0 files)** and is required for the Windows/MSIX Release Client. See `CONTENT_INTAKE_RESOLUTION_AUTHORITY_FROZEN.md`.

**FD-9 constraint (FROZEN):** composers **consume governed acting context**. No composer may implement "post/send/reply as institution" via local role checks or its own selector. `ACTING CONTEXT + SURFACE CAPABILITY + BACKEND AUTHORITY → AVAILABLE REPRESENTATIONAL ACTION`. Where several legitimate acting identities exist, selection must be deliberate and understandable, and acting identity must be visible at the point of consequential action.

| Field | Value |
|---|---|
| Original items | 5 (Compose Link Intelligence), 10 (Selection/Clipboard/Rich Paste), 13 (External Link/OG), 14 (Internal Link Hydration), 15 (Rich-Text), 16 (Content-Length) |
| Drift findings | C1 (6 composers), C2 (11 uploads), C3 (voice) |
| Backend dependency | link intelligence, MIME policy, CIS classes, E_OFFICIAL (frozen) |
| Certification | Product-Behavior, Cross-System |

## Chapter F6 — Realtime Convergence

**Governed by FD-3 (FROZEN).** Two obligations held simultaneously:

- **Semantics preserved.** DM / Thread / Space / Institution Room / Meeting keep distinct ownership, initiation, invitation, participation, admission, authority, moderation, history, continuity and end-state. Meetings are never collapsed into a generic room/call abstraction.
- **UX reconstructed.** Creating, starting, adding/selecting/inviting people, joining and participant management must be modern, simplified and curated — **SIMPLIFY THE ACT, NOT THE AUTHORITY.**

Work (**FD-4 FROZEN**): converge participant list · host controls · admission/join-requests · consent onto **one shared component family** that renders **context-supplied states and language** — the component **does not own semantic meaning**. **No wholesale Meetings rewrite:** extract/replace proven duplicates **slice by slice, with targeted regression after each slice**. Preserve Meetings lifecycle; client for multi-device routing and D2 transfer; Institution Room client against frozen contracts; investigate a governed **People & Participation selection** primitive that never re-derives eligibility locally.

| Field | Value |
|---|---|
| Original items | 1 (Runtime Lifecycle), 2 (Device Presence), 7 (Realtime Correction), 9 (Lifecycle Ph2), **12 (Advanced Device Preference/Transfer)** |
| Drift findings | R1 (3 rooms), R2 (Institution Room mismatch), R3 (undefined semantics), R4 (no transfer client), R6 (notification asymmetry) |
| Preserve | R5 reconnect/orphan recovery |
| Backend dependency | D1, D2, D5, D6 (frozen) |
| Certification | Product-Behavior, Real-Boundary |

## Chapter F7 — Live Thread / Space *(new capability)*

**FD-5 FROZEN — OPTION A: Live as a governed mode/state of an owning Thread or Space.**

> **⚠ THIS IS A CROSS-REPOSITORY CHAPTER, NOT A FRONTEND PHASE.** Backend construction must not be hidden inside it.

**Backend construction required:** consume `PUBLIC_STAGE` · go-live authority · **public observation distinct from active media participation** · **audience-scale topology (SFU/broadcast — provider/topology NOT frozen)** · Live attention/interaction · replay-as-product.

**Already modelled (correction preserved):** `PUBLIC_STAGE`, participant roles (HOST/CO_HOST/MODERATOR/SPEAKER/PARTICIPANT/LISTENER/OBSERVER), hand-raise, per-track publish state — **vocabulary exists, mechanism does not.**

**Client:** consumes shared realtime primitives (FD-4) with context-supplied semantics; canonical delivery authorities for any ringing; attention in the owning Thread/Space.

**Rulings:** capability-based enablement · governed visibility (`GO LIVE != PUBLIC`) · invited + request-to-speak · reactions + governed questions only · explicit/opt-in recording with separately authorised replay owned by the Thread/Space · instant **and** scheduled · host/co-host end with advisory scheduled end · **audience attention does not ring**.

**FD-3 constraint (FROZEN):** Live emerges from the appropriate Thread/Space context and is **NOT to be treated as another Meeting merely because both use realtime media.**

| Field | Value |
|---|---|
| Original items | none — genuinely new |
| Backend dependency | **NOT YET BUILT** |
| Blocked by | **F6 convergence (staging APPROVED)**; 8 sub-decisions now RULED |
| Certification | Product-Behavior, Real-Boundary |

## Chapter F-T — Human Temporal Presentation *(cross-cutting)*

**Governed by the frozen Human Temporal Presentation Authority.** Not a standalone chapter in sequence — a cross-cutting obligation delivered alongside F2, F3 and F5.

> **MACHINES STORE PRECISE TIME; PEOPLE EXPERIENCE MEANINGFUL TIME.**

Work: semantic event type + canonical timestamp selection (**the owning domain decides which event time has meaning**) · humanized relative/absolute presentation · locale/timezone incl. DST and cross-timezone events · **sorting semantics per projection** (what event determines order?) · coherent aging of relative labels · exact time preserved where useful.

| Field | Value |
|---|---|
| Original items | 6 (Communication Timeline Authority) |
| Drift findings | **D5** — `relative_time` 9 consumers vs 52 hand-rolled; `createdAt` 295× vs `receivedAt` 0× |
| Backend dependency | communication timeline authority (frozen) |
| Constraints | FD-1 attention ordering; Canonical Product Language (temporal verbs) |
| Certification | Product-Behavior |

## Chapter F8 — Cross-Platform (mobile / web / MSIX)

Native notification presentation per platform; desktop file handling, **drag/drop (currently 0 implementations)**, keyboard, background, tray, deep links, window lifecycle.

**Content Intake constraint (FROZEN):** drop gestures resolve through the same governed intake layer as paste — not a desktop-only side path. See `CONTENT_INTAKE_RESOLUTION_AUTHORITY_FROZEN.md`.

| Field | Value |
|---|---|
| Original items | 7, 8 (iOS APNs) |
| Extended scope | **Windows/MSIX Release Client obligations** |
| Backend dependency | WNS/APNs/FCM/Web Push (frozen) |
| Certification | Real-Boundary |

## Chapter F9 — Accessibility & Performance

Keyboard, focus, screen readers, contrast, semantics, targets, scaling, reduced motion, captions, realtime participation a11y; architectural hotspots.

| Field | Value |
|---|---|
| Original items | 10 |
| Drift findings | D4 hotspots |
| Certification | Product-Behavior |

## Chapter F10 — Item 17: Integrated Release-Client Certification

**Unchanged and undiminished.** Integrated certification/release gate across all platforms.

| Field | Value |
|---|---|
| Original items | **17 — scope NOT reduced** |
| Status | OPEN, NOT STARTED |
| Certification | Founder Product Acceptance, Real-Boundary, Item 17 |

---

## Nothing vanished

Items 1–16 backend construction is complete; every item's **frontend** obligation is carried above. No item was merged away, renumbered or declared irrelevant. Item 17 remains a separate release gate at full scope.

Items 5, 10, 13, 14, 15, 16 all land in F5 because they are all composition-system obligations — that is convergence of *implementation*, not reduction of *scope*; each remains individually traceable.
