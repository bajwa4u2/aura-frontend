# Frontend Authority / Consumer Matrix

Proposed client-side authorities. The pattern for each is:

**backend contract → repository → client authority → presentation model → consumer set**

Status is measured, not aspirational.

| Proposed authority | Exists today? | Evidence | Consumers | Drift risk |
|---|---|---|---|---|
| **Acting Context** (FD-9 ✅ FROZEN) | ❌ | context carried by 40 mirrored routes | every surface | **critical** |
| **Person identity** (distinct from acting context) | partial | conflated with acting context today | profile, composer, realtime | high |
| **Identity projection** (FD-11 ✅ FROZEN) | ❌ | 3 implementations (`profile/`, `me/`, `institutions/profile/`) | profile, feed, participants, composer, realtime, attention | high |
| **Presence projection** (FD-11 ✅ FROZEN) | partial | `PresenceStatus`, `PresencePinger` | profile, participants, DM | high (word has 6 meanings) |
| **Attention** (FD-1 ✅ FROZEN) | partial | `updates/module_attention` exists, not adopted by 6 older hubs | 8 surfaces | **critical** |
| **Notification presentation** | partial | `updates/`, `incoming_call_bridge` | calls, notifications | high |
| **Realtime session** | ✅ | `realtime_controller` (2,737 lines) | 3 room screens — transport only | medium |
| **Participant presentation** (FD-4 ✅ FROZEN) | ❌ | 2 implementations (shared widget vs Meetings-internal); 5 shared widgets used 0× by Meetings | rooms, meetings, future Live | high |
| **Composition** (FD-6 ✅ FROZEN) | ❌ | 6 composers | all publishing surfaces | **critical** |
| **Attachment / media lifecycle** (FD-6 ✅ FROZEN) | ❌ | 11 implementations | composers, profiles, meetings | **critical** |
| **Navigation** (✅ FROZEN) | ❌ | literal `context.go('/path')` throughout; 171 routes, 27 redirects | all | high |
| **Product language / CTA** (FD-10 ✅ FROZEN — vocabulary + method) | ❌ | `Try again` 29 vs `Retry` 22; 4 words for stop/undo | all | high |
| **Capabilities / permissions** | ❌ | `canX` in 20 files, role checks in 29 | institution surfaces | **critical** |
| **Relationship projection** (FD-11 ✅ FROZEN) | partial | `profile/` follow surfaces | profile, feed | medium |
| **Verification projection** (FD-11 ✅ FROZEN) | ❌ | `'Verified'` shown as one label over 3 backend layers | profile, participants, pickers | high |
| **Content rendering** | partial | `unified_feed_card` (1,893), `post_card` (1,520) | feed, profile, thread | medium |
| **Lifecycle (account state)** | ❌ | none found | profile, auth | medium |
| **Content intake / resolution** (✅ FROZEN) | ❌ | Clipboard in 25 files, paste in 25, **drag-drop in 0** | all composition surfaces | **critical** |
| **Temporal presentation** (✅ FROZEN) | partial | `relative_time` 9 consumers vs **52 files** computing `.difference(`; `toLocal()` in 35; 22 files sorting | posts, messages, attention, meetings, activity | **critical** |

---

## FINDING M1 — Shadow governance in the client

**Evidence.** 29 files perform role comparisons (`role ==`, `isAdmin`, `isOwner`); 20 files compute capability booleans (`canManage`, `canPublish`, `canInvite`, `canModerate`, `canGovern`).

**PRODUCT CONSEQUENCE.** The client re-derives authority the frozen backend owns. Divergence produces either a visible action that fails on submit, or a hidden action the person was entitled to. Both erode trust, and **neither is detectable by backend tests** — the backend is correct in both cases.

**ROOT CAUSE.** Client needed to hide/show controls before a capability projection existed, so each surface inferred authority locally.

**FD-9 (FROZEN 2026-08-15) governs this finding directly.** The frontend Acting Context Authority must **not become shadow authorization**: backend determines eligible institutional relationships, roles/capabilities, permissions, whether an action is allowed, and representational authority. The frontend maintains, presents and propagates context, and consumes backend eligibility.

**CLASSIFICATION.** REFACTOR — the client must **project** capability, never compute it. The backend already resolves effective capability (role ∪ active delegated grants) in a single authority, and treats governance-exclusive acts as owner-only role checks that can never be delegated.

**MIGRATION CONSEQUENCE.** Every hidden/disabled control must be re-derived from projected capability; some currently-hidden controls may become visible (or vice versa) once the client stops guessing. That is a correction, but it is user-visible and should be expected.

**FOUNDER DECISION.** No — objective. The frozen backend owns these truths.

---

## FINDING M2 — Raw-map consumption bypasses domain models

`institution_live_rooms_screen` consumes `Map<String, dynamic>` directly (`_readList(data['sessions'])`) with no domain model, while `realtime/domain/` defines `realtime_models`, `realtime_state` and `realtime_enums`.

**CLASSIFICATION.** REFACTOR — untyped consumption is how backend contract changes become silent client breakage.

---

## Acting Context Authority — FD-9 frozen requirements

Recorded so later design cannot drift:

- The authenticated **person is the default actor**; institutional context is entered **deliberately**.
- Acting identity must be **sufficiently visible at the point of consequential action** (publishing, posting, messaging, replying, inviting, starting governed communication, moderating, administering, approving, public representation).
- **No invisible representational switching.**
- **Person identity ≠ acting context ≠ institution profile** — never collapsed to simplify UI.
- Composers **consume** acting context: no local "post as institution" selectors (`ACTING CONTEXT + SURFACE CAPABILITY + BACKEND AUTHORITY → AVAILABLE REPRESENTATIONAL ACTION`).
- Acting context determines **authorised representation within** realtime contexts; it never redefines their semantics (FD-3 compatibility).
- Enforcement to investigate later: canonical Acting Context controller · restricted direct role interpretation · consumer boundaries · navigation + composer integration · architecture tests · source-level gates.

See `FD9_ACTING_CONTEXT_FROZEN.md`.

## Attention Authority — FD-1 frozen requirements

- Attention is a **projection**, never a new owner of DM/Thread/Space/Meeting/Room/Live objects.
- It may govern: projection · semantic type · owning domain · destination · state · available actions · priority · aggregation · read/seen/resolved presentation.
- It must **not invent permissions or business state** — backend/domain authorities remain final truth.
- It must **not reimplement domain actions** (accept, decline, reply, call, moderate). It resolves through a domain action descriptor: `ATTENTION ITEM → DOMAIN ACTION AUTHORITY → CANONICAL DOMAIN ACTION → DOMAIN STATE → ATTENTION UPDATES`.
- Items must reconcile deterministically so **no dead CTAs** survive.
- One architecture projects across acting contexts — **no mirrored institutional inbox** (FD-9).

**Badge contract (FD-2, FROZEN):** the primary badge counts **unresolved actionable obligations only** — `ACTION_REQUIRED`, `INVITED`, `MISSED`, plus mentions that represent unresolved attention. Passive unread is contextual, never in the badge. Internal states stay behavioural. Truncation `99+`.

See `FD1_ATTENTION_HUB_FROZEN.md` and `FD2_ATTENTION_VOCABULARY_FROZEN.md`.

## Composition Authority — frozen requirements

- **Composition ≠ representation ≠ delivery/publication.** `ACTING CONTEXT + OWNING PRODUCT CONTEXT + COMPOSITION + BACKEND AUTHORITY → AUTHORIZED DELIVERY/PUBLICATION ACTION`.
- Shared: content state · drafts · autosave · attachments · media · mentions · links · previews · hydration · formatting · validation · upload state · retry · edit state · send/publish readiness · keyboard · paste · drag/drop · accessibility · abandonment/recovery.
- Attachment lifecycle **distinct** from communication lifecycle — upload never implies sent/published.
- **Upload timing (FD-7, FROZEN):** begins on select/paste/drop. Uncommitted attachments belong to the **draft**; explicit discard releases immediately; uncontrolled abandonment falls to backend orphan cleanup. **Attachment readiness is part of composition readiness — no silent queued-send.** No hybrid size/type timing. See `FD7_ATTACHMENT_SEND_MODEL_FROZEN.md`.
- Context policy (not duplicated mechanics) governs file types, size, count, eligibility, permissions.

See `CANONICAL_COMPOSITION_SYSTEM_FROZEN.md`.

## Capability-Adaptive Experience — frozen cross-product principle

`PERSON + ACTING CONTEXT + PRODUCT CONTEXT + BACKEND CAPABILITIES + CURRENT STATE → CURATED AVAILABLE EXPERIENCE`, **deterministically**.

Roles change available capability, never the product. Authority complexity stays hidden until exercised. Management is object-local where practical. Progressive disclosure is required. **The client determines presentation hierarchy, never permission** — this is the governing answer to Finding M1.

See `CAPABILITY_ADAPTIVE_EXPERIENCE_FROZEN.md`.

## Identity / Presence Authorities — FD-11 frozen requirements

Five governed projections, so identity presentation cannot drift per surface:

| Projection | Governs |
|---|---|
| **Identity** | canonical Person / Institution presentation |
| **Relationship** | relevant contextual relationship (incl. membership) |
| **Presence** | *permitted* human-facing presence only |
| **Verification** | layered trust information, never a boolean |
| **Action** | backend-authorised contextual actions |

Frozen constraints: **PERSON ≠ INSTITUTION ≠ MEMBERSHIP ≠ ACTING CONTEXT ≠ PRESENCE** · member is Person + relationship, not a third type · **technical connectivity ≠ social presence** (socket/device/`lastSeen`/transport state must not be exposed socially) · no boolean verification flattening or enum leakage · composers, realtime and attention all **consume** these projections rather than inventing avatar, label, verification or relationship rendering.

Drift to prevent: independent Person/Member profile models · local role-derived identity · duplicated avatar/name logic · boolean verification flattening · local presence inference · institution-as-user modelling · route-specific profile implementations.

See `CANONICAL_IDENTITY_PRESENTATION_FROZEN.md`.

## Navigation & Product Language Authorities — frozen requirements

**Navigation.** Users navigate to **objects and intentions, not backend modules**. Few stable primary destinations; objects own contextual depth; capability-adaptive actions; deep links preserve the **most specific legitimate context**; acting context never duplicates the IA; primary navigation need not contain every capability. **Exact primary destinations are NOT frozen.**

**Canonical Product Language Authority.** Governs product-facing nouns · verbs · CTA families · state terminology · navigation labels · action labels · contextual variants · relationship and participation terminology.

> **CONVERGE SYNONYMS. PRESERVE GENUINE SEMANTIC DISTINCTIONS.**
> **SAME ACTION → CONSISTENT LANGUAGE. DIFFERENT ACTION → PRESERVE MEANINGFUL DISTINCTION.**
> **Semantic truth first, vocabulary second. No copy-only fixes where drift reflects duplicated architecture.**

Enforcement to investigate (minimum mechanism that actually prevents drift, **no bureaucracy**): canonical product-language registry · shared CTA primitives · canonical route/object definitions · navigation authority/configuration · architecture tests · source-level gates · restricted raw product labels · documentation contracts.

See `NAVIGATION_IA_PRODUCT_LANGUAGE_FROZEN.md`.

## Content Intake & Temporal Authorities — frozen requirements

**Content Intake & Resolution.** `USER INPUT → CONTENT INTAKE & RESOLUTION → CANONICAL COMPOSITION → ATTACHMENT/MEDIA LIFECYCLE → OWNING DOMAIN DELIVERY/PUBLICATION`. Preserve richness, never invent it · pasted images/files resolve as attachments · links resolve to **governed** previews (consume backend link intelligence, do not fetch metadata client-side) · unsupported content fails visibly and recoverably · never silently pick one clipboard representation. See `CONTENT_INTAKE_RESOLUTION_AUTHORITY_FROZEN.md`.

**Temporal Presentation.** Owns semantic event type · canonical timestamp selection · relative vs absolute · locale/timezone · humanized formatting · exact-time access · **sorting semantics** · refresh/aging. **Owning domains remain authoritative for what the event means.** Do not interchange `createdAt`/`updatedAt`/`publishedAt`/`sentAt`/`receivedAt`/`deliveredAt`/start/end for convenience. See `HUMAN_TEMPORAL_PRESENTATION_AUTHORITY_FROZEN.md`.

## Participant / Realtime Presentation — FD-4 frozen requirements

- One shared component family for **participant list · host controls · admission/join-requests · consent**.
- **The shared component does not own semantic meaning** — context-specific states and language are **supplied by the owning domain** (Meeting attendee ≠ Room invitee ≠ Live speaker).
- Participant rendering **consumes canonical identity projection** (FD-11) — no realtime-specific identity model.
- Host/admin controls appear **progressively**, never permanently occupying other participants' UI (Capability-Adaptive Experience).
- **Meetings lifecycle untouched**; convergence proceeds **slice by slice with targeted regression after each**.

See `FD4_REALTIME_PRESENTATION_CONVERGENCE_FROZEN.md`.

## Publication governance — FD-8 frozen requirements

- Designation is expressed **only in the publish flow**, never in composition (FD-6 layering).
- **No post-publication elevation.** Withdrawal is permitted and **object-local**, preserving actor, timestamp, reason and provenance.
- **Any content change after approval invalidates the approval** — no client-side minor/substantive distinction.
- The client **consumes** acting context, publication capability, designation eligibility and approval state. It never computes institutional authority locally.
- Designation consequence must be **legible before commitment**, never delivered as a governance error at Publish.

See `FD8_OFFICIAL_DESIGNATION_MOMENT_FROZEN.md`.

## Live (FD-5, FROZEN) — authority consequences

- Live is a **state of an owning Thread/Space**, never its own product authority.
- **Enablement, visibility and speaking are backend-governed capabilities** — the client never infers them from role names.
- Live **consumes** the shared realtime presentation family (FD-4) while the owning context supplies SPEAKER/LISTENER/OBSERVER/HOST/MODERATOR semantics.
- Live **consumes** the canonical Notification Delivery + Multi-Device authorities — **no separate Live ringing path**.
- Live attention belongs to the originating Thread/Space — **no Live Inbox**.
- **Public observation must be architecturally distinct from active media participation.**

See `FD5_LIVE_THREAD_SPACE_FROZEN.md`.

## Consumer enforcement — FD-13 FROZEN 2026-08-15

**No longer "proposed."** Source-level gates + architecture tests, **hard-failing** the build/certification path, **added with each authority** — never as a retrofit chapter.

> **AUTHORITY + CONSUMER MIGRATION + ANTI-DRIFT ENFORCEMENT + REGRESSION/CERTIFICATION = COMPLETE RECONSTRUCTION.**

- **Exceptions:** explicit, narrow, justified, reviewable, and visible in the enforcement artifact. No wildcards, no `legacy/` exclusions, no silent bypasses.
- **Enforce the invariant, not the filename** — gates evolve with the authority.
- **No governance platform up front.** Minimum effective mechanism only.
- **Gate quality:** a gate with known false positives or routine suppression is not acceptable; record the obligation and bring the limitation forward instead of downgrading to a warning.
- **Definition of done per authority:** frozen invariant, canonical owner, migrated consumers, prohibited competing pattern, enforcement mechanism, legitimate exceptions, regression/certification evidence.

See `FD13_ENFORCEMENT_MECHANISMS_FROZEN.md`.

## Consumer enforcement (original proposal, retained for history)

Future correctness must not depend on developer memory. Candidate mechanisms, mirroring what already works on the backend:

1. **Source-level gates** — no `FilePicker`/`ImagePicker` outside the attachment authority; no `CircularProgressIndicator` outside the state system; no role comparison outside the capability projection.
2. **Restricted imports** — a feature may not import another feature's `presentation/`.
3. **Canonical navigation actions** — no literal route strings outside the navigation authority.
4. **Consumer registry** — each authority declares its permitted consumers; adding one is a deliberate, reviewable edit.
5. **Widget tests per authority** rather than per screen.

The backend uses exactly this pattern (14 structural gates plus migration-safety gates), and it is the reason backend drift stopped recurring rather than being re-fixed each chapter. **The frontend has no equivalent, which is the root reason this discovery found so much drift.**
