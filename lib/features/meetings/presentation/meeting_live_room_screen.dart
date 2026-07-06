import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_space.dart';
import '../application/meeting_entry_prefs.dart';
import '../application/meetings_provider.dart';
import 'widgets/meeting_conversation_panel.dart';
import 'widgets/meeting_device_picker.dart';
import 'widgets/meeting_pending_guests_panel.dart';
import '../domain/meeting.dart';
import '../domain/meeting_conversation_message.dart';
import '../../realtime/application/realtime_controller.dart';
import '../../realtime/application/realtime_providers.dart';
import '../../realtime/data/realtime_media_service.dart';
import '../../realtime/data/realtime_event_parser.dart';
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
  // Applies the user's pre-join camera/mic choice ONCE, after local media is
  // ready, via the public media controls. Never touches the join/RTC path.
  StreamSubscription<RealtimeMediaSnapshot>? _entryPrefsSub;
  bool _entryPrefsApplied = false;

  // Phase 3.2 — in-call participation (ephemeral, additive over the socket).
  StreamSubscription<RealtimeParsedEvent>? _participationSub;
  final List<_FlyingReaction> _reactions = [];
  final Set<String> _raisedHands = {};
  bool _handRaised = false;
  String _myUserId = '';

  // Phase 4 — Meeting Conversation Stream. The screen owns the message list
  // (not the panel) so the unread badge keeps counting while the panel is
  // closed. History backfills over the socket ack once joined — works for
  // guests too, who cannot call member REST endpoints.
  bool _showChat = false;
  final List<MeetingConversationMessage> _conversation = [];
  int _unseenChat = 0;
  bool _chatHistoryRequested = false;

  void _onParticipationEvent(RealtimeParsedEvent e) {
    if (!mounted) return;
    switch (e.name) {
      case 'session:reaction':
        final emoji = (e.payload['emoji'] ?? '👍').toString();
        final id = DateTime.now().microsecondsSinceEpoch;
        setState(() => _reactions.add(_FlyingReaction(id: id, emoji: emoji)));
        Timer(const Duration(milliseconds: 3200), () {
          if (!mounted) return;
          setState(() => _reactions.removeWhere((r) => r.id == id));
        });
        break;
      case 'session:hand.updated':
        final uid = (e.payload['userId'] ?? '').toString().trim();
        if (uid.isEmpty) break;
        final raised = e.payload['raised'] == true;
        setState(() {
          if (raised) {
            _raisedHands.add(uid);
          } else {
            _raisedHands.remove(uid);
          }
          if (uid == _myUserId) _handRaised = raised;
        });
        break;
      case 'session:mute-request':
        final target = (e.payload['targetUserId'] ?? '').toString().trim();
        if (target.isNotEmpty && target == _myUserId) {
          _bridge.muteLocalMic();
          _showArrivalToast('You were muted by the host');
        }
        break;
      case 'session:conversation.message':
        final msg = MeetingConversationMessage.fromJson(
          Map<String, dynamic>.from(e.payload),
        );
        if (msg.id.isEmpty) break;
        setState(() {
          if (!_conversation.any((m) => m.id == msg.id)) {
            _conversation.add(msg);
            if (!_showChat) _unseenChat++;
          }
        });
        break;
      case 'session:conversation.deleted':
        final mid = (e.payload['messageId'] ?? '').toString().trim();
        if (mid.isEmpty) break;
        setState(() => _conversation.removeWhere((m) => m.id == mid));
        break;
    }
  }

  Future<bool> _sendConversationMessage(
    String body,
    MeetingMessageType type,
  ) async {
    try {
      final res = await ref
          .read(realtimeSocketServiceProvider)
          .emitAck('session:conversation.post', {
        'sessionId': widget.sessionId,
        'body': body,
        'messageType': type.wire,
      });
      return res['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  void _deleteConversationMessage(String messageId) {
    unawaited(
      ref
          .read(realtimeSocketServiceProvider)
          .emitAck('session:conversation.delete', {
            'sessionId': widget.sessionId,
            'messageId': messageId,
          })
          .catchError((_) => <String, dynamic>{}),
    );
  }

  // Backfill (and re-backfill after a reconnect) the conversation over the
  // socket ack; appended messages dedupe by id against live fan-out.
  Future<void> _requestConversationHistory() async {
    try {
      final res = await ref
          .read(realtimeSocketServiceProvider)
          .emitAck('session:conversation.history', {
        'sessionId': widget.sessionId,
      });
      if (!mounted || res['ok'] != true) return;
      final list = res['messages'];
      if (list is! List) return;
      final fetched = list
          .whereType<Map>()
          .map((m) =>
              MeetingConversationMessage.fromJson(Map<String, dynamic>.from(m)))
          .where((m) => m.id.isNotEmpty)
          .toList();
      if (fetched.isEmpty) return;
      setState(() {
        final known = _conversation.map((m) => m.id).toSet();
        _conversation.insertAll(
          0,
          fetched.where((m) => !known.contains(m.id)),
        );
      });
    } catch (_) {
      // Best-effort: a failed backfill must never disturb the live session.
      // Allow a later join transition to retry.
      _chatHistoryRequested = false;
    }
  }

  void _sendReaction(String emoji) {
    unawaited(
      ref
          .read(realtimeSocketServiceProvider)
          .emitAck('session:reaction', {
            'sessionId': widget.sessionId,
            'emoji': emoji,
          })
          .catchError((_) => <String, dynamic>{}),
    );
  }

  void _toggleHand() {
    final next = !_handRaised;
    setState(() => _handRaised = next);
    unawaited(
      ref
          .read(realtimeSocketServiceProvider)
          .emitAck('session:hand.set', {
            'sessionId': widget.sessionId,
            'raised': next,
          })
          .catchError((_) => <String, dynamic>{}),
    );
  }

  void _requestMute(String targetUserId) {
    unawaited(
      ref
          .read(realtimeSocketServiceProvider)
          .emitAck('session:mute-request', {
            'sessionId': widget.sessionId,
            'targetUserId': targetUserId,
          })
          .catchError((_) => <String, dynamic>{}),
    );
  }

  void _showReactionPicker(BuildContext context) {
    const emojis = ['👍', '❤️', '😂', '🎉', '👏', '😮'];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final e in emojis)
                InkWell(
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _sendReaction(e);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(e, style: const TextStyle(fontSize: 30)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

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
    // Phase 3.2 — listen for in-call participation signals (reactions, hands,
    // mute requests) on the existing realtime event stream. Additive: the
    // frozen controller is untouched; these are handled here as ephemeral UI.
    _participationSub = ref
        .read(realtimeSocketServiceProvider)
        .events
        .listen(_onParticipationEvent);
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
    _applyEntryPrefsWhenReady();
  }

  /// Applies the pre-join camera/mic ON-OFF choice once local media is ready.
  /// Uses the same public controls the in-room buttons use — no join/RTC change.
  void _applyEntryPrefsWhenReady() {
    if (_entryPrefsApplied) return;
    final media = ref.read(realtimeMediaServiceProvider);
    if (media.currentSnapshot.ready) {
      _applyEntryPrefs(media);
      return;
    }
    _entryPrefsSub = media.snapshots.listen((snap) {
      if (snap.ready) {
        _entryPrefsSub?.cancel();
        _entryPrefsSub = null;
        _applyEntryPrefs(media);
      }
    });
  }

  Future<void> _applyEntryPrefs(RealtimeMediaService media) async {
    if (_entryPrefsApplied) return;
    _entryPrefsApplied = true;
    final prefs = ref.read(meetingEntryPrefsProvider);
    // Only act when the user opted OUT; defaults are on (a no-op otherwise).
    if (!prefs.micOn) await media.setMicrophoneEnabled(false);
    if (!prefs.cameraOn) await media.setCameraEnabled(false);
  }

  @override
  void dispose() {
    // Release the wake lock when leaving the live room.
    WakelockPlus.disable();
    _entryPrefsSub?.cancel();
    _participationSub?.cancel();
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

  /// In-meeting device menu: live-switches camera/mic (replaceTrack — no
  /// renegotiation) and routes speaker output. Reuses the same picker as
  /// pre-join. Frozen join/signalling path untouched.
  void _showDeviceSettings() {
    final media = ref.read(realtimeMediaServiceProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheet) => Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 18,
              bottom: 24 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Devices',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                MeetingDevicePicker(
                  cameraId: media.preferredVideoDeviceId,
                  micId: media.preferredAudioDeviceId,
                  speakerId: media.preferredAudioOutputDeviceId,
                  onCameraChanged: (id) {
                    media.switchVideoInput(id);
                    setSheet(() {});
                  },
                  onMicChanged: (id) {
                    media.switchAudioInput(id);
                    setSheet(() {});
                  },
                  onSpeakerChanged: (id) {
                    media.setAudioOutput(id);
                    setSheet(() {});
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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
    _myUserId = myUserId.toString().trim();

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

    // Phase 4 — backfill the conversation once joined; re-arms after a
    // reconnect (isJoined dips false, then true again) and dedupes by id.
    if (!state.isJoined) {
      _chatHistoryRequested = false;
    } else if (!_chatHistoryRequested) {
      _chatHistoryRequested = true;
      Future.microtask(_requestConversationHistory);
    }

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
              localSocketId:
                  ref.read(realtimeSocketServiceProvider).socketId ?? '',
            ),
          ),

          // Camera-busy banner: shown when video capture failed but audio
          // succeeded (e.g. host + guest sharing one physical camera on the
          // same laptop — the second browser can't open it). We join audio-only
          // instead of silently publishing nothing.
          Positioned(
            bottom: 96,
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

          // Phase 3.2 — flying reaction overlay (never blocks pointer input).
          if (_reactions.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: _ReactionsOverlay(reactions: _reactions),
              ),
            ),

          // Phase 3.2 — raised-hands strip (who currently has a hand up).
          if (_raisedHands.isNotEmpty)
            Positioned(
              top: 56,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.topCenter,
                child: _RaisedHandsStrip(
                  raised: _raisedHands,
                  participants: state.participants,
                  localUserId: myUserId,
                ),
              ),
            ),

          // Guest-approval — host-only "waiting to join" panel (polls /pending;
          // renders nothing when no one is knocking).
          if (widget.isHost)
            Positioned(
              top: 64,
              left: 16,
              child: MeetingPendingGuestsPanel(meetingId: widget.meetingId),
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
                raisedHands: _raisedHands,
                onClose: () => setState(() => _showParticipants = false),
                onRemoveParticipant: widget.isHost
                    ? (userId) => _bridge.removeParticipantFromMeeting(userId)
                    : null,
                onMuteParticipant: widget.isHost ? _requestMute : null,
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
                initialNotes: meeting?.liveNotes,
                onClose: () => setState(() => _showNotes = false),
              ),
            ),

          // Phase 4 — Meeting Conversation Stream panel (right, shifts past
          // the participant/notes panels when they are open).
          if (_showChat)
            Positioned(
              top: 0,
              right: (_showParticipants ? 300 : 0) + (_showNotes ? 300 : 0),
              bottom: 0,
              child: MeetingConversationPanel(
                messages: _conversation,
                localUserId: _myUserId,
                isHost: widget.isHost,
                chatEnabled: meeting?.chatEnabled ?? true,
                onClose: () => setState(() => _showChat = false),
                onSend: _sendConversationMessage,
                onDelete:
                    widget.isHost ? _deleteConversationMessage : null,
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
              showChat: _showChat,
              unreadChat: _unseenChat,
              onToggleChat: () => setState(() {
                _showChat = !_showChat;
                if (_showChat) _unseenChat = 0;
              }),
              onShareScreen: _toggleScreenShare,
              onFlipCamera: _flipCamera,
              onDeviceSettings: _showDeviceSettings,
              onEndMeeting: _endMeeting,
              onLeaveMeeting: _leaveMeeting,
              handRaised: _handRaised,
              onToggleHand: _toggleHand,
              onReact: () => _showReactionPicker(context),
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

class _MeetingVideoGrid extends StatelessWidget {
  final RTCVideoRenderer? localRenderer;
  final Map<String, RTCVideoRenderer> remoteRenderers;
  final bool micOn;
  final bool isLocalScreenSharing;
  final String? screenSharingPeerId;
  final List<RealtimeParticipant> participants;
  final String localUserId;
  final String localSocketId;

  const _MeetingVideoGrid({
    required this.localRenderer,
    required this.remoteRenderers,
    required this.micOn,
    required this.isLocalScreenSharing,
    required this.participants,
    required this.localUserId,
    required this.localSocketId,
    this.screenSharingPeerId,
  });

  String _raw(String s) => s.startsWith('socket:') ? s.substring(7) : s;

  // Ground-truth video state for a renderer: a video track is present AND not
  // muted (a muted receive-track = the peer's camera is actually off). Used
  // instead of the roster's videoOn flag, which can be stale.
  bool _hasLiveVideo(RTCVideoRenderer? renderer) {
    final tracks = renderer?.srcObject?.getVideoTracks() ?? const [];
    if (tracks.isEmpty) return false;
    return tracks.first.muted != true;
  }

  RealtimeParticipant? _participantForKey(String key) {
    for (final p in participants) {
      if ((p.runtimeDeviceId ?? '') == key) return p;
    }
    return null;
  }

  Widget _buildRemoteTile(String key, RTCVideoRenderer renderer) {
    final p = _participantForKey(key);
    // Render video ONLY when the renderer's stream actually carries a video
    // track. A peer that degraded to audio-only (camera busy on its machine)
    // has a renderer but no video track — relying on the roster's videoOn flag
    // (which stays true because it never explicitly turned video off) painted a
    // black RTCVideoView. Check the real track so we fall through to the
    // avatar/"camera off" tile instead of a black void.
    final hasVideoTrack =
        renderer.srcObject?.getVideoTracks().isNotEmpty ?? false;
    final videoOn = (p?.videoOn ?? true) && hasVideoTrack;
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

  RealtimeParticipant? _participantForUserId(String userId) {
    final id = userId.trim();
    if (id.isEmpty) return null;
    for (final p in participants) {
      if (p.userId.trim() == id) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Remote screen share stays a spotlight (shared surface + presenter PiP) —
    // a screen is not a participant tile.
    if (screenSharingPeerId != null) {
      final screenRenderer = remoteRenderers[screenSharingPeerId];
      if (screenRenderer != null) {
        return _buildSpotlightLayout(
            screenSharingPeerId!, screenRenderer, localRenderer);
      }
    }

    // Unified participant grid: the local participant and every remote are
    // first-class tiles in ONE grid — no floating self-preview, no separate
    // "waiting" screen once we're live. A camera-off / audio-only participant
    // gets an avatar tile in the same grid; the layout auto-adjusts as people
    // join. (Small self-preview belongs to pre-join, a different screen.)
    return _buildParticipantGrid();
  }

  Widget _buildParticipantGrid() {
    final tiles = <_ParticipantTile>[];

    // Local participant — always a tile, labelled "You", never a floating PiP.
    final localP = _participantForUserId(localUserId);
    final localHasVideo =
        localRenderer?.srcObject?.getVideoTracks().isNotEmpty ?? false;
    tiles.add(_ParticipantTile(
      renderer: localRenderer,
      videoOn: localHasVideo && !isLocalScreenSharing,
      mirror: true,
      isLocal: true,
      label: 'You',
      avatarUrl: localP?.avatarUrl,
      micOn: micOn,
    ));

    // INVENTORY-DRIVEN remote tiles. Every remote PARTICIPANT gets a tile;
    // video is a tile STATE (attach the renderer if one exists for this
    // participant, else a camera-off avatar). A participant is NEVER hidden
    // because its video track is absent — that caused the asymmetry where the
    // host dropped the audio-only guest's tile while the guest still rendered
    // the host. Both sides share the same participant inventory, so both render
    // the same set of tiles.
    final myUserId = localUserId.trim();
    final mySocket = _raw(localSocketId);
    bool isSelf(RealtimeParticipant p) {
      if (myUserId.isNotEmpty && p.userId.trim() == myUserId) return true;
      final key = _raw((p.runtimeDeviceId ?? '').trim());
      return mySocket.isNotEmpty && key == mySocket;
    }

    final claimed = <String>{};
    for (final p in participants) {
      if (isSelf(p)) continue;
      final key = (p.runtimeDeviceId ?? '').trim();
      if (key.isNotEmpty) claimed.add(key);
      final renderer = key.isNotEmpty ? remoteRenderers[key] : null;
      tiles.add(_ParticipantTile(
        // Video state is the LIVE track, not the roster's videoOn hint. The
        // roster flag can be stale-false (a peer's camera-on didn't propagate),
        // which hid a real incoming video — the "host sees Camera off while the
        // guest is on camera" bug. The received track is ground truth.
        renderer: renderer,
        videoOn: _hasLiveVideo(renderer),
        mirror: false,
        isLocal: false,
        label: p.identityLabel,
        avatarUrl: p.avatarUrl,
        micOn: p.audioOn,
      ));
    }

    // Fallback: a live renderer whose peer isn't in the roster yet (socketId
    // not backfilled) still gets a tile so media is never dropped. Deduped
    // against the inventory above by renderer key.
    for (final entry in remoteRenderers.entries) {
      if (claimed.contains(entry.key)) continue;
      if (mySocket.isNotEmpty && _raw(entry.key) == mySocket) continue;
      tiles.add(_ParticipantTile(
        renderer: entry.value,
        videoOn: _hasLiveVideo(entry.value),
        mirror: false,
        isLocal: false,
        label: 'Participant',
        avatarUrl: null,
        micOn: true,
      ));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = tiles.length;
        final columns = _gridColumns(count, constraints);
        final rows = (count / columns).ceil();
        final cellW = (constraints.maxWidth - (columns + 1) * 4) / columns;
        final cellH = (constraints.maxHeight - (rows + 1) * 4) / rows;
        final aspect =
            (cellW > 0 && cellH > 0) ? (cellW / cellH) : (16 / 9);
        return GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          padding: const EdgeInsets.all(4),
          childAspectRatio: aspect,
          children: tiles,
        );
      },
    );
  }

  // Column count that keeps tiles roughly square and readable. 2 participants
  // split equally (side-by-side in landscape, stacked in portrait); 3–4 use a
  // 2-wide grid; more scale to 3–4 columns.
  int _gridColumns(int count, BoxConstraints c) {
    if (count <= 1) return 1;
    final landscape = c.maxWidth >= c.maxHeight;
    if (count == 2) return landscape ? 2 : 1;
    if (count <= 4) return 2;
    if (count <= 9) return 3;
    return 4;
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
}

// One participant tile — local or remote, first-class in the grid. Renders the
// video when a live video track exists, otherwise an avatar + "Camera off".
// Always carries the identity label and a mic indicator.
class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({
    required this.renderer,
    required this.videoOn,
    required this.mirror,
    required this.isLocal,
    required this.label,
    required this.avatarUrl,
    required this.micOn,
  });

  final RTCVideoRenderer? renderer;
  final bool videoOn;
  final bool mirror;
  final bool isLocal;
  final String label;
  final String? avatarUrl;
  final bool micOn;

  @override
  Widget build(BuildContext context) {
    final showVideo = videoOn && renderer != null;
    final trimmed = label.trim();
    final initial = trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '?';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120),
        borderRadius: BorderRadius.circular(12),
        border: isLocal
            ? Border.all(color: const Color(0xFF6C63FF), width: 1.5)
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showVideo)
              RTCVideoView(
                renderer!,
                mirror: mirror,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            else
              _avatar(initial),

            // Identity label + mic indicator (bottom-left).
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                      size: 13,
                      color: micOn
                          ? const Color(0xFFE5E7EB)
                          : const Color(0xFFF87171),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFFE5E7EB),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(String initial) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.25),
            backgroundImage: avatarUrl?.trim().isNotEmpty == true
                ? NetworkImage(avatarUrl!)
                : null,
            child: avatarUrl?.trim().isNotEmpty == true
                ? null
                : Text(
                    initial,
                    style: const TextStyle(
                      color: Color(0xFFE5E7EB),
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off_rounded,
                  size: 13, color: Color(0xFF6B7280)),
              SizedBox(width: 4),
              Text('Camera off',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
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
  final bool showChat;
  final int unreadChat;
  final bool endingMeeting;
  final bool togglingScreenShare;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleParticipants;
  final VoidCallback onToggleNotes;
  final VoidCallback onToggleChat;
  final VoidCallback onShareScreen;
  final VoidCallback onFlipCamera;
  final VoidCallback onDeviceSettings;
  final VoidCallback onEndMeeting;
  final VoidCallback onLeaveMeeting;
  final bool handRaised;
  final VoidCallback onToggleHand;
  final VoidCallback onReact;

  const _MeetingControlBar({
    required this.state,
    required this.isHost,
    required this.showParticipants,
    required this.showNotes,
    required this.showChat,
    required this.unreadChat,
    required this.endingMeeting,
    required this.togglingScreenShare,
    required this.onToggleMic,
    required this.onToggleCamera,
    required this.onToggleParticipants,
    required this.onToggleNotes,
    required this.onToggleChat,
    required this.onShareScreen,
    required this.onFlipCamera,
    required this.onDeviceSettings,
    required this.onEndMeeting,
    required this.onLeaveMeeting,
    required this.handRaised,
    required this.onToggleHand,
    required this.onReact,
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

          // React — send an emoji reaction to the room.
          _ControlButton(
            icon: Icons.add_reaction_outlined,
            label: 'React',
            active: false,
            onTap: onReact,
          ),

          // Raise / lower hand.
          _ControlButton(
            icon: handRaised
                ? Icons.back_hand_rounded
                : Icons.back_hand_outlined,
            label: handRaised ? 'Lower hand' : 'Raise hand',
            active: handRaised,
            onTap: onToggleHand,
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

          // Phase 4 — meeting conversation stream.
          _ControlButton(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Chat',
            active: showChat,
            badge: unreadChat,
            onTap: onToggleChat,
          ),

          // Devices — camera / microphone / speaker selection.
          _ControlButton(
            icon: Icons.tune_rounded,
            label: 'Devices',
            active: false,
            onTap: onDeviceSettings,
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
  // Unread count bubble (e.g. chat); hidden when 0.
  final int badge;
  final VoidCallback? onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.active,
    this.danger = false,
    this.badge = 0,
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
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: onTap == null ? bg.withValues(alpha: 0.5) : bg,
                  borderRadius: BorderRadius.circular(12),
                  border: active && !danger
                      ? Border.all(
                          color:
                              const Color(0xFF6C63FF).withValues(alpha: 0.5),
                        )
                      : null,
                ),
                child: Icon(icon, color: fg, size: 22),
              ),
              if (badge > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
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
  final Set<String> raisedHands;
  final VoidCallback onClose;
  final void Function(String userId)? onRemoveParticipant;
  final void Function(String userId)? onMuteParticipant;

  const _MeetingParticipantPanel({
    required this.participants,
    required this.isHost,
    required this.localUserId,
    required this.raisedHands,
    required this.onClose,
    this.onRemoveParticipant,
    this.onMuteParticipant,
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
                        handRaised: raisedHands.contains(p.userId.trim()),
                        onRemove: (isHost && !isMe && onRemoveParticipant != null)
                            ? () => onRemoveParticipant!(p.userId)
                            : null,
                        onMute: (isHost &&
                                !isMe &&
                                p.audioOn &&
                                onMuteParticipant != null)
                            ? () => onMuteParticipant!(p.userId)
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
  final bool handRaised;
  final VoidCallback? onRemove;
  final VoidCallback? onMute;

  const _ParticipantRow({
    required this.participant,
    required this.isHost,
    required this.isMe,
    this.handRaised = false,
    this.onRemove,
    this.onMute,
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
          if (handRaised) ...[
            const SizedBox(width: AuraSpace.s6),
            const Text('✋', style: TextStyle(fontSize: 14)),
          ],
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
          // Host mute request (shown when the participant's mic is on).
          if (onMute != null) ...[
            const SizedBox(width: AuraSpace.s6),
            GestureDetector(
              onTap: onMute,
              child: const Tooltip(
                message: 'Ask to mute',
                child: Icon(
                  Icons.mic_off_rounded,
                  size: 16,
                  color: Color(0xFFF59E0B),
                ),
              ),
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
// E6 — Notes drawer: saves LIVE notes (Meeting.liveNotes) via updateMeeting().
// Kept distinct from preparationNotes (the pre-meeting agenda/brief) so live
// note-taking never overwrites the host's preparation material.
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
          .updateMeeting(widget.meetingId, liveNotes: _ctrl.text.trim());
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

// ---------------------------------------------------------------------------
// Phase 3.2 — in-call participation UI (reactions overlay, raised-hands strip)
// ---------------------------------------------------------------------------

class _FlyingReaction {
  final int id;
  final String emoji;
  final double lane;
  _FlyingReaction({required this.id, required this.emoji})
      : lane = (id % 100) / 100.0;
}

class _ReactionsOverlay extends StatelessWidget {
  final List<_FlyingReaction> reactions;
  const _ReactionsOverlay({required this.reactions});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (final r in reactions)
          Positioned.fill(
            key: ValueKey(r.id),
            child: _RisingReaction(reaction: r),
          ),
      ],
    );
  }
}

class _RisingReaction extends StatelessWidget {
  final _FlyingReaction reaction;
  const _RisingReaction({required this.reaction});

  @override
  Widget build(BuildContext context) {
    final xAlign = -0.55 + reaction.lane * 1.1;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 3000),
      curve: Curves.easeOut,
      builder: (context, t, child) {
        final yAlign = 0.75 - t * 1.45;
        final opacity = t < 0.8 ? 1.0 : (1.0 - (t - 0.8) / 0.2);
        return Align(
          alignment: Alignment(xAlign, yAlign),
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Text(reaction.emoji, style: const TextStyle(fontSize: 36)),
          ),
        );
      },
    );
  }
}

class _RaisedHandsStrip extends StatelessWidget {
  final Set<String> raised;
  final List<RealtimeParticipant> participants;
  final String localUserId;

  const _RaisedHandsStrip({
    required this.raised,
    required this.participants,
    required this.localUserId,
  });

  String _labelFor(String userId) {
    if (userId == localUserId) return 'You';
    for (final p in participants) {
      if (p.userId.trim() == userId) return p.identityLabel;
    }
    return 'Someone';
  }

  @override
  Widget build(BuildContext context) {
    final names = raised.map(_labelFor).toList();
    final text = names.length <= 2
        ? names.join(', ')
        : '${names.take(2).join(', ')} +${names.length - 2}';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xF20F172A),
        border: Border.all(color: const Color(0x66F59E0B)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✋', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              names.length == 1 ? '$text raised a hand' : '$text raised hands',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFF59E0B),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
