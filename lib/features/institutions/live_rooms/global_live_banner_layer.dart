/// Phase 2 Distribution — global live-now banner overlay.
///
/// Mounted around the shell body alongside `AuraIncomingLiveLayer`. When
/// a public-audience institution session enters the active set, a
/// single banner slides into the top of the screen with the host's
/// name and a Join CTA. Banner auto-dismisses after a few seconds,
/// can be manually closed, and respects a per-session cooldown so the
/// same session can never re-banner inside the cooldown window.
///
/// Design constraints:
///   * Max one banner at a time.
///   * Cooldown: 5 minutes per session id (per-process, not persisted —
///     SharedPreferences would persist a "dismissed forever" effect
///     across reinstalls; an in-memory cooldown keeps the user in
///     control without going stale).
///   * Public sessions only — internal sessions never banner.
///   * `/realtime/...` routes already render the live experience; we
///     suppress the banner there to avoid stacking.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/institutions/institution_access_provider.dart';
import 'global_live_discovery.dart';
import 'institution_session_meta.dart';

/// 5-minute window — same session cannot re-banner inside this.
const Duration _kCooldown = Duration(minutes: 5);

/// 8 seconds before auto-dismiss.
const Duration _kAutoDismiss = Duration(seconds: 8);

/// Per-process tracking of which sessions we've already banner'd. Keyed
/// by session id, value is the time the banner was first shown. The
/// cooldown predicate compares now - lastShown >= _kCooldown.
class _GlobalBannerStateNotifier extends StateNotifier<_GlobalBannerState> {
  _GlobalBannerStateNotifier() : super(const _GlobalBannerState());

  void show(String sessionId) {
    state = state.copyWith(
      activeSessionId: sessionId,
      lastShownAt: DateTime.now(),
      seen: {...state.seen, sessionId: DateTime.now()},
    );
  }

  void dismiss() {
    state = state.copyWith(activeSessionId: null);
  }

  bool wasRecentlyShown(String sessionId) {
    final last = state.seen[sessionId];
    if (last == null) return false;
    return DateTime.now().difference(last) < _kCooldown;
  }
}

class _GlobalBannerState {
  const _GlobalBannerState({
    this.activeSessionId,
    this.lastShownAt,
    this.seen = const {},
  });

  final String? activeSessionId;
  final DateTime? lastShownAt;
  final Map<String, DateTime> seen;

  _GlobalBannerState copyWith({
    String? activeSessionId,
    DateTime? lastShownAt,
    Map<String, DateTime>? seen,
  }) {
    return _GlobalBannerState(
      activeSessionId: activeSessionId,
      lastShownAt: lastShownAt ?? this.lastShownAt,
      seen: seen ?? this.seen,
    );
  }
}

final _globalBannerProvider =
    StateNotifierProvider<_GlobalBannerStateNotifier, _GlobalBannerState>(
  (_) => _GlobalBannerStateNotifier(),
);

/// Wraps the shell body. When a new public live session is detected and
/// the cooldown allows, renders a thin banner at the top of the layer.
class GlobalLiveBannerLayer extends ConsumerStatefulWidget {
  const GlobalLiveBannerLayer({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<GlobalLiveBannerLayer> createState() =>
      _GlobalLiveBannerLayerState();
}

class _GlobalLiveBannerLayerState extends ConsumerState<GlobalLiveBannerLayer> {
  Future<void> _onPublicLiveChanged(
    List<LiveNowDiscoveryEntry> entries,
  ) async {
    if (entries.isEmpty) return;
    final notifier = ref.read(_globalBannerProvider.notifier);
    final state = ref.read(_globalBannerProvider);
    if (state.activeSessionId != null) return; // already showing one
    // Pick the first entry not in cooldown.
    LiveNowDiscoveryEntry? candidate;
    for (final e in entries) {
      if (notifier.wasRecentlyShown(e.sessionId)) continue;
      candidate = e;
      break;
    }
    if (candidate == null) return;

    notifier.show(candidate.sessionId);
    // Auto-dismiss after the configured window. The user can close the
    // banner manually before this fires; if they navigate to the
    // session, the banner will be torn down by the route guard below.
    Future<void>.delayed(_kAutoDismiss, () {
      if (!mounted) return;
      final current = ref.read(_globalBannerProvider).activeSessionId;
      if (current == candidate!.sessionId) notifier.dismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Suppress the banner on the realtime route — the user is already
    // inside a session and an extra "join" surface would be noise.
    final path = GoRouterState.of(context).uri.path;
    final suppressOnRoute = path.startsWith('/realtime');

    ref.listen<List<LiveNowDiscoveryEntry>>(
      publicLiveDiscoveryProvider,
      (_, next) {
        if (suppressOnRoute) return;
        _onPublicLiveChanged(next);
      },
    );

    final activeId = ref.watch(_globalBannerProvider).activeSessionId;
    final entries = ref.watch(publicLiveDiscoveryProvider);
    LiveNowDiscoveryEntry? active;
    if (!suppressOnRoute && activeId != null) {
      for (final e in entries) {
        if (e.sessionId == activeId) {
          active = e;
          break;
        }
      }
    }

    return Stack(
      children: [
        widget.child,
        if (active != null)
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
                child: _LiveBannerCard(
                  entry: active,
                  onDismiss: () =>
                      ref.read(_globalBannerProvider.notifier).dismiss(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LiveBannerCard extends ConsumerWidget {
  const _LiveBannerCard({required this.entry, required this.onDismiss});

  final LiveNowDiscoveryEntry entry;
  final VoidCallback onDismiss;

  void _join(BuildContext context) {
    final m = entry.meta;
    final qp = <String, String>{
      'action': 'join',
      'returnTo': GoRouterState.of(context).uri.toString(),
      if (m != null) 'sessionType': m.type.wire,
      if (m != null) 'sessionAudience': m.audience.wire,
      if (m != null && (m.title?.trim().isNotEmpty ?? false))
        'sessionTitle': m.title!.trim(),
    };
    final qs = qp.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    onDismiss();
    context.push('/realtime/${entry.sessionId}?$qs');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Best-effort host name. We use the viewer's own institution
    // identity when the live session belongs to it; otherwise we leave
    // the host name blank and the banner reads as a generic session.
    final identity = ref.watch(institutionIdentityProvider);
    final viewerInstitutionId = identity?.id ?? '';
    final hostName = (entry.session.surfaceId == viewerInstitutionId)
        ? identity?.name.trim() ?? ''
        : '';
    final isVerified = (entry.session.surfaceId == viewerInstitutionId) &&
        (identity?.isVerified == true);
    final participantHint = entry.session.activeParticipantCount > 0
        ? '${entry.session.activeParticipantCount} attending'
        : 'People are joining';

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
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s14,
          AuraSpace.s10,
          AuraSpace.s10,
          AuraSpace.s10,
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AuraSurface.coVerdant,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AuraSpace.s10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'LIVE NOW',
                        style: AuraText.micro.copyWith(
                          color: AuraSurface.coVerdant,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.9,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '· ${entry.eyebrow}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AuraText.micro.copyWith(
                            color: AuraSurface.muted,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hostName.isNotEmpty
                        ? '$hostName · ${entry.displayTitle}'
                        : entry.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuraText.body.copyWith(
                      color: AuraSurface.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isVerified) ...[
                        const Icon(
                          Icons.verified_rounded,
                          size: 11,
                          color: AuraSurface.accentText,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        participantHint,
                        style: AuraText.micro.copyWith(
                          color: AuraSurface.faint,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AuraSpace.s10),
            AuraPrimaryButton(
              label: 'Join',
              icon: Icons.call_rounded,
              onPressed: () => _join(context),
            ),
            IconButton(
              tooltip: 'Dismiss',
              icon: const Icon(Icons.close_rounded, size: 18),
              color: AuraSurface.muted,
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}
