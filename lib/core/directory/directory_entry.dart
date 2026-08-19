/// Canonical member/person identity resolution -- Identity Foundation
/// Phase 1's shared identity resolution repair.
///
/// Extracted from `new_conversation_screen.dart`'s formerly-private
/// `_DirectoryEntry`/`_memberEntryFromMap`/`_dedupeEntries` so every member
/// picker surface (personal Thread/Space creation, institution-space
/// creation, and any future one) resolves a raw API payload into the same
/// canonical shape through the same function, instead of each surface
/// re-implementing its own field-precedence logic and risking the same
/// class of divergence bug this chapter fixed once already.
library;

import '../identity/person_identity_model.dart';

/// A resolved, canonical member/person entry for selection surfaces.
///
/// `id` is always derived from [userId] (never an independent, differently
/// -ordered fallback) -- selection state keyed by `id` and a submitted
/// participant list built from `userId` are therefore always the same
/// value by construction. See [memberEntryFromMap] for the resolution rule
/// this invariant depends on.
class DirectoryEntry {
  const DirectoryEntry({
    required this.id,
    required this.userId,
    required this.handle,
    required this.displayName,
    required this.subtitle,
    required this.avatarUrl,
    required this.profileRoute,
  });

  const DirectoryEntry.empty()
    : id = '',
      userId = '',
      handle = '',
      displayName = '',
      subtitle = '',
      avatarUrl = '',
      profileRoute = null;

  final String id;
  final String userId;
  final String handle;
  final String displayName;
  final String subtitle;
  final String avatarUrl;
  final String? profileRoute;
}

String normalizeDirectoryHandle(String? handle) {
  final value = (handle ?? '').trim().toLowerCase();
  if (value.startsWith('@')) return value.substring(1);
  return value;
}

/// Resolves a raw API payload (a search result, a relationship listing
/// entry, an institution roster row, ...) into a canonical [DirectoryEntry].
///
/// `userId` is resolved once, from a single precedence order
/// (`['userId','id','_id']`), and `id` is derived from it -- never resolved
/// independently. This is the fix for the divergence bug: previously `id`
/// and `userId` were each picked via their own, differently-ordered
/// fallback chain, so a payload where a wrapper/relationship-row id
/// differed from the actual user id could produce two different `id`
/// values for the same real person depending on which listing produced
/// the entry.
DirectoryEntry? memberEntryFromMap(Map<String, dynamic> map) {
  // F053/F116 — this function was written to stop member pickers each
  // re-implementing field precedence, and it succeeded at that. What it could
  // not do was agree with the REST of the product: it kept its own alias list
  // (`avatar`, `image`, but never `photoUrl`), its own invented label
  // ('Member'), and its own address for a person ('/$handle', which the router
  // does not declare — only '/u/:handle' exists, so "open profile" from a
  // member picker resolved to nothing). One shared reader for four surfaces is
  // still a second person authority. The person is now read canonically; what
  // stays here is the DIRECTORY's own business — the stable selection key, the
  // subtitle line, and the de-duplication invariant.
  // Payload hygiene, not an identity decision: directory listings have
  // historically carried a rendered handle ('@carol'). The backend performs
  // the same strip on the way IN (users.service, invites, follows), so the
  // map is made well-formed first and the canonical reader then decides
  // everything that is actually about identity.
  final person = _bareHandle(AuraPersonIdentity.fromJson(map));
  if (person.isEmpty) return null;

  final userId = person.userId;
  final handle = person.handle;
  final displayName = person.label;
  final avatarUrl = person.avatarUrl ?? '';

  final subtitle = handle.isNotEmpty
      ? '@${handle.replaceFirst('@', '')}'
      : 'Member';
  final profileRoute = person.profileRoute;

  final stableId = userId.isNotEmpty
      ? userId
      : handle.isNotEmpty
      ? handle
      : displayName;

  if (stableId.trim().isEmpty) return null;

  return DirectoryEntry(
    id: stableId,
    userId: userId,
    handle: handle,
    displayName: displayName,
    subtitle: subtitle,
    avatarUrl: avatarUrl,
    profileRoute: profileRoute,
  );
}

/// De-duplicates a combined entry list by canonical userId (falling back to
/// a normalized handle when userId is unavailable) -- the same person
/// surfaced through two different listings collapses to one entry.
List<DirectoryEntry> dedupeDirectoryEntries(List<DirectoryEntry> entries) {
  final seen = <String>{};
  final out = <DirectoryEntry>[];
  for (final entry in entries) {
    final key = entry.userId.trim().isNotEmpty
        ? 'user:${entry.userId.trim()}'
        : 'handle:${normalizeDirectoryHandle(entry.handle)}';
    if (seen.add(key)) {
      out.add(entry);
    }
  }
  return out;
}

/// Payload hygiene applied AFTER the canonical read, never instead of it:
/// directory listings have historically carried a rendered handle ('@carol'),
/// and the backend performs the same strip on the way IN (users.service,
/// invites, follows). One field is normalised; nothing about who the person is
/// is re-decided here.
AuraPersonIdentity _bareHandle(AuraPersonIdentity person) {
  final handle = person.handle.trim();
  if (!handle.startsWith('@')) return person;
  return AuraPersonIdentity(
    userId: person.userId,
    displayName: person.displayName,
    handle: handle.substring(1),
    avatarUrl: person.avatarUrl,
    accountStatus: person.accountStatus,
  );
}
