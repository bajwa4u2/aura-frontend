// DIAGNOSTIC: REMOVE BEFORE STORE RELEASE
//
// Temporary Windows-runtime diagnostic instrumentation.
//
// Purpose: produce a sideload-only build that captures real failures from
// Messages / Institution Members / Communication Settings / etc. so we can
// build a failure matrix BEFORE shipping fixes. This file is intentionally
// self-contained so it can be deleted in one step:
//
//   1. Delete `lib/core/diagnostics/runtime_diagnostics.dart`
//   2. Remove the three insertion points tagged with the comment above
//      (one in `dio_provider.dart`, one in `aura_app.dart`, one in `main.dart`)
//
// Gating: every entry point is wrapped in `RuntimeDiagnostics.enabled`,
// which is false unless the build was compiled with
// `--dart-define=AURA_DIAGNOSTIC=true`. A production build without the flag
// pays no observable runtime cost beyond the constant boolean check.
//
// Privacy guardrails (NEVER log these):
//   - Authorization header value (the token itself). We log "yes"/"no" only.
//   - Refresh token (never touched here — request body for /auth/refresh is
//     redacted entirely).
//   - Full message bodies. Error responses are truncated to 300 chars.
//   - User PII fields if recognizable. We do a key-aware redact for known
//     sensitive keys.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../config.dart';

/// Compile-time flag. Pass via:
///   flutter build windows --dart-define=AURA_DIAGNOSTIC=true
/// or:
///   dart run msix:create --dart-define=AURA_DIAGNOSTIC=true
class RuntimeDiagnostics {
  RuntimeDiagnostics._();

  static const bool enabled = bool.fromEnvironment(
    'AURA_DIAGNOSTIC',
    defaultValue: false,
  );

  /// Last route observed by the diagnostic overlay. Updated on every build
  /// of [DiagnosticOverlay], read by the Dio interceptor (which has no
  /// BuildContext). Static so we don't need provider plumbing.
  static String _currentRoute = '/';
  static String get currentRoute => _currentRoute;
  // ignore: use_setters_to_change_properties
  static void setCurrentRoute(String value) => _currentRoute = value;

  /// Bootstrap status set by the session bootstrap path. Captured here so
  /// the diagnostic line shows whether bootstrap had completed at the
  /// moment of a failing request.
  static String _bootstrapStatus = 'unknown';
  static String get bootstrapStatus => _bootstrapStatus;
  static void setBootstrapStatus(String value) => _bootstrapStatus = value;

  /// Whether the token store reports an in-memory access token at the
  /// moment of the failing request. We never log the token value itself.
  static bool _accessTokenPresent = false;
  static bool get accessTokenPresent => _accessTokenPresent;
  static void setAccessTokenPresent(bool value) => _accessTokenPresent = value;

  /// Ring buffer of recent events. Bounded so a long-running diagnostic
  /// session doesn't grow without limit.
  static const int _maxEvents = 400;
  static final Queue<DiagnosticEvent> _events = Queue<DiagnosticEvent>();
  static final StreamController<void> _changes =
      StreamController<void>.broadcast();
  static Stream<void> get onChange => _changes.stream;

  static List<DiagnosticEvent> snapshot() => _events.toList();
  static int get errorCount =>
      _events.where((e) => e.isError).length;

  /// Optional file sink. We try to open it on init but fall back gracefully
  /// to in-memory-only if the path cannot be written. The canonical
  /// hand-off mechanism is the "Copy" button in the diagnostic panel — the
  /// file is a convenience for long-running sessions.
  static IOSink? _sink;
  static String? _logPath;
  static String? get logPath => _logPath;

  static Future<void> initializeFileSink() async {
    if (!enabled) return;
    try {
      // Use the OS temp dir to avoid adding a path_provider dependency.
      // On MSIX-packaged Windows this still resolves to a writable per-user
      // temp folder; the absolute path is surfaced in the diagnostic panel
      // so the user can locate it.
      final dirPath = Directory.systemTemp.path;
      final stamp =
          DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final file = File('$dirPath${Platform.pathSeparator}'
          'aura-diagnostic-$stamp.log');
      _sink = file.openWrite(mode: FileMode.append);
      _logPath = file.path;
      _sink!.writeln(
          '== AURA DIAGNOSTIC LOG START ${DateTime.now().toIso8601String()} ==');
      _sink!.writeln(
          'apiBaseUrl=${AppConfig.apiBaseUrl} '
          'os=${Platform.operatingSystem} osver=${Platform.operatingSystemVersion}');
      await _sink!.flush();
    } catch (e) {
      // File sink is best-effort; the in-memory buffer + overlay still work.
      debugPrint('[DIAG] file sink init failed: $e');
    }
  }

  static Future<void> closeFileSink() async {
    if (!enabled) return;
    try {
      await _sink?.flush();
      await _sink?.close();
    } catch (_) {}
    _sink = null;
  }

  static void record(DiagnosticEvent event) {
    if (!enabled) return;
    _events.addLast(event);
    while (_events.length > _maxEvents) {
      _events.removeFirst();
    }
    try {
      _sink?.writeln(event.toLogLine());
    } catch (_) {}
    if (!_changes.isClosed) _changes.add(null);
  }

  static void clear() {
    _events.clear();
    if (!_changes.isClosed) _changes.add(null);
  }
}

class DiagnosticEvent {
  DiagnosticEvent({
    required this.timestamp,
    required this.route,
    required this.method,
    required this.url,
    required this.status,
    required this.authPresent,
    required this.bootstrapStatus,
    required this.bodySnippet,
    required this.kind,
  });

  final DateTime timestamp;
  final String route;
  final String method;
  final String url;
  final int? status;
  final bool authPresent;
  final String bootstrapStatus;
  final String bodySnippet;

  /// 'request' | 'response' | 'error'
  final String kind;

  bool get isError => kind == 'error' || (status != null && status! >= 400);

  String toLogLine() {
    return '[${timestamp.toIso8601String()}] kind=$kind '
        'route="$route" method=$method status=${status ?? '-'} '
        'auth=${authPresent ? 'yes' : 'no'} bootstrap=$bootstrapStatus '
        'url=$url'
        '${bodySnippet.isEmpty ? '' : ' body="${_oneLine(bodySnippet)}"'}';
  }

  String toPanelLine() {
    final t = timestamp.toIso8601String().substring(11, 19);
    final statusStr = status?.toString() ?? '—';
    return '$t  $kind  ${method.padRight(6)} $statusStr  '
        'auth=${authPresent ? 'y' : 'n'}  $route\n'
        '       $url'
        '${bodySnippet.isEmpty ? '' : '\n       ${_oneLine(bodySnippet, max: 240)}'}';
  }

  static String _oneLine(String s, {int max = 300}) {
    final flat = s
        .replaceAll('\r', ' ')
        .replaceAll('\n', ' ')
        .replaceAll('"', '\\"');
    return flat.length > max ? '${flat.substring(0, max)}…' : flat;
  }
}

/// Privacy redactor — only ever called for ERROR bodies. We never log success
/// bodies. Even on error, known-sensitive keys get redacted before truncation.
String _redactErrorBody(dynamic data) {
  if (data == null) return '';
  String raw;
  try {
    if (data is String) {
      raw = data;
    } else if (data is Map || data is List) {
      raw = jsonEncode(_redactKeys(data));
    } else {
      raw = data.toString();
    }
  } catch (_) {
    raw = '<unloggable>';
  }
  if (raw.length > 300) raw = '${raw.substring(0, 300)}…';
  return raw;
}

Object? _redactKeys(Object? value) {
  if (value is Map) {
    return value.map((k, v) {
      final key = k.toString().toLowerCase();
      if (key.contains('token') ||
          key.contains('password') ||
          key.contains('secret') ||
          key.contains('phone') ||
          key.contains('email') ||
          key.contains('refreshtoken') ||
          key.contains('accesstoken') ||
          key.contains('authorization')) {
        return MapEntry(k.toString(), '<redacted>');
      }
      return MapEntry(k.toString(), _redactKeys(v));
    });
  }
  if (value is List) {
    return value.map(_redactKeys).toList();
  }
  return value;
}

/// Dio interceptor — added at the END of the chain so the status seen here
/// is the FINAL status the caller will observe (after the auth/refresh
/// interceptor has run). Add via:
///
///   if (RuntimeDiagnostics.enabled) {
///     dio.interceptors.add(DiagnosticDioInterceptor());
///   }
class DiagnosticDioInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (RuntimeDiagnostics.enabled) {
      final url = '${options.baseUrl.replaceAll(RegExp(r"/$"), '')}'
          '${options.path.startsWith('/') ? options.path : '/${options.path}'}';
      final auth = options.headers['Authorization'];
      RuntimeDiagnostics.record(DiagnosticEvent(
        timestamp: DateTime.now(),
        route: RuntimeDiagnostics.currentRoute,
        method: options.method,
        url: url,
        status: null,
        authPresent: auth is String && auth.trim().isNotEmpty,
        bootstrapStatus: RuntimeDiagnostics.bootstrapStatus,
        bodySnippet: '',
        kind: 'request',
      ));
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (RuntimeDiagnostics.enabled) {
      final req = response.requestOptions;
      final url = '${req.baseUrl.replaceAll(RegExp(r"/$"), '')}'
          '${req.path.startsWith('/') ? req.path : '/${req.path}'}';
      final auth = req.headers['Authorization'];
      RuntimeDiagnostics.record(DiagnosticEvent(
        timestamp: DateTime.now(),
        route: RuntimeDiagnostics.currentRoute,
        method: req.method,
        url: url,
        status: response.statusCode,
        authPresent: auth is String && auth.trim().isNotEmpty,
        bootstrapStatus: RuntimeDiagnostics.bootstrapStatus,
        bodySnippet: '', // success — never log body
        kind: 'response',
      ));
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (RuntimeDiagnostics.enabled) {
      final req = err.requestOptions;
      final url = '${req.baseUrl.replaceAll(RegExp(r"/$"), '')}'
          '${req.path.startsWith('/') ? req.path : '/${req.path}'}';
      final auth = req.headers['Authorization'];
      final body = _redactErrorBody(err.response?.data);
      final fallback = err.message ?? err.type.toString();
      RuntimeDiagnostics.record(DiagnosticEvent(
        timestamp: DateTime.now(),
        route: RuntimeDiagnostics.currentRoute,
        method: req.method,
        url: url,
        status: err.response?.statusCode,
        authPresent: auth is String && auth.trim().isNotEmpty,
        bootstrapStatus: RuntimeDiagnostics.bootstrapStatus,
        bodySnippet: body.isEmpty ? fallback : body,
        kind: 'error',
      ));
    }
    handler.next(err);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UI: floating badge + panel.  Mounted from `aura_app.dart` only when
// AURA_DIAGNOSTIC is true.  Captures the current GoRouter URI in build() so
// the interceptor (which has no BuildContext) can read it via the static
// accessor.
// ─────────────────────────────────────────────────────────────────────────────

class DiagnosticOverlay extends StatelessWidget {
  const DiagnosticOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!RuntimeDiagnostics.enabled) return child;
    // Update the static route accessor on every rebuild so the interceptor
    // (no context) always sees the latest URI.
    try {
      final routerState = GoRouterState.of(context);
      RuntimeDiagnostics.setCurrentRoute(routerState.uri.toString());
    } catch (_) {
      // GoRouterState may be unavailable on some shells; non-fatal.
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        const Positioned(
          right: 8,
          bottom: 8,
          child: _DiagnosticBadge(),
        ),
      ],
    );
  }
}

class _DiagnosticBadge extends StatefulWidget {
  const _DiagnosticBadge();

  @override
  State<_DiagnosticBadge> createState() => _DiagnosticBadgeState();
}

class _DiagnosticBadgeState extends State<_DiagnosticBadge> {
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = RuntimeDiagnostics.onChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final errors = RuntimeDiagnostics.errorCount;
    final total = RuntimeDiagnostics.snapshot().length;
    return Material(
      color: errors > 0 ? Colors.red.shade700 : Colors.amber.shade800,
      shape: const StadiumBorder(),
      elevation: 6,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => _DiagnosticPanel.show(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            '🛠 DIAG  $total / err $errors',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }
}

class _DiagnosticPanel extends StatefulWidget {
  const _DiagnosticPanel();

  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A1018),
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.9,
        child: _DiagnosticPanel(),
      ),
    );
  }

  @override
  State<_DiagnosticPanel> createState() => _DiagnosticPanelState();
}

class _DiagnosticPanelState extends State<_DiagnosticPanel> {
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = RuntimeDiagnostics.onChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final events = RuntimeDiagnostics.snapshot().reversed.toList();
    final logPath = RuntimeDiagnostics.logPath ?? '<sink not initialized>';
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFF101822),
            border: Border(bottom: BorderSide(color: Colors.white12)),
          ),
          child: Row(
            children: [
              const Icon(Icons.build_circle, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Aura Diagnostic — DIAGNOSTIC BUILD',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy to clipboard',
                icon: const Icon(Icons.copy_all, color: Colors.white70),
                onPressed: () async {
                  final report = _buildReport(events, logPath);
                  await Clipboard.setData(ClipboardData(text: report));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Diagnostic report copied')),
                  );
                },
              ),
              IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.clear_all, color: Colors.white70),
                onPressed: () => RuntimeDiagnostics.clear(),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        // Header info
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          color: const Color(0xFF0C141D),
          child: Text(
            'apiBaseUrl: ${AppConfig.apiBaseUrl}\n'
            'log file:  $logPath\n'
            'route:     ${RuntimeDiagnostics.currentRoute}\n'
            'auth:      access=${RuntimeDiagnostics.accessTokenPresent ? 'yes' : 'no'}  '
            'bootstrap=${RuntimeDiagnostics.bootstrapStatus}\n'
            'total:     ${events.length}  errors: ${RuntimeDiagnostics.errorCount}',
            style: const TextStyle(
              color: Colors.white70,
              fontFamily: 'monospace',
              fontSize: 11,
            ),
          ),
        ),
        // Event list
        Expanded(
          child: events.isEmpty
              ? const Center(
                  child: Text(
                    'No diagnostic events yet.\nUse the app and they will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: events.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (_, i) {
                    final e = events[i];
                    final color = e.isError
                        ? Colors.red.shade300
                        : e.kind == 'response'
                            ? Colors.green.shade200
                            : Colors.amber.shade200;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Text(
                        e.toPanelLine(),
                        style: TextStyle(
                          color: color,
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  static String _buildReport(List<DiagnosticEvent> events, String logPath) {
    final buf = StringBuffer()
      ..writeln('== AURA DIAGNOSTIC REPORT ==')
      ..writeln('generated: ${DateTime.now().toIso8601String()}')
      ..writeln('apiBaseUrl: ${AppConfig.apiBaseUrl}')
      ..writeln('log file: $logPath')
      ..writeln('route at copy: ${RuntimeDiagnostics.currentRoute}')
      ..writeln('bootstrap at copy: ${RuntimeDiagnostics.bootstrapStatus}')
      ..writeln('access token present at copy: '
          '${RuntimeDiagnostics.accessTokenPresent}')
      ..writeln('total events: ${events.length}')
      ..writeln('errors: ${events.where((e) => e.isError).length}')
      ..writeln('os: ${Platform.operatingSystem} '
          '${Platform.operatingSystemVersion}')
      ..writeln('---')
      ..writeln();
    for (final e in events) {
      buf.writeln(e.toLogLine());
    }
    return buf.toString();
  }
}
