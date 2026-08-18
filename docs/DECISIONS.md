# Aura Release Client — Frozen Decisions

**All frozen 2026-08-15.** Full text for each lives in `docs/frontend-discovery/`.

> **Decisions are authoritative by NAME, not by option letter.** Founder instructions twice used a number/letter that differed from the register — recorded in the register's numbering caution.

## Founder Decision Register — FD-1 … FD-13

| FD | Decision |
|---|---|
| **FD-1** | **One Governed Attention Hub + Actionable Attention** — attention is a projection, never a new owner; domain-owned resolvable actions |
| **FD-2** | **Obligation Badge** — badge = unresolved actionable obligations; passive unread never contributes; truncation `99+` |
| **FD-3** | **Realtime product semantics** — DM/Thread/Space/Institution Room/Meeting/Live distinct; shared infrastructure never erases semantics; **UX to be reconstructed** |
| **FD-4** | **Realtime presentation convergence** — shared primitives, Meetings lifecycle untouched, **no wholesale rewrite; slice-by-slice with regression** |
| **FD-5** | **Live as a governed mode of a Thread/Space** — not a product, not a Meeting, not an Institution Room; 8 rulings |
| **FD-6** | **Canonical Composition System** — composition ≠ representation ≠ delivery/publication |
| **FD-7** | **Upload on selection** — uploaded ≠ sent; drafts own uncommitted attachments; explicit discard releases immediately |
| **FD-8** | **Pre-publication official designation only** — no post-publication elevation; content change invalidates approval |
| **FD-9** | **Contextual Acting Authority** — one client, one IA, person is default actor, backend defines eligibility |
| **FD-10** | **Canonical semantic vocabulary** — Correspondence distinct · Post canonical · Presence retained · Follow ≠ Connect · layered verification · `RETRY` · four CTA families |
| **FD-11** | **Canonical Identity Presentation + Contextual Projection** — person ≠ institution ≠ membership ≠ acting context ≠ presence |
| **FD-12** | **Proven-dead retirement only** + surface reachability principle; naïve zero-reference gate forbidden |
| **FD-13** | **Enforcement ships with the authority it protects** — hard failure, narrow exceptions, no end-stage enforcement chapter |

## Five named cross-product freezes

1. **Capability-Adaptive Experience** — roles change available capability, not the product
2. **Task/Domain-Oriented Adaptive Navigation + Canonical Product Language Authority**
3. **Threads / Spaces Product Model** — distinct but composable
4. **Content Intake & Resolution Authority** *(founder-surfaced)*
5. **Human Temporal Presentation Authority** *(founder-surfaced)*

## Roadmap decision (2026-08-15)

**FINAL / FOUNDER APPROVED / FROZEN**, subject to two corrections, both applied:

1. **Live product-dependency correction** — C3, C4 and C5 are **product-architecture prerequisites** of Live, not merely later chapters. Governing invariant frozen: **LIVE MUST NOT CREATE TEMPORARY VERSIONS OF AUTHORITIES ALREADY SCHEDULED FOR RECONSTRUCTION.**
2. **C9/C10 overlap rule** — **C10 construction entry** requires C0–C8 authorities stable; **C10 cross-platform completion/certification** requires the relevant C9 platform contracts proven. C9 may overlap C10 construction.

Plus: **`SupportScreen` — ownership undetermined → product disposition checkpoint. Not assigned to C9.**

## Corrections preserved (never rewritten)

- *"FD-9 Option C"* label — original Option C (separate institution shell) was **rejected**; decisions are named
- *"Cancel/Dismiss/Close/Discard are pure synonyms"* — **wrong**; four distinct families
- *"The backend has no speaker/audience model"* — **withdrawn**; vocabulary exists, mechanism does not
- *"C3/C4/C5 are not on the critical path to Live"* — **withdrawn**; too permissive

---

# C0 CLOSEOUT — FROZEN 2026-08-15

**C0 — Cross-Cutting Foundations: COMPLETE / FOUNDER APPROVED / LOCALLY CERTIFIED.**

## Certified authorities

| Authority | File | Status |
|---|---|---|
| Product Language | `lib/core/product/product_language.dart` | ✅ APPROVED / CERTIFIED |
| Product State Presentation | `lib/core/product/product_state.dart` · `product_state_view.dart` | ✅ APPROVED / CERTIFIED |
| Human Temporal Presentation | `lib/core/product/temporal.dart` | ✅ APPROVED / CERTIFIED |

Anti-drift enforcement · Representation canonical alignment · G5 ownership assignment · C0 consumer migration — all **APPROVED**.

## C0-1 · Final Product Language — FROZEN

**Nouns (13):** Person · Institution · Member · Participant · Thread · Space · Meeting · Room · Live · Message · Correspondence · Post · Announcement

**Stop/abandon/surface intents (4):** Cancel · Dismiss · Close · Discard

**Actions (25):** Retry · Refresh · Reload · Cancel · Dismiss · Close · Discard · Send · Publish · Reply · Join · Leave · Add member · Invite person · Manage invites · Invite · Accept · Decline · Follow · Manage · View · Open · Remove · Save · Edit

**`IdentityConcept`** preserves `PERSON ≠ INSTITUTION ≠ MEMBERSHIP ≠ ACTING CONTEXT ≠ PRESENCE`. Follow remains an action.

**Not to be introduced** without their own governed product decision and implementation requirement: **Connect · Works · generic Verified.**

## C0-2 · Membership actions — FROZEN

`addMember` · `invitePerson` · `manageInvites` · generic `invite` where legitimately broader. They remain semantically distinct. **No action label itself grants authority** — backend and domain authority decide availability.

## C0-3 · Person / Member — FROZEN

**PERSON = canonical human identity. MEMBER = contextual membership/relationship state.** A human is never canonically typed as "Member". The Representation reconciliation was applied to the actual source of the stale "Aura member" wording (`AURA_REPRESENTATION_MODULE_INVENTORY.md`), not to `PRODUCT_IDENTITY_CANON`, which contains no such wording.

## C0-4 · Correspondence — FROZEN

**One canonical product meaning: governed formal/deliberate communication.** The umbrella module meaning is **LEGACY / ARCHITECTURAL NAMING DRIFT**. **C7 owns the eventual path/module rename or convergence — the semantic decision is not reopened there.**

## C0-5 · Discovery framing — SUPERSEDED

The 2026-07-11 *"always trusted discovery / never directory"* directive is superseded by the later canons. Historical record preserved (struck through, not deleted). "Discovery" remains legitimate as a feature/module term where current canon supports it.

## C0-6 · Representation authority chain — FROZEN

```
IMPLEMENTATION / PRODUCT AUTHORITY   → owns product facts
FOUNDER-FROZEN DECISIONS             → authoritative later semantic rulings
REPRESENTATION                       → canonical reconciliation/presentation within governed scope
```

**Stale Representation wording does not override later founder-frozen product truth.** Later chapters **consume** `REPRESENTATION_CANONICAL_FRONTEND_ALIGNMENT.md` and `REPRESENTATION_FRONTEND_REDESIGN_INPUTS.md` rather than rediscovering this hierarchy.

## C0-7 · G5 ownership — APPROVED

**181/181 assigned, zero unassigned.** C1 42 · C2 21 · C3 44 · C4 26 · C5 16 · C7 26 · C8 3 · C9 3 · **C6 0**.

**R/J basis semantics preserved.** A `J` assignment is reasoned, **not immutable product truth** — the owning chapter re-verifies against actual reconstruction scope before migrating, and the register is updated if ownership moves.

## C0-8 · Meetings — PRESERVED

**Meetings holds zero G5 sites.** Its protected debt is **G3 (16)** and **G4 (14)**, belonging to controlled **C6** review. Certified Meetings is not modified for foundation debt reduction.

## C0-9 · Enforcement pattern — the FD-13 precedent

**11 zero-tolerance rules + 5 ratchets + 2 baseline-honesty gates.** Preserved properties: hard failure · architecture-aware checks · truthful baseline · narrow legitimate exceptions · **no warning-only structural governance.** This is the working precedent every later chapter follows.

## C0-10 · Date correction — ACCEPTED

The `2026-08-16` propagation was an authoring error, corrected across the Aura repositories where git evidence established the true dates. `docs/DATE_CORRECTION_2026-08-15.md` is the preserved reconciliation record. The Estonia visa-note dates are **outside C0**, recorded as **UNRESOLVED FACTUAL DATE — LEFT UNCHANGED PENDING SOURCE VERIFICATION**, and are not a product-architecture gap.

## Obligations owned by later chapters — NOT C0 backlog

| Chapter | Obligation |
|---|---|
| **C2** | verification labels |
| **C5** | official-designation vocabulary |
| **C7** | legacy Correspondence architectural rename/convergence |
| **C10** | Live plural/contextual language |
| **All** | measured G2/G3/G4/G5/G7 debt under ratchet |

---

# C1 CLOSEOUT — FROZEN 2026-08-15

**C1 — Acting Context & Capability Projection: COMPLETE / FOUNDER APPROVED / LOCALLY CERTIFIED.**

## C1-1 · Attribution at the consequential act — FROZEN

> **ACTING AUTHORITY BECOMES EXPLICIT WHEN A CONSEQUENTIAL ACTION REQUIRES ATTRIBUTION — NOT BECAUSE OF THE ROUTE THE PERSON NAVIGATED THROUGH.**

No global acting mode · no route-derived sender · one context → no manufactured choice · several → explicit choice before the act · institutional acting context always person-backed · unavailable actions absent rather than disabled · governance never a delegable capability.

## C1-2 · Surface-dependent personal alternative — FROZEN

> **WHETHER A PERSONAL ACTING ALTERNATIVE EXISTS IS A PROPERTY OF THE SURFACE / ACTION CONTEXT, NOT AN INTRINSIC PROPERTY OF THE CONSEQUENTIAL ACT.**

`resolve(act, offerPersonalAlternative: …)` is the governed contract. A single-purpose institutional composer must not manufacture an alternative it cannot perform.

> **NO CHOICE WITHOUT A REAL CONSEQUENCE.** A control that appears to change acting identity but cannot change the resulting action is prohibited.

## C1-3 · Switch identity — C0 Product Language extension

See `C0_PRODUCT_LANGUAGE_VOCABULARY.md` §6. One semantic action; contextual copy permitted; four competing phrasings gate-prohibited. **C0 extended through governed C1 discovery — not C0 remediation.**

## C1-4 · Presence — FROZEN

Presence is the person. It never inherits institutional identity from affiliation, navigation or membership.

## C1-5 · Backend authority — CONVERGED

`institutions.service.ts` delegates to `InstitutionAuthorityService` (it had been recomputing the effective-capability formula while the canonical service was already injected). Every membership now carries its own effective capabilities — previously only the person's arbitrarily-oldest one did.

## C1-6 · Fabricated capabilities — REMOVED

The six-token client injection was proven **unreachable dead code**: `institution-bootstrap` always creates an `InstitutionMember` row with `role: OWNER`. No backend correction was warranted; no alternate authority path was created.

## C1-7 · G5 ownership correction

38 of 42 C1 sites withdrawn on measured evidence → **PD-1 Platform Administration** (34) and **PD-2 Authentication & Account Entry** (3). C1 retains 4 on `R` basis. C0 ledger annotated; 181 sites still traceable.

## Accepted exceptions — none blocks closeout

R1 (25 files / 85 role-derived booleans, ratcheted) · R2 (3 files / 6 role-literal comparisons, classified) · `resolveActorContext` 3 consumers → C3/C7 · platform-admin flattening → PD-1 · further attribution consumers → owning chapters.

---

# AURA PUBLIC-FIRST CAUSAL DOCTRINE — ADOPTED 2026-08-15

**Canonical source, never restated:** `representation/inventory/AURA_PUBLIC_FIRST_CAUSAL_DOCTRINE.md` (founder-frozen, incorporated into `PRODUCT_IDENTITY_CANON.md` and `PUBLIC_REPRESENTATION_CANON.md`).

**Aura is public-first, not institution-first.** People and their need for better communication, discourse, continuity and accountable relationships are the originating force. Institutional identity is **accountability and responsibility infrastructure inside a public environment whose value already exists** — not Aura's acquisition premise.

**Prohibited reverse model:** institutions join, establish presence, and become the reason people discover and engage.

**This is a product-interpretation rule, not copy guidance**, and it is a **clarification, not a pivot** — Aura's reality has not changed; the agent interpretation has become more accurate. Older institution-first wording is not product truth merely because it predates the clarification.

## What it does not authorise

- It does **not** make Aura a consumer social network. Responsibility, attribution, credible discourse, continuity, governed authority and institutional accountability remain the differentiators.
- It does **not** weaken institution-specific surfaces. Institution governance, membership administration and official communication remain legitimately institution-focused.
- It does **not** invert commercialization into "sell institutions first so they bring the users."
- It does **not** override implementation truth. `Aura Identity -> Institutional Identity -> Discovery` remains a valid *technical* dependency; it is simply not the public-product causal story.

## Frozen surface classes

**GENERAL AURA SURFACE** (shared shell, landing, sign in/register, onboarding, general navigation, Explore, cross-product empty states, public CTAs) → must reflect public-first identity.
**PERSON / SOCIAL COMMUNICATION SURFACE** → begins from human communication, participation, continuity, relationships.
**INSTITUTION-SPECIFIC SURFACE** → legitimately institution-focused.

## Agent consumption

The pre-flight rule and running-product drift rule live in `aura/AGENTS.md` → *Aura Public-First Causal Doctrine*, with concise pointers in `aura_final/AGENTS.md` and `aura-backend/AGENTS.md`. One canonical source; references everywhere else.

## Chapter inheritance

Recorded per chapter in `docs/frontend-discovery/FINAL_FRONTEND_RECONSTRUCTION_ROADMAP.md`. **Roadmap ordering is unchanged by this doctrine.**

## Running-product contradictions found during propagation

Four institution-first framings were found on **general/public** surfaces and are recorded in `docs/frontend-discovery/PUBLIC_FIRST_RUNNING_PRODUCT_CONTRADICTIONS.md`.

**Founder ruling 2026-08-15: resolve now, do not defer into PD-2.** All four are **RESOLVED** under a narrow *public-first general-entry product copy reconciliation* — copy only, no auth redesign, no behaviour change. One canonical general expression was derived from the three canonical sources and adapted for length; C-4 needed no change (already gated to institution entry); the pubspec had a second stale occurrence in `msix_config`. Enforced by `test/doctrine/public_first_causal_gate_test.dart`, scoped to named general surfaces so institution-specific language stays legitimate.

**PD-2-ADJACENT PUBLIC-FIRST COPY DRIFT → RESOLVED. PD-2 STRUCTURAL DISPOSITION → STILL OPEN.**

---

# C2 FOUNDER ADJUDICATION — 2026-08-15 (chapter still open)

Full text: `docs/frontend-discovery/C2_FOLLOW_FORENSIC.md` -> *Founder Adjudication*.

| # | Ruling |
|---|---|
| **R1** | **Blocking (D2/D6) resolved inside C2.** `BLOCKING OUTRANKS FOLLOW / RELATIONSHIP / MESSAGING ELIGIBILITY.` Use the canonical existing blocking authority; do not create a second one. |
| **R2** | **FOLLOW = a governed relationship between an acting Person or Institution and another Person or Institution, subject to the target's applicable relationship and consent rules.** FROZEN. Public-first does not make Person->Person ontologically superior; do not manufacture symmetry. |
| **R3** | `InteractionFollow` is the stronger foundation but **its current schema is NOT a safe canonical replacement**. **Live Follow data must NOT be migrated into it.** Target: actor-aware authority + full consent lifecycle + blocking + downstream consequences. No semantics flattened to obtain one table. |
| **R4** | **FOLLOW != SUBSCRIBE — FROZEN.** Shared storage does not define ontology. C2 records semantics; **C4 owns the vocabulary.** C0 not reopened. |
| **R5** | **BLOCK > EXPLICIT CONSENT/REJECTION > ACTIVE FOLLOW.** REJECTED wins over an active follow; **provenance preserved, history not erased.** |
| **R6** | **No historical relationship may silently gain a new behavioural consequence because its row moved.** Consequence model certified before migration is authorized. |
| **R7** | Relationship **domain events** (REQUEST/APPROVAL/REJECTION) are C2; **attention delivery policy is C4**. Dormant templates are evidence of intent, not authority. |
| **R8** | No zombie `REQUESTED`; no accepted-and-discarded request `message`. Both classified from evidence. |
| **R9** | **Institution->Person must be classified, not inferred from API reach.** Institutional power over public relationships must not expand because the schema allows it. |
| **R10** | Blocking prerequisite first, then **complete §8-§12 discovery before destructive convergence.** |

**Not executed:** no migration, no convergence, no blocking implementation yet.

---

# FOUNDER RECONSTRUCTION DOCTRINE — FROZEN 2026-08-16

> **RECONSTRUCTION IS COMPLETE ONLY WHEN CANONICAL PRODUCT TRUTH IS ADOPTED BY THE RUNTIME/RELEASE CLIENT AND LEGACY IMPLEMENTATION HAS AN EXPLICIT RETIREMENT PATH.**
>
> **VISIBLE PRODUCT OUTCOME IS A REQUIRED CLOSEOUT DIMENSION.**

The objective is a reconstructed release client, not a governed legacy client. Legacy implementation has no preservation right merely because it exists, is embedded, or is hard to migrate. Compatibility layers are transitional only — each must carry a reason, canonical destination, retirement condition and path. Every chapter demonstrates: CANONICAL ARCHITECTURE → RUNTIME ADOPTION → VISIBLE PRODUCT OUTCOME → LEGACY RETIREMENT. Correctness constraints (product truth, data integrity, privacy/security, frozen doctrine, certified shared surfaces) are not relaxed.

Applied register: \`docs/frontend-discovery/C2_RECONSTRUCTION_DEBT_REGISTER.md\` (chapter-level completeness table + all compatibility retirements).

## D1 — FROZEN FEED SEMANTIC (founder-authorized)

An established Person→Person Follow makes eligible public participation from the followed Person **available to the member feed's existing visibility/ranking rules**. It does not guarantee delivery, bypass ranking/visibility/moderation/blocks, expose restricted content, or become Subscribe.

## C2 — Trust presentation doctrine (frozen by implementation, 2026-08-16)

- **Layered, never collapsed.** Person verification presents one mark per governed class (IDENTITY / INSTITUTION_AFFILIATION / ROLE_OR_CREDENTIAL); "Verified person" does not exist as a product concept. Absence renders nothing — absence is not suspicion.
- **Subject-explicit wording.** No user-facing mark may say bare "Verified" except the institution compact mark rendered adjacent to the institution name it describes, and even that carries "Verified institution" + meaning in semantics/tooltip. Labels are literal restatements of frozen governed classes — founder may refine ROLE_OR_CREDENTIAL public wording ("Role or credential verified" chosen as the non-inventive restatement).
- **Verification is not authority.** Official institutional speech is never presented from a verification fact (violation found and corrected in the realtime trust line). Verification is not endorsement, popularity, payment eligibility, or portability; ROLE_OR_CREDENTIAL presents as an Aura record, not a portable credential.
- **Revoked/expired first-class.** Public surfaces stop presenting positively by construction (active-class wire); admin/governance surfaces present full history with REVOKED/EXPIRED as states, never flattened to "not verified".
- **Unknown wire classes are dropped, never guessed at** — an older client stays quiet about a newer taxonomy entry rather than inventing wording.


## C2 — Monetization × Verification Decoupling (founder ruling, FROZEN 2026-08-16)

1. **Verification is not purchasable.**
2. **A commercial tier does not establish verification.** Payment never writes `Institution.isVerified`; downgrade never erases it. The only writer is the verification authority (`approveVerificationRequest`), which writes verification fields ONLY (status/verifiedAt/isVerified) and never touches plan/memberLimit/canSpeakOfficially.
3. **Trust is not a purchasable Aura status.**
4. **TRUSTED is rejected as a commercial product concept.** Retired from the offered taxonomy; legacy persisted rows resolve with operational capabilities and no trust semantics until the founder adjudicates their remapping.
5. **Verification authority and commercial entitlement are separate**, structurally (no `capabilities.isVerified` anywhere) and visually (the billing entitlements card no longer presents verification).
6. **ROLE_OR_CREDENTIAL is governed attestation, not a portable credential.**
7. **“Role attested” is the public wording** where the underlying fact concerns a role; the public wire carries class only (no subtype), so it is the narrowest non-overclaiming presentation for the whole class. Model limitation recorded: role vs credential-like facts are not publicly distinguishable today.
8. **Official institutional speech remains authority, not verification** (reaffirmed; the realtime violation was corrected in the trust reconstruction).

Interim, deliberately NOT frozen: the customer-facing name of the tier persisted as `InstitutionPlan.VERIFIED` (displayed as neutral “Institution plan” placeholder) — founder names it; then a staged enum/data migration retires the legacy value.


## C2 — Commercial Taxonomy Closeout (founder ruling, FROZEN 2026-08-16)

1. **Active commercial taxonomy = FREE + PRO.**
2. **The legacy VERIFIED middle tier is retired, not renamed.** No replacement middle tier; no capabilities invented to justify preserving it.
3. **TRUSTED remains permanently rejected.**
4. **No final Free/Pro entitlement boundary is decided now.**
5. **No new payment enforcement during release-client reconstruction** — none introduced, none strengthened.
6. **Existing behavior is preserved for now** — legacy VERIFIED rows keep their exact effective entitlements through a behavior-preserving legacy read until observed migration.
7. **Before payment enforcement:** inventory the COMPLETED Aura product and obtain founder adjudication of Free/Pro/credits/limits/pricing.
8. **Current implementation does not prejudge future commercialization policy** — today's configuration is implementation history, not pricing doctrine.

### FUTURE COMMERCIALIZATION GOVERNANCE MARKER (survives handoff)

**COMMERCIAL TAXONOMY: FREE + PRO — FROZEN.**
**FINAL COMMERCIAL ENTITLEMENT BOUNDARY: NOT YET FROZEN.**
**PAYMENT ENFORCEMENT: NOT TO BE ACTIVATED/EXPANDED DURING RELEASE-CLIENT RECONSTRUCTION.**
**REQUIRED BEFORE ENFORCEMENT: complete post-reconstruction product inventory + founder adjudication.**

A future agent must NOT infer that Free/Pro entitlements were decided during C2. Official-publishing gating, credit metering for AI/translation/realtime, and env member limits are all *current behavior preserved*, not adjudicated commercial policy.


## C3 — DR4 Final Architecture (reconciliation outcome, 2026-08-16; for founder freeze at C3 closure)

**MIRRORED ROUTE ≠ OBJECT-LOCAL INSTITUTION DEPTH ≠ PATH-MANUFACTURED CONTEXT.**

- A *mirrored route* duplicates a global capability under an acting-context path — demolished (2 existed; both retired to aliases, gate-pinned unbuildable).
- *Object-local institution depth* (`/institution/:id/…`, 34 routes) is the single canonical address space of institution-owned operations: the id is OBJECT SCOPE (whose members/domains/billing/…), immutable across renames, and carries no authority, no acting identity, and no shell truth. `/institutions/:slug` remains the public durable link contract — mutable human identity for sharing; internal id for rename-stable operational addresses.
- *Path-manufactured context* is structurally impossible: resolveActorContext deleted (0 mechanisms), shell classification is alias-aware destination-identity presentation pinned as never-authority, and the route-integrity gate + literal ratchet prevent regression.
- The institutional-inbox quartet (4 routes) carries the explicit-context contract and finalizes with C7.
- The Phase-1 phrasing "the :institutionId prefix is what dies" is SUPERSEDED as over-broad; the roadmap's per-route DR4 test is the governing wording and was applied per route.


## FOUNDER-OWNED ROADMAP GAPS (recorded 2026-08-16 at C4 opening; NOT chapter work)

**GAP 1 — Settings / Personal Controls.** The roadmap charters no Settings chapter; prior "C4 Settings" references were continuity shorthand, now formally reclassified. The broader personal Settings experience is UNCHARTERED. The **Availability Off user-facing control** remains: C2 doctrine frozen, runtime semantics canonical, control required, **implementation owner UNASSIGNED pending founder roadmap placement**. Availability doctrine is not reopened by this gap.

**GAP 2 — Long-Form Publishing / Articles.** Net-new first-class capability, NOT reconstruction debt. Frozen product distinction to preserve for later architecture: **Post = timely expression/discourse participation · Article = substantial authored thought/durable long-form publication · Announcement = governed institutional communication.** Full lifecycle eventually required (authoring → drafting → structuring/revision → preview → publication → reading → attribution → discussion → continuity). Person and Institution authorship both legitimate; institutional publication inherits canonical acting-identity/authority doctrine — route/context never manufactures authorship. NOT a Post extension, NOT part of C4, no chapter number assigned; awaiting deliberate founder dependency placement.


## FOUNDER-OBSERVED NAVIGATION CORRECTION (2026-08-16, authoritative founder rulings — amends the C3 five-primary freeze)

**GOVERNING TEST (frozen): PRIMARY NAVIGATION MUST REPRESENT A FUNDAMENTAL, RECURRING HUMAN INTENTION IN AURA.** Importance, route count, functionality, convenience, precedent, and symmetry do not qualify a destination; being technically an "action" does not disqualify one.

**AUTHENTICATED PRIMARIES — FOUR: HOME · MESSAGES · DISCOVER · CREATE** (see/continue · communicate · discover · create). Public primaries unchanged (Home · Discover).

- **ME — REMOVED from primary navigation (CLOSED).** Identity/profile/account depth, served persistently by the identity/avatar chrome (rail/drawer identity block → `/me`; header avatar account menu → Profile/Preferences/Settings/Sign out). `/me` and all personal depth (Personal Record, Participations, Connections, Devices, workspace/Admin jumps) are PRESERVED as destinations.
- **MEETINGS — REMOVED from primary navigation (CLOSED). MEETINGS ARE AN INSTITUTIONAL DOMAIN**: the institution owns the meeting lifecycle; a member's relationship is contextual — Institution workspace → Meetings (operate) · Book (initiate) · Attention/Invitation (respond) · Me → Participations (continuity) · deep links (direct access). There is deliberately NO bare `/meetings` destination and no manufactured personal meetings landing.
- **CREATE — RESTORED as primary.** "Create is a contextual action, not a destination" is SUPERSEDED: creation itself is a persistent primary human intention. **GLOBAL CREATE and CONTEXTUAL CREATE are complementary — one canonical lifecycle per creation kind, multiple legitimate entry points.** Create exposes human creation intentions only: current, truthful, capability-aware, acting-identity-aware (C1 inherited); never a backend-module menu, never disabled-action forests. Current composition: Write (post) · Conversation (canonical chooser) · Invitation · Institution (acquisition) · Announcement (authority-gated). Article creation NOT exposed until Long-Form Publishing exists. Institution meeting creation stays contextual-only in the workspace.
- **NO FIFTH DESTINATION** is invented or reserved. Attention may earn primary status only at C4's own founder checkpoint, on product merits — navigation count is not a product requirement.
- **INSTITUTION ONBOARDING = lifecycle-contextual acquisition action**, not permanent primary chrome: desktop header action only while the member has no institutional participation; accessible secondary entry afterwards (account menu + Create hub — multi-institution membership is a real supported case). One canonical journey: `/institutions/get-started` (`NavigationAuthority.institutionOnboardingRoute`).
- **DISCOVER = extensible discovery framework; immediate domains PEOPLE · INSTITUTIONS · SPACES · ARTICLES.** People = personalized human discovery with search always available (current truthful capability is search; personalization capability recorded, not faked). Institutions = public participation discovery; onboarding/workspace affordances removed; **verification is never relevance ranking** — one activity-ordered list, truthfully labeled "recent activity", verification as per-item mark + explicit filter. Spaces = subject discovery, single-registry taxonomy (10 subjects). Articles = canonically declared, **NOT rendered in the live experience** until truthful reading capability exists (founder visibility ruling — no dead "coming soon" tenancy).
- **Header semantic layers:** primaries (rail/bottom bar only) · identity/account (avatar) · attention (bell, until C4) · institution acquisition (lifecycle-gated) · Live (justified global) · **invite icon RETIRED** (dead parameter surface; invitation creation lives in Create + Me → Connections).

**GOVERNANCE LESSON (record, not app copy): ARCHITECTURE CAN PROPOSE COHERENCE. HUMAN USE VALIDATES MEANING. WHEN THEY CONFLICT, INVESTIGATE THE CONFLICT RATHER THAN PROTECTING THE ARCHITECTURE.** C3's five-primary model was locally certified and internally coherent — and still product-wrong in observed use (dead `/meetings` primary; orphaned Create hub; Me duplication). A locally certified architecture can be product-wrong; founder observation is evidence with amending authority.

**CERTIFICATION CORRECTION:** the C3 route-integrity gate tested registry self-consistency, not registry → router executability, which let a declared primary ship with no executable route. The gate now proves every authority-declared address (primaries, object builders, global actions) against the declared route table.


## AURA CONVERSATION SYSTEM + AURA INVITATION SYSTEM (founder-frozen 2026-08-16)

Canonical doctrine lives in ONE place per system (no duplication here):
**aura-backend/docs/2026-08-16-aura-conversation-system-canon.md** and
**aura-backend/docs/2026-08-16-aura-invitation-system-canon.md** — the
constitutional definitions (Conversation/Space/Publication/Attention/Delivery/
Identity/Authority never collapse), ten-year doctrine (capabilities attach,
never fork), origin ≠ governance (v1 = leave-only), direct-pair identity
survives naming, party legitimacy (AI = capability, not Party), institution
desk defaults, block/consent truth, address-verified invitation binding,
invitation/destination/attention/delivery boundaries, and the legacy
disposition rules. The clean-sheet implementation replaces the DirectThread
and Space-as-conversation stacks; MESSAGES is one conversation list; the
external claim journey is `/i/:token`.

**DISCOVER → PEOPLE (frozen doctrine):** personalized human discovery, with
search always available, using legitimate, explainable, privacy-safe signals.
The v1 signal weighting (`PEOPLE_DISCOVERY_WEIGHTS`) is a TUNABLE
IMPLEMENTATION HEURISTIC, not product doctrine. "Not interested" feedback is
a recorded future enhancement triggered by observed need — not debt.

**C7 AMENDMENT — FOUNDER-APPROVED AND FROZEN (2026-08-16):**
**C7 = INSTITUTIONAL CONVERSATION & DESK.** C7 consumes canonical
Conversation and foundational Invitation; owns the institution-side
Conversation/Desk experience and appropriate institutional
participation/membership-entry reconstruction. C7 does NOT recreate
Correspondence as a product, does NOT own Invitation, and there is ONE
canonical Conversation system.

**CREATE INTENT VOCABULARY (founder §5, frozen 2026-08-16):** MESSAGE ·
POST · ARTICLE (when real) · contextual ANNOUNCEMENT. "Message" is the
human intention; "Conversation" is the durable object underneath. No
"Write" umbrella, no Invitation/Institution/Article tenants until real.
Pinned by test/create/create_hub_domains_test.dart.

**CONVERSATION COMPLETION REGISTER (frozen obligation, 2026-08-16):** the
already-frozen capabilities — audio call · video call · screen sharing ·
media/attachments · intentional Live · message reporting/moderation —
remain REQUIRED contextual attachments of canonical Conversation, to be
built against the CONVERSATION realtime surface. No fake UI ships
meanwhile. Conversation is NOT final-certified until this register is
resolved; C4 progression does not erase it.

**INVITATION ABUSE POLICY (founder §3, 2026-08-16):** no numerical
issuance caps/cooldowns for this release; hooks + block/authority/safety
protections stand; numbers come from evidence later. NOT release-blocking
debt.

**C5 HARD GATE (frozen transition rule):** C5 remains CLOSED until C4 is
implemented, locally certified, pushed as authorized, deployed, observed
end-to-end on the LIVE site, live defects resolved, and founder declares C4
certified/closed. C4 LOCAL CERTIFICATION ≠ C5 AUTHORIZATION.

---

## 2026-08-18 — PD-1 and PD-2 adjudicated; Wave 1 Parts 1 and 2 executed

**PD-2 — RATIFIED SPLIT.** CH-02 owns STRUCTURE (session establishment, route classification,
redirect/destination reconstruction, verification gating). CH-10 owns ACCOUNT-ENTRY EXPERIENCE.
This recognised convergent evidence already recorded *independently* in both chapters'
`founderActions`; it was not a new decomposition. The seam is enumerated and gated at
`docs/governance/CH02_DESTINATION_RECONSTRUCTION_CONTRACT.md` +
`test/navigation/ch02_s3_destination_contract_test.dart`.

**PD-1 — OUT OF CURRENT RECONSTRUCTION SCOPE.** Platform Administration remains a legitimate shipped
Aura capability: **not deprecated, not demolished, not architecturally invalid, not removed.** Its
11 files / 52 foundation-debt sites are `FROZEN_BY_RULE`, preserved in the register, and
ownerless-by-reconstruction is recorded as **intentional, not neglected**. They are not counted as
ordinary executable debt. The C0 ratchet still holds the counts — exclusion from reconstruction is
not exclusion from measurement. **Scope exclusion is not a security bypass:** CH-02 S2 fail-closed
classification of `/admin` still applies, and is now asserted by gate rather than assumed.

**34 vs 35 G5 sites — closed mechanically, no founder escalation.** Site sets compared file by file:
same 11 files, every per-file count agrees. The disposition matrix's own rows sum to 35 while its
summary line says 34 — a summation error, not a different site population. 35 is operative; 34
retained as historical evidence.

**Session establishment (CH-02 S1).** The session hint is written at exactly one choke point,
`TokenStore.setSession`. The two original call sites in `auth_controller.dart` were removed — they
were not merely redundant, they wrote unconditionally and bypassed the guest-token exclusion.
Establishment on the login path is now fire-and-forget, matching the frozen "hint bookkeeping must
never delay or fail auth" design. Clearing deliberately remains multi-sited and is enumerated with
justifications, including the governed `session_bootstrap` exception where there is no session to
clear.

**Not closed by any of this:** F065 remains `IMPLEMENTED_NOT_LIVE_CERTIFIED` (the live refresh proof
is owed and needs PB-11 founder observation); F103/F104 remain `OPEN`; F116/F053 remain
`PARTIALLY_VALIDATED`; DEFECT-1 (realtime room goldens) is assigned to CH-04 and not waived. **No
chapter was closed.**
