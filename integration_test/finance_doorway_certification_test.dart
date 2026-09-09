/// THE FINANCE DOORWAY, ON A REAL PLATFORM, AGAINST A REAL BACKEND.
///
///     flutter test integration_test/finance_doorway_certification_test.dart -d windows
///     flutter test integration_test/finance_doorway_certification_test.dart -d <android device>
///
/// Requires the isolated certification stack on 34999 and the Finance
/// relying-party stub on 35080. Never production: the account below is a
/// fixture literal in an ephemeral tmpfs database that dies with the container.
///
/// WHAT THIS CERTIFIES. That on this platform — real binary, real networking
/// stack, real plugin registration, real widget tree — the shipped doorway
/// resolves eligibility from Finance, draws or withholds the destination on
/// that answer alone, begins the handoff at AURA rather than at Finance, and
/// hands the browser a URL that actually completes the journey.
///
/// WHAT IT DOES NOT CERTIFY. It does not drive the operating system's browser.
/// The URL the app hands over is captured and then walked with an HTTP client,
/// which proves the URL is right and the chain completes; it does not prove
/// this platform's browser renders it. That is a separate, human observation
/// and is reported as such rather than inferred here.
library;

import 'dart:convert';

import 'package:aura/features/admin/areas/finance_area.dart';
import 'package:aura/features/admin/data/admin_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

const String _origin = 'http://localhost:34999';
const String _api = '$_origin/v1';
const String _stub = 'http://localhost:35080';
const String _email = 'doorway-a@certification.invalid';
const String _password = 'certification_only_pw_1';

class _CapturingLauncher extends UrlLauncherPlatform with MockPlatformInterfaceMixin {
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

Future<void> _setEligible(bool value) async {
  final r = await http.get(Uri.parse('$_stub/__eligible?v=$value'));
  expect(r.statusCode, 200, reason: 'the Finance stub must be running on 35080');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late String token;
  late _CapturingLauncher launcher;

  setUpAll(() async {
    final login = await http.post(
      Uri.parse('$_api/auth/login'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'email': _email, 'password': _password}),
    );
    expect(login.statusCode, inInclusiveRange(200, 299),
        reason: 'legitimate sign-in must succeed: ${login.body}');
    final decoded = jsonDecode(login.body) as Map<String, dynamic>;
    final data = (decoded['data'] ?? decoded) as Map<String, dynamic>;
    token = data['accessToken'] as String;
  });

  setUp(() {
    launcher = _CapturingLauncher();
    UrlLauncherPlatform.instance = launcher;
  });

  ProviderContainer container() {
    // BASE IS THE ORIGIN, NOT THE ORIGIN PLUS /v1.
    //
    // The repository writes absolute paths (`/v1/finance/entry`) and the app's
    // real Dio has an interceptor that de-duplicates a `/v1` already present in
    // the base. A raw Dio has no such interceptor, so pointing it at `.../v1`
    // produced `/v1/v1/finance/entry`, a 404, and a doorway that failed closed
    // — a harness fault that looked exactly like the product refusing.
    final dio = Dio(BaseOptions(
      baseUrl: _origin,
      headers: {'authorization': 'Bearer $token'},
      validateStatus: (s) => s != null && s < 500,
    ));
    return ProviderContainer(
      overrides: [
        adminRepositoryProvider.overrideWith((ref) => AdminRepository(dio)),
      ],
    );
  }

  Future<ProviderContainer> mount(WidgetTester tester) async {
    final c = container();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: FinanceArea())),
      ),
    );
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    return c;
  }

  testWidgets('with a grant, the destination is drawn on this platform', (tester) async {
    await _setEligible(true);
    await mount(tester);
    expect(find.text('Open Finance'), findsOneWidget);
    expect(find.text('Not available'), findsNothing);
  });

  testWidgets('without a grant, it is ABSENT — not disabled, not explained',
      (tester) async {
    await _setEligible(false);
    await mount(tester);

    expect(find.text('Open Finance'), findsNothing);
    expect(find.text('Not available'), findsOneWidget);

    // No teaser, no "request access", no hint that a Finance system exists.
    for (final leak in ['Finance', 'grant', 'request access', 'permission']) {
      expect(find.textContaining(leak), findsNothing, reason: 'leaked "$leak"');
    }
    await _setEligible(true);
  });

  testWidgets('the handoff begins at AURA, and the URL it hands over works',
      (tester) async {
    await _setEligible(true);
    await mount(tester);

    await tester.tap(find.text('Open Finance'));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(launcher.launched, hasLength(1), reason: 'exactly one destination');
    final url = launcher.launched.single;

    // THE ASSERTION THAT MATTERS ON A NATIVE PLATFORM. Opening Finance directly
    // would strand the person at a browser with no Aura session.
    expect(url, startsWith('$_api/auth/finance/start?ticket='));
    expect(url, isNot(contains(_stub)));
    expect(url.toLowerCase(), isNot(contains('bearer')));
    expect(url, isNot(contains(token)));

    // WALK IT. A URL that looks right and 404s is not a doorway.
    final client = http.Client();
    var next = Uri.parse(url);
    final cookies = <String, String>{};
    final chain = <String>[];
    for (var hop = 0; hop < 8; hop++) {
      final req = http.Request('GET', next)..followRedirects = false;
      if (cookies.isNotEmpty) {
        req.headers['cookie'] =
            cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
      }
      final res = await http.Response.fromStream(await client.send(req));
      chain.add('${res.statusCode} ${next.toString().split('?').first}');
      for (final raw in res.headers['set-cookie']?.split(RegExp(r',(?=[^;]+=)')) ?? const []) {
        final pair = raw.split(';').first.trim();
        final i = pair.indexOf('=');
        if (i > 0) cookies[pair.substring(0, i)] = pair.substring(i + 1);
      }
      final loc = res.headers['location'];
      if (loc == null) {
        expect(res.statusCode, 200, reason: 'chain ended badly: $chain');
        expect(res.body, contains('Finance workspace'),
            reason: 'the journey did not arrive: $chain');
        expect(res.body, contains(_email));
        break;
      }
      next = next.resolve(loc);
    }
    client.close();

    expect(chain.any((c) => c.contains('/auth/finance/start')), isTrue);
    expect(chain.any((c) => c.contains('/api/auth/sign-in')), isTrue);
    expect(chain.any((c) => c.contains('/auth/finance/authorize')), isTrue);
    expect(chain.any((c) => c.contains('/api/auth/callback')), isTrue);
  });

  testWidgets('a revoked grant removes the destination on the next entry',
      (tester) async {
    await _setEligible(true);
    await mount(tester);
    expect(find.text('Open Finance'), findsOneWidget);

    await _setEligible(false);
    await mount(tester);
    expect(find.text('Open Finance'), findsNothing,
        reason: 'entering the door must re-ask, or a revocation stays drawn');
    await _setEligible(true);
  });

  testWidgets('the destination shown is the one Aura names', (tester) async {
    await _setEligible(true);
    await mount(tester);
    expect(find.text(_stub), findsOneWidget,
        reason: 'the client must not hold an address of its own');
  });
}
