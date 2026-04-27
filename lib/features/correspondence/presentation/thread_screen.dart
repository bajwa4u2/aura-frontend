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
import '../data/messages_repository.dart';
import '../data/threads_repository.dart';
import '../data/correspondence_identity.dart';
import '../../realtime/application/realtime_providers.dart';
import '../../realtime/domain/realtime_enums.dart';
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
                          ),
                          _ThreadLiveDock(
                            thread: thread,
                            liveState: liveState,
                            onJoinLive: () async {
                              final sessionId = _threadResolvedSessionId(
                                thread,
                                liveState,
                                widget.threadId,
                              );
                              if (sessionId.isEmpty) return;
                              await ref
                                  .read(realtimeControllerProvider.notifier)
                                  .join(sessionId);
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
                              final wide = constraints.maxWidth >= 760;
                              final showRail = constraints.maxWidth >= 560;
                              final conversationPanel = _ThreadConversationPanel(
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
                                    Expanded(child: conversationPanel),
                                    const SizedBox(width: AuraSpace.s16),
                                    SizedBox(width: 300, child: sideRail),
                                  ],
                                );
                              }

                              if (showRail) {
                                return Column(
                                  children: [
                                    conversationPanel,
                                    const SizedBox(height: AuraSpace.s16),
                                    sideRail,
                                  ],
                                );
                              }

                              return conversationPanel;
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
          ThreadComposerBar(
            threadId: widget.threadId,
            onSent: _refreshThreadData,
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
  });

  final Map<String, dynamic> thread;
  final CorrespondenceThreadContext contextData;
  final RealtimeState liveState;
  final VoidCallback onOpenSpace;
  final VoidCallback onInvite;
  final VoidCallback onAddMembers;
  final Future<void> Function() onStartAudio;
  final Future<void> Function() onStartVideo;

  @override
  Widget build(BuildContext context) {
    final isDirect = contextData.isDirect;
    final isGroup = contextData.isGroup;
    final participantCount = _extractParticipants(thread).length;
    final conversationId = pickString(thread, const ['id', 'threadId']);

    if (isDirect) {
      return _DirectThreadHeader(
        contextData: contextData,
        conversationId: conversationId,
        participantCount: participantCount,
        onStartAudio: onStartAudio,
        onStartVideo: onStartVideo,
      );
    }

    if (isGroup) {
      return _GroupThreadHeader(
        contextData: contextData,
        conversationId: conversationId,
        participantCount: participantCount,
        onStartAudio: onStartAudio,
        onStartVideo: onStartVideo,
      );
    }

    return _SpaceThreadHeader(
      contextData: contextData,
      conversationId: conversationId,
      participantCount: participantCount,
      onOpenSpace: onOpenSpace,
      onInvite: onInvite,
      onAddMembers: onAddMembers,
      onStartAudio: onStartAudio,
      onStartVideo: onStartVideo,
    );
  }
}

class _DirectThreadHeader extends StatelessWidget {
  const _DirectThreadHeader({
    required this.contextData,
    required this.conversationId,
    required this.participantCount,
    required this.onStartAudio,
    required this.onStartVideo,
  });

  final CorrespondenceThreadContext contextData;
  final String conversationId;
  final int participantCount;
  final Future<void> Function() onStartAudio;
  final Future<void> Function() onStartVideo;

  @override
  Widget build(BuildContext context) {
    final title = contextData.title;
    final subtitle = [
      if (contextData.participantSummary.isNotEmpty) contextData.participantSummary,
      if (contextData.activityWeight.isNotEmpty) contextData.activityWeight,
    ].join(' · ');

    return AuraCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuraAvatar(name: title, imageUrl: contextData.avatarUrl, size: 48),
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
                    const AuraStatusChip(
                      label: 'Private conversation',
                      backgroundColor: AuraSurface.subtle,
                      textColor: AuraSurface.muted,
                    ),
                    if (participantCount > 0)
                      AuraStatusChip(
                        label: participantCount == 1
                            ? '1 participant'
                            : '$participantCount participants',
                        backgroundColor: AuraSurface.subtle,
                        textColor: AuraSurface.muted,
                      ),
                  ],
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: AuraSpace.s4),
                  Text(
                    subtitle,
                    style: AuraText.body.copyWith(color: AuraSurface.muted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (contextData.roleSummary.isNotEmpty) ...[
                  const SizedBox(height: AuraSpace.s6),
                  Text(
                    contextData.roleSummary,
                    style: AuraText.small.copyWith(color: AuraSurface.muted),
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
          ),
        ],
      ),
    );
  }
}

class _GroupThreadHeader extends StatelessWidget {
  const _GroupThreadHeader({
    required this.contextData,
    required this.conversationId,
    required this.participantCount,
    required this.onStartAudio,
    required this.onStartVideo,
  });

  final CorrespondenceThreadContext contextData;
  final String conversationId;
  final int participantCount;
  final Future<void> Function() onStartAudio;
  final Future<void> Function() onStartVideo;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuraAvatar(name: contextData.title, imageUrl: contextData.avatarUrl, size: 48),
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
                    const AuraStatusChip(
                      label: 'Group conversation',
                      backgroundColor: AuraSurface.subtle,
                      textColor: AuraSurface.muted,
                    ),
                    if (participantCount > 0)
                      AuraStatusChip(
                        label: participantCount == 1
                            ? '1 participant'
                            : '$participantCount participants',
                        backgroundColor: AuraSurface.subtle,
                        textColor: AuraSurface.muted,
                      ),
                  ],
                ),
                if (contextData.participantSummary.isNotEmpty) ...[
                  const SizedBox(height: AuraSpace.s4),
                  Text(
                    contextData.participantSummary,
                    style: AuraText.body.copyWith(color: AuraSurface.muted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (contextData.activityWeight.isNotEmpty) ...[
                  const SizedBox(height: AuraSpace.s6),
                  Text(
                    contextData.activityWeight,
                    style: AuraText.small.copyWith(color: AuraSurface.muted),
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
          ),
        ],
      ),
    );
  }
}

class _SpaceThreadHeader extends StatelessWidget {
  const _SpaceThreadHeader({
    required this.contextData,
    required this.conversationId,
    required this.participantCount,
    required this.onOpenSpace,
    required this.onInvite,
    required this.onAddMembers,
    required this.onStartAudio,
    required this.onStartVideo,
  });

  final CorrespondenceThreadContext contextData;
  final String conversationId;
  final int participantCount;
  final VoidCallback onOpenSpace;
  final VoidCallback onInvite;
  final VoidCallback onAddMembers;
  final Future<void> Function() onStartAudio;
  final Future<void> Function() onStartVideo;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuraAvatar(name: contextData.spaceTitle.isNotEmpty ? contextData.spaceTitle : contextData.title, imageUrl: contextData.avatarUrl, size: 48),
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
                    Text(
                      contextData.spaceTitle.isNotEmpty
                          ? contextData.spaceTitle
                          : contextData.title,
                      style: AuraText.title,
                    ),
                    const AuraStatusChip(
                      label: 'Shared space',
                      backgroundColor: AuraSurface.goodBg,
                      textColor: AuraSurface.goodInk,
                    ),
                    if (participantCount > 0)
                      AuraStatusChip(
                        label: participantCount == 1
                            ? '1 participant'
                            : '$participantCount participants',
                        backgroundColor: AuraSurface.subtle,
                        textColor: AuraSurface.muted,
                      ),
                  ],
                ),
                if (contextData.explicitTitle.isNotEmpty &&
                    contextData.explicitTitle.toLowerCase() !=
                        contextData.spaceTitle.toLowerCase()) ...[
                  const SizedBox(height: AuraSpace.s4),
                  Text(
                    contextData.explicitTitle,
                    style: AuraText.body.copyWith(color: AuraSurface.muted),
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
              ],
            ),
          ),
          const SizedBox(width: AuraSpace.s12),
          _ThreadActionCluster(
            conversationId: conversationId,
            onStartAudio: onStartAudio,
            onStartVideo: onStartVideo,
            onSpaceOpen: onOpenSpace,
            onInvite: onInvite,
            onAddMembers: onAddMembers,
          ),
        ],
      ),
    );
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
    required this.messagesAsync,
    required this.currentUserId,
    required this.threadContext,
    required this.onRefresh,
    required this.onEditMessage,
    required this.onDeleteMessage,
  });

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

              final tiles = <Widget>[];
              for (var i = 0; i < messages.length; i++) {
                final showDate = i == 0 ||
                    !_isSameDay(messages[i], messages[i - 1]);
                if (showDate) {
                  if (tiles.isNotEmpty) {
                    tiles.add(const SizedBox(height: AuraSpace.s12));
                  }
                  tiles.add(_DateSeparator(message: messages[i]));
                  tiles.add(const SizedBox(height: AuraSpace.s10));
                }
                tiles.add(
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
                );
                if (i != messages.length - 1) {
                  tiles.add(const SizedBox(height: AuraSpace.s8));
                }
              }
              return Column(children: tiles);
            },
          ),
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
          connectionStatus: liveState.connectionStatus,
          joinState: liveState.joinState,
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
    required this.connectionStatus,
    required this.joinState,
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
  final RealtimeConnectionStatus connectionStatus;
  final RealtimeJoinState joinState;
  final Future<void> Function() onJoin;
  final Future<void> Function() onLeave;
  final Future<void> Function() onToggleMicrophone;
  final Future<void> Function()? onToggleCamera;

  String get _stateLabel {
    switch (joinState) {
      case RealtimeJoinState.joining:
        return 'Connecting...';
      case RealtimeJoinState.requested:
        return 'Waiting for approval...';
      case RealtimeJoinState.rejected:
        return 'Call declined';
      case RealtimeJoinState.removed:
        return 'You were removed';
      case RealtimeJoinState.banned:
        return 'Banned from session';
      case RealtimeJoinState.locked:
        return 'Room is locked';
      case RealtimeJoinState.failed:
        return 'Call failed';
      default:
        break;
    }
    if (connectionStatus == RealtimeConnectionStatus.reconnecting) {
      return 'Reconnecting...';
    }
    if (connectionStatus == RealtimeConnectionStatus.error) {
      return 'Connection error';
    }
    return '';
  }

  Color get _dotColor {
    if (isJoined) return AuraSurface.goodInk;
    if (joinState == RealtimeJoinState.joining ||
        connectionStatus == RealtimeConnectionStatus.connecting ||
        connectionStatus == RealtimeConnectionStatus.reconnecting) {
      return AuraSurface.accent;
    }
    if (joinState == RealtimeJoinState.rejected ||
        joinState == RealtimeJoinState.removed ||
        joinState == RealtimeJoinState.failed ||
        connectionStatus == RealtimeConnectionStatus.error) {
      return AuraSurface.dangerInk;
    }
    return AuraSurface.muted;
  }

  @override
  Widget build(BuildContext context) {
    final stateLabel = _stateLabel;
    final showStateLabel = stateLabel.isNotEmpty;
    final showJoinBtn = !isJoined &&
        joinState != RealtimeJoinState.joining &&
        joinState != RealtimeJoinState.requested &&
        joinState != RealtimeJoinState.rejected &&
        joinState != RealtimeJoinState.removed &&
        joinState != RealtimeJoinState.failed &&
        joinState != RealtimeJoinState.banned;

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
              color: _dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  showStateLabel ? stateLabel : liveLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AuraText.small.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!showStateLabel && liveDetail.trim().isNotEmpty)
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
          if (showJoinBtn)
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
    final firstRemoteEntry =
        remoteRenderers.isEmpty ? null : remoteRenderers.entries.first;
    final firstRemoteParticipant = firstRemoteEntry == null
        ? null
        : participants.cast<RealtimeParticipant?>().firstWhere(
            (p) =>
                p?.runtimeDeviceId == firstRemoteEntry.key ||
                p?.userId == firstRemoteEntry.key,
            orElse: () => null,
          );
    final remoteLabel =
        firstRemoteParticipant?.isHost == true ? 'Host' : 'Member';
    final extraRemotes = remoteRenderers.length > 1
        ? Map.fromEntries(remoteRenderers.entries.skip(1))
        : <String, RTCVideoRenderer>{};

    return LayoutBuilder(
      builder: (context, constraints) {
        final stageH = constraints.maxWidth < 600
            ? 260.0
            : constraints.maxWidth < 960
            ? 320.0
            : 380.0;
        return SizedBox(
          height: stageH,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AuraRadius.card),
            child: Stack(
              children: [
                // Primary remote — full stage
                Positioned.fill(
                  child: Container(
                    color: const Color(0xFF0D1117),
                    child: firstRemoteEntry != null
                        ? RTCVideoView(
                            firstRemoteEntry.value,
                            objectFit: RTCVideoViewObjectFit
                                .RTCVideoViewObjectFitContain,
                          )
                        : const _CallStatePlaceholder(),
                  ),
                ),
                // Remote label
                if (firstRemoteEntry != null)
                  Positioned(
                    left: 10,
                    top: 10,
                    child: _VideoLabel(label: remoteLabel),
                  ),
                // Extra remote thumbnails
                if (extraRemotes.isNotEmpty)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _ExtraParticipantsPip(renderers: extraRemotes),
                  ),
                // Local PiP — bottom right, above controls
                if (localRenderer != null)
                  Positioned(
                    right: 10,
                    bottom: 58,
                    child: _LocalPip(renderer: localRenderer!),
                  ),
                // Floating controls — bottom centre
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: Center(
                    child: _FloatingCallControls(
                      microphoneEnabled: microphoneEnabled,
                      cameraEnabled: cameraEnabled,
                      onToggleMicrophone: onToggleMicrophone,
                      onToggleCamera: onToggleCamera,
                      onLeave: onLeave,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CallStatePlaceholder extends StatelessWidget {
  const _CallStatePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.person_outline_rounded, size: 48, color: Color(0x99FFFFFF)),
        SizedBox(height: 8),
        Text(
          'Waiting for video...',
          style: TextStyle(color: Color(0x99FFFFFF), fontSize: 12),
        ),
      ],
    );
  }
}

class _VideoLabel extends StatelessWidget {
  const _VideoLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LocalPip extends StatelessWidget {
  const _LocalPip({required this.renderer});

  final RTCVideoRenderer renderer;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 96,
        height: 72,
          child: RTCVideoView(
          renderer,
          mirror: true,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
        ),
      ),
    );
  }
}

class _ExtraParticipantsPip extends StatelessWidget {
  const _ExtraParticipantsPip({required this.renderers});

  final Map<String, RTCVideoRenderer> renderers;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: renderers.values
          .take(3)
          .map(
            (r) => Padding(
              padding: const EdgeInsets.only(left: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 72,
                  height: 54,
                    child: RTCVideoView(
                    r,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _FloatingCallControls extends StatelessWidget {
  const _FloatingCallControls({
    required this.microphoneEnabled,
    required this.cameraEnabled,
    required this.onToggleMicrophone,
    required this.onToggleCamera,
    required this.onLeave,
  });

  final bool microphoneEnabled;
  final bool cameraEnabled;
  final Future<void> Function() onToggleMicrophone;
  final Future<void> Function() onToggleCamera;
  final Future<void> Function() onLeave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AuraRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ControlButton(
            icon: microphoneEnabled
                ? Icons.mic_off_rounded
                : Icons.mic_rounded,
            active: microphoneEnabled,
            onTap: onToggleMicrophone,
          ),
          const SizedBox(width: 8),
          _ControlButton(
            icon: cameraEnabled
                ? Icons.videocam_off_rounded
                : Icons.videocam_rounded,
            active: cameraEnabled,
            onTap: onToggleCamera,
          ),
          const SizedBox(width: 8),
          _ControlButton(
            icon: Icons.call_end_rounded,
            danger: true,
            onTap: onLeave,
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.onTap,
    this.active = true,
    this.danger = false,
  });

  final IconData icon;
  final Future<void> Function() onTap;
  final bool active;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? AuraSurface.dangerInk
        : active
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.white.withValues(alpha: 0.08);
    final iconColor = danger
        ? Colors.white
        : (active ? Colors.white : Colors.white70);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onTap(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: iconColor),
        ),
      ),
    );
  }
}

bool _isSameDay(Map<String, dynamic> a, Map<String, dynamic> b) {
  final aRaw = pickString(a, const ['createdAt', 'sentAt', 'timestamp']);
  final bRaw = pickString(b, const ['createdAt', 'sentAt', 'timestamp']);
  final aDate = DateTime.tryParse(aRaw)?.toLocal();
  final bDate = DateTime.tryParse(bRaw)?.toLocal();
  if (aDate == null || bDate == null) return true;
  return aDate.year == bDate.year &&
      aDate.month == bDate.month &&
      aDate.day == bDate.day;
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.message});
  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final raw = pickString(message, const ['createdAt', 'sentAt', 'timestamp']);
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);

    String label;
    if (d == today) {
      label = 'Today';
    } else if (d == today.subtract(const Duration(days: 1))) {
      label = 'Yesterday';
    } else {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      label = '${months[date.month - 1]} ${date.day}';
      if (date.year != now.year) label += ', ${date.year}';
    }

    return Row(
      children: [
        const Expanded(
          child: Divider(color: AuraSurface.divider, height: 1, thickness: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s12),
          child: Text(
            label,
            style: AuraText.micro.copyWith(
              color: AuraSurface.faint,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Expanded(
          child: Divider(color: AuraSurface.divider, height: 1, thickness: 1),
        ),
      ],
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
