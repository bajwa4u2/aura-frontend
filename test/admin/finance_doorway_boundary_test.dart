/// THE FINANCE DOORWAY BOUNDARY — founder §6, before this integration may be
/// called complete.
///
/// AURA_ADMIN != FINANCE_AUTHORITY. Founder-frozen, permanently.
///
/// Everything here exists to prove ONE proposition from as many sides as the
/// client can reach: the Finance destination appears because Finance said this
/// principal holds an active grant, and for NO other reason. Not because
/// somebody is an operator. Not because they own the company. Not because their
/// identity baseline is complete. Not because `admissionBasis` says anything at
/// all. Not because a user id matched a constant in this source tree.
///
/// AND WHEN IT DOES NOT APPEAR, IT IS ABSENT. Not disabled, not locked, no
/// "request access", no teaser, no balance, no count, no metadata, and no
/// indication that financial information exists at all — because "you lack
/// permission for Finance" already discloses that there is a Finance to lack
/// permission for.
///
/// TWO PROOFS THAT ARE NOT ABOUT VISIBILITY AND MATTER MORE THAN IT
/// ----------------------------------------------------------------
/// 1. Hiding a navigation item is USER EXPERIENCE, never a security boundary.
///    The server-side half of this contract — unknown `contractVersion` refused
///    before any field is interpreted, unknown `admissionBasis` conferring
///    nothing, revoked and expired grants resolving to no capability — is
///    proven in aura-finance's own suite, against the real database, because
///    that is where the boundary actually is.
/// 2. REACHABILITY. This estate has already shipped a complete, routed surface
///    that was linked from nowhere in the entire client. A destination that
///    exists only in the router is not a destination. So these tests assert the
///    door is drawn at desktop AND at phone widths, including for an operator
///    narrow enough that the overflow sheet would not otherwise exist.
library;

import 'dart:io';

import 'package:aura/core/auth/admin_access_provider.dart';
import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/features/admin/areas/finance_area.dart';
import 'package:aura/features/admin/areas/now_area.dart';
import 'package:aura/features/admin/data/admin_providers.dart';
import 'package:aura/features/admin/domain/finance_entry.dart';
import 'package:aura/features/admin/domain/operator_area.dart';
import 'package:aura/features/admin/shell/operator_shell.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PRINCIPALS
// ─────────────────────────────────────────────────────────────────────────────

/// An operator holding a broad grant — the most powerful principal this console
/// can model. The founder's rule is that this buys NOTHING in Finance.
Map<String, dynamic> _fullOperator() => {
      'userId': 'usr_operator_full',
      'roles': ['OWNER'],
      'effectivePermissions': [
        'USERS_READ',
        'MODERATION_READ',
        'AUDIT_READ',
        'SYSTEM_HEALTH_READ',
        'SETTINGS_READ',
        'EXTERNAL_CONSUMERS_READ',
      ],
      'primaryGrant': {'role': 'OWNER'},
    };

/// An operator whose grant is narrow enough that the console shows THREE areas
/// or fewer. Deliberate: at phone width the "More" affordance only exists when
/// something overflows, so this is the principal for whom a naive
/// implementation makes Finance unreachable on a phone while it works on a
/// desktop.
Map<String, dynamic> _narrowOperator() => {
      'userId': 'usr_operator_narrow',
      'roles': ['ANALYST'],
      'effectivePermissions': ['AUDIT_READ'],
      'primaryGrant': {'role': 'ANALYST'},
    };

// ─────────────────────────────────────────────────────────────────────────────
// TRANSPORT
// ─────────────────────────────────────────────────────────────────────────────

/// How Finance answered — or failed to.
enum _Entry {
  /// An active grant. The only state that opens a door.
  eligible,

  /// No grant, a revoked grant, or an expired one. Finance answers the same
  /// `false` for all three by design; the client cannot and must not tell them
  /// apart.
  notEligible,

  /// The principal has no Aura session.
  unauthenticated,

  /// The Aura-side entry endpoint does not exist yet.
  ///
  /// NOT HYPOTHETICAL — this is the LIVE PRODUCTION STATE the moment this
  /// client ships, because the Aura provider module has not been deployed and
  /// `FINANCE_*` is unset. Every principal, founder included, must see an
  /// absent destination and nothing else.
  endpointAbsent,

  /// Finance is down, unreachable, or the proxy failed. Must be
  /// INDISTINGUISHABLE from `notEligible` at this surface.
  outage,

  /// A well-formed response carrying more than the contract allows. Included
  /// because the leak this guards against is not hypothetical: a future server
  /// change could start returning books, counts or balances, and the client
  /// must read `eligible` and nothing else.
  eligibleWithExtraPayload,
}

/// Captures what the client actually asked for, so "it worked" can be
/// distinguished from "it asked the wrong thing and failed closed".
class _Transport {
  _Transport(this.entry);

  _Entry entry;
  final List<String> financeRequests = <String>[];

  Dio build(Map<String, dynamic>? adminMe) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final path = options.path;

          if (path.contains('/finance/entry')) {
            financeRequests.add(path);
            switch (entry) {
              case _Entry.eligible:
                return handler.resolve(_ok(options, {'eligible': true}));
              case _Entry.notEligible:
                return handler.resolve(_ok(options, {'eligible': false}));
              case _Entry.eligibleWithExtraPayload:
                return handler.resolve(_ok(options, {
                  'eligible': true,
                  // None of this may reach a rendered pixel.
                  'books': ['AURA_PLATFORM_LLC'],
                  'bookCount': 1,
                  'role': 'STEWARD',
                  'capabilities': ['LEDGER_READ', 'REPORT_READ'],
                  'cashMinor': '1234567',
                  'currency': 'USD',
                  'lastPostedAt': '2026-09-01T00:00:00.000Z',
                }));
              case _Entry.unauthenticated:
                return handler.reject(
                  DioException(
                    requestOptions: options,
                    response: Response<dynamic>(
                        requestOptions: options, statusCode: 401),
                    type: DioExceptionType.badResponse,
                  ),
                );
              case _Entry.endpointAbsent:
                return handler.reject(
                  DioException(
                    requestOptions: options,
                    response: Response<dynamic>(
                        requestOptions: options, statusCode: 404),
                    type: DioExceptionType.badResponse,
                  ),
                );
              case _Entry.outage:
                return handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.connectionError,
                    error: 'finance unreachable',
                  ),
                );
            }
          }

          if (path.endsWith('/admin/me')) {
            return handler.resolve(_ok(options, adminMe));
          }

          // Everything else the console reads while painting. Empty rather than
          // absent, so a surface renders its real "nothing yet" state instead
          // of an error that could be mistaken for the Finance answer.
          return handler.resolve(_ok(options, const <String, dynamic>{}));
        },
      ),
    );
    return dio;
  }

  static Response<dynamic> _ok(RequestOptions options, dynamic body) =>
      Response<dynamic>(requestOptions: options, statusCode: 200, data: body);
}

// ─────────────────────────────────────────────────────────────────────────────
// HARNESS
// ─────────────────────────────────────────────────────────────────────────────

/// Desktop: wide enough for the rail.
const Size _desktop = Size(1440, 900);

/// Phone: the bottom bar and its sheet.
const Size _phone = Size(390, 844);

/// iPad in portrait, and iPad in landscape.
///
/// A TABLET IS NOT A BIG PHONE OR A SMALL DESKTOP, and this estate has shipped
/// surfaces that composed correctly at 390 and at 1440 and were adrift at 1024.
/// Both orientations are checked because the rail/sheet decision flips between
/// them on some breakpoints.
const Size _tabletPortrait = Size(834, 1194);
const Size _tabletLandscape = Size(1194, 834);

class _Mounted {
  _Mounted(this.container, this.transport);

  final ProviderContainer container;
  final _Transport transport;
}

Future<_Mounted> _mount(
  WidgetTester tester, {
  required Map<String, dynamic>? adminMe,
  required _Entry entry,
  Size size = _desktop,
  String at = '/admin',
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final transport = _Transport(entry);

  final container = ProviderContainer(
    overrides: [
      dioProvider.overrideWithValue(transport.build(adminMe)),
      appAdminAccessProvider.overrideWith((ref) async => AppAdminAccess(
            state: adminMe == null ? AppAdminState.none : AppAdminState.admin,
            me: adminMe,
          )),
      adminMeProvider.overrideWith(
          (ref) async => adminMe == null ? null : AdminAccess.fromJson(adminMe)),
    ],
  );
  addTearDown(container.dispose);

  final router = GoRouter(
    initialLocation: at,
    routes: [
      ShellRoute(
        builder: (_, __, child) => OperatorShell(child: child),
        routes: [
          GoRoute(path: '/admin', builder: (_, __) => const NowArea()),
          GoRoute(
            path: kFinanceDestinationPath,
            builder: (_, __) => const FinanceArea(),
          ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    ),
  );

  // Frame-only pumps, then short frames. The shell's coordinator holds a
  // periodic timer, so `pumpAndSettle` never returns here.
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }

  return _Mounted(container, transport);
}

/// Unmount so the shell's timer is cancelled before the test ends. A pending
/// timer is reported against the NEXT test, which points at the wrong surface.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  // The clock is advanced only AFTER the tree is gone: with nothing left to
  // rebuild, already-scheduled timers retire instead of being reported as
  // leaked against whichever test happens to run next.
  //
  // TWENTY-FIVE SECONDS, not one. `cacheOperatorReading` schedules a 20s
  // freshness timer as its subscription is torn down, so a shorter advance
  // leaves it pending and the binding reports it against the NEXT test.
  await tester.pump(const Duration(seconds: 25));
}

/// Every piece of text currently on screen.
List<String> _visibleText(WidgetTester tester) {
  final out = <String>[];
  for (final w in tester.widgetList<Text>(find.byType(Text))) {
    final s = w.data ?? w.textSpan?.toPlainText();
    if (s != null && s.trim().isNotEmpty) out.add(s);
  }
  return out;
}

/// True when the word "Finance" appears anywhere a person could read it.
bool _financeIsMentioned(WidgetTester tester) =>
    _visibleText(tester).any((t) => t.toLowerCase().contains('finance'));

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(const {});
  });

  // ───────────────────────────────────────────────────────────────────────────
  // §6.1 — ACTIVE GRANT + ELIGIBLE PRINCIPAL → THE DESTINATION IS VISIBLE
  // ───────────────────────────────────────────────────────────────────────────

  testWidgets('an active grant draws the destination in the desktop rail',
      (tester) async {
    final m = await _mount(
        tester, adminMe: _fullOperator(), entry: _Entry.eligible);

    expect(find.text(FinanceDestination.label), findsWidgets,
        reason: 'Finance answered eligible; the door must be drawn.');
    expect(m.transport.financeRequests, isNotEmpty,
        reason: 'Visibility must come from asking Finance, not from anything '
            'this console already knew about the operator.');

    await _unmount(tester);
  });

  testWidgets('the destination is REACHABLE, not merely routed', (tester) async {
    await _mount(tester, adminMe: _fullOperator(), entry: _Entry.eligible);

    // Tap the rail item and land on the doorway. A routed surface linked from
    // nowhere has shipped in this client before; a built widget proves nothing.
    await tester.tap(find.text(FinanceDestination.label).first);
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byType(FinanceArea), findsOneWidget,
        reason: 'Following the destination must actually arrive at it.');
    expect(find.text('Open Finance'), findsOneWidget,
        reason: 'The doorway must offer the handoff, not just a title.');

    await _unmount(tester);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // §6.2 — AURA ADMIN WITHOUT A FINANCE GRANT → ABSENT
  // ───────────────────────────────────────────────────────────────────────────

  testWidgets('a full Aura operator with no grant sees no Finance anything',
      (tester) async {
    await _mount(
        tester, adminMe: _fullOperator(), entry: _Entry.notEligible);

    expect(_financeIsMentioned(tester), isFalse,
        reason: 'AURA_ADMIN != FINANCE_AUTHORITY. The most powerful operator '
            'this console models must not learn that Finance exists.');

    // ABSENT, not disabled and not offered.
    final text = _visibleText(tester).join(' | ').toLowerCase();
    for (final forbidden in [
      'request access',
      'no access',
      'locked',
      'restricted',
      'coming soon',
    ]) {
      expect(text.contains(forbidden), isFalse,
          reason: 'A teaser or a lock discloses that something is behind it.');
    }

    await _unmount(tester);
  });

  testWidgets('the same operator reaching /admin/finance directly is told '
      'nothing about Finance', (tester) async {
    await _mount(
      tester,
      adminMe: _fullOperator(),
      entry: _Entry.notEligible,
      at: kFinanceDestinationPath,
    );

    // The route is reachable by typing, so it must be SAFE to reach: it renders
    // a truthful no-destination state that names nothing.
    expect(find.text('Not available'), findsOneWidget);
    expect(_financeIsMentioned(tester), isFalse,
        reason: 'Even the chrome must not name Finance here. A header reading '
            '"Finance" over a refusal is itself the disclosure.');
    expect(find.text('Open Finance'), findsNothing);

    await _unmount(tester);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // §6.3 — REVOKED → ABSENT
  // ───────────────────────────────────────────────────────────────────────────

  testWidgets('revoking the grant removes the destination', (tester) async {
    final m = await _mount(
        tester, adminMe: _fullOperator(), entry: _Entry.eligible);
    expect(find.text(FinanceDestination.label), findsWidgets);

    // Finance now answers false — a revoked grant, an expired one, or one that
    // never existed. The client cannot tell them apart, and must not try.
    m.transport.entry = _Entry.notEligible;
    m.container.invalidate(financeEntryProvider);
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }

    expect(_financeIsMentioned(tester), isFalse,
        reason: 'Authority withdrawn is a destination withdrawn.');

    await _unmount(tester);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // §6.4 — UNAUTHENTICATED, AND §6.5 — OUTAGE, BOTH → ABSENT
  // ───────────────────────────────────────────────────────────────────────────

  for (final failure in [
    _Entry.unauthenticated,
    _Entry.outage,
    _Entry.endpointAbsent,
  ]) {
    testWidgets('${failure.name} fails closed to an absent destination',
        (tester) async {
      await _mount(tester, adminMe: _fullOperator(), entry: failure);

      expect(_financeIsMentioned(tester), isFalse,
          reason: 'Fail closed. A door that cannot be opened reads as a '
              'product fault, and a door shown to someone with no authority '
              'discloses that something is behind it.');

      await _unmount(tester);
    });
  }

  testWidgets('an outage is indistinguishable from a revocation',
      (tester) async {
    // Rendered identically ON PURPOSE. Telling them apart here would leak the
    // existence of financial authority to a principal who does not hold it;
    // operators diagnose Finance from Finance's own health.
    await _mount(tester, adminMe: _fullOperator(), entry: _Entry.outage);
    final outage = _visibleText(tester);
    await _unmount(tester);

    await _mount(tester, adminMe: _fullOperator(), entry: _Entry.notEligible);
    final revoked = _visibleText(tester);
    await _unmount(tester);

    // And the state this client actually ships in: the Aura endpoint not
    // deployed yet. Identical again, so shipping ahead of the provider is
    // indistinguishable from having no grant — which is the correct
    // pre-activation behaviour rather than a broken-looking console.
    await _mount(tester, adminMe: _fullOperator(), entry: _Entry.endpointAbsent);
    final notDeployed = _visibleText(tester);
    await _unmount(tester);

    expect(outage, equals(revoked));
    expect(notDeployed, equals(revoked));
  });

  // ───────────────────────────────────────────────────────────────────────────
  // §6.6 — NO FINANCIAL METADATA LEAKS THROUGH THE ADMIN DESTINATION
  // ───────────────────────────────────────────────────────────────────────────

  testWidgets('a richer payload than the contract allows leaks nothing',
      (tester) async {
    await _mount(
      tester,
      adminMe: _fullOperator(),
      entry: _Entry.eligibleWithExtraPayload,
      at: kFinanceDestinationPath,
    );

    // The door opens, because `eligible` is true.
    expect(find.text('Open Finance'), findsOneWidget);

    // And nothing else in that payload reached a pixel.
    final text = _visibleText(tester).join(' | ');
    for (final leak in [
      'AURA_PLATFORM_LLC',
      'STEWARD',
      'LEDGER_READ',
      'REPORT_READ',
      '1234567',
      '12,345.67',
      'USD',
      '2026-09-01',
    ]) {
      expect(text.contains(leak), isFalse,
          reason: 'The Admin destination must carry no financial fact. '
              'Found: $leak');
    }

    await _unmount(tester);
  });

  testWidgets('the doorway itself displays no financial content',
      (tester) async {
    await _mount(
      tester,
      adminMe: _fullOperator(),
      entry: _Entry.eligible,
      at: kFinanceDestinationPath,
    );

    final text = _visibleText(tester).join(' | ').toLowerCase();
    // Everything on this screen must be true of the Finance SYSTEM, never of
    // the company's finances. A second frontend over one ledger is how two
    // frontends start disagreeing.
    for (final financial in [
      'balance',
      'cash',
      'revenue',
      'expense',
      'invoice',
      'profit',
      'journal',
      'ledger',
      'transaction',
      'account balance',
      r'$',
    ]) {
      expect(text.contains(financial), isFalse,
          reason: 'The doorway must show no financial content. Found: '
              '$financial');
    }

    await _unmount(tester);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // §6.7 — MOBILE. NO CAPABILITY DISAPPEARS BECAUSE THE VIEWPORT DID.
  // ───────────────────────────────────────────────────────────────────────────

  testWidgets('the destination is reachable at phone width', (tester) async {
    await _mount(
      tester,
      adminMe: _fullOperator(),
      entry: _Entry.eligible,
      size: _phone,
    );

    // Finance never takes a primary slot from an operator area; it lives in the
    // sheet, which must therefore be openable.
    expect(find.text('More'), findsOneWidget);
    await tester.tap(find.text('More'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.text(FinanceDestination.label), findsOneWidget,
        reason: 'The door must exist on a phone, not only on a desktop.');

    await _unmount(tester);
  });

  testWidgets('a narrow operator with a grant still reaches Finance on a phone',
      (tester) async {
    // THE CASE A NAIVE IMPLEMENTATION LOSES. This operator sees two areas, so
    // nothing overflows and the "More" affordance would not exist at all —
    // making a granted destination unreachable on the platform where it is
    // hardest to notice.
    await _mount(
      tester,
      adminMe: _narrowOperator(),
      entry: _Entry.eligible,
      size: _phone,
    );

    expect(find.text('More'), findsOneWidget,
        reason: 'The sheet must exist whenever Finance does.');
    await tester.tap(find.text('More'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.text(FinanceDestination.label), findsOneWidget);

    await _unmount(tester);
  });

  testWidgets('the destination is reachable at TABLET geometry, both orientations',
      (tester) async {
    // Whether an iPad gets the rail or the sheet is a layout decision this test
    // deliberately does not assert. What it asserts is the thing that matters:
    // by ONE of those routes the door is reachable, at both orientations, and
    // the founder is never handed a tablet with no way in.
    for (final size in [_tabletPortrait, _tabletLandscape]) {
      await _mount(
        tester,
        adminMe: _fullOperator(),
        entry: _Entry.eligible,
        size: size,
      );

      var found = find.text(FinanceDestination.label).evaluate().isNotEmpty;
      if (!found && find.text('More').evaluate().isNotEmpty) {
        await tester.tap(find.text('More'));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        found = find.text(FinanceDestination.label).evaluate().isNotEmpty;
      }

      expect(found, isTrue,
          reason: 'no route to Finance at ${size.width}x${size.height}');
      await _unmount(tester);
    }
  });

  testWidgets('a tablet without a grant is told nothing, in either orientation',
      (tester) async {
    // The control. Without it the test above would pass on a build that showed
    // Finance to everyone at tablet width.
    for (final size in [_tabletPortrait, _tabletLandscape]) {
      await _mount(
        tester,
        adminMe: _fullOperator(),
        entry: _Entry.notEligible,
        size: size,
      );
      if (find.text('More').evaluate().isNotEmpty) {
        await tester.tap(find.text('More'));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      }
      expect(find.text(FinanceDestination.label), findsNothing,
          reason: 'Finance leaked at ${size.width}x${size.height}');
      await _unmount(tester);
    }
  });

  test('the doorway measure composes for a tablet, not for a phone or a desktop', () {
    // THE PART OF THE TABLET STORY THAT CAN BE ASSERTED EXACTLY.
    //
    // An earlier version of this measured the laid-out paragraph and compared
    // it to the pane. It could not tell a full-bleed layout from a correctly
    // constrained one — 998 against 966 once the rail and the card padding had
    // taken their share — so it passed under the very mutation it existed to
    // catch. The rule itself has no such ambiguity.
    const phone = 390.0;
    const tabletPortrait = 834.0;
    const tabletLandscape = 1194.0;
    const desktop = 1440.0;

    // A phone gets the whole pane; there is nothing to centre it in.
    expect(financeDoorwayMeasure(phone), phone);

    // A tablet gets a real gutter AND a measure wider than a phone column.
    for (final pane in [tabletPortrait, tabletLandscape]) {
      final m = financeDoorwayMeasure(pane);
      expect(m, greaterThan(phone),
          reason: 'a phone column adrift in a \$pane pane');
      expect(pane - m, greaterThanOrEqualTo(64),
          reason: 'prose running to the edge of a \$pane pane');
    }

    // Beyond a point the measure stops growing, or a wide desktop turns the
    // body copy into a single unreadable line.
    expect(financeDoorwayMeasure(desktop), financeDoorwayMeasure(2560));
    expect(financeDoorwayMeasure(desktop), lessThan(desktop / 1.5));

    // Monotonic: a wider pane never yields a narrower measure.
    var previous = 0.0;
    for (var w = 320.0; w <= 2000; w += 10) {
      final m = financeDoorwayMeasure(w);
      expect(m, greaterThanOrEqualTo(previous), reason: 'measure shrank at \$w');
      previous = m;
    }
  });

  testWidgets('a narrow operator WITHOUT a grant gains no sheet',
      (tester) async {
    // The control for the test above. If "More" appeared regardless, the
    // previous assertion would prove nothing about Finance.
    await _mount(
      tester,
      adminMe: _narrowOperator(),
      entry: _Entry.notEligible,
      size: _phone,
    );

    expect(find.text('More'), findsNothing);
    expect(_financeIsMentioned(tester), isFalse);

    await _unmount(tester);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // FROZEN — isOperator != FinanceGrant
  // ───────────────────────────────────────────────────────────────────────────
  //
  // The operator check answers exactly ONE question: can this principal reach
  // the Aura Admin shell, which is where the doorway happens to be rendered
  // today. It is REACHABILITY, never Finance authority.
  //
  // Once inside that surface, FinanceGrant alone decides. The distinction has
  // to be frozen now, while the doorway lives in Admin, because the moment
  // accountants and auditors enter Finance directly — without ever being Aura
  // administrators — an `isOperator` that had quietly become a Finance
  // precondition would lock out exactly the people the system is for.

  group('Finance visibility is a function of the grant, and of nothing else', () {
    testWidgets('the SAME grant answer yields the SAME visibility for very '
        'different operators', (tester) async {
      // A principal holding six permissions including OWNER, and one holding a
      // single AUDIT_READ. If operator breadth leaked into Finance visibility
      // at all, these two would not agree.
      for (final eligible in [true, false]) {
        final entry = eligible ? _Entry.eligible : _Entry.notEligible;

        await _mount(tester, adminMe: _fullOperator(), entry: entry);
        final full = _financeIsMentioned(tester);
        await _unmount(tester);

        await _mount(tester, adminMe: _narrowOperator(), entry: entry);
        final narrow = _financeIsMentioned(tester);
        await _unmount(tester);

        expect(full, equals(eligible),
            reason: 'A broad operator must see Finance exactly when Finance '
                'says they hold a grant.');
        expect(narrow, equals(full),
            reason: 'isOperator != FinanceGrant. Operator breadth must not '
                'move Finance visibility by one pixel.');
      }
    });

    testWidgets('the OWNER role buys nothing', (tester) async {
      // Named separately because "owner" is the specific shortcut the founder
      // forbade: never `if (owner) show Finance`.
      await _mount(tester, adminMe: _fullOperator(), entry: _Entry.notEligible);

      final authority = _fullOperator();
      expect(authority['roles'], contains('OWNER'));
      expect(_financeIsMentioned(tester), isFalse);

      await _unmount(tester);
    });

    test('the shell resolves Finance from the grant provider alone', () {
      // The behavioural tests above prove the two agree today. This proves WHY,
      // so a future edit that starts consulting authority fails here rather
      // than passing until somebody happens to test the narrow operator.
      final source =
          File('lib/features/admin/shell/operator_shell.dart').readAsStringSync();

      // The two widgets that render the destination, and the header gate.
      for (final region in ['_FinanceRailItem', '_FinanceSheetEntry']) {
        final start = source.indexOf('class $region');
        expect(start, greaterThan(-1), reason: '$region must exist to be checked.');
        // To the end of the class: the next top-level `class ` declaration.
        final next = RegExp(r'^class ', multiLine: true)
            .allMatches(source)
            .map((m) => m.start)
            .firstWhere((i) => i > start, orElse: () => source.length);
        final body = source.substring(start, next);

        expect(body, contains('financeDestinationVisibleProvider'),
            reason: '$region must resolve Finance authority from the grant.');
        for (final forbidden in [
          'authority',
          'isOperator',
          'OperatorCapability',
          'OperatorAuthority',
          'OperatorArea',
          'appAdminAccess',
        ]) {
          expect(body.contains(forbidden), isFalse,
              reason: '$region must not consult "$forbidden". The operator '
                  'check is reachability; FinanceGrant is authority.');
        }
      }

      // And the header names Finance only on the grant bit, never on the route
      // alone and never on authority.
      expect(source, contains('final financeVisible = ref.watch(financeDestinationVisibleProvider)'));
      expect(source, contains('final namesFinance = onFinance && financeVisible'));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // §6.8 — STRUCTURAL. THE FORBIDDEN IMPLEMENTATIONS CANNOT BE WRITTEN HERE.
  // ───────────────────────────────────────────────────────────────────────────

  group('the forbidden authority shortcuts are absent from the source', () {
    /// The files that decide whether the Finance destination is drawn.
    final governed = <String>[
      'lib/features/admin/domain/finance_entry.dart',
      'lib/features/admin/areas/finance_area.dart',
    ];

    /// Comments and string literals stripped: the rule is about CODE. These
    /// files describe the forbidden shortcuts at length in prose, and a naive
    /// scan would match its own documentation.
    String executable(String source) => source
        .replaceAll(RegExp(r'///.*'), ' ')
        .replaceAll(RegExp(r'//.*'), ' ')
        .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), ' ')
        .replaceAll(RegExp(r"'[^'\n]*'"), "''")
        .replaceAll(RegExp(r'"[^"\n]*"'), '""');

    test('never: if isAdmin, if owner, if baseline complete, if member', () {
      for (final path in governed) {
        final code = executable(File(path).readAsStringSync());
        for (final forbidden in [
          'isAdmin',
          'isOperator',
          'isOwner',
          'OperatorCapability',
          'OperatorAuthority',
          'operatorAuthorityProvider',
          'appAdminAccessProvider',
          'adminMeProvider',
          'admissionBasis',
          'identityBaselineComplete',
          'emailVerified',
        ]) {
          expect(code.contains(forbidden), isFalse,
              reason: '$path decides Finance visibility. It must consult a '
                  'FinanceGrant and nothing else; found "$forbidden".');
        }
      }
    });

    test('no founder principal id is hardcoded anywhere in the doorway', () {
      // An authorization exception written into the client is one nobody can
      // revoke, audit, or scope to a book.
      final suspicious = RegExp(
        r'usr_[A-Za-z0-9_-]{6,}|'
        r'\b[cC][a-z0-9]{24}\b|' // cuid
        r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|'
        r'\bSakhawat\b|\bMuhammad\b',
      );
      for (final path in governed) {
        final source = File(path).readAsStringSync();
        final hits = suspicious.allMatches(source).map((m) => m.group(0)!);
        expect(hits, isEmpty,
            reason: '$path appears to name a specific person or principal. '
                'Finance authority is a FinanceGrant, never an identity '
                'written into a client build.');
      }
    });

    test('Finance is not modelled as an OperatorArea', () {
      // `OperatorArea.now` carries `anyOf: []`, which makes it visible to ANY
      // operator holding admin authority at all. An area is therefore the one
      // shape Finance must never take: it would BE the forbidden
      // `if isAdmin then show Finance`, structurally.
      for (final area in OperatorArea.values) {
        expect(area.path, isNot(equals(kFinanceDestinationPath)));
        expect(area.label.toLowerCase(), isNot(contains('finance')));
      }
    });

    test('the console reads exactly one field from Finance', () {
      final source =
          File('lib/features/admin/data/admin_repository.dart').readAsStringSync();
      final method = RegExp(
        r'Future<FinanceEntry> fetchFinanceEntry\(\) async \{[\s\S]*?\n  \}',
      ).firstMatch(source);
      expect(method, isNotNull, reason: 'fetchFinanceEntry must exist to read.');

      final body = method!.group(0)!;
      final fields = RegExp(r"body\['([^']+)'\]")
          .allMatches(body)
          .map((m) => m.group(1)!)
          .toSet();
      expect(fields, equals({'eligible'}),
          reason: 'The contract is one boolean. Reading any other field would '
              'give a future server something to leak through.');
    });
  });
}
