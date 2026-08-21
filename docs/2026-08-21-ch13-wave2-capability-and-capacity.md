# CH-13 Wave 2 — the draft claim, and capability that is not a habit

**Date:** 2026-08-21
**Scope:** CO-RC-C5-007 closed · all six composers converged · attachment type and
media capacity reconstructed.

---

## 1. CO-RC-C5-007 — closed

### The exposure, quantified

`institution_post_composer_screen` autosaved a **recoverable** draft to
SharedPreferences (`localStorage` on web) holding an uploaded `mediaUrl`, with
no server row behind it. The chain was exact:

1. Cover uploaded → `Media` row READY. `MediaService` stamps
   `orphanedAt = now` at confirm for any object with **no** `attachedToId`.
2. `_scheduleDraftSave()` wrote the draft to localStorage. It is now genuinely
   recoverable — a refresh reopens the composer with the cover.
3. No server row → no `InstitutionPostMedia` → no `ContentReference`.
4. `hasLiveReference()` false, `orphanedAt` older than `orphanRetentionDays`
   (**7 days**) → the abandoned-upload sweep reclaims it.
5. The person reopens a draft they can still see; the cover is a dead URL.

**The window was 7 days.** Not a fault in the reaper — an unasserted claim.

### The closure

No timer, and no longer retention window. The draft is made **real**: a
server-side DRAFT post carries an `InstitutionPostMedia` link, one of the
authoritative sources `ContentReference` derives from. The media is protected
for exactly as long as the draft exists and becomes reclaimable the moment it
does not.

`_ensureServerDraftClaim()` promotes as soon as there is anything worth
recovering. A DRAFT create needs only title and body — `primaryTopic` is
optional on the backend even though the *publish* gate requires it — so a
half-finished composition is claimed rather than left exposed precisely when it
is most likely to be abandoned.

**The invariant:** *a local draft never records media the server cannot see.*
If a claim cannot be made, the draft keeps its text and records **no** media at
all, rather than promising a cover that retention authority cannot protect.

Two further defects were found and fixed while closing it:

* The composer **discarded `result.mediaId`**, keeping only the URL. Server
  identity is the only proof an upload finished; it is now retained.
* A reopened draft would have minted a **second** DRAFT post, leaving the first
  behind holding a reference nobody could see or release. `serverDraftPostId`
  is persisted, and `_commitComposition()` gives save and publish one path that
  reuses the existing claim.

### Against the founder's five conditions

| Condition | Evidence |
| --- | --- |
| Every recoverable draft with media has a server-visible claim | `_ensureServerDraftClaim()`; local draft records media only when `_draftClaim == serverHeld` |
| Transient composition creates no false durable ownership | Nothing is claimed until title+body exist; before that the local store already declines to persist |
| Abandoned media stays reclaimable | Release is soft — the link drops on the next autosave; the reaper decides, not the composer |
| Cleanup re-derives rather than trusting counters | Untouched. No cleanup code was changed in Wave 2 |
| No arbitrary draft-lifetime timer | None introduced; no retention constant added or changed |

---

## 2. Capacity — every ceiling is now a constraint

### What actually bounds a ceiling

Bytes reach storage through a **presigned PUT** and never traverse the API
process, so the API's 1 MiB JSON body limit does not bound media and never did.
The binding constraint is the founder-frozen invariant already in the codebase:

> *if Aura accepts an object, Aura's required safety examination must be
> CAPABLE of examining it.*

`MAX_EXAMINABLE_BYTES` (32 MiB) is how much an examiner holds in memory at once.
It bounds every capability that parses a **whole** file — image, audio structure,
document. Malware scanning and container sanity **stream**, which is why video
stands higher.

### Every cap found

| Cap | Layer | Was | Now | Reason |
| --- | --- | --- | --- | --- |
| IMAGE | backend `maxBytesFor` | 10 MiB | **32 MiB** | whole-file examination bound |
| AUDIO | backend `maxBytesFor` | 25 MiB | **32 MiB** | whole-file examination bound |
| DOCUMENT | backend `maxBytesFor` | 25 MiB | **32 MiB** | whole-file examination bound |
| VIDEO | backend `maxBytesFor` | 150 MiB | 150 MiB | streamed; this is the accepted envelope the malware invariant is measured against |
| image | institution post composer | 8 MiB | **retired** | private constant, no measured basis |
| video | institution post composer | 50 MiB | **retired** | private constant, no measured basis |
| any | conversation composer | none | canonical | had no client cap at all |
| API JSON body | `main.ts` | 1 MiB | 1 MiB | does not bound media — presigned PUT bypasses it |
| multipart media | `mime-policy.ts` | 25 MiB | 25 MiB | legacy `/uploads/media` route; presign path is the modern door |
| avatar | `mime-policy.ts` | 5 MiB | 5 MiB | identity imagery, deliberately tight |
| logo / cover | profile screens | 2 / 4 MiB | 2 / 4 MiB | identity imagery, deliberately tight |

Capacity is now judged **once, at the intake door**, against `MediaCapacity`.
No migrated composer retains a legacy ceiling.

**Remaining ceilings and why they stay:** VIDEO at 150 MiB is the accepted
envelope; raising it requires the malware examiner to rise with it, and clamd's
`MaxFileSize` lives in a **separate service with no repo or image source in this
codebase** (F137), so it cannot be moved from here. That is a genuine
infrastructure blocker, surfaced rather than backlogged. The three identity
caps (avatar/logo/cover) are deliberate product tightness, not historical drift.

---

## 3. Type capability

### Inventory

| Class | Doors | Resolver | Validation | Storage | Presentation | Disposition |
| --- | --- | --- | --- | --- | --- | --- |
| Image (jpeg/png/webp/gif) | picker · paste · drop | `ContentIntake` | mime + kind + capacity | presigned PUT | inline | supported |
| Video (mp4/webm/quicktime) | picker · drop | same | + duration | presigned PUT | player | supported |
| Audio (9 types) | picker · recording | same | + duration | presigned PUT | voice player | supported, **3 newly accepted** |
| Document (pdf/doc/docx/xls/xlsx/ppt/pptx/rtf/txt/csv) | picker · drop | same | mime + capacity | presigned PUT | attachment card | supported |
| Archive (zip) | picker · drop | same | mime + capacity | presigned PUT | attachment card | supported; frontend models it as DOCUMENT |
| HEIC / HEIF | picker · drop | resolves, then **refused** | — | — | — | **blocked, see below** |
| SVG | — | — | — | — | — | refused at five gates, P0 security, deliberate |

### Newly / convergently supported

`audio/mp3`, `audio/m4a`, `audio/x-aac` — present in the backend's canonical
matrix all along and refused **only** by the frontend mirror. A browser naming
the same bytes differently was turned away at the client.

### Previously refused or inconsistently handled

* **DOCX → octet-stream late refusal.** Four composers resolved mime themselves
  and fell back to `application/octet-stream`, which the presign allow-list
  refuses. The file appeared attached, climbed, and failed with a generic
  message. Fixed at the door in all of them.
* **Caller-declared kind.** `compose_screen` took `kind` from whichever button
  was pressed and never checked it against the content.
* **Guessed image mime.** `article_editor_screen` used `?? 'image/jpeg'` twice.
* **Silent drops.** Both announcement composers `continue`d past a file with
  missing bytes without a word.
* **Per-composer type policy.** Each declared its own allow-list check.

### Remaining unsupported, with the exact reason

| Format | Reason |
| --- | --- |
| **HEIC / HEIF** | `inferMimeFromFileName` already maps `.heic`→`image/heic`, so an iPhone photo resolves correctly and is then refused by the allow-list. Accepting it needs **transcoding**: no browser but Safari renders HEIC, so Aura would store images most viewers cannot see. A real processing dependency, not a policy choice. **Needs founder direction.** |
| **AVIF / JXL** | Same shape, weaker case — narrower capture-side pressure than HEIC. |
| **SVG** | Deliberately refused at five gates as a P0 security measure. Not a gap. |
| **MKV / AVI** | No transcoding pipeline; would store video many clients cannot play. |

---

## 4. `wireKind` — a compatibility boundary, held there

Per founder ruling the released contract is preserved and **not** unified. The
collapse is an explicit `collapseDocumentToImage` parameter, defaulting to
released behaviour. Conversation continues to send `'DOCUMENT'` (25 MiB → now
32 MiB bucket); the other composers continue to send `'IMAGE'`.

Critically, the compatibility answer **does not reach the canonical layer**:
`ContentIntake`, `AttachmentLifecycle` and `CompositionAuthority` all speak
`AttachmentKind` and never the wire string. `wireKind` is called only at the
upload call site.

**Retirement path:** convergence requires (a) client/version telemetry showing
which installed builds still send the collapsed kind, (b) a separately
authorized wire-contract migration, (c) confirmation that the DOCUMENT bucket
applies to all callers before IMAGE senders are moved. None is engineering-only.

---

## 5. ARTICLES ENGAGEMENT — the owed audit, now done

Recorded as owed on 2026-08-21 and never performed. Implementation remains out
of scope by standing ruling; **this is the measurement, not a change.**

`src/articles/articles.controller.ts` exposes **eight** endpoints:
`GET /`, `GET /by-slug/:slug`, `POST /`, `GET /mine`, `GET /mine/:id`,
`PATCH /:id`, `POST /:id/publish`, `DELETE /:id`.

That is authoring and reading. **There is no engagement capability of any
kind** — no like, reaction, comment, reply, share, repost, bookmark/save,
view count or translate.

The structural finding is sharper than "missing features":

* `model Reaction` is **Post-bound**, not polymorphic — `postId String` with a
  required FK to `Post`. `model Save` is the same shape.
* The `Article` model carries **no** engagement relation at all.

So Articles cannot reuse Aura's existing engagement primitives. Closing the gap
requires either a migration making reactions/saves polymorphic across content
types, or representing Articles as Posts. **That is an architectural decision
with a schema migration behind it, and it belongs to CH-14 with founder
direction.** It is carried here so it is not lost, not started.

---

## 6. Wave 2 remainder

All six measured composers now resolve acquisition through `ContentIntake`.

| Surface | State |
| --- | --- |
| `conversation_screen` | fully migrated (Wave 1) — state, phase, readiness, all three doors |
| `institution_post_composer_screen` | migrated — intake, capacity, **draft claim** |
| `compose_screen` | intake + capacity + kind verification; still holds its own multi-attachment state machine |
| `announcement_editor_screen` | intake + capacity + spoken refusals; own state |
| `institution_announcement_composer` | intake + capacity + spoken refusals; own state |
| `article_editor_screen` | intake + capacity + readable refusals; own cover/inline state |

**Not yet converged:** the four surfaces above still keep private
readiness/`_uploading` state rather than `CompositionState`. That is the next
increment; their acquisition, type and capacity answers are already canonical,
which is where every measured defect lived.

**Chapter boundary respected:** drag/drop remains jointly owned with C9. Shared
`ContentIntake` is consumed; no C9-owned product behaviour was reconstructed.
