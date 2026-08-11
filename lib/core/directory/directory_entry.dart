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

String pickDirectoryString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    final s = (value ?? '').toString().trim();
    if (s.isNotEmpty) return s;
  }
  return '';
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
  final userId = pickDirectoryString(map, const ['userId', 'id', '_id']);
  final handle = pickDirectoryString(map, const ['handle', 'username']);
  final name = pickDirectoryString(map, const [
    'displayName',
    'name',
    'fullName',
  ]);
  final avatarUrl = pickDirectoryString(map, const [
    'avatarUrl',
    'avatar',
    'image',
  ]);

  final displayName = name.isNotEmpty
      ? name
      : (handle.isNotEmpty ? handle.replaceFirst('@', '') : 'Member');

  final subtitle = handle.isNotEmpty
      ? '@${handle.replaceFirst('@', '')}'
      : 'Member';
  final profileRoute = handle.isNotEmpty ? '/$handle' : null;

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
