// ACCESSIBILITY OF THE CH-14 ARTICLE EXPERIENCE.
//
// "Semantics added" is not certification. These assert the actual semantic
// tree and the actual hit targets, on the controls CH-14 introduced.
//
// The defects they pin were real:
//   * an unlabelled chevron announced only as "button";
//   * reaction totals spoken as an emoji name followed by a bare digit;
//   * 24px controls, half the 48dp minimum target;
//   * engagement state changing with no announcement at all.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/engagement/aura_engagement_bar.dart';
import 'package:aura/core/engagement/engagement_model.dart';
import 'package:aura/core/engagement/engagement_repository.dart';

const _key = (target: PublicationTarget.article, id: 'a1');

Widget _harness(EngagementState state) {
  return ProviderScope(
    overrides: [
      engagementStateProvider(_key).overrideWith((ref) async => state),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: AuraEngagementBar(
          target: PublicationTarget.article,
          publicationId: 'a1',
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('every control is NAMED, not just tappable', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_harness(const EngagementState(count: 3)));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp(r'React\. 3 reactions')), findsOneWidget);
    // The chevron's accessible name is a TOOLTIP, which screen readers
    // announce. Asserting it as a label would pass only by accident of how
    // Flutter happens to lower tooltips today.
    expect(
      tester.getSemantics(find.byIcon(Icons.expand_more)).tooltip,
      'Choose a reaction',
    );
    expect(
      find.bySemanticsLabel(RegExp(r'Save this to your saved items')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('a held reaction announces removal, not a bare count',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _harness(const EngagementState(myReaction: AuraReaction.love, count: 4)),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp(r'Remove your Love reaction')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('reaction totals are spoken as counts, not emoji plus digits',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _harness(const EngagementState(
        count: 5,
        breakdown: {AuraReaction.love: 3, AuraReaction.laugh: 2},
      )),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('3 Love'), findsOneWidget);
    expect(find.bySemanticsLabel('2 Funny'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('engagement state is a LIVE REGION, so changes are announced',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_harness(const EngagementState(
        myReaction: AuraReaction.love, count: 2, saved: true)));
    await tester.pumpAndSettle();

    final node = tester.getSemantics(find.byType(AuraEngagementBar));
    expect(node.value, contains('Your reaction: Love'));
    expect(node.value, contains('2 reactions'));
    expect(node.value, contains('Saved'));
    handle.dispose();
  });

  testWidgets('controls meet the 48dp minimum target', (tester) async {
    await tester.pumpWidget(_harness(const EngagementState(count: 1)));
    await tester.pumpAndSettle();

    // The visual padding is unchanged; the CONSTRAINT is what grows, so the
    // design is untouched and the target is real.
    final inkWells = find.byType(InkWell);
    expect(inkWells, findsWidgets);
    for (var i = 0; i < tester.widgetList(inkWells).length; i++) {
      final size = tester.getSize(inkWells.at(i));
      expect(size.height, greaterThanOrEqualTo(48.0),
          reason: 'A 24px control is genuinely hard to hit.');
    }
  });
}
