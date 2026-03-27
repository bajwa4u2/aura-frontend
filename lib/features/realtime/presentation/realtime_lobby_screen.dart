import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_card.dart';
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
          Text('Live rooms', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'Start a room, enter an existing one, or reopen a room you already joined.',
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
                    'You need an active member session before entering a live room.',
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
                    'Start live room',
                    style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AuraSpace.s8),
                  Text(
                    'Choose where this room belongs and how it will open.',
                    style: AuraText.muted,
                  ),
                  const SizedBox(height: AuraSpace.s12),
                  DropdownButtonFormField<String>(
                    initialValue: _surfaceType,
                    decoration: const InputDecoration(
                      labelText: 'Room context',
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
                    'This room will open as ${_kindLabel(_kind).toLowerCase()} in ${_surfaceLabel(_surfaceType).toLowerCase()}.',
                    style: AuraText.small,
                  ),
                  const SizedBox(height: AuraSpace.s12),
                  FilledButton(
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
                    child: const Text('Start and enter'),
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
                    'Open existing room',
                    style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AuraSpace.s8),
                  Text(
                    'Use a room id to enter, reopen, or inspect the current room state.',
                    style: AuraText.muted,
                  ),
                  const SizedBox(height: AuraSpace.s12),
                  TextField(
                    controller: _existingSessionController,
                    decoration: const InputDecoration(
                      labelText: 'Room id',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s12),
                  Wrap(
                    spacing: AuraSpace.s8,
                    runSpacing: AuraSpace.s8,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          final id = _existingSessionController.text.trim();
                          if (id.isEmpty) return;
                          context.go('/realtime/$id?action=join');
                        },
                        child: const Text('Enter room'),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          final id = _existingSessionController.text.trim();
                          if (id.isEmpty) return;
                          context.go('/realtime/$id?action=resume');
                        },
                        child: const Text('Reopen room'),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          final id = _existingSessionController.text.trim();
                          if (id.isEmpty) return;
                          context.go('/realtime/$id');
                        },
                        child: const Text('View room'),
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
