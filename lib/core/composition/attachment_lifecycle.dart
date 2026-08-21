// CH-13 · CO-RC-C5-011 — ATTACHMENT LIFECYCLE.
//
// §12's frozen lifecycle for an attachment is:
//
//   SELECT/PASTE/DROP → VALIDATE → PREVIEW → UPLOAD → PROGRESS → READY → SEND
//
// Aura already had a shared attachment SHAPE — `Attachment` in
// lib/core/media/attachment.dart, which replaced three private models. What it
// does not have is a shared MEANING. The shape carries `uploading`,
// `uploadProgress`, `error` and `attachedToDraft` as independent mutable flags,
// and every composer decides for itself what a combination of them means. Two
// surfaces reading the same object can disagree about whether it may be sent,
// and both can be locally correct.
//
// That is exactly the failure §12 named: *"shared shape, divergent meaning"*
// recreating today's fragmentation one level up. So the answer here is NOT
// another flag. It is to stop storing the phase at all and DERIVE it from the
// facts the object already carries, so the phase cannot drift from the data and
// no surface can invent a fourth reading.
//
// The lifecycle is deliberately a pure function over a value. It has no Flutter
// dependency, no I/O and no provider, so it can be proven exhaustively in tests
// rather than observed in a running composer.

import '../media/attachment.dart';
import '../media/media_capacity.dart';

/// Where an attachment actually is in the frozen lifecycle.
///
/// Ordered by progress so `index` comparisons are meaningful, and named for the
/// §12 stage rather than for the widget that happens to render it.
enum AttachmentPhase {
  /// Taken in from a picker, a paste or a drop, not yet judged.
  selected,

  /// Judged and refused. Terminal, and never silently retried — a rejection the
  /// person cannot see is indistinguishable from a bug.
  rejected,

  /// Judged acceptable and locally previewable. Nothing has left the device.
  preview,

  /// Bytes are moving. `progress` may be null when a surface cannot measure it.
  uploading,

  /// The upload failed and MAY be retried. Distinct from [rejected], which
  /// never may — conflating them is how a transient network error becomes a
  /// permanent refusal in the product.
  failed,

  /// The server has issued identity for this object. It may be composed.
  ready,

  /// Cancelled by the person. Terminal by intent, not by failure.
  cancelled,
}

/// Why an attachment was refused, in terms the product can speak.
///
/// A closed set on purpose: an open string would let each composer invent its
/// own vocabulary, which is the same fragmentation one level down.
enum AttachmentRejection {
  /// The bytes are not a type Aura accepts at all.
  unsupportedType,

  /// The declared kind and the resolved MIME disagree. Never guessed past —
  /// the D7 rule is that possession is not authority, and a caller-declared
  /// type is possession.
  kindMismatch,

  /// Nothing to attach: no file, no bytes.
  empty,

  /// Larger than the canonical ceiling for its class. Refused at the door so a
  /// person is told before a long upload is attempted and then rejected.
  tooLarge,
}

/// The lifecycle authority.
///
/// Every method is static and pure. There is no instance to hold stale state,
/// which is the point: the phase is a reading of the attachment, not a fact
/// stored beside it.
class AttachmentLifecycle {
  const AttachmentLifecycle._();

  /// THE derivation. Every surface asks this and no surface decides for itself.
  ///
  /// Order matters and is not arbitrary. Terminal states are read first so a
  /// stale `uploading` flag left behind by an aborted send cannot outrank a
  /// rejection or a cancellation the person already saw.
  static AttachmentPhase phaseOf(
    Attachment attachment, {
    AttachmentRejection? rejection,
    bool cancelled = false,
  }) {
    if (cancelled) return AttachmentPhase.cancelled;
    if (rejection != null) return AttachmentPhase.rejected;

    // Server identity is the only proof that an upload finished. `uploading`
    // going false proves the attempt STOPPED, never that it succeeded — which
    // is precisely the confusion that let a half-finished attachment look
    // sendable.
    final hasIdentity = (attachment.mediaId ?? '').trim().isNotEmpty;
    if (hasIdentity) return AttachmentPhase.ready;

    if (attachment.uploading) return AttachmentPhase.uploading;

    // An error with no identity is retryable. With identity it is noise from a
    // superseded attempt and the object is ready regardless — handled above.
    if ((attachment.error ?? '').trim().isNotEmpty) return AttachmentPhase.failed;

    final hasLocalBytes =
        attachment.file != null || (attachment.bytes?.isNotEmpty ?? false);
    if (hasLocalBytes) return AttachmentPhase.preview;

    return AttachmentPhase.selected;
  }

  /// May this attachment be part of a send or publish?
  ///
  /// ONLY from [AttachmentPhase.ready]. Not "not uploading", not "no error" —
  /// both of those are true of an attachment that was never uploaded at all.
  static bool isComposable(AttachmentPhase phase) =>
      phase == AttachmentPhase.ready;

  /// May this attachment be retried?
  ///
  /// Failure is retryable; refusal is not. A surface that offers Retry on a
  /// rejected file is promising something that cannot succeed.
  static bool isRetryable(AttachmentPhase phase) =>
      phase == AttachmentPhase.failed;

  /// Does this attachment still hold a claim on the composition?
  ///
  /// Terminal-by-refusal and terminal-by-intent attachments do not: they are
  /// shown, then dropped. Everything else is still in flight and must block
  /// readiness rather than be silently discarded.
  static bool holdsClaim(AttachmentPhase phase) =>
      phase != AttachmentPhase.rejected && phase != AttachmentPhase.cancelled;

  /// Is the composition waiting on this attachment?
  static bool isPending(AttachmentPhase phase) =>
      holdsClaim(phase) && phase != AttachmentPhase.ready;

  /// Human-facing reason, in product language rather than transport language.
  ///
  /// Deliberately vague about WHY a type is unsupported: a precise refusal is
  /// an oracle, and D7 froze that a refusal must not become one.
  /// [kind] is supplied where it is known, so a capacity refusal can name the
  /// actual ceiling. "That file is too large" without a number tells a person
  /// nothing they can act on.
  static String rejectionMessage(
    AttachmentRejection rejection, {
    AttachmentKind? kind,
  }) {
    switch (rejection) {
      case AttachmentRejection.unsupportedType:
        return 'That file type cannot be attached.';
      case AttachmentRejection.kindMismatch:
        return 'That file does not match the kind it claims to be.';
      case AttachmentRejection.empty:
        return 'That file is empty.';
      case AttachmentRejection.tooLarge:
        return kind == null
            ? 'That file is too large.'
            : 'That file is larger than the '
                '${MediaCapacity.describeLimit(kind)} limit.';
    }
  }
}
