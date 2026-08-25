import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/product/product_language.dart';
import 'package:aura/core/product/product_state.dart';
import 'package:aura/core/product/product_state_view.dart';
import 'package:aura/core/ui/aura_platform_components.dart';

/// SHARED CREATE ENTRY LOADING — founder closeout correction, item 2.
///
/// Entering Create showed the bare word "Loading", then "Loading institutions",
/// each centred alone in a dark page. The fix belongs to the canonical shared
/// owner, with no Meetings-specific branching, so these tests are written
/// against the shared authority and its non-Meetings consumers.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await tester.pump();
  }

  group('the copy no longer says what the code is doing', () {
    test('"Loading" is not the headline of a waiting surface', () {
      const subjects = <ProductNoun?>[
        null,
        ProductNoun.institution,
        ProductNoun.meeting,
        ProductNoun.conversation,
        ProductNoun.person,
      ];
      for (final subject in subjects) {
        final copy = ProductStateCopy.of(
          ProductState.loading,
          subject: subject,
        );
        expect(copy.headline, 'Just a moment', reason: '$subject');
        expect(
          copy.headline.toLowerCase(),
          isNot(contains('loading')),
          reason: '$subject',
        );
      }
    });

    test('but the subject is still named, so two waits differ', () {
      // C0 doctrine: the route boundary, the space and the timeline each
      // rendered the identical word and could not be told apart.
      final generic = ProductStateCopy.of(ProductState.loading);
      final institutions = ProductStateCopy.of(
        ProductState.loading,
        subject: ProductNoun.institution,
      );
      expect(generic.detail, isNot(institutions.detail));
      expect(institutions.detail.toLowerCase(), contains('institution'));
    });
  });

  group('a whole surface waiting looks different from a control waiting', () {
    testWidgets('surface scope renders the composed loading surface', (
      tester,
    ) async {
      await pump(
        tester,
        const AuraProductState(
          state: ProductState.loading,
          subject: ProductNoun.institution,
        ),
      );
      expect(find.byType(AuraLoadingSurface), findsOneWidget);
      expect(find.text('Just a moment'), findsOneWidget);
      expect(find.textContaining('institutions'), findsOneWidget);
      // The 16px spinner-and-a-word treatment is for inline use.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('inline scope is untouched — it was already right', (
      tester,
    ) async {
      await pump(
        tester,
        const AuraProductState(
          state: ProductState.loading,
          scope: StateScope.inline,
        ),
      );
      expect(find.byType(AuraLoadingSurface), findsNothing);
    });

    testWidgets('it does not animate, so pumpAndSettle cannot hang', (
      tester,
    ) async {
      await pump(
        tester,
        const AuraLoadingSurface(title: 'Just a moment', detail: 'Ready soon.'),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('the wait is announced, not just drawn', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const AuraLoadingSurface(title: 'Just a moment'));
      expect(find.bySemanticsLabel('Just a moment'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('every transient state gets the surface, not a bare spinner', (
      tester,
    ) async {
      for (final state in ProductState.values.where((s) => s.isTransient)) {
        await pump(tester, AuraProductState(state: state));
        expect(
          find.byType(AuraLoadingSurface),
          findsOneWidget,
          reason: '$state',
        );
      }
    });
  });
}
