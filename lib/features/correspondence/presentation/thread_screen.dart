import 'dart:async';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/attachments/aura_media_upload.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/aura_text_block.dart';
import '../data/messages_repository.dart';
import '../data/threads_repository.dart';
import '../data/correspondence_identity.dart';
import '../../realtime/application/realtime_providers.dart';
import '../../realtime/domain/realtime_models.dart';
import '../../realtime/domain/realtime_state.dart';

final threadOpenProvider = FutureProvider.family<void, String>((
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

final threadDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, threadId) async {
      final repo = ref.watch(threadsRepositoryProvider);
      return repo.getThread(threadId);
    });

final messagesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      threadId,
    ) async {
      final repo = ref.watch(messagesRepositoryProvider);
      return repo.listMessages(threadId: threadId);
    });

final currentUserProvider = FutureProvider<Map<String, dynamic>>((ref) async {
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
  final code = Localizations.localeOf(
    context,
  ).languageCode.trim().toLowerCase();
  if (_translationLanguageLabels.containsKey(code)) return code;
  return 'en';
}

bool _hasRtlScript(String text) {
  final value = text.trim();
  if (value.isEmpty) return false;
  final rtl = RegExp(
    r'[\u0590-\u05FF\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
  );
  return rtl.hasMatch(value);
}

TextDirection _directionForText(String text) {
  return _hasRtlScript(text) ? TextDirection.rtl : TextDirection.ltr;
}

TextAlign _alignForText(String text) {
  return _hasRtlScript(text) ? TextAlign.right : TextAlign.left;
}

String _threadResolvedSessionId(
  Map<String, dynamic> thread,
  RealtimeState liveState,
  String fallbackThreadId,
) {
  final direct = _pickString(thread, const [
    'liveSessionId',
    'activeSessionId',
    'sessionId',
    'realtimeSessionId',
    'currentSessionId',
  ]);
  if (direct.isNotEmpty) return direct;

  final nested = _pickNested(thread, const [
    ['live', 'sessionId'],
    ['activeLive', 'sessionId'],
    ['realtime', 'sessionId'],
    ['session', 'id'],
    ['activeSession', 'id'],
  ]);
  if (nested.isNotEmpty) return nested;

  final session = liveState.session;
  if (session != null) {
    final expectedType = _threadLiveSurfaceType(thread).trim().toLowerCase();
    final expectedId = _threadLiveSurfaceId(thread, fallbackThreadId).trim();
    final sessionType = session.surfaceType.name.trim().toLowerCase();
    final sessionSurfaceId = (session.surfaceId ?? '').trim();
    if (sessionType == expectedType && sessionSurfaceId == expectedId) {
      return (liveState.sessionId ?? session.id).trim();
    }
  }
  return '';
}

String _threadLiveKind(Map<String, dynamic> thread, RealtimeState liveState) {
  final direct = _pickString(thread, const [
    'liveKind',
    'callKind',
    'callMode',
    'sessionKind',
    'liveMode',
  ]).toLowerCase();
  if (direct == 'audio' || direct == 'video') return direct;
  if (liveState.isVideoMode) return 'video';
  if (liveState.isAudioMode) return 'audio';
  return 'audio';
}

String _threadStartedByUserId(
  Map<String, dynamic> thread,
  RealtimeState liveState,
) {
  final direct = _pickString(thread, const [
    'startedByUserId',
    'liveStartedByUserId',
    'callerUserId',
    'ownerUserId',
  ]);
  if (direct.isNotEmpty) return direct;
  final nested = _pickNested(thread, const [
    ['live', 'startedByUserId'],
    ['activeLive', 'startedByUserId'],
    ['realtime', 'startedByUserId'],
    ['session', 'startedByUserId'],
  ]);
  if (nested.isNotEmpty) return nested;
  return (liveState.session?.startedByUserId ?? '').trim();
}

class ThreadScreen extends ConsumerStatefulWidget {
  const ThreadScreen({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends ConsumerState<ThreadScreen> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      final liveState = ref.read(realtimeControllerProvider);
      if (liveState.isJoined || liveState.isBusy || liveState.isMediaBusy) {
        return;
      }
      _refreshThreadData();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _refreshThreadData() {
    ref.invalidate(threadDetailProvider(widget.threadId));
    ref.invalidate(messagesProvider(widget.threadId));
  }

  Future<void> _refreshAll() async {
    ref.invalidate(threadOpenProvider(widget.threadId));
    _refreshThreadData();
    ref.invalidate(currentUserProvider);
    await Future.wait([
      ref.read(threadOpenProvider(widget.threadId).future),
      ref.read(threadDetailProvider(widget.threadId).future),
      ref.read(messagesProvider(widget.threadId).future),
      ref.read(currentUserProvider.future),
    ]);
  }

  Future<void> _startLive({
    required Map<String, dynamic> thread,
    required String kind,
  }) async {
    final controller = ref.read(realtimeControllerProvider.notifier);
    final sessionId = await controller.ensureCorrespondenceLive(
      surfaceType: _threadLiveSurfaceType(thread),
      surfaceId: _threadLiveSurfaceId(thread, widget.threadId),
      kind: kind,
      metadata:
          <String, dynamic>{
            'threadId': widget.threadId,
            'spaceId': _pickString(thread, const ['spaceId', 'space_id']),
          }..removeWhere(
            (key, value) => value == null || value.toString().trim().isEmpty,
          ),
    );
    if (!mounted || sessionId.trim().isEmpty) return;
  }

  @override
  Widget build(BuildContext context) {
    final threadId = widget.threadId;

    ref.watch(threadOpenProvider(threadId));

    final threadAsync = ref.watch(threadDetailProvider(threadId));
    final messagesAsync = ref.watch(messagesProvider(threadId));
    final meAsync = ref.watch(currentUserProvider);
    final liveState = ref.watch(realtimeControllerProvider);
    final currentUserId = meAsync.maybeWhen(
      data: (me) => _pickString(me, const ['id', '_id', 'userId']),
      orElse: () => '',
    );
    final thread = threadAsync.maybeWhen(
      data: (data) => data,
      orElse: () => null,
    );
    final threadContext = thread == null
        ? null
        : CorrespondenceIdentity.resolveThreadContext(
            thread,
            currentUserId: currentUserId,
          );
    final pageTitle = threadContext?.title ??
        threadAsync.maybeWhen(
          data: (thread) => _threadScreenTitle(
            thread,
            currentUserId: currentUserId,
          ),
          orElse: () => 'Conversation',
        ) ??
        'Conversation';

    return AuraScaffold(
      title: pageTitle,
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshAll,
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
                        onRetry: _refreshThreadData,
                      ),
                    ),
                    data: (thread) {
                      final contextData = CorrespondenceIdentity.resolveThreadContext(
                        thread,
                        currentUserId: currentUserId,
                      );

                      return Column(
                        children: [
                          _ThreadHeaderCard(
                            thread: thread,
                            contextData: contextData,
                            liveState: liveState,
                            onOpenSpace: () {
                              final spaceId = _pickString(thread, const [
                                'spaceId',
                                'space_id',
                              ]);
                              if (spaceId.isEmpty) return;
                              context.push('/me/correspondence/$spaceId');
                            },
                            onInvite: () async {
                              final spaceId = _pickString(thread, const [
                                'spaceId',
                                'space_id',
                              ]);
                              if (spaceId.isEmpty) return;
                              final returnTo =
                                  '/me/correspondence/$spaceId/thread/$threadId';
                              final inviteRoute = Uri(
                                path: '/invite/create',
                                queryParameters: {
                                  'destinationType': 'JOIN_SPACE',
                                  'spaceId': spaceId,
                                  'threadId': threadId,
                                  'returnTo': returnTo,
                                },
                              ).toString();
                              await context.push(inviteRoute);
                              if (!context.mounted) return;
                              _refreshThreadData();
                            },
                            onAddMembers: () async {
                              final spaceId = _pickString(thread, const [
                                'spaceId',
                                'space_id',
                              ]);
                              if (spaceId.isEmpty) return;
                              await context.push(
                                '/me/correspondence/$spaceId/invite',
                              );
                              if (!context.mounted) return;
                              _refreshThreadData();
                            },
                            onStartAudio: () =>
                                _startLive(thread: thread, kind: 'AUDIO'),
                            onStartVideo: () =>
                                _startLive(thread: thread, kind: 'VIDEO'),
                            onJoinLive: () async {
                              final sessionId = _threadResolvedSessionId(
                                thread,
                                liveState,
                                widget.threadId,
                              );
                              if (sessionId.isEmpty) return;
                              final controller = ref.read(
                                realtimeControllerProvider.notifier,
                              );
                              await controller.join(sessionId);
                            },
                            onLeaveLive: () async {
                              await ref
                                  .read(realtimeControllerProvider.notifier)
                                  .leave();
                            },
                            onToggleMicrophone: () async {
                              await ref
                                  .read(realtimeControllerProvider.notifier)
                                  .toggleMicrophone();
                            },
                            onToggleCamera: () async {
                              await ref
                                  .read(realtimeControllerProvider.notifier)
                                  .toggleCamera();
                            },
                          ),
                          const SizedBox(height: AuraSpace.s16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final wide = constraints.maxWidth >= 1180;
                              final conversationPanel = _ThreadConversationPanel(
                                threadId: threadId,
                                messagesAsync: messagesAsync,
                                currentUserId: currentUserId,
                                onRefresh: _refreshThreadData,
                                onEditMessage: (message) =>
                                    _showEditMessageDialog(
                                  context,
                                  ref,
                                  message,
                                ),
                                onDeleteMessage: (message) async {
                                  final messageId = _pickString(
                                    message,
                                    const ['id', 'messageId'],
                                  );
                                  if (messageId.isEmpty) return;
                                  await ref
                                      .read(messagesRepositoryProvider)
                                      .deleteMessage(messageId);
                                  _refreshThreadData();
                                },
                              );

                              final sideRail = _ThreadSideRail(
                                threadAsync: threadAsync,
                                liveState: liveState,
                                currentUserId: currentUserId,
                                onOpenSpace: () {
                                  final spaceId = _pickString(
                                    thread,
                                    const ['spaceId', 'space_id'],
                                  );
                                  if (spaceId.isEmpty) return;
                                  context.push('/me/correspondence/$spaceId');
                                },
                                onOpenInvites: () async {
                                  final spaceId = _pickString(
                                    thread,
                                    const ['spaceId', 'space_id'],
                                  );
                                  if (spaceId.isEmpty) return;
                                  await context.push(
                                    '/me/correspondence/$spaceId/invite',
                                  );
                                  if (!context.mounted) return;
                                  _refreshThreadData();
                                },
                                onStartAudio: () =>
                                    _startLive(thread: thread, kind: 'AUDIO'),
                                onStartVideo: () =>
                                    _startLive(thread: thread, kind: 'VIDEO'),
                              );

                              if (wide) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 7, child: conversationPanel),
                                    const SizedBox(width: AuraSpace.s16),
                                    SizedBox(width: 352, child: sideRail),
                                  ],
                                );
                              }

                              return Column(
                                children: [
                                  conversationPanel,
                                  const SizedBox(height: AuraSpace.s16),
                                  sideRail,
                                ],
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
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
      ref.invalidate(threadDetailProvider(widget.threadId));
      ref.invalidate(messagesProvider(widget.threadId));
    }
  }
}

class _ThreadHeaderCard extends StatelessWidget {
  const _ThreadHeaderCard({
    required this.thread,
    required this.contextData,
    required this.liveState,
    required this.onOpenSpace,
    required this.onInvite,
    required this.onAddMembers,
    required this.onStartAudio,
    required this.onStartVideo,
    required this.onJoinLive,
    required this.onLeaveLive,
    required this.onToggleMicrophone,
    required this.onToggleCamera,
  });

  final Map<String, dynamic> thread;
  final CorrespondenceThreadContext contextData;
  final RealtimeState liveState;
  final VoidCallback onOpenSpace;
  final VoidCallback onInvite;
  final VoidCallback onAddMembers;
  final Future<void> Function() onStartAudio;
  final Future<void> Function() onStartVideo;
  final Future<void> Function() onJoinLive;
  final Future<void> Function() onLeaveLive;
  final Future<void> Function() onToggleMicrophone;
  final Future<void> Function() onToggleCamera;

  @override
  Widget build(BuildContext context) {
    final spaceId = _pickString(thread, const ['spaceId', 'space_id']);
    final chips = contextData.participantChips;
    final kindLabel = contextData.kindLabel;

    return AuraCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AuraAvatar(
                name: contextData.title,
                imageUrl: contextData.avatarUrl,
                size: 44,
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
                        Text(contextData.title, style: AuraText.title),
                        AuraStatusChip(label: kindLabel),
                          if (spaceId.isNotEmpty)
                            const AuraStatusChip(
                              label: 'Space',
                              backgroundColor: AuraSurface.goodBg,
                              textColor: AuraSurface.goodInk,
                            ),
                      ],
                    ),
                    if (contextData.subtitle.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s4),
                      AuraTextBlock(
                        contextData.subtitle,
                        style: AuraText.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s10),
                      Wrap(
                        spacing: AuraSpace.s8,
                        runSpacing: AuraSpace.s8,
                        children: chips
                            .map(
                              (label) => AuraStatusChip(
                                label: label,
                                backgroundColor: AuraSurface.subtle,
                                textColor: AuraSurface.ink,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (contextData.roleSummary.isNotEmpty ||
                        contextData.activityWeight.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s4),
                      AuraTextBlock(
                        [
                          if (contextData.roleSummary.isNotEmpty)
                            contextData.roleSummary,
                          if (contextData.activityWeight.isNotEmpty)
                            contextData.activityWeight,
                        ].join(' · '),
                        style: AuraText.small.copyWith(
                          color: AuraSurface.muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AuraSpace.s12),
              Flexible(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AuraSpace.s6,
                    runSpacing: AuraSpace.s6,
                    children: [
                      _HeaderIconAction(
                        icon: Icons.call_rounded,
                        onPressed: () => onStartAudio(),
                      ),
                      _HeaderIconAction(
                        icon: Icons.videocam_rounded,
                        onPressed: () => onStartVideo(),
                      ),
                      if (spaceId.isNotEmpty)
                        _HeaderIconAction(
                          icon: Icons.person_add_alt_1_rounded,
                          onPressed: onAddMembers,
                        ),
                      if (spaceId.isNotEmpty)
                        _HeaderIconAction(
                          icon: Icons.group_add_rounded,
                          onPressed: onInvite,
                        ),
                      if (spaceId.isNotEmpty)
                        _HeaderIconAction(
                          icon: Icons.open_in_new_rounded,
                          onPressed: onOpenSpace,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s12),
          _ThreadLiveDock(
            thread: thread,
            liveState: liveState,
            onJoinLive: onJoinLive,
            onLeaveLive: onLeaveLive,
            onToggleMicrophone: onToggleMicrophone,
            onToggleCamera: onToggleCamera,
          ),
        ],
      ),
    );
  }
}

class _HeaderIconAction extends StatelessWidget {
  const _HeaderIconAction({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

class _ThreadConversationPanel extends StatelessWidget {
  const _ThreadConversationPanel({
    required this.threadId,
    required this.messagesAsync,
    required this.currentUserId,
    required this.onRefresh,
    required this.onEditMessage,
    required this.onDeleteMessage,
  });

  final String threadId;
  final AsyncValue<List<Map<String, dynamic>>> messagesAsync;
  final String currentUserId;
  final VoidCallback onRefresh;
  final void Function(Map<String, dynamic> message) onEditMessage;
  final Future<void> Function(Map<String, dynamic> message) onDeleteMessage;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text('Messages', style: AuraText.title),
              ),
              AuraStatusChip(
                label: 'Thread',
                backgroundColor: AuraSurface.subtle,
                textColor: AuraSurface.muted,
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s12),
          messagesAsync.when(
            loading: () => const AuraCard(
              child: _LoadingBlock(label: 'Loading messages...'),
            ),
            error: (error, _) => AuraCard(
              child: _ErrorBlock(
                title: 'Could not load messages',
                body: '$error',
                onRetry: onRefresh,
              ),
            ),
            data: (messages) {
              if (messages.isEmpty) {
                return const AuraEmptyState(
                  title: 'No messages yet',
                  body: 'This conversation has not started yet. Your first note will appear here.',
                  icon: Icons.forum_outlined,
                );
              }

              return Column(
                children: [
                  for (var i = 0; i < messages.length; i++) ...[
                    _MessageTile(
                      message: messages[i],
                      currentUserId: currentUserId,
                      showAuthorHeader: !_isSameSender(
                        messages[i],
                        i > 0 ? messages[i - 1] : null,
                      ),
                      onEdit: () => onEditMessage(messages[i]),
                      onDelete: () => onDeleteMessage(messages[i]),
                    ),
                    if (i != messages.length - 1)
                      const SizedBox(height: AuraSpace.s10),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: AuraSpace.s16),
          _ComposerBar(threadId: threadId, onSent: onRefresh),
        ],
      ),
    );
  }
}

class _ThreadSideRail extends StatelessWidget {
  const _ThreadSideRail({
    required this.threadAsync,
    required this.liveState,
    required this.currentUserId,
    this.onOpenSpace,
    this.onOpenInvites,
    this.onStartAudio,
    this.onStartVideo,
  });

  final AsyncValue<Map<String, dynamic>> threadAsync;
  final RealtimeState liveState;
  final String currentUserId;
  final VoidCallback? onOpenSpace;
  final Future<void> Function()? onOpenInvites;
  final Future<void> Function()? onStartAudio;
  final Future<void> Function()? onStartVideo;

  @override
  Widget build(BuildContext context) {
    return threadAsync.when(
      loading: () => const AuraCard(
        child: _LoadingBlock(label: 'Loading context...'),
      ),
      error: (error, _) => AuraErrorState(
        title: 'Could not load thread context',
        body: '$error',
      ),
      data: (thread) {
        final threadContext = CorrespondenceIdentity.resolveThreadContext(
          thread,
          currentUserId: currentUserId,
        );
        final participants = CorrespondenceIdentity.extractParticipants(thread);
        final spaceId = _pickString(thread, const ['spaceId', 'space_id']);
        final showSpaceActions = spaceId.isNotEmpty;
        final joinedCount = liveState.participants.where((p) => p.isPresent).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuraCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Conversation brief', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s12),
                  AuraAvatar(
                    name: threadContext.title,
                    imageUrl: threadContext.avatarUrl,
                    size: 52,
                  ),
                  const SizedBox(height: AuraSpace.s12),
                  Text(threadContext.title, style: AuraText.subtitle),
                  if (threadContext.subtitle.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s6),
                    Text(
                      threadContext.subtitle,
                      style: AuraText.muted,
                    ),
                  ],
                  if (threadContext.participantChips.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s12),
                    Wrap(
                      spacing: AuraSpace.s8,
                      runSpacing: AuraSpace.s8,
                      children: threadContext.participantChips
                          .map(
                            (label) => AuraStatusChip(
                              label: label,
                              backgroundColor: AuraSurface.subtle,
                              textColor: AuraSurface.ink,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if (threadContext.roleSummary.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s12),
                    Text(threadContext.roleSummary, style: AuraText.small),
                  ],
                  if (threadContext.activityWeight.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s6),
                    Text(threadContext.activityWeight, style: AuraText.small),
                  ],
                  if (participants.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s12),
                    Text(
                      '${participants.length} participant${participants.length == 1 ? '' : 's'}',
                      style: AuraText.small.copyWith(color: AuraSurface.muted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AuraSpace.s12),
            AuraCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Live status', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s10),
                  Text(
                    joinedCount > 0
                        ? 'Live participants present now.'
                        : 'No one is currently joined.',
                    style: AuraText.body,
                  ),
                  if (onStartAudio != null || onStartVideo != null) ...[
                    const SizedBox(height: AuraSpace.s12),
                    Wrap(
                      spacing: AuraSpace.s10,
                      runSpacing: AuraSpace.s10,
                      children: [
                        if (onStartAudio != null)
                          AuraSecondaryButton(
                            label: 'Audio call',
                            icon: Icons.call_rounded,
                            onPressed: () => onStartAudio!(),
                          ),
                        if (onStartVideo != null)
                          AuraSecondaryButton(
                            label: 'Video call',
                            icon: Icons.videocam_rounded,
                            onPressed: () => onStartVideo!(),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (showSpaceActions) ...[
              const SizedBox(height: AuraSpace.s12),
              AuraCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Space actions', style: AuraText.title),
                    const SizedBox(height: AuraSpace.s10),
                    if (onOpenSpace != null)
                      AuraSecondaryButton(
                        label: 'Open space',
                        icon: Icons.open_in_new_rounded,
                        onPressed: onOpenSpace,
                      ),
                    const SizedBox(height: AuraSpace.s10),
                    if (onOpenInvites != null)
                      AuraSecondaryButton(
                        label: 'Manage invites',
                        icon: Icons.mail_outline_rounded,
                        onPressed: () => onOpenInvites!(),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

String _threadScreenTitle(
  Map<String, dynamic> thread, {
  String? currentUserId,
}) {
  return CorrespondenceIdentity.threadDisplayTitle(
    thread,
    currentUserId: currentUserId,
  );
}

List<Map<String, dynamic>> _extractParticipants(Map<String, dynamic> thread) {
  return CorrespondenceIdentity.extractParticipants(thread);
}

String _identityLabel(Map<String, dynamic> entity) {
  return CorrespondenceIdentity.identityLabel(entity);
}

String _threadLiveSurfaceType(Map<String, dynamic> thread) {
  return 'THREAD';
}

String _threadLiveSurfaceId(Map<String, dynamic> thread, String threadId) {
  return threadId;
}

bool _threadMatchesLiveState(
  RealtimeState liveState,
  Map<String, dynamic> thread,
) {
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
    required this.onJoinLive,
    required this.onLeaveLive,
    required this.onToggleMicrophone,
    required this.onToggleCamera,
  });

  final Map<String, dynamic> thread;
  final RealtimeState liveState;
  final Future<void> Function() onJoinLive;
  final Future<void> Function() onLeaveLive;
  final Future<void> Function() onToggleMicrophone;
  final Future<void> Function() onToggleCamera;

  @override
  Widget build(BuildContext context) {
    final belongsHere = _threadMatchesLiveState(liveState, thread);
    final sessionId = _threadResolvedSessionId(
      thread,
      liveState,
      _pickString(thread, const ['id', 'threadId']),
    );
    final hasLive =
        sessionId.isNotEmpty &&
        (belongsHere ||
            _pickString(thread, const [
              'liveSessionId',
              'activeSessionId',
            ]).isNotEmpty ||
            _pickNested(thread, const [
              ['live', 'sessionId'],
              ['activeLive', 'sessionId'],
              ['realtime', 'sessionId'],
            ]).isNotEmpty);
    if (!hasLive) return const SizedBox.shrink();

    final joinedCount = liveState.participants.where((p) => p.isPresent).length;
    final startedByUserId = _threadStartedByUserId(thread, liveState);
    final startedByEntity = _extractParticipants(thread)
        .cast<Map<String, dynamic>?>()
        .firstWhere((participant) {
          if (participant == null) return false;
          final id = _pickString(participant, const [
            'id',
            '_id',
            'userId',
            'memberId',
          ]);
          return id.isNotEmpty && id == startedByUserId;
        }, orElse: () => null);
    final startedByName = startedByEntity == null
        ? ''
        : _identityLabel(startedByEntity);
    final liveKind = _threadLiveKind(thread, liveState);
    final hasVideoStage =
        liveState.isJoined &&
        (liveState.isVideoMode ||
            (!liveState.isAudioMode &&
                (liveState.localRenderer != null ||
                    liveState.remoteRenderers.isNotEmpty ||
                    liveState.participants.any(
                      (p) => p.videoOn || p.screenOn,
                    ))));
    final hasAudioState = liveState.isJoined && !hasVideoStage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ThreadStatusStrip(
          joinedCount: joinedCount,
          isJoined: liveState.isJoined,
          isBusy: liveState.isBusy,
          microphoneEnabled: liveState.microphoneEnabled,
          cameraEnabled: liveState.cameraEnabled,
          liveLabel: startedByName.isNotEmpty
              ? (liveState.isJoined
                    ? '$startedByName · ${liveKind == 'video' ? 'video' : 'audio'}'
                    : '$startedByName is calling')
              : (liveKind == 'video' ? 'Video call' : 'Audio call'),
          liveDetail: joinedCount > 0
              ? (joinedCount == 1 ? '1 joined' : '$joinedCount joined')
              : 'Waiting for response',
          onJoin: onJoinLive,
          onLeave: onLeaveLive,
          onToggleMicrophone: onToggleMicrophone,
          onToggleCamera: hasVideoStage ? onToggleCamera : null,
        ),
        if (hasAudioState) ...[
          const SizedBox(height: AuraSpace.s12),
          _ThreadAudioStage(
            participants: liveState.participants,
            microphoneEnabled: liveState.microphoneEnabled,
            onToggleMicrophone: onToggleMicrophone,
            onLeave: onLeaveLive,
          ),
        ],
        if (hasVideoStage) ...[
          const SizedBox(height: AuraSpace.s12),
          _ThreadVideoStage(
            localRenderer: liveState.localRenderer,
            remoteRenderers: liveState.remoteRenderers,
            participants: liveState.participants,
            microphoneEnabled: liveState.microphoneEnabled,
            cameraEnabled: liveState.cameraEnabled,
            onToggleMicrophone: onToggleMicrophone,
            onToggleCamera: onToggleCamera,
            onLeave: onLeaveLive,
          ),
        ],
      ],
    );
  }
}

class _ThreadStatusStrip extends StatelessWidget {
  const _ThreadStatusStrip({
    required this.joinedCount,
    required this.isJoined,
    required this.isBusy,
    required this.microphoneEnabled,
    required this.cameraEnabled,
    required this.liveLabel,
    required this.liveDetail,
    required this.onJoin,
    required this.onLeave,
    required this.onToggleMicrophone,
    this.onToggleCamera,
  });

  final int joinedCount;
  final bool isJoined;
  final bool isBusy;
  final bool microphoneEnabled;
  final bool cameraEnabled;
  final String liveLabel;
  final String liveDetail;
  final Future<void> Function() onJoin;
  final Future<void> Function() onLeave;
  final Future<void> Function() onToggleMicrophone;
  final Future<void> Function()? onToggleCamera;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AuraSurface.overlay,
        border: Border.all(color: AuraSurface.divider),
        borderRadius: BorderRadius.circular(AuraRadius.md),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isJoined ? AuraSurface.goodInk : AuraSurface.muted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  liveLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AuraText.small.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (liveDetail.trim().isNotEmpty)
                  Text(
                    liveDetail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuraText.small.copyWith(color: AuraSurface.muted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AuraSpace.s10),
          if (!isJoined)
            _StripIconButton(
              icon: Icons.login_rounded,
              enabled: !isBusy,
              onTap: () => onJoin(),
            ),
          if (isJoined) ...[
            _StripIconButton(
              icon: microphoneEnabled
                  ? Icons.mic_off_rounded
                  : Icons.mic_rounded,
              onTap: () => onToggleMicrophone(),
            ),
            if (onToggleCamera != null) ...[
              const SizedBox(width: AuraSpace.s8),
              _StripIconButton(
                icon: cameraEnabled
                    ? Icons.videocam_off_rounded
                    : Icons.videocam_rounded,
                onTap: () => onToggleCamera!(),
              ),
            ],
            const SizedBox(width: AuraSpace.s8),
            _StripIconButton(
              icon: Icons.call_end_rounded,
              tone: AuraSurface.dangerInk,
              onTap: () => onLeave(),
            ),
          ],
        ],
      ),
    );
  }
}

class _StripIconButton extends StatelessWidget {
  const _StripIconButton({
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.tone,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? (tone ?? Colors.white) : Colors.white38;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

class _ThreadAudioStage extends StatelessWidget {
  const _ThreadAudioStage({
    required this.participants,
    required this.microphoneEnabled,
    required this.onToggleMicrophone,
    required this.onLeave,
  });

  final List<RealtimeParticipant> participants;
  final bool microphoneEnabled;
  final Future<void> Function() onToggleMicrophone;
  final Future<void> Function() onLeave;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: participants.isEmpty
                ? const <Widget>[]
                : participants
                      .map((p) => _ThreadParticipantChip(participant: p))
                      .toList(),
          ),
        ],
      ),
    );
  }
}

class _ThreadParticipantChip extends StatelessWidget {
  const _ThreadParticipantChip({required this.participant});

  final RealtimeParticipant participant;

  @override
  Widget build(BuildContext context) {
    final label = participant.isHost ? 'Host' : 'Member';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: participant.isPresent
                  ? AuraSurface.goodInk
                  : AuraSurface.faint,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
          ),
          if (participant.audioOn ||
              participant.videoOn ||
              participant.screenOn) ...[
            const SizedBox(width: 8),
            Icon(
              participant.screenOn
                  ? Icons.screen_share_rounded
                  : participant.videoOn
                  ? Icons.videocam_rounded
                  : Icons.mic_rounded,
              size: 14,
              color: AuraSurface.muted,
            ),
          ],
        ],
      ),
    );
  }
}

class _ThreadVideoStage extends StatelessWidget {
  const _ThreadVideoStage({
    required this.localRenderer,
    required this.remoteRenderers,
    required this.participants,
    required this.microphoneEnabled,
    required this.cameraEnabled,
    required this.onToggleMicrophone,
    required this.onToggleCamera,
    required this.onLeave,
  });

  final RTCVideoRenderer? localRenderer;
  final Map<String, RTCVideoRenderer> remoteRenderers;
  final List<RealtimeParticipant> participants;
  final bool microphoneEnabled;
  final bool cameraEnabled;
  final Future<void> Function() onToggleMicrophone;
  final Future<void> Function() onToggleCamera;
  final Future<void> Function() onLeave;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];
    if (localRenderer != null) {
      tiles.add(
        _ThreadVideoTile(label: 'You', renderer: localRenderer!, mirror: true),
      );
    }
    remoteRenderers.forEach((key, renderer) {
      final participant = participants.cast<RealtimeParticipant?>().firstWhere(
        (p) => p?.runtimeDeviceId == key || p?.userId == key,
        orElse: () => null,
      );
      final label = participant?.isHost == true ? 'Host' : 'Member';
      tiles.add(_ThreadVideoTile(label: label, renderer: renderer));
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: tiles.length <= 1 ? 1 : 2,
          mainAxisSpacing: AuraSpace.s10,
          crossAxisSpacing: AuraSpace.s10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.08,
          children: tiles,
        ),
      ],
    );
  }
}

class _ThreadVideoTile extends StatelessWidget {
  const _ThreadVideoTile({
    required this.label,
    required this.renderer,
    this.mirror = false,
  });

  final String label;
  final RTCVideoRenderer renderer;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: RTCVideoView(
              renderer,
              mirror: mirror,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),
          Positioned(
            left: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AuraRadius.pill),
              ),
              child: Text(
                label,
                style: AuraText.small.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
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

class _ComposerBar extends ConsumerStatefulWidget {
  const _ComposerBar({required this.threadId, required this.onSent});

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
  DateTime? _recordingStartedAt;
  Timer? _recordingTicker;
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
  bool get _isMobileCapturePlatform {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
  }

  bool get _supportsCameraCapture => _isMobileCapturePlatform;
  bool get _supportsAudioRecording => _isMobileCapturePlatform;

  @override
  void dispose() {
    _recordingTicker?.cancel();
    _controller.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  bool get _canSend {
    if (_sending) return false;
    if (_recordingAudio) return false;
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
    if (!_supportsCameraCapture) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Camera capture is not available here. Choose a file instead.',
          ),
        ),
      );
      await _pickImageFromGallery();
      return;
    }
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
    if (!_supportsCameraCapture) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Video capture is not available here. Choose a file instead.',
          ),
        ),
      );
      await _pickVideoFromGallery();
      return;
    }
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
      await _finishAudioRecording(keep: true);
      return;
    }

    if (!_supportsAudioRecording) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Audio recording is not available here. Upload an audio file instead.',
          ),
        ),
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
    _recordingTicker?.cancel();
    _recordingStartedAt = DateTime.now();
    _recordingTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_recordingAudio || _recordingStartedAt == null) return;
      setState(() {});
    });
    setState(() => _recordingAudio = true);
  }

  Future<void> _cancelAudioRecording() async {
    await _finishAudioRecording(keep: false);
  }

  Future<void> _finishAudioRecording({required bool keep}) async {
    if (!_recordingAudio) return;

    final startedAt = _recordingStartedAt;
    final path = await _audioRecorder.stop();
    if (!mounted) return;

    _recordingTicker?.cancel();
    _recordingTicker = null;
    _recordingStartedAt = null;

    setState(() => _recordingAudio = false);

    if (!keep) return;

    if (path == null || path.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save audio recording.')),
      );
      return;
    }

    final file = XFile(path, mimeType: 'audio/aac');
    final elapsed = startedAt == null
        ? null
        : DateTime.now().difference(startedAt);
    await _addAttachment(
      file,
      kind: _AttachmentKind.audio,
      source: _AttachmentSource.recording,
      duration: elapsed,
    );
  }

  Future<void> _addAttachment(
    XFile file, {
    required _AttachmentKind kind,
    _AttachmentSource source = _AttachmentSource.gallery,
    Duration? duration,
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
      durationSec: duration?.inSeconds,
    );
    attachment.uploading = true;

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
    final result = await uploadAuraMedia(
      dio: ref.read(dioProvider),
      bytes: attachment.bytes,
      fileName: attachment.file.name,
      mimeType: attachment.mimeType,
      kind: _mediaKindValue(attachment.kind),
      source: _mediaSourceValue(attachment.source),
      width: attachment.width,
      height: attachment.height,
      duration: attachment.kind == _AttachmentKind.audio
          ? attachment.durationSec
          : null,
      metadataPatch: <String, dynamic>{
        if (attachment.width != null) 'width': attachment.width,
        if (attachment.height != null) 'height': attachment.height,
        'editDisclosure': false,
      },
    );

    attachment.storageKey = result.storageKey;
    attachment.url = result.url.isNotEmpty ? result.url : null;
    attachment.thumbUrl = result.thumbUrl.isNotEmpty ? result.thumbUrl : null;

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
        '/composition/review',
        data: {'text': text, 'surface': 'dm'},
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
      if (!context.mounted) return;
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
        '/composition/apply',
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
        _suggestions = findings.isNotEmpty
            ? findings
            : _suggestions.where((item) {
                final id = _firstNonEmpty(item, const ['id', 'findingId']);
                return id != suggestionId;
              }).toList();
        _dismissedSuggestionIds.remove(suggestionId);
      });
    } catch (e) {
      if (!context.mounted) return;
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
        '/composition/translate',
        data: {'text': text, 'targetLanguage': _translationTargetLanguage},
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
        .where(
          (a) => !a.uploading && a.error == null && a.storageKey.isNotEmpty,
        )
        .map((a) => a.toMessagePayload())
        .toList();

    setState(() => _sending = true);

    try {
      await ref
          .read(messagesRepositoryProvider)
          .sendMessage(
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not send message: $e')));
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

    final width = MediaQuery.sizeOf(context).width;
    final desktopSheet = width >= 760;

    Widget buildSheet(BuildContext sheetContext) {
      Future<void> openAction(Future<void> Function() action) async {
        Navigator.of(sheetContext).pop();
        await Future<void>.microtask(action);
      }

      final actions = _attachmentActions(sheetContext, onTap: openAction);
      final body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: actions,
      );

      if (desktopSheet) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AuraCard(
                padding: const EdgeInsets.all(16),
                child: body,
              ),
            ),
          ),
        );
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          child: AuraCard(
            padding: const EdgeInsets.all(12),
            child: body,
          ),
        ),
      );
    }

    if (desktopSheet) {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black54,
        builder: buildSheet,
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: buildSheet,
    );
  }

  List<Widget> _attachmentActions(
    BuildContext context, {
    required Future<void> Function(Future<void> Function() action) onTap,
  }) {
    final children = <Widget>[];

    if (_supportsCameraCapture) {
      children.addAll([
        _AttachmentActionTile(
          icon: Icons.photo_camera_outlined,
          title: 'Take photo',
          subtitle: 'Open the camera',
          onTap: () => onTap(_pickImageFromCamera),
        ),
        _AttachmentActionTile(
          icon: Icons.image_outlined,
          title: 'Choose photo',
          subtitle: 'Pick from your library',
          onTap: () => onTap(_pickImageFromGallery),
        ),
        _AttachmentActionTile(
          icon: Icons.videocam_outlined,
          title: 'Record video',
          subtitle: 'Capture a short video',
          onTap: () => onTap(_pickVideoFromCamera),
        ),
        _AttachmentActionTile(
          icon: Icons.video_library_outlined,
          title: 'Choose video',
          subtitle: 'Pick a video file',
          onTap: () => onTap(_pickVideoFromGallery),
        ),
      ]);
    } else {
      children.addAll([
        _AttachmentActionTile(
          icon: Icons.image_outlined,
          title: 'Choose photo',
          subtitle: kIsWeb
              ? 'Upload an image from this browser'
              : 'Pick an image from this device',
          onTap: () => onTap(_pickImageFromGallery),
        ),
        _AttachmentActionTile(
          icon: Icons.videocam_outlined,
          title: 'Choose video',
          subtitle: kIsWeb
              ? 'Upload a video from this browser'
              : 'Pick a video from this device',
          onTap: () => onTap(_pickVideoFromGallery),
        ),
      ]);
    }

    if (_supportsAudioRecording) {
      children.add(
        _AttachmentActionTile(
          icon: _recordingAudio
              ? Icons.stop_circle_outlined
              : Icons.mic_none_rounded,
          title: _recordingAudio ? 'Stop audio recording' : 'Record audio',
          subtitle: _recordingAudio
              ? 'Finishing current recording'
              : 'Capture a voice note',
          onTap: () => onTap(_toggleAudioRecording),
        ),
      );
    } else {
      children.add(
        const _AttachmentActionTile(
          icon: Icons.mic_none_rounded,
          title: 'Audio recording unavailable',
          subtitle: 'This device or browser does not support recording.',
          enabled: false,
          onTap: null,
        ),
      );
    }

    children.add(
      _AttachmentActionTile(
        icon: Icons.audio_file_outlined,
        title: 'Upload audio',
        subtitle: 'Attach an audio file',
        onTap: () => onTap(_pickAudioFile),
      ),
    );

    return children;
  }

  Future<void> _pickComposerLanguage() async {
    if (_translationBusy) return;
    final current = _translationTargetLanguage.trim().toLowerCase();

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
                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: InkWell(
                        onTap: () => Navigator.of(ctx).pop(entry.key),
                        borderRadius: BorderRadius.circular(AuraRadius.pill),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AuraSpace.s12,
                            vertical: AuraSpace.s8,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? AuraSurface.overlay
                                : Colors.transparent,
                            border: Border.all(color: AuraSurface.divider),
                            borderRadius:
                                BorderRadius.circular(AuraRadius.pill),
                          ),
                          child: Text(
                            entry.value,
                            style: AuraText.small.copyWith(
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? AuraSurface.ink
                                  : AuraSurface.muted,
                            ),
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final uploadingCount = _attachments.where((a) => a.uploading).length;
    final recordingElapsed = _recordingStartedAt == null
        ? Duration.zero
        : DateTime.now().difference(_recordingStartedAt!);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AuraCard(
              padding: const EdgeInsets.all(14),
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
                  if (_recordingAudio) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AuraSurface.dangerBg,
                        borderRadius: BorderRadius.circular(AuraRadius.md),
                        border: Border.all(
                          color: AuraSurface.dangerInk.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.fiber_manual_record,
                            size: 14,
                            color: AuraSurface.dangerInk,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Recording audio ${_formatRecordingDuration(recordingElapsed)}',
                              style: AuraText.body.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          AuraGhostButton(
                            label: 'Cancel',
                            onPressed: _sending ? null : _cancelAudioRecording,
                          ),
                          const SizedBox(width: 6),
                          AuraPrimaryButton(
                            label: 'Stop',
                            icon: Icons.stop_rounded,
                            onPressed: _sending
                                ? null
                                : () => _toggleAudioRecording(),
                          ),
                        ],
                      ),
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
                        final id = _firstNonEmpty(suggestion, const [
                          'id',
                          'findingId',
                        ]);
                        if (id.isEmpty) return;
                        setState(() => _dismissedSuggestionIds.add(id));
                      },
                    ),
                    const SizedBox(height: AuraSpace.s10),
                  ],
                  if (_translationPreview != null ||
                      _translationError != null) ...[
                    _ComposerTranslationPanel(
                      targetLanguage: _translationTargetLanguage,
                      preview: _translationPreview,
                      errorText: _translationError,
                      busy: _translationBusy,
                      onApply:
                          _translationPreview == null ? null : _applyTranslation,
                      onRestore: _translationSnapshot == null
                          ? null
                          : _restoreBeforeTranslation,
                    ),
                    const SizedBox(height: AuraSpace.s10),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AuraSurface.subtle,
                          borderRadius: BorderRadius.circular(
                            AuraRadius.r14,
                          ),
                          border: Border.all(color: AuraSurface.divider),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          onPressed: _sending ? null : _showAttachmentSheet,
                          icon: const Icon(Icons.add_circle_outline),
                          tooltip: 'Add attachment',
                        ),
                      ),
                      const SizedBox(width: AuraSpace.s10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _controller,
                              minLines: 1,
                              maxLines: 6,
                              decoration: InputDecoration(
                                hintText: _recordingAudio
                                    ? 'Recording audio...'
                                    : 'Write a message',
                                filled: true,
                                fillColor: AuraSurface.subtle,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AuraRadius.r16,
                                  ),
                                  borderSide:
                                      const BorderSide(color: AuraSurface.divider),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AuraRadius.r16,
                                  ),
                                  borderSide:
                                      const BorderSide(color: AuraSurface.divider),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AuraRadius.r16,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AuraSurface.accent,
                                  ),
                                ),
                              ),
                              onChanged: (_) {
                                setState(() {
                                  if ((_assistSnapshot ?? '') !=
                                      _controller.text.trim()) {
                                    _suggestions = const [];
                                    _assistError = null;
                                    _assistSessionId = null;
                                    _dismissedSuggestionIds.clear();
                                  }
                                  if ((_translationSnapshot ?? '') !=
                                      _controller.text.trim()) {
                                    _translationPreview = null;
                                    _translationError = null;
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: AuraSpace.s8),
                            Wrap(
                              spacing: AuraSpace.s8,
                              runSpacing: AuraSpace.s8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                AuraSecondaryButton(
                                  label: _assistBusy ? 'Polishing…' : 'Polish',
                                  icon: Icons.auto_fix_high_outlined,
                                  onPressed: !_hasText || _assistBusy
                                      ? null
                                      : _runAssist,
                                ),
                                MouseRegion(
                                  cursor: _translationBusy
                                      ? SystemMouseCursors.basic
                                      : SystemMouseCursors.click,
                                  child: InkWell(
                                    onTap: _translationBusy
                                        ? null
                                        : _pickComposerLanguage,
                                    borderRadius: BorderRadius.circular(
                                      AuraRadius.pill,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AuraSpace.s12,
                                        vertical: AuraSpace.s8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AuraSurface.subtle,
                                        border: Border.all(
                                          color: AuraSurface.divider,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AuraRadius.pill,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.translate,
                                            size: 14,
                                            color: AuraSurface.muted,
                                          ),
                                          const SizedBox(width: AuraSpace.s6),
                                          Text(
                                            _languageLabel(
                                              _translationTargetLanguage,
                                            ),
                                            style: AuraText.small.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(width: AuraSpace.s4),
                                          const Icon(
                                            Icons.arrow_drop_down_rounded,
                                            size: 16,
                                            color: AuraSurface.muted,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                AuraSecondaryButton(
                                  label: _translationBusy
                                      ? 'Translating…'
                                      : 'Translate',
                                  icon: Icons.translate_outlined,
                                  onPressed: !_hasText || _translationBusy
                                      ? null
                                      : _translateDraft,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AuraSpace.s10),
                      AuraPrimaryButton(
                        label: _sending
                            ? 'Sending…'
                            : uploadingCount > 0
                                ? 'Uploading…'
                                : 'Send',
                        onPressed: _canSend ? _submit : null,
                        icon: Icons.send_rounded,
                      ),
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

class _AttachmentActionTile extends StatelessWidget {
  const _AttachmentActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = enabled && onTap != null;
    return ListTile(
      enabled: active,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AuraSurface.subtle,
          borderRadius: BorderRadius.circular(AuraRadius.r12),
          border: Border.all(color: AuraSurface.divider),
        ),
        child: Icon(
          icon,
          color: active ? AuraSurface.ink : AuraSurface.faint,
          size: 18,
        ),
      ),
      title: Text(
        title,
        style: AuraText.body.copyWith(
          fontWeight: FontWeight.w700,
          color: active ? AuraSurface.ink : AuraSurface.faint,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AuraText.small.copyWith(
          color: active ? AuraSurface.muted : AuraSurface.faint,
        ),
      ),
      onTap: onTap,
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
          const Text('Writing support', style: AuraText.title),
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
    final message = _firstNonEmpty(suggestion, const [
      'message',
      'title',
      'finding',
    ]);
    final detail = _firstNonEmpty(suggestion, const [
      'suggestion',
      'detail',
      'description',
    ]);

    return Container(
      padding: const EdgeInsets.all(AuraSpace.s12),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        border: Border.all(color: AuraSurface.divider),
        borderRadius: BorderRadius.circular(AuraRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.isNotEmpty)
            Text(
              message,
              style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
            ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text(detail, style: AuraText.body),
          ],
          const SizedBox(height: AuraSpace.s10),
          Row(
            children: [
              AuraGhostButton(
                label: 'Dismiss',
                onPressed: busy ? null : onDismiss,
              ),
              const SizedBox(width: AuraSpace.s8),
              AuraPrimaryButton(
                label: busy ? 'Applying…' : 'Apply',
                onPressed: busy ? null : onApply,
                icon: Icons.check_rounded,
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
          const Text('Translation preview', style: AuraText.title),
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
                AuraGhostButton(
                  label: 'Restore original',
                  onPressed: busy ? null : onRestore,
                ),
                const SizedBox(width: AuraSpace.s8),
                AuraPrimaryButton(
                  label: 'Use translation',
                  onPressed: busy ? null : onApply,
                  icon: Icons.check_rounded,
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
        color: AuraSurface.subtle,
        border: Border.all(color: AuraSurface.divider),
        borderRadius: BorderRadius.circular(AuraRadius.md),
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
      await ref
          .read(messagesRepositoryProvider)
          .editMessage(messageId: messageId, body: body);

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
              decoration: const InputDecoration(labelText: 'Message'),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: AuraSpace.s12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorText!,
                  style: AuraText.small.copyWith(color: AuraSurface.dangerInk),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        AuraGhostButton(
          label: 'Cancel',
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
        AuraPrimaryButton(
          label: _saving ? 'Saving…' : 'Save',
          onPressed: _saving ? null : _submit,
          icon: Icons.check_rounded,
        ),
      ],
    );
  }
}

String _formatRecordingDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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
    final current =
        (_translationTargetLanguage ?? _defaultTranslationLanguage(context))
            .toLowerCase();

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
                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: InkWell(
                      onTap: () => Navigator.of(ctx).pop(entry.key),
                      borderRadius: BorderRadius.circular(AuraRadius.pill),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AuraSpace.s12,
                          vertical: AuraSpace.s8,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? AuraSurface.overlay
                              : Colors.transparent,
                          border: Border.all(color: AuraSurface.divider),
                          borderRadius: BorderRadius.circular(AuraRadius.pill),
                        ),
                        child: Text(
                          entry.value,
                          style: AuraText.small.copyWith(
                            fontWeight: FontWeight.w700,
                            color: active ? AuraSurface.ink : AuraSurface.muted,
                          ),
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

    final target =
        (_translationTargetLanguage ?? _defaultTranslationLanguage(context))
            .toLowerCase();

    setState(() {
      _translationBusy = true;
      _translationError = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post(
        '/composition/translate',
        data: {'text': trimmed, 'targetLanguage': target},
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
      if (!context.mounted) return;
      setState(() {
        _translationBusy = false;
        _translationError = 'Could not translate this message right now.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not translate this message right now.'),
        ),
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
    final createdAt = _pickString(message, const [
      'createdAt',
      'sentAt',
      'timestamp',
    ]);
    final attachments = _listOfMap(message['attachments']);
    final senderId = _extractSenderId(message);
    final isMine =
        currentUserId.trim().isNotEmpty &&
        senderId.trim() == currentUserId.trim();

    final bubbleColor = isMine ? AuraSurface.overlay : AuraSurface.elevated;
    final bubbleBorderColor = isMine
        ? AuraSurface.accent.withValues(alpha: 0.3)
        : AuraSurface.divider;
    const textColor = AuraSurface.ink;
    const metaColor = AuraSurface.muted;
    const translatedTextColor = AuraSurface.ink;
    const translatedSurfaceColor = AuraSurface.subtle;

    _translationTargetLanguage ??= _defaultTranslationLanguage(context);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width > 900 ? 660 : 560,
        ),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isMine && showAuthorHeader && author.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 6),
                child: MouseRegion(
                  cursor: handle.isEmpty
                      ? SystemMouseCursors.basic
                      : SystemMouseCursors.click,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: handle.isEmpty
                        ? null
                        : () => context.push('/u/$handle'),
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
                        MouseRegion(
                          cursor: _translationBusy
                              ? SystemMouseCursors.basic
                              : SystemMouseCursors.click,
                          child: InkWell(
                            onTap: _translationBusy
                                ? null
                                : () => _translateMessage(context, body),
                            borderRadius: BorderRadius.circular(AuraRadius.pill),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AuraSpace.s6,
                                vertical: AuraSpace.s6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_translationBusy) ...[
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          AuraSurface.muted,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AuraSpace.s8),
                                  ],
                                  Text(
                                    _translationBusy
                                        ? 'Translating...'
                                        : (_showTranslation
                                              ? 'Refresh translation'
                                              : 'Translate'),
                                    style: AuraText.small.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: metaColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: InkWell(
                            onTap: () => _pickTranslationLanguage(context),
                            borderRadius: BorderRadius.circular(AuraRadius.pill),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AuraSpace.s10,
                                vertical: AuraSpace.s6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                  AuraRadius.pill,
                                ),
                                border: Border.all(color: AuraSurface.divider),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.translate,
                                    size: 14,
                                    color: metaColor,
                                  ),
                                  const SizedBox(width: AuraSpace.s6),
                                  Text(
                                    _languageLabel(
                                      _translationTargetLanguage ??
                                          _defaultTranslationLanguage(context),
                                    ),
                                    style: AuraText.small.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AuraSurface.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_showTranslation)
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _showTranslation = false;
                                  _translationError = null;
                                });
                              },
                              borderRadius: BorderRadius.circular(
                                AuraRadius.pill,
                              ),
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
                          ),
                      ],
                    ),
                    if ((_translationError ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s8),
                      Text(
                        _translationError!,
                        style: AuraText.small.copyWith(
                          color: AuraSurface.dangerInk,
                        ),
                      ),
                    ],
                    if (_showTranslation &&
                        (_translatedText ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AuraSpace.s10),
                        decoration: BoxDecoration(
                          color: translatedSurfaceColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AuraSurface.divider),
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
                              textDirection: _directionForText(
                                _translatedText!,
                              ),
                              child: AuraTextBlock(
                                _translatedText!,
                                textAlign: _alignForText(_translatedText!),
                                style: AuraText.body.copyWith(
                                  color: translatedTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (attachments.isNotEmpty)
                      const SizedBox(height: AuraSpace.s10),
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
                          icon: const Icon(
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
          _MessageAttachmentCard(attachment: attachments[i], isMine: isMine),
          if (i != attachments.length - 1) const SizedBox(height: AuraSpace.s8),
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
      mode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
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
                        color: AuraSurface.overlay,
                        borderRadius: BorderRadius.circular(AuraRadius.card),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Could not load image.',
                        style: AuraText.body.copyWith(color: AuraSurface.muted),
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
                  backgroundColor: AuraSurface.overlay,
                  foregroundColor: AuraSurface.ink,
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
    final fileName = _pickString(attachment, const ['fileName', 'name']);
    final mimeType = _pickString(attachment, const ['mimeType', 'mime']);
    final sizeBytes = _pickInt(attachment, const ['sizeBytes', 'size']);
    final kind = _kindFromMime(mimeType);
    final url = _resolveAttachmentUrl(attachment);
    final thumbUrl = _resolveAttachmentThumbUrl(attachment);

    const borderColor = AuraSurface.divider;
    const surfaceColor = AuraSurface.subtle;
    const primaryTextColor = AuraSurface.ink;
    const secondaryTextColor = AuraSurface.muted;

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
      child: GestureDetector(onTap: handleTap, child: mediaSurface),
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
      transform: Matrix4.identity()
        ..scaleByDouble(
          hovering ? 1.01 : 1.0,
          hovering ? 1.01 : 1.0,
          hovering ? 1.01 : 1.0,
          1,
        ),
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
                    color: Colors.black.withValues(
                      alpha: hovering ? 0.18 : 0.08,
                    ),
                  ),
                ),
                const Center(child: _CenterOpenIcon()),
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
      transform: Matrix4.identity()
        ..scaleByDouble(
          hovering ? 1.01 : 1.0,
          hovering ? 1.01 : 1.0,
          hovering ? 1.01 : 1.0,
          1,
        ),
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
                    errorBuilder: (_, __, ___) => const _BrokenMediaFallback(
                      icon: Icons.videocam_outlined,
                      text: 'Video preview unavailable',
                      textColor: Colors.white70,
                      dark: true,
                    ),
                  )
                else
                  const _BrokenMediaFallback(
                    icon: Icons.videocam_outlined,
                    text: 'Video ready to open',
                    textColor: Colors.white70,
                    dark: true,
                  ),
                Container(
                  color: Colors.black.withValues(alpha: hovering ? 0.34 : 0.26),
                ),
                const Center(child: _CenterPlayIcon()),
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
      transform: Matrix4.identity()
        ..scaleByDouble(
          hovering ? 1.01 : 1.0,
          hovering ? 1.01 : 1.0,
          hovering ? 1.01 : 1.0,
          1,
        ),
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
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.transparent,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.graphic_eq_outlined, color: secondaryTextColor),
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
      color: dark ? AuraSurface.overlay : AuraSurface.subtle,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: textColor),
          const SizedBox(height: 8),
          Text(text, style: AuraText.small.copyWith(color: textColor)),
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
        color: AuraSurface.overlay,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
      ),
      child: const Icon(Icons.open_in_full, size: 24, color: AuraSurface.ink),
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
        color: AuraSurface.overlay,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: AuraSurface.ink,
        size: 32,
      ),
    );
  }
}

class _OpenBadge extends StatelessWidget {
  const _OpenBadge({required this.label, this.dark = false});

  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AuraSurface.overlay,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.open_in_new, size: 12, color: AuraSurface.ink),
          const SizedBox(width: 4),
          Text(label, style: AuraText.small.copyWith(color: AuraSurface.ink)),
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
        border: Border.all(color: AuraSurface.divider),
        borderRadius: BorderRadius.circular(AuraRadius.md),
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
        AuraSecondaryButton(
          label: 'Try again',
          onPressed: onRetry,
          icon: Icons.refresh_rounded,
        ),
      ],
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
  String storageKey = '';
  bool uploading = false;
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

enum _AttachmentKind { image, video, audio }

enum _AttachmentSource { gallery, camera, upload, recording }

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
  return {'width': image.width, 'height': image.height};
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
    const nestedKeys = ['data', 'user', 'item', 'result', 'payload'];

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
        final message = _firstNonEmpty(item, const [
          'message',
          'title',
          'finding',
        ]);
        final detail = _firstNonEmpty(item, const [
          'suggestion',
          'detail',
          'description',
        ]);
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
  const keys = ['author', 'sender', 'user', 'member', 'profile', 'createdBy'];

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

  return _pickString(author, const ['id', '_id', 'userId', 'memberId']);
}

String _resolveAttachmentUrl(Map<String, dynamic> attachment) {
  return _pickString(attachment, const [
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
  ]);
}

String _resolveAttachmentThumbUrl(Map<String, dynamic> attachment) {
  return _pickString(attachment, const [
    'thumbnailUrl',
    'thumbUrl',
    'previewUrl',
    'posterUrl',
    'displayUrl',
    'publicUrl',
    'signedUrl',
    'url',
  ]);
}

bool _isSameSender(
  Map<String, dynamic> current,
  Map<String, dynamic>? previous,
) {
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

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
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
