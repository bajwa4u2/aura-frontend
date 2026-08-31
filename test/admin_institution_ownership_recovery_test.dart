import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/features/admin/areas/subject_institution_area.dart';
import 'package:aura/features/admin/domain/operator_authority_provider.dart';
import 'package:aura/features/admin/domain/operator_capability.dart';

/// Institution Ownership Continuity — Part D certification.
///
/// PORTED 2026-08-31, not rewritten. The screen this used to mount
/// (`admin_institution_members_screen.dart`) was one of the seventeen the
/// Admin Operator Hub reconstruction deleted; the DOCTRINE it certifies is
/// unchanged and now lives in `SubjectInstitutionArea`. The assertions below
/// are the same claims against the surface that answers them today:
///
///   * the affordance exists only in the recovery condition,
///   * it names the owner of record without leaking a lifecycle enum,
///   * ownership is never offered as an ordinary role assignment,
///   * an explicit target and an explicit reason are both required,
///   * only backend-approved candidates are offered,
///   * executing posts the governed payload and the affordance then goes.
///
/// Two things changed in HOW the surface asks, and both are stated rather
/// than quietly absorbed: the target is chosen by acting on a named candidate
/// rather than by a dropdown, and the reason is collected by the governed
/// action ceremony rather than by a bespoke dialog. The requirement that both
/// exist before anything is posted is identical.
void main() {
  testWidgets(
    'no recovery affordance appears when the institution has an actionable owner',
    (tester) async {
      _useLargeSurface(tester);
      await tester.pumpWidget(_wrap(_adminDio(recoveryRequired: false)));
      await tester.pumpAndSettle();

      expect(find.text('Ownership'), findsNothing);
      expect(find.text('Appoint as owner'), findsNothing);
      // The membership list itself still renders normally.
      expect(find.text('Ada Owner'), findsOneWidget);
    },
  );

  testWidgets(
    'the recovery affordance appears, truthfully, only when there is no actionable owner',
    (tester) async {
      _useLargeSurface(tester);
      await tester.pumpWidget(_wrap(_adminDio(recoveryRequired: true)));
      await tester.pumpAndSettle();

      expect(find.text('Ownership'), findsOneWidget);
      expect(
        find.textContaining('nobody who can act for it'),
        findsOneWidget,
      );
      // Names the prior owner-of-record without exposing any internal
      // lifecycle enum name or moderation rationale.
      expect(find.textContaining('Ada Owner'), findsWidgets);
      expect(find.textContaining('MODERATION_DISABLED'), findsNothing);
      expect(find.textContaining('SELF_DELETED'), findsNothing);
    },
  );

  testWidgets(
    'ownership is never offered as an ordinary role assignment',
    (tester) async {
      _useLargeSurface(tester);
      await tester.pumpWidget(_wrap(_adminDio(recoveryRequired: false)));
      await tester.pumpAndSettle();

      // The backend has always refused OWNER through the member-role
      // endpoint. The reconstruction goes further than the screen it
      // replaces: membership offers no role assignment at all, so there is
      // no menu for the control to be absent from.
      expect(find.text('Promote to Owner'), findsNothing);
      expect(find.text('Promote to Admin'), findsNothing);
      // And an owner cannot even be removed here — the lock says why.
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'recovery requires both an explicit target and an explicit reason',
    (tester) async {
      _useLargeSurface(tester);
      await tester.pumpWidget(_wrap(_adminDio(recoveryRequired: true)));
      await tester.pumpAndSettle();

      // THE TARGET IS THE ACT. There is no "recover ownership" control that
      // could be pressed before a person is chosen: the only way in is
      // through a named candidate.
      final appoint = find.text('Appoint as owner');
      expect(appoint, findsOneWidget);
      await tester.tap(appoint);
      await tester.pumpAndSettle();

      // The ceremony then withholds the act until a reason is written.
      final confirm = find.widgetWithText(FilledButton, 'Appoint');
      expect(confirm, findsOneWidget);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

      await tester.enterText(
        find.byType(TextField),
        'Owner is no longer able to act.',
      );
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    },
  );

  testWidgets(
    'only backend-approved candidates are offered, and the acting admin is not among them',
    (tester) async {
      _useLargeSurface(tester);
      await tester.pumpWidget(_wrap(_adminDio(recoveryRequired: true)));
      await tester.pumpAndSettle();

      // Exactly the candidate set the backend returned. The removed member,
      // the lifecycle-ineligible member and the acting platform
      // administrator were all excluded server-side and therefore cannot
      // appear here.
      expect(find.textContaining('Bea Member'), findsWidgets);
      expect(find.textContaining('Removed Member'), findsNothing);
      expect(find.textContaining('Disabled Member'), findsNothing);
      expect(find.textContaining('Platform Admin'), findsNothing);
    },
  );

  testWidgets(
    'executing recovery posts the governed payload and refreshes into the restored state',
    (tester) async {
      _useLargeSurface(tester);
      final recorded = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        _wrap(_adminDio(recoveryRequired: true, recordedPosts: recorded)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Appoint as owner'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'Owner is no longer able to act.',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Appoint'));
      await tester.pumpAndSettle();

      expect(recorded, hasLength(1));
      expect(recorded.single['newOwnerUserId'], 'u-bea');
      expect(recorded.single['reason'], 'Owner is no longer able to act.');

      // The outcome is reported before the sheet closes — a decision the
      // operator cannot see land is a decision they will take twice.
      expect(find.textContaining('is now the owner'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Close'));
      await tester.pumpAndSettle();

      // The reload reports the restored state, so the emergency affordance
      // disappears rather than lingering.
      expect(find.text('Appoint as owner'), findsNothing);
    },
  );
}

void _useLargeSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1400, 2400);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// An operator holding what this surface asks for, and nothing more.
///
/// Overridden at the authority provider rather than faked through
/// `/v1/admin/me`, because the probe machinery in front of that endpoint is a
/// different subject with its own tests.
final _operator = OperatorAuthority(
  userId: 'u-admin',
  roles: const {OperatorRole.admin},
  capabilities: const {
    OperatorCapability.institutionsRead,
    OperatorCapability.institutionsWrite,
    OperatorCapability.verificationRead,
    OperatorCapability.verificationWrite,
  },
  unknownCapabilities: const {},
);

Widget _wrap(Dio dio) {
  return ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(dio),
      operatorAuthorityProvider.overrideWithValue(AsyncValue.data(_operator)),
    ],
    // The operator shell owns the chrome in production; the harness supplies
    // the Scaffold the shell would, because the governed action ceremony
    // opens a modal sheet and needs a Navigator and an Overlay under it.
    child: const MaterialApp(
      home: Scaffold(
        body: SubjectInstitutionArea(institutionId: 'inst-1'),
      ),
    ),
  );
}

Dio _adminDio({
  required bool recoveryRequired,
  List<Map<String, dynamic>>? recordedPosts,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  // After a successful recovery the backend reports the institution as
  // restored; the surface reloads and must reflect that.
  var recovered = false;

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final path = options.path;
        final method = options.method;

        if (method == 'GET' && path == '/v1/institutions/admin') {
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'items': [
                  {
                    'id': 'inst-1',
                    'name': 'Civic Institute',
                    'slug': 'civic-institute',
                    'status': 'VERIFIED',
                    'memberCount': 2,
                    'verifiedAt': '2026-01-01T00:00:00.000Z',
                  },
                ],
              },
            ),
          );
        }

        if (method == 'GET' && path == '/v1/institutions/inst-1/members') {
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'members': [
                  {
                    'id': 'm-ada',
                    'userId': 'u-ada',
                    'role': 'OWNER',
                    'joinedAt': '2026-01-01T00:00:00.000Z',
                    'user': {'displayName': 'Ada Owner', 'handle': 'ada'},
                  },
                  {
                    'id': 'm-bea',
                    'userId': 'u-bea',
                    'role': 'MEMBER',
                    'joinedAt': '2026-01-02T00:00:00.000Z',
                    'user': {'displayName': 'Bea Member', 'handle': 'bea'},
                  },
                ],
              },
            ),
          );
        }

        if (method == 'GET' &&
            path ==
                '/v1/institutions/inst-1/authority/ownership-recovery-state') {
          final needsRecovery = recoveryRequired && !recovered;
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: needsRecovery
                  ? {
                      'ok': true,
                      'recoveryRequired': true,
                      'ownerOfRecord': {
                        'userId': 'u-ada',
                        'displayName': 'Ada Owner',
                        'handle': 'ada',
                      },
                      // Only eligible candidates — the backend already
                      // excluded removed/ineligible members and the acting
                      // platform administrator.
                      'candidates': [
                        {
                          'userId': 'u-bea',
                          'role': 'MEMBER',
                          'displayName': 'Bea Member',
                          'handle': 'bea',
                        },
                      ],
                    }
                  : {
                      'ok': true,
                      'recoveryRequired': false,
                      'actionableOwnerUserId': 'u-ada',
                      'ownerOfRecord': null,
                      'candidates': <dynamic>[],
                    },
            ),
          );
        }

        if (method == 'POST' &&
            path ==
                '/v1/institutions/inst-1/authority/emergency-recover-ownership') {
          recordedPosts?.add(Map<String, dynamic>.from(options.data as Map));
          recovered = true;
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'ok': true},
            ),
          );
        }

        // Everything else this area reads is answered EMPTY rather than 404,
        // so an unrelated section failing cannot be mistaken for the
        // ownership assertions failing.
        if (method == 'GET') {
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'items': <dynamic>[]},
            ),
          );
        }

        return handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 404,
            data: 'unhandled ${options.method} $path',
          ),
        );
      },
    ),
  );
  return dio;
}
