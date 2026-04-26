import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../application/realtime_providers.dart';

class RealtimeLobbyScreen extends ConsumerStatefulWidget {
  const RealtimeLobbyScreen({super.key});

  @override
  ConsumerState<RealtimeLobbyScreen> createState() => _RealtimeLobbyScreenState();
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text('Standalone live', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'Use this only for truly standalone live. Correspondence-owned live should be opened from its conversation or space.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s16),
          if (authStatus != AuthStatus.authed)
            AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sign in required',
                    style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AuraSpace.s8),
                  Text(
                    'You need an active member session before joining live.',
                    style: AuraText.muted,
                  ),
                ],
              ),
            )
          else ...[
            AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Start standalone live',
                    style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AuraSpace.s8),
                  Text(
                    'Choose where this live session belongs and how it should open.',
                    style: AuraText.muted,
                  ),
                  const SizedBox(height: AuraSpace.s12),
                  DropdownButtonFormField<String>(
                    initialValue: _surfaceType,
                    decoration: const InputDecoration(
                      labelText: 'Live context',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'SPACE', child: Text('Space')),
                      DropdownMenuItem(value: 'DM', child: Text('Direct conversation')),
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
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _surfaceType = value);
                    },
                  ),
                  const SizedBox(height: AuraSpace.s12),
                  DropdownButtonFormField<String>(
                    initialValue: _kind,
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
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _kind = value);
                    },
                  ),
                  const SizedBox(height: AuraSpace.s12),
                  TextField(
                    controller: _surfaceIdController,
                    decoration: InputDecoration(
                      labelText: '${_surfaceLabel(_surfaceType)} id',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s12),
                  Text(
                    'This live session will open as ${_kindLabel(_kind).toLowerCase()} in ${_surfaceLabel(_surfaceType).toLowerCase()}.',
                    style: AuraText.small,
                  ),
                  const SizedBox(height: AuraSpace.s12),
                  AuraPrimaryButton(
                    label: 'Start and join',
                    onPressed: realtime.isBusy
                        ? null
                        : () async {
                            final router = GoRouter.of(context);
                            final controller = ref.read(realtimeControllerProvider.notifier);
                            final id = await controller.createSession(
                              surfaceType: _surfaceType,
                              surfaceId: _surfaceIdController.text.trim(),
                              kind: _kind,
                            );
                            if (!context.mounted) return;
                            router.go('/realtime/$id?action=join');
                          },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AuraSpace.s12),
            AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Open existing live',
                    style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AuraSpace.s8),
                  Text(
                    'Use a live session id to join, reopen, or inspect the current state.',
                    style: AuraText.muted,
                  ),
                  const SizedBox(height: AuraSpace.s12),
                  TextField(
                    controller: _existingSessionController,
                    decoration: const InputDecoration(
                      labelText: 'Live session id',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s12),
                  Wrap(
                    spacing: AuraSpace.s8,
                    runSpacing: AuraSpace.s8,
                    children: [
                      AuraSecondaryButton(
                        label: 'Join live',
                        onPressed: () {
                          final id = _existingSessionController.text.trim();
                          if (id.isEmpty) return;
                          context.go('/realtime/$id?action=join');
                        },
                      ),
                      AuraSecondaryButton(
                        label: 'Reopen live',
                        onPressed: () {
                          final id = _existingSessionController.text.trim();
                          if (id.isEmpty) return;
                          context.go('/realtime/$id?action=resume');
                        },
                      ),
                      AuraSecondaryButton(
                        label: 'View live',
                        onPressed: () {
                          final id = _existingSessionController.text.trim();
                          if (id.isEmpty) return;
                          context.go('/realtime/$id');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if ((realtime.errorMessage ?? '').isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s12),
            AuraCard(
              child: Text(realtime.errorMessage!, style: AuraText.body),
            ),
          ],
          if ((realtime.infoMessage ?? '').isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s12),
            AuraCard(
              child: Text(realtime.infoMessage!, style: AuraText.body),
            ),
          ],
        ],
      ),
    );
  }
}
