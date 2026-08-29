# Compose — creation and sharing reconstruction

**Part of:** AURA RICH CONTENT & INTERACTION SYSTEM
**Date:** 2026-08-29
**Status:** first pass — root causes established, three defects repaired in
code, **nothing product-proven on a device yet** (Railway deploy incident).

Compose is the platform's creation and sharing surface. It is not a text box
with attachments, and this document records where it still behaved like one.

---

## 1. CURRENT COMPOSE ARCHITECTURE (as found)

A canonical acquisition module exists — `lib/core/media/media_acquisition.dart`
— and its own header claims that gallery, camera, drag-drop and paste all
converge through it. **They do not.** The module exposes exactly two entry
points, `acquireMultipleMedia` (gallery) and `resolveAcquired` (everything
already-selected). **There is no camera function in it at all.**

So the composers reach for the picker directly. Measured across `lib/`:

| Surface | Picker APIs called directly |
|---|---|
| `posts/…/compose_screen.dart` | `ImageSource.camera`, `pickImage`, `pickVideo`, `pickMedia`, `pickMultipleMedia` |
| `conversation/…/conversation_screen.dart` | `ImageSource.camera` |
| `institutions/posts/…_composer_screen.dart` | `pickMedia`, `pickMultipleMedia` |
| `announcements/…/announcement_editor_screen.dart` | `pickMedia` |
| `institutions/announcements/…_composer.dart` | `pickMedia` |
| `articles/…/article_editor_screen.dart` | `pickImage` |
| `shared/media/profile_media_pipeline.dart` | `pickImage` |

**Five different picker APIs in one file**, and a canonical module standing
beside them that the camera never enters. Two ceilings also disagree:
`kMaxComposableMedia = 10` in the canonical module, `_maxAttachments = 5` in
the composer.

This is the shape of the whole problem: a canonical path was built and the
older paths were never retired, so "converged" is true of the documentation
and not of the code.

---

## 2. PHOTO CAPTURE — root cause

`_pickImageFromCamera` → `ImagePicker().pickImage(source: camera)` →
`_addPickedFile(type: image)`.

The photo path works because `_addPickedFile` happens to do the image-shaped
work: it reads the bytes, decodes them, and records width and height. Nothing
about that is camera-aware — a photograph survives because the branch it lands
in is the one that was finished.

**Defect found and fixed:** `ContentIntake.resolveFile` refuses an empty file
and an oversized one, but **both checks are guarded by `sizeBytes != null`**,
and the composer never passed it. A zero-byte capture — a cancelled recording,
a camera that created its file and failed, an OS that reclaimed the temp file —
passed the door, appeared in the composition, and failed later where nobody
could tell what had happened. Size is now measured and passed.

---

## 3. VIDEO CAPTURE — root cause and the first broken arrow

**FIRST BROKEN ARROW: `Attachment.durationMs`, `width` and `height` had no
producer on the video path.**

They have consumers everywhere. `aura_video_surface` renders a duration label;
layouts size themselves from the aspect ratio; `uploadAuraMedia` accepts all
three. And the only place that ever wrote them was:

```dart
if (type == AttachmentKind.image) {
  final bytes = await file.readAsBytes();
  final size = await _decodeImageSize(bytes);
  attachment.width = size?['width'];
  attachment.height = size?['height'];
}
```

Video fell past that branch untouched, and the upload then read the fields back
as:

```dart
width:    attachment.isImage ? attachment.width : null,   // nulled for video
height:   attachment.isImage ? attachment.height : null,  // nulled for video
duration: attachment.isVideo ? attachment.durationMs : null,  // never set
```

So **every recorded video arrived at storage with no dimensions, no duration
and nothing to lay a poster out against.** The file itself was intact and the
upload returned success — which is exactly why this reads as "uploads fine,
then appears broken". Upload success was never content success.

The `Media` table has had `width`, `height`, `duration`, `thumbUrl` and
`thumbnailUrl` columns the whole time, and the backend has a poster derivative
worker with ffmpeg. **The columns and the processing existed; the producer did
not.**

**Repair:** `_probeVideoIdentity` measures the recorded file locally through
the codebase's existing `local_video_source` platform abstraction (the same one
`aura_video_surface` uses), recording duration and dimensions **with rotation
applied** — a portrait phone recording reports a landscape natural size plus a
90° correction, and laying out from the raw numbers produces a sideways
letterbox in every feed it reaches. Best-effort by construction: an
unmeasurable file proceeds exactly as it does today, so it cannot regress.

`dart:io` was deliberately NOT used. It would have analysed clean and broken
the web build; the conditional-import abstraction already in this codebase is
the right instrument, and a full `flutter build web` was run to prove it.

---

## 4. EXTERNAL DESTINATIONS — root cause

Founder: *"sometimes TikTok appears; LinkedIn can disappear entirely;
destination presence/absence does not feel deterministic."*

It was not random. Both destinations resolved like this:

```dart
final results = await Future.wait([
  _safeGet(dio, '/integrations/tiktok/account'),
  _safeGet(dio, '/integrations/linkedin/account'),
]);
// _safeGet:  catch (_) { return null; }
```

and each answer was reduced to one boolean, `connected`. **A swallowed error is
indistinguishable from a considered no.** A dropped request, an expired token,
a 500 and a genuinely unconnected account all became `false`, and `false`
removed the destination from the surface entirely.

So visibility depended on whether a transient GET happened to succeed. That is
the definition of "feels random", and it is worst in the case that matters
most: a token expiring made a destination the person had **deliberately
connected** vanish with no explanation and no way to fix it.

**LINKEDIN_DISAPPEARANCE_ROOT_CAUSE** and **TIKTOK_INCONSISTENCY_ROOT_CAUSE**
are the same defect: a boolean derived inside `catch (_)`.

**Repair:** `lib/core/distribution/destination_capability.dart` — destinations
resolve into explicit states (`available`, `connectRequired`,
`reconnectRequired`, `unsupportedContent`, `unsupportedPlatform`,
`accountNotEligible`, `temporarilyUnavailable`, `notOffered`). The probe now
reports **what happened** and the resolver decides **what it means**, which is
the separation the old code collapsed:

* `401/403` — the provider answered and refused this authorisation →
  `reconnectRequired`, and the account is still treated as connected.
* `404` — a real absence → `connectRequired`.
* offline / timeout / 5xx — **we** failed to ask → `temporarilyUnavailable`.

Only `notOffered` may be invisible. Everything else says what it is and, where
one exists, offers the action.

### 4b. Destination presentation — the slice completed

**OLD MODEL.** Each provider owned ~90 lines that decided its own visibility,
subtitle and enablement from its own booleans, and the two did not agree:

```dart
final linkedinVisible = _linkedinLoading || _linkedinConnected;
// TikTok had no visibility guard at all
final linkedinHelper = (_linkedinError ?? '').trim();   // e.toString()
```

So TikTok always appeared and LinkedIn disappeared whenever `connected` went
false — which, since `connected` came from a swallowed error, meant whenever a
request failed. **That asymmetry is exactly the reported symptom.** The
subtitle also rendered a raw exception where a sentence belongs.

**NEW MODEL.** One `_buildDestinationRow`, driven by `DestinationCapability`
and nothing else. A destination becomes invisible for exactly one reason:
`notOffered`.

| State | Shown | Control | Publish allowed |
|---|---|---|---|
| `available` | yes | Switch | **yes** |
| `connectRequired` | yes | **Connect** | no |
| `reconnectRequired` | yes | **Reconnect** | no |
| `temporarilyUnavailable` | yes | **Retry** | no |
| `unsupportedContent` | yes | disabled, reason shown | no |
| `unsupportedPlatform` | yes | disabled | no |
| `accountNotEligible` | yes | disabled | no |
| `notOffered` | **no** | — | no |

**Actions follow state at the action too.** The publish guard asked
`_tiktokConnected`; it now asks `_tiktok.isPublishable`, so a
disabled-looking destination cannot reach the legacy publishing path behind
the UI. `_syncExternalPublishingToggles` likewise clears a selection only when
the destination genuinely cannot take the composition — a merely unreachable
provider no longer silently discards a choice the person made.

**Legacy consumers.**

| Consumer | Status |
|---|---|
| `compose_screen` visibility/subtitle/enablement | **retired** — fields deleted, not merely unused |
| `compose_screen` publish guard | **retired** |
| `compose_screen._syncExternalPublishingToggles` | **retired** |
| `announcement_editor_screen` probe | **authority converged** — a failed request no longer writes `connected = false`; only a 404 does |
| `announcement_editor_screen` / `announcement_distribution` presentation | **NOT converged** — still renders from `linkedinConnected` / `tiktokConnected` booleans |
| `me_connected_accounts_panel` | **different capability context** — it manages connections rather than resolving them for a composition, and is documented as such rather than converged |

**Draft preservation.** No path in this slice mutates the composition on a
provider failure: the probe writes only destination state, the publish guard
returns before touching the draft, and toggle sync clears a boolean. Provider
failure cannot remove media, clear text, or reset the composer.

**Proof, client-side only.** 18 tests in
`test/distribution/destination_capability_test.dart`, including the regression
that matters most — *no failure state hides a destination* — asserted across
every state at once, so a reintroduced disappearance fails loudly.

---

### 4c. Mobile capture — doors removed

The path to a photograph was **Compose → "Add attachment" → sheet → "Take
photo" → camera**: three taps and two doors to do the thing people open a
composer for. The sheet also offered "Choose photo" and "Choose video" as
separate entries, while `_pickVideoFromGallery` is literally
`=> _pickMediaFromGallery()` — one behaviour wearing two labels, in a picker
that already returns photographs and videos in a single selection. The split
existed only in the menu, and it made a person choose a category before
choosing content.

Now, where a camera exists: **Photo · Video · Library · More**, with capture
one tap from the composer. "More" keeps the fuller set, which is where a file
type nobody has in mind belongs.

---

## 5. CANONICAL CONTENT IDENTITY

The identity that must survive acquisition → preview → upload → storage →
hydration → render:

```
kind · mime (+ originalMimeType) · width · height · durationMs ·
poster/thumb · source (camera|gallery|share-in|paste|drop) ·
storage identity (mediaId) · processing status · caption
```

Established this pass: **dimensions and duration now survive video capture**,
and `width`/`height` are no longer discarded at the upload boundary for video.

Still unproven end-to-end: poster arrival, processing-state rendering, and
whether the hydrated projection keeps VIDEO semantics through to the renderer.

---

## 6. WHAT IS NOT DONE

Named honestly, because the instruction was explicit that a large audit with
untouched defects is not an outcome:

* **Camera still bypasses the canonical acquisition module.** The repairs above
  are inside `_addPickedFile`, which is the shared door for the composer's own
  camera paths — but the module's claim to be canonical remains false, and the
  other six surfaces still call the picker directly.
* **Share-in** (`§9`) not audited: no OS share-target path was traced.
* **Draft recovery across upload failure** (`§7`) not exercised.
* **Native share sheet** (`§14`) not implemented or assessed.
* **Multi-media ordering** untouched, therefore unregressed but unproven.
* The new `DestinationCapability` is **resolved but not yet rendered** — the
  composer still draws its toggles from the derived booleans. The states exist
  and are correct; the UI does not yet show `Reconnect` where it should.

---

## 7. CROSS-CLIENT STATUS

| Platform | Status |
|---|---|
| ANDROID | IMPLEMENTED, UNVERIFIED — no device run with these changes |
| IOS | NO_COVERAGE — no macOS host |
| WEB | IMPLEMENTED, build-verified (`flutter build web` passes) |
| WINDOWS | UNVERIFIED — `video_player` has no Windows implementation, so video probing returns null there by design and the attachment proceeds unmeasured |

Nothing here is PRODUCT_PROVEN. Railway is in a declared deploy incident, so
neither the API nor the web build could be shipped for a real run.
