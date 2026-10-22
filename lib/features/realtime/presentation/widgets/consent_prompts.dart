import 'package:flutter/material.dart';

import '../../../../core/ui/adaptive_dialog_action.dart';

/// EVERYONE'S YES (founder-approved design, 22 Oct 2026).
///
/// Going live and recording change what happens to everyone in the room, so
/// each person is asked; nothing starts on one person's say-so. These are the
/// two questions, in each platform's own dialog convention.

/// Whether this device should be asked, for a `session:live.request` or
/// `recording:consent.required` payload: it lists who still has to answer
/// and who asked. The person who asked is never asked again.
bool shouldAskForConsent(
  Map<String, dynamic> payload, {
  required String me,
  required String requesterKey,
}) {
  if (me.isEmpty) return false;
  final pending = (payload['pendingUserIds'] as List? ?? const [])
      .map((v) => v.toString())
      .toSet();
  // Recording also lists everyone it waits on, guests included, by the id
  // their own connection carries (user id, or guest-session id).
  for (final p in payload['pendingParticipants'] as List? ?? const []) {
    if (p is Map && p['id'] != null) pending.add(p['id'].toString());
  }
  final by = (payload[requesterKey] ?? '').toString();
  return pending.contains(me) && by != me;
}

/// "Ana wants to go live." Returns true for Go live; Stay private, or
/// dismissing the question, keeps the call private.
Future<bool> askGoLive(BuildContext context, String requester) async {
  final accept = await showAdaptiveDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog.adaptive(
      title: Text('$requester wants to go live.'),
      content: const Text('Everyone on Aura could watch this call.'),
      actions: [
        adaptiveDialogAction(
          ctx,
          label: 'Stay private',
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
        adaptiveDialogAction(
          ctx,
          label: 'Go live',
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );
  return accept == true;
}

/// "Mia wants to record this meeting." Returns true for Allow recording,
/// false for Leave, and null when the question is dismissed unanswered —
/// recording then simply does not start; nobody is made to leave.
///
/// Someone arriving while the recording is already running is asked
/// "Mia is recording this meeting." instead ([alreadyRecording]).
Future<bool?> askRecording(
  BuildContext context,
  String requester, {
  bool alreadyRecording = false,
}) async {
  final allow = await showAdaptiveDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog.adaptive(
      title: Text(alreadyRecording
          ? '$requester is recording this meeting.'
          : '$requester wants to record this meeting.'),
      actions: [
        adaptiveDialogAction(
          ctx,
          label: 'Leave',
          destructive: true,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
        adaptiveDialogAction(
          ctx,
          label: 'Allow recording',
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );
  return allow;
}

/// Why a go-live request ended without going live, in the room's words:
/// `session:live.request.cancelled` reason 'declined' | 'expired' |
/// 'participant_left'. Null for anything else.
String? goLiveCancelledWords(String reason, String name) {
  final who = name.isEmpty ? 'Someone' : name;
  switch (reason) {
    case 'declined':
      return '$who chose to stay private.';
    case 'expired':
      return 'No one answered in time. The call stays private.';
    case 'participant_left':
      return '$who left, so the call stays private.';
  }
  return null;
}
