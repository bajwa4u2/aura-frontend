# C2 — Canonical Follow Construction

**Date:** 2026-08-16 · Built from the frozen §6/§7 forensic + R1–R10 rulings. **No forensic repeated; no ruling contradicted by implementation evidence.**

---

## 1. The canonical model

**`CanonicalFollowService`** (`src/follows/canonical-follow.service.ts`) — the single place relationship truth is asked and written. Consumers never again know *"check `Follow`, then `FollowRequest`, then `InteractionFollow`."*

### The frozen consent partition, now product truth

The shipped product already partitioned cleanly; the canonical model freezes that partition as **product semantics** rather than storage accident:

| Direction | Consent | Store | Writer |
|---|---|---|---|
| **Person → Person** | **CONSENT-REQUIRED**: request → accept/reject, 7-day rejection cooldown, request identity, inbox/outbox direction | `FollowRequest` + `Follow` | canonical lifecycle methods |
| **Person → Institution** | immediate | `InteractionFollow` | delegated to `FollowsService` (block gate + FOLLOW notification intact) |
| **Institution → Institution** | immediate (speaker-gated) | `InteractionFollow` | same |
| **Institution → Person** | **REFUSED** — structurally representable, product semantics NOT authorized (R9) | — | both writers refuse (`ForbiddenException`) |

**FOLLOW ≠ SUBSCRIBE** holds structurally: nothing in the canonical service reads or writes thread/space rows, and a test pins that the person read constrains both actor and target to USER.

### Model answers (§9 A–J)

**A/B** actor-aware, direction explicit · **C** consent partition above · **D** PENDING/APPROVED/**REJECTED** (retained state, never "no row") · **E** request identity = `FollowRequest.id`, carried in notifications' payload · **F** cooldown anchored to REJECTED `updatedAt`, 7 days, surfaced as a truthful `cooldown` relationship state · **G** `BLOCK > CONSENT/REJECTION > FOLLOW` — block enforced at request creation (the legacy writer never checked), `UserBlock`/`BlocksService` only; `InteractionFollowStatus.BLOCKED` untouched (zombie, no new reads/writes) · **H** consequences below · **I** R9 disposition enforced in code · **J** subscribe separation pinned.

## 2. Writer convergence

| Writer | Before | After |
|---|---|---|
| `POST /users/:handle/follow/request` | `users.service` — **no block check, no notification, accepted-and-discarded `message`** | canonical `requestFollow` — block-gated, **emits `FOLLOW_REQUEST`** (deduped per request), `message` contract **removed** (R8: never stored, never displayed, never sent by any shipped client) |
| `…/follow/cancel` | delete pending | canonical, unchanged semantics |
| `…/follow/requests/:id/accept` | tx Follow+APPROVED, silent | canonical, same tx invariant, **emits `FOLLOW_ACCEPTED`** to the requester |
| `…/follow/requests/:id/decline` | REJECTED, silent | canonical, REJECTED retained, **deliberately still silent** — no rejection event exists in the authorized pipeline; emitting one would invent attention policy (C4's) |
| `POST /follows` USER→USER | **wrote FOLLOWING immediately — the D3 consent bypass** | **CLOSED.** Refused with guidance to the request flow. Existing bypass-created rows still *read* as following — no relationship loses standing; none can be newly created |
| `POST /follows` INSTITUTION→USER | structurally accepted | **REFUSED** (R9) |
| Legacy `users.service` lifecycle methods | live | **retired** — no zombie writers |

## 3. Reader convergence

| Reader | Disposition |
|---|---|
| `GET /users/:handle/follow/state` | → canonical `personRelationshipByHandle` — wire-compatible states + truthful new `cooldown` state (unknown states tolerated by the shipped client) |
| **Availability** (`followedSubsetOf`) | **replaced at the designated point** — now delegates to canonical `followedPersonIdsAmong`; union semantics preserved exactly; **privacy policy untouched** |
| `GET /users/:handle` profile | **D4 closed** — now emits real `followersCount`/`followingCount` from the canonical authority |
| Followers/following lists, inbox/outbox | unchanged (`Follow`/`FollowRequest` reads — already the canonical stores for those views) |
| **Feed** (`feed-member.followedUserIds`) | **deliberately unchanged.** Activating person-follow feed visibility (D1) is a *new behavioral consequence* for existing relationships — exactly what the frozen migration rule forbids as a side effect. Staged as an explicit founder decision, not smuggled in |
| DM gating (`canMessage`) | unchanged — USER→USER always allowed; USER→INSTITUTION requires FOLLOWING; blocks canonical (R1) |

## 4. Counts (§19)

From the **person-follow store only**, so counts match the lists exactly. **Not counted:** Thread/Space subscriptions, person→institution follows (different surface), institution→person structural rows (counting would legitimize the unauthorized direction). Pinned by test.

## 5. Migration / transition strategy (§26)

**Chosen: legacy preservation + canonical projection.** No rows moved, nothing destructive, fully reversible:

- Both stores remain authoritative for their own segment; the canonical service is the projection.
- Bypass-created USER→USER `InteractionFollow` rows: read, never written — no standing lost, no growth.
- Physical convergence (one store) is a **later, separately staged migration chapter after deployment observation** — legitimate staging under §26, because the canonical construction itself is complete and what remains is genuinely data-transition work under the frozen no-new-consequences rule.
- Retirement path: once feed/D1 activation is adjudicated and data reconciled, the bypass-row read and the legacy stores can converge in one place each (`followedPersonIdsAmong`, list readers).

## 6. Behavioral-consequence matrix (§25) — proven by test

| State | Profile state | Counts | Feed | Notification | DM | Availability |
|---|---|---|---|---|---|---|
| P→P accepted | `following` | counted | **unchanged (none — staged)** | request+accept events | unchanged (always allowed) | disclosed |
| P→P pending | `outgoing/incoming_pending` + requestId | not counted | none | FOLLOW_REQUEST once | unchanged | not disclosed |
| P→P rejected (cooldown) | `cooldown` + days | not counted | none | **none (state only)** | unchanged | not disclosed |
| blocked either way | request refused | — | — | none | refused (R1) | hidden |
| P→I | `FollowsService` state | not in person counts | unchanged | FOLLOW | gates USER→INST DM | n/a |
| I→P structural | never surfaced | never counted | never | never | never | never |
| Thread/Space subscribe | outside Follow entirely | never counted | activity fanout (unchanged) | none (unchanged) | — | — |

**No existing relationship gained or lost any consequence.** The only behavior changes are the three adjudicated corrections: block-gated requests, the two authorized notifications, and D3/R9 refusals at creation time.

## 7. Certification

Backend: **tsc clean · 177 suites / 2249 tests** (new: `canonical-follow.service.spec.ts` — 17 tests). Frontend: **519 tests**, no changes required (contract additive). Spec corrections were repins of adjudicated behavior (D3-bypass fixtures), not weakenings — DM specs' USER→USER follow setup was removed because it never was a precondition (USER→USER messaging is always allowed).

## 8. Nine Follow-blocked G5 sites

**Technically unblocked** — the canonical authority now provides truthful state, requests, cooldown and counts for the three legacy surfaces (`followers_screen`, `following_screen`, `follow_requests_screen`). **Not consumed in this task**, per the stopping rule.

## 9. Remaining founder decisions

1. **D1 feed activation** — should established person-follows populate the member feed? The fix is one reader change, but it retroactively changes what existing relationships do. Deliberately staged for your call.
2. **Physical store convergence** — authorize as a later migration chapter after deployment observation.

Nothing else. R1–R10 fully implemented or explicitly staged as above.
