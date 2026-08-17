# §12 FINAL RICH CONTENT & INTERACTION CONTRACT — FREEZE CANDIDATE

**Status:** FREEZE CANDIDATE — awaiting founder freeze + Phase C authorization.
**Date:** 2026-08-17
**Supersedes:** the §12 PROPOSED contract (same date), which remains the record of
the reasoning this document ratifies.
**Evidence base:** `2026-08-17-rich-content-system-audit.md`, the F126 correction,
and the founder rulings of 2026-08-17.

---

## 1. INCORPORATED RULINGS

| # | Ruling | Where incorporated |
|---|---|---|
| 1 | Self-hosted rich document preview is the TARGET; identity-only is a transitional capability state, not a destination | §8, §9 |
| 2 | Permissive PDF licensing; no AGPL in core; freeze interface not library | §8, §16 |
| 3 | Aura-controlled async worker boundary frozen; bounded sync inspection only | §8 |
| 4 | External preview imagery fetched through the SSRF-safe boundary and served from Aura-controlled cache | §12 |
| 5 | Delivered derivatives strip privacy-sensitive metadata by default | §8.4 |
| 6 | PUBLIC ≠ permanent unrevocable storage access | §6 — **and see the contradiction in §2** |
| 7 | Legacy retirement condition frozen | §14 |
| 8 | Moderation/inspection lifecycle hook established now, vocabulary converged | §5, §7 |
| 9 | ContentReference integrity pressure-tested | §7 |
| 10 | Governed semantic vocabulary, not a loose convention | §4 |
| 11 | Accessibility is first-class | §11 |
| 12 | Broad format support by default; restriction requires a reason | §9 |
| 13 | Capability-based format families, not a flat allowlist | §9 |
| 14 | Acceptance ≠ preview ≠ processing; capability matrix | §9.3 |
| 15 | Active/executable content held separate; SVG stays blocked | §9.4 |
| 16 | Preserve recognizable content identity; honest fallback | §10 |
| 17 | New formats enter by governed registration, not code changes everywhere | §9.5 |

---

## 2. ARCHITECTURAL CONTRADICTION DISCOVERED

Ruling 6 forced a question the audit had recorded but not yet confronted, and the
answer is serious.

### F138 — storage-level public readability may undercut visibility enforcement

**There is one R2 bucket, and every object — PUBLIC, RESTRICTED and PRIVATE
alike — is written to the same public prefix via `buildPublicUrl`.** "Private" is
enforced by *withholding the URL* from DTOs (`media-redaction.ts`, whose own
header concedes this) and by issuing signed URLs. It is **not** enforced by
object ACL or by a separate private bucket.

The consequence, stated plainly:

> If the bucket permits public read, then the permanent unsigned URL of a
> RESTRICTED object still resolves for anyone who learns or guesses its key.
> Signed URLs then add ceremony, not protection.

This does not mean F126 was wrongly fixed — the fix closed the path that
*handed out* those URLs to any caller, which was the live exposure. But it means
**F126's guarantee is currently bounded by an operational bucket setting rather
than by architecture**, and the object key is derived from `userId` plus a
timestamp and uuid, so it is unguessable but not secret.

Ruling 6 cannot be satisfied without resolving this: Aura cannot claim revocable,
governed delivery for PUBLIC content while RESTRICTED content is reachable at a
permanent public URL.

**This requires an operational fact I cannot read from code: whether the R2
bucket currently allows public read.** It is registered as **F138**, and its
resolution is a **freeze-blocking prerequisite for the delivery model in §6** —
the only such item in this document.

**Resolution direction (contingent on that fact):** all object access moves
behind Aura-controlled delivery; the bucket becomes non-public; PUBLIC media is
served through a cacheable Aura delivery route (CDN beneath Aura's authority,
per ruling 6) rather than a raw storage URL. Staged so Posts never break — see
§6.

*(No other contradiction was found. Rulings 12–17 initially appear to conflict
with the content-truth requirement — broad acceptance versus provable type — but
§9.3 resolves this coherently: a format whose type cannot be established is
accepted as opaque, and opacity constrains its capabilities rather than its
acceptance.)*

---

## 3. FINAL CANONICAL LIFECYCLE

```
ACQUIRE → NORMALIZE → INSPECT → VALIDATE → POLICY/INSPECTION → SECURE → STORE
        → PROCESS → ENRICH → PERSIST → HYDRATE → PRESENT → INTERACT
        → GOVERN → RETAIN/DELETE
```

`POLICY/INSPECTION` is new, per ruling 8: the moderation/quarantine hook is part
of the lifecycle from the beginning, sized for Aura's actual load today but
requiring no reconstruction to grow.

---

## 4. GOVERNED SEMANTIC VOCABULARY (ruling 10)

The envelope remains a **projection contract, not an owner table**. But its
vocabulary is frozen and shared, so "shared shape, divergent meaning" cannot
recreate today's fragmentation one level up.

```
ContentPartRole   ATTACHMENT · INLINE · COVER · VOICE_MESSAGE · VIDEO_MESSAGE · DOCUMENT
ReferenceCategory INTERNAL_OBJECT · EXTERNAL_URL · MEDIA
ResolvedTypeClass IMAGE · VIDEO · AUDIO · DOCUMENT · ARCHIVE · TEXT · OPAQUE
TruthDisposition  CONFIRMED · CORRECTED · REJECTED · UNVERIFIABLE
ProcessingState   PENDING · RUNNING · COMPLETE · FAILED · SKIPPED · UNSUPPORTED
DeliveryState     READY · NOT_READY · DENIED · GONE
FailureKind       UPLOAD · VALIDATION · POLICY · PROCESSING · HYDRATION · ACCESS · REMOVED
Capability        (see §9.3)
```

**Extensibility rule (frozen):** new values are added by amending this vocabulary
and its registry, never by a surface inventing a local variant. Every enum has a
single canonical definition mirrored across backend and client by a compatibility
test — the pattern already proven by `media-frontend-mime-compatibility.spec.ts`.

**Envelope:** `body` (rich text) + ordered `parts[]` (role-tagged) +
`references[]`. Voice and video messages remain the same Media under a different
role — not a separate storage universe.

---

## 5. FINAL CONTENT-TRUTH MODEL

Six non-collapsed layers: **declared → transport → signature → container →
structural → resolved**, producing a verdict (`TruthDisposition`) plus a
`ResolvedTypeClass`.

**Invariant: A FILE IS NOT TRUSTED MERELY BECAUSE THE CLIENT NAMED ITS TYPE.**

Container inspection is its own layer because DOCX/PPTX/XLSX/ODF and plain ZIP
share the signature `50 4B 03 04`; the archive directory distinguishes them
(`word/`, `ppt/`, `xl/`). Formats with no signature (`text/plain`, `text/csv`)
resolve `UNVERIFIABLE` and are governed by policy — never served with an
HTML-capable content type.

**Policy/inspection stage (ruling 8):** after validation, before delivery
eligibility. States converge with `ProcessingState` and the existing
`MediaStatus` rather than adding a parallel enum; `QUARANTINED` is the one new
terminal state required, and `REJECTED` maps to the existing `FAILED` with a
reason. No redundant vocabulary.

**Closes:** F127, F128, F130, F122.
**Preserves:** allowlist governance, size/duration limits, filename
sanitization, presign/download governance, SSRF protection, storage authorization.

---

## 6. FINAL DELIVERY MODEL (ruling 6)

**Frozen principle: PUBLIC CONTENT IS NOT PERMANENT UNREVOCABLE STORAGE ACCESS.**

Aura retains the ability to withdraw, moderate, delete, change visibility,
replace, invalidate and govern — for **all** visibility classes.

Canonical delivery is an Aura-authored route for every class. Cache/CDN
efficiency sits *beneath* that authority, never in place of it.

**Staged migration — Posts must not break** (they rely on the permanent-URL
shortcut today):

1. Introduce the canonical delivery route; both paths valid.
2. Move clients to canonical delivery (the client resolver is already
   expiry-aware and centralized, so this is a small change).
3. Add cache/CDN semantics beneath Aura's authority for PUBLIC content.
4. **Contingent on F138:** remove bucket public read; retire raw storage URLs.

Step 4 is where ruling 6 actually becomes true. Steps 1–3 are safe regardless.

---

## 7. FINAL REFERENCE / RETENTION MODEL (ruling 9)

Answering the pressure test directly, because a weak polymorphic graph would be
a generalized F131.

**The decisive design choice: the reference graph is an INDEX, not an
assertion.** Surface composition tables (`PostMedia`, `ConversationMessageMedia`,
`Article.coverMediaId`, …) remain the **source of truth**. `ContentReference` is
a derived, verifiable index over them. When the two disagree, **the index is
wrong and is rebuilt** — which is precisely what stops them becoming competing
truths (answer K).

| | Answer |
|---|---|
| **A. Who may create** | Only the shared `attachContent()` helper. No surface writes `ContentReference` directly; the helper is the sole writer, which also collapses the five existing stamping writers. |
| **B. Owner existence proof** | A governed per-type **verifier registry**: each `referenceType` registers a callback proving the owning row exists. Postgres cannot enforce polymorphic FKs declaratively — so existence is proven at write time and **re-proven** by the reconciler. |
| **C/D. referenceType governance** | A closed enum in the frozen vocabulary (§4). Free-form types are rejected. Registering a new type requires a verifier — no verifier, no type. |
| **E. Who may release** | The owning surface's delete/detach path, through the same helper. |
| **F. Transactionality** | Yes. Reference writes/releases occur in the **same transaction** as the owning row's write. A composition that commits without its reference is impossible. |
| **G. Partial failure** | The transaction rolls back. The reconciler is the safety net for anything that escapes (e.g. legacy paths mid-migration). |
| **H. Orphan detection** | A periodic **reconciler** re-derives the expected reference set from the source tables and reports divergence in both directions — extra references and missing ones — as an operational signal, not a silent repair. |
| **I. Fake reference keeping media alive forever** | Impossible to assert: an unverifiable reference fails its verifier and is reported by the reconciler. Because the index is derived, a reference with no backing row has no authority — it cannot outvote the source table. |
| **J. Losing the last reference prematurely** | Release is **soft** (`releasedAt`), followed by a retention grace period. Deletion requires: zero live references **AND** grace elapsed **AND** a fresh reconciler pass confirming no source table still points at the media. Three independent conditions. |
| **K. Coexistence with join tables** | Join tables own *composition* (position, caption, role). The graph owns *retention*. One is derived from the other, so they cannot diverge into competing truths. |

**Backfill:** derive the initial index from every join table, `attachedToId`, and
`Article.coverMediaId`, then run the reconciler to prove equivalence **before**
the reaper next runs. `Article.coverMediaId` gains a real Prisma relation, and
`ArticleRevision` begins snapshotting the cover (F131, plus the versioning gap).

---

## 8. FINAL DERIVATIVE / PROCESSING MODEL

`MediaDerivative(mediaId, kind, url, mimeType, width?, height?, bytes?,
pageIndex?, state, error?)`, unique on `(mediaId, kind, pageIndex)`.
Kinds: `THUMBNAIL · PREVIEW · POSTER · OPTIMIZED · WAVEFORM · DOCUMENT_PAGE ·
TRANSCODE · CAPTIONS · EXTERNAL_CACHE`.

- `Media.url` is always the preserved original.
- Selection is a query — smallest derivative ≥ requested size, else original.
- **A failed derivative never fails the media.**
- Retires the six ad-hoc URL columns (two literal duplicates) behind a
  compatibility read.

### 8.1 Worker boundary (ruling 3, frozen)

**Synchronous at `confirmUpload`** — bounded, no decoding of untrusted media:
signature + container inspection, header-level dimensions, PDF page count,
declared-vs-actual reconciliation, **size enforcement (rejection, not
reconciliation)**, policy/inspection hook.

**Asynchronous behind the worker**: image derivatives, EXIF stripping, video
posters/transcodes, waveforms, document previews, captions.

**Mechanism:** `MediaProcessingJob` queue polled by an Aura-controlled worker
authenticating with the existing `MEDIA_INTERNAL_TOKEN` — the gate already
exists. Scaling later means more execution capacity, not a new architecture.

### 8.2 Provider independence (frozen, rulings 1–3)

**§12 freezes capability interfaces, never libraries.**

```
ImageProcessor · VideoProcessor · AudioProcessor · DocumentRasterizer
```

Every capability requires a **self-hosted tier-0 default**; external services may
only ever be tier-1 enrichment. **Private documents must not leave Aura's
governed infrastructure to obtain a preview.** LibreOffice is a candidate
*implementation* behind `DocumentRasterizer`, never a constitutional dependency.

### 8.3 Licensing as a selection constraint (ruling 2, frozen)

Permissive licensing is required for core processing. **AGPL implementations
(MuPDF) are excluded from core.** PDFium-class permissive licensing is the
preferred starting direction. Licensing is recorded as a standing selection
constraint, re-evaluated per implementation choice — not a one-time decision.

### 8.4 Privacy metadata (ruling 5, frozen)

**Delivered derivatives strip privacy-sensitive metadata by default**, GPS
especially. Useful technical metadata is extracted *first* for processing and
presentation. Original retention stays governed by original-content policy and
access authority. Closes **F132**.

---

## 9. FINAL FORMAT-CAPABILITY MODEL (rulings 12–17)

**Frozen doctrine: BROAD SUPPORT BY DEFAULT. RESTRICTION REQUIRES A REASON.**
"Not previously in our MIME list" is explicitly **not** a reason.

Valid reasons: demonstrated security risk · no trustworthy content truth ·
dangerous active content · unsafe storage/processing · serious platform
incompatibility · licensing · no honest usable fallback · disproportionate
operational risk.

### 9.1 Families, not a flat allowlist

Governance moves from 28 enumerated MIME strings to **families** (IMAGE, VIDEO,
AUDIO, DOCUMENT, TEXT, ARCHIVE, OPAQUE), each with member formats and a
capability profile.

### 9.2 Target landscape (to be established per format, not assumed)

- **Image:** JPEG, PNG, WebP, GIF, AVIF, HEIC/HEIF *(HEIC is the instructive
  case — browsers largely cannot render it, so it is `CAN_ACCEPT` +
  `CAN_TRANSCODE` but `CAN_RENDER_INLINE` only via an optimized derivative)*
- **Video:** MP4, WebM, MOV/QuickTime, plus containers made practical by transcode
- **Audio:** MP3, M4A/AAC, WAV, OGG/Opus, FLAC, WebM audio
- **Document:** PDF, DOC, DOCX, PPT, PPTX, XLS, XLSX, RTF, TXT, CSV
- **Archive:** ZIP and similar, only where the security model and product purpose
  justify acceptance

### 9.3 The capability matrix (ruling 14, frozen)

One binary "supported" flag is replaced by per-format capabilities:

```
CAN_ACCEPT · CAN_IDENTIFY · CAN_INSPECT · CAN_SANITIZE · CAN_EXTRACT_METADATA
CAN_GENERATE_THUMBNAIL · CAN_GENERATE_PREVIEW · CAN_TRANSCODE · CAN_STREAM
CAN_RENDER_INLINE · CAN_DOWNLOAD · CAN_MODERATE
```

This is what lets Aura support real-world communication **without lying**: a safe
format may be accepted, stored and downloadable long before Aura can preview it,
and the UI then shows honest rich identity rather than "unsupported".

It also resolves the apparent broad-support/content-truth tension: a format that
cannot be identified is `CAN_ACCEPT` + `CAN_DOWNLOAD` and **nothing else** —
opacity constrains capability, not acceptance.

### 9.4 Active/executable content (ruling 15, frozen)

Four levels held permanently distinct:

```
SAFE TO STORE  ≠  SAFE TO INSPECT  ≠  SAFE TO PREVIEW  ≠  SAFE TO EXECUTE
```

Aura never inline-renders or executes uploaded HTML, scripts, executables or
macros because storage was permitted. **Macro-enabled Office containers require
explicit analysis before acceptance.** **SVG remains blocked** — unchanged, and
changeable only by future evidence of a genuinely safe sanitization architecture
plus founder approval.

### 9.5 Extensibility (ruling 17, frozen)

A new format enters through **capability registration** in the content-truth /
processing registry — never by editing Conversation, Posts, Articles,
Announcements, Meetings, MediaService and every renderer. Surfaces consume
capabilities and apply their own domain policy. This is the provision that keeps
§12 alive as the format landscape moves.

---

## 10. FINAL PRESENTATION / HYDRATION MODEL (ruling 16)

Presentation resolves from **(resolved type × capabilities × available
derivatives × access state × role)** — never from the acquisition door.

**Degradation chain, every step a truthful state:**

```
native rich → reduced rich → rich identity → generic → explicit error
```

Preserved wherever feasible: real filename, real type, meaningful iconography,
dimensions, native aspect, page/slide counts, thumbnails/posters, document
previews, durations.

Broad format support must **not** become hundreds of identical pills. Identity-
only is a legitimate *capability state*, never the destination (ruling 1).

Documents become first-class; audio gets a real player with **seek**, duration,
elapsed/remaining and waveform where a derivative exists; video gets posters and
inline playback. Failure states read distinctly — CORS, 404 and expiry are three
different truths (closes F058's real damage).

---

## 11. ACCESSIBILITY MODEL (ruling 11, first-class)

**The canonical model already has legitimate places for this** — `Media.altText`,
`Media.caption` and `Media.transcript` exist today and are essentially unused.
The contract makes them load-bearing rather than adding a parallel structure.

| Concern | Home |
|---|---|
| alt descriptions | `Media.altText` |
| captions/subtitles | `MediaDerivative(kind: CAPTIONS)` (WebVTT) |
| transcripts | `Media.transcript` |
| accessible labels | presentation primitives, from resolved type + filename |
| semantic playback controls, keyboard, focus | shared playback/interaction primitives |
| accessible failure/processing states | the failure taxonomy, surfaced as text |

**No automatic transcription is mandated.** The requirement is that these
representations have canonical homes and require no reconstruction later.

---

## 12. EXTERNAL PREVIEW MEDIA (ruling 4)

External OG imagery is fetched **through the existing SSRF-safe boundary,
unchanged and un-weakened**, validated as a real image against the same content-
truth authority, and served from an Aura-controlled `EXTERNAL_CACHE` derivative
instead of being hotlinked.

- **Scope:** preview imagery for successfully resolved link previews only.
- **Refresh/expiry:** bounded cache tied to the existing 7-day staleness window;
  re-fetch on refresh.
- **Rights:** cached as a transient rendering aid at preview scale, not an asset
  claim; purged when the preview is purged. Aura does not claim arbitrary web
  assets.
- **Failure fallback:** preview renders without imagery — never a broken tile.
- **Retention:** released with its `LinkPreview`.

Closes **F135** (viewer IP leakage to third parties) and the disappearing/
hotlink-rejecting asset problem.

---

## 13. FINAL AUTHORITY BOUNDARIES

| Shared (Rich Content system) | Owned by surface |
|---|---|
| acquisition/intake normalization | who may compose |
| content truth + format capabilities | who may read |
| storage + presign governance | who may edit/delete |
| access-context → visibility authority | publication state |
| derivatives + processing | institutional authority |
| reference index + retention mechanics | discourse/integrity rules |
| canonical delivery/hydration | moderation decisions |
| presentation, playback, interaction primitives | retention policy inputs |
| accessibility carriers | continuity semantics |

**Generalize capability. Never centralize domain authority into media.**

**PROTECTED — untouched by this contract:** 1:1 calls, group audio/video,
screenshare, Live escalation, session lifecycle/convergence, Conversation party
truth, Meetings, and C4-owned attention findings.
**One real intersection:** meeting recordings already use the multipart upload
path this contract generalizes. That boundary is identified here and requires
explicit regression before it is touched — it is not assumed safe.

---

## 14. MIGRATION / RETIREMENT MODEL (ruling 7, frozen)

**Frozen retirement condition — indefinite compatibility is rejected:**

```
NEW CONTRACT IMPLEMENTED → HISTORY MIGRATED / EQUIVALENCE PROVEN
→ LIVE BEHAVIOR CERTIFIED → COMPATIBILITY CONSUMERS REMOVED
→ LEGACY REPRESENTATION RETIRED
```

Applies to: `MessageAttachment` (incl. the seconds-vs-ms mismatch, F133) ·
`thumbUrl`/`thumbnailUrl` duplication · the dead `presign.dto.ts` versus the
inline unvalidated type (F130) · 3× MIME mappers · 4× Media writers (F129) ·
5× stamp writers · 4× wire projections · 2× signed-URL issuers ·
conversation-local duplicates · `wireKind(document)==='IMAGE'` (F122) ·
the `'…'` sentinel (F124) · baked signed URLs in article markdown (F121) ·
raw storage URLs (F138, contingent).

**F129 specifically:** Correspondence converges onto the canonical lifecycle. It
is not patched with three checks around a raw key — its domain authorization and
semantics are preserved; only ingestion converges.

---

## 15. SECURITY GATES

No presentation stage ships on an ungoverned ingestion path.

1. Content truth resolved before delivery eligibility.
2. Size enforced by rejection at confirm, not reconciliation.
3. Presign body validated (no unvalidated inline type).
4. Access context declared at ingestion; fail-closed; PUBLIC asserted, never drifted into.
5. Policy/inspection hook present before delivery eligibility.
6. Active content never inline-rendered or executed; SVG blocked.
7. SSRF protections unchanged; external fetch only through the safe boundary.
8. Privacy metadata stripped from delivered derivatives.
9. **F138 resolved before raw storage URLs are retired.**

---

## 16. IMPLEMENTATION STAGES

| Stage | Content | Gate |
|---|---|---|
| **C1** | Content-truth authority, capability registry, presign validation, size rejection (F127/F128/F130/F122) | — |
| **C2** | Reference index + verifier registry + reconciler + retention rewrite + backfill (F131) | — |
| **C3** | Access context at ingestion; restricted branches for POST/REPLY (F126 generalized) | C1 |
| **C4** | Canonical ingestion convergence — Correspondence, Articles, uploads (F129) | C1, C2 |
| **C5** | Canonical delivery route; **F138 resolution**; PUBLIC delivery migration steps 1–3 | C1 |
| **D1** | `MediaDerivative` + worker + image pipeline + EXIF stripping (F132, F136) | C1 |
| **D2** | Video posters, audio duration/waveform, PDF preview, document identity | D1 |
| **D3** | Broad format families + transcode-dependent formats (HEIC etc.) + external preview cache (F135) | D1 |
| **E1** | Shared client primitives: intake, upload (progress/cancel/retry), players with seek, viewers, cards, accessibility | C1 |
| **E2** | **Conversation as FIRST COMPLETE REFERENCE** (F011–F019, F123–F125, WG001/2/4/5/6/9) | D2, E1 |
| **F1** | Propagation: Articles (F121, F025–F027), Posts, Announcements, Institution Posts, Correspondence | E2 |

---

## 17. VALIDATION GATES

| Class | Applies to |
|---|---|
| LOCALLY VERIFIED | truth verdicts, capability matrix, reference integrity + reconciler, visibility authority, failure mapping, derivative selection |
| AUTHORIZED-BROWSER VERIFIED | presentation, playback/seek, document preview, upload progress/cancel/retry, degradation chain, keyboard/focus |
| **TWO-ACCOUNT / TWO-BROWSER REQUIRED** | F126 live journey, cross-party render parity, access denial, sender-vs-receiver truth |
| LIVE_CERTIFIED | only after the above, per surface |

Architectural confidence is never converted into certification. Every stage
declares its class before work begins.

---

## 18. REMAINING FOUNDER DECISION REQUIRED BEFORE FREEZE

**Exactly one, and it is a fact rather than a preference:**

**F138 — does the production R2 bucket currently allow public read?**

- **If NO:** RESTRICTED media was never storage-reachable, F126's fix is
  complete as delivered, and §6 proceeds as a straightforward improvement.
- **If YES:** RESTRICTED media is reachable at a permanent URL by anyone who
  learns the key, F126 is only partially mitigated, and **C5 must be promoted
  ahead of D1** as a security stage rather than a delivery improvement.

Every other ruling integrates without contradiction. All eight of the previously
open decisions are now resolved by founder ruling and recorded above.

**With F138 answered, §12 is ready for freeze and Phase C authorization.**
