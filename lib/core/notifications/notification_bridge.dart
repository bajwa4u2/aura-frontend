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
import 'sw_message_bridge.dart';

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

  final Set<String> _seenNotificationIds = <String>{};
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

    final threadId = _stringOf(payload['threadId']);
    final spaceId = _stringOf(payload['spaceId']);

    // 2026-08-14 repair — a call notification tap never auto-joins. A
    // still-ringing call was already registered on the incoming-call
    // bridge above, so the recipient lands on the call's thread/space
    // context with the Accept/Decline overlay on top — the same choice a
    // foreground call already gives them. The accept/decline path is now
    // the sole way into /realtime from a notification.
    if (isCall) {
      if (threadId.isNotEmpty && spaceId.isNotEmpty) {
        return '/me/correspondence/$spaceId/thread/$threadId';
      }
      if (spaceId.isNotEmpty) {
        return '/me/correspondence/$spaceId';
      }
      return '/home';
    }

    // Thread message tap.
    if (threadId.isNotEmpty && spaceId.isNotEmpty) {
      return '/me/correspondence/$spaceId/thread/$threadId';
    }
    if (spaceId.isNotEmpty) {
      return '/me/correspondence/$spaceId';
    }

    return '';
  }

  // ── Snackbar ──────────────────────────────────────────────────────────────

  void _showForegroundSnackbar(Map<String, dynamic> payload) {
    final title = _payloadTitle(payload);
    final body = _payloadBody(payload);
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

  String _payloadTitle(Map<String, dynamic> payload) {
    final kind = _resolveNotificationKind(payload).toUpperCase();
    final callState = _stringOf(payload['callState']).toUpperCase();
    final actor = _mapOf(payload['actor']);
    final actorName = _firstNonEmpty([
      _stringOf(actor['displayName']),
      _stringOf(actor['handle']),
      _stringOf(payload['actorName']),
    ]);

    if (kind == 'LIVE' || kind == 'CALL' || kind == 'REALTIME') {
      if (callState == 'MISSED') {
        return actorName.isNotEmpty
            ? 'Missed call from $actorName'
            : 'Missed call';
      }
      if (callState == 'ENDED') {
        return actorName.isNotEmpty
            ? 'Call ended with $actorName'
            : 'Call ended';
      }
      if (callState == 'DECLINED') {
        return actorName.isNotEmpty ? '$actorName declined' : 'Call declined';
      }
      return actorName.isNotEmpty
          ? '$actorName started a call'
          : 'Incoming call';
    }

    if (actorName.isNotEmpty) return actorName;

    return _firstNonEmpty([
      _stringOf(payload['title']),
      _stringOf(_mapOf(payload['data'])['title']),
      'Update',
    ]);
  }

  String _payloadBody(Map<String, dynamic> payload) {
    return _firstNonEmpty([
      _stringOf(payload['body']),
      _stringOf(_mapOf(payload['data'])['previewText']),
      _stringOf(_mapOf(payload['data'])['body']),
    ]);
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
        _seenNotificationIds.clear();
      }
    });

    ref.listen<List<Map<String, dynamic>>>(
      notificationsControllerProvider.select((state) => state.items),
      (prev, next) {
        _handleNotificationUpdate(prev, next);
      },
    );

    if (_seenNotificationIds.isEmpty && items.isNotEmpty) {
      _seenNotificationIds.addAll(
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

    final previousIds = <String>{};
    if (previous != null) {
      for (final item in previous) {
        final id = _notificationIdOf(item);
        if (id != null) previousIds.add(id);
      }
    }

    for (final item in next) {
      final id = _notificationIdOf(item);
      if (id == null || _seenNotificationIds.contains(id)) continue;

      _seenNotificationIds.add(id);
      if (previousIds.contains(id)) continue;

      // Live interrupts are handled by AuraIncomingLiveLayer.
      if (_isLiveInterrupt(item)) continue;

      _showForegroundNotification(item);
    }
  }

  // Deliberately does NOT check terminal status (unlike `_isCallInterrupt`
  // above) — this only decides whether to skip a duplicate snackbar because
  // AuraIncomingLiveLayer already renders the ringing card; a terminal call
  // notification legitimately still wants its own history/toast treatment.
  bool _isLiveInterrupt(Map<String, dynamic> item) {
    final kind = _resolveNotificationKindFromItem(item).toUpperCase();
    final data = _mapOf(item['data']);
    final attention = _stringOf(data['attention']).toUpperCase();
    return projection.isCallKind(kind) && attention == 'INTERRUPT';
  }

  String _resolveNotificationKindFromItem(Map<String, dynamic> item) =>
      projection.resolveNotificationKind(item);

  void _showForegroundNotification(Map<String, dynamic> item) {
    final title = _notificationTitle(item);
    final body = _notificationBody(item);
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

  String _notificationTitle(Map<String, dynamic> item) {
    final kind = _resolveNotificationKindFromItem(item).toUpperCase();
    final data = _mapOf(item['data']);
    final callState = _stringOf(data['callState']).toUpperCase();
    final actor = _mapOf(item['actor']);
    final actorName = _firstNonEmpty([
      _stringOf(actor['displayName']),
      _stringOf(actor['handle']),
    ]);

    if (kind == 'LIVE' || kind == 'CALL' || kind == 'REALTIME') {
      if (callState == 'MISSED') {
        return actorName.isNotEmpty
            ? 'Missed call from $actorName'
            : 'Missed call';
      }
      if (callState == 'ENDED') {
        return actorName.isNotEmpty
            ? 'Call ended with $actorName'
            : 'Call ended';
      }
      if (callState == 'DECLINED') {
        return actorName.isNotEmpty ? '$actorName declined' : 'Call declined';
      }
      return actorName.isNotEmpty
          ? '$actorName started a call'
          : 'Incoming call';
    }

    if (actorName.isNotEmpty) return actorName;

    return _firstNonEmpty([
      _stringOf(item['title']),
      _stringOf(data['title']),
      'Update',
    ]);
  }

  String _notificationBody(Map<String, dynamic> item) {
    return _firstNonEmpty([
      _stringOf(item['body']),
      _stringOf(_mapOf(item['data'])['previewText']),
      _stringOf(_mapOf(item['data'])['body']),
    ]);
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

  Map<String, dynamic> _mapOf(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _stringOf(dynamic value) => value?.toString().trim() ?? '';
}
