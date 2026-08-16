# C3 — NAVIGATION & INFORMATION ARCHITECTURE: CLOSEOUT (execution authority / handoff)

**Date:** 2026-08-16 · C3 charter executed to the closeout checkpoint. Awaiting founder closure declaration.

## Final destination tree (founder-frozen)

**Authenticated primaries (5):** Home `/home` · Messages `/messages` · Discover `/discover` · Meetings `/meetings` · Me `/me` — identical identities on mobile bottom nav and desktop rail. **Public:** Home · Discover. **Create** = contextual action. **Admin** = governed shell from Me. **Institution** = contextual object depth (`/institution/:id/…` = its single canonical operational address space; `/institutions/:slug` = the public object), never a second universe. **Discover** = the consolidated find intention; search is the mechanism; People/Institutions/Spaces stay distinct facet objects.

## Route architecture

`NavigationAuthority` (`core/navigation/`) owns: frozen primary sets · path→destination identity (`primaryOf` — selected state; facets highlight Discover; directory≠object pinned) · presentation-shell classification (`contextOf` — post-DR4 this is destination-identity classification, documented + pinned as never-acting-authority) · canonical object route builders (person/institution/thread/directThread/post) · `legacyAliasTarget` (retired-mirror alias resolution).

## DR4 verdict (per-route demolition test, executed)

Of the 40 mirrored routes: **2 were pure duplicates** of global objects (`…/u/:handle`, `…/institutions/:slug` — identical builders) → **retired to alias redirects** resolved through the authority; every feature call site migrated (gate-enforced: navigating to a retired mirror fails the build). **35 are genuinely institution-owned contextual depth** (dashboard, members, invites, join-requests, domains, billing, availability, branding, verification-request, announcements, posts-manage, spaces-scoped, live-rooms, explore, activity, units, engagement, correspondence, meetings-in-institution — Meetings protected) — the single canonical home of those destinations, not mirrors. **3 are the institutional-inbox trio** (`…/messages`, `…/messages/direct(±archived)`, `…/direct/:threadId`) — preserved with **explicit** `institutionContextId` from their route builders until C7 reconstructs the correspondence sender experience (handoff in `actor_context.dart`).

## Acting-identity safety — 0 route-derived mechanisms

`resolveActorContext` deleted · Follow-as explicit (chip choice, only when a real choice exists; `canActAsInstitution` = the one canonical governance predicate, R1-recorded) · institutional inbox context explicit-by-builder · shell classification pinned non-authority. Search re-run post-DR4: **zero** path-shape→actor mechanisms.

## Enforcement (registry, live)

`test/navigation/` — 13 gate tests: frozen primaries · alias/facet resolution · shell-context-non-authority · **route-integrity gate** (every feature literal must resolve against the declared route table, constants + interpolations understood — caught 2 real defects on first run: a stale profile mirror link ×2, and validated `/messages/direct`) · **literal ratchet** (`c3_route_literal_baseline.txt`: 103 files / 294 literal sites frozen — no rises; falls recorded; new code uses the authority) · retired-mirror alias-resolvable-never-buildable pin.

## Measurements (before → after)

| Signal | Phase-1 forensic | Closeout |
|---|---|---|
| Declared routes | 171 | 172 (+`/discover`) |
| Mirror routes with builders | 40 | **38** (2 → alias redirects); classified: 35 canonical depth · 3 C7-pending |
| Route-derived acting-context mechanisms | 3 consumers + resolver | **0** |
| Redirect sites | 27 | 29 (+2 DR4 aliases; every one classified: session/auth ×2 keep · rename aliases ×6 = alias boundary · id-canonicalization ≈8 = parse guards on canonical depth · workspace-anchor ≈9 = id-less "my workspace" conveniences · parse guards ×2 · DR4 aliases ×2). **No redirect patches a broken destination model** — the model the old redirects patched (duplicated IA) is gone; the remainder are aliases, guards, and session transitions with owners |
| Feature literals | 266 | 261, **all validated against the declared table + frozen by ratchet**; migration proceeds per-surface as owning chapters reconstruct (owners in baseline header) |
| Shell-by-prefix as authority | AppShell raw prefixes | authority-owned destination classification, non-authority pinned |

## Visible experience

People: five clear places, identical across devices, truthful selection (Discover lights up wherever finding happens); old institution-prefixed person/institution links land on the modern canonical objects; Follow-as asks who the relationship belongs to only when that's a real question. Institutions: workspace unchanged and capability-true — now formally the institution object's operational depth inside one Aura, with its two identity-duplicating exits retired.

## Contracts inherited by later chapters

**C4:** Settings/attention internals; Me-depth placement fixed. **C7:** membership/invite/join lifecycles + correspondence sender experience — MUST consume the explicit-context contract (`institutionContextId` + `correspondAsInstitution`); no route-derived sender may survive C7 closure; the institutional-inbox trio's route disposition finalizes with it. **C8:** live-rooms internals (DR2). **PD-1:** admin internals. **Meetings:** protected; its 8 institution-context routes untouched. **All chapters:** navigate via `NavigationAuthority`; the literal ratchet + integrity gate enforce it.

## Remaining C3-owned debt: NONE unexplained

Every remainder above carries owner + retirement condition (literal baseline per-surface owners; C7 trio; alias retirement = link-traffic evidence at a future observed window; G5 C3-owned sites burn with their surfaces per the standing register).
