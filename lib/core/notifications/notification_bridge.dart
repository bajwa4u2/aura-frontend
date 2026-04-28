import 'dart:async';
import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/session_providers.dart';
import '../../features/updates/providers.dart';
import '../../router.dart';
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
  static const _browserRegisteredAtKey = 'aura_browser_notification_registered_at';

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
          ref.read(routerProvider).go(route);
        } catch (e) {
          debugPrint('SW navigate failed: $e');
        }
      });
    });
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
    final route = _routeFromPayload(payload);
    if (route.isEmpty) return;

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

  bool _isCallInterrupt(Map<String, dynamic> payload) {
    final kind = _resolveNotificationKind(payload).toUpperCase();
    final attention = _stringOf(payload['attention']).toUpperCase();
    return (kind == 'LIVE' || kind == 'CALL' || kind == 'REALTIME') &&
        attention == 'INTERRUPT';
  }

  String _resolveNotificationKind(Map<String, dynamic> payload) {
    return _firstNonEmpty([
      _stringOf(payload['notificationKind']),
      _stringOf(payload['type']),
      _stringOf(payload['communicationType']),
      _stringOf(payload['kind']),
    ]);
  }

  String _resolveSessionId(Map<String, dynamic> payload) {
    return _firstNonEmpty([
      _stringOf(payload['realtimeSessionId']),
      _stringOf(payload['sessionId']),
    ]);
  }

  String _routeFromPayload(Map<String, dynamic> payload) {
    // Prefer explicit deeplink/route from backend.
    final deeplink = _firstNonEmpty([
      _stringOf(payload['deeplink']),
      _stringOf(payload['route']),
    ]);
    if (deeplink.isNotEmpty && deeplink.startsWith('/')) return deeplink;

    final kind = _resolveNotificationKind(payload).toUpperCase();
    final sessionId = _resolveSessionId(payload);
    final threadId = _stringOf(payload['threadId']);
    final spaceId = _stringOf(payload['spaceId']);

    // Call/live notification tap → realtime session or thread live.
    if (kind == 'LIVE' || kind == 'CALL' || kind == 'REALTIME') {
      if (sessionId.isNotEmpty) {
        if (threadId.isNotEmpty && spaceId.isNotEmpty) {
          return '/me/correspondence/$spaceId/thread/$threadId/live/$sessionId';
        }
        if (spaceId.isNotEmpty) {
          return '/me/correspondence/$spaceId/live/$sessionId';
        }
        return '/realtime/$sessionId?action=join';
      }
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
        return actorName.isNotEmpty ? 'Missed call from $actorName' : 'Missed call';
      }
      if (callState == 'ENDED') {
        return actorName.isNotEmpty ? 'Call ended with $actorName' : 'Call ended';
      }
      if (callState == 'DECLINED') {
        return actorName.isNotEmpty ? '$actorName declined' : 'Call declined';
      }
      return actorName.isNotEmpty ? '$actorName started a call' : 'Incoming call';
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
      _seenNotificationIds.addAll(items.map(_notificationIdOf).whereType<String>());
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

  bool _isLiveInterrupt(Map<String, dynamic> item) {
    final kind = _resolveNotificationKindFromItem(item).toUpperCase();
    final data = _mapOf(item['data']);
    final attention = _stringOf(data['attention']).toUpperCase();
    return (kind == 'LIVE' || kind == 'CALL' || kind == 'REALTIME') &&
        attention == 'INTERRUPT';
  }

  String _resolveNotificationKindFromItem(Map<String, dynamic> item) {
    final data = _mapOf(item['data']);
    return _firstNonEmpty([
      _stringOf(item['notificationKind']),
      _stringOf(item['type']),
      _stringOf(data['notificationKind']),
      _stringOf(data['communicationType']),
    ]);
  }

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
        return actorName.isNotEmpty ? 'Missed call from $actorName' : 'Missed call';
      }
      if (callState == 'ENDED') {
        return actorName.isNotEmpty ? 'Call ended with $actorName' : 'Call ended';
      }
      if (callState == 'DECLINED') {
        return actorName.isNotEmpty ? '$actorName declined' : 'Call declined';
      }
      return actorName.isNotEmpty ? '$actorName started a call' : 'Incoming call';
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
