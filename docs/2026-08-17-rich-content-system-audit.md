# Aura Rich Content & Interaction System — Capability Audit (Frontend)

**Date:** 2026-08-17 · **Chapter:** founder-frozen platform reconstruction
(task #173) · **Status:** audit phase, §11 of the founder charter.

## THE HEADLINE FINDING

**Aura already has a competent shared content foundation — and Conversation,
the surface chosen as the reference implementation, is the one surface that
bypasses essentially all of it.**

`lib/core/media/`, `lib/core/link_preview/`, `lib/core/rich_content/` and
`lib/core/ui/publication/` contain canonical, reusable authorities consumed
by Posts, Announcements, Threads, Institution composers and the feed.
`conversation_screen.dart` re-implements sixteen of those concerns locally,
usually more thinly.

> Conversation is the richest ACQUISITION surface (the only one with
> drag/drop AND clipboard-image paste) built on the THINNEST shared
> foundation.

This changes the shape of the chapter: it is **less "invent a platform
system"** and **more "generalize the authorities that already exist,
reconstruct Conversation onto them, then extend the stack where it is
genuinely missing (documents, audio, video richness, transfer truth)."**

## WHAT EXISTS — classification per charter §11

### KEEP (canonical, architecturally correct)
| Capability | Location |
|---|---|
| Upload primitive (presign → PUT → confirm → patch) | `core/attachments/aura_media_upload.dart` — genuinely shared, 7 call sites |
| Signed/delivery URL resolution (cached, in-flight-deduped, expiry-aware) | `core/media/media_url_resolver.dart` |
| Image rendering (cache key, placeholder, error tile, semantics) | `core/media/aura_attachment_image.dart` (+ resolvable variant) |
| Media layout authority (aspect heuristics, modes, save overlay) | `core/media/aura_media_frame.dart` |
| Fullscreen viewer (zoom, actual-size, keyboard, open original) | `core/media/aura_media_viewer.dart` |
| Media save (web/io conditional, CORS-degrades to external open) | `core/media/media_save_*.dart` |
| MIME authority mirroring the backend allowlist | `core/media/media_mime.dart` |
| Canonical staged-attachment model | `core/media/attachment.dart` |
| Link preview + internal reference cards | `core/link_preview/` |
| Rich paste (HTML flavor → markdown) | `core/rich_content/rich_paste_field.dart` |
| Publication markdown renderer | `core/ui/publication/aura_publication_markdown.dart` |

### GENERALIZE (correct but incomplete for the target bar)
- **Upload**: no retry, no cancellation, no resumability, whole file in
  memory, no timeouts, progress covers only the PUT and is ignored by most
  callers, no client-side thumbnail/poster generation.
- **Media kind model**: `AttachmentKind{image,video,audio,document}` is a
  closed switch — the charter requires an extensible handler registry.
- **Viewer/frame**: no inline video playback in feed surfaces (video renders
  as a still image only).

### RECONSTRUCT (structurally wrong / below the bar)
- **Conversation content layer**, wholesale — see duplication map.
- **Playback**: three unshared implementations, none with a seek bar,
  duration, elapsed time, waveform, or speed control. Voice notes are an
  opaque play/pause pill. `video_player` is the only package; **no audio
  package exists at all**.
- **Documents**: rendered as a static "Attachment" chip with no filename,
  no size, no open/download action.

### REPLACE
- `_PendingAttachment` (conversation-local) → canonical `Attachment`.
- Conversation's local link/internal-ref cards → canonical cards.
- Conversation's bespoke paste path → `RichPasteField` + image intake.

### RETIRE (with explicit path)
- `wireKind(AttachmentKind.document) == 'IMAGE'` legacy quirk (see F122).

## DUPLICATION MAP (16 concerns implemented more than once)

Staged-attachment model · MIME inference/kind derivation · delivery-URL
resolution · link-preview card · internal-reference card · URL
detection/debounce · body rich spans · rich paste · fullscreen viewer ·
video playback · audio playback · voice recording · attachment surface by
kind · pre-send preview tile · attach bottom sheet · media kind enum.

In every row the conversation surface is on the non-canonical side.

## PLAYBACK REALITY (charter §D/§E)

| Surface | Video | Audio |
|---|---|---|
| Media viewer | play/pause/restart, **no seek** | — |
| Conversation | inline, play/pause only | opaque "Voice note" pill |
| Thread | **no playback** — launches the browser | **no playback** — launches the browser |
| Feed/Posts | still image only | — |

No timeline, scrubbing, duration, elapsed time, waveform or speed control
anywhere in the product.

## NEW CONCRETE DEFECTS FOUND (registered F121–F125)

- **F121** — Article image insertion writes the **resolved, expiring signed
  URL** into durable markdown body text (`article_editor_screen.dart:129`).
  A published article's images will 404 once the signature expires. Distinct
  from F025 (which is about raw markdown as UX); this is durability/
  correctness.
- **F122** — Wire-kind inconsistency: canonical
  `wireKind(AttachmentKind.document)` returns `'IMAGE'`, while
  `conversation_screen` sends `'DOCUMENT'` for the same file class. Two
  messaging surfaces report different kinds for identical content.
- **F123** — Falsified content provenance: conversation labels every
  attachment `source: 'GALLERY'`, including clipboard pastes and desktop
  drops, despite `AttachmentSource` supporting `paste`/`upload`.
- **F124** — Empty-text sends transmit a literal `'…'` sentinel as the
  message body, and rendering special-cases it away. Message body truth is
  being used as a UI flag.
- **F125** — Conversation images have **no viewer and no save**: not
  tappable, no fullscreen, no save affordance — while every other surface
  routes through `AuraMediaViewer`/`MediaSaveService`.

## BACKEND AUDIT — what exists

**KEEP (genuinely single-source):** `src/media/mime-policy.ts` (28 permitted
MIME types across IMAGE/VIDEO/AUDIO/DOCUMENT/ARCHIVE; SVG blocked
unconditionally; per-kind size + duration limits), `src/media/r2_s3.client.ts`
(presign/put/head/delete/signed-read + multipart), `MediaService` lifecycle
(`TEMP→UPLOADING→UPLOADED→PROCESSING→READY→FAILED/ORPHANED/DELETED/ARCHIVED`)
with real R2 HEAD verification at confirm, `getDeliveryUrl` visibility gating,
`src/link-intelligence/` (genuinely strong SSRF defence — literal-IP check,
per-hop re-resolution, byte/time caps, allow-listed content types),
`src/internal-references/` (11 kinds, delegates to each family's real
retrieval authority rather than re-implementing authorization).

**MISSING ENTIRELY:** any image/video/document processing. No `sharp`,
`ffmpeg`, `pdf-lib`, `file-type` — nothing. `PROCESSING` status,
`markProcessing`/`markReady`, the `x-media-worker-token` gate and the
worker-only `thumbnailUrl`/`displayUrl`/`playbackUrl` write paths are
**scaffolding for a worker that does not exist**. Nothing ever moves a Media
row to `PROCESSING`.

**Backend duplication (10 concerns):** MIME→MediaType mapping ×3 (none in
mime-policy where it belongs) · Media-row creation ×4 (only presign validates)
· parent-attachment stamping ×5 · Media→wire projection ×4 (each with a
different URL-preference chain) · signed-URL issuance ×2 (different candidate
orders) · attachment metadata ×2 tables with different units · presign DTO ×2
(the validated one is dead code) · TTL clamp ×2 · cross-repo MIME policy ×2 ·
visibility derivation ×2.

## NEW CONCRETE DEFECTS — BACKEND (F126–F137)

**Security / privacy — highest severity:**
- **F126 (P0, privacy)** — **Conversation media visibility is never set**, so
  private DM attachments stay `PUBLIC`. `GET /media/:id/url` then returns a
  permanent public URL **to any caller**, and the `CONVERSATION` branch of
  `canAccessRestricted` is unreachable in production. Posts/announcements/
  institution posts/messages all set visibility; **the most private surface is
  the least protected.**
- **F127 (P0, security)** — **No magic-byte/signature validation anywhere.**
  The client-declared `contentType` at presign is the only check; R2 stores
  whatever bytes are PUT. `confirmUpload` already calls `headObject()` which
  *returns* the stored content type — and discards it.
- **F129 (P0, security)** — The correspondence-messages path **bypasses
  `/media/presign` entirely**: the client supplies a raw `storageKey`, so there
  is no MIME check, no size check, and no proof the caller owns that key.
  Creates `Media` at `status=READY` with no HEAD verification.
- **F131 (P0, data loss)** — `Article.coverMediaId` is a bare string with no
  Prisma relation, no `READY` check, no MIME check and **no `attachedTo`
  stamp** — so `MediaCleanupService` treats a published article's cover as an
  orphan and deletes it.
- **F128 (P1, security)** — Size limits are advisory: the presigned PUT carries
  no `content-length-range`, and `confirmUpload` reconciles the real size but
  never rejects an over-limit object.
- **F130 (P1, security)** — The presign body is a bare TS `type`, so the global
  `ValidationPipe` skips it entirely; no runtime validation on any presign
  field. A validated `PresignDto` class exists but is dead code.
- **F132 (P1, privacy)** — No EXIF stripping: GPS coordinates in uploaded
  photos are published to public R2 verbatim.

**Correctness / capability:**
- **F133 (P1)** — Duration unit mismatch: `Media.duration` is milliseconds
  (presign compares it to `*_DURATION_MS`), while `MessageAttachment.durationSec`
  is seconds — and `messages.service` copies one straight into the other.
- **F136 (P1)** — No thumbnail generation. For images `thumbUrl` is set to the
  **full-resolution original** (a thumbnail in name only); for video/audio/
  document it is null — which is why video tiles have nothing to show.
- **F134 (P2)** — `Media.aiFlags` is client-writable through `PATCH /media/:id`
  (not worker-gated) and read by nothing.
- **F135 (P2, privacy)** — Link-preview images are hotlinked third-party URLs,
  never mirrored into R2, leaking viewer IP addresses to external hosts at
  render time.
- **F137 (P2, governance)** — No moderation or scanning of uploaded media of
  any kind: the moderation service is text-only; there is no AV scan, no NSFW
  classifier, no perceptual hashing, no `Media.moderationStatus`.

## CORS (F058 interaction)

There is **no CORS handling in the image path at all** — a CORS rejection is
indistinguishable from a 404 or an expired signature; both render the same
broken tile. The only CORS-aware code is `MediaSaveService`, which degrades
a blocked byte-fetch to "opened externally". This means F058 (R2 CORS)
currently manifests as an *untruthful* error state, not just a missing
image.
