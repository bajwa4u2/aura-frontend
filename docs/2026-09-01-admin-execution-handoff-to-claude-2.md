# Admin / Operator Console — execution handoff

**Date:** 2026-09-01
**From:** Claude-1 (Admin reconstruction)
**To:** Claude-2 (sole active execution owner from this date)
**Status:** Claude-1 new implementation STOPPED. Admin active execution owner is Claude-2.

This document exists so the work can continue **without reconstructing a chat
session**. It records the product reasoning, not only the commits. Where a
claim rests on evidence, the evidence is named; where something is unproven,
it says so rather than rounding up.

---

## A. Product and architecture

### What Admin is for

Admin is the **operator control plane**. It is not a CRUD surface over the
database. It answers, in order, the questions an operator actually has:

> what needs me now → what work is waiting → who or what is this about →
> what may I do about it → what happens if I do → what was done → is any of
> this being found

### The seven areas (frozen IA, in order)

| Area | Owns |
|---|---|
| **NOW** | Situational awareness. What is degraded, what is unconfigured, what changed. Never a worklist. |
| **WORK** | The unified worklist across seven authorities. Per-source failure is named, never rendered as a reassuring zero. |
| **SUBJECTS** | People and institutions as *subjects of governance* — standing, verification, membership, affiliation. |
| **INTEGRITY** | Moderation, media appeals, identity verification, product feedback, support cases. Judgment, not data entry. |
| **PLATFORM** | Health, providers, settings, flags, policies, media retention. |
| **RECORD** | What was done, by whom, with what reason. Append-only history. |
| **DISCOVERY** | Whether what Aura published is reachable and being found. Observation only. |

### Operator lifecycle

```
situational awareness (NOW)
  → attention / work (WORK)
    → subject (SUBJECTS)
      → governed action (INTEGRITY / SUBJECTS)
        → consequence (notification, publication, record)
          → history (RECORD)
            → discovery / intelligence (DISCOVERY)
```

### Authority boundaries that must not be eroded

1. **Authority is per-act, never route-derived.** A path containing an id
   grants nothing. `AdminPermissionGuard` **throws when a route declares no
   permission** — fail-closed by design. Do not "fix" that by defaulting.
2. **Capability ≠ role.** Areas gate on `OperatorCapability`, not role names.
3. **A capability-poor operator is TOLD, not shown a blank page.**
   `OperatorInsufficientCapability` is the required answer.
4. **State words are never softened.** `OperatorSignal` / `OperatorReach` /
   `OperatorCondition` vocabulary is frozen; "unavailable" must not become
   "unavailable right now".
5. **Discovery observes. It never controls.** See §C-Discovery.
6. **Identity evidence is custody-governed.** See §C-Identity.

---

## B. Current production state

| | |
|---|---|
| **Backend repo** | `aura-backend`, branch `main`, HEAD `1c21f63` |
| **Frontend repo** | `aura_final`, branch `main`, HEAD `e5ddb5b` (before this doc) |
| **Deploy** | Railway auto-deploys `main` on both repos |
| **Backend suite** | 326 suites / 4113 tests green |
| **Client admin suite** | 190 green |
| **Client full suite** | 2271 pass, 6 fail — see §D-6 |

### Migrations added in this pass

- `prisma/migrations/20261101000000_discovery_arrival/` — `DiscoveryArrival`
  table. **Applied in production** (verified by direct query).
  Note: sibling migrations `20261014*` / `20261015*` sort *before* this one;
  Prisma applies pending migrations regardless of order, but be aware.

### Configuration names (NEVER record values)

| Variable | Service | Purpose |
|---|---|---|
| `BING_WEBMASTER_API_KEY` | `aura-backend` | Bing Webmaster reporting. **Configured 2026-09-01.** |
| `FIREBASE_PROJECT_ID` / `FIREBASE_CLIENT_EMAIL` / `FIREBASE_PRIVATE_KEY` | `aura-backend` | FCM push **and** Google Search Console. The same service identity is a user on the GSC property — that is deliberate, not accidental reuse. |
| `DATABASE_URL`, `R2_*` | `aura-backend` | Jest does **not** load `.env`; suites touching R2 need it exported (`set -a; . ./.env; set +a`). |

### Local tooling constraints (windows-arm64)

- Prisma **query** engine has no windows-arm64 build → Prisma client cannot
  run locally. Use raw `pg` for direct production reads.
- Prisma **migration** engine *does* work locally.
- `railway run --service aura-backend -- npx ts-node -T <script>` injects
  production env into a local process — the way to exercise credential-bearing
  adapters **without ever seeing the credential**.

---

## C. Closed work

### AURA_REFERRAL — LIVE, REAL DATA

Aura observing its own published pages being reached.

| Stage | Where |
|---|---|
| Public arrival / acquisition | `src/share/share.controller.ts` → `serve()` |
| Privacy-safe recording | `src/discovery-intelligence/arrival-recorder.service.ts` |
| Persistence | `DiscoveryArrival` (counted, not logged) |
| Aggregation / projection | `src/discovery-intelligence/providers/aura-referral.provider.ts` |
| Admin presentation | `lib/features/admin/areas/discovery_area.dart` |
| Tests | `arrival-recorder.spec.ts` (17), `aura-referral.provider.spec.ts` (4) |

**The important design fact — do not undo it.** The first implementation put
the hook in the Flutter router. It could never fire: `/p/` canonical share
URLs are rendered by the backend over Express, so a visitor arriving from a
search engine is answered by the backend and **never boots the app**. The one
arrival the feature exists to observe was the one arrival the hook could not
see. Observation is server-side, in the single `serve()` method every share
family passes through, including visitors running no JavaScript.

Consequently the **public unauthenticated write endpoint was retired** — it
had no caller left. Do not reintroduce one.

**Privacy behaviour (frozen):**
- referrer reduced to **origin** only; query strings never stored
- day resolution only, never a moment
- no user, session, IP or user-agent stored — there is nowhere to put one
- the URL must already be in the published inventory, so nobody can mint
  counters for pages Aura never published
- normalized-and-aggregated at write time, so the 90-day raw-evidence rule has
  nothing to bite on; 24-month retention applies
- **a crawler is not an arrival** (user-agent filter, documented as coarse and
  deliberately non-exhaustive — a user agent is a claim, not a fact)
- **an arrival from Aura is not a discovery** — self-referrals are *recorded*
  (they are true) but excluded in the **projection** (what they mean is a
  judgment). Do not move this to the door.

**Live evidence:** 50 arrival rows / 52 arrivals, all `direct`, across pages
Claude-1 never visited. Crawler fetches (curl UA, Googlebot UA) returned 200
and incremented nothing.

### GOOGLE_SEARCH_CONSOLE — LIVE, REAL DATA

`src/discovery-intelligence/providers/google-search-console.provider.ts`
Spec: `google-search-console.provider.spec.ts` (9 tests).

- **Authority:** `sc-domain:auraplatform.org` is a verified **domain**
  property. `FIREBASE_CLIENT_EMAIL` is a user on it. This was recorded for
  months as "an ownership step only a person can complete" — **it was not.**
  It was configuration, and configuration is ours. Treat inherited "blocked on
  a human" absences as unverified claims.
- **Credential mechanism:** RS256 JWT minted with `node:crypto`, exchanged at
  Google's OAuth endpoint. **Do not import `google-auth-library`** — it is
  only a transitive dep of `firebase-admin`, and depending on it directly
  would make Discovery's availability depend on someone else's dependency
  graph.
- **Observational-only boundary:** scope is `webmasters.readonly`. Google
  itself refuses a submission. The spec pins the scope string.
- **Reporting lag — the trap.** Ingestion asks every provider for the last
  **24 hours**. Search Console does not report the last 2–3 days, so the
  adapter returned **zero rows silently in production** while a 28-day probe
  returned 46. Fixed: the provider shifts its own window back 3 days and asks
  for 7 trailing days (overlap is safe — `DiscoveryObservation` is upserted on
  `(estate, canonicalUrl, observedOn)`).
- **Live proof:** 17 rows across Aug 22–29, 44 impressions, 1 click, flowing
  into production tables through the operator's own Collect action.

### BING_WEBMASTER — LIVE VERIFIED, LEGITIMATE ZERO DATA

`src/discovery-intelligence/providers/bing-webmaster.provider.ts`
Spec: `bing-webmaster.provider.spec.ts` (12 tests).

```
BING_AUTHENTICATION      = PASS
BING_PROPERTY_AUTHORITY  = PASS
BING_PRODUCTION_WINDOW   = PASS
BING_REAL_DATA_OBSERVED  = NO  →  LEGITIMATE ZERO DATA, not adapter failure
BING_CONTROL_BOUNDARY    = PASS
```

**A future agent must not reinterpret this zero as a broken adapter.** The
evidence that it is genuinely zero:

- `GetUserSites` → 200 with 7 sites ⇒ credential authenticates and is authorised
- `https://auraplatform.org/` is in that list ⇒ property authority
- **Negative control:** a site the credential does *not* hold returns **HTTP 400**;
  ours returns **200** ⇒ "unknown site" is distinguishable from "no data"
- `GetPageStats` → `200, d = array(0)` — an *accepted call returning an empty
  array*, not null, not an error
- `GetRankAndTrafficStats` and `GetQueryStats` also `array(0)`
- Even a ±400-day window returns 0 ⇒ **not** the reporting lag
- **Positive control:** `bajwawrites.com` returns `array(14)` through the same
  endpoint, credential and parser ⇒ the pipe demonstrably works

Bing's own console said the property's data was still processing (up to 48h);
it was added recently. Evidence should begin appearing on its own.

**The production window is deliberately NOT widened to manufacture evidence.**
A green built from a window the product never uses is worse than an honest
zero — that is exactly how the GSC defect above survived a "passing" probe.

**Control boundary — ours to keep, not the provider's.** Unlike Google's
read-only scope, Bing issues **one key that can also submit URLs and
sitemaps**. Nothing outside our code prevents misuse. Discovery has **no
authority** for `SubmitUrl`, `SubmitUrlbatch`, `SubmitContent`, `SubmitFeed`,
`AddSite`, `RemoveSite`, `IndexNow` or any equivalent mutation. The spec
asserts the shape of every outbound request. **Credential capability does not
define product authority.**

Secret is recorded by **name only**: `BING_WEBMASTER_API_KEY`.

Note: Bing retired its legacy SOAP/POX APIs on 2026-08-31; the adapter targets
the JSON REST surface. Bing's date format carries a timezone
(`/Date(1777014000000-0700)/`) — the epoch is UTC midnight *in Bing's
reporting timezone*, so the offset is applied before the day is taken. Reading
it as UTC only worked because Bing's offsets are negative.

### DISCOVERY — the six-source model

Do **not** flatten these into green/red.

| Source | State | Meaning |
|---|---|---|
| `SITEMAP` | **ACTIVE** | Aura's own sitemap, fetched. |
| `CRAWLER_FETCH` | **ACTIVE** | Aura probes its own canonical URLs as a crawler would. |
| `AURA_REFERRAL` | **ACTIVE** | Real arrivals, real data. |
| `GOOGLE_SEARCH_CONSOLE` | **ACTIVE** | Real data. |
| `BING_WEBMASTER` | **ACTIVE / LEGITIMATE ZERO** | Verified live; property holds no data yet. |
| `INDEXNOW` | **NOT_APPLICABLE (permanent)** | A submission protocol with **no read side**. Submitting would be control, not observation. It will never report here. Do not "implement" it. |

**Standing product finding, unactioned and owned by the founder:**
**56 of 56 published objects are absent from the sitemap** (19 static URLs,
zero `/p/`), corroborated independently by GSC returning zero `/p/` rows.
**40 of the 56 are PERSON profiles.** Fixing the sitemap would push 40 real
people's profiles into Google — a privacy decision that is the founder's, not
an engineering one. The 16 editorial/institutional objects are separable from
the 40 person profiles and are two different decisions. **Do not "fix" this.**

### INSTITUTION SEMANTICS — frozen, founder-accepted (PASS)

```
INSTITUTION STANDING  ≠  VERIFICATION EVIDENCE  ≠  DOMAIN-PROOF DECISION
```

Governing principle: **a suspended institution keeps the verification evidence
it legitimately earned; a verified institution can be suspended tomorrow.**
"Its identity was verified, and it is not currently admitted" is a coherent
sentence the model can express.

The original defect was a *collapse*: one pill drew `status` tinted by
`verifiedAt`, which is what made a refused **domain proof** look as though it
should have changed the **institution's standing**. Now two labelled facts on
two lines in `lib/features/admin/areas/subject_institution_area.dart`.

**38-action audit result: PASS, no further instances.** Every operator action
carries a scoped `subject`, and wherever an action could be misread as acting
on the whole entity, the narrow object leads:

- domain proof → subject is `proof.domain`; detail opens *"This decides ONE claim"*
- verification → subject is `<class> · <person>`, so revoking one class cannot
  read as revoking the person
- membership → subject is `<person> · <role>`; detail says they stop acting
  *for the institution*, their own account untouched

Do not reopen without evidence of an actual new semantic collapse.

### FEEDBACK — lifecycle semantics complete

Model: `ProductFeedback` (`RECEIVED` / `REVIEWED` / `ACTIONED` / `CLOSED`)
plus `reviewedByUserId`, `reviewedAt`, `operatorNote`, `outcome`, release ref.

- **`REVIEWED` means read, NOT resolved.** The surface says
  `"Read. Nothing has been done about it yet"` — this sentence exists because
  a founder read "still open" as "my read action failed". Do not reword it
  into something friendlier.
- **Internal note has no submitter consequence** — `operatorNote` is
  operator-only and the person is never told it was written.
- **Submitter-facing response is `outcome`**, delivered through the governed
  consequence path.
- **Notification fires on `ACTIONED` and `CLOSED` only** — "somebody read it"
  is not news. `_reaches()` in `integrity_detail.dart` encodes this, and
  getting it wrong in either direction is the failure the grouping prevents.
- Operator actions are grouped by **actual consequence**, not by verb.

### IDENTITY — lifecycle and custody boundary

`lib/features/admin/areas/identity_review.dart`,
`lib/features/admin/data/operator_identity.dart`.

```
submission → evidence → verdict → notification → record
```

Preserved custody rules — **do not relax any of these**:

- **Evidence is not prefetched.** It is fetched when an operator chooses to look.
- **Audit precedes evidence/media access.** The record of looking is written
  before the looking.
- **DESTROYED evidence stays truthfully represented.** A destroyed record is
  shown as destroyed, not as missing or as an error.
- **SELFIE_COMPARISON is not liveness** and must never be presented as it.
- **No fabricated sensitive submission was created** to demonstrate a
  production queue. Deterministic proofs use controlled contracts/fixtures.
  Do not manufacture one.

### Contracts, loading, and other closed defects

- **Server-owned contracts:** 45 captured, zero remaining. Pipeline is
  backend mappers → `aura-backend/contracts/admin/*.json` → vendored to
  `aura_final/test/contracts/admin/`. Regenerate with
  `npx ts-node scripts/capture-admin-contract.ts`.
- **Contract churn resolved.** Work captures anchored fixture rows to a fixed
  date but ran through the controller, which ages against the real clock — so
  six committed contracts rewrote themselves **every midnight**, in two repos,
  and a tree nobody had edited came up dirty. That is a staging hazard as much
  as a correctness one. The capture clock is now **pinned**
  (`atContractNow()` in `admin-work-capture.ts`). Do not replace it with a
  real clock or with post-hoc field normalisation — an earlier attempt froze
  `openedAt` and broke 14 renders, because a contract saying an item was
  opened 2026-01-01 *and* is twenty days old is not renderable.
- **Loading state captured across all seven areas** — the state every operator
  sees first and nobody had looked at. All seven hold their shape (name,
  section headings and navigation affordances live before data arrives).
  Held still with a transport that never answers.
- **Below-the-fold reachability asserted** at 1440×765 for DISCOVERY and
  PLATFORM. This exists because a live browser check produced a confident
  **false negative** — see §E.
- **`AdminPermissionGuard` 403** that made the worklist never work — fixed.
- **Probe-latch bootstrap stall** — fixed.
- **Sole-owner protection:** the last owner of an institution cannot be
  revoked; rendered and asserted.
- **Moderation subject naming** closed.

---

## D. Open work — TRANSFERRED to Claude-2, not deferred

### D-1. ANDROID operator proof

- **WHAT IS MISSING:** the operator journey has never been exercised on
  Android. Web and Windows have been.
- **WHY IT REMAINS:** no AVD configured on this machine; no physical device in
  the loop for this pass.
- **AVAILABLE HARNESS:** `integration_test/operator_hub_certification_test.dart`
  runs unmodified on Android (`flutter test <path> -d <device>`); it needs no
  backend. `integration_test/android_return_path_test.dart` and
  `av_android_certification_test.dart` exist as precedent for Android lanes.
  Codemagic has been used for this project's builds (app id
  `6a0fbf3fcbbc949b570fbb23`; token at `$SP/.cm_token`, plain `curl` with
  `x-auth-token`).
- **EXPECTED PRODUCT BEHAVIOUR:** mobile is **not a reduced subset**. All seven
  areas present; every navigation target ≥48dp; capability-poor operators told
  rather than blanked; no area rendered as a desktop console with a phone
  build attached.
- **RELEVANT PATHS:** `lib/features/admin/**`, `integration_test/operator_hub_certification_test.dart`
- **KNOWN BLOCKER:** AVD provisioning, or a connected device.
- **NEXT EXECUTABLE ACTION:** create/boot an AVD (or attach a device), run the
  operator hub certification against it, then walk NOW→WORK→SUBJECTS→
  INTEGRITY→PLATFORM→RECORD→DISCOVERY and capture what an operator sees.

### D-2. iOS operator proof

- **WHAT IS MISSING:** same journey on iOS.
- **WHY IT REMAINS:** iOS builds require a macOS host; none available here.
- **WHAT IS STRUCTURALLY SHARED:** the entire Admin surface is Dart/Flutter
  with no platform channels in the operator path. Layout, authority gating,
  capability messaging, touch targets and state vocabulary are shared code and
  are already proven on Windows + widget matrix at six widths.
- **WHAT CAN BE CERTIFIED IN CI/SIMULATOR:** the whole operator hub
  certification, unchanged, on an iOS simulator in a macOS CI lane.
- **WHAT GENUINELY NEEDS NATIVE/PHYSICAL EVIDENCE:** only things touching
  platform services — notification presentation, background/terminated
  delivery, and any media/camera path reached from identity evidence. Those
  are *not* in the Admin operator path proper.
- **NEXT EXECUTABLE ACTION:** run the operator hub certification on an iOS
  simulator via the existing macOS CI lane; escalate to physical hardware only
  for platform-service items, and name which.

### D-3. STALE state

- **WHAT IS MISSING:** no Admin surface is proven in a *stale* state.
- **WHAT CAN GO STALE, concretely:**
  - WORK summary/list — an authority answered earlier and has since changed
  - NOW health/providers — a snapshot with a `checkedAt` in the past
  - DISCOVERY coverage — evidence from the last Collect, not from now
  - PLATFORM media-retention status — last pass may be old
  - SUBJECTS detail — standing/verification changed elsewhere
- **INTENDED BEHAVIOUR (to be confirmed against `OperatorSignal` vocabulary):**
  stale data is shown **with its age**, never silently as current, and never
  blanked. The vocabulary already distinguishes unavailable from empty; stale
  must not collapse into either.
- **SURFACES REQUIRING PROOF:** NOW, WORK, DISCOVERY, PLATFORM.
- **NEXT EXECUTABLE ACTION:** add render cases to
  `test/admin/operator_render_harness_test.dart` using the existing `inspect`
  hook and a transport that answers with deliberately old timestamps.

### D-4. RECOVERY state

- **WHAT IS MISSING:** the path *back* from failure is never rendered.
- **CASES TO DEFINE AND PROVE:**
  - network failure → retry succeeds
  - authority failure (`/admin/me` unreadable) → re-entry succeeds
  - partial-source failure (one of seven authorities down) → that source
    recovers while others were fine throughout
  - explicit refresh / re-entry into an area
  - session or auth change mid-session (sign-out, token rotation)
- **NOTE:** partial-source *failure* is already proven
  (`WORK · one authority down`); what is missing is the **recovery
  transition**, i.e. that the console returns to a correct state rather than
  keeping the error.
- **NEXT EXECUTABLE ACTION:** extend the render harness with a transport whose
  answers change between pumps.

### D-5. PLATFORM / provider governance gap (inherited product input)

Provider review, compliance state, submission deadlines, signing-registration
status and the operator attention they need is a **PLATFORM/Admin concern**,
not an ad-hoc distribution-script concern. Not built. Do not lose it, and do
not build it during handoff.

### D-6. Six pre-existing client failures

All six are the **same surface**: the RECORD area's golden at all six widths.

| Field | Value |
|---|---|
| **TEST/SUITE** | `test/admin/operator_render_harness_test.dart` |
| **CASES** | `record · w320`, `w360`, `w390`, `w768`, `w1024`, `w1440` |
| **ASSERTION** | `matchesGoldenFile('goldens/operator/record_wNNNN.png')` |
| **CURRENT FAILURE** | `Pixel test failed, 0.03%, 412px diff detected` (w1440; others comparable) |
| **CLEAN-BASELINE REPRODUCED** | **YES** — identical six failures with all Claude-1 changes stashed |
| **CLAUDE-1 CANDIDATE CAUSED** | **NO** |
| **INVESTIGATED ROOT CAUSE** | **NO** — deliberately not investigated per handoff instruction |
| **CURRENT OWNER** | Claude-2, for causal classification |
| **PRODUCT CONSEQUENCE KNOWN** | **NO** |

**Unverified observation, flagged as such:** the failure is confined to one
area at every width, and RECORD renders audit history with dates/ages. A
clock-dependent value drifting in the golden would produce exactly this shape,
and that class of bug was found and fixed in the *work* contracts this pass
(§C). **This is a hypothesis, not a finding.** It has not been checked.

Proved not-caused-by-this-pass. **Not** proved harmless or safe to ignore.

---

## E. Landmines

1. **Shared-worktree collisions are real and have caused production
   incidents.** History: broad Admin staging swept 20 calling files onto
   `main` and stopped backend + media-worker deploys; a stale calling
   candidate capable of reverting Admin work; a later revert deleting calling
   work; stale candidates attempting to resurrect or delete unrelated
   Discovery/Admin paths.

   **Frozen rule — still applies even with a single active owner:**
   never `git add src`, `git add lib`, `git add test`, `git add .`,
   `git add -A` in a repo with concurrent workstreams. Use isolated
   worktrees, explicit owned paths, reconstruction from current `main`, exact
   candidate diff inspection, and remote refs as the durable authority.
   Before every commit: enumerate changed paths, classify ownership, verify
   staged paths, inspect the staged diff. Before every push: inspect the
   complete `origin/main..HEAD` diff.

2. **`test/admin/failures/*.png` are TRACKED** and are rewritten by any failing
   golden run. They will make a tree look dirty and will break `git stash pop`.
   Clean them; never stage them.

3. **A green unit suite does not prove the app boots.** Route paths compile
   only when an HTTP adapter is created; both the unit suite and the
   dependency-graph smoke boot miss it. (2026-08-20 crash loop.)

4. **Jest does not load `.env`.** ~58 suites "fail" without R2 vars exported.
   That is environment, not regression.

5. **Do not widen a provider's query window to make a result green.** See
   §C-Bing and the GSC lag defect.

6. **Identity custody** (§C-Identity) and **Discovery privacy** (§C-AURA_REFERRAL)
   are governed boundaries, not implementation preferences.

7. **The provider observational boundary** (§C-Bing) is enforced in our code
   because the credential does not enforce it.

8. **`_render` in the render harness unmounts the tree before returning** (it
   must, or the shell's periodic timer is reported as a failure in the *next*
   test). Anything asserted after it returns is asserted against an **empty
   tree** and will produce a false negative. Use the `inspect` hook.

9. **Release hold:** the founder personally triggers all store submissions.
   Engineering stops at certified artifacts plus instructions.

---

## F. Recommended next execution order for Claude-2

1. **Classify the six RECORD golden failures** (§D-6). Cheapest, and it is the
   only currently-red thing in the client suite.
2. **STALE and RECOVERY** (§D-3, §D-4). Same harness, same `inspect` hook,
   no new infrastructure, and they close the state matrix.
3. **Android operator proof** (§D-1). Highest-value platform gap; the harness
   already exists and needs no backend.
4. **iOS via simulator in the macOS CI lane** (§D-2), escalating to hardware
   only for named platform-service items.
5. **PLATFORM provider governance** (§D-5) when the founder authorises scope.

**Do not reopen** AURA_REFERRAL, GSC, Bing, institution semantics, feedback
lifecycle, identity custody, contract pinning or the bootstrap finding without
new evidence. Each has live proof or an explicit founder acceptance recorded
above.

---

## G. Foreground bootstrap — measured result and an explicit retraction

**Measured on the real Windows client** (real `AuraApp`, real `routerProvider`
with its redirect and admin-probe latch) with a transport answering instantly,
so any remaining gap is the client's own sequencing:

```
first frame                          =  942 ms
/v1/admin/entry                      = 2729 ms
/v1/admin/me                         = 4507 ms
settled                              = 6979 ms

ENTER /admin → authority requested   =   71 ms
```

**Interpretation — read this before quoting the numbers.** The absolute
timings are **NOT** production UX latency and must not be quoted as such: the
harness pumps frames synchronously and that time is included. The meaningful
causal measurement is **admin entry → authority request = 71 ms**.

### RETRACTED: the 16.2-second finding

An earlier browser trace put `/v1/admin/me` at **16.2 s** while its
dependencies completed at 1.2 s, firing in the same millisecond as a presence
heartbeat. **That evidence is invalid.** Chrome reported
`visibilityState: "hidden"` for every tab in that window, and a backgrounded
tab throttles timers to roughly one tick per minute, producing exactly that
shape for reasons unrelated to the product.

**There is no unresolved Admin performance defect.** Do not carry 16.2 s
forward as an open issue.

### The real defect this measurement found

`cachedAdminAuthorityProvider` (`lib/core/auth/admin_access_provider.dart`)
attached its sign-out listener **during its own initialisation**. `ref.listen`
takes a baseline read of its source, and reading `isAuthedProvider` for the
first time from inside another provider's build cascades into whatever else
listens to it — Riverpod forbids a provider mutating another while it is
building. **Which surface initialised first therefore decided whether the app
threw.**

It never surfaced in the browser (notifications initialise long before any
admin route is entered there, and a release build strips the assertion). It
fires immediately when `/admin` is the **first** route opened — exactly what a
returning operator with a bookmark does.

**Repair:** listener attachment deferred to a microtask, which drains before
the next frame, so the sign-out reset is established long before any practical
sign-out opportunity.

**Regression test:** `integration_test/operator_bootstrap_timing_test.dart`.
Its purpose is to (a) detect reintroduced dead time and (b) ensure authority
is never gated behind the presence heartbeat. It asserts a **generous
ceiling**, not a target — arbitrary millisecond performance is deliberately
**not** a product contract, and the test must not be tightened into one.

---

## H. Ownership

```
CLAUDE_1_NEW_IMPLEMENTATION   = STOPPED
ADMIN_ACTIVE_EXECUTION_OWNER  = CLAUDE-2
```
