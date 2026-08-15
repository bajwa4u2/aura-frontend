# Navigation / Information Architecture Audit

> ✅ **RESOLVED — TASK/DOMAIN-ORIENTED ADAPTIVE NAVIGATION + CONTEXTUAL DEPTH + CANONICAL PRODUCT LANGUAGE AUTHORITY, FROZEN 2026-08-15.**
>
> **Users navigate to objects and intentions, not backend modules.** One coherent IA · few stable primary destinations · objects own their contextual depth · capability-adaptive actions · deep links preserve exact context · acting context never duplicates the IA. The findings below (N1–N6) are now reconstruction territory rather than open questions.
>
> **⚠ Exact primary destinations are NOT frozen** — they are derived later. **No generic Calls destination** (FD-3), **no global composer destination** (FD-6), **no notification-specific navigation** (FD-1). See `NAVIGATION_IA_PRODUCT_LANGUAGE_FROZEN.md`.

> ✅ **CAPABILITY-ADAPTIVE EXPERIENCE — FROZEN 2026-08-15** constrains the IA rebuild: **management should be object-local where practical** (Space → Manage Space; Room → manage participation), with deeper administrative surfaces reserved for genuinely administrative work — governance, roles, institution-wide policy, configuration, security. **Do not create dashboard detours for simple contextual administration**, and do not route an authorised admin into a separate dense administrative application. See `CAPABILITY_ADAPTIVE_EXPERIENCE_FROZEN.md`.
>
> ✅ **CANONICAL IDENTITY PRESENTATION — FROZEN 2026-08-15** additionally constrains identity destinations: **no separate profile products per context** (general / institution / Space / Meeting / Room / Live all project onto one canonical identity), and **profile switching must never substitute for governed acting authority** (FD-9). See `CANONICAL_IDENTITY_PRESENTATION_FROZEN.md`.

## FINDING N1 — 171 routes, 27 redirects, 4 shells, one 2,100-line router

**PRODUCT CONSEQUENCE.** Nobody can hold the destination map in mind. 27 redirects mean a meaningful share of navigation is *corrective* rather than intentional — routes that exist to repair other routes.

**CLASSIFICATION.** DEMOLISH + REBUILD the IA (not necessarily the screens).

---

## FINDING N2 — Institution context is a mirrored route tree, not a context

**Evidence.** 40 routes prefixed `/institution/:institutionId/` duplicate personal-context destinations: `u/:handle`, `institutions/:slug`, `direct/:threadId`, `posts/:postId`, `posts/:postId/edit`, `activity`, `messages`, `messages/direct`, `correspondence`, `spaces`, `announcements`.

**PRODUCT CONSEQUENCE.** Every new destination must be built twice or it silently works in only one context. "Acting as an institution" is expressed as *a different URL space* rather than *a different actor identity*, so context is carried by the path instead of by an identity authority.

**ROOT CAUSE.** Institution acting-context was added after the personal tree existed; mirroring was the cheapest way to add it.

**CLASSIFICATION.** DEMOLISH + REBUILD — replace mirroring with an explicit acting-identity authority plus one destination tree.

**OPTIONS.**
- **A. One route tree + explicit acting identity (person or institution) held by a client Identity Authority.**
- B. Keep mirrored routes but generate them from a single definition.
- C. Separate institution app shell entirely.

**RECOMMENDATION.** A. It matches the frozen backend, which treats institution action as capability held by an actor, not as a separate address space. A prior chapter fixed a production router bug rooted in exactly this confusion, and froze the doctrine that **institutionId-in-path ≠ institution-actor identity** — a doctrine these 40 routes structurally contradict.

**MIGRATION CONSEQUENCE.** Existing deep links and any shared/bookmarked institution URLs must continue to resolve; redirects would need to survive the transition.

**FOUNDER DECISION.** ✅ **RESOLVED — FD-9 CONTEXTUAL ACTING AUTHORITY, FROZEN 2026-08-15.**

*(Note: the founder-approved direction is identified by name. It is **not** option C of the list above — that option, "separate institution shell", was **rejected**.)*

One Release Client, one coherent navigation architecture, first-class contextual acting authority. Navigation expresses **what the user is trying to do**, not which historical route tree they are inside. Acting context is state/authority and must not duplicate the information architecture.

Each of the ~40 mirrored routes is now subject to an explicit test:

| Test | Outcome |
|---|---|
| **A.** genuinely a different institution-owned **product semantic** | separation may remain |
| **B.** same capability under a different **acting context** | should generally not survive as separate architecture |

**Nothing is merged mechanically**, and this freeze grants permission to *recommend* demolition — **not** to implement it. See `FD9_ACTING_CONTEXT_FROZEN.md`.

---

## FINDING N3 — Four messaging entry points inside institution context

`/institution/:id/messages`, `/institution/:id/messages/direct`, `/institution/:id/correspondence`, `/institution/:id/direct/:threadId` — plus the personal equivalents. Consistent with the eight attention surfaces documented in `INBOX_ATTENTION_AUDIT.md`.

**CLASSIFICATION.** MERGE.

**Governed by FD-1 (FROZEN).** One governed Attention architecture projects according to acting context — **`/inbox` + `/institution/inbox` must NOT be created as mirrored product architectures** merely because institutional attention exists. Institutional attention may carry different semantics; that does not justify another Inbox product.

---

## FINDING N4 — Live destinations are fragmented

`/meetings/:id/room`, `/meetings/:id/live`, `/meetings/:id/waiting`, `/meetings/:id/prep`, `/realtime`, `/realtime/:sessionId`, `/institution/:id/live-rooms` — seven live-adjacent destinations across three implementations.

**CLASSIFICATION.** MERGE destinations; **preserve** Meetings lifecycle stages — `prep` and `waiting` are real product states, not drift.

---

## FINDING N5 — Session continuity across navigation is already solved

`floating_call_widget` + `thread_call_lifecycle_host` + `incoming_live_overlay` keep an active session alive across navigation.

**CLASSIFICATION.** **PRESERVE.** This is the pattern modern products converge on, and Aura already has it working. Any IA rebuild must carry it forward unchanged.

---

## FINDING N6 — Route strings are literals scattered across the client

Navigation is performed with `context.go('/literal/path')` throughout, rather than through named canonical actions. Combined with 171 routes and 27 redirects, this makes any IA change a repo-wide find-and-replace with no compile-time safety.

**CLASSIFICATION.** REFACTOR — introduce canonical navigation actions (see `FRONTEND_AUTHORITY_CONSUMER_MATRIX.md`).
