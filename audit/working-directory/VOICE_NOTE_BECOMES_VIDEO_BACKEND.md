# Voice notes still become videos — the backend half was never fixed

**Date:** 2026-09-11
**Reported by:** founder — *"it also sent audio message and it become video when sent"*
**Status:** ROOT CAUSE ESTABLISHED. Not fixed, not deployed.

    DEFECT      A NATIVE VOICE NOTE IS STORED AND RENDERED AS VIDEO
    LOCATION    aura-backend/src/media/content-truth.ts  (identifyBySignature)
    AFFECTS     Android and iOS voice notes. Web voice notes are FINE.
    SHIPPED     Yes — this is in production and in Apple build 38.

## This is the same defect that was fixed in the client on 2026-09-04

`aura_final/lib/core/media/media_mime.dart` carries the fix and the story:

> *"This returned `video/mp4` for every brand it did not recognise, and that
> turned Aura's own voice notes into videos. Android records them with
> `MediaRecorder` as AAC in an MPEG-4 container, which is stamped `isom` or
> `mp42` — never `m4a `. The recorder declared `audio/mp4` honestly, the
> sniffer overruled it to `video/mp4` because bytes outrank a declaration, and
> the message then rendered as a video card. Founder-observed on a Pixel,
> 2026-09-04."*

The client was repaired — it now calls `_isoBaseMediaTrackMime`, which reads
`hdlr` handler types and answers `vide` / `soun` from the tracks themselves.

**The backend has an independent copy of the same rule, and it was not
repaired.** Two mirrors of one decision; one was fixed and the other kept the
original mistake, so the defect survived in the half nobody re-read.

## The exact line

`content-truth.ts`, LAYER 3, `identifyBySignature`:

```ts
// ISO base media (MP4/MOV/M4A/HEIC/AVIF): 'ftyp' box at offset 4, brand at 8.
if (asciiAt(head, 4, 4) === 'ftyp') {
  if (brand === 'qt  ') return 'video/quicktime'
  if (brand.startsWith('m4a')) return 'audio/mp4'
  return 'video/mp4'            // ← isom, mp42, and every other brand
}
```

`VoiceNoteCapture` declares `audio/mp4` truthfully — the bytes really are AAC
in an MPEG-4 container. The backend contradicts that honest declaration with a
**guess**, and the guess wins because detection is treated as outranking
declaration.

## The asymmetry is the whole bug

The identical problem in the **WebM** family was diagnosed and solved properly,
and the reasoning is written down at LAYER 4:

> *"EBML magic identifies a CONTAINER, never a media kind: a voice note
> recorded as Opus-in-WebM and a camera video share the first four bytes
> exactly... Returns null when the window contains no Tracks element — the
> honest answer is 'undetermined', never 'video'."*

and in the resolution step:

> *"a declaration that is merely UNCONTRADICTED must survive, which is why a
> WebM declaration is adopted here instead of being 'corrected' to video on no
> evidence."*

Every word of that applies to ISO-BMFF. `ftyp` identifies a container, not a
media kind; `isom` says the file is ISO base media and says nothing about its
tracks. But ISO-BMFF got **no refinement pass at all** — no track inspection,
and no rule letting an uncontradicted declaration stand.

So: WebM voice notes (web) are protected. MPEG-4 voice notes (Android, iOS)
are not. That is exactly the platform split the founder is seeing.

## A second constraint the fix has to respect

    CONTENT_TRUTH_HEAD_BYTES = 512

The backend inspects only the first 512 bytes. **Android's `MediaRecorder`
writes `moov` — which contains every `hdlr` box — at the END of the file.** So
copying the client's track-reading approach onto `headBytes` would find
nothing and change no outcome.

The codebase already has the shape for this: `tailBytes` exists and the ZIP
layer uses it (`classifyZipContainer(input.tailBytes)`), and `ebmlBytes` exists
as a deliberately wider window for EBML. An ISO-BMFF refinement needs the same
treatment — read the tail for `hdlr`, and where the tracks cannot be reached,
let an `audio/mp4` declaration stand rather than "correcting" it to video on no
evidence.

## Disposition

Not fixed here. It is a backend change, and Apple build 38 is in App Review —
deploying mid-review was already flagged as the founder's call, not mine.

Worth noting for that decision: this defect is **already in the shipped
build and in production**, so deploying the fix would improve what a reviewer
sees rather than change a behaviour they have been evaluating. The fix is small
and symmetric with the WebM code that already exists.
