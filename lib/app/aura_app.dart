import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_broadcast.dart';
import '../core/notifications/android_telecom.dart';
import '../core/notifications/ios_call_kit.dart';
import '../core/notifications/native_call_actions.dart';
import '../core/auth/auth_providers.dart';
import '../core/auth/session_bootstrap.dart';
import '../core/auth/session_providers.dart';
import '../core/interactions/presence_repository.dart';
import '../core/media/media_url_resolver.dart';
import '../core/navigation/boot_gate.dart';
import '../core/release_governance/update_gate.dart';
import '../core/ui/aura_radius.dart';
import '../core/ui/aura_surface.dart';
import '../core/ui/aura_text.dart';
import '../core/notifications/notification_bridge.dart';
import '../features/correspondence/data/correspondence_live_service.dart';
import '../features/devices/device_providers.dart';
import '../features/realtime/application/realtime_providers.dart';
import '../features/realtime/domain/realtime_enums.dart';
import '../features/realtime/application/thread_call_lifecycle_controller.dart';
import '../features/share_intake/application/share_intake_channel.dart';
import '../features/share_intake/application/share_intake_inbox.dart';
import '../features/share_intake/domain/acquisition_envelope.dart';
import '../features/realtime/data/realtime_reconciliation_controller.dart';
import '../features/realtime/presentation/thread_call_lifecycle_host.dart';
import '../features/realtime/presentation/widgets/orphaned_session_banner.dart';
import '../features/updates/incoming_call_bridge.dart';
import '../router.dart';
import '../core/navigation/navigation_authority.dart';

class AuraApp extends ConsumerStatefulWidget {
  const AuraApp({super.key});

  @override
  ConsumerState<AuraApp> createState() => _AuraAppState();
}

class _AuraAppState extends ConsumerState<AuraApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Cross-tab logout fan-out: when a sibling tab calls
    // AuthBroadcast.publishLogout(), every other tab on this origin runs
    // the local-clear path here. We deliberately do NOT call the backend
    // logout endpoint — the originating tab already did that. This keeps
    // the cleanup quiet and idempotent. Login events trigger a soft
    // refresh of auth-derived providers so a stale signed-out tab catches
    // up without forcing a hard reload.
    AuthBroadcast.start(onMessage: _onRemoteAuthEvent);

    // NATIVE CALL ARRIVAL (iOS). No-op on every other platform.
    //
    // Bound before the first frame because a PushKit push can already have put
    // a CallKit screen on the lock screen while this app was terminated — the
    // native side buffers those events and releases them the moment `start()`
    // reports ready. Binding later would answer into nothing.
    _bindNativeCallArrival();

    // TRACK C — ANDROID'S CALL STACK ACTING ON A CALL.
    //
    // Bound beside the iOS binding because it is the same kind of thing: the
    // operating system doing something to a call, which Aura then has to make
    // true. No-op on every platform but Android.
    _bindNativeTelecom();

    // OS SHARE ARRIVAL. No-op on every platform that has not implemented the
    // channel, and deliberately without asking which platform this is.
    //
    // Bound before the first frame for the same reason as the call binding: a
    // share can be what LAUNCHED the app, in which case the content is already
    // waiting natively and Dart has to ask for it. Binding later means the
    // person shares a photograph, Aura opens, and the photograph is not there.
    unawaited(ref.read(shareIntakeChannelProvider).start());

    // Register device if already authed at startup (stored token from prior session)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(isAuthedProvider)) {
        try {
          ref.read(deviceServiceProvider).registerCurrentDevice();
        } catch (_) {}
      }
      // R3 — Boot the cross-device reconciliation controller. The
      // controller subscribes to the correspondence socket and
      // converts incoming `post:interaction.changed` / `follow:state
      // .changed` / `socket:connected` events into canonical-provider
      // invalidations so a mutation on one session converges on the
      // others. The read is idempotent — the provider is a long-lived
      // singleton scoped to the ProviderScope.
      try {
        ref.read(realtimeReconciliationProvider);
      } catch (_) {
        // Reconciliation is best-effort; failure here must never
        // prevent the app from booting.
      }
    });
  }

  /// Send a CallKit presentation outcome to the backend.
  ///
  /// Reuses the stage diagnostic channel rather than inventing an endpoint:
  /// same shape, same authority, and it already carries client-side truth the
  /// server cannot otherwise see. Best-effort and never awaited — diagnosing a
  /// call must not delay answering one.
  void _reportCallKit(String sessionId, String code, String message) {
    if (sessionId.isEmpty) return;
    try {
      unawaited(
        ref.read(realtimeRepositoryProvider).reportStageDiagnostic(
              sessionId,
              phase: 'callkit',
              code: code,
              message: message,
              platform: 'iOS',
            ),
      );
    } catch (_) {
      // Observability is never worth a crash.
    }
  }

  /// WHETHER THIS PHONE ACTUALLY RANG — reported to the one authority that
  /// decides whether the fallback banner is still owed.
  ///
  /// The server suppresses this phone's ordinary notification on the
  /// expectation that CallKit will present, then waits a bounded moment for
  /// this report. Saying ESTABLISHED keeps the fallback silent; saying
  /// REJECTED brings it immediately; saying nothing at all lets the grace
  /// period bring it. Every direction degrades toward the phone ringing.
  void _reportPresentation(String sessionId, String state, [String? detail]) {
    if (sessionId.isEmpty) return;
    try {
      unawaited(
        ref.read(realtimeRepositoryProvider).reportCallPresentation(
              sessionId,
              state: state,
              platform: 'iOS',
              detail: detail,
            ),
      );
    } catch (_) {
      // Observability is never worth a crash — and the server's grace period
      // already treats silence as "did not ring".
    }
  }

  /// Wire the native incoming-call surface to Aura's own authorities.
  ///
  /// Everything here is a translation, never a decision: a VoIP token becomes a
  /// device registration, a CallKit answer becomes a join through the existing
  /// lifecycle controller, and a CallKit decline becomes the same local removal
  /// the in-app card performs. The backend stays the authority on whether the
  /// call exists at all.
  void _bindNativeCallArrival() {
    final callKit = IosCallKit.instance;
    if (!callKit.isSupported) return;

    callKit.onVoipToken = (token) async {
      try {
        await ref.read(deviceServiceProvider).registerVoipToken(token);
      } catch (e) {
        debugPrint('[callkit] voip token registration failed: $e');
      }
    };

    // ONE CALL, ONE CANONICAL STATE — INCLUDING WHEN THE PUSH IS WHAT ARRIVED.
    //
    // CallKit and Aura's own incoming-call state were independent systems on
    // iOS. `IosCallKit.onIncomingCall` existed and was bound by nobody, so a
    // VoIP-delivered invitation reached the system call screen and never
    // reached `incomingCallBridgeProvider`. Everything downstream of that
    // bridge — the in-app card, the ring alert, terminal reconciliation, the
    // payload the accept path prefers — was therefore blind to any call that
    // arrived by push rather than by socket. Two surfaces, two opinions, one
    // call.
    //
    // The bridge is the single authority, so the native arrival is folded into
    // it in the shape every other transport already uses. It dedupes by
    // sessionId, so the socket's `call:incoming` landing a moment later is
    // harmless — whichever arrives first wins and the other is absorbed.
    callKit.onPushReceived = (sessionId) async {
      _reportCallKit(sessionId, 'push_received', 'PushKit handler reached report');
    };

    callKit.onIncomingCall = (payload) async {
      final sessionId = '${payload['sessionId'] ?? ''}'.trim();
      if (sessionId.isEmpty) return;
      final raw = <String, dynamic>{};
      final nativeRaw = payload['raw'];
      if (nativeRaw is Map) {
        nativeRaw.forEach((k, v) => raw['$k'] = v);
      }
      String pick(String key) => '${raw[key] ?? ''}'.trim();

      try {
        ref.read(incomingCallBridgeProvider.notifier).addIncoming({
          // The invite id is the notification identity everywhere else; the
          // session is the fallback so a payload without one still registers
          // rather than being dropped by addIncoming's empty-id guard.
          'id': pick('inviteId').isNotEmpty ? pick('inviteId') : sessionId,
          'notificationKind': 'CALL_RINGING',
          '_auraLifecycleSource': 'nativeCall',
          'data': <String, dynamic>{
            'sessionId': sessionId,
            'realtimeSessionId': pick('realtimeSessionId'),
            'inviteId': pick('inviteId'),
            // The overlay refuses anything that is not an INTERRUPT, and a
            // ringing call is the definition of one.
            'attention': 'INTERRUPT',
            'callState': 'RINGING',
            'mediaMode': pick('mediaMode'),
            'callKind': pick('mediaMode'),
            'expiresAt': pick('expiresAt'),
            'callerDisplayName': pick('callerDisplayName'),
            'callerHandle': pick('callerHandle'),
            'deeplink': pick('deeplink'),
            // Where the call belongs. Without these the thread projection has
            // no canonical identifier to match on and a push-delivered call
            // could only ever be shown as a global event.
            'correspondenceId': pick('correspondenceId'),
            'threadId': pick('threadId'),
            'spaceId': pick('spaceId'),
          },
        });
      } catch (e) {
        debugPrint('[callkit] bridging native arrival failed: $e');
      }

      // WHAT CALLKIT ACTUALLY DID, WHERE I CAN SEE IT.
      //
      // The server can prove a VoIP push was accepted and that the app woke —
      // the device row updates a second later — and then the trail stops. Every
      // remaining question about a phone that does not ring lives on the far
      // side of that gap, and guessing across it has cost real device tests.
      // `reportNewIncomingCall` succeeded here, so this records that fact; the
      // refusal path below records the reason iOS gave.
      _reportCallKit(sessionId, 'presented', 'reportNewIncomingCall succeeded');
      // The phone rang. The fallback is not owed.
      _reportPresentation(sessionId, 'ESTABLISHED');
    };

    // THE SYSTEM STOPPED SHOWING THE CALL. THE CALL MAY STILL BE LIVE.
    //
    // iOS retires an unanswered CallKit call on its own schedule, which is
    // shorter than Aura's 90s invitation TTL and not ours to configure. When
    // that happens the invitation is often still answerable — and build 35 had
    // no answer for that state, which is why a locked iPhone's call "became
    // buried" and the only recovery was opening the app.
    //
    // The recovery is deliberately small, because the correct state already
    // exists: the in-app card is in the bridge, the backend still owns the
    // invitation, and native has already retracted the notification so nothing
    // stale competes. All that is needed is to drop the card if the invite has
    // since expired, and to say the lapse happened so it stops being invisible.
    //
    // Nothing here fabricates a terminal state. A lapsed SYSTEM presentation is
    // not a declined, cancelled or ended CALL, and treating it as one would
    // hang up a call the person can still answer.
    callKit.onSystemPresentationLapsed = (sessionId) async {
      _reportCallKit(
        sessionId,
        'presentation_lapsed',
        'system call UI retired while the invitation may still be live',
      );
      _reportPresentation(sessionId, 'LAPSED');
      if (!mounted) return;
      try {
        ref.read(incomingCallBridgeProvider.notifier).evictExpired();
      } catch (e) {
        debugPrint('[callkit] lapse reconciliation failed: $e');
      }
    };

    callKit.onVoipTokenInvalidated = () async {
      try {
        await ref.read(deviceServiceProvider).deactivateVoipDevice();
      } catch (_) {}
    };

    // ANSWERING FROM A LOCK SCREEN IS A COLD START, AND AUTH LOADS ASYNC.
    //
    // Physical evidence, build 28: the CallKit screen appeared and answering
    // left the caller waiting. The answer arrives the instant Dart says
    // `ready`, which is during initState — before TokenStore.load() has
    // finished restoring the session. The join then ran unauthenticated,
    // failed, and reported `failed` to CallKit, which is exactly what a
    // caller left ringing into nothing looks like from the other side.
    //
    // So the answer waits for Aura to actually be able to act, bounded.
    //
    // THE BUDGET WAS SIX SECONDS, AND SIX SECONDS ENDED CALLS. Founder, build
    // 34: "i try to press as it ring but it cut off". Answering during a cold
    // launch — engine booting, TokenStore restoring, all triggered by the VoIP
    // push itself — can exceed six seconds, and on timeout this path reports
    // the call `failed`, which hangs it up. The person pressed Answer and
    // Aura ended their call for them.
    //
    // The ceiling now sits inside the server's ring window rather than under
    // it, so a slow restore costs a moment of "connecting" instead of the
    // call. It stays bounded and still reports `failed` honestly if identity
    // genuinely never arrives — waiting forever on a call that cannot be
    // joined would be its own kind of lie.
    Future<bool> awaitAuthed() async {
      const step = Duration(milliseconds: 150);
      for (var i = 0; i < 200; i++) {
        if (!mounted) return false;
        if (ref.read(isAuthedProvider)) return true;
        await Future<void>.delayed(step);
      }
      return ref.read(isAuthedProvider);
    }

    callKit.onAnswer = (sessionId) async {
      // ANSWERING IS THE DESTINATION. SET IT NOW, NOT WHEN THE JOIN RETURNS.
      //
      // Navigating only after auth restore and the join meant a lock-screen
      // answer landed on Aura's home screen first and arrived at the call
      // seconds later — founder, build 33: "took me to aura home then after a
      // while call surfaced normally". Correct destination, wrong moment.
      //
      // Setting the location immediately is safe during a cold start: the
      // router deliberately stays put while the session is restoring and
      // BootGate renders the restoring state IN PLACE of the routed child, so
      // the call screen mounts when auth is known rather than firing requests
      // before it. The person answers a call and the call is what boots.
      //
      // Re-asserted after the join, where the meeting branch is finally
      // knowable; going to the same location twice costs nothing.
      if (mounted) {
        try {
          ref
              .read(routerProvider)
              .go(NavigationAuthority.realtimeSessionJoinRoute(sessionId));
        } catch (e) {
          debugPrint('[callkit] early answer navigation failed: $e');
        }
      }

      // The system sheet already reads "connecting". If the join fails we must
      // say so rather than leave it there — a CallKit call connected to nothing
      // is worse than one that ends honestly.
      final authed = await awaitAuthed();
      debugPrint('[callkit] answer session=$sessionId authed=$authed');
      if (!authed) {
        // Nothing can be joined without an identity. Say so rather than hold
        // the system call UI open on a call that cannot proceed.
        await callKit.reportEnded(sessionId, reason: 'failed');
        return;
      }
      try {
        final controller = ref.read(threadCallLifecycleProvider.notifier);
        // Prefer the invite payload the socket already delivered; a cold start
        // from a VoIP push has none, and the session id is enough to join on.
        final payload = ref
            .read(incomingCallBridgeProvider)
            .cast<Map<String, dynamic>?>()
            .firstWhere(
              (item) {
                final data = item?['data'];
                return data is Map &&
                    '${data['sessionId'] ?? ''}'.trim() == sessionId;
              },
              orElse: () => null,
            );
        if (payload != null) {
          await controller.acceptIncomingCall(payload);
        } else {
          await controller.joinThreadCallSession(sessionId);
        }
        await callKit.reportConnected(sessionId);

        // A CONNECTED CALL NOBODY CAN SEE IS NOT A CONNECTED CALL.
        //
        // Answering from the CallKit screen joined the session and stopped
        // there. The media was live — the founder proved it by ending the call
        // and watching the camera light go out — but the app was still on
        // whatever screen it had been on, so the call was running underneath
        // the UI with no way to reach it. Every other accept path navigates;
        // this one never did.
        //
        // Same route and same authority the in-app card uses, so answering on
        // the lock screen and answering in the app arrive at the same place.
        if (mounted) {
          try {
            // Accepting CLEARS the ringing surface — that is correct, nobody
            // wants a ringing card over a call they are now in. But clearing
            // it was the only thing happening: the card vanished, the media
            // stayed live, and there was no call screen underneath it. The
            // founder's description of the symptom is exact — "join killing
            // the call surface but kept camera engaged".
            final session = ref.read(realtimeControllerProvider).session;
            final meetingId = (session?.surfaceId ?? '').trim();
            final route =
                session?.surfaceType == RealtimeSurfaceType.meeting &&
                        meetingId.isNotEmpty
                    ? '/meetings/$meetingId/live?sessionId=$sessionId'
                    : NavigationAuthority.realtimeSessionJoinRoute(sessionId);
            ref.read(routerProvider).go(route);
          } catch (e) {
            debugPrint('[callkit] answer navigation failed: $e');
          }
        }
      } catch (e) {
        debugPrint('[callkit] answer join failed: $e');
        await callKit.reportEnded(sessionId, reason: 'failed');
      }
    };

    callKit.onEnd = (sessionId) async {
      // Local terminal only. This clears Aura's own presentation and state; it
      // does NOT yet propagate a decline to the backend, because no client-side
      // decline authority exists to call and inventing one here would put call
      // state in the wrong place. Tracked, not papered over.
      try {
        ref
            .read(threadCallLifecycleProvider.notifier)
            .handleTerminal(sessionId, reason: 'declined');
      } catch (e) {
        debugPrint('[callkit] local terminal failed: $e');
      }
    };

    callKit.onRejectedBySystem = (sessionId, reason) async {
      // The exact CXError text. This is the one fact that separates "the
      // system refused" from "the report never happened", and without it both
      // look identical from the server.
      _reportCallKit(sessionId, 'report_refused', reason);
      // THE SILENT-CALL PATH, CLOSED.
      //
      // CallKit refused to present — Do Not Disturb, a blocked caller, a call
      // slot still occupied — and this phone's ordinary banner was suppressed
      // in the expectation that it would present. Saying so brings the
      // fallback immediately instead of leaving the person with a call that
      // rang nowhere.
      _reportPresentation(sessionId, 'REJECTED', reason);
      // Do Not Disturb, a blocked caller, or an already-dead call. The device
      // will never ring for this session, so do not leave the invite pending.
      debugPrint('[callkit] system refused call $sessionId: $reason');
      ref.read(incomingCallBridgeProvider.notifier).removeBySession(sessionId);
    };

    unawaited(callKit.start());
  }

  /// The system acted on a call Aura registered with Telecom.
  ///
  /// THREE EVENTS, AND NOT ONE OF THEM DECIDES ANYTHING. Each is routed into
  /// the authority that already owns that decision — the same rule the
  /// notification path keeps, and the reason a headset button cannot join a
  /// call on the recipient's behalf.
  void _bindNativeTelecom() {
    final telecom = AndroidTelecom.instance;
    if (!telecom.isSupported) return;

    // A Bluetooth headset button, a car, a wearable. The person answered on a
    // real control, so this is an ACCEPT — but it is carried to the same
    // incoming-call surface a foreground answer uses rather than joining
    // here. Founder ruling 2026-08-14: never join on the recipient's behalf.
    telecom.onAnswer = (sessionId) async {
      if (!mounted || sessionId.isEmpty) return;
      debugPrint('[telecom] system answered session=$sessionId');
      try {
        ref
            .read(routerProvider)
            .go(NavigationAuthority.realtimeSessionJoinRoute(sessionId));
      } catch (e) {
        debugPrint('[telecom] answer navigation failed: $e');
      }
    };

    // The system took the call away — a cellular call arrived and won, or the
    // person ended it from a system surface. The ringing card must go, or the
    // phone keeps offering a call the OS has already disconnected.
    telecom.onDisconnect = (sessionId) async {
      if (!mounted || sessionId.isEmpty) return;
      debugPrint('[telecom] system disconnected session=$sessionId');
      try {
        ref
            .read(incomingCallBridgeProvider.notifier)
            .removeBySession(sessionId);
      } catch (e) {
        debugPrint('[telecom] disconnect cleanup failed: $e');
      }
    };

    // Held and resumed. Recorded rather than acted on: Aura has no hold
    // semantics of its own yet, and inventing one here — muting, leaving,
    // pausing media — would be a call behaviour nobody designed, arriving
    // through a system callback. When Aura has a hold, this is where it is
    // driven from.
    telecom.onHoldChanged = (sessionId, active) async {
      debugPrint('[telecom] session=$sessionId active=$active');
    };

    unawaited(telecom.start());
  }

  @override
  void dispose() {
    AuthBroadcast.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Bounded, race-free teardown of the realtime + correspondence sockets
  /// on any auth-drop transition. Returns once both services have
  /// confirmed disconnect or 3 seconds have passed — whichever is first.
  ///
  /// Why a single helper:
  ///   - Both the cross-tab logout handler (`_onRemoteAuthEvent`) and the
  ///     in-tab auth-drop listener used to call `unawaited(disconnect())`
  ///     and then synchronously clear tokens. That allowed a heartbeat
  ///     tick or pending emit to fire between the unawaited call and the
  ///     token clear, producing 401-spam against the auth surface.
  ///   - Awaiting in lockstep guarantees the sockets stop emitting before
  ///     tokens go away. The timeout protects the UI from a permanently-
  ///     hung disconnect (e.g. a half-broken WebSocket pinned by the OS).
  Future<void> _awaitAuthDropTeardown() async {
    Future<void> safeDisconnect(Future<void> Function() run) async {
      try {
        await run();
      } catch (_) {
        // Either service may already be disposed (idempotent) — ignore.
      }
    }

    final correspondence = safeDisconnect(
      () => ref.read(correspondenceLiveServiceProvider).disconnect(),
    );
    final realtime = safeDisconnect(
      () => ref.read(realtimeControllerProvider.notifier).disconnect(),
    );

    try {
      await Future.wait([
        correspondence,
        realtime,
      ]).timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // The timeout case is rare but real: a half-broken transport can
      // leave a socket spinning on close. We accept the leak rather
      // than blocking the rest of the logout pipeline.
    } catch (_) {
      // Defensive — any other surprise here must not prevent the
      // token-clear that follows.
    }

    // Drop any pending incoming-call cards held by the bridge. The
    // provider is long-lived (no autoDispose), so without this a ring
    // received seconds before sign-out would survive into the next
    // identity on the same tab. The bridge re-subscribes to its sockets
    // automatically; clearing state is enough.
    try {
      ref.read(incomingCallBridgeProvider.notifier).clear();
    } catch (_) {
      // Bridge may not have been built yet on a cold logout path.
    }
  }

  Future<void> _onRemoteAuthEvent(String type) async {
    if (!mounted) return;
    if (type == AuthBroadcast.typeLogout) {
      // Local-only teardown: tokens, hint, providers. The originating tab
      // already POSTed /auth/logout, so we deliberately skip the network
      // call to avoid duplicate refresh-cookie clears and 401s.

      // Disconnect runtime sockets BEFORE clearing tokens so any final
      // event fires against a still-valid identity. AWAIT both so a
      // heartbeat tick can't fire mid-clear and produce 401-spam in
      // logs. Bound the wait so a hung disconnect can't freeze the
      // logout path — 3s is well above socket.io's local close cost.
      await _awaitAuthDropTeardown();

      try {
        await ref.read(tokenStoreProvider).clearTokens();
      } catch (_) {}
      try {
        await setSessionHint(false);
      } catch (_) {}
      // RC9 — release the once-per-app-load latch first. Without this the
      // invalidations below are cosmetic: the rebuilt bootstrap returns on
      // its first line because module state still says it already ran.
      try {
        resetSessionBootstrap();
      } catch (_) {}
      // Invalidate auth-derived providers in one go so the router refresh
      // listenable picks up the unauthed state on the next frame.
      try {
        ref.invalidate(authStatusProvider);
      } catch (_) {}
      try {
        ref.invalidate(emailVerifiedProvider);
      } catch (_) {}
      try {
        ref.invalidate(authMeDataProvider);
      } catch (_) {}
      // Stop the local device-registration link to the now-revoked record.
      // revokeCurrentDevice gates on _isAuthed and self-clears local state.
      try {
        unawaited(ref.read(deviceServiceProvider).revokeCurrentDevice());
      } catch (_) {}
    } else if (type == AuthBroadcast.typeLogin) {
      // Sibling tab signed in. Re-evaluate session state without forcing a
      // page reload; if a refresh cookie now lives in this browser, the
      // bootstrap on the next provider read will pick it up.
      //
      // RC9 — that sentence was FALSE until the latch below was released.
      // The invalidation rebuilt the provider, whose first line returned
      // because module state still said the bootstrap had run, so a sibling
      // login never converged here at all.
      try {
        resetSessionBootstrap();
      } catch (_) {}
      try {
        ref.invalidate(sessionBootstrapProvider);
      } catch (_) {}
      try {
        ref.invalidate(authMeDataProvider);
      } catch (_) {}
      try {
        ref.invalidate(emailVerifiedProvider);
      } catch (_) {}
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Defensive auth gate: DeviceService also self-gates, but skipping the
      // call entirely on signed-out resumes keeps the network/console clean
      // when a user is parked on a public route and switches tabs.
      if (!ref.read(isAuthedProvider)) return;
      try {
        ref.read(deviceServiceProvider).refreshPresence();
      } catch (_) {}

      // R3 — Nudge the correspondence socket back online on resume so
      // the synthetic `socket:connected` event fires through the
      // reconciliation controller. That's the missed-event recovery
      // path: any like/save/follow that happened on another device
      // while this one was backgrounded converges on the next frame
      // after resume. Idempotent — `ensureConnected` no-ops when
      // already connected.
      try {
        unawaited(
          ref
              .read(correspondenceLiveServiceProvider)
              .ensureConnected()
              .catchError((_) {}),
        );
      } catch (_) {}

      try {
        unawaited(
          ref
              .read(threadCallLifecycleProvider.notifier)
              .onAppResumed()
              .catchError((_) {}),
        );
      } catch (_) {}

      // Ringing-card reconciliation on resume.
      //
      // Background scenario the bridge can't recover from on its own: while
      // this client was backgrounded, the call was accepted (or declined/
      // expired/ended) on another device. The backend emitted `call:terminal`
      // to our user-room while our socket was disconnected, so we never
      // received it. The bridge state therefore still holds the ringing card,
      // and the local ring timer happily counts down for up to 90s after the
      // peer device answered — that is the "mobile keeps ringing after I
      // picked up on desktop" report.
      //
      // Fix: on every resume, ask the backend whether each ringing session
      // is still ringing FOR US, and evict the card if not. The repository
      // call is bounded and idempotent; transport errors leave the card
      // alone so the TTL still wins.
      unawaited(_reconcileIncomingCallsOnResume());

      // A call answered or declined from the native call notification while
      // the engine was detached. Held natively until Dart could hear it; the
      // slot clears on read, so draining on every resume cannot replay an act.
      unawaited(NativeCallActions.instance.drainPending());

      // A share can arrive at an engine that was detached. The native slot
      // clears on read, so draining on every resume cannot present the same
      // content twice.
      unawaited(ref.read(shareIntakeChannelProvider).drainPending());
    }
  }

  Future<void> _reconcileIncomingCallsOnResume() async {
    try {
      final bridge = ref.read(incomingCallBridgeProvider.notifier);
      final sessionIds = bridge.currentSessionIds();
      if (sessionIds.isEmpty) return;

      final me = await ref.read(authMeDataProvider.future);
      final myUserId =
          (me['id'] ??
                  me['userId'] ??
                  (me['user'] is Map ? (me['user'] as Map)['id'] : null) ??
                  '')
              .toString()
              .trim();
      if (myUserId.isEmpty) return;

      final repo = ref.read(realtimeRepositoryProvider);
      await Future.wait(
        sessionIds.map((sid) async {
          final resolved = await repo.isCallResolvedForUser(sid, myUserId);
          if (resolved) {
            bridge.removeBySession(sid);
          }
        }),
        eagerError: false,
      );
    } catch (_) {
      // Reconciliation is best-effort; failures should never crash the
      // resume path. The 90s frontend TTL and the 30s backend sweep both
      // back this up.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Register device on any auth transition to authed (login, session restore via bootstrap)
    ref.listen<bool>(isAuthedProvider, (prev, next) {
      if (next && !(prev ?? false)) {
        try {
          ref.read(deviceServiceProvider).registerCurrentDevice();
        } catch (_) {}
      }
      // Auth-drop teardown: any path that flips this tab from authed → unauthed
      // (Dio's clearSessionState on a forced 401, cross-tab logout, manual
      // logout) MUST also stop the live runtime services. Without this, an
      // expired-token tab keeps the realtime socket open and the heartbeat
      // ticker firing — those calls then 401 in a tight loop until the user
      // closes the tab. ref.listen callbacks can't be async, so kick off
      // the awaited teardown helper and ignore the future locally.
      if ((prev ?? false) && !next) {
        unawaited(_awaitAuthDropTeardown());
        // C7 — drop the signed-URL cache so a previous user's RESTRICTED
        // / PRIVATE media URLs don't leak into the next session on the
        // same device.
        try {
          ref.read(mediaUrlResolverProvider).clearAll();
        } catch (_) {}
      }
    });

    // SOMETHING WAS SHARED INTO AURA.
    //
    // The routing lives HERE, above the router, rather than in the channel:
    // an adapter's job ends at delivery, and a platform adapter that also
    // navigated would be the beginning of a second share pipeline. Every
    // share — Android, iOS, Windows, cold or warm — reaches the destination
    // through this one line.
    //
    // Note what it does NOT do. It does not check who is signed in, and it
    // does not decide anything about the content. `/share/incoming` gates on
    // an authenticated Human itself, and holds the share while the person
    // signs in rather than discarding it.
    ref.listen<AcquisitionEnvelope?>(shareIntakeInboxProvider, (_, next) {
      if (next == null) return;
      // AFTER THE FRAME, NOT DURING IT.
      //
      // Found on a physical Pixel, 2026-09-04: a real cold share arrived and
      // the person got "This section ran into a problem" instead of their
      // content — `Tried to modify a provider while the widget tree was
      // building`, thrown by this listener.
      //
      // The chain is the whole reason: a share can be delivered while the tree
      // is mid-build (the native drain resolves during startup), delivery sets
      // the inbox state, that notifies here, and `go()` then rebuilds the
      // router inside the same build. Navigation is a consequence of the
      // delivery, not part of it, so it waits for the frame to finish. Nothing
      // is lost by waiting: the envelope is already in the inbox.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          ref.read(routerProvider).go(NavigationAuthority.incomingShareRoute);
        } catch (e) {
          debugPrint('[share] navigation to the share destination failed: $e');
        }
      });
    });

    final router = ref.watch(routerProvider);

    final theme = _buildTheme();

    return NotificationBridge(
      child: PresencePinger(
        child: MaterialApp.router(
          scaffoldMessengerKey: auraScaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          title: 'Aura',
          theme: theme,
          darkTheme: theme,
          themeMode: ThemeMode.dark,
          routerConfig: router,
          // UpdateGate sits between MaterialApp and the routed widget so
          // the blocking screens have access to Material/MediaQuery
          // ancestors and the gate watches its own provider without
          // forcing a rebuild of the rest of the tree.
          builder: (context, child) {
            // BootGate is innermost so it can render INSTEAD of the routed
            // child: a destination that is not in the tree cannot fire
            // requests while authentication is still being restored. It sits
            // inside UpdateGate because a pending release takes precedence
            // over restoring a session for a client that is about to be
            // replaced.
            return ThreadCallLifecycleHost(
              child: OrphanedSessionBanner(
                child: UpdateGate(
                  child: BootGate(child: child ?? const SizedBox.shrink()),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  ThemeData _buildTheme() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AuraSurface.accent,
      onPrimary: Colors.white,
      secondary: AuraSurface.accent,
      onSecondary: Colors.white,
      error: Color(0xFFF07878),
      onError: Colors.white,
      surface: AuraSurface.card,
      onSurface: AuraSurface.ink,
    );

    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AuraRadius.r14),
      borderSide: BorderSide(color: color, width: 1),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,

      scaffoldBackgroundColor: AuraSurface.page,
      canvasColor: AuraSurface.page,
      cardColor: AuraSurface.card,
      dividerColor: AuraSurface.divider,

      splashColor: AuraSurface.accentSoft,
      highlightColor: Colors.transparent,
      splashFactory: InkRipple.splashFactory,

      textTheme: const TextTheme(
        displayLarge: AuraText.display,
        displayMedium: AuraText.headline,
        titleLarge: AuraText.title,
        titleMedium: AuraText.subtitle,
        bodyLarge: AuraText.body,
        bodyMedium: AuraText.body,
        bodySmall: AuraText.small,
        labelLarge: AuraText.emphasis,
        labelMedium: AuraText.label,
        labelSmall: AuraText.micro,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AuraSurface.subtle,
        labelStyle: AuraText.small.copyWith(color: AuraSurface.muted),
        hintStyle: AuraText.small.copyWith(color: AuraSurface.faint),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: border(AuraSurface.divider),
        enabledBorder: border(AuraSurface.divider),
        focusedBorder: border(AuraSurface.accent),
        errorBorder: border(AuraSurface.dangerInk.withValues(alpha: 0.5)),
        focusedErrorBorder: border(AuraSurface.dangerInk),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AuraRadius.r14),
          ),
          backgroundColor: AuraSurface.accent,
          foregroundColor: Colors.white,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          foregroundColor: AuraSurface.ink,
          side: const BorderSide(color: AuraSurface.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AuraRadius.r14),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          foregroundColor: AuraSurface.ink,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AuraRadius.r12),
          ),
        ),
      ),

      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AuraSurface.card,
        indicatorColor: AuraSurface.accentSoft,
        labelTextStyle: WidgetStatePropertyAll(AuraText.label),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AuraSurface.page,
        elevation: 0,
        centerTitle: false,
        foregroundColor: AuraSurface.ink,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AuraSurface.elevated,
        contentTextStyle: AuraText.body.copyWith(color: AuraSurface.ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuraRadius.r12),
          side: const BorderSide(color: AuraSurface.divider),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AuraSurface.overlay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuraRadius.xl),
          side: const BorderSide(color: AuraSurface.divider),
        ),
        titleTextStyle: AuraText.title,
        contentTextStyle: AuraText.body,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AuraSurface.overlay,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AuraRadius.xl),
          ),
        ),
      ),
    );
  }
}
