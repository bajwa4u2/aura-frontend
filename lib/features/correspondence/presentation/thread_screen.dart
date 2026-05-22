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
    required this.clientMessageId,
  });

  /// Stable handle used by the UI list. Identical to clientMessageId so the
  /// retry path can locate the same row by either field.
  final String localId;
  final String body;
  final String senderId;
  final String senderName;
  final String senderHandle;
  final String senderAvatarUrl;
  final List<Map<String, dynamic>> attachments;
  final DateTime sentAt;

  /// Idempotency key shared with the server; survives retries.
  final String clientMessageId;

  bool failed = false;
  bool retrying = false;

  Map<String, dynamic> toMessage() => {
        '_localId': localId,
        '_clientMessageId': clientMessageId,
        '_pending': true,
        '_failed': failed,
        '_retrying': retrying,
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
  if (session != null && session.isActive) {
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
    required String clientMessageId,
    required String body,
    required String senderId,
    required String senderName,
    required String senderHandle,
    required String senderAvatarUrl,
    required List<Map<String, dynamic>> attachments,
  }) {
    final pending = _PendingMessage(
      localId: clientMessageId,
      clientMessageId: clientMessageId,
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

  void _markPendingFailed({
    required String clientMessageId,
  }) {
    if (!mounted) return;
    setState(() {
      for (final p in _pendingMessages) {
        if (p.clientMessageId == clientMessageId) {
          p.failed = true;
          p.retrying = false;
        }
      }
    });
  }

  Future<void> _retryPendingMessage(_PendingMessage pending) async {
    if (pending.retrying) return;
    setState(() {
      pending.retrying = true;
      pending.failed = false;
    });
    try {
      await ref.read(messagesRepositoryProvider).sendMessage(
            threadId: widget.threadId,
            body: pending.body,
            attachments: pending.attachments
                .where((a) => (a['storageKey']?.toString() ?? '').isNotEmpty)
                .map((a) => Map<String, dynamic>.from(a))
                .toList(),
            // B4: same idempotency key — backend dedupes if the prior attempt
            // actually persisted a row.
            clientMessageId: pending.clientMessageId,
          );
      if (!mounted) return;
      _refreshThreadData();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        pending.retrying = false;
        pending.failed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Retry failed: $e')),
      );
    }
  }

  void _dismissPendingMessage(_PendingMessage pending) {
    setState(() {
      _pendingMessages.removeWhere(
        (p) => p.clientMessageId == pending.clientMessageId,
      );
    });
  }

  /// B5: read the clientMessageId from a server-side message map. The backend
  /// stores the key in metadataJson.clientMessageId (see messages.service.ts).
  /// Falling back to message id is safe — pending messages never share an
  /// id with the server payload, so the fallback never falsely reconciles.
  static String _readClientMessageId(Map<String, dynamic> message) {
    final meta = message['metadataJson'];
    if (meta is Map) {
      final v = meta['clientMessageId'];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    final direct = message['clientMessageId'];
    if (direct is String && direct.trim().isNotEmpty) return direct.trim();
    return '';
  }

  void _clearPendingOnRefresh() {
    // B6: refresh must NOT drop in-flight pending messages. The optimistic
    // reconciliation listener removes pending rows once a server message
    // with the matching clientMessageId arrives — that's the only correct
    // condition for evicting a pending row. A bare refresh might fire while
    // a send is still in-flight; dropping it here would erase a legitimate
    // optimistic message that's still waiting on the network.
    //
    // No-op kept so callers don't need to be updated; the actual reconcile
    // happens in the messagesProvider listener.
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
      final surfaceType = _threadLiveSurfaceType(thread);
      final surfaceId = _threadLiveSurfaceId(thread, widget.threadId);
      final sessionId = await controller.ensureCorrespondenceLive(
        surfaceType: surfaceType,
        surfaceId: surfaceId,
        kind: kind,
        metadata: <String, dynamic>{
          'threadId': widget.threadId,
          'spaceId': pickString(thread, const ['spaceId', 'space_id']),
        }..removeWhere(
          (key, value) => value == null || value.toString().trim().isEmpty,
        ),
        joinAfterCreate: false,
      );
      if (!mounted) return;
      context.go('/realtime/$sessionId?action=join&returnTo=${Uri.encodeComponent(GoRouterState.of(context).uri.toString())}');
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

  Future<void> _renameThread(String currentTitle) async {
    final ctrl = TextEditingController(text: currentTitle);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AuraSurface.card,
        title: const Text('Rename conversation'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Conversation name',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (newTitle == null || newTitle.isEmpty || !mounted) return;
    try {
      await ref
          .read(threadsRepositoryProvider)
          .updateThread(widget.threadId, title: newTitle);
      ref.invalidate(threadDetailProvider(widget.threadId));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not rename. Please try again.')),
      );
    }
  }

  Future<void> _archiveThread() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AuraSurface.card,
        title: const Text('Archive conversation'),
        content: const Text(
          'This conversation will be archived and hidden from your messages. '
          'Members can still access it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: AuraSurface.dangerInk,
            ),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(threadsRepositoryProvider)
          .updateThread(widget.threadId, archived: true);
      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not archive. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final threadId = widget.threadId;

    ref.watch(threadOpenProvider(threadId));

    // Refresh thread data when a live session ends so the call card clears
    // immediately rather than waiting for the next 60-second poll cycle.
    ref.listen<RealtimeState>(
      realtimeControllerProvider,
      (prev, next) {
        if (!mounted) return;
        // Transition from active session → idle (call ended / left / ended remotely).
        if (prev != null &&
            prev.session != null &&
            next.session == null &&
            !next.isJoined) {
          _refreshThreadData();
        }
      },
    );

    // Track new incoming messages for bottom-anchor affordance + B5/B6
    // optimistic reconciliation by clientMessageId.
    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(
      messagesProvider(widget.threadId),
      (prev, next) {
        if (!mounted) return;
        final prevList = prev?.maybeWhen(data: (d) => d, orElse: () => null);
        final nextList = next.maybeWhen(data: (d) => d, orElse: () => null);

        // B5: reconcile pending → confirmed using clientMessageId stored in
        // the server message's metadataJson. Prior code dedup'd by `_localId`,
        // a client-only field that the server never returns — so optimistic
        // rows stuck in the list as "Sending…" forever.
        if (nextList != null && _pendingMessages.isNotEmpty) {
          final confirmedClientIds = <String>{};
          for (final s in nextList) {
            final cmid = _readClientMessageId(s);
            if (cmid.isNotEmpty) confirmedClientIds.add(cmid);
          }
          if (confirmedClientIds.isNotEmpty) {
            final before = _pendingMessages.length;
            _pendingMessages.removeWhere(
              (p) => confirmedClientIds.contains(p.clientMessageId),
            );
            if (_pendingMessages.length != before) {
              // Trigger a rebuild so the optimistic row vanishes the same
              // frame the confirmed server row appears.
              setState(() {});
            }
          }
        }

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
    final spaceId =
        thread != null ? pickString(thread, const ['spaceId', 'space_id']) : '';

    return AuraScaffold(
      body: Column(
        children: [
          // ── Sticky compact header ───────────────────────────────────────────
          if (thread != null && threadContext != null)
            _ThreadCompactBar(
              contextData: threadContext,
              conversationId: pickString(thread, const ['id', 'threadId']),
              callBusy: callBusy,
              onStartAudio: () => _startLive(thread: thread, kind: 'AUDIO'),
              onStartVideo: () => _startLive(thread: thread, kind: 'VIDEO'),
              onOpenSpace: spaceId.isNotEmpty
                  ? () => context.push('/me/correspondence/$spaceId')
                  : null,
              onInvite: spaceId.isNotEmpty
                  ? () {
                      final returnTo =
                          '/me/correspondence/$spaceId/thread/${widget.threadId}';
                      final inviteRoute = Uri(
                        path: '/invite/create',
                        queryParameters: {
                          'destinationType': 'JOIN_SPACE',
                          'spaceId': spaceId,
                          'threadId': widget.threadId,
                          'returnTo': returnTo,
                        },
                      ).toString();
                      unawaited(context.push(inviteRoute).then((_) {
                        if (mounted) _refreshThreadData();
                      }));
                    }
                  : null,
              onAddMembers: spaceId.isNotEmpty
                  ? () {
                      unawaited(
                        context
                            .push('/me/correspondence/$spaceId/invite')
                            .then((_) {
                          if (mounted) _refreshThreadData();
                        }),
                      );
                    }
                  : null,
              // Rename/archive only for group or space threads — not 1:1.
              onRename: !threadContext.isDirect
                  ? () => _renameThread(threadContext.explicitTitle)
                  : null,
              onArchive: !threadContext.isDirect ? _archiveThread : null,
            )
          else
            const _ThreadBarPlaceholder(),
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
                    // Keep the thread visible during a post-send / realtime
                    // refresh — only the genuine first load shows the
                    // loading card, never a reload that already has data.
                    skipLoadingOnReload: true,
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
                          _ConversationCallCard(
                            sessionId: _threadResolvedSessionId(thread, liveState, widget.threadId),
                            liveState: liveState,
                            callBusy: callBusy,
                            onJoin: () async {
                              final sid = _threadResolvedSessionId(thread, liveState, widget.threadId);
                              if (sid.isEmpty) return;
                              context.go('/realtime/$sid?action=join&returnTo=${Uri.encodeComponent(GoRouterState.of(context).uri.toString())}');
                            },
                            onLeave: () async => ref.read(realtimeControllerProvider.notifier).leave(),
                            onReturn: () {
                              final sid = _threadResolvedSessionId(thread, liveState, widget.threadId);
                              if (sid.isEmpty) return;
                              context.go('/realtime/$sid?returnTo=${Uri.encodeComponent(GoRouterState.of(context).uri.toString())}');
                            },
                          ),
                          const SizedBox(height: AuraSpace.s16),
                          LayoutBuilder(
                            builder: (context, constraints) {
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
                                onRetryPending: (clientMessageId) {
                                  final pending = _pendingMessages.firstWhere(
                                    (p) => p.clientMessageId == clientMessageId,
                                    orElse: () => _PendingMessage(
                                      localId: '',
                                      clientMessageId: '',
                                      body: '',
                                      senderId: '',
                                      senderName: '',
                                      senderHandle: '',
                                      senderAvatarUrl: '',
                                      attachments: const [],
                                      sentAt: DateTime.now(),
                                    ),
                                  );
                                  if (pending.clientMessageId.isEmpty) return;
                                  unawaited(_retryPendingMessage(pending));
                                },
                                onDismissPending: (clientMessageId) {
                                  final pending = _pendingMessages.firstWhere(
                                    (p) => p.clientMessageId == clientMessageId,
                                    orElse: () => _PendingMessage(
                                      localId: '',
                                      clientMessageId: '',
                                      body: '',
                                      senderId: '',
                                      senderName: '',
                                      senderHandle: '',
                                      senderAvatarUrl: '',
                                      attachments: const [],
                                      sentAt: DateTime.now(),
                                    ),
                                  );
                                  if (pending.clientMessageId.isEmpty) return;
                                  _dismissPendingMessage(pending);
                                },
                              );

                              // Conversation-first layout: messages remain the primary surface.
                              // Context/actions stay available from the compact header menu,
                              // not as a permanent side rail that competes with messages.
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
            onSendFailed: ({required String clientMessageId, required Object error}) {
              _markPendingFailed(clientMessageId: clientMessageId);
            },
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

// ─────────────────────────────────────────────────────────────────────────────
// COMPACT STICKY HEADER BAR
// ─────────────────────────────────────────────────────────────────────────────

class _ThreadCompactBar extends StatelessWidget {
  const _ThreadCompactBar({
    required this.contextData,
    required this.conversationId,
    required this.callBusy,
    required this.onStartAudio,
    required this.onStartVideo,
    this.onOpenSpace,
    this.onInvite,
    this.onAddMembers,
    this.onRename,
    this.onArchive,
  });

  final CorrespondenceThreadContext contextData;
  final String conversationId;
  final bool callBusy;
  final VoidCallback onStartAudio;
  final VoidCallback onStartVideo;
  final VoidCallback? onOpenSpace;
  final VoidCallback? onInvite;
  final VoidCallback? onAddMembers;
  final VoidCallback? onRename;
  final VoidCallback? onArchive;

  String _contextLine() {
    if (contextData.isSpace) {
      final space = contextData.spaceTitle;
      final channel = contextData.explicitTitle;
      if (channel.isNotEmpty &&
          channel.toLowerCase() != space.toLowerCase()) {
        return space.isNotEmpty ? '$space · $channel' : channel;
      }
      return space.isNotEmpty ? space : 'Shared space';
    }
    if (contextData.isGroup) {
      return contextData.participantSummary.isNotEmpty
          ? contextData.participantSummary
          : 'Group conversation';
    }
    return contextData.subtitle.isNotEmpty ? contextData.subtitle : '';
  }

  @override
  Widget build(BuildContext context) {
    final ctxLine = _contextLine();
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: AuraSurface.card,
        border: Border(
          bottom: BorderSide(color: AuraSurface.divider, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s16),
      child: Row(
        children: [
          AuraAvatar(
            name: contextData.title,
            imageUrl: contextData.avatarUrl,
            size: 32,
          ),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contextData.title,
                  style: AuraText.emphasis.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AuraSurface.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (ctxLine.isNotEmpty)
                  Text(
                    ctxLine,
                    style: AuraText.micro.copyWith(
                      fontSize: 11,
                      color: AuraSurface.muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AuraSpace.s8),
          _BarIconButton(
            icon: Icons.call_rounded,
            busy: callBusy,
            onPressed: callBusy ? null : onStartAudio,
          ),
          const SizedBox(width: AuraSpace.s4),
          _BarIconButton(
            icon: Icons.videocam_rounded,
            busy: callBusy,
            onPressed: callBusy ? null : onStartVideo,
          ),
          const SizedBox(width: AuraSpace.s4),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(
              Icons.more_horiz_rounded,
              size: 18,
              color: AuraSurface.muted,
            ),
            color: AuraSurface.card,
            itemBuilder: (_) {
              final items = <PopupMenuEntry<String>>[
                const PopupMenuItem(
                  value: 'copy-id',
                  child: Text('Copy conversation ID'),
                ),
              ];
              if (onOpenSpace != null) {
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
              if (onRename != null || onArchive != null) {
                items.add(const PopupMenuDivider());
                if (onRename != null) {
                  items.add(const PopupMenuItem(
                    value: 'rename',
                    child: Text('Rename conversation'),
                  ));
                }
                if (onArchive != null) {
                  items.add(const PopupMenuItem(
                    value: 'archive',
                    child: Text('Archive conversation'),
                  ));
                }
              }
              return items;
            },
            onSelected: (value) async {
              if (value == 'copy-id') {
                final text = conversationId.trim().isNotEmpty
                    ? conversationId.trim()
                    : GoRouterState.of(context).uri.path;
                await Clipboard.setData(ClipboardData(text: text));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Conversation ID copied.')),
                );
                return;
              }
              if (value == 'open-space' && onOpenSpace != null) {
                onOpenSpace!();
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
              if (value == 'rename' && onRename != null) {
                onRename!();
                return;
              }
              if (value == 'archive' && onArchive != null) {
                onArchive!();
                return;
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ThreadBarPlaceholder extends StatelessWidget {
  const _ThreadBarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: AuraSurface.card,
        border: Border(
          bottom: BorderSide(color: AuraSurface.divider, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AuraSurface.subtle,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AuraSpace.s10),
          Container(
            width: 120,
            height: 12,
            decoration: BoxDecoration(
              color: AuraSurface.subtle,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarIconButton extends StatelessWidget {
  const _BarIconButton({
    required this.icon,
    required this.onPressed,
    this.busy = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: busy ? 0.45 : 1.0,
      child: MouseRegion(
        cursor: onPressed != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Icon(icon, size: 15, color: AuraSurface.ink),
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
    required this.onRetryPending,
    required this.onDismissPending,
  });

  final AsyncValue<List<Map<String, dynamic>>> messagesAsync;
  final List<Map<String, dynamic>> pendingMessages;
  final String currentUserId;
  final CorrespondenceThreadContext threadContext;
  final VoidCallback onRefresh;
  final void Function(Map<String, dynamic> message) onEditMessage;
  final Future<void> Function(Map<String, dynamic> message) onDeleteMessage;
  /// Invoked when the user taps Retry on a failed pending message.
  final void Function(String clientMessageId) onRetryPending;
  /// Invoked when the user taps Dismiss on a failed pending message.
  final void Function(String clientMessageId) onDismissPending;

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
            // Stale messages stay on screen during a send / refresh reload;
            // a populated conversation never blanks back to a spinner.
            skipLoadingOnReload: true,
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
              // B5: reconcile pending → server by clientMessageId.
              // The server stores it in metadataJson.clientMessageId. The
              // listener in thread_screen typically removes pending rows
              // before this build runs, but this defensive filter ensures a
              // pending row never duplicates a confirmed server row even on
              // an early frame.
              final confirmedClientIds = <String>{};
              for (final s in serverMessages) {
                final meta = s['metadataJson'];
                if (meta is Map) {
                  final v = meta['clientMessageId'];
                  if (v is String && v.trim().isNotEmpty) {
                    confirmedClientIds.add(v.trim());
                  }
                }
              }
              final messages = [
                ...serverMessages,
                // Append pending messages that aren't yet confirmed by server.
                ...pendingMessages.where((p) {
                  final cmid = (p['_clientMessageId'] ?? p['_localId'] ?? '')
                      .toString()
                      .trim();
                  if (cmid.isEmpty) return true;
                  return !confirmedClientIds.contains(cmid);
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
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Failed to send',
                                    style: AuraText.micro.copyWith(
                                      color: AuraSurface.dangerInk,
                                    ),
                                  ),
                                  const SizedBox(width: AuraSpace.s8),
                                  _PendingActionChip(
                                    label: 'Retry',
                                    icon: Icons.refresh_rounded,
                                    accent: true,
                                    onTap: () {
                                      final cmid = pickString(
                                        messages[i],
                                        const ['_clientMessageId', '_localId'],
                                      );
                                      if (cmid.isEmpty) return;
                                      onRetryPending(cmid);
                                    },
                                  ),
                                  const SizedBox(width: AuraSpace.s4),
                                  _PendingActionChip(
                                    label: 'Dismiss',
                                    icon: Icons.close_rounded,
                                    onTap: () {
                                      final cmid = pickString(
                                        messages[i],
                                        const ['_clientMessageId', '_localId'],
                                      );
                                      if (cmid.isEmpty) return;
                                      onDismissPending(cmid);
                                    },
                                  ),
                                ],
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

/// Compact chip used in the message tile footer to expose Retry/Dismiss
/// affordances on a failed pending message. Mirrors the visual rhythm of
/// inline status chips elsewhere in the thread surface.
class _PendingActionChip extends StatelessWidget {
  const _PendingActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.accent = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final fg = accent ? AuraSurface.accentText : AuraSurface.muted;
    final bg = accent ? AuraSurface.accentSoft : AuraSurface.subtle;
    final border = accent
        ? AuraSurface.accent.withValues(alpha: 0.35)
        : AuraSurface.divider;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s8,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(AuraRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11, color: fg),
              const SizedBox(width: 4),
              Text(
                label,
                style: AuraText.micro.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
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
