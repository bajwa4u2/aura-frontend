/// Realtime Architecture Correction — Phase 6, Meeting Attendee-Context
/// Restoration.
///
/// OWNERSHIP DOCTRINE: institution meetings are owned by the Institution
/// Workspace end to end — the record still renders the institution as the
/// meeting's owner regardless of who is viewing it. But an external
/// participant (an Aura member who booked or was invited/attended) has no
/// seat in the institution's Workspace; only an actual institutional actor
/// (a member/affiliate of the OWNING institution specifically) belongs
/// there. Before this chapter, `booking_confirm_screen.dart` and
/// `keep_meeting_screen.dart` routed unconditionally into
/// `/institution/:id/meetings/:id` whenever the meeting had ANY owning
/// institution — trapping every external attendee inside a shell requiring
/// institution Workspace access they don't have, surfacing as a redirect to
/// Institution Sign In. `meeting_detail_screen.dart` already had the
/// correct doctrine (as inline logic); this module is the single shared,
/// tested source all three screens now use, instead of three independent
/// copies of the same decision.
library;

/// True when the viewer is actually affiliated with [owningInstitutionId]
/// — either it's their currently-active institution identity, or it
/// appears among their institution affiliations. An empty/null
/// [owningInstitutionId] means the meeting isn't institution-owned at all,
/// so this is always false.
bool belongsToOwningInstitution({
  required String? owningInstitutionId,
  required String? viewerActiveInstitutionId,
  required Iterable<String> viewerAffiliationInstitutionIds,
}) {
  final owning = (owningInstitutionId ?? '').trim();
  if (owning.isEmpty) return false;
  if ((viewerActiveInstitutionId ?? '').trim() == owning) return true;
  return viewerAffiliationInstitutionIds.any((id) => id.trim() == owning);
}

/// The correct meeting-record route for [meetingId] given whether the
/// viewer belongs to the owning institution. Institutional actors
/// canonicalize into the Institution Workspace shell; everyone else
/// (including a genuinely unowned meeting) lands on the member-path record,
/// which resolves correctly regardless of ownership.
String resolveMeetingRecordRoute({
  required String meetingId,
  required String? owningInstitutionId,
  required bool viewerBelongsToOwningInstitution,
}) {
  final id = meetingId.trim();
  if (id.isEmpty) return '/home';
  final owning = (owningInstitutionId ?? '').trim();
  if (viewerBelongsToOwningInstitution && owning.isNotEmpty) {
    return '/institution/$owning/meetings/$id';
  }
  return '/meetings/$id';
}
