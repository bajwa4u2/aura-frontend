import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/topics/aura_topic_selector.dart';
import 'package:aura/features/topics/topic.dart';
import 'package:aura/features/topics/topic_repository.dart';

/// Minimal controlled-widget harness — owns the state AuraTopicSelector
/// expects its parent (compose screens) to own, with fake backend hooks
/// injected so tests control the approved-set / suggestion responses
/// directly rather than hitting a real network.
class _Harness extends StatefulWidget {
  const _Harness({
    this.initialPrimary,
    this.initialSecondaries = const [],
    required this.fetchApprovedSecondaries,
    required this.fetchSuggestions,
  });

  final AuraTopic? initialPrimary;
  final List<AuraTopic> initialSecondaries;
  final Future<List<ApprovedSecondaryTopic>> Function(AuraTopic primary)
  fetchApprovedSecondaries;
  final Future<TopicSuggestionResult> Function(AuraTopic primary, String text)
  fetchSuggestions;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late AuraTopic? primary = widget.initialPrimary;
  late List<AuraTopic> secondaries = widget.initialSecondaries;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: AuraTopicSelector(
          primary: primary,
          secondaries: secondaries,
          contentText: 'Some content text',
          onPrimaryChanged: (t) => setState(() => primary = t),
          onSecondariesChanged: (list) => setState(() => secondaries = list),
          fetchApprovedSecondaries: widget.fetchApprovedSecondaries,
          fetchSuggestions: widget.fetchSuggestions,
        ),
      ),
    );
  }
}

Future<List<ApprovedSecondaryTopic>> Function(AuraTopic) _approvedTable(
  Map<AuraTopic, List<AuraTopic>> table,
) {
  return (primary) async => (table[primary] ?? const <AuraTopic>[])
      .map((t) => ApprovedSecondaryTopic(topic: t, strength: 'MODERATE'))
      .toList();
}

Future<List<ApprovedSecondaryTopic>> Function(AuraTopic) _failingApproved() {
  return (primary) async => throw Exception('network down');
}

Future<TopicSuggestionResult> Function(AuraTopic, String) _noSuggestions() {
  return (primary, text) async =>
      const TopicSuggestionResult(suggestions: [], mode: 'keyword');
}

void main() {
  const educationApproved = {
    AuraTopic.education: [
      AuraTopic.employment,
      AuraTopic.research,
      AuraTopic.community,
    ],
    AuraTopic.faith: [AuraTopic.community, AuraTopic.artsCulture],
  };

  testWidgets(
    'selecting a primary retrieves the approved secondary set from the backend',
    (tester) async {
      var calls = 0;
      Future<List<ApprovedSecondaryTopic>> fetch(AuraTopic primary) async {
        calls++;
        return _approvedTable(educationApproved)(primary);
      }

      await tester.pumpWidget(
        _Harness(
          initialPrimary: AuraTopic.education,
          fetchApprovedSecondaries: fetch,
          fetchSuggestions: _noSuggestions(),
        ),
      );
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(find.text('Loading related topics…'), findsNothing);
      expect(find.text('Add topic'), findsOneWidget);
    },
  );

  testWidgets(
    'manual Add Topic only shows the backend-provided approved set',
    (tester) async {
      await tester.pumpWidget(
        _Harness(
          initialPrimary: AuraTopic.education,
          initialSecondaries: const [AuraTopic.research],
          fetchApprovedSecondaries: _approvedTable(educationApproved),
          fetchSuggestions: _noSuggestions(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add topic'));
      await tester.pumpAndSettle();

      bool menuHas(String label) => tester
          .widgetList<PopupMenuItem<AuraTopic>>(
            find.byType(PopupMenuItem<AuraTopic>),
          )
          .any((w) => (w.child as Text).data == label);

      // Backend said EMPLOYMENT and COMMUNITY are approved for EDUCATION and
      // not yet selected — must be offered.
      expect(menuHas('Employment'), isTrue);
      expect(menuHas('Community'), isTrue);
      // RESEARCH is already selected — must not reappear.
      expect(menuHas('Research'), isFalse);
      // Never offered anything the backend didn't return.
      expect(menuHas('Housing'), isFalse);
      expect(menuHas('Government'), isFalse);
    },
  );

  testWidgets(
    'suggestions come from the backend topic-suggestion capability',
    (tester) async {
      var suggestCalledWith = (primary: null as AuraTopic?, text: '');
      await tester.pumpWidget(
        _Harness(
          initialPrimary: AuraTopic.education,
          fetchApprovedSecondaries: _approvedTable(educationApproved),
          fetchSuggestions: (primary, text) async {
            suggestCalledWith = (primary: primary, text: text);
            return const TopicSuggestionResult(
              suggestions: [AuraTopic.employment],
              mode: 'ai',
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Suggest'));
      await tester.pumpAndSettle();

      expect(suggestCalledWith.primary, AuraTopic.education);
      expect(suggestCalledWith.text, 'Some content text');
      expect(find.text('Employment'), findsWidgets); // now a selected chip too
    },
  );

  testWidgets(
    'a failed approved-secondaries request shows a recoverable state, not a fallback list',
    (tester) async {
      await tester.pumpWidget(
        _Harness(
          initialPrimary: AuraTopic.education,
          fetchApprovedSecondaries: _failingApproved(),
          fetchSuggestions: _noSuggestions(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Couldn\'t load related topics'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      // No local fallback list is ever offered.
      expect(find.text('Add topic'), findsNothing);
    },
  );

  testWidgets(
    'retry re-issues the approved-secondaries request',
    (tester) async {
      var attempt = 0;
      await tester.pumpWidget(
        _Harness(
          initialPrimary: AuraTopic.education,
          fetchApprovedSecondaries: (primary) async {
            attempt++;
            if (attempt == 1) throw Exception('network down');
            return _approvedTable(educationApproved)(primary);
          },
          fetchSuggestions: _noSuggestions(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(attempt, 2);
      expect(find.text('Add topic'), findsOneWidget);
    },
  );

  testWidgets(
    'previously selected values remain visible while the approved-set request is loading or failed',
    (tester) async {
      final gate = Completer<List<ApprovedSecondaryTopic>>();
      await tester.pumpWidget(
        _Harness(
          initialPrimary: AuraTopic.education,
          initialSecondaries: const [AuraTopic.research, AuraTopic.employment],
          fetchApprovedSecondaries: (primary) => gate.future,
          fetchSuggestions: _noSuggestions(),
        ),
      );
      await tester.pump();

      // Still loading — previously selected chips remain visible.
      expect(find.text('Loading related topics…'), findsOneWidget);
      expect(find.text('Research'), findsWidgets);
      expect(find.text('Employment'), findsWidgets);

      gate.completeError(Exception('network down'));
      await tester.pumpAndSettle();

      // Now failed — still visible, nothing silently dropped.
      expect(find.textContaining('Couldn\'t load related topics'), findsOneWidget);
      expect(find.text('Research'), findsWidgets);
      expect(find.text('Employment'), findsWidgets);
    },
  );

  testWidgets(
    'changing the primary drops now-invalid secondaries once the new approved set is known, and shows a notice',
    (tester) async {
      await tester.pumpWidget(
        _Harness(
          initialPrimary: AuraTopic.education,
          initialSecondaries: const [AuraTopic.research, AuraTopic.employment],
          fetchApprovedSecondaries: _approvedTable(educationApproved),
          fetchSuggestions: _noSuggestions(),
        ),
      );
      await tester.pumpAndSettle();

      // FAITH's approved set (per the fake table) is [COMMUNITY, ARTS_CULTURE]
      // — neither RESEARCH nor EMPLOYMENT survive.
      await tester.tap(find.text('Faith'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Removed 2 secondary topics'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a legacy combination is not silently stripped merely by opening/loading the editor',
    (tester) async {
      // EMPLOYMENT is not in FAITH's approved set in the fake table below —
      // simulating pre-existing (legacy) data. Loading the editor with FAITH
      // already selected must NOT auto-drop it or show a removal notice;
      // only an explicit primary *change* does that.
      await tester.pumpWidget(
        _Harness(
          initialPrimary: AuraTopic.faith,
          initialSecondaries: const [AuraTopic.employment],
          fetchApprovedSecondaries: _approvedTable(educationApproved),
          fetchSuggestions: _noSuggestions(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Removed'), findsNothing);
      expect(find.text('Employment'), findsWidgets);
    },
  );

  testWidgets(
    'secondary selection is disabled before a primary topic is chosen, and no request is made',
    (tester) async {
      var called = false;
      await tester.pumpWidget(
        _Harness(
          fetchApprovedSecondaries: (primary) async {
            called = true;
            return const [];
          },
          fetchSuggestions: _noSuggestions(),
        ),
      );
      await tester.pumpAndSettle();

      expect(called, isFalse);
      expect(find.text('Choose a primary topic first.'), findsOneWidget);
      expect(find.text('Add topic'), findsNothing);

      final suggestButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Suggest'),
      );
      expect(suggestButton.onPressed, isNull);
    },
  );
}
