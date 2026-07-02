import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_space.dart';
import '../application/meetings_provider.dart';
import '../domain/meeting.dart';
import '../../realtime/application/realtime_controller.dart';
import '../../realtime/application/realtime_providers.dart';
import '../../realtime/data/realtime_media_service.dart';
import '../../realtime/domain/realtime_enums.dart';
import '../../realtime/domain/realtime_models.dart';
import '../../realtime/domain/realtime_state.dart';

// E1 — MeetingTransportBridge: sole interface between meeting UI and WebRTC layer.
// All mic/camera/screen operations from meeting widgets MUST go through this bridge.
// Direct calls to RealtimeController or RealtimeMediaService from meeting widgets
// are forbidden — the bridge is the seam that allows Phase I to swap transport.
class MeetingTransportBridge {
  MeetingTransportBridge({
    required this.sessionId,
    required this.meetingId,
    required RealtimeMediaService mediaService,
    required RealtimeController controller,
  })  : _mediaService = mediaService,
        _controller = controller;

  final String sessionId;
  final String meetingId;
  final RealtimeMediaService _mediaService;
  final RealtimeController _controller;

  Stream<RealtimeMediaSnapshot> get mediaStream => _mediaService.snapshots;

  void muteLocalMic() => _controller.toggleMicrophone();
  void unmuteLocalMic() => _controller.toggleMicrophone();
  void disableLocalCamera() => _controller.toggleCamera();
  void enableLocalCamera() => _controller.toggleCamera();

  // I1: Screen sharing as Aura Meeting capability.
  Future<void> startScreenShare() => _controller.startScreenShare();
  Future<void> stopScreenShare() => _controller.stopScreenShare();

  // I4: Camera flip as Aura Meeting capability.
  Future<void> flipCamera() => _controller.flipCamera();

  // I3: Participant removal as Aura Meeting capability (host only).
  Future<void> removeParticipantFromMeeting(String userId) =>
      _controller.removeParticipant(userId);
}

// E2 — MeetingLiveRoomScreen: meeting-branded live room at /meetings/:id/live
class MeetingLiveRoomScreen extends ConsumerStatefulWidget {
  final String meetingId;
  final String sessionId;
  final String? institutionId;
  final bool isHost;
  // meetingCode allows guest sessions to fetch meeting metadata via the
  // public endpoint when the member endpoint is inaccessible for the token.
  final String? meetingCode;
  // guestUserId is the GuestSession.id — passed through URL params from
  // pre_join_screen so guests have a stable local identity without /auth/me.
  final String? guestUserId;

  const MeetingLiveRoomScreen({
    super.key,
    required this.meetingId,
    required this.sessionId,
    this.institutionId,
    this.isHost = false,
    this.meetingCode,
    this.guestUserId,
  });

  @override
  ConsumerState<MeetingLiveRoomScreen> createState() =>
      _MeetingLiveRoomScreenState();
}

class _MeetingLiveRoomScreenState extends ConsumerState<MeetingLiveRoomScreen> {
  bool _intentToLeave = false;
  bool _endingMeeting = false;
  bool _showParticipants = false;
  bool _showNotes = false;
  bool _meetingEnded = false;
  bool _togglingScreenShare = false;
  // L3c: auto-hide control bar
  bool _controlsVisible = true;
  Timer? _controlBarTimer;
  // L2: arrival/departure toast
  String? _arrivalToast;
  Timer? _arrivalTimer;
  late final DateTime _joinedAt;
  late final MeetingTransportBridge _bridge;

  void _scheduleControlBarHide() {
    _controlBarTimer?.cancel();
    _controlBarTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _onUserInteraction() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleControlBarHide();
  }

  void _showArrivalToast(String message) {
    _arrivalTimer?.cancel();
    setState(() => _arrivalToast = message);
    _arrivalTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _arrivalToast = null);
    });
  }

  @override
  void initState() {
    super.initState();
    // Keep the mobile device screen awake for the whole live session — a video
    // call must not let the phone dim/sleep while the user is in the room.
    WakelockPlus.enable();
    _joinedAt = DateTime.now();
    _bridge = MeetingTransportBridge(
      sessionId: widget.sessionId,
      meetingId: widget.meetingId,
      mediaService: ref.read(realtimeMediaServiceProvider),
      controller: ref.read(realtimeControllerProvider.notifier),
    );
    // Production-visible sync diagnostic: compare across host/guest consoles to
    // confirm SAME meetingId + sessionId. A mismatch means each side is in a
    // different realtime room and can never see the other.
    debugPrint(
      '[meeting-live] mounted meetingId=${widget.meetingId}'
      ' sessionId=${widget.sessionId} isHost=${widget.isHost}'
      ' guestId=${(widget.guestUserId ?? '').trim()} code=${(widget.meetingCode ?? '').trim()}',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      ref.read(realtimeControllerProvider.notifier).setCallRoomVisible(true);
      await _ensureGuestAuthAndJoin();
      _scheduleControlBarHide();
    });
  }

  // Establish (or refresh) the guest session before joining the realtime room.
  // Also used by the connecting-overlay Retry: a transient guest-auth failure
  // (e.g. token cleared on web reload) is recoverable only if we re-exchange
  // before re-joining — a bare re-join would fail identically.
  Future<void> _ensureGuestAuthAndJoin() async {
    if (!mounted) return;
    final guestId = (widget.guestUserId ?? '').trim();
    if (guestId.isNotEmpty) {
      final tokenStore = ref.read(tokenStoreProvider);
      if (!tokenStore.isAuthed) {
        try {
          final repo = ref.read(meetingsRepositoryProvider);
          final guestAuth = await repo.exchangeGuestAuth(guestId);
          if (guestAuth.accessToken.trim().isNotEmpty) {
            await tokenStore.setSession(accessToken: guestAuth.accessToken);
          }
        } catch (_) {}
      }
    }
    if (!mounted) return;
    ref.read(realtimeControllerProvider.notifier).join(widget.sessionId);
  }

  @override
  void dispose() {
    // Release the wake lock when leaving the live room.
    WakelockPlus.disable();
    _controlBarTimer?.cancel();
    _arrivalTimer?.cancel();
    ref
        .read(realtimeControllerProvider.notifier)
        .setCallRoomVisible(false);
    if (_intentToLeave) {
      ref.read(realtimeControllerProvider.notifier).leave();
    }
    super.dispose();
  }

  String get _summaryPath => widget.institutionId == null
      ? '/meetings/${widget.meetingId}/summary'
      : '/institution/${widget.institutionId}/meetings/${widget.meetingId}/summary';

  Future<void> _endMeeting() async {
    if (_endingMeeting) return;
    setState(() => _endingMeeting = true);
    _intentToLeave = true;
    try {
      await ref
          .read(meetingsRepositoryProvider)
          .endMeeting(widget.meetingId);
      await ref.read(realtimeControllerProvider.notifier).endCall();
      if (!mounted) return;
      context.go(_summaryPath);
    } catch (e) {
      _intentToLeave = false;
      if (!mounted) return;
      setState(() => _endingMeeting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to end meeting. Try again or leave the room.')),
      );
    }
  }

  Future<void> _toggleScreenShare() async {
    if (_togglingScreenShare) return;
    setState(() => _togglingScreenShare = true);
    try {
      final sharing = ref.read(realtimeControllerProvider).isScreenSharing;
      if (sharing) {
        await _bridge.stopScreenShare();
      } else {
        await _bridge.startScreenShare();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to start screen share. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _togglingScreenShare = false);
    }
  }

  Future<void> _flipCamera() => _bridge.flipCamera();

  Future<void> _leaveMeeting() async {
    _intentToLeave = true;
    await ref.read(realtimeControllerProvider.notifier).leave();
    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(realtimeControllerProvider);
    // Provider priority for meeting metadata:
    // 1. meetingProvider   — member JWT; succeeds for host/member sessions.
    // 2. meetingByCodeProvider — public endpoint; used when ?code= is present (normal guest flow).
    // 3. guestMeetingContextProvider — guest JWT endpoint; fallback for cold-launch
    //    deep-links that reach the live room without a ?code= param. Only activated
    //    when the member endpoint fails AND no code was supplied.
    final meetingAsync = ref.watch(meetingProvider(widget.meetingId));
    final codeAsync = (widget.meetingCode?.trim().isNotEmpty == true)
        ? ref.watch(meetingByCodeProvider(widget.meetingCode!.trim()))
        : null;
    final contextAsync = (codeAsync == null && meetingAsync.hasError)
        ? ref.watch(guestMeetingContextProvider(widget.meetingId))
        : null;
    final meeting = meetingAsync.valueOrNull ?? codeAsync?.valueOrNull ?? contextAsync?.valueOrNull;

    // I3: local user ID for host participant controls.
    // /auth/me returns { user: { id: ... }, accountType, emailVerified } — read
    // the nested user.id, not the top-level id which does not exist in this envelope.
    // For guests (token rejected by /auth/me) fall back to widget.guestUserId which
    // is the GuestSession.id threaded through URL params from pre_join_screen.
    final meAsync = ref.watch(authMeDataProvider);
    final myUserId = meAsync.maybeWhen(
      data: (me) {
        final userMap = me['user'];
        final id = userMap is Map ? (userMap['id'] ?? me['id'] ?? '') : (me['id'] ?? '');
        final resolved = id.toString().trim();
        return resolved.isNotEmpty ? resolved : (widget.guestUserId ?? '');
      },
      orElse: () => widget.guestUserId ?? '',
    );

    // I2: Distinguish host-ended meeting from network drop.
    // session:ended / call:terminal = host ended → show ended overlay.
    // socket:disconnected = network drop → auto-reconnect, keep meeting UI.
    ref.listen(
      realtimeControllerProvider.select((s) => s.lastSocketEvent),
      (prev, next) {
        if (next == null || _intentToLeave || _endingMeeting || _meetingEnded) return;
        if (next == 'session:ended' || next == 'call:terminal') {
          setState(() => _meetingEnded = true);
        } else if (next == 'socket:disconnected') {
          Future.microtask(() {
            if (mounted && !_intentToLeave && !_meetingEnded) {
              ref
                  .read(realtimeControllerProvider.notifier)
                  .join(widget.sessionId);
            }
          });
        }
      },
    );

    // L2: participant arrival/departure toasts
    ref.listen(
      realtimeControllerProvider.select((s) => s.participants),
      (prev, next) {
        final prevList = prev ?? const <RealtimeParticipant>[];
        // Production-visible roster diagnostic: confirms whether the other
        // party's participant.joined actually reached this side.
        debugPrint(
          '[meeting-live] roster sessionId=${widget.sessionId}'
          ' isHost=${widget.isHost} count=${next.length}'
          ' ids=${next.map((p) => '${p.userId}/${(p.displayName ?? '').trim()}').join(',')}',
        );
        if (next.length > prevList.length) {
          final added = next.where(
            (p) => !prevList.any((q) => q.userId == p.userId),
          );
          final name = (added.firstOrNull?.displayName ?? '').trim();
          _showArrivalToast(
            name.isNotEmpty ? '$name has joined' : 'Someone has joined',
          );
        } else if (next.length < prevList.length && next.isNotEmpty) {
          _showArrivalToast('A participant has left');
        }
      },
    );

    final remoteRenderers = state.remoteRenderers;
    final localRenderer = state.localRenderer;

    // I1: Find which peer is currently screen sharing, for video grid promotion.
    final screenSharingPeerId = state.participants
        .where((p) => p.screenOn)
        .map((p) => p.runtimeDeviceId)
        .whereType<String>()
        .firstOrNull;

    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _onUserInteraction,
        onPanUpdate: (_) => _onUserInteraction(),
        child: Stack(
        children: [
          // E3 — Video grid fills the screen
          Positioned.fill(
            child: _MeetingVideoGrid(
              localRenderer: localRenderer,
              remoteRenderers: remoteRenderers,
              micOn: state.microphoneEnabled,
              isLocalScreenSharing: state.isScreenSharing,
              screenSharingPeerId: screenSharingPeerId,
              participants: state.participants,
              localUserId: myUserId,
              isHost: widget.isHost,
            ),
          ),

          // ── TEMPORARY RTC DEBUG BADGE (video track/render diagnosis) ──
          Positioned(
            top: 72,
            left: 8,
            child: _RtcDebugBadge(
              mediaService: ref.read(realtimeMediaServiceProvider),
              participants: state.participants,
              meSocket: ref.read(realtimeSocketServiceProvider).socketId ?? '',
              isJoined: state.isJoined,
              isMediaReady: state.isMediaReady,
            ),
          ),

          // Camera-busy banner: shown when video capture failed but audio
          // succeeded (e.g. host + guest sharing one physical camera on the
          // same laptop — the second browser can't open it). We join audio-only
          // instead of silently publishing nothing.
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: _CameraUnavailableBanner(
              mediaService: ref.read(realtimeMediaServiceProvider),
            ),
          ),

          // E2 — Meeting-branded header with institution + elapsed timer
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _MeetingLiveHeader(
              meeting: meeting,
              joinedAt: _joinedAt,
            ),
          ),

          // E5 — Participant panel (right sidebar)
          if (_showParticipants)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              child: _MeetingParticipantPanel(
                participants: state.participants,
                isHost: widget.isHost,
                localUserId: myUserId,
                onClose: () => setState(() => _showParticipants = false),
                onRemoveParticipant: widget.isHost
                    ? (userId) => _bridge.removeParticipantFromMeeting(userId)
                    : null,
              ),
            ),

          // E6 — Notes drawer (right panel)
          if (_showNotes)
            Positioned(
              top: 0,
              right: _showParticipants ? 300 : 0,
              bottom: 0,
              child: _MeetingNotesDrawer(
                meetingId: widget.meetingId,
                initialNotes: meeting?.preparationNotes,
                onClose: () => setState(() => _showNotes = false),
              ),
            ),

          // I2: Connecting / reconnecting overlay (initial join and auto-reconnect).
          if (!state.isJoined && !_meetingEnded)
            Positioned.fill(
              child: _ConnectingOverlay(
                state: state,
                onRetry: _ensureGuestAuthAndJoin,
              ),
            ),

          // E9 — Meeting ended overlay (guest path)
          if (_meetingEnded)
            Positioned.fill(
              child: _MeetingEndedOverlay(
                onViewSummary: () => context.go(_summaryPath),
                onLeave: () {
                  _intentToLeave = true;
                  context.pop();
                },
              ),
            ),

          // L2: arrival/departure toast
          if (_arrivalToast != null)
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _arrivalToast != null ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xCC0F172A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Text(
                      _arrivalToast ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // E4 — Control bar at bottom. All media ops route through _bridge.
          // L3c: auto-hides after 4s of inactivity; reappears on any interaction.
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: _MeetingControlBar(
              state: state,
              isHost: widget.isHost,
              showParticipants: _showParticipants,
              showNotes: _showNotes,
              endingMeeting: _endingMeeting,
              togglingScreenShare: _togglingScreenShare,
              onToggleMic: state.microphoneEnabled
                  ? _bridge.muteLocalMic
                  : _bridge.unmuteLocalMic,
              onToggleCamera: state.cameraEnabled
                  ? _bridge.disableLocalCamera
                  : _bridge.enableLocalCamera,
              onToggleParticipants: () =>
                  setState(() => _showParticipants = !_showParticipants),
              onToggleNotes: () =>
                  setState(() => _showNotes = !_showNotes),
              onShareScreen: _toggleScreenShare,
              onFlipCamera: _flipCamera,
              onEndMeeting: _endMeeting,
              onLeaveMeeting: _leaveMeeting,
            ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// E3 — Video grid: spotlight (1 remote) or grid (2+)
// ---------------------------------------------------------------------------

// Banner shown when the local camera couldn't be opened (busy in another
// app/browser) but audio succeeded — the call continues audio-only.
class _CameraUnavailableBanner extends StatelessWidget {
  const _CameraUnavailableBanner({required this.mediaService});

  final RealtimeMediaService mediaService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RealtimeMediaSnapshot>(
      stream: mediaService.snapshots,
      initialData: mediaService.currentSnapshot,
      builder: (context, snap) {
        final s = snap.data ?? mediaService.currentSnapshot;
        if (!s.cameraUnavailable) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF7C2D12).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFF59E0B), width: 1),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off, color: Color(0xFFFDE68A), size: 18),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Camera unavailable in this browser. Another browser or app '
                  'may be using it — you joined with audio only.',
                  style: TextStyle(
                    color: Color(0xFFFDE68A),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── TEMPORARY on-screen RTC debug badge ──────────────────────────────────
// Surfaces the video track/render truth so we stop guessing: what tracks we
// sent to the peer, whether we received the remote audio/video tracks, how many
// remote renderers exist, and whether their keys map to roster participants.
class _RtcDebugBadge extends StatelessWidget {
  const _RtcDebugBadge({
    required this.mediaService,
    required this.participants,
    required this.meSocket,
    required this.isJoined,
    required this.isMediaReady,
  });

  final RealtimeMediaService mediaService;
  final List<RealtimeParticipant> participants;
  final String meSocket;
  final bool isJoined;
  final bool isMediaReady;

  String _short(String k) => k.length > 6 ? k.substring(0, 6) : k;
  String _raw(String s) => s.startsWith('socket:') ? s.substring(7) : s;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: StreamBuilder<RealtimeMediaSnapshot>(
        stream: mediaService.snapshots,
        initialData: mediaService.currentSnapshot,
        builder: (context, snap) {
          final s = snap.data ?? mediaService.currentSnapshot;
          final rKeys = s.remoteRenderers.keys.toList();
          final partIds = participants
              .map((p) => (p.runtimeDeviceId ?? '').trim())
              .where((x) => x.isNotEmpty)
              .toList();
          final mapped = rKeys.where(partIds.contains).length;
          final myRaw = _raw(meSocket);
          // For each peer, 'I' if I'm the deterministic initiator (higher raw
          // socket) so I should be offering; 'w' if I should wait for theirs.
          final initFlags = partIds
              .map((p) => myRaw.compareTo(_raw(p)) > 0 ? 'I' : 'w')
              .join(',');
          final lines = <String>[
            'RTC DEBUG me=${_short(meSocket)} join=$isJoined mediaRdy=$isMediaReady',
            'sent=${s.sentTrackKinds} localVid=${s.localVideoTrackPresent} cam=${s.cameraEnabled} camBusy=${s.cameraUnavailable}',
            'onTrack A=${s.onTrackAudioSeen} V=${s.onTrackVideoSeen}',
            'remoteRenderers=${rKeys.length} remoteVid=${s.remoteVideoRendererAttached}',
            'peers=${partIds.map(_short).toList()} initiator=[$initFlags]',
            'rKeys=${rKeys.map(_short).toList()} mapped=$mapped/${rKeys.length}',
          ];
          return Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final l in lines)
                  Text(
                    l,
                    style: const TextStyle(
                      color: Color(0xFF6EE7B7),
                      fontSize: 10,
                      fontFamily: 'monospace',
                      height: 1.3,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MeetingVideoGrid extends StatelessWidget {
  final RTCVideoRenderer? localRenderer;
  final Map<String, RTCVideoRenderer> remoteRenderers;
  final bool micOn;
  final bool isLocalScreenSharing;
  final String? screenSharingPeerId;
  final List<RealtimeParticipant> participants;
  final String localUserId;
  final bool isHost;

  const _MeetingVideoGrid({
    required this.localRenderer,
    required this.remoteRenderers,
    required this.micOn,
    required this.isLocalScreenSharing,
    required this.participants,
    required this.localUserId,
    required this.isHost,
    this.screenSharingPeerId,
  });

  RealtimeParticipant? _participantForKey(String key) {
    for (final p in participants) {
      if ((p.runtimeDeviceId ?? '') == key) return p;
    }
    return null;
  }

  Widget _buildRemoteTile(String key, RTCVideoRenderer renderer) {
    final p = _participantForKey(key);
    final videoOn = p?.videoOn ?? true;
    if (videoOn) {
      return RTCVideoView(
        renderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    }
    final name = (p?.displayName ?? '').trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return ColoredBox(
      color: const Color(0xFF1E293B),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.25),
              backgroundImage: p?.avatarUrl?.trim().isNotEmpty == true
                  ? NetworkImage(p!.avatarUrl!)
                  : null,
              child: p?.avatarUrl?.trim().isNotEmpty == true
                  ? null
                  : Text(
                      initial,
                      style: const TextStyle(
                        color: Color(0xFFE5E7EB),
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            if (name.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                name,
                style: const TextStyle(
                  color: Color(0xFFCBD5E1),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 4),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam_off_rounded,
                    size: 14, color: Color(0xFF6B7280)),
                SizedBox(width: 4),
                Text(
                  'Camera off',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remoteEntries = remoteRenderers.entries.toList();

    // I1: Remote screen share — promote that participant to spotlight.
    if (screenSharingPeerId != null) {
      final screenRenderer = remoteRenderers[screenSharingPeerId];
      if (screenRenderer != null) {
        return _buildSpotlightLayout(
            screenSharingPeerId!, screenRenderer, localRenderer);
      }
    }

    if (remoteEntries.isEmpty) {
      // A remote participant may be in the roster but its media renderer hasn't
      // arrived yet. In that case show a CONNECTING avatar — never the local
      // camera in the main slot (that was the "each side sees its own video"
      // bug). Local stays a PiP. Only when we're genuinely alone do we show the
      // local-preview "waiting" layout.
      final remotes = participants
          .where((p) =>
              p.userId.trim().isNotEmpty &&
              p.userId.trim() != localUserId.trim())
          .toList();
      if (remotes.isNotEmpty) {
        return _buildConnectingLayout(remotes.first, localRenderer);
      }
      return _buildWaitingLayout(localRenderer, isLocalScreenSharing);
    }

    if (remoteEntries.length == 1) {
      final entry = remoteEntries.first;
      return _buildSpotlightLayout(entry.key, entry.value, localRenderer);
    }

    // Grid: up to 4 participants in 2×2
    return _buildGridLayout(remoteEntries, localRenderer);
  }

  /// Remote participant present but no remote renderer yet. Shows an avatar +
  /// "Connecting…" as the MAIN view with the local camera as a PiP — never the
  /// local camera masquerading as the remote tile.
  Widget _buildConnectingLayout(
    RealtimeParticipant remote,
    RTCVideoRenderer? local,
  ) {
    final name = (remote.displayName ?? '').trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Color(0xFF0B1120))),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.25),
                backgroundImage: remote.avatarUrl?.trim().isNotEmpty == true
                    ? NetworkImage(remote.avatarUrl!)
                    : null,
                child: remote.avatarUrl?.trim().isNotEmpty == true
                    ? null
                    : Text(
                        initial,
                        style: const TextStyle(
                          color: Color(0xFFE5E7EB),
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(height: 14),
              Text(
                name.isNotEmpty ? 'Connecting to $name…' : 'Connecting…',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (local != null)
          Positioned(
            right: 12,
            bottom: 130,
            width: 100,
            height: 140,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: RTCVideoView(
                local,
                mirror: true,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWaitingLayout(RTCVideoRenderer? local, bool isScreenSharing) {
    return Stack(
      children: [
        // Local camera fills the full background when available.
        if (local != null)
          Positioned.fill(
            child: RTCVideoView(
              local,
              mirror: true,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          )
        else
          const Positioned.fill(
            child: ColoredBox(color: Color(0xFF030712)),
          ),

        // Dark gradient overlay — lets text sit above the camera feed.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF030712).withValues(alpha: 0.55),
                  Colors.transparent,
                  Colors.transparent,
                  const Color(0xFF030712).withValues(alpha: 0.70),
                ],
                stops: const [0.0, 0.25, 0.65, 1.0],
              ),
            ),
          ),
        ),

        // Centre presence card — shows host is live and ready.
        if (!isScreenSharing)
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF030712).withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _PulsingReadyDot(),
                  const SizedBox(height: 12),
                  const Text(
                    'You\'re ready',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _waitingLabel(participants, localUserId, isHost),
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Screen-share badge.
        if (isScreenSharing)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.screen_share_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Sharing your screen',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
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

  Widget _buildSpotlightLayout(
    String remoteKey,
    RTCVideoRenderer remote,
    RTCVideoRenderer? local,
  ) {
    return Stack(
      children: [
        Positioned.fill(
          child: _buildRemoteTile(remoteKey, remote),
        ),
        if (local != null)
          Positioned(
            right: 12,
            bottom: 130,
            width: 100,
            height: 140,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: RTCVideoView(
                local,
                mirror: true,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGridLayout(
    List<MapEntry<String, RTCVideoRenderer>> remoteEntries,
    RTCVideoRenderer? local,
  ) {
    final tiles = <Widget>[
      ...remoteEntries.take(3).map((e) => _buildRemoteTile(e.key, e.value)),
    ];
    if (local != null && tiles.length < 4) {
      tiles.add(RTCVideoView(
        local,
        mirror: true,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      ));
    }

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 4 / 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: tiles.length,
      itemBuilder: (context, index) => tiles[index],
    );
  }

  static String _waitingLabel(
    List<RealtimeParticipant> participants,
    String localUserId,
    bool isHost,
  ) {
    // Filter out the local participant — we're waiting for *others*, not ourselves.
    final others = localUserId.isEmpty
        ? participants
        : participants.where((p) => p.userId != localUserId).toList();
    // Role-aware alone state: a host waits for guests, a guest waits for the
    // host. Never tell the guest "waiting for guest" when the guest is the one
    // present. (This layout only renders when there is no remote media yet, so
    // "both connected" already shows video instead of any waiting copy.)
    if (others.isEmpty) {
      return isHost
          ? 'Waiting for guests to join…'
          : 'Waiting for the host to join…';
    }
    final names = others
        .map((p) => (p.displayName ?? '').trim())
        .where((n) => n.isNotEmpty)
        .toList();
    if (names.isEmpty) {
      return isHost
          ? 'Waiting for guests to join…'
          : 'Waiting for the host to join…';
    }
    if (names.length == 1) return 'Waiting for ${names[0]} to join…';
    if (names.length == 2) return 'Waiting for ${names[0]} and ${names[1]}…';
    return 'Waiting for ${names[0]} and ${names.length - 1} others…';
  }
}

// ---------------------------------------------------------------------------
// E2 — Header: institution identity + meeting title + elapsed timer
// ---------------------------------------------------------------------------

class _MeetingLiveHeader extends StatelessWidget {
  final Meeting? meeting;
  final DateTime joinedAt;

  const _MeetingLiveHeader({required this.meeting, required this.joinedAt});

  @override
  Widget build(BuildContext context) {
    final institution = meeting?.booking?.institution;
    final title = meeting?.title ?? '';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xDD030712), Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (institution != null) ...[
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF1E293B),
              backgroundImage: institution.logoUrl?.trim().isNotEmpty == true
                  ? NetworkImage(institution.logoUrl!)
                  : null,
              child: institution.logoUrl?.trim().isNotEmpty == true
                  ? null
                  : const Icon(
                      Icons.business_rounded,
                      size: 18,
                      color: Color(0xFF9CA3AF),
                    ),
            ),
            const SizedBox(width: AuraSpace.s10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (institution != null)
                  Text(
                    institution.name,
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AuraSpace.s8),
          _ElapsedTimer(joinedAt: joinedAt),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pulsing "ready" indicator shown in the host-alone waiting state.
// ---------------------------------------------------------------------------

class _PulsingReadyDot extends StatefulWidget {
  const _PulsingReadyDot();

  @override
  State<_PulsingReadyDot> createState() => _PulsingReadyDotState();
}

class _PulsingReadyDotState extends State<_PulsingReadyDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _opacity = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Opacity(
          opacity: _opacity.value,
          child: Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _ElapsedTimer extends StatefulWidget {
  final DateTime joinedAt;

  const _ElapsedTimer({required this.joinedAt});

  @override
  State<_ElapsedTimer> createState() => _ElapsedTimerState();
}

class _ElapsedTimerState extends State<_ElapsedTimer> {
  late Timer _timer;
  late Duration _elapsed;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.joinedAt);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed = DateTime.now().difference(widget.joinedAt);
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = _elapsed.inHours;
    final m = _elapsed.inMinutes.remainder(60);
    final s = _elapsed.inSeconds.remainder(60);
    final label = h > 0
        ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF9CA3AF),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// E4 — Control bar: meeting vocabulary, no "call" language
// ---------------------------------------------------------------------------

class _MeetingControlBar extends StatelessWidget {
  final RealtimeState state;
  final bool isHost;
  final bool showParticipants;
  final bool showNotes;
  final bool endingMeeting;
  final bool togglingScreenShare;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleParticipants;
  final VoidCallback onToggleNotes;
  final VoidCallback onShareScreen;
  final VoidCallback onFlipCamera;
  final VoidCallback onEndMeeting;
  final VoidCallback onLeaveMeeting;

  const _MeetingControlBar({
    required this.state,
    required this.isHost,
    required this.showParticipants,
    required this.showNotes,
    required this.endingMeeting,
    required this.togglingScreenShare,
    required this.onToggleMic,
    required this.onToggleCamera,
    required this.onToggleParticipants,
    required this.onToggleNotes,
    required this.onShareScreen,
    required this.onFlipCamera,
    required this.onEndMeeting,
    required this.onLeaveMeeting,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xEE030712), Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: AuraSpace.s10,
        runSpacing: AuraSpace.s10,
        children: [
          // Mute / Unmute
          _ControlButton(
            icon: state.microphoneEnabled
                ? Icons.mic_rounded
                : Icons.mic_off_rounded,
            label: state.microphoneEnabled ? 'Mute' : 'Unmute',
            active: state.microphoneEnabled,
            onTap: onToggleMic,
          ),

          // Hide / Show camera
          _ControlButton(
            icon: state.cameraEnabled
                ? Icons.videocam_rounded
                : Icons.videocam_off_rounded,
            label: state.cameraEnabled ? 'Hide camera' : 'Show camera',
            active: state.cameraEnabled,
            onTap: onToggleCamera,
          ),

          // Participants
          _ControlButton(
            icon: Icons.people_rounded,
            label: 'Participants',
            active: showParticipants,
            onTap: onToggleParticipants,
          ),

          // Notes
          _ControlButton(
            icon: Icons.notes_rounded,
            label: 'Notes',
            active: showNotes,
            onTap: onToggleNotes,
          ),

          // I1: Share screen — active when broadcasting.
          _ControlButton(
            icon: state.isScreenSharing
                ? Icons.stop_screen_share_rounded
                : Icons.screen_share_rounded,
            label: state.isScreenSharing ? 'Stop sharing' : 'Share screen',
            active: state.isScreenSharing,
            onTap: togglingScreenShare ? null : onShareScreen,
          ),

          // I4: Flip camera — visible when camera is enabled and in video mode.
          if (state.isVideoMode && state.cameraEnabled)
            _ControlButton(
              icon: Icons.flip_camera_ios_rounded,
              label: 'Flip camera',
              active: false,
              onTap: onFlipCamera,
            ),

          // End / Leave
          if (isHost)
            _ControlButton(
              icon: Icons.stop_rounded,
              label: endingMeeting ? 'Ending...' : 'End meeting',
              active: false,
              danger: true,
              onTap: endingMeeting ? null : onEndMeeting,
            )
          else
            _ControlButton(
              icon: Icons.logout_rounded,
              label: 'Leave meeting',
              active: false,
              danger: true,
              onTap: onLeaveMeeting,
            ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool danger;
  final VoidCallback? onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.active,
    this.danger = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? const Color(0xFFDC2626)
        : active
            ? const Color(0xFF1E293B)
            : const Color(0xFF0F172A);
    final fg = danger ? Colors.white : const Color(0xFFE5E7EB);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: onTap == null ? bg.withValues(alpha: 0.5) : bg,
              borderRadius: BorderRadius.circular(12),
              border: active && !danger
                  ? Border.all(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.5),
                    )
                  : null,
            ),
            child: Icon(icon, color: fg, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: danger ? const Color(0xFFFCA5A5) : const Color(0xFF9CA3AF),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// E5 — Participant panel
// ---------------------------------------------------------------------------

class _MeetingParticipantPanel extends StatelessWidget {
  final List<RealtimeParticipant> participants;
  final bool isHost;
  final String localUserId;
  final VoidCallback onClose;
  final void Function(String userId)? onRemoveParticipant;

  const _MeetingParticipantPanel({
    required this.participants,
    required this.isHost,
    required this.localUserId,
    required this.onClose,
    this.onRemoveParticipant,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 48, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Participants',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF9CA3AF)),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF1E293B), height: 1),
          Expanded(
            child: participants.isEmpty
                ? const Center(
                    child: Text(
                      'No participants yet',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    itemCount: participants.length,
                    itemBuilder: (context, index) {
                      final p = participants[index];
                      final isMe = localUserId.isNotEmpty &&
                          p.userId == localUserId;
                      return _ParticipantRow(
                        participant: p,
                        isHost: isHost,
                        isMe: isMe,
                        onRemove: (isHost && !isMe && onRemoveParticipant != null)
                            ? () => onRemoveParticipant!(p.userId)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  final RealtimeParticipant participant;
  final bool isHost;
  final bool isMe;
  final VoidCallback? onRemove;

  const _ParticipantRow({
    required this.participant,
    required this.isHost,
    required this.isMe,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s16,
        vertical: AuraSpace.s8,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF1E293B),
            backgroundImage: participant.avatarUrl?.trim().isNotEmpty == true
                ? NetworkImage(participant.avatarUrl!)
                : null,
            child: participant.avatarUrl?.trim().isNotEmpty == true
                ? null
                : Text(
                    (participant.displayName ?? '').trim().isEmpty
                        ? '?'
                        : (participant.displayName ?? '').trim()[0].toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFE5E7EB),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (participant.displayName ?? '').trim().isEmpty
                      ? 'Guest'
                      : (participant.displayName ?? '').trim(),
                  style: const TextStyle(
                    color: Color(0xFFE5E7EB),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if ((participant.displayRole ?? '').trim().isNotEmpty)
                  Text(
                    (participant.displayRole ?? '').trim(),
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AuraSpace.s6),
          Icon(
            participant.audioOn ? Icons.mic_rounded : Icons.mic_off_rounded,
            size: 16,
            color: participant.audioOn
                ? const Color(0xFF6B7280)
                : const Color(0xFFEF4444),
          ),
          const SizedBox(width: AuraSpace.s4),
          Icon(
            participant.videoOn
                ? Icons.videocam_rounded
                : Icons.videocam_off_rounded,
            size: 16,
            color: participant.videoOn
                ? const Color(0xFF6B7280)
                : const Color(0xFFEF4444),
          ),
          // I1: Screen sharing indicator
          if (participant.screenOn) ...[
            const SizedBox(width: AuraSpace.s4),
            const Icon(
              Icons.screen_share_rounded,
              size: 16,
              color: Color(0xFF6C63FF),
            ),
          ],
          // I3: Host remove button (not shown for self)
          if (onRemove != null) ...[
            const SizedBox(width: AuraSpace.s4),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(
                Icons.person_remove_rounded,
                size: 16,
                color: Color(0xFFEF4444),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// E6 — Notes drawer: saves to preparationNotes via updateMeeting()
// ---------------------------------------------------------------------------

class _MeetingNotesDrawer extends ConsumerStatefulWidget {
  final String meetingId;
  final String? initialNotes;
  final VoidCallback onClose;

  const _MeetingNotesDrawer({
    required this.meetingId,
    required this.initialNotes,
    required this.onClose,
  });

  @override
  ConsumerState<_MeetingNotesDrawer> createState() =>
      _MeetingNotesDrawerState();
}

class _MeetingNotesDrawerState extends ConsumerState<_MeetingNotesDrawer> {
  late final TextEditingController _ctrl;
  Timer? _debounce;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialNotes ?? '');
    _ctrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_saved) setState(() => _saved = false);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), _save);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(meetingsRepositoryProvider)
          .updateMeeting(widget.meetingId, preparationNotes: _ctrl.text.trim());
      ref.invalidate(meetingProvider(widget.meetingId));
      if (mounted) setState(() => _saved = true);
    } catch (_) {
      // Best-effort during live session; don't interrupt the meeting.
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 48, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Notes',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (_saving)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF6C63FF),
                    ),
                  )
                else if (_saved)
                  const Text(
                    'Saved',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF9CA3AF)),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF1E293B), height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AuraSpace.s12),
              child: TextField(
                controller: _ctrl,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                  color: Color(0xFFE5E7EB),
                  fontSize: 13,
                ),
                decoration: const InputDecoration(
                  hintText: 'Quick notes for this meeting…',
                  hintStyle: TextStyle(color: Color(0xFF4B5563)),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Connecting overlay
// ---------------------------------------------------------------------------

class _ConnectingOverlay extends StatelessWidget {
  final RealtimeState state;
  final VoidCallback onRetry;

  const _ConnectingOverlay({required this.state, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final hasError = state.joinState == RealtimeJoinState.failed &&
        state.errorMessage != null;

    return Container(
      color: const Color(0xEE030712),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!hasError) ...[
              const CircularProgressIndicator(color: Color(0xFF6C63FF)),
              const SizedBox(height: AuraSpace.s16),
              Text(
                state.infoMessage ?? 'Connecting to meeting...',
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 40),
              const SizedBox(height: AuraSpace.s12),
              Text(
                state.errorMessage!,
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AuraSpace.s16),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// E9 — Meeting ended overlay (guest path)
// ---------------------------------------------------------------------------

class _MeetingEndedOverlay extends StatelessWidget {
  final VoidCallback onViewSummary;
  final VoidCallback onLeave;

  const _MeetingEndedOverlay({
    required this.onViewSummary,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xEE030712),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: Color(0xFF10B981),
              size: 48,
            ),
            const SizedBox(height: AuraSpace.s16),
            const Text(
              'Meeting ended',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AuraSpace.s8),
            const Text(
              'The host has ended the meeting.',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
            ),
            const SizedBox(height: AuraSpace.s24),
            FilledButton.icon(
              onPressed: onViewSummary,
              icon: const Icon(Icons.description_outlined),
              label: const Text('View summary'),
            ),
            const SizedBox(height: AuraSpace.s12),
            OutlinedButton(
              onPressed: onLeave,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF9CA3AF),
              ),
              child: const Text('Leave'),
            ),
          ],
        ),
      ),
    );
  }
}
