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
  final _surfaceIdController = TextEditingController(text: 'room-1');
  final _existingSessionController = TextEditingController();

  String _surfaceType = 'SPACE';
  String _kind = 'MIXED';

  @override
  void dispose() {
    _surfaceIdController.dispose();
    _existingSessionController.dispose();
    super.dispose();
  }

  String _surfaceLabel(String value) {
    switch (value) {
      case 'SPACE':
        return 'Space';
      case 'DM':
        return 'Direct conversation';
      case 'INSTITUTION_ROOM':
        return 'Institution';
      case 'EVENT_ROOM':
        return 'Event';
      case 'THREAD':
        return 'Thread';
      default:
        return value;
    }
  }

  String _kindLabel(String value) {
    switch (value) {
      case 'AUDIO':
        return 'Audio';
      case 'VIDEO':
        return 'Video';
      case 'SCREEN':
        return 'Screen';
      default:
        return 'Mixed';
    }
  }

  @override
  Widget build(BuildContext context) {
    final realtime = ref.watch(realtimeControllerProvider);
    final authStatus = ref.watch(authStatusProvider);

    return AuraScaffold(
      title: 'Live',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s20,
              AuraSpace.s24,
              AuraSpace.s20,
              AuraSpace.s32,
            ),
            children: [
              _LobbyHeader(
                surfaceType: _surfaceType,
                kind: _kind,
                surfaceLabel: _surfaceLabel,
                kindLabel: _kindLabel,
              ),
              const SizedBox(height: AuraSpace.s24),
              if (authStatus != AuthStatus.authed)
                _LobbyAuthGate()
              else ...[
                _StartLiveCard(
                  surfaceType: _surfaceType,
                  kind: _kind,
                  surfaceIdController: _surfaceIdController,
                  isBusy: realtime.isBusy,
                  surfaceLabel: _surfaceLabel,
                  kindLabel: _kindLabel,
                  onSurfaceTypeChanged: (v) =>
                      setState(() => _surfaceType = v),
                  onKindChanged: (v) => setState(() => _kind = v),
                  onStart: () async {
                    final router = GoRouter.of(context);
                    final controller =
                        ref.read(realtimeControllerProvider.notifier);
                    final id = await controller.createSession(
                      surfaceType: _surfaceType,
                      surfaceId: _surfaceIdController.text.trim(),
                      kind: _kind,
                    );
                    if (!context.mounted) return;
                    router.go('/realtime/$id?action=join');
                  },
                ),
                const SizedBox(height: AuraSpace.s16),
                _JoinExistingCard(
                  controller: _existingSessionController,
                  onJoin: () {
                    final id = _existingSessionController.text.trim();
                    if (id.isEmpty) return;
                    context.go('/realtime/$id?action=join');
                  },
                  onResume: () {
                    final id = _existingSessionController.text.trim();
                    if (id.isEmpty) return;
                    context.go('/realtime/$id?action=resume');
                  },
                  onView: () {
                    final id = _existingSessionController.text.trim();
                    if (id.isEmpty) return;
                    context.go('/realtime/$id');
                  },
                ),
              ],
              if ((realtime.errorMessage ?? '').isNotEmpty) ...[
                const SizedBox(height: AuraSpace.s16),
                _StatusBanner(
                  message: realtime.errorMessage!,
                  isError: true,
                ),
              ],
              if ((realtime.infoMessage ?? '').isNotEmpty) ...[
                const SizedBox(height: AuraSpace.s16),
                _StatusBanner(message: realtime.infoMessage!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _LobbyHeader extends StatelessWidget {
  const _LobbyHeader({
    required this.surfaceType,
    required this.kind,
    required this.surfaceLabel,
    required this.kindLabel,
  });

  final String surfaceType;
  final String kind;
  final String Function(String) surfaceLabel;
  final String Function(String) kindLabel;

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
              const Text('Standalone live', style: AuraText.headline),
              const SizedBox(height: AuraSpace.s4),
              Text(
                'Start or join a live session outside of messages.',
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

class _LobbyAuthGate extends StatelessWidget {
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
            'You need an active member session before starting or joining live.',
            style: AuraText.body.copyWith(color: AuraSurface.muted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _StartLiveCard extends StatelessWidget {
  const _StartLiveCard({
    required this.surfaceType,
    required this.kind,
    required this.surfaceIdController,
    required this.isBusy,
    required this.surfaceLabel,
    required this.kindLabel,
    required this.onSurfaceTypeChanged,
    required this.onKindChanged,
    required this.onStart,
  });

  final String surfaceType;
  final String kind;
  final TextEditingController surfaceIdController;
  final bool isBusy;
  final String Function(String) surfaceLabel;
  final String Function(String) kindLabel;
  final ValueChanged<String> onSurfaceTypeChanged;
  final ValueChanged<String> onKindChanged;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s20,
              AuraSpace.s18,
              AuraSpace.s20,
              AuraSpace.s16,
            ),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AuraSurface.divider)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.play_circle_outline_rounded,
                  size: 20,
                  color: AuraSurface.accentText,
                ),
                const SizedBox(width: AuraSpace.s10),
                const Expanded(
                  child: Text('Start new live', style: AuraText.subtitle),
                ),
                if (isBusy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AuraSurface.accent,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AuraSpace.s20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose where this live session belongs and how it should open.',
                  style: AuraText.small.copyWith(
                    color: AuraSurface.muted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AuraSpace.s16),
                DropdownButtonFormField<String>(
                  initialValue: surfaceType,
                  decoration: const InputDecoration(
                    labelText: 'Live context',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'SPACE', child: Text('Space')),
                    DropdownMenuItem(
                      value: 'DM',
                      child: Text('Direct conversation'),
                    ),
                    DropdownMenuItem(
                      value: 'INSTITUTION_ROOM',
                      child: Text('Institution'),
                    ),
                    DropdownMenuItem(
                      value: 'EVENT_ROOM',
                      child: Text('Event'),
                    ),
                    DropdownMenuItem(value: 'THREAD', child: Text('Thread')),
                  ],
                  onChanged: (v) {
                    if (v != null) onSurfaceTypeChanged(v);
                  },
                ),
                const SizedBox(height: AuraSpace.s12),
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  decoration: const InputDecoration(
                    labelText: 'Live format',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'MIXED', child: Text('Mixed')),
                    DropdownMenuItem(value: 'AUDIO', child: Text('Audio')),
                    DropdownMenuItem(value: 'VIDEO', child: Text('Video')),
                    DropdownMenuItem(value: 'SCREEN', child: Text('Screen')),
                  ],
                  onChanged: (v) {
                    if (v != null) onKindChanged(v);
                  },
                ),
                const SizedBox(height: AuraSpace.s12),
                TextField(
                  controller: surfaceIdController,
                  decoration: InputDecoration(
                    labelText: '${surfaceLabel(surfaceType)} ID',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AuraSpace.s12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s12,
                    vertical: AuraSpace.s10,
                  ),
                  decoration: BoxDecoration(
                    color: AuraSurface.subtle,
                    borderRadius: BorderRadius.circular(AuraRadius.r12),
                    border: Border.all(color: AuraSurface.divider),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: AuraSurface.muted,
                      ),
                      const SizedBox(width: AuraSpace.s8),
                      Expanded(
                        child: Text(
                          'Opens as ${kindLabel(kind).toLowerCase()} in ${surfaceLabel(surfaceType).toLowerCase()}.',
                          style: AuraText.small.copyWith(
                            color: AuraSurface.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AuraSpace.s16),
                SizedBox(
                  width: double.infinity,
                  child: AuraPrimaryButton(
                    label: isBusy ? 'Starting…' : 'Start and join',
                    onPressed: isBusy ? null : onStart,
                    icon: isBusy ? null : Icons.play_arrow_rounded,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JoinExistingCard extends StatelessWidget {
  const _JoinExistingCard({
    required this.controller,
    required this.onJoin,
    required this.onResume,
    required this.onView,
  });

  final TextEditingController controller;
  final VoidCallback onJoin;
  final VoidCallback onResume;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s20,
              AuraSpace.s18,
              AuraSpace.s20,
              AuraSpace.s16,
            ),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AuraSurface.divider)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.meeting_room_outlined,
                  size: 20,
                  color: AuraSurface.muted,
                ),
                SizedBox(width: AuraSpace.s10),
                Expanded(
                  child: Text('Open existing live', style: AuraText.subtitle),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AuraSpace.s20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Use a live session ID to join, reopen, or inspect the current state.',
                  style: AuraText.small.copyWith(
                    color: AuraSurface.muted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AuraSpace.s16),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Live session ID',
                    border: OutlineInputBorder(),
                    hintText: 'Paste session ID here',
                  ),
                ),
                const SizedBox(height: AuraSpace.s16),
                Wrap(
                  spacing: AuraSpace.s8,
                  runSpacing: AuraSpace.s8,
                  children: [
                    AuraPrimaryButton(
                      label: 'Join',
                      onPressed: onJoin,
                      icon: Icons.login_rounded,
                    ),
                    AuraSecondaryButton(
                      label: 'Reopen',
                      onPressed: onResume,
                      icon: Icons.refresh_rounded,
                    ),
                    AuraGhostButton(
                      label: 'View only',
                      onPressed: onView,
                      icon: Icons.visibility_outlined,
                    ),
                  ],
                ),
              ],
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
