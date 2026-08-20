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

/// `/institution/:institutionId/spaces/:spaceId` — the reconstructed
/// Institution Space. Both identifiers are required: a Space with no
/// institution is a legacy personal space, which has no surviving surface.
String? institutionSpaceDestination(String? institutionId, String? spaceId) {
  final institution = _clean(institutionId);
  final space = _clean(spaceId);
  if (institution == null || space == null) return null;
  return '/institution/$institution/spaces/$space';
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
