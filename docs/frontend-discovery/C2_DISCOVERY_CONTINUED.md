# C2 — §8, §10, §11 (continued discovery)

**Date:** 2026-08-15 · Code/schema evidence only. **No production access.**
Companion to `C2_FOLLOW_FORENSIC.md` (§6/§7 + founder adjudication R1–R10).

---

# R1 — Blocking authority · **RESOLVED / CERTIFIED**

## Canonical authority established first

`UserBlock` + `BlocksService` is the canonical blocking authority. It is **person-to-person only** (`@@unique([blockerId, blockedId])`), stores direction (blocker → blocked), and supports idempotent create/remove plus `blockedIdsFor`.

**No second blocking system was created.** `BlocksService` gained one predicate, `isBlockedBetween(a, b)`, which is bidirectional: *if A blocked B, B must not reach A either.*

## What was wrong

`FollowsService.canMessage` checked `InteractionFollow.status === BLOCKED` — a status **no code anywhere writes**. The check always passed. `direct-threads.service` gates **both** thread creation and the first message on `canMessage`, so **a blocked person could still open a DM and message the person who blocked them.** The block only affected the feed.

## What changed

| Site | Change |
|---|---|
| `blocks.service.ts` | `+ isBlockedBetween()` — the canonical predicate |
| `follows.service.ts` · `canMessage` | dead `InteractionFollow.BLOCKED` query **replaced** by the canonical check |
| `follows.service.ts` · `follow()` | **new gate** — a blocked relationship is not followable (`ForbiddenException`) |
| `follows.module.ts` | imports `BlocksModule` (no cycle: Blocks → Prisma + Moderation only) |

**Institution actors deliberately excluded.** `UserBlock` models person-to-person; inferring an institutional block from a personal one would be a second blocking system. Asserted by test.

## Certification

`follows.service.blocking-authority.spec.ts` — 7 tests, including the precedence proof: **a live `FOLLOWING` row does not override a block.**

**Shared-system regression:** `follows` + `direct-threads` + `blocks` → 6 suites / 47 passed. **Full backend: 173 suites / 2207 tests passed**, `tsc` clean. Three pre-existing specs updated for the new constructor dependency.

**Boundaries traced:** UserBlock · Follow · FollowRequest · InteractionFollow · canMessage · DM/thread creation · feed eligibility (unchanged — already used `BlocksService`) · follow eligibility (now gated) · unblock (idempotent delete; removing the block restores eligibility with no residue).

> **`InteractionFollowStatus.BLOCKED` remains in the enum, still never written.** It is now also never read. Its retirement belongs to the Follow convergence (R3/R8 "no zombie status"), not to this safety fix.

---

# §8 — Availability privacy: options and enforcement boundary

> **SUPERSEDED 2026-08-15 by founder ruling — preserved as the evidence the decision rested on.**
> The policy was chosen (established-Follow default, block hides both directions, no raw
> timestamp to third parties, viewer identity authorized) and is **implemented**. See
> *§8 IMPLEMENTED — Availability Disclosure Authority* at the end of this document.

## Current state, precisely

| Fact | Evidence |
|---|---|
| Endpoints | `POST /v1/presence/ping`, `GET /v1/presence/state` |
| Auth | `@UseGuards(JwtAuthGuard)` — **signed-in callers only, never anonymous** |
| **Viewer identity on read** | **`getState` does not receive `@CurrentUserId()` at all** |
| What is returned | `{ actorType, userId/institutionId, lastActiveAt, status }` — **raw `lastActiveAt`**, plus ONLINE / RECENT / OFFLINE |
| Relationship check | none |
| Block check | none |
| Privacy field | none exists on any model |
| Heartbeat | ~45s while signed in, unconditional |

The controller's own doc states it plainly: *"the actor probed there does not have to be the caller."*

**So today: any signed-in person can read any other person's exact last-active timestamp and online status, with no relationship, consent or block check.**

Also recorded honestly: **`InstitutionPresence` exists as a backend model.** That does not resurrect the withdrawn client-side "institutional public presence family" finding — that was a regex artefact — but institutional availability is a real backend concept and any policy must say whether it is governed the same way.

## The enforcement boundary — the decisive architectural point

> **`PresenceService.getState` currently has no viewer to enforce against.**

Every policy below therefore requires the **same** structural change first: thread viewer identity into the read path (`@CurrentUserId()` → `getState({ viewerUserId, actor })`). Until that exists, no visibility policy can be enforced anywhere, and **a client-side toggle would be decoration.**

Enforcement must live in `PresenceService.getState`, not in the client and not in the controller — because presence is also consumed server-side.

## Options — for founder adjudication, not chosen

| | Policy | What it requires beyond viewer identity | Cost / consequence |
|---|---|---|---|
| **A** | **Everyone signed in** (today's behaviour, made explicit) | nothing | honest but no protection; the current default was never a decision |
| **B** | **Followers only** | a follow lookup per read | depends on the Follow convergence — and today person→person follows live in the legacy table, so this would be wrong until R3 lands |
| **C** | **Mutual relationships only** | bidirectional follow lookup | strictest relationship-based option; smallest visible surface |
| **D** | **Explicit allow-list** | a new preference model | most control, most UI, most support burden |
| **E** | **Nobody / off** | a per-person switch | must be a real stored preference, enforced server-side |

**Independent of the choice, two sub-decisions:**

1. **Block interaction.** Should a block hide availability? R1's precedence (`BLOCK > …`) argues yes, and it is cheap now that `isBlockedBetween` exists. **My recommendation: yes, regardless of which option is chosen.**
2. **Online state vs exact `lastActiveAt`.** These are separable and arguably deserve different treatment: `ONLINE/RECENT/OFFLINE` is coarse and useful; a precise timestamp reveals routine and sleep patterns. **Recommendation: stop returning raw `lastActiveAt` to third parties by default and expose the bucket** — this is the single highest-value change and is independent of the visibility policy.

**Policy not invented.** Options and consequences only.

---

# §10 — People Selection

**Two canonical person projections exist, and they are distinct by design** (reaffirmed by the backend Founder Acceptance Register, not my inference):

| Projection | Concern | Used by |
|---|---|---|
| `core/directory/directory_entry.dart` — `DirectoryEntry` | **picking a person** | `member_picker_field`, thread/space creation, institution-space member selection, mention scope |
| `features/correspondence/data/correspondence_identity.dart` — `CorrespondenceIdentity` | **rendering an existing conversation** | correspondence hub, space/thread screens, messages hub, invitations |

**Finding: neither projection carries verification or availability.** `verifiedClasses`, `isVerified`, presence and availability are all absent from both. So People Selection currently shows a person **without** any trust or availability signal — consistent with the C2 verification forensic (client-wide flattening) and with §8 (no governed availability).

**This is the C2 obligation:** the shared canonical Person projection that selection consumes must be able to carry layered verification and governed availability **without** selection becoming an authority system — it consumes projections, it does not compute them. C1 remains authoritative for acting context; no ambient acting identity or route-derived authority may be reintroduced here.

⚠ Six surfaces still show local person-shaped extraction (`_extractMembers`-style) — `admin_institution_members_screen` · `conversations_screen` (retired in C4) · `correspondence_hub_screen` · `invite_member_screen` · `space_screen` · `member_home_screen`. These need per-site classification before convergence; not all are selection surfaces.

---

# §11 — G5 re-verification: **21/21 confirmed C2**

Unlike C1 (where 38 of 42 were disproved), the C2 assignments **hold** — every file is a genuine identity/profile/relationship surface.

| File | Sites | Verdict |
|---|---|---|
| `institutions/profile/institution_edit_profile_screen.dart` | 3 | ✅ C2 — DR5 |
| `institutions/profile/institution_profile_screen.dart` | 4 | ✅ C2 — DR5 |
| `me/presentation/edit_profile_screen.dart` | 1 | ✅ C2 — DR5 |
| `me/presentation/me_screen.dart` | 2 | ✅ C2 — DR5 |
| `profile/presentation/author_profile_screen.dart` | 2 | ✅ C2 — DR5 |
| `profile/presentation/follow_requests_screen.dart` | 3 | ⏸ C2 — **blocked on Follow convergence** |
| `profile/presentation/followers_screen.dart` | 3 | ⏸ C2 — **blocked on Follow convergence** |
| `profile/presentation/following_screen.dart` | 3 | ⏸ C2 — **blocked on Follow convergence** |
| **Total** | **21** | **21 confirmed C2** |

**But they are not equally actionable.** 12 sites (5 profile files) can proceed with profile reconstruction. **9 sites (3 files) are the legacy Follow surfaces** — they consume `/users/:handle/followers|following` and the request inbox/outbox, so reconstructing them before the canonical relationship model exists would build against a model R3 has explicitly ruled unsafe.

**Zero reassignment. Total preserved at 181.** (`shared/media/profile_media_editor.dart` remains C5's — DR3 upload pipelines — and was never part of C2's 21.)

---

# §8 IMPLEMENTED — Availability Disclosure Authority

Founder direction frozen and implemented. **Backend enforcement, not a client toggle.**

| Ruling | Implementation |
|---|---|
| Availability = contextual projection of a **Person** | `getState` treats USER and INSTITUTION paths as different concepts |
| Default third-party visibility = **established Follow** (not everyone, not mutual) | `mayDiscloseAvailability()` — asymmetric follow accepted |
| **Block hides availability both directions** | consumes canonical `BlocksService.isBlockedBetween`; short-circuits *before* any follow lookup |
| **No raw `lastActiveAt` to third parties** | humanized state only; self keeps the timestamp |
| Online state vs historical activity | state disclosed under policy; exact time withheld |
| Self visibility | full state including timestamp |
| **Viewer identity authorized** | `@CurrentUserId()` → `getState({ viewerUserId, actor })` |

**Hidden is deliberately indistinguishable from genuinely offline** — a distinct HIDDEN marker would itself disclose that the person hid. Proven by test.

## The temporary compatibility projection (ruling 9)

Person-to-person follows are split across `Follow` (legacy approval path) and `InteractionFollow`. `mayDiscloseAvailability` reads the **union of both** — the explicitly permitted "authoritative across BOTH current systems" allowance, **not a third interpretation**. It is isolated in one method so replacing it with the canonical Follow authority is a single edit.

## Second disclosure path found and closed

`FeedPresenceHydratorService` attaches author availability to **every feed item** — a second availability surface alongside `/presence/state`, also unenforced. **Raw timestamp suppressed there too.** Relationship-gating that path additionally depends on the canonical Follow authority and is recorded as an explicit dependency, not silently deferred.

## Availability Off — architecture supports it, not yet built

`mayDiscloseAvailability` is the single disclosure decision point, so an Off preference becomes one additional check inside it — **enforced server-side by construction**. No frontend-only toggle is possible against this design. **The user-facing setting belongs to the Settings/Attention chapter (C4); the backend authority does not make Off impossible.** Dependency recorded, no privacy debt created.

## §12 — InstitutionPresence: a distinct concept

`InstitutionPresence { institutionId, lastActiveAt }` — written by the same ping path when the actor is an institution, read by `getState` and the feed hydrator.

**It is organizational operational state, not personal information**, and it is kept distinct: the person-availability disclosure policy is **not** applied to it, and no personal privacy semantics were inherited onto it. This does **not** resurrect the withdrawn client-side "institutional public presence family" finding — that was a regex artefact. Whether institution availability warrants its own policy is a separate question, not answered here.

**Institutional access to person availability remains NOT AUTHORIZED** — an institution actor querying a person receives the same deny-by-default treatment as any other viewer, because the viewer is resolved as a Person.

## Certification

`presence.service.availability-disclosure.spec.ts` — 7 tests including block-outranks-relationship and hidden-vs-offline indistinguishability.
**Full backend: 174 suites / 2214 tests.** Frontend: analyze clean, **508 tests** — the contract change is backward-compatible (`lastActiveAt` was already nullable in both client models).

---

# FEED DISCLOSURE CLOSURE — **IMPLEMENTED / CERTIFIED** (founder ruling 3)

Not deferred to Follow convergence. The existing disclosure path is closed now.

## One authority, consumed twice

`AvailabilityDisclosureService` (`src/presence/`) is now **the single decision point**. Both surfaces consume it:

| Surface | Consumes |
|---|---|
| `PresenceService.getState` — direct probe | `mayDisclose(viewer, target)` |
| `FeedPresenceHydratorService` — author availability on every feed item | `disclosableUserIds(viewer, targets)` — **batched** |

`PresenceService`'s own copy of the rule was **removed**, not left alongside. A privacy rule implemented twice is one that will eventually disagree with itself, and the feed is exactly where that would go unnoticed.

**Batched deliberately:** a feed page hydrates many authors, so a per-author decision would be an N+1 privacy check — and N+1 checks create pressure to skip the check.

## The full path was traced, not patched

Seven call sites required viewer propagation — five in `feed.controller.ts`, two via `feed-reply.service.ts` → `hydrateReplyAuthors`. **Both** hydration paths are gated; no alternate serialization path reaches presence without passing the authority. `userId` was already in scope at every controller site (the interaction hydrator already took a viewer — the precedent existed).

**The gate runs before the read.** Undisclosable availability is never loaded from the database, let alone serialized.

## Institution presence kept separate

Institution authors bypass the personal gate entirely — organizational operational state, not personal information. A test asserts institution ids are never even submitted to the personal decision.

> **No unresolved public-disclosure question found.** `InstitutionPresence` is surfaced only as feed-author presence for institution authors and via `/presence/state` for an institution actor. It carries no personal semantics and no new policy was manufactured. Nothing to report under ruling 2's escalation clause.

## Certification

| Suite | Result |
|---|---|
| `availability-disclosure.service.spec.ts` | **11** — policy pinned once, at the authority |
| `presence.service.availability-disclosure.spec.ts` | **6** — delegation + timestamp rules |
| `feed-presence-hydrator.disclosure.spec.ts` | **8** — feed gate, incl. institution separation |
| Backend total | **176 suites / 2232 tests**, `tsc` clean |
| Frontend | analyze clean, **508 tests** |

Covered as required: allowed follower · non-follower · blocked viewer→author · blocked author→viewer · self · raw timestamp suppression · hidden/offline indistinguishability · anonymous viewer · institution separation · mixed page.

## Availability Off — ownership recorded

> **C2 owns the doctrine. C4 Settings owns the control.**

`disclosableUserIds` is the single server-enforceable decision point, so an Off preference is one additional check inside it, applied before the relationship test. **No C4 surface built, no temporary C2 preference surface created.** C4 consumes this requirement rather than re-deciding it.

## Canonical Follow replacement point

`followedSubsetOf` is the **only** method that knows how Follow is stored. When convergence lands it is a single authoritative edit — not another privacy rewrite. That isolation was the reason for centralising.

