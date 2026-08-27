// AURA TRACE — the client.
//
// TR is a signal, not a conclusion, and the product is what opens behind it.
// The client performs NO reasoning and NO curation: the server has already
// resolved the headline, the ordering, the evidence wording and the history.
// These tests mostly protect what this layer must refuse to do with them.
//
// They deliberately do NOT prove that Trace works. A fixture that sets
// `available: true` proves only that IF derived state exists, the UI can show
// it. Proving the capability is the lifecycle test, which starts from real
// provenance-bearing bytes.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/media/aura_media_group.dart';
import 'package:aura/features/feed/domain/feed_item.dart';
import 'package:aura/features/feed/domain/feed_media.dart';
import 'package:aura/core/media/trace/aura_trace.dart';
import 'package:aura/core/media/trace/aura_trace_mark.dart';
import 'package:aura/core/media/trace/aura_trace_surface.dart';

/// A resolved public account, as the server sends it.
Map<String, dynamic> account({
  String headline = 'Created with AI',
  String? source = 'OpenAI Media Service API',
  String? summary =
      'This media carries origin information indicating that it was generated using AI.',
  List<Map<String, dynamic>> evidence = const [
    {
      'label': 'The file states it was generated with AI',
      'detail': 'Aura has not verified the signature on it.',
    },
  ],
  List<Map<String, dynamic>> history = const [],
  Map<String, dynamic>? publication,
  List<String> uncertainty = const [],
  bool available = true,
  bool hasConflict = false,
  String density = 'SIMPLE',
}) =>
    {
      'available': available,
      'headline': headline,
      'source': source,
      'summary': summary,
      'evidence': evidence,
      'history': history,
      'publication': publication,
      'uncertainty': uncertainty,
      'hasConflict': hasConflict,
      'about':
          'Trace describes available evidence about this content’s origin and '
              'history. It does not by itself determine whether what the content '
              'depicts or claims is true.',
      'density': density,
    };

Future<void> pumpMark(WidgetTester tester, AuraTrace trace,
    {VoidCallback? onOpen}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: AuraTraceMark(trace: trace, onOpen: onOpen ?? () {}),
    ),
  ));
}

Future<void> openSurface(WidgetTester tester, AuraTrace trace) async {
  // A DESKTOP-SIZED VIEWPORT. The default 800x600 test surface is smaller than
  // any real pointer client, and the inspector is content-responsive — sizing
  // the test window down would make a scrollable section read as a missing one.
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showAuraTrace(context, trace: trace),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

FeedMedia traced(String id) => FeedMedia(
      id: id,
      mediaId: id,
      mediaType: 'IMAGE',
      mimeType: 'image/jpeg',
      visibility: 'PUBLIC',
      url: 'https://example.invalid/$id.jpg',
      trace: AuraTrace.fromJson(account()),
    );

FeedMedia plain(String id) => FeedMedia(
      id: id,
      mediaId: id,
      mediaType: 'IMAGE',
      mimeType: 'image/jpeg',
      visibility: 'PUBLIC',
      url: 'https://example.invalid/$id.jpg',
    );

void main() {
  group('THE VISIBILITY RULE', () {
    testWidgets('no TR when there is nothing to disclose', (tester) async {
      await pumpMark(tester, AuraTrace.none);
      expect(find.text('TR'), findsNothing);
    });

    testWidgets('no TR when the server says unavailable, even with content',
        (tester) async {
      // `available` is READ, never inferred from a non-empty account, so the
      // visibility rule lives in exactly one place — the server.
      await pumpMark(tester, AuraTrace.fromJson(account(available: false)));
      expect(find.text('TR'), findsNothing);
    });

    testWidgets('TR appears when there is', (tester) async {
      await pumpMark(tester, AuraTrace.fromJson(account()));
      expect(find.text('TR'), findsOneWidget);
    });

    testWidgets('opening it is what the mark does', (tester) async {
      var opened = 0;
      await pumpMark(tester, AuraTrace.fromJson(account()),
          onOpen: () => opened++);
      await tester.tap(find.text('TR'));
      await tester.pump();
      expect(opened, 1);
    });
  });

  group('THE CLIENT NEVER CURATES', () {
    test("the headline is the server's, never derived from the evidence", () {
      final t = AuraTrace.fromJson(account(
        headline: 'Conflicting origin information',
        evidence: const [
          {'label': 'The file states it was generated with AI'},
        ],
      ));
      // The evidence would suggest "Created with AI" to anything that reasoned
      // about it. The client does not reason about it.
      expect(t.headline, 'Conflicting origin information');
    });

    test('an unknown density resolves to the SMALLER container', () {
      for (final wire in ['ENORMOUS', '', null, 'FULL']) {
        expect(traceDensityFrom(wire), TraceDensity.simple);
      }
      expect(traceDensityFrom('RICH'), TraceDensity.rich);
    });

    test('malformed input becomes silence, not a guess', () {
      expect(AuraTrace.fromJson(null).available, isFalse);
      expect(AuraTrace.fromJson('nonsense').available, isFalse);
      expect(AuraTrace.fromJson({'available': true}).isEmpty, isTrue);
    });

    test('a line with no label is dropped', () {
      // Rendering an empty row would suggest Aura knows something it cannot
      // express.
      final t = AuraTrace.fromJson(account(evidence: const [
        {'label': '   '},
        {'label': 'Real line'},
      ]));
      expect(t.evidence, hasLength(1));
      expect(t.evidence.single.label, 'Real line');
    });

    test('no client copy can claim a human made anything', () {
      final t = AuraTrace.fromJson(account());
      final blob = [
        t.headline,
        t.summary,
        t.about,
        ...t.evidence.map((e) => '${e.label} ${e.detail}'),
      ].join(' ').toLowerCase();
      expect(blob, isNot(contains('human-created')));
      expect(blob, isNot(contains('authentic')));
    });
  });

  group('THE SURFACE leads with meaning, not with vocabulary', () {
    testWidgets('the headline is first and the source is under it',
        (tester) async {
      await openSurface(tester, AuraTrace.fromJson(account()));
      expect(find.text('Created with AI'), findsOneWidget);
      expect(find.text('OpenAI Media Service API'), findsOneWidget);
      expect(
        find.textContaining('indicating that it was generated using AI'),
        findsOneWidget,
      );
    });

    testWidgets('evidence and its limits appear together', (tester) async {
      await openSurface(
        tester,
        AuraTrace.fromJson(account(
          uncertainty: const [
            'Aura has not independently verified the credential signer.'
          ],
        )),
      );
      expect(find.text('Evidence'), findsOneWidget);
      expect(
          find.text('The file states it was generated with AI'), findsOneWidget);
      // The limit sits WITH the evidence, because an unverified signer is part
      // of what the evidence is rather than a footnote to it.
      expect(
        find.textContaining('not independently verified the credential signer'),
        findsOneWidget,
      );
    });

    testWidgets('history renders as a sequence with its basis per step',
        (tester) async {
      await openSurface(
        tester,
        AuraTrace.fromJson(account(
          density: 'RICH',
          history: const [
            {
              'title': 'Created with AI',
              'detail': 'OpenAI Media Service API',
              'basis': 'Content credential observed',
            },
            {
              'title': 'Entered Aura',
              'detail': '22 August 2026',
              'basis': 'Recorded by Aura',
            },
          ],
        )),
      );
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Entered Aura'), findsOneWidget);
      // Two DIFFERENT bases on two steps — the distinction survives being put
      // in one sequence, which is where it is most at risk of flattening.
      expect(find.text('Content credential observed'), findsOneWidget);
      expect(find.text('Recorded by Aura'), findsOneWidget);
    });

    testWidgets('PUBLICATION is its own section, never the origin',
        (tester) async {
      await openSurface(
        tester,
        AuraTrace.fromJson(account(
          publication: const {
            'by': 'M S Bajwa',
            'forInstitution': 'Aura Platform',
          },
        )),
      );
      expect(find.text('Publication'), findsOneWidget);
      expect(find.text('M S Bajwa'), findsOneWidget);
      expect(find.text('for Aura Platform'), findsOneWidget);
      // The publisher's name must not have become the source line.
      expect(find.text('OpenAI Media Service API'), findsOneWidget);
    });

    testWidgets('empty sections never render', (tester) async {
      await openSurface(tester, AuraTrace.fromJson(account()));
      // A heading with nothing under it reads as something withheld.
      expect(find.text('History'), findsNothing);
      expect(find.text('Publication'), findsNothing);
    });

    testWidgets('the boundary is present and is NOT the headline',
        (tester) async {
      await openSurface(tester, AuraTrace.fromJson(account()));
      expect(
        find.textContaining('does not by itself determine'),
        findsOneWidget,
      );
    });

    testWidgets('refuses to open when there is nothing to show', (tester) async {
      await openSurface(tester, AuraTrace.none);
      expect(find.text('Trace'), findsNothing);
    });
  });

  group('THE CONTAINER FOLLOWS THE EVIDENCE', () {
    test('density is read, never inferred from how much content arrived', () {
      expect(AuraTrace.fromJson(account(density: 'SIMPLE')).density,
          TraceDensity.simple);
      expect(AuraTrace.fromJson(account(density: 'RICH')).density,
          TraceDensity.rich);
    });

    testWidgets('a simple Trace still shows its headline', (tester) async {
      await openSurface(tester, AuraTrace.fromJson(account(density: 'SIMPLE')));
      expect(find.text('Created with AI'), findsOneWidget);
    });
  });

  group('WHERE TR MOUNTS — the bug this suite exists to prevent', () {
    // The first implementation put TR on AuraMediaGroup CELLS, so it was
    // invisible for the commonest case in the product: a post with ONE image
    // never enters the collage path at all — the group returns the shared
    // adapter directly to keep the single-media treatment.

    testWidgets('SINGLE media shows TR', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body:
              SizedBox(width: 400, child: AuraMediaGroup(items: [traced('a')])),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('TR'), findsOneWidget);
    });

    testWidgets('a GROUP shows TR once per item that has one', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: AuraMediaGroup(items: [traced('a'), plain('b'), traced('c')]),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('TR'), findsNWidgets(2));
    });

    testWidgets('media with nothing to disclose shows none', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: AuraMediaGroup(items: [plain('a'), plain('b')]),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('TR'), findsNothing);
    });
  });

  group('TEXT TRACE reaches the client model', () {
    test('a post that discloses something carries it', () {
      final item = FeedItem.fromJson({
        'id': 'p1',
        'type': 'USER_POST',
        'authorType': 'INSTITUTION',
        'author': {'id': 'i1', 'name': 'Aura Health'},
        'body': 'statement',
        'trace': account(
          headline: 'Published as Aura Health',
          source: null,
          evidence: const [
            {'label': 'Published as Aura Health'},
          ],
        ),
      });
      expect(item.trace.isNotEmpty, isTrue);
      expect(item.trace.headline, 'Published as Aura Health');
    });

    test('a post with nothing to disclose is silent, not broken', () {
      final item = FeedItem.fromJson({
        'id': 'p2',
        'type': 'USER_POST',
        'authorType': 'USER',
        'author': {'id': 'u1', 'name': 'A'},
        'body': 'hello',
        'trace': {'available': false},
      });
      expect(item.trace.isEmpty, isTrue);
    });

    test('a server too old to send it is also silent, not broken', () {
      final item = FeedItem.fromJson({
        'id': 'p3',
        'type': 'USER_POST',
        'authorType': 'USER',
        'author': {'id': 'u1', 'name': 'A'},
        'body': 'hello',
      });
      expect(item.trace.isEmpty, isTrue);
    });
  });
}
