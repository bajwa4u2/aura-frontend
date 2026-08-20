# Aura Release Client — Next Work

**As of 2026-08-15.** Roadmap frozen. **C0 implemented and fully adjudicated — awaiting final closeout review.**

---

## C0 — CROSS-CUTTING FOUNDATIONS ✅ IMPLEMENTED

Three authorities built, consumers migrated, hard gate in place, regression green.
Full record: `docs/frontend-discovery/C0_MIGRATION_REGISTER.md`.

> **The raw scope figures previously listed here were superseded by
> classification.** They over-counted, and acting on them directly would have
> produced the mass replacement the chapter forbids:
>
> | Raw figure | Actual |
> |---|---|
> | "83 files → shared loading state" | **26** full-surface sites; 91 spinner uses are legitimate inline progress |
> | "52 hand-rolled `.difference()`" | **41** human-facing; 28 are internal TTL/cooldown/debounce, and one was a `Set.difference` false positive |
> | "35 direct `toLocal()`" | **47** measured; 16 are Meetings |
> | "22 independent sorts" | **10** temporal; 16 non-temporal, out of scope |
> | "68 `SizedBox.shrink()` → empty states" | not adjudicated — most are legitimate conditional layout, and C0 did **not** convert them |

**In-chapter founder checkpoint: CLEARED.** The concrete vocabulary was
reviewed against the canonical Representation body and adjudicated on
2026-08-15. Final map: `C0_PRODUCT_LANGUAGE_VOCABULARY.md`.

**Obligations handed to later chapters by that adjudication**

| Chapter | Obligation |
|---|---|
| **C2** | Verification labels remain undecided — **no generic "Verified"**, now gate-enforced. Follow reconciliation (three inconsistent backend models). |
| **C5** | Official-designation and institutional-approval vocabulary, deliberately not pre-empted by C0. |
| **C7** | **Correspondence umbrella rename/migration** — choose the correct internal name, migrate safely, preserve compatibility and history. Paths may lag until then; documentation may not. |
| **C10** | Whether `Live` ever needs a plural form. |
| **All** | Re-verify `J`-basis G5 assignments against actual reconstruction scope before migrating. |

**Carried into later chapters as measured, enforced debt** — see
`test/product/c0_drift_baseline.txt`:
24 local elapsed-time sites · 47 `toLocal()` · 26 full-surface spinners
(**14 in Meetings, a protected certified surface**) · 181 direct
state-primitive constructions · 17 screen-declared time formatters.

**G5 ownership: ALL 181 sites assigned, zero unassigned** —
C1 42 · C2 21 · C3 44 · C4 26 · C5 16 · C7 26 · C8 3 · C9 3 · **C6 0**.
Full matrix with per-row basis codes: `C0_G5_OWNERSHIP_MATRIX.md`.

---

> **Every remaining chapter inherits the Aura Public-First Causal Doctrine.** Canonical
> source: `representation/inventory/AURA_PUBLIC_FIRST_CAUSAL_DOCTRINE.md`. Per-chapter inheritance is
> recorded in the roadmap. Roadmap ordering is unchanged by the doctrine.


## The next executable chapter

# C1 — ACTING CONTEXT & CAPABILITY PROJECTION ✅ COMPLETE

Founder approved / locally certified 2026-08-15. Registers:
`C1_AUTHORITY_ARCHITECTURE.md` · `C1_G5_DISPOSITION_MATRIX.md`.

**Two new product disposition checkpoints opened before C11:**
**PD-1 Platform Administration** (11 files / 34 G5 sites) and
**PD-2 Authentication & Account Entry** (2 files / 3 sites). Neither has an
owning chapter in the approved roadmap; both need a product decision.

---

## The next executable chapter

# C2 — IDENTITY, PRESENCE & PROFILE

**⛔ NOT STARTED. Awaiting explicit founder authorisation.** Roadmap approval is
**not** authorisation to start a chapter, and C1 closure is not authorisation for C2.

C1 unblocks it. C2 inherits: verification labels (open checkpoint, **no generic
"Verified"**, gate-enforced) · Presence retirement of its six-meaning overload,
now that presence is correctly the person · Follow reconciliation across three
inconsistent backend models · 21 assigned G5 sites (`J` basis — re-verify before
migrating, as C1 did).

**Unlocks.** C1.

---

## Chapter sequence

`C0 → C1 → {C2 ∥ C3} → {C4 ∥ C5 ∥ C6} → {C7 ∥ C8} → C10 → C11`, with **C9 overlapping where its dependencies permit**.

| Chapter | Blocked until |
|---|---|
| C1 Acting Context & Capability | C0 |
| C2 Identity, Presence & Profile | C1 |
| C3 Navigation & IA | C1 |
| C4 Attention | C2 + C3 |
| C5 Composition, Intake & Attachments | C2 + C3 |
| C6 Realtime Presentation Convergence | C2 |
| C7 Threads, Spaces & Correspondence | C4 + C5 + C6 |
| C8 Institution Room | C6 |
| C9 Cross-Platform | C4 + C5 (may overlap C10) |
| **C10 LIVE (cross-repository)** | **C0–C8 all stable** |
| C11 Item 17 | all chapters |

## Open implementation checkpoints — tracked, not backlog

| Item | Owning chapter |
|---|---|
| Orphan-cleanup windows vs draft lifetime | C5 |
| Presence privacy/visibility policy | C2 ⚑ |
| Verification label mapping | C2 ⚑ |
| Live moderation policy | C10 ⚑ |
| Live audience-scale topology/provider | C10 |
| `InstitutionCorrespondenceScreen` · `PresenceScreen` · `LoginScreen` | C7 · C2 · C3 |
| **`SupportScreen`** | **ownership undetermined → product disposition checkpoint** |
| Exact primary navigation destinations | C3 ⚑ |
| Thread vs Space Live differences | C10 |
| Drag/drop (0 implementations) | C5 + C9 |

## Explicitly NOT next

Live (C10) · Item 17 (C11) · any demolition · any route change · Representation edits before wording is frozen.

---

## 2026-08-18 — Wave 1 Parts 1 & 2 complete; what is next

**Done (nothing closed).** W1-000 PBCR 7+8 discharged · W1-A CH-17 governance mechanism (both repos) ·
W1-B CH-01 ratchets, 11/11 proven ENFORCING by seeded failure · W1-F 335-consumer identity audit ·
W1-C/D/E the CH-02 keystone S1–S3 with the PD-2 seam published and gated.

**Owed before CH-02 can close — none of it is optional:**

1. **F065 LIVE REFRESH PROOF.** The chapter's own first gate. A live authenticated session that
   survives a browser refresh without dropping to unauthenticated. Requires a running app and
   **PB-11 founder observation** of the authentication behaviour change. Until it passes, no
   downstream continuity finding may be claimed closed.
2. **Live signed-out probe** for the route-classification contract (S2). Fail-closedness is proven by
   gate, not yet on a live browser.
3. **F103 / F104** remain `OPEN`, gated by F065.
4. **CH-02 S4** (draft identity/ownership contract) still refused — it consumes CH-03's conformance
   gate, which is W2.

**Blocked on a founder decision:** W1-X1 (CH-11) needs the **RC-C5 scope ratification** — does the
BIFURCATED ruling answer CH-11's recorded scope question? Fail-closed default is *treat as gated*, so
CH-11 has not been started.

**Assigned but not scheduled:** DEFECT-1 — `realtime_room_golden_test.dart` is skipped for
pre-existing rot, so realtime *rendered* presentation has no automated visual proof. Assigned to
CH-04, not waived; restoration/replacement is a CH-04 closure requirement. The 333-pass realtime suite
must never be represented as covering it.

---

## 2026-08-19 — CH-03 typed-person convergence complete; two founder decisions owed

**Done.** The two instrument rulings executed (domain-aware detector · enforcing
`NON_CANONICAL_PERSON_DESERIALIZATION`, proven enforcing by a seeded violation), then the typed
boundaries migrated: **62 -> 18 typed-person sites**, three measurements kept separate. Full record:
`docs/portfolio/run/stage0-2026-08-18/05-execution/ch03-f116-typed-person-convergence.json`.

**Owed before F116 / F053 can move past PARTIALLY_VALIDATED — both are founder decisions, not work:**

1. **NARROW RULING — the `'Guest'` default in `MeetingIdentityRef`.** Legitimate on the GUEST branch
   (an external non-Aura contact; GUEST is a meeting ROLE). The F054 invented-label defect on the
   **AURA_USER** branch, where an identifiable Aura person is named by a role they do not hold.
   Correcting it decides what an unnamed Aura participant is called in the meeting UI — protected
   Meetings semantics, so it was returned rather than changed.
2. **AUTHORIZATION — the four protected Meetings domain models** (`meeting_identity`, `meeting`,
   `availability_profile`, `meeting_entry_resolution`, **16 sites**). They are the remaining half of
   F116 criterion 2. Measured, not excluded; no Meetings file was modified.

**Retained by design, not owed:** 2 polymorphic feed actors (`FeedSignalActor`, `FeedReplyAuthor`)
consume the union projection (`handleOrSlug` / `avatarOrLogoUrl`) emitted for a user OR an
institution. Composing person identity onto them would force person semantics onto institutions.
They stay measured so the decision stays visible.

## 2026-08-19 — CH-03 CLOSED: the protected Meetings pass, Guest semantics, and the feed actors

Both decisions above were granted. Both are now executed, and **typed-person debt is zero**.

**The founder ruling, on both sides of the wire.** An AURA_USER is never named `'Guest'` — the client
delegates that branch to `AuraPersonIdentity` and `buildAuraUserBookerIdentity` stops emitting the
string, which is the only backend change in the pass and the only one that could work (no client fix
undoes a literal `'Guest'` already written into a person's `displayName`). A genuine external CONTACT
or GUEST **keeps** `'Guest'`, because for them it is a truthful statement of what they are.
**PERSON IDENTITY ≠ MEETING ROLE / EXTERNAL PARTICIPANT TYPE.**

**All 16 Meetings sites dispositioned** — 14 converged outright, 2 split (one line each in
`meeting_identity` and `meeting_entry_resolution` was serving both a person branch and an external
branch). Every public accessor kept its type and nullability, so no Meetings surface changed:
**MEETINGS BEHAVIOR PRESERVED.**

**The two feed actors were classified from their producers, not their field names** — and the brief's
premise needed one correction: `handleOrSlug` / `avatarOrLogoUrl` are emitted by
`feed-projection.service.ts` for the **post author**, not for either of these DTOs, both of which carry
plainly named fields. `FeedSignalActor` is a **true PERSON | INSTITUTION union** (two backend builders,
`userActor` / `institutionActor`): union retained, person branch delegated, institution identity kept in
institution terms so no slug can be read through a person-shaped accessor. `FeedReplyAuthor` is a
**person model** — every reply author comes from one builder, `userAuthor`, routed to `/u/:handle` — that
had been accepting institution aliases it is never sent. Fully converged.

**One governed non-promotion, recorded not hidden.** `MeetingEntryResolution.identityName` delegates its
parsing but deliberately does not answer with the canonical label: the pre-join screen pre-fills the
entrant's own name box from it, so 'Someone' would be typed into a stranger's name field.

**States.** F116 and F053 both advance **PARTIALLY_VALIDATED → IMPLEMENTED_NOT_LIVE_CERTIFIED**; all six
F116 criteria met. F052 gains structural evidence without promotion. F054 gains implementation evidence
only — not promoted from association. F055–F057 unaffected. **F051 preserved untouched as a conflict.**

**Next executable frontier: the 19 SURFACE sites across 11 files** — widgets reading person fields off
untyped maps. Separately measured, separately ratcheted, and the last named residue on F053.

Record: `docs/portfolio/run/stage0-2026-08-18/05-execution/ch03-f116-meetings-guest-and-feed-actor-closeout.json`.
Ratchet proof: `tool/meetings_person_ratchet_proof.mjs` (PASS both directions).

## 2026-08-19 — F116/F053 promotion WITHDRAWN; one decision blocks closure

The founder held the promotion because 19 measured surface sites looked inconsistent with criterion 2.
**The hold was right and the stated reason was not.** All 19 are non-competing — 11 presentation over
already-canonical identity, 4 institution, 3 governed, 1 detector window catch, **zero class A**.

**The promotion fails because the detector understated.** Its matcher saw `map['displayName']` and could
not see `pick(map, const ['displayName', 'name'])` — and a list *is* a private alias order. Tracing the
19 to their producers, as the task required, found real debt that was never in the count:

- **the app-shell header** — `_pickMeString` was a complete private person reader (nested-`user`
  envelope unwrap plus its own name order), on the most globally visible person in the product. Its own
  docstring described the F057-shaped bug it had been written to patch.
- **the member directory** — `memberEntryFromMap`, built in an earlier chapter to stop four pickers
  re-implementing precedence, was still a *second authority*: its own avatar aliases (`avatar`, `image`,
  never `photoUrl`), an invented `'Member'` label, and its own `/handle` address for a person. **The
  router only declares `/u/:handle`**, so "open profile" from the member picker pushed an address that
  does not exist. A live navigation defect, found by asking where a person's identity comes from.
- the profile editor's hydration, and two viewer-identity reads.

**11 class-A sites converged. The gate then still read 11 files / 19 sites — unchanged.** A gate that
cannot see the debt just removed is decoration, so the instrument was widened: alias-list detection,
same-line receiver, enclosing type as the weakest and person-vetoed signal, and the canonical person
model declared as authority. Proof **13/13 → 23/23** — and it caught a precedence bug in the extension
(a person inside an institution-named class) before the baseline was frozen.

**Honest measurement:** surface **19 → 29** sites / 16 files, typed-person **0 → 8** sites / 2 files.
**Entirely instrument correction — zero new debt**, recorded separately from the 11 real migrations.

**F116 and F053 remain PARTIALLY_VALIDATED.** Criteria 2, 3, 4, 6 NOT MET.

**Exact residue — 18 class-A sites:** 17 in the correspondence / conversations / messages family
(including `CorrespondenceIdentity`, a second complete person authority) and 1 actor union in
`RoutedRecord`, which reads `handleOrSlug` with no actorType to tell it which side of the union it holds.

**FOUNDER DECISION — the only thing blocking F116 criterion 2:** `MessagesHubScreen` is parked at
`/messages/legacy-hub` and the router says plainly that the legacy hub and its routes retire after
history migration. Converge person identity inside those retirement-pending surfaces now, or scope the
remaining client work to surviving surfaces and let retirement discharge the rest? Converging them
unasked would be work in territory whose disposition is already pending.

Record: `docs/portfolio/run/stage0-2026-08-18/05-execution/ch03-f116-f053-promotion-reconciliation.json`.

## 2026-08-19 — Retirement-owned debt ruled; RoutedRecord resolved; active person debt is ZERO

**Founder ruling applied.** Person-identity debt inside code already governed for removal is
**RETIREMENT_OWNED STRUCTURAL DEBT** — still real, still measured, discharged only by physical deletion.
Not a governed exception, not a false positive, not eligible for detector exclusion.

**The retirement owner already existed and only needed tracing** — no new retirement program invented:
- **CO-RC-C7-005** (RC-C7): *Phase 5 legacy retirement NOT AUTHORIZED — gate: additive deploy → migration
  → founder live observation → journey certification → explicit authorization. Legacy hub parked at
  `/messages/legacy-hub`.*
- **CO-RC-C2-010** (RC-C2) had **already assigned per-file owners**: `conversations_screen` → C4-retired;
  `correspondence_hub` / `space` → C7.

**15 of 17 sites are retirement-owned.** `correspondence_identity` 7, `messages_hub` 3,
`correspondence_hub` 2, `conversations_screen` 2, `space_screen` 1.

**2 were rejected from the bucket** — and the reason matters: `mention_scope_providers` *looked*
retirement-owned because it read its person through `CorrespondenceIdentity`, but it lives in
`lib/core/tagging` and serves `DirectThreadScreen` at `/direct/:threadId`. **Depending on retiring code is
not the same as being retired by it** — no deletion would ever reach that file, so its debt could never be
discharged by waiting. It carried the same two defects as the member directory (an avatar order accepting
`avatar`/`image` but never `photoUrl`, and `'Member'` invented for an unresolved person) and is converged.
Its second site is institution identity, not person.

**`conversations_screen` is unreachable but NOT proven dead** — one file, no route, no importer, no test.
Recorded, not deleted: **FD-12** forbids precisely the naive zero-reference gate that would justify it.

**RoutedRecord: the union did not exist.** It read `['handle', 'handleOrSlug']`, and `handleOrSlug` is the
field a person's handle and an institution's slug share — so a consumer could not tell which authority
owned the value. The producer settles it: `InstitutionEngagementService.toDto` builds the author from a
`User` relation selected with **`PERSON_REFERENCE_SELECT`**, and never emits `handleOrSlug` on this
contract at all. **The client had invented an ambiguity the server never had.** The repair is to stop
reading a field that is never sent — **not** to add an actorType to discriminate a union of one. The author
is now `AuraPersonIdentity`. No Actor model invented, no identity authorities merged, and no route work:
`authorHandle` is never navigated.

**ACTIVE EXECUTABLE PERSON DEBT: 2 → 0.** Every person-identity site in the *surviving* product now
resolves through the one canonical reader. Surface **29 → 28**, typed-person **8 → 7**, both real
migration. **The detector was not touched** — no legacy exclusions, no suppressions, no baseline tricks.

**F116 and F053 remain PARTIALLY_VALIDATED.** Criteria 2, 3, 4, 6 NOT MET while 15 competing person
parsers are physically present and executable. This is a real milestone even though the finding is not
implementation-complete: what blocks it is not architecture that is wrong, but architecture that is
scheduled for deletion and has not been deleted.

**Observed and deliberately not fixed** (not identity, so out of this task's authorization): engagement
`postBody` reads `['body']` while the DTO emits `text`, so the post body never renders on either
engagement screen.

**Next frontier — the only thing that discharges the 15:** CO-RC-C7-005 Phase 5 legacy retirement, in its
recorded order. When those files are removed the sites disappear from the audit by deletion, the baseline
falls, and F116 criteria 2/3/4/6 are reassessed. Nothing here starts that retirement.

Record: `docs/portfolio/run/stage0-2026-08-18/05-execution/ch03-retirement-owned-debt-and-routedrecord.json`.

## 2026-08-19 — Engagement content contract repaired (non-identity)

The defect surfaced by the RoutedRecord trace and deliberately left for its own task. **The routed post
rendered on neither engagement screen.**

**Canonical field: `text`** — established from the producer chain, not from naming preference:
`Post.text` (prisma) → `post.text` (`EngagementRecordDto`) → `json['text']` (the client's own
`feed/domain/post.dart`). The engagement model read `post['body']` with a `postBody` fallback — **two keys
no producer has ever emitted**. The client was disagreeing with itself as much as with the server.

**Why it survived an alignment pass.** Commit 3dac187 ("align engagement repository and models with live
API response shape") corrected four sibling mismatches — `records`/`data`, `record`/`data`,
`needsResponse`/`pending`, `post.id`/`postId` — and walked past this one. All four had visible symptoms.
This one does not: every consumer guards with `if (content.isNotEmpty)`, so **a wrong key looks exactly
like a post with no text**. Worth remembering as a shape — a nullable field read through a key nobody
sends, consumed behind an emptiness guard, is invisible.

**No compatibility alias.** `body ?? text` would preserve the appearance of a dual contract where only
one has ever existed, and would make the mismatch permanently invisible rather than fixed.

**Two same-class stale reads fixed in the same parse:** `createdAt` read a top-level key the DTO does not
emit, so **both bylines were dateless** — now `post.createdAt`, and deliberately **not** `routedAt`, which
is a genuinely different fact (when the post reached the institution) and stays separate and unconsumed.
`institutionId` and `updatedAt` were always-empty-by-contract and were removed — the backend spec already
asserts institutionId is *deliberately* not exposed, so keeping a field that can only ever be `''` is the
same trap that produced this defect.

**Backend source unchanged** — the producer was never the defective side. Its spec gained two assertions
so the two contracts cannot drift apart in silence again.

**Tests:** 8 frontend (5 model + 3 widget), 2 backend. The widget tests drive the *real* list and detail
screens, because model tests could not have caught a defect that hides behind an emptiness guard. Seeded
proof: restoring `body` fails 4 of them.

Frontend **829 pass**, analyze clean, backend **205 suites / 2579**, tsc clean, Meetings **52 pass**,
identity gate unchanged, 451/451, 17/17. **No finding effects** — this was never an identity defect.

Record: `docs/portfolio/run/stage0-2026-08-18/05-execution/engagement-content-contract-repair.json`.

## 2026-08-20 — CO-RC-C7-005 Phase 5 readiness audit: NOT READY

Read-only audit. Nothing retired, no production polled or mutated, no migration run.

**The retirement is further away than the register implied, for five concrete reasons.**

**1. The history migration is a DATA migration, and the deploy path does not run it.**
`scripts/railway-start.sh` runs exactly `prisma migrate deploy` then Nest. Nothing anywhere invokes
`scripts/migrate-conversations.js` or `seed-public-spaces.js`. The 2026-08-20 deploy logs corroborate it
(`No pending migrations to apply` is the Prisma stage). **Pushing and deploying did not advance this
prerequisite** — §62's "run through the authorized deployment path" has to mean a founder-run step,
because the deployment path as coded does not contain one.

**2. There is no compatibility layer.** `ConversationsService` reads only `Conversation`,
`ConversationParty`, `ConversationMessage` and `ConversationHumanState`. It never touches `DirectThread`,
`Space`, `Thread` or `Message`. History is not adapted — it must be physically copied. **Until the
migration runs, every legacy conversation is reachable only through legacy code, and deleting the family
would make all of it unreachable** (the rows would remain; nothing could read them).

**3. Eleven backend files still produce `/me/correspondence/...` deep links** — activity-record,
attention-mapper, attention-policy, canonical-call-notification, communications, correspondence-orchestrator,
canonical-event, internal-reference, actor-notifications, notifications, communication-live. Exactly one
file emits the canonical `/messages/c/:id`. Those links are **already persisted** in production
notification and activity rows, so retirement breaks both history and new production.

**4. Correspondence is not merely parked.** `communication_resolver.dart` returns `/me/correspondence/...`
for thread and space targets and is consumed by `activity_screen` and `incoming_live_overlay`;
`route_normalizer.dart` normalizes `/correspondence` into it. Live code routes there today.

**5. `correspondence_identity.dart` is not discharged by retiring the surfaces.** Two live, non-retiring
consumers still import it: `mention_scope_providers` (8 remaining utility calls — the person read was
converged, the id/slug/logo/spaceId use was not) and the routed `invitations_screen` (7 invite helpers).
So **7 of the 15 identity sites carry a MIGRATE-FIRST precondition**. The count stays 15 and nothing was
reclassified — recorded rather than assumed away, because "the deletion will handle it" is exactly what
would leave 7 sites standing after Phase 5.

**Readiness:** additive deploy PARTIAL · history migration NOT COMPLETE/UNKNOWN · route+deep-link
migration NOT COMPLETE · founder observation OWED **and not yet meaningful** (observing before migration
would certify an empty list as correct) · certification OWED · manifest READY · approval NOT GRANTED.

**Rollback is understood and cheap:** retirement is code-only and deletes no data; the migration is
idempotent and additive; a revert restores the routes and the legacy rows are untouched. The real risk is
**address loss, not data loss**.

**Founder decisions owed — two:**
1. Authorize the read-only migration-status query (specified exactly in the record). Nothing downstream
   can be sequenced while "has the migration run?" is unknown. Note `--dry-run` alone will not answer it:
   it returns before the verification block and reports the legacy corpus only.
2. Persisted `/me/correspondence` deep links after retirement — add a redirect to the canonical
   conversation, or accept them as broken.

**Next step:** determine migration status read-only; if not run, run it through a founder-controlled path
and verify with the migrated-vs-legacy counts; only then begin the J1–J10 observation. **F116/F053 remain
PARTIALLY_VALIDATED** (active executable identity debt 0, retirement-owned 15). Retirement remains
unauthorized and unattempted.

Record: `docs/portfolio/run/stage0-2026-08-18/05-execution/co-rc-c7-005-phase5-retirement-readiness.json`.

## 2026-08-20 — Migration status: NOT_APPLIED (confirmed, read-only). Mutation authorization owed.

Founder authorized read-only production evidence. **Write protection was enforced by Postgres, not by
intent** — `SET SESSION CHARACTERISTICS AS TRANSACTION READ ONLY`, every probe inside
`BEGIN TRANSACTION READ ONLY … ROLLBACK`, with `SHOW transaction_read_only = on` captured as proof.
Method committed at `aura-backend/scripts/c7-migration-status-readonly.js`.

**Status: `NOT_APPLIED`. Zero migrated rows of any kind.**

| population | legacy | migrated |
|---|---|---|
| DirectThread | 5 | **0** |
| DirectMessage | 9 | **0** |
| eligible personal Spaces | 12 | **0** |
| eligible Space messages | 67 | **0** |

The 4 conversations / 20 messages already in canonical storage are **new-system rows** created since the
additive deploy — none carries a migrated id prefix. `ConversationHumanState` is **empty**: no read state
exists canonically at all. The corpus has **not drifted** since the 2026-08-16 design measurement, and the
two named spaces are still 'Aura Internal' (WORKROOM, 3 members, 1 msg) and 'family' (CIRCLE, 2 members,
3 msgs).

**Migration script safety audit: SAFE TO APPLY. No defect found; the script was not changed.** Every
INSERT target matches the live schema, all three `ON CONFLICT` targets exist, and every apply-blocking
data risk probed clean — NULL `body` 0, duplicate `(messageId,position)` 0 (that one matters: it is a
unique index that is *not* the conflict target, so a duplicate would have errored rather than skipped),
NULL `SpaceMember.userId` 0, the `'system'` fallback unreachable, and **directKey collisions 0**, so all 5
DirectThreads migrate with pair identity intact. The script has no wrapping transaction — safe **only**
because it is idempotent and restart-safe, which is stated plainly rather than left to look like a defect.

One thing that briefly looked like a defect and was not: a probe errored with `column "archivedAt" does not
exist` on `Conversation`. That was my query being wrong. Archive is per-person state on
`ConversationHumanState`, which is exactly where the script writes it.

**NEW SCOPE GAP — institution spaces are not migrated at all.** The eligibility filter is
`institutionId IS NULL`. Production holds 1 institution space / 1 thread / **2 messages**, which are
precisely the 2 of 69 Space messages outside the eligible set. Probably deliberate — the C7 Institutional
Conversation & Desk amendment is frozen separately — but **CO-RC-C7-005 does not name it**, and retiring
the family would strand that history.

**Deep-link mapping authority established (ruling: persisted links must not break).** The mapping is
**deterministic from the migration's own key scheme** — `sp:<spaceId>`, `dt:<threadId>`. No lookup table,
no heuristic, no participant guessing, no most-recent-thread inference. Backend owns new rows; a bounded
frontend translator owns old addresses; **no data mutation needed** — persisted rows keep their stored
address and resolve at navigation time. Unmappable cases named: multi-thread personal spaces (0 today),
institution spaces (1), and anything deleted before migration. **Not implemented** — gated behind status.

**Additive deploy, dimensionally:** HTTP health COMPLETE · canonical runtime COMPLETE · history canonical
**NOT COMPLETE** · old addresses reach canonical **NOT COMPLETE** · surviving consumers off retiring
identity **NOT COMPLETE**.

**NOT READY for founder live observation** — J1–J10 unchanged and still owed; running them now would
certify an empty list as correct. **NOT READY for retirement authorization.**

**Founder decisions owed — two:**
1. **Authorize the production migration apply.** `cd aura-backend && node -r dotenv/config
   scripts/migrate-conversations.js`. INSERTs only, into the five canonical tables; nothing written to any
   legacy table. Expect 17 conversations, 76 messages, up to 25 media joins. Verify with the read-only
   collector afterwards.
2. **Institution spaces** — retire with the family, migrate first under the frozen C7 amendment, or stay?

**F116/F053 unchanged at PARTIALLY_VALIDATED** (active executable identity debt 0, retirement-owned 15).
451/451, 17/17, Stage-0 ratified. Retirement remains unauthorized and unattempted.

Record: `docs/portfolio/run/stage0-2026-08-18/05-execution/co-rc-c7-005-phase5-retirement-readiness.json`.

## 2026-08-20 — Institution Spaces reconstruction: audit complete, held on four decisions

**Founder ruling recorded:** legacy message history has no strategic value and must not block
reconstruction. The migration is **HELD, not run**. No production data deleted.

**The finding that reframes everything.** Institution Spaces and the "legacy correspondence family" are
**the same code**. `/institution/:id/spaces/:spaceId` and `/me/correspondence/:spaceId` both build
`SpaceScreen`, separated only by whether an institutionId is passed; the institution thread route builds
the same `ThreadStateWrapper`. **Retiring the correspondence family as previously scoped would have
deleted the Institution Spaces product.** `space_screen.dart` is reconstruction-owned, not
retirement-owned — the 15-site count is unchanged, but what discharges it is this reconstruction.

**Two frozen doctrines collide.** The Institution Space Membership Doctrine (FROZEN 2026-08-13) requires
admin-governed roles and direct Add Member, with a frozen boundary that Space membership never becomes a
backdoor to Institution membership. The Conversation canon freezes **ORIGIN ≠ GOVERNANCE**, omits
participant removal in v1, and forbids **role vocabulary on ordinary conversations**. Both are
founder-approved. They cannot both describe one object.

**Cardinality has an evidence answer, not just an opinion.** The Thread table permits many threads per
Space; **all 13 production spaces have exactly one**. The multi-thread capability has never been used, and
the Conversation canon has no channel concept.

**Executed and unblocked — `CorrespondenceIdentity` is now retirement-local.** Both surviving consumers
moved off it: the invite helpers relocated to `features/invitations/data/invite_presentation.dart`
(relocation, not rewrite), and `core/tagging` got a local 4-line generic picker. Every remaining reference
outside the retiring family is a comment. **Honest consequence:** those invite helpers read people
*positionally* out of payload envelopes, so the move carried **five person-shaped reads into surviving
code**, where the detector cannot see them (nested path pairs, not flat alias lists). Recorded in the new
file as the reads to canonicalise when invitations is reconstructed — converging them now would have made
this a rewrite and hidden identity work inside a retirement chore.

**Four decisions owed before implementation** (§V forbids deciding these independently):

1. **D1 — Governance.** (A) Space governs access, Conversation parties derived — canon untouched;
   (B) adopt the TRANSFERABLE STEWARDSHIP primitive the canon itself anticipates, institution-owned
   conversations only — one membership model, deliberate amendment; (C) a third party-governed kind —
   rejected, that is how a new legacy gets built.
2. **D2 — Cardinality.** One Conversation per Space (recommended on the production evidence) or several.
   Decides navigation and notification shape.
3. **D3 — Realtime in this slice?** Conversation has a realtime adapter; canonical N-party group realtime
   is unverified. Meetings stays protected and is not to be reused.
4. **D4 — Visibility/taxonomy.** DISCOVERABLE has no canonical analogue and touches live/broadcast;
   SpaceType may be vocabulary the new product does not need.

**Next frontier:** D1 and D2 are the gate. With those ruled, the reconstruction is implementable
end-to-end without further decisions.

Record: `docs/portfolio/run/stage0-2026-08-18/05-execution/institution-spaces-reconstruction-record.json`.

## 2026-08-20 — Institution Spaces reconstructed (D1–D4 applied, locally certified)

**D1 Option A applied.** Space governs membership and access; Conversation serves communication among the
admitted. Parties are a **projection** of Space membership, implemented as **one synchronisation boundary**
(`institution-space-conversation.authority.ts`) rather than scattered `SpaceMember → ConversationParty`
writes. `syncParties` **reconciles the whole set rather than applying deltas** — a delta is correct only if
every mutation path remembers to call it, and a reconciliation is correct even after one forgot. A test
applies three membership changes with zero notifications and still converges.

**The Conversation canon is untouched.** No role vocabulary reached a conversation, no creator-admin
semantics, no removal governance. Setting `leftAt` when a Space removes someone is the projection reporting
that they no longer belong to the Space; an ordinary conversation has no Space to project from.

**D2 applied.** `Space.conversationId` (nullable, unique, FK), created **lazily** so Spaces predating this
architecture work without a production backfill. `createInstitutionSpace` **no longer creates a Thread** —
the block is deleted, not renamed.

**D3 applied as written**: realtime deferred, architecture not. No Space-local realtime stack exists; the
surface reuses `ConversationScreen`, so group realtime later arrives through
`RealtimeSessionSurfaceType.CONVERSATION` with nothing to undo. **Meetings untouched and not reused.**

**D4 applied.** SpaceType and DISCOVERABLE are not read, rendered or offered anywhere in the reconstructed
surface, and no renamed equivalent was introduced. The columns remain only because dropping them is a
destructive schema action and is not authorised. No product requirement for public Space discovery surfaced.

**New capability the legacy product never had: Remove Member** — the mirror of the frozen Add Member
doctrine, Space membership only (never institution membership), refusing to remove a sole owner.

**The frontend is a governance shell, not a second messenger.** `ConversationScreen` gained ONE optional
parameter that changes the header and Back destination. Timeline, composer, rich content, attachments,
media, read state and identity are the canonical implementation, unmodified — no `SpaceMessage`,
`SpaceAttachment`, `SpaceMedia`, `SpaceReadState`, `SpaceCall` or `SpaceNotification` was created.

**Three of our own ratchets fired on the new file and all three were right** — C1 caught role-as-permission
(`role == 'OWNER' || 'ADMIN'`, now a capability question the server answers), C3 caught two route literals,
C0 caught "Try again". Gates that only fire on other people's code are decoration.

**Legacy dependency severed.** Institution Spaces no longer depend on Thread, Message, `SpaceScreen`,
`ThreadStateWrapper` or `correspondence_identity`. That removes the institution-side obstacle to Phase 5;
the legacy runtime stays present and retirement stays unauthorised.

**ONE ADDITIVE PRODUCTION MIGRATION REQUIRED, NOT EXECUTED:**
`20260905000000_institution_space_conversation` — one nullable column, one unique index, one guarded FK.
No row written, no legacy table altered, nothing dropped. It applies on the next authorised deploy.

Backend **207 suites / 2594 tests** (+12 anti-drift), tsc clean, route guard green. Frontend **829 pass**,
analyze clean. Identity gate unchanged. Meetings 52 pass. 451/451, 17/17, Stage-0 ratified.
**F116/F053 unchanged** (active 0, retirement-owned 15 — no site artificially cleared).

**Next:** apply the migration on the next authorised deploy, then founder live observation of the
reconstructed Space journeys.

Record: `docs/portfolio/run/stage0-2026-08-18/05-execution/institution-spaces-reconstruction-record.json`.

## 2026-08-20 — Reconstructed Institution Spaces DEPLOYED; founder live observation OWED

**Founder authorised the additive migration.** `20260905000000_institution_space_conversation` was
re-verified before pushing rather than trusted from the commit that wrote it: three statements, all
additive and guarded — nullable `Space.conversationId`, `CREATE UNIQUE INDEX IF NOT EXISTS`, and an
existence-guarded FK. No `DROP`/`TRUNCATE`/`DELETE`/`INSERT`/`UPDATE`/`ALTER COLUMN`/`NOT NULL`; the only
DELETE/UPDATE text in the file is the FK's referential-action clause. **No backfill** — existing Spaces
carry NULL until first use, and Postgres permits many NULLs under a unique index.

**Pushed backend-first**, so the migration and API land before the client that calls them:
`aura-backend 879b205..8182bc6`, `aura-frontend 7eab7b7..a7396d8`. Both synced with origin/main.

**The startup guard was part of pre-deploy health deliberately.** Tests + tsc + migration safety are not
startup evidence — the 2026-08-20 crash loop passed all three and still refused to boot. Route-path
compilation spec PASS.

**HELD and unchanged:** the legacy history migration (`migrate-conversations.js` **not run**), legacy
message/Space deletion, table drops, destructive cleanup, arbitrary backfills. **Phase 5 remains
UNAUTHORISED.**

**Stage discipline:** deployment makes the reconstructed product **observable** and certifies nothing.
Observation is not retirement.

### FOUNDER LIVE OBSERVATION — 18 journeys, ordered as the product is used

Workspace → Space → membership/governance → conversation → rich content → continuity.

1. Institution workspace → Spaces list opens
2. Open a Space → **reconstructed** surface, title + purpose (not the old correspondence screen)
3. Create a Space → opens with an honest empty timeline
4. Open Members → roster with names/avatars, and the institution-membership disclaimer
5. **Add Member** → immediate membership for an eligible institution member, **no invitation step**
6. The added member can open the Space and read the timeline
7. **Remove Member** → loses access; conversation stops counting them
8. Sole-owner removal is **refused** with a reason
9. Removed person is **still an institution member** (frozen boundary)
10. Non-member is refused the Space and never obtains its conversation
11. Send a message → appears and persists
12. Reply, and a second member replies → one continuous thread
13. **Acting context** → personal vs institution voice, human actor still attributable
14. **Rich content** → image/document/media attach, render, open, save
15. Mentions resolve to the right person
16. Unread appears and clears
17. Hard-refresh / cold deep-link to `/institution/:id/spaces/:spaceId` reconstructs
18. **No legacy runtime** appears anywhere in the experience

**Not required:** old message chronology, legacy history visibility, realtime audio/video (D3 deferred),
archive/closure beyond what is currently implemented.

**Still visible, still owed:** the five nested positional person reads in `invite_presentation.dart` —
surviving identity debt the current detector cannot see. Not blocking; not canonical; an executable
cleanup item after observation.

**F116/F053 unchanged PARTIALLY_VALIDATED** (active 0, retirement-owned 15). 451/451, 17/17, Stage-0
ratified.

**Next:** founder performs the observation above; then journey certification, then retirement-readiness
reassessment. Nothing crosses into destructive retirement without its own authorisation.
