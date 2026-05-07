import 'dart:async';

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
/// renders ringing live-session invitations as cards with a TTL countdown.
///
/// Behavior:
///   * Each ringing session shows a card with caller / room name and a
///     time-to-expiry countdown (TTL from `expiresAt` if surfaced; otherwise
///     computed from `createdAt + 30s`).
///   * When countdown reaches 0 the card auto-dismisses, the local
///     "ringing" sound (if any) stops, and the card transitions to a
///     "Missed" state for 5 seconds, then disappears entirely.
///   * No infinite ring.
class InstitutionLiveInviteWidget extends ConsumerStatefulWidget {
  const InstitutionLiveInviteWidget({
    super.key,
    required this.institutionId,
  });

  final String institutionId;

  /// Default TTL when the API does not surface `expiresAt`.
  static const Duration defaultTtl = Duration(seconds: 30);

  /// How long the "Missed" state remains visible after expiry.
  static const Duration missedHoldTime = Duration(seconds: 5);

  @override
  ConsumerState<InstitutionLiveInviteWidget> createState() =>
      _InstitutionLiveInviteWidgetState();
}

class _InstitutionLiveInviteWidgetState
    extends ConsumerState<InstitutionLiveInviteWidget> {
  Timer? _ticker;

  // sessionId -> when it transitioned to "missed" (so we can hide after hold).
  final Map<String, DateTime> _missedAt = <String, DateTime>{};
  // sessionId -> dismiss requested by the user (hide immediately).
  final Set<String> _dismissed = <String>{};

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() {});
      _evictExpiredMissed();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _evictExpiredMissed() {
    final now = DateTime.now();
    _missedAt.removeWhere((_, t) =>
        now.difference(t) > InstitutionLiveInviteWidget.missedHoldTime);
  }

  /// Compute remaining TTL for a session.
  Duration _remainingTtl(RealtimeSession session) {
    final meta = session.metadataJson ?? const {};
    DateTime? expiresAt;
    final raw = meta['expiresAt']?.toString().trim() ?? '';
    if (raw.isNotEmpty) {
      expiresAt = DateTime.tryParse(raw);
    }
    expiresAt ??= (session.createdAt ?? DateTime.now())
        .add(InstitutionLiveInviteWidget.defaultTtl);
    final diff = expiresAt.difference(DateTime.now());
    if (diff.isNegative) return Duration.zero;
    return diff;
  }

  bool _isInstitutionInvite(RealtimeSession s) {
    if (s.surfaceType != RealtimeSurfaceType.institution) return false;
    if (s.surfaceId == null || s.surfaceId!.isEmpty) return false;
    return s.surfaceId == widget.institutionId;
  }

  /// Treat sessions in their first ~TTL window as "ringing" — i.e. the
  /// invite has been sent but the call has not been answered (joined).
  bool _isRinging(RealtimeSession s) {
    if (!s.isActive) return false;
    if (s.firstJoinedAt != null) return false;
    return _remainingTtl(s) > Duration.zero;
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

    final invites = <_InviteCardData>[];
    for (final s in sessions) {
      if (!_isInstitutionInvite(s)) continue;
      if (_dismissed.contains(s.id)) continue;

      final ringing = _isRinging(s);
      if (ringing) {
        invites.add(_InviteCardData(
          session: s,
          state: _InviteState.ringing,
          remaining: _remainingTtl(s),
        ));
        // Clear any prior "missed" record once it's ringing again.
        _missedAt.remove(s.id);
      } else if (s.isActive && s.firstJoinedAt == null) {
        // Just expired — flip to missed state and hold for `missedHoldTime`.
        _missedAt.putIfAbsent(s.id, () => DateTime.now());
        final missedAt = _missedAt[s.id]!;
        if (DateTime.now().difference(missedAt) <
            InstitutionLiveInviteWidget.missedHoldTime) {
          invites.add(_InviteCardData(
            session: s,
            state: _InviteState.missed,
            remaining: Duration.zero,
          ));
        }
      }
    }

    if (invites.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final data in invites)
          Padding(
            padding: const EdgeInsets.only(bottom: AuraSpace.s10),
            child: _InviteCard(
              data: data,
              onJoin: () => _join(data.session.id),
              onDismiss: () => _dismiss(data.session.id),
            ),
          ),
      ],
    );
  }
}

enum _InviteState { ringing, missed }

class _InviteCardData {
  const _InviteCardData({
    required this.session,
    required this.state,
    required this.remaining,
  });

  final RealtimeSession session;
  final _InviteState state;
  final Duration remaining;
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.data,
    required this.onJoin,
    required this.onDismiss,
  });

  final _InviteCardData data;
  final VoidCallback onJoin;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final isRinging = data.state == _InviteState.ringing;
    final session = data.session;
    final name = session.contextName ?? session.title ?? 'Live invite';
    final isVideo = session.kind.toUpperCase() == 'VIDEO';
    final remainingSec = data.remaining.inSeconds;

    final accentBg = isRinging ? AuraSurface.goodBg : AuraSurface.subtle;
    final accentInk = isRinging ? AuraSurface.goodInk : AuraSurface.faint;

    return Container(
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(
          color: isRinging
              ? AuraSurface.goodInk.withValues(alpha: 0.4)
              : AuraSurface.divider,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accentBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isVideo ? Icons.videocam_rounded : Icons.mic_rounded,
              size: 18,
              color: accentInk,
            ),
          ),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AuraText.body
                      .copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      isRinging ? 'Ringing…' : 'Missed call',
                      style: AuraText.micro.copyWith(
                        color: accentInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isRinging) ...[
                      const SizedBox(width: AuraSpace.s8),
                      Text(
                        '${remainingSec}s',
                        style: AuraText.micro
                            .copyWith(color: AuraSurface.muted),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isRinging) ...[
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
        ],
      ),
    );
  }
}
