// The installed app's return from a platform's consent page (2026-10-21).
//
// Connect opens Facebook in the system browser; Facebook's return lands
// there, not in the app. The app must say it is the app (so Aura answers the
// return with a "go back to the app" page), and when the member comes back to
// the app it must re-read the connection and open the Page chooser — once per
// Connect, and never on a resume the member did not leave for.
import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/features/me/presentation/widgets/connect_return_watcher.dart';
import 'package:aura/features/me/presentation/widgets/facebook_page_connection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _FakeLauncher extends UrlLauncherPlatform with MockPlatformInterfaceMixin {
  final List<String> launched = <String>[];
  final List<PreferredLaunchMode> modes = <PreferredLaunchMode>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launched.add(url);
    return true;
  }

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    modes.add(options.mode);
    return true;
  }
}

class _Facebook {
  bool connected = false;
  bool needsPage = false;
  final List<String> requests = <String>[];

  Dio dio() {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final path = options.uri.path;
          requests.add('${options.method} ${options.uri.path}${options.uri.hasQuery ? '?${options.uri.query}' : ''}');
          Object? data;
          if (path == '/integrations/facebook/account') {
            data = {'connected': connected, 'needsPage': needsPage, 'page': null};
          } else if (path == '/integrations/facebook/connect/start') {
            data = {'authorizationUrl': 'https://www.facebook.com/dialog/oauth?x=1'};
          } else if (path == '/integrations/facebook/pages') {
            data = {
              'pages': [
                {'id': 'A', 'name': 'Aura Platform', 'canPost': true},
              ],
            };
          }
          if (data == null) {
            return handler.reject(
              DioException(requestOptions: options, message: 'unexpected $path'),
            );
          }
          return handler.resolve(
            Response(requestOptions: options, statusCode: 200, data: data),
          );
        },
      ),
    );
    return dio;
  }
}

void _leaveAndReturn(WidgetTester tester) {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

void main() {
  late UrlLauncherPlatform original;
  late _FakeLauncher launcher;

  setUp(() {
    original = UrlLauncherPlatform.instance;
    launcher = _FakeLauncher();
    UrlLauncherPlatform.instance = launcher;
  });

  tearDown(() => UrlLauncherPlatform.instance = original);

  test('the app says it is the app on connect/start; the web keeps its address', () {
    expect(
      connectStartPath('/integrations/facebook/connect/start', isWeb: false),
      '/integrations/facebook/connect/start?client=app',
    );
    expect(
      connectStartPath('/integrations/linkedin/connect/start', isWeb: true),
      '/integrations/linkedin/connect/start',
    );
  });

  test("the app opens consent in the member's browser; the web keeps its default", () {
    // iOS's default for https is an in-app Safari sheet: the app never leaves
    // the front, so no return is ever seen.
    expect(connectLaunchMode(isWeb: false), LaunchMode.externalApplication);
    expect(connectLaunchMode(isWeb: true), LaunchMode.platformDefault);
  });

  test('a resume without having left is not a return; a return fires once', () {
    var returns = 0;
    final w = ConnectReturnWatcher(isWeb: false);
    w.arm(() async => returns++);
    w.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(returns, 0);
    w.didChangeAppLifecycleState(AppLifecycleState.paused);
    w.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(returns, 1);
    w.didChangeAppLifecycleState(AppLifecycleState.paused);
    w.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(returns, 1);
    expect(w.isArmed, isFalse);
    w.dispose();
  });

  test('the web has nothing to watch', () {
    final w = ConnectReturnWatcher(isWeb: true);
    w.arm(() async {});
    expect(w.isArmed, isFalse);
    w.dispose();
  });

  testWidgets('coming back from Facebook re-reads the connection and opens the Page chooser once', (
    tester,
  ) async {
    final fb = _Facebook();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWithValue(fb.dio())],
        child: const MaterialApp(
          home: Scaffold(body: FacebookPageConnection()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Not connected'), findsOneWidget);

    await tester.tap(find.text('Facebook Page'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(
      fb.requests,
      contains('GET /integrations/facebook/connect/start?client=app'),
    );
    expect(launcher.launched.single, startsWith('https://www.facebook.com/'));
    expect(launcher.modes.single, PreferredLaunchMode.externalApplication);

    // The member approves on Facebook; Aura now holds the connection.
    fb.connected = true;
    fb.needsPage = true;
    final accountReadsBefore =
        fb.requests.where((r) => r == 'GET /integrations/facebook/account').length;

    _leaveAndReturn(tester);
    await tester.pumpAndSettle();

    expect(
      fb.requests.where((r) => r == 'GET /integrations/facebook/account').length,
      accountReadsBefore + 1,
    );
    expect(find.text('Share to which Facebook Page?'), findsOneWidget);

    // Dismiss, then leave and return again: the chooser does not reopen.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    _leaveAndReturn(tester);
    await tester.pumpAndSettle();
    expect(find.text('Share to which Facebook Page?'), findsNothing);
  });
}
