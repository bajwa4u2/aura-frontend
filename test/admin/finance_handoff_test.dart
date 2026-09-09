/// THE HANDOFF — what actually happens when the founder presses the door.
///
/// The boundary test beside this one proves WHETHER the door is drawn. This one
/// proves WHERE IT GOES, which is a different question and the one that decides
/// whether the founder ends up in the Finance workspace or stranded in a
/// browser being asked to sign in again.
///
/// TWO PATHS, ONE JOURNEY:
///
///   web     the browser IS the Aura session (the refresh cookie is issued for
///           `.auraplatform.org`), so it goes straight to Finance's sign-in and
///           the rest happens in redirects.
///
///   native  the session lives in the APP and the system browser has never
///           heard of it. Aura mints a single-use, two-minute browser-entry
///           ticket and the browser opens Aura's own start endpoint, which
///           converts it into a narrow cookie and bounces to the SAME Finance
///           sign-in.
///
/// THE FAILURE THIS FILE EXISTS TO CATCH: a native client that opens Finance's
/// sign-in directly. It looks correct, it compiles, the door opens, and the
/// founder lands on a browser with no Aura session and is asked to sign in a
/// second time — the exact outcome the whole exchange exists to prevent. A test
/// that only asserted "something was launched" would pass.
library;

import 'package:aura/features/admin/areas/finance_area.dart';
import 'package:aura/features/admin/data/admin_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Captures what the app tried to open, and how.
class _FakeLauncher extends UrlLauncherPlatform with MockPlatformInterfaceMixin {
  final List<String> launched = <String>[];
  final List<PreferredLaunchMode> modes = <PreferredLaunchMode>[];
  bool succeed = true;

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
    return succeed;
  }

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    modes.add(options.mode);
    return succeed;
  }
}

class _Transport {
  _Transport();

  final List<String> requests = <String>[];
  bool ticketFails = false;
  bool destinationFails = false;
  bool eligible = true;

  Dio build() {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/v1'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add('${options.method} ${options.path}');

          if (options.path.contains('/auth/finance/destination')) {
            if (destinationFails) {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                ),
              );
            }
            return handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: {'origin': 'https://finance.example.test'},
              ),
            );
          }

          if (options.path.contains('/finance/entry')) {
            return handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: {'eligible': eligible},
              ),
            );
          }

          if (options.path.contains('/auth/finance/ticket')) {
            if (ticketFails) {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                  error: 'aura unreachable',
                ),
              );
            }
            return handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 201,
                data: {
                  'entryUrl': '/v1/auth/finance/start?ticket=abc123def456',
                  'expiresIn': 120,
                },
              ),
            );
          }

          return handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: const <String, dynamic>{},
            ),
          );
        },
      ),
    );
    return dio;
  }
}

void main() {
  late _FakeLauncher launcher;
  late UrlLauncherPlatform original;

  setUp(() {
    original = UrlLauncherPlatform.instance;
    launcher = _FakeLauncher();
    UrlLauncherPlatform.instance = launcher;
  });

  tearDown(() {
    UrlLauncherPlatform.instance = original;
  });

  Future<ProviderContainer> mount(WidgetTester tester, _Transport transport) async {
    final container = ProviderContainer(
      overrides: [
        adminRepositoryProvider.overrideWith(
          (ref) => AdminRepository(transport.build()),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: FinanceArea())),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    return container;
  }

  testWidgets('the client mints a browser-entry ticket and opens AURA, not Finance',
      (tester) async {
    final transport = _Transport();
    await mount(tester, transport);

    expect(find.text('Open Finance'), findsOneWidget);
    await tester.tap(find.text('Open Finance'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(
      transport.requests,
      contains('POST /v1/auth/finance/ticket'),
      reason: 'the handoff begins at Aura on every platform, so there is one '
          'code path to certify and no client holds Finance address',
    );
    expect(launcher.launched, hasLength(1));

    final url = launcher.launched.single;
    // Resolved against the ORIGIN of the base this repository talks to, not
    // against the base itself — the server returns a path beginning /v1 and
    // doubling it would 404.
    expect(url, 'https://api.example.test/v1/auth/finance/start?ticket=abc123def456');
    expect(url, isNot(contains('/v1/v1/')));

    // THE ASSERTION THIS FILE EXISTS FOR.
    expect(
      url,
      isNot(contains('finance.auraplatform.org')),
      reason: 'opening Finance directly on native strands the founder at a '
          'second sign-in, which is what the exchange exists to prevent',
    );
  });

  testWidgets('opens the EXTERNAL browser, not an in-app view', (tester) async {
    // An in-app web view has its own cookie jar: Finance's session would vanish
    // when the sheet closed and the founder would sign in again every time.
    final transport = _Transport();
    await mount(tester, transport);
    await tester.tap(find.text('Open Finance'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(launcher.modes.single, PreferredLaunchMode.externalApplication);
  });

  testWidgets('the launched URL carries no Aura credential or principal identity',
      (tester) async {
    final transport = _Transport();
    await mount(tester, transport);
    await tester.tap(find.text('Open Finance'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final url = launcher.launched.single;
    for (final forbidden in [
      'Bearer',
      'authorization',
      'accessToken',
      'refresh',
      '@',
      'usr_',
    ]) {
      expect(url.toLowerCase(), isNot(contains(forbidden.toLowerCase())));
    }
  });

  testWidgets('a failed handoff opens NOTHING — it does not fall back to a weaker path',
      (tester) async {
    final transport = _Transport()..ticketFails = true;
    await mount(tester, transport);

    await tester.tap(find.text('Open Finance'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(
      launcher.launched,
      isEmpty,
      reason: 'falling back to Finance sign-in here would produce the second '
          'password the exchange exists to remove',
    );
    expect(find.text('Finance could not be opened. Try again.'), findsOneWidget);
  });

  testWidgets('the failure message names no cause, no status and no authority',
      (tester) async {
    // SCOPED TO THE FAILURE, deliberately. An earlier version of this test
    // scanned every string on the screen and failed on the doorway's own
    // explanation of the mechanism ("Finance resolves your grant and opens the
    // book you are authorised for") — copy that is shown ONLY to a principal
    // who already holds the door, and which contains no figure, no book name
    // and no count. The rule is about what a FAILURE discloses, and a test that
    // cannot tell those apart forces the product to stop explaining itself.
    final transport = _Transport()..ticketFails = true;
    await mount(tester, transport);
    await tester.tap(find.text('Open Finance'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final failure = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .firstWhere((t) => t.startsWith('Finance could not be opened'));

    for (final leak in [
      'grant',
      'unauthor',
      'forbidden',
      'revoked',
      'ledger',
      'balance',
      '401',
      '403',
      '404',
      'unreachable',
      'aura unreachable',
      'DioException',
    ]) {
      expect(failure.toLowerCase(), isNot(contains(leak.toLowerCase())),
          reason: 'the failure leaked "$leak"');
    }
    expect(failure, 'Finance could not be opened. Try again.');
  });

  testWidgets('no figure, count or money ever appears on the doorway', (tester) async {
    // §17 — Aura Admin must not become a second Finance dashboard. Asserted
    // against every rendered string, on the surface a grant-holder DOES see.
    final transport = _Transport();
    await mount(tester, transport);

    // READ WHAT IS RENDERED, not what happens to be a `Text`.
    //
    // This took two goes, and both failures are worth keeping written down.
    // Scanning `find.byType(Text)` passed with "Cash on hand $12,345.00" on
    // screen, because that string sat in a SelectableText. Scanning RichText
    // as well STILL passed — a SelectableText builds an EditableText, not a
    // RichText. So both layers are read, and the scan is then made to prove it
    // can see each of them before any assertion is trusted.
    final all = [
      ...tester
          .widgetList<RichText>(find.byType(RichText))
          .map((r) => r.text.toPlainText()),
      ...tester
          .widgetList<EditableText>(find.byType(EditableText))
          .map((e) => e.controller.text),
    ].join(' | ');

    // The screen's heading is a Text; the origin line is a SelectableText.
    // Requiring both means a future refactor cannot quietly blind this test.
    expect(all, contains('Finance'), reason: 'the scan cannot see any Text');
    expect(all, contains('https://finance.example.test'),
        reason: 'the scan cannot see any SelectableText');
    expect(all, isNot(matches(RegExp(r'[$€£]\s*\d'))));
    expect(all, isNot(matches(RegExp(r'\d[\d,]*\.\d{2}'))));
    for (final leak in ['balance', 'cash', 'revenue', 'profit', 'journal', 'reconcil']) {
      expect(all.toLowerCase(), isNot(contains(leak)));
    }
  });

  testWidgets('the door re-asks Finance on entry, once, rather than polling',
      (tester) async {
    final transport = _Transport();
    await mount(tester, transport);

    // Let a generous number of frames pass. A timer-driven refresh would show
    // up here as a growing count.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final entryCalls =
        transport.requests.where((r) => r.contains('/finance/entry')).length;
    expect(entryCalls, lessThanOrEqualTo(2),
        reason: 'the doorway must not interrogate Finance on a schedule');
    expect(entryCalls, greaterThanOrEqualTo(1),
        reason: 'entering the door must re-check, or a revoked grant stays drawn');
  });

  testWidgets('the action is a real touch target and takes keyboard focus',
      (tester) async {
    final transport = _Transport();
    await mount(tester, transport);

    final button = find.ancestor(
      of: find.text('Open Finance'),
      matching: find.byType(FilledButton),
    );
    expect(button, findsOneWidget);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48.0));

    final focus = Focus.of(tester.element(find.text('Open Finance')));
    expect(focus.hasFocus || focus.hasPrimaryFocus, isTrue,
        reason: 'the screen has one action; keyboard arrival should land on it');
  });

  testWidgets('the destination shown is the one AURA names, not one compiled in',
      (tester) async {
    // A hostname in the binary needs an app store release to change. This
    // asserts the screen shows what the server said, and the transport says
    // something the production constant never would.
    final transport = _Transport();
    await mount(tester, transport);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(transport.requests, contains('GET /v1/auth/finance/destination'));
    expect(find.text('https://finance.example.test'), findsOneWidget);
    expect(find.textContaining('finance.auraplatform.org'), findsNothing);
  });

  testWidgets('when Aura cannot name the destination, the line is absent not guessed',
      (tester) async {
    final transport = _Transport()..destinationFails = true;
    await mount(tester, transport);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.textContaining('finance'), findsNothing);
    // The door still opens; it simply does not claim to know the address.
    expect(find.text('Open Finance'), findsOneWidget);
  });

  testWidgets('an ineligible principal is told nothing, and no handoff exists',
      (tester) async {
    final transport = _Transport()..eligible = false;
    await mount(tester, transport);

    expect(find.text('Open Finance'), findsNothing);
    expect(find.text('Not available'), findsOneWidget);
    expect(launcher.launched, isEmpty);
  });
}
