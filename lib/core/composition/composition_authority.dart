// CH-13 · CO-RC-C5-010 — COMPOSITION AUTHORITY.
//
// The obligation names the whole span: content state → drafts → autosave →
// mentions → links → formatting → validation → readiness → keyboard →
// accessibility. What every one of those has in common is that six composers
// currently answer them six times, and the answers differ in ways nobody
// intended.
//
// The most consequential of those answers is READINESS — may this be sent. It
// is currently re-derived per composer from a mix of text emptiness, an
// `uploading` boolean and, in places, nothing at all. That is how a composer
// enables Send while an attachment is still climbing, and how another disables
// Send forever because a rejected file was never dropped from the list.
//
// This is the authority. It owns:
//
//   * READINESS — one derivation, from the lifecycle and the length policy.
//   * DIRTINESS + AUTOSAVE SCHEDULING — when a draft must be written, decided
//     from state rather than from a timer each composer starts itself.
//   * THE DRAFT CLAIM — the rule that CO-RC-C5-007 turns on (see below).
//
// It deliberately does NOT own presentation, keyboard handling or the widget
// tree. Those are E1 client primitives and belong with the surfaces; an
// authority that reached into them would be the "another abstraction layered
// over the surfaces" outcome Wave 1 was told to avoid.
//
// ─────────────────────────────────────────────────────────────────────────────
// CO-RC-C5-007 — THE DRAFT CLAIM
//
// The founder's governing rule: a legitimate recoverable draft must not lose
// its media because a cleanup timer expired. Media may be destroyed only when
// lifecycle/reference authority establishes genuine abandonment.
//
// The backend already implements exactly that, and it is not a timer:
// `ContentReference` is a derived index, release is soft, and
// `isRetentionEligible` requires zero live references AND grace elapsed AND a
// fresh re-derivation from the authoritative source tables. `abandoned-upload`
// refuses to reclaim anything with `referenceCount > 0` under
// `ReclamationDisposition.REFERENCED`.
//
// So the client's whole responsibility is to make a recoverable draft VISIBLE
// to that authority. A draft that exists only in widget state holds no
// reference, and correctly-implemented cleanup will eventually reclaim its
// media — not by fault of the reaper, but because nothing ever asserted a
// claim. [CompositionState.draftClaim] names that condition so a composer
// cannot hold recoverable media without either registering a claim or
// admitting it has none.

import 'package:characters/characters.dart';

import '../content_policy/content_length_policy.dart';
import '../media/attachment.dart';
import 'attachment_lifecycle.dart';

/// Whether a composition's media is protected from reclamation, and by what.
enum DraftClaim {
  /// Nothing is held that could be reclaimed. The safe, common case.
  nothingToProtect,

  /// A server-side row exists whose own table is an authoritative source for
  /// the reference index — an Article draft's `coverMediaId`, a persisted
  /// message row. The backend can see this media and will not reclaim it.
  serverHeld,

  /// Recoverable media is held in CLIENT STATE ONLY. No `ContentReference`
  /// derives from it, so retention authority cannot see it, and the abandoned-
  /// upload sweep may eventually reclaim it. Not a bug in the sweep — an
  /// unasserted claim.
  ///
  /// A composer in this state is either non-recoverable by design (the draft
  /// dies with the widget, which is honest) or it is carrying an unrecorded
  /// obligation.
  clientOnly,
}

/// The canonical composition state. Immutable; every transition returns a new
/// value, so a stale reference cannot silently mutate a live composition.
class CompositionState {
  const CompositionState({
    this.body = '',
    this.attachments = const <Attachment>[],
    this.rejections = const <String, AttachmentRejection>{},
    this.cancelled = const <String>{},
    this.maxLength = ContentLengthPolicy.message,
    this.requiresBody = true,
    this.isSubmitting = false,
    this.draftClaim = DraftClaim.nothingToProtect,
    this.savedBody,
  });

  final String body;
  final List<Attachment> attachments;

  /// Refusals, keyed by `localId`. Held beside the attachment rather than on
  /// it, because a refusal is a judgement about intake and the attachment is
  /// evidence — merging them would let a later mutation erase the judgement.
  final Map<String, AttachmentRejection> rejections;

  /// Cancellations, keyed by `localId`. Same reasoning.
  final Set<String> cancelled;

  final int maxLength;

  /// Whether text is required. A voice message composer legitimately has no
  /// body; a post composer does. This is the "legitimate context difference"
  /// the gate obligations require be expressed rather than hard-coded per
  /// surface.
  final bool requiresBody;

  final bool isSubmitting;
  final DraftClaim draftClaim;

  /// The body as last persisted. Null when never saved. Dirtiness is the
  /// difference between this and [body] — not a flag someone must remember to
  /// set, which is how autosave silently stops running.
  final String? savedBody;

  CompositionState copyWith({
    String? body,
    List<Attachment>? attachments,
    Map<String, AttachmentRejection>? rejections,
    Set<String>? cancelled,
    int? maxLength,
    bool? requiresBody,
    bool? isSubmitting,
    DraftClaim? draftClaim,
    String? savedBody,
    bool clearSavedBody = false,
  }) {
    return CompositionState(
      body: body ?? this.body,
      attachments: attachments ?? this.attachments,
      rejections: rejections ?? this.rejections,
      cancelled: cancelled ?? this.cancelled,
      maxLength: maxLength ?? this.maxLength,
      requiresBody: requiresBody ?? this.requiresBody,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      draftClaim: draftClaim ?? this.draftClaim,
      savedBody: clearSavedBody ? null : (savedBody ?? this.savedBody),
    );
  }

  // ── Derived truth. Nothing below is stored, so nothing below can drift. ──

  AttachmentPhase phaseOf(Attachment attachment) =>
      AttachmentLifecycle.phaseOf(
        attachment,
        rejection: rejections[attachment.localId],
        cancelled: cancelled.contains(attachment.localId),
      );

  /// Attachments that still hold a claim — everything not refused or cancelled.
  List<Attachment> get liveAttachments => attachments
      .where((a) => AttachmentLifecycle.holdsClaim(phaseOf(a)))
      .toList(growable: false);

  /// Attachments the composition is waiting on.
  List<Attachment> get pendingAttachments => attachments
      .where((a) => AttachmentLifecycle.isPending(phaseOf(a)))
      .toList(growable: false);

  /// Attachments that may actually be sent.
  List<Attachment> get composableAttachments => attachments
      .where((a) => AttachmentLifecycle.isComposable(phaseOf(a)))
      .toList(growable: false);

  bool get hasPendingAttachments => pendingAttachments.isNotEmpty;

  String get trimmedBody => body.trim();

  bool get isOverLength => body.characters.length > maxLength;

  bool get isEmpty => trimmedBody.isEmpty && liveAttachments.isEmpty;

  /// Unsaved work exists. `savedBody == null` with an empty body is a fresh
  /// composer, not a dirty one.
  bool get isDirty => savedBody == null ? trimmedBody.isNotEmpty : body != savedBody;

  /// THE readiness derivation. One place, and every composer asks it.
  ///
  /// A composition is ready when it carries something, is not over length, has
  /// nothing still in flight, and is not already being submitted. The last of
  /// those is what stops the double-send every composer currently guards
  /// against with its own boolean.
  bool get canSubmit {
    if (isSubmitting) return false;
    if (isOverLength) return false;
    if (hasPendingAttachments) return false;
    if (requiresBody && trimmedBody.isEmpty) {
      // Text-required surfaces still accept an attachment-only composition when
      // the attachment is genuinely ready — a photo with no caption is a real
      // message, and refusing it was a per-composer accident rather than a rule.
      return composableAttachments.isNotEmpty;
    }
    return !isEmpty;
  }

  /// Why submission is blocked, for surfaces that explain themselves. Null when
  /// [canSubmit] is true.
  String? get blockedReason {
    if (isSubmitting) return 'Sending…';
    if (isOverLength) return 'This is longer than the limit.';
    // A FAILED item is not a slow one. Both block the send, but only one of
    // them will resolve if the person waits, and telling someone to wait for
    // something that has already stopped is how a composition appears frozen.
    if (failedAttachments.isNotEmpty) {
      final n = failedAttachments.length;
      return n == 1
          ? "One item didn't upload. Retry it or remove it."
          : "$n items didn't upload. Retry them or remove them.";
    }
    if (hasPendingAttachments) return 'Waiting for attachments to finish.';
    if (isEmpty) return 'Nothing to send yet.';
    return null;
  }

  /// Items that failed and may be retried.
  ///
  /// Distinct from rejected: a refusal is terminal, a failure is not, and
  /// offering Retry on something that can never succeed is a false promise.
  List<Attachment> get failedAttachments => attachments
      .where((a) => phaseOf(a) == AttachmentPhase.failed)
      .toList(growable: false);

  /// True when some items are ready and others have failed.
  ///
  /// The state that must never resolve itself silently. Sending the survivors
  /// would publish a composition the author never approved — three photographs
  /// where they chose four — and they would not find out.
  bool get hasPartialFailure =>
      failedAttachments.isNotEmpty && composableAttachments.isNotEmpty;

  /// REORDER — author intent, expressed deliberately.
  ///
  /// Returns a new state with the item at [oldIndex] moved to [newIndex].
  /// Order is composition intent all the way down: it is persisted against
  /// `PostMedia.position` / `MessageMedia.position`, returned in that order,
  /// and rendered in that order by the collage and the immersive viewer.
  ///
  /// Out-of-range indices return the state unchanged rather than throwing — a
  /// drag that ends outside the list is an ordinary gesture, not an error.
  CompositionState reorderAttachment(int oldIndex, int newIndex) {
    final list = [...attachments];
    if (oldIndex < 0 || oldIndex >= list.length) return this;
    var target = newIndex;
    // A drag downward reports the index BEFORE removal, which is the classic
    // off-by-one in every reorderable list.
    if (target > oldIndex) target -= 1;
    if (target < 0) target = 0;
    if (target > list.length - 1) target = list.length - 1;
    if (target == oldIndex) return this;
    final moved = list.removeAt(oldIndex);
    list.insert(target, moved);
    return copyWith(attachments: list);
  }

  /// REMOVE — and the removal must stick.
  ///
  /// An upload already in flight for this item may still complete afterwards.
  /// The id is recorded as cancelled so a late success cannot resurrect media
  /// the author has already taken out of the composition: [holdsClaim] is
  /// false for a cancelled id, so it can never re-enter `composableAttachments`
  /// however the upload finishes.
  CompositionState removeAttachment(String localId) {
    if (!attachments.any((a) => a.localId == localId)) return this;
    return copyWith(
      attachments:
          attachments.where((a) => a.localId != localId).toList(growable: false),
      cancelled: {...cancelled, localId},
    );
  }

  /// Whether [localId] has been withdrawn and must not be re-admitted.
  ///
  /// Read by upload completion handlers before writing a result back, which is
  /// the one place a stale success could otherwise undo a removal.
  bool isWithdrawn(String localId) =>
      cancelled.contains(localId) ||
      !attachments.any((a) => a.localId == localId);

  /// Media is held that retention authority cannot see. Recorded rather than
  /// silently tolerated — see the CO-RC-C5-007 note at the top of this file.
  bool get hasUnprotectedRecoverableMedia =>
      draftClaim == DraftClaim.clientOnly &&
      liveAttachments.any((a) => (a.mediaId ?? '').trim().isNotEmpty);
}

/// When a draft should be written.
///
/// Separated from the state so a surface can schedule with its own timer while
/// the DECISION stays canonical. The article editor's 2-second debounce is the
/// established product behaviour and is preserved as the default rather than
/// re-litigated here.
class AutosavePolicy {
  const AutosavePolicy({this.debounce = const Duration(seconds: 2)});

  final Duration debounce;

  /// Autosave is for recovering work, not for mirroring keystrokes. A
  /// composition that is submitting must not be written underneath itself, and
  /// a clean composition has nothing to write.
  bool shouldSave(CompositionState state) {
    if (state.isSubmitting) return false;
    if (!state.isDirty) return false;
    return true;
  }
}
