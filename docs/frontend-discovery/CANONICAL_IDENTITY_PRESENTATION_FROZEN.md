# CANONICAL IDENTITY PRESENTATION + CONTEXTUAL PROJECTION

# STATUS: FROZEN — FOUNDER APPROVED 2026-08-15

**Identified by NAME.** Register identifier: **FD-11 (Profile hierarchy)** — the existing canonical entry this decision resolves. No option lettering is used.

## Register mapping

| Register entry | Effect |
|---|---|
| **FD-11 — Profile hierarchy** | ✅ **RESOLVED** — and substantially widened: the freeze covers the whole identity/presence/relationship model, not only visual hierarchy |
| **FD-10 — Terminology** | **CONSTRAINED, still OPEN.** Verification must not be flattened to a boolean (§12) and the five identity concepts are frozen as distinct (§2) — but exact copy, CTA vocabulary and presence state names are **not** frozen |
| **P1 / P2 / P3** (Profile-Presence-Identity audit) | all three findings answered |

---

## 1. Core decision

> **CANONICAL IDENTITY PRESENTATION + CONTEXTUAL PROJECTION + CAPABILITY-ADAPTIVE EXPERIENCE.**

- Do **not** preserve separate personal/member/institution profile architectures merely because the frontend accumulated them.
- Do **not** solve this by collapsing Person, Institution, Membership, Acting Context and Presence into one universal Profile object.

They are semantically distinct. The experience makes them **coherent without destroying the distinctions**.

---

## 2. Canonical conceptual model *(frozen)*

| Concept | Meaning |
|---|---|
| **PERSON** | a person's identity |
| **INSTITUTION** | an institution's identity |
| **MEMBERSHIP / RELATIONSHIP** | the relationship between a person and an institution/context |
| **ACTING CONTEXT** | who the authenticated person is currently authorised to represent |
| **PRESENCE** | an appropriate projection of current availability/activity |

> **PERSON ≠ INSTITUTION ≠ MEMBERSHIP ≠ ACTING CONTEXT ≠ PRESENCE** — yet all participate in **one coherent identity experience**.

*(Directly answers Finding P1: "presence" currently carries six unrelated meanings.)*

---

## 3. Member is not a third identity type

**Do NOT create a parallel identity architecture called "Member."**

```
MEMBER = PERSON + RELATIONSHIP TO INSTITUTION
```

Membership may contribute contextual information — institutional relationship · relevant title · participation · legitimate contextual capability — but it **does not replace the underlying Person identity**.

This prevents parallel *Person Profile* / *Member Profile* / *Institution Member Profile* architectures representing the same human being differently.

---

## 4. Person profile experience

Lightweight, useful, modern, immediately understandable. The current visually heavy public/member profile is **not** preserved merely because it works.

> **IDENTITY FIRST. CONTEXT SECOND. ACTIONS THIRD. METADATA ON DEMAND.**

*(Answers Finding P3.)*

---

## 5. Contextual person projection

A Person remains the same Person; context changes what is *useful*.

| Encountered | Projects |
|---|---|
| Generally | basic identity · legitimate relationship/context · appropriate actions |
| In an institution | Person identity · relevant institutional relationship · institution-context actions |
| In a Space | Person identity · Space relationship/participation · contextual actions |
| In a Meeting / Room / future Live | Person identity · participation state · legitimate participant actions |

> **Do not create separate profile products per context. Project relevant context onto canonical identity.**

---

## 6. Action model

Capability-adaptive. Examples only — Message · Follow · Invite · Connect · View relevant activity · Manage — resolved by product context · relationship · acting context · backend authority · current state.

> **Do NOT display every theoretically possible action. Expose the smallest useful current action set.** CTA terminology is **not** frozen here (FD-10 remains open).

---

## 7. Institution identity experience

An Institution is a **first-class identity** — *not* "a user account with a company avatar."

```
INSTITUTION IDENTITY → PURPOSE / RELEVANT PUBLIC PRESENCE
  → PUBLIC COMMUNICATION / ACTIVITY → RELEVANT RELATIONSHIPS → APPROPRIATE ACTIONS
```

Authorised operators (FD-9) may receive contextual management capability. **Ordinary visitors/members must not see administrative machinery merely because the institution has operators.**

---

## 8. Institution management

Per frozen Capability-Adaptive Experience: expose management **progressively and contextually**.

> **Do NOT turn the normal institution identity experience into a permanent administration dashboard.**

Ordinary institution experience **+** authorised contextual Manage capability. Deeper administration/settings surfaces remain appropriate for genuinely administrative work.

---

## 9. Presence — separate from identity

Presence must not become another Profile architecture. It is a **contextual projection**.

Illustrative concepts only (**not frozen**): Available · Busy · In a meeting · In a room · Offline. Which states carry legitimate user value is determined later.

---

## 10. Technical connectivity ≠ social presence *(frozen)*

> **TECHNICAL CONNECTIVITY IS NOT AUTOMATICALLY SOCIAL PRESENCE.**

An active socket · active device · recent session · realtime connectivity · device registration · `lastSeen` · transport state does **NOT** authorise the frontend to expose that information socially.

> **Do not turn infrastructure telemetry into a surveillance-like presence experience.**

---

## 11. Presence privacy / context

Presence is exposed only where product context makes it useful · policy permits · privacy expectations permit · the underlying signal is semantically meaningful.

To investigate later: visibility · granularity · stale-state handling · contextual presence · whether users/institutions need presence controls.

> **Do not invent policy now. Unresolved presence/privacy decisions return to founder adjudication.**

---

## 12. Verification presentation

The frontend consumes layered backend verification **without**: flattening it into one boolean · exposing backend enums directly · producing badge clutter · inventing verification meaning locally.

Verification appears when it contributes meaningful trust/context.

> **Identity presentation must not revolve around collecting badges.** Exact presentation remains a later design decision.

*(Answers the highest-severity row of the Representation drift register: `'Verified'` currently shown as one label over three independent backend layers.)*

---

## 13–17. Compatibility with frozen decisions

| Frozen decision | Requirement |
|---|---|
| **FD-9 Acting Context** | Person identity is **not** acting context; institution profile/identity is **not** acting context either. **Do not use profile switching as a substitute for governed acting authority.** |
| **Capability-Adaptive Experience** | The same identity experience adapts to legitimate capability. An operator viewing a person in institution context sees the **same canonical Person** plus authorised management — **roles change capability, not the identity product**. |
| **FD-1 Attention** | Attention referencing people/institutions routes into canonical identity/context. **No "notification profiles."** |
| **FD-3 Realtime** | Realtime participation consumes canonical identity projection. **No separate identity representation for realtime** — participant state is contextual state attached to canonical identity. |
| **FD-6 Composition** | Mentions, recipients and participant selection consume canonical Person/Institution projections. No composer invents avatar treatment · identity labels · verification treatment · institutional relationship rendering · acting identity rendering. |

---

## 18. People selection consequence

The People & Participation selection direction (FD-3) consumes this same identity architecture. Selection provides enough context to distinguish people **without becoming visually heavy**: identity · relevant institutional relationship · participation state · verification where genuinely useful · eligibility.

> **Do not expose unrelated metadata merely because it exists.**

---

## 19. Public / member profile reconstruction

Classified **DEMOLISH + REBUILD / RECONSTRUCT, while preserving valid data and proven product behaviour.**

- Do **not** preserve the current visual architecture.
- Do **not** treat cosmetic cleanup as the primary solution.

**Preserve where valid:** canonical identity data · relationships · public content · institution relationships · legitimate verification data · privacy controls · follow/relationship state · existing backend authority/contracts · deep links where still conceptually correct.

---

## 20–21. Experience standard

Modern · simplified · visually restrained · easy to adopt · context-aware · capability-adaptive · trustworthy · consistent · useful without being information-dense.

> The goal is **not** *"show everything Aura knows about this person."*
> The goal is *"show who this is, why they matter here, and what I can appropriately do."*

Later research: person/organisation profiles · member and contextual identity · presence · relationship and verification presentation · profile actions · compact identity cards · people pickers · participant identity · progressive disclosure. **Do not copy another product.**

---

## 22. Frontend authority direction

Investigate canonical identity/presence authorities or primitives so identity presentation does not drift per surface:

**IDENTITY PROJECTION** (canonical Person/Institution) · **RELATIONSHIP PROJECTION** · **PRESENCE PROJECTION** (permitted human-facing presence) · **VERIFICATION PROJECTION** (layered trust) · **ACTION PROJECTION** (backend-authorised contextual actions).

> Implementation is not frozen. **Do not create architecture merely to satisfy terminology.**

---

## 23. Drift / enforcement expectation

Prevent re-emergence of: independent Person/Member profile models · local role-derived identity · duplicated avatar/name logic · boolean verification flattening · local presence inference · institution-as-user modelling · route-specific profile implementations.

Investigate architecture tests / source gates where useful.

---

## 24. Representation repository

When implementation reaches copy/identity presentation, inspect Representation for canonical identity terminology and presentation authority.

> **Do NOT edit Representation during adjudication.** Release Client copy must not independently redefine Person, Institution, Membership, Acting Context, verification or presence semantics. **Any Representation conflict discovered later must be brought forward, never silently reconciled.**

---

## 25. Frozen doctrine

> **CANONICAL IDENTITY PRESENTATION + CONTEXTUAL PROJECTION.**
> **PERSON ≠ INSTITUTION ≠ MEMBERSHIP ≠ ACTING CONTEXT ≠ PRESENCE.**
> **A MEMBER IS A PERSON WITH A RELATIONSHIP TO AN INSTITUTION — NOT A THIRD IDENTITY TYPE.**
> **IDENTITY FIRST. CONTEXT SECOND. ACTIONS THIRD. METADATA ON DEMAND.**
> **INSTITUTION IS A FIRST-CLASS IDENTITY, NOT A COMPANY-SHAPED USER.**
> **PRESENCE IS A CONTEXTUAL PROJECTION, NOT IDENTITY.**
> **TECHNICAL CONNECTIVITY DOES NOT AUTOMATICALLY BECOME SOCIAL PRESENCE.**
> **VERIFICATION MUST PRESERVE LAYERED BACKEND MEANING WITHOUT BADGE CLUTTER OR ENUM LEAKAGE.**
> **ROLES CHANGE AVAILABLE CAPABILITY, NOT THE IDENTITY PRODUCT.**
> **PUBLIC/MEMBER PROFILE EXPERIENCE IS A DEMOLISH + REBUILD CANDIDATE.**
> **SIMPLIFY PRESENTATION WITHOUT FLATTENING SEMANTIC TRUTH.**

---

## 26. Anti-drift guard

| ❌ Prohibited reading | Why it violates this freeze |
|---|---|
| "One universal Profile object for people and institutions" | §1, §2 |
| "Build a Member profile type" | §3 |
| "Institution is just a user account with a company avatar" | §7 |
| "Show everything we know about this person" | §4, §21 |
| "`isVerified: true` is enough" | §12 — flattens three independent backend layers |
| "Expose the backend verification enum in the UI" | §12 |
| "They have an active socket, so show them as online" | §10 |
| "Derive presence from lastSeen locally" | §10, §23 |
| "Let the user switch profiles to act as the institution" | §13 — that is acting authority, not profile switching |
| "Realtime needs its own participant identity model" | §16 |
| "Each composer styles mentions its own way" | §17 |
| "Operators get an admin profile view" | §8, §14 — roles change capability, not the product |
| "Cosmetic cleanup of the profile screens solves this" | §19 |
| "This froze presence state names / verification UI / CTA copy" | §6, §9, §12 — those remain open (FD-10) |
| "Reconcile the Representation wording while we are here" | §24 — bring it forward instead |
