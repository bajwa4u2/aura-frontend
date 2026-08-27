// AURA TRACE — the client.
//
// TR is a doorway, not a verdict. The client performs NO reasoning: the server
// has already composed the facts and attached an evidence class to each, and
// these tests mostly protect what this layer must refuse to do with them.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/media/trace/aura_trace.dart';
import 'package:aura/core/media/trace/aura_trace_mark.dart';
import 'package:aura/core/media/trace/aura_trace_surface.dart';

AuraTrace parse(Map<String, dynamic> json) => AuraTrace.fromJson(json);

Map<String, dynamic> fact({
  String section = 'AI_INVOLVEMENT',
  String evidence = 'DECLARED',
  String summary = 'Creator says this was generated with AI',
  String? detail,
}) =>
    {
      'section': section,
      'evidence': evidence,
      'summary': summary,
      if (detail != null) 'detail': detail,
    };

Future<void> pumpMark(WidgetTester tester, AuraTrace trace,
    {VoidCallback? onOpen}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: AuraTraceMark(trace: trace, onOpen: onOpen ?? () {}),
    ),
  ));
}

void main() {
  group('THE VISIBILITY RULE', () {
    testWidgets('no TR when there is nothing to disclose', (tester) async {
      await pumpMark(tester, AuraTrace.none);
      expect(find.text('TR'), findsNothing);
    });

    testWidgets('no TR when the server says unavailable, even with facts',
        (tester) async {
      // `available` is READ, never inferred from a non-empty list, so the
      // visibility rule lives in exactly one place — the server.
      final t = parse({'available': false, 'facts': [fact()]});
      await pumpMark(tester, t);
      expect(find.text('TR'), findsNothing);
    });

    testWidgets('TR appears when there is', (tester) async {
      final t = parse({'available': true, 'facts': [fact()]});
      await pumpMark(tester, t);
      expect(find.text('TR'), findsOneWidget);
    });

    testWidgets('opening it is what the mark does', (tester) async {
      var opened = 0;
      final t = parse({'available': true, 'facts': [fact()]});
      await pumpMark(tester, t, onOpen: () => opened++);
      await tester.tap(find.text('TR'));
      await tester.pump();
      expect(opened, 1);
    });
  });

  group('THE CLIENT NEVER UPGRADES EVIDENCE', () {
    test('an unrecognised class resolves to the WEAKEST reading', () {
      // A newer server sending a class this build does not know must not have
      // it silently promoted into verification.
      for (final wire in ['SOMETHING_NEW', '', null, 'TRUSTED', 'PROVEN']) {
        expect(traceEvidenceFrom(wire), TraceEvidenceClass.observed);
        expect(traceEvidenceFrom(wire), isNot(TraceEvidenceClass.verified));
      }
    });

    test('each known class maps exactly, with no promotion', () {
      expect(traceEvidenceFrom('KNOWN'), TraceEvidenceClass.known);
      expect(traceEvidenceFrom('VERIFIED'), TraceEvidenceClass.verified);
      expect(traceEvidenceFrom('DECLARED'), TraceEvidenceClass.declared);
      expect(traceEvidenceFrom('INFERRED'), TraceEvidenceClass.inferred);
      expect(traceEvidenceFrom('CONFLICTING'), TraceEvidenceClass.conflicting);
    });

    test('a declaration never reads as a verification', () {
      expect(traceEvidenceLabel(TraceEvidenceClass.declared),
          'Stated by the creator');
      expect(traceEvidenceLabel(TraceEvidenceClass.declared).toLowerCase(),
          isNot(contains('verified')));
    });

    test('an assessment says it is automated', () {
      expect(traceEvidenceLabel(TraceEvidenceClass.inferred),
          'Automated assessment');
    });

    test('there is no label that claims a human made anything', () {
      for (final e in TraceEvidenceClass.values) {
        expect(traceEvidenceLabel(e).toLowerCase(), isNot(contains('human')));
        expect(traceEvidenceLabel(e).toLowerCase(), isNot(contains('authentic')));
      }
    });
  });

  group('PARSING is tolerant but never inventive', () {
    test('a fact with no summary is dropped', () {
      // Rendering an empty row would suggest Aura knows something it cannot
      // express.
      final t = parse({
        'available': true,
        'facts': [
          {'section': 'ORIGIN', 'evidence': 'KNOWN', 'summary': '   '},
          fact(),
        ],
      });
      expect(t.facts, hasLength(1));
    });

    test('malformed input becomes silence, not a guess', () {
      expect(AuraTrace.fromJson(null).available, isFalse);
      expect(AuraTrace.fromJson('nonsense').available, isFalse);
      expect(AuraTrace.fromJson({'available': true}).facts, isEmpty);
    });
  });

  group('GROUPING leads with what matters, not with what is firmest', () {
    test('uncertainty and integrity come before verified credentials', () {
      final t = parse({
        'available': true,
        'facts': [
          fact(section: 'CONTENT_CREDENTIALS', evidence: 'VERIFIED', summary: 'c'),
          fact(section: 'UNCERTAINTY', evidence: 'CONFLICTING', summary: 'u'),
          fact(section: 'INTEGRITY', evidence: 'INFERRED', summary: 'i'),
        ],
      });
      // Ordering by evidence strength would bury exactly the thing a reader
      // most needs to know exists.
      expect(t.grouped.map((g) => g.key).take(2),
          [TraceSection.uncertainty, TraceSection.integrity]);
    });

    test('empty sections are never emitted', () {
      final t = parse({'available': true, 'facts': [fact()]});
      expect(t.grouped, hasLength(1));
      expect(t.grouped.first.key, TraceSection.aiInvolvement);
    });
  });

  group('THE SURFACE', () {
    testWidgets('shows the fact, its basis, and the boundary', (tester) async {
      final t = parse({
        'available': true,
        'facts': [
          fact(detail: 'Aura has not independently verified it.'),
        ],
      });
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAuraTrace(context, trace: t),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Trace'), findsOneWidget);
      expect(find.text('Creator says this was generated with AI'), findsOneWidget);
      // The basis, beside the fact — this is what stops a declaration reading
      // like a verification.
      expect(find.text('Stated by the creator'), findsOneWidget);
      // And the boundary, said plainly rather than left to be inferred.
      expect(
        find.textContaining('not a judgement about whether'),
        findsOneWidget,
      );
    });

    testWidgets('refuses to open when there is nothing to show', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAuraTrace(context, trace: AuraTrace.none),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Trace'), findsNothing);
    });
  });

  group('SECTION LABELS are human, not state names', () {
    test('each reads as something a person would say', () {
      expect(traceSectionLabel(TraceSection.aiInvolvement), 'AI involvement');
      expect(traceSectionLabel(TraceSection.transformations), 'What changed');
      expect(traceSectionLabel(TraceSection.uncertainty), 'What is unresolved');
      for (final s in TraceSection.values) {
        expect(traceSectionLabel(s), isNot(contains('_')));
      }
    });
  });
}
