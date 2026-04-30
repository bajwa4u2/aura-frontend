import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

// ── Pending message ───────────────────────────────────────────────────────────

class _PendingMessage {
  _PendingMessage({
    required this.localId,
    required this.body,
    required this.senderId,
    required this.senderName,
    required this.senderHandle,
    required this.senderAvatarUrl,
    required this.attachments,
    required this.sentAt,
  });

  final String localId;
  final String body;
  final String senderId;
  final String senderName;
  final String senderHandle;
  final String senderAvatarUrl;
  final List<Map<String, dynamic>> attachments;
  final DateTime sentAt;
  bool failed = false;

  Map<String, dynamic> toMessage() => {
        '_localId': localId,
        '_pending': true,
        '_failed': failed,
        'body': body,
        'text': body,
        'authorId': senderId,
        'author': {
          'id': senderId,
          'displayName': senderName,
          'handle': senderHandle,
          'avatarUrl': senderAvatarUrl,
        },
        'attachments': attachments,
        'createdAt': sentAt.toIso8601String(),
        'sentAt': sentAt.toIso8601String(),
      };
}

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

class ThreadScreen extends ConsumerStatefulWidget {
  const ThreadScreen({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends ConsumerState<ThreadScreen> {
  Timer? _pollTimer;
  final ScrollController _scrollController = ScrollController();
  final List<_PendingMessage> _pendingMessages = [];

  bool _isNearBottom = true;
  bool _showNewMessages = false;
  bool _hasScrolledInitialBottom = false;
  bool _callBusy = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted) return;
      final liveState = ref.read(realtimeControllerProvider);
      if (liveState.isBusy) return;
      _refreshThreadData();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (!_scrollController.position.hasContentDimensions) return;
    final atBottom =
        _scrollController.position.maxScrollExtent -
            _scrollController.position.pixels <=
        120;
    if (atBottom == _isNearBottom) return;
    setState(() {
      _isNearBottom = atBottom;
      if (atBottom) _showNewMessages = false;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (!_scrollController.position.hasContentDimensions) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _addPendingMessage({
    required String body,
    required String senderId,
    required String senderName,
    required String senderHandle,
    required String senderAvatarUrl,
    required List<Map<String, dynamic>> attachments,
  }) {
    final pending = _PendingMessage(
      localId: '${DateTime.now().microsecondsSinceEpoch}',
      body: body,
      senderId: senderId,
      senderName: senderName,
      senderHandle: senderHandle,
      senderAvatarUrl: senderAvatarUrl,
      attachments: attachments,
      sentAt: DateTime.now(),
    );
    setState(() => _pendingMessages.add(pending));
    _scrollToBottom();
  }

  void _clearPendingOnRefresh() {
    setState(() => _pendingMessages.removeWhere((p) => !p.failed));
  }

  void _refreshThreadData() {
    ref.invalidate(threadDetailProvider(widget.threadId));
    ref.invalidate(messagesProvider(widget.threadId));
    _clearPendingOnRefresh();
    if (_isNearBottom) {
      _scrollToBottom();
    }
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
    if (_callBusy) return;
    setState(() => _callBusy = true);
    try {
      final controller = ref.read(realtimeControllerProvider.notifier);
      final sessionId = await controller.ensureCorrespondenceLive(
        surfaceType: _threadLiveSurfaceType(thread),
        surfaceId: _threadLiveSurfaceId(thread, widget.threadId),
        kind: kind,
        metadata: <String, dynamic>{
          'threadId': widget.threadId,
          'spaceId': pickString(thread, const ['spaceId', 'space_id']),
        }..removeWhere(
          (key, value) => value == null || value.toString().trim().isEmpty,
        ),
      );
      if (!mounted) return;
      context.push('/realtime/$sessionId');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calls are temporarily unavailable. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _callBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final threadId = widget.threadId;

    ref.watch(threadOpenProvider(threadId));

    // Track new incoming messages for bottom-anchor affordance.
    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(
      messagesProvider(widget.threadId),
      (prev, next) {
        if (!mounted) return;
        final prevList = prev?.maybeWhen(data: (d) => d, orElse: () => null);
        final nextList = next.maybeWhen(data: (d) => d, orElse: () => null);
        // Initial data load — jump straight to bottom once.
        if (prevList == null && nextList != null && !_hasScrolledInitialBottom) {
          _hasScrolledInitialBottom = true;
          _scrollToBottom();
          return;
        }
        if (prevList != null &&
            nextList != null &&
            nextList.length > prevList.length) {
          if (_isNearBottom) {
            _scrollToBottom();
          } else {
            setState(() => _showNewMessages = true);
          }
        }
      },
    );

    final threadAsync = ref.watch(threadDetailProvider(threadId));
    final messagesAsync = ref.watch(messagesProvider(threadId));
    final meAsync = ref.watch(currentUserProvider);
    final liveState = ref.watch(realtimeControllerProvider);
    final callBusy = _callBusy || liveState.isBusy;
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
            child: Stack(
              children: [
            RefreshIndicator(
              onRefresh: _refreshAll,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: ListView(
                controller: _scrollController,
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
                            callBusy: callBusy,
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
                          _ConversationCallCard(
                            sessionId: _threadResolvedSessionId(thread, liveState, widget.threadId),
                            liveState: liveState,
                            callBusy: callBusy,
                            onJoin: () async {
                              final sid = _threadResolvedSessionId(thread, liveState, widget.threadId);
                              if (sid.isEmpty) return;
                              await ref.read(realtimeControllerProvider.notifier).join(sid);
                              if (!context.mounted) return;
                              context.push('/realtime/$sid');
                            },
                            onLeave: () async => ref.read(realtimeControllerProvider.notifier).leave(),
                            onReturn: () {
                              final sid = _threadResolvedSessionId(thread, liveState, widget.threadId);
                              if (sid.isEmpty) return;
                              context.push('/realtime/$sid');
                            },
                          ),
                          const SizedBox(height: AuraSpace.s16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final wide = constraints.maxWidth >= 760;
                              final showRail = constraints.maxWidth >= 560;
                              final conversationPanel = _ThreadConversationPanel(
                                messagesAsync: messagesAsync,
                                pendingMessages: _pendingMessages
                                    .map((p) => p.toMessage())
                                    .toList(),
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
            ),
            if (_showNewMessages)
              Positioned(
                bottom: AuraSpace.s16,
                left: 0,
                right: 0,
                child: Center(
                  child: _NewMessagesBanner(
                    onTap: () {
                      setState(() => _showNewMessages = false);
                      _scrollToBottom();
                    },
                  ),
                ),
              ),
              ],
            ),
          ),
          ThreadComposerBar(
            threadId: widget.threadId,
            currentUserId: currentUserId,
            onOptimisticSend: _addPendingMessage,
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
    required this.callBusy,
    required this.onOpenSpace,
    required this.onInvite,
    required this.onAddMembers,
    required this.onStartAudio,
    required this.onStartVideo,
  });

  final Map<String, dynamic> thread;
  final CorrespondenceThreadContext contextData;
  final RealtimeState liveState;
  final bool callBusy;
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
        callBusy: callBusy,
        onStartAudio: onStartAudio,
        onStartVideo: onStartVideo,
      );
    }

    if (isGroup) {
      return _GroupThreadHeader(
        contextData: contextData,
        conversationId: conversationId,
        participantCount: participantCount,
        callBusy: callBusy,
        onStartAudio: onStartAudio,
        onStartVideo: onStartVideo,
      );
    }

    return _SpaceThreadHeader(
      contextData: contextData,
      conversationId: conversationId,
      participantCount: participantCount,
      callBusy: callBusy,
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
    required this.callBusy,
    required this.onStartAudio,
    required this.onStartVideo,
  });

  final CorrespondenceThreadContext contextData;
  final String conversationId;
  final int participantCount;
  final bool callBusy;
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
            callBusy: callBusy,
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
    required this.callBusy,
    required this.onStartAudio,
    required this.onStartVideo,
  });

  final CorrespondenceThreadContext contextData;
  final String conversationId;
  final int participantCount;
  final bool callBusy;
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
            callBusy: callBusy,
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
    required this.callBusy,
    required this.onOpenSpace,
    required this.onInvite,
    required this.onAddMembers,
    required this.onStartAudio,
    required this.onStartVideo,
  });

  final CorrespondenceThreadContext contextData;
  final String conversationId;
  final int participantCount;
  final bool callBusy;
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
            callBusy: callBusy,
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
    this.callBusy = false,
    this.onSpaceOpen,
    this.onInvite,
    this.onAddMembers,
  });

  final String conversationId;
  final Future<void> Function() onStartAudio;
  final Future<void> Function() onStartVideo;
  final bool callBusy;
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
          busy: callBusy,
          onPressed: () => onStartAudio(),
        ),
        _HeaderIconAction(
          icon: Icons.videocam_rounded,
          busy: callBusy,
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
  const _HeaderIconAction({
    required this.icon,
    required this.onPressed,
    this.busy = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: busy ? 0.45 : 1.0,
      child: MouseRegion(
        cursor: busy ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: busy ? null : onPressed,
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
      ),
    );
  }
}

class _ThreadConversationPanel extends StatelessWidget {
  const _ThreadConversationPanel({
    required this.messagesAsync,
    required this.pendingMessages,
    required this.currentUserId,
    required this.threadContext,
    required this.onRefresh,
    required this.onEditMessage,
    required this.onDeleteMessage,
  });

  final AsyncValue<List<Map<String, dynamic>>> messagesAsync;
  final List<Map<String, dynamic>> pendingMessages;
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
            data: (serverMessages) {
              final messages = [
                ...serverMessages,
                // Append pending messages that aren't yet in server list.
                ...pendingMessages.where((p) {
                  final localId = p['_localId']?.toString() ?? '';
                  if (localId.isEmpty) return true;
                  return !serverMessages.any(
                    (s) => s['_localId']?.toString() == localId,
                  );
                }),
              ];

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
                final isPending = messages[i]['_pending'] == true;
                final isFailed = messages[i]['_failed'] == true;
                tiles.add(
                  Opacity(
                    opacity: isPending ? 0.65 : 1.0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                        if (isPending && !isFailed)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 4,
                              right: 4,
                            ),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 10,
                                    height: 10,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Sending…',
                                    style: AuraText.micro.copyWith(
                                      color: AuraSurface.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (isFailed)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, right: 4),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Failed to send',
                                style: AuraText.micro.copyWith(
                                  color: AuraSurface.dangerInk,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
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
    required this.threadContext,
    this.onOpenSpace,
    this.onOpenInvites,
  });

  final AsyncValue<Map<String, dynamic>> threadAsync;
  final CorrespondenceThreadContext threadContext;
  final VoidCallback? onOpenSpace;
  final Future<void> Function()? onOpenInvites;

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

        if (threadContext.isDirect) {
          return _DirectConversationRail(
            thread: thread,
            threadContext: threadContext,
          );
        }

        if (threadContext.isGroup) {
          return _GroupConversationRail(
            thread: thread,
            threadContext: threadContext,
            participants: participants,
          );
        }

        return _SpaceThreadRail(
          thread: thread,
          threadContext: threadContext,
          participants: participants,
          onOpenSpace: onOpenSpace,
          onOpenInvites: onOpenInvites,
        );
      },
    );
  }
}

class _DirectConversationRail extends StatelessWidget {
  const _DirectConversationRail({
    required this.thread,
    required this.threadContext,
  });

  final Map<String, dynamic> thread;
  final CorrespondenceThreadContext threadContext;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
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
        ],
      ),
    );
  }
}

class _GroupConversationRail extends StatelessWidget {
  const _GroupConversationRail({
    required this.thread,
    required this.threadContext,
    required this.participants,
  });

  final Map<String, dynamic> thread;
  final CorrespondenceThreadContext threadContext;
  final List<Map<String, dynamic>> participants;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
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
    );
  }
}

class _SpaceThreadRail extends StatelessWidget {
  const _SpaceThreadRail({
    required this.thread,
    required this.threadContext,
    required this.participants,
    this.onOpenSpace,
    this.onOpenInvites,
  });

  final Map<String, dynamic> thread;
  final CorrespondenceThreadContext threadContext;
  final List<Map<String, dynamic>> participants;
  final VoidCallback? onOpenSpace;
  final Future<void> Function()? onOpenInvites;

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

String _threadLiveSurfaceType(Map<String, dynamic> thread) {
  return 'THREAD';
}

String _threadLiveSurfaceId(Map<String, dynamic> thread, String threadId) {
  return threadId;
}

class _StripIconButton extends StatelessWidget {
  const _StripIconButton({
    required this.icon,
    required this.onTap,
    this.tone,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: tone ?? Colors.white),
        ),
      ),
    );
  }
}

class _ConversationCallCard extends StatelessWidget {
  const _ConversationCallCard({
    required this.sessionId,
    required this.liveState,
    required this.callBusy,
    required this.onJoin,
    required this.onLeave,
    required this.onReturn,
  });

  final String sessionId;
  final RealtimeState liveState;
  final bool callBusy;
  final Future<void> Function() onJoin;
  final Future<void> Function() onLeave;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    if (sessionId.isEmpty) return const SizedBox.shrink();

    final isJoined = liveState.isJoined;
    final isBusy = liveState.isBusy || callBusy;
    final isVideo = liveState.isVideoMode;

    final dotColor = isJoined
        ? AuraSurface.goodInk
        : (isBusy ? AuraSurface.accent : AuraSurface.muted);

    final statusText = isBusy
        ? 'Connecting…'
        : isJoined
            ? (isVideo ? 'Video call in progress' : 'Audio call in progress')
            : (isVideo ? 'Video call started' : 'Audio call started');

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
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: AuraSpace.s8),
          Icon(
            isVideo ? Icons.videocam_rounded : Icons.mic_rounded,
            size: 16,
            color: AuraSurface.accentText,
          ),
          const SizedBox(width: AuraSpace.s8),
          Expanded(
            child: Text(
              statusText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AuraText.small.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AuraSpace.s8),
          if (isJoined) ...[
            _StripIconButton(icon: Icons.open_in_new_rounded, onTap: onReturn),
            const SizedBox(width: AuraSpace.s8),
            _StripIconButton(
              icon: Icons.call_end_rounded,
              tone: AuraSurface.dangerInk,
              onTap: () => onLeave(),
            ),
          ] else if (!isBusy)
            _StripIconButton(icon: Icons.call_rounded, onTap: () => onJoin()),
        ],
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

class _NewMessagesBanner extends StatelessWidget {
  const _NewMessagesBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s16,
          vertical: AuraSpace.s8,
        ),
        decoration: BoxDecoration(
          color: AuraSurface.accent,
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.arrow_downward_rounded,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: AuraSpace.s6),
            Text(
              'New messages',
              style: AuraText.small.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
