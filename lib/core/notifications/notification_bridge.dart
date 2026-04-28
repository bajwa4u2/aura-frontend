import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/session_providers.dart';
import '../../features/updates/providers.dart';

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
      // Only mark ready on success. On exception we stay false so the next
      // build cycle can retry (e.g. if SharedPreferences was temporarily
      // unavailable in private browsing mode).
      _browserRegistrationReady = true;
    } catch (_) {
      // SharedPreferences.getInstance() can throw on web when localStorage is
      // blocked (private browsing, cross-origin iframe). Best-effort: leave
      // _browserRegistrationReady = false so a retry is possible.
    } finally {
      // Always release the queue lock regardless of outcome or auth state.
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
      if (id == null || _seenNotificationIds.contains(id)) {
        continue;
      }

      _seenNotificationIds.add(id);
      if (previousIds.contains(id)) {
        continue;
      }

      if (_isLiveInterrupt(item)) {
        continue;
      }

      _showForegroundNotification(item);
    }
  }

  bool _isLiveInterrupt(Map<String, dynamic> item) {
    final type = _stringOf(item['type']).toUpperCase();
    final data = _mapOf(item['data']);
    final attention = _stringOf(data['attention']).toUpperCase();
    return type == 'LIVE' && attention == 'INTERRUPT';
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
          content: Text(body.isEmpty ? title : '$title - $body'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  String _notificationTitle(Map<String, dynamic> item) {
    final actor = _mapOf(item['actor']);
    final actorName = _firstNonEmpty([
      _stringOf(actor['displayName']),
      _stringOf(actor['handle']),
    ]);
    final type = _stringOf(item['type']).toUpperCase();
    final data = _mapOf(item['data']);
    final body = _notificationBody(item);

    if (type == 'LIVE' && body.toLowerCase().contains('missed')) {
      return actorName.isNotEmpty ? 'Missed call from $actorName' : 'Missed call';
    }
    if (type == 'LIVE') {
      return actorName.isNotEmpty ? '$actorName started a call' : 'Incoming call';
    }
    if (actorName.isNotEmpty) {
      return actorName;
    }
    final title = _firstNonEmpty([
      _stringOf(item['title']),
      _stringOf(data['title']),
    ]);
    return title.isNotEmpty ? title : 'Update';
  }

  String _notificationBody(Map<String, dynamic> item) {
    final body = _firstNonEmpty([
      _stringOf(item['body']),
      _stringOf(_mapOf(item['data'])['previewText']),
      _stringOf(_mapOf(item['data'])['body']),
    ]);
    return body;
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
