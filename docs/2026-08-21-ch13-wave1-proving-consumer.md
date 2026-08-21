# CH-13 Wave 1 — the proving consumer, and what measuring it found

**Date:** 2026-08-21
**Scope:** CO-RC-C5-010 / -011 / -012 proven through one real consumer; CO-RC-C5-007 measured empirically.
**Status:** Wave 1 authorities proven end to end. Five composers remain for Wave 2.

---

## 1. Why the conversation composer

`lib/features/conversation/presentation/conversation_screen.dart` was selected as the
first migration on measured grounds, not convenience:

* It is **the only surface in Aura that supports all three acquisition doors** —
  picker, clipboard paste and drag/drop. Every other composer has the picker
  alone. Migrating it exercises the whole of `ContentIntake` rather than a
  corner of it.
* It carried a **fourth private attachment model**, `_PendingAttachment`, that
  survived the consolidation `lib/core/media/attachment.dart` documents itself
  as having finished. It had a stringly-typed kind (`'IMAGE' | 'VIDEO' |
  'AUDIO'`) and its own `failed` boolean.
* It re-derived readiness locally, from `_uploading`, `_sending` and a text/media
  emptiness check at the send site.

It is, in other words, the surface where "shared shape, divergent meaning" was
most advanced.

## 2. What the migration proved

The full path now runs through the canonical authorities:

```
picker / paste / drop
  → ContentIntake.resolveBytes(...)      (CO-RC-C5-012)
  → AttachmentLifecycle.phaseOf(...)     (CO-RC-C5-011)
  → CompositionState.canSubmit           (CO-RC-C5-010)
  → uploadAuraMedia → /conversations/:id/messages
```

Retired from the screen:

| Displaced private logic | Replaced by |
| --- | --- |
| `_PendingAttachment` model | canonical `Attachment` |
| `_uploading` getter | `CompositionState.hasPendingAttachments` |
| `_sending` flag | `CompositionState.isSubmitting` |
| send-site emptiness check | `CompositionState.canSubmit` |
| `_ingestBytes` mime/kind ladder | `ContentIntake` |
| inline `.png ? image/png : image/jpeg` | `ContentIntake` |
| tile's `mediaId == null && !failed` | `AttachmentLifecycle.phaseOf` |

`test/product/ch13_conversation_composer_migration_test.dart` drives the **real
`ConversationScreen`**, not a harness resembling it, via the injectable
`FilePicker.platform` seam. Five tests, all passing.

**Scope boundary, stated plainly:** only the DOCUMENT door is driven in the
widget test. Clipboard paste arrives through `contentInsertionConfiguration`
and drag/drop through a native `desktop_drop` event; neither has a Flutter-side
seam a widget test can drive. All three doors call the same `_admit` → intake →
lifecycle → authority path, and that path is covered, but paste and drop are
covered *through the document door*, not through their own.

## 3. Measured defects corrected

Each was found by measurement, not inspection, and each is pinned by a test.

**D1 — `application/octet-stream` deferred a refusal instead of removing one.**
`_ingestBytes` fell back to octet-stream when neither the caller nor the
filename answered. The server's allow-list refuses that at presign, so the
attachment appeared in the composer, climbed, and failed with a generic
message. The fallback moved the refusal later rather than removing it. Intake
refuses at the door with product language, and nothing reaches `/media/presign`.

**D2 — a failed attachment was silently dropped from its own send.**
The guard read `mediaId == null && !failed` as "still uploading", so a FAILED
attachment counted as *finished*: the send proceeded and `whereType<String>()`
quietly dropped it. The person watched a message leave without the file they
had attached to it. `AttachmentLifecycle` holds that a failure still holds a
claim and is still pending, so the composition is not ready.

**D3 — paste provenance was laundered.** The retired upload path derived
`source` from the kind (`kind == 'AUDIO' ? 'RECORDING' : 'GALLERY'`), so a
pasted image and a dropped PDF were both recorded as GALLERY. Each door now
records its own provenance. `PresignDto` already accepts PASTE and UPLOAD;
nothing on the backend needed to change.

## 4. Disclosed behaviour changes

Two changes are visible and deliberate:

* **The send control now reflects readiness.** It was previously enabled on an
  empty composer and `_send()` returned early. It is now disabled until
  `canSubmit`. A composer that kept its own enablement rule would not have
  migrated; this is the authority answering.
* **Message bodies are now length-checked client-side** at
  `ContentLengthPolicy.message` (10,000 grapheme clusters). Previously
  unbounded on the client.

## 5. FINDING — Aura sends two different `kind` values for a document

Discovered while migrating, and **not resolved here.**

| Caller | Presign `kind` for a document | Backend size bucket |
| --- | --- | --- |
| Conversation composer (always has) | `'DOCUMENT'` | **25 MiB** |
| The other four composers, via `wireKind()` | `'IMAGE'` | **10 MiB** |

Both are live and both are accepted. `PresignDto.PRESIGN_KINDS` includes
`DOCUMENT`, and F130's own comment records the IMAGE routing as the defect it
fixed: *"DOCUMENT was missing from the inline type despite MediaKind supporting
it, so document uploads were validated against the IMAGE size bucket."*
Meanwhile `mime-policy.ts` names `wireKind()` explicitly and states the IMAGE
collapse is *preserved exactly* for the released client. `maxBytesFor` comments
the DOCUMENT bucket as "Conversation/document attachments".

Routing conversation through `wireKind()` would have cut its document limit from
25 MiB to 10 MiB — a 15 MiB PDF that attaches today would begin failing. The
migration therefore **preserves conversation's existing `'DOCUMENT'`**, and the
collapse is now an explicit named parameter of the single `wireKind` function
(`collapseDocumentToImage`, defaulting to the released behaviour) rather than a
hidden constant. No existing caller changes.

**Requires founder resolution.** Choosing one answer is a wire-contract change
with an installed client in the field, and it moves a real size limit for four
composers. It is recorded, not settled.

## 6. CO-RC-C5-007 — the empirical measurement

The founder's governing rule is that a *legitimate recoverable draft* must not
lose its media to a cleanup timer. The backend already implements exactly that,
and not with a timer: `ContentReference` is derived, release is soft,
`isRetentionEligible` requires zero live references **and** elapsed grace **and**
a fresh re-derivation, and `abandoned-upload` refuses to reclaim anything under
`ReclamationDisposition.REFERENCED`.

So the only open question was empirical: **which composers hold the sole
legitimate claim on uploaded media in client state alone?** All six were
measured.

| # | Composer | Draft persistence | Class |
| --- | --- | --- | --- |
| 1 | `compose_screen` (posts) | `PUT /posts/draft`, sets `attachedToDraft` | **A** — server reference |
| 2 | `article_editor_screen` | `repo.createDraft()`, `coverMediaId` on the row | **A** — server reference |
| 3 | `announcement_editor_screen` | `repo.createDraft(mediaIds: …)` | **A** — server reference |
| 4 | `institution_announcement_composer` | explicit `_saveDraft()` → server | **C** — no recoverable draft before save |
| 5 | `conversation_screen` | none; the draft dies with the widget | **C** — no recoverable draft exists |
| 6 | `institution_post_composer_screen` | **localStorage autosave holding `mediaUrl`** | **D** — unprotected |

Classes A and C carry no obligation. In class C the composition is not
recoverable at all, so reclaiming its media is *correct* behaviour rather than
loss — there is no draft to come back to.

### The single class-D exposure

`institution_post_composer_screen.dart` + `institution_draft_store.dart`.

`InstitutionDraft` persists `mediaUrl`, `mediaThumbUrl` and `mediaMimeType` to
`SharedPreferences` (`localStorage` on web), on a 600 ms debounce, scoped by
`(institutionId, userId, visibility)`. The store's own docstring records why:
*"The backend currently has no endpoint to list the current user's draft posts,
so the composer cannot rehydrate a draft from the server."*

The exposure window is precise:

1. A cover is uploaded → a READY `Media` row exists, `_mediaUrl` is set.
2. `_scheduleDraftSave()` writes the draft to localStorage. **It is now
   genuinely recoverable** — a refresh reopens the composer with the cover.
3. No server row exists, so no `ContentReference` derives from it.
4. If "Save draft" or "Publish now" is never pressed, `referenceCount` stays 0,
   grace elapses, and the abandoned-upload sweep reclaims the media.
5. The person reopens their recoverable draft and the cover is a dead URL.

Pressing "Save draft" creates a server-side post with `status: 'DRAFT'` and
clears the local fallback, so the exposure is strictly the *auto-saved,
never-explicitly-saved* window.

This is not a fault in the reaper. It is an unasserted claim, and it is exactly
the condition `CompositionState.draftClaim` was written to name.

**This is a concrete CH-13 migration requirement, carried into Wave 2.** No
hypothetical retention duration is needed or requested: the fix is to make the
claim visible to the authority that already exists, not to invent a policy.

## 7. Wave 2 remainder — measured

| Composer | Lines | Doors | Notes |
| --- | --- | --- | --- |
| `compose_screen` (posts) | 3429 | picker | largest; multi-attachment + caption map |
| `institution_post_composer_screen` | 2081 | picker | **carries the class-D exposure** |
| `announcement_editor_screen` | 1499 | picker | still has its own media model |
| `institution_announcement_composer` | 996 | picker | |
| `article_editor_screen` | 591 | picker | already has the 2 s autosave the policy preserves |

`public_composer.dart` (131 lines) takes no attachments and is not a CH-13
consumer.
