import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/navigation/navigation_authority.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../application/realtime_providers.dart';
import '../domain/realtime_models.dart';

/// LIVE DIRECTORY — founder charter 2026-08-17.
///
/// "LIVE IS NOT SOMETHING A USER CREATES. LIVE IS SOMETHING AN EXISTING
///  REALTIME HUMAN INTERACTION DELIBERATELY BECOMES."
/// "ORIGINATION IS CONTEXTUAL. DISCOVERY IS GLOBAL."
///
/// This surface answers exactly one question: WHAT IS LIVE ON AURA RIGHT
/// NOW? It is a watch/discovery surface — it never creates Live. The
/// previous incarnation of this screen was the retired legacy individual
/// broadcast console ("Start live" → STANDALONE sessions); no creation
/// CTA of any kind may return here, including in the empty state.
class RealtimeLobbyScreen extends ConsumerWidget {
  const RealtimeLobbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authStatus = ref.watch(authStatusProvider);
    final broadcasts = ref.watch(publicBroadcastsProvider);

    return AuraScaffold(
      title: 'Live',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(publicBroadcastsProvider);
              await ref.read(publicBroadcastsProvider.future).catchError(
                    (_) => <RealtimeSession>[],
                  );
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.s20,
                AuraSpace.s32,
                AuraSpace.s20,
                AuraSpace.s32,
              ),
              children: [
                const _DirectoryHeader(),
                const SizedBox(height: AuraSpace.s24),
                if (authStatus != AuthStatus.authed)
                  Text(
                    'Sign in to watch live sessions on Aura.',
                    style: AuraText.body.copyWith(color: AuraSurface.muted),
                  )
                else
                  broadcasts.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: AuraSpace.s32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => Text(
                      'Could not load live sessions — pull to retry.',
                      style: AuraText.body.copyWith(color: AuraSurface.muted),
                    ),
                    data: (sessions) => sessions.isEmpty
                        // Honest empty state — never a creation CTA.
                        ? Container(
                            padding: const EdgeInsets.all(AuraSpace.s24),
                            decoration: BoxDecoration(
                              color: AuraSurface.card,
                              borderRadius:
                                  BorderRadius.circular(AuraRadius.card),
                              border:
                                  Border.all(color: AuraSurface.divider),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.sensors_off_rounded,
                                  size: 32,
                                  color: AuraSurface.muted,
                                ),
                                const SizedBox(height: AuraSpace.s12),
                                Text(
                                  'Nothing is live right now',
                                  style: AuraText.body.copyWith(
                                    color: AuraSurface.ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: AuraSpace.s4),
                                Text(
                                  'When someone opens a call to the '
                                  'public, it appears here.',
                                  textAlign: TextAlign.center,
                                  style: AuraText.small.copyWith(
                                    color: AuraSurface.muted,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              for (final s in sessions) ...[
                                _LiveRow(session: s),
                                const SizedBox(height: AuraSpace.s12),
                              ],
                            ],
                          ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectoryHeader extends StatelessWidget {
  const _DirectoryHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AuraSurface.accentSoft,
            borderRadius: BorderRadius.circular(AuraRadius.card),
            border: Border.all(
              color: AuraSurface.accent.withValues(alpha: 0.3),
            ),
          ),
          child: const Icon(
            Icons.sensors_rounded,
            size: 24,
            color: AuraSurface.accentText,
          ),
        ),
        const SizedBox(width: AuraSpace.s16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Live on Aura', style: AuraText.headline),
              const SizedBox(height: AuraSpace.s4),
              Text(
                'Public live sessions happening right now.',
                style: AuraText.body.copyWith(
                  color: AuraSurface.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LiveRow extends StatelessWidget {
  const _LiveRow({required this.session});

  final RealtimeSession session;

  @override
  Widget build(BuildContext context) {
    final label = (session.title ?? session.contextName ?? 'Live session')
        .trim();
    final isVideo = session.kind == 'VIDEO';
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(
          color: AuraSurface.coRose.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isVideo ? Icons.videocam_rounded : Icons.graphic_eq_rounded,
            size: 20,
            color: AuraSurface.coRose,
          ),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.isEmpty ? 'Live session' : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AuraText.body.copyWith(
                    color: AuraSurface.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'LIVE now',
                  style: AuraText.micro.copyWith(
                    color: AuraSurface.coRose,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AuraSpace.s12),
          AuraPrimaryButton(
            label: 'Watch',
            onPressed: () => context.push(
              NavigationAuthority.realtimeSessionJoinRoute(session.id),
            ),
          ),
        ],
      ),
    );
  }
}
