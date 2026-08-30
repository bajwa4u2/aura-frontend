import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../realtime/application/realtime_providers.dart';
import '../../realtime/application/thread_call_lifecycle_controller.dart';
import '../../updates/incoming_call_bridge.dart';

/// THE SAME INVITATION, SHOWN WHERE IT BELONGS.
///
/// This is a projection, not a call system. It reads the one canonical
/// invitation store — `incomingCallBridgeProvider` — that CallKit and the
/// app-root card already read, and owns no lifecycle of its own: it cannot
/// create, expire or resolve an invitation. It draws the one that exists and
/// hands intent back to the same authorities every other surface uses.
///
/// It appears only while the conversation the call belongs to is on screen.
/// Association is by canonical identifier — `correspondenceId`, which the
/// backend itself maps to a conversation id (activity-history.service.ts:
/// `conversationId: r.correspondenceId`) — with `threadId` accepted alongside
/// for the legacy surface still mid-convergence. Never by the caller's name: a
/// display name is not an identity, and matching on it would put one person's
/// call in another person's thread.
///
/// Nothing of the conversation travels with the invitation, and nothing of the
/// invitation reveals the conversation. A call arriving is not a reason to
/// expose history.

/// Selects the invitation belonging to [conversationId], or null.
///
/// Top-level and pure so the rule that decides whose call appears in whose
/// thread is testable without mounting a conversation.
Map<String, dynamic>? conversationIncomingCall(
  List<Map<String, dynamic>> items,
  String conversationId, {
  String? joinedSessionId,
  DateTime? now,
}) {
  final id = conversationId.trim();
  if (id.isEmpty) return null;
  final at = now ?? DateTime.now().toUtc();

  for (final item in items) {
    final data = _dataOf(item);
    String field(String key) => '${data[key] ?? ''}'.trim();

    // Canonical identifiers only.
    if (field('correspondenceId') != id && field('threadId') != id) continue;

    final sessionId = field('sessionId').isNotEmpty
        ? field('sessionId')
        : field('realtimeSessionId');
    if (sessionId.isEmpty) continue;

    // Already in THIS call — the room is the surface now, not a ring.
    if (joinedSessionId != null && joinedSessionId == sessionId) continue;

    // An invitation the server has already expired is not an invitation.
    final expiresAt = DateTime.tryParse(field('expiresAt'));
    if (expiresAt != null && expiresAt.isBefore(at)) continue;

    return item;
  }
  return null;
}

Map<String, dynamic> _dataOf(Map<String, dynamic> item) {
  final raw = item['data'];
  if (raw is Map) return raw.map((k, v) => MapEntry('$k', v));
  return const <String, dynamic>{};
}

class ConversationIncomingCall extends ConsumerStatefulWidget {
  const ConversationIncomingCall({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ConversationIncomingCall> createState() =>
      _ConversationIncomingCallState();
}

class _ConversationIncomingCallState
    extends ConsumerState<ConversationIncomingCall> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(incomingCallBridgeProvider);
    final live = ref.watch(realtimeControllerProvider);
    final item = conversationIncomingCall(
      items,
      widget.conversationId,
      joinedSessionId: live.isJoined ? live.sessionId : null,
    );
    if (item == null) return const SizedBox.shrink();

    final data = _dataOf(item);
    String field(String key) => '${data[key] ?? ''}'.trim();

    final sessionId = field('sessionId').isNotEmpty
        ? field('sessionId')
        : field('realtimeSessionId');
    final isVideo = field('mediaMode').toLowerCase().contains('video') ||
        field('callKind').toLowerCase().contains('video');

    final actor = item['actor'];
    final actorName =
        actor is Map ? '${actor['displayName'] ?? ''}'.trim() : '';
    final caller = actorName.isNotEmpty
        ? actorName
        : (field('callerDisplayName').isNotEmpty
            ? field('callerDisplayName')
            : 'Someone');

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s16,
        vertical: AuraSpace.s10,
      ),
      decoration: const BoxDecoration(
        color: AuraSurface.subtle,
        border: Border(bottom: BorderSide(color: AuraSurface.divider)),
      ),
      child: Row(
        children: [
          Icon(
            isVideo ? Icons.videocam_rounded : Icons.call_rounded,
            size: 18,
            color: AuraSurface.coVerdant,
          ),
          const SizedBox(width: AuraSpace.s8),
          Expanded(
            child: Text(
              isVideo ? '$caller is calling with video' : '$caller is calling',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AuraText.small.copyWith(
                color: AuraSurface.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: _busy ? null : () => _decline(sessionId, item),
            child: Text(
              'Decline',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
          ),
          const SizedBox(width: AuraSpace.s4),
          AuraPrimaryButton(
            label: 'Accept',
            onPressed: _busy ? null : () => _accept(item),
          ),
        ],
      ),
    );
  }

  /// The SAME accept path the app-root card and the CallKit answer use.
  /// Nothing about joining a call is decided here.
  Future<void> _accept(Map<String, dynamic> item) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(threadCallLifecycleProvider.notifier)
          .acceptIncomingCall(item);
      final id = '${item['id'] ?? ''}'.trim();
      if (id.isNotEmpty) {
        // Clears every ringing projection for this session WITHOUT telling
        // CallKit the call ended — accepting a call must never end it.
        ref.read(incomingCallBridgeProvider.notifier).removeAccepted(id);
      }
    } catch (_) {
      // The app-root surface owns join-failure presentation; this projection
      // must not grow a second, competing error state.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Decline is a real backend transition, not a hidden widget.
  /// `declineInvite` is the same authority the active-call ribbon already uses.
  Future<void> _decline(String sessionId, Map<String, dynamic> item) async {
    if (sessionId.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(realtimeRepositoryProvider).declineInvite(sessionId);
    } catch (_) {
      // Refusing to fake it: if the backend did not accept the decline, the
      // card stays, because the invitation genuinely still stands.
      if (mounted) setState(() => _busy = false);
      return;
    }
    final id = '${item['id'] ?? ''}'.trim();
    if (id.isNotEmpty) {
      ref.read(incomingCallBridgeProvider.notifier).remove(id);
    }
    if (mounted) setState(() => _busy = false);
  }
}
