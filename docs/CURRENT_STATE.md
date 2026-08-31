# Aura Release Client — Current State

**Last updated: 2026-08-31**

---

## Status

> **2026-08-31 — OPERATOR CONTROL PLANE: RECONSTRUCTED.**
>
> Management REJECTED the hub result below and the framing that came with it
> ("four bounded causes, not a reconstruction gap"), and ruled that the seven
> areas were a PRODUCT MODEL rather than a filing system for seventeen legacy
> routes. This entry supersedes the hub entry that follows it; the hub entry is
> kept because the migration register it records is still true.
>
> Full record: `docs/2026-08-31-operator-control-plane-reconstruction.md`.
>
> `OPERATOR_CONTROL_PLANE_RECONSTRUCTED = YES`
> `PRODUCTION_OBSERVATION_WITH_A_REAL_GRANT = PENDING`
>
> Client 2131 green (`--exclude-tags golden`), `dart analyze lib` 0 issues;
> backend 324 suites / 4047 green, `tsc --noEmit` clean.
>
> **THE PROOF METHOD CHANGED FIRST.** The console had been proved against
> fixtures written on the client side, which encode what the client already
> believes and therefore cannot fail — three shipped defects passed every green
> test. `aura-backend/src/admin/contract/` now builds 26 fixtures from the
> SERVER's own mappers and vendors them into `aura_final/test/contracts/admin/`.
> 63 backend conformance tests, 46 client ones, and the render harness draws
> from the same files.
>
> **DEFECTS FOUND AND FIXED BY THAT METHOD**
>
> * `listInstitutions` counted `_count: { members: true }` — every membership
>   row, removed ones included. The operator directory was the ONE surface in
>   Aura that counted people who had been removed: "6 members" beside a roster
>   of 5.
> * The same endpoint defaulted to VERIFIED, so every pending, suspended and
>   rejected institution was absent from the console's only institution list,
>   with nothing on screen to say so.
> * An institution subject was found by searching that filtered list, so a
>   suspended institution reported "No such institution" on its own page.
> * The work contracts were captured from the SERVICE, whose return value has no
>   `totalOpen`; the CONTROLLER adds it. The client defaulted the missing key to
>   zero and WORK read "All 0" above four open items.
> * `countActiveOwnerGrants` counted ROWS, so owner continuity was satisfiable
>   by two grants held by one person, or by a grant on a disabled account.
>   `countActiveOwnerHolders` counts people who can act.
> * Two authority bootstraps: `appAdminAccessProvider` and `adminMeProvider`
>   each fired `GET /v1/admin/me`, and the whole gated data layer waited behind
>   the second.
> * `kOperatorDesktopWidth` was 1180, so 1142 — an ordinary laptop viewport —
>   fell into an icon-only rail: the frozen IA as seven unlabelled glyphs.
>
> **WHAT WAS REMOVED, NOT RE-FACED.** PLATFORM's policy document (seven
> switches, including a maintenance switch reading ON while Aura served every
> request) and its Configuration dump of member ids and avatar URLs are GONE.
> A grep across the backend settles it: not one of those values is read by any
> runtime path. Nothing was wired up to preserve them.
>
> **INTEGRITY NOW CARRIES EVIDENCE.** A report showed "Reported post" and a
> cuid — an operator asked to act against content they had never been shown.
> `resolveReportSubject` serves what was written, who is answerable and when,
> and refuses to invent any of it: deleted content is withheld with its removal
> stated, a reported person carries no excerpt, a vanished target stays a
> reference.
>
> **RECORD NAMES ITS SUBJECT.** Person and institution targets resolve to
> canonical identity in one batched query per class. Everything else stays a
> reference — a record that invents a name for a deleted subject is worse than
> one showing an id.
>
> **SIX WIDTHS RENDERED**: 1440 / 1024 / 768 / 390 / 360 / 320, 94 pictures in
> `test/admin/goldens/operator/`.
>
> **OPEN**: production observation with a real grant; Android and iOS
> certification lanes; eight surfaces still without a captured contract (listed
> at the end of the reconstruction record).

<details>
<summary>Superseded — 2026-08-31, the hub migration this replaced</summary>

> **2026-08-31 — ADMIN OPERATOR HUB: RECONSTRUCTION COMPLETE.**
>
> Client `a2290b0` · backend `437c2fc`, both pushed; the backend deployed
> through the ordinary Railway path and its new routes probed there.
>
> `IMPLEMENTATION_COMPLETE = YES` · `RELEASE_CLIENT_CERTIFICATION_COMPLETE = NO`
>
> Client 2122 green (1 skipped), backend 322 suites / 3974 green, Windows
> desktop certification 10/10 on the real client.
>
> Full record: `docs/2026-08-31-admin-operator-hub-reconstruction.md`.
>
> **THE MIGRATION REGISTER IS EMPTY.** All seventeen legacy admin routes are
> migrated into the frozen IA — NOW → WORK → SUBJECTS → INTEGRITY → PLATFORM →
> RECORD → DISCOVERY — and every screen behind them is DELETED, not left
> unrouted. `/admin/migrations` is retired as a destination; the convergence
> audit TABLES survive untouched.
>
> **AUTHORITIES INTRODUCED**
>
> * `features/admin/domain/operator_capability.dart` — capability truth, read
>   from the fields the server actually sends. The previous model read `role`
>   and `permissions` while the server sends `roles` and
>   `effectivePermissions`, so the permission list was ALWAYS empty. That is
>   very likely why nobody ever built gating on it, and why a MODERATOR holding
>   4 permissions saw the same fourteen destinations as an OWNER holding 25.
> * `features/admin/domain/operator_area.dart` — navigation DERIVED from
>   capability. An area an operator cannot enter is not drawn.
> * `features/admin/ui/operator_action.dart` — the governed ceremony:
>   INTENT → CONSEQUENCE PREVIEW → CONFIRM → ACTION → OUTCOME → RECORD. The
>   preview is the part that was missing everywhere.
> * `features/admin/areas/discovery_area.dart` + backend
>   `src/discovery-intelligence/` — the seventh area. OBSERVATION ≠ CONTROL:
>   no path publishes, retires or submits anything.
> * backend `src/media/media-retention.service.ts` — media retention finally
>   RUNS. The cleanup job was reference-safe and had a dry run from the day it
>   was written, and nothing ever scheduled it.
>
> **THE DISCOVERY FINDING (verified against production 2026-08-31)**
>
> Aura's sitemap advertises 19 URLs, all static marketing pages, and ZERO
> canonical `/p/` share URLs — while those same canonical URLs are
> demonstrably crawler-reachable and serve real cards. Every article, profile,
> institution page and announcement is findable and never advertised. Surfaced
> as a finding awaiting a ruling; fixing it would be control, which this area
> is frozen against.
>
> **NOT CERTIFIED:** Android and iOS were not exercised (the Windows lane runs
> headlessly; Android needs an AVD and iOS needs macOS). Production observation
> of the console with a real grant is owed.

---

> **2026-08-27 — RICH CONTENT MEDIA: IMPLEMENTATION COMPLETE, RELEASE
> CERTIFICATION PARTIAL.** These are different claims and are recorded
> separately on purpose.
>
> `IMPLEMENTATION_COMPLETE = YES` · `RELEASE_CLIENT_CERTIFICATION_COMPLETE = NO`
>
> Frontend `e60fae5` · backend `67267bf`. Frontend 1738 green, backend 296
> suites / 3649 green.
>
> **AUTHORITIES INTRODUCED**
>
> * `media_interaction_profile.dart` — layer 4, which did not exist. The viewer
>   had ZERO references to `defaultTargetPlatform`/`kIsWeb`/`Platform.is`, so a
>   desktop pointer model shipped byte-identically to phones. Touch is decided
>   by INPUT MODEL, not OS: a browser on a phone is a touch client.
> * `immersive_presenter.dart` — retires the closed `if (item.isVideo)` switch.
>   Presenters DECLARE capability; chrome is assembled from capability ×
>   platform. This is what makes `Open original` primary exactly where Aura
>   cannot present the media, and secondary everywhere else.
> * `aura_media_group.dart` — ordered collage. The feed rendered
>   `item.media.first` while the backend had always shipped an ordered array.
> * `aura_composition_strip.dart` — one composition preview for every composer.
> * `media_acquisition.dart` — one selection, images and videos together.
> * `media_origin_label.dart` / `media_origin_disclosure.dart` — item-scoped
>   labels, and the first product path to `UPLOADER_DECLARATION`.
> * backend `media-distribution.authority.ts` — `MAY_VIEW ≠ MAY_EXPORT ≠
>   MAY_DOWNLOAD_ORIGINAL`; `provenance/origin-ingestion.ts` — the first
>   production producers for a model that had zero callers.
>
> **AUTHORITIES CONVERGED**
>
> * `create-institution-post.dto.ts` gained `media[]`. `InstitutionPostMedia`
>   had carried `position` all along; the CONTRACT was the single-media limit.
> * The post composer's `_maxAttachments = 5` became the shared
>   `kMaxComposableMedia`, so the ceiling stopped depending on which composer
>   was open.
> * Announcement composers moved onto the canonical strip for visual media.
>
> **TRANSITIONAL PATHS STILL PRESENT** (each isolated, mapped in, documented)
>
> * `InstitutionPost.mediaUrl` — mapped INTO `media[]`, ignored when the
>   collection is supplied, never read beside it. New clients do not write it.
> * `_mediaId` / `_mediaUrl` in the institution composer — DERIVED from the
>   first item so draft persistence keeps working. Never the authority.
> * `MessageAttachment` — legacy dual-write beside the canonical
>   `MessageMedia`, which is the ordered authority.
> * Legacy flat `mediaUrl` on feed items — behind an explicitly named bridge.
>
> **EXTERNAL BOUNDARIES — NOT DEFERRALS**
>
> * `AURA_GENERATED_PROVENANCE` — the ingestion contract exists and is callable
>   (presign + `x-media-worker-token` + `auraGeneration`). No Aura generation
>   engine ships media into Aura: `aura-studio-backend` has no presign path at
>   all, and its own `PRODUCTION_ARCHITECTURE_BLOCKER.md` records that
>   NestJS/Railway cannot reach ACE — no public route, enforced by a regression
>   test. The producer does not exist to call the contract.
> * `VERIFIED_CREDENTIAL_PATH` — no C2PA library is installed, and
>   `ProvenanceTrustService` reads a `PlatformSetting` trust list that is empty,
>   so `trustedSigner` is false by configuration as well as by dependency.
>   Detection-only is correct and deliberate; presence is never recorded as
>   evidence.
>
> **CERTIFICATION RUN** — `integration_test/media_certification_test.dart`
>
> | Client | Result |
> |---|---|
> | Windows desktop | **23/23 PASS** — `canDecodeVideo=false`, source actions primary |
> | Android (physical Pixel 9a) | **23/23 PASS** — `pointer=touch`, no zoom cluster, source actions secondary |
> | Web / browser | widget layer green in Chrome; automated video DECODE unavailable |
> | iOS | **UNVERIFIED** — no macOS host. No claim inferred from Android. |
>
> The two native runs are the interaction contract's real proof: identical code
> resolving opposite answers from one measured capability fact.
>
> **STILL OWED** — physical iOS, and a live product pass on real uploaded and
> recorded media through the deployed clients. Automated certification exercises
> the widgets and authorities, not a person actually composing a post.

> **2026-08-26 — STORED VIDEO PRESENTATION IS NOW A PLATFORM AUTHORITY.** A
> video shared into a post rendered as a broken-image glyph. The cause was not
> the post card: the backend sets a thumbnail for images only, so `thumbUrl` is
> null for EVERY stored video, and four surfaces each improvised over the
> absence — three of them by handing an MP4 to an image decoder.
>
> The fix is layered, not local. `stored_media.dart` resolves what a media
> object IS; `aura_stored_media.dart` decides what it looks like inline through
> a presenter REGISTRY rather than a closed switch; `AuraVideoSurface` is the
> one video primitive; `AuraMediaViewer` still owns fullscreen.
> `CanonicalMediaThumb` is a consumer of that stack, not its owner.
>
> Migrated: posts (cards + compose), conversation, correspondence, institution
> spaces, announcements, institution posts + composer, meeting stored
> recordings, and the legacy flat-`mediaUrl` path (behind an explicit,
> named bridge). Conversation's private `_MediaPlayback` fork is RETIRED.
> Realtime is untouched.
>
> Recorded and uploaded video converge on the same object model, so both take
> the same path.
>
> **Platform truth, stated rather than assumed:** `video_player` resolves no
> Windows or Linux implementation. `storedVideoCanDecodeInline()` returns false
> there and NO decode is attempted — the surface shows an honest identity tile
> instead. This is also why the poster is produced server-side (aura-backend
> `docs/2026-08-26-stored-video-poster-derivative.md`): a JPEG works everywhere.
>
> **Not yet certified live** — deployed behaviour is owed on Web, Android and
> Windows with real uploaded and recorded video.

> **2026-08-25 — MEETINGS §11 ACTIVE WORKSPACE RECONSTRUCTED.** The room now
> keeps the meeting's identity, participants and elapsed time legible while the
> transport is connecting or failing — they were rendered under a 93% scrim and
> invisible. The ended overlay names what continues. The record's loading,
> error and canonicalising states lost their full-surface spinners.
>
> Two shared primitives I had duplicated (`MeetingSection`, `MeetingStatusChip`)
> were folded back into the canonical ones.
>
> **Returned to the founder, not fixed:** `GET /meetings/:id` is never
> requested in the affected session state — measured, both routes, no 4xx/5xx,
> every other call inside 1.45 s. The record does not load slowly; it does not
> load. Cause is upstream of Meetings (shared auth or institution identity).
> `MEETING_RECORD_PERFORMANCE = BOUNDED`.
>
> Certified: Windows native 14/14 real session; Pixel 9a 14/14 (10 exercised,
> 4 skipped, no session). No A/V machinery touched.

> **2026-08-25 — MEETINGS WORKSPACE RECONSTRUCTION EXECUTED (B0–B8).**
> The Meetings audit of 2026-08-25 is the frozen baseline; all 23 open findings
> are closed, including the three P0s. Four founder rulings implemented:
> **R-1** Live is not established and the vocabulary is now enforced code;
> **R-2** `NO_RESPONSE` converged onto `PENDING` and `MeetingAudience` is
> non-nullable with a tested backfill; **R-3** a Meeting references one
> canonical Conversation, created lazily; **R-4** Meetings is admitted to
> `ReturnPathAuthority`, with live CALLS exempt by behaviour rather than the
> whole domain by name.
>
> Six defects were found by doing the work and are listed in
> `docs/meetings/2026-08-25-meetings-reconstruction.md` — including a personal
> meeting card that navigated to `/home`, a refused participant who watched a
> spinner forever, and an attendance `noShow` count that was structurally
> always zero.
>
> **Certified:** Windows native 11/11 with a real session; physical Pixel 9a
> 11/11 (7 exercised, 4 session-dependent skipped). iOS `NOT_EXECUTED`.
>
> **COMMITTED, PUSHED AND DEPLOYED 2026-08-25** — client `a6a82df`, backend
> `6223286`. Migration `20261003000000` applied in production and verified
> against the live database: `Meeting.audience` is NOT NULL with default
> `PRIVATE`, **0 nulls remaining**, 120 meetings backfilled (GUEST 112,
> INSTITUTION 6, PRIVATE 2); `Meeting.conversationId` present. The new
> endpoint answers 401 rather than 404 — routed and guarded — and the service
> held steady across repeated probes.
>
> The next chapter is **AUDIO / VIDEO CALL SYSTEM RECONSTRUCTION**, against the
> Meetings-facing contract this chapter produced. Live Broadcast follows it.

</details>

> **2026-08-24 — DISCOVER RECONSTRUCTION CLOSED (founder-directed chapter).**
> Discover is a live, curated, actionable discovery dashboard across exactly
> four domains — People, Spaces, Institutions, Articles — with search operating
> inside the surface rather than redirecting to a separate product.
>
> The next chapter is **MESSAGES**, plan first. Meetings and Live remain
> deliberately untouched; two-party active-media certification stays held.

### What Discover became

**Three layers, separated on purpose.** Eligibility answers "may this viewer
discover this object at all" and is the only layer that reads candidates from
the database. Relevance receives ids and may reorder or drop them, never add.
Presentation is the surfaces above.

The boundary is structural, not editorial: `EligibleId` is branded with a
module-private symbol, so nothing outside the eligibility service can construct
one, and the composer builds its output by walking its input. Adversarial
property tests point hostile providers at it — smuggling a private object with
an overwhelming score, and an empty eligible set that must stay empty.

**Relevance is composed per domain, not one global ladder.** People rank from
the relationship graph; Spaces from topic affinity and shared participation;
Institutions from relationship, subject matter and place; Articles from author
relationship and recency. Signal providers are independent and additive, so one
that throws is logged and dropped rather than blanking a section.

**Cold start is a floor, not a branch.** Curated public standing contributes a
small weight in every domain always, so it breaks ties for an established
viewer and carries the whole ranking for a new one — with no separate code path
that can be missed, which is exactly the defect repaired in People discovery.

**Topic affinity is derived, never stored.** What the viewer wrote, responded
to, and follows, recomputed per read. A plain topic-weight map that can be
printed and explained, not an embedding.

### Domains and their destinations

| Domain | Landing | Destination |
|---|---|---|
| People | horizontal identity run, request-to-follow inline | `/discover/people` |
| Spaces | environment tiles with live participation | `/spaces` |
| Institutions | restrained presence cards | `/discover/institutions` |
| Articles | editorial rows, cover-led | `/discover/articles` |

The 24-sector ontology lives inside Institution discovery, where it narrows the
eligible set server-side. It is not on the general landing: a classification
wall would make institutional taxonomy the acquisition premise, and no
institution currently carries a classification, so every sector chip led
nowhere.

### Search

One surface, four states: no query is the dashboard, a query becomes
cross-domain discovery in place, a domain chip narrows without losing the
query, clearing restores the dashboard. State lives outside the widget, so
opening a result and returning restores query, narrowing and scroll.

The legacy search screen is retired. `/search?q=` still resolves — governed tag
taps produce it — by rendering this surface with the query seeded. Posts are
deliberately not a Discover domain; Home owns ongoing discourse.

### Public browsing

`/discover`, `/spaces`, `/institutions` and `/search` are PUBLIC by route
classification. The discovery endpoints are auth-only because relevance is
personal, so a signed-out viewer reads the public projections that were already
public — the same objects, no relevance reason, no follow state. Nothing became
discoverable that was not already.

### Follow, corrected

Person-to-person following is **consent-required**: request, then accept.
`POST /follows` refuses USER → USER outright and names
`POST /users/:handle/follow/request`. The People card had hand-rolled the wrong
call to the wrong authority, so Follow had been silently broken there and on
the People screen. Institutions and Spaces were unaffected — different
authorities.

**Open data gap:** the request endpoint is addressed by handle, so a person with
no handle cannot be followed at all. The control is not offered rather than
offered-and-broken. Recorded, not worked around.

---


## Previously

## Status

> **2026-08-22 — RELEASE-CLIENT CLOSURE AUTHORISATION: 2 of 4 MUST-CLOSE items corrected, 2 OPEN.**
> Reconstruction is **NOT** closed.
>
> **Attention converges with reading.** Reading a conversation could not clear its
> badge: `notifyRecipients` wrote the `Notification` table directly, so the row carried
> its destination only in `data.conversationId` and had **no relational target** —
> `markReadForTarget` matches on columns and could never match it. Its dedup key
> embedded wall-clock time, so the `(userId, dedupKey)` unique index could never
> collide and dedup was structurally impossible. Proven in production before the fix:
> unread-count 22 → mark the conversation read (201) → unread-count still 22.
> A conversation is now a first-class notification target (column + FK + backfill),
> both bypass producers route through the canonical service, `markRead` clears
> attention **server-side** so no client can forget, and the screen refreshes the count
> so the person does not watch their own read messages counted for 120s.
> **SAVE notifications** were the last consumer of the legacy `Communication`-only
> path — emailed, invisible in-app. Also converged.
>
> **Refresh continuity NOT reproduced, and therefore NOT closed.** `/home` survived 7
> consecutive reloads and `/saved` 5, authenticated and unchanged; every route family
> tested preserved both destination and render. RC1/RC2/RC3/RC9 verified closed in
> current code. Two apparent failures during this work were **my instrument** —
> `/auth/refresh` rotates the cookie and a harness reusing one single-use token
> exhausts the chain mid-run; controls disproved both. Not reproducing is not evidence
> of correctness: the founder's screen and sequence is the missing input. Untested:
> native binaries, institution-affiliated accounts, institution workspace routes.
>
> **Meetings/Live audited, NOT closed.** Both one-way-media repairs are **reverted and
> not in effect** — `9815742` by `4420602`, `381c452` by `a77b62e` (which also deleted
> `silent_peer_repair_test.dart`). Current main has neither repair nor test.
> `merge-base --is-ancestor 381c452 HEAD` says YES — the commit is in history and so is
> its revert. One-way media can still occur; leave/rejoin remains the workaround.
> Re-landing reverted realtime work blindly is forbidden and `9815742` already failed
> founder certification; certification needs two live participants.
>
> Record: `aura-backend/docs/2026-08-22-release-client-closure-attention-and-continuity.md`


> **2026-08-22 — CH-14 CLOSED. Founder-certified on the live article.**
> Articles are first-class publications: reactions, saves, discussion, native reshare,
> external share with real OG, translation, notifications, blocking, moderation,
> Discourse Quality, retract/restore, media interaction, accessibility and canonical
> deep linking are all implemented, certified and deployed. The founder confirmed the
> article action row on the live reader — the last item that required observation
> rather than a test.
>
> **One continuity model replaced four.** Boot, refresh, deep-link return and release
> were the same problem: the router treated *restoring* as a destination and navigated
> to `/_boot?redirect=…`. It now stays put and `BootGate` renders in place — and
> renders **instead of** the routed child, so a destination cannot fire requests while
> authentication is unknown. `bootRedirectFor`, `_bootParkFor` and the duplicate boot
> screen are retired; nothing emits `/_boot`. F065, F068 and RC4 are all preserved —
> F068's bounded, honest wait **moved** to `BootGate` rather than being weakened.
> Evidence: all **171 registered routes** walked, plus 8 representative classes driven
> through the real router.
>
> **`/og/*` retired** to 301s carrying no resolution logic; `/p/*` is the sole canonical
> external identity. The share-return matrix passes **7/7 families** from external URL
> back into Aura, with the transit page no longer painting.
>
> **Release is not navigation either.** A running client now detects a new build from
> `flutter_bootstrap.js` and offers a reload that preserves the current URL; nothing
> reloads by itself.
>
> **Translation length is a cost question, not a capability.** Segmented translation
> with per-segment caching, byte-for-byte reassembly, and partial failure reported as
> failure rather than returned half-done.

> **2026-08-21 — canonical accounting reconciled; Meetings realtime parked.**
> `RECONSTRUCTION_REGISTER.md` was regenerated through its own generator after four days of
> execution-layer facts had accumulated without being printed. **Nothing was lost** — 192 → 238
> lines, zero items dropped — and fifteen items became visible that were already recorded:
> the F059/F061/F062/F063 transitions of 2026-08-19, F053/F116, F137, F044, the G1 leg 5(B),
> Institution Spaces and CH-12 E6 live certifications, the CH-12 web-consumer certification
> **correction**, and the three admitted execution defects.
>
> **The register's distribution table was mislabelled.** It reads from Stage-0 evidence, which
> is never rewritten — correct and deliberate — but it was headed *CURRENT STATE DISTRIBUTION*,
> so a 2026-08-18 baseline read as a live count and every later movement was invisible. It now
> says **STAGE-0 RATIFIED STATE DISTRIBUTION** and points at the sections that carry the
> movement. That single mislabel is what made the accounting look stale.
>
> **Accounting unchanged and independently re-proved: 143 findings + 308 obligations = 451
> units across 17 chapters.** `17/17` means chapter *accounting coverage*, never completion —
> **no chapter has closed.** `138` remains a historical checkpoint and must never be quoted as
> a live counter.
>
> **Meetings realtime investigation CLOSED by founder ruling.** Production stays reverted at
> `4420602`; `9815742` FAILED founder production certification and is historical evidence, not
> an accepted repair. One-way media can still occur and **leave/rejoin remains the working
> workaround**. Full disposition:
> `docs/2026-08-21-meetings-realtime-certification-disposition.md`.
>
> **Articles are not established as a first-class publication surface** —
> `ARTICLES-FIRST-CLASS-DEFECT`, admitted to CH-14 through the execution-defect mechanism,
> accounting unchanged. The Article cover capability is separate and is **not** first-class
> publication completion.
>
> **CH-12.** E6 live-certified against backend `3faa46d`; E8 complete; the F137 adjudication
> against the original frozen D4 criteria records *"F137 is CLOSED"*. `CLOSED` is not a
> register terminal state, so F137 sits at `STRUCTURALLY_CLOSED_NOT_LIVE_CERTIFIED` pending a
> founder ruling on whether that adjudication constitutes `FOUNDER_CLOSED`.
>
> **Same-origin media delivery incident CLOSED**, founder-verified in the released product
> (backend `fc2bd71` / frontend `3f24f94`). It also *corrected* a CH-12 claim: the web-consumer
> leg had been certified on a signed URL that never exercised the Flutter Web / CanvasKit
> CORS-read path.

> **2026-08-20 — G1 leg 5 COMPLETE; CH-12 entered.**
> Founder observed the predeclared leg 5(B) test live: a plain-text file renamed to `photo.png`
> was **rejected** by the live attachment flow. All four predeclared properties reconcile PASS, so
> **leg 5(B) is LIVE_CERTIFIED** and, with 5(A) already complete, **G1 leg 5 is COMPLETE**. That
> was the programme's single recorded choke point; **CH-12 Media Custody, Delivery & Processing is
> now executable and has been entered.**
>
> **F137 confirmed OPEN by forensic assessment, not by its sentence.** No malware scanning,
> malicious-document or archive-content examination, media decoding, metadata extraction,
> provider-side examination, async post-upload examination or quarantine exists anywhere.
> Signature detection is **not** scanning: content truth answers *what is this file*, never *is it
> harmful*. **`READY` does not mean examined.**
>
> **Closed this pass — F127's residue, not F137.** The institution-post door resolved type from the
> storage transport header, which the client sets on its own presigned PUT, and never read a byte —
> so the exact file the founder watched Aura refuse could enter there and be created `READY`. Both
> doors now share one inspection helper and one authority. No new finding: this is inside F127's
> recorded "anywhere" scope.
>
> **Founder decision owed** before genuine examination can be built: the engine choice (self-hosted
> ClamAV vs managed API vs neither). No provider integrated, no credential added, no cost incurred.
> Record: `aura-backend/docs/2026-08-20-ch12-f137-forensic-assessment.md`.


> **2026-08-20 — native release-cutover workstream CLOSED (founder ruling).**
> Maintenance policy live on `android-direct` and `ios`; **14 legacy endpoints 404 in production**;
> `POST /spaces/:id/invites` and `GET/POST /threads/:id/invites` retained on live consumers;
> canonical realtime rehome healthy with `CorrespondenceModule` absent; active
> `/me/correspondence` production **zero** in both repos. Live: backend `9b51bc7`,
> frontend `4284763`.
>
> **Accepted limitation:** already-installed Android/iOS binaries carry frozen client code and may
> show "This section ran into a problem" instead of the August 22 explanation. The server returns
> `maintenance / show_maintenance` correctly. Not a blocker, and not a reason to reopen anything;
> any pre-upgrade messaging belongs to a store-listing or release-note path.
>
> **Carried forward, not complete:** F044 live observation · F053/F116 live certification · the
> upgraded native release and its ClientPolicy transition (August 22, no automatic authority) ·
> destructive persistence cleanup only if ever separately authorised.
>
> **Lesson kept, no new machinery:** server-side correctness is not evidence of user-visible
> correctness — this chapter produced three versions of it. And HTTP 200 proves availability, not
> that the intended release is live; certify with a build/content marker instead.


| Track | State |
|---|---|
| **Aura Public-First Causal Doctrine** | ✅ **FOUNDER-FROZEN / ADOPTED** (2026-08-15) — interpretive lens for all product work; canonical source in Representation |
| **Public-first general-entry copy** | ✅ **RECONCILED / LOCALLY CERTIFIED** (2026-08-15) — C-1…C-4 resolved; gate at `test/doctrine/` |
| **Backend construction baseline** | ✅ **FROZEN** (aura-backend, commit `2a92a0e`) |
| **Frontend product-architecture adjudication** | ✅ **COMPLETE / FROZEN** |
| **Final frontend reconstruction roadmap** | ✅ **FOUNDER APPROVED / FROZEN** |
| **C0 — Cross-Cutting Foundations** | ✅ **COMPLETE / FOUNDER APPROVED / LOCALLY CERTIFIED** (2026-08-15) |
| **C1 — Acting Context & Capability** | ✅ **COMPLETE / FOUNDER APPROVED / LOCALLY CERTIFIED** (2026-08-15) |
| **C2 — Identity / Presence / Profile** | ⛔ **READY / NOT STARTED / NOT YET AUTHORIZED** |
| **Frontend implementation (C2–C11)** | ⛔ **NOT STARTED** |
| **PD-1 Platform Administration** | ✅ **RESOLVED** (founder ruling 2026-08-18) — `OUT_OF_CURRENT_RECONSTRUCTION_SCOPE`. NOT deprecated, demolished or removed; 11 files / 52 debt sites `FROZEN_BY_RULE`. `/admin` route classification still applies — scope exclusion is not a security bypass. |
| **PD-2 Authentication & Account Entry** | ✅ **RESOLVED** (founder ruling 2026-08-18) — split ratified: **CH-02 owns STRUCTURE, CH-10 owns ACCOUNT-ENTRY EXPERIENCE**. Seam enumerated in `docs/governance/CH02_DESTINATION_RECONSTRUCTION_CONTRACT.md`. |
| **Portfolio reconstruction — Wave 1** | 🟡 **PART 1 + PART 2 EXECUTED** (2026-08-18) — W1-000/A/B/F and W1-C/D/E done. **No chapter closed.** F065 live refresh proof OWED (PB-11 founder observation). See `docs/portfolio/PART2_EXECUTION_RECORD_2026-08-18.md`. |
| **Portfolio reconstruction — execution-first (CH-13)** | 🟡 **IN PROGRESS** (2026-08-19) — F011/F125/F014/F025/F026 implemented, live certification OWED for all five. **F017 `FOUNDER_CLOSED`** by ruling on production evidence (zero eligible rows; no mutation performed). **F135 implemented** (2026-08-19) — link-preview images now delivered by Aura, never fetched from the third-party host by the viewer. CH-13 finding-level construction **exhausted**. ~~(its 26 obligations are all RC-C5, behind the frozen hard gate)~~ — **CORRECTED 2026-08-21 by founder ruling: the RC-C5 gate DOES NOT TRANSFER.** The 26 are *chartered by* RC-C5, which is provenance, not authorization inheritance. They are released from that gate and remain subject to their own dependencies. **CH-02 refresh continuity** — RC1, RC7-articles, **RC2 + RC3** done: institution route restoration now runs through one canonical authority that separates *unresolved* from *absent* and validates the URL's institution against real membership. **RC4, RC7-compose and the RC3 screen-binding half now done too** — `/institutions/me` is scopeable to a held institution, so a second institution's workspace reconstructs honestly. **F059 and F062 → IMPLEMENTED_NOT_LIVE_CERTIFIED**; F061/F063 remain OPEN. **RC8 executed under narrow founder authorization** (booking/reschedule/meeting-entry navigation only) and **RC5** done. All four findings now IMPLEMENTED_NOT_LIVE_CERTIFIED. **MEETINGS BEHAVIOR PRESERVED** — 31 frontend + 125 backend meeting/booking tests pass. **RC6 + RC9 done — all nine ranked shared causes (RC1–RC9) are now repaired.** RC6 closed a real authorization hole: the institution-admin gate matched only the two shorthand routes, which RC2/RC3 had turned into pure redirects, so it could no longer fire. What remains for CH-02's four findings is **live certification only**. **CH-03 F053/F116 started 2026-08-19**: the client's canonical person identity model now exists (the counterpart to the backend's `PERSON_IDENTITY_SELECT`), and identity debt fell **66 files / 202 sites → 49 / 131** across two batches, with the ratchet re-frozen at each verified reduction. Backend producers now compose `PERSON_REFERENCE_SELECT` (admin-hub 21 sites → 0); the narrow Meetings authorization was applied and **MEETINGS BEHAVIOR PRESERVED**. Debt **202 → 57 sites**. Private person models: 3 retired, 2 composed, the rest classified as different domain concepts. Backend Meetings person projections converged under narrow authorization — **MEETINGS BEHAVIOR PRESERVED**. Debt **202 → 29 sites**, and **every remaining site is classified**: 2 governed backend credential reads, 15 presentation-class CircleAvatar (identity already canonical), 9 non-person (institution/external account/branding), 3 real person sites. Debt **202 → 26 sites**; **zero true person debt at any surface**. The residue search found the real remainder: **63 typed boundaries still parse person fields independently**, so F116 criterion 2 is **NOT met** and both F116 and F053 stay PARTIALLY_VALIDATED. Two detector-design questions preserved for a separate ruling. **Both were ruled on and executed 2026-08-19**: the detector is now DOMAIN-AWARE (person vs institution vs external-platform account, by receiver, by assignment destination and by call subject - never by path or filename), and the rejected "all typed boundaries are debt" proposal was replaced by the enforcing `NON_CANONICAL_PERSON_DESERIALIZATION` concept, which is now ratcheted and PROVEN ENFORCING by a seeded violation. Three measurements are kept separate: surface person debt **11 files / 19 sites**, typed-person debt **62 -> 18 sites**, typed-boundary inventory **62 -> 20**. Migrated: blocks, follows, articles, conversations, feed post author, realtime participant, updates actor, admin hub (5 types), explore, support, and the two feed actors the backend proves are always people. `post_model.dart` DELETED - a 312-line dead duplicate carrying the exact competing alias chains. Remaining 18: **16 protected Meetings domain sites (not authorized this batch, measured not excluded)** and 2 deliberately polymorphic feed actors. F116 criterion 2 is now SUBSTANTIALLY MET and ratcheted; F116/F053 stay PARTIALLY_VALIDATED. Returned for founder decision: the `'Guest'` default on MeetingIdentityRef's **AURA_USER** branch (legitimate for a GUEST contact, the F054 invented-label defect for an identifiable Aura person), and authorization for the four Meetings domain models. **Both were granted and executed 2026-08-19 — CH-03 typed-person convergence is COMPLETE.** The four protected Meetings models and both feed actors are dispositioned, and **typed-person debt is 18 → 0**; surface debt is unchanged at 11 files / 19 sites, typed-boundary inventory 20 → 7. The founder ruling was implemented on both sides of the wire: an AURA_USER is never named `'Guest'` (client delegates to `AuraPersonIdentity`; `buildAuraUserBookerIdentity` stops emitting the string), while a genuine external CONTACT or GUEST **keeps** `'Guest'`, because for them it is a truthful statement of what they are. **PERSON IDENTITY ≠ MEETING ROLE / EXTERNAL PARTICIPANT TYPE.** The two feed actors were classified from their producers, not their field names: **FeedSignalActor is a true PERSON | INSTITUTION union** (union retained, person branch delegated, institution identity kept in institution terms so no slug can be read through a person-shaped accessor), and **FeedReplyAuthor is a person model** that had been accepting institution aliases (fully converged). One governed non-promotion is recorded: `MeetingEntryResolution.identityName` delegates its parsing but deliberately does **not** answer with the canonical label, because the pre-join screen pre-fills the entrant's own name box from it — 'Someone' would be typed into a stranger's name field. **MEETINGS BEHAVIOR PRESERVED** (frontend 810 pass, backend 205 suites / 2577 tests, analyze clean, 451/451 and 17/17 PASS). The typed-person ratchet is proven enforcing over the protected models by a new seeded-failure harness (`tool/meetings_person_ratchet_proof.mjs`) in **both** directions: the founder-named defect, a private alias chain and raw envelope parsing each make the gate FAIL, while the external GUEST fallback, meeting roles, the actor union and separate institution identity are all GREEN. **F116 and F053 both advance PARTIALLY_VALIDATED → IMPLEMENTED_NOT_LIVE_CERTIFIED**; all six F116 criteria are met. F052 gains structural evidence without promotion; F054 gains implementation evidence only; F055–F057 unaffected; **F051 preserved untouched as a conflict**. Named residue and next frontier: the **19 SURFACE sites across 11 files** where widgets still read person fields off untyped maps. No production polled or mutated. Record: `docs/portfolio/run/stage0-2026-08-18/05-execution/ch03-f116-meetings-guest-and-feed-actor-closeout.json`. **THE F116/F053 PROMOTION WAS HELD BY THE FOUNDER AND IS NOW WITHDRAWN (2026-08-19).** The reconciliation of the 19 measured surface sites found all 19 non-competing (11 presentation over already-canonical identity, 4 institution, 3 governed, 1 detector window catch - **zero** class A), so the inconsistency as posed did not exist. The promotion fails for the opposite reason: **the detector understated.** Its matcher saw `map['displayName']` but not `pick(map, const ['displayName', 'name'])` - and a list *is* a private alias order. Tracing the 19 to their producers surfaced real debt that was never counted: the app-shell header carried a complete private person reader (nested-envelope unwrap + its own name order), and the member directory carried its own avatar aliases, an invented `'Member'` label, and its own `/handle` address for a person **which the router does not declare** - so "open profile" from the member picker resolved to nothing. **11 class-A sites converged**; after converging all of them the gate still read 11 files / 19 sites - the number did not move, which is how a gate becomes decoration. The instrument was widened (alias-list detection, same-line receiver, enclosing type as the weakest and person-vetoed signal, canonical person model declared as authority); proof 13/13 -> **23/23**, and it caught a precedence bug in the extension before the baseline was frozen. Honest measurement now: surface **19 -> 29 sites / 16 files**, typed-person **0 -> 8 sites / 2 files** - **entirely instrument correction, zero new debt**, kept separate from the 11 real migrations. **F116 and F053 both remain PARTIALLY_VALIDATED**; criteria 2, 3, 4 and 6 NOT MET. Exact residue: **18 class-A sites** - 17 in the retirement-pending correspondence/conversations/messages family (incl. `CorrespondenceIdentity`, a second complete person authority) and 1 actor union in institution engagement. **One founder decision blocks closure:** converge identity inside surfaces pending retirement, or scope the work to surviving surfaces and let retirement discharge the rest. F051 preserved untouched. Record: `.../05-execution/ch03-f116-f053-promotion-reconciliation.json`. **RETIREMENT-OWNED RULING APPLIED + ROUTEDRECORD RESOLVED (2026-08-19).** Founder ruling: do not canonicalize person identity inside code already governed for removal — those sites become **RETIREMENT_OWNED STRUCTURAL DEBT**, still real, still visible, discharged only by physical deletion. The retirement owner was **already governed and only needed tracing**: **CO-RC-C7-005** (Phase 5 legacy retirement NOT AUTHORIZED; legacy hub parked at `/messages/legacy-hub`) plus **CO-RC-C2-010**, which had already assigned per-file owners (`conversations_screen` C4-retired; `correspondence_hub`/`space` C7). **15 of the 17 sites are retirement-owned**; **2 were rejected**: `mention_scope_providers` is `lib/core/tagging` serving the live `DirectThreadScreen` at `/direct/:threadId` — *depending on retiring code is not the same as being retired by it*, so no deletion would ever discharge it. Its person reader carried the same defects as the member directory (`avatar`/`image` but never `photoUrl`; `'Member'` invented) and is **converged**; its second site is institution identity. `conversations_screen` is additionally unreferenced by route, library and test — recorded as **unreachable but NOT proven dead**, because **FD-12** forbids exactly the naive zero-reference gate that would justify deleting it. **RoutedRecord: the union did not exist.** It read `['handle','handleOrSlug']`, but `InstitutionEngagementService.toDto` builds the author from a `User` relation via **PERSON_REFERENCE_SELECT** and never emits `handleOrSlug` — the client had invented an ambiguity the server never had. Repair was to stop reading a field that is never sent, **not** to add an actorType to discriminate a union of one: the author is now `AuraPersonIdentity`, no Actor model invented, no identity authorities merged, and **no route work** — `authorHandle` is never navigated. **ACTIVE EXECUTABLE PERSON DEBT: 2 -> 0.** Every person-identity site in the *surviving* product now resolves through the one canonical reader. Surface **29 -> 28**, typed-person **8 -> 7** (both real migration; detector **unchanged**, no legacy exclusions). **F116 and F053 stay PARTIALLY_VALIDATED** — criteria 2/3/4/6 NOT MET while 15 competing parsers remain physically executable. Non-identity defect observed and reported unfixed: engagement `postBody` reads `body` while the DTO emits `text`. F054 gains a third invented-label instance (evidence only). F051 preserved. Record: `.../05-execution/ch03-retirement-owned-debt-and-routedrecord.json`. **ENGAGEMENT CONTENT CONTRACT REPAIRED (2026-08-19)** — the non-identity defect surfaced by the RoutedRecord trace, now fixed. Canonical field established from the producer chain, not naming taste: `Post.text` (schema) -> `post.text` (EngagementRecordDto) -> `json['text']` (the client's own `feed/domain/post.dart`). The engagement model read `post['body']` with a `postBody` fallback — **two keys no producer has ever emitted** — so **the routed post rendered on neither engagement screen**. Root cause: the model was written against an assumed shape, and the later 'align with live API response shape' pass (3dac187) caught four sibling mismatches but not this one, because every consumer guards with `if (content.isNotEmpty)` — **a wrong key looks exactly like a post with no text**. **No alias used** (`body ?? text` would have made the mismatch permanent instead of fixed). Two same-class stale reads in the same parse were fixed with it: `createdAt` read a top-level key the DTO does not emit, so **both bylines were dateless** — now `post.createdAt`, deliberately **not** `routedAt`, which is a different fact (when the post reached the institution) and stays separate; `institutionId`/`updatedAt` were always-empty-by-contract and were removed (the backend spec already asserts institutionId is deliberately not exposed). Backend source **unchanged** — the producer was never the defective side; only its spec gained assertions. **8 new frontend tests** (incl. widget tests driving both real screens, because model tests could not have caught a defect that hides behind an emptiness guard) **+ 2 backend**; seeded proof: restoring `body` fails 4. Frontend **829 pass**, backend **205 suites / 2579**, tsc clean, Meetings 52 pass, identity gate unchanged. **No finding effects** — this was never an identity defect. Record: `.../05-execution/engagement-content-contract-repair.json`. **CO-RC-C7-005 PHASE 5 RETIREMENT READINESS AUDIT (2026-08-20) - NOT READY, and the blocker is bigger than the frontend.** Read-only audit; nothing retired, no production polled or mutated, no migration run. **(1) The history migration is a DATA migration and the deploy path does not run it** - `railway-start.sh` runs `prisma migrate deploy` then Nest, and nothing anywhere invokes `scripts/migrate-conversations.js`. Pushing and deploying therefore did **not** advance this prerequisite. **(2) There is NO compatibility layer**: `ConversationsService` reads only `Conversation*` tables and never touches `DirectThread`/`Space`/`Thread`/`Message`, so legacy history is reachable **only** through legacy surfaces until the rows are physically copied - deleting the family today would make every historical conversation unreachable. **(3) Eleven backend files still PRODUCE `/me/correspondence/...` deep links** (activity, attention x2, call-notification, communications, orchestrator, events, internal-reference, notifications x2, communication-live) against exactly one emitting the canonical `/messages/c/:id` - and those links are already persisted in production notification/activity rows. **(4) Correspondence is not merely parked**: `communication_resolver` routes into it from Activity and the incoming-live overlay, and `route_normalizer` normalizes into it. **(5) `correspondence_identity.dart` cannot be deleted by retiring the surfaces** - `mention_scope_providers` (8 utility calls) and the routed `invitations_screen` (7 invite helpers) still import it, so 7 of the 15 identity sites carry a MIGRATE-FIRST precondition; the count stays 15 and nothing was reclassified. Readiness matrix: additive deploy **PARTIAL**, history migration **NOT COMPLETE/UNKNOWN**, route+deep-link migration **NOT COMPLETE**, live observation **OWED and not yet meaningful** (observing before migration would certify an empty list as correct), certification **OWED**, manifest **READY** (5 MIGRATE_FIRST / 5 REMOVE / 4 RETAIN / 2 UNKNOWN), approval **NOT GRANTED**. Rollback is **code-only** - retirement deletes no data, migration is idempotent and additive, revert restores routes and the legacy rows are untouched; the real risk is address loss, not data loss. J1-J10 founder observation checklist + certification criteria recorded; J11 exists to CONFIRM the deep-link blocker, not to pass. **F116/F053 UNCHANGED at PARTIALLY_VALIDATED** (active 0, retirement-owned 15); F051/F052/F054-F057/CH-13/RC-C5/Meetings untouched. 451/451, 17/17, Stage-0 ratified. **Two founder decisions owed:** authorize the read-only migration-status query, and rule on persisted deep links (redirect vs accept-broken). Record: `.../05-execution/co-rc-c7-005-phase5-retirement-readiness.json`. **MIGRATION STATUS RESOLVED BY AUTHORIZED READ-ONLY EVIDENCE (2026-08-20): `NOT_APPLIED`.** Founder granted read-only production access; write protection was enforced **by Postgres**, not by intent (`SET SESSION CHARACTERISTICS AS TRANSACTION READ ONLY` + per-probe `BEGIN TRANSACTION READ ONLY`/`ROLLBACK`, with `SHOW transaction_read_only = on` captured as proof). Method committed as `aura-backend/scripts/c7-migration-status-readonly.js`. **Zero migrated rows of any kind** — `migrated_dt` 0 of 5, `migrated_dm` 0 of 9, `migrated_sp` 0 of 12, `migrated_m` 0 of 67. The 4 conversations / 20 messages already in canonical storage are **new-system rows** created since the additive deploy; none carries a migrated id prefix, and `ConversationHumanState` is **empty**, so no read state exists canonically at all. **Corpus has not drifted since the 2026-08-16 design measurement** — same counts, and the two named spaces are still 'Aura Internal' (WORKROOM, 3 members, 1 msg) and 'family' (CIRCLE, 2 members, 3 msgs). **Migration script safety audit: SAFE TO APPLY, no defect, script unchanged.** Every INSERT target matches the live schema; all three `ON CONFLICT` targets exist; and every apply-blocking data risk probed clean — NULL `body` 0, duplicate `(messageId,position)` 0 (which would have *errored* rather than skipped, since that unique index is not the conflict target), NULL `SpaceMember.userId` 0, `'system'` fallback unreachable, and **directKey collisions 0**, so all 5 DirectThreads migrate with pair identity intact. The script has no wrapping transaction — safe **only** because it is idempotent and restart-safe, stated plainly rather than left to look like a defect. **NEW SCOPE GAP FOUND:** the eligibility filter is `institutionId IS NULL`, so **institution spaces are not migrated at all** — 1 space / 1 thread / **2 messages**, which are exactly the 2 of 69 Space messages outside the eligible set. Probably deliberate (the C7 Institutional Conversation & Desk amendment is frozen separately) but **CO-RC-C7-005 does not name it**, and retiring the family would strand that history. **Deep-link mapping authority ESTABLISHED (founder ruling: persisted links must not break):** the mapping is **deterministic from the migration's own key scheme** — Space `<id>` becomes `sp:<id>`, DirectThread `<id>` becomes `dt:<id>`. No lookup table, no heuristic, no participant guessing. Backend owns new rows, a bounded frontend translator owns old addresses, and **no data mutation is needed** — persisted rows keep their stored address and resolve at navigation time. **Not implemented** — gated behind migration status. Additive deploy reported dimensionally: HTTP health **COMPLETE**, canonical runtime **COMPLETE**, history canonical **NOT COMPLETE**, old addresses reach canonical **NOT COMPLETE**, surviving consumers off retiring identity **NOT COMPLETE**. **NOT READY for founder live observation** (J1–J10 unchanged and still owed); **NOT READY for retirement authorization**. **F116/F053 UNCHANGED at PARTIALLY_VALIDATED** (active 0, retirement-owned 15). 451/451, 17/17, Stage-0 ratified. **Two founder decisions owed:** authorize the production migration apply (exact command + expected row counts recorded), and rule on institution spaces. **INSTITUTION SPACES RECONSTRUCTION — AUDIT COMPLETE, IMPLEMENTATION HELD ON FOUR FOUNDER DECISIONS (2026-08-20).** Founder ruled legacy message history has no strategic value and must not block reconstruction; the personal-history migration is **HELD, not run**, and no production data was deleted. **The decisive finding reframes the retirement itself: Institution Spaces and the 'legacy correspondence family' ARE THE SAME CODE** — `/institution/:id/spaces/:spaceId` and `/me/correspondence/:spaceId` both build `SpaceScreen`, distinguished only by a passed institutionId, and the institution thread route builds the same `ThreadStateWrapper`. **Retiring the correspondence family as previously scoped would have deleted the Institution Spaces product outright.** `space_screen.dart` is therefore **RECONSTRUCTION-owned, not retirement-owned** (15-site count unchanged; what discharges it changed). **Two frozen doctrines collide and only the founder can resolve it:** the Institution Space Membership Doctrine (FROZEN 2026-08-13) requires admin-governed roles and direct Add Member, while the Conversation canon freezes **ORIGIN ≠ GOVERNANCE**, omits participant removal in v1, and forbids **role vocabulary on ordinary conversations**. Full legacy inventory and a 21-row responsibility classification recorded (Thread/Message/attachments = LEGACY DUPLICATE DELETE; timeline/read/mute/archive = CONSUME CONVERSATION; attachments = CONSUME RICH CONTENT; calling = CONSUME REALTIME, **never Meetings**). **Production evidence settles cardinality on the merits:** the Thread table permits many-per-Space but **every one of the 13 production spaces has exactly one thread** — the multi-thread capability has never been used. **Deep-link policy corrected**: the bounded translator is now mostly unnecessary — only Space addresses need continuity, because only Spaces survive. **Executed and unblocked:** both surviving `CorrespondenceIdentity` consumers migrated off it, so it is now **retirement-local** (invite helpers relocated to `features/invitations/data/invite_presentation.dart`; `core/tagging` given a local generic picker). Honest consequence recorded: that relocation moved **five person-shaped positional reads into surviving code** where the detector cannot see them — documented in the new file, to be canonicalised when invitations is reconstructed, rather than smuggled into a retirement chore. **Meetings protected and untouched.** F116/F053 unchanged PARTIALLY_VALIDATED (active 0, retirement-owned 15). 829 tests, analyze clean, identity gate PASS, 451/451, 17/17, Stage-0 ratified. **D1-D4 RULED AND APPLIED; ADDITIVE RECONSTRUCTION IMPLEMENTED AND LOCALLY CERTIFIED (2026-08-20).** **D1 Option A**: Space governs membership/access, Conversation serves communication; parties are a PROJECTION of Space membership, built as **one synchronisation boundary** (`institution-space-conversation.authority.ts`) rather than scattered writes. **The Conversation canon is untouched** — no role vocabulary, no creator-admin semantics, no removal governance. `syncParties` **reconciles rather than deltas**, because a delta is only correct if every mutation path remembers to call it; a test applies three membership changes with zero notifications and still converges. **D2**: `Space.conversationId` (nullable, unique, FK), created **lazily** so pre-existing Spaces need no production backfill; `createInstitutionSpace` **no longer creates a Thread** — deleted, not renamed. **D3**: no realtime built and **no Space-local realtime stack**; the surface reuses `ConversationScreen`, so group realtime arrives later through `RealtimeSessionSurfaceType.CONVERSATION` with nothing to undo. **Meetings untouched, 52 tests pass.** **D4**: SpaceType and DISCOVERABLE are not read, rendered or offered anywhere in the new surface; the columns remain only because dropping them is destructive and unauthorised. **New capability the legacy product never had: Remove Member** — mirror of the frozen Add Member doctrine, Space membership only, refuses to remove a sole owner. **Frontend is a governance shell, not a second messenger**: `ConversationScreen` gained ONE optional context parameter (header + Back); timeline, composer, rich content, media, read state and identity are the canonical implementation, unduplicated — **no SpaceMessage/SpaceAttachment/SpaceReadState/SpaceCall/SpaceNotification exists**. The conversation id comes from an endpoint that **checks Space access first**, so it is never a way around governance. **Three of our own ratchets fired on the new file and all three were right**: C1 caught `role == 'OWNER' || 'ADMIN'` (role-as-permission — now a capability question), C3 caught two route literals, C0 caught 'Try again'. **Institution Spaces no longer depend on Thread/Message/SpaceScreen/correspondence_identity**, which removes the institution-side obstacle to Phase 5 — the legacy runtime stays present and retirement stays unauthorised. **One additive production migration is REQUIRED and NOT executed** (`20260905000000_institution_space_conversation`: one nullable column, unique index, guarded FK; no data touched). Backend **207 suites / 2594 tests** (+12 anti-drift), tsc clean, route guard green; frontend **829 pass**, analyze clean; identity gate unchanged; 451/451, 17/17, Stage-0 ratified. **F116/F053 unchanged PARTIALLY_VALIDATED** (active 0, retirement-owned 15 — no site artificially cleared). **Founder decisions required: NONE.** **ADDITIVE MIGRATION FOUNDER-AUTHORISED AND DEPLOYED (2026-08-20).** `20260905000000_institution_space_conversation` re-verified before pushing rather than trusted from the commit that wrote it: three statements, all additive and guarded — nullable `Space.conversationId`, `CREATE UNIQUE INDEX IF NOT EXISTS`, existence-guarded FK. **No DROP/TRUNCATE/DELETE/INSERT/UPDATE/ALTER COLUMN/NOT NULL**; the only DELETE/UPDATE text is the FK's referential-action clause. **No backfill** — existing Spaces carry NULL until first use, and Postgres permits many NULLs under a unique index. Pushed backend-first so the migration and API land before the client that calls them: **aura-backend `879b205..8182bc6`**, **aura-frontend `7eab7b7..a7396d8`**; both synced with origin/main. **Pre-deploy health included the startup guard deliberately** — tests + tsc + migration safety are not startup evidence, as the 2026-08-20 crash loop proved by passing all three and still refusing to boot: route-path compilation spec PASS. Backend 207 suites / 2594 tests, tsc clean, prisma validate clean, Space+Conversation authorities 8 suites / 66 tests; frontend 829 pass, analyze clean, identity gate unchanged, domain proof 23/23, **Meetings 52 pass and untouched**; 451/451, 17/17, Stage-0 ratified. **HELD AND UNCHANGED:** legacy history migration (`migrate-conversations.js` NOT run), legacy message/Space deletion, table drops, destructive cleanup, arbitrary backfills. **Phase 5 remains UNAUTHORISED.** **Stage discipline:** deployment makes the product **observable** and certifies nothing; observation is not retirement. **FOUNDER LIVE OBSERVATION NOW OWED** — an 18-journey package is recorded, ordered as the product is used (workspace → Space → membership/governance → conversation → rich content → continuity), deliberately excluding realtime (D3 deferred), legacy history and old message chronology. **ConversationScreen parameter judgment ACCEPTED and CLOSED.** **Invitation identity residue stays visible** — five nested positional person reads in `invite_presentation.dart` that the detector cannot see; not blocking, not canonical, still owed. **F116/F053 unchanged PARTIALLY_VALIDATED** (active 0, retirement-owned 15). Record: `.../05-execution/institution-spaces-reconstruction-record.json`. **FOUNDER LIVE OBSERVATION PASS — INSTITUTION SPACES `LIVE_CERTIFIED` (2026-08-20):** *"institution spaces done beautifully"*. State transition uses the register's existing certification vocabulary; no new state invented. **Calling defects seen through the Space are INHERITED, not Space-local, and NO new finding was created.** Proven from the register and from ROUTE rather than assumption: two of the three captures are on the personal `/messages` surface, which the reconstruction never touched, and the third shows the identical state via a Space. Mapping — **F044** (Ready-to-join persists, IMPLEMENTED_NOT_LIVE_CERTIFIED, *proof was outstanding*) now carries **negative** live evidence on both surfaces; **F035** (Roster vs actually-connected, C4_OWNED_OPEN) confirmed visually — badge reads 2 while unjoined; **F047** (ring-card underline, IMPLEMENTED_NOT_LIVE_CERTIFIED) — founder attests the **redbox pill (overlay)** is unchanged live, so **I withdrew my earlier 'may predate the fix' caveat**: its proof is now FAILED, not outstanding; **F045** (RC-B: *overlay mounted above the router never unmounts*) flagged as a plausible **single shared mechanism** behind F044+F047, not a confirmed reproduction. **F036 deliberately NOT implicated** — 'Ready to join' is a pre-join affordance, not 'Connecting', and conflating them would have wrongly reopened a LIVE_CERTIFIED finding. Repair belongs to the canonical Conversation calling authority: **one repair fixes personal, public and Space together**; no SpaceCall or Space-local realtime. **Meetings untouched and not implicated.** **CO-RC-C7-005 REASSESSED:** history/data migration is **NO LONGER REQUIRED** (superseded by founder ruling; `migrate-conversations.js` stays HELD and unrun). A **COMPLETE** · B **COMPLETE** · C **PASS** · D complete for the institution side / not required for the personal side · E **COMPLETE** (correspondence_identity retirement-local) · F ready · G ready · H **OWED** (personal correspondence runtime still live) · I ready (institution legacy routes now **orphaned** — only `space_screen` produced them) · J **COMPLETE** · K ready (**all 15 sites map to deletion → 0**; typed-person 7 → 0) · L ready (code-only, revert restores, legacy rows untouched) · M separable and not required · N **NOT GRANTED**. **Deep links: NO translator recommended** — the one surviving address class (institution Spaces) already resolves unchanged, which the stable route bought for free. **RUNTIME RETIREMENT IS READY; destructive database cleanup is separate and unauthorised; PHASE 5 REMAINS UNAUTHORISED.** F116/F053 **unchanged PARTIALLY_VALIDATED** — no pre-promotion; they advance only after the code changes and the audit is rerun. 451/451, 17/17, Stage-0 ratified. Record: `.../05-execution/co-rc-c7-005-phase5-retirement-readiness.json`. **F044 REPAIRED + PHASE 5 RUNTIME RETIREMENT EXECUTED (2026-08-20). NO F144 CREATED** — accounting stays 143/308/451/17. **F044 clarified to its invariant**: *ready-to-join presentation appears outside a valid pre-join state*, with two evidenced manifestations (post-end, post-accept). **Root cause**: `Ready to join` was the presentation for `joinState == idle`, and idle was being read as 'has not asked to join' when it also covers 'asked, in flight' and 'already finished'; the room issues its join from a POST-FRAME callback, so the first frame painted an instruction to accept at someone who had just accepted. **Repair**: one pure predicate (`ready_to_join_policy.dart`), join intent recorded **synchronously** in initState. **Not a timing hack** — hiding the widget would have masked the flash and left the rule wrong. **Lifecycle preserved**: RINGING→ACCEPTED→JOINING→CONNECTED untouched, with a test that fails if a future 'simplification' collapses them. 8 tests + **seeded proof**. **F045/F047/F035 NOT promoted** — each must satisfy its own closure test, and a shared repair passing nearby is not evidence; **F036 still not implicated**. **Mobile = class B** (responsive aggravation of the same defect, not separate). **Retirement executed**: 12 files + the whole `/me/correspondence` route family, `/messages/legacy-hub`, and two orphaned institution routes. **Worth recording: my first attempt deleted `lib/features/correspondence` wholesale and produced 27 errors** across app/activity/auth/invitations/realtime — the DATA layer is shared infrastructure that survives while only the PRESENTATION layer is legacy. Restored, redone per file against proven consumers. **Backend removed: NOTHING, and that is a finding** — the retained repositories still call `/spaces`, `/threads`, `/messages`, and their consumers are surviving product (direct threads, activity, interactions, mention scope, public spaces); classified **MIGRATE CONSUMER FIRST**. **Five of our own gates fired and all were right** (C0 baseline honesty, C3 route integrity ×2, C3 literal ratchet burn-down, attachment single-authority) — each fixed, none weakened. **15 identity sites → 0, caused by the deletions**, baseline re-frozen *after* the measurement moved: surface 28→**20**, typed-person 7→**0**, inventory 15→**8**. **invite_presentation residue RESOLVED — and a sweep found 4 MORE unrecorded nested reads in `invite_accept_screen`**, also fixed; detector deliberately **not** widened to chase a metric. **F053/F116 now satisfy all six criteria** — evidence presented, **promotion left to the founder** because this exact promotion was held once before. **No destructive persistence work**: legacy rows unchanged (5 DT / 9 DM / 69 messages / 13 Spaces), `migrate-conversations.js` still HELD. Frontend **837 pass**, analyze clean, Meetings **52 pass** untouched; backend **207 suites / 2594**, tsc clean, startup guard green, **untouched**. 451/451, 17/17, Stage-0 ratified. **F053 + F116 PROMOTED → IMPLEMENTED_NOT_LIVE_CERTIFIED (founder-authorised 2026-08-20); BACKEND CONSUMER MIGRATION COMPLETE.** Implementation only — neither is LIVE_CERTIFIED. **The inventory I handed over last task OVERSTATED the surviving consumers**, because it came from filename substring matches: `public_spaces_repository` is the PublicSpace product, `direct_threads_repository` is direct threads' own, `direct_thread_screen`/`inbox_screen` never imported the correspondence layer, and `thread_composer` was retained on five references that are **comments, not imports**. Caught before migrating or deleting anything. **Real consumers were four**: activity (a Thread fetch that chose between two identical destinations after Phase 5 — removed), `threadMentionScopeProvider` (only consumer was the orphaned composer — removed with its subject; `directThreadMentionScope` survives untouched), `thread_composer` (nothing constructs it — removed), and `correspondence_live_service` (**RETAINED**, 7 real consumers, canonical live-calling infrastructure under a legacy name). **Zero frontend HTTP calls to legacy `/spaces`, `/threads`, `/messages` remain**; the family is down to **one file**. **Backend retired: NOTHING, deliberately** — two non-discretionary blockers: (1) `ConversationsModule` depends on `CorrespondenceOrchestratorService`, so canonical Conversation calling runs through the legacy module and deleting it would break the thing this retirement exists to protect — **MIGRATE FIRST**; (2) per **F071**, released native binaries may still call these endpoints, and breaking installed users is a product decision, **returned not assumed**. **Public Spaces required no decision** — it was never a consumer. Institution Spaces **LIVE_CERTIFIED untouched**; Meetings untouched (ratchet PASS both directions); **F044 untouched and NOT promoted** — live observation still owed. Identity after migration: surface **19 sites / 11 files**, typed-person **0/0**, domain proof 23/23, **residue sweep for nested positional person reads returns ZERO**. `migrate-conversations.js` HELD; production rows untouched; destructive cleanup UNAUTHORISED. Frontend **833 pass**, analyze clean; backend **207 suites / 2594**, tsc clean, startup guard green, **untouched**. 451/451, 17/17, Stage-0 ratified. |
| **Item 17 — Release Gate** | ⛔ **OPEN, NOT STARTED** |

## What is frozen

**Founder Decision Register — fully adjudicated.** FD-1 … FD-13 all RESOLVED/FROZEN, plus five named cross-product freezes: Capability-Adaptive Experience · Task/Domain-Oriented Adaptive Navigation + Canonical Product Language Authority · Threads/Spaces Product Model · Content Intake & Resolution Authority · Human Temporal Presentation Authority.

**Final roadmap — 12 chapters (C0–C11)**, organised by product authority and dependency, governed by **AUTHORITIES BEFORE SURFACES**.

## Where things live

| Area | Location |
|---|---|
| All frozen decisions, audits, matrices, roadmap | `docs/frontend-discovery/` (41 documents) |
| Final roadmap | `docs/frontend-discovery/FINAL_FRONTEND_RECONSTRUCTION_ROADMAP.md` |
| Dependency graph | `docs/frontend-discovery/FRONTEND_RECONSTRUCTION_DEPENDENCY_GRAPH.md` |
| Founder Decision Register | `docs/frontend-discovery/FOUNDER_DECISION_REGISTER.md` |
| Superseded draft (retained) | `docs/frontend-discovery/DRAFT_FRONTEND_RECONSTRUCTION_ROADMAP.md` |

## Codebase facts (measured 2026-08-15)

189,134 lines · 544 Dart files · 171 routes · 27 redirects · 136 screen classes · 37 feature directories.

**Known reconstruction territory:** 8 attention surfaces · 6 composers · 11 upload pipelines · 40 mirrored institution routes · 3 profile implementations · 3 thread screens · 3 live-room implementations · 83 raw spinners vs 63 shared · 68 blank empty states · 52 hand-rolled `.difference()` · 29 role checks + 20 `canX` · **0 drag-and-drop implementations**.

## C0 — Cross-Cutting Foundations (implemented 2026-08-15)

Three authorities now exist in `lib/core/product/`:

| Authority | File |
|---|---|
| Product Language | `product_language.dart` |
| Product State Presentation | `product_state.dart` · `product_state_view.dart` |
| Human Temporal Presentation | `temporal.dart` |

**Migrated:** 33 `'Try again'` labels across 30 files → canonical `ProductAction.retry`; one `Refresh` sitting in a recovery position; `relative_time.dart` now forwards to `AuraTemporal` (9 transitive consumers); `local_timezone.dart` reached via `AuraTemporal.zoneId`; `CommLoadingState` / `CommErrorState` → `AuraProductState`.

**Two deliberate visible changes:** older timestamps read `Aug 12` rather than the machine form `2026-08-12`, and future instants no longer render as `now` (a real pre-existing bug — `formatRelative` took a negative difference through its `inSeconds < 60` branch).

**Enforcement:** `test/product/c0_anti_drift_gate_test.dart` — hard build failure. Four zero-tolerance rules plus five ratchets (G2/G3/G4/G5/G7) frozen in `test/product/c0_drift_baseline.txt`. Each rule was verified to actually fail by introducing a deliberate violation.

**Not migrated, frozen as measured debt:** 24 local elapsed-time sites · 47 `toLocal()` · 26 full-surface spinners (**14 in Meetings**) · 181 direct state-primitive constructions · 17 screen-declared time formatters. Meetings is a **PROTECTED CERTIFIED SURFACE** and was not touched.

**Founder review, 2026-08-15 — FULLY ADJUDICATED.** Approved and applied: the two temporal changes · the future-time bug correction · the G5 ownership doctrine · the baseline/ratchet approach · `addMember`/`invitePerson`/`manageInvites` added to the language authority · **Person = canonical human identity, Member = contextual status** · **Correspondence = one meaning**, umbrella sense retired to a C7 obligation · the Discovery "trusted discovery" directive marked superseded in Representation · Connect/Works gate-enforced absent.

**Date correction.** The `2026-08-16` stamps were my own authoring error, not a provenance mystery. **40 files / 178 occurrences** corrected across three repositories to each file's git-evidenced date, plus two file renames. One file deliberately left alone pending a founder answer — see `docs/DATE_CORRECTION_2026-08-15.md`.

**G5 ownership: all 181 sites assigned, zero unassigned** — C1 42 · C2 21 · C3 44 · C4 26 · C5 16 · C7 26 · C8 3 · C9 3. **Meetings holds zero G5 sites** (its protected sites are G3/G4). 74 sites assigned from roadmap text, **107 from labelled judgment** — because the approved roadmap never names an owner for platform admin, institution admin, public directory, search/saves/updates or auth surfaces.

**Representation alignment pass (read-only) complete.** Nothing in Representation was edited. Found: `Add Member`/`Invite Person`/`Manage Invites` is a FROZEN doctrine the Product Language Authority cannot currently express (HIGH); the Discovery module's “trusted discovery” directive is banned by two later canons; “Correspondence” carries two governance meanings; `Connect` and `Works` have no canonical existence anywhere and are now gate-enforced absent.

Registers: `C0_MIGRATION_REGISTER.md` · `C0_G5_OWNERSHIP_MATRIX.md` · `C0_PRODUCT_LANGUAGE_VOCABULARY.md` · `REPRESENTATION_CANONICAL_FRONTEND_ALIGNMENT.md` · `REPRESENTATION_FRONTEND_REDESIGN_INPUTS.md`.

**Verification:** `flutter analyze lib/ test/` clean · `flutter test` **458 passed / 1 skipped / 0 failed** (411 pre-C0, +47 new — no regressions).

## C1 — Acting Context & Capability Projection (implemented 2026-08-15)

Two authorities in `lib/core/authority/`: **Acting Context** (`acting_context.dart`) and **Capability Projection** (`capability_projection.dart`), plus `authority_providers.dart` and the founder-approved Option A attribution component `acting_attribution.dart`.

**Frozen rule:** acting authority becomes explicit when a consequential action requires attribution — **never because of the route the person navigated through**.

**Four real defects corrected.** Presence heartbeat published as the institution for anyone merely affiliated · "tap Message" started threads as the institution purely from the URL · six capability tokens fabricated client-side (proven unreachable dead code) · `/institutions/me` returned capabilities for the person's arbitrarily-oldest membership, so a client viewing institution B reasoned with institution A's authority.

**Backend converged:** `institutions.service.ts` no longer duplicates the effective-capability formula — it delegates to `InstitutionAuthorityService`, which was already injected. Every membership now carries its own effective capabilities.

**The discovery baseline was wrong in both directions:** role-literal comparisons 29 files → **5 files / 6 sites** (3 not authorization at all); `canX` 20 files → **38 files / 73 sites** (most not authorization). The real vector was never named: **86 `isOwner`/`isAdmin` sites**.

**G5 re-verification withdrew 38 of 42 sites from C1** — measured zero institutional authority code in all 11 admin and both auth files. Dispositioned to **PD-1** and **PD-2**. 181 sites still traceable.

Registers: `C1_AUTHORITY_ARCHITECTURE.md` · `C1_G5_DISPOSITION_MATRIX.md`.

**Option A certified** on a representative surface (institution post composer): attribution stated where the act commits, no manufactured chooser, acting person kept visible. 4 widget tests.

**Product Language extended:** `ProductAction.switchIdentity` ("Switch identity") — approved C0 extension discovered through C1 implementation, with four competing phrasings gate-prohibited.

**Verification:** analyze clean · **505 frontend** / **2200 backend** tests passing.

## C2 — Identity, Presence & Profile (in discovery, 2026-08-15)

**§6 Follow forensic COMPLETE** — `docs/frontend-discovery/C2_FOLLOW_FORENSIC.md`. The two systems partition by target type in the shipped client: person→person is request-only via legacy `Follow`/`FollowRequest`; person/institution→institution is immediate via `InteractionFollow`. They are complementary halves of one feature, each blind to the other.

**Eight defects, four new.** D1 following a person never reaches the feed · **D2 blocking does not stop DMs (safety)** · D3 API consent bypass · D4 counts never emitted · D5 `REQUESTED` never written · **D6 `BLOCKED` never written — only read, by the dead check in D2** · **D7 `FOLLOW_REQUEST`/`FOLLOW_ACCEPTED` fully plumbed through email, routing and delivery but never emitted — relationship events are silent** · D8 request message accepted and discarded.

**§7 recommendation:** Follow and Subscribe are **separate concepts sharing infrastructure** — following an actor notifies them; subscribing to a Thread/Space notifies nobody and only changes what reaches you. Keep `InteractionFollow` as shared storage. Naming deferred to C4 (recommended).

**Blocked on founder adjudication:** canonical Follow target, conflict rules for states 2–5, Follow/Subscribe naming ownership. **No migration performed, no production access.**

**Founder adjudication R1–R10 recorded** (see `C2_FOLLOW_FORENSIC.md`). **R1 blocking defect RESOLVED and CERTIFIED** — `canMessage` now consults the canonical `UserBlock`/`BlocksService` authority instead of a status nothing writes; follow eligibility gated too; backend 173 suites / 2207 tests green.

**§8 availability privacy:** five options returned with the decisive finding that `getState` **receives no viewer identity at all**, so no policy is enforceable until that changes. **§10 People Selection:** two by-design person projections, neither carrying verification or availability. **§11 G5: 21/21 confirmed C2**, zero reassignment — but 9 of the 21 are legacy Follow surfaces blocked on the convergence model.

**§9 edit-profile convergence COMPLETE** — `C2_PROFILE_CONVERGENCE.md`. Shared `ProfileMediaPipeline` (8 duplicated flows → 1, person side gained validation), institution gate corrected from `isAdmin` to the `MANAGE_BRANDING` capability the backend actually enforces (both defect directions pinned by test), 4 G5 sites eliminated (181→177), 3 R1 sites eliminated (85→82), person "Presence" naming drift corrected. No flattened Profile ontology — subjects remain distinct.

**Canonical Follow COMPLETE** — `C2_CANONICAL_FOLLOW.md`. `CanonicalFollowService` is the single relationship authority; consent partition frozen as product truth (person→person request-only, →institution immediate); D3 consent bypass CLOSED; R9 institution→person refused at both writers; FOLLOW_REQUEST/FOLLOW_ACCEPTED wired (rejection deliberately state-only); D4 counts emitted; availability relationship source replaced at the designated point; legacy writers retired. **No rows moved** — legacy preservation + canonical projection; physical convergence staged for a later migration chapter. Feed activation (D1) deliberately NOT performed — staged founder decision.

**Follow ADOPTED in the release client (2026-08-16):** D1 feed activation live (old follows participate, no refollow needed) · nine Follow G5 sites consumed (G5 177→168) · cooldown state visible on profiles · counts real · request/accept notifications live. **Final storage architecture designed** (FollowEdge + FollowConsent) with an executable, gated physical migration plan. **C0–C2 reconstruction-debt register produced** under the new founder doctrine — \`C2_RECONSTRUCTION_DEBT_REGISTER.md\`.

**Verification & Trust Experience — EXECUTED 2026-08-16** (`C2_TRUST_PRESENTATION.md`): canonical trust layer (`core/trust/verification.dart` + `trust_marks.dart`), person profile wire gap closed backend-side (profile now emits `verification.classes`; raw column stripped), Person Verification Authority exposed to admins for the first time (grant/revoke/history under VERIFICATION_READ/WRITE), person profile renders per-class marks, 13 institution sites migrated onto canonical marks, §11 'Official session'-from-isVerified violation corrected, admin verification sheet added. Generic `'Verified'` literals 16→8 (all remaining subject-unambiguous, classified). NEW founder decision surfaced: plan taxonomy sells verification (§20 STOP) — **adjudicated and RESOLVED 2026-08-16**: full decoupling implemented backend+frontend (see DECISIONS.md §Monetization × Verification Decoupling; backend commit “Decouple commercial plans from verification authority”; reconciliation SQL in prisma/manual/, manual + founder-observed). “Role attested” wording applied in the canonical trust layer. **Taxonomy CLOSED 2026-08-16: FREE + PRO frozen** (backend 2217480) — middle tier retired not renamed, dead capability booleans + requirePlan/PLAN_REQUIRED_VERIFIED deleted, new checkouts refuse the retired product code, legacy rows behavior-preserved pending the observed migration window. FUTURE COMMERCIALIZATION GOVERNANCE MARKER recorded in DECISIONS.md — final Free/Pro boundary deliberately NOT decided. **Commercial-matrix forensic complete 2026-08-16** (C2_TRUST_PRESENTATION.md §11): only enforced tier differences are member capacity (env-driven) and PRO's institution-level official-publishing gate; AI/translation/realtime are credit-metered plan-independent (plan copy corrected to enforcement truth, backend d940477); middle tier commercially weak after decoupling — reported, nothing invented.

**§12 Representation consistency — EXECUTED 2026-08-16** (`C2_REPRESENTATION_CONSISTENCY.md`): full bidirectional matrix; Representation caught up via NEW `inventory/AURA_IDENTITY_RELATIONSHIP_TRUST_CANON.md` + dated supersession banners on the stale Follow/Presence/Verification characterizations (selective 3-file commit, other agents' uncommitted Representation work untouched); two client-behind-authority defects corrected (three local time-ago dialects → AuraTemporal; three bare institution checkmarks in discourse intelligence → canonical marks); G2 updates_screen burn-down 6→0 recorded in baseline.

**Public Home reconstruction — EXECUTED 2026-08-16** (`C2_PUBLIC_HOME_RECONSTRUCTION.md`): institution-first hero on `/` replaced with public-first entry copy; verification glyph decoupled from 8 institution-involvement/accountability motifs (3 files); hand-rolled Verified-institution line → canonical mark; feed-card timestamp off the deprecated shim (11→10 callers); 6 G5 sites → product-state authority with retry (baseline burn-down recorded); retired "works" vocabulary removed; participation copy made truthful; **public-first gate extended to cover both home surfaces** (the gap that let the old hero ship). No founder decisions required.

**FINAL CONVERGENCE + PRE-MIGRATION CLOSEOUT — EXECUTED 2026-08-16** (`C2_PRE_MIGRATION_CLOSEOUT.md` is the handoff authority): Follow HTTP-in-widget retired (FollowsRepository now owns the consent lifecycle + canonical counts); live-rooms startLive gate converged onto C1 capability projection (R1 burn-down recorded); dead FeedPresence.lastActiveAt parse slot removed; final debt remeasured — zero unexplained C2-owned remainder. **Frontend committed in 5 bounded commits** (11e85fa, 0d0abf5, 121d029, cff6982, 7a243e1 + closeout doc); backend 9 bounded commits, Representation 1 — all local, nothing pushed.

**C2 STATUS: DATA TRANSITIONS EXECUTED 2026-08-16** (see C2_FINAL_CLOSEOUT.md): verification reconciled (drift 0), TRUSTED+legacy VERIFIED enum values physically retired (zero-row evidence), Follow migrated to FollowEdge+FollowConsent with 8/8 equivalence checks and canonical-store cutover live (AURA_FOLLOW_STORE=canonical). Cutover observed healthy → **legacy Follow stores + flag + zombie enums RETIRED (d18b0bb)**; zero migration-dependent debt.

**C2: FINAL CLOSURE DECLARED BY FOUNDER 2026-08-16.**

**C3 (NAVIGATION & IA): PHASE 1 FORENSIC COMPLETE 2026-08-16** — see C3_NAVIGATION_IA_RECONSTRUCTION.md. Re-measured: 171 routes / 40 DR4 mirrors / 27 redirects / 266 feature route literals in 92 files. Root cause identified: shell selection is path-derived (AppShell), which forces the mirrored universe; resolveActorContext still derives institutional acting context from path (3 consumers — DM-actor fix is C7-reserved per C1 contract). Capability-adaptive institution nav already RESOLVED (hidden-not-disabled, effective-capability-true). **FOUNDER FROZE THE PRIMARY IA 2026-08-16** (Home/Messages/Discover/Meetings/Me + Discover semantics + institution-as-context + Follow-as ruling). **Phase 2 certified boundary shipped** (9ffb777 + d577e67): Navigation Authority live, five-primary adoption on Member+Public shells, /discover destination, route-derived acting context RETIRED (resolveActorContext deleted; explicit Follow-as; explicit institution inbox context; canActAsInstitution governance predicate), 544 tests + all gates green. **C3 CLOSEOUT REACHED 2026-08-16** (C3_FINAL_CLOSEOUT.md is the handoff authority): DR4 executed per-route (2 pure duplicates → alias redirects, 35 canonical institution depth, 3 C7-pending inbox trio); route-derived acting context = 0 mechanisms; route-integrity gate + literal ratchet live (103 files/294 sites frozen, every literal validated against the declared table — caught 2 real defects on first run); redirects all classified with owners; shell classification = destination identity, non-authority pinned. 547 tests + all gates green. **DR4 reconciliation EXECUTED (founder-ordered proof): HELD** — 34 canonical depth + 4 C7-held, 0 mirrors remaining, over-broad Phase-1 phrasing superseded, alias-aware shell hardening + pin added (C3_DR4_ARCHITECTURE_RECONCILIATION.md). **Recommendation: C3 FINAL CLOSE. Awaiting founder declaration.** Commits local, NOT pushed.

**C3 was previously: AUTHORIZED — NOT STARTED.** Founder paused at closure; no C3 discovery or implementation has begun. Next session starts C3 from the C2 closeout contracts (C2_FINAL_CLOSEOUT.md + C2_PRE_MIGRATION_CLOSEOUT.md), which C3 must not reopen. Boot incident fixed + app-boot graph spec added (79de236). C3 not authorized.

## What has NOT been touched

No routes · no screens redesigned · no layout or visual treatment changed · Meetings untouched · no backend · no Representation. **Nothing committed.**


---

**C3: FINAL CLOSURE DECLARED BY FOUNDER; pushed + deployed (70ec625..4aa3035).** The stale "not pushed / nothing committed" lines above predate that push and are superseded by this entry.

**FOUNDER-OBSERVED NAVIGATION CORRECTION EXECUTED 2026-08-16** (authoritative rulings — see DECISIONS.md "FOUNDER-OBSERVED NAVIGATION CORRECTION"): authenticated primaries amended to **HOME · MESSAGES · DISCOVER · CREATE** (Me removed → identity/avatar chrome; Meetings removed → institutional domain, no bare /meetings destination; Create restored as primary human intention with global+contextual complementarity). Discover corrected: four-domain framework (Articles canonically declared, not rendered until truthful capability), institutions directory de-contaminated + verification-as-ranking retired end-to-end (backend single activity-ordered list with keyset cursor + transitional cohort arrays for released clients), Spaces taxonomy broadened to 10 in the single registry. Messages gained the persistent contextual "New conversation" entry (canonical chooser lifecycle). Institution onboarding = lifecycle-gated acquisition action (desktop header while no affiliation; account menu + Create hub afterwards). Header invite icon retired (dead parameter surface). Route-integrity gate strengthened: authority-declared addresses proven executable against the router table (the /meetings class of defect cannot recur). C4 (ATTENTION) forensic evidence base complete; C4 implementation NOT started, held per founder sequencing.


**AURA CONVERSATION + INVITATION SYSTEMS BUILT (2026-08-16, local, uncommitted;
awaiting §62 checkpoint ruling):** canon frozen (see DECISIONS pointer); backend
foundation complete (AuraInvitation + Conversation* schema, additive migration
20260825…, InvitationAuthority + ConversationAuthority + adapter registry,
People Discovery /v1/discover/people; backend 2307/2307 + 32 new-system tests).
Frontend: new lib/features/conversation/ module (MessagesScreen at /messages,
ConversationScreen /messages/c/:id, picker /messages/new, AddPeople→Invitation,
/i/:token claim landing) + Discover→People personalized surface
(/discover/people); Create hub per §53 (Invitation/Institution cards removed);
frontend 557/557, analyzer clean, all gates green incl. C0 product-state
ratchet (new surfaces consume AuraProductState; ProductNoun.conversation
added). Production measured (read-only): 5 DirectThreads/9 msgs, 10 PRIVATE
personal spaces/67 msgs, 0 grown-past-pair, 2 named personal spaces.
Idempotent migration script scripts/migrate-conversations.js (+ dry-run
measurement mode) and scripts/seed-public-spaces.js (4 broadened subjects →
real PublicSpace rows) ready for authorized deploy. Legacy conversation
surfaces NOT yet retired (Phase 5 follows verified production migration);
legacy hub parked at /messages/legacy-hub. C4 held; C5 hard-gated.

**§62 FOUNDER RESOLUTION APPLIED (2026-08-16):** C7 amendment FROZEN
(Institutional Conversation & Desk); both named personal spaces inspected
individually ("family" CIRCLE 2 members/3 msgs; "Aura Internal" WORKROOM 3
members/1 msg — single-thread each) → MIGRATE with human-chosen names as
Conversation presentation (migration script extended + dry-run verified);
Create vocabulary corrected to frozen intent (Message · Post · contextual
Announcement; pinned); Conversation completion register recorded (realtime/
media/report attach before Conversation final certification); abuse policy =
hooks only per founder; Phase 5 retirement NOT authorized (gate: additive
deploy → migration → founder live observation → journey certification →
explicit authorization). Release authorized: commit + push both repos;
founder observes deployment; migration + PublicSpace seed run through the
authorized deployment path. C4 next after founder live certification; C5
hard-gated on C4 live closure.

**MEETINGS CLOSEOUT BATCH (2026-08-25):** Create Meeting reconstructed against
the released form — no default "Meeting" title, a summary that answers what /
when / how long / who / convened by and shows unmet requirements as unmet
before submit, booking-page card removed from the create flow, backend
terminology out of the subtitle, member-picker loading given shape, and the
"All active members ON / No internal members selected" contradiction removed.
Four defects were caught only by looking at the deployed build (invisible hint
under a Material label; "Owning institution" rendered as a real institution's
name during load; a missing controller listener exposed by removing the default
title; a 23 px overflow in the invitee buttons). Frontend suite 1480 green,
analyzer clean, C0 ratchet updated in the reducing direction (one full-surface
spinner removed). The reported **shared bootstrap hang does not exist** — it was
a hidden-tab measurement error of mine; diagnostics reverted in `a5a3bc4`, no
Meetings-local workaround added, no A/V boundary crossed. Meetings is returned
for founder review, NOT closed: wide-layout review pane still scrolls out of
view, production submit not executed, Android/iOS not executed. Record:
`docs/meetings/2026-08-25-meetings-closeout.md`.

**MEETINGS CLOSEOUT CORRECTION (2026-08-25):** Wide-layout review pane fixed at
the scroll architecture (sibling scrollables in a bounded Row; primary action
moved into the rail) — not a wrapper; a nested-scroll trap in the member picker
found and removed while proving it (the create button had been unreachable by
touch on a narrow window). Shared entry loading fixed at the canonical owner
(`AuraLoadingSurface` + copy), regression-tested on non-Meetings consumers. One
founder-authorized Host-only production creation exercised Create → persistence
→ record → return → landing, and found two further defects: the same meeting
rendered twice on the landing (Up next + Needs attention), and **cancelling a
meeting was impossible from the released client** — the dialog builder discarded
its own context so both buttons popped the screen's route instead of the dialog,
and POST /meetings/:id/cancel was never issued (proved against a working network
control). Both fixed, deployed. Certified on **Windows native 8/8** and
**physical Pixel 9a 8/8** via `integration_test/create_meeting_certification_test.dart`,
plus web against production. iOS NOT_EXECUTED (no macOS host).

**A/V CHAPTER — FIRST BATCH (2026-08-25):** Measured the A/V surface (35 client
realtime files, 82 backend realtime files, 11 getUserMedia sites) and resolved
the P0 Meetings handoff. `permission_handler` added; `MediaPermissionService`
gives Android/iOS real permission status, permanent-denial detection and a
settings trip, while web/desktop honestly report `notRequested` rather than
faking readiness. `CallReadiness` + `CallPreflightSheet` are one shared
preflight; thread calls now ask BEFORE creating the session and ringing anyone.
`DevicePermissionState` gained `permanentlyDenied` and `unknown`. The media
engine consumes the canonical classifier — zero browser-flavoured strings
remain. Call controls name their effect and announce state/effect to screen
readers (they carried no Semantics at all). Android manifest gained
BLUETOOTH_CONNECT / FOREGROUND_SERVICE(+types) / WAKE_LOCK; iOS gained the
`audio` background mode. TURN re-measured live: 3478 UDP/TCP and 5349 TLS
healthy with a valid certificate, **443 closed** (enterprise-443-only networks
unsupported, reported not hidden). Suite 1523 green, analyzer clean, Android APK
builds, Windows A/V certification 8/8 on real hardware. Android physical
NOT_EXECUTED (Pixel disconnected); iOS NOT_EXECUTED; no two-party call executed.
Live Broadcast untouched.

**A/V ANDROID PHYSICAL CERTIFICATION (2026-08-25):** Final current A/V code
certified on Pixel 9a (Android 17, API 37) — 18/18 on the new
`av_android_certification_test.dart`, 8/8 on the baseline harness, suite 1529
green. Found and fixed a defect only the handset could expose: `CallReadiness`
called `notifyListeners()` after disposal, because Android's check (permission
request + real device open) is slow enough to be dismissed mid-flight, whereas
Windows returns almost instantly. The fix also releases whatever the in-flight
check opened, so an abandoned preflight cannot leave the camera running.
Ordering invariant (intent → preflight → readiness → proceed → session → ring)
proved structurally AND negative-controlled: reintroducing the pre-chapter
defect made the test fail, restoring it made it pass. Permission agreement
measured in TWO OS states driven from outside via adb — denied on fresh install,
granted after `pm grant` — with BLUETOOTH_CONNECT confirmed grantable, proving
the new manifest entry is real. iOS still NOT_EXECUTED; real two-party call
still pending a second identity; TURNS/TLS 443 remains BLOCKED_EXTERNAL.
