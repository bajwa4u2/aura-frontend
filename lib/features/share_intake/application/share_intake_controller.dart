import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../../core/authority/acting_context.dart';
import '../../../core/composition/content_intake.dart';
import '../../../core/media/attachment.dart';
import '../domain/acquisition_envelope.dart';
import '../domain/share_destination.dart';

/// THE ONE PLACE AN OPERATING-SYSTEM SHARE BECOMES AURA CONTENT.
///
/// An OS share arrives with no destination, no acting identity, and a claim
/// about its own type that nothing has checked. Three frozen rules bear on
/// exactly that moment, and this is where all three are applied:
///
///  * **Nothing is published by arriving.** A share is an ACQUISITION. The
///    consequence happens later, on an explicit act, with the content on
///    screen. [readyToConfirm] is the only path to one and it requires a
///    destination, an identity and a preview the person has seen.
///  * **Acting identity is per-act** (C1) and is never derived from the route,
///    the platform, or what was used last.
///  * **Type is decided by the bytes** — `ContentIntake` — because the sharing
///    application's declaration is a hint and this door is the one where a
///    wrong hint is most likely.
///
/// WHAT IS NOT HERE, AND MUST NOT BE. There is no "recent destination", no
/// "last identity", and no per-platform branch. Android, iOS and Windows differ
/// in how a share is delivered and in nothing after the envelope is built —
/// which is what stops a page-specific share pipeline from appearing the first
/// time a platform is awkward.
class ShareIntakeController extends ChangeNotifier {
  ShareIntakeController(this.envelope);

  final AcquisitionEnvelope envelope;

  final List<Attachment> _attachments = <Attachment>[];
  final List<String> _refusals = <String>[];

  String _body = '';
  bool _resolving = false;
  bool _resolved = false;

  ShareDestination? _destination;
  ActingOption? _identity;
  bool _previewSeen = false;

  /// Content that passed the door, ready to compose with.
  List<Attachment> get attachments => List.unmodifiable(_attachments);

  /// Content that did not, each with the reason in the product's own words.
  /// Surfaced rather than dropped: a file that vanishes between the share
  /// sheet and the composer looks like Aura lost it.
  List<String> get refusals => List.unmodifiable(_refusals);

  /// The text the share carried, offered as a starting point and fully
  /// editable. A subject line is a suggestion, never a caption someone did not
  /// write.
  String get body => _body;

  bool get isResolving => _resolving;
  bool get isResolved => _resolved;

  ShareDestination? get destination => _destination;

  /// Resolved by `ActingContextAuthority` for [ShareDestination.act], set by
  /// the surface. RESOLVED IS NOT INFERRED: the authority answers from the
  /// person's standing right now, and where more than one identity is
  /// legitimate the surface must make the person choose before this is set.
  ActingOption? get actingIdentity => _identity;

  /// True once the person has actually looked at what they are about to send.
  /// Set by the surface when the preview is on screen, never inferred.
  bool get previewSeen => _previewSeen;

  bool get hasContent => _attachments.isNotEmpty || _body.trim().isNotEmpty;

  /// EVERY CONDITION FOR A CONSEQUENCE, IN ONE PLACE.
  ///
  /// Deliberately conjunctive and deliberately explicit. Each clause is a thing
  /// a person did, not a thing the system decided on their behalf.
  bool get readyToConfirm =>
      _resolved &&
      hasContent &&
      _destination != null &&
      _destination!.available &&
      _identity != null &&
      _previewSeen;

  /// Why not, in words. Null when [readyToConfirm]. Every gate speaks.
  String? get blockedReason {
    if (_resolving) return 'Reading what was shared…';
    if (!_resolved) return 'Nothing has been read yet.';
    if (!hasContent) {
      return _refusals.isEmpty
          ? 'Nothing came through that Aura can accept.'
          : 'Nothing usable came through. ${_refusals.first}';
    }
    if (_destination == null) return 'Choose where this goes.';
    if (!_destination!.available) {
      return _destination!.unavailableReason ??
          'You cannot publish into that destination.';
    }
    if (_identity == null) return 'Choose who this is published as.';
    if (!_previewSeen) return 'Check what you are about to send.';
    return null;
  }

  /// Read everything the OS handed over, deciding each item by its bytes.
  ///
  /// Never throws: a share that cannot be read must produce a refusal a person
  /// can see, not an error screen behind the share sheet.
  Future<void> resolve() async {
    if (_resolving || _resolved) return;
    _resolving = true;
    notifyListeners();

    // Refusals the platform adapter already made, before Aura saw the content.
    // Adopted first so they appear alongside intake's own in the order things
    // actually happened.
    _refusals.addAll(envelope.refusals);

    final textParts = <String>[];

    for (final payload in envelope.payloads) {
      if (payload.isTextual) {
        final text = (payload.text ?? '').trim();
        if (text.isNotEmpty) textParts.add(text);
        continue;
      }

      final bytes = await _bytesOf(payload);
      if (bytes == null || bytes.isEmpty) {
        _refusals.add('One item arrived empty and was not kept.');
        continue;
      }

      try {
        final resolution = await ContentIntake.resolveAndPrepareBytes(
          // The share door, named honestly. It resolves exactly like every
          // other door — by reading the bytes — and says where it came from.
          path: IntakePath.share,
          bytes: bytes,
          fileName: payload.fileName,
          // A HINT. `ContentIntake` prefers what it sniffs and falls back to
          // this only when the bytes are silent.
          declaredMimeType: payload.declaredMimeType,
          source: AttachmentSource.upload,
        );
        if (resolution.isAccepted) {
          _attachments.add(resolution.attachment!);
        } else {
          _refusals.add(
            resolution.rejectionMessage ?? 'One item could not be accepted.',
          );
        }
      } catch (_) {
        _refusals.add('One item could not be read.');
      }
    }

    // The subject goes last and only when the share carried no text of its
    // own, so a platform's title never displaces what the person actually
    // shared.
    if (textParts.isEmpty) {
      final subject = (envelope.subject ?? '').trim();
      if (subject.isNotEmpty) textParts.add(subject);
    }

    _body = textParts.join('\n\n');
    _resolving = false;
    _resolved = true;
    notifyListeners();
  }

  /// The content itself, however the adapter chose to hand it over.
  ///
  /// A path is read HERE rather than in the adapter because a hundred-megabyte
  /// video should cross into Dart once, when it is actually being judged — not
  /// be held in memory from the moment the share sheet closed.
  Future<Uint8List?> _bytesOf(AcquiredPayload payload) async {
    if (payload.bytes != null) return payload.bytes;
    final path = payload.filePath;
    if (path == null || path.isEmpty) return null;
    try {
      return await XFile(path).readAsBytes();
    } catch (_) {
      return null;
    }
  }

  void editBody(String value) {
    _body = value;
    notifyListeners();
  }

  /// Choosing a destination clears any identity already chosen.
  ///
  /// Not tidiness — correctness. "As whom" is only meaningful against a
  /// "where", and carrying an institutional identity from a Space over to a
  /// public post is precisely the mis-share this surface exists to prevent.
  void chooseDestination(ShareDestination value) {
    _destination = value;
    _identity = null;
    _previewSeen = false;
    notifyListeners();
  }

  void chooseIdentity(ActingOption value) {
    _identity = value;
    _previewSeen = false;
    notifyListeners();
  }

  /// Called by the surface when the preview is actually on screen.
  void markPreviewSeen() {
    if (_previewSeen) return;
    _previewSeen = true;
    notifyListeners();
  }

  void removeAttachment(String localId) {
    _attachments.removeWhere((a) => a.localId == localId);
    _previewSeen = false;
    notifyListeners();
  }
}
