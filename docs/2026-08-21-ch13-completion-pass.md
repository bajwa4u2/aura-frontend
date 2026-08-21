# CH-13 completion pass — convergence, capacity, and what is genuinely blocked

**Date:** 2026-08-21
**Scope:** CompositionState convergence across all six composers · the 32 MiB
examination investigation · identity imagery · HEIC/HEIF disposition.

---

## 1. CompositionState convergence — complete

| Surface | Semantic state retired | Now answered by |
| --- | --- | --- |
| `compose_screen` | `_canPublish`'s `!_hasText` / `_textTooLong` / `_hasUploadingAttachments` | `CompositionState.canSubmit` + `blockedReason` |
| `announcement_editor_screen` | `_canSubmit` — which checked **no attachments at all** | `CompositionState.canSubmit` + `blockedReason` |
| `institution_announcement_composer` | its own uploading/failed attachment scan | `hasPendingAttachments` + `phaseOf` |
| `article_editor_screen` | unconditional 2 s autosave | `AutosavePolicy.shouldSave` + `isDirty` |

**Destination requirements were deliberately left with their surfaces** — a post
needs a topic, an announcement needs a title and summary, an institution post
needs a visibility scope. Those are not composition facts and the authority has
no business owning them. What converged is dirtiness, readiness, attachment
contribution and the blocked reason.

### Real defects this fixed

* **`announcement_editor_screen` never checked attachments.** An announcement
  could be submitted while an image was still climbing; the `mediaId` filter at
  submit then dropped it silently and the announcement published without it.
* **`compose_screen` read `a.uploading` as "in flight".** A FAILED attachment is
  not uploading, so publish proceeded and dropped it — the same silent-drop
  defect found in the conversation composer.
* **`compose_screen` refused attachment-only posts.** A photograph with no
  caption is a real post; requiring text was a per-composer accident.
* **`article_editor_screen` autosaved unconditionally** — it wrote an unchanged
  draft on every keystroke batch, and could write underneath a publish in
  flight. It also had no saved baseline, so a freshly opened draft read as
  dirty.
* **A disabled control now says why.** Publish/submit carry the authority's
  `blockedReason`, so a greyed-out button is no longer a dead end.

---

## 2. The 32 MiB examination ceiling — investigated, and it does not bind what
we thought

The question was whether 32 MiB is architectural or merely the current
examiner. **It is both, depending on the class**, and that distinction was
measurable rather than a matter of judgement.

`examination-policy.ts` states what each class REQUIRES:

| Class | Required capabilities | Whole object needed? |
| --- | --- | --- |
| IMAGE | `MALWARE_SCAN` only | **No** — it streams to clamd |
| VIDEO | `MALWARE_SCAN` only | **No** |
| AUDIO | `MALWARE_SCAN` only | **No** |
| DOCUMENT | `MALWARE_SCAN` + `DOCUMENT_INSPECTION` + `STRUCTURAL_VALIDATION` | **Yes** — a PDF's objects are anywhere |
| ARCHIVE | `MALWARE_SCAN` + `ARCHIVE_INSPECTION` + `STRUCTURAL_VALIDATION` | **Yes** — the directory is at the END |

`STRUCTURAL_VALIDATION` answers from a header window and is in
`STREAMABLE_CAPABILITIES`. `MEDIA_DECODE_VALIDATION` does need the whole object
— but it is **OPTIONAL** for image/video/audio, and above the buffer the
fetcher returns null and the examiner reports `UNAVAILABLE`. That is an honest
absence Aura records, never a pass it did not earn. **That is precisely why
raising the image ceiling is safe: the only capability that would have to lie
is the one permitted to say "I could not look".**

### Resulting ceilings

| Class | Before this pass | After | Reason |
| --- | --- | --- | --- |
| IMAGE | 32 MiB | **150 MiB** | only streamed examination is required |
| AUDIO | 32 MiB | **150 MiB** | only streamed examination is required |
| VIDEO | 150 MiB | 150 MiB | unchanged; externally constrained |
| DOCUMENT | 32 MiB | **32 MiB** | `DOCUMENT_INSPECTION` is REQUIRED and whole-object — **architectural** |
| ARCHIVE | 32 MiB | **32 MiB** | `ARCHIVE_INSPECTION` is REQUIRED and whole-object — **architectural** |

The malware-coherence envelope is unmoved: it is measured against
`MAX_ACCEPTED_OBJECT_BYTES`, which is video's ceiling.

**Stated rather than hidden:** Aura has no derived-representation pipeline, so a
very large image is delivered at full size to every viewer. That is a DELIVERY
concern, and the honest lever is a derivative — not refusing a legitimate 40 MiB
photograph to avoid a hypothetical 140 MiB one. It is the same missing component
HEIC needs.

---

## 3. Identity imagery — member, institution, public

**Surfaces measured.** Exactly two upload identity imagery, both through
`ProfileMediaPipeline`: `edit_profile_screen` (member) and
`institution_edit_profile_screen`. There is **no separate public-profile
editor** — `author_profile_screen` and the public surfaces are viewers that
render `avatarUrl`, they do not upload. So member and institution were already
consistent with each other by construction.

**FRAME — already correct.** `ProfileMediaEditor` crops to
`config.outputWidth/outputHeight` and re-encodes. Avatar and cover each get
their own ratio. This is the one place Aura already produces a normalized
derived representation.

**SIZE — a real defect, fixed.** Caps were 2 MiB avatar / 2 MiB logo / 4 MiB
cover, applied to the file **as picked**. An ordinary modern phone photograph is
3–8 MB, so choosing one for an avatar was **refused outright** — for an image
that ends up a few dozen kilobytes once cropped to a fixed size. The cap now
governs what the on-device editor can DECODE (`MediaCapacity.profileSource`,
32 MiB), which is the only real constraint, because the stored object is the
cropped output.

**TYPE — converged.** The pipeline carried its own three-format whitelist and a
fourth private `_inferMime` that defaulted anything unrecognised to
`image/jpeg`. Both retired; it resolves through `ContentIntake` and refuses by
KIND rather than relabelling.

**ENRICHMENT — the honest gap.** The crop is the only derivative. `thumbUrl` /
`displayUrl` are not populated with a genuinely different object, there is no
blurhash/placeholder or dominant colour, and the backend has **no image
dependency at all** (verified: `package.json` has no sharp/jimp/canvas). Output
is **PNG** — for a photographic avatar that is 5–10× larger than JPEG or WebP
would be. Institution logos legitimately need PNG for transparency; avatars and
covers do not. **Recommended but NOT changed in this pass**, because encode
format per call site is a product decision about logo transparency.

**HYDRATION.** The pipeline returns `result.url` and the profile field stores
that URL. Server-side emission maps stored URLs to the governed door
(`governedMediaUrls`), so delivery is governed — but the identity field itself
holds a URL rather than a media id, which is the same "references are URL
strings not FKs" shape recorded on 2026-08-18. Not changed here; it is a
schema-shaped question.

---

## 4. HEIC / HEIF — pursued, and the exact blocker

**Where it can actually arrive.** `image_picker` on iOS converts HEIC to JPEG
unconditionally — its `convertImage:` default branch returns
`UIImageJPEGRepresentation` and names the result `.jpg` — so the commonest phone
path does not deliver HEIC at all. Android is different, and it produced a
defect of its own (below). Real HEIC exposure is web/desktop: `desktop_drop`
drag-drop and `file_picker`.

### The Android defect this uncovered — fixed

`image_picker` on **Android** does not convert a picked HEIC unless a size or
quality constraint is set. When one IS set it re-encodes to JPEG **and keeps the
original filename** — producing `photo.heic` containing perfectly good JPEG
bytes. Two of Aura's own pickers set `imageQuality: 92`
(`institution_post_composer_screen:755`, `profile_media_pipeline:90`).

`ContentIntake._resolveMime` resolved from the declared type and then the
filename, and never looked at the content — so Aura refused a JPEG it fully
supports, for a reason the person could not possibly guess.

**Content sniffing is now the first evidence.** `sniffMimeFromBytes` reads the
signature, and the order is: **bytes → declared type → filename**. Bytes outrank
a declaration because a declaration is possession rather than authority — the D7
rule one layer up — and they outrank a filename because a filename is provably
wrong in the field. The sniffer returns null for a zip container rather than
guessing, because `PK..` cannot distinguish docx from xlsx and the filename is
genuinely the better evidence for which zip it is.

Detection is not permission: genuine HEIC bytes are still refused, but now for
being HEIC rather than for what they were called.

**Where it stops today.** `inferMimeFromFileName` already maps `.heic` →
`image/heic` and `.heif` → `image/heif`. The type resolves **correctly** and is
then refused because `kAllowedImageMimes` excludes it. Nothing guesses; the
refusal is honest.

**Browser reality, researched rather than assumed.** caniuse `heif` reports
**15.02% global support: Safari 17+ / iOS 17+ only.** Chrome, Edge and Firefox
are "no" on every version and every platform — verifiable at source level, not
just in a tracker: Blink's supported-image list in
`third_party/blink/common/mime_util/mime_util.cc` contains no `image/heic` or
`image/heif`, with no platform `#ifdef`. Safari's support is the OS decoder
(ImageIO) rather than a WebKit one, which is why it arrived with the OS version.
Firefox's tracking bug (Bugzilla 1402293) has been NEW and unassigned since 2017.

Two traps worth recording, because both would have cost us:

* **Do not feature-detect with `ImageDecoder.isTypeSupported('image/heic')`.**
  It is hardcoded false in Chromium *and* `ImageDecoder` is unimplemented in
  Safari — so it is wrong in **both** directions, returning a false negative on
  the only browser that actually renders HEIC.
* **Real iPhone HEICs are commonly tiled grids** plus separate alpha/depth/
  gain-map items. Any decode route must reassemble multiple tiles; it is not
  one chunk in, one frame out.

**Why it is not implemented in this pass.** Serving HEIC is not an option for
~85% of browsers, so accepting it REQUIRES producing a derived representation.
That needs a decoder, and Aura has no image-processing dependency anywhere in
the backend. Every route is new infrastructure:

| Route | What it costs |
| --- | --- |
| `heic-convert` / `libheif-js` (WASM) | pure JS, no native build — but a **new HEVC decode surface** in the API process, and HEVC decoding carries patent-licensing exposure |
| `sharp` + libheif | native build, system libraries, heavier deploy; same patent surface |
| Cloudflare Images / Image Resizing | Aura already uses R2, so this is the most natural fit — but it is an **account-level paid feature** and none is configured in the repo |
| WASM libheif in the browser (`heic2any`, `heic-decode`) | works everywhere, but ~2.7 MB shipped to every client, decoding on the viewer's device |
| WebCodecs `VideoDecoder` + HEVC | proven — libheif ships `decoder_webcodecs.cc` — but Chromium-only, GPU-dependent, and still requires tiled-grid reassembly |
| Client-side in Flutter | not viable: the `image` package does not decode HEIC |

This is precisely the founder's named stop condition — a genuinely new
infrastructure component and a commercially significant dependency.

**Recommendation:** Cloudflare Images, because the storage relationship already
exists, it keeps the decoder **out of Aura's process** (removing the CVE and
memory surface entirely), and it produces the derivative at delivery rather than
adding a transcoding stage to upload. The governed shape would be: accept HEIC
at intake as its true type → store the original with its true type → derive a
renderable representation → serve the derivative while the original keeps its
identity. That shape also solves large-image delivery.

**Needs founder decision:** whether to provision Cloudflare Images (cost), or
accept an in-process HEVC decoder (patent + security surface).

---

## 5. FINDING — the AI provenance subsystem has zero callers

Raised because composers were asked to assess and label AI-generated media.

`src/media/provenance/` is complete and tested: `c2pa-evidence.ts`,
`provenance-classifier.ts`, `provenance-resolver.ts`,
`provenance-trust.service.ts`, `media-provenance.service.ts`. It has a full
vocabulary — `ProvenanceEvidenceKind` (including `UPLOADER_DECLARATION`),
`EvidenceStrength`, `ProvenanceClaim` (`AI_GENERATED` / `AI_ALTERED` / `NOT_AI`
/ `INDETERMINATE`), and a resolver producing `DisclosureState`. `Media.aiFlags`
and `Media.editDisclosure` exist on the schema.

**It is never invoked.** `recordEvidence`, `disclosureFor`, `recompute` and
`disclosureBadgeState` have **no callers outside the provenance package**, and
there is **no controller and no endpoint**. `MediaProvenanceService` is provided
and exported by `MediaModule` and used by nothing. No evidence is ever recorded,
so a resolution would always return `NO_EVIDENCE`.

Meanwhile every composer sends a hardcoded `'editDisclosure': false`
(`compose_screen:1291`, `institution_post_composer_screen:811`), and
`post_card_parts.dart:378` already renders a disclosure when the flag is true.
So the presentation exists, the authority exists, and nothing connects them.

**Composers cannot label AI-generated attachments because nothing assesses
them, and there is no API to declare it through.** Wiring this is CH-12
integration work with an API surface behind it — a cross-chapter decision, not a
CH-13 composer change. No speculative UI was built.

---

## 6. CH-13 state

All six composers resolve acquisition, type, capacity and provenance-of-origin
through `ContentIntake`, and all six answer readiness/dirtiness through
`CompositionAuthority` where it owns the answer. `ProfileMediaPipeline` — a
seventh media surface not previously counted — is converged too.

**Concrete construction remaining before CH-13 could close:**

1. Derived representations (thumbnail/display copy). Blocks HEIC, large-image
   delivery, and identity-imagery payload size. **Needs the infrastructure
   decision above.**
2. Identity fields storing URLs rather than media ids. Schema-shaped.
3. AI provenance integration. Cross-chapter (CH-12).

None is a composer defect. The composer layer is converged.
