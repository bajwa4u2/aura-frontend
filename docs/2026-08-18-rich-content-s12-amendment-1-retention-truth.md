# §12 RICH CONTENT & INTERACTION — **AMENDMENT 1: RETENTION TRUTH**

**Date:** 2026-08-18
**Status:** FOUNDER-RULED. Amends the FROZEN §12 contract without reopening it.
**Parent contract:** `2026-08-17-rich-content-s12-freeze-candidate.md` (FROZEN, `cc56195`)
**Evidence basis:** `aura-backend/docs/2026-08-18-c2-unindexed-media-provenance-investigation.md` (`db41d5b`)
**Chain:** C1 `62b39bf` · C2 `4f20b62` · production reconciliation `8960e4b` · investigation `db41d5b`

---

## Why an amendment rather than an edit

§12 is frozen. The frozen text is **not wrong** — §7 already holds that the
reference graph is an index over authoritative composition tables, and that
release is soft with three independent deletion conditions. That design is
upheld here.

What the investigation established is that the **set of authoritative sources**
§7 enumerates is incomplete against production reality, and that one lifecycle
field silently conflates five distinct facts. Both are additive corrections to a
correct design, so they are recorded as an amendment. The freeze stands.

---

## A. ACCEPTED PRODUCTION EVIDENCE

Founder-accepted 2026-08-18:

- 150 Media rows at the earlier probe; the unindexed population grew 99 → 100
  during the investigation itself, because no producer calls `attach()`.
- **23 of the 100 are PROVEN in live use:** 12 live identity avatar/cover/logo
  assets · 10 legacy `MessageAttachment` assets · 1 `Article.bodyMarkdown`
  inline media reference.
- 6 further identity assets are strongly evidenced as **superseded**.
- 71 have **no surviving reference found** after exhaustive ID/URL scanning.
  **They are not to be called orphaned on that absence.**
- All 100 lack the current polymorphic attachment pointer.
- `confirmUpload` sets `orphanedAt` merely because `attachedToId` is absent —
  so `orphanedAt` currently means, in part, *"the producer did not use this
  attachment model"*, **not** *"the content is abandoned"*.
- At least **20 proven-live objects** satisfy the existing reaper deletion
  predicate today.
- The reaper is **manual/admin-triggered**, not cron-driven.
- Meetings use a separate storage/lifecycle universe and remain protected.
- REPLY is not an independent persistence authority; replies are `Post` rows and
  media composes through `PostMedia`.
- Identity relationships are presently represented as **URL strings**, not
  Media foreign-key/reference truth.
- Inline authored content can contain real Media references not represented in
  retention truth.

Accepted as a **material enlargement of F131** and as evidence for **F139–F142**.

---

## B. NEW FROZEN ARCHITECTURAL DISTINCTION

> ### ACQUISITION ≠ ATTACHMENT ≠ REFERENCE ≠ RETENTION ≠ PRESENTATION
>
> These are **five distinct facts**. No single field may silently collapse them.

| Fact | What it asserts | Where it lives | What it does **not** prove |
|---|---|---|---|
| **ACQUISITION** | how the bytes entered Aura | `Media.source` — CAMERA / GALLERY / UPLOAD / RECORDING / PASTE | ownership, attachment, abandonment, orphanhood |
| **ATTACHMENT** | a producer bound this object to a parent during composition | `attachedToType` / `attachedToId`, composition writes | that the binding is the *only* or *authoritative* one |
| **REFERENCE** | an authoritative record requires this content | composition tables, `Article.coverMediaId`, identity relationship (D-1), inline reference truth (D-5) | that the index knows about it |
| **RETENTION** | eligibility **derived** from authoritative references + lifecycle rules | `isRetentionEligible()` re-derivation | permission to destroy |
| **PRESENTATION** | this content was once rendered somewhere | notification payloads, activity records, event JSON | any retention right (D-2) |

**Frozen consequences:**

1. **Acquisition provenance never implies retention.** UPLOAD/GALLERY/RECORDING/
   CAMERA describe how bytes arrived and nothing else.
2. **`orphanedAt` is not authoritative evidence of abandonment** while legitimate
   producers can reach READY without the current attachment pointer. It presently
   conflates ATTACHMENT with RETENTION and must stop doing so.
3. **Presentation history is not retention authority** (D-2), and is not proof of
   discardability either.
4. **Retention is a derived consequence; storage deletion is a separate,
   irreversible execution decision.** The two must never be one step.

The governing question, in order, is:

> **"What authoritative fact requires this content to continue to exist?"**
> asked and answered *before*
> **"May this content be destroyed?"**

The goal is **not** a `ContentReference` table that looks complete on paper.

---

## C. FOUNDER RULINGS

### D-1 — IDENTITY MEDIA RELATIONSHIP · **YES, establish real authority**

Identity avatar, cover and institutional logo are **first-class Aura identity
assets**. The model must converge toward:

```
identity authority → authoritative Media relationship → governed Media delivery
```

and away from:

```
identity authority → arbitrary URL string → retention system guesses ownership later
```

- URL equality **may** be used for migration/evidence discovery. It **may not**
  become the constitutional relationship — URLs change, expire, are external, are
  transformed, and represent different delivery variants.
- The migration/compatibility path must be **additive**. Deployed identity
  consumers must not be broken.
- Existing URL fields **may remain transitional** while canonical Media identity
  is introduced and consumers migrate.
- This touches **canonical identity**. The shared boundary must be identified and
  affected identity consumers regression-tested. The broader identity system is
  **not** to be casually rewritten because C2 needs a relationship.

### D-2 — SUPERSEDED IDENTITY MEDIA IN NOTIFICATIONS · **no automatic retention right**

A delivered notification payload preserves an **event/fact**. It does not silently
become lifetime ownership of whatever avatar URL happened to be rendered then.

- The six superseded identity assets are **NOT authorized for deletion** and must
  not be deleted during this chapter.
- If Aura later requires immutable historical identity presentation, that becomes
  an **explicit snapshot/derivative/history policy** — never accidental retention
  through notification JSON.
- Preserve the evidence.

### D-3 — `hasLiveReference()` / REAPER BLIND SPOTS · **AUTHORIZED IMMEDIATELY**

First implementation action after the evidence commit.

**Monotonically protective. `uncertain/deletable → KEEP` is allowed;
`protected/keep → DELETE` is NOT.**

Must investigate and correctly cover authoritative structures including
`ConversationMessageMedia`, `Article.coverMediaId`, institution-post media,
message media, any other proven-authoritative composition table absent from the
check, and legacy `MessageAttachment` **where its canonical relationship can be
deterministically established**.

- Identity is **not** protected by URL heuristics here — D-1 owns that.
- **Do not run the reaper** after the correction.
- Tests must prove the previously blind relationships prevent deletion.
- **F142 is not closed merely because one function gained conditions.** Coverage
  of the known blind spots must be established.

### D-4 — REPLY REFERENCE TYPE · **RETIRE**

Replies are `Post` rows and compose media through `PostMedia`. No separate REPLY
retention authority is to be manufactured for enum symmetry. Retire through a
migration/compatibility-safe path; historical data must not be stranded.
POST-family composition truth owns this relationship.

### D-5 — INLINE AUTHORED MEDIA · **IN SCOPE**

A Media object does not lose retention rights because its reference occurs inside
authored content rather than an attachment join table. Applies conceptually to
article body content, rich text, pasted/inserted images, structured authored
documents, embedded Media, and future rich composition structures.

- **Permanent retention authority must NOT depend on regex-scanning Markdown URLs.**
- Legacy authored URL references may need discovery/backfill/migration treatment.
- Future rich-content composition must produce **explicit structured Media
  reference truth** through the shared Rich Content lifecycle.
- F141 belongs inside this chapter and must inform C2/C3 producer/reference design.

### D-5.1 — ARTICLE REVISION MEDIA RETENTION · **RULED 2026-08-18**

Resolves the open policy question D-5 deliberately refused to settle in code.

> **A retained `ArticleRevision` DOES confer retention on the Media required
> to faithfully reconstruct that revision.**

**Governing doctrine (frozen):**

> A durable authored revision must remain **faithfully reconstructable** for
> the duration of that revision's authoritative retention.

Therefore:

```
ArticleRevision
  → owns/records the authored state at that historical point
  → that state INCLUDES the Media necessary to reconstruct it
  → those Media relationships remain retained while the revision remains authoritative
  → when the revision is legitimately released/deleted per its OWN lifecycle,
    its media references may release
  → physical storage deletion still independently passes the storage-object
    retention authority (level 2, F143)
```

**The distinction this does NOT collapse.** Arbitrary historical URLs do not
gain permanent retention. Presentation history is still not retention
authority (D-2 stands unchanged — a delivered notification depicting an old
avatar confers nothing). What confers retention here is a **durable
authored record Aura deliberately preserves**, not the incidental survival of
a URL in a payload.

**Legacy content:** parsing/scanning remains permitted for discovery,
migration, reconciliation and backfill, and remains prohibited as permanent
constitutional retention authority. Unchanged from D-5.

**Forward architecture:**

```
revision creation
  → authored-state snapshot
  → STRUCTURED Media-reference snapshot
  → authoritative revision retention
```

A historical revision preserves **both** the authored content and the
structured reference set needed to reconstruct that authored state.

**Implementation status — recorded, NOT executed.** C2 is stopped at its
authorised boundary and was not reopened to satisfy this ruling. What already
exists (`dd025f5`): `ArticleRevisionMedia` captures the structured reference
snapshot at revision creation, and the retention gate honours it as a
fail-safe KEEP — so nothing is at risk in the interim. What this ruling now
**obliges and defers**:

1. Revision references become first-class in `ContentReference` (they were
   deliberately withheld pending exactly this decision), with a reference
   type/role that is derivable and reconcilable.
2. Release of revision media follows the **revision's** lifecycle, not the
   article's.
3. Reconstruction fidelity — not mere non-deletion — becomes the stated
   completion test.

This ruling is **canonical input to subsequent implementation planning** and
is owned by the portfolio layer, not by a resumed C2.

### D-6 — PRODUCER WIRING · **AUTHORIZED, SEQUENCED**

Not blind immediate wiring. Required order:

1. Protect existing known live relationships (**D-3**).
2. Establish/model missing authoritative relationships, especially identity (**D-1**).
3. Resolve truthful reference semantics — REPLY retirement (**D-4**), inline
   authored media (**D-5**).
4. Wire applicable producers **transactionally** through the shared reference path.
5. Reconcile again.
6. Demonstrate equivalence/coverage against production reality.
7. **Only then** propose any reaper authority change.

**The reaper remains outside this authorization.**

---

## D. MEETINGS BOUNDARY — accepted and recorded

Meetings occupy a **separate storage/lifecycle universe**:

- `MeetingAsset` has **no Media relationship** (`storageKey` matched 0 Media rows;
  `storageKey = Media.id` matched 0).
- `RealtimeSessionRecording.storageUrl` does not map to Media (0 matches).
- Meetings already own `retainedUntil` / `deletedAt` and cascade lifecycle semantics.

**Therefore the empty `MEETING` deriver is presently truthful**, not an omission.

**Recorded explicitly: `MEETING` is OUTSIDE the current Media/ContentReference
retention universe** unless a future approved architectural convergence changes
that fact.

Prohibited: creating a fake Media bridge · adding a Meeting deriver · modifying
Meeting storage · refactoring recording retention · changing Meetings.

This is a *deliberate external universe*, and must never be reported as an
unresolved blind spot.

---

## E. FINDINGS DISCIPLINE — kept separate, not merged

F131 is the **systemic** retention defect. F139–F142 are **independently
actionable manifestations/boundaries**. They intersect F131; that is not a reason
to merge them.

| Finding | Statement | Status |
|---|---|---|
| **F131** | Generalized retention failure — exception-list and incomplete-authority problem | **OPEN, enlarged.** Still unexercised by real data: production has zero article covers |
| **F139** | Identity media can become orphaned-at-upload and reaper-deletable despite active identity use | **OPEN** — owned by D-1 (structure) + D-3 (protection) |
| **F140** | Legacy `MessageAttachment` media invisible to C2 and current cleanup authority | **OPEN** — D-3 where deterministic; §14 retirement path owns the rest |
| **F141** | Media referenced inside authored content can exist outside structured retention truth | **OPEN** — owned by D-5. Lineage note: distinct from but adjacent to **F121** (baked signed URLs in article markdown, §14). F121 is a *delivery/representation* defect; F141 is the *retention* consequence. Not merged |
| **F142** | Cleanup authority omits authoritative composition/reference structures | **OPEN** — D-3. Not closable by adding conditions alone; coverage must be established |
| **F143** | **NEW 2026-08-18.** Media identity is not 1:1 with storage objects — deleting an unreferenced row frees an object that referenced rows still address | **OPEN** — protection landed in D-3. Production holds 10 duplicate/canonical pairs; the duplication itself needs a disposition under D-6 |

**F143 detail.** `deleteObject()` acts on a storage KEY while protection was
evaluated per Media ROW. Ten production pairs exist in which an unindexed
duplicate addresses the identical R2 object as a live, **indexed** correspondence
attachment. Collecting the duplicate would have left ten *protected* rows READY
with no bytes behind them. It also corrects §A's cohort reading: those ten rows
are duplicate Media rows for already-indexed objects, not merely legacy
attachments the index cannot see. Protection is now evaluated per **object**.

Also carried forward unmerged: **F126** (app-level disclosure) and **F138**
(storage boundary performs no authorization). All 100 investigated rows are
`visibility = PUBLIC`, consistent with F138. No R2 public-read ratchet performed.

---

## F. R&D EVIDENCE — record only

> Internal consistency of a derived model is not proof that the model corresponds
> to complete authoritative reality.
>
> Absence of evidence from a partial derived model is not authoritative evidence
> of absence, particularly when the resulting action is irreversible.

Instance: the derived `ContentReference` model was internally consistent and
reported **zero divergence** across its modelled universe, while an exhaustive
production investigation found **23 unindexed Media objects provably in live use**.

**Record only. No R&D implementation in this workstream. No novelty claimed.**

The operational encoding already exists in §12 and is reaffirmed: a partial model
may authorize **retention** on its own; it may never authorize **destruction**.

---

## G. HARD STOPS IN FORCE

Do not: run `MediaCleanupService`/the reaper · delete any of the 100 investigated
objects · delete the six superseded identity assets · classify the 71
no-reference-found rows as orphans without authoritative proof · mutate production
data to make the index reconcile · let `ContentReference` alone authorize deletion
· use URL equality as permanent identity authority · use Markdown regex scanning
as permanent inline-media authority · modify Meetings · advance to C5 · perform
the R2 public-read ratchet · collapse F126/F138/F131/F139–F142 · silently decide
any newly discovered product/architecture contradiction.

**Return before reaper authority or C5.**

---

## H. AMENDMENT EFFECT ON §12 SECTIONS

| §12 section | Effect |
|---|---|
| **§7 Reference/Retention model** | Design upheld. Authoritative source set **extended**: identity relationship (D-1), inline authored reference truth (D-5). `REPLY` **retired** from the closed type set (D-4). `MEETING` recorded as a deliberate external universe |
| **§4 Governed vocabulary** | Gains the frozen five-fact distinction in **§B** above |
| **§13 Authority boundaries** | Unchanged. Identity remains surface-owned; Rich Content owns reference/retention *mechanics*, not identity policy |
| **§14 Migration/retirement** | `MessageAttachment` retirement now additionally gated on F140 coverage |
| **§16 Implementation stages** | C2 gains the D-1/D-4/D-5/D-6 completion work before any reaper authority change |
| Everything else | **Unchanged. §12 remains FROZEN.** |
