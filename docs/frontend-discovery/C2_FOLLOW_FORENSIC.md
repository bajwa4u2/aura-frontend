# C2 §6 — Follow Behavioural Forensic (complete)

**Date:** 2026-08-15 · Code/schema/test evidence only. **No production access used or required.**
**No canonical target chosen. No migration performed.**

---

## 1. What is actually reachable in the shipped client

The two systems **partition by target type**. They are not currently competing over the same rows.

| Direction | Path used by the client | Backing model | Consent |
|---|---|---|---|
| **Person → Person** | `/users/:handle/follow/request` → approve | `FollowRequest` → `Follow` | **request → approval, always** |
| **Person → Institution** | `POST /follows` | `InteractionFollow` | **immediate, none** |
| **Institution → Institution** | `POST /follows` (acting as institution) | `InteractionFollow` | immediate |
| **Institution → Person** | **API only — no client surface** | `InteractionFollow` | immediate |

`POST /users/:handle/follow` is *deliberately disabled* — `legacyToggleBlocked()` throws *"Aura follow requires a request."* There is **no private-account flag on `User`**: person→person follow is request-only **by design for everyone**, not a privacy branch.

Institution actors are gated: `assertCallerCanActAs` requires `adminUserId` or speaker rights.

---

## 2. Consequence matrix — what each relationship actually changes today

| Consequence | Person → Person (`Follow`) | Person → Institution (`InteractionFollow`) |
|---|---|---|
| **Feed visibility** | ❌ **NONE** — `feed-member.followedUserIds()` reads `InteractionFollow`, which this path never writes | ✅ `followedInstitutionIds()` reads the same table |
| **Notifications** | ❌ **NONE at any step** — request, approve and decline emit nothing | ✅ `NotificationType.FOLLOW` to the target |
| **canMessage / DM** | ⚪ no effect — USER→USER is *always allowed* regardless of follow | ✅ required: USER→INSTITUTION returns `false` unless `FOLLOWING` |
| **Follower/following lists** | ✅ `/users/:handle/followers`/`following` read `Follow` | ❌ institution follows never appear in these lists |
| **Profile follow state** | ✅ `followStateByHandle` reads `Follow` + `FollowRequest` | ❌ invisible to that endpoint |
| **Counts** | ❌ `followersCount`/`followingCount` **never emitted by the backend** (0 occurrences in `src/`) | ❌ same |
| **Blocking** | ❌ not enforced — see D2 | ❌ not enforced |
| **Privacy / consent** | ✅ approval required | ❌ none |
| **Audit / history** | ⚪ `Follow` has no id and no status history; `FollowRequest` retains REJECTED + a 7-day cooldown | ⚪ row deleted on unfollow — no history |

**Reading of this matrix:** the two paths are close to **complementary halves of one feature**, each blind to the other. Person-follow has consent, lists and state but no feed and no notifications. Institution-follow has feed, notifications and DM gating but no lists, no state endpoint and no consent.

---

## 3. Defects (D1–D4 confirmed, D5–D8 new)

| # | Defect | Severity |
|---|---|---|
| **D1** | **Following a person never affects the feed.** The member feed's "people I follow" source is a table the person-follow flow never writes. | HIGH — core function broken |
| **D2** | **Blocking does not stop DMs.** `canMessage` checks `InteractionFollow.status === BLOCKED`, which **nothing ever writes**. Real blocking is `UserBlock`, consulted only by `blocks.controller` and `feed.controller`. `direct-threads.service` gates creation *and* first message on `canMessage`. | **HIGH — safety** |
| **D3** | **API-level consent bypass.** `POST /follows` accepts `target: USER` and writes `FOLLOWING` immediately, bypassing the request-only design. Not client-reachable; reachable by any API client. | MEDIUM |
| **D4** | **Counts never emitted.** `author_profile_screen` renders `profile.followersCount`, permanently 0. `me_screen` sidesteps it by counting the returned list. | MEDIUM |
| **D5** | **`InteractionFollowStatus.REQUESTED` is never written.** Declared, read nowhere meaningful. | MEDIUM |
| **D6** | **`BLOCKED` is never written either** — it is only *read*, by the dead check in D2. | HIGH (with D2) |
| **D7** | **`FOLLOW_REQUEST` / `FOLLOW_ACCEPTED` are fully plumbed but never emitted.** Email templates, routing rules, communications service and the delivery authority all handle them; **no code creates them.** A person is never told someone asked to follow them, nor that they were approved. | HIGH — silent relationship |
| **D8** | **The request `message` is accepted and discarded** — `void message`, with the comment *"schema currently does not store a request message."* The API takes input it cannot persist. | LOW |

---

## 4. Can `InteractionFollow.REQUESTED` replace `FollowRequest`?

**Not as it stands.** Faithful replacement would lose four things:

| Lost | Detail |
|---|---|
| **REJECTED as a state** | `InteractionFollowStatus` has only FOLLOWING / REQUESTED / BLOCKED. `FollowRequestStatus` has PENDING / APPROVED / **REJECTED**. |
| **The 7-day cooldown** | `FOLLOW_REQUEST_COOLDOWN_DAYS = 7` is anti-spam keyed off a *rejected* request's `updatedAt`. Without REJECTED there is nothing to key from. |
| **Inbox / outbox** | Requester-vs-target views are derived from `FollowRequest` rows; `InteractionFollow` has no request-direction concept beyond actor/target. |
| **Request identity** | `FollowRequest.id` is used by accept/decline endpoints. `Follow` has no id at all (composite PK). |

**Conclusion: REQUESTED is structurally capable but behaviourally insufficient.** Convergence onto it requires adding a rejected state and a cooldown anchor — a schema change, not a status write.

## 5. Can `Follow` migrate to `InteractionFollow.FOLLOWING`?

**Yes, structurally.** Mapping is `actorType=USER, actorUserId=followerId, targetType=USER, targetUserId=followingId, status=FOLLOWING`.

- **Synthesized:** `id` (legacy has none).
- **Must be preserved:** `createdAt`.
- **Nothing semantic is lost.**

⚠ **But the migration has a live side effect:** it would retroactively make every existing person-follow start feeding the member feed (fixing D1 in bulk). That is a **visible product change for existing users**, not a silent data move.

---

## 6. Conflict matrix — states possible after convergence

Uniqueness today is enforced by **six partial unique indexes** (`userUser`, `userInst`, `instUser`, `instInst`, `user_thread`, `institution_thread`), so `InteractionFollow` cannot hold duplicate pairs. `Follow` has a composite PK. The conflicts are therefore **cross-system**, not intra-table.

| # | State | Possible? | Required rule |
|---|---|---|---|
| 1 | `Follow` exists, no `InteractionFollow` | **Yes — the normal case today** | migrate → `FOLLOWING`, preserve `createdAt` |
| 2 | `InteractionFollow FOLLOWING` USER→USER, no `Follow` | Only via D3 (API bypass) | **Founder decision:** honour it, or treat as consent-bypassed and downgrade? |
| 3 | Both exist | Possible via D3 | keep one row; take the **earlier** `createdAt`; no duplicate |
| 4 | `FollowRequest PENDING` + `InteractionFollow FOLLOWING` | Possible via D3 | contradiction — consent pending yet already following. **Founder decision.** |
| 5 | `FollowRequest REJECTED` + `InteractionFollow FOLLOWING` | Possible via D3 | **worst case — a refusal already overridden.** Founder decision; my recommendation is that REJECTED wins. |
| 6 | `FollowRequest PENDING`, no InteractionFollow | Normal | migrate → `REQUESTED` **only after** a REJECTED state exists |
| 7 | `FollowRequest REJECTED` | Normal | no follow row; cooldown anchor must survive |
| 8 | `UserBlock` exists + any follow row | **Yes — blocks and follows are unaware of each other** | converge blocking first, else the migration imports follows that a block should have prevented |
| 9 | Stale rows after unfollow | No — `unfollow` deletes the row | — |

**Rule 8 is the ordering constraint:** blocking (D2/D6) should be corrected **before** any follow migration, otherwise blocked relationships are carried into the converged model.

---

## 7. Migration ordering (design only — not authorized)

1. Fix **D2/D6** — make blocking real and consulted by `canMessage`.
2. Close **D3** — stop `POST /follows` writing USER→USER without consent.
3. Add the missing states (**REJECTED**, cooldown anchor) if `InteractionFollow` is the target.
4. Emit **D7** notifications so relationship events stop being silent.
5. Only then migrate `Follow` → `FOLLOWING`, `FollowRequest PENDING` → `REQUESTED`.
6. Repoint readers (lists, `followStateByHandle`, counts).
7. Retire the legacy tables.

**Steps 1–2 are defect fixes that stand on their own merit regardless of which convergence target is chosen.**

---

## 8. Live-row evidence — not yet required

Everything above came from schema, code and migrations. Production rows would only be needed to size conflict classes 2–5, and those exist **only** via the D3 bypass. If D3 was never exercised, classes 2–5 are empty and the migration is mechanical.

**A narrow read-only count would settle it** — but only once the founder chooses a convergence target, since the query depends on the target. Not requested now.

---

# C2 §7 — Follow vs Subscribe: **separate concepts sharing infrastructure**

Judged on behaviour, not table names.

| | **Follow** (Person/Institution) | **Subscribe** (Thread/Space) |
|---|---|---|
| Who is notified at the moment of the act | **the target** — `NotificationType.FOLLOW` | **nobody** |
| What the act registers | a relationship toward an actor | interest in a context's activity |
| Direction of value | my feed changes; you learn I follow you | content is fanned out to me (capped at 200) |
| Consumed by | `feed-member.service` (feed sources), `canMessage` (DM eligibility) | `posts.service` activity fanout |
| Service | `follows.service.ts` | **`thread-space-follows.service.ts` — its own service** |
| Reversibility of meaning | unfollowing withdraws a social signal | unsubscribing withdraws only delivery |
| Actor rules | actor may be USER or INSTITUTION | thread/space are **target-only**; nothing can act *as* one |

**The decisive asymmetry:** following an actor *tells them something about the relationship*. Subscribing to a thread tells nobody anything — it changes only what reaches you. One is relational and mutual-facing; the other is a private attention subscription.

The backend already treats them as distinct in code (separate service, separate consumers, target-only actor kinds). Only storage is shared.

## Recommendation

**Distinguish them in Product Language: `Follow` and `Subscribe`. Keep `InteractionFollow` as shared storage — an implementation detail, not a product statement.**

Consistent with the public-first doctrine: **Follow is first a relationship capability between people**, available person-to-person before any institution exists; institutional following is one legitimate case, not the definition. Defining Follow around institutional discovery would invert the causal order.

**Not frozen by me.** This needs a C0 Product Language extension (`ProductAction.subscribe` / a Subscribe concept), and **C4 may own the final attention wording** — the founder has previously reserved attention terminology to C4. Two options:

- **A** — extend C0 now with `subscribe`, so C2/C7 can build against a stable word.
- **B** — record the semantic separation now and let C4 name it, with C2 using the neutral internal term meanwhile.

**My recommendation: B.** The separation is established and can be recorded without a word; C4 owns attention language and would otherwise have to re-open whatever C0 froze here.

---

# FOUNDER ADJUDICATION — 2026-08-15

Recorded verbatim in substance. **No migration executed. No convergence performed.**

## R1 · Blocking (D2/D6) — RESOLVE INSIDE C2

Authorized as a current behavioural/safety defect, a relationship-authority concern, and a
**prerequisite to safe Follow convergence**. Not backlog.

Establish the **canonical existing** blocking authority first — **do not create a second blocking
system** to repair `InteractionFollow`.

> **BLOCKING OUTRANKS FOLLOW / RELATIONSHIP / MESSAGING ELIGIBILITY.**
> A blocked relationship must not remain actionable because another table reports FOLLOWING.

Boundaries to trace before implementation: `UserBlock` · `Follow` · `FollowRequest` ·
`InteractionFollow` · `canMessage` · DM/thread creation authorization · feed eligibility where
blocking applies · follow/request eligibility · unblock behaviour. Targeted regression required
for every shared subsystem touched.

## R2 · Follow convergence — converge the **product concept**, not one table

Neither implementation is canonical merely because it exists.

**Frozen product semantic:**

> **FOLLOW is a governed relationship between an acting Person or Institution and another Person
> or Institution, subject to the target's applicable relationship and consent rules.**

Public-first causality stays explicit: institutions are **not** a prerequisite for people's
relationships. **But public-first does not make Person→Person the only or ontologically superior
direction** — each direction must be governed by real product authority. **Do not manufacture
symmetry because the model can represent it.**

## R3 · Structural direction — `InteractionFollow` is the stronger foundation, and **not yet safe**

It already understands actor kinds, target kinds, institutional acting context, and feed /
notification / messaging consequences.

> **DO NOT MIGRATE LIVE FOLLOW DATA INTO THE CURRENT `InteractionFollow` MODEL.**

The legacy path carries consent semantics `REQUESTED` cannot faithfully represent: request
identity, approval/rejection, REJECTED state, cooldown, inbox/outbox direction, consent history.

Intended direction:

```text
ACTOR-AWARE FOLLOW AUTHORITY
  + FULL CONSENT / RELATIONSHIP LIFECYCLE
  + BLOCKING AUTHORITY
  + DOWNSTREAM CONSEQUENCES
```

**not** "delete legacy Follow and copy rows into InteractionFollow." **No semantic information may
be flattened to obtain one table.**

## R4 · FOLLOW ≠ SUBSCRIBE — **FROZEN**

Follow concerns a relationship between actors. Subscribe concerns receiving activity from a Thread
or Space. Shared storage does not define ontology; subscription does not inherit Follow consent
semantics.

**C2 records the semantic authority; C4 owns the final user-facing vocabulary** when it
reconstructs attention surfaces. C0 is not reopened. C2 must leave C4 enough precise semantics that
it never has to rediscover whether these are the same concept.

## R5 · Conflict precedence — **FROZEN**

```text
BLOCK  >  EXPLICIT TARGET CONSENT / REJECTION  >  ACTIVE OR INFERRED FOLLOW STATE
```

State-5 resolution: **REJECTED → NO ACTIVE FOLLOW RELATIONSHIP.**

**But contradictory historical evidence must not be erased to make the database look clean.**
Reconciliation preserves provenance: what each source said · which state won · why · what
consequence followed. States 2-4 derive from the same principle, not isolated exceptions. Genuine
residual ambiguity returns to the founder.

## R6 · Migration must not create silent product changes

The feed-activation side effect is **not a harmless data migration**. Before any migration design
is authorized for execution, classify every consequence convergence could activate: feed visibility
· messaging eligibility · notifications · follower/following lists · profile relationship state ·
counts · recommendation/discovery · institutional acting-context effects · any other observed
consumer.

> **No historical relationship may silently gain a new behavioural consequence because its row moved.**

## R7 · D7 relationship events — domain truth is C2, attention policy is C4

Model the truthful relationship transitions where they actually occur: REQUEST · APPROVAL ·
REJECTION · public/non-consent Follow if such a governed mode exists.

**Do not activate dormant email templates because they exist** — they are evidence of intended
capability, not authority for current semantics. Separate **domain event truth** (C2) from
**attention delivery/channel policy** (C4). Do not pre-build C4 inside C2.

## R8 · D5 / D8 — no zombie status, no discarded input

`REQUESTED` must gain a defined canonical role or be deliberately retired. The request `message`
must be classified from evidence: a real governed concept requiring persistence and presentation,
legacy API residue, or another relationship concept. **No accepted-and-discarded user input.**

## R9 · Institution → Person — classify, do not infer

API representability is **not** product intent. Classify as: intentionally supported · future
structural · accidental generic API reach · or prohibited/unneeded.

> **Institutional power over public relationships must not expand merely because the schema
> supports the direction.**

Public-first is relevant but does not answer it automatically. If product authority does not
resolve it, return a specific founder checkpoint.

## R10 · Sequencing

Resolve the authorized blocking prerequisite where safely possible, then **continue remaining C2
discovery (§8-§12) before destructive convergence.** Do not rush into migration because the
direction is adjudicated.

---

## Status after adjudication

| Item | State |
|---|---|
| Blocking (D2/D6) | **AUTHORIZED for resolution inside C2** — not yet implemented |
| Follow product semantic | **FROZEN** (R2) |
| Convergence target | **Direction adjudicated; current `InteractionFollow` schema explicitly NOT safe as-is** |
| Live data migration | **NOT AUTHORIZED for execution** |
| Follow vs Subscribe | **FROZEN** (R4); vocabulary deferred to C4 |
| Conflict precedence | **FROZEN** (R5) |
| §8-§12 discovery | **Outstanding** |
