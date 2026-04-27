import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

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
import 'thread/thread_composer.dart';
import 'thread/thread_message_tile.dart';
import 'thread/thread_utils.dart';

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



String _threadResolvedSessionId(
  Map<String, dynamic> thread,
  RealtimeState liveState,
  String fallbackThreadId,
) {
  final direct = pickString(thread, const [
    'liveSessionId',
    'activeSessionId',
    'sessionId',
    'realtimeSessionId',
    'currentSessionId',
  ]);
  if (direct.isNotEmpty) return direct;

  final nested = pickNested(thread, const [
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
  final direct = pickString(thread, const [
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
  final direct = pickString(thread, const [
    'startedByUserId',
    'liveStartedByUserId',
    'callerUserId',
    'ownerUserId',
  ]);
  if (direct.isNotEmpty) return direct;
  final nested = pickNested(thread, const [
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
            'spaceId': pickString(thread, const ['spaceId', 'space_id']),
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
      data: (me) => pickString(me, const ['id', '_id', 'userId']),
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
                          _ThreadModeHeaderCard(
                            thread: thread,
                            contextData: contextData,
                            liveState: liveState,
                            onOpenSpace: () {
                              final spaceId = pickString(thread, const [
                                'spaceId',
                                'space_id',
                              ]);
                              if (spaceId.isEmpty) return;
                              context.push('/me/correspondence/$spaceId');
                            },
                            onInvite: () async {
                              final spaceId = pickString(thread, const [
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
                              final spaceId = pickString(thread, const [
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
                                threadContext: contextData,
                                onRefresh: _refreshThreadData,
                                onEditMessage: (message) =>
                                    _showEditMessageDialog(
                                  context,
                                  ref,
                                  message,
                                ),
                                onDeleteMessage: (message) async {
                                  final messageId = pickString(
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
                                threadContext: contextData,
                                onOpenSpace: () {
                                  final spaceId = pickString(
                                    thread,
                                    const ['spaceId', 'space_id'],
                                  );
                                  if (spaceId.isEmpty) return;
                                  context.push('/me/correspondence/$spaceId');
                                },
                                onOpenInvites: () async {
                                  final spaceId = pickString(
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
      builder: (_) => ThreadEditMessageDialog(message: message),
    );

    if (edited == true) {
      ref.invalidate(threadDetailProvider(widget.threadId));
      ref.invalidate(messagesProvider(widget.threadId));
    }
  }
}

class _ThreadModeHeaderCard extends StatelessWidget {
  const _ThreadModeHeaderCard({
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
    final isDirect = contextData.isDirect;
    final isGroup = contextData.isGroup;
    final isSpace = contextData.isSpace;
    final title = _modeTitle();
    final subtitle = _modeSubtitle();
    final participantCount = _extractParticipants(thread).length;
    final conversationId = pickString(thread, const ['id', 'threadId']);

    return AuraCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AuraAvatar(
                name: title,
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
                        Text(title, style: AuraText.title),
                        AuraStatusChip(label: contextData.kindLabel),
                        if (isDirect)
                          const AuraStatusChip(
                            label: 'Private',
                            backgroundColor: AuraSurface.subtle,
                            textColor: AuraSurface.muted,
                          )
                        else if (isGroup)
                          const AuraStatusChip(
                            label: 'Group',
                            backgroundColor: AuraSurface.subtle,
                            textColor: AuraSurface.muted,
                          )
                        else if (isSpace)
                          const AuraStatusChip(
                            label: 'Shared space',
                            backgroundColor: AuraSurface.goodBg,
                            textColor: AuraSurface.goodInk,
                          ),
                      ],
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s4),
                      AuraTextBlock(
                        subtitle,
                        style: AuraText.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (contextData.participantChips.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s10),
                      Wrap(
                        spacing: AuraSpace.s8,
                        runSpacing: AuraSpace.s8,
                        children: contextData.participantChips
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
                    if (participantCount > 0) ...[
                      const SizedBox(height: AuraSpace.s4),
                      Text(
                        isDirect
                            ? (participantCount == 1
                                  ? '1 participant in view'
                                  : '$participantCount participants in view')
                            : '$participantCount participant${participantCount == 1 ? '' : 's'}',
                        style: AuraText.small.copyWith(
                          color: AuraSurface.muted,
                        ),
                      ),
                    ],
                    if (contextData.roleSummary.isNotEmpty ||
                        contextData.activityWeight.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s4),
                      Text(
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
              _ThreadActionCluster(
                conversationId: conversationId,
                onStartAudio: onStartAudio,
                onStartVideo: onStartVideo,
                onSpaceOpen: isSpace ? onOpenSpace : null,
                onInvite: isSpace ? onInvite : null,
                onAddMembers: isSpace ? onAddMembers : null,
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

  String _modeTitle() {
    if (contextData.isDirect || contextData.isGroup) {
      return contextData.title;
    }
    if (contextData.spaceTitle.isNotEmpty) {
      return contextData.spaceTitle;
    }
    return contextData.title;
  }

  String _modeSubtitle() {
    if (contextData.isDirect) {
      return contextData.activityWeight.isNotEmpty
          ? contextData.activityWeight
          : contextData.subtitle;
    }
    if (contextData.isGroup) {
      return contextData.participantSummary.isNotEmpty
          ? contextData.participantSummary
          : contextData.subtitle;
    }
    if (contextData.isSpace) {
      final base = contextData.spaceTitle.isNotEmpty
          ? 'Shared space'
          : contextData.subtitle;
      if (contextData.explicitTitle.isNotEmpty &&
          contextData.explicitTitle != contextData.spaceTitle) {
        return '$base · ${contextData.explicitTitle}';
      }
      return base;
    }
    return contextData.subtitle;
  }
}

class _ThreadActionCluster extends StatelessWidget {
  const _ThreadActionCluster({
    required this.conversationId,
    required this.onStartAudio,
    required this.onStartVideo,
    this.onSpaceOpen,
    this.onInvite,
    this.onAddMembers,
  });

  final String conversationId;
  final Future<void> Function() onStartAudio;
  final Future<void> Function() onStartVideo;
  final VoidCallback? onSpaceOpen;
  final VoidCallback? onInvite;
  final VoidCallback? onAddMembers;

  @override
  Widget build(BuildContext context) {
    return Wrap(
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
        PopupMenuButton<String>(
          tooltip: 'More actions',
          icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
          color: AuraSurface.card,
          itemBuilder: (_) {
            final items = <PopupMenuEntry<String>>[
              const PopupMenuItem(
                value: 'copy-id',
                child: Text('Copy conversation ID'),
              ),
            ];
            if (onSpaceOpen != null) {
              items.addAll([
                const PopupMenuItem(
                  value: 'open-space',
                  child: Text('Open space'),
                ),
                if (onAddMembers != null)
                  const PopupMenuItem(
                    value: 'add-members',
                    child: Text('Add members'),
                  ),
                const PopupMenuItem(
                  value: 'manage-invites',
                  child: Text('Manage invites'),
                ),
              ]);
            }
            return items;
          },
          onSelected: (value) async {
            if (value == 'copy-id') {
              final text = conversationId.trim().isNotEmpty
                  ? conversationId.trim()
                  : GoRouterState.of(context).uri.path;
              await Clipboard.setData(
                ClipboardData(text: text),
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Conversation ID copied.')),
              );
              return;
            }
            if (value == 'open-space' && onSpaceOpen != null) {
              onSpaceOpen!();
              return;
            }
            if (value == 'add-members' && onAddMembers != null) {
              onAddMembers!();
              return;
            }
            if (value == 'manage-invites' && onInvite != null) {
              onInvite!();
              return;
            }
          },
        ),
      ],
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
    required this.threadContext,
    required this.onRefresh,
    required this.onEditMessage,
    required this.onDeleteMessage,
  });

  final String threadId;
  final AsyncValue<List<Map<String, dynamic>>> messagesAsync;
  final String currentUserId;
  final CorrespondenceThreadContext threadContext;
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
          Row(
            children: [
              Expanded(
                child: Text(_sectionTitle(), style: AuraText.title),
              ),
              AuraStatusChip(
                label: threadContext.kindLabel,
                backgroundColor: AuraSurface.subtle,
                textColor: AuraSurface.muted,
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s12),
          messagesAsync.when(
            loading: () => const AuraCard(
              child: _LoadingBlock(label: 'Loading conversation...'),
            ),
            error: (error, _) => AuraCard(
              child: _ErrorBlock(
                title: 'Could not load conversation',
                body: '$error',
                onRetry: onRefresh,
              ),
            ),
            data: (messages) {
              if (messages.isEmpty) {
                return AuraEmptyState(
                  title: _emptyTitle(),
                  body: _emptyBody(),
                  icon: Icons.forum_outlined,
                );
              }

              return Column(
                children: [
                  for (var i = 0; i < messages.length; i++) ...[
                    ThreadMessageTile(
                      message: messages[i],
                      currentUserId: currentUserId,
                      showAuthorHeader: !isSameSender(
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
          ThreadComposerBar(threadId: threadId, onSent: onRefresh),
        ],
      ),
    );
  }

  String _sectionTitle() {
    if (threadContext.isDirect) return 'Conversation';
    if (threadContext.isGroup) return 'Group messages';
    if (threadContext.isSpace) return 'Thread';
    return 'Messages';
  }

  String _emptyTitle() {
    if (threadContext.isDirect) return 'No messages yet';
    if (threadContext.isGroup) return 'No group messages yet';
    if (threadContext.isSpace) return 'No thread messages yet';
    return 'No messages yet';
  }

  String _emptyBody() {
    if (threadContext.isDirect) {
      return 'This private conversation has not started yet. Your first message will appear here.';
    }
    if (threadContext.isGroup) {
      return 'This group conversation is still quiet. Start the thread and it will appear here.';
    }
    if (threadContext.isSpace) {
      return 'This space thread has not started yet. Your first note will appear here.';
    }
    return 'This conversation has not started yet. Your first note will appear here.';
  }
}

class _ThreadSideRail extends StatelessWidget {
  const _ThreadSideRail({
    required this.threadAsync,
    required this.liveState,
    required this.threadContext,
    this.onOpenSpace,
    this.onOpenInvites,
    this.onStartAudio,
    this.onStartVideo,
  });

  final AsyncValue<Map<String, dynamic>> threadAsync;
  final RealtimeState liveState;
  final CorrespondenceThreadContext threadContext;
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
        final participants = CorrespondenceIdentity.extractParticipants(thread);
        final joinedCount = liveState.participants.where((p) => p.isPresent).length;

        if (threadContext.isDirect) {
          return _DirectConversationRail(
            thread: thread,
            threadContext: threadContext,
            joinedCount: joinedCount,
            onStartAudio: onStartAudio,
            onStartVideo: onStartVideo,
          );
        }

        if (threadContext.isGroup) {
          return _GroupConversationRail(
            thread: thread,
            threadContext: threadContext,
            participants: participants,
            joinedCount: joinedCount,
            onStartAudio: onStartAudio,
            onStartVideo: onStartVideo,
          );
        }

        return _SpaceThreadRail(
          thread: thread,
          threadContext: threadContext,
          participants: participants,
          joinedCount: joinedCount,
          onOpenSpace: onOpenSpace,
          onOpenInvites: onOpenInvites,
          onStartAudio: onStartAudio,
          onStartVideo: onStartVideo,
        );
      },
    );
  }
}

class _DirectConversationRail extends StatelessWidget {
  const _DirectConversationRail({
    required this.thread,
    required this.threadContext,
    required this.joinedCount,
    this.onStartAudio,
    this.onStartVideo,
  });

  final Map<String, dynamic> thread;
  final CorrespondenceThreadContext threadContext;
  final int joinedCount;
  final Future<void> Function()? onStartAudio;
  final Future<void> Function()? onStartVideo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuraCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Profile brief', style: AuraText.title),
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
                Text(threadContext.subtitle, style: AuraText.muted),
              ],
              if (threadContext.activityWeight.isNotEmpty) ...[
                const SizedBox(height: AuraSpace.s6),
                Text(threadContext.activityWeight, style: AuraText.small),
              ],
              const SizedBox(height: AuraSpace.s12),
              Text(
                joinedCount > 0
                    ? 'Live presence detected now.'
                    : 'No active live presence yet.',
                style: AuraText.small.copyWith(color: AuraSurface.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: AuraSpace.s12),
        _ThreadLiveCard(
          label: 'Live status',
          joinedCount: joinedCount,
          onStartAudio: onStartAudio,
          onStartVideo: onStartVideo,
        ),
      ],
    );
  }
}

class _GroupConversationRail extends StatelessWidget {
  const _GroupConversationRail({
    required this.thread,
    required this.threadContext,
    required this.participants,
    required this.joinedCount,
    this.onStartAudio,
    this.onStartVideo,
  });

  final Map<String, dynamic> thread;
  final CorrespondenceThreadContext threadContext;
  final List<Map<String, dynamic>> participants;
  final int joinedCount;
  final Future<void> Function()? onStartAudio;
  final Future<void> Function()? onStartVideo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuraCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Participants', style: AuraText.title),
              const SizedBox(height: AuraSpace.s12),
              Text(
                threadContext.participantSummary.isNotEmpty
                    ? threadContext.participantSummary
                    : '${participants.length} participants',
                style: AuraText.body,
              ),
              if (threadContext.roleSummary.isNotEmpty) ...[
                const SizedBox(height: AuraSpace.s6),
                Text(threadContext.roleSummary, style: AuraText.small),
              ],
              if (threadContext.activityWeight.isNotEmpty) ...[
                const SizedBox(height: AuraSpace.s6),
                Text(threadContext.activityWeight, style: AuraText.small),
              ],
              const SizedBox(height: AuraSpace.s12),
              Wrap(
                spacing: AuraSpace.s8,
                runSpacing: AuraSpace.s8,
                children: participants
                    .take(4)
                    .map(
                      (participant) => AuraStatusChip(
                        label: CorrespondenceIdentity.identityLine(
                          participant,
                          preferHandle: false,
                        ),
                        backgroundColor: AuraSurface.subtle,
                        textColor: AuraSurface.ink,
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AuraSpace.s12),
        _ThreadLiveCard(
          label: 'Live status',
          joinedCount: joinedCount,
          onStartAudio: onStartAudio,
          onStartVideo: onStartVideo,
        ),
      ],
    );
  }
}

class _SpaceThreadRail extends StatelessWidget {
  const _SpaceThreadRail({
    required this.thread,
    required this.threadContext,
    required this.participants,
    required this.joinedCount,
    this.onOpenSpace,
    this.onOpenInvites,
    this.onStartAudio,
    this.onStartVideo,
  });

  final Map<String, dynamic> thread;
  final CorrespondenceThreadContext threadContext;
  final List<Map<String, dynamic>> participants;
  final int joinedCount;
  final VoidCallback? onOpenSpace;
  final Future<void> Function()? onOpenInvites;
  final Future<void> Function()? onStartAudio;
  final Future<void> Function()? onStartVideo;

  @override
  Widget build(BuildContext context) {
    final spaceId = pickString(thread, const ['spaceId', 'space_id']);
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
                Text(threadContext.subtitle, style: AuraText.muted),
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
        _ThreadLiveCard(
          label: 'Live status',
          joinedCount: joinedCount,
          onStartAudio: onStartAudio,
          onStartVideo: onStartVideo,
        ),
        if (spaceId.isNotEmpty) ...[
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
  }
}

class _ThreadLiveCard extends StatelessWidget {
  const _ThreadLiveCard({
    required this.label,
    required this.joinedCount,
    this.onStartAudio,
    this.onStartVideo,
  });

  final String label;
  final int joinedCount;
  final Future<void> Function()? onStartAudio;
  final Future<void> Function()? onStartVideo;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AuraText.title),
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
    pickString(thread, const ['id', 'threadId']),
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
      pickString(thread, const ['id', 'threadId']),
    );
    final hasLive =
        sessionId.isNotEmpty &&
        (belongsHere ||
            pickString(thread, const [
              'liveSessionId',
              'activeSessionId',
            ]).isNotEmpty ||
            pickNested(thread, const [
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
          final id = pickString(participant, const [
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

