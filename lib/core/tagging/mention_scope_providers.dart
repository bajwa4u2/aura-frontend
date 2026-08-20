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


import '../interactions/actor_context.dart';
import '../interactions/direct_threads_repository.dart';
import 'mention_scope.dart';
import 'tag_entities.dart';
import '../identity/person_identity_model.dart';

/// Test seam for the member-row person resolution. The rule this pins — that a
/// person the canonical reader cannot name is skipped rather than offered under
/// an invented label — is identity behaviour, not widget behaviour, so it is
/// worth reaching directly.
List<TagSuggestion> memberTagSuggestionsForTest(dynamic rows) =>
    _suggestionsFromMemberRows(rows);

List<TagSuggestion> _suggestionsFromMemberRows(dynamic rows) {
  if (rows is! List) return const [];
  final out = <TagSuggestion>[];
  for (final raw in rows) {
    if (raw is! Map) continue;
    final row = Map<String, dynamic>.from(raw);
    // F053/F116 — this file is `lib/core/tagging`, and it serves a LIVE
    // surface: DirectThreadScreen at `/direct/:threadId`. It was reading its
    // person through `CorrespondenceIdentity`, which belongs to the family
    // governed for retirement under CO-RC-C7-005 — so its debt was NOT
    // retirement-owned and could not be left to be discharged by a deletion
    // that will never reach this file. The private reader here carried the
    // same two defects the member directory did: an avatar order that accepted
    // `avatar` and `image` but never `photoUrl`, and 'Member' invented as a
    // name for someone it had failed to resolve.
    final person = AuraPersonIdentity.fromJson(row);
    final userId = person.userId.isNotEmpty
        ? person.userId
        : _pick(row, const ['userId']);
    if (userId.isEmpty) continue;
    final handle = person.handle;
    // A mention must be insertable, so a person with no resolvable name is
    // skipped rather than offered as 'Member' — the neutral word is for
    // RENDERING someone, and '@Someone' is not a mention anyone can act on.
    if (person.displayName.trim().isEmpty && handle.isEmpty) continue;
    final display = person.proseName;
    final avatarUrl = person.avatarUrl ?? '';
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
      // F053/F116 — the mention scope resolves the counterpart through the
      // canonical model, so a bounded mention offers the same person the
      // thread header names. 'Member' as a stand-in for an unresolved person
      // is exactly the invented-label defect; the shared fallback replaces it.
      final person = AuraPersonIdentity.fromJson(p.user);
      final handle = person.handle;
      final avatarUrl = person.avatarUrl ?? '';
      final resolvedDisplay = person.displayName.isNotEmpty
          ? person.displayName
          : (handle.isNotEmpty ? handle : person.label);
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

/// Generic first-non-empty key read.
///
/// This file used `CorrespondenceIdentity.pickString` for it. The helper is not
/// identity — the PERSON read above delegates to `AuraPersonIdentity`, and what
/// remains here reads institution ids, slugs, logos and space ids. Keeping the
/// import would have tied `lib/core/tagging`, which serves the LIVE
/// DirectThreadScreen at `/direct/:threadId`, to a class the C7 retirement
/// deletes. Depending on retiring code is not the same as being retired by it,
/// so the four-line utility is local now and the coupling is gone.
String _pick(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}
