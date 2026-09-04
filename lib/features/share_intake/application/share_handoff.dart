import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/authority/acting_context.dart';
import '../../../core/media/attachment.dart';
import '../domain/share_destination.dart';

/// WHAT A CONFIRMED SHARE HANDS TO THE COMPOSER THAT WILL SEND IT.
///
/// Resolved content, the destination the person chose, and the identity the
/// authority resolved for that destination's act. Nothing else, and in
/// particular nothing that could send it.
class StagedShare {
  const StagedShare({
    required this.destination,
    required this.actingIdentity,
    required this.attachments,
    required this.body,
  });

  final ShareDestination destination;
  final ActingOption actingIdentity;

  /// Already through `ContentIntake`. Every item here has had its bytes read
  /// and its class decided; none of them is still a claim.
  final List<Attachment> attachments;

  final String body;
}

/// THE REASON SHARE INTAKE CANNOT PUBLISH ANYTHING.
///
/// A confirmed share does not become a message or a post here. It is staged,
/// and the destination's ORDINARY composer picks it up — the same composer the
/// person would have used had they started inside Aura, with the same send
/// button, the same authority checks and the same server calls.
///
/// That is a deliberate structural choice rather than a convenience. A share
/// path that published on its own would be a second publishing implementation:
/// a second place to enforce capability, a second place to attach media, a
/// second place for the two to drift. The share sheet earns no shortcut past
/// the composer, so `OS_SHARE_DIRECT_PUBLISH = 0` holds because this feature
/// contains nothing that can publish — not because a rule says it must not.
///
/// It also means the person gets one more look. Content arriving from another
/// app lands in the composer they know, and sending is still their act.
class ShareHandoff extends StateNotifier<StagedShare?> {
  ShareHandoff() : super(null);

  void stage(StagedShare staged) => state = staged;

  /// Claim a staged share for a conversation. Returns null when the staged
  /// share was meant for somewhere else, so opening an unrelated conversation
  /// can never pick up someone's pending content.
  StagedShare? takeForConversation(String conversationId) {
    final staged = state;
    if (staged == null) return null;
    if (staged.destination.kind != ShareDestinationKind.conversation) {
      return null;
    }
    if (staged.destination.id != conversationId) return null;
    state = null;
    return staged;
  }

  /// Claim a staged share for the public post composer.
  StagedShare? takeForPublicPost() {
    final staged = state;
    if (staged == null) return null;
    if (staged.destination.kind != ShareDestinationKind.publicPost) return null;
    state = null;
    return staged;
  }

  void clear() => state = null;
}

final shareHandoffProvider =
    StateNotifierProvider<ShareHandoff, StagedShare?>((ref) => ShareHandoff());
