# C3 — Navigation & Information Architecture Reconstruction

**Date:** 2026-08-16 · Phase 1: forensic + founder destination checkpoint. Canonical charter: `FINAL_FRONTEND_RECONSTRUCTION_ROADMAP.md` C3 · governed by `NAVIGATION_IA_PRODUCT_LANGUAGE_FROZEN.md` (2026-08-15) + `CAPABILITY_ADAPTIVE_EXPERIENCE_FROZEN.md` + FD-9/FD-12/FD-13.

## 1. Re-measured reality (2026-08-16, post-C2)

| Signal | Historical | **Current** |
|---|---|---|
| Declared `GoRoute`s | 171 | **171** |
| Mirrored `/institution/:institutionId/…` routes (DR4) | ~40 | **40 exactly** |
| `redirect:` sites | ~27 | **27 exactly** |
| Feature-level route literals (`context.go/push('/…')` outside router) | — | **266 across 92 files** (+4 `GoRouter.of` variants) |
| Router size | 2,100 lines | 2,100 lines |
| Shells | 4 | **PublicShell · MemberShell · InstitutionShell · AdminShell**, selected in `AppShell` (`app_shell.dart`) — **by URL path prefix** (`isInstitutionShellPath`, `isAdminShellPath`) + auth/guest token state |

Top-level route families: `/institution` **41** · `/meetings` 13 · `/admin` 12 · `/me` 8 · `/institutions` 5 · `/meet` 4 · `/invite` 4 · `/i` 4 · `/u` 3 · `/announcements` 3 · ~30 singletons (`/home`, `/search`, `/spaces`, `/thread`, `/direct`, `/conversations`→redirect, `/settings`, `/activity`, `/updates`, `/saved`, `/create`, `/compose`, marketing/legal pages…).

## 2. Structural findings

**F1 — The shell IS the path.** `AppShell` chooses Public/Member/Institution/Admin **from the URL prefix**. The institution "context" is therefore an address-space fact, which is what forces every institution-context surface to exist as a second route universe. This is the root cause of DR4, not a symptom.

**F2 — Route-derived acting context is still live** (`core/interactions/actor_context.dart`): `resolveActorContext` returns an **institution actor whenever the path starts with `/institution/`** and an identity is loaded, with an R1 composite (`canPublishPosts || isAdmin`) for `canSpeakAsInstitution`. Consumers: `institution_detail_screen` (follow actor — an I→I follow becomes institutional *because of the URL*), `direct_thread_screen` (DM actor — mirrored `/institution/:id/direct/:threadId` makes the **message sender** institutional by path, violating the frozen C1 institutional-DM ruling "a route may never establish the sender"), `inbox_screen` (degrades to user in practice). Disposition: the DM/inbox actor fix is the exact contract C1 reserved for **C7's correspondence reconstruction** (`ConsequentialAct.correspondAsInstitution` doc); the mirrored routes and the path-derivation mechanism itself are **C3-owned** and retire with DR4 convergence. The follow-actor case needs an explicit acting choice (NO CHOICE WITHOUT A REAL CONSEQUENCE — person vs institution follow are both legitimate); flagged at checkpoint.

**F3 — DR4 classification of the 40 mirrors.** Category A (same object, duplicated for context): `…/u/:handle` (person profile), `…/institutions/:slug` (institution detail), `…/direct/:threadId`, explore/search-like surfaces — **converge**. Category B (genuinely institution-owned objects): dashboard, members, join-requests, invites, domains, billing, availability/booking pages, announcements-manage, live-rooms, edit-profile — these are real objects; what must die is the *`:institutionId` path-context prefix*, not the destinations. Category C (route exists to manufacture acting context): the A-set doubles as C — proven by F2. Category D (deep-link aliases): all 40 need alias mapping at migration.

**F4 — Capability-adaptive nav is already largely real.** The institution side-nav (`member_shell.dart` `_InstEntry` list) gates Join Requests/Invites/Availability/Domains/Billing/Edit-Profile via `visibleWhen: identity.canManageX` — and those getters are **effective-capability-true** (`institution_access_provider.can(...)`), hidden-not-disabled. Historical findings "greyed unauthorized tiles / capability-blind rail / billing hidden by URL" are **RESOLVED** on this surface (billing is a capability-gated nav entry today). Residual: `adminOnly` flags coexist redundantly with capability predicates; member `counts` fetch is `isAdmin`-gated (registered R1 owner, backend-coupled).

**F5 — Redirect classification (27).**
- **E · session/auth continuity (2, keep):** the top-level auth redirect (`router.dart:510`, the login/verify/redirect-dest machine) + meetings guest boundary (`:1930` — the frozen institutionId-in-path ≠ actor fix).
- **D · stale rename aliases (6, retire with alias policy):** `/auth`→`/login`, `/safety`+`/trust-safety`→`/child-safety`, `/institution/sign-in`→`/login`, `/conversations`→messages, `/me/communications` alias.
- **F · object-id canonicalization (≈8, DR4-coupled):** the `_enforceCanonicalIdMatch` cluster — exists only because `:institutionId` lives in the path; retires with DR4.
- **C · duplicated-IA patches (≈9, retire with DR4):** `/institution/(dashboard|…)` anchor redirects that repair the mirrored universe.
- **F · slug-reserved-word guards (2, keep or fold into typed routing):** `/institutions/:slug` reserved-word handling.
**Target state:** no redirect that patches the destination model; keep only session continuity, permanent public-link contracts, and parse guards.

**F6 — 266 route literals in 92 feature files** — every one is a hidden dependency on today's route text. Convergence onto a typed Navigation/Surface Authority is mechanical but should follow the founder-approved destination tree so strings are replaced once, not twice.

**F7 — Module-oriented labels are mostly gone** from primary chrome (MemberShell: Home/Messages/Create/Institutions/Support; InstitutionShell: Overview/Explore/Activity/Announcements/Live/Spaces/Messages/Meetings/Members/Join Requests/Invites/Booking pages/Domains/Billing/Profile). Residual language questions (e.g. "Explore" vs discovery vocabulary, "Overview" vs "Home", FD-10 open vocabulary) land with the destination checkpoint.

**F8 — Navigation state authority:** shell rails derive active state from path matchers per entry (`isActive(p)` predicates with `contains('/members')`-style matching) — string-fragile, replaced by registry identity at migration. No duplicated selectedIndex stores found in shells (path-driven).

## 3. What is already resolved (do not rebuild)

Capability-gated institution nav (F4) · Public Home entry (C2) · meetings router guest boundary · verification/trust nav-adjacent presentation (C2) · `startLive`/`manageBranding` capability gates (C2/closeout) · G5 on home surfaces (burned in C2).

## 4. C3-owned G5 (post-C2 re-measure pending per-file)

Baseline says 20 files/44 sites; home-screen sites (6) already burned during C2 Public-Home work → real remainder concentrated in institutions/* and public discovery screens. Full per-file re-measure scheduled with Phase-2 implementation (burning while converging surfaces, per §27).

## 5. Ownership boundaries honored

C7: membership/invite/join **lifecycle internals** + correspondence acting-actor fix · C8: institution_live_rooms DR2 internals · PD-1: `/admin/*` internals (C3 covers only its placement/reachability) · Meetings: protected, entry/deep-links only · C4: Settings internals + attention.

## 6. Proposed primary destinations — FOUNDER CHECKPOINT (not frozen, not implemented)

See the checkpoint report (§50 AI–AP) delivered with this document. Summary of the proposal:

**Authenticated Person primary (5):** **Home** · **Messages** · **Discover** (people + institutions + spaces + search as one intention) · **Meetings** · **Me** (profile/settings depth). **Create** becomes a contextual action (FD-6: no global composer destination). **Institution context** becomes an *object context inside the one tree* — entering an institution you belong to adapts the same tree (institution home, its communication, its people, its operations) rather than switching address universes; operations (members/invites/domains/billing/branding/verification) are **object-local depth** under the institution object, capability-gated exactly as today. **Public/unauthenticated (4):** Home · Discover · About/Mission depth · Sign in/Join. **Admin** remains a separate governed shell (PD-1 internals) reached from Me, not primary chrome. Mobile: bottom nav (≤5) = the same primaries; desktop: rail + object-local secondary nav; deep links: every current URL resolves via alias map to registry destinations.

## 7. Migration sequence (post-approval)

1. Typed destination registry + Navigation Authority (route identity, generation, alias resolution). 2. Feature literal convergence (266 sites → authority calls). 3. DR4 convergence per-route (A-set first; B-set re-homed as object-local depth under `/institutions/:slug/...` or successor canonical object path), alias redirects added. 4. Shell selection off path → off destination identity + session; acting-context path-derivation deleted (with C7 coordinating the correspondence actor). 5. Redirect burn-down (D/C/F classes) + literal-route gate (no route strings outside the authority). 6. G5/R1 burn + registry-enforced reachability tests + deep-link suite.


---

## Phase 2 — certified boundary (2026-08-16)

**FOUNDER FROZE:** the five authenticated primaries (Home/Messages/Discover/Meetings/Me), Discover semantics (intention, search = mechanism, facets stay distinct objects), institution = contextual object not a universe, public nav Home/Discover, Admin from Me, Create = contextual action, same identities across widths, Follow-as ruling (explicit choice only when real).

**Shipped at this boundary** (commits `9ffb777`, `d577e67`):
- `core/navigation/navigation_authority.dart` — typed destination identity, frozen primary sets, path→destination resolution (selected state), presentation-shell context classification (non-authority, pinned).
- `/discover` (public) + DiscoverScreen; directory/search/spaces highlight Discover; MemberShell five primaries (bottom nav + rail, same identities); PublicShell Home/Discover; AppShell consumes authority context.
- **Route-derived acting context RETIRED**: `resolveActorContext` deleted. Follow-as at institution detail (explicit chip choice, default You, governance-gated institutional option via the single canonical `canActAsInstitution` predicate — R1-baselined with justification). Institution inbox/threads receive `institutionContextId` explicitly from their route builders. C7 handoff recorded in `actor_context.dart`.
- 10 navigation pins; full suite 544 green; all gates + ratchets green.

**Explicit next segment (not yet executed):** DR4 per-route convergence of the 40 mirrors + alias map · 266 feature literal migration onto the authority · redirect burn-down (D/C/F classes) · route-literal gate · deep-link test matrix · shell-selection full de-pathing (context classification still keys on the `/institution/` prefix inside the authority — one owner now, semantics unchanged; retires with DR4 since mirrors are what the prefix matches).
