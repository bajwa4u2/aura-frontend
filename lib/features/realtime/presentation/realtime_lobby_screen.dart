import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../application/realtime_providers.dart';

class RealtimeLobbyScreen extends ConsumerStatefulWidget {
  const RealtimeLobbyScreen({super.key});

  @override
  ConsumerState<RealtimeLobbyScreen> createState() =>
      _RealtimeLobbyScreenState();
}

class _RealtimeLobbyScreenState extends ConsumerState<RealtimeLobbyScreen> {
  String _kind = 'AUDIO';

  Future<void> _startLive() async {
    final router = GoRouter.of(context);
    final controller = ref.read(realtimeControllerProvider.notifier);
    final id = await controller.createSession(
      surfaceType: 'STANDALONE',
      surfaceId: '',
      kind: _kind,
    );
    if (!context.mounted) return;
    router.go('/realtime/$id?action=join');
  }

  @override
  Widget build(BuildContext context) {
    final realtime = ref.watch(realtimeControllerProvider);
    final authStatus = ref.watch(authStatusProvider);

    return AuraScaffold(
      title: 'Live',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s20,
              AuraSpace.s32,
              AuraSpace.s20,
              AuraSpace.s32,
            ),
            children: [
              const _LiveHeader(),
              const SizedBox(height: AuraSpace.s32),
              if (authStatus != AuthStatus.authed)
                const _LobbyAuthGate()
              else ...[
                _KindSelector(
                  selected: _kind,
                  onChanged: (v) => setState(() => _kind = v),
                ),
                const SizedBox(height: AuraSpace.s24),
                SizedBox(
                  width: double.infinity,
                  child: AuraPrimaryButton(
                    label: realtime.isBusy ? 'Starting…' : 'Start live',
                    onPressed: realtime.isBusy ? null : _startLive,
                    icon: realtime.isBusy ? null : Icons.sensors_rounded,
                  ),
                ),
              ],
              if ((realtime.errorMessage ?? '').isNotEmpty) ...[
                const SizedBox(height: AuraSpace.s16),
                _StatusBanner(
                  message: realtime.errorMessage ?? '',
                  isError: true,
                ),
              ],
              if ((realtime.infoMessage ?? '').isNotEmpty) ...[
                const SizedBox(height: AuraSpace.s16),
                _StatusBanner(message: realtime.infoMessage ?? ''),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _LiveHeader extends StatelessWidget {
  const _LiveHeader();

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
              const Text('Start live', style: AuraText.headline),
              const SizedBox(height: AuraSpace.s4),
              Text(
                'Start a live session instantly.',
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

class _KindSelector extends StatelessWidget {
  const _KindSelector({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _KindOption(
          label: 'Audio',
          icon: Icons.mic_none_rounded,
          selected: selected == 'AUDIO',
          onTap: () => onChanged('AUDIO'),
        ),
        const SizedBox(width: AuraSpace.s12),
        _KindOption(
          label: 'Video',
          icon: Icons.videocam_outlined,
          selected: selected == 'VIDEO',
          onTap: () => onChanged('VIDEO'),
        ),
      ],
    );
  }
}

class _KindOption extends StatelessWidget {
  const _KindOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s16,
              vertical: AuraSpace.s14,
            ),
            decoration: BoxDecoration(
              color: selected ? AuraSurface.accentSoft : AuraSurface.card,
              borderRadius: BorderRadius.circular(AuraRadius.card),
              border: Border.all(
                color: selected
                    ? AuraSurface.accent.withValues(alpha: 0.5)
                    : AuraSurface.divider,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color:
                      selected ? AuraSurface.accentText : AuraSurface.muted,
                ),
                const SizedBox(width: AuraSpace.s8),
                Text(
                  label,
                  style: AuraText.small.copyWith(
                    fontWeight: FontWeight.w600,
                    color:
                        selected ? AuraSurface.accentText : AuraSurface.muted,
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

class _LobbyAuthGate extends StatelessWidget {
  const _LobbyAuthGate();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s20),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AuraSurface.warnBg,
                  borderRadius: BorderRadius.circular(AuraRadius.r10),
                  border: Border.all(
                    color: AuraSurface.warnInk.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: AuraSurface.warnInk,
                ),
              ),
              const SizedBox(width: AuraSpace.s12),
              const Expanded(
                child: Text('Sign in required', style: AuraText.subtitle),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s12),
          Text(
            'You need an active session to start live.',
            style: AuraText.body.copyWith(
              color: AuraSurface.muted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s16,
        vertical: AuraSpace.s14,
      ),
      decoration: BoxDecoration(
        color: isError ? AuraSurface.dangerBg : AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(
          color: isError
              ? AuraSurface.dangerInk.withValues(alpha: 0.35)
              : AuraSurface.divider,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            size: 18,
            color: isError ? AuraSurface.dangerInk : AuraSurface.muted,
          ),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Text(
              message,
              style: AuraText.body.copyWith(
                color: isError ? AuraSurface.dangerInk : AuraSurface.ink,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
