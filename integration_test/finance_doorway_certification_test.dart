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
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
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

/// True when this run is on a physical handset rather than a desktop or a
/// browser. The difference matters for exactly one thing: the test harness's
/// connection does not survive a driven lifecycle transition there.
final bool _onDevice = !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

Future<void> _setEligible(bool value) async {
  final r = await http.get(Uri.parse('$_stub/__eligible?v=$value'));
  expect(r.statusCode, 200, reason: 'the Finance stub must be running on 35080');
}

/// Make the eligibility question FAIL rather than answer.
///
/// An outage and a revocation must be indistinguishable at this surface — both
/// mean "no destination" — but they must be produced by different causes, or
/// the fail-closed claim is only ever tested one way.
Future<void> _setOutage(bool value) async {
  final r = await http.get(Uri.parse('$_stub/__outage?v=$value'));
  expect(r.statusCode, 200);
}

/// Expire every outstanding browser-entry ticket.
///
/// A test running ON A DEVICE cannot reach the host's database or its clock.
/// The stub can, and it is certification scaffolding rather than product — so
/// expiry is provable here without a single test-only branch in Aura's auth
/// path.
Future<void> _expireTickets() async {
  final r = await http.get(Uri.parse('$_stub/__expire-tickets'));
  expect(r.statusCode, 200);
}

/// Walk a handed-over URL exactly as a browser would, and report where it ends.
Future<({int status, String body, List<String> chain})> _walk(String url) async {
  final client = http.Client();
  var next = Uri.parse(url);
  final cookies = <String, String>{};
  final chain = <String>[];
  try {
    for (var hop = 0; hop < 8; hop++) {
      final req = http.Request('GET', next)..followRedirects = false;
      if (cookies.isNotEmpty) {
        req.headers['cookie'] =
            cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
      }
      final res = await http.Response.fromStream(await client.send(req));
      chain.add('${res.statusCode} ${next.toString().split('?').first}');
      for (final raw
          in res.headers['set-cookie']?.split(RegExp(r',(?=[^;]+=)')) ?? const []) {
        final pair = raw.split(';').first.trim();
        final i = pair.indexOf('=');
        if (i > 0) cookies[pair.substring(0, i)] = pair.substring(i + 1);
      }
      final loc = res.headers['location'];
      if (loc == null) return (status: res.statusCode, body: res.body, chain: chain);
      next = next.resolve(loc);
    }
    return (status: 0, body: '', chain: chain);
  } finally {
    client.close();
  }
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
    final walked = await _walk(url);
    expect(walked.status, 200, reason: 'chain ended badly: ${walked.chain}');
    expect(walked.body, contains('Finance workspace'),
        reason: 'the journey did not arrive: ${walked.chain}');
    expect(walked.body, contains(_email));

    final chain = walked.chain;
    expect(chain.any((c) => c.contains('/auth/finance/start')), isTrue);
    expect(chain.any((c) => c.contains('/api/auth/sign-in')), isTrue);
    expect(chain.any((c) => c.contains('/auth/finance/authorize')), isTrue);
    expect(chain.any((c) => c.contains('/api/auth/callback')), isTrue);

    // WHAT BROWSER HISTORY WOULD HOLD. Every URL in the chain, checked.
    final history = '${chain.join(' ')} $url';
    expect(history, isNot(contains(token)));
    expect(history.toLowerCase(), isNot(contains('bearer')));
    expect(history, isNot(contains(_email)));
  });

  testWidgets('A DUPLICATE TAP does not strand the person', (tester) async {
    await _setEligible(true);
    await mount(tester);

    // Two presses in quick succession, as a thumb produces.
    await tester.tap(find.text('Open Finance'));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('Open Finance'), warnIfMissed: false);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // The action disables itself while opening, so a second tap should not mint
    // a second ticket — and whatever WAS handed over must still work.
    expect(launcher.launched.length, lessThanOrEqualTo(2));
    for (final u in launcher.launched) {
      final w = await _walk(u);
      expect(w.body, contains('Finance workspace'),
          reason: 'a duplicate tap produced a dead door: ${w.chain}');
    }
  });

  testWidgets('AN EXPIRED TICKET is refused, without explaining itself',
      (tester) async {
    await _setEligible(true);
    await mount(tester);
    await tester.tap(find.text('Open Finance'));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final url = launcher.launched.single;

    await _expireTickets();

    final w = await _walk(url);
    expect(w.body, isNot(contains('Finance workspace')));
    expect(w.status, 400);
    expect(w.body, contains('finance:entry_invalid'));
    // Says nothing about WHY. An expired ticket and a forged one look the same
    // to whoever presented it.
    expect(w.body.toLowerCase(), isNot(contains('expired')));
  });

  testWidgets('A REPLAYED ticket names nobody the second time', (tester) async {
    await _setEligible(true);
    await mount(tester);
    await tester.tap(find.text('Open Finance'));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final url = launcher.launched.single;

    final first = await _walk(url);
    expect(first.body, contains('Finance workspace'));

    // The same handed-over URL again.
    //
    // REFUSED AT AURA'S OWN DOOR, and earlier than I first assumed. I expected
    // it to reach Finance and be refused there; it does not get that far,
    // because `/start` finds the ticket spent and stops. Refusing before the
    // browser leaves Aura is the better behaviour of the two, and asserting the
    // one I expected would have failed a correct product.
    final second = await _walk(url);
    expect(second.body, isNot(contains('Finance workspace')));
    expect(second.status, 400);
    expect(second.body, contains('finance:entry_invalid'));
    expect(second.chain.any((c) => c.contains('/api/auth/')), isFalse,
        reason: 'a spent ticket must not even start the journey');
  });

  testWidgets('A PROVIDER OUTAGE leaves Aura stable and the destination absent',
      (tester) async {
    await _setOutage(true);
    await mount(tester);

    // Absent, exactly as a revocation is — an outage must not be
    // distinguishable from "no grant" at this surface.
    expect(find.text('Open Finance'), findsNothing);
    expect(find.text('Not available'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'the console must not crash');

    // No spinner left behind, and nothing about Finance being unwell.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    for (final leak in ['unavailable', 'error', 'unreachable', '503', 'retry']) {
      expect(find.textContaining(leak), findsNothing, reason: 'leaked "$leak"');
    }

    await _setOutage(false);
    await mount(tester);
    expect(find.text('Open Finance'), findsOneWidget,
        reason: 'and it recovers when Finance does');
  });

  testWidgets('NO FINANCIAL METADATA reaches the doorway', (tester) async {
    await _setEligible(true);
    await mount(tester);

    final all = [
      ...tester
          .widgetList<RichText>(find.byType(RichText))
          .map((r) => r.text.toPlainText()),
      ...tester
          .widgetList<EditableText>(find.byType(EditableText))
          .map((e) => e.controller.text),
    ].join(' | ');
    expect(all, contains('Finance'), reason: 'the scan cannot see the screen');

    expect(all, isNot(matches(RegExp(r'[$€£]\s*\d'))));
    expect(all, isNot(matches(RegExp(r'\d[\d,]*\.\d{2}'))));
    for (final leak in [
      'balance',
      'cash',
      'revenue',
      'profit',
      'journal',
      'reconcil',
      'ledger',
    ]) {
      expect(all.toLowerCase(), isNot(contains(leak)), reason: 'leaked "$leak"');
    }
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

  // DELIBERATELY LAST.
  //
  // Driving the binding to `paused` on a PHYSICAL device backgrounds the
  // application for real, and the test harness's connection does not always
  // survive it — twice this run stalled at exactly this point and four later
  // cases never executed. Ordering is not a fix for that and is not presented
  // as one; it is so that a stall costs this case only, instead of every case
  // after it. The stall itself is recorded as a harness limit, not as a
  // product finding.
  testWidgets('BACKGROUND AND RESUME does not lose or leak the doorway',
      (tester) async {
    await _setEligible(true);
    await mount(tester);
    expect(find.text('Open Finance'), findsOneWidget);

    if (_onDevice) {
      // NOT SIMULATED HERE, AND NOT CLAIMED HERE.
      //
      // Driving the binding's lifecycle on a physical handset detaches the
      // test harness: the run stalls at this line and never returns, which
      // cost four later cases twice before it was understood. It is not
      // `paused` alone — omitting it did not help.
      //
      // So the DEVICE evidence for a real background comes from outside this
      // harness, by backgrounding the installed application with adb and
      // bringing it forward again, which is a genuine OS background rather
      // than a simulation of one. It is recorded as its own evidence.
      //
      // What is still asserted here is the half that governs the doorway's
      // state on return: the destination is re-resolved on entry, and a grant
      // revoked while the app was away is honoured.
      await _setEligible(false);
      await mount(tester);
      expect(find.text('Open Finance'), findsNothing,
          reason: 'a revocation during a trip to the browser must be honoured');
      await _setEligible(true);
      await mount(tester);
      expect(find.text('Open Finance'), findsOneWidget,
          reason: 'and the door returns when the grant does');
      return;
    }

    // DESKTOP AND WEB: the full transition, including `paused`.
    //
    // Flutter asserts on the transitions themselves — inactive -> paused is
    // invalid because `hidden` sits between them — so this is the real
    // sequence rather than an abbreviation of it.
    final binding = TestWidgetsFlutterBinding.instance;
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      binding.handleAppLifecycleStateChanged(state);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 200));
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      binding.handleAppLifecycleStateChanged(state);
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Open Finance'), findsOneWidget,
        reason: 'the door must survive a trip to the browser and back');
    expect(tester.takeException(), isNull);

    await _setEligible(false);
    await mount(tester);
    expect(find.text('Open Finance'), findsNothing);
    await _setEligible(true);
  });
}
