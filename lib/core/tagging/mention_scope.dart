/// AXR-1 — Universal Governed Tagging: mention target eligibility scope.
///
/// GLOBAL IDENTITY DISCOVERABILITY != CONTEXTUAL MENTION ELIGIBILITY. Posts,
/// Institution Posts, Announcements, and their replies keep the existing
/// global, `/search`-backed candidate pool — their mention validity is
/// legitimately unbounded, unchanged by this file. Threads, Spaces, and DMs
/// are bounded communication surfaces: the set of entities that may ever be
/// meaningfully addressed there is small and already known to the caller
/// (Thread/Space membership, a DM's own participants). [MentionScope.bounded]
/// carries that already-resolved, already-eligible candidate set so the
/// composer never *offers* a target the backend's `assertMentionTargetsEligible`
/// (aura-backend `src/common/tags/mention-target-eligibility.ts`) would
/// reject — filtered locally against a governed set, never against the raw
/// global `/search` result, and never a second network-backed ranking
/// authority. This mirrors the backend's own authority split: identity
/// discoverability, contextual eligibility, and attention-recipient
/// resolution stay three separate concerns, never collapsed into one.
library;

import 'tag_entities.dart';

abstract class MentionScope {
  const MentionScope();
  const factory MentionScope.global() = MentionScopeGlobal;
  const factory MentionScope.bounded(List<TagSuggestion> eligible) =
      MentionScopeBounded;
}

/// Default. Delegates to [TagSuggestService]'s live `/search`-backed
/// ranking, exactly as before this file existed.
class MentionScopeGlobal extends MentionScope {
  const MentionScopeGlobal();
}

/// The caller already knows its full, small, contextually-eligible
/// candidate set. Filtered locally by substring match — no network call,
/// matching the existing `MemberPickerField` local-filter precedent.
class MentionScopeBounded extends MentionScope {
  const MentionScopeBounded(this.eligible);
  final List<TagSuggestion> eligible;
}
