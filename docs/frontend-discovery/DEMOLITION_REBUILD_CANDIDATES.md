# Demolition / Rebuild Candidates

Demolition is proposed only where continued refactoring would cost more and preserve more confusion than reconstruction. Each candidate states what must be **salvaged**, not only what is unfit.

---

## DR1 — Attention / inbox layer (8 surfaces)

> **FD-1 — ONE GOVERNED ATTENTION HUB + ACTIONABLE ATTENTION, FROZEN 2026-08-15.** Architectural permission to treat this layer as demolish + rebuild. **Do NOT implement demolition yet.**
>
> **Preserve:** valid domain behaviour · backend contracts · communication histories · notification delivery capability · valid read/unread data · invitation state · deep-link destinations · legitimate user preferences.
> **Do not preserve fragmentation** merely because these capabilities currently live on different screens.

**Why unfit.** Six live surfaces answer the same question with no rule for which; one (`conversations_screen`, 1,033 lines) is unreachable. Attention vocabulary is collapsed into a single "unread" concept across 19 files. There is no attention authority to refactor *toward* — `updates/module_attention` was the attempt and was never adopted.

**Salvage.** `updates/module_attention` and `notifications_controller` as the seed of the authority; server-side read/attention records; existing notification permission handling.

**Backend already available.** Notification delivery authority, delivery attempts, acknowledgement, attention records.

**Must survive.** Read/unread state; no user should return to a wall of false unreads.

**Must not survive.** Six competing hubs; locally cached unread with TTL; one aggregated badge meaning several different obligations.

**FD-12 (FROZEN):** `conversations_screen.dart` is **approved for retirement** within this territory — disposition authorised, deletion deferred to the implementation chapter with dependency verification, regression and route/build verification. `InstitutionCorrespondenceScreen` remains a **candidate** for contextual adjudication here, not a retirement decision. See `FD12_SURFACE_DISPOSITION_FROZEN.md`.

**New model (FD-1 frozen).** **One governed Attention Hub** projecting across domains through a small set of semantic views (Conversations · Activity · Invitations · Actions), with **domain-owned resolvable actions**, deep routing to the exact owning context, owning-domain clearing semantics, and noise reduction as a primary requirement.

*(This supersedes the earlier two-surface recommendation recorded above.)*

---

## DR2 — Institution live rooms surface

**Why unfit.** 1,078 lines that import neither realtime nor meetings, consume untyped JSON, and represent "realtime sessions belonging to an institution" — a concept the frozen backend replaced with a governed `InstitutionRoom` (participants, invitation lifecycle, ring policy).

**Salvage.** Card layout only.

**Must survive.** "See what is live now" for an institution.

**Must not survive.** The raw-map data path; the session-as-room concept.

---

## DR3 — Composer layer (6 composers) and attachment layer (11 implementations)

> **CANONICAL COMPOSITION SYSTEM — FROZEN 2026-08-15** (register FD-6). Architectural permission to treat this as demolish + rebuild / converge, **while salvaging proven product behaviour. Do NOT begin demolition.**
>
> **Preserve where valid:** backend contracts · supported content behaviour · attachment/media capabilities · drafts/data · proven validation · accessibility behaviour · legitimate context differences · working media rendering · user-visible capabilities that remain product-correct. See `CANONICAL_COMPOSITION_SYSTEM_FROZEN.md`.

**Why unfit.** Capability is distributed with no product logic (hashtags in 1 of 6; upload progress in 1 of 6). Eleven upload paths mean eleven interpretations of one canonical backend MIME policy. Refactoring toward a shared engine means touching all six anyway, at which point rebuild is cheaper and produces one contract instead of six reconciliations.

**Salvage.** `compose_screen`'s capability set is the most complete and should define the target feature list; `thread_composer`'s upload-state handling is the only real progress implementation; `composition/` domain models.

**Must survive.** Drafts; existing content and attachment rendering; per-surface presentation differences (a message bar must not become an editor).

**Must not survive.** Six content models; eleven upload implementations; voice implied by route; **per-composer paste/clipboard handling (25 files)**.

**Must be added.** A **Content Intake & Resolution** layer serving the canonical Composition System — and **drag-and-drop, which does not exist anywhere today (0 implementations)** despite Windows/MSIX being a governed release target. See `CONTENT_INTAKE_RESOLUTION_AUTHORITY_FROZEN.md`.

---

## DR4 — Navigation / IA (institution mirroring, module-oriented navigation, CTA/label drift)

> **FD-9 — CONTEXTUAL ACTING AUTHORITY, FROZEN 2026-08-15.** This candidate now has founder architectural permission to *recommend* demolition of mirrored institution routes **whose only justification is acting-context duplication**. It does **NOT** authorize implementation or deletion.
>
> Per-route test: **(A)** genuinely different institution-owned product semantic → **preserve**; **(B)** same capability under a different acting context → **demolish/converge**; ambiguous → **return for adjudication**. **Do not merge mechanically.**
>
> **TASK/DOMAIN-ORIENTED ADAPTIVE NAVIGATION + CANONICAL PRODUCT LANGUAGE — FROZEN 2026-08-15** widens this candidate to include **module-oriented navigation · redundant destinations · inconsistent CTA vocabulary · semantically drifting labels**. Classification: **DEMOLISH / CONVERGE / REBUILD AS WARRANTED**, preserving valid product behaviour and deep-link requirements.
>
> **Migration/refactor fear is explicitly removed as a design constraint** — structural drift must not be preserved to avoid a route migration. Still **planning permission only**. See `NAVIGATION_IA_PRODUCT_LANGUAGE_FROZEN.md`.

**Why unfit.** 40 mirrored routes make context a property of the address space rather than of the actor, contradicting frozen backend doctrine. 27 redirects are corrective navigation. Every new destination must be built twice.

**Salvage.** Shells; `floating_call_widget` continuity; deep-link handling; existing redirects as a compatibility layer during transition.

**Must survive.** All existing deep links must continue to resolve.

**Must not survive.** Route-carried acting context; literal route strings scattered across features; a permanent global Personal/Institution toggle as the organising principle (explicitly rejected by FD-9).

**Must be added.** A first-class Acting Context authority — person as default actor, institutional context entered deliberately and remaining attributable, eligibility resolved by backend.

---

## DR5 — Public / member profile experience (3 implementations)

> **CANONICAL IDENTITY PRESENTATION + CONTEXTUAL PROJECTION — FROZEN 2026-08-15** (register FD-11). Architectural permission to reconstruct. **Do NOT begin demolition.**

**Why unfit.** Three profile implementations (`profile/`, `me/`, `institutions/profile/`) represent the same human being differently; `edit_profile_screen` (1,948) and `institution_edit_profile_screen` (2,153) are ~4,100 lines of parallel implementation. "Presence" carries six unrelated meanings, one of them a screen class declared inside `me_screen.dart`. `'Verified'` is shown as a single label over three independent backend verification layers.

**Salvage.** Canonical identity data · relationships · public content · institution relationships · legitimate verification data · privacy controls · follow/relationship state · backend authority/contracts · deep links where still conceptually correct.

**Must survive.** The three verification layers as independently expressible truth; privacy controls; relationship state.

**Must not survive.** Three profile architectures · a "Member" identity type · institution-as-user modelling · boolean verification flattening · locally inferred presence · route-specific profile implementations · the current visual weight.

**New model.** One canonical identity presentation with contextual projection — **IDENTITY FIRST · CONTEXT SECOND · ACTIONS THIRD · METADATA ON DEMAND**, smallest useful action set, institution as a first-class identity. Cosmetic cleanup is explicitly **not** the solution. See `CANONICAL_IDENTITY_PRESENTATION_FROZEN.md`.

---

## NOT demolition candidates (explicitly)

| Area | Why it survives |
|---|---|
| **Realtime transport** (`realtime_controller`, media service, event parser, reconciliation) | Sound, shared, and the reconnect/orphan recovery is the best work in the client |
| **Meetings lifecycle** | Protected certified surface. Converge its *presentation*, never its lifecycle |
| **Visual design system** | Sound; the failure is adoption, not design |
| **Session continuity** (`floating_call_widget`, `incoming_live_overlay`) | Already matches where the market converged |
| **Feed/content rendering** | Large but coherent; refactor candidate at most |

---

## Cross-cutting obligation — NOT a demolition candidate

**Human Temporal Presentation** is a **cross-product refactor/consolidation**, not a demolish+rebuild. The shared helpers (`relative_time.dart`, `local_timezone.dart`) are sound; the failure is adoption (9 and 3 consumers against 52 and 35 hand-rolled call sites) and **semantic collapse onto `createdAt`**. Consolidate and enforce; do not rebuild. See `HUMAN_TEMPORAL_PRESENTATION_AUTHORITY_FROZEN.md`.

## FD-10 architectural consequences (FROZEN)

- **Correspondence** survives as a distinct governed communication form — **its current duplicate messaging architecture is explicitly NOT protected.** Audit `correspondence`, `direct_threads`, the three thread screens, repositories and routes against the frozen distinction; converge/rebuild mechanics while preserving semantics.
- **Works** must not survive as a second canonical publication model competing with **Post**. If they are the same concept, **retire/converge the duplicate Works model**.

See `FD10_TERMINOLOGY_FROZEN.md`.

## Live staging constraint (FD-5, FROZEN)

**Do NOT retrofit Live into any of the three existing live-room screens.** Realtime presentation/authority convergence comes **first**; Live is built on that foundation. Building a fourth disconnected live surface would repeat the exact failure this discovery documents. See `FD5_LIVE_THREAD_SPACE_FROZEN.md`.

## Enforcement obligation (FD-13, FROZEN)

Every demolition/rebuild above is incomplete until its replacement authority also carries **migrated consumers**, **minimum hard-failing anti-drift gates**, and **regression/certification evidence**. Rebuilding a surface without its gate reproduces the exact condition this discovery documented: a shared authority that exists while competing patterns keep accumulating. See `FD13_ENFORCEMENT_MECHANISMS_FROZEN.md`.

## Sequencing constraint

DR1–DR5 must not run in parallel. **Authorities before surfaces:** identity/acting context and capability projection first, because attention, composition and IA all depend on knowing *who is acting* and *what they may do*. Rebuilding surfaces first would rebuild them twice.
