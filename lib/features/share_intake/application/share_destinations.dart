import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/identity/person_identity_model.dart';
import '../../conversation/data/conversations_repository.dart';
import '../../conversation/presentation/conversation_identity.dart';
import '../domain/share_destination.dart';

/// EVERY PLACE THIS PERSON MAY SEND A SHARE, RESOLVED NOW.
///
/// Built from what the person demonstrably has at this moment: the
/// conversations the Conversation authority returns for them, plus the public
/// post anyone signed in may write. Nothing is carried over from a previous
/// share.
///
/// WHY THERE IS NO "RECENT" SECTION, AND WHY THERE MUST NOT BE. Every other
/// share sheet in the industry puts the last few destinations at the top, and
/// it is the single most convincing feature to add here. It is also the exact
/// mechanism by which a photograph intended for one person is sent to a
/// different one: the target of a share is decided by the person's fingers
/// hitting a familiar position, not by them reading a name. Aura shows the
/// destinations in the ledger's own order and makes the person pick one.
///
/// This is `LAST_USED_DESTINATION_INFERENCE = 0` — enforceable because it is
/// the absence of code in one file rather than a rule 40 surfaces must keep.
final shareDestinationsProvider =
    FutureProvider.autoDispose<List<ShareDestination>>((ref) async {
  if (ref.watch(authStatusProvider) != AuthStatus.authed) {
    return const <ShareDestination>[];
  }

  // The canonical person model, not a hand-unpacked payload. F053/F116 record
  // what happens when a surface re-derives identity its own way: a slightly
  // different shape produces no identity at all, silently.
  final myUserId =
      AuraPersonIdentity.fromJson(ref.watch(authMeDataProvider).valueOrNull)
          .userId;

  final conversations = await ref.watch(conversationsListProvider.future);
  final postInProgress = await ref.watch(_postInProgressProvider.future);

  return <ShareDestination>[
    // The public option is stated FIRST and never pre-selected. Putting it at
    // the end, below a familiar list, is how a public post gets chosen by
    // someone who meant to send a message — it should be the option a person
    // reads deliberately, not the one they scroll past.
    ShareDestination(
      kind: ShareDestinationKind.publicPost,
      id: '',
      title: 'Publish publicly',
      subtitle: 'Anyone can read this.',
      // THE ONE DESTINATION THAT CAN COST SOMETHING TO OFFER.
      //
      // A person holds exactly ONE post draft — `PUT /posts/draft` upserts it
      // — so seeding the public composer from a share would replace whatever
      // they had written and not yet published. Losing someone's unfinished
      // writing to a photograph they shared from another app is not a
      // trade Aura gets to make silently, so the option is shown with the
      // reason instead of quietly overwriting.
      available: !postInProgress,
      unavailableReason: postInProgress
          ? 'You have a post in progress. Finish or discard it first.'
          : null,
    ),
    for (final conversation in conversations)
      // Archived conversations are deliberately absent. Archiving is a person
      // saying they are done with a conversation, and a share sheet is not a
      // reason to reopen it behind their back.
      if (!conversation.archived)
        ShareDestination(
          kind: ShareDestinationKind.conversation,
          id: conversation.id,
          title: conversationDisplayName(conversation, myUserId),
          subtitle: _context(conversation),
        ),
  ];

  // MEMBER SPACES ARE NOT LISTED SEPARATELY, AND THAT IS NOT AN OMISSION.
  // The 2026-08-23 convergence moved member Spaces onto Conversation, so they
  // already appear above. Adding a second Space section would offer the same
  // place twice under two names, which is precisely the mis-send this surface
  // exists to prevent. `ShareDestinationKind.space` remains for institution
  // Spaces, which an institution-account session reaches through its own
  // ledger.
});

/// Whether the person has unpublished writing in the post composer.
///
/// A FAILED CHECK ANSWERS "NO". Removing a legitimate destination because a
/// network call did not come back would make an ordinary offline moment look
/// like a permission the person does not have.
final _postInProgressProvider = FutureProvider.autoDispose<bool>((ref) async {
  try {
    final res = await ref.watch(dioProvider).get<dynamic>('/posts/draft');
    final root = res.data is Map
        ? Map<String, dynamic>.from(res.data as Map)
        : const <String, dynamic>{};
    final source = root['item'] ?? root['draft'] ?? root['data'] ?? root;
    if (source is! Map) return false;
    final draft = Map<String, dynamic>.from(source);
    final text = (draft['text'] ?? '').toString().trim();
    final media = draft['media'];
    return text.isNotEmpty || (media is List && media.isNotEmpty);
  } catch (_) {
    return false;
  }
});

/// What kind of place this is, when the name alone does not say. Silent for an
/// ordinary person-to-person conversation, where "conversation" is noise.
String? _context(Conversation conversation) {
  if (conversation.parties.any((p) => !p.isPerson && p.isActive)) {
    return 'Institution';
  }
  if (!conversation.isDirect && conversation.parties.length > 2) {
    return '${conversation.parties.length} people';
  }
  return null;
}
