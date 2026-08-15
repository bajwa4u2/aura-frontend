# Founder Decision Register — Frontend Product Architecture

> **REGISTER FULLY ADJUDICATED (2026-08-15).** All 13 FD entries plus five named cross-product freezes are RESOLVED and FROZEN.
>
> **Roadmap status:** the complete frozen set has been reconstructed into a final dependency-based roadmap — `FINAL_FRONTEND_RECONSTRUCTION_ROADMAP.md` (**C0–C11**), with dependency graph, traceability matrix, demolition matrix, authority map, certification/founder gates and old-to-new reconciliation.
>
> **FRONTEND PRODUCT-ARCHITECTURE ADJUDICATION — COMPLETE / FROZEN.**
> **FINAL FRONTEND RECONSTRUCTION ROADMAP — FOUNDER APPROVED / FROZEN (2026-08-15).**
> **IMPLEMENTATION — NOT YET STARTED.** Roadmap approval is not authorisation to begin a chapter.

**Each entry: decision, options, recommendation, consequence.**

**Adjudication status (2026-08-15).** **FD-1**, **FD-2**, **FD-3**, **FD-4**, **FD-6**, **FD-7**, **FD-8**, **FD-9**, **FD-11**, **FD-5**, **FD-10**, **FD-12** and **FD-13** are **RESOLVED and FROZEN**, plus five named cross-cutting freezes: **Capability-Adaptive Experience** · **Task/Domain-Oriented Adaptive Navigation + Canonical Product Language Authority** · **Threads/Spaces Product Model** · **Content Intake & Resolution Authority** · **Human Temporal Presentation Authority**.

> **Discovery is not closed.** Two of the freezes above (Content Intake, Human Temporal Presentation) were **founder-surfaced after the audit** — the audit did not find them. The roadmap is not limited to the original FD list or audit categories; newly exposed systemic drift must be brought forward, never buried, silently deferred, or forced into an unrelated decision to complete a checklist.

> **⚠ Numbering caution.** Founder instructions have twice labelled a decision with a number that differs from this register: the *Contextual Acting Authority* freeze was labelled "FD-9 Option C" (a rejected option), and the *Canonical Composition System* freeze was labelled "FD-2" (which here is Attention vocabulary, still open). **Decisions are authoritative by NAME.** Always confirm the named decision, not the number.

---

## FD-1 — ONE GOVERNED ATTENTION HUB + ACTIONABLE ATTENTION

# ✅ RESOLVED — FROZEN / FOUNDER APPROVED 2026-08-15
# FOUNDER-APPROVED DECISION: **ONE GOVERNED ATTENTION HUB + ACTIONABLE ATTENTION**

**Decision taken.** The fragmented attention architecture does not survive. One governed Attention Hub answers *"what needs my attention?"* as a **projection** across domains — never as a new owner of them. Actionable items expose **domain-owned** resolvable actions (`ATTENTION → CONTEXT → ACTION → RESOLUTION → CONTINUITY`), resolvable directly where safe, with deep routing to the exact owning context. `UNREAD` is **not** the universal attention state. Noise reduction is a primary requirement, and resolved actions must reconcile deterministically so no dead CTAs remain.

**Explicitly rejected.** One giant chronological notification feed · a renamed notification screen · a dumping ground for every event · a mirrored personal/institution inbox · the Hub replacing owning domains · the Hub reimplementing domain business logic.

### Decision history (traceability preserved)

| Step | Record |
|---|---|
| 1 | Original investigation proposed options **A / B / C**. |
| 2 | **A** = Communication Inbox + Notification Centre · **B** = one unified inbox, filtered · **C** = contextual only. |
| 3 | Founder approved **none as written**; a distinct model was defined during adjudication. |
| 4 | Founder **approved** *One Governed Attention Hub + Actionable Attention*. |
| 5 | It **supersedes the original FD-1 option set** where necessary. |

**Relationship to the original options:** **not** Option B (a single chronological feed is explicitly rejected) · **partially subsumes** Option A's separation, but as semantic **views inside one hub** rather than two products · **rejects** Option C's premise that no governed cross-domain projection should exist.

> **This decision is identified by NAME, not by option letter.** Never restate it as "FD-1 Option A/B/C".

**Full frozen text:** `FD1_ATTENTION_HUB_FROZEN.md` — semantic views, domain-owned action model, routing, resolution/clearing semantics, dead-CTA prevention, noise reduction, FD-9/FD-3 compliance, anti-drift guard.

**Consequence.** Governs Chapter F3; establishes DR1 as a demolish+rebuild candidate (**planning permission only, not deletion**); adds a frontend Attention Authority to F1; constrains F2 (no mirrored inbox) and F6 (realtime attention keeps owning semantics).

---

## FD-2 — ATTENTION VOCABULARY: OBLIGATION BADGE

# ✅ RESOLVED — FROZEN / FOUNDER APPROVED 2026-08-15
# SELECTED: OPTION A — OBLIGATION BADGE

> This is the register's own FD-2 (*Attention vocabulary*) — **not** the composition decision a founder instruction once labelled "FD-2", which is registered as **FD-6**.

**Decision taken.** **Primary Attention badge = unresolved actionable obligations.** Passive unread communication does **not** contribute; unread remains **contextual** to conversations and content. `ACTION_REQUIRED`, `INVITED` and `MISSED` contribute **while unresolved**. **Mentions contribute when they represent unresolved attention**, and resolve through owning-domain behaviour. Internal lifecycle states do **not** become unnecessary global UI vocabulary — though **context may still explain** states such as expired/dismissed where useful. **Badge truncation = `99+`.**

**Consequence.** The badge number drops sharply versus today, because it stops counting passive reading. That is the intended correction and it is user-visible.

**Together with FD-1:** FD-1 froze the attention *model*; FD-2 freezes the *exposure*. The attention vocabulary question is now closed.

**Full frozen text:** `FD2_ATTENTION_VOCABULARY_FROZEN.md`.

---

## FD-3 — Realtime semantics per context

# ✅ RESOLVED — FROZEN / FOUNDER APPROVED 2026-08-15

**Decision taken.** Shared realtime infrastructure does NOT imply shared product semantics. DM / Thread / Space / Institution Room / Meeting / Live each retain distinct ownership and meaning. Meetings keep their institutional lifecycle and are not collapsed into a generic room/call abstraction.

**Simultaneously frozen:** the *user experience* of creating, starting, adding/selecting/inviting people, joining, and managing participation **is to be reconstructed** — modern, simplified, curated. Governing principle: **SIMPLIFY THE ACT, NOT THE AUTHORITY.**

**Full frozen text:** `FD3_REALTIME_SEMANTICS_FROZEN.md` — including the shared-infrastructure boundary, the People & Participation selection investigation directive, and the anti-drift guard table.

**Consequence.** Governs Chapter F6 entirely, constrains F7 (Live is not a Meeting), and adds a People & Participation selection primitive to the authority work in F1.

---

## FD-4 — REALTIME PRESENTATION CONVERGENCE

# ✅ RESOLVED — FROZEN / FOUNDER APPROVED 2026-08-15
# SELECTED: OPTION A — SHARED PRESENTATION PRIMITIVES, MEETINGS LIFECYCLE UNTOUCHED

**Decision taken.** Converge participant list · host controls · admission/join-requests · consent onto a shared component family. **Meetings lifecycle untouched** — booking, invitation, attendance, waiting/admission, prep, summary and follow-up remain exactly as certified.

**Also frozen (founder addition).** **One shared participant/presentation component family may render different context-specific states and language supplied by the owning domain. The shared component does not own semantic meaning.** A Meeting attendee, a Room invitee and a future Live speaker are different states on the same component.

**Implementation safeguard (founder addition, frozen).** **Meetings must not be rewritten wholesale to "use the new shared screen."** Extract and replace only the proven duplicate presentation concerns, **slice by slice, with targeted regression after each slice** (Meetings currently 97/97).

**Explicitly rejected.** One unified room screen (option C — risks a certified surface for uniformity) · participant-list-only extraction (option B — leaves three of four divergences).

**Scope.** `institution_live_rooms_screen` is **not** in scope — it remains **DR2**, a rebuild against the frozen Institution Room contracts. Transport, media, reconciliation, orphan recovery and session continuity are untouched.

**Full frozen text:** `FD4_REALTIME_PRESENTATION_CONVERGENCE_FROZEN.md`. **Consequence:** governs the convergence half of Chapter F6.

---

## FD-5 — LIVE AS A GOVERNED MODE OF A THREAD OR SPACE

# RESOLVED — FROZEN / FOUNDER APPROVED 2026-08-15
# SELECTED: OPTION A

**This closes the Founder Decision Register.** Register closure is **not** roadmap approval.

**Decision taken.** Live is a governed public/stage participation **state** of an owning Thread or Space: `THREAD/SPACE -> AUTHORIZED GO LIVE -> LIVE STATE -> AUDIENCE/PARTICIPATION -> LIVE ENDS -> CONTINUITY REMAINS`. **Going Live must never orphan the conversation from its source context.**

**Eight rulings.** **Enable** = governed delegated capability (never hard-coded owner/admin; frontend never infers from role names). **Watch** = governed visibility policy; `GO LIVE != MAKE EVERYTHING PUBLIC`. **Speak** = invited speakers + request-to-speak/hand-raise; **no open mic**. **Audience voice** = lightweight reactions + governed questions; continuing discussion stays owned by Thread/Space (**no second Live comments system**). **Recording** = explicit/opt-in, distinct from go-live authorization; replay only when separately authorised and **owned by Thread/Space**. **Timing** = both instant and scheduled (**scheduled Live is not a Meeting**). **End** = authorised host/co-host action primary; scheduled end **advisory, not a hard cutoff**. **Notification** = ordinary audience attention **does not ring** (entitlement != interruption); explicitly invited speakers/co-hosts/moderators may receive governed ringing **through the canonical Notification Delivery + Multi-Device authorities**.

**Boundaries.** Option B (separate Live product) and **Option C (extend Institution Room) REJECTED**. Meetings must not be used as the implementation shortcut. Durable membership is never mutated by temporary Live roles.

**Discovery correction preserved.** `PUBLIC_STAGE`, the full participant-role vocabulary (HOST/CO_HOST/MODERATOR/SPEAKER/PARTICIPANT/LISTENER/OBSERVER), hand-raise and per-track publish state **already exist in the backend model** — the earlier claim that no speaker/audience model existed is **withdrawn**. But `PUBLIC_STAGE` is **declared and unconsumed**: **the role/stage vocabulary exists; the operational Live mechanism does not.**

**Staging APPROVED.** Realtime presentation/authority convergence **first**; Live after. **Do not build a fourth disconnected live surface.**

**Cross-repository chapter.** Go-live authority, public observation, audience scale, Live attention/interaction and replay-as-product are **missing backend construction**. **FD-5 creates a cross-repository chapter — backend construction must not be hidden inside a frontend phase.**

**Full frozen text:** `FD5_LIVE_THREAD_SPACE_FROZEN.md`.

---

## FD-6 — CANONICAL COMPOSITION SYSTEM + CONTEXT-GOVERNED EXPERIENCE

# ✅ RESOLVED — FROZEN / FOUNDER APPROVED 2026-08-15

> **⚠ NUMBERING NOTE.** The founder instruction that froze this decision labelled it **"FD-2"**. In this register **FD-2 is a different, still-open decision (*Attention vocabulary*)**. This decision resolves **FD-6** and constrains **FD-7**. The register numbering is unchanged; the decision is authoritative **by name**.

**Decision taken.** One canonical composition system + shared attachment/media lifecycle + context-governed product semantics + capability-adaptive presentation. Composition, **representation** (FD-9 acting context) and **delivery/publication** (owning domain + backend authority) are three distinct concepts no composer may reconstruct. Owning domains retain their communication semantics — surfaces are not forced to say Send or Publish for consistency. The default composer exposes only what the immediate act needs, with progressive disclosure for everything else.

**Explicitly rejected.** Solving fragmentation by making the six composers visually consistent · one giant universal text-box UI used identically everywhere · duplicated upload mechanics justified by differing file-type policy.

### Decision history

| Step | Record |
|---|---|
| 1 | Original options **A** (one composition authority + per-surface policy) · **B** (two engines) · **C** (shared attachment pipeline only). |
| 2 | Founder approved the direction of **A**, defined more fully as *Canonical Composition System + Context-Governed Experience*. |
| 3 | That definition **supersedes the original option set** where necessary. |

**Full frozen text:** `CANONICAL_COMPOSITION_SYSTEM_FROZEN.md`.

**Consequence.** Governs Chapter F5; makes the 6 composers + 11 upload pipelines a demolish/converge candidate (**planning permission only**); binds composers to FD-9 acting context.

---

## FD-7 — ATTACHMENT SEND MODEL: UPLOAD ON SELECTION

# ✅ RESOLVED — FROZEN / FOUNDER APPROVED 2026-08-15
# SELECTED: OPTION A — UPLOAD ON SELECTION

**Decision taken.** Upload begins on **select / paste / drop**: `SELECT/PASTE/DROP → VALIDATE → PREVIEW → UPLOAD → PROGRESS → READY → SEND/PUBLISH`. **Send/Publish remains a separate deliberate act, and uploading never means sent or published.**

**Draft ownership.** An uploaded-but-uncommitted attachment belongs to the **composition/draft state**, not to a message/post/publication. It survives draft save and reopen; on successful Send/Publish the reference is associated with the committed object **by the owning domain**.

**Release policy.** **Explicit discard → deterministic immediate release** (no waiting for the cleanup window). **Uncontrolled abandonment** (termination, crash, lost connectivity, interrupted lifecycle) → **existing backend orphan cleanup as the safety net**.

**Frozen invariant.** **ATTACHMENT READINESS IS PART OF COMPOSITION READINESS; ATTACHMENT UPLOAD IS NOT COMMUNICATION COMMITMENT.** A person must never believe a communication is ready while a required attachment is unresolved/failed/incomplete. **No silent queued-send semantics** — queued send is a separate future decision if ever wanted.

**Also frozen.** No developer lifecycle vocabulary in ordinary UI (`selected → progress → ready`, or `failed → retry/remove`). **No hybrid size/type upload timing** — option C rejected; context policy governs type/size/count/eligibility, not timing.

**⚠ Carry-forward (OPEN).** Review backend orphan-cleanup windows against the eventual canonical draft lifetime. **Backend policy is NOT changed by this decision** — any conflict is brought forward for adjudication.

**Full frozen text:** `FD7_ATTACHMENT_SEND_MODEL_FROZEN.md`. **Consequence:** completes the attachment half of Chapter F5 with FD-6.

---

## FD-8 — OFFICIAL DESIGNATION: PRE-PUBLICATION ONLY

# RESOLVED — FROZEN / FOUNDER APPROVED 2026-08-15
# SELECTED: OPTION A — PRE-PUBLICATION DESIGNATION ONLY

**Decision taken.** Designation is expressed **only before publication**, in the publish flow — **not** in writing/composition: `COMPOSE -> CONTENT READY -> PUBLISH FLOW -> CONFIRM ACTING/PUBLISHING AUTHORITY -> OFFICIAL DESIGNATION WHERE AUTHORIZED -> REQUIRED INSTITUTIONAL APPROVAL -> PUBLISH`. FD-6 remains authoritative: designation belongs to the **delivery/publication** layer.

**No post-publication elevation (B and C rejected).** An already-published ordinary institutional publication must never be promoted to `E_OFFICIAL` by a management action — that would grant official standing without passing the pre-publication approval floor. Substantially the same material must enter a **new official publication lifecycle** instead.

**Withdrawal remains legitimate** after publication because it **removes** standing rather than granting it. **Object-local** to the publication, preserving actor, timestamp, reason and provenance. It never rewrites historical assessments.

**Approval invalidation on edit — APPROVED.** **Any content change after approval invalidates that approval** and requires fresh review/approval. **No frontend "minor vs substantive" edit concept** unless a future deterministic governance rule defines it. Preserves the backend's existing stale-review behaviour.

**Experience requirement.** The consequence must be understood **before commitment** — never *select Official, press Publish, receive a governance error*. Where the actor can designate but not approve, the workflow becomes **DESIGNATE AS OFFICIAL -> SUBMIT FOR APPROVAL** (final copy subject to FD-10).

**Capability-adaptive.** Designation controls are hidden where irrelevant; the client **consumes** acting context, publication capability, designation eligibility and approval state — never implementing institutional-authority logic locally.

**Full frozen text:** `FD8_OFFICIAL_DESIGNATION_MOMENT_FROZEN.md`. **Consequence:** completes the publication half of Chapter F5; adds product-language obligations to FD-10.

---

## FD-9 — CONTEXTUAL ACTING AUTHORITY

# ✅ RESOLVED — FROZEN / FOUNDER APPROVED 2026-08-15
# FOUNDER-APPROVED DECISION: **CONTEXTUAL ACTING AUTHORITY**

**Decision taken.** One Release Client, one coherent navigation architecture, first-class contextual acting authority. The authenticated **person is the default actor**; institutional acting context is **entered deliberately and remains clearly attributable** where representation matters. Backend defines eligible acting contexts and permissions; the frontend never locally infers representational authority. Historical mirrored personal/institution route trees should be demolished/converged **where their only distinction is acting context** — genuinely different product semantics remain distinct, and nothing is merged mechanically.

**Explicitly rejected.** A permanent global Personal/Institution toggle as the organising principle · separate mirrored applications · invisible representational switching · **the original Option C (separate institution shell)**.

### Decision history (traceability preserved)

| Step | Record |
|---|---|
| 1 | Original investigation proposed options **A / B / C**. |
| 2 | Original **Option C = "Separate institution shell"**. |
| 3 | Founder **did NOT select** that proposal — original Option C is **REJECTED**. |
| 4 | A distinct **Contextual Acting Authority** model was defined during adjudication. |
| 5 | Founder **approved** that newly defined model. |
| 6 | It **supersedes the original FD-9 option set** where necessary. |

*(Historical option set, retained for audit only, no longer authoritative: **A.** One route tree + acting identity · **B.** Generate mirrored routes from one definition · **C.** Separate institution shell — REJECTED.)*

> **This decision is identified by NAME, not by option letter.** No replacement letter was invented. Never restate it as "FD-9 Option C".

**Full frozen text:** `FD9_ACTING_CONTEXT_FROZEN.md` — route-tree A/B test, composer and profile consequences, FD-3 compatibility clause, backend-authority boundary, anti-drift guard.

**Consequence.** Governs Chapters F1 and F2; constrains F5 (composer consumes acting context) and F4 (person identity ≠ acting context ≠ institution profile); establishes permission to **recommend** demolition of mirrored routes — **not** to implement it.

---

## FD-10 — TERMINOLOGY: CANONICAL SEMANTIC VOCABULARY

# RESOLVED — FROZEN / FOUNDER APPROVED 2026-08-15
# SELECTED: OPTION A — RESOLVE NOW WHERE SEMANTIC TRUTH IS SUFFICIENT

> **Premise correction.** The brief classified Cancel/Dismiss/Close/Discard as **pure synonyms**. That was **wrong**: they are four distinct user intentions and are governed semantically, not collapsed.

**Doctrine.** SEMANTIC TRUTH FIRST, VOCABULARY SECOND. A word survives only when the underlying concept survives. Copy changes never fix duplicated architecture; concepts are never collapsed to reduce vocabulary count; synonymous nouns are never kept merely because both exist.

**Rulings.**

- **Retry** is the canonical failed-operation CTA (retires `Try again`/`Retry` drift).
- **Cancel / Dismiss / Close / Discard** are **four distinct semantic families** — stop an incomplete operation · remove from attention without deleting · close a presentation surface · abandon uncommitted draft work.
- **Correspondence SURVIVES** as a distinct governed communication form (deliberate/formal communication with institutional/documentary continuity), separate from Message/DM and Thread. **The surviving word does NOT protect the current architecture** — if the implementation is merely duplicate messaging, converge/rebuild the mechanics while preserving the semantics.
- **Two-layer naming approved with condition:** any internal/product naming split must be **deliberate and documented**; the current accidental split is drift.
- **Post is canonical**; **Works** may survive only as a *curated/aggregated projection* of a body of work, never as a second publication authority.
- **Presence survives as the authority/domain concept** — not globally renamed to Availability. UI expresses the meaningful human state; local surfaces never infer presence.
- **Follow (asymmetric) and Connect (reciprocal) are distinct.** Connect becomes user-visible only if/when the reciprocal capability is legitimately built and approved — **vocabulary, not an implementation obligation**.
- **Verification:** no generic user-visible "Verified". Map each frozen backend class to what was verified, who established it, and where it has user value. Recorded as a **constrained Product Language implementation obligation**, not an unresolved semantic decision.
- **Missing vocabulary** frozen in intent for official designation, institutional approval, device transfer/routing and attention — with backend class names, routing internals and raw governance errors explicitly barred from product language.

**Scope.** FD-10 freezes **semantic vocabulary and distinctions**, not every string. The Product Language Authority governs nouns, CTA families, synonym drift and governance-to-product translation — **not a database of every sentence**. Enforcement per FD-13 is **minimum effective and mechanically reliable only** — no indiscriminate natural-language linting.

**Full frozen text:** `FD10_TERMINOLOGY_FROZEN.md`.

---

## FD-11 — CANONICAL IDENTITY PRESENTATION + CONTEXTUAL PROJECTION

# ✅ RESOLVED — FROZEN / FOUNDER APPROVED 2026-08-15

**Decision taken.** Canonical identity presentation + contextual projection + capability-adaptive experience. **PERSON ≠ INSTITUTION ≠ MEMBERSHIP ≠ ACTING CONTEXT ≠ PRESENCE**, never collapsed, yet participating in one coherent identity experience. A **member is a Person + relationship to an institution — not a third identity type**. Presentation hierarchy is frozen as **IDENTITY FIRST · CONTEXT SECOND · ACTIONS THIRD · METADATA ON DEMAND**. Institution is a **first-class identity**, not a company-shaped user. Presence is a contextual projection, and **technical connectivity does not automatically become social presence**. Verification preserves layered backend meaning without badge clutter or enum leakage.

**Scope note.** This resolves the registered FD-11 question (what is immediate vs progressive vs moved vs removed) **and widens it** to the whole identity/presence/relationship model.

**Explicitly rejected.** Separate personal/member/institution profile architectures · one universal Profile object collapsing all five concepts · a "Member" identity type · institution-as-user modelling · profile switching as a substitute for acting authority · cosmetic cleanup as the primary solution.

### Decision history

| Step | Record |
|---|---|
| 1 | Discovery findings **P1** (six meanings of "presence"), **P2** (three profile implementations), **P3** (visual weight) raised the question. |
| 2 | FD-11 originally asked only about presentation hierarchy. |
| 3 | Founder froze a broader model — *Canonical Identity Presentation + Contextual Projection* — which **supersedes and widens** the original FD-11 framing. |

**Full frozen text:** `CANONICAL_IDENTITY_PRESENTATION_FROZEN.md`.

**Consequence.** Governs Chapter F4; makes the public/member profile a demolish+rebuild candidate (**DR5 — planning permission only**); constrains F5 (composers consume identity primitives), F6 (realtime consumes canonical identity), F3 (attention routes to canonical identity) and the People & Participation selection primitive in F1.

---

## FD-12 — SURFACE DISPOSITION: PROVEN-DEAD RETIREMENT ONLY

# RESOLVED — FROZEN / FOUNDER APPROVED 2026-08-15
# SELECTED: OPTION A

**Decision taken.** Retire only what is **proven dead**; adjudicate low-reference surfaces in their **owning reconstruction chapters**.

**Confirmed dead — approved for retirement:** `conversations_screen.dart` (~1,033 lines, zero router references, only self-references, inside approved Attention demolition territory, and holding the codebase's only `sortDate: updatedAt` hazard). **Not preserved merely because substantial code exists.**

**Authorization is not implementation.** No frontend code is deleted during adjudication; removal happens in the implementation/cleanup chapter with dependency verification, regression, route/build verification and salvage.

**Low reference is not death.** `InstitutionCorrespondenceScreen`, `PresenceScreen`, `SupportScreen` and `LoginScreen` remain **candidates**, carried into correspondence reconstruction, FD-11 identity reconstruction, auth/navigation review and monetization-ownership review respectively. **They must not vanish from the obligation register because FD-12 closed.**

**LoginScreen false-positive recorded as evidence:** **static reference count alone is not a safe reachability authority** — indirect routing, generated registration or registry-driven navigation can hide legitimate surfaces from grep.

**Founder-approved principle.** **EVERY PRODUCTION SURFACE MUST HAVE AN EXPLICIT, AUDITABLE REACHABILITY / OWNERSHIP PATH — OR BE EXPLICITLY CLASSIFIED AS LEGITIMATE NON-ROUTABLE / INTERNAL.** A screen must not persist merely because nobody knows whether it is used. **A naïve zero-reference build gate is explicitly forbidden** (it would have flagged LoginScreen); enforcement must be architecture-aware. **Exact mechanism deferred to FD-13.**

**Retirement doctrine frozen.** PROVEN DEAD -> authorize retirement. LOW REFERENCE -> investigate in owning context. INDIRECTLY REACHABLE -> preserve if product-correct. SEMANTICALLY SUPERSEDED -> retire during the replacement chapter. **Do not delete from grep count alone. Do not preserve from fear alone.**

**Full frozen text:** `FD12_SURFACE_DISPOSITION_FROZEN.md`.

---

## FD-13 — ENFORCEMENT: GATES SHIP WITH THE AUTHORITY THEY PROTECT

# RESOLVED — FROZEN / FOUNDER APPROVED 2026-08-15
# SELECTED: OPTION A — SOURCE-LEVEL GATES + ARCHITECTURE TESTS PER AUTHORITY

**Decision taken.** Source-level gates and architecture tests, added **with each authority**. **Hard build/certification failure** — soft gates rejected as the default model. Exceptions permitted but **explicit, narrow, justified, reviewable**, and visible in the governing enforcement artifact; no wildcard suppressions, generic legacy exclusions, ignore directories or silent bypasses.

**Sequencing frozen.** **ENFORCEMENT SHIPS WITH THE AUTHORITY IT PROTECTS. THERE IS NO SEPARATE END-OF-PROGRAM ENFORCEMENT CHAPTER.** `AUTHORITY REBUILT -> MIGRATE CONSUMERS -> ADD MINIMUM GATES -> REGRESSION/CERTIFICATION -> only then is that authority complete.`

**Completion formula frozen.** **AUTHORITY + CONSUMER MIGRATION + ANTI-DRIFT ENFORCEMENT + REGRESSION/CERTIFICATION = COMPLETE RECONSTRUCTION.** A shared authority is not complete merely because it exists.

**Enforce the invariant, not accidental implementation.** The invariant is *humanized time flows through the canonical Temporal Authority* — not *every file must import `relative_time.dart`*. Gates evolve with the authority without weakening doctrine.

**No governance platform up front (Option B rejected).** No generated infrastructure, metadata frameworks, governance DSLs, broad registries or generalized lint platforms before reconstructed authorities establish demonstrated need. If consolidation later proves warranted, bring it forward rather than silently building it.

**Gate quality requirement.** A gate must be trustworthy — no known false positives, no routine suppression, no blindness to legitimate indirect architecture, no false sense of certification. **Where a reliable hard gate cannot yet be built, record the obligation with its authority and bring the limitation forward — never silently downgrade to a warning.**

**Definition of done.** Every authority chapter records: frozen invariant, canonical owner, migrated consumers, prohibited competing pattern, enforcement mechanism, legitimate exceptions, regression/certification evidence.

**Full frozen text:** `FD13_ENFORCEMENT_MECHANISMS_FROZEN.md`. **Consequence:** closes the fourth structural fault; every reconstruction chapter now carries its own enforcement obligation.

---

## FROZEN DECISION — TASK/DOMAIN-ORIENTED ADAPTIVE NAVIGATION + CONTEXTUAL DEPTH + CANONICAL PRODUCT LANGUAGE AUTHORITY

# ✅ FROZEN / FOUNDER APPROVED 2026-08-15

> **Register mapping.** The **navigation/IA** half has **no pre-existing register entry** — IA questions were previously folded into FD-9. It is therefore recorded as a **named** decision (same pattern as *Capability-Adaptive Experience*); **no new FD number was invented**. The **Canonical Product Language Authority** half governed the *method*; **FD-10 vocabulary was subsequently FROZEN separately (2026-08-15)**. It **complies with, and does not supersede, FD-9.**

**Decision taken.** One coherent information architecture · few stable primary destinations · contextual object-local navigation · capability-adaptive actions · canonical product language. **Users navigate to objects and intentions, not backend modules.** Objects own their contextual depth; acting context never duplicates the IA; primary navigation need not contain every capability; deep links preserve exact context. A **Canonical Product Language Authority** will govern nouns, verbs, CTA families and state terminology under the rule **converge synonyms, preserve genuine semantic distinctions** — and **copy-only fixes are forbidden where drift reflects duplicated architecture**.

**⚠ Explicitly NOT frozen.** The exact primary destinations/tabs. Those are to be derived later from frozen semantics, domain ownership, research, journeys, frequency, object relationships, attention architecture, acting context and capability-adaptive experience.

**Explicitly rejected.** Cleaning up today's route tree as the solution · reorganising today's menus · preserving mirrored institution navigation · exposing backend modules as navigation · renaming tabs without resolving semantics · a generic Calls/Realtime destination · a global composer destination · search as a patch for bad IA · designing desktop IA then separately inventing mobile IA · preserving structural drift to avoid migration.

**Full frozen text:** `NAVIGATION_IA_PRODUCT_LANGUAGE_FROZEN.md`.

**Consequence.** Governs Chapter F2 and the CTA/terminology work feeding FD-10; extends DR4 to cover CTA/label drift and module-oriented navigation; adds navigation and product-language authorities to F1.

---

## FROZEN DECISION — THREADS / SPACES PRODUCT MODEL (DISTINCT BUT COMPOSABLE)

# ✅ FROZEN / FOUNDER APPROVED 2026-08-15

> **Register mapping.** No pre-existing FD entry — Threads/Spaces semantics were only partially covered inside FD-3. Recorded as a **named** decision; **no new FD number invented**. **Complies with, does not supersede, FD-3.**

**THREAD = focused conversation continuity. SPACE = persistent shared context/community.** Distinct concepts; infrastructure may converge, semantics do not. **A Space may contain multiple Threads; a Thread does not require a Space.** **Durable Space membership ≠ temporary realtime/Live participation role** (a Space member may become speaker and back without mutating membership). Management is object-local where practical; role vocabulary is exposed only where the distinction has user value.

**Live dependency frozen here:** future Live emerges from a governed Thread/Space context, not an isolated generic broadcast product. **The full Live model was subsequently FROZEN as FD-5 (2026-08-15).**

**Full frozen text:** `THREADS_SPACES_PRODUCT_MODEL_FROZEN.md`. **Consequence:** governs the Thread/Space portions of F2/F6; constrains F5 and F7.

---

## FROZEN OBLIGATION — CONTENT INTAKE & RESOLUTION AUTHORITY

# ✅ FOUNDER DIRECTION FROZEN 2026-08-15 — CROSS-PRODUCT

> **Founder-surfaced; the original audit did not identify this.** Adjacent to the canonical Composition System (**FD-6**). No new FD number invented.

**Paste/drop/selection must resolve the content the person actually provided.** `TYPE/SELECT/PASTE/DROP → DETECT → RESOLVE → PRESERVE SUPPORTED SEMANTICS → PREVIEW → VALIDATE → ATTACH/COMPOSE → SEND/PUBLISH`. **PRESERVE RICHNESS; DO NOT INVENT RICHNESS.** Supported pasted images/files become attachments naturally; links resolve to governed previews where supported; unsupported content fails **visibly and recoverably, never silently**. This is **not another composer** — it is an input/resolution layer serving the canonical Composition System.

**Measured:** Clipboard handling in **25 files**, paste handling in **25 files**, and **drag-and-drop in 0 files** — a new discovery, notable because Windows/MSIX is a governed release target.

**Full frozen text:** `CONTENT_INTAKE_RESOLUTION_AUTHORITY_FROZEN.md`. **Consequence:** joins Chapter F5.

---

## FROZEN OBLIGATION — HUMAN TEMPORAL PRESENTATION AUTHORITY

# ✅ FOUNDER DIRECTION FROZEN 2026-08-15 — CROSS-PRODUCT

> **Founder-surfaced; the original audit missed this entirely.** No pre-existing FD entry; no new FD number invented.

> **MACHINES STORE PRECISE TIME; PEOPLE EXPERIENCE MEANINGFUL TIME.** Event semantics determine labelling **and sorting**; the owning domain decides which event time has product meaning; raw developer timestamps must not dominate ordinary experience; exact time stays available where useful.

**Measured:** `relative_time.dart` has **9 consumers** while **52 files** compute `.difference(` themselves; `toLocal()` in **35 files**; `DateFormat` in only 5; **22 files** sort independently. `createdAt` appears **295×** against `sentAt` 14× — and **`receivedAt` / `occurredAt` never appear at all.**

**Full frozen text:** `HUMAN_TEMPORAL_PRESENTATION_AUTHORITY_FROZEN.md`. **Consequence:** new cross-cutting obligation spanning F3 (attention ordering), F5 (composition/publication semantics) and F2 (product language verbs).

---

## GOVERNING PRINCIPLE — CAPABILITY-ADAPTIVE EXPERIENCE

# ✅ FROZEN / FOUNDER APPROVED 2026-08-15 — CROSS-PRODUCT

Not a single decision entry: a principle constraining **every** remaining frontend decision and reconstruction chapter.

> ONE COHERENT PRODUCT → CONTEXT REVEALS RELEVANT CAPABILITY → AUTHORITY REVEALS AVAILABLE ACTIONS → CURRENT STATE DETERMINES WHAT MATTERS NOW → COMPLEXITY APPEARS ONLY WHEN NEEDED.

**Roles change available capability — they do not force people into different products.** Never expose authority complexity until the person needs to exercise it. Management is **object-local** where practical; progressive disclosure is **required**; the resolution must be **deterministic** (not AI-generated UI, not frontend role inference). Backend remains final authority — the client determines presentation hierarchy, never permission.

Compatible with and constrained by frozen **FD-3**, **FD-9** and **FD-1**.

**Full frozen text:** `CAPABILITY_ADAPTIVE_EXPERIENCE_FROZEN.md`.

**Applies to:** navigation · profiles · presence · Inbox/Attention · DM · Threads · Spaces · Meetings · Institution Rooms · future Live · composers · attachments · institution/member management · moderation · participant management · settings.

---

## Decision dependency order

**FD-3 ✅ done. FD-9 ✅ done** (they governed F1/F2/F6) → **FD-1 ✅ done**, **FD-2 ✅ done** (F3) → **FD-10 ✅ done**, **FD-11 ✅ done** (F4) → **FD-6 ✅ done**, **FD-7 ✅ done**, **FD-8 ✅ done** (F5) → **FD-4 ✅ done** (F6) → **FD-5 ✅ done** (F7). **FD-12 ✅ done. FD-13 ✅ done.**
