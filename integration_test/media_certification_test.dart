// RICH CONTENT MEDIA — RELEASED-CLIENT CERTIFICATION.
//
// Runs the REAL widgets on the REAL platform with real plugins. What this
// proves that a unit test cannot: the platform's own answers. On Windows
// `video_player` genuinely resolves no implementation, and the point of running
// here is that the honest fallback is exercised rather than asserted.
//
//     flutter test integration_test/media_certification_test.dart -d windows
//     flutter test integration_test/media_certification_test.dart -d chrome
//     flutter test integration_test/media_certification_test.dart -d <pixel-id>
//
// ANDROID: install with granted permissions FIRST, or `getUserMedia`-class
// plugins block on a dialog nobody can tap and the run dies with no output:
//
//     adb install -r -g build/app/outputs/flutter-apk/app-debug.apk
//
// DELIBERATELY NOT BOOTED: the whole app via `routerProvider` + MaterialApp.
// The real router starts network work that outlives the test and Flutter then
// reports "This test failed after it had already completed".

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:aura/core/composition/attachment_lifecycle.dart';
import 'package:aura/core/composition/composition_authority.dart';
import 'package:aura/core/media/attachment.dart';
import 'package:aura/core/media/aura_composition_strip.dart';
import 'package:aura/core/media/aura_media_group.dart';
import 'package:aura/core/media/aura_video_surface.dart';
import 'package:aura/core/media/immersive_presenter.dart';
import 'package:aura/core/media/media_interaction_profile.dart';
import 'package:aura/core/media/media_origin_disclosure.dart';
import 'package:aura/core/media/trace/aura_trace.dart';
import 'package:aura/features/feed/domain/feed_media.dart';

/// A resolved Trace, as the server would send it. Built here rather than
/// derived from `originState`, because the client performs no reasoning: if a
/// test could synthesise a Trace from a state string, so could the client.
AuraTrace traceOf(String summary) => AuraTrace.fromJson({
      'available': true,
      'headline': summary,
      'facts': [
        {
          'section': 'AI_INVOLVEMENT',
          'evidence': 'DECLARED',
          'summary': summary,
        }
      ],
    });

FeedMedia img(String id, {String? origin}) => FeedMedia(
      id: id,
      mediaId: id,
      mediaType: 'IMAGE',
      mimeType: 'image/jpeg',
      visibility: 'PUBLIC',
      url: 'https://example.invalid/$id.jpg',
      width: 1600,
      height: 1200,
      originState: origin,
      trace: origin == null ? AuraTrace.none : traceOf('Creator says AI was used'),
    );

FeedMedia vid(String id, {String? origin}) => FeedMedia(
      id: id,
      mediaId: id,
      mediaType: 'VIDEO',
      mimeType: 'video/mp4',
      visibility: 'PUBLIC',
      url: 'https://example.invalid/$id.mp4',
      thumbUrl: 'https://example.invalid/$id.jpg',
      width: 1080,
      height: 1920,
      duration: 6000,
      originState: origin,
      trace: origin == null ? AuraTrace.none : traceOf('Creator says AI was used'),
    );

Attachment att(String id, AttachmentKind kind, {bool failed = false}) =>
    Attachment(
      localId: id,
      kind: kind,
      mediaId: failed ? null : 'server-$id',
      url: failed ? null : 'https://example.invalid/$id',
      error: failed ? 'network' : null,
    );

Future<void> host(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: SizedBox(width: 420, child: child))),
  );
  await tester.pump(const Duration(milliseconds: 120));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final platform = defaultTargetPlatform;
  final profile = MediaInteractionProfile.resolve(
    canDecodeVideo: storedVideoCanDecodeInline(),
  );

  group('PLATFORM CAPABILITY — measured here, not assumed', () {
    testWidgets('reports what this client can actually decode', (tester) async {
      // Printed so a certification run is self-describing in its own log.
      debugPrint(
        'CERT platform=${platform.name} web=$kIsWeb '
        'canDecodeVideo=${storedVideoCanDecodeInline()} '
        'pointer=${profile.pointer.name} zoomButtons=${profile.zoomButtons} '
        'sourceActionsPrimary=${profile.persistentSourceActions}',
      );
      expect(profile.pointer, isNotNull);
    });

    testWidgets('WINDOWS_VIDEO_PLAYBACK is honestly reported', (tester) async {
      if (platform != TargetPlatform.windows || kIsWeb) return;
      // The whole reason this file runs on Windows: `video_player` resolves no
      // Windows implementation, and the product must say so rather than offer
      // a play button that cannot work.
      expect(storedVideoCanDecodeInline(), isFalse);
      final caps = ImmersivePresenterRegistry.capabilitiesFor(
        ImmersiveRequest(
          isVideo: true,
          mimeType: 'video/mp4',
          profile: profile,
          mediaId: 'm',
          isPublic: true,
          originalUrl: 'https://example.invalid/m.mp4',
        ),
      );
      expect(caps.canPresent, isFalse);
      // OPEN_ORIGINAL becomes the primary recovery here, and only here.
      expect(caps.sourceActionIsPrimary, isTrue);
      expect(profile.persistentSourceActions, isTrue);
    });

    testWidgets('WEB and ANDROID decode inline, so source access stays secondary',
        (tester) async {
      if (platform == TargetPlatform.windows && !kIsWeb) return;
      expect(storedVideoCanDecodeInline(), isTrue);
      expect(profile.persistentSourceActions, isFalse);
    });

    testWidgets('touch clients get gestures, not a zoom cluster', (tester) async {
      if (platform != TargetPlatform.android && platform != TargetPlatform.iOS) {
        return;
      }
      expect(profile.pointer, PointerModel.touch);
      expect(profile.pinchZoom, isTrue);
      expect(profile.doubleTapZoom, isTrue);
      expect(profile.zoomButtons, isFalse);
      expect(profile.zoomReadout, isFalse);
      // Dismissal must yield to a zoomed image or it steals the pan gesture.
      expect(profile.dismissGestureAvailable(isZoomed: true), isFalse);
      expect(profile.dismissGestureAvailable(isZoomed: false), isTrue);
    });
  });

  group('GROUP PRESENTATION on the real platform', () {
    testWidgets('SINGLE_IMAGE keeps the single-media treatment', (tester) async {
      await host(tester, AuraMediaGroup(items: [img('a')]));
      expect(find.byType(AuraMediaGroup), findsOneWidget);
    });

    testWidgets('SINGLE_VIDEO renders poster-first, no decoder', (tester) async {
      await host(tester, AuraMediaGroup(items: [vid('v')]));
      expect(find.byType(AuraMediaGroup), findsOneWidget);
    });

    testWidgets('MULTI_IMAGE renders every item', (tester) async {
      await host(tester, AuraMediaGroup(items: [img('a'), img('b'), img('c')]));
      expect(find.byType(AuraMediaGroup), findsOneWidget);
    });

    testWidgets('MULTI_VIDEO does not instantiate a decoder per cell',
        (tester) async {
      // Four videos in a scrolling feed must not become four decoders.
      await host(tester, AuraMediaGroup(items: [vid('1'), vid('2'), vid('3'), vid('4')]));
      expect(find.byType(AuraMediaGroup), findsOneWidget);
    });

    testWidgets('MIXED_IMAGE_VIDEO composes as one group', (tester) async {
      await host(tester, AuraMediaGroup(items: [img('a'), vid('b'), img('c'), vid('d')]));
      expect(find.byType(AuraMediaGroup), findsOneWidget);
    });

    testWidgets('5_PLUS collapses the tail into a continuation', (tester) async {
      await host(tester, AuraMediaGroup(items: [
        img('a'), img('b'), img('c'), img('d'), img('e'), vid('f'),
      ]));
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('IMMERSIVE_NAVIGATION carries the group and the index',
        (tester) async {
      final opened = <int>[];
      await host(
        tester,
        AuraMediaGroup(items: [img('a'), vid('b'), img('c')], onOpenItem: opened.add),
      );
      final group = tester.widget<AuraMediaGroup>(find.byType(AuraMediaGroup));
      group.onOpenItem!(1);
      expect(opened, [1]);
    });
  });

  group('PER_ITEM_PROVENANCE in a real mixed group', () {
    testWidgets('only the item with evidence is labelled', (tester) async {
      await host(tester, AuraMediaGroup(items: [
        img('captured'),
        img('made', origin: 'AI_GENERATED'),
        vid('unknown'),
      ]));
      // One TR, on one cell. A group is not AI because one item is, and the
      // mark is a doorway to the basis rather than a verdict stamped on media.
      expect(find.text('TR'), findsOneWidget);
    });

    testWidgets('NO_EVIDENCE renders no badge at all', (tester) async {
      await host(tester, AuraMediaGroup(items: [img('a'), img('b')]));
      // Existing in Aura's database is not something worth marking.
      expect(find.text('TR'), findsNothing);
    });

    testWidgets('AURA_GENERATED and DECLARED_AI both surface', (tester) async {
      await host(tester, AuraMediaGroup(items: [
        img('aura', origin: 'AURA_GENERATED'),
        img('declared', origin: 'AI_GENERATED'),
      ]));
      expect(find.text('TR'), findsNWidgets(2));
    });

    testWidgets('a SINGLE media item is marked — the case that was invisible',
        (tester) async {
      // The regression this exists for: TR was mounted on collage CELLS, and a
      // post with one image never enters the collage path — the group returns
      // the shared adapter directly to keep the single-media treatment. Every
      // group assertion above passed the whole time.
      await host(tester, AuraMediaGroup(items: [img('made', origin: 'AI_GENERATED')]));
      expect(find.text('TR'), findsOneWidget);
    });

    testWidgets('and opening it shows the basis, on the real platform',
        (tester) async {
      await host(tester, AuraMediaGroup(items: [img('made', origin: 'AI_GENERATED')]));
      await tester.tap(find.text('TR'));
      await tester.pumpAndSettle();
      expect(find.text('Trace'), findsOneWidget);
      // The basis beside the fact — a declaration must not read as a
      // verification on any platform.
      expect(find.text('Stated by the creator'), findsOneWidget);
    });

    testWidgets('CONFLICTING does not render as an AI verdict', (tester) async {
      await host(tester, AuraMediaGroup(items: [
        img('x', origin: 'CONFLICTING'),
        img('y'),
      ]));
      // A conflict opens TR — a reader most needs to know it exists — but the
      // mark still states no verdict.
      expect(find.text('TR'), findsOneWidget);
    });
  });

  group('COMPOSITION on the real platform', () {
    testWidgets('the strip shows each item, in order, with its position',
        (tester) async {
      final items = [
        att('a', AttachmentKind.image),
        att('b', AttachmentKind.video),
        att('c', AttachmentKind.image),
      ];
      final state = CompositionState(attachments: items, requiresBody: false);
      await host(
        tester,
        AuraCompositionStrip(
          attachments: items,
          phaseOf: state.phaseOf,
          onRemove: (_) {},
          onReorder: (_, __) {},
        ),
      );
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('FAILED_UPLOAD offers retry and blocks the send', (tester) async {
      final items = [
        att('ok', AttachmentKind.image),
        att('bad', AttachmentKind.image, failed: true),
      ];
      final state = CompositionState(attachments: items, requiresBody: false);
      expect(state.canSubmit, isFalse);
      expect(state.hasPartialFailure, isTrue);
      // The reason must name the problem, not tell someone to wait for
      // something that has already stopped.
      expect(state.blockedReason, contains("didn't upload"));

      var retried = 0;
      await host(
        tester,
        AuraCompositionStrip(
          attachments: items,
          phaseOf: state.phaseOf,
          onRemove: (_) {},
          onRetry: (_) => retried++,
        ),
      );
      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.pump();
      expect(retried, 1);
    });

    testWidgets('REMOVAL is offered per item', (tester) async {
      final items = [att('a', AttachmentKind.image)];
      final state = CompositionState(attachments: items, requiresBody: false);
      var removed = '';
      await host(
        tester,
        AuraCompositionStrip(
          attachments: items,
          phaseOf: state.phaseOf,
          onRemove: (id) => removed = id,
        ),
      );
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(removed, 'a');
    });

    testWidgets('REORDER preserves the arranged order', (tester) async {
      final state = CompositionState(
        attachments: [
          att('first', AttachmentKind.image),
          att('second', AttachmentKind.video),
          att('third', AttachmentKind.image),
        ],
        requiresBody: false,
      );
      final moved = state.reorderAttachment(2, 0);
      expect(moved.attachments.map((a) => a.localId), ['third', 'first', 'second']);
      // And the send order follows it.
      expect(moved.composableAttachments.map((a) => a.localId),
          ['third', 'first', 'second']);
    });

    testWidgets('a late upload cannot resurrect a removed item', (tester) async {
      final late = Attachment(
        localId: 'late',
        kind: AttachmentKind.image,
        uploading: true,
      );
      final state = CompositionState(
        attachments: [late, att('kept', AttachmentKind.image)],
        requiresBody: false,
      );
      final after = state.removeAttachment('late');
      late.uploading = false;
      late.mediaId = 'server-late';
      final resurrected =
          after.copyWith(attachments: [late, ...after.attachments]);
      expect(resurrected.phaseOf(late), AttachmentPhase.cancelled);
      expect(resurrected.composableAttachments.map((a) => a.localId), ['kept']);
    });
  });

  group('CREATOR DECLARATION on the real platform', () {
    testWidgets('defaults to saying nothing', (tester) async {
      await host(
        tester,
        MediaOriginDisclosureControl(value: null, onChanged: (_) {}),
      );
      expect(find.text('Not specified'), findsOneWidget);
    });

    testWidgets('is absent when there is no visual media', (tester) async {
      await host(
        tester,
        MediaOriginDisclosureControl(
          value: null,
          visible: false,
          onChanged: (_) {},
        ),
      );
      expect(find.text('Origin'), findsNothing);
    });

    testWidgets('offers no human-authenticity claim', (tester) async {
      for (final d in OriginDeclaration.values) {
        expect(originDeclarationLabel(d).toLowerCase(), isNot(contains('human')));
      }
    });
  });
}
