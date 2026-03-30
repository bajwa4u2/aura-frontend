import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/aura_text_block.dart';
import '../data/messages_repository.dart';
import '../data/threads_repository.dart';
import '../data/correspondence_identity.dart';
import '../data/correspondence_live_service.dart';
import '../../realtime/application/realtime_providers.dart';
import '../../realtime/domain/realtime_state.dart';

final _threadOpenProvider = FutureProvider.family<void, String>((
  ref,
  threadId,
) async {
  final repo = ref.watch(threadsRepositoryProvider);
  try {
    await repo.markThreadRead(threadId);
  } catch (_) {
    // best-effort
  }
});

final _threadDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, threadId) async {
  final repo = ref.watch(threadsRepositoryProvider);
  return repo.getThread(threadId);
});

final _messagesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      threadId,
    ) async {
      final repo = ref.watch(messagesRepositoryProvider);
      return repo.listMessages(threadId: threadId);
    });

final _currentUserProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/users/me');
  return _unwrapResponseMap(res.data);
});

const Map<String, String> _translationLanguageLabels = {
  'en': 'English',
  'ur': 'Urdu',
  'ar': 'Arabic',
  'es': 'Spanish',
  'fr': 'French',
  'de': 'German',
  'it': 'Italian',
  'pt': 'Portuguese',
  'tr': 'Turkish',
  'fa': 'Persian',
  'hi': 'Hindi',
  'bn': 'Bengali',
  'zh': 'Chinese',
  'ja': 'Japanese',
  'ko': 'Korean',
  'ru': 'Russian',
};

String _languageLabel(String code) {
  final key = code.trim().toLowerCase();
  return _translationLanguageLabels[key] ?? key.toUpperCase();
}

String _defaultTranslationLanguage(BuildContext context) {
  final code = Localizations.localeOf(context).languageCode.trim().toLowerCase();
  if (_translationLanguageLabels.containsKey(code)) return code;
  return 'en';
}

bool _hasRtlScript(String text) {
  final value = text.trim();
  if (value.isEmpty) return false;
  final rtl = RegExp(r'[\u0590-\u05FF\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
  return rtl.hasMatch(value);
}

TextDirection _directionForText(String text) {
  return _hasRtlScript(text) ? TextDirection.rtl : TextDirection.ltr;
}

TextAlign _alignForText(String text) {
  return _hasRtlScript(text) ? TextAlign.right : TextAlign.left;
}

class ThreadScreen extends ConsumerStatefulWidget {
  const ThreadScreen({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends ConsumerState<ThreadScreen> {
  Timer? _pollTimer;
  StreamSubscription<CorrespondenceLiveEvent>? _liveSubscription;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      ref.invalidate(_threadDetailProvider(widget.threadId));
      ref.invalidate(_messagesProvider(widget.threadId));
    });

    Future.microtask(() async {
      final live = ref.read(correspondenceLiveServiceProvider);
      await live.joinThread(widget.threadId);
      _liveSubscription = live.events.listen((event) {
        if (!mounted) return;
        if (event.matchesThread(widget.threadId) || event.name.startsWith('invite:') || event.name.startsWith('space:member.')) {
          ref.invalidate(_threadDetailProvider(widget.threadId));
          ref.invalidate(_messagesProvider(widget.threadId));
        }
      });
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    unawaited(ref.read(correspondenceLiveServiceProvider).leaveThread(widget.threadId));
    _liveSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final threadId = widget.threadId;

    ref.watch(_threadOpenProvider(threadId));

    final threadAsync = ref.watch(_threadDetailProvider(threadId));
    final messagesAsync = ref.watch(_messagesProvider(threadId));
    final meAsync = ref.watch(_currentUserProvider);
    final liveState = ref.watch(realtimeControllerProvider);

    return AuraScaffold(
      title: threadAsync.maybeWhen(
        data: (thread) => _threadScreenTitle(thread),
        orElse: () => 'Conversation',
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(_threadOpenProvider(threadId));
                ref.invalidate(_threadDetailProvider(threadId));
                ref.invalidate(_messagesProvider(threadId));
                ref.invalidate(_currentUserProvider);
                await Future.wait([
                  ref.read(_threadOpenProvider(threadId).future),
                  ref.read(_threadDetailProvider(threadId).future),
                  ref.read(_messagesProvider(threadId).future),
                  ref.read(_currentUserProvider.future),
                ]);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  threadAsync.when(
                    loading: () => const AuraCard(
                      child: _LoadingBlock(label: 'Loading thread...'),
                    ),
                    error: (error, _) => AuraCard(
                      child: _ErrorBlock(
                        title: 'Could not load thread',
                        body: '$error',
                        onRetry: () =>
                            ref.invalidate(_threadDetailProvider(threadId)),
                      ),
                    ),
                    data: (thread) => _ThreadHeaderCard(
                      thread: thread,
                      liveState: liveState,
                      onOpenSpace: () {
                        final spaceId = _pickString(thread, const ['spaceId', 'space_id']);
                        if (spaceId.isEmpty) return;
                        context.push('/me/correspondence/$spaceId');
                      },
                      onInvite: () async {
                        final spaceId = _pickString(thread, const ['spaceId', 'space_id']);
                        if (spaceId.isEmpty) return;
                        await context.push(
                          '/invite/create?destinationType=JOIN_SPACE'
                          '&spaceId=${Uri.encodeComponent(spaceId)}'
                          '&threadId=${Uri.encodeComponent(threadId)}'
                          '&returnTo=${Uri.encodeComponent('/me/correspondence/$spaceId/thread/$threadId')}',
                        );
                        if (!context.mounted) return;
                        ref.invalidate(_threadDetailProvider(widget.threadId));
                        ref.invalidate(_messagesProvider(widget.threadId));
                      },
                      onStartAudio: () async {
                        final controller = ref.read(realtimeControllerProvider.notifier);
                        await controller.ensureCorrespondenceLive(
                          surfaceType: _threadLiveSurfaceType(thread),
                          surfaceId: _threadLiveSurfaceId(thread, widget.threadId),
                          kind: 'AUDIO',
                          metadata: <String, dynamic>{
                            'threadId': widget.threadId,
                            'spaceId': _pickString(thread, const ['spaceId', 'space_id']),
                          }..removeWhere((key, value) => value == null || value.toString().trim().isEmpty),
                        );
                      },
                      onStartVideo: () async {
                        final controller = ref.read(realtimeControllerProvider.notifier);
                        await controller.ensureCorrespondenceLive(
                          surfaceType: _threadLiveSurfaceType(thread),
                          surfaceId: _threadLiveSurfaceId(thread, widget.threadId),
                          kind: 'VIDEO',
                          metadata: <String, dynamic>{
                            'threadId': widget.threadId,
                            'spaceId': _pickString(thread, const ['spaceId', 'space_id']),
                          }..removeWhere((key, value) => value == null || value.toString().trim().isEmpty),
                        );
                      },
                      onJoinLive: () async {
                        final sessionId = (liveState.sessionId ?? liveState.session?.id ?? '').trim();
                        if (sessionId.isEmpty) return;
                        final controller = ref.read(realtimeControllerProvider.notifier);
                        await controller.join(sessionId);
                      },
                      onLeaveLive: () async {
                        await ref.read(realtimeControllerProvider.notifier).leave();
                      },
                      onToggleMicrophone: () async {
                        await ref.read(realtimeControllerProvider.notifier).toggleMicrophone();
                      },
                      onToggleCamera: () async {
                        await ref.read(realtimeControllerProvider.notifier).toggleCamera();
                      },
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s16),
                  Text('Messages', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s10),
                  messagesAsync.when(
                    loading: () => const AuraCard(
                      child: _LoadingBlock(label: 'Loading messages...'),
                    ),
                    error: (error, _) => AuraCard(
                      child: _ErrorBlock(
                        title: 'Could not load messages',
                        body: '$error',
                        onRetry: () =>
                            ref.invalidate(_messagesProvider(threadId)),
                      ),
                    ),
                    data: (messages) {
                      if (messages.isEmpty) {
                        return const AuraCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('No messages yet', style: AuraText.title),
                              SizedBox(height: AuraSpace.s8),
                              Text(
                                'Nothing has been said here yet.',
                                style: AuraText.body,
                              ),
                            ],
                          ),
                        );
                      }

                      final currentUserId = meAsync.maybeWhen(
                        data: (me) => _pickString(
                          me,
                          const ['id', '_id', 'userId'],
                        ),
                        orElse: () => '',
                      );

                      return Column(
                        children: [
                          for (var i = 0; i < messages.length; i++) ...[
                            _MessageTile(
                              message: messages[i],
                              currentUserId: currentUserId,
                              showAuthorHeader:
                                  !_isSameSender(
                                    messages[i],
                                    i > 0 ? messages[i - 1] : null,
                                  ),
                              onEdit: () => _showEditMessageDialog(
                                context,
                                ref,
                                messages[i],
                              ),
                              onDelete: () async {
                                final messageId = _pickString(
                                  messages[i],
                                  const ['id', 'messageId'],
                                );
                                if (messageId.isEmpty) return;
                                await ref
                                    .read(messagesRepositoryProvider)
                                    .deleteMessage(messageId);
                                ref.invalidate(_threadDetailProvider(widget.threadId));
                                ref.invalidate(_messagesProvider(widget.threadId));
                              },
                            ),
                            if (i != messages.length - 1)
                              const SizedBox(height: AuraSpace.s10),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          _ComposerBar(
            threadId: threadId,
            onSent: () {
              ref.invalidate(_threadDetailProvider(widget.threadId));
              ref.invalidate(_messagesProvider(widget.threadId));
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showEditMessageDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> message,
  ) async {
    final edited = await showDialog<bool>(
      context: context,
      builder: (_) => _EditMessageDialog(message: message),
    );

    if (edited == true) {
      ref.invalidate(_threadDetailProvider(widget.threadId));
      ref.invalidate(_messagesProvider(widget.threadId));
    }
  }
}

class _ThreadHeaderCard extends StatelessWidget {
  const _ThreadHeaderCard({
    required this.thread,
    required this.liveState,
    required this.onOpenSpace,
    required this.onInvite,
    required this.onStartAudio,
    required this.onStartVideo,
    required this.onJoinLive,
    required this.onLeaveLive,
    required this.onToggleMicrophone,
    required this.onToggleCamera,
  });

  final Map<String, dynamic> thread;
  final RealtimeState liveState;
  final VoidCallback onOpenSpace;
  final VoidCallback onInvite;
  final Future<void> Function() onStartAudio;
  final Future<void> Function() onStartVideo;
  final Future<void> Function() onJoinLive;
  final Future<void> Function() onLeaveLive;
  final Future<void> Function() onToggleMicrophone;
  final Future<void> Function() onToggleCamera;

  @override
  Widget build(BuildContext context) {
    final title = _threadScreenTitle(thread);
    final kind = _pickString(thread, const ['kind', 'type']);
    final archived =
        thread['archived'] == true || thread['archivedAt'] != null;
    final description = _pickString(
      thread,
      const ['description', 'summary', 'subtitle'],
    );
    final spaceId = _pickString(thread, const ['spaceId', 'space_id']);
    final participants = _extractParticipants(thread);
    final participantSummary = _participantSummary(participants);
    final roles = _participantRoleSummary(participants);
    final recentWeight = _threadRecentWeight(thread);

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Conversation',
            style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IdentityAvatar(
                label: title,
                imageUrl: _threadAvatarUrl(thread),
                radius: 22,
              ),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AuraSpace.s8,
                      runSpacing: AuraSpace.s8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(title, style: AuraText.title),
                        if (kind.isNotEmpty) _Pill(label: _humanizeLabel(kind)),
                        if (archived) _StatusPill(label: 'Archived', tone: _StatusTone.neutral),
                        if (recentWeight.isNotEmpty) _StatusPill(label: recentWeight, tone: _StatusTone.accent),
                      ],
                    ),
                    if (participantSummary.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s6),
                      AuraTextBlock(
                        participantSummary,
                        style: AuraText.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (roles.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s4),
                      AuraTextBlock(
                        roles,
                        style: AuraText.small.copyWith(color: Colors.black54),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s8),
                      Text(description, style: AuraText.body),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s12),
          _ThreadLiveDock(
            thread: thread,
            liveState: liveState,
            onStartAudio: onStartAudio,
            onStartVideo: onStartVideo,
            onJoinLive: onJoinLive,
            onLeaveLive: onLeaveLive,
            onToggleMicrophone: onToggleMicrophone,
            onToggleCamera: onToggleCamera,
          ),
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              if (spaceId.isNotEmpty)
                OutlinedButton(
                  onPressed: onOpenSpace,
                  child: const Text('Open space'),
                ),
              OutlinedButton(
                onPressed: onInvite,
                child: const Text('Add member'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _threadScreenTitle(Map<String, dynamic> thread) {
  return CorrespondenceIdentity.threadTitle(thread);
}

List<Map<String, dynamic>> _extractParticipants(Map<String, dynamic> thread) {
  return CorrespondenceIdentity.extractParticipants(thread);
}

String _participantSummary(List<Map<String, dynamic>> participants) {
  return CorrespondenceIdentity.threadParticipantSummaryFromParticipants(participants);
}

String _participantRoleSummary(List<Map<String, dynamic>> participants) {
  final thread = <String, dynamic>{'participants': participants};
  return CorrespondenceIdentity.threadParticipantRoleSummary(thread);
}

String _threadPreview(Map<String, dynamic> thread) {
  return CorrespondenceIdentity.threadPreview(thread);
}

String _threadRecentWeight(Map<String, dynamic> thread) {
  return CorrespondenceIdentity.threadRecentWeight(thread);
}

String _identityLabel(Map<String, dynamic> entity) {
  return CorrespondenceIdentity.identityLabel(entity);
}

String _identityLine(Map<String, dynamic> entity, {bool preferHandle = true}) {
  return CorrespondenceIdentity.identityLine(entity, preferHandle: preferHandle);
}

String _threadAvatarUrl(Map<String, dynamic> thread) {
  return CorrespondenceIdentity.threadAvatarUrl(thread);
}

String _humanizeLabel(String value) {
  return CorrespondenceIdentity.humanize(value);
}


String _threadLiveSurfaceType(Map<String, dynamic> thread) {
  final spaceId = _pickString(thread, const ['spaceId', 'space_id']);
  if (spaceId.isNotEmpty) return 'SPACE';
  return 'DM';
}

String _threadLiveSurfaceId(Map<String, dynamic> thread, String threadId) {
  final spaceId = _pickString(thread, const ['spaceId', 'space_id']);
  if (spaceId.isNotEmpty) return spaceId;
  return threadId;
}

bool _threadMatchesLiveState(RealtimeState liveState, Map<String, dynamic> thread) {
  final session = liveState.session;
  if (session == null) return false;
  final expectedType = _threadLiveSurfaceType(thread).trim().toLowerCase();
  final expectedId = _threadLiveSurfaceId(
    thread,
    _pickString(thread, const ['id', 'threadId']),
  ).trim();
  return session.surfaceType.name.trim().toLowerCase() == expectedType &&
      (session.surfaceId ?? '').trim() == expectedId;
}

class _ThreadLiveDock extends StatelessWidget {
  const _ThreadLiveDock({
    required this.thread,
    required this.liveState,
    required this.onStartAudio,
    required this.onStartVideo,
    required this.onJoinLive,
    required this.onLeaveLive,
    required this.onToggleMicrophone,
    required this.onToggleCamera,
  });

  final Map<String, dynamic> thread;
  final RealtimeState liveState;
  final Future<void> Function() onStartAudio;
  final Future<void> Function() onStartVideo;
  final Future<void> Function() onJoinLive;
  final Future<void> Function() onLeaveLive;
  final Future<void> Function() onToggleMicrophone;
  final Future<void> Function() onToggleCamera;

  @override
  Widget build(BuildContext context) {
    final belongsHere = _threadMatchesLiveState(liveState, thread);
    final hasLive = belongsHere &&
        ((liveState.sessionId ?? liveState.session?.id ?? '').trim().isNotEmpty);
    final participantCount = belongsHere ? liveState.participants.length : 0;
    final joinedCount = belongsHere
        ? liveState.participants.where((p) => p.isPresent).length
        : 0;
    final statusLabel = !hasLive
        ? 'Not live'
        : liveState.isJoined
            ? 'Live now'
            : 'Live available';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AuraSpace.s12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.wifi_tethering_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: AuraSpace.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Live in this conversation', style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: AuraSpace.s4),
                    Text(
                      hasLive
                          ? '$statusLabel • $joinedCount joined${participantCount > joinedCount ? ' • $participantCount listed' : ''}'
                          : 'Start audio or video without leaving the thread.',
                      style: AuraText.small.copyWith(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              if (hasLive)
                _StatusPill(
                  label: statusLabel,
                  tone: liveState.isJoined ? _StatusTone.positive : _StatusTone.accent,
                ),
            ],
          ),
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              FilledButton.icon(
                onPressed: liveState.isBusy ? null : () => onStartAudio(),
                icon: const Icon(Icons.call_outlined),
                label: Text(hasLive ? 'Restart audio' : 'Audio call'),
              ),
              FilledButton.icon(
                onPressed: liveState.isBusy ? null : () => onStartVideo(),
                icon: const Icon(Icons.videocam_outlined),
                label: Text(hasLive ? 'Restart video' : 'Video call'),
              ),
              if (hasLive && !liveState.isJoined)
                OutlinedButton.icon(
                  onPressed: liveState.isBusy ? null : () => onJoinLive(),
                  icon: const Icon(Icons.login),
                  label: const Text('Join live'),
                ),
              if (hasLive && liveState.isJoined)
                OutlinedButton.icon(
                  onPressed: () => onLeaveLive(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Leave'),
                ),
              if (hasLive && liveState.isJoined)
                OutlinedButton.icon(
                  onPressed: () => onToggleMicrophone(),
                  icon: Icon(liveState.microphoneEnabled ? Icons.mic_off_outlined : Icons.mic_outlined),
                  label: Text(liveState.microphoneEnabled ? 'Mute' : 'Unmute'),
                ),
              if (hasLive && liveState.isJoined)
                OutlinedButton.icon(
                  onPressed: () => onToggleCamera(),
                  icon: Icon(liveState.cameraEnabled ? Icons.videocam_off_outlined : Icons.videocam_outlined),
                  label: Text(liveState.cameraEnabled ? 'Camera off' : 'Camera on'),
                ),
            ],
          ),
          if (hasLive && (liveState.infoMessage ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s10),
            Text(liveState.infoMessage!.trim(), style: AuraText.small.copyWith(color: Colors.black54)),
          ],
          if (hasLive && (liveState.errorMessage ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s8),
            Text(liveState.errorMessage!.trim(), style: AuraText.small.copyWith(color: Colors.red.shade700)),
          ],
        ],
      ),
    );
  }
}

class _IdentityAvatar extends StatelessWidget {
  const _IdentityAvatar({required this.label, this.imageUrl = '', this.radius = 20});

  final String label;
  final String imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(label);
    if (imageUrl.trim().isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(imageUrl.trim()));
    }
    return CircleAvatar(
      radius: radius,
      child: Text(initials, style: AuraText.small.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

enum _StatusTone { neutral, accent, positive, negative }

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.tone});

  final String label;
  final _StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = switch (tone) {
      _StatusTone.positive => (border: Colors.green.shade200, text: Colors.green.shade800, fill: Colors.green.shade50),
      _StatusTone.negative => (border: Colors.red.shade200, text: Colors.red.shade800, fill: Colors.red.shade50),
      _StatusTone.accent => (border: Colors.blue.shade200, text: Colors.blue.shade800, fill: Colors.blue.shade50),
      _StatusTone.neutral => (border: Colors.black12, text: Colors.black87, fill: Colors.transparent),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s10, vertical: AuraSpace.s6),
      decoration: BoxDecoration(
        color: palette.fill,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: AuraText.small.copyWith(fontWeight: FontWeight.w700, color: palette.text)),
    );
  }
}

String _truncateLabel(String value, {int max = 48}) {
  final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.length <= max) return text;
  return '${text.substring(0, max - 1).trimRight()}…';
}

String _pickNested(Map<String, dynamic> map, List<List<String>> paths) {
  for (final path in paths) {
    dynamic current = map;
    for (final key in path) {
      if (current is! Map) {
        current = null;
        break;
      }
      current = current[key];
    }
    final text = (current ?? '').toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList(growable: false);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

class _ComposerBar extends ConsumerStatefulWidget {
  const _ComposerBar({
    required this.threadId,
    required this.onSent,
  });

  final String threadId;
  final VoidCallback onSent;

  @override
  ConsumerState<_ComposerBar> createState() => _ComposerBarState();
}

class _ComposerBarState extends ConsumerState<_ComposerBar> {
  final _controller = TextEditingController();
  final _audioRecorder = AudioRecorder();
  final _picker = ImagePicker();

  final List<_DraftAttachment> _attachments = [];
  final Set<String> _dismissedSuggestionIds = <String>{};
  final Set<String> _applyingSuggestionIds = <String>{};

  bool _sending = false;
  bool _recordingAudio = false;
  bool _assistBusy = false;
  String? _assistError;
  String? _assistSessionId;
  String? _assistSnapshot;
  List<Map<String, dynamic>> _suggestions = const [];

  bool _translationBusy = false;
  String? _translationError;
  String? _translationPreview;
  String? _translationSnapshot;
  String _translationTargetLanguage = 'ur';

  @override
  void dispose() {
    _controller.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  bool get _canSend {
    if (_sending) return false;
    if (_attachments.any((a) => a.uploading)) return false;
    return _controller.text.trim().isNotEmpty || _attachments.isNotEmpty;
  }

  bool get _hasText => _controller.text.trim().isNotEmpty;

  List<Map<String, dynamic>> get _visibleSuggestions {
    final out = <Map<String, dynamic>>[];
    for (final suggestion in _suggestions) {
      final id = _firstNonEmpty(suggestion, const ['id', 'findingId']);
      if (id.isNotEmpty && _dismissedSuggestionIds.contains(id)) continue;
      out.add(suggestion);
      if (out.length >= 2) break;
    }
    return out;
  }

  Future<void> _pickImageFromGallery() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    await _addAttachment(file, kind: _AttachmentKind.image);
  }

  Future<void> _pickImageFromCamera() async {
    final file = await _picker.pickImage(source: ImageSource.camera);
    if (file == null) return;
    await _addAttachment(
      file,
      kind: _AttachmentKind.image,
      source: _AttachmentSource.camera,
    );
  }

  Future<void> _pickVideoFromGallery() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    await _addAttachment(file, kind: _AttachmentKind.video);
  }

  Future<void> _pickVideoFromCamera() async {
    final file = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 60),
    );
    if (file == null) return;
    await _addAttachment(
      file,
      kind: _AttachmentKind.video,
      source: _AttachmentSource.camera,
    );
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.audio,
    );
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.single;
    if (picked.bytes == null || picked.bytes!.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read selected audio file.')),
      );
      return;
    }

    final file = XFile.fromData(
      picked.bytes!,
      name: picked.name,
      mimeType: _inferMime(picked.name),
    );

    await _addAttachment(
      file,
      kind: _AttachmentKind.audio,
      source: _AttachmentSource.upload,
    );
  }

  Future<void> _toggleAudioRecording() async {
    if (_sending) return;

    if (_recordingAudio) {
      final path = await _audioRecorder.stop();
      if (!mounted) return;

      setState(() => _recordingAudio = false);

      if (path == null || path.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save audio recording.')),
        );
        return;
      }

      final file = XFile(path, mimeType: 'audio/aac');
      await _addAttachment(
        file,
        kind: _AttachmentKind.audio,
        source: _AttachmentSource.recording,
      );
      return;
    }

    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required.')),
      );
      return;
    }

    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: 'aura_msg_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );

    if (!mounted) return;
    setState(() => _recordingAudio = true);
  }

  Future<void> _addAttachment(
    XFile file, {
    required _AttachmentKind kind,
    _AttachmentSource source = _AttachmentSource.gallery,
  }) async {
    final bytes = await file.readAsBytes();

    int? width;
    int? height;

    if (kind == _AttachmentKind.image) {
      try {
        final size = await _decodeImageSize(bytes);
        width = size?['width'];
        height = size?['height'];
      } catch (_) {}
    }

    final attachment = _DraftAttachment(
      localId: '${DateTime.now().microsecondsSinceEpoch}_${file.name}',
      file: file,
      bytes: bytes,
      kind: kind,
      source: source,
      width: width,
      height: height,
      mimeType: file.mimeType ?? _inferMime(file.name),
      sizeBytes: bytes.length,
      uploading: true,
    );

    setState(() {
      _attachments.add(attachment);
    });

    try {
      await _uploadAttachment(attachment);
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        attachment.uploading = false;
        attachment.error = '$e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not upload attachment: $e')),
      );
    }
  }

  Future<void> _uploadAttachment(_DraftAttachment attachment) async {
    final dio = ref.read(dioProvider);
    final mime = attachment.mimeType;

    final pres = await dio.post(
      '/media/presign',
      data: {
        'fileName': attachment.file.name,
        'mimeType': mime,
        'bytes': attachment.sizeBytes,
        'kind': _mediaKindValue(attachment.kind),
        'source': _mediaSourceValue(attachment.source),
        if (attachment.width != null) 'width': attachment.width,
        if (attachment.height != null) 'height': attachment.height,
      },
    );

    final presigned = _unwrapDataMap(pres.data);
    final mediaMap = _asMap(presigned['media']);
    final upload = _asMap(presigned['upload']);
    final uploadUrl = _str(upload['url']);
    final headers = _asMap(upload['headers']);

    if (uploadUrl.isEmpty) {
      throw Exception('Upload URL missing from presign response.');
    }

    final uploadHeaders = <String, String>{};
    headers.forEach((k, v) {
      if (v == null) return;
      uploadHeaders[k.toString()] = v.toString();
    });
    if (!uploadHeaders.containsKey('Content-Type')) {
      uploadHeaders['Content-Type'] = mime;
    }

    final uploadDio = _cleanUploadDio();
    await uploadDio.put(
      uploadUrl,
      data: attachment.bytes,
      options: Options(
        headers: uploadHeaders,
        contentType: uploadHeaders['Content-Type'],
        responseType: ResponseType.plain,
        followRedirects: true,
        validateStatus: (code) => code != null && code >= 200 && code < 300,
      ),
    );

    final mediaId = _firstNonEmpty(mediaMap, const ['id', 'mediaId']);
    if (mediaId.isNotEmpty) {
      await dio.post('/media/$mediaId/confirm');
      await dio.post('/media/$mediaId/ready');

      final patch = await dio.patch(
        '/media/$mediaId',
        data: {
          if (attachment.width != null) 'width': attachment.width,
          if (attachment.height != null) 'height': attachment.height,
          'editDisclosure': false,
        },
      );

      final patched = _unwrapDataMap(patch.data);

      attachment.url = _firstNonEmpty(
        patched,
        const [
          'displayUrl',
          'url',
          'publicUrl',
          'signedUrl',
          'sourceUrl',
          'fileUrl',
        ],
      );
      attachment.thumbUrl = _firstNonEmpty(
        patched,
        const [
          'thumbnailUrl',
          'thumbUrl',
          'previewUrl',
          'displayUrl',
          'url',
        ],
      );

      attachment.storageKey = _firstNonEmpty(patched, const [
        'storageKey',
        'objectKey',
        'key',
        'path',
      ]);

      if (attachment.storageKey.isEmpty) {
        attachment.storageKey = _firstNonEmpty(mediaMap, const [
          'storageKey',
          'objectKey',
          'key',
          'path',
        ]);
      }
    }

    if (attachment.storageKey.isEmpty) {
      attachment.storageKey = _firstNonEmpty(upload, const [
        'objectKey',
        'storageKey',
        'key',
        'path',
      ]);
    }

    if (attachment.storageKey.isEmpty) {
      attachment.storageKey = _firstNonEmpty(presigned, const [
        'storageKey',
        'objectKey',
        'key',
        'path',
      ]);
    }

    if (attachment.storageKey.isEmpty) {
      throw Exception(
        'Storage key missing from upload response. Message attachment cannot be finalized yet.',
      );
    }

    attachment.uploading = false;
    attachment.error = null;
  }

  Future<void> _runAssist() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _assistBusy) return;

    setState(() {
      _assistBusy = true;
      _assistError = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post(
        '/v1/composition/review',
        data: {
          'text': text,
          'surface': 'dm',
        },
      );

      final root = _unwrapDataMap(res.data);
      final findings = _extractFindings(root);
      final sessionId = _pickDeepString(root, const [
        ['sessionId'],
        ['review', 'sessionId'],
        ['data', 'sessionId'],
        ['session', 'id'],
      ]);

      if (!mounted) return;
      setState(() {
        _assistBusy = false;
        _assistSessionId = sessionId;
        _assistSnapshot = text;
        _suggestions = findings;
        _dismissedSuggestionIds.clear();
        _assistError = findings.isEmpty ? 'Nothing urgent to revise.' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _assistBusy = false;
        _assistError = 'Could not review this draft right now.';
      });
    }
  }

  Future<void> _applySuggestion(Map<String, dynamic> suggestion) async {
    final suggestionId = _firstNonEmpty(suggestion, const ['id', 'findingId']);
    final sessionId = (_assistSessionId ?? '').trim();
    if (suggestionId.isEmpty || sessionId.isEmpty) return;

    setState(() {
      _applyingSuggestionIds.add(suggestionId);
      _assistError = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final currentText = _controller.text;
      final res = await dio.post(
        '/v1/composition/apply',
        data: {
          'sessionId': sessionId,
          'findingId': suggestionId,
          'currentText': currentText,
        },
      );

      final root = _unwrapDataMap(res.data);
      final nextText = _pickDeepString(root, const [
        ['text'],
        ['updatedText'],
        ['data', 'text'],
        ['data', 'updatedText'],
        ['result', 'text'],
      ], fallback: currentText);

      final selection = TextSelection.collapsed(offset: nextText.length);
      _controller.value = TextEditingValue(
        text: nextText,
        selection: selection,
        composing: TextRange.empty,
      );

      final findings = _extractFindings(root);

      if (!mounted) return;
      setState(() {
        _assistSnapshot = nextText;
        _suggestions = findings.isNotEmpty ? findings : _suggestions.where((item) {
          final id = _firstNonEmpty(item, const ['id', 'findingId']);
          return id != suggestionId;
        }).toList();
        _dismissedSuggestionIds.remove(suggestionId);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _assistError = 'Could not apply that suggestion.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _applyingSuggestionIds.remove(suggestionId);
        });
      }
    }
  }

  Future<void> _translateDraft() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _translationBusy) return;

    setState(() {
      _translationBusy = true;
      _translationError = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post(
        '/v1/composition/translate',
        data: {
          'text': text,
          'targetLanguage': _translationTargetLanguage,
        },
      );

      final root = _unwrapDataMap(res.data);
      final translatedText = _pickDeepString(root, const [
        ['translatedText'],
        ['translation', 'text'],
        ['data', 'translatedText'],
        ['data', 'text'],
      ]);

      if (!mounted) return;
      setState(() {
        _translationBusy = false;
        _translationSnapshot = text;
        _translationPreview = translatedText;
        if (translatedText.isEmpty) {
          _translationError = 'Translation was empty.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _translationBusy = false;
        _translationError = 'Could not translate this draft right now.';
      });
    }
  }

  void _applyTranslation() {
    final translatedText = (_translationPreview ?? '').trim();
    if (translatedText.isEmpty) return;

    _controller.value = TextEditingValue(
      text: translatedText,
      selection: TextSelection.collapsed(offset: translatedText.length),
      composing: TextRange.empty,
    );

    setState(() {
      _translationPreview = null;
      _translationError = null;
      _assistSnapshot = null;
      _suggestions = const [];
      _dismissedSuggestionIds.clear();
    });
  }

  void _restoreBeforeTranslation() {
    final snapshot = (_translationSnapshot ?? '').trim();
    if (snapshot.isEmpty) return;

    _controller.value = TextEditingValue(
      text: snapshot,
      selection: TextSelection.collapsed(offset: snapshot.length),
      composing: TextRange.empty,
    );

    setState(() {
      _translationPreview = null;
      _translationError = null;
    });
  }

  Future<void> _submit() async {
    if (!_canSend) return;

    final body = _controller.text.trim();
    final attachmentsPayload = _attachments
        .where((a) => !a.uploading && a.error == null && a.storageKey.isNotEmpty)
        .map((a) => a.toMessagePayload())
        .toList();

    setState(() => _sending = true);

    try {
      await ref.read(messagesRepositoryProvider).sendMessage(
            threadId: widget.threadId,
            body: body,
            attachments: attachmentsPayload,
          );

      _controller.clear();
      _attachments.clear();

      if (!mounted) return;
      widget.onSent();
      setState(() {
        _suggestions = const [];
        _assistSnapshot = null;
        _assistError = null;
        _assistSessionId = null;
        _dismissedSuggestionIds.clear();
        _translationPreview = null;
        _translationSnapshot = null;
        _translationError = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send message: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _removeAttachment(_DraftAttachment attachment) {
    if (_sending) return;
    setState(() {
      _attachments.removeWhere((a) => a.localId == attachment.localId);
    });
  }

  Future<void> _showAttachmentSheet() async {
    if (_sending) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        void closeAnd(Future<void> Function() action) {
          Navigator.of(sheetContext).pop();
          Future<void>.microtask(action);
        }

        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                onTap: () => closeAnd(_pickImageFromCamera),
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Upload image'),
                onTap: () => closeAnd(_pickImageFromGallery),
              ),
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('Record video'),
                onTap: () => closeAnd(_pickVideoFromCamera),
              ),
              ListTile(
                leading: const Icon(Icons.video_library_outlined),
                title: const Text('Upload video'),
                onTap: () => closeAnd(_pickVideoFromGallery),
              ),
              ListTile(
                leading: Icon(
                  _recordingAudio ? Icons.stop_circle_outlined : Icons.mic_none,
                ),
                title: Text(
                  _recordingAudio ? 'Stop audio recording' : 'Record audio',
                ),
                onTap: () => closeAnd(_toggleAudioRecording),
              ),
              ListTile(
                leading: const Icon(Icons.audio_file_outlined),
                title: const Text('Upload audio'),
                onTap: () => closeAnd(_pickAudioFile),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uploadingCount = _attachments.where((a) => a.uploading).length;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.black12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_attachments.isNotEmpty) ...[
              _AttachmentPreviewRow(
                attachments: _attachments,
                onRemove: _removeAttachment,
              ),
              const SizedBox(height: AuraSpace.s10),
            ],
            if (_visibleSuggestions.isNotEmpty || _assistError != null) ...[
              _ComposerAssistPanel(
                suggestions: _visibleSuggestions,
                errorText: _assistError,
                applyingIds: _applyingSuggestionIds,
                onApply: _applySuggestion,
                onDismiss: (suggestion) {
                  final id = _firstNonEmpty(suggestion, const ['id', 'findingId']);
                  if (id.isEmpty) return;
                  setState(() => _dismissedSuggestionIds.add(id));
                },
              ),
              const SizedBox(height: AuraSpace.s10),
            ],
            if (_translationPreview != null || _translationError != null) ...[
              _ComposerTranslationPanel(
                targetLanguage: _translationTargetLanguage,
                preview: _translationPreview,
                errorText: _translationError,
                busy: _translationBusy,
                onApply: _translationPreview == null ? null : _applyTranslation,
                onRestore: _translationSnapshot == null ? null : _restoreBeforeTranslation,
              ),
              const SizedBox(height: AuraSpace.s10),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: _sending ? null : _showAttachmentSheet,
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Add attachment',
                ),
                Expanded(
                  child: Column(
                    children: [
                      TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 6,
                        decoration: InputDecoration(
                          hintText: _recordingAudio
                              ? 'Recording audio...'
                              : 'Write a message',
                        ),
                        onChanged: (_) {
                          setState(() {
                            if ((_assistSnapshot ?? '') != _controller.text.trim()) {
                              _suggestions = const [];
                              _assistError = null;
                              _assistSessionId = null;
                              _dismissedSuggestionIds.clear();
                            }
                            if ((_translationSnapshot ?? '') != _controller.text.trim()) {
                              _translationPreview = null;
                              _translationError = null;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: AuraSpace.s8),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: !_hasText || _assistBusy ? null : _runAssist,
                            icon: _assistBusy
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.auto_fix_high_outlined, size: 16),
                            label: const Text('Polish'),
                          ),
                          const SizedBox(width: AuraSpace.s8),
                          DropdownButton<String>(
                            value: _translationTargetLanguage,
                            items: const [
                              DropdownMenuItem(value: 'ur', child: Text('Urdu')),
                              DropdownMenuItem(value: 'en', child: Text('English')),
                              DropdownMenuItem(value: 'ar', child: Text('Arabic')),
                            ],
                            onChanged: _translationBusy
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    setState(() {
                                      _translationTargetLanguage = value;
                                    });
                                  },
                          ),
                          const SizedBox(width: AuraSpace.s8),
                          OutlinedButton.icon(
                            onPressed: !_hasText || _translationBusy ? null : _translateDraft,
                            icon: _translationBusy
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.translate_outlined, size: 16),
                            label: const Text('Translate'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AuraSpace.s10),
                FilledButton(
                  onPressed: _canSend ? _submit : null,
                  child: Text(
                    _sending
                        ? 'Sending...'
                        : uploadingCount > 0
                            ? 'Uploading...'
                            : 'Send',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerAssistPanel extends StatelessWidget {
  const _ComposerAssistPanel({
    required this.suggestions,
    required this.errorText,
    required this.applyingIds,
    required this.onApply,
    required this.onDismiss,
  });

  final List<Map<String, dynamic>> suggestions;
  final String? errorText;
  final Set<String> applyingIds;
  final void Function(Map<String, dynamic> suggestion) onApply;
  final void Function(Map<String, dynamic> suggestion) onDismiss;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Writing support', style: AuraText.title),
          if (errorText != null && errorText!.trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s8),
            Text(errorText!, style: AuraText.body),
          ],
          for (final suggestion in suggestions) ...[
            const SizedBox(height: AuraSpace.s10),
            _ComposerSuggestionTile(
              suggestion: suggestion,
              busy: applyingIds.contains(
                _firstNonEmpty(suggestion, const ['id', 'findingId']),
              ),
              onApply: () => onApply(suggestion),
              onDismiss: () => onDismiss(suggestion),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComposerSuggestionTile extends StatelessWidget {
  const _ComposerSuggestionTile({
    required this.suggestion,
    required this.busy,
    required this.onApply,
    required this.onDismiss,
  });

  final Map<String, dynamic> suggestion;
  final bool busy;
  final VoidCallback onApply;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final message = _firstNonEmpty(suggestion, const ['message', 'title', 'finding']);
    final detail = _firstNonEmpty(suggestion, const ['suggestion', 'detail', 'description']);

    return Container(
      padding: const EdgeInsets.all(AuraSpace.s12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.isNotEmpty)
            Text(message, style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text(detail, style: AuraText.body),
          ],
          const SizedBox(height: AuraSpace.s10),
          Row(
            children: [
              TextButton(
                onPressed: busy ? null : onDismiss,
                child: const Text('Dismiss'),
              ),
              const SizedBox(width: AuraSpace.s8),
              FilledButton(
                onPressed: busy ? null : onApply,
                child: Text(busy ? 'Applying...' : 'Apply'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComposerTranslationPanel extends StatelessWidget {
  const _ComposerTranslationPanel({
    required this.targetLanguage,
    required this.preview,
    required this.errorText,
    required this.busy,
    required this.onApply,
    required this.onRestore,
  });

  final String targetLanguage;
  final String? preview;
  final String? errorText;
  final bool busy;
  final VoidCallback? onApply;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final label = switch (targetLanguage) {
      'ur' => 'Urdu',
      'ar' => 'Arabic',
      _ => 'English',
    };

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Translation preview', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          Text('Target language: $label', style: AuraText.small),
          if (errorText != null && errorText!.trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s8),
            Text(errorText!, style: AuraText.body),
          ],
          if ((preview ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s8),
            Directionality(
              textDirection: _directionForText(preview!),
              child: Text(
                preview!,
                textAlign: _alignForText(preview!),
                style: AuraText.body,
              ),
            ),
            const SizedBox(height: AuraSpace.s10),
            Row(
              children: [
                TextButton(
                  onPressed: busy ? null : onRestore,
                  child: const Text('Restore original'),
                ),
                const SizedBox(width: AuraSpace.s8),
                FilledButton(
                  onPressed: busy ? null : onApply,
                  child: const Text('Use translation'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
class _AttachmentPreviewRow extends StatelessWidget {
  const _AttachmentPreviewRow({
    required this.attachments,
    required this.onRemove,
  });

  final List<_DraftAttachment> attachments;
  final void Function(_DraftAttachment attachment) onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: attachments.length,
        separatorBuilder: (_, _) => const SizedBox(width: AuraSpace.s10),
        itemBuilder: (context, index) {
          final attachment = attachments[index];
          return _AttachmentPreviewCard(
            attachment: attachment,
            onRemove: () => onRemove(attachment),
          );
        },
      ),
    );
  }
}

class _AttachmentPreviewCard extends StatelessWidget {
  const _AttachmentPreviewCard({
    required this.attachment,
    required this.onRemove,
  });

  final _DraftAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final label = attachment.file.name;
    final subtitle = attachment.uploading
        ? 'Uploading...'
        : attachment.error != null
            ? 'Failed'
            : _attachmentKindLabel(attachment.kind);

    return Container(
      width: 240,
      padding: const EdgeInsets.all(AuraSpace.s10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _AttachmentIcon(kind: attachment.kind),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AuraSpace.s4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AuraText.small,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: attachment.uploading ? null : onRemove,
            icon: const Icon(Icons.close),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

class _EditMessageDialog extends ConsumerStatefulWidget {
  const _EditMessageDialog({required this.message});

  final Map<String, dynamic> message;

  @override
  ConsumerState<_EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends ConsumerState<_EditMessageDialog> {
  late final TextEditingController _controller;
  bool _saving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _pickString(widget.message, const ['body', 'text', 'content']),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final messageId = _pickString(widget.message, const ['id', 'messageId']);
    final body = _controller.text.trim();

    if (messageId.isEmpty || body.isEmpty) {
      setState(() {
        _errorText = 'Message body cannot be empty.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _errorText = null;
    });

    try {
      await ref.read(messagesRepositoryProvider).editMessage(
            messageId: messageId,
            body: body,
          );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _errorText = '$e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit message'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Message',
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: AuraSpace.s12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorText!,
                  style: AuraText.small.copyWith(
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}

class _MessageTile extends ConsumerStatefulWidget {
  const _MessageTile({
    required this.message,
    required this.currentUserId,
    required this.showAuthorHeader,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> message;
  final String currentUserId;
  final bool showAuthorHeader;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  ConsumerState<_MessageTile> createState() => _MessageTileState();
}

class _MessageTileState extends ConsumerState<_MessageTile> {
  bool _translationBusy = false;
  bool _showTranslation = false;
  String? _translatedText;
  String? _translationError;
  String? _translationTargetLanguage;

  Future<void> _pickTranslationLanguage(BuildContext context) async {
    final current = (_translationTargetLanguage ?? _defaultTranslationLanguage(context)).toLowerCase();

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Translate to',
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AuraSpace.s12),
                Wrap(
                  spacing: AuraSpace.s10,
                  runSpacing: AuraSpace.s10,
                  children: _translationLanguageLabels.entries.map((entry) {
                    final active = entry.key == current;
                    return InkWell(
                      onTap: () => Navigator.of(ctx).pop(entry.key),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AuraSpace.s12,
                          vertical: AuraSpace.s8,
                        ),
                        decoration: BoxDecoration(
                          color: active ? Colors.black : Colors.transparent,
                          border: Border.all(color: Colors.black12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          entry.value,
                          style: AuraText.small.copyWith(
                            fontWeight: FontWeight.w700,
                            color: active ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null || selected.trim().isEmpty) return;
    setState(() {
      _translationTargetLanguage = selected.trim().toLowerCase();
      _translationError = null;
    });
  }

  Future<void> _translateMessage(BuildContext context, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _translationBusy) return;

    final target = (_translationTargetLanguage ?? _defaultTranslationLanguage(context)).toLowerCase();

    setState(() {
      _translationBusy = true;
      _translationError = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post(
        '/v1/composition/translate',
        data: {
          'text': trimmed,
          'targetLanguage': target,
        },
      );

      final root = _unwrapDataMap(res.data);
      final translatedText = _pickDeepString(root, const [
        ['translatedText'],
        ['translation', 'text'],
        ['data', 'translatedText'],
        ['data', 'text'],
      ]);

      if (!mounted) return;

      if (translatedText.trim().isEmpty) {
        setState(() {
          _translationError = 'Translation was empty.';
          _translationBusy = false;
        });
        return;
      }

      setState(() {
        _translatedText = translatedText;
        _showTranslation = true;
        _translationTargetLanguage = target;
        _translationBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _translationBusy = false;
        _translationError = 'Could not translate this message right now.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not translate this message right now.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final currentUserId = widget.currentUserId;
    final showAuthorHeader = widget.showAuthorHeader;
    final onEdit = widget.onEdit;
    final onDelete = widget.onDelete;

    final body = _pickString(message, const ['body', 'text', 'content']);
    final authorMap = _extractAuthorMap(message);
    final author = _pickString(
      authorMap.isNotEmpty ? authorMap : message,
      const ['displayName', 'authorName', 'senderName', 'name', 'userName'],
    );
    final handle = _pickString(
      authorMap.isNotEmpty ? authorMap : message,
      const ['handle', 'authorHandle', 'senderHandle', 'username'],
    );
    final contextLine = _pickString(
      authorMap.isNotEmpty ? authorMap : message,
      const ['authorContext', 'senderContext', 'bio', 'tagline', 'headline'],
    );
    final createdAt = _pickString(
      message,
      const ['createdAt', 'sentAt', 'timestamp'],
    );
    final attachments = _listOfMap(message['attachments']);
    final senderId = _extractSenderId(message);
    final isMine =
        currentUserId.trim().isNotEmpty && senderId.trim() == currentUserId.trim();

    final bubbleColor = isMine ? Colors.black : Colors.white;
    final bubbleBorderColor = isMine ? Colors.black : Colors.black12;
    final textColor = isMine ? Colors.white : Colors.black87;
    final metaColor = isMine ? Colors.white70 : Colors.black54;
    final translatedTextColor = isMine ? Colors.white : Colors.black87;
    final translatedSurfaceColor =
        isMine ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.03);

    _translationTargetLanguage ??= _defaultTranslationLanguage(context);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width > 900 ? 660 : 560,
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMine && showAuthorHeader && author.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap:
                      handle.isEmpty ? null : () => context.push('/u/$handle'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Directionality(
                          textDirection: _directionForText(author),
                          child: Text(
                            author,
                            textAlign: _alignForText(author),
                            style: AuraText.small.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (handle.isNotEmpty) ...[
                          const SizedBox(height: AuraSpace.s4),
                          Directionality(
                            textDirection: _directionForText(handle),
                            child: Text(
                              '@$handle',
                              textAlign: _alignForText(handle),
                              style: AuraText.small,
                            ),
                          ),
                        ],
                        if (contextLine.isNotEmpty) ...[
                          const SizedBox(height: AuraSpace.s4),
                          Directionality(
                            textDirection: _directionForText(contextLine),
                            child: Text(
                              contextLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: _alignForText(contextLine),
                              style: AuraText.small,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
            Container(
              decoration: BoxDecoration(
                color: bubbleColor,
                border: Border.all(color: bubbleBorderColor),
                borderRadius: BorderRadius.circular(20),
                boxShadow: isMine
                    ? null
                    : const [
                        BoxShadow(
                          blurRadius: 12,
                          offset: Offset(0, 3),
                          color: Color(0x08000000),
                        ),
                      ],
              ),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (body.isNotEmpty) ...[
                    Directionality(
                      textDirection: _directionForText(body),
                      child: AuraTextBlock(
                        body,
                        textAlign: _alignForText(body),
                        style: AuraText.body.copyWith(color: textColor),
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s8),
                    Wrap(
                      spacing: AuraSpace.s10,
                      runSpacing: AuraSpace.s8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        InkWell(
                          onTap: _translationBusy
                              ? null
                              : () => _translateMessage(context, body),
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AuraSpace.s6,
                              vertical: AuraSpace.s6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_translationBusy) ...[
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isMine ? Colors.white70 : Colors.black54,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AuraSpace.s8),
                                ],
                                Text(
                                  _translationBusy
                                      ? 'Translating...'
                                      : (_showTranslation ? 'Refresh translation' : 'Translate'),
                                  style: AuraText.small.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: metaColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => _pickTranslationLanguage(context),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AuraSpace.s10,
                              vertical: AuraSpace.s6,
                            ),
                            decoration: BoxDecoration(
                              color: isMine ? Colors.white.withOpacity(0.06) : Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: isMine ? Colors.white24 : Colors.black12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.translate,
                                  size: 14,
                                  color: metaColor,
                                ),
                                const SizedBox(width: AuraSpace.s6),
                                Text(
                                  _languageLabel(_translationTargetLanguage ?? _defaultTranslationLanguage(context)),
                                  style: AuraText.small.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: isMine ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_showTranslation)
                          InkWell(
                            onTap: () {
                              setState(() {
                                _showTranslation = false;
                                _translationError = null;
                              });
                            },
                            borderRadius: BorderRadius.circular(999),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AuraSpace.s6,
                                vertical: AuraSpace.s6,
                              ),
                              child: Text(
                                'Hide translation',
                                style: AuraText.small.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: metaColor,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if ((_translationError ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s8),
                      Text(
                        _translationError!,
                        style: AuraText.small.copyWith(
                          color: isMine ? Colors.white70 : Colors.red.shade700,
                        ),
                      ),
                    ],
                    if (_showTranslation && (_translatedText ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AuraSpace.s10),
                        decoration: BoxDecoration(
                          color: translatedSurfaceColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isMine ? Colors.white24 : Colors.black12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Translation · ${_languageLabel(_translationTargetLanguage ?? _defaultTranslationLanguage(context))}',
                              style: AuraText.small.copyWith(
                                color: metaColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AuraSpace.s6),
                            Directionality(
                              textDirection: _directionForText(_translatedText!),
                              child: AuraTextBlock(
                                _translatedText!,
                                textAlign: _alignForText(_translatedText!),
                                style: AuraText.body.copyWith(color: translatedTextColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (attachments.isNotEmpty) const SizedBox(height: AuraSpace.s10),
                  ],
                  if (attachments.isNotEmpty) ...[
                    _MessageAttachmentList(
                      attachments: attachments,
                      isMine: isMine,
                    ),
                    const SizedBox(height: AuraSpace.s10),
                  ] else if (body.isEmpty) ...[
                    Text(
                      '(empty message)',
                      style: AuraText.body.copyWith(color: textColor),
                    ),
                    const SizedBox(height: AuraSpace.s10),
                  ],
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_formatMessageTimestamp(createdAt).isNotEmpty)
                        Flexible(
                          child: Text(
                            _formatMessageTimestamp(createdAt),
                            overflow: TextOverflow.ellipsis,
                            style: AuraText.small.copyWith(color: metaColor),
                          ),
                        ),
                      if (isMine) ...[
                        const SizedBox(width: AuraSpace.s8),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.more_horiz,
                            size: 18,
                            color: metaColor,
                          ),
                          onSelected: (value) {
                            if (value == 'edit') {
                              onEdit();
                            } else if (value == 'delete') {
                              onDelete();
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem<String>(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageAttachmentList extends StatelessWidget {
  const _MessageAttachmentList({
    required this.attachments,
    required this.isMine,
  });

  final List<Map<String, dynamic>> attachments;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < attachments.length; i++) ...[
          _MessageAttachmentCard(
            attachment: attachments[i],
            isMine: isMine,
          ),
          if (i != attachments.length - 1)
            const SizedBox(height: AuraSpace.s8),
        ],
      ],
    );
  }
}

class _MessageAttachmentCard extends StatefulWidget {
  const _MessageAttachmentCard({
    required this.attachment,
    required this.isMine,
  });

  final Map<String, dynamic> attachment;
  final bool isMine;

  @override
  State<_MessageAttachmentCard> createState() => _MessageAttachmentCardState();
}

class _MessageAttachmentCardState extends State<_MessageAttachmentCard> {
  bool _hovering = false;

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this attachment.')),
      );
      return;
    }

    final ok = await launchUrl(
      uri,
      mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );

    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this attachment.')),
      );
    }
  }

  void _openImageViewer(BuildContext context, String imageUrl, String title) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      height: 320,
                      width: 520,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Could not load image.',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
            if (title.isNotEmpty)
              Positioned(
                left: 16,
                right: 72,
                top: 16,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attachment = widget.attachment;
    final isMine = widget.isMine;

    final fileName = _pickString(attachment, const ['fileName', 'name']);
    final mimeType = _pickString(attachment, const ['mimeType', 'mime']);
    final sizeBytes = _pickInt(attachment, const ['sizeBytes', 'size']);
    final kind = _kindFromMime(mimeType);
    final url = _resolveAttachmentUrl(attachment);
    final thumbUrl = _resolveAttachmentThumbUrl(attachment);

    final borderColor = isMine ? Colors.white24 : Colors.black12;
    final surfaceColor = isMine ? Colors.white.withOpacity(0.08) : Colors.white;
    final primaryTextColor = isMine ? Colors.white : Colors.black87;
    final secondaryTextColor = isMine ? Colors.white70 : Colors.black54;

    void handleTap() {
      if (url.isEmpty) return;

      if (kind == _AttachmentKind.image) {
        _openImageViewer(
          context,
          thumbUrl.isNotEmpty ? thumbUrl : url,
          fileName,
        );
        return;
      }

      _openUrl(context, url);
    }

    Widget mediaSurface;
    switch (kind) {
      case _AttachmentKind.image:
        mediaSurface = _ImageAttachmentSurface(
          thumbUrl: thumbUrl,
          url: url,
          borderColor: borderColor,
          surfaceColor: surfaceColor,
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
          fileName: fileName,
          sizeBytes: sizeBytes,
          hovering: _hovering,
        );
        break;
      case _AttachmentKind.video:
        mediaSurface = _VideoAttachmentSurface(
          thumbUrl: thumbUrl,
          url: url,
          borderColor: borderColor,
          surfaceColor: surfaceColor,
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
          fileName: fileName,
          sizeBytes: sizeBytes,
          hovering: _hovering,
        );
        break;
      case _AttachmentKind.audio:
        mediaSurface = _AudioAttachmentSurface(
          url: url,
          borderColor: borderColor,
          surfaceColor: surfaceColor,
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
          fileName: fileName,
          sizeBytes: sizeBytes,
          mimeType: mimeType,
          hovering: _hovering,
        );
        break;
    }

    if (url.isEmpty) return mediaSurface;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: handleTap,
        child: mediaSurface,
      ),
    );
  }
}

class _ImageAttachmentSurface extends StatelessWidget {
  const _ImageAttachmentSurface({
    required this.thumbUrl,
    required this.url,
    required this.borderColor,
    required this.surfaceColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.fileName,
    required this.sizeBytes,
    required this.hovering,
  });

  final String thumbUrl;
  final String url;
  final Color borderColor;
  final Color surfaceColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final String fileName;
  final int? sizeBytes;
  final bool hovering;

  @override
  Widget build(BuildContext context) {
    final imageUrl = thumbUrl.isNotEmpty ? thumbUrl : url;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      transform: Matrix4.identity()..scale(hovering ? 1.01 : 1.0),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl.isNotEmpty)
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _BrokenMediaFallback(
                      icon: Icons.image_outlined,
                      text: 'Image preview unavailable',
                      textColor: secondaryTextColor,
                    ),
                  )
                else
                  _BrokenMediaFallback(
                    icon: Icons.image_outlined,
                    text: 'Image unavailable',
                    textColor: secondaryTextColor,
                  ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 140),
                  opacity: hovering ? 1 : 0.92,
                  child: Container(
                    color: Colors.black.withOpacity(hovering ? 0.18 : 0.08),
                  ),
                ),
                const Center(
                  child: _CenterOpenIcon(),
                ),
                const Positioned(
                  right: 10,
                  bottom: 10,
                  child: _OpenBadge(label: 'Open', dark: true),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AuraSpace.s10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    fileName.isEmpty ? 'Image' : fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuraText.small.copyWith(
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                ),
                if (sizeBytes != null)
                  Text(
                    _formatBytes(sizeBytes!),
                    style: AuraText.small.copyWith(color: secondaryTextColor),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoAttachmentSurface extends StatelessWidget {
  const _VideoAttachmentSurface({
    required this.thumbUrl,
    required this.url,
    required this.borderColor,
    required this.surfaceColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.fileName,
    required this.sizeBytes,
    required this.hovering,
  });

  final String thumbUrl;
  final String url;
  final Color borderColor;
  final Color surfaceColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final String fileName;
  final int? sizeBytes;
  final bool hovering;

  @override
  Widget build(BuildContext context) {
    final previewUrl = thumbUrl.isNotEmpty ? thumbUrl : url;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      transform: Matrix4.identity()..scale(hovering ? 1.01 : 1.0),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (previewUrl.isNotEmpty)
                  Image.network(
                    previewUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _BrokenMediaFallback(
                      icon: Icons.videocam_outlined,
                      text: 'Video preview unavailable',
                      textColor: Colors.white70,
                      dark: true,
                    ),
                  )
                else
                  _BrokenMediaFallback(
                    icon: Icons.videocam_outlined,
                    text: 'Video ready to open',
                    textColor: Colors.white70,
                    dark: true,
                  ),
                Container(color: Colors.black.withOpacity(hovering ? 0.34 : 0.26)),
                const Center(
                  child: _CenterPlayIcon(),
                ),
                const Positioned(
                  right: 10,
                  bottom: 10,
                  child: _OpenBadge(label: 'Open', dark: true),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AuraSpace.s10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    fileName.isEmpty ? 'Video' : fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuraText.small.copyWith(
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                ),
                if (sizeBytes != null)
                  Text(
                    _formatBytes(sizeBytes!),
                    style: AuraText.small.copyWith(color: secondaryTextColor),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioAttachmentSurface extends StatelessWidget {
  const _AudioAttachmentSurface({
    required this.url,
    required this.borderColor,
    required this.surfaceColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.fileName,
    required this.sizeBytes,
    required this.mimeType,
    required this.hovering,
  });

  final String url;
  final Color borderColor;
  final Color surfaceColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final String fileName;
  final int? sizeBytes;
  final String mimeType;
  final bool hovering;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      transform: Matrix4.identity()..scale(hovering ? 1.01 : 1.0),
      padding: const EdgeInsets.all(AuraSpace.s12),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: hovering
                  ? Colors.white.withOpacity(0.06)
                  : Colors.transparent,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.graphic_eq_outlined,
              color: secondaryTextColor,
            ),
          ),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName.isEmpty ? 'Audio' : fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AuraText.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: AuraSpace.s4),
                Text(
                  [
                    if (mimeType.isNotEmpty) mimeType,
                    if (sizeBytes != null) _formatBytes(sizeBytes!),
                  ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AuraText.small.copyWith(color: secondaryTextColor),
                ),
                const SizedBox(height: AuraSpace.s6),
                Row(
                  children: [
                    Icon(
                      Icons.open_in_new,
                      size: 14,
                      color: secondaryTextColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      url.isNotEmpty ? 'Open audio' : 'Audio unavailable',
                      style: AuraText.small.copyWith(color: secondaryTextColor),
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

class _BrokenMediaFallback extends StatelessWidget {
  const _BrokenMediaFallback({
    required this.icon,
    required this.text,
    required this.textColor,
    this.dark = false,
  });

  final IconData icon;
  final String text;
  final Color textColor;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: dark ? Colors.black38 : Colors.black12,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: textColor),
          const SizedBox(height: 8),
          Text(
            text,
            style: AuraText.small.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}

class _CenterOpenIcon extends StatelessWidget {
  const _CenterOpenIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      width: 52,
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Icon(
        Icons.open_in_full,
        size: 24,
        color: Colors.white,
      ),
    );
  }
}

class _CenterPlayIcon extends StatelessWidget {
  const _CenterPlayIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      width: 56,
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: 32,
      ),
    );
  }
}

class _OpenBadge extends StatelessWidget {
  const _OpenBadge({
    required this.label,
    this.dark = false,
  });

  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: dark ? Colors.black54 : Colors.white70,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.open_in_new,
            size: 12,
            color: dark ? Colors.white : Colors.black87,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AuraText.small.copyWith(
              color: dark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentIcon extends StatelessWidget {
  const _AttachmentIcon({required this.kind});

  final _AttachmentKind kind;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (kind) {
      case _AttachmentKind.image:
        icon = Icons.image_outlined;
        break;
      case _AttachmentKind.video:
        icon = Icons.videocam_outlined;
        break;
      case _AttachmentKind.audio:
        icon = Icons.graphic_eq_outlined;
        break;
    }

    return Container(
      height: 40,
      width: 40,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: AuraSpace.s10),
        Text(label, style: AuraText.body),
      ],
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({
    required this.title,
    required this.body,
    required this.onRetry,
  });

  final String title;
  final String body;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AuraText.title),
        const SizedBox(height: AuraSpace.s8),
        Text(body, style: AuraText.body),
        const SizedBox(height: AuraSpace.s12),
        OutlinedButton(
          onPressed: onRetry,
          child: const Text('Try again'),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s6,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AuraText.small.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _DraftAttachment {
  _DraftAttachment({
    required this.localId,
    required this.file,
    required this.bytes,
    required this.kind,
    required this.source,
    required this.mimeType,
    required this.sizeBytes,
    this.width,
    this.height,
    this.durationSec,
    this.url,
    this.thumbUrl,
    this.storageKey = '',
    this.uploading = false,
    this.error,
  });

  final String localId;
  final XFile file;
  final Uint8List bytes;
  final _AttachmentKind kind;
  final _AttachmentSource source;
  final String mimeType;
  final int sizeBytes;
  int? width;
  int? height;
  int? durationSec;
  String? url;
  String? thumbUrl;
  String storageKey;
  bool uploading;
  String? error;

  Map<String, dynamic> toMessagePayload() {
    return {
      'storageKey': storageKey,
      'fileName': file.name,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (durationSec != null) 'durationSec': durationSec,
    };
  }
}

enum _AttachmentKind {
  image,
  video,
  audio,
}

enum _AttachmentSource {
  gallery,
  camera,
  upload,
  recording,
}

String _attachmentKindLabel(_AttachmentKind kind) {
  switch (kind) {
    case _AttachmentKind.image:
      return 'Image';
    case _AttachmentKind.video:
      return 'Video';
    case _AttachmentKind.audio:
      return 'Audio';
  }
}

String _mediaKindValue(_AttachmentKind kind) {
  switch (kind) {
    case _AttachmentKind.image:
      return 'IMAGE';
    case _AttachmentKind.video:
      return 'VIDEO';
    case _AttachmentKind.audio:
      return 'AUDIO';
  }
}

String _mediaSourceValue(_AttachmentSource source) {
  switch (source) {
    case _AttachmentSource.gallery:
      return 'GALLERY';
    case _AttachmentSource.camera:
      return 'CAMERA';
    case _AttachmentSource.upload:
      return 'UPLOAD';
    case _AttachmentSource.recording:
      return 'RECORDING';
  }
}

_AttachmentKind _kindFromMime(String mime) {
  final lower = mime.toLowerCase();
  if (lower.startsWith('image/')) return _AttachmentKind.image;
  if (lower.startsWith('video/')) return _AttachmentKind.video;
  return _AttachmentKind.audio;
}

String _inferMime(String fileName) {
  final lower = fileName.toLowerCase();

  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.webp')) return 'image/webp';

  if (lower.endsWith('.mp4')) return 'video/mp4';
  if (lower.endsWith('.mov')) return 'video/quicktime';
  if (lower.endsWith('.webm')) return 'video/webm';
  if (lower.endsWith('.mkv')) return 'video/x-matroska';

  if (lower.endsWith('.mp3')) return 'audio/mpeg';
  if (lower.endsWith('.m4a')) return 'audio/mp4';
  if (lower.endsWith('.aac')) return 'audio/aac';
  if (lower.endsWith('.wav')) return 'audio/wav';
  if (lower.endsWith('.ogg')) return 'audio/ogg';

  return 'application/octet-stream';
}

Future<Map<String, int>?> _decodeImageSize(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  return {
    'width': image.width,
    'height': image.height,
  };
}

Dio _cleanUploadDio() {
  return Dio(
    BaseOptions(
      responseType: ResponseType.plain,
      followRedirects: true,
    ),
  );
}

Map<String, dynamic> _unwrapDataMap(dynamic raw) {
  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);
    final data = map['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return map;
  }
  return <String, dynamic>{};
}

Map<String, dynamic> _unwrapResponseMap(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    const nestedKeys = [
      'data',
      'user',
      'item',
      'result',
      'payload',
    ];

    for (final key in nestedKeys) {
      final nested = raw[key];
      if (nested is Map<String, dynamic>) {
        return _unwrapResponseMap(nested);
      }
      if (nested is Map) {
        return _unwrapResponseMap(Map<String, dynamic>.from(nested));
      }
    }

    return raw;
  }

  if (raw is Map) {
    return _unwrapResponseMap(Map<String, dynamic>.from(raw));
  }

  return <String, dynamic>{};
}

Map<String, dynamic> _asMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _listOfMap(dynamic raw) {
  if (raw is! List) return const [];
  return raw.map((e) => _asMap(e)).toList();
}


List<Map<String, dynamic>> _extractFindings(Map<String, dynamic> root) {
  for (final path in const [
    ['findings'],
    ['review', 'findings'],
    ['data', 'findings'],
    ['result', 'findings'],
    ['items'],
    ['data', 'items'],
  ]) {
    final value = _valueAtPath(root, path);
    if (value is List) {
      return value.map(_asMap).where((item) {
        final id = _firstNonEmpty(item, const ['id', 'findingId']);
        final message = _firstNonEmpty(item, const ['message', 'title', 'finding']);
        final detail = _firstNonEmpty(item, const ['suggestion', 'detail', 'description']);
        return id.isNotEmpty || message.isNotEmpty || detail.isNotEmpty;
      }).toList();
    }
  }
  return const [];
}

dynamic _valueAtPath(Map<String, dynamic> map, List<String> path) {
  dynamic current = map;
  for (final segment in path) {
    if (current is! Map) return null;
    current = current[segment];
  }
  return current;
}

String _pickDeepString(
  Map<String, dynamic> map,
  List<List<String>> paths, {
  String fallback = '',
}) {
  for (final path in paths) {
    final value = _valueAtPath(map, path);
    final text = _str(value);
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

String _str(dynamic value) => (value ?? '').toString().trim();

String _firstNonEmpty(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = _str(map[key]);
    if (value.isNotEmpty) return value;
  }
  return '';
}

int? _pickInt(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is int) return value;
    final parsed = int.tryParse('${value ?? ''}');
    if (parsed != null) return parsed;
  }
  return null;
}

String _pickString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = (map[key] ?? '').toString().trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}

Map<String, dynamic> _extractAuthorMap(Map<String, dynamic> message) {
  const keys = [
    'author',
    'sender',
    'user',
    'member',
    'profile',
    'createdBy',
  ];

  for (final key in keys) {
    final value = message[key];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
  }

  return const <String, dynamic>{};
}

String _extractSenderId(Map<String, dynamic> message) {
  final direct = _pickString(message, const [
    'authorId',
    'senderId',
    'userId',
    'createdById',
    'memberId',
  ]);
  if (direct.isNotEmpty) return direct;

  final author = _extractAuthorMap(message);
  if (author.isEmpty) return '';

  return _pickString(author, const [
    'id',
    '_id',
    'userId',
    'memberId',
  ]);
}

String _resolveAttachmentUrl(Map<String, dynamic> attachment) {
  return _pickString(
    attachment,
    const [
      'displayUrl',
      'playbackUrl',
      'url',
      'publicUrl',
      'signedUrl',
      'sourceUrl',
      'fileUrl',
      'href',
      'src',
      'downloadUrl',
      'originalUrl',
    ],
  );
}

String _resolveAttachmentThumbUrl(Map<String, dynamic> attachment) {
  return _pickString(
    attachment,
    const [
      'thumbnailUrl',
      'thumbUrl',
      'previewUrl',
      'posterUrl',
      'displayUrl',
      'publicUrl',
      'signedUrl',
      'url',
    ],
  );
}

bool _isSameSender(Map<String, dynamic> current, Map<String, dynamic>? previous) {
  if (previous == null) return false;
  final currentSender = _extractSenderId(current).trim();
  final previousSender = _extractSenderId(previous).trim();
  if (currentSender.isEmpty || previousSender.isEmpty) return false;
  return currentSender == previousSender;
}


String _formatMessageTimestamp(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';

  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;

  final local = parsed.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final targetDay = DateTime(local.year, local.month, local.day);
  final diffDays = today.difference(targetDay).inDays;

  String formatTime(DateTime dt) {
    final hour = dt.hour == 0
        ? 12
        : dt.hour > 12
            ? dt.hour - 12
            : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  if (diffDays == 0) return formatTime(local);
  if (diffDays == 1) return 'Yesterday';
  if (diffDays > 1 && diffDays < 7) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[local.weekday - 1];
  }

  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[local.month - 1]} ${local.day}';
}


String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(gb >= 100 ? 0 : 1)} GB';
}