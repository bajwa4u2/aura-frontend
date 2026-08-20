/// WHAT AN INSTITUTION SPACE LENDS TO ITS CONVERSATION.
///
/// RC-C7 reconstruction, founder rulings D1/D2 (2026-08-20).
///
///     SPACE         governs — membership, access, institution ownership,
///                   identity, purpose, lifecycle.
///     CONVERSATION  communicates — timeline, composer, rich content,
///                   per-human read state.
///
/// A Space does NOT get its own messaging runtime. It reuses the canonical
/// `ConversationScreen` and hands it this small amount of context so the
/// surface can name itself as the Space rather than as an unnamed group, and
/// so its back button and member management lead where a Space's should.
///
/// Deliberately tiny. Everything richer than a title, a purpose line and two
/// callbacks belongs to one of the two owners above — the moment this grows a
/// message, an attachment or an identity field, a second messages runtime has
/// started forming and the reconstruction has failed.
class InstitutionSpaceContext {
  const InstitutionSpaceContext({
    required this.institutionId,
    required this.spaceId,
    required this.title,
    this.purpose,
    this.memberCount,
    this.canGovern = false,
    this.onOpenMembers,
    this.onBack,
  });

  final String institutionId;
  final String spaceId;

  /// The Space's own name. The conversation's `name` is only a mirror of it;
  /// the Space is the authority.
  final String title;

  /// Why the Space exists — shown under the title when there is one.
  final String? purpose;

  final int? memberCount;

  /// Whether this viewer may govern membership. Space authority decides this;
  /// the surface only renders the consequence.
  final bool canGovern;

  final void Function()? onOpenMembers;
  final void Function()? onBack;
}
