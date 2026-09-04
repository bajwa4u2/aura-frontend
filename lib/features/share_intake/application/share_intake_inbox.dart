import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/acquisition_envelope.dart';

/// THE ONE DOOR EVERY OPERATING SYSTEM DELIVERS A SHARE INTO.
///
/// Android's `ACTION_SEND`, an iOS Share Extension handoff and a Windows share
/// target are three different mechanisms and one destination: [deliver]. Each
/// platform adapter's whole job is to turn what it received into an
/// [AcquisitionEnvelope] and hand it over. Nothing downstream of here knows or
/// asks which platform it came from.
///
/// THIS IS THE INVARIANT `PAGE_SPECIFIC_SHARE_PIPELINES = 0` LIVES ON. The
/// moment a platform is awkward, the tempting fix is a second path "just for
/// that one" — an Android branch that opens the conversation directly, an iOS
/// route that skips the preview. Each such path is a place the destination and
/// identity rules would have to be re-implemented, and therefore a place they
/// could differ. One door means one set of rules.
///
/// A DELIVERED ENVELOPE IS NOT A PUBLISHED ONE. Delivery puts the content in
/// front of a person. Everything after that — where it goes, who it goes as,
/// whether it goes — is theirs.
class ShareIntakeInbox extends StateNotifier<AcquisitionEnvelope?> {
  ShareIntakeInbox() : super(null);

  /// Hand over what the operating system supplied.
  ///
  /// An empty share is dropped rather than presented: opening Aura onto a
  /// composer with nothing in it, because some app shared a payload it could
  /// not produce, would be worse than the share appearing not to have
  /// happened.
  void deliver(AcquisitionEnvelope envelope) {
    if (envelope.isEmpty) return;
    state = envelope;
  }

  /// Consume the pending share exactly once.
  ///
  /// Read-and-clear rather than read-then-clear-later, so a share cannot be
  /// presented twice — which on this surface would mean a person publishing
  /// the same thing twice without having asked to.
  AcquisitionEnvelope? take() {
    final pending = state;
    state = null;
    return pending;
  }

  /// Abandon a share without acting on it. Backing out is an answer.
  void discard() => state = null;
}

/// Deliberately NOT auto-disposed. A share can arrive while Aura is cold, and
/// the envelope has to survive from the platform channel through app start,
/// through sign-in if the person is not signed in, and up to the moment the
/// destination surface reads it.
final shareIntakeInboxProvider =
    StateNotifierProvider<ShareIntakeInbox, AcquisitionEnvelope?>(
  (ref) => ShareIntakeInbox(),
);

/// Whether something is waiting. Used to route, never to publish.
final hasPendingShareProvider = Provider<bool>(
  (ref) => ref.watch(shareIntakeInboxProvider) != null,
);
