# HEVC / HEIC decode — rights review and the decision it leaves

**Date:** 2026-08-21
**Status:** HEIC sub-capability STOPPED at the commercial boundary, as instructed.
Thumbnails, display copies and every other derivative shipped unaffected.

**Not legal advice.** This records published terms, verifiable packaging facts,
and the documented conduct of other projects.

---

## The direct question, answered

> Is there any route to decode HEIC in a Linux Node.js server that avoids
> **both** LGPL obligations **and** HEVC patent exposure?

**No.** But the two halves fail for completely different reasons, and
conflating them hides the real decision.

### The LGPL half is benign — and this is the part everyone gets wrong in our favour

**SaaS is not distribution.** LGPL-3.0 inherits GPL-3.0's definition of
"convey", and mere interaction over a network is expressly not conveying. The
AGPL exists *precisely because* the GPL/LGPL do not reach network use.

For a hosted service that never ships binaries, running libheif on our own
servers and returning only JPEG triggers **no LGPL obligation at all** — no
source offer, no relinking, no notices. Static vs. dynamic linking, the thing
everyone worries about, only matters when you convey.

One constraint worth recording: if Aura ever ships a **container image, an
on-prem build, or a desktop app** containing these libraries, LGPL-3.0 §4 comes
alive immediately. That is a constraint on the *artifact*, not the runtime.

### The patent half is unavoidable — and worse than the common assumption

The prevailing wisdom is "pools charge per unit at first sale, so a hosted
service isn't covered." **That is false for Access Advance**, which since
2025-12-15 administers *both* remaining HEVC pools. Their own terms:

> "We license HEVC Decoders and HEVC Encoders in Consumer HEVC Products,
> whether made available in devices, software, **or through Cloud Based
> Services**."

> licensees include parties that "**(b) process content at the End User's
> request using HEVC Decoders... where the output is returned to the End User**"

That clause is a literal description of a server-side HEIC thumbnail. **No
published rate exists for that category** — it appears in none of the three
rate tables. The exposure cannot be priced from public documents.

An open-source licence grants **copyright** permissions and nothing under
third-party patents. libheif and libde265 are LGPL-3.0 and neither project's
copyright holders hold the HEVC SEPs. libde265's own FAQ mentions patents,
royalties and pools **zero times** — upstream gives adopters no warning at all.

**No still-image carve-out exists.** Both pools' terms were searched for
still/image/HEIF/HEIC — zero relevant hits. Via LA states the same terms apply
across all profiles, and Main Still Picture is a profile of H.265. The
container's own author, Nokia, writes: *"Codec Patent licenses are neither
granted, implied nor otherwise conveyed hereunder"* — and Nokia has joined no
pool.

**AVIF does not help.** An iPhone HEIC is HEVC-coded; AVIF is AV1-coded. They
share the container and **nothing at the codec layer**. Apple offers exactly two
capture settings — HEIF/HEVC or JPEG — and no AVIF constant exists in
`AVVideoCodecType`. And "royalty-free" is itself contested now: Dolby sued Snap
over **AV1 and HEVC** in March 2026.

## The framing that matters most

**Aura already decodes HEIC — on the user's Apple device, under Apple's own
licence.** `ContentNormalizer` uses `ui.instantiateImageCodec`, which is the
platform codec.

Moving that into the worker would not be a refactor. It would **transfer the
licensed act onto Aura's infrastructure.**

## The libraries are unsafe as well as unlicensed

This was the review's most actionable finding, and it is independent of the
rights question.

`heic-convert → heic-decode → libheif-js` ships **pristine libheif 1.19.8 and
libde265 1.0.15 with roughly 28 unpatched advisories** from the May–June 2026
wave — including a Critical heap-overflow that overwrites a C++ vtable pointer,
and CVE-2026-47247, which **renders process heap bytes as visible pixels in the
output thumbnail** (leaking other users' image data if a module instance is
reused across requests).

**`npm audit` reports all of it clean**, because no advisory is filed against
the npm package names. Silently insecure is worse than loudly insecure.

An inversion worth knowing: **distro packages are safer than the npm package**
at the same upstream version. Debian trixie backports the entire 2026 wave;
Alpine 3.21/3.22 — our base image — records **no 2026 fixes** for either
library, and Alpine's libheif links GPL-2 x265 unavoidably.

## What everyone else does

| | |
| --- | --- |
| **Fedora / Red Hat** | Ships libheif **with HEVC disabled**. `libde265` is not in Fedora at all — it lives only in RPM Fusion |
| **sharp** | Prebuilts bundle libheif with **aom only**, so AVIF works and HEIC fails. The docs call HEVC "patent-encumbered". A deliberate exclusion by the maintainer |
| **Chrome / Firefox** | Neither ships a **software** HEVC decoder; both offload to the platform vendor |
| **Cloudinary** | Markets HEIC→JPEG conversion while writing that "the HEVC codec... is subject to an extensive amount of patents with substantial royalty fees" |
| **Immich / Nextcloud / PhotoPrism** | Ship it, and have never publicly discussed the question |

There is no Cisco-OpenH264 equivalent for HEVC. **Nobody absorbs the cost on
your behalf.**

No pool has been documented asserting against a small SaaS for server-side HEIC
decode — but the two closest analogues both target *services* and are both
recent: Velos Media v. TikTok (June 2025) and Dolby v. Snap (March 2026).
Historic protection has been **enforcement economics, not a safe harbour.**

---

## What was done in the code

The boundary is **enforced, not commented**. `hevc-decode-boundary.spec.ts`
fails if `heic-convert`, `heic-decode`, `libheif-js`, `@saschazar/wasm-heif`,
`heif2jpeg`, `heic-to` or `sharp` is declared **or installed transitively**, and
pins that HEIC is refused as `SKIPPED` (policy) rather than `FAILED` (fault).

If that test ever fails, the failure *is* the question — someone is proposing
that Aura decode HEVC on its own servers, and it must be answered before the
dependency lands rather than discovered after.

---

## THE FOUNDER DECISION

One binary question:

> **Will Aura perform HEVC decoding on its own infrastructure without a licence
> from Access Advance — or not at all?**

**If "not at all"** — nothing changes. Client-side decode continues on iOS,
macOS and Android 28+; `originalMimeType` keeps recording provenance; HEIC from
web and Android < 28 continues to be refused truthfully. **Zero cost, zero
legal spend, zero new exposure.** A vendor that decodes on *their*
infrastructure (Cloudflare Images, Cloudinary) is the paid variant of the same
answer — it moves the licensed act off our servers.

**If "we will"** — the engineering is ready and slots into the existing worker
as one line of `DERIVABLE_SOURCE_MIMES` plus a decode branch. The responsible
implementation is **not** the npm route: switch the worker image from Alpine to
Debian trixie, install `libheif1 + libheif-plugin-libde265` (deliberately *not*
the x265 plugin — we need decode, not encode, and this keeps GPL-2 out of the
image), decode through libvips, which is the only stack that clamps libheif's
limits for us, in a short-lived wall-clock-capped child process. The honest cost
of the decision is **one email to Access Advance** describing a consumer service
that decodes user-submitted HEVC still images server-side, asking for the
Cloud-Based Services rate. There is no published number; asking is the only way
to learn it — and it is also what surfaces whether they consider it a
"Commercial HEVC Excluded Product" and therefore outside their pool entirely,
which would be the best available outcome and cannot be determined from public
documents.

Aura's existing code had already identified this as a decision above
engineering. The review did not change that conclusion — **it priced it.**
