import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback, SystemSound, SystemSoundType;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/communication/communication_resolver.dart';
import '../../../core/notifications/native_call_notification_channel.dart';
import '../application/incoming_call_projection.dart' as projection;
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../application/thread_call_lifecycle_controller.dart';
import '../../updates/incoming_call_bridge.dart';
import '../../updates/providers.dart';
import '../application/realtime_providers.dart';
import '../domain/realtime_enums.dart';
import '../domain/realtime_state.dart';
import 'widgets/floating_call_widget.dart';
import '../../../router.dart';
import '../../../core/identity/person_identity_model.dart';
import '../../../core/navigation/navigation_authority.dart';

// ── TRACE BYPASS FLAGS — flip one at a time, hot-restart, reproduce scenario ──
// Trace 5: bypass entire overlay → if blank clears, overlay is root cause
const bool _kBypassOverlay = false;
// Trace 6: bypass PiP only → if blank clears, FloatingCallWidget is root cause
const bool _kBypassPiP = false;
// ─────────────────────────────────────────────────────────────────────────────

/// 2026-08-14 — Thread Call Lifecycle Convergence, Phase 1/2/5. The founder
/// mandated invariant: "CONNECTED/JOINED truth must invalidate stale
/// JOINING and stale join-failure presentation... tied to authoritative
/// event ordering/session identity." Extracted as a pure, top-level
/// function — not just inline in build() — specifically so it is
/// independently unit-testable without mounting the full overlay widget
/// (which needs a large provider-override harness that doesn't exist yet
/// in this repo; this is the smallest seam that lets this exact
/// precedence rule be tested today rather than left uncovered).
///
/// Returns true when [joinErrorSessionId] (the session an earlier local
/// join failure belongs to) should no longer be treated as live, because
/// authoritative state now says that EXACT session is joined — a later,
/// genuinely different failure (a different session, or [joinErrorSessionId]
/// null) is never suppressed by this check.
bool joinErrorIsStale({
  required String? joinErrorSessionId,
  required bool isJoined,
  required String? liveSessionId,
}) {
  if (joinErrorSessionId == null || joinErrorSessionId.isEmpty) return false;
  if (!isJoined) return false;
  return liveSessionId == joinErrorSessionId;
}

class AuraIncomingLiveLayer extends ConsumerStatefulWidget {
  const AuraIncomingLiveLayer({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AuraIncomingLiveLayer> createState() =>
      _AuraIncomingLiveLayerState();
}

class _AuraIncomingLiveLayerState extends ConsumerState<AuraIncomingLiveLayer>
    with SingleTickerProviderStateMixin {
  static const _resolver = CommunicationResolver();
  // C1: Auto-dismiss aligned with the backend invite TTL (RING_TTL_SECONDS = 90s
  // in realtime-session.service.ts). Previously 50s, which dismissed the card
  // while the server-side invite was still valid for another ~40s — so taps
  // arriving in that window appeared to silently drop. Adding a small cushion
  // beyond 90s would risk the inverse race (showing a card the server has
  // already expired); 90s is the exact upper bound and the bridge listens for
  // session:removed/call:terminal events to dismiss earlier when applicable.
  static const _ringTimeout = Duration(seconds: 90);

  final Set<String> _dismissedIds = <String>{};
  final Set<String> _dismissedSessionIds = <String>{};
  bool _joining = false;
  String? _joinError;
  // 2026-08-14 — Thread Call Lifecycle Convergence, Phase 1/2/5. _joinError
  // used to be sticky, uncoordinated local state: nothing external ever
  // cleared it, so a transient failure on an early attempt could keep
  // showing Retry/Dismiss indefinitely even after the SAME logical call
  // went on to connect successfully via a later attempt or an automatic
  // reconnect. Tracking which session an error belongs to lets build()
  // apply the founder-mandated invariant precisely: authoritative
  // JOINED/CONNECTED truth for a session invalidates STALE failure
  // presentation for that same session — without blindly suppressing a
  // genuinely different, later failure for a different attempt.
  String? _joinErrorSessionId;
  Timer? _ringTimer;
  String? _ringTimerNotificationId;
  Timer? _joinErrorTimer;

  /// Bounded-accept watchdog — see _startAcceptWatchdog.
  Timer? _acceptWatchdog;

  // Pulse animation for the ringing avatar ring.
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _cancelRingTimer();
    _joinErrorTimer?.cancel();
    _joinErrorTimer = null;
    _acceptWatchdog?.cancel();
    _acceptWatchdog = null;
    _pulseController.dispose();
    super.dispose();
  }

  // ── Payload helpers ───────────────────────────────────────────────────────
  // Realtime Architecture Correction — Phase 4, Part F: delegate to the ONE
  // shared projection authority (incoming_call_projection.dart) instead of
  // maintaining a second, independently-drifting copy of this classification
  // logic (notification_bridge.dart previously had a near-duplicate with a
  // slightly different fallback phrase list — merged there, not lost).

  String _resolveKind(Map<String, dynamic> item) =>
      projection.resolveNotificationKind(item);

  String _resolveSessionId(Map<String, dynamic> item) =>
      projection.resolveCallSessionId(item);

  bool _isTerminalCallItem(Map<String, dynamic> item) =>
      projection.isTerminalCallPayload(item);

  bool _isCallKind(String kind) => projection.isCallKind(kind);

  // ── Interrupt candidate logic ─────────────────────────────────────────────

  bool _isInterruptCandidate(
    Map<String, dynamic> item,
    String currentPath,
    RealtimeState liveState,
  ) {
    final id = _stringOf(item['id']);
    if (id.isEmpty || _dismissedIds.contains(id)) return false;

    final sessionId = _resolveSessionId(item);
    if (sessionId.isNotEmpty && _dismissedSessionIds.contains(sessionId)) {
      return false;
    }
    if (_stringOf(item['readAt']).isNotEmpty) return false;

    // Terminal/missed call notifications are history/toast items, never
    // interrupting call UI. Some backend payloads only expose this in text or
    // status fields, so use robust detection instead of trusting callState only.
    if (_isTerminalCallItem(item)) return false;

    // Suppress if the invite has already expired server-side.
    final data = _mapOf(item['data']);
    final expiresAtStr = _stringOf(data['expiresAt']);
    if (expiresAtStr.isNotEmpty) {
      final expiresAt = DateTime.tryParse(expiresAtStr);
      if (expiresAt != null && expiresAt.isBefore(DateTime.now().toUtc())) {
        return false;
      }
    }

    // Already in a dedicated realtime room or live sub-route — suppress.
    if (currentPath.contains('/realtime') ||
        currentPath.contains('/live/') ||
        currentPath.contains('/activity')) {
      return false;
    }

    // Already joined this exact session — never re-interrupt regardless of route.
    // (For a different session we still surface the ringing card so the user
    // can decide whether to switch calls; the previous "joined any call →
    // suppress" rule caused new invites to silently fall through to PiP-only
    // when a stale joined state lingered from an earlier session.)
    if (liveState.isJoined &&
        sessionId.isNotEmpty &&
        liveState.sessionId == sessionId) {
      return false;
    }

    final attention = _stringOf(data['attention']).toUpperCase();
    if (attention != 'INTERRUPT') return false;

    final kind = _resolveKind(item);
    return _isCallKind(kind);
  }

  Map<String, dynamic>? _currentIncoming(
    String currentPath,
    List<Map<String, dynamic>> items,
    RealtimeState liveState,
  ) {
    for (final item in items) {
      if (_isInterruptCandidate(item, currentPath, liveState)) {
        return item;
      }
    }
    return null;
  }

  /// Sessions this device has already reported as presented.
  ///
  /// One report per call: the ring fact is "this device began alerting", not
  /// "a widget rebuilt".
  final Set<String> _presentedSessionIds = <String>{};

  /// THIS DEVICE IS ACTUALLY ALERTING SOMEONE — SAY SO.
  ///
  /// ── THE DEFECT THIS CLOSES ────────────────────────────────────────────
  ///
  /// `ESTABLISHED` was reported from exactly one place: the iOS CallKit
  /// arrival path. Everywhere else — every in-app incoming call, which is the
  /// whole of web and every Android call that arrives while Aura is open — the
  /// card appeared on screen, a person was visibly being called, and the
  /// server was told nothing.
  ///
  /// Proven in a two-party local run: the callee's card was on screen with
  /// Answer and Decline, and the call sat at INVITED with zero presentation
  /// acknowledgements. Two consequences, both wrong in the direction that
  /// matters:
  ///
  ///   * the caller could never see "Ringing…", only "Calling…", while the
  ///     other person's screen was ringing at them;
  ///   * an unanswered call would be recorded NOT_PRESENTED — "could not be
  ///     reached" — when the device demonstrably DID present it. That is the
  ///     precise misreport the call authority exists to prevent, inverted.
  ///
  /// This card IS the presentation on these platforms. Reporting it here is
  /// not a proxy for ringing; it is the ringing.
  void _reportPresented(Map<String, dynamic> item) {
    final sessionId = _resolveSessionId(item);
    if (sessionId.isEmpty) return;
    if (!_presentedSessionIds.add(sessionId)) return;
    unawaited(
      ref
          .read(realtimeRepositoryProvider)
          .reportCallPresentation(
            sessionId,
            state: 'ESTABLISHED',
            platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
            detail: 'in-app incoming call surface presented',
          )
          .catchError((_) {
            // A ring that could not be reported is still a ring. Allow a later
            // attempt rather than pretending it was recorded.
            _presentedSessionIds.remove(sessionId);
          }),
    );
  }

  void _ensureRingTimer(Map<String, dynamic> item) {
    final id = _stringOf(item['id']);
    if (id == _ringTimerNotificationId) return;
    _ringTimer?.cancel();
    _ringTimerNotificationId = id;
    _ringTimer = Timer(_ringTimeout, () {
      // context.mounted checks _lifecycleState == active, unlike State.mounted
      // which only checks _element != null and returns true during inactive.
      if (!context.mounted) return;
      final sessionId = _resolveSessionId(item);
      if (id.isNotEmpty) _dismissedIds.add(id);
      if (sessionId.isNotEmpty) _dismissedSessionIds.add(sessionId);
      ref.read(incomingCallBridgeProvider.notifier).remove(id);
      if (id.isNotEmpty) {
        unawaited(
          ref.read(notificationsControllerProvider.notifier).markRead(id),
        );
      }
      setState(() {
        _joinError = null;
        _joinErrorSessionId = null;
      });
    });
  }

  void _cancelRingTimer() {
    _ringTimer?.cancel();
    _ringTimer = null;
    _ringTimerNotificationId = null;
  }

  /// Foreground incoming-call presentation: one audible + haptic cue per
  /// genuinely new incoming call, on every platform where the framework
  /// supports it (`HapticFeedback`/`SystemSound` are safe no-ops elsewhere —
  /// no platform branching needed). This deliberately does not attempt a
  /// looping ringtone: Android's existing "already-working" behavior it must
  /// preserve is a single OS-channel alert burst, not an app-driven loop, so
  /// a single cue here is consistent rather than inventing new behavior.
  void _triggerIncomingCallAlert(String sessionId) {
    if (sessionId.isEmpty) return;
    // ONE CALL, ONE ALERT. Since 2026-08-25 an Android call that arrives while
    // the app is backgrounded is already ringing natively, for the invite's
    // whole window. Sounding this in-app alert on top of it would make one
    // call alert twice — the same duplication this chapter has been removing
    // everywhere else. This alert exists for the case the native ring does
    // not cover: a call that arrives with the app already in front of you.
    if (_nativeRingingSessionIds.contains(sessionId)) return;
    unawaited(SystemSound.play(SystemSoundType.alert));
    unawaited(HapticFeedback.heavyImpact());
  }

  /// Sessions whose ring is being sounded by the native call surface.
  final Set<String> _nativeRingingSessionIds = <String>{};

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _joinCurrent(Map<String, dynamic> item) async {
    debugPrint('[join-diag] _joinCurrent called, _joining=$_joining item.id=${item['id']}');
    if (_joining) {
      debugPrint('[join-diag] _joinCurrent early-return: already _joining (stale guard candidate)');
      return;
    }

    final data = _mapOf(item['data']);
    final target = _resolver.resolveFromPayload({...item, ...data});
    final sessionId = _firstNonEmpty([
      _resolveSessionId(item),
      target.sessionId ?? '',
    ]);

    if (sessionId.isEmpty) {
      debugPrint('[join-diag] _joinCurrent early-return: empty sessionId');
      return;
    }
    debugPrint('[join-diag] _joinCurrent proceeding sessionId=$sessionId');

    _cancelRingTimer();
    // Native notification cancellation now happens centrally in build()'s
    // bridge-removal listener (see the "single authoritative choke point"
    // comment there) — it fires the moment `.remove(id)` below changes the
    // bridge state, covering this and every other termination path
    // uniformly instead of duplicating the call at each action site.

    // Capture all context-derived values BEFORE any await.
    // Read the router via its Riverpod provider, not GoRouter.of(context) —
    // this widget is mounted inside MaterialApp.router's `builder` parameter
    // (app-root, wraps the whole routed tree), so its OWN context has no
    // InheritedGoRouter ancestor and GoRouter.of(context) throws a null-check
    // failure here (proven by device logs: the identical call inside
    // `_currentUri` only "worked" because it silently swallows the same
    // failure in a try/catch and falls back to '/'). The provider gives the
    // same GoRouter singleton without depending on tree position.
    final router = ref.read(routerProvider);
    final returnTo = Uri.encodeComponent(_currentUri(router).toString());

    setState(() {
      _joining = true;
      _joinError = null;
      _joinErrorSessionId = null;
    });
    _startAcceptWatchdog(sessionId);

    final id = _stringOf(item['id']);
    _dismissedSessionIds.add(sessionId);
    try {
      await ref
          .read(threadCallLifecycleProvider.notifier)
          .acceptIncomingCall(item);
      // remove() reports the CallKit call DECLINED — on the accept button.
      // It ended the call and mislabelled it in the system call log.
      ref.read(incomingCallBridgeProvider.notifier).removeAccepted(id);
      if (id.isNotEmpty) {
        // Best-effort — marking the notification read must never surface
        // as a join failure. Previously awaited inline: a transient
        // failure here (found via live device testing) fell into the same
        // catch block as a real join failure and showed "Could not join
        // the call" with Retry/Dismiss even though acceptIncomingCall
        // above — the actual join — had already succeeded.
        unawaited(
          ref
              .read(notificationsControllerProvider.notifier)
              .markRead(id)
              .catchError((_) {}),
        );
      }

      if (!context.mounted) return;
      final joinedSession = ref.read(realtimeControllerProvider).session;
      if (joinedSession?.surfaceType == RealtimeSurfaceType.meeting) {
        final meetingId = (joinedSession!.surfaceId ?? '').trim();
        if (meetingId.isNotEmpty) {
          router.go('/meetings/$meetingId/live?sessionId=$sessionId');
        } else {
          // Accepting IS the intent, so it belongs in the address.
          // Without `action=join` the room mounted able to conclude the
          // person had not asked to join, and instructed them to accept
          // again — the classical stall, measured live 2026-08-22.
          router.go(NavigationAuthority.realtimeSessionJoinRoute(
            sessionId,
            returnTo: returnTo,
          ));
        }
      } else {
        // Accepting IS the intent, so it belongs in the address.
        // Without `action=join` the room mounted able to conclude the
        // person had not asked to join, and instructed them to accept
        // again — the classical stall, measured live 2026-08-22.
        router.go(NavigationAuthority.realtimeSessionJoinRoute(
          sessionId,
          returnTo: returnTo,
        ));
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      final isExpired =
          msg.contains('invite_expired') ||
          msg.contains('session_closed') ||
          msg.contains('invite has expired');
      if (isExpired) {
        // Invite is no longer valid — dismiss the overlay silently.
        ref.read(incomingCallBridgeProvider.notifier).remove(id);
        if (context.mounted) {
          setState(() {
            _joinError = 'This call is no longer available.';
            _joinErrorSessionId = sessionId;
          });
        }
        // Store so it can be cancelled in dispose(); cancel any prior timer.
        _joinErrorTimer?.cancel();
        _joinErrorTimer = Timer(const Duration(seconds: 3), () {
          _joinErrorTimer = null;
          if (context.mounted) {
            _dismissedIds.add(id);
            setState(() {
              _joinError = null;
              _joinErrorSessionId = null;
            });
          }
        });
      } else {
        // Transient join failure — let user retry or dismiss.
        _dismissedSessionIds.remove(sessionId);
        if (context.mounted) {
          setState(() {
            _joinError = 'Could not join the call. Check your connection.';
            _joinErrorSessionId = sessionId;
          });
        }
      }
    } finally {
      // PERMANENT ACCEPT-FREEZE FIX (founder-proven 2026-08-17, "accept
      // spinning freeze is there for every other call... you have to hard
      // refresh"): this overlay is mounted in MaterialApp.router's builder
      // — app-root, wrapping the whole routed tree — so router.go() does
      // NOT unmount it. The old `if (!navigated)` guard therefore left
      // _joining latched TRUE forever after the first accepted call, and
      // `onAccept: _joining ? null : …` disabled Accept permanently for
      // every subsequent call, with the spinner still painted. _joining is
      // per-attempt state and must ALWAYS be released; the setState is
      // deferred to a post-frame callback so it can never run against an
      // element that this frame's navigation just deactivated.
      _joining = false;
      _cancelAcceptWatchdog();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _cancelAcceptWatchdog() {
    _acceptWatchdog?.cancel();
    _acceptWatchdog = null;
  }

  /// Second, independent guarantee that an Accept can never spin forever:
  /// whatever happens below (a stranded in-flight join future, a socket
  /// that never acks, a future regression in the join stack), the button
  /// returns to an actionable state within a bounded window and tells the
  /// truth. Never cancels the underlying join — a late success still lands.
  void _startAcceptWatchdog(String sessionId) {
    _cancelAcceptWatchdog();
    _acceptWatchdog = Timer(const Duration(seconds: 30), () {
      _acceptWatchdog = null;
      if (!mounted || !_joining) return;
      final joined = ref.read(realtimeControllerProvider).isJoined;
      setState(() {
        _joining = false;
        if (!joined) {
          _joinError = 'Still connecting — retry, or decline the call.';
          _joinErrorSessionId = sessionId;
          // Re-offer the card: this session is no longer "handled".
          _dismissedSessionIds.remove(sessionId);
        }
      });
    });
  }

  Future<void> _retryJoin(Map<String, dynamic> item) async {
    setState(() {
        _joinError = null;
        _joinErrorSessionId = null;
      });
    await _joinCurrent(item);
  }

  final Set<String> _consumedNativeActions = <String>{};

  void _executePendingNativeAction(List<Map<String, dynamic>> items) {
    for (final item in items) {
      final action = _stringOf(item['_auraNativeAction']);
      if (action != 'answer' && action != 'decline') continue;

      final sessionId = _resolveSessionId(item);
      final key = sessionId.isNotEmpty ? sessionId : _stringOf(item['id']);
      if (key.isEmpty) continue;
      // Once only: the bridge list is rebuilt on every change, and acting
      // twice would either double-join or decline a call already accepted.
      if (!_consumedNativeActions.add(key)) continue;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (action == 'decline') {
          unawaited(_declineCurrent(item));
        } else {
          unawaited(_joinCurrent(item));
        }
      });
    }
  }

  Future<void> _declineCurrent(Map<String, dynamic> item) async {
    _cancelRingTimer();
    // See _joinCurrent — native notification cancellation is centralized in
    // build()'s bridge-removal listener now.
    final id = _stringOf(item['id']);
    if (id.isNotEmpty) _dismissedIds.add(id);

    final sessionId = _resolveSessionId(item);
    if (sessionId.isNotEmpty) _dismissedSessionIds.add(sessionId);

    // Remove from socket bridge and dismiss overlay immediately.
    ref.read(incomingCallBridgeProvider.notifier).remove(id);
    if (mounted) {
      setState(() {
        _joinError = null;
        _joinErrorSessionId = null;
      });
    }

    // Authoritative decline: awaited so the backend reflects the decision.
    if (sessionId.isNotEmpty) {
      try {
        await ref.read(realtimeRepositoryProvider).declineInvite(sessionId);
      } catch (_) {
        // Local dismiss already applied; backend will clean up on session timeout.
      }
    }

    if (id.isNotEmpty) {
      try {
        await ref.read(notificationsControllerProvider.notifier).markRead(id);
      } catch (_) {}
    }
  }

  void _dismissError(Map<String, dynamic> item) {
    _cancelRingTimer();
    final id = _stringOf(item['id']);
    if (id.isNotEmpty) _dismissedIds.add(id);
    final sessionId = _resolveSessionId(item);
    if (sessionId.isNotEmpty) _dismissedSessionIds.add(sessionId);
    ref.read(incomingCallBridgeProvider.notifier).remove(id);
    setState(() {
        _joinError = null;
        _joinErrorSessionId = null;
      });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_kBypassOverlay) {
      return widget.child;
    }
    // C4: when the bridge drops a session (because a terminal/removed event
    // arrived on either the correspondence or realtime socket), dismiss any
    // matching poll item so a stale notification cannot re-render the card
    // before the next poll. Mirrors the dedup the bridge already does on
    // its own state.
    ref.listen<List<Map<String, dynamic>>>(incomingCallBridgeProvider, (
      prev,
      next,
    ) {
      if (!mounted) return;
      final prevSet = <String>{
        for (final item in prev ?? const <Map<String, dynamic>>[])
          if (_resolveSessionId(item).isNotEmpty) _resolveSessionId(item),
      };
      final nextSet = <String>{
        for (final item in next)
          if (_resolveSessionId(item).isNotEmpty) _resolveSessionId(item),
      };
      final removedSessions = prevSet.difference(nextSet);
      for (final removed in removedSessions) {
        _dismissedSessionIds.add(removed);
      }
      if (removedSessions.isNotEmpty) {
        // 2026-08-14 — single authoritative choke point for cancelling the
        // native Android ring notification (see
        // native_call_notification_channel.dart). Every path that ends
        // ringing — accept, decline, the 90s ring-timeout, a remote
        // cancel/decline/expiry, or another device answering first —
        // removes the session from this bridge, so cancelling here (instead
        // of at each individual action site) guarantees notification
        // presentation follows lifecycle truth rather than best-effort calls
        // scattered across action handlers that can't see remote-driven
        // removals. Previously only wired into local accept/decline, which
        // is why stale ringing notifications were observed stacking up in
        // the shade after remote-driven call endings.
        unawaited(cancelNativeCallNotifications());
      }

      // 2026-08-14 repair — foreground incoming-call audible + haptic alert.
      // Governed by the SAME dedup this bridge already performs (by
      // sessionId/notification id, merging the correspondence socket, the
      // /realtime socket, and foreground FCM) — a newly-added session id
      // here is guaranteed to be a genuinely new incoming call, not a
      // duplicate delivery from a second transport. One alert per newly
      // seen session; ends implicitly (nothing loops) the moment the
      // session leaves the bridge via accept/decline/cancel/expiry/terminal,
      // all of which already remove it from `next` above.
      for (final item in next) {
        if (_stringOf(item['_auraLifecycleSource']) != 'nativeCall') continue;
        final sid = _resolveSessionId(item);
        if (sid.isNotEmpty) _nativeRingingSessionIds.add(sid);
      }
      for (final added in nextSet.difference(prevSet)) {
        _triggerIncomingCallAlert(added);
      }

      // AN EXPLICIT ACT ON THE CALL NOTIFICATION IS THE ACT ITSELF.
      //
      // Android's incoming-call notification carries real Answer and Decline
      // controls (2026-08-25). Pressing one is unambiguous, so it must not be
      // answered with a second Accept/Decline card asking the same question.
      // The act arrives on the bridge item as `_auraNativeAction` and is
      // executed HERE — through the same _joinCurrent / _declineCurrent this
      // overlay already owns — so there is exactly one accept path and one
      // decline path in the app, not a shadow pair behind a notification.
      //
      // Only `answer` and `decline` act. `open` — the notification body and
      // the full-screen call surface — deliberately falls through to the card,
      // preserving the founder ruling of 2026-08-14 that a tap must offer the
      // choice rather than join on the recipient's behalf.
      _executePendingNativeAction(next);
    });

    final notifications = ref.watch(notificationsControllerProvider);
    final bridgeItems = ref.watch(incomingCallBridgeProvider);
    final liveState = ref.watch(realtimeControllerProvider);
    final currentPath = _currentUri(ref.read(routerProvider)).path;

    if (liveState.session?.surfaceType == RealtimeSurfaceType.meeting) {
      _cancelRingTimer();
      return widget.child;
    }

    // C3: cross-source dedup. Bridge (correspondence socket) takes priority
    // over poll (notifications API + FCM-triggered refresh) so the same call
    // never produces two ringing cards even when both transports deliver the
    // same event. Then dedup the merged stream by sessionId AND notification
    // id so a payload that appears once via socket and once via FCM-poll only
    // surfaces once. Items with no sessionId or id (rare; malformed payload)
    // pass through to a separate fallback bucket.
    final allItems = <Map<String, dynamic>>[];
    final seenSessionIds = <String>{};
    final seenIds = <String>{};
    for (final source in [bridgeItems, notifications.items]) {
      for (final item in source) {
        final sid = _resolveSessionId(item);
        final id = _stringOf(item['id']);
        if (sid.isNotEmpty && seenSessionIds.contains(sid)) continue;
        if (id.isNotEmpty && seenIds.contains(id)) continue;
        if (sid.isNotEmpty) seenSessionIds.add(sid);
        if (id.isNotEmpty) seenIds.add(id);
        allItems.add(item);
      }
    }

    final item = _currentIncoming(currentPath, allItems, liveState);
    if (item == null) {
      _cancelRingTimer();
      if (!liveState.isJoined) {
        return widget.child;
      }
      // Active local call — keep PiP overlay mounted so the card persists
      // when the user navigates away from the /realtime screen.
      return Stack(
        children: [
          widget.child,
          if (liveState.isJoined && !_kBypassPiP) const FloatingCallWidget(),
        ],
      );
    }

    _ensureRingTimer(item);
    // The card is about to be built for this person: this device is alerting
    // them, and that is the one fact that entitles the caller to see
    // "Ringing…". Reported once per session.
    _reportPresented(item);

    final data = _mapOf(item['data']);
    final actor = _mapOf(item['actor']);

    // F052/F053 — a ringing call names the caller through the canonical
    // model. This is the surface class F057 broke: it resolved identity by
    // hand and could disagree with the thread the call belongs to.
    final person = AuraPersonIdentity.fromJson(actor);

    // WHO IS CALLING.
    //
    // Read from the canonical actor ALONE. Measured on a physical Pixel: a
    // push-delivered ring arrives with no `actor` block and the caller flat at
    // the top level, which is why this card announced "Someone" for a fully
    // governed identity.
    //
    // That is now reconciled where the two payload shapes meet — see
    // `IncomingCallBridge._normalizeIncomingPayload`, which folds the flat
    // caller fields back into the canonical actor envelope. This surface asks
    // one question of one authority, with no per-surface fallback to drift.
    final actorName = person.label;
    // Caller identity hydration: the canonical actor payload
    // (buildCanonicalIncomingCallNotification, aura-backend) already
    // carries a real avatarUrl end to end — it was resolved but never
    // rendered here, falling back to a generic initial-letter avatar even
    // when the caller's real photo was available.
    final actorAvatarUrl = person.avatarUrl ?? '';

    final target = _resolver.resolveFromPayload({...item, ...data});
    final mode = _firstNonEmpty([
      _stringOf(data['callKind']),
      _stringOf(data['mediaMode']),
      _stringOf(data['mode']),
      target.mode ?? '',
    ]).toLowerCase();
    final contextName = _firstNonEmpty([
      target.context ?? '',
      _stringOf(data['contextName']),
      'this conversation',
    ]);
    final ownerType = _stringOf(data['ownerType']).toUpperCase();

    final title = ownerType == 'SPACE'
        ? '${mode == 'video' ? 'Video' : 'Audio'} is live in $contextName'
        : mode == 'video'
        ? '$actorName started a video call'
        : '$actorName started an audio call';

    final isVideo = mode == 'video';
    final ringLabel = isVideo ? 'Incoming video call' : 'Incoming audio call';

    // Phase 1/2/5 precedence: a stale local join-failure for THIS exact
    // session must not render once authoritative state says that session
    // is actually joined — see joinErrorIsStale's doc comment. A genuinely
    // different failure (different session, or none) is unaffected.
    final effectiveJoinError = joinErrorIsStale(
      joinErrorSessionId: _joinErrorSessionId,
      isJoined: liveState.isJoined,
      liveSessionId: liveState.sessionId,
    )
        ? null
        : _joinError;

    // While a ringing card is on screen the user is in the "decide whether to
    // accept" phase — the PiP must not render. Otherwise a stale joined state
    // from a previous session would put a small floating widget at the bottom
    // that the user mistakes for the call surface and misses the Accept card.
    return Stack(
      children: [
        widget.child,
        Positioned(
          right: MediaQuery.of(context).size.width >= 700
              ? AuraSpace.s20
              : AuraSpace.s12,
          left: MediaQuery.of(context).size.width >= 700 ? null : AuraSpace.s12,
          bottom: MediaQuery.of(context).size.width >= 700
              ? AuraSpace.s20
              : AuraSpace.s12,
          child: SafeArea(
            child: _IncomingCallCard(
              actorName: actorName,
              actorAvatarUrl: actorAvatarUrl,
              title: title,
              ringLabel: ringLabel,
              isVideo: isVideo,
              joining: _joining,
              joinError: effectiveJoinError,
              pulseAnim: _pulseAnim,
              onAccept: _joining ? null : () => _joinCurrent(item),
              onDecline: _joining ? null : () => _declineCurrent(item),
              onDismissError: () => _dismissError(item),
              onRetry: () => _retryJoin(item),
            ),
          ),
        ),
      ],
    );
  }
}

class _IncomingCallCard extends StatelessWidget {
  const _IncomingCallCard({
    required this.actorName,
    this.actorAvatarUrl,
    required this.title,
    required this.ringLabel,
    required this.isVideo,
    required this.joining,
    required this.joinError,
    required this.pulseAnim,
    required this.onAccept,
    required this.onDecline,
    required this.onDismissError,
    required this.onRetry,
  });

  final String actorName;
  final String? actorAvatarUrl;
  final String title;
  final String ringLabel;
  final bool isVideo;
  final bool joining;
  final String? joinError;
  final Animation<double> pulseAnim;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback onDismissError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ringColor = isVideo ? AuraSurface.accent : AuraSurface.coVerdant;
    // Material ancestor is MANDATORY here (founder evidence 2026-08-17):
    // this card renders in a root overlay Stack; without Material every
    // Text that inherits any style falls back to the framework's
    // yellow-double-underline error style — the exact "ugly confusing"
    // ring card observed on both browser and mobile at ring start.
    return Material(
      type: MaterialType.transparency,
      child: Container(
      width: 360,
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: const Color(0xF20D1520),
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        border: Border.all(color: ringColor.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: pulseAnim,
                builder: (context, child) {
                  final pulseOpacity = joining ? 0.0 : pulseAnim.value;
                  return Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ringColor.withValues(
                          alpha: 0.35 + pulseOpacity * 0.25,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ringColor.withValues(
                            alpha: pulseOpacity * 0.26,
                          ),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: AuraAvatar(
                      name: actorName,
                      imageUrl: actorAvatarUrl,
                      size: 52,
                    ),
                  );
                },
              ),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                          size: 15,
                          color: ringColor,
                        ),
                        const SizedBox(width: AuraSpace.s6),
                        Expanded(
                          child: Text(
                            ringLabel,
                            style: AuraText.small.copyWith(
                              color: ringColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AuraSpace.s4),
                    Text(
                      actorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AuraText.title.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: AuraSpace.s2),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AuraText.small.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (joinError != null) ...[
            const SizedBox(height: AuraSpace.s12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AuraSpace.s10),
              decoration: BoxDecoration(
                color: AuraSurface.coRose.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AuraRadius.md),
                border: Border.all(
                  color: AuraSurface.coRose.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                joinError!,
                style: AuraText.small.copyWith(
                  color: AuraSurface.coRose,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: AuraSpace.s14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (joinError != null) ...[
                _GhostCallButton(label: 'Dismiss', onTap: onDismissError),
                const SizedBox(width: AuraSpace.s10),
                _GhostCallButton(label: 'Retry', onTap: onRetry, accent: true),
              ] else ...[
                _CallCircleButton(
                  icon: Icons.call_end_rounded,
                  color: AuraSurface.coRose,
                  background: AuraSurface.coRose.withValues(alpha: 0.16),
                  size: 48,
                  onTap: onDecline,
                ),
                const SizedBox(width: AuraSpace.s14),
                _CallCircleButton(
                  icon: isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                  color: Colors.white,
                  background: isVideo
                      ? AuraSurface.accent
                      : AuraSurface.coVerdant,
                  size: 54,
                  onTap: onAccept,
                  busy: joining,
                ),
              ],
            ],
          ),
        ],
      ),
      ),
    );
  }
}

// ── Call buttons ──────────────────────────────────────────────────────────────

class _CallCircleButton extends StatelessWidget {
  const _CallCircleButton({
    required this.icon,
    required this.color,
    required this.background,
    required this.size,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final double size;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: background.withValues(alpha: 0.4),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: busy
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              : Icon(icon, size: size * 0.38, color: color),
        ),
      ),
    );
  }
}

class _GhostCallButton extends StatelessWidget {
  const _GhostCallButton({
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: accent
                ? AuraSurface.accent.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AuraRadius.pill),
            border: Border.all(
              color: accent
                  ? AuraSurface.accent.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.15),
            ),
          ),
          child: Text(
            label,
            style: AuraText.small.copyWith(
              fontWeight: FontWeight.w700,
              color: accent ? AuraSurface.accentText : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Primitive helpers (module-private) ────────────────────────────────────────

Map<String, dynamic> _mapOf(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return const <String, dynamic>{};
}

String _stringOf(dynamic value) {
  if (value == null) return '';
  return value.toString().trim();
}

String _firstNonEmpty(List<String> values) {
  for (final value in values) {
    if (value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

Uri _currentUri(GoRouter router) {
  try {
    return router.routerDelegate.currentConfiguration.uri;
  } catch (_) {
    return Uri(path: '/');
  }
}
