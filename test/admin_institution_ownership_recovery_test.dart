import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/auth/session_providers.dart';
import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/features/admin/data/admin_models.dart';
import 'package:aura/features/admin/presentation/admin_institution_members_screen.dart';

/// Institution Ownership Continuity — Part D certification.
///
/// Mounts the REAL platform-admin institution members screen (not a
/// minimal harness) and proves the governed emergency-recovery affordance
/// obeys its doctrine: it exists only in the recovery condition, offers
/// only backend-approved candidates, requires an explicit reason, and
/// never presents ownership as an ordinary role assignment.
void main() {
  testWidgets(
    'no recovery affordance appears when the institution has an actionable owner',
    (tester) async {
      _useLargeSurface(tester);
      await tester.pumpWidget(_wrap(_adminDio(recoveryRequired: false)));
      await tester.pumpAndSettle();

      expect(find.text('Ownership recovery required'), findsNothing);
      expect(find.text('Restore ownership…'), findsNothing);
      // The members list itself still renders normally.
      expect(find.text('Ada Owner'), findsOneWidget);
    },
  );

  testWidgets(
    'the recovery affordance appears, truthfully, only when there is no actionable owner',
    (tester) async {
      _useLargeSurface(tester);
      await tester.pumpWidget(_wrap(_adminDio(recoveryRequired: true)));
      await tester.pumpAndSettle();

      expect(find.text('Ownership recovery required'), findsOneWidget);
      expect(
        find.textContaining('no owner who can act'),
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

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      // The backend has always refused OWNER through the member-role
      // endpoint; this control must not exist anywhere in the menu.
      expect(find.text('Promote to Owner'), findsNothing);
      expect(find.text('Promote to Admin'), findsOneWidget);
    },
  );

  testWidgets(
    'recovery requires both an explicit target and an explicit reason before it can be executed',
    (tester) async {
      _useLargeSurface(tester);
      await tester.pumpWidget(_wrap(_adminDio(recoveryRequired: true)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Restore ownership…'));
      await tester.pumpAndSettle();

      final restoreButton = find.widgetWithText(TextButton, 'Restore ownership');
      expect(restoreButton, findsOneWidget);
      // Disabled until a candidate AND a reason are supplied.
      expect(tester.widget<TextButton>(restoreButton).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Owner is no longer able to act.');
      await tester.pumpAndSettle();
      // A reason alone is still not enough — a target is required too.
      expect(tester.widget<TextButton>(restoreButton).onPressed, isNull);
    },
  );

  testWidgets(
    'only backend-approved candidates are offered, and the acting admin is not among them',
    (tester) async {
      _useLargeSurface(tester);
      await tester.pumpWidget(_wrap(_adminDio(recoveryRequired: true)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Restore ownership…'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<OwnershipRecoveryCandidate>).first);
      await tester.pumpAndSettle();

      // Exactly the candidate set the backend returned. The removed
      // member, the lifecycle-ineligible member and the acting platform
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

      await tester.tap(find.text('Restore ownership…'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<OwnershipRecoveryCandidate>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Bea Member').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Owner is no longer able to act.');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Restore ownership'));
      await tester.pumpAndSettle();

      expect(recorded, hasLength(1));
      expect(recorded.single['newOwnerUserId'], 'u-bea');
      expect(recorded.single['reason'], 'Owner is no longer able to act.');

      // The reload reports the restored state, so the emergency affordance
      // disappears rather than lingering.
      expect(find.text('Ownership recovery required'), findsNothing);
    },
  );
}

void _useLargeSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1400, 1800);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _wrap(Dio dio) {
  return ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(dio),
      isAuthedProvider.overrideWithValue(true),
      isGuestSessionProvider.overrideWithValue(false),
    ],
    // AuraScaffold deliberately renders no Scaffold of its own (the app
    // shell owns it), so the harness supplies the one the shell would —
    // this screen's snackbars need a ScaffoldMessenger target exactly as
    // they have in production.
    child: const MaterialApp(
      home: Scaffold(
        body: AdminInstitutionMembersScreen(
          institutionId: 'inst-1',
          institutionName: 'Civic Institute',
        ),
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
  // restored; the screen reloads and must reflect that.
  var recovered = false;

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final path = options.path;
        final method = options.method;

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
            path == '/v1/institutions/inst-1/authority/ownership-recovery-state') {
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
            Response(requestOptions: options, statusCode: 200, data: {'ok': true}),
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
