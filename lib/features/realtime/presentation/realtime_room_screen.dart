import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/services/call_presence_bridge.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_design_system.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../correspondence/presentation/thread_screen.dart';
import '../../search/search_repository.dart';
import '../application/caller_ringback_provider.dart';
import '../application/realtime_controller.dart';
import '../application/realtime_providers.dart';
import '../domain/realtime_enums.dart';
import '../domain/realtime_models.dart';
import '../domain/realtime_state.dart';
import 'widgets/realtime_consent_sheet.dart';
import 'widgets/realtime_host_controls.dart';
import 'widgets/realtime_join_requests_panel.dart';
import 'widgets/realtime_participant_list.dart';


class _CallRouteRedirectingFallback extends StatelessWidget {
  const _CallRouteRedirectingFallback();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AuraSurface.page,
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> _unwrapResponseMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    final inner = value['data'];
    if (inner is Map<String, dynamic>) return inner;
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return value;
  }
  if (value is Map) {
    final map = Map<String, dynamic>.from(value);
    final inner = map['data'];
    if (inner is Map<String, dynamic>) return inner;
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return map;
  }
  return <String, dynamic>{};
}

final _realtimeCurrentUserProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/users/me');
  return _unwrapResponseMap(response.data);
});

const _kPanelParticipants = 'participants';
const _kPanelMore = 'more';

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class RealtimeRoomScreen extends ConsumerStatefulWidget {
  const RealtimeRoomScreen({
    super.key,
    required this.sessionId,
    this.action,
    this.returnTo,
  });

  final String sessionId;
  final String? action;
  final String? returnTo;

  @override
  ConsumerState<RealtimeRoomScreen> createState() => _RealtimeRoomScreenState();
}

class _RealtimeRoomScreenState extends ConsumerState<RealtimeRoomScreen> {
  bool _didBoot = false;
  bool _isEnding = false;
  bool _wasJoined = false;
  bool _hasNavigatedAway = false;
  String? _lastConsentSyncKey;
  Timer? _durationTimer;
  DateTime _now = DateTime.now();
  // Panel state: null = closed; only one panel open at a time
  String? _activePanel;
  // Captured at first didChangeDependencies so dispose() can emit a best-effort
  // leave without using `ref` (which throws once the State is being disposed).
  ProviderContainer? _capturedContainer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _capturedContainer ??= ProviderScope.containerOf(context, listen: false);
    if (_didBoot) return;
    _didBoot = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = ref.read(realtimeControllerProvider.notifier);
      final action = (widget.action ?? '').trim().toLowerCase();

      if (action == 'join') {
        await controller.join(widget.sessionId);
      } else if (action == 'resume') {
        await controller.resume(widget.sessionId);
      } else {
        final currentState = ref.read(realtimeControllerProvider);
        final managedId =
            (currentState.sessionId ?? currentState.session?.id ?? '').trim();
        final alreadyJoined =
            currentState.isJoined && managedId == widget.sessionId.trim();
        if (!alreadyJoined) {
          await controller.hydrateSession(widget.sessionId);
        }
      }
    });

    _durationTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    // Best-effort leave on dispose (browser refresh / forced navigation).
    // Read via the captured ProviderContainer — `ref` is invalid once the State
    // is being disposed and would throw "Cannot use \"ref\" after the widget
    // was disposed", silently aborting the leave RPC and leaving the backend
    // session with a ghost participant.
    final container = _capturedContainer;
    if (container != null) {
      try {
        if (container.read(realtimeControllerProvider).isJoined) {
          final controller =
              container.read(realtimeControllerProvider.notifier);
          unawaited(controller.leave().catchError((_) {}));
        }
      } catch (_) {
        // best-effort: never let dispose throw
      }
    }
    super.dispose();
  }

  void _syncConsentsIfNeeded({
    required RealtimeController controller,
    required String sessionId,
    required bool? canManageConsents,
  }) {
    if (sessionId.trim().isEmpty || canManageConsents != true) return;
    final syncKey = '$sessionId:moderator';
    if (_lastConsentSyncKey == syncKey) return;
    _lastConsentSyncKey = syncKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      controller.syncConsentsVisibility(canManageConsents: canManageConsents);
    });
  }

  void _togglePanel(String panelId, bool wide) {
    if (wide) {
      setState(() {
        _activePanel = _activePanel == panelId ? null : panelId;
      });
    } else {
      _openBottomPanel(panelId);
    }
  }

  Future<void> _endCallAndClose(RealtimeController controller) async {
    if (_isEnding) return;
    setState(() => _isEnding = true);
    final session = ref.read(realtimeControllerProvider).session;
    debugPrint('[END] End button tapped: sessionId=${session?.id}');
    try {
      debugPrint('[END] _endCallAndClose: awaiting controller.endCall()');
      await controller.endCall();
    } catch (e, st) {
      // endCall is designed to be local-first, but never let an unexpected
      // exception keep the user trapped on the call route.
      debugPrint('[END] _endCallAndClose unexpected error: $e\n${st.toString().split('\n').take(4).join('\n')}');
    } finally {
      if (mounted) {
        _hasNavigatedAway = true;
        _navigateAfterCall(session);
      }
    }
  }

  Future<void> _leaveAndNavigate(RealtimeController controller) async {
    final session = ref.read(realtimeControllerProvider).session;
    try {
      await controller.leave();
    } catch (_) {}
    if (mounted) {
      _hasNavigatedAway = true;
      _navigateAfterCall(session);
    }
  }

  String _safeReturnRoute(RealtimeSession? session) {
    final explicit = _decodeReturnRoute(widget.returnTo);
    if (_isUsableReturnRoute(explicit)) {
      return explicit;
    }

    final surfaceId = (session?.surfaceId ?? '').trim();
    if (session != null) {
      switch (session.surfaceType) {
        case RealtimeSurfaceType.space:
          if (surfaceId.isNotEmpty) return '/me/correspondence/$surfaceId';
        case RealtimeSurfaceType.dm:
        case RealtimeSurfaceType.thread:
          // DM/thread call sessions only carry surfaceId; they do not always
          // carry the space id required for a thread route. Do not fall back to
          // the generic correspondence shell because it can render an empty
          // grey workspace. Use /home unless a precise returnTo was captured.
          return '/home';
        default:
          break;
      }
    }
    return '/home';
  }

  String _decodeReturnRoute(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return '';
    try {
      final decoded = value.startsWith('%2F') || value.startsWith('%2f')
          ? Uri.decodeComponent(value)
          : value;
      final parsed = Uri.tryParse(decoded);
      return parsed?.toString().trim() ?? decoded;
    } catch (_) {
      return '';
    }
  }

  bool _isUsableReturnRoute(String route) {
    if (!route.startsWith('/') || route.startsWith('/realtime')) return false;

    // The generic correspondence hub/shell is not a safe post-call landing
    // route. It has produced the blank grey state in live testing. Exact space
    // and thread routes remain valid.
    if (route == '/me/correspondence') return false;

    return true;
  }

  void _navigateAfterCall(RealtimeSession? session) {
    // Invalidate cached thread data so the stale liveSessionId ribbon is gone
    // when the thread screen remounts after the call ends.
    final surfaceId = (session?.surfaceId ?? '').trim();
    if (surfaceId.isNotEmpty) {
      ref.invalidate(threadDetailProvider(surfaceId));
      ref.invalidate(messagesProvider(surfaceId));
    }

    final target = _safeReturnRoute(session);
    context.go(target);
  }

  void _minimizeCall(RealtimeSession? session) {
    // Navigate back without ending the call — PiP widget takes over.
    final target = _safeReturnRoute(session);
    context.go(target);
  }

  void _openBottomPanel(String panelId) {
    final state = ref.read(realtimeControllerProvider);
    final myUserId = ref
        .read(_realtimeCurrentUserProvider)
        .maybeWhen(data: (me) => (me['id'] ?? '').toString(), orElse: () => '');
    final isHost =
        myUserId.isNotEmpty && state.session?.startedByUserId == myUserId;
    final canModerate =
        state.participants
            .where((p) => p.userId == myUserId)
            .map((p) => p.isModerator)
            .firstOrNull ??
        isHost;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AuraSurface.subtle,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: _CallPanelContent(
            panelId: panelId,
            sessionId: widget.sessionId,
            myUserId: myUserId,
            canModerate: canModerate,
            scrollController: scrollController,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep the presence bridge alive in this window so it can broadcast
    // heartbeats to the main tab's FloatingCallWidget PiP overlay.
    ref.watch(callPresenceBridgeProvider);

    // Track when the session first becomes joined so the post-end guard
    // can distinguish "never joined" from "joined and now torn down".
    ref.listen<RealtimeState>(realtimeControllerProvider, (_, next) {
      if (next.isJoined && !_wasJoined) _wasJoined = true;
    });

    final state = ref.watch(realtimeControllerProvider);
    final controller = ref.read(realtimeControllerProvider.notifier);
    final meAsync = ref.watch(_realtimeCurrentUserProvider);
    final ringingSessionIds = ref.watch(callerRingbackProvider);

    // After teardown, leave the realtime route immediately. Do not render a
    // blank scaffold on /realtime/:id; that was the source of the grey/wrapped
    // post-call screen.
    if (_wasJoined &&
        state.joinState == RealtimeJoinState.idle &&
        state.session == null) {
      if (!_hasNavigatedAway) {
        _hasNavigatedAway = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _navigateAfterCall(null);
        });
      }
      return const _CallRouteRedirectingFallback();
    }

    final myUserId = meAsync.maybeWhen(
      data: (me) => (me['id'] ?? '').toString(),
      orElse: () => '',
    );

    RealtimeParticipant? myParticipant;
    for (final p in state.participants) {
      if (p.userId == myUserId) {
        myParticipant = p;
        break;
      }
    }

    final isHost =
        myUserId.isNotEmpty && state.session?.startedByUserId == myUserId;
    final canModerate = myParticipant?.isModerator ?? isHost;
    final policy = state.policy;
    final roomIsClosed =
        state.session?.isLocked == true || policy?.isLocked == true;

    _syncConsentsIfNeeded(
      controller: controller,
      sessionId: state.isJoined ? (state.sessionId ?? widget.sessionId) : '',
      canManageConsents: canModerate,
    );

    final callDuration = _callDuration(state.session, _now);
    final showConnectionIssue =
        state.connectionStatus == RealtimeConnectionStatus.disconnected ||
        state.connectionStatus == RealtimeConnectionStatus.error;
    final isConnecting =
        state.connectionStatus == RealtimeConnectionStatus.connecting ||
        state.connectionStatus == RealtimeConnectionStatus.reconnecting;
    final joinRequestCount = (policy?.joinRequests ?? const []).length;

    return PopScope(
      canPop: !state.isJoined,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && state.isJoined && !_hasNavigatedAway) {
          _hasNavigatedAway = true;
          _minimizeCall(state.session);
        }
      },
      child: Scaffold(
      backgroundColor: AuraSurface.page,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 860;

          return Column(
            children: [
              // ── Header bar ────────────────────────────────────────────────
              _CallTopBar(
                title: _callTitle(state.session, state.isVideoMode),
                contextLabel: _contextLabel(state.session),
                duration: callDuration,
                participantCount: state.participants.length,
                isConnecting: isConnecting,
                hasIssue: showConnectionIssue,
                isRinging: state.isJoined &&
                    state.participants.length <= 1 &&
                    ringingSessionIds.contains(widget.sessionId),
                onMinimize: state.isJoined
                    ? () => _minimizeCall(state.session)
                    : null,
              ),

              // ── Consent banner ────────────────────────────────────────────
              RealtimeConsentSheet(
                currentUserId: myUserId.isNotEmpty ? myUserId : null,
                consents: state.consents,
              ),

              // ── Connection issue banner ───────────────────────────────────
              if (showConnectionIssue)
                _ConnectionBanner(
                  isBusy: state.isBusy || isConnecting,
                  onReconnect: () => controller.resume(widget.sessionId),
                ),

              // ── Main body ─────────────────────────────────────────────────
              Expanded(
                child: state.isJoined
                    ? _buildActiveCall(
                        state: state,
                        controller: controller,
                        myUserId: myUserId,
                        canModerate: canModerate,
                        wide: wide,
                      )
                    : _buildPreJoin(
                        context: context,
                        state: state,
                        controller: controller,
                        policy: policy,
                        roomIsClosed: roomIsClosed,
                      ),
              ),

              // ── Call controls ─────────────────────────────────────────────
              if (state.isJoined)
                _CallControlDock(
                  micOn: state.microphoneEnabled,
                  cameraOn: state.cameraEnabled,
                  isVideoMode: state.isVideoMode,
                  activePanel: _activePanel,
                  pendingRequests: canModerate ? joinRequestCount : 0,
                  onToggleMic: controller.toggleMicrophone,
                  onToggleCamera: controller.toggleCamera,
                  onParticipants: () =>
                      _togglePanel(_kPanelParticipants, wide),
                  onMore: () => _togglePanel(_kPanelMore, wide),
                  // Only the session host can end for everyone.
                  // Non-hosts always leave; the backend auto-ends when the
                  // last active participant leaves.
                  isEndCall: isHost,
                  isEnding: _isEnding,
                  onLeave: _isEnding
                      ? null
                      : isHost
                          ? () => unawaited(_endCallAndClose(controller))
                          : () => unawaited(_leaveAndNavigate(controller)),
                ),
            ],
          );
        },
      ),
      ),
    );
  }

  // ── Active call layout ────────────────────────────────────────────────────

  Widget _buildActiveCall({
    required RealtimeState state,
    required RealtimeController controller,
    required String myUserId,
    required bool canModerate,
    required bool wide,
  }) {
    final stage = _CallStage(
      state: state,
      myUserId: myUserId,
    );

    if (!wide || _activePanel == null) return stage;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: stage),
        SizedBox(
          width: 360,
          child: Container(
            decoration: const BoxDecoration(
              color: AuraSurface.subtle,
              border: Border(left: BorderSide(color: AuraSurface.divider)),
            ),
            child: _CallPanelContent(
              panelId: _activePanel!,
              sessionId: widget.sessionId,
              myUserId: myUserId,
              canModerate: canModerate,
              onClose: () => setState(() => _activePanel = null),
            ),
          ),
        ),
      ],
    );
  }

  // ── Pre-join / lobby view ─────────────────────────────────────────────────

  Widget _buildPreJoin({
    required BuildContext context,
    required RealtimeState state,
    required RealtimeController controller,
    required RealtimePolicy? policy,
    required bool roomIsClosed,
  }) {
    final (icon, title, subtitle, showJoin, showRequest) =
        _preJoinContent(state: state, policy: policy, roomIsClosed: roomIsClosed);

    // Auto-navigate away from an ended session so the screen never stays blank.
    if (state.session?.isActive == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _navigateAfterCall(state.session);
      });
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AuraSpace.s24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: AuraGradients.accent,
                  borderRadius: BorderRadius.circular(AuraRadius.xl),
                ),
                child: Icon(icon, size: 30, color: Colors.white),
              ),
              const SizedBox(height: AuraSpace.s20),
              Text(title, style: AuraText.headline, textAlign: TextAlign.center),
              const SizedBox(height: AuraSpace.s8),
              Text(subtitle, style: AuraText.muted, textAlign: TextAlign.center),
              if ((state.errorMessage ?? '').isNotEmpty) ...[
                const SizedBox(height: AuraSpace.s12),
                Container(
                  padding: const EdgeInsets.all(AuraSpace.s12),
                  decoration: BoxDecoration(
                    color: AuraSurface.dangerBg,
                    borderRadius: BorderRadius.circular(AuraRadius.md),
                    border: Border.all(
                      color: AuraSurface.dangerInk.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    state.errorMessage ?? '',
                    style: AuraText.small.copyWith(color: AuraSurface.dangerInk),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: AuraSpace.s24),
              Wrap(
                spacing: AuraSpace.s8,
                runSpacing: AuraSpace.s8,
                alignment: WrapAlignment.center,
                children: [
                  if (showJoin)
                    AuraPrimaryButton(
                      label: state.isBusy ? 'Joining…' : 'Join call',
                      onPressed: state.isBusy
                          ? null
                          : () => controller.join(widget.sessionId),
                    ),
                  if (showRequest)
                    AuraPrimaryButton(
                      label: 'Request access',
                      onPressed: state.isBusy
                          ? null
                          : () => controller.requestJoin(widget.sessionId),
                    ),
                  if ((_spaceRoute(state.session) ?? '').isNotEmpty)
                    AuraSecondaryButton(
                      label: 'Back to conversation',
                      onPressed: () {
                        final route = _spaceRoute(state.session);
                        if (route != null && mounted) context.go(route);
                      },
                    ),
                  AuraSecondaryButton(
                    label: 'Leave',
                    onPressed: () {
                      unawaited(controller.leave());
                      _navigateAfterCall(state.session);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  (IconData, String, String, bool, bool) _preJoinContent({
    required RealtimeState state,
    required RealtimePolicy? policy,
    required bool roomIsClosed,
  }) {
    if (state.isBusy || state.joinState == RealtimeJoinState.joining) {
      return (
        Icons.call_rounded,
        'Connecting…',
        'Setting up your session. This only takes a moment.',
        false,
        false,
      );
    }
    switch (state.joinState) {
      case RealtimeJoinState.requested:
        return (
          Icons.hourglass_top_rounded,
          'Waiting for approval',
          'Your request has been sent. The host will let you in shortly.',
          false,
          false,
        );
      case RealtimeJoinState.rejected:
        return (
          Icons.block_rounded,
          'Entry declined',
          'Your request to join was declined.',
          false,
          true,
        );
      case RealtimeJoinState.removed:
        return (
          Icons.person_remove_rounded,
          'Removed from call',
          'You were removed from this call by the host.',
          false,
          false,
        );
      case RealtimeJoinState.locked:
        return (
          Icons.lock_rounded,
          'Room closed',
          'This room is not accepting new participants right now.',
          false,
          policy?.waitingRoomEnabled == true,
        );
      case RealtimeJoinState.failed:
        final errLower = (state.errorMessage ?? '').toLowerCase();
        final isTerminal = errLower.contains('invite_expired') ||
            errLower.contains('invite has expired') ||
            errLower.contains('session_closed') ||
            errLower.contains('session is closed');
        if (isTerminal) {
          return (
            Icons.call_end_rounded,
            'Call unavailable',
            'This call has ended or your invite has expired.',
            false,
            false,
          );
        }
        return (
          Icons.error_outline_rounded,
          'Could not join',
          'Something went wrong. Please try again.',
          true,
          false,
        );
      default:
        if (state.session?.isActive == false) {
          return (
            Icons.call_end_rounded,
            'Call has ended',
            'This call is no longer active.',
            false,
            false,
          );
        }
        if (roomIsClosed) {
          return (
            Icons.lock_rounded,
            'Room closed',
            'This room is closed to new entries.',
            false,
            true,
          );
        }
        return (
          Icons.call_rounded,
          'Ready to join',
          'Tap Join call to enter.',
          true,
          false,
        );
    }
  }

  String _callTitle(RealtimeSession? session, bool isVideo) {
    if (session == null) return isVideo ? 'Video call' : 'Audio call';
    switch (session.surfaceType) {
      case RealtimeSurfaceType.dm:
      case RealtimeSurfaceType.thread:
        return isVideo ? 'Video call' : 'Audio call';
      case RealtimeSurfaceType.space:
      case RealtimeSurfaceType.room:
        return isVideo ? 'Video call' : 'Audio call';
      case RealtimeSurfaceType.institution:
        return isVideo ? 'Video call' : 'Audio call';
      case RealtimeSurfaceType.unknown:
        return isVideo ? 'Video call' : 'Audio call';
    }
  }

  String? _contextLabel(RealtimeSession? session) {
    if (session == null) return null;
    final named = session.contextName ?? session.title;
    switch (session.surfaceType) {
      case RealtimeSurfaceType.dm:
        return named != null ? 'Direct call · $named' : 'Direct call';
      case RealtimeSurfaceType.thread:
        return named != null ? 'in $named' : null;
      case RealtimeSurfaceType.space:
      case RealtimeSurfaceType.room:
        return named != null ? 'in $named' : 'Space live';
      case RealtimeSurfaceType.institution:
        return named != null ? '$named · Institution live' : 'Institution live';
      case RealtimeSurfaceType.unknown:
        return named;
    }
  }

  String? _spaceRoute(RealtimeSession? session) {
    if (session == null) return null;
    if (session.surfaceType == RealtimeSurfaceType.space) {
      final id = (session.surfaceId ?? '').trim();
      if (id.isNotEmpty) return '/me/correspondence/$id';
    }
    return null;
  }

  Duration? _callDuration(RealtimeSession? session, DateTime now) {
    if (session == null) return null;
    final start =
        session.answeredAt ??
        session.firstJoinedAt ??
        session.startedAt ??
        session.createdAt;
    if (start == null) return null;
    if (session.endedAt != null) return session.endedAt!.difference(start);
    final d = now.difference(start);
    return d.inSeconds < 0 ? Duration.zero : d;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CALL TOP BAR
// ─────────────────────────────────────────────────────────────────────────────

class _CallTopBar extends StatelessWidget {
  const _CallTopBar({
    required this.title,
    required this.duration,
    required this.participantCount,
    required this.isConnecting,
    required this.hasIssue,
    this.contextLabel,
    this.isRinging = false,
    this.onMinimize,
  });

  final String title;
  final String? contextLabel;
  final Duration? duration;
  final int participantCount;
  final bool isConnecting;
  final bool hasIssue;
  final bool isRinging;
  final VoidCallback? onMinimize;

  String _fmt(Duration d) {
    final s = d.inSeconds;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '${two(h)}:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
  }

  @override
  Widget build(BuildContext context) {
    final durationLabel =
        duration != null ? _fmt(duration!) : null;

    Color statusColor;
    String statusLabel;
    if (hasIssue) {
      statusColor = AuraSurface.dangerInk;
      statusLabel = 'Connection issue';
    } else if (isConnecting) {
      statusColor = AuraSurface.warnInk;
      statusLabel = 'Connecting…';
    } else if (isRinging) {
      statusColor = const Color(0xFFFBBF24);
      statusLabel = 'Ringing…';
    } else {
      statusColor = const Color(0xFF4ADE80);
      statusLabel = 'Live';
    }

    return Container(
      constraints: BoxConstraints(minHeight: contextLabel != null ? 60 : 52),
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s16,
        vertical: AuraSpace.s8,
      ),
      decoration: const BoxDecoration(
        color: AuraSurface.subtle,
        border: Border(bottom: BorderSide(color: AuraSurface.divider)),
      ),
      child: Row(
        children: [
          // Live indicator dot
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AuraSpace.s8),

          // Title + context label
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AuraText.body.copyWith(
                      color: AuraSurface.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (durationLabel != null) ...[
                    const SizedBox(width: AuraSpace.s8),
                    Text(
                      durationLabel,
                      style: AuraText.small.copyWith(
                        color: AuraSurface.muted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
              if (contextLabel != null)
                Text(
                  contextLabel!,
                  style: AuraText.small.copyWith(color: AuraSurface.muted),
                ),
            ],
          ),

          const Spacer(),

          // Status label (issue, connecting, or ringing states)
          if (hasIssue || isConnecting || isRinging) ...[
            Text(
              statusLabel,
              style: AuraText.label.copyWith(color: statusColor),
            ),
            const SizedBox(width: AuraSpace.s12),
          ],

          // Participant count
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s8,
              vertical: AuraSpace.s4,
            ),
            decoration: BoxDecoration(
              color: AuraSurface.accentSoft,
              borderRadius: BorderRadius.circular(AuraRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.people_rounded,
                  size: AuraIconSize.xs,
                  color: AuraSurface.accentText,
                ),
                const SizedBox(width: AuraSpace.s4),
                Text(
                  '$participantCount',
                  style: AuraText.label.copyWith(
                    color: AuraSurface.accentText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          // Minimize button — navigates to previous route with PiP overlay
          if (onMinimize != null) ...[
            const SizedBox(width: AuraSpace.s8),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onMinimize,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AuraSurface.card,
                    borderRadius: BorderRadius.circular(AuraRadius.md),
                    border: Border.all(color: AuraSurface.divider),
                  ),
                  child: const Icon(
                    Icons.minimize_rounded,
                    size: 16,
                    color: AuraSurface.muted,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONNECTION ISSUE BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({
    required this.isBusy,
    required this.onReconnect,
  });

  final bool isBusy;
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s16,
        vertical: AuraSpace.s10,
      ),
      decoration: const BoxDecoration(
        color: AuraSurface.warnBg,
        border: Border(bottom: BorderSide(color: AuraSurface.divider)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 16, color: AuraSurface.warnInk),
          const SizedBox(width: AuraSpace.s8),
          Expanded(
            child: Text(
              'Connection lost — tap to reconnect.',
              style: AuraText.small.copyWith(color: AuraSurface.warnInk),
            ),
          ),
          TextButton(
            onPressed: isBusy ? null : onReconnect,
            child: Text(
              isBusy ? 'Reconnecting…' : 'Reconnect',
              style: AuraText.small.copyWith(
                color: AuraSurface.warnInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CALL STAGE
// ─────────────────────────────────────────────────────────────────────────────

class _CallStage extends StatelessWidget {
  const _CallStage({required this.state, required this.myUserId});

  final RealtimeState state;
  final String myUserId;

  @override
  Widget build(BuildContext context) {
    final mediaError = (state.mediaError ?? '').trim();
    final hasRemoteRenderers = state.remoteRenderers.isNotEmpty;
    final hasLocalRenderer = state.localRenderer != null;
    final hasAnyRenderer = hasLocalRenderer || hasRemoteRenderers;

    // Video call with renderers
    if (state.isVideoMode && hasAnyRenderer) {
      return _VideoGrid(
        localRenderer: state.localRenderer,
        remoteRenderers: state.remoteRenderers,
        participants: state.participants,
        myUserId: myUserId,
        micOn: state.microphoneEnabled,
      );
    }

    // Media actively loading (first launch)
    if (state.isMediaBusy && !state.isMediaReady && !hasAnyRenderer) {
      return _MediaLoadingView(isVideo: state.isVideoMode);
    }

    // Media error with no renderers
    if (mediaError.isNotEmpty && !hasAnyRenderer) {
      return _MediaWarningView(isVideo: state.isVideoMode);
    }

    // Audio call or awaiting video — avatar stage
    return _AvatarStage(
      participants: state.participants,
      myUserId: myUserId,
      micOn: state.microphoneEnabled,
      isLoading: state.isMediaBusy && state.participants.isEmpty,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VIDEO GRID
// ─────────────────────────────────────────────────────────────────────────────

class _VideoGrid extends StatelessWidget {
  const _VideoGrid({
    required this.localRenderer,
    required this.remoteRenderers,
    required this.participants,
    required this.myUserId,
    required this.micOn,
  });

  final RTCVideoRenderer? localRenderer;
  final Map<String, RTCVideoRenderer> remoteRenderers;
  final List<RealtimeParticipant> participants;
  final String myUserId;
  final bool micOn;

  String _nameForUserId(String userId) {
    if (userId == myUserId) return 'You';
    for (final p in participants) {
      if (p.userId != userId) continue;
      final name = (p.displayName ?? '').trim();
      if (name.isNotEmpty) return name;
      final handle = (p.handle ?? '').trim();
      if (handle.isNotEmpty) return '@$handle';
      return 'Participant';
    }
    return 'Participant';
  }

  @override
  Widget build(BuildContext context) {
    final entries = <(String, RTCVideoRenderer, bool)>[];
    if (localRenderer != null) {
      entries.add(('You', localRenderer!, true));
    }
    for (final entry in remoteRenderers.entries) {
      entries.add((_nameForUserId(entry.key), entry.value, false));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        if (entries.length == 1) {
          return _VideoTile(
            label: entries.first.$1,
            renderer: entries.first.$2,
            mirror: entries.first.$3,
            micOn: entries.first.$1 == 'You' ? micOn : true,
          );
        }

        if (entries.length == 2) {
          final isLandscape = w > h;
          if (isLandscape) {
            return Row(
              children: entries
                  .map((e) => Expanded(
                        child: _VideoTile(
                          label: e.$1,
                          renderer: e.$2,
                          mirror: e.$3,
                          micOn: e.$1 == 'You' ? micOn : true,
                        ),
                      ))
                  .toList(),
            );
          }
          return Column(
            children: entries
                .map((e) => Expanded(
                      child: _VideoTile(
                        label: e.$1,
                        renderer: e.$2,
                        mirror: e.$3,
                        micOn: e.$1 == 'You' ? micOn : true,
                      ),
                    ))
                .toList(),
          );
        }

        // 3+ participants — responsive grid
        final cols = w >= 900 ? 3 : w >= 600 ? 2 : 2;
        final rows = (entries.length / cols).ceil();
        final tileH = h / rows;
        final tileW = w / cols;

        return SizedBox(
          width: w,
          height: h,
          child: Wrap(
            children: entries.map((e) {
              return SizedBox(
                width: tileW,
                height: tileH,
                child: _VideoTile(
                  label: e.$1,
                  renderer: e.$2,
                  mirror: e.$3,
                  micOn: e.$1 == 'You' ? micOn : true,
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VIDEO TILE
// ─────────────────────────────────────────────────────────────────────────────

class _VideoTile extends StatelessWidget {
  const _VideoTile({
    required this.label,
    required this.renderer,
    required this.micOn,
    this.mirror = false,
  });

  final String label;
  final RTCVideoRenderer renderer;
  final bool micOn;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: const Color(0xFF080E18)),
        RTCVideoView(
          renderer,
          mirror: mirror,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
        ),
        // Name + mic overlay at bottom-left
        Positioned(
          left: AuraSpace.s10,
          bottom: AuraSpace.s10,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s8,
              vertical: AuraSpace.s4,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(AuraRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!micOn) ...[
                  const Icon(
                    Icons.mic_off_rounded,
                    size: 11,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: AuraText.micro.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AVATAR STAGE (audio call / no video)
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarStage extends StatelessWidget {
  const _AvatarStage({
    required this.participants,
    required this.myUserId,
    required this.micOn,
    required this.isLoading,
  });

  final List<RealtimeParticipant> participants;
  final String myUserId;
  final bool micOn;
  final bool isLoading;

  String _displayName(RealtimeParticipant p, int index) {
    if (p.userId == myUserId) return 'You';
    final name = (p.displayName ?? '').trim();
    if (name.isNotEmpty) return name;
    final handle = (p.handle ?? '').trim();
    if (handle.isNotEmpty) return '@$handle';
    return 'Participant ${index + 1}';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && participants.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AuraSurface.accent,
              ),
            ),
            SizedBox(height: AuraSpace.s16),
            Text('Connecting your microphone…', style: AuraText.muted),
          ],
        ),
      );
    }

    if (participants.isEmpty) {
      return const Center(
        child: Text('Waiting for participants…', style: AuraText.muted),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = participants.length == 1
            ? 1
            : w >= 720
                ? math.min(4, participants.length)
                : w >= 480
                    ? math.min(3, participants.length)
                    : math.min(2, participants.length);
        final tileSize = math.min(
          (w - (cols - 1) * AuraSpace.s16) / cols,
          140.0,
        );

        return Center(
          child: Wrap(
            spacing: AuraSpace.s16,
            runSpacing: AuraSpace.s20,
            alignment: WrapAlignment.center,
            children: List.generate(participants.length, (i) {
              final p = participants[i];
              final name = _displayName(p, i);
              final isMe = p.userId == myUserId;
              final pMicOn = isMe ? micOn : p.audioOn;
              return SizedBox(
                width: tileSize,
                child: _AvatarTile(
                  name: name,
                  avatarUrl: p.avatarUrl,
                  micOn: pMicOn,
                  isPresent: p.isPresent,
                  size: math.min(tileSize * 0.55, 80.0),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _AvatarTile extends StatelessWidget {
  const _AvatarTile({
    required this.name,
    required this.avatarUrl,
    required this.micOn,
    required this.isPresent,
    required this.size,
  });

  final String name;
  final String? avatarUrl;
  final bool micOn;
  final bool isPresent;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Avatar ring when present
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isPresent
                      ? AuraSurface.accent.withValues(alpha: 0.7)
                      : AuraSurface.divider,
                  width: 2,
                ),
              ),
              child: AuraAvatar(
                name: name,
                imageUrl: avatarUrl,
                size: size,
              ),
            ),
            // Mic state badge
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: micOn ? AuraSurface.card : AuraSurface.dangerBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: AuraSurface.divider, width: 1.5),
                ),
                child: Icon(
                  micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                  size: 11,
                  color: micOn ? AuraSurface.accentText : AuraSurface.dangerInk,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.s8),
        Text(
          name,
          style: AuraText.small.copyWith(
            color: AuraSurface.ink,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MEDIA STATE PLACEHOLDERS
// ─────────────────────────────────────────────────────────────────────────────

class _MediaLoadingView extends StatelessWidget {
  const _MediaLoadingView({required this.isVideo});

  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AuraSurface.accent,
            ),
          ),
          const SizedBox(height: AuraSpace.s16),
          Text(
            isVideo
                ? 'Connecting your camera and microphone…'
                : 'Connecting your microphone…',
            style: AuraText.muted,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MediaWarningView extends StatelessWidget {
  const _MediaWarningView({required this.isVideo});

  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.mic_off_rounded,
              size: 36,
              color: AuraSurface.warnInk,
            ),
            const SizedBox(height: AuraSpace.s16),
            Text(
              isVideo
                  ? 'Camera and microphone are unavailable'
                  : 'Microphone is unavailable',
              style: AuraText.body.copyWith(color: AuraSurface.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AuraSpace.s8),
            const Text(
              'Check your browser permissions and try rejoining.',
              style: AuraText.muted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CALL CONTROL DOCK
// ─────────────────────────────────────────────────────────────────────────────

class _CallControlDock extends StatelessWidget {
  const _CallControlDock({
    required this.micOn,
    required this.cameraOn,
    required this.isVideoMode,
    required this.activePanel,
    required this.pendingRequests,
    required this.onToggleMic,
    required this.onToggleCamera,
    required this.onParticipants,
    required this.onMore,
    required this.onLeave,
    this.isEndCall = false,
    this.isEnding = false,
  });

  final bool micOn;
  final bool cameraOn;
  final bool isVideoMode;
  final String? activePanel;
  final int pendingRequests;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;
  final VoidCallback onParticipants;
  final VoidCallback onMore;
  final VoidCallback? onLeave;
  final bool isEndCall;
  final bool isEnding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s16,
        AuraSpace.s12,
        AuraSpace.s16,
        AuraSpace.s16,
      ),
      decoration: const BoxDecoration(
        color: AuraSurface.subtle,
        border: Border(top: BorderSide(color: AuraSurface.divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mic
          _DockButton(
            icon: micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
            label: micOn ? 'Mute' : 'Unmute',
            active: micOn,
            warning: !micOn,
            onPressed: onToggleMic,
          ),
          const SizedBox(width: AuraSpace.s8),

          // Camera (video calls only)
          if (isVideoMode) ...[
            _DockButton(
              icon: cameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
              label: cameraOn ? 'Camera' : 'Camera off',
              active: cameraOn,
              warning: !cameraOn,
              onPressed: onToggleCamera,
            ),
            const SizedBox(width: AuraSpace.s8),
          ],

          // Participants
          _DockButton(
            icon: Icons.people_rounded,
            label: 'Participants',
            active: activePanel == _kPanelParticipants,
            onPressed: onParticipants,
          ),
          const SizedBox(width: AuraSpace.s8),

          // More / Settings
          _DockButton(
            icon: Icons.tune_rounded,
            label: 'More',
            active: activePanel == _kPanelMore,
            badge: pendingRequests > 0 ? pendingRequests : null,
            onPressed: onMore,
          ),

          // Spacer before leave
          const SizedBox(width: AuraSpace.s16),

          // Leave / End button (distinct, red)
          _LeaveButton(
            onPressed: onLeave,
            label: isEnding ? 'Ending…' : (isEndCall ? 'End' : 'Leave'),
            busy: isEnding,
          ),
        ],
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
    this.warning = false,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool active;
  final bool warning;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final bgColor = active
        ? AuraSurface.accentSoft
        : warning
            ? AuraSurface.dangerBg
            : AuraSurface.card;
    final iconColor = active
        ? AuraSurface.accentText
        : warning
            ? AuraSurface.dangerInk
            : AuraSurface.muted;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(AuraRadius.md),
                child: AnimatedContainer(
                  duration: AuraMotion.fast,
                  width: 48,
                  height: 44,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(AuraRadius.md),
                    border: Border.all(
                      color: active
                          ? AuraSurface.accent.withValues(alpha: 0.4)
                          : AuraSurface.divider,
                    ),
                  ),
                  child: Icon(icon, size: AuraIconSize.md, color: iconColor),
                ),
              ),
            ),
            if ((badge ?? 0) > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: AuraSurface.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AuraSpace.s4),
        Text(
          label,
          style: AuraText.micro.copyWith(
            color: AuraSurface.faint,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _LeaveButton extends StatelessWidget {
  const _LeaveButton({
    required this.onPressed,
    this.label = 'Leave',
    this.busy = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AuraRadius.md),
            child: AnimatedContainer(
              duration: AuraMotion.fast,
              width: 56,
              height: 44,
              decoration: BoxDecoration(
                color: disabled
                    ? AuraSurface.dangerBg.withValues(alpha: 0.45)
                    : AuraSurface.dangerBg,
                borderRadius: BorderRadius.circular(AuraRadius.md),
                border: Border.all(
                  color: AuraSurface.dangerInk.withValues(
                    alpha: disabled ? 0.15 : 0.35,
                  ),
                ),
              ),
              child: busy
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AuraSurface.dangerInk,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.call_end_rounded,
                      size: AuraIconSize.md,
                      color: AuraSurface.dangerInk.withValues(
                        alpha: disabled ? 0.4 : 1.0,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: AuraSpace.s4),
        Text(
          label,
          style: AuraText.micro.copyWith(
            color: AuraSurface.dangerInk.withValues(
              alpha: disabled ? 0.4 : 1.0,
            ),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PANEL CONTENT (shared by desktop side panel + mobile bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────

class _CallPanelContent extends ConsumerStatefulWidget {
  const _CallPanelContent({
    required this.panelId,
    required this.sessionId,
    required this.myUserId,
    required this.canModerate,
    this.onClose,
    this.scrollController,
  });

  final String panelId;
  final String sessionId;
  final String myUserId;
  final bool canModerate;
  final VoidCallback? onClose;
  final ScrollController? scrollController;

  @override
  ConsumerState<_CallPanelContent> createState() => _CallPanelContentState();
}

class _CallPanelContentState extends ConsumerState<_CallPanelContent> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = const [];
  bool _searching = false;
  String? _inviting;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _noteCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String q, List<RealtimeParticipant> participants) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _search(q, participants);
    });
  }

  Future<void> _search(String query, List<RealtimeParticipant> participants) async {
    final q = query.trim();
    if (q.isEmpty) {
      if (mounted) setState(() { _results = const []; _searching = false; });
      return;
    }
    if (mounted) setState(() => _searching = true);
    try {
      final repo = SearchRepository(ref.read(dioProvider));
      final result = await repo.search(q, limit: 8);
      final existingIds = participants.map((p) => p.userId).toSet();
      final filtered = result.users.where((u) {
        final id = (u['id'] ?? '').toString().trim();
        return id.isNotEmpty &&
            id != widget.myUserId &&
            !existingIds.contains(id);
      }).toList();
      if (mounted) setState(() { _results = filtered; _searching = false; });
    } catch (_) {
      if (mounted) setState(() { _results = const []; _searching = false; });
    }
  }

  Future<void> _invite(Map<String, dynamic> user) async {
    final id = (user['id'] ?? '').toString().trim();
    if (id.isEmpty || _inviting != null) return;
    if (mounted) setState(() => _inviting = id);
    try {
      await ref.read(realtimeControllerProvider.notifier).inviteMember(
        invitedUserId: id,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _results = _results.where((u) => (u['id'] ?? '') != id).toList();
        _inviting = null;
      });
      _searchCtrl.clear();
      _noteCtrl.clear();
    } catch (_) {
      if (mounted) setState(() => _inviting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(realtimeControllerProvider);
    final controller = ref.read(realtimeControllerProvider.notifier);
    final isParticipants = widget.panelId == _kPanelParticipants;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelHeader(
          title: isParticipants ? 'Participants' : 'Call options',
          count: isParticipants ? state.participants.length : null,
          onClose: widget.onClose,
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(AuraSpace.s16),
            child: isParticipants
                ? _buildParticipants(state, controller)
                : _buildMore(state, controller),
          ),
        ),
      ],
    );
  }

  Widget _buildParticipants(RealtimeState state, RealtimeController ctrl) {
    return RealtimeParticipantList(
      participants: state.participants,
      session: state.session,
      canModerate: widget.canModerate,
      currentUserId: widget.myUserId,
      hostUserId: state.session?.startedByUserId,
      remoteRenderers: state.remoteRenderers,
      onRemove: ctrl.removeParticipant,
    );
  }

  Widget _buildMore(RealtimeState state, RealtimeController ctrl) {
    final policy = state.policy;
    final joinRequests = policy?.joinRequests ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Consent banner (if pending)
        RealtimeConsentSheet(
          currentUserId:
              widget.myUserId.isNotEmpty ? widget.myUserId : null,
          consents: state.consents,
        ),

        // Host controls
        if (widget.canModerate) ...[
          const SizedBox(height: AuraSpace.s4),
          RealtimeHostControls(
            session: state.session,
            policy: policy,
            onToggleWaitingRoom: (v) => ctrl.setWaitingRoom(v),
            onToggleLock: (v) => ctrl.setLocked(v),
            onRequestConsent: ctrl.requestConsent,
            onRequestRecording: ctrl.requestRecording,
            onRequestTranscript: ctrl.requestTranscript,
            onRefresh: () => ctrl.hydrateSession(widget.sessionId),
          ),
          const SizedBox(height: AuraSpace.s12),

          if (joinRequests.isNotEmpty) ...[
            RealtimeJoinRequestsPanel(
              requests: joinRequests,
              onApprove: ctrl.approveJoinRequest,
              onReject: ctrl.rejectJoinRequest,
            ),
            const SizedBox(height: AuraSpace.s12),
          ],

          _RoomInviteCard(
            searchController: _searchCtrl,
            noteController: _noteCtrl,
            isSearching: _searching,
            results: _results,
            invitingUserId: _inviting,
            onSearchChanged: (v) => _onSearchChanged(v, state.participants),
            onInvite: _invite,
          ),
          const SizedBox(height: AuraSpace.s12),
        ],

        _ArtifactBlock(
          policy: policy,
          recordingCount: state.recordings.length,
          transcriptCount: state.transcripts.length,
          artifactCount: state.artifacts.length,
        ),
        const SizedBox(height: AuraSpace.s12),

        AuraSecondaryButton(
          label: 'Refresh session',
          onPressed: () => ctrl.hydrateSession(widget.sessionId),
        ),
        const SizedBox(height: AuraSpace.s4),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PANEL HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    this.count,
    this.onClose,
  });

  final String title;
  final int? count;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AuraSurface.divider)),
      ),
      child: Row(
        children: [
          // Drag handle for bottom sheets (centered when no close button)
          if (onClose == null)
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AuraSurface.faint,
                  borderRadius: BorderRadius.circular(AuraRadius.pill),
                ),
              ),
            )
          else ...[
            Text(
              title,
              style: AuraText.subtitle.copyWith(fontWeight: FontWeight.w700),
            ),
            if (count != null) ...[
              const SizedBox(width: AuraSpace.s8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AuraSurface.accentSoft,
                  borderRadius: BorderRadius.circular(AuraRadius.pill),
                ),
                child: Text(
                  '$count',
                  style: AuraText.micro.copyWith(
                    color: AuraSurface.accentText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: AuraIconSize.md),
              onPressed: onClose,
              color: AuraSurface.muted,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INVITE CARD (moderator only, inside More panel)
// ─────────────────────────────────────────────────────────────────────────────

class _RoomInviteCard extends StatelessWidget {
  const _RoomInviteCard({
    required this.searchController,
    required this.noteController,
    required this.isSearching,
    required this.results,
    required this.invitingUserId,
    required this.onSearchChanged,
    required this.onInvite,
  });

  final TextEditingController searchController;
  final TextEditingController noteController;
  final bool isSearching;
  final List<Map<String, dynamic>> results;
  final String? invitingUserId;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Map<String, dynamic>> onInvite;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Invite members', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          const Text(
            'Find Aura members and invite them into this call.',
            style: AuraText.muted,
          ),
          const SizedBox(height: AuraSpace.s12),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              labelText: 'Search members',
              hintText: 'Name, handle, or bio',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: AuraSpace.s10),
          TextField(
            controller: noteController,
            decoration: const InputDecoration(
              labelText: 'Optional note',
              hintText: 'Add context for the invite',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            minLines: 1,
            maxLines: 2,
          ),
          const SizedBox(height: AuraSpace.s12),
          if (isSearching)
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AuraSurface.accent,
                ),
              ),
            )
          else if (searchController.text.trim().isEmpty)
            const Text('Search to invite people.', style: AuraText.small)
          else if (results.isEmpty)
            const Text('No matching members found.', style: AuraText.small)
          else
            ...results.map((user) {
              final id = (user['id'] ?? '').toString();
              final displayName =
                  (user['displayName'] ?? '').toString().trim();
              final handle = (user['handle'] ?? '').toString().trim();
              final bio = (user['bio'] ?? '').toString().trim();
              final title = displayName.isNotEmpty
                  ? displayName
                  : handle.isNotEmpty
                      ? '@$handle'
                      : 'Member';
              final subtitle = [
                if (handle.isNotEmpty && displayName.isNotEmpty) '@$handle',
                if (bio.isNotEmpty) bio,
              ].join(' • ');
              final isInviting = invitingUserId == id;

              return Padding(
                padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AuraText.body.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: AuraSpace.s4),
                            Text(subtitle, style: AuraText.small),
                          ],
                        ],
                      ),
                    ),
                    AuraPrimaryButton(
                      label: isInviting ? 'Inviting…' : 'Invite',
                      onPressed: isInviting ? null : () => onInvite(user),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ARTIFACT BLOCK (inside More panel)
// ─────────────────────────────────────────────────────────────────────────────

class _ArtifactBlock extends StatelessWidget {
  const _ArtifactBlock({
    required this.policy,
    required this.recordingCount,
    required this.transcriptCount,
    required this.artifactCount,
  });

  final RealtimePolicy? policy;
  final int recordingCount;
  final int transcriptCount;
  final int artifactCount;

  @override
  Widget build(BuildContext context) {
    final canRecord = policy?.canRecord == true;
    final canTranscribe = policy?.canTranscribe == true;

    // Show nothing if no capabilities and no data yet
    if (!canRecord && !canTranscribe && recordingCount == 0 && transcriptCount == 0 && artifactCount == 0) {
      return const SizedBox.shrink();
    }

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Call output',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s8),
          if (canRecord || recordingCount > 0)
            Text(
              recordingCount > 0
                  ? (recordingCount == 1
                      ? '1 recording'
                      : '$recordingCount recordings')
                  : 'Recording available',
              style: AuraText.small,
            ),
          if (canTranscribe || transcriptCount > 0)
            Text(
              transcriptCount > 0
                  ? (transcriptCount == 1 ? '1 live note' : '$transcriptCount live notes')
                  : 'Live notes available',
              style: AuraText.small,
            ),
          if (artifactCount > 0)
            Text(
              artifactCount == 1
                  ? '1 saved artifact'
                  : '$artifactCount saved artifacts',
              style: AuraText.small,
            ),
        ],
      ),
    );
  }
}
