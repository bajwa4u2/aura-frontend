# Original content identity — the lifecycle, and where derivatives stop

**Date:** 2026-08-21
**Scope:** provenance persistence end to end · the server-side image-processing
boundary, measured.

---

## 1. The canonical lifecycle

Original content identity now survives every stage. Each row is a real
mechanism, not a hand-off assumed to work.

| Stage | What happens | Where |
| --- | --- | --- |
| **Acquisition** | picker / paste / drop / recording hands over bytes | six composers + `ProfileMediaPipeline` |
| **Byte detection** | type resolved from the SIGNATURE, then declared type, then filename | `sniffMimeFromBytes` → `ContentIntake._resolveMime` |
| **Normalization** | HEIC/HEIF decoded through the platform codec, re-encoded to JPEG | `ContentNormalizer.normalize` |
| **Client record** | what it was before is kept beside what it is now | `Attachment.originalMimeType` |
| **Upload** | sent only when it DIFFERS from the stored type | `uploadAuraMedia` → `POST /media/presign` |
| **Contract** | optional, validated, deliberately not allow-listed | `PresignDto.originalMimeType` |
| **Coercion** | a claimed transformation that did not happen is dropped | `MediaService.presign` |
| **Persistence** | born with the row, not patched in afterwards | `Media.originalMimeType` |
| **Projection** | travels with delivery and with presign | `getDeliveryUrl`, presign response |

### The semantics, and why the column is nullable

```
NULL      Aura changed nothing. The stored representation IS the original.
non-NULL  Aura transcoded this, and this is what it was beforehand.
```

The column is **self-describing**: its presence is itself the record that a
transformation happened. A mirror of `mimeType` would have needed a second
field to say the same thing, and would have gone stale the first time someone
forgot to write it.

### Three properties that are enforced, not just intended

1. **A transformation that did not happen cannot be recorded.** The service
   drops `originalMimeType` when it equals the stored type. A provenance field
   able to say something false about itself is worse than no field.
2. **It is not allow-listed, on purpose.** The whole point is that it names a
   format Aura refuses to STORE. Allow-listing it would make the field
   incapable of holding the one value it exists for.
3. **It is not a bypass.** The stored type is still judged. Declaring an
   original cannot smuggle an unsupported stored type past the allow-list.

### Evidence class

An **UPLOADER DECLARATION** in `media-provenance.types.ts`' own vocabulary —
attributable to a person, but never proof. The server did not see the original
bytes; only the client that re-encoded them did. It must never be surfaced as
verified.

### Migration

`20260911000000_media_original_mime_provenance` — one nullable column, purely
additive. **No existing row is read or rewritten**: every row already in the
table was stored exactly as it arrived, so NULL is not merely a safe default
for them, it is the TRUE value. Migrations here are explicit (`db:deploy`,
guarded by `db-guard.cjs`), so this does not apply itself.

**Proof:** `media-original-mime-provenance.spec.ts` — six tests covering
persistence, the NULL case, the refused false claim, the deliberate absence of
allow-listing, the non-bypass, and the projection.

---

## 2. Server-side derivatives — measured, and the boundary is real

Three measured needs are one capability, not three TODOs:

* HEIC on web / Android < 28, where no platform codec exists;
* large-image delivery at the raised 150 MiB ceiling;
* identity-imagery payload size (avatars are stored as PNG).

### What Aura already has

**A media worker contract, fully designed — and no worker.**

`media.controller.ts` carries `MEDIA_WORKER_TOKEN_HEADER`, `hasWorkerAccess`,
`markProcessing`, `markReady`, and an `allowUnsafeFields` gate. The derivative
fields — `thumbnailUrl`, `displayUrl`, `playbackUrl` — are **worker-only**:
a normal owner PATCHing them is refused with *"Processed media fields require
worker access"*.

So Aura already decided how derivatives get made: **a separate process
produces them and PATCHes them back under an internal token.** That boundary
exists precisely so a client cannot supply a thumbnail showing something other
than the object.

`hasWorkerAccess` returns false unless `MEDIA_INTERNAL_TOKEN` is set. **No
worker exists in this repo or as a deployed service.** The contract is
complete and nothing implements it — the same shape as the AI provenance
subsystem.

### What Aura does not have

* **No image-processing dependency at all** in `package.json` — no sharp, jimp,
  canvas or vips.
* **No Cloudflare Images, no Image Resizing, no Worker, no `wrangler` config,
  no `/cdn-cgi/image` usage.** R2 is used purely as S3-compatible storage
  through `@aws-sdk/client-s3`. The Cloudflare relationship is storage only.

### Why this is a boundary and not a library choice

A pure-JS MIT library (jimp) would cover downscaling and re-encoding for JPEG
and PNG — two of the three needs — with no vendor, no cost and no native build.
It would **not** cover HEIC; that still needs libheif, which is LGPL and carries
HEVC patent exposure.

But choosing a library is not the decision. Generating derivatives **inside the
API process** would:

* create a **competing answer** to a boundary Aura has already drawn — the
  worker contract exists exactly so this work happens elsewhere;
* put an unbounded decode surface in the request path, which is what
  `MAX_EXAMINABLE_BYTES` caps everywhere else;
* put CPU-heavy, memory-heavy work in the API process.

The client cannot fill the gap either, and that is deliberate: derivative
fields are worker-gated so a client cannot supply a thumbnail that
misrepresents the object. Weakening that to ship a derivative would trade a
real security property for a convenience.

### The smallest founder decision

**Authorize a media worker service** — a separate deployable that consumes the
contract already built (`markProcessing` → derive → PATCH derivative fields
with `MEDIA_INTERNAL_TOKEN` → `markReady`).

Consequences to weigh:

| | |
| --- | --- |
| **Operating cost** | one additional always-on or queue-driven service |
| **Covers immediately** | thumbnails, display copies, avatar re-encode — with a pure-JS MIT library, no vendor |
| **HEIC on web** | needs libheif in that worker: LGPL, HEVC patent exposure — but **isolated to the worker**, never in the API |
| **Security** | keeps decoding out of the request path; the worker gate already exists |
| **Alternative** | Cloudflare Images — no worker to run, but a paid vendor product and none is configured today |

Not implemented, and deliberately not started: this is a deployment and cost
decision, which is the exact category to stop at.

**Nothing was regressed to reach this conclusion.** Native HEIC normalization,
content detection, the raised capacities and the composer convergence are all
intact.
