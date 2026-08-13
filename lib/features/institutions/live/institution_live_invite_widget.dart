import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../realtime/application/realtime_providers.dart';
import '../../realtime/domain/realtime_enums.dart';
import '../../realtime/domain/realtime_models.dart';

/// A widget (not a screen) for the institution live-rooms surface that
/// surfaces this institution's live sessions nobody has joined yet, as
/// simple "just started, tap to join" cards.
///
/// Realtime Architecture Correction — Phase 8 (Legacy Retirement). This
/// widget previously simulated point-to-point call semantics (a per-second
/// ringing countdown, then a 5-second "Missed call" transition) that this
/// surface never actually had backing it: Institution Room is a join-only
/// broadcast (`startInstitutionLive` never reaches the invite-issuing path
/// — `resolveForSurface` only resolves THREAD/DM/SPACE, so no
/// `call:incoming` socket event is ever emitted for an institution room
/// going live), so there was no real ring/accept/decline lifecycle for the
/// old TTL/missed simulation to honestly reflect — it was client-invented
/// on top of the same plain REST poll (`liveSessionsProvider`) the "Live
/// Now" discovery banner (`global_live_banner_layer.dart`) already uses
/// correctly, without fabricating a countdown. This widget now matches
/// that same honest pattern instead of forking its own.
class InstitutionLiveInviteWidget extends ConsumerStatefulWidget {
  const InstitutionLiveInviteWidget({
    super.key,
    required this.institutionId,
  });

  final String institutionId;

  @override
  ConsumerState<InstitutionLiveInviteWidget> createState() =>
      _InstitutionLiveInviteWidgetState();
}

class _InstitutionLiveInviteWidgetState
    extends ConsumerState<InstitutionLiveInviteWidget> {
  // sessionId -> dismiss requested by the user (hide immediately).
  final Set<String> _dismissed = <String>{};

  bool _isInstitutionSession(RealtimeSession s) {
    if (s.surfaceType != RealtimeSurfaceType.institution) return false;
    if (s.surfaceId == null || s.surfaceId!.isEmpty) return false;
    return s.surfaceId == widget.institutionId;
  }

  /// Nobody has joined this session yet — the moment it's actually worth
  /// surfacing as a "tap to join" card here (once occupied, it shows as a
  /// normal ACTIVE room card elsewhere on this screen instead).
  bool _isJoinable(RealtimeSession s) {
    return s.isActive && s.firstJoinedAt == null;
  }

  void _dismiss(String sessionId) {
    setState(() => _dismissed.add(sessionId));
  }

  void _join(String sessionId) {
    // Phase-7 regression fix — return to the canonical id-aware
    // path so leaving the realtime room lands on the same workspace
    // tab the user came from. The legacy shorthand
    // `/institution/live-rooms` was a context-blind redirect that
    // crashed when the identity provider was null.
    context.push('/realtime/$sessionId?action=join'
        '&returnTo=/institution/${widget.institutionId}/live-rooms');
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(liveSessionsProvider);
    final sessions = sessionsAsync.maybeWhen(
      data: (s) => s,
      orElse: () => const <RealtimeSession>[],
    );

    final invites = <RealtimeSession>[];
    for (final s in sessions) {
      if (!_isInstitutionSession(s)) continue;
      if (_dismissed.contains(s.id)) continue;
      if (!_isJoinable(s)) continue;
      invites.add(s);
    }

    if (invites.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final session in invites)
          Padding(
            padding: const EdgeInsets.only(bottom: AuraSpace.s10),
            child: _InviteCard(
              session: session,
              onJoin: () => _join(session.id),
              onDismiss: () => _dismiss(session.id),
            ),
          ),
      ],
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.session,
    required this.onJoin,
    required this.onDismiss,
  });

  final RealtimeSession session;
  final VoidCallback onJoin;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final name = session.contextName ?? session.title ?? 'Live session';
    final isVideo = session.kind.toUpperCase() == 'VIDEO';

    return Container(
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(
          color: AuraSurface.coVerdant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AuraSurface.coVerdant.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isVideo ? Icons.videocam_rounded : Icons.mic_rounded,
              size: 18,
              color: AuraSurface.coVerdant,
            ),
          ),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Just started',
                  style: AuraText.micro.copyWith(
                    color: AuraSurface.coVerdant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          AuraSecondaryButton(
            label: 'Dismiss',
            onPressed: onDismiss,
          ),
          const SizedBox(width: AuraSpace.s8),
          AuraPrimaryButton(
            label: 'Join',
            icon: Icons.call_rounded,
            onPressed: onJoin,
          ),
        ],
      ),
    );
  }
}
