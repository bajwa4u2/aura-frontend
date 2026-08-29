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


---

## 8. SHARE — the content-first creation intention (founder ruling 2026-08-29)

### Roles, frozen

| | |
|---|---|
| **COMPOSE** | discourse-first. Media supported, secondary. |
| **SHARE** | content-first. |

They coexist. Share does not replace ordinary media inside Compose. Mobile
camera-first creation belongs to Share.

### Placement

`/create` hub, **first card**, labelled **Share**. Not "Photo or video": photo
and video are today's acquisition capabilities, not the product boundary — the
architecture must accept links, rich content and share-in later without
renaming the product.

**MOBILE NAVIGATION UNCHANGED.** No tab added, reordered or removed; Home
untouched; no new primary destination. The hub already asks what you want to
make, and Share is a new answer, not a new place.

### What Share owns: almost nothing

| Concern | Authority consumed |
|---|---|
| acquisition | `media_acquisition` — capturePhoto / captureVideo / acquireMultipleMedia |
| the door | `ContentIntake` |
| content identity | `Attachment` (local file/bytes + width/height/durationMs) |
| draft | `CompositionState`, requiresBody false |
| phases / readiness | `AttachmentLifecycle` |
| preview | **`AuraCompositionStrip`** |
| upload | `uploadAuraMedia` |
| feed publication | PUT /posts/draft then POST /posts/draft/publish |
| conversation send | `conversationsRepository.send(id, body, mediaIds:)` |

No ShareAttachment, ShareDraft, ShareUpload or ShareMedia exists.

### Camera acquisition convergence

`media_acquisition` claimed camera convergence and had **no camera function**.
It now has capturePhoto and captureVideo, and Share is their first caller.
Capture is singular by design — a camera returns one thing at a time, and a
degenerate multi-select would invent a plural the device never offers.
`AttachmentSource.camera` survives intake, which is what lets a preview say
Retake rather than Remove. Compose's direct picker calls remain OPEN.

### Upload behind preview

The attachment enters `CompositionState` and is drawn by
`AuraCompositionStrip` from its LOCAL source before any upload starts; uploads
run behind it with per-item progress, explicit failure and retry. Nobody waits
on a round trip to recognise what they just made.

### Destination model

`AuraDestination` (Feed | Conversation) is deliberately NOT
`DestinationCapability`. Internal destinations are always available; external
capability depends on providers we do not own. Collapsing them is how provider
health starts deciding whether Aura content is publishable. Order is fixed:
capture, preview, context, Aura destination, publish — external distribution
downstream and optional.

### /compose?mode=media

**Inventoried: zero in-app callers.** It can only arrive from a typed URL or an
external deep link, so it is an intent expressed before there was a surface for
it. On mobile it now resolves into Share; the route is NOT deleted and deep
links still work. On web/desktop the sheet remains — Share is mobile-first, and
forcing it onto a desktop composer would make one platform wear another's
shape.

### Governance gates crossed, and how

Five anti-drift gates caught the new surface. All satisfied, none bypassed:

* route classification x2 — `/share` classified MEMBER
* full-height sheet census — conversation picker reclassified against the
  census's own section 6 (transient, dismissible, returns a value, traps
  nothing, no addressable identity), not merely counted
* C0 full-surface spinner — replaced with `AuraProductState(loading)`
* Create vocabulary gate — updated with the founder ruling recorded IN the
  test, so it reads as a decision rather than drift

### Status

| | |
|---|---|
| ANDROID / IOS | IMPLEMENTED — UNVERIFIED, no device run |
| WEB | IMPLEMENTED, build-verified |
| WINDOWS | IMPLEMENTED, unverified |
| Phase-1 flows | UNVERIFIED_PENDING_DEPLOY/DEVICE |

Re-upload: none. Second draft model: none.


---

## 9. THE HELD-DRAFT COLLISION (found and repaired before device testing)

### The defect

Share's first Feed path was:

```
PUT  /posts/draft          // overwrite whatever is held
POST /posts/draft/publish  // publish whatever is held
```

Both are keyed by AUTHOR. So somebody holding an unfinished post in Compose,
who then shared a photograph, would have had **their unfinished post replaced
by the photograph and published in its place.**

### Root cause

Every draft operation in `posts.service` resolves by author alone —
`getLatestHeld(userId)`, `saveLatestHeld(userId)`, `publishLatestHeld(userId)`,
`clearLatestHeld(userId)`. One draft per person, by construction. Two creation
intentions collapsed into one row because the endpoint's key was the author
rather than the draft.

**AND IT RUNS BOTH WAYS.** `getLatestHeld` selects the most recently updated
DRAFT, so a Share draft left behind becomes what Compose resumes next time —
Share silently inheriting Compose's chair.

### The fix: identity, not a second model

**No schema change, no migration, no `ShareDraft`.** The same service already
exposed an identity-addressed path that nothing was using:

```
POST /posts/held        -> creates a NEW row, returns its id
PUT  /posts/:id         -> updates THAT draft
POST /posts/:id/publish -> publishes THAT post
DELETE /posts/:id       -> removes THAT draft
```

`FeedDraftPublisher` uses only these. It has **no method that resolves the
caller's draft** — `publish` requires a `draftId` and throws without one, so
publishing the wrong draft is not something care at the call site prevents; it
is unreachable.

### Ownership rules

| Event | What happens |
|---|---|
| publish | that draft id only |
| retry after failure | **the same** draft id, kept on the screen |
| leave with an unpublished draft | that id deleted, best effort, named |
| any failure | Compose's draft untouched — never addressed |

`discardDraft` names one id. There is no `clearCurrentDraft()` here, because a
broad clear is exactly how one creation context destroys another's.

### Legacy drafts

Untouched. No migration was required precisely because no schema changed:
existing held drafts remain the author's single Compose draft, reached by the
unchanged `GET /posts/draft`. Share simply stops competing for that row.

### Control tests

`test/distribution/feed_draft_publisher_test.dart` — 30 tests, and the first
group proves the guard is a control rather than a description: it runs the OLD
sequence (`PUT /posts/draft`, `POST /posts/draft/publish`) through the same
predicate and asserts it IS flagged. Without that, every other assertion could
pass against the very defect they exist to prevent.

The predicate matches paths **exactly**: `/posts/draft` is a prefix of
`/posts/draft_share_1`, and a `contains` check reported a correctly
id-addressed call as a singleton one — a guard against a dangerous path
flagging the safe path instead.

### Status

**HELD_DRAFT_COLLISION = STRUCTURALLY_CONVERGED.** Device proof still owed for
the human flows.
