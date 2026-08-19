// RC3, SCREEN-BINDING HALF — whose institution is on the screen?
//
// `/institutions/me` described the caller's OLDEST membership, always. A
// member of two institutions could route to institution B while every payload
// they received described institution A, so the router's only truthful option
// was to rewrite B's URL back to A. That was safer than lying, and still
// wrong: the person asked for an institution they hold and did not get it.
//
// The endpoint now answers about a NAMED institution the caller holds, and a
// bound workspace screen reads it. The route id remains a CLAIM throughout —
// validated against membership by the route authority, and re-validated
// server-side on every read and every write.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/auth/session_bootstrap.dart';
import 'package:aura/core/auth/session_providers.dart';
import 'package:aura/core/institutions/institution_access_provider.dart';
import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/features/institutions/profile/institution_profile_screen.dart';

/// The caller holds both. `/institutions/me` picks inst-a by default; asked
/// about inst-b it answers about inst-b; asked about anything else it answers
/// with no standing at all.
Dio _institutionsDio(List<String> asked) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));

  Map<String, dynamic> workspace(String id, String name) => {
        'state': 'AUTHORIZED_SPEAKER',
        'membership': {
          'role': 'ADMIN',
          'canSpeakOfficially': true,
          'capabilities': ['MANAGE_BRANDING'],
          'institution': {'id': id, 'name': name, 'slug': id, 'status': 'VERIFIED'},
        },
        'institution': {'id': id, 'name': name, 'slug': id, 'status': 'VERIFIED'},
        'memberships': [
          {
            'role': 'ADMIN',
            'canSpeakOfficially': true,
            'capabilities': ['MANAGE_BRANDING'],
            'institution': {'id': 'inst-a', 'name': 'Institution A', 'slug': 'inst-a'},
          },
          {
            'role': 'ADMIN',
            'canSpeakOfficially': true,
            'capabilities': ['MANAGE_BRANDING'],
            'institution': {'id': 'inst-b', 'name': 'Institution B', 'slug': 'inst-b'},
          },
        ],
      };

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      if (options.path == '/institutions/me') {
        final id = (options.queryParameters['institutionId'] ?? '').toString();
        asked.add(id);
        if (id.isEmpty || id == 'inst-a') {
          return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: workspace('inst-a', 'Institution A')));
        }
        if (id == 'inst-b') {
          return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: workspace('inst-b', 'Institution B')));
        }
        // Not held: the same no-standing payload a stranger receives.
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {'state': 'SIGNED_IN_NO_STANDING', 'memberships': <dynamic>[]},
        ));
      }
      return handler.resolve(Response(
          requestOptions: options, statusCode: 200, data: {'data': <String, dynamic>{}}));
    },
  ));
  return dio;
}

Widget _app(Dio dio, {String? institutionId}) {
  return ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(dio),
      // The real bootstrap never settles under a canned transport; the
      // access provider awaits it before asking anything.
      sessionBootstrapProvider.overrideWith((ref) async {}),
      authStatusProvider.overrideWithValue(AuthStatus.authed),
      authMeDataProvider.overrideWith((ref) async => {
            'id': 'user-1',
            'accountType': 'PUBLIC',
            'identityBaselineComplete': true,
          }),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/x',
        routes: [
          GoRoute(
            path: '/x',
            builder: (context, state) => Scaffold(
              body: InstitutionProfileScreen(institutionId: institutionId),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Drains the canned transport's timers. `pumpAndSettle` cannot be used: the
/// loading state animates continuously, so it never reaches quiescence.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  testWidgets('active A + valid member B → B renders honestly', (tester) async {
    final asked = <String>[];
    await tester.pumpWidget(_app(_institutionsDio(asked), institutionId: 'inst-b'));
    await _settle(tester);

    expect(asked, contains('inst-b'),
        reason: 'The screen must ASK about the institution the route names.');
    expect(find.text('Institution B'), findsWidgets);
    expect(find.text('Institution A'), findsNothing,
        reason: 'Rendering A under B\'s URL is the defect being removed.');
  });

  testWidgets('no route institution → the ambient workspace, exactly as before',
      (tester) async {
    final asked = <String>[];
    await tester.pumpWidget(_app(_institutionsDio(asked)));
    await _settle(tester);

    expect(asked, contains(''),
        reason: 'An unscoped read is the unchanged behaviour.');
    expect(find.text('Institution A'), findsWidgets);
    await _settle(tester);
  });

  testWidgets('route names the institution already in context → renders it, unchanged',
      (tester) async {
    final asked = <String>[];
    await tester.pumpWidget(_app(_institutionsDio(asked), institutionId: 'inst-a'));
    await _settle(tester);

    // A route naming the institution already in context renders it exactly as
    // an unscoped screen would. (Before the ambient read resolves, the route
    // id legitimately looks distinct from "nothing yet", so a scoped read may
    // happen — asking about the right institution immediately is preferable
    // to waiting to discover it was the same one.)
    expect(find.text('Institution A'), findsWidgets);
    expect(find.text('Institution B'), findsNothing);
    await _settle(tester);
  });

  testWidgets('an institution the person does NOT hold shows no institution',
      (tester) async {
    // Removed membership, foreign id, stale bookmark — all the same answer,
    // and no data from any institution leaks into the refusal.
    final asked = <String>[];
    await tester.pumpWidget(
        _app(_institutionsDio(asked), institutionId: 'inst-stranger'));
    await _settle(tester);

    expect(asked, contains('inst-stranger'));
    expect(find.text('Institution A'), findsNothing);
    expect(find.text('Institution B'), findsNothing);
    expect(find.text('No institution'), findsOneWidget);
    await _settle(tester);
  });
}
