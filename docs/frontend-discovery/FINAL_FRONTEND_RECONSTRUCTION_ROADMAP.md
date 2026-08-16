# FINAL — Aura Release Client Reconstruction Roadmap

**Constructed 2026-08-15 from the complete frozen decision set** (FD-1…FD-13 plus five named cross-product freezes). This **supersedes** the F0–F10 draft, which was written before any decision was frozen — see `FRONTEND_ROADMAP_OLD_TO_NEW_RECONCILIATION.md`.

> # FINAL / FOUNDER APPROVED / FROZEN — 2026-08-15
>
> Approved subject to two corrections, both applied: the **Live product-dependency correction** (C3/C4/C5 cannot be bypassed) and the **C9/C10 overlap rule** (construction entry vs cross-platform completion). **SupportScreen remains an explicitly tracked disposition with no invented ownership.**
>
> **IMPLEMENTATION HAS NOT STARTED.** Roadmap approval is not authorisation to begin a chapter.

---

## Thesis

The frontend's fault was never too many capabilities — it was **too many implementations of too few defined concepts**, with nothing preventing the next divergence.

Therefore the roadmap is organised as:

> **PRODUCT AUTHORITY → DEPENDENCY → RECONSTRUCTION → CONSUMER MIGRATION → ANTI-DRIFT ENFORCEMENT → REGRESSION → CERTIFICATION → FOUNDER REVIEW**

with one governing rule: **AUTHORITIES BEFORE SURFACES.**

**Twelve chapters.** Not forty micro-phases; not one "frontend rebuild".

Per **FD-13**, a chapter is complete only when: *authority + consumer migration + hard anti-drift gate + narrow reviewable exceptions + regression + certification*. **Code compiling is not completion.** There is **no standalone enforcement chapter** — every chapter carries its own gates.

---


> ## Aura Public-First Causal Doctrine — inherited by every chapter below
>
> **Canonical source, never restated here:** `representation/inventory/AURA_PUBLIC_FIRST_CAUSAL_DOCTRINE.md` (founder-frozen 2026-08-15).
> Agent-facing pre-flight and drift rules: `aura/AGENTS.md`.
>
> **Aura is public-first, not institution-first.** People and their communication needs are
> the originating force; institutional identity is accountability infrastructure inside a
> public environment whose value already exists — not the acquisition premise.
>
> **Roadmap ordering is unchanged by this doctrine.** It is an interpretive lens, not a
> resequencing instruction. Classify each surface as **general/public**, **person/social**
> or **institution-specific** and apply it accordingly. Institution-specific surfaces remain
> legitimately institution-focused; do not weaken them to prove alignment, and do not force
> public-first language onto institutional administration screens.


# CHAPTER C0 — CROSS-CUTTING FOUNDATIONS

> **STATUS: ✅ COMPLETE / FOUNDER APPROVED / LOCALLY CERTIFIED — closed 2026-08-15.**
> Registers: `C0_MIGRATION_REGISTER.md` · `C0_G5_OWNERSHIP_MATRIX.md` · `C0_PRODUCT_LANGUAGE_VOCABULARY.md` · `REPRESENTATION_CANONICAL_FRONTEND_ALIGNMENT.md` · `REPRESENTATION_FRONTEND_REDESIGN_INPUTS.md`.
> **C1: READY / NOT STARTED / NOT YET AUTHORIZED.**

**PURPOSE.** Build the three surface-agnostic authorities every later chapter consumes: **Product Language**, **Product State Presentation**, **Human Temporal Presentation**.

**WHY NOW / DEPENDENCIES.** None. All three are independent of product semantics, so building them first prevents rebuilding every surface later. They are also the cheapest place to establish the FD-13 enforcement pattern.

**FROZEN DECISIONS CONSUMED.** FD-10 (canonical semantic vocabulary) · Canonical Product Language Authority · Human Temporal Presentation Authority · FD-13.

**HISTORICAL ITEMS.** Item 6 (Communication Timeline Authority — temporal half).

**PRESERVE.** `AuraLoadingState` / `AuraErrorState` / `AuraEmptyState` (sound design, incomplete adoption) · `relative_time.dart` · `local_timezone.dart` as seeds.

**DEMOLISH / RETIRE.** Nothing. This chapter is additive + migratory.

**BUILD / RECONSTRUCT.**
- **Product Language Authority (minimum):** canonical nouns, semantic CTA families (`RETRY`; `CANCEL`/`DISMISS`/`CLOSE`/`DISCARD` as four distinct families), state terminology. **Not a database of every sentence.**
- **Product State Presentation:** loading · empty · error · retry · offline · reconnecting · expired · unavailable · revoked · deleted · sending · uploading · failed · unauthorized · success. Vocabulary derived from states the frozen backend actually produces.
- **Temporal Presentation:** semantic event type · canonical timestamp selection · relative vs absolute · locale/timezone (incl. DST, cross-timezone) · humanized formatting · exact-time access · **sorting semantics** · aging/refresh.

**BACKEND DEPENDENCIES.** None new. Consumes existing timeline/delivery/integrity state vocabulary.

**REPRESENTATION ALIGNMENT.** First checkpoint: canonical nouns and CTA families must not conflict with Representation. **Bring conflicts forward; do not choose silently.**

**GLOBAL RESEARCH REQUIRED.** Humanized time and relative-time aging patterns; state/empty-state patterns.

**MIGRATION.** 83 files → shared loading · 68 `SizedBox.shrink()` empty states → real empty states · 52 hand-rolled `.difference()` → temporal authority · 35 direct `toLocal()` · 22 independent sorts → declared event semantics.

**ENFORCEMENT.** Hard gates: no raw spinner/blank-as-empty outside declared exceptions; no local time humanization or timezone conversion; sorting declares its event. **Enforce the invariant, not the filename.**

**TESTING.** Targeted state/temporal suites; cross-system regression on feeds, messages, meetings, attention ordering.

**CERTIFICATION.** Architecture + Implementation locally. Product-Behavior partially.

**FOUNDER CHECKPOINT.** ⚑ Product-language canonical nouns/CTA families before freeze.

**PARALLEL-SAFE.** All three authorities in parallel.

**EXIT CONDITION.** Three authorities exist, consumers migrated, gates hard-failing, regression green.

**NEXT UNLOCKED.** C1.

---

# CHAPTER C1 — ACTING CONTEXT & CAPABILITY PROJECTION

> **STATUS: COMPLETE / FOUNDER APPROVED / LOCALLY CERTIFIED — closed 2026-08-15.** Registers: `C1_AUTHORITY_ARCHITECTURE.md` · `C1_G5_DISPOSITION_MATRIX.md`. Opened two product disposition checkpoints before C11: **PD-1 Platform Administration**, **PD-2 Authentication & Account Entry**. **C2 NOT STARTED / NOT AUTHORIZED.**

**PURPOSE.** Make "who is acting" and "what may they do" explicit client authorities.

**WHY NOW.** FD-9 forbids reconstructing mirrored routes before acting context exists; FD-11 requires person identity ≠ acting context. **This chapter gates all institutional work.**

**FROZEN DECISIONS CONSUMED.** FD-9 · Capability-Adaptive Experience · FD-13 · FD-11 (boundary only).

**HISTORICAL ITEMS.** Item 4 (Identity Foundation — acting/capability half).
**EXTENDED SCOPE.** Fail-closed auth projection · institution capability model.

**PRESERVE.** Existing auth flows, session handling, backend contracts.

**DEMOLISH / RETIRE.** **Shadow governance:** role comparisons in **29 files**, `canX` derivations in **20 files**.

**BUILD.** Acting Context Authority (person = default actor; institutional context entered deliberately and remains attributable) · Capability Projection (consumes backend effective capability; **never computes it**).

**BACKEND DEPENDENCIES.** Frozen: institution capability authority, fail-closed auth, delegated grants.

**REPRESENTATION ALIGNMENT.** Acting-identity language ("acting as…") — checkpoint.

**GLOBAL RESEARCH.** Contextual acting-identity patterns; avoiding enterprise account-switching mazes.

**MIGRATION.** Every hidden/disabled control re-derived from projected capability. **Expect some controls to appear or disappear — that is a correction, and it is user-visible.**

**ENFORCEMENT.** Hard gate: no role comparison or capability derivation outside the projection. Gate must distinguish **presentation state** from **invented authority**.

**TESTING.** Capability projection suites; institution-surface regression.

**CERTIFICATION.** Architecture + Implementation + Cross-System (client/backend authority agreement).

**FOUNDER CHECKPOINT.** ⚑ How acting identity is made visible at consequential actions.

**PARALLEL-SAFE.** Acting Context and Capability Projection may proceed together.

**EXIT.** No client file derives institutional authority locally.

**NEXT UNLOCKED.** C2 ∥ C3.

---

# CHAPTER C2 — IDENTITY, PRESENCE & PROFILE

> **Public-first inheritance.** Person is the **originating human identity**. Institutional identity remains a separate accountability identity, never a prerequisite for human identity or public participation. Person / Institution / Membership / Acting Context / Availability / Authority stay distinct.


**PURPOSE.** One canonical identity presentation with contextual projection — and the rebuilt profile surfaces that consume it.

**WHY NOW.** Depends on C1. Feeds attention, composition, realtime participants and people selection.

**FROZEN DECISIONS CONSUMED.** FD-11 · FD-10 (Presence/verification rulings) · Capability-Adaptive Experience · FD-3 §6 (People & Participation) · FD-13.

**HISTORICAL ITEMS.** Item 4 (Identity Foundation).
**EXTENDED SCOPE.** Canonical person identity projection · layered verification · account lifecycle states.

**PRESERVE.** Canonical identity data · relationships · public content · institution relationships · verification data · privacy controls · follow state · backend contracts · conceptually-correct deep links.

**DEMOLISH / REBUILD.** **DR5** — three profile implementations (`profile/`, `me/`, `institutions/profile/`; ~4,100 lines of parallel edit screens). **Retire** the six-meaning overload of "presence". **Disposition** `PresenceScreen` here (FD-12 §5 — never on reference count).

**BUILD.** Identity Projection (Person/Institution) · Relationship Projection · Presence Projection (permitted human-facing only) · Verification Projection (**layered, never boolean**) · Action Projection (backend-authorised) · **People & Participation Selection primitive** (backend-resolved eligibility; no local inference) · rebuilt profile surfaces (**IDENTITY FIRST · CONTEXT SECOND · ACTIONS THIRD · METADATA ON DEMAND**).

**BACKEND DEPENDENCIES.** Frozen: `PERSON_IDENTITY_SELECT` / `PERSON_REFERENCE_SELECT`, layered verification (IDENTITY / INSTITUTION_AFFILIATION / ROLE_OR_CREDENTIAL), account retention lifecycle.

**REPRESENTATION ALIGNMENT.** Identity, presence and **verification** language — highest-severity register rows.

**GLOBAL RESEARCH.** Person/organisation profiles · compact identity cards · people pickers · presence · verification presentation · progressive disclosure.

**MIGRATION.** Profile data and privacy controls preserved; relationship state preserved; profile deep links mapped.

**ENFORCEMENT.** Gates against: independent Person/Member models · institution-as-user · **boolean verification flattening** · local presence inference · local role-derived identity · route-specific profile implementations.

**TESTING.** Identity/verification/presence suites; profile and feed regression.

**CERTIFICATION.** Architecture + Implementation; Product-Behavior at founder checkpoint.

**FOUNDER CHECKPOINTS.** ⚑ **Verification label mapping** (class → human meaning → user value → label → context). ⚑ **Presence privacy/visibility policy.** ⚑ Profile visual direction.

**PARALLEL-SAFE.** Runs alongside C3, with route ownership held by C3.

**EXIT.** One identity presentation; three verification layers independently expressible; no local presence inference.

**NEXT UNLOCKED.** C4 · C5 · C6.

---

# CHAPTER C3 — NAVIGATION & INFORMATION ARCHITECTURE

> **Public-first inheritance.** Do **not** organise general Aura as institution-first. Institution discovery is a legitimate capability, not the master product model or the primary public journey.


**PURPOSE.** One coherent IA where people navigate to **objects and intentions, not backend modules**.

**WHY NOW.** Depends on C1 (acting context) and C0 (language). Blocks attention deep-routing and composition entry points.

**FROZEN DECISIONS CONSUMED.** Task/Domain-Oriented Adaptive Navigation + Canonical Product Language Authority · FD-9 · FD-12 · Capability-Adaptive Experience · FD-13.

**HISTORICAL ITEMS.** Item 11 (Legacy global runtime overlay cleanup).

**PRESERVE.** Four shells where product-correct · **session continuity** (`floating_call_widget`, `incoming_live_overlay`, `thread_call_lifecycle_host`) · **all existing deep links must continue to resolve** · redirects as a temporary compatibility layer.

**DEMOLISH / REBUILD.** **DR4** — **40 mirrored `/institution/:institutionId/…` routes** (per-route test: genuinely different institution-owned semantic → preserve; same capability under different acting context → converge) · module-oriented destinations · redundant destinations · **27 corrective redirects** · literal route strings scattered across features.

**BUILD.** Navigation/Surface Authority · canonical navigation actions · declared **surface/route registry** (FD-12 §8 — architecture-aware; **naïve zero-reference gate forbidden**) · object-local contextual depth · responsive IA (conceptual before visual) · room for universal Find/Go-To (**supplements** IA, never patches it).

**BACKEND DEPENDENCIES.** Institution capability (frozen). No new backend.

**REPRESENTATION ALIGNMENT.** Destination and section names.

**GLOBAL RESEARCH.** Primary/contextual/object-local/adaptive navigation · command-find · deep-link continuity · mobile vs desktop IA.

**MIGRATION.** **Old route inventory → canonical destination → redirect policy → external/deep-link compatibility → notification destinations updated → corrective redirect chains eliminated over time.**

**ENFORCEMENT.** No literal route strings outside the navigation authority; surface reachability/ownership enforced via the registry.

**TESTING.** Deep-link suites; navigation regression; notification routing regression.

**CERTIFICATION.** Architecture + Implementation + Product-Behavior.

**FOUNDER CHECKPOINT.** ⚑ **Exact primary destinations — deliberately NOT frozen; derived and reviewed here.**

**PARALLEL-SAFE.** Runs alongside C2.

**EXIT.** One destination tree; acting context carried by identity, not path; every surface has an auditable reachability/ownership path.

**NEXT UNLOCKED.** C4 · C5 · C6.

---

# CHAPTER C4 — ATTENTION

> **Public-first inheritance.** Attention serves **human obligations and communication**, not institutional broadcast volume.


**PURPOSE.** One governed Attention Hub answering *"what needs my attention?"* as a **projection**, never a new owner.

**WHY NOW.** Needs identity (C2) for people/institutions, navigation (C3) for exact-context routing, temporal (C0) for ordering, capability (C1) for actions.

**FROZEN DECISIONS CONSUMED.** FD-1 · FD-2 · FD-12 · Human Temporal Presentation · Capability-Adaptive Experience · FD-13.

**HISTORICAL ITEMS.** Item 3 (Notification Delivery Authority — client half) · Item 6 (Timeline).

**PRESERVE.** Read/unread data where valid · invitation state · notification delivery capability · notification preferences · `updates/module_attention` + `notifications_controller` as the authority seed.

**DEMOLISH / REBUILD.** **DR1** — eight attention surfaces: messages hub · notifications · activity · direct inbox · communications centre · correspondence hub · module attention · **`conversations_screen.dart` (1,033 lines, unreachable) RETIRED here** (FD-12).

**BUILD.** Attention Authority (projection · semantic type · owning domain · destination · state · available actions · priority · aggregation) · semantic views (Conversations · Activity · Invitations · Actions) · **domain-owned resolvable actions** (`ATTENTION → CONTEXT → ACTION → RESOLUTION → CONTINUITY`) · **obligation badge** (`ACTION_REQUIRED` + `INVITED` + `MISSED` + qualifying mentions; **passive unread never contributes**; truncation `99+`) · owning-domain clearing semantics · deterministic reconciliation (**no dead CTAs**) · cross-device read state · noise reduction.

**BACKEND DEPENDENCIES.** Frozen: notification delivery authority, delivery attempts, acknowledgement, attention records, timeline.

**REPRESENTATION ALIGNMENT.** Attention/obligation language.

**GLOBAL RESEARCH.** Actionable inbox/notification models · badge semantics · grouping · noise reduction.

**MIGRATION.** Read/attention state preserved — **no wall of false unreads**. Notification destinations re-pointed to canonical routes.

**ENFORCEMENT.** Gates against: parallel attention hubs · unread-as-universal-attention · independent badge semantics · dead CTA projections · competing reconciliation · **mirrored institutional inbox** · generic "Calls" domain.

**TESTING.** Attention state/badge/reconciliation suites; cross-device state; notification regression.

**CERTIFICATION.** Architecture + Implementation + Product-Behavior; Real-Boundary partially (native delivery lands in C9).

**FOUNDER CHECKPOINT.** ⚑ Attention interaction direction before the eight surfaces are retired.

**PARALLEL-SAFE.** Alongside C5 and C6.

**EXIT.** One Hub; one badge semantic; eight surfaces retired; no dead CTAs.

**NEXT UNLOCKED.** C9.

---

# CHAPTER C5 — COMPOSITION, CONTENT INTAKE & ATTACHMENTS

> **Public-first inheritance.** Personal/public communication and institutional communication are **distinct but equally first-class**. Neither is the default that the other decorates.


**PURPOSE.** One canonical composition system, one attachment lifecycle, one governed content-intake layer.

**WHY NOW.** Needs acting context (representation), identity (mentions/recipients), navigation (contextual entry), product state and temporal.

**FROZEN DECISIONS CONSUMED.** FD-6 · FD-7 · FD-8 · Content Intake & Resolution Authority · FD-10 · Capability-Adaptive Experience · FD-13.

**HISTORICAL ITEMS.** **Item 5** (Compose Link Intelligence/OG) · **Item 10** (Selection/Clipboard/Rich Paste) · **Item 13** (External Link/OG) · **Item 14** (Internal Link Hydration) · **Item 15** (Rich-Text Composition) · **Item 16** (Content-Length Expansion).
**EXTENDED SCOPE.** E_OFFICIAL designation representation · institutional approval workflow language.

**PRESERVE.** Backend contracts · supported content behaviour · attachment/media capabilities · **drafts and draft data** · proven validation · accessibility behaviour · legitimate context differences · working media rendering.

**DEMOLISH / REBUILD.** **DR3** — six composers (capability distributed at random: hashtags in 1 of 6; upload progress in 1 of 6) · **eleven upload pipelines** · per-composer paste/clipboard handling (25 files) · voice implied by route.

**BUILD.**
- **Composition Authority:** content state · drafts · autosave · mentions · links · formatting · validation · readiness · keyboard · accessibility. **COMPOSITION ≠ REPRESENTATION ≠ DELIVERY/PUBLICATION.**
- **Attachment Lifecycle:** `SELECT/PASTE/DROP → VALIDATE → PREVIEW → UPLOAD → PROGRESS → READY → SEND/PUBLISH`; **upload on selection**; uncommitted attachments belong to the **draft**; **explicit discard → immediate release**; abandonment → backend cleanup; **attachment readiness is part of composition readiness**; **no silent queued-send**; no hybrid size/type timing.
- **Content Intake & Resolution:** rich paste (**preserve richness, do not invent richness**) · image/file paste · **drag-and-drop (currently 0 implementations)** · mixed content · governed link previews (consume backend link intelligence; do not fetch client-side) · **unsupported input fails visibly and recoverably, never silently**.
- **Official designation in the publish flow only** (FD-8): no post-publication elevation; consequence legible **before** commitment (`DESIGNATE AS OFFICIAL → SUBMIT FOR APPROVAL`); withdrawal object-local; **content change invalidates approval**.

**BACKEND DEPENDENCIES.** Frozen: canonical MIME policy · SSRF-safe link fetching · internal link hydration · CIS classes · E_OFFICIAL designation + institutional approval floor · media cleanup service.

**REPRESENTATION ALIGNMENT.** Post/Works · Send/Publish · designation and approval language.

**GLOBAL RESEARCH.** Modern composers · attachment handling · paste/drop · clipboard · link unfurling · preview editing · mixed content · mobile share/input · error recovery.

**MIGRATION.** **Drafts must survive.** Existing content and attachment rendering unchanged. Draft-attachment association made explicit.

**⚑ OPEN CHECKPOINT.** **Orphan-cleanup windows vs canonical draft lifetime** — review here. **Backend policy is not changed unilaterally; conflicts are brought forward.**

**ENFORCEMENT.** Gates against: independent composer architectures · independent upload mechanics · local attachment lifecycle interpretation · **send/upload lifecycle collapse** · per-surface intake reimplementation · per-composer institutional-voice selectors. **Must not erase legitimate domain differences.**

**TESTING.** Composition/attachment/intake suites; publication regression; CIS integration regression.

**CERTIFICATION.** Architecture + Implementation + Product-Behavior + Cross-System.

**FOUNDER CHECKPOINT.** ⚑ Composition interaction direction. ⚑ Designation/approval workflow language.

**PARALLEL-SAFE.** Alongside C4 and C6.

**EXIT.** One composition system, one attachment lifecycle, one intake layer; six composers and eleven pipelines retired; drag/drop exists.

**NEXT UNLOCKED.** C7 · C9.

---

# CHAPTER C6 — REALTIME PRESENTATION CONVERGENCE

> **Public-first inheritance.** Human communication and collaboration are first-class; realtime audio/video is part of meaningful collaboration, not an isolated calling feature.


**PURPOSE.** Converge realtime **presentation** beneath distinct product semantics — and finally expose frozen multi-device capability.

**WHY NOW.** Needs identity (participants), capability (host controls), product state. Blocks Institution Room, Threads/Spaces realtime and Live.

**FROZEN DECISIONS CONSUMED.** FD-3 · FD-4 · FD-11 · Capability-Adaptive Experience · FD-13.

**HISTORICAL ITEMS.** **Item 1** (Runtime Lifecycle) · **Item 2** (Device Presence) · **Item 7** (Realtime Architecture Correction) · **Item 9** (Lifecycle Phase 2) · **Item 12** (Advanced Device Preference / Transfer).
**EXTENDED SCOPE.** Multi-device authority · preferred-first ring + stagger + fallback · durable media ownership · **D2 transfer handshake**.

**PRESERVE — do not touch.** Realtime transport · media service · event parser · **reconnect/orphan recovery** (`realtime_reconciliation_controller`, orphaned-session handling) · **session continuity across navigation** · **Meetings lifecycle** (booking, invitation, attendance, waiting/admission, prep, summary, follow-up).

**DEMOLISH / CONVERGE.** Duplicated presentation: Meetings reimplements participant grid, spotlight and remote tiles across 3,890 lines while using **0 of 5** shared realtime widgets.

**BUILD.** Shared presentation family — participant list · host controls · admission/join-requests · consent — **rendering context-supplied states and language; the component never owns semantic meaning** · modern invite/add flows consuming the People & Participation primitive · **device transfer UI** (offer/accept/relinquish/failed) · **preferred-device behaviour made visible**.

**BACKEND DEPENDENCIES.** Frozen: D1 routing, D2 transfer handshake, D6 durable media ownership, WNS/APNs/FCM delivery.

**REPRESENTATION ALIGNMENT.** Participant/speaker/host language; transfer language (**never routing internals**).

**GLOBAL RESEARCH.** Modern call/room/meeting/huddle patterns · participant management · device handoff.

**MIGRATION.** **Slice by slice — NO wholesale Meetings rewrite.** **Targeted Meetings regression after each slice** (currently 97/97).

**ENFORCEMENT.** Gates against another surface reimplementing canonical primitives. **Must not force Meeting/Room/Thread/Space/Live semantic convergence** (FD-3).

**TESTING.** Realtime suites; **Meetings regression after every slice**; transfer/multi-device suites.

**CERTIFICATION.** Architecture + Implementation + Product-Behavior; Real-Boundary partially (device testing in C9).

**FOUNDER CHECKPOINT.** ⚑ Participation/invite interaction direction. ⚑ Sign-off after each Meetings slice.

**PARALLEL-SAFE.** Alongside C4 and C5.

**EXIT.** One presentation family; Meetings lifecycle intact and green; transfer and preferred-device visible.

**NEXT UNLOCKED.** C7 · C8 · (with C7+C8) C10.

---

# CHAPTER C7 — THREADS, SPACES & CORRESPONDENCE

> **Public-first inheritance.** Threads and Spaces are **purposeful communication contexts** — social, working and creative — not institution-only collaboration containers.


> **ADDED OBLIGATION (founder decision 2026-08-15).** "Correspondence" now has exactly **one** canonical product meaning — the governed formal/deliberate communication form. The legacy umbrella sense (Spaces + Threads + Messages + Direct Threads) is **architectural naming drift**. C7 determines the correct umbrella/internal name and migrates safely, preserving compatibility and history. Filesystem/package naming may retain the legacy sense until this chapter runs; documentation and the Product Language Authority may not.

**PURPOSE.** Reconstruct the conversation surfaces on frozen semantics — and resolve the Correspondence architecture question.

**WHY NOW.** Needs composition (C5), attention (C4), realtime (C6), identity (C2), navigation (C3).

**FROZEN DECISIONS CONSUMED.** Threads/Spaces Product Model · FD-10 (Correspondence ruling) · FD-3 · FD-6 · FD-1 · FD-9 · Capability-Adaptive Experience · FD-13.

**PRESERVE.** Communication histories · membership/relationship data · Thread/Space content · deep links · Meetings boundary.

**DEMOLISH / CONVERGE.** **Three `thread_screen` implementations** (`correspondence/`, `public/`, `direct_threads/`) · duplicated conversation mechanics · **four institution messaging entry points** · **disposition `InstitutionCorrespondenceScreen` here** (FD-12 §4).

**BUILD.** Thread surfaces (focused conversation continuity) · Space surfaces (persistent shared context; **no eight-tab interface**) · membership/join/invite flows (**never expose role enums or permission machinery**) · object-local management · **Correspondence as a distinct governed communication form** — deliberate/formal communication with institutional/documentary continuity, **sharing infrastructure but not semantics**.

> **The surviving word does not protect the architecture.** If the current Correspondence implementation is merely duplicate messaging, **converge/rebuild the mechanics while preserving the semantics.**

**BACKEND DEPENDENCIES.** Frozen: correspondence orchestrator, thread/space models, institution capability.

**REPRESENTATION ALIGNMENT.** **Correspondence vs Conversation vs Message** — deliberate two-layer naming must be **documented, not accidental**.

**GLOBAL RESEARCH.** Community/space IA · membership flows · conversation continuity.

**MIGRATION.** Conversation histories, membership, drafts and deep links preserved across surface convergence.

**ENFORCEMENT.** Gates against duplicated Thread semantics inside Space implementations and per-surface composer/attention reimplementation.

**TESTING.** Thread/Space/Correspondence suites; history and membership regression.

**CERTIFICATION.** Architecture + Implementation + Product-Behavior.

**FOUNDER CHECKPOINT.** ⚑ Correspondence presentation and its architectural convergence verdict.

**PARALLEL-SAFE.** Alongside C8.

**EXIT.** One thread surface family; Space surfaces coherent; Correspondence distinct in semantics and non-duplicated in mechanics.

**NEXT UNLOCKED.** C10.

---

# CHAPTER C8 — INSTITUTION ROOM

> **Public-first inheritance.** **Legitimately institution-owned.** Public-first does not erase institutional ownership; do not dilute this surface to prove alignment.


**PURPOSE.** Build the client for the frozen D5 Institution Room authority.

**WHY NOW.** Needs converged realtime (C6), identity/people selection (C2), attention (C4).

**FROZEN DECISIONS CONSUMED.** FD-3 · FD-4 · FD-9 · FD-1 · Capability-Adaptive Experience · FD-13.
**EXTENDED SCOPE.** Institution Room (backend D5).

**PRESERVE.** "See what is live now" for an institution; card layout only.

**DEMOLISH + REBUILD.** **DR2** — `institution_live_rooms_screen` (1,078 lines): imports neither realtime nor meetings, consumes untyped `Map<String,dynamic>`, and lists **realtime sessions rather than `InstitutionRoom`**. **Do not retrofit.**

**BUILD.** Room ownership · invitations · participant states · **ring policy** (`JOIN_ONLY` / `RING_INVITED` / `RING_INVITED_AND_PARTICIPANTS`) · lifecycle · contextual realtime · attention · modern participant selection.

> **Entitlement ≠ interruption.** Membership never becomes a ring list.

**BACKEND DEPENDENCIES.** Frozen D5: `InstitutionRoom`, participants, invitation lifecycle, governed ring resolution, canonical delivery.

**REPRESENTATION ALIGNMENT.** Room vs Meeting vs Live language; **Member vs Participant**.

**GLOBAL RESEARCH.** Drop-in room patterns; invitation vs ringing.

**MIGRATION.** No user-visible behaviour worth preserving beyond "what is live now"; **no data migration** — the old screen has no canonical model.

**ENFORCEMENT.** Gates against raw-map consumption, ring-from-membership, and local room push.

**TESTING.** Room lifecycle/ring-policy suites; **large-institution invariant** (10,000 members → zero recipients absent invitation).

**CERTIFICATION.** Architecture + Implementation + Product-Behavior + Cross-System.

**FOUNDER CHECKPOINT.** ⚑ Room experience direction.

**PARALLEL-SAFE.** Alongside C7.

**EXIT.** Institution Room reachable, governed, and consuming canonical contracts.

**NEXT UNLOCKED.** C10.

---

# CHAPTER C9 — CROSS-PLATFORM COMPLETION (MSIX / MOBILE / WEB)

**PURPOSE.** Make the Release Client genuinely first-class on each supported platform.

**WHY NOW.** Needs attention (native notification presentation) and content intake (drag/drop).

**FROZEN DECISIONS CONSUMED.** Capability-Adaptive Experience · Content Intake · FD-1/FD-2 · FD-13.

**HISTORICAL ITEMS.** **Item 7** (device/native pass) · **Item 8** (iOS Firebase/APNs).
**EXTENDED SCOPE.** **Windows/MSIX native push (WNS)** · desktop obligations.

**PRESERVE.** Existing device registration; notification preferences; session continuity.

**BUILD.** Native Windows notifications (WNS) · desktop lifecycle · **drag/drop** · clipboard · file handling · keyboard · hover/context affordances · window sizing/responsiveness · background/foreground · **active realtime continuity** · deep links · installation/launch context · iOS/Android native notification presentation.

> **Desktop is not web with a wider viewport.**

**BACKEND DEPENDENCIES.** Frozen: WNS adapter, APNs, FCM, Web Push, delivery authority, device registry.

**REPRESENTATION ALIGNMENT.** Platform-specific product language where it differs.

**GLOBAL RESEARCH.** Desktop drag/drop · keyboard · windowing · notification/background expectations.

**MIGRATION.** Device registrations preserved; notification destinations aligned to canonical routes.

**ENFORCEMENT.** Gates against per-platform forks of shared product semantics.

**TESTING.** Per-platform suites; **real-device testing**; notification delivery verification.

**CERTIFICATION.** Implementation + Product-Behavior + **Real-Boundary** (first chapter where real-boundary substantially lands).

**FOUNDER CHECKPOINT.** ⚑ Desktop experience direction.

**PARALLEL-SAFE.** Platform branches parallel after shared semantics are frozen. **C9 may also overlap C10 construction** — but **C10 cross-platform completion/certification requires the relevant C9 contracts proven**.

**EXIT.** All three platforms behave coherently with warranted platform-specific behaviour.

**NEXT UNLOCKED.** C11 (with the rest).

---

# CHAPTER C10 — LIVE (CROSS-REPOSITORY)

> **Public-first inheritance.** A public communication context first; institutional official participation follows its own governed authority. Do not treat Live as a separate generic broadcast product, and do not market future capability as current.


> ## ⚠ THIS IS A CROSS-REPOSITORY CONSTRUCTION CHAPTER — **NOT A FRONTEND PHASE**.
> Backend construction must not be hidden inside it.

**PURPOSE.** Build Live as a governed **mode/state** of an owning Thread or Space.

**WHY NOW.** FD-5 §29 staging is frozen: **realtime convergence first** (C6), owning contexts reconstructed (C7, C8).

> ### GOVERNING INVARIANT (FROZEN 2026-08-15)
> **LIVE MUST NOT CREATE TEMPORARY VERSIONS OF AUTHORITIES ALREADY SCHEDULED FOR RECONSTRUCTION.**

**C3, C4 and C5 are PRODUCT dependencies of Live — not optional, and not merely "later chapters".**

| Consumed authority | Why Live cannot bypass it |
|---|---|
| **C3 Navigation/IA** | Live is a governed state of its owning Thread/Space — it consumes canonical navigation, contextual ownership, deep links, surface ownership and acting-context navigation. **No temporary Live navigation.** |
| **C4 Attention** | FD-5 freezes Live attention: audience eligibility does not ring · invited speakers may be interrupted · actionable invitations resolve · attention belongs to the originating Thread/Space · **no generic Calls/Live inbox**. **No temporary Live notification path.** |
| **C5 Composition/Intake** | Governed questions, continuing discussion, replay/content relationships and surrounding communication **must not be built on composers already authorised for demolition**. |

**C10 CONSTRUCTION ENTRY:** all Live-consumed authorities stable — **C0, C1, C2, C3, C4, C5, C6, C7, C8**.
**C10 CROSS-PLATFORM COMPLETION / CERTIFICATION:** additionally requires the relevant **C9** platform contracts proven. **C9 may overlap C10 construction where its own dependencies permit.**

**FROZEN DECISIONS CONSUMED.** FD-5 (all eight rulings) · Threads/Spaces · FD-3 · FD-4 · FD-1 · FD-11 · Capability-Adaptive Experience · FD-13.

**BACKEND CONSTRUCTION REQUIRED.**

| Concern | State |
|---|---|
| Role/stage vocabulary (`PUBLIC_STAGE`, HOST/CO_HOST/MODERATOR/SPEAKER/PARTICIPANT/LISTENER/OBSERVER, hand-raise, per-track publish) | **already modelled** |
| `PUBLIC_STAGE` consumption | **declared but unconsumed** |
| Go-live authority | **missing** |
| Public observation (distinct from active media participation) | **missing** |
| **Audience scale (SFU/broadcast topology)** | **missing** |
| Live attention/interaction | **missing** |
| Replay-as-product | **missing** |

> **Correction preserved:** the earlier claim that the backend had no speaker/audience model is **withdrawn**. **The vocabulary exists; the mechanism does not.**

**CLIENT CONSTRUCTION.** Go Live flow (`GO LIVE → CONFIRM VISIBILITY/PARTICIPATION → CONFIRM RECORDING → CONFIRM HOST/SPEAKER SETUP → START`) · visibility · speaker/audience state · hand raise · host/moderator controls (**progressive, never in a listener's UI**) · questions · reactions · recording state · replay · attention · post-live continuity.

**FROZEN POLICIES CARRIED.** Capability-based enablement · governed visibility (**`GO LIVE ≠ PUBLIC`**) · invited + request-to-speak (**no open mic**) · reactions + governed questions (**continuing discussion stays with Thread/Space**) · **explicit/opt-in recording**, separately authorised replay **owned by the Thread/Space** · instant **and** scheduled · host/co-host end with **advisory** scheduled end · **ordinary audience attention does not ring**; invited speakers may be interrupted **via canonical delivery authorities** · **durable membership never mutated by temporary Live role**.

**BOUNDARIES.** Not a Meeting · not an Institution Room (**Option C rejected**) · not a standalone product (**Option B rejected**) · **no fourth live surface**.

**REPRESENTATION ALIGNMENT.** Live/public participation language.

**GLOBAL RESEARCH.** Stage/audience · request-to-speak · moderated Q&A · reactions · scheduling · recording/replay · public viewing · host tools.

**⚑ OPEN CHECKPOINTS.** **Live moderation policy** · **audience-scale topology/provider** (provider independence preserved; not frozen) · **Thread vs Space Live differences** if material.

**ENFORCEMENT.** Gates against: standalone orphan Live product · local role inference · ungoverned public visibility · **ring-all audience** · membership mutation from speaker state · duplicate Live comment system · Meeting lifecycle reuse · Institution Room reuse · local notification delivery · **peer-to-peer audience scaling**.

**TESTING.** Live lifecycle · speaker/audience transitions · moderation · **audience-scale load** · recording/replay · attention.

**CERTIFICATION.** Architecture + Implementation + Product-Behavior + Cross-System + **Real-Boundary (media scale)** + Founder Acceptance.

**FOUNDER CHECKPOINT.** ⚑ Live architecture details where policy remains; ⚑ acceptance before release inclusion.

**EXIT — two distinct gates.**
- **Construction exit:** Live works end-to-end from a governed Thread/Space with continuity preserved after it ends, consuming canonical navigation, attention and composition — **no temporary authorities anywhere**.
- **Cross-platform completion:** required C9 platform contracts proven (MSIX native notifications · desktop lifecycle · realtime foreground/background continuity · responsive presentation · deep links · platform media behaviour · semantic mobile/web/MSIX parity · real-device behaviour).

**NEXT UNLOCKED.** C11.

---

# CHAPTER C11 — ITEM 17: INTEGRATED RELEASE-CLIENT CERTIFICATION

> **Item 17 is unchanged, undiminished, and NOT a construction dumping ground.**

**PURPOSE.** The integrated Release Client certification / release gate.

**ENTRY CONDITIONS — all must be true.**

1. C0–C9 complete to their FD-13 definition of done (authority + migration + gate + regression + certification)
2. C10 complete **or** explicitly excluded from this release candidate by founder decision
3. Backend frozen baseline intact; approved Live additions certified where included
4. Cross-platform behaviour verified on mobile, web and **MSIX**
5. Real-device / native testing complete
6. Integrated end-to-end journeys pass
7. Real-Boundary certification complete
8. Founder Product Acceptance readiness
9. A Release Client candidate exists

**DO NOT START** until entry conditions hold. **DO NOT REDEFINE.**

---

## Certification layers — kept explicit

| Layer | Where it lands |
|---|---|
| **Architecture** | each chapter locally |
| **Implementation** | each chapter locally |
| **Product-Behavior** | per chapter at its founder checkpoint |
| **Cross-System** | C1, C5, C8, C10 |
| **Real-Boundary** | C9 substantially; C10 for media scale |
| **Founder Product Acceptance** | per checkpoint, consolidated at C11 |
| **Item 17 / Release Gate** | C11 only |

**A lower layer passing never implies a higher one.**
