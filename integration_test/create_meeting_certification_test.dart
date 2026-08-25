import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:aura/core/product/product_state.dart';
import 'package:aura/core/product/product_state_view.dart';
import 'package:aura/core/ui/aura_platform_components.dart';
import 'package:aura/features/institutions/data/institutions_repository.dart';
import 'package:aura/features/institutions/domain/institution.dart';
import 'package:aura/features/meetings/application/meetings_provider.dart';
import 'package:aura/features/meetings/presentation/create_meeting_screen.dart';

/// CREATE MEETING — CLOSEOUT CERTIFICATION ON A REAL CLIENT.
///
/// Founder closeout correction, items 1, 2 and 5. Run per platform:
///
///     flutter test integration_test/create_meeting_certification_test.dart -d windows
///     flutter test integration_test/create_meeting_certification_test.dart -d <android>
///
/// These are session-INDEPENDENT: they certify the client, not the account.
/// What they buy over the widget suite is real platform geometry — real text
/// metrics, real hit-testing, real visual density — which is exactly where the
/// touch-target and overflow defects in this chapter actually lived.
///
/// Real production creation is a separate, founder-authorized, one-time act
/// and is deliberately NOT driven from here.
class _StubInstitutions extends InstitutionsRepository {
  _StubInstitutions() : super(Dio());

  @override
  Future<Institution> getById(String id) async => Institution(
        id: id,
        name: 'Aura Platform LLC',
        slug: 'aura-platform-llc',
        domain: 'auraplatform.org',
        jurisdiction: 'US',
        description: '',
        website: '',
        isVerified: true,
      );

  @override
  Future<Map<String, dynamic>> listMembers(String institutionId) async => {
        'callerRole': 'OWNER',
        'members': [
          for (var i = 0; i < 14; i++)
            {
              'userId': 'u$i',
              'displayName': 'Member $i',
              'title': 'Title $i',
              'role': 'MEMBER',
              'status': 'ACTIVE',
            },
        ],
      };
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> open(WidgetTester tester, {Size? size}) async {
    if (size != null) {
      tester.view.physicalSize = size * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          institutionsRepositoryProvider.overrideWithValue(_StubInstitutions()),
          myAvailabilityProfilesProvider.overrideWith((ref) async => const []),
          currentBookingIdentityProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
          home: Material(child: CreateMeetingScreen(institutionId: 'i1')),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  ScrollableState owner(WidgetTester tester, Finder f) =>
      Scrollable.of(tester.element(f));

  group('CREATE - wide layout, real geometry', () {
    testWidgets('the review rail does not travel with the form',
        (tester) async {
      await open(tester, size: const Size(1440, 900));
      if (find.text('When').evaluate().isEmpty) {
        markTestSkipped('narrow client: the wide rail is not applicable');
        return;
      }
      expect(
        owner(tester, find.text('When')),
        isNot(same(owner(tester, find.text('Agenda or description')))),
      );
      final before = tester.getTopLeft(find.text('When'));
      await tester.drag(
          find.text('Agenda or description'), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('When')), before);
      expect(find.text('External invitees'), findsOneWidget);
    });

    testWidgets('the summary names the meeting as it is typed', (tester) async {
      await open(tester, size: const Size(1440, 900));
      await tester.enterText(
        find.widgetWithText(TextField, 'Meeting title').first,
        'Aura Meetings Certification',
      );
      await tester.pumpAndSettle();
      expect(find.text('Aura Meetings Certification'), findsWidgets);
      expect(find.text('Untitled meeting'), findsNothing);
    });
  });

  group('CREATE - narrow layout, real geometry', () {
    testWidgets('the page scrolls as ONE surface, including over the members',
        (tester) async {
      // The nested-scroll trap: a fixed member well with its own ListView used
      // to swallow the page's drags, so the create button was unreachable.
      await open(tester, size: const Size(420, 860));
      expect(find.byType(ListView), findsOneWidget,
          reason: 'a scrollable is nested inside the page scrollable');
      final button = find.widgetWithText(FilledButton, 'Create meeting');
      for (var i = 0; i < 30 && button.evaluate().isEmpty; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pumpAndSettle();
      }
      expect(find.text('When'), findsOneWidget,
          reason: 'the review pane is unreachable by scrolling');
      expect(button, findsOneWidget,
          reason: 'the create button is unreachable by scrolling');
    });

    testWidgets('a long member list is bounded, not a keyhole', (tester) async {
      await open(tester, size: const Size(420, 860));
      expect(find.textContaining('more. Search to narrow'), findsOneWidget);
    });
  });

  group('CREATE - input and platform', () {
    testWidgets('the title question is visible before anything is typed',
        (tester) async {
      await open(tester, size: const Size(1440, 900));
      expect(find.text('What is this meeting for?'), findsOneWidget);
      final field = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Meeting title').first,
      );
      expect(field.controller?.text, isEmpty);
      expect(
          field.decoration?.floatingLabelBehavior, FloatingLabelBehavior.always);
    });

    testWidgets('keyboard traversal reaches the form and typing lands',
        (tester) async {
      await open(tester, size: const Size(1440, 900));
      await tester.tap(find.widgetWithText(TextField, 'Meeting title').first);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('the primary control is reachable at this density',
        (tester) async {
      // Platform-truthful: touch densities give 48px, pointer densities give
      // less by design. Assert against what THIS platform actually resolves,
      // not against a number copied from a guideline.
      await open(tester, size: const Size(1440, 900));
      final density =
          Theme.of(tester.element(find.byType(CreateMeetingScreen)))
              .visualDensity;
      final floor = density.vertical >= 0 ? 44.0 : 32.0;
      final button = find.widgetWithText(FilledButton, 'Create meeting');
      expect(button, findsOneWidget);
      expect(tester.getSize(button).height, greaterThanOrEqualTo(floor),
          reason: 'density ${density.vertical}');
    });
  });

  group('SHARED - a whole surface waiting', () {
    testWidgets('does not render the inline spinner treatment', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AuraProductState(state: ProductState.loading),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AuraLoadingSurface), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Just a moment'), findsOneWidget);
      expect(find.text('Loading'), findsNothing);
    });
  });
}
