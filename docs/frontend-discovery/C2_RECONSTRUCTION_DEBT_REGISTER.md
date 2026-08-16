# C0–C2 Reconstruction-Debt Register · Follow Adoption · Final Storage Architecture

**Date:** 2026-08-16 · Produced under the founder reconstruction doctrine:
**CANONICAL ARCHITECTURE → RUNTIME ADOPTION → VISIBLE PRODUCT OUTCOME → LEGACY RETIREMENT.**

---

# PART 1 — Follow adoption (Objective A)

## D1 — Person→Person feed activation · IMPLEMENTED

`feed-member.followedUserIds()` now resolves through `CanonicalFollowService.followedPersonIds()` — the union of both live stores. **Existing accepted follows begin participating without unfollow/refollow.** Only the candidate *source set* widened: visibility, ranking, moderation, blocks, and content eligibility unchanged; Thread/Space subscriptions structurally excluded (both sides constrained to USER). Pinned by test.

## Nine Follow-blocked G5 sites · CONSUMED

`followers_screen` · `following_screen` · `follow_requests_screen` — all nine direct state-primitive constructions replaced with `AuraProductState` (C0 authority), with honest retry recovery and canonical `ProductNoun.person` empties. **G5: 177 → 168 sites (70 → 67 files)**, ratchet-verified.

## Follow end-to-end client experience

| Lifecycle element | State |
|---|---|
| Follow / request / pending / accept / reject | canonical endpoints, wire-compatible |
| **Cooldown** | **now visible** — profile button shows *"Not available yet"* (disabled) instead of offering an action the backend refuses with a surprise 400 |
| Counts | **real for the first time** (D4) — `author_profile` renders true numbers |
| Requests inbox/outbox | working, now notification-backed (FOLLOW_REQUEST / FOLLOW_ACCEPTED) |
| Blocked relationship | requests refused at the earliest gate; availability hidden; DM refused |
| Person→Institution | unchanged, canonical |
| Institution→Person | never offered, never counted, never shown |

## Final canonical Follow storage architecture (§13)

Designed from product semantics, not from today's tables.

**The truthful final model is TWO stores, because the product has two distinct kinds of truth:**

```prisma
/// THE relationship — one row per established, governed relationship.
model FollowEdge {
  id            String   @id @default(cuid())
  actorType     ActorKind   // PERSON | INSTITUTION
  actorId       String      // person id or institution id
  targetType    ActorKind
  targetId      String
  establishedAt DateTime    // provenance: original createdAt preserved
  origin        FollowOrigin // CONSENT_APPROVED | IMMEDIATE | LEGACY_BYPASS
  @@unique([actorType, actorId, targetType, targetId])
  @@index([targetType, targetId])   // follower lists/counts
  @@index([actorType, actorId])     // following lists/feed source
}

/// THE consent lifecycle — request identity is first-class, never inferred.
model FollowConsent {
  id          String        @id @default(cuid())   // request identity survives
  requesterId String        // person only (consent applies to person targets)
  targetId    String
  status      ConsentStatus // PENDING | APPROVED | REJECTED
  createdAt   DateTime
  respondedAt DateTime?     // cooldown anchor (today's updatedAt semantics)
  @@unique([requesterId, targetId])
  @@index([targetId, status])       // inbox
  @@index([requesterId, status])    // outbox
}
```

**Why two, from semantics:** a relationship and a consent decision are different product facts with different lifecycles — REJECTED must persist *without* any relationship existing (cooldown anchor, truthful history), and collapsing them into one row forces either zombie statuses (today's `InteractionFollowStatus.REQUESTED/BLOCKED`) or history destruction. "One table" was the goal that produced the current split-brain. **One canonical product truth, expressed by two honest stores + one authority.**

- **Subscribe** stays physically where it is (`InteractionFollow` thread/space rows) until **C4** names its product surface — semantically separate today, structurally separate then.
- **Institution→Person**: representable in `FollowEdge` (generic kinds) but no writer creates it; `origin` cannot express it; refusal stays in the authority.
- **Blocking**: never duplicated — `UserBlock` remains the only block store; precedence lives in the authority.

## Executable physical migration plan (§14)

Gated on deployment observation of the current commits; may not disappear into backlog.

1. **Preconditions:** current four commits deployed and observed; D3 closure confirmed in production behaviour (no new USER→USER `InteractionFollow` rows: `SELECT count(*) ... WHERE actorUserId IS NOT NULL AND targetUserId IS NOT NULL AND createdAt > <deploy>` = 0).
2. **Schema:** create `FollowEdge` + `FollowConsent` (additive migration, no destructive DDL).
3. **Backfill (idempotent, re-runnable):**
   - `Follow(followerId, followingId, createdAt)` → `FollowEdge(PERSON→PERSON, establishedAt=createdAt, origin=CONSENT_APPROVED)`
   - `InteractionFollow` USER→INSTITUTION / INSTITUTION→INSTITUTION `FOLLOWING` → `FollowEdge(..., origin=IMMEDIATE)`
   - `InteractionFollow` USER→USER `FOLLOWING` (bypass residue) → `FollowEdge(origin=LEGACY_BYPASS)` — **preserved with provenance**, per R5 ("do not erase contradictory history")
   - `FollowRequest` → `FollowConsent` 1:1, **ids preserved** (request identity), `respondedAt=updatedAt` for non-PENDING
   - **Institution→Person `InteractionFollow` rows, if any exist:** NOT migrated to active edges — exported to an audit table; **founder decision on disposition** (they are product-unauthorized)
   - Conflict rule (frozen R5): `REJECTED` consent + any FOLLOWING row for the same pair → edge carries `origin=LEGACY_BYPASS`, flagged in validation output; **BLOCK pairs**: edges between blocked pairs are backfilled but the authority already suppresses all consequences.
4. **Validation queries (before cutover):** per-pair equivalence of `followedPersonIds`, follower/following lists, counts, inbox/outbox between old-store reads and new-store reads; zero rows lost; id preservation check on consent.
5. **Cutover (dual-read → single-read):** `CanonicalFollowService` internals switch to the new stores behind its existing method signatures — **consumers unchanged by construction**, because table knowledge already ends at the authority. Old stores become read-frozen.
6. **Retirement:** after an observation window with clean validation — drop legacy writers' remaining references, then `Follow`, `FollowRequest`, and the USER→USER rows of `InteractionFollow`; delete `InteractionFollowStatus.REQUESTED/BLOCKED` zombie enum values; `InteractionFollow` remains solely Subscribe storage until C4.
7. **Rollback:** step 5 is a flag-flip back to old-store reads; steps 2–3 are additive and reversible by dropping the new tables.

---

# PART 2 — C0–C2 legacy-debt audit (Objective B)

## Measured now (not quoted from old forensics)

| Measure | At forensic | **Now** |
|---|---|---|
| G5 direct state primitives | 181 / 72 files | **168 / 67 files** |
| R1 role-as-permission | 85 / 25 files | **82 / 23 files** |
| `'Try again'` literals | 33 | **0** |
| `verifiedClasses` consumers | 0 | **0** |
| `isVerified` sites | 82 | **82 (26 files)** + 16 `'Verified'` literals |
| `identity.isAdmin` | — | **4 code sites** (see register) |
| Deprecated temporal shim callers | 9 | **11 files** (shim forwards correctly) |

## The register

| # | Chapter | Surface | Legacy | Canonical | Runtime uses canonical? | Visible upgrade? | Status · retirement |
|---|---|---|---|---|---|---|---|
| 1 | C2 | **Verification presentation** | flattened boolean trust | canonical trust layer (`core/trust/`) + layered person wire + admin grant/revoke exposure | **YES** | **YES** | **MIGRATED (2026-08-16).** Person profile renders per-class marks from `verification.classes`; 13 institution presentation sites on canonical marks; §11 'Official session'-from-isVerified violation corrected; admin verification sheet exposes full governed history (REVOKED/EXPIRED first-class). Remaining `isVerified` = legitimate canonical Institution field + non-presentational; remaining `'Verified'` literals = 8, all subject-unambiguous, classified in `C2_TRUST_PRESENTATION.md`. NEW founder item: plan taxonomy sells verification (§20 STOP, see decisions) |
| 2 | C1 | `actor_context.dart` (`resolveActorContext`, 3 consumers) | route-derived acting identity | `ActingContextAuthority` | NO (retired provider: 0 consumers; resolve fn: 3) | partial | **TRANSITIONAL** · retired when C3 (inbox/detail nav) + C7 (thread screens) reconstruct their surfaces — registered owners |
| 3 | C1 | `member_shell.dart:267` admin count gating | `identity.isAdmin` | capability question | NO | — | **TRANSITIONAL, backend-coupled** — the payload itself is role-gated server-side (`getMyInstitutionState` isAdmin); client mirrors payload presence. Retire with the backend role→capability count gating + C3 shell reconstruction |
| 4 | C1/C7 | `institution_correspondence_screen.dart` | `isAdmin` gate | capability | NO | — | **LEGITIMATELY FUTURE-OWNED (C7** — registered surface disposition FD-12 §4) |
| 5 | C0 | 11 files calling deprecated temporal shims | local call sites | `AuraTemporal` (shim forwards — one implementation) | YES (via shim) | YES (uniform time language) | **TRANSITIONAL COMPATIBILITY** · retirement: per-chapter adoption of `ProductTime`; shim deleted when callers = 0; G2/G7 ratchets prevent growth |
| 6 | C0 | G5 remainder 168 sites / 67 files | direct state primitives | `AuraProductState` | NO | NO | **ACTIVE DEBT, chapter-owned** per the G5 ownership matrix (C3 44 · C4 26 · C5 16 · C7 26 · C8 3 · C9 3 · PD-1 34 · PD-2 3 · C2 view-profiles 8) — each owner adopts as it reconstructs; ratchet enforced |
| 7 | C2 | Follow compatibility union (`followedPersonIdsAmong`/`followedPersonIds` reading two stores) | split-brain stores | `FollowEdge`+`FollowConsent` (designed above) | YES (authority is canonical; stores transitional) | YES | **TRANSITIONAL** · retirement: physical migration plan above, gated on deployment observation |
| 8 | C2 | Bypass USER→USER `InteractionFollow` rows | consent-bypassed relationships | `origin=LEGACY_BYPASS` edges | read-only | — | **TRANSITIONAL** · retirement at migration step 6; **founder decision** if institution→person rows are found |
| 9 | C2 | `InteractionFollowStatus.REQUESTED/BLOCKED` | zombie enum values | canonical lifecycle / `UserBlock` | n/a (never read/written) | — | **TRANSITIONAL** · deleted at migration step 6 |
| 10 | C2 | People Selection — 6 local person-shaped extraction sites | local extraction | `DirectoryEntry`/`CorrespondenceIdentity` | partial | — | classified: `conversations_screen` **C4-retired**; `correspondence_hub/space/invite_member` **C7**; `member_home` **C3**; `admin_institution_members` **PD-1**. All future-owned with named owners — none actionable under C2 authority without touching owned surfaces |
| 11 | C0/C7 | umbrella "Correspondence" naming (paths, `CorrespondenceIdentity`, hub screens) | legacy umbrella sense | one canonical meaning (frozen) | docs yes, paths no | — | **LEGITIMATELY FUTURE-OWNED (C7** — founder-recorded rename obligation) |
| 12 | C2 | Availability Off user control | none | single enforcement point ready | backend ready | NO (no UI) | **LEGITIMATELY FUTURE-OWNED (C4 Settings** — adjudicated ownership split) |

**No item is labelled future-owned without a named owner and adoption point.**

## Chapter-level completeness (founder table)

| | ARCHITECTURE | RUNTIME ADOPTION | VISIBLE PRODUCT ADOPTION | LEGACY RETIREMENT |
|---|---|---|---|---|
| **C0** | complete | **partial** — language/temporal broadly adopted (0 'Try again', shim-unified time); state authority at 168 remaining sites, chapter-owned by design | **partial** — uniform action language + human dates visible everywhere; state coherence only on reconstructed surfaces | **partial** — shim + G5 ratchets with owners; nothing unowned |
| **C1** | complete | **near-complete** — 4 residual sites, all named-owner transitional | **partial** — capability-true gating visible on profile surfaces; attribution component live on one composer | **partial** — `resolveActorContext` awaiting C3/C7 |
| **C2** | complete | **substantially complete** — blocking, availability (both paths), profiles, canonical Follow + D1 + nine sites adopted at runtime | **YES — see below** | **partial** — Follow physical migration planned+gated; verification presentation MIGRATED 2026-08-16 |

## Visible product outcome (§8) — what changed for real users

**A person now:** is actually protected by Block in DMs · has availability disclosed only to established followers, never with a raw timestamp, indistinguishably-hidden otherwise · sees real follower/following counts (previously always 0) · gets notified of follow requests and acceptances (previously silent) · sees a truthful cooldown instead of a surprise error · **their feed finally reflects who they follow** (D1) · edits their profile with validated media and honest state/language.

**An institution now:** its profile editor is offered exactly to holders of the real backend capability (delegable — a MEMBER with the grant can edit; an ADMIN without it isn't teased) · denial reads as honest non-access, not an error · its follow relationships are notification-backed · institutional identity is never inferred from a URL.

---

# PART 3 — Compatibility layers (complete list, §15)

Every one has a reason, destination, retirement condition, and deletion target — listed in register rows 2, 3, 5, 7, 8, 9. **None is "kept for backward compatibility" without an answer to: with what, for whom, until when, retired by what.**

# PART 4 — Founder decisions still required

1. **Institution→Person residue disposition** at migration step 3 — *only if* production rows exist (unknown until the read-only validation query runs at migration time).
2. **Authorize the physical migration execution window** after deployment observation (plan above is ready).
3. ~~Verification/trust presentation~~ — **EXECUTED 2026-08-16** (`C2_TRUST_PRESENTATION.md`).
4. ~~Monetization × verification conflation~~ — **ADJUDICATED + RESOLVED 2026-08-16** (VERIFICATION IS NOT PURCHASABLE; full decoupling implemented, reconciliation SQL staged manual/founder-observed). Two successor decisions: ~~4a (tier naming)~~ — **RESOLVED 2026-08-16 by taxonomy closeout: FREE + PRO frozen; the middle tier is retired, not renamed.** Remaining successor items are DATA dispositions at the founder-observed migration window, both queried by the reconciliation SQL: **4a′** legacy `VERIFIED` rows/subscriptions → founder remap (FREE vs PRO) from real subscription/payment evidence — paying institutions must not silently lose value; **4b** legacy `TRUSTED` rows → 0 rows = retire enum residue without adjudication, >0 = founder remapping decision (member-usage query included). Original finding: — the plan taxonomy sells verification: `InstitutionPlan.VERIFIED` (“Verification badge…”, `capabilities.isVerified: true` on paid plans), a `TRUSTED` plan label colliding with the public-first rejection of inherent “trusted institutions”, and `deriveVerifiedTrustState` coupling plan upgrades to the `Institution.isVerified` flag. Deeper than presentation drift — a product/commercial-policy decision only the founder can make. Presentation was made truthful; the model was not redesigned.

Nothing else. No new product decisions were taken by assumption.


---

## §12 addendum (2026-08-16) — Representation consistency outcomes

- **Temporal**: 3 local time-ago dialects converged onto `AuraTemporal.humanize(compact)` (activity, civic-signal card, updates); G2 `updates_screen` 6→0 recorded. Deprecated `relative_time.dart` shim: 11 caller files remain — semantics already canonical (shim forwards); burn-down owners C4 (notifications/inbox/feed-adjacent), C6 (thread surfaces); retirement = last caller converged → shim deleted.
- **Discourse intelligence**: 3 bare institution `verified_rounded` icons → `InstitutionVerifiedIcon` (subject-explicit semantics). Missed by earlier sweeps because the model field is `verified`, not `isVerified` — grep-term lesson recorded.
- **Follow direct-dio sites** (me_screen, follow_requests_screen — 6 calls): canonical endpoints, presentation-layer HTTP-in-widget debt only; owner: C2 closeout note / C4 attention refactor.
- **Representation**: stale Follow/Presence/Verification characterizations superseded with dated banners; C2 truths now canonical in `AURA_IDENTITY_RELATIONSHIP_TRUST_CANON.md`. No collision with other agents' uncommitted Representation work (3-file selective commit).
- **Q-item**: only remaining valid-authority-without-adoption is the Availability Off control — C4 Settings, already registered.


## Public Home addendum (2026-08-16)

- **Hero causality**: institution-first acquisition premise on `/` — corrected to public-first; gate scope extended to both home surfaces + 2 new prohibited phrases (the gap that let it ship is closed structurally).
- **Glyph doctrine**: verification icons reserved for verification; institutional involvement/accountability motifs use institution/hourglass glyphs (public_home ×5, discourse_card ×2, unified_feed_card ×1).
- **G5**: public_home 4→0, member_home 2→0 (dated baseline notes). Temporal shim 11→10 (unified_feed_card direct). Retired 'works' vocabulary removed from member home.
- **Follow direct-dio debt confirmed NOT Public Home** — owner: remaining C2 convergence/closeout task (me_screen.dart, follow_requests_screen.dart).
