import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/aura_platform_components.dart';
import '../../../../core/ui/aura_radius.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../../../core/ui/aura_text.dart';
import '../../application/realtime_providers.dart';
import '../../data/orphaned_session_dismissal_cache.dart';
import '../../domain/orphaned_session.dart';
import '../../domain/realtime_enums.dart';
import '../../domain/realtime_models.dart';

/// Realtime Architecture Correction — Runtime Lifecycle Phase 2.
///
/// App-root banner (mounted alongside `ThreadCallLifecycleHost`) that
/// surfaces a session the backend still holds this user as an
/// ACTIVE/JOINING participant on, but that this process has no in-memory
/// awareness of — the process-recreation gap `findOrphanedActiveSession`
/// documents. Deliberately does not auto-join: silently opening the
/// microphone/camera on a cold boot the user didn't ask for would be worse
/// than a missed reconnect. Routes through the same `/realtime/:id?action=join`
/// entry point every other surface already uses — no new join/reconnect
/// mechanics, no surface-specific policy.
///
/// Dismissal is persisted per session id via `OrphanedSessionDismissalCache`
/// (client-local only — never mutates canonical session truth) so a
/// still-genuinely-active session that the user already dismissed does not
/// re-banner on every reload/relaunch; see that class for the full trace.
class OrphanedSessionBanner extends ConsumerStatefulWidget {
  const OrphanedSessionBanner({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OrphanedSessionBanner> createState() =>
      _OrphanedSessionBannerState();
}

class _OrphanedSessionBannerState
    extends ConsumerState<OrphanedSessionBanner> {
  final Set<String> _dismissed = <String>{};

  @override
  void initState() {
    super.initState();
    // Dismissal must survive a reload/relaunch, not just the widget's own
    // lifetime — see OrphanedSessionDismissalCache for why.
    OrphanedSessionDismissalCache.read().then((ids) {
      if (mounted && ids.isNotEmpty) {
        setState(() => _dismissed.addAll(ids));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(liveSessionsProvider);
    final clientState = ref.watch(realtimeControllerProvider);

    final mySessions = sessionsAsync.maybeWhen(
      data: (s) => s,
      orElse: () => const <RealtimeSession>[],
    );
    final orphaned = findOrphanedActiveSession(
      mySessions: mySessions,
      clientState: clientState,
    );

    if (orphaned == null || _dismissed.contains(orphaned.id)) {
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.s12,
                AuraSpace.s8,
                AuraSpace.s12,
                0,
              ),
              child: _RejoinBanner(
                isMeeting: orphaned.surfaceType == RealtimeSurfaceType.meeting,
                label: orphaned.contextName ?? orphaned.title,
                onRejoin: () {
                  final id = orphaned.id;
                  setState(() => _dismissed.add(id));
                  context.push('/realtime/$id?action=join');
                },
                onDismiss: () {
                  setState(() => _dismissed.add(orphaned.id));
                  OrphanedSessionDismissalCache.markDismissed(
                    orphaned.id,
                    stillActiveIds: mySessions.map((s) => s.id).toSet(),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RejoinBanner extends StatelessWidget {
  const _RejoinBanner({
    required this.isMeeting,
    required this.label,
    required this.onRejoin,
    required this.onDismiss,
  });

  final bool isMeeting;
  final String? label;
  final VoidCallback onRejoin;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final subtitle = (label ?? '').trim();
    return Material(
      elevation: 6,
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AuraRadius.lg),
      child: Container(
        decoration: BoxDecoration(
          color: AuraSurface.card,
          borderRadius: BorderRadius.circular(AuraRadius.lg),
          border: Border.all(
            color: AuraSurface.coVerdant.withValues(alpha: 0.45),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(AuraSpace.s12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMeeting
                        ? 'You have an active meeting'
                        : 'You have an active call',
                    style: AuraText.body.copyWith(
                      color: AuraSurface.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AuraText.micro.copyWith(
                        color: AuraSurface.faint,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AuraSpace.s8),
            AuraSecondaryButton(label: 'Dismiss', onPressed: onDismiss),
            const SizedBox(width: AuraSpace.s8),
            AuraPrimaryButton(
              label: 'Rejoin',
              icon: Icons.call_rounded,
              onPressed: onRejoin,
            ),
          ],
        ),
      ),
    );
  }
}
