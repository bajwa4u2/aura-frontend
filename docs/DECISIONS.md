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
