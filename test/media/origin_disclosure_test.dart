// CREATOR DECLARATION — a model nobody could exercise, now exercisable.
//
// `UPLOADER_DECLARATION` existed in the evidence model with no product path to
// it. These tests cover the one shared control and, more importantly, the
// wording and defaults: an interrogation before every upload would be worse
// than no control at all.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/media/media_origin_disclosure.dart';

Future<void> pump(
  WidgetTester tester, {
  OriginDeclaration? value,
  bool visible = true,
  ValueChanged<OriginDeclaration?>? onChanged,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: MediaOriginDisclosureControl(
        value: value,
        visible: visible,
        onChanged: onChanged ?? (_) {},
      ),
    ),
  ));
}

void main() {
  group('saying nothing is the default, and costs nothing', () {
    testWidgets('opens with no declaration selected', (tester) async {
      await pump(tester);
      expect(find.text('Not specified'), findsOneWidget);
    });

    testWidgets('is hidden when there is no visual media to describe', (tester) async {
      // Asking about the origin of a voice note or a document is noise.
      await pump(tester, visible: false);
      expect(find.text('Origin'), findsNothing);
    });
  });

  group('the wire values match the evidence model exactly', () {
    test('each option maps to a claim the server understands', () {
      expect(originDeclarationWire(OriginDeclaration.aiGenerated), 'AI_GENERATED');
      expect(originDeclarationWire(OriginDeclaration.aiEdited), 'AI_EDITED');
      expect(originDeclarationWire(OriginDeclaration.notAi), 'NOT_AI');
    });

    test('there is no wire value that could mean "verified"', () {
      // The server records every one of these as an UPLOADER_DECLARATION.
      // A value implying verification would be a claim the client cannot make.
      for (final d in OriginDeclaration.values) {
        final wire = originDeclarationWire(d);
        expect(wire, isNot(contains('VERIFIED')));
        expect(wire, isNot(contains('HUMAN')));
      }
    });
  });

  group('the wording claims only what a person can honestly say', () {
    test('NOT_AI reads as an absence of AI, not as proof of authorship', () {
      final label = originDeclarationLabel(OriginDeclaration.notAi);
      expect(label, 'No AI involved');
      // "Made by a human" would imply a certification neither the person nor
      // Aura can produce, and the resolver has no state to hold it.
      expect(label.toLowerCase(), isNot(contains('human')));
      expect(label.toLowerCase(), isNot(contains('authentic')));
      expect(label.toLowerCase(), isNot(contains('verified')));
    });

    test('every option is phrased as something the creator did', () {
      for (final d in OriginDeclaration.values) {
        expect(originDeclarationLabel(d), isNotEmpty);
      }
    });
  });

  group('choosing a declaration reports it', () {
    testWidgets('the selection reaches the caller', (tester) async {
      OriginDeclaration? chosen;
      await pump(tester, onChanged: (v) => chosen = v);
      await tester.tap(find.byType(DropdownButton<OriginDeclaration?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generated with AI').last);
      await tester.pumpAndSettle();
      expect(chosen, OriginDeclaration.aiGenerated);
    });

    testWidgets('it can be taken back to saying nothing', (tester) async {
      OriginDeclaration? chosen = OriginDeclaration.aiGenerated;
      await pump(
        tester,
        value: OriginDeclaration.aiGenerated,
        onChanged: (v) => chosen = v,
      );
      await tester.tap(find.byType(DropdownButton<OriginDeclaration?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not specified').last);
      await tester.pumpAndSettle();
      // Withdrawing a declaration must be possible: a mis-tap should not
      // permanently attach a claim to someone's media.
      expect(chosen, isNull);
    });
  });
}
