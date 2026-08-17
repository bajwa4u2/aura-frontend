# §12 — PROPOSED RICH CONTENT & INTERACTION CONTRACT

**Status:** PROPOSED — not frozen. Founder review required before Phase C.
**Date:** 2026-08-17 · **Evidence base:** `2026-08-17-rich-content-system-audit.md`
(frontend + backend capability audit) and the F126 correction.

---

## 0. THE ONE IDEA

Aura does not need a new content system. It needs the system it already has to
become **one lifecycle instead of nine parallel half-lifecycles**.

The audit found competent authorities (MIME policy, R2 client, media lifecycle,
SSRF-safe fetching, internal-reference resolution) surrounded by surfaces that
each re-derive the same decisions differently. The contract below does not
replace those authorities. It **names the decisions they were never asked to
make**, and makes every surface consume them.

Three structural moves carry most of the value:

1. **Content truth becomes layered evidence**, not a client claim.
2. **Retention becomes a reference graph**, not a per-surface exception list.
3. **Derivatives become first-class rows**, not six ad-hoc URL columns.

Everything else follows from those.

---

## 1. PROPOSED CANONICAL ARCHITECTURE

### 1.1 The content envelope (question A)

**Proposal: an envelope, expressed as a shared contract — NOT a new owner table.**

Every Aura composition surface already stores the same three things in
de-normalized form: a body, an ordered set of media links, and zero or more
references (`linkPreviewId`, internal refs). Conversation, Posts, Announcements,
Institution Posts and Correspondence each re-invent the projection of that shape
(backend duplication #4: four different URL-preference chains).

```
ContentEnvelope
  ├─ body            RichText            (markdown + inline spans)
  ├─ parts[]         ContentPart         (ordered, role-tagged)
  └─ references[]    ContentReference    (internal Aura + external URL)
```

```
ContentPart
  ├─ mediaId         canonical Media id
  ├─ position        int
  ├─ role            ContentRole   (ATTACHMENT | VOICE_MESSAGE | VIDEO_MESSAGE
  │                                 | COVER | INLINE | DOCUMENT)
  └─ caption?        string
```

**Why an envelope and not blocks.** A block model (Notion/Editor.js style) would
be the "purer" answer and is the wrong trade here: it forces every surface onto a
new persistence model, destabilizes certified surfaces, and buys expressiveness
Aura's communication surfaces do not yet need. The envelope describes what the
data **already is**, so it can be adopted incrementally, surface by surface,
without a big-bang migration.

**Why not a flat Media object.** A flat object cannot express "this voice message
is the message" versus "this file is attached to the message" — a distinction
questions J and K require.

**Critical boundary (question O).** The envelope is a **projection contract**,
not a table. Each surface keeps its own tables and its own authority over who
may compose, read, edit and delete. Shared code owns the *shape* and the
*resolution*; domain authorities own the *permission*. This directly honours
"generalize capability, do not centralize domain authority into media."

### 1.2 Content roles carry communication semantics (questions J, K)

A voice message and an audio attachment are **the same Media with different
roles**. A video message and an attached video, likewise.

| Concern | Owner |
|---|---|
| storage, MIME truth, derivatives, access | canonical Media authority (shared) |
| "this is a voice message" | `ContentPart.role` (envelope) |
| recording UX, composer rules, presentation | surface + shared presentation primitives |

This avoids the trap of a separate voice-message storage universe, while letting
Conversation present a waveform-and-scrubber where Posts would present a plain
audio player.

---

## 2. LIFECYCLE

```
ACQUIRE → NORMALIZE → INSPECT → VALIDATE → SECURE → STORE
        → PROCESS → ENRICH → PERSIST → HYDRATE → PRESENT → INTERACT
        → GOVERN → RETAIN/DELETE
```

Mapped to real boundaries (not one-to-one, per §7 of the directive):

| Responsibility | Where it lives |
|---|---|
| ACQUIRE, NORMALIZE | client acquisition layer (one intake, many doors) |
| INSPECT, VALIDATE | `presign` (declared) + `confirmUpload` (actual bytes) |
| SECURE | access-context authority (visibility at ingestion) |
| STORE | R2 client (unchanged) |
| PROCESS, ENRICH | **new** media worker (async) + bounded sync probe |
| PERSIST | Media + MediaDerivative + ContentReference |
| HYDRATE | delivery authority (batch) + client resolver |
| PRESENT, INTERACT | shared presentation primitives |
| GOVERN | owning surface authority |
| RETAIN/DELETE | reference-graph cleanup |

### 2.1 Acquisition is one family (question A, directive §8)

**Frozen intent: ACQUISITION METHOD IS NOT PRESENTATION IDENTITY.**

All doors — typed, paste (plain/rich/image), drag-drop, picker, camera,
microphone, voice/video message capture — converge on a single client
`ContentIntake` producing a normalized `StagedContent` before anything is
uploaded. Downstream code never re-asks which door was used.

`MediaSource` (CAMERA|GALLERY|PASTE|RECORDING|UPLOAD) is retained and finally
**told the truth** — F123 exists because Conversation hardcodes `GALLERY`.
Source becomes provenance metadata, never a presentation input.

---

## 3. CONTENT TRUTH / SECURITY ARCHITECTURE (question B)

**Invariant: A FILE IS NOT TRUSTED MERELY BECAUSE THE CLIENT NAMED ITS TYPE.**

Six distinct layers, never collapsed:

| # | Layer | Source | When |
|---|---|---|---|
| 1 | declared | client `contentType` | presign |
| 2 | transport | R2 HEAD `ContentType` | confirm |
| 3 | signature | magic bytes (first N) | confirm |
| 4 | container | archive/OOXML inspection | confirm |
| 5 | structural | dimensions, page count, duration | confirm (cheap) / worker |
| 6 | **resolved** | the authority's verdict | confirm |

**Container formats are the reason layer 4 exists (directive §3).** DOCX, PPTX,
XLSX and ODF are all ZIP archives sharing one signature `50 4B 03 04`. Signature
alone cannot distinguish them from a plain `.zip`, or from each other. Resolution
requires reading the archive directory:

- `word/document.xml` → DOCX
- `ppt/presentation.xml` → PPTX
- `xl/workbook.xml` → XLSX
- none of the above → ZIP (or reject)

This is exactly the "one-signature-equals-one-MIME" assumption the directive
warns against, and it is why content truth is an **authority with a verdict**,
not a lookup table.

**Honest limits.** `text/plain` and `text/csv` have no signature and are
structurally unverifiable. They resolve as `UNVERIFIABLE` and are governed by
policy (allowed, but never served with an HTML-capable content type). This
limitation is stated rather than hidden.

**Verdict dispositions:** `CONFIRMED` · `CORRECTED` (declared wrong, actual
allowed → canonical type replaced) · `REJECTED` (actual not permitted) ·
`UNVERIFIABLE` (no signature possible; policy decides).

**Closes:** F127 (no magic-byte validation), F130 (unvalidated presign DTO —
replace the dead inline `type` with the existing validated class), F122
(wire-kind inconsistency: one resolved type, one wire vocabulary).

**Preserved unchanged:** the 28-type allowlist, unconditional SVG block, per-kind
size/duration limits, sanitized filenames, presigned upload/download governance,
SSRF protections, storage authorization.

**Also closed here:** F128 — `confirmUpload` already HEADs the object and receives
`ContentLength`; it must **reject** over-limit objects rather than reconcile them.
Plus a `content-length-range` condition on the upload where the presign flow
supports it.

---

## 4. OWNERSHIP / ACCESS ARCHITECTURE (question C)

**The F126 lesson, generalized: content must not accidentally acquire public
access as an intermediate default state.**

Today: born PUBLIC, tightened later, *if the surface remembers*. Conversation
forgot. That is not a bug class we should be able to have twice.

**Proposal — access context declared at ingestion:**

```
presign(..., intendedParent: { type: MediaParentType, ... })
   → visibilityForParent(intendedParent)   // fail-closed authority
```

`visibilityForParent` generalizes the `media-visibility.authority.ts` seeded
during Phase A. Unknown or absent context → **RESTRICTED**. PUBLIC is something
a surface must *assert*, never something media *drifts into*.

**Staged, because it cannot be flipped in one move.** Posts depend on born-PUBLIC
media, and `canAccessRestricted` denies POST parents outright, so flipping the
column default today breaks post imagery platform-wide:

1. Add `intendedParentType` to presign; resolve visibility from it. Legacy
   callers omitting it keep today's behaviour.
2. Implement the missing `canAccessRestricted` branches (POST/REPLY today deny
   unconditionally — user-post media has no restricted path at all).
3. Convert surfaces one at a time, each with its own access test.
4. When every parent family declares context, **flip the column default to
   RESTRICTED** and delete the legacy branch. Ratchet test prevents regression.

**Closes:** F126 architecturally (already corrected surgically), and the
"least-protected private surface" class of defect.

---

## 5. RETENTION (question D)

**F131 must not become a cleanup-reaper exception list.**

Today retention is a single `attachedToId` stamp plus ad-hoc `delete()` checks
that already miss `messageLinks`, `institutionPostLinks` and
`conversationMessages`. `Article.coverMediaId` has no stamp at all, so the reaper
deletes published article covers.

**Proposal — a reference graph:**

```
ContentReference
  id, mediaId, referenceType (MediaParentType + ARTICLE, PROFILE, MEETING…),
  referenceId, role (ContentRole), createdAt, releasedAt?
  @@unique([mediaId, referenceType, referenceId, role])
```

Retention becomes one question, asked once:

> Does this media have at least one un-released reference?

No per-surface exceptions, ever. A new surface that forgets to write references
fails its own attach test, rather than silently causing data loss later.

**Relationship to existing join tables.** They stay — `PostMedia.position/caption`
etc. are *composition* semantics owned by the surface. `ContentReference` is
*retention* truth. Both are written by one shared `attachContent()` helper,
which also collapses backend duplication #3 (five independent stamping writers).

**Backfill:** derive rows from every existing join table, `attachedToId`, and
`Article.coverMediaId` before the reaper next runs. `Article.coverMediaId` also
gains a real Prisma relation (F131), and `ArticleRevision` should snapshot the
cover, which it currently does not.

---

## 6. ORIGINALS AND DERIVATIVES (question E)

Today: six URL columns on `Media` (`url`, `originalUrl`, `displayUrl`,
`playbackUrl`, `thumbUrl`, `thumbnailUrl` — the last two are literal duplicates),
each surface picking a different preference chain, and for images the
"thumbnail" is the **full-resolution original**.

**Proposal:**

```
MediaDerivative
  id, mediaId, kind, url, mimeType, width?, height?, bytes?,
  pageIndex?, status, error?, createdAt
  @@unique([mediaId, kind, pageIndex])
```

`kind`: `THUMBNAIL` · `PREVIEW` · `POSTER` · `OPTIMIZED` · `WAVEFORM` ·
`DOCUMENT_PAGE` · `TRANSCODE`.

- `Media.url` remains the **original**, always preserved.
- Selection is a query, not a guess: "smallest derivative ≥ requested size, else
  original."
- **A failed derivative never fails the media.** `Media.status` stays READY; the
  derivative carries its own status and error. This is the F-series lesson that
  a broken thumbnail must not destroy a successfully delivered message.
- Retire `thumbUrl`/`thumbnailUrl` duplication behind a compatibility read.

---

## 7. PROCESSING ARCHITECTURE (question F)

The audit found `PROCESSING`, `markProcessing`/`markReady`, the
`x-media-worker-token` gate and worker-only URL writes — **scaffolding for a
worker that does not exist.** The contract is largely a matter of *building the
thing the schema already expects*.

**Synchronous (at `confirmUpload`, bounded, no decoding of untrusted media):**
magic-byte + container inspection, image dimensions from headers, PDF page count
from the trailer, declared-vs-actual reconciliation, size enforcement.

**Asynchronous (worker):** thumbnails, optimized derivatives, EXIF stripping
(F132), video posters and transcodes, audio duration + waveform (F136), document
page renders.

**Boundary:** a queue table (`MediaProcessingJob`) polled by a separate Railway
service authenticating with the existing `MEDIA_INTERNAL_TOKEN`. No new auth
model is required — the gate already exists.

**Partial failure is normal, not exceptional.** Each job targets one derivative;
failure marks that derivative FAILED with a reason and leaves the media usable.
Retry is explicit and bounded.

**Provider independence (standing doctrine).** Every processing capability needs a
**self-hosted tier-0 default**; external services may only ever be tier-1
enrichment. Candidate tier-0: `sharp` (libvips) for images, `ffmpeg` (LGPL build)
for audio/video, a PDF rasterizer for documents. **Not frozen here** — see §12
unresolved decisions, including a real licensing hazard.

---

## 8. PRESENTATION / HYDRATION ARCHITECTURE (questions G, H, I)

**Frozen intent: the generic container is a fallback state, never the target.**

Presentation resolves from **(resolved type × available derivatives × access
state × role)** — never from the acquisition door, never from a file extension
alone.

**Degradation chain** (each step is a truthful state, not a failure):

```
native rich  →  reduced rich  →  identity card  →  generic  →  explicit error
```

An image that has no thumbnail yet still renders as an image (from the original,
sized down) rather than collapsing to a pill.

**Documents become first-class (question I).** Filename, real extension identity,
size, page count, first-page preview derivative, inline PDF viewer, explicit
open/download. A document is a document, not "Attachment".

**Audio/voice (question J).** A real audio player: duration, elapsed/remaining,
**seek**, waveform where a derivative exists, speed control where appropriate.
Aura currently has no audio package at all and plays voice notes through
`video_player` with a play/pause pill — this is the single largest presentation
gap found.

**Video (question K).** Poster derivative, inline playback, seek. Feed surfaces
today render video as a still image.

**Links (question L).** External previews keep the existing SSRF-safe fetcher
**unchanged**; internal references keep delegating to owning domain authorities
**unchanged** — the audit found both to be correct. The only additions proposed
are batching/caching (internal refs re-resolve on every message list fetch) and
optional OG-image mirroring (F135, privacy — see unresolved decisions).

**Interaction (question H).** Shared primitives keyed to *content capability*:
select · copy · paste · drag · drop · attach · open · expand · play · seek ·
save · download · retry · reply · share · translate. A surface enables the set
its domain permits; it does not re-implement them.

**Shared client primitives replace the 16 duplicated concerns**, and Conversation
— the only surface with both drag-drop and clipboard-image paste, and the one
bypassing nearly all shared infrastructure — is where they get proven.

---

## 9. FAILURE MODEL (question M)

Never collapse distinct truths into "attachment unavailable":

| State | Meaning | Retryable |
|---|---|---|
| `LOCAL` | staged, not uploaded | — |
| `UPLOADING` | bytes in flight (progress, cancellable) | yes |
| `CONFIRMING` | verifying against storage | yes |
| `PROCESSING` | derivatives being produced | — |
| `READY` | usable | — |
| `UPLOAD_FAILED` | transport failed | yes |
| `REJECTED` | validation/content-truth refusal | **no** — user must act |
| `PROCESSING_FAILED` | derivative failed; original intact | yes (derivative only) |
| `HYDRATION_FAILED` | delivery/network failure at read | yes |
| `ACCESS_DENIED` | authorization refusal | no |
| `REMOVED` | deleted/expired | no |

These map onto the existing `MediaStatus` enum where possible; the read-side
states (`HYDRATION_FAILED`, `ACCESS_DENIED`) are **client-side truths**, not
columns.

**Closes F058's real damage:** today a CORS rejection, a 404 and an expired
signature render the identical broken tile. Those are three different truths and
must read differently.

---

## 10. PERFORMANCE (question N)

- **Derivative selection** by requested render size; never the original for a thumb.
- **Batch delivery-URL endpoint** — today clients resolve one media id at a time;
  a 20-image thread is 20 round trips.
- **Upload**: progress (already produced, mostly discarded), **cancellation**,
  **timeout**, **bounded retry**, streaming rather than whole-file-in-memory,
  and chunked/resumable upload for large files (the multipart machinery already
  exists for meeting recordings and can be generalized).
- **Hydration cache** with in-flight dedup and expiry-awareness — the client
  resolver already does this well and becomes the single path.
- **Lazy hydration** for offscreen content; explicit player disposal.

---

## 11. SURFACE INTEGRATION MODEL (question O)

| Shared (Rich Content system) | Owned by surface (unchanged) |
|---|---|
| acquisition/intake normalization | who may compose |
| content-truth resolution | who may read |
| storage + presign governance | who may edit/delete |
| access-context → visibility authority | publication state |
| derivatives + processing | institutional authority |
| reference graph + retention | discourse/integrity rules |
| delivery/hydration | moderation decisions |
| presentation + playback primitives | retention policy inputs |
| interaction primitives | continuity semantics |

**Meetings, realtime calls, group audio/video, screenshare, Live escalation and
Conversation party truth are PROTECTED.** The only intersection this contract has
with them is that meeting recordings already use the multipart upload path being
generalized — a boundary to be identified and regression-tested explicitly
before it is touched, not assumed safe.

---

## 12. MIGRATION / RETIREMENT STRATEGY (question P)

| Legacy | Disposition |
|---|---|
| `MessageAttachment` (dual-written, different field names, **seconds vs ms**) | retire onto canonical Media after backfill (F133) |
| `thumbUrl` + `thumbnailUrl` duplicate columns | collapse into `MediaDerivative` behind compatibility read |
| dead `presign.dto.ts` class vs inline unvalidated `type` | adopt the validated class, delete the inline type (F130) |
| 3× MIME→MediaType mappers | one authority in `mime-policy.ts` |
| 4× Media-row writers | one governed ingestion path (F129) |
| 5× parent-stamp writers | one `attachContent()` helper |
| 4× wire projections | one envelope projection |
| 2× signed-URL issuers | one delivery authority |
| conversation-local `_PendingAttachment`, cards, paste, players | replaced by shared primitives |
| `wireKind(document) === 'IMAGE'` | retire with the wire vocabulary (F122) |
| `'…'` empty-body sentinel | remove; body truth is not a UI flag (F124) |
| article markdown with baked signed URLs | rewrite to media references (F121) |

**F129 specifically:** Correspondence must consume the canonical lifecycle rather
than gaining three checks around a raw storage key — the directive is explicit
that patching the bypass in place is not acceptable. Correspondence domain
authorization and semantics are preserved; only ingestion converges.

---

## 13. IMPLEMENTATION SEQUENCING

Each stage is independently shippable and independently certifiable.

| Stage | Content | Gated on |
|---|---|---|
| **C1** | Content-truth authority + presign validation + size enforcement (F127/F128/F130) | — |
| **C2** | Reference graph + retention + cleanup rewrite + backfill (F131) | — |
| **C3** | Access context at ingestion; restricted branches for POST/REPLY (F126 generalization) | C1 |
| **C4** | Canonical ingestion convergence — Correspondence, Articles, uploads (F129) | C1, C2 |
| **D1** | `MediaDerivative` + worker + image pipeline + EXIF (F132, F136) | C1 |
| **D2** | Video posters, audio duration/waveform, document previews | D1 |
| **E1** | Shared client primitives: intake, upload (cancel/retry/progress), players, viewers, cards | C1 |
| **E2** | **Conversation as FIRST COMPLETE REFERENCE** (F011–F019, F123–F125, WG001/2/4/5/6/9) | D2, E1 |
| **F1** | Propagation: Articles (F121, F025–F027), Posts, Announcements, Institution Posts, Correspondence | E2 |

C1–C3 are prerequisites because they are security and data-integrity work; no
presentation stage should ship on top of an ungoverned ingestion path.

---

## 14. VALIDATION STRATEGY

| Class | Applies to |
|---|---|
| LOCALLY VERIFIED | content-truth verdicts, reference-graph retention, visibility authority, failure-state mapping, derivative selection |
| AUTHORIZED-BROWSER VERIFIED | presentation, playback, seek, document preview, upload progress/cancel/retry, degradation chain |
| **TWO-ACCOUNT / TWO-BROWSER REQUIRED** | F126 live journey, cross-party render parity, sender-vs-receiver truth, access denial |
| LIVE_CERTIFIED | only after the above, per surface |

Architectural confidence is never converted into certification. Every stage
declares its own class before work begins.

---

## 15. UNRESOLVED DECISIONS REQUIRING FOUNDER RULING

1. **Document preview strategy.** There is no good self-hostable DOCX/PPTX
   renderer. The realistic options are (a) headless LibreOffice — heavy, slow,
   operationally significant; (b) rich *identity* only, no visual preview, for
   Office formats while PDF gets full preview; (c) an external service, which
   conflicts with provider-independence doctrine and sends private documents
   off-platform. **Recommendation: (b) now, (a) later if demanded.**
2. **PDF rasterizer licensing — a real hazard.** MuPDF is AGPL; PDFium is
   BSD-ish. This choice has licensing consequences for Aura and must be a
   deliberate ruling, not an npm install.
3. **Processing runtime and cost.** A separate Railway worker service with
   `ffmpeg`/`sharp` — sizing, cold-start and cost implications.
4. **OG image mirroring (F135).** Mirroring stops leaking viewer IPs to third
   parties but stores third-party imagery. Privacy gain vs storage/copyright.
5. **EXIF policy (F132).** Strip everywhere, or strip from derivatives while
   preserving the original for the uploader?
6. **PUBLIC permanence.** Should PUBLIC media also move to signed URLs? Today a
   permanent public URL survives any later visibility change — relevant if
   content is ever un-published.
7. **`MessageAttachment` retirement timing** — now, or after Conversation lands?
8. **Media moderation (F137).** Currently zero scanning of uploaded media. Scope
   and timing is a governance decision, not an engineering one.

---

## 16. WHAT THIS CONTRACT DELIBERATELY DOES NOT DO

- It does not flip the global visibility default (breaks Posts today).
- It does not freeze processing libraries or providers.
- It does not adopt a block-based content model.
- It does not centralize domain authorization into the media layer.
- It does not touch realtime, Live, Meetings, or C4-owned attention findings.
- It does not implement anything: **this is a proposal awaiting founder review.**
