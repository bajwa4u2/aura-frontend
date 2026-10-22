import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../config.dart';
import 'report_silently.dart';

/// Sends the app's crashes and silent failures to `POST /v1/client/errors`,
/// so a failure on someone's device is no longer invisible to us.
///
/// Fire and forget: it never blocks, never throws and never shows anything.
/// At most [maxPerSession] reports per run, each distinct message once.
/// Release builds only, unless [force] is set (tests). Nothing a person wrote
/// is sent: messages are cut short and scrubbed of email addresses and tokens.
class ClientErrorReporter {
  ClientErrorReporter({
    Future<void> Function(Map<String, dynamic> body)? send,
    bool force = false,
    String? build,
    String? platform,
  }) : _send = send ?? _httpSend,
       _enabled = force || kReleaseMode,
       _build = build,
       _platform = platform ?? _platformName();

  static const maxPerSession = 10;
  static const maxMessage = 2000;
  static const maxStack = 8000;

  final Future<void> Function(Map<String, dynamic> body) _send;
  final bool _enabled;
  final String _platform;
  String? _build;
  int _sent = 0;
  final Set<String> _seen = <String>{};

  /// The route on screen, when the app tells us (never its query string).
  static String? Function() currentRoute = () => null;

  static ClientErrorReporter? _installed;

  /// Installs the reporter as the target of [reportSilently] and returns it.
  static ClientErrorReporter install({ClientErrorReporter? reporter}) {
    final r = reporter ?? ClientErrorReporter();
    _installed = r;
    ReportSilentlySink.sink = (error, stack, context) =>
        r.report(error, stack, context: context);
    r._loadBuild();
    return r;
  }

  static ClientErrorReporter? get installed => _installed;

  void report(Object error, StackTrace? stack, {String? context}) {
    if (!_enabled || _sent >= maxPerSession) return;
    final message = scrub(
      '${context == null ? '' : '[$context] '}'
      '${error.runtimeType}: $error',
    );
    final key = message.length > 200 ? message.substring(0, 200) : message;
    if (!_seen.add(key)) return;
    _sent++;
    final route = _safeRoute();
    final body = <String, dynamic>{
      'message': _cut(message, maxMessage),
      if (stack != null) 'stack': _cut(scrub(stack.toString()), maxStack),
      'build': _build ?? 'unknown',
      'platform': _platform,
      if (route != null) 'route': route,
    };
    // Never awaited: a crash report must not hold anything up.
    _send(body).catchError((Object _) {});
  }

  /// Removes what could identify a person or open an account.
  @visibleForTesting
  static String scrub(String text) {
    return text
        .replaceAll(RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+'), '<email>')
        .replaceAll(RegExp(r'eyJ[\w-]+\.[\w-]+\.[\w-]+'), '<token>')
        .replaceAll(
          RegExp(r'bearer\s+\S+', caseSensitive: false),
          'Bearer <token>',
        )
        .replaceAll(RegExp(r'\b\d{7,}\b'), '<number>');
  }

  String? _safeRoute() {
    try {
      final r = currentRoute();
      if (r == null || r.isEmpty) return null;
      final q = r.indexOf('?');
      return _cut(q < 0 ? r : r.substring(0, q), 200);
    } catch (_) {
      // A route we cannot read is simply left out.
      return null;
    }
  }

  Future<void> _loadBuild() async {
    if (_build != null || !_enabled) return;
    try {
      final info = await PackageInfo.fromPlatform();
      _build = '${info.version}+${info.buildNumber}';
    } catch (_) {
      // Left as "unknown"; the report still goes.
    }
  }

  static String _cut(String s, int max) =>
      s.length <= max ? s : s.substring(0, max);

  static String _platformName() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }

  // Its own client, outside dio_provider on purpose: a report must not pass
  // through the interceptors whose failure it may be describing.
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );

  static Future<void> _httpSend(Map<String, dynamic> body) async {
    await _dio.post<dynamic>('/client/errors', data: body);
  }
}
