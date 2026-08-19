# Aura Release Client — Current State

**Last updated: 2026-08-19**

---

## Status

| Track | State |
|---|---|
| **Aura Public-First Causal Doctrine** | ✅ **FOUNDER-FROZEN / ADOPTED** (2026-08-15) — interpretive lens for all product work; canonical source in Representation |
| **Public-first general-entry copy** | ✅ **RECONCILED / LOCALLY CERTIFIED** (2026-08-15) — C-1…C-4 resolved; gate at `test/doctrine/` |
| **Backend construction baseline** | ✅ **FROZEN** (aura-backend, commit `2a92a0e`) |
| **Frontend product-architecture adjudication** | ✅ **COMPLETE / FROZEN** |
| **Final frontend reconstruction roadmap** | ✅ **FOUNDER APPROVED / FROZEN** |
| **C0 — Cross-Cutting Foundations** | ✅ **COMPLETE / FOUNDER APPROVED / LOCALLY CERTIFIED** (2026-08-15) |
| **C1 — Acting Context & Capability** | ✅ **COMPLETE / FOUNDER APPROVED / LOCALLY CERTIFIED** (2026-08-15) |
| **C2 — Identity / Presence / Profile** | ⛔ **READY / NOT STARTED / NOT YET AUTHORIZED** |
| **Frontend implementation (C2–C11)** | ⛔ **NOT STARTED** |
| **PD-1 Platform Administration** | ✅ **RESOLVED** (founder ruling 2026-08-18) — `OUT_OF_CURRENT_RECONSTRUCTION_SCOPE`. NOT deprecated, demolished or removed; 11 files / 52 debt sites `FROZEN_BY_RULE`. `/admin` route classification still applies — scope exclusion is not a security bypass. |
| **PD-2 Authentication & Account Entry** | ✅ **RESOLVED** (founder ruling 2026-08-18) — split ratified: **CH-02 owns STRUCTURE, CH-10 owns ACCOUNT-ENTRY EXPERIENCE**. Seam enumerated in `docs/governance/CH02_DESTINATION_RECONSTRUCTION_CONTRACT.md`. |
| **Portfolio reconstruction — Wave 1** | 🟡 **PART 1 + PART 2 EXECUTED** (2026-08-18) — W1-000/A/B/F and W1-C/D/E done. **No chapter closed.** F065 live refresh proof OWED (PB-11 founder observation). See `docs/portfolio/PART2_EXECUTION_RECORD_2026-08-18.md`. |
| **Portfolio reconstruction — execution-first (CH-13)** | 🟡 **IN PROGRESS** (2026-08-19) — F011/F125/F014/F025/F026 implemented, live certification OWED for all five. **F017 `FOUNDER_CLOSED`** by ruling on production evidence (zero eligible rows; no mutation performed). **F135 implemented** (2026-08-19) — link-preview images now delivered by Aura, never fetched from the third-party host by the viewer. CH-13 finding-level construction **exhausted** (its 26 obligations are all RC-C5, behind the frozen hard gate). **CH-02 refresh continuity** — RC1, RC7-articles, **RC2 + RC3** done: institution route restoration now runs through one canonical authority that separates *unresolved* from *absent* and validates the URL's institution against real membership. **RC4, RC7-compose and the RC3 screen-binding half now done too** — `/institutions/me` is scopeable to a held institution, so a second institution's workspace reconstructs honestly. **F059 and F062 → IMPLEMENTED_NOT_LIVE_CERTIFIED**; F061/F063 remain OPEN. **RC8 is blocked on founder authorization** — its whole remaining surface is booking/meeting-entry. |
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

## C1 — Acting Context & Capability Projection (implemented 2026-08-15)

Two authorities in `lib/core/authority/`: **Acting Context** (`acting_context.dart`) and **Capability Projection** (`capability_projection.dart`), plus `authority_providers.dart` and the founder-approved Option A attribution component `acting_attribution.dart`.

**Frozen rule:** acting authority becomes explicit when a consequential action requires attribution — **never because of the route the person navigated through**.

**Four real defects corrected.** Presence heartbeat published as the institution for anyone merely affiliated · "tap Message" started threads as the institution purely from the URL · six capability tokens fabricated client-side (proven unreachable dead code) · `/institutions/me` returned capabilities for the person's arbitrarily-oldest membership, so a client viewing institution B reasoned with institution A's authority.

**Backend converged:** `institutions.service.ts` no longer duplicates the effective-capability formula — it delegates to `InstitutionAuthorityService`, which was already injected. Every membership now carries its own effective capabilities.

**The discovery baseline was wrong in both directions:** role-literal comparisons 29 files → **5 files / 6 sites** (3 not authorization at all); `canX` 20 files → **38 files / 73 sites** (most not authorization). The real vector was never named: **86 `isOwner`/`isAdmin` sites**.

**G5 re-verification withdrew 38 of 42 sites from C1** — measured zero institutional authority code in all 11 admin and both auth files. Dispositioned to **PD-1** and **PD-2**. 181 sites still traceable.

Registers: `C1_AUTHORITY_ARCHITECTURE.md` · `C1_G5_DISPOSITION_MATRIX.md`.

**Option A certified** on a representative surface (institution post composer): attribution stated where the act commits, no manufactured chooser, acting person kept visible. 4 widget tests.

**Product Language extended:** `ProductAction.switchIdentity` ("Switch identity") — approved C0 extension discovered through C1 implementation, with four competing phrasings gate-prohibited.

**Verification:** analyze clean · **505 frontend** / **2200 backend** tests passing.

## C2 — Identity, Presence & Profile (in discovery, 2026-08-15)

**§6 Follow forensic COMPLETE** — `docs/frontend-discovery/C2_FOLLOW_FORENSIC.md`. The two systems partition by target type in the shipped client: person→person is request-only via legacy `Follow`/`FollowRequest`; person/institution→institution is immediate via `InteractionFollow`. They are complementary halves of one feature, each blind to the other.

**Eight defects, four new.** D1 following a person never reaches the feed · **D2 blocking does not stop DMs (safety)** · D3 API consent bypass · D4 counts never emitted · D5 `REQUESTED` never written · **D6 `BLOCKED` never written — only read, by the dead check in D2** · **D7 `FOLLOW_REQUEST`/`FOLLOW_ACCEPTED` fully plumbed through email, routing and delivery but never emitted — relationship events are silent** · D8 request message accepted and discarded.

**§7 recommendation:** Follow and Subscribe are **separate concepts sharing infrastructure** — following an actor notifies them; subscribing to a Thread/Space notifies nobody and only changes what reaches you. Keep `InteractionFollow` as shared storage. Naming deferred to C4 (recommended).

**Blocked on founder adjudication:** canonical Follow target, conflict rules for states 2–5, Follow/Subscribe naming ownership. **No migration performed, no production access.**

**Founder adjudication R1–R10 recorded** (see `C2_FOLLOW_FORENSIC.md`). **R1 blocking defect RESOLVED and CERTIFIED** — `canMessage` now consults the canonical `UserBlock`/`BlocksService` authority instead of a status nothing writes; follow eligibility gated too; backend 173 suites / 2207 tests green.

**§8 availability privacy:** five options returned with the decisive finding that `getState` **receives no viewer identity at all**, so no policy is enforceable until that changes. **§10 People Selection:** two by-design person projections, neither carrying verification or availability. **§11 G5: 21/21 confirmed C2**, zero reassignment — but 9 of the 21 are legacy Follow surfaces blocked on the convergence model.

**§9 edit-profile convergence COMPLETE** — `C2_PROFILE_CONVERGENCE.md`. Shared `ProfileMediaPipeline` (8 duplicated flows → 1, person side gained validation), institution gate corrected from `isAdmin` to the `MANAGE_BRANDING` capability the backend actually enforces (both defect directions pinned by test), 4 G5 sites eliminated (181→177), 3 R1 sites eliminated (85→82), person "Presence" naming drift corrected. No flattened Profile ontology — subjects remain distinct.

**Canonical Follow COMPLETE** — `C2_CANONICAL_FOLLOW.md`. `CanonicalFollowService` is the single relationship authority; consent partition frozen as product truth (person→person request-only, →institution immediate); D3 consent bypass CLOSED; R9 institution→person refused at both writers; FOLLOW_REQUEST/FOLLOW_ACCEPTED wired (rejection deliberately state-only); D4 counts emitted; availability relationship source replaced at the designated point; legacy writers retired. **No rows moved** — legacy preservation + canonical projection; physical convergence staged for a later migration chapter. Feed activation (D1) deliberately NOT performed — staged founder decision.

**Follow ADOPTED in the release client (2026-08-16):** D1 feed activation live (old follows participate, no refollow needed) · nine Follow G5 sites consumed (G5 177→168) · cooldown state visible on profiles · counts real · request/accept notifications live. **Final storage architecture designed** (FollowEdge + FollowConsent) with an executable, gated physical migration plan. **C0–C2 reconstruction-debt register produced** under the new founder doctrine — \`C2_RECONSTRUCTION_DEBT_REGISTER.md\`.

**Verification & Trust Experience — EXECUTED 2026-08-16** (`C2_TRUST_PRESENTATION.md`): canonical trust layer (`core/trust/verification.dart` + `trust_marks.dart`), person profile wire gap closed backend-side (profile now emits `verification.classes`; raw column stripped), Person Verification Authority exposed to admins for the first time (grant/revoke/history under VERIFICATION_READ/WRITE), person profile renders per-class marks, 13 institution sites migrated onto canonical marks, §11 'Official session'-from-isVerified violation corrected, admin verification sheet added. Generic `'Verified'` literals 16→8 (all remaining subject-unambiguous, classified). NEW founder decision surfaced: plan taxonomy sells verification (§20 STOP) — **adjudicated and RESOLVED 2026-08-16**: full decoupling implemented backend+frontend (see DECISIONS.md §Monetization × Verification Decoupling; backend commit “Decouple commercial plans from verification authority”; reconciliation SQL in prisma/manual/, manual + founder-observed). “Role attested” wording applied in the canonical trust layer. **Taxonomy CLOSED 2026-08-16: FREE + PRO frozen** (backend 2217480) — middle tier retired not renamed, dead capability booleans + requirePlan/PLAN_REQUIRED_VERIFIED deleted, new checkouts refuse the retired product code, legacy rows behavior-preserved pending the observed migration window. FUTURE COMMERCIALIZATION GOVERNANCE MARKER recorded in DECISIONS.md — final Free/Pro boundary deliberately NOT decided. **Commercial-matrix forensic complete 2026-08-16** (C2_TRUST_PRESENTATION.md §11): only enforced tier differences are member capacity (env-driven) and PRO's institution-level official-publishing gate; AI/translation/realtime are credit-metered plan-independent (plan copy corrected to enforcement truth, backend d940477); middle tier commercially weak after decoupling — reported, nothing invented.

**§12 Representation consistency — EXECUTED 2026-08-16** (`C2_REPRESENTATION_CONSISTENCY.md`): full bidirectional matrix; Representation caught up via NEW `inventory/AURA_IDENTITY_RELATIONSHIP_TRUST_CANON.md` + dated supersession banners on the stale Follow/Presence/Verification characterizations (selective 3-file commit, other agents' uncommitted Representation work untouched); two client-behind-authority defects corrected (three local time-ago dialects → AuraTemporal; three bare institution checkmarks in discourse intelligence → canonical marks); G2 updates_screen burn-down 6→0 recorded in baseline.

**Public Home reconstruction — EXECUTED 2026-08-16** (`C2_PUBLIC_HOME_RECONSTRUCTION.md`): institution-first hero on `/` replaced with public-first entry copy; verification glyph decoupled from 8 institution-involvement/accountability motifs (3 files); hand-rolled Verified-institution line → canonical mark; feed-card timestamp off the deprecated shim (11→10 callers); 6 G5 sites → product-state authority with retry (baseline burn-down recorded); retired "works" vocabulary removed; participation copy made truthful; **public-first gate extended to cover both home surfaces** (the gap that let the old hero ship). No founder decisions required.

**FINAL CONVERGENCE + PRE-MIGRATION CLOSEOUT — EXECUTED 2026-08-16** (`C2_PRE_MIGRATION_CLOSEOUT.md` is the handoff authority): Follow HTTP-in-widget retired (FollowsRepository now owns the consent lifecycle + canonical counts); live-rooms startLive gate converged onto C1 capability projection (R1 burn-down recorded); dead FeedPresence.lastActiveAt parse slot removed; final debt remeasured — zero unexplained C2-owned remainder. **Frontend committed in 5 bounded commits** (11e85fa, 0d0abf5, 121d029, cff6982, 7a243e1 + closeout doc); backend 9 bounded commits, Representation 1 — all local, nothing pushed.

**C2 STATUS: DATA TRANSITIONS EXECUTED 2026-08-16** (see C2_FINAL_CLOSEOUT.md): verification reconciled (drift 0), TRUSTED+legacy VERIFIED enum values physically retired (zero-row evidence), Follow migrated to FollowEdge+FollowConsent with 8/8 equivalence checks and canonical-store cutover live (AURA_FOLLOW_STORE=canonical). Cutover observed healthy → **legacy Follow stores + flag + zombie enums RETIRED (d18b0bb)**; zero migration-dependent debt.

**C2: FINAL CLOSURE DECLARED BY FOUNDER 2026-08-16.**

**C3 (NAVIGATION & IA): PHASE 1 FORENSIC COMPLETE 2026-08-16** — see C3_NAVIGATION_IA_RECONSTRUCTION.md. Re-measured: 171 routes / 40 DR4 mirrors / 27 redirects / 266 feature route literals in 92 files. Root cause identified: shell selection is path-derived (AppShell), which forces the mirrored universe; resolveActorContext still derives institutional acting context from path (3 consumers — DM-actor fix is C7-reserved per C1 contract). Capability-adaptive institution nav already RESOLVED (hidden-not-disabled, effective-capability-true). **FOUNDER FROZE THE PRIMARY IA 2026-08-16** (Home/Messages/Discover/Meetings/Me + Discover semantics + institution-as-context + Follow-as ruling). **Phase 2 certified boundary shipped** (9ffb777 + d577e67): Navigation Authority live, five-primary adoption on Member+Public shells, /discover destination, route-derived acting context RETIRED (resolveActorContext deleted; explicit Follow-as; explicit institution inbox context; canActAsInstitution governance predicate), 544 tests + all gates green. **C3 CLOSEOUT REACHED 2026-08-16** (C3_FINAL_CLOSEOUT.md is the handoff authority): DR4 executed per-route (2 pure duplicates → alias redirects, 35 canonical institution depth, 3 C7-pending inbox trio); route-derived acting context = 0 mechanisms; route-integrity gate + literal ratchet live (103 files/294 sites frozen, every literal validated against the declared table — caught 2 real defects on first run); redirects all classified with owners; shell classification = destination identity, non-authority pinned. 547 tests + all gates green. **DR4 reconciliation EXECUTED (founder-ordered proof): HELD** — 34 canonical depth + 4 C7-held, 0 mirrors remaining, over-broad Phase-1 phrasing superseded, alias-aware shell hardening + pin added (C3_DR4_ARCHITECTURE_RECONCILIATION.md). **Recommendation: C3 FINAL CLOSE. Awaiting founder declaration.** Commits local, NOT pushed.

**C3 was previously: AUTHORIZED — NOT STARTED.** Founder paused at closure; no C3 discovery or implementation has begun. Next session starts C3 from the C2 closeout contracts (C2_FINAL_CLOSEOUT.md + C2_PRE_MIGRATION_CLOSEOUT.md), which C3 must not reopen. Boot incident fixed + app-boot graph spec added (79de236). C3 not authorized.

## What has NOT been touched

No routes · no screens redesigned · no layout or visual treatment changed · Meetings untouched · no backend · no Representation. **Nothing committed.**


---

**C3: FINAL CLOSURE DECLARED BY FOUNDER; pushed + deployed (70ec625..4aa3035).** The stale "not pushed / nothing committed" lines above predate that push and are superseded by this entry.

**FOUNDER-OBSERVED NAVIGATION CORRECTION EXECUTED 2026-08-16** (authoritative rulings — see DECISIONS.md "FOUNDER-OBSERVED NAVIGATION CORRECTION"): authenticated primaries amended to **HOME · MESSAGES · DISCOVER · CREATE** (Me removed → identity/avatar chrome; Meetings removed → institutional domain, no bare /meetings destination; Create restored as primary human intention with global+contextual complementarity). Discover corrected: four-domain framework (Articles canonically declared, not rendered until truthful capability), institutions directory de-contaminated + verification-as-ranking retired end-to-end (backend single activity-ordered list with keyset cursor + transitional cohort arrays for released clients), Spaces taxonomy broadened to 10 in the single registry. Messages gained the persistent contextual "New conversation" entry (canonical chooser lifecycle). Institution onboarding = lifecycle-gated acquisition action (desktop header while no affiliation; account menu + Create hub afterwards). Header invite icon retired (dead parameter surface). Route-integrity gate strengthened: authority-declared addresses proven executable against the router table (the /meetings class of defect cannot recur). C4 (ATTENTION) forensic evidence base complete; C4 implementation NOT started, held per founder sequencing.


**AURA CONVERSATION + INVITATION SYSTEMS BUILT (2026-08-16, local, uncommitted;
awaiting §62 checkpoint ruling):** canon frozen (see DECISIONS pointer); backend
foundation complete (AuraInvitation + Conversation* schema, additive migration
20260825…, InvitationAuthority + ConversationAuthority + adapter registry,
People Discovery /v1/discover/people; backend 2307/2307 + 32 new-system tests).
Frontend: new lib/features/conversation/ module (MessagesScreen at /messages,
ConversationScreen /messages/c/:id, picker /messages/new, AddPeople→Invitation,
/i/:token claim landing) + Discover→People personalized surface
(/discover/people); Create hub per §53 (Invitation/Institution cards removed);
frontend 557/557, analyzer clean, all gates green incl. C0 product-state
ratchet (new surfaces consume AuraProductState; ProductNoun.conversation
added). Production measured (read-only): 5 DirectThreads/9 msgs, 10 PRIVATE
personal spaces/67 msgs, 0 grown-past-pair, 2 named personal spaces.
Idempotent migration script scripts/migrate-conversations.js (+ dry-run
measurement mode) and scripts/seed-public-spaces.js (4 broadened subjects →
real PublicSpace rows) ready for authorized deploy. Legacy conversation
surfaces NOT yet retired (Phase 5 follows verified production migration);
legacy hub parked at /messages/legacy-hub. C4 held; C5 hard-gated.

**§62 FOUNDER RESOLUTION APPLIED (2026-08-16):** C7 amendment FROZEN
(Institutional Conversation & Desk); both named personal spaces inspected
individually ("family" CIRCLE 2 members/3 msgs; "Aura Internal" WORKROOM 3
members/1 msg — single-thread each) → MIGRATE with human-chosen names as
Conversation presentation (migration script extended + dry-run verified);
Create vocabulary corrected to frozen intent (Message · Post · contextual
Announcement; pinned); Conversation completion register recorded (realtime/
media/report attach before Conversation final certification); abuse policy =
hooks only per founder; Phase 5 retirement NOT authorized (gate: additive
deploy → migration → founder live observation → journey certification →
explicit authorization). Release authorized: commit + push both repos;
founder observes deployment; migration + PublicSpace seed run through the
authorized deployment path. C4 next after founder live certification; C5
hard-gated on C4 live closure.
