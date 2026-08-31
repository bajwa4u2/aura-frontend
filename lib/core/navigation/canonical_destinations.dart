/// CANONICAL DESTINATION AUTHORITY (client)
///
/// The mirror of the backend authority at
/// `src/common/routes/canonical-destinations.ts`. One place that decides where
/// the app sends a member when it has an event, a notification or an
/// invitation in hand.
///
/// Phase 5 retired the `/me/correspondence/...` family. The router declares no
/// `errorBuilder`, so anything still pointing there lands on GoRouter's default
/// not-found page. The rule is the same on both sides of the wire: a
/// destination is minted only from an identifier that names a surviving
/// product object.
///
/// A legacy `threadId` is not such an identifier, and is not accepted as an
/// input anywhere in this file. There is no Thread → Conversation mapping, so
/// it cannot be honestly converted. When nothing canonical is known the answer
/// is `null` — no destination — never a guess and never a retired address.
library;

/// Prefix of the retired family, so gates can assert against one constant.
const String kRetiredCorrespondenceRoutePrefix = '/me/correspondence';

String? _clean(String? value) {
  final trimmed = (value ?? '').trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// `/messages/c/:conversationId` — the canonical Conversation surface.
String? conversationDestination(String? conversationId) {
  final id = _clean(conversationId);
  return id == null ? null : '/messages/c/$id';
}

/// `/institution/:institutionAddress/spaces/:spaceAddress` — the reconstructed
/// Institution Space.
///
/// BOTH SEGMENTS ARE PRODUCT ADDRESSES (founder ruling 2026-08-23). The Space
/// address is scoped to its parent institution, so the institution half is not
/// decoration — it is the namespace that makes the second half mean anything.
///
/// Both are required for a second reason that has not changed: a Space with no
/// institution is a private member context, which has no Space address at all
/// and is reached through the Conversation it owns.
String? institutionSpaceDestination(
  String? institutionAddress,
  String? spaceAddress,
) {
  final institution = _clean(institutionAddress);
  final space = _clean(spaceAddress);
  if (institution == null || space == null) return null;
  return '/institution/$institution/spaces/$space';
}

/// `/media/:mediaId/restricted` — the member's surface for an attachment whose
/// delivery has been stopped, and the route back through the appeal.
///
/// Minted from the media id alone, because that is the only identifier a
/// restriction notice is guaranteed to carry. Deliberately NOT read out of a
/// stored `deeplink`: the notices written before that field existed have none,
/// and a destination authority that only works for rows created after it
/// shipped is not an authority — it is a migration waiting to be noticed by a
/// member whose tap does nothing.
String? restrictedMediaDestination(String? mediaId) {
  final id = _clean(mediaId);
  return id == null ? null : '/media/$id/restricted';
}

/// Where an identity verification notice belongs, derived from its TYPE.
///
/// Deliberately NOT read out of a stored path. The released clients
/// (`1.4.0+27`, client commit `b73e8a1`) return a payload deeplink verbatim
/// and their router has no `/verify-identity` — so a decision notice carrying
/// that path takes a member who verified from a mobile browser to a red
/// "Route not found: /verify-identity" screen inside the installed app.
///
/// Deriving it here means the destination exists exactly where the route
/// does. A build that lacks the screen resolves nothing and the tap is inert,
/// which is a disappointment; the alternative is a developer error page shown
/// to someone who just submitted their passport.
String? identityVerificationDestination(String? notificationType) {
  final t = _clean(notificationType)?.toUpperCase();
  if (t == null || !t.startsWith('IDENTITY_VERIFICATION')) return null;
  // The reviewer's queue notice and the subject's decision notices are the
  // same family and must not resolve to the same place.
  return t == 'IDENTITY_VERIFICATION_SUBMITTED'
      ? '/admin/identity-review'
      : '/verify-identity';
}

/// The media id carried by a quarantine or quarantine-lifted notice.
///
/// Tolerates BOTH governed shapes on purpose: the quarantine notice nests it
/// under `subject` (the D3 notice contract), while the lifted notice carries it
/// flat. One reader for both means the paired lifecycle notifications cannot
/// drift apart — the failure that left QUARANTINED navigable and LIFTED not.
String? mediaIdFromRestrictionNotice(Map<String, dynamic>? payload) {
  if (payload == null) return null;
  final subject = payload['subject'];
  if (subject is Map) {
    final nested = _clean(subject['mediaId']?.toString());
    if (nested != null) return nested;
  }
  return _clean(payload['mediaId']?.toString());
}

/// `/realtime/:sessionId` — where a live session is actually experienced.
String? realtimeSessionDestination(String? sessionId, {bool join = false}) {
  final id = _clean(sessionId);
  if (id == null) return null;
  return join ? '/realtime/$id?action=join' : '/realtime/$id';
}

/// Where an event *belongs* — the context a member should land on when they
/// open a notification, an activity row or an invitation.
String? canonicalContextDestination({
  String? conversationId,
  String? institutionId,
  String? spaceId,
}) {
  return institutionSpaceDestination(institutionId, spaceId) ??
      conversationDestination(conversationId);
}

/// Where a *live* event should send a member: the session surface if there is
/// one, otherwise the context that owns it.
String? canonicalLiveDestination({
  String? sessionId,
  String? conversationId,
  String? institutionId,
  String? spaceId,
  bool join = true,
}) {
  return realtimeSessionDestination(sessionId, join: join) ??
      canonicalContextDestination(
        conversationId: conversationId,
        institutionId: institutionId,
        spaceId: spaceId,
      );
}

/// `/posts/:postId/edit` — the editor for a post the viewer wrote.
///
/// Minted here rather than typed at the call site so the owner actions on the
/// feed card and on `PostCard` cannot drift to two different addresses for the
/// same act.
String? postEditDestination(String? postId) {
  final id = _clean(postId);
  return id == null ? null : '/posts/$id/edit';
}

/// `/home` — the member's own surface.
///
/// The fallback for an action that destroyed the page it was performed on and
/// has nowhere to pop back to.
String memberHomeDestination() => '/home';

/// `/announcements` — the announcement index.
///
/// Where a reader lands when the announcement they were reading is removed
/// from under them.
String announcementsIndexDestination() => '/announcements';

/// `/` — the public front door.
///
/// Distinct from [memberHomeDestination]: this is where a person who may not
/// be signed in belongs. A booking cancellation is reached from an emailed
/// link by someone who is very often neither signed in nor a member, so
/// sending them to `/home` would bounce them through an auth gate to reach a
/// page they did not ask for.
String publicRootDestination() => '/';

/// `/meet/:slug/book`, or its institution-scoped form.
///
/// The calendar a booking came from. Someone who cancels because the time did
/// not suit them wants the next time, not a front page — so the address is
/// built from the profile the booking already names, and lives here rather
/// than being assembled inline at the one screen that happens to need it.
///
/// Returns null when there is no profile to return to; a caller must not
/// render a dead "book another time" control.
String? meetingBookingDestination({
  required String profileSlug,
  String institutionSlug = '',
}) {
  final slug = _clean(profileSlug);
  if (slug == null) return null;
  final institution = _clean(institutionSlug);
  return institution == null
      ? '/meet/$slug/book'
      : '/i/$institution/meet/$slug/book';
}
