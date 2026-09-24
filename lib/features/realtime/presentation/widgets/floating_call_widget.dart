import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/call_presence_bridge.dart';
import '../../application/realtime_providers.dart';
import '../../domain/realtime_enums.dart';
import '../../domain/realtime_models.dart';
import '../../../../core/navigation/navigation_authority.dart';
import '../../../../router.dart';
import '../../domain/realtime_state.dart';
import 'floating_call_card.dart';
import 'floating_call_layout.dart';

// THE CARD'S DIMENSIONS AND COMPOSITIONS LIVE IN `floating_call_layout.dart`.
//
// They were pulled out so the rules — which shape an audio call takes, which a
// video call takes, and how big a control has to be for a thumb — can be
// asserted without a renderer, a socket or a camera. See that file's header for
// what was wrong with the single shape this replaced.

// ─────────────────────────────────────────────────────────────────────────────
// RESOLVED CALL INFO
// ─────────────────────────────────────────────────────────────────────────────

class _CallInfo {
  const _CallInfo({
    required this.sessionId,
    required this.isVideo,
    required this.micOn,
    required this.cameraOn,
    required this.startedAt,
    required this.participants,
    required this.isOwner,
    this.remoteRenderer,
    this.remoteName,
  });

  final String sessionId;
  final bool isVideo;
  final bool micOn;
  final bool cameraOn;
  final DateTime? startedAt;
  final List<RealtimeParticipant> participants;

  /// THE PICTURE OF SOMEBODY ELSE.
  ///
  /// This used to be `localRenderer` — the viewer's own camera, mirrored. A
  /// minimised call is kept on screen so the CALL keeps going while you look at
  /// something else; the one participant you do not need a picture of is
  /// yourself. Null when nobody remote is decoding a frame, and the card then
  /// takes its bar composition rather than showing an empty well.
  final RTCVideoRenderer? remoteRenderer;

  /// Who [remoteRenderer] belongs to, for the bar composition's label.
  final String? remoteName;

  /// True when this tab owns and is joined to the call.
  /// False when the call is active in another tab (passive view only).
  final bool isOwner;
}

// ─────────────────────────────────────────────────────────────────────────────
// FLOATING CALL WIDGET
// ─────────────────────────────────────────────────────────────────────────────

/// Minimised call status strip.
///
/// Shown when the user navigates away from the full call screen (/realtime/:id).
/// When this tab owns the call: shows Return and End/Leave controls.
/// When the call is in another tab: shows a passive "Call active in another tab"
/// indicator with no interactive controls — passive tabs must not end calls.
///
/// Returns a [Positioned] widget so the render box is exactly card-sized.
/// This prevents a full-screen hitbox from blocking underlying UI.
class FloatingCallWidget extends ConsumerStatefulWidget {
  const FloatingCallWidget({super.key});

  @override
  ConsumerState<FloatingCallWidget> createState() => _FloatingCallWidgetState();
}

class _FloatingCallWidgetState extends ConsumerState<FloatingCallWidget> {
  Offset? _offset;
  bool _positionInitialized = false;

  /// The composition last built, so the drag clamp measures the card that is
  /// actually on screen. The old code clamped against a single hardcoded
  /// estimate, which is how the controls ended up reachable-in-theory and
  /// parked under the home indicator in practice.
  FloatingCallComposition _composition = FloatingCallComposition.bar;

  /// A PICTURE ARRIVES AFTER THE CARD IS BUILT.
  ///
  /// The renderer is handed its track by the media service on its own schedule.
  /// A card that asks "is anybody decoding?" once, at build time, answers "no"
  /// for the rest of the call — the same fault that made every meeting tile say
  /// "Camera off" a few hours earlier (M-13). So it keeps looking, and rebuilds
  /// ONLY when the answer changes: a periodic `setState` would rebuild the
  /// `RTCVideoView` with it, which is the churn A6 removed.
  Timer? _pictureRecheck;
  bool _hadPicture = false;
  // A6: removed the 1-second ticker that rebuilt the entire card (and the
  // RTCVideoView with it). The duration display now ticks inside its own
  // isolated subwidget (`_DurationDisplay`), so the video renderer survives
  // every duration update without dispose/reinit churn.

  // A5: removed local _isEnding — UI reads state.isEndingCall now.

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_positionInitialized) _initPosition();
  }

  @override
  void initState() {
    super.initState();
    _pictureRecheck = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      final hasPicture =
          _remotePicture(ref.read(realtimeControllerProvider)) != null;
      if (hasPicture != _hadPicture) setState(() => _hadPicture = hasPicture);
    });
  }

  void _initPosition() {
    final size = MediaQuery.sizeOf(context);
    if (size.isEmpty) return;
    // Keep the initial bottom-right anchor clear of the home indicator /
    // gesture bar (and the windowed-desktop edge) by offsetting with the
    // real system inset rather than a blind margin.
    final pad = MediaQuery.viewPaddingOf(context);
    _positionInitialized = true;
    final card = floatingCallSize(_composition);
    _offset = Offset(
      size.width - card.width - 20 - pad.right,
      size.height - card.height - 84 - pad.bottom,
    );
  }

  @override
  void dispose() {
    _pictureRecheck?.cancel();
    super.dispose();
  }

  // ── Drag ────────────────────────────────────────────────────────────────────

  void _onPanUpdate(DragUpdateDetails d) {
    if (_offset == null) return;
    final size = MediaQuery.sizeOf(context);
    // Clamp the drag bounds to the safe area so the PiP can never be parked
    // under the notch / status bar, the home indicator, or a desktop title
    // bar — it must stay fully visible and draggable in every orientation.
    final pad = MediaQuery.viewPaddingOf(context);
    setState(() {
      final card = floatingCallSize(_composition);
      final raw = _offset! + d.delta;
      final minX = pad.left;
      final maxX = (size.width - card.width - pad.right).clamp(
        minX,
        double.infinity,
      );
      final minY = pad.top;
      final maxY = (size.height - card.height - pad.bottom).clamp(
        minY,
        double.infinity,
      );
      _offset = Offset(raw.dx.clamp(minX, maxX), raw.dy.clamp(minY, maxY));
    });
  }

  // ── Which picture, and whose ────────────────────────────────────────────────

  /// The remote participant whose picture the card should carry, with the
  /// renderer that is actually decoding it.
  ///
  /// A PICTURE IS PROVEN BY A FRAME, NOT BY A FLAG. `participant.videoOn` is
  /// derived server-side and is under repair — M-10 has it reporting OFF for
  /// participants who were visibly publishing — so trusting it here would give
  /// a black 16:9 well exactly when somebody's camera was on. The renderer's
  /// `srcObject` holding a live video track is the observable fact.
  ({RealtimeParticipant participant, RTCVideoRenderer renderer})?
  _remotePicture(RealtimeState local) {
    final byParticipant = local.remoteRenderersByParticipant;
    if (byParticipant.isEmpty) return null;
    for (final participant in local.participants) {
      if (!participant.isPresent) continue;
      final renderer = byParticipant[participant.id];
      if (renderer == null) continue;
      final stream = renderer.srcObject;
      if (stream == null) continue;
      if (stream.getVideoTracks().isEmpty) continue;
      return (participant: participant, renderer: renderer);
    }
    return null;
  }

  /// The name the bar composition says out loud.
  ///
  /// Prefers whoever has a picture, then the first other present participant —
  /// a minimised call should name the person it is with, not the number of rows
  /// of chrome it can fit.
  String? _remoteName(RealtimeState local) {
    final withPicture = _remotePicture(local)?.participant;
    final candidate =
        withPicture ??
        local.participants
            .where((p) => p.isPresent)
            .cast<RealtimeParticipant?>()
            .firstWhere(
              (p) => (p?.displayName ?? p?.handle ?? '').trim().isNotEmpty,
              orElse: () => null,
            );
    final name = (candidate?.displayName ?? candidate?.handle ?? '').trim();
    return name.isEmpty ? null : name;
  }

  // ── Resolve active call info ─────────────────────────────────────────────

  _CallInfo? _resolve() {
    final local = ref.read(realtimeControllerProvider);
    final sessionId = local.sessionId;
    if (local.isJoined && sessionId != null && sessionId.isNotEmpty) {
      // A3: Active in this tab — only render when the loaded session is
      // confirmed active. `session?.isActive == false` (terminal) AND
      // `session == null` (still hydrating / cleared / stale ref) both
      // suppress the card, so we never show a dead session card during
      // the post-end race window.
      final session = local.session;
      if (session == null || !session.isActive) {
        return null;
      }
      return _CallInfo(
        sessionId: sessionId,
        isVideo: local.isVideoMode,
        micOn: local.microphoneEnabled,
        cameraOn: local.cameraEnabled,
        // THE SAME CLOCK THE ROOM SHOWS.
        //
        // This used to anchor on `session.startedAt` — when the ROOM opened —
        // while the full-screen room anchored on a different field entirely.
        // Minimising a call visibly changed the elapsed time, because the two
        // surfaces were counting different things. `connectedAt` is the one
        // start instant, and null until the call actually connected.
        // For a call: `connectedAt`, and null until it connects, so the PiP
        // shows `--:--` rather than counting a call nobody has answered. For a
        // meeting or a stage there is no call, and the room's own start is the
        // honest anchor because nobody was ever ringing.
        startedAt: session.call != null
            ? session.call!.connectedAt
            : session.startedAt,
        participants: local.participants.where((p) => p.isPresent).toList(),
        isOwner: true,
        remoteRenderer: _remotePicture(local)?.renderer,
        remoteName: _remoteName(local),
      );
    }

    // Fallback: a call is active in *another* tab. Show a passive PiP so
    // the user can see at a glance that they're still in a call (e.g.
    // after navigating to another tab/window). Owner controls are
    // suppressed because this tab does not own the media session.
    final presence = ref.read(callPresenceBridgeProvider);
    if (presence == null) return null;
    if (presence.sessionId.isEmpty) return null;
    return _CallInfo(
      sessionId: presence.sessionId,
      isVideo: presence.isVideo,
      micOn: presence.micOn,
      cameraOn: presence.cameraOn,
      startedAt: presence.startedAt,
      participants: const [],
      isOwner: false,
      remoteRenderer: null,
      remoteName: null,
    );
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  void _returnToCall(_CallInfo info) {
    if (info.isOwner) {
      // A2: only navigate to /realtime/:sessionId when the controller still
      // holds an active session for this id. If the host ended (or the
      // server tore down) the session between the PiP rendering and the tap
      // landing, clear the stale local reference instead of routing to a
      // dead screen.
      final local = ref.read(realtimeControllerProvider);
      final session = local.session;

      // A TAP THAT DOES NOTHING IS THE WORST OF THE THREE OUTCOMES.
      //
      // This used to require `isJoined && session.isActive` before returning,
      // and silently cleared the session otherwise — so anything that knocked
      // the controller out of `joined` for a moment (a socket reconnect, a
      // re-hydrate mid-call) turned the PiP into a dead button that also
      // threw the call reference away. Founder-observed 2026-08-28: "after
      // minimizing, return doesn't work".
      //
      // The session id is the only thing worth guarding on here: if the PiP
      // is showing a DIFFERENT session from the one the controller holds, the
      // reference really is stale and clearing it is right. If it is the same
      // session, the room screen is the authority on whether it is still
      // live — it already renders an ended call honestly — so go there and
      // let it answer, rather than deciding from flags that are allowed to
      // flicker.
      final sameSession =
          (local.sessionId ?? '').trim() == info.sessionId.trim();
      if (!sameSession && session != null) {
        ref.read(realtimeControllerProvider.notifier).clearLocalSession();
        return;
      }
    }
    final liveState = ref.read(realtimeControllerProvider);
    final liveSession = liveState.session;
    if (liveSession?.surfaceType == RealtimeSurfaceType.meeting) {
      final meetingId = (liveSession!.surfaceId ?? '').trim();
      if (meetingId.isNotEmpty) {
        context.go('/meetings/$meetingId/live?sessionId=${info.sessionId}');
        return;
      }
    }
    // Returning to a call IS intent. A bare address let the room conclude
    // the person had not asked to join and instruct them to join the call
    // they were already in — the same stall as the accept path. The owner
    // branch above proves an active local session; a non-owner reaches
    // here without that proof, which is exactly who would be stranded.
    context.go(NavigationAuthority.realtimeSessionJoinRoute(info.sessionId));
  }

  // A1+A5: End the call from PiP using the same authoritative controller path.
  // The controller's `endCall()` flips state.isEndingCall, which the chip
  // reads to disable itself for re-taps. No local flag — single source.
  Future<void> _endCallFromPip() async {
    if (ref.read(realtimeControllerProvider).isEndingCall) return;
    try {
      await ref.read(realtimeControllerProvider.notifier).endCall();
    } catch (_) {
      // endCall is local-first; backend errors are swallowed by the controller.
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final liveState = ref.watch(realtimeControllerProvider);
    // Re-render when cross-tab presence changes so passive PiP appears /
    // disappears within one heartbeat without polling.
    ref.watch(callPresenceBridgeProvider);

    // THE ADDRESS SAYS WHICH SURFACE OWNS THE CALL.
    //
    // A4 drove this from `isCallRoomVisible`, which the room toggles in
    // initState/dispose. `dispose` IS synchronous with leaving, so minimising
    // was correct — but `initState` runs only after the route has been built,
    // so ENTERING left a window in which the call was joined and the room was
    // not yet on screen. The PiP filled that window: on accepting a call it
    // appeared, expanded, and was then replaced by the full room. Founder-
    // observed on the attendee side, 2026-08-22, and worse on mobile where the
    // window is longer.
    //
    // Adding a second flag for "entering" would have been another race to
    // arbitrate. The address changes SYNCHRONOUSLY with navigation, in both
    // directions, and now reflects imperative navigation too — so it answers
    // "is the call surface on screen" without a window to be caught in.
    final addresses = ref.watch(routerProvider).routeInformationProvider;
    return ValueListenableBuilder<RouteInformation>(
      valueListenable: addresses,
      builder: (context, routeInformation, _) =>
          _buildPip(context, liveState, routeInformation.uri),
    );
  }

  /// Sessions whose full call surface this client has actually shown.
  ///
  /// See the rule in [_buildPip].
  final Set<String> _surfaceShown = <String>{};

  Widget _buildPip(
    BuildContext context,
    RealtimeState liveState,
    Uri location,
  ) {
    if (callSurfaceOwnsTheScreen(location)) {
      // Remember that the room for THIS session has been on screen. Recorded
      // during build rather than in the room's initState because that is
      // precisely the lifecycle window the 2026-08-22 repair had to escape.
      //
      // The identity recorded is the one `_resolve()` reports, NOT the id in
      // the path: on `/meetings/:id/live` the path carries the MEETING id
      // while the PiP compares realtime session ids, so matching on the path
      // would silently suppress the meetings PiP forever.
      final shown = _resolve();
      if (shown != null) _surfaceShown.add(shown.sessionId);
      return const SizedBox.shrink();
    }

    final info = _resolve();
    if (info == null) return const SizedBox.shrink();

    // A PiP MUST NOT PRECEDE THE ROOM IT REPRESENTS.
    //
    // Founder-observed on the receiving end, 2026-08-25, still present after
    // the 2026-08-22 route-based repair: accepting a call flashed the PiP
    // before the room appeared.
    //
    // That repair fixed *which* signal is used — the address, which changes
    // synchronously with navigation — but not the ordering. Joining happens
    // BEFORE navigation begins: the callee accepts, the session becomes
    // joined, `_resolve()` starts returning info, and the PiP renders in the
    // gap before the route changes. On the receiving end that gap is longest,
    // because accepting does the join and the navigation back to back.
    //
    // The product rule this encodes: the PiP means "a call is running on some
    // other screen". A call whose room has never been shown is not running
    // somewhere else — it is arriving here. So the PiP stays silent until the
    // room for that session has actually been on screen at least once.
    //
    // Leaving is unaffected: by then the surface has been shown, so minimising
    // still produces a PiP immediately.
    if (!_surfaceShown.contains(info.sessionId)) {
      return const SizedBox.shrink();
    }

    if (_offset == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_positionInitialized) _initPosition();
      });
      return const SizedBox.shrink();
    }

    // WHICH SHAPE THIS CALL TAKES.
    //
    // Decided from the content, every build: a video call with somebody's
    // picture decoding becomes that picture; anything else — an audio call, or
    // a video call before the first frame, or one where every camera is off —
    // becomes a short bar with no picture area to leave empty.
    final composition = floatingCallComposition(
      isVideo: info.isVideo,
      hasRemotePicture: info.remoteRenderer != null,
    );
    _composition = composition;

    return Positioned(
      left: _offset!.dx,
      top: _offset!.dy,
      width: kFloatingCallWidth,
      // THE DRAG SURFACE MUST NOT COVER THE BUTTONS.
      //
      // `onPanUpdate` used to wrap the WHOLE card, controls included, and that
      // is what made Return "dead on Android" while it worked perfectly on the
      // web (C-4, Film A capture 9).
      //
      // A tap and a pan compete in the same gesture arena. The tap recogniser
      // rejects ITSELF once the finger drifts past `kTouchSlop` (18px), and the
      // pan does not claim until `kPanSlop` (36px) — so a finger that moves
      // 18–36px while pressing lands in a dead band where the tap has given up,
      // the pan has not taken over, and NOTHING AT ALL HAPPENS. Past 36px the
      // pan wins and the card slides out from under the finger instead. A mouse
      // click drifts zero pixels, which is why this was invisible on desktop.
      //
      // The fix is not a bigger tolerance, it is not owning the buttons: the
      // card is dragged by its body (which is where the drag handle has always
      // been drawn), and the controls row is left out of the drag surface
      // entirely. See `kFloatingControlTapTarget` for the other half of C-4.
      child: FloatingCallCard(
        composition: composition,
        isVideo: info.isVideo,
        micOn: info.micOn,
        cameraOn: info.cameraOn,
        participants: info.participants,
        startedAt: info.startedAt,
        isOwner: info.isOwner,
        remoteName: info.remoteName,
        onPanUpdate: _onPanUpdate,
        // RETURNING IS ALWAYS AVAILABLE. Ending is not.
        //
        // This was `info.isOwner ? ... : null`, so a passive PiP — the
        // one shown when this tab is not the media owner — had NO return
        // handler at all and the button did nothing. Founder-observed
        // 2026-08-28: "nothing happens on return".
        //
        // The irony is that `_returnToCall` already has a branch written
        // for exactly that case, navigating to the session and letting
        // the room resolve it. It was simply unreachable.
        //
        // Ending stays owner-only: closing a call from a tab that does
        // not own the media is a different act with different
        // consequences.
        onReturn: () => _returnToCall(info),
        // A1: passive (cross-tab) PiPs cannot end the call; only the
        // owner tab has the media session and authoritative state.
        onEnd: info.isOwner ? _endCallFromPip : null,
        isEnding: liveState.isEndingCall,
        // The card lays out a picture; only this file knows the picture is a
        // WebRTC surface.
        picture: info.remoteRenderer == null
            ? null
            : RTCVideoView(
                info.remoteRenderer!,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD CONTENT
// ─────────────────────────────────────────────────────────────────────────────

/// A state worth reporting, which for this card means a state that is OFF.
// ─────────────────────────────────────────────────────────────────────────────
// MICRO-WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// A6: isolated 1-second ticker that owns only the duration text. Sits next
/// to the RTCVideoView in the card so the video renderer's parent build
/// scope is not invalidated every second by the duration update.
/// A CONTROL A THUMB CAN FIND — the other half of C-4.
///
/// What this replaces was a text pill with 8px of horizontal and 4px of
/// vertical padding around an 11px glyph: a target about **21 logical pixels
/// tall**. Flutter's own `kMinInteractiveDimension` is 48 and Android's
/// guidance is 48dp, for the plain reason that a fingertip is not a mouse
/// cursor. Founder-observed on Android: Return did nothing. It had been hit
/// every time in testing because everything that tested it had a cursor.
///
/// The visible mark stays small — this belongs to a 276px card — but it now
/// answers across a full [kFloatingControlTapTarget] square, and it carries a
/// semantic label so the word that used to be printed beside it is still
/// available to anyone who needs it read out.
/// Whether the current address IS a full call surface.
///
/// The PiP exists to represent a call the person is NOT looking at. When the
/// address already names a call surface, a PiP would be a second
/// representation of the same call — which is what produced the appear /
/// expand / replace sequence on accept.
///
/// Deliberately covers BOTH systems without collapsing them: a conversation
/// call room (/realtime/:id) and a Meeting's live room (/meetings/:id/live)
/// are separate authorities that happen to share this one property — each owns
/// the whole screen while it is the address.
bool callSurfaceOwnsTheScreen(Uri location) {
  final path = location.path;
  if (path.startsWith('/realtime/')) return true;
  if (path.startsWith('/meetings/') && path.endsWith('/live')) return true;
  return false;
}
