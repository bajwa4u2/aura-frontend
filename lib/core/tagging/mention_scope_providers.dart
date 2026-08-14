/// AXR-1 — Universal Governed Tagging: bounded [MentionScope] resolution.
///
/// Derives Thread/Space/DM mention candidate sets from data these surfaces
/// already fetch through their own existing, authorization-checked
/// endpoints (`GET /threads/:id`, `GET /spaces/:id`,
/// `GET /institutions/:id/spaces/:id`, the DM's own already-loaded
/// participant pair) — deliberately not a new backend endpoint, and
/// deliberately not a client-side filter over the global `/search` result.
/// The eligibility rule mirrors aura-backend's `messages.service.ts` /
/// `direct-threads.service.ts` write-boundary checks exactly:
///  * private Thread person-eligibility = the Thread's own membership;
///  * non-private (Space-owned) Thread person-eligibility = the parent
///    Space's active membership;
///  * institution-eligibility (either case) = the parent Space's owning
///    `institutionId` only — a Personal Space has none;
///  * DM person-eligibility = the DM's own two participants;
///  * DM institution-eligibility = a participant that IS that institution.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interactions/actor_context.dart';
import '../interactions/direct_threads_repository.dart';
import '../../features/correspondence/data/correspondence_identity.dart';
import '../../features/correspondence/data/spaces_repository.dart';
import '../../features/correspondence/data/threads_repository.dart';
import '../../features/institutions/data/institutions_repository.dart';
import 'mention_scope.dart';
import 'tag_entities.dart';

List<TagSuggestion> _suggestionsFromMemberRows(dynamic rows) {
  if (rows is! List) return const [];
  final out = <TagSuggestion>[];
  for (final raw in rows) {
    if (raw is! Map) continue;
    final row = Map<String, dynamic>.from(raw);
    final userMap = row['user'] is Map
        ? Map<String, dynamic>.from(row['user'] as Map)
        : row;
    final userId = CorrespondenceIdentity.pickString(row, const [
      'userId',
      'id',
    ]);
    if (userId.isEmpty) continue;
    final handle = CorrespondenceIdentity.pickString(userMap, const [
      'handle',
      'username',
    ]);
    final name = CorrespondenceIdentity.pickString(userMap, const [
      'displayName',
      'name',
      'fullName',
    ]);
    final display = name.isNotEmpty
        ? name
        : (handle.isNotEmpty ? handle : 'Member');
    final avatarUrl = CorrespondenceIdentity.pickString(userMap, const [
      'avatarUrl',
      'avatar',
      'image',
    ]);
    out.add(
      TagSuggestion(
        kind: TagKind.member,
        canonicalId: userId,
        display: display,
        insertText: '@$display',
        subtitle: handle.isNotEmpty ? '@$handle' : null,
        imageUrl: avatarUrl.isEmpty ? null : avatarUrl,
      ),
    );
  }
  return out;
}

TagSuggestion? _institutionSuggestionFromMap(dynamic institution) {
  if (institution is! Map) return null;
  final map = Map<String, dynamic>.from(institution);
  final id = CorrespondenceIdentity.pickString(map, const ['id']);
  if (id.isEmpty) return null;
  final name = CorrespondenceIdentity.pickString(map, const [
    'name',
    'displayName',
  ]);
  final slug = CorrespondenceIdentity.pickString(map, const ['slug']);
  final display = name.isNotEmpty ? name : slug;
  if (display.isEmpty) return null;
  final logo = CorrespondenceIdentity.pickString(map, const [
    'logoUrl',
    'logo',
  ]);
  return TagSuggestion(
    kind: TagKind.institution,
    canonicalId: id,
    display: display,
    insertText: '@$display',
    subtitle: slug.isNotEmpty ? '@$slug · Institution' : 'Institution',
    imageUrl: logo.isEmpty ? null : logo,
  );
}

/// Thread/Space mention scope. `threadId` is enough — the Thread's own
/// `spaceId` and the parent Space's `institutionId` come from the Thread
/// payload itself, so callers never need to thread Space/institution
/// context through the composer widgets by hand.
final threadMentionScopeProvider = FutureProvider.family<MentionScope, String>(
  (ref, threadId) async {
    final thread = await ref.watch(threadsRepositoryProvider).getThread(threadId);

    final isPrivate = thread['isPrivate'] == true;
    final spaceId = CorrespondenceIdentity.pickString(thread, const [
      'spaceId',
      'space_id',
    ]);
    final threadSpace = thread['space'];
    final ownerInstitutionId = threadSpace is Map
        ? CorrespondenceIdentity.pickString(
            Map<String, dynamic>.from(threadSpace),
            const ['institutionId'],
          )
        : '';

    List<TagSuggestion> personCandidates;
    TagSuggestion? institutionCandidate;

    if (spaceId.isEmpty) {
      // Defensive: no parent Space resolvable at all — fall back to the
      // Thread's own membership, its only available authority.
      personCandidates = _suggestionsFromMemberRows(thread['members']);
    } else if (ownerInstitutionId.isNotEmpty) {
      final spaceDetail = await ref
          .watch(institutionsRepositoryProvider)
          .getInstitutionSpace(ownerInstitutionId, spaceId);
      institutionCandidate = _institutionSuggestionFromMap(
        spaceDetail['institution'],
      );
      // A private Thread's own membership stays authoritative even inside
      // an Institution Space — mirrors messages.service.ts exactly.
      personCandidates = isPrivate
          ? _suggestionsFromMemberRows(thread['members'])
          : _suggestionsFromMemberRows(spaceDetail['members']);
    } else if (isPrivate) {
      // Private Thread in a Personal Space: its own ThreadMember list is
      // already complete and authoritative — no extra fetch needed.
      personCandidates = _suggestionsFromMemberRows(thread['members']);
    } else {
      final spaceDetail = await ref
          .watch(spacesRepositoryProvider)
          .getSpace(spaceId);
      personCandidates = _suggestionsFromMemberRows(spaceDetail['members']);
    }

    return MentionScope.bounded([
      ...personCandidates,
      if (institutionCandidate != null) institutionCandidate,
    ]);
  },
);

/// DM mention scope — pure, synchronous: `DirectThreadInfo` is already
/// fully loaded by the screen for its own header/identity rendering, so
/// no extra fetch is needed here. Candidates = the DM's own other
/// participant only (whichever of person/institution it actually is) —
/// deliberately a subset of what the backend allows (which also permits
/// self-mention), never a superset, so this can never offer a target the
/// backend would reject.
MentionScope directThreadMentionScope(
  DirectThreadInfo info,
  ActorContext actor,
) {
  final candidates = [info.participantA, info.participantB];
  for (final p in candidates) {
    if (actor.isInstitution &&
        p.type == ActorType.institution &&
        p.institutionId == actor.institutionId) {
      continue;
    }
    if (actor.isUser && p.type == ActorType.user && p.userId == actor.userId) {
      continue;
    }
    if (p.type == ActorType.institution && (p.institutionId ?? '').isNotEmpty) {
      // The institution's canonical id comes from the participant struct
      // itself (always present), never from the embedded display map
      // (which may omit 'id' — it's presentation data, not identity).
      final inst = p.institution;
      final name = (inst?['name'] ?? inst?['displayName'] ?? '').toString().trim();
      final slug = (inst?['slug'] ?? '').toString().trim();
      final logo = (inst?['logoUrl'] ?? inst?['logo'] ?? '').toString().trim();
      final display = name.isNotEmpty ? name : (slug.isNotEmpty ? slug : 'Institution');
      return MentionScope.bounded([
        TagSuggestion(
          kind: TagKind.institution,
          canonicalId: p.institutionId!,
          display: display,
          insertText: '@$display',
          subtitle: slug.isNotEmpty ? '@$slug · Institution' : 'Institution',
          imageUrl: logo.isEmpty ? null : logo,
        ),
      ]);
    }
    if (p.type == ActorType.user && (p.userId ?? '').isNotEmpty) {
      final user = p.user;
      final display = (user?['displayName'] ?? user?['name'] ?? '')
          .toString()
          .trim();
      final handle = (user?['handle'] ?? '').toString().trim();
      final avatarUrl = (user?['avatarUrl'] ?? '').toString().trim();
      final resolvedDisplay = display.isNotEmpty
          ? display
          : (handle.isNotEmpty ? handle : 'Member');
      return MentionScope.bounded([
        TagSuggestion(
          kind: TagKind.member,
          canonicalId: p.userId!,
          display: resolvedDisplay,
          insertText: '@$resolvedDisplay',
          subtitle: handle.isNotEmpty ? '@$handle' : null,
          imageUrl: avatarUrl.isEmpty ? null : avatarUrl,
        ),
      ]);
    }
  }
  return const MentionScope.bounded([]);
}
