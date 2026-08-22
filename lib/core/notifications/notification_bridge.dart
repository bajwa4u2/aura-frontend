import 'dart:async';
import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/session_providers.dart';
import '../../features/realtime/application/incoming_call_projection.dart'
    as projection;
import '../../features/updates/incoming_call_bridge.dart';
import '../../features/updates/providers.dart';
import '../../router.dart';
import 'native_call_notification_channel.dart';
import 'notification_open_reconcile.dart';
import 'notification_arrival_gate.dart';
import 'notification_presentation.dart';
import 'sw_message_bridge.dart';
import '../navigation/canonical_destinations.dart';

final auraScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class NotificationBridge extends ConsumerStatefulWidget {
  const NotificationBridge({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationBridge> createState() => _NotificationBridgeState();
}

class _NotificationBridgeState extends ConsumerState<NotificationBridge> {
  static const _browserIdKey = 'aura_browser_notification_device_id';
  static const _browserRegisteredAtKey =
      'aura_browser_notification_registered_at';

  /// Arrival truth lives in its own authority so it can be tested. See
  /// `notification_arrival_gate.dart` for why the previous inline seen-set
  /// could not express "the first load is history".
  final NotificationArrivalGate _arrivals = NotificationArrivalGate();
  bool _browserRegistrationReady = false;
  bool _registrationSyncQueued = false;

  StreamSubscription<RemoteMessage>? _fcmForegroundSub;
  StreamSubscription<RemoteMessage>? _fcmTapSub;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initFcm();
    } else {
      _initWebSwBridge();
    }
  }

  @override
  void dispose() {
    _fcmForegroundSub?.cancel();
    _fcmTapSub?.cancel();
    stopSwNavigateListener();
    super.dispose();
  }

  void _initWebSwBridge() {
    listenForSwNavigate((deeplink) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          final trimmed = deeplink.trim();
          if (trimmed.isEmpty) return;
          final route = trimmed.startsWith('/') ? trimmed : '/$trimmed';
          // R5 — Web push lands here without an FCM RemoteMessage in
          // hand; we only have the deeplink. Infer the notification
          // type from the route prefix so the right canonical surfaces
          // refresh before navigation lands. /posts/* → post family,
          // /u/* + /institutions/* → follow family, /direct/* + /spaces/*
          // → feed family, /realtime/* → call family.
          NotificationOpenReconcile.onFcmTap(ref, _payloadFromRoute(route));
          ref.read(routerProvider).go(route);
        } catch (e) {
          debugPrint('SW navigate failed: $e');
        }
      });
    });
  }

  /// R5 — Reconstruct a minimal payload so the reconcile helper can
  /// route invalidations from a service-worker deeplink alone. Recognised
  /// patterns mirror the in-app `_routeFor()` map.
  Map<String, dynamic> _payloadFromRoute(String route) {
    String inferType() {
      if (route.startsWith('/realtime')) return 'CALL';
      if (route.startsWith('/u/') || route.startsWith('/institutions/')) {
        return 'FOLLOW';
      }
      if (route.startsWith('/direct/')) return 'MESSAGE';
      if (route.startsWith('/spaces/')) return 'SPACE_ACTIVITY';
      // Participant continuity — meeting lifecycle deeplinks land on the
      // Meeting Record (personal or institution path).
      if (route.startsWith('/meetings/') || route.contains('/meetings/')) {
        return 'MEETING_REMINDER';
      }
      if (route.startsWith('/posts/') || route.contains('/posts/')) {
        return 'REPLY';
      }
      return '';
    }

    return <String, dynamic>{'type': inferType(), 'deeplink': route};
  }

  void _initFcm() {
    // Foreground FCM messages — show snackbar / call overlay fallback.
    _fcmForegroundSub = FirebaseMessaging.onMessage.listen(_onFcmForeground);

    // Background tap — app was in background when user tapped the notification.
    _fcmTapSub = FirebaseMessaging.onMessageOpenedApp.listen(_onFcmTap);

    // Killed-app tap — schedule after first frame so GoRouter is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final initial = await FirebaseMessaging.instance.getInitialMessage();
        if (initial != null && mounted) {
          _onFcmTap(initial);
        }
      } catch (e) {
        debugPrint('NotificationBridge.getInitialMessage failed: $e');
      }
    });
  }

  // ── FCM message handlers ──────────────────────────────────────────────────

  void _onFcmForeground(RemoteMessage message) {
    if (!mounted) return;
    final payload = _payloadFromFcm(message);
    if (_isCallInterrupt(payload)) {
      ref
          .read(incomingCallBridgeProvider.notifier)
          .addIncoming(
            Map<String, dynamic>.from(payload)
              ..['_auraLifecycleSource'] = 'foregroundPush',
          );
      // Trigger an immediate notification refresh so the incoming-call overlay
      // can show the call without waiting for the next 45-second poll cycle.
      unawaited(
        ref.read(notificationsControllerProvider.notifier).refresh(force: true),
      );
      // The AuraIncomingLiveLayer handles live calls via the polling provider;
      // FCM foreground call messages are surfaced as a fallback snackbar here
      // only if the overlay could not resolve a session.
      final sessionId = _resolveSessionId(payload);
      if (sessionId.isEmpty) {
        _showForegroundSnackbar(payload);
      }
      return;
    }
    // Also refresh notifications for non-call messages so the badge count stays current.
    unawaited(
      ref.read(notificationsControllerProvider.notifier).refresh(force: true),
    );
    _showForegroundSnackbar(payload);
  }

  void _onFcmTap(RemoteMessage message) {
    if (!mounted) return;
    final payload = _payloadFromFcm(message);

    // 2026-08-14 repair — tapping a still-ringing call notification must
    // offer the same Accept/Decline choice a foreground call gets, not
    // silently join on the recipient's behalf. Registering it on the
    // shared incoming-call bridge (the same one `_onFcmForeground` already
    // uses) surfaces `AuraIncomingLiveLayer`'s accept/decline card —
    // that widget is mounted app-root and renders for any bridge entry
    // regardless of how it arrived. `_routeFromPayload` below now lands a
    // joinable call on its thread/space context instead of `/realtime/
    // :id?action=join`, so nothing auto-joins from a tap. This is shared
    // Dart code — the fix applies uniformly to Android, iOS, and Web.
    if (_isCallInterrupt(payload)) {
      ref.read(incomingCallBridgeProvider.notifier).addIncoming(
        Map<String, dynamic>.from(payload)
          ..['_auraLifecycleSource'] = 'notificationTap',
      );
      // The tap itself is proof the user has seen/acted on this call —
      // stop the native ringtone-style alert now rather than leaving it
      // to Android's own (unreliable, for this channel) tap-cancel behavior.
      unawaited(cancelNativeCallNotifications());
    }

    final route = _routeFromPayload(payload);
    if (route.isEmpty) return;

    // R5 — Flush canonical providers before navigation so the landing
    // surface re-fetches against backend truth. Critical for cold-start
    // (getInitialMessage) and background-tap paths where a stale
    // provider value can survive across the launch.
    try {
      NotificationOpenReconcile.onFcmTap(ref, payload);
    } catch (_) {}

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final router = ref.read(routerProvider);
        router.go(route);
      } catch (e) {
        debugPrint('NotificationBridge routing failed: $e');
      }
    });
  }

  // ── Payload helpers ───────────────────────────────────────────────────────

  Map<String, dynamic> _payloadFromFcm(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);
    final notification = message.notification;
    if (notification != null) {
      data['title'] ??= notification.title ?? '';
      data['body'] ??= notification.body ?? '';
    }
    return data;
  }

  // Realtime Architecture Correction — Phase 4, Part F: delegate to the ONE
  // shared projection authority (incoming_call_projection.dart) — this file
  // previously carried its own near-duplicate of this classification logic,
  // independently of incoming_live_overlay.dart's copy (their fallback
  // phrase lists had already drifted apart; merged, not lost, in the shared
  // module).

  bool _isCallInterrupt(Map<String, dynamic> payload) =>
      projection.isCallInterruptPayload(payload);

  String _resolveNotificationKind(Map<String, dynamic> payload) =>
      projection.resolveNotificationKind(payload);

  String _resolveSessionId(Map<String, dynamic> payload) =>
      projection.resolveCallSessionId(payload);

  String _routeFromPayload(Map<String, dynamic> payload) {
    final kind = _resolveNotificationKind(payload).toUpperCase();
    final isCall = kind == 'LIVE' || kind == 'CALL' || kind == 'REALTIME';

    // Prefer explicit deeplink/route from backend, except call payloads must
    // not auto-navigate straight into /realtime — a still-ringing call is
    // handled by the incoming-call bridge registration in `_onFcmTap`
    // (accept/decline overlay), and terminal/expired calls must not
    // resurrect /realtime either (that would just hit a 403 from the
    // backend). R5 — also accept `deepLink` (camelCase) for resilience
    // against partner integrations / older payload variants.
    final deeplink = _firstNonEmpty([
      _stringOf(payload['deeplink']),
      _stringOf(payload['deepLink']),
      _stringOf(payload['route']),
    ]);
    if (deeplink.isNotEmpty && deeplink.startsWith('/')) {
      final isRealtimeDeeplink = deeplink.startsWith('/realtime');
      if (!(isCall && isRealtimeDeeplink)) {
        return deeplink;
      }
    }

    final spaceId = _stringOf(payload['spaceId']);

    // 2026-08-14 repair — a call notification tap never auto-joins. A
    // still-ringing call was already registered on the incoming-call
    // bridge above, so the recipient lands on the call's thread/space
    // context with the Accept/Decline overlay on top — the same choice a
    // foreground call already gives them. The accept/decline path is now
    // the sole way into /realtime from a notification.
    // Phase 5 retired the correspondence family, so the context this lands on
    // is whatever canonical surface the payload actually names. A legacy
    // threadId names none, and is no longer used to build a destination.
    final conversationId = _stringOf(payload['conversationId']);
    final institutionId = _stringOf(payload['institutionId']);
    final canonical = canonicalContextDestination(
      conversationId: conversationId,
      institutionId: institutionId,
      spaceId: spaceId,
    );

    if (isCall) {
      return canonical ?? '/home';
    }

    return canonical ?? '';
  }

  // ── Snackbar ──────────────────────────────────────────────────────────────

  void _showForegroundSnackbar(Map<String, dynamic> payload) {
    final title = resolveNotificationTitle(payload);
    final body = resolveNotificationBody(payload);
    final messenger = auraScaffoldMessengerKey.currentState;
    if (messenger != null) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(body.isEmpty ? title : '$title — $body'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ── Polling-based in-app notification handling ────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isAuthed = ref.watch(isAuthedProvider);
    final items = ref.watch(
      notificationsControllerProvider.select((state) => state.items),
    );

    ref.listen<bool>(isAuthedProvider, (prev, next) {
      unawaited(_syncBrowserRegistration(next));
      if (!next) {
        // Signing out ends the session, so the next one establishes its own
        // baseline rather than inheriting this one.
        _arrivals.reset();
      }
    });

    ref.listen<List<Map<String, dynamic>>>(
      notificationsControllerProvider.select((state) => state.items),
      (prev, next) {
        _handleNotificationUpdate(prev, next);
      },
    );

    // Re-mounting on top of an already-populated controller is also a
    // baseline: those notifications existed before this widget did.
    if (items.isNotEmpty) {
      _arrivals.establishBaseline(
        items.map(_notificationIdOf).whereType<String>(),
      );
    }

    if (isAuthed && !_browserRegistrationReady && !_registrationSyncQueued) {
      _registrationSyncQueued = true;
      unawaited(_syncBrowserRegistration(true));
    }

    return widget.child;
  }

  Future<void> _syncBrowserRegistration(bool authed) async {
    if (!mounted) return;

    try {
      if (!authed) {
        _browserRegistrationReady = false;
        await _clearBrowserRegistration();
        return;
      }
      await _ensureBrowserRegistration();
      _browserRegistrationReady = true;
    } catch (_) {
      // SharedPreferences can throw in private-browsing mode.
    } finally {
      _registrationSyncQueued = false;
    }
  }

  Future<void> _ensureBrowserRegistration() async {
    final prefs = await SharedPreferences.getInstance();
    final browserId = prefs.getString(_browserIdKey);
    if ((browserId ?? '').trim().isEmpty) {
      await prefs.setString(_browserIdKey, _generateBrowserId());
    }
    await prefs.setString(
      _browserRegisteredAtKey,
      DateTime.now().toIso8601String(),
    );
  }

  Future<void> _clearBrowserRegistration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_browserIdKey);
    await prefs.remove(_browserRegisteredAtKey);
  }

  void _handleNotificationUpdate(
    List<Map<String, dynamic>>? previous,
    List<Map<String, dynamic>> next,
  ) {
    if (next.isEmpty) return;

    final admitted = _arrivals
        .admit(
          previousIds: (previous ?? const <Map<String, dynamic>>[])
              .map(_notificationIdOf)
              .whereType<String>(),
          nextIds: next.map(_notificationIdOf).whereType<String>(),
        )
        .toSet();
    if (admitted.isEmpty) return;

    for (final item in next) {
      final id = _notificationIdOf(item);
      if (id == null || !admitted.contains(id)) continue;

      // Live interrupts are handled by AuraIncomingLiveLayer.
      if (_isLiveInterrupt(item)) continue;

      _showForegroundNotification(item);
    }
  }

  /// A CALL IS NEVER ANNOUNCED BY THE GLOBAL RIBBON.
  ///
  /// This used to require `attention == 'INTERRUPT'` before suppressing a
  /// call, and NO real call payload carries that key — production rows carry
  /// `sessionId`, `threadId`, `spaceId`, `mediaMode`, `contextName`,
  /// `realtimeType`, `notificationKind` and nothing else. So the suppression
  /// never fired and every call notification fell through to the floating
  /// snackbar, including the one for the call the person had just ACCEPTED:
  /// a transient ribbon announcing the call they were already in.
  /// Founder-observed on the attendee side, 2026-08-22.
  ///
  /// Calls already have canonical presentation at every stage —
  /// AuraIncomingLiveLayer while ringing, the room once joined, the PiP when
  /// minimised, and the Activity list as history. The ribbon adds nothing to
  /// any of those and contradicts the first two.
  ///
  /// The previous comment argued a terminal call "legitimately still wants its
  /// own history/toast treatment". History is the list, which still shows it.
  /// A four-second ribbon is not history.
  bool _isLiveInterrupt(Map<String, dynamic> item) {
    final kind = _resolveNotificationKindFromItem(item).toUpperCase();
    return projection.isCallKind(kind);
  }

  String _resolveNotificationKindFromItem(Map<String, dynamic> item) =>
      projection.resolveNotificationKind(item);

  void _showForegroundNotification(Map<String, dynamic> item) {
    final title = resolveNotificationTitle(item);
    final body = resolveNotificationBody(item);
    final messenger = auraScaffoldMessengerKey.currentState;

    if (messenger != null) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(body.isEmpty ? title : '$title — $body'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  String? _notificationIdOf(Map<String, dynamic> item) {
    final id = _stringOf(item['id']);
    return id.isEmpty ? null : id;
  }

  String _generateBrowserId() {
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final rand = Random().nextInt(1 << 32).toRadixString(36);
    return 'browser_$now$rand';
  }

  // ── Primitive helpers ─────────────────────────────────────────────────────

  String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      final text = value.trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _stringOf(dynamic value) => value?.toString().trim() ?? '';
}
