# C3 — DR4 ARCHITECTURAL RECONCILIATION

**Date:** 2026-08-16 · Bounded proof of the final route architecture. Verdict up front: **the retained routes are canonical object-local institution depth, not a preserved second universe — with the earlier "the prefix dies" phrasing formally superseded as over-broad.** One defensive hardening was added (alias-aware shell classification); no route architecture changed because the proof held.

## 1. The exact DR4 canonical wording (recovered verbatim)

`FINAL_FRONTEND_RECONSTRUCTION_ROADMAP.md`, CHAPTER C3, DEMOLISH/REBUILD:

> **DR4** — **40 mirrored `/institution/:institutionId/…` routes** (**per-route test: genuinely different institution-owned semantic → preserve; same capability under different acting context → converge**) · module-oriented destinations · redundant destinations · 27 corrective redirects · literal route strings scattered across features.

Exit condition: *"One destination tree; **acting context carried by identity, not path**; every surface has an auditable reachability/ownership path."*

The canon therefore distinguishes three things and never equates them: a **mirrored route** (same capability duplicated under an acting-context path), **institution-owned contextual depth** (genuinely different institution-owned semantic — *explicitly preserved by the canon*), and the **prefix as acting-context manufacture** (what the exit condition kills). The demolition target was always the *mirroring and the context-manufacture*, not institution-owned addresses.

## 2. Why the two statements differed — and which was wrong

**Phase-1 checkpoint said** "what must die is the `:institutionId` path-context prefix, not the destinations." **Closeout said** the prefix survives as the canonical operational address space. These were not two architectures — the checkpoint sentence was **over-broad shorthand**: at that time the prefix genuinely did three jobs at once (address + shell selector + acting-context source via `resolveActorContext`), and the sentence named the bundle by its address. Implementation then separated the bundle: the acting-context job **died** (resolver deleted, 0 mechanisms), the mirror job **died** (2 duplicates → aliases), and the remaining job — *identifying which institution's operation a destination addresses* — is object scope, which the canon explicitly preserves. The roadmap's per-route test, applied per route, produces exactly this result. **The over-broad phrasing is superseded; the canon's own wording was never violated.**

## 3. The 35-route proof table

Central test per route: *if `/institution/:id/` were removed, what product truth would be lost?* Legend: **OLD** = canonical object-local depth. Global-equivalent column answers §4.4/4.5. All routes: shell = InstitutionShell (presentation), authority = backend effective capability / governance role (never the route), acting context = none (per-act), deep links = unchanged.

| Route (`/institution/:id/…`) | Object / intention | Truth lost without the id | Global equivalent? | Verdict |
|---|---|---|---|---|
| `dashboard` | this institution's workspace home | which institution's workspace | none (member home ≠ institution home) | **OLD** |
| `members` | this institution's membership roster | whose members | none | **OLD** (lifecycle internals C7) |
| `join-requests` | pending joins **to this institution** | whose queue | none | **OLD** (C7 internals) |
| `invites` | this institution's outgoing invites | whose invites | none | **OLD** (C7 internals) |
| `domains` | this institution's domains | whose domains | none | **OLD** |
| `billing` | this institution's plan/billing | whose billing | none | **OLD** |
| `availability` | this institution's booking pages | whose availability | none | **OLD** |
| `profile` / `edit-profile` | this institution's identity mgmt | whose branding | `/institutions/:slug` is the PUBLIC object, not its editor | **OLD** (MANAGE_BRANDING) |
| `request-verification` | verification request for this institution | whose verification | none | **OLD** |
| `units` | this institution's sub-entities mgmt | whose units | `/institutions/:slug/units` is the public roster — different intent (manage vs view) | **OLD** |
| `announcements` / `announcements/new` | this institution's announcements mgmt | whose announcements | `/announcements` is the public feed — publish/manage vs read | **OLD** (Announcements certified) |
| `posts/new` / `posts/:postId` / `posts/:postId/edit` | this institution's posts (authoring/detail/edit — `InstitutionPostDetailScreen`, distinct object) | whose posts | `/posts/:id` is the public record — different object model | **OLD** (Posts certified) |
| `explore` | explore **this institution's** content | scope | global explore explores Aura — different data scope | **OLD** |
| `activity` | this institution's activity | scope | personal activity ≠ institution activity | **OLD** |
| `spaces` / `spaces/:spaceId` / `spaces/:spaceId/archived-threads` | this institution's spaces (list scoped; detail passes explicit `institutionId` param) | whose spaces / which context | `/spaces` is global discovery; Space object shared, context explicit-by-param | **OLD** (C7 internals) |
| `live-rooms` | this institution's rooms | whose rooms | none | **OLD** (internals C8/DR2) |
| `public-engagement` (+`/participation`, `/:recordId`) | civic records routed to this institution | whose engagement queue | none | **OLD** |
| `correspondence` | this institution's correspondence surface | whose | personal correspondence hub is a different subject | **OLD** (C7 internals) |
| `meetings` ×8 (`new`, `:meetingId`, `prep`, `room`, `waiting`, `live`, `summary`) | this institution's meetings | whose meetings | `/meetings` = personal meetings — different scope | **OLD** (Meetings protected) |
| `messages`, `messages/direct`, `messages/direct/archived`, `direct/:threadId` | this institution's inbox (explicit `institutionContextId` from builders) | whose inbox | personal Messages — different subject | **C7 HOLD** (sender experience; route disposition finalizes with C7) |

**Counts (F):** canonical object-local depth **34** · C7 holds **4** (the inbox quartet — the closeout's "3" undercounted by one: `messages/direct/archived`) · true mirrors **0 remaining** (2 already retired to aliases) · founder-decision-required **0**.

*(That corrects the closeout's 35/3 split to 34/4 — same routes, one reclassified from depth to C7-hold for precision: `messages/direct` and its archived variant both carry the explicit-context contract.)*

## 4. One-destination-tree proof (§6)

The model, stated once: **DESTINATION TREE** = one product IA (five primaries + object depth) — owned by `NavigationAuthority`. **ROUTE NAMESPACE** = addresses, which may nest object-scoped operations (`/institution/:id/…` is an address family, exactly like `/meetings/:id/room` or `/me/correspondence/:spaceId/thread/:threadId` — nobody calls those "second universes"). **SHELL** = presentation of destination context. **ACTING IDENTITY** = per consequential act. **AUTHORITY** = backend effective capability/governance. Proof the depth is not a second tree: it contains **no duplicate of any global destination** (the two duplicates are retired and gate-pinned unbuildable), it is reached *from within* the one tree (institution object → its operations), its selected-state and classification resolve through the same single authority, and its 4 remaining non-depth routes are contractually assigned to C7.

## 5. Shell-selection proof (§7)

Input: `NavigationAuthority.contextOf(path, isAuthed)` — now **alias-aware** (a retired-mirror address classifies as its canonical target; new pin proves `/institution/i1/u/amina` classifies as member chrome, defense-in-depth beneath the router redirect that resolves it first). Matching the canonical institution-depth address family identifies *which destinations these are* — post-DR4 there is nothing else at those addresses to confuse. Traced consumers of shell state: **zero** interpret InstitutionShell presence as acting-for-institution (grep: 2 remaining references are comments). Shell selection reads token/guest/session + classification; it writes no authority, capability, or actor state. Pinned by the standing "shell context is PRESENTATION, never authority" test group.

## 6. Acting-context proof (§8)

Re-run in full: `resolveActorContext`/`_pathIsInstitutionShell` — **0 live references** (comments only). `pathParameters['institutionId']` consumed **only inside route builders** as object scope / explicit context params. Remaining `GoRouterState…uri.path` readers: return-path continuity (`currentPath` for back-navigation), the update-gate suppressing prompts on admin routes (presentation nicety), shell/nav selection — none decide an actor. Follow = explicit Follow-as (pinned) · correspondence = explicit `institutionContextId` + C7 contract · posts/announcements = capability-gated composers with C1 attribution · Live entry = `ConsequentialAct.startLive` projection · Meetings = protected admission model. **0 consequential actor decisions derive from route shape.**

## 7. Authorization proof (§9)

Representative classes, all: **route identifies, authority decides.** Members/join-requests/invites/domains/billing/availability/branding nav entries are `visibleWhen: identity.canManageX` → effective-capability set from the backend (`institution_access_provider.can(...)`); screens re-gate (e.g. branding editor requires `ConsequentialAct.manageBranding == available`, C2-pinned); the backend enforces independently (InstitutionAuthorityService guards; verified during C1/C2). Route existence grants nothing: an unauthorized person deep-linking to `/institution/:id/billing` meets the capability gate, not the address's blessing.

## 8. Slug vs id (§10) and alternatives (§11)

`/institutions/:slug` = the **public durable link contract**: human-readable, shareable, the institution's public identity. `/institution/:id/…` = **authenticated operational depth keyed by immutable internal identity**: stable across renames (an institution renaming its slug must not break every operational bookmark, saved admin link, and notification destination), opaque, auth-gated. **Alternative B** (single `/institutions/:slug/…` namespace) was evaluated: it is viable and prettier, but strictly worse on rename-stability of operational addresses (slug is mutable public identity; id is immutable object identity) and would force either slug-immutability (a new product constraint) or canonicalization redirects on every rename (recreating corrective-redirect debt) — while buying no additional product truth: authorization, acting identity, and shell already don't depend on the address form. **Alternative C**: no repository evidence supports a third model. **A is retained on architecture grounds, not inertia.** The `/institution` vs `/institutions` singular/plural asymmetry is acknowledged as naming awkwardness, harmless, and gate-protected against confusion (directory ≠ object ≠ depth pins).

## 9. Downstream safety (§13)

**C4** Settings reconstructs against truthful object-local depth (personal settings under Me; institution settings under the institution object) — no route ambiguity. **C7** inherits institution object scope with zero ambient acting identity (explicit-context contract; the inbox quartet's final route disposition is C7's, with the alias mechanism ready if it converges them). **C8** builds room depth under institution scope; temporary resource roles cannot become institution-wide identity because no route or shell carries identity at all. **PD-1** Admin remains a separate governed shell; `/admin` classification is distinct and never conflated with institution operations.

## 10. Outcome

Proof held → **no route architecture changed** (§14 honored). Changes made: alias-aware `contextOf` + pin (defense in depth), the 34/4 count correction, and this canon. The durable distinction for all future chapters: **MIRRORED ROUTE ≠ OBJECT-LOCAL INSTITUTION DEPTH ≠ PATH-MANUFACTURED CONTEXT.** The first is dead, the second is the product, the third is structurally impossible while the gates stand.

**Recommendation: C3 FINAL CLOSE.**
