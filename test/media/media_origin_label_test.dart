// MEDIA ORIGIN LABELS — and, more importantly, the silences.
//
// The client performs no inference: the canonical resolver has already decided
// server-side, and this layer only turns a state into words. What these tests
// mostly protect is what Aura must NOT say.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/media/media_origin_label.dart';

void main() {
  group('NO_EVIDENCE_ABSTENTION', () {
    testWidgets('renders nothing at all — not even an "unverified" chip', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MediaOriginBadge(state: MediaOriginState.noEvidence),
        ),
      ));
      expect(find.byType(Text), findsNothing);
    });

    test('produces no label', () {
      expect(mediaOriginLabel(MediaOriginState.noEvidence), isNull);
    });

    test('an unrecognised state is treated as nothing established', () {
      // A state this client does not know about must not become a guess.
      for (final wire in [null, '', 'HUMAN_CREATED', 'SOMETHING_NEW', 'verified']) {
        expect(mediaOriginStateFrom(wire), MediaOriginState.noEvidence);
        expect(mediaOriginLabel(mediaOriginStateFrom(wire)), isNull);
      }
    });

    test('its detail text says absence is not a human claim', () {
      final detail =
          mediaOriginDetail(MediaOriginState.noEvidence, credentials: false)!;
      expect(detail, contains('not a'));
      expect(detail.toLowerCase(), contains('person made it'));
    });
  });

  group('NEVER_MINTS_HUMAN', () {
    test('no state produces a human-created label', () {
      for (final s in MediaOriginState.values) {
        final label = mediaOriginLabel(s)?.toLowerCase() ?? '';
        expect(label, isNot(contains('human')));
        expect(label, isNot(contains('authentic')));
        expect(label, isNot(contains('real')));
      }
    });

    test('there is no state that could mean human-created', () {
      expect(MediaOriginState.values.map((s) => s.name),
          isNot(contains('humanCreated')));
    });
  });

  group('the labels say exactly what the evidence supports', () {
    test('AURA_GENERATED is stated plainly — Aura knows', () {
      expect(mediaOriginLabel(MediaOriginState.auraGenerated), 'Made with Aura');
    });

    test('VERIFIED/DECLARED AI is stated plainly', () {
      expect(mediaOriginLabel(MediaOriginState.aiGenerated), 'Generated with AI');
      expect(mediaOriginLabel(MediaOriginState.aiAltered), 'AI-edited');
    });

    test('WEAK_DETECTOR_ONLY is HEDGED, never asserted', () {
      // Only a classifier thinks so. Stating it as fact would make a false
      // positive indistinguishable from a verified credential.
      final label = mediaOriginLabel(MediaOriginState.likelyAi)!;
      expect(label, startsWith('May be'));
      expect(label, isNot('Generated with AI'));
    });

    test('CONFLICT does not resolve into an AI or non-AI answer', () {
      final label = mediaOriginLabel(MediaOriginState.conflicting)!;
      expect(label, 'Origin disputed');
      // Picking a side would invent the certainty the resolver declined to.
      expect(label, isNot(contains('Generated')));
      expect(label, isNot(contains('not')));
    });

    test('the detail for a classifier admits it can be wrong', () {
      final detail =
          mediaOriginDetail(MediaOriginState.likelyAi, credentials: false)!;
      expect(detail, contains('opinion'));
      expect(detail, contains('can be wrong'));
    });
  });

  group('Content Credentials are reported as presence, never as verdict', () {
    test('presence is appended without changing the state\'s meaning', () {
      final without =
          mediaOriginDetail(MediaOriginState.noEvidence, credentials: false)!;
      final with_ =
          mediaOriginDetail(MediaOriginState.noEvidence, credentials: true)!;
      expect(with_, startsWith(without));
      expect(with_, contains('Content Credentials'));
      // Crucially, having credentials did not turn NO_EVIDENCE into a claim.
      expect(mediaOriginLabel(MediaOriginState.noEvidence), isNull);
    });
  });

  group('presentation is transparency, not stigma', () {
    testWidgets('a badge renders neutrally rather than as a warning', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MediaOriginBadge(state: MediaOriginState.aiGenerated),
        ),
      ));
      expect(find.text('Generated with AI'), findsOneWidget);
    });

    testWidgets('the compact form fits a collage cell', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MediaOriginBadge(state: MediaOriginState.aiGenerated, compact: true),
        ),
      ));
      expect(find.text('AI'), findsOneWidget);
    });

    testWidgets('the compact form is still silent on NO_EVIDENCE', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MediaOriginBadge(state: MediaOriginState.noEvidence, compact: true),
        ),
      ));
      expect(find.byType(Text), findsNothing);
    });
  });
}
