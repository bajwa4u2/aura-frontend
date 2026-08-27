import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/media/aura_attachment_card.dart';
import 'package:aura/core/media/aura_stored_media.dart';
import 'package:aura/core/media/aura_video_surface.dart';
import 'package:aura/core/media/canonical_media_thumb.dart';
import 'package:aura/core/media/stored_media.dart';
import 'package:aura/features/feed/domain/feed_media.dart';
import 'package:aura/features/posts/presentation/widgets/post_card/post_card_models.dart';

/// STORED VIDEO PRESENTATION — the certification gate.
///
/// The defect these lock down was not one broken screen. `thumbUrl` is null
/// for every video the product stores, and four surfaces each guessed
/// differently at what to do about it — three of them by handing an MP4 to an
/// image decoder, which renders a broken-image glyph.
///
/// The invariants below are the ones that make that class of defect
/// unreachable, not the ones that make a particular screenshot look right.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(AuraStoredMediaRegistry.resetForTest);

  Widget host(Widget child) => ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: SizedBox(width: 400, height: 400, child: child)),
        ),
      );

  // ───────────────────────────────────────────────────────────────────────
  // NO_MP4_TO_IMAGE_DECODER
  // ───────────────────────────────────────────────────────────────────────

  group('an MP4 is never offered to an image decoder', () {
    test('a poster-less video yields NO image preview url', () {
      const item = PostCardResolvedMediaItem(
        id: 'm1',
        type: 'VIDEO',
        url: 'https://cdn.example.com/clip.mp4',
        thumbUrl: null,
        caption: null,
        width: 1920,
        height: 1080,
        duration: 42000,
        editDisclosure: false,
      );

      // The regression in one line: this used to return the MP4 url.
      expect(item.previewUrl, isEmpty,
          reason: 'a video url was offered as an image url');
      expect(item.playableUrl, 'https://cdn.example.com/clip.mp4',
          reason: 'the playable source must survive — identity is preserved');
    });

    test('a video WITH a server poster offers the poster, not the video', () {
      const item = PostCardResolvedMediaItem(
        id: 'm2',
        type: 'VIDEO',
        url: 'https://cdn.example.com/clip.mp4',
        thumbUrl: 'https://cdn.example.com/clip-poster.jpg',
        caption: null,
        width: null,
        height: null,
        duration: null,
        editDisclosure: false,
      );
      expect(item.previewUrl, 'https://cdn.example.com/clip-poster.jpg');
      expect(item.posterUrl, 'https://cdn.example.com/clip-poster.jpg');
    });

    test('images are unaffected', () {
      const item = PostCardResolvedMediaItem(
        id: 'm3',
        type: 'IMAGE',
        url: 'https://cdn.example.com/photo.jpg',
        thumbUrl: null,
        caption: null,
        width: null,
        height: null,
        duration: null,
        editDisclosure: false,
      );
      expect(item.previewUrl, 'https://cdn.example.com/photo.jpg');
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // THE SHARED ADAPTER — one delegation, three surfaces
  // ───────────────────────────────────────────────────────────────────────

  group('CanonicalMediaThumb delegates video instead of framing it', () {
    testWidgets('a poster-less video renders the video surface, never a '
        'broken-image tile', (tester) async {
      await tester.pumpWidget(host(const CanonicalMediaThumb(
        media: FeedMedia(
          id: 'fm1',
          mediaId: 'media-1',
          mediaType: 'VIDEO',
          mimeType: 'video/mp4',
          visibility: 'PUBLIC',
          url: 'https://cdn.example.com/clip.mp4',
          width: 1280,
          height: 720,
          duration: 12000,
        ),
      )));
      await tester.pump();

      expect(find.byType(AuraVideoSurface), findsOneWidget,
          reason: 'video did not reach the canonical surface');
      expect(find.byType(BrokenMediaTile), findsNothing);
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing,
          reason: 'the founder-observed glyph is back');
    });

    testWidgets('an image still goes through the image frame', (tester) async {
      await tester.pumpWidget(host(const CanonicalMediaThumb(
        media: FeedMedia(
          id: 'fm2',
          mediaId: 'media-2',
          mediaType: 'IMAGE',
          mimeType: 'image/jpeg',
          visibility: 'PUBLIC',
          url: 'https://cdn.example.com/photo.jpg',
        ),
      )));
      await tester.pump();
      expect(find.byType(AuraVideoSurface), findsNothing,
          reason: 'images were dragged onto the video path');
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // PLATFORM REACH — the reason a client-only poster cannot be the authority
  // ───────────────────────────────────────────────────────────────────────

  group('platform decode capability is stated, not assumed', () {
    test('web, Android, iOS and macOS can decode', () {
      expect(storedVideoCanDecodeInline(isWeb: true), isTrue);
      for (final p in [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      ]) {
        expect(storedVideoCanDecodeInline(platform: p, isWeb: false), isTrue,
            reason: '$p should decode');
      }
    });

    test('Windows and Linux cannot — video_player ships no implementation', () {
      for (final p in [TargetPlatform.windows, TargetPlatform.linux]) {
        expect(storedVideoCanDecodeInline(platform: p, isWeb: false), isFalse,
            reason: '$p has no video_player implementation; claiming '
                'otherwise is how a released platform ends up throwing');
      }
    });

    testWidgets('where it cannot decode, it says so honestly rather than '
        'attempting a decode', (tester) async {
      await tester.pumpWidget(host(const AuraVideoSurface(
        url: 'https://cdn.example.com/clip.mp4',
        fileName: 'quarterly-update.mp4',
        canDecode: false,
      )));
      await tester.pump();

      // No decode was attempted, and the object keeps its identity.
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
      expect(find.byType(AuraVideoSurface), findsOneWidget);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // FALLBACK GRAMMAR
  // ───────────────────────────────────────────────────────────────────────

  group('failure states stay honest', () {
    testWidgets('an unreachable video names itself, and is not a broken image',
        (tester) async {
      await tester.pumpWidget(host(AuraStoredMedia(
        media: StoredMedia.fromParts(
          declaredKind: 'VIDEO',
          mimeType: 'video/mp4',
          fileName: 'board-briefing.mp4',
          state: StoredMediaState.unavailable,
        ),
      )));
      await tester.pump();

      expect(find.byType(AuraVideoUnavailableTile), findsOneWidget);
      expect(find.text('board-briefing.mp4'), findsOneWidget,
          reason: 'identity was lost on failure');
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    });

    testWidgets('an unrecognised object keeps its identity card',
        (tester) async {
      await tester.pumpWidget(host(AuraStoredMedia(
        media: StoredMedia.fromParts(
          mimeType: 'application/zip',
          fileName: 'evidence.zip',
          sourceUrl: 'https://cdn.example.com/evidence.zip',
          sizeBytes: 2048,
        ),
      )));
      await tester.pump();
      expect(find.byType(AuraAttachmentCard), findsOneWidget);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // RESOLUTION LAYER
  // ───────────────────────────────────────────────────────────────────────

  group('stored media resolution', () {
    test('the mime wins over a declared kind', () {
      final m = StoredMedia.fromParts(
        mimeType: 'video/quicktime',
        declaredKind: 'IMAGE',
      );
      expect(m.kind, AttachmentPresentationKind.video);
      expect(m.isVideo, isTrue);
    });

    test('an empty poster is no poster', () {
      final m = StoredMedia.fromParts(mimeType: 'video/mp4', posterUrl: '   ');
      expect(m.hasPoster, isFalse);
      expect(m.posterUrl, isNull);
    });

    test('identity survives alongside presentation metadata', () {
      final m = StoredMedia.fromParts(
        mediaId: 'media-9',
        mimeType: 'video/mp4',
        sourceUrl: 'https://cdn.example.com/clip.mp4',
        posterUrl: 'https://cdn.example.com/poster.jpg',
        fileName: 'clip.mp4',
        width: 1920,
        height: 1080,
        durationMs: 65000,
        sizeBytes: 4096,
      );
      expect(m.mediaId, 'media-9');
      expect(m.sourceUrl, 'https://cdn.example.com/clip.mp4');
      expect(m.fileName, 'clip.mp4');
      expect(m.durationMs, 65000);
      expect(m.sizeBytes, 4096);
      expect(m.aspectRatio, closeTo(16 / 9, 0.001));
      expect(m.hasPoster, isTrue,
          reason: 'poster must ride ALONGSIDE identity, not replace it');
    });

    test('aspect ratio is never invented', () {
      expect(StoredMedia.fromParts(mimeType: 'video/mp4').aspectRatio, isNull);
      expect(
        StoredMedia.fromParts(mimeType: 'video/mp4', width: 0, height: 0)
            .aspectRatio,
        isNull,
      );
    });

    test('duration renders as a clock, and absence renders as nothing', () {
      expect(formatVideoDuration(65000), '1:05');
      expect(formatVideoDuration(3_725_000), '1:02:05');
      expect(formatVideoDuration(0), isEmpty);
      expect(formatVideoDuration(null), isEmpty);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // EXTENSIBILITY — the reason this is a registry and not a switch
  // ───────────────────────────────────────────────────────────────────────

  group('presentation registry', () {
    testWidgets('a registered presenter takes precedence over the built-ins',
        (tester) async {
      AuraStoredMediaRegistry.register((context, request) =>
          request.media.isVideo ? const Text('custom-video') : null);

      await tester.pumpWidget(host(AuraStoredMedia(
        media: StoredMedia.fromParts(
          mimeType: 'video/mp4',
          sourceUrl: 'https://cdn.example.com/clip.mp4',
          isPublic: true,
        ),
      )));
      await tester.pump();

      expect(find.text('custom-video'), findsOneWidget);
      expect(find.byType(AuraVideoSurface), findsNothing);
    });

    testWidgets('a presenter that declines falls through to the built-ins',
        (tester) async {
      AuraStoredMediaRegistry.register((context, request) => null);

      await tester.pumpWidget(host(AuraStoredMedia(
        media: StoredMedia.fromParts(
          mimeType: 'video/mp4',
          sourceUrl: 'https://cdn.example.com/clip.mp4',
          isPublic: true,
        ),
      )));
      await tester.pump();
      expect(find.byType(AuraVideoSurface), findsOneWidget);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // COMPOSE → SENT CONTINUITY
  // ───────────────────────────────────────────────────────────────────────

  group('compose and sent content share one grammar', () {
    testWidgets('a locally chosen video previews from its local source',
        (tester) async {
      await tester.pumpWidget(host(AuraStoredMedia(
        media: StoredMedia.fromParts(
          mimeType: 'video/mp4',
          localPath: 'blob:https://app.example.com/abcdef',
          fileName: 'chosen.mp4',
          state: StoredMediaState.local,
        ),
        context: StoredMediaContext.compose,
      )));
      await tester.pump();

      final surface =
          tester.widget<AuraVideoSurface>(find.byType(AuraVideoSurface));
      expect(surface.localPath, 'blob:https://app.example.com/abcdef');
      expect(surface.tap, AuraVideoTap.inline);
    });

    testWidgets('the preview survives while the upload is in flight',
        (tester) async {
      await tester.pumpWidget(host(AuraStoredMedia(
        media: StoredMedia.fromParts(
          mimeType: 'video/mp4',
          localPath: '/tmp/chosen.mp4',
          fileName: 'chosen.mp4',
          state: StoredMediaState.pending,
        ),
        context: StoredMediaContext.compose,
      )));
      await tester.pump();

      // Keying the local branch on state alone would blank this the moment
      // someone pressed send.
      expect(find.byType(AuraVideoSurface), findsOneWidget);
      expect(
        tester.widget<AuraVideoSurface>(find.byType(AuraVideoSurface)).localPath,
        '/tmp/chosen.mp4',
      );
    });

    testWidgets('once hydrated it presents from the stored object',
        (tester) async {
      await tester.pumpWidget(host(AuraStoredMedia(
        media: StoredMedia.fromParts(
          mediaId: 'media-77',
          mimeType: 'video/mp4',
          localPath: '/tmp/chosen.mp4',
          sourceUrl: 'https://cdn.example.com/clip.mp4',
          isPublic: true,
          fileName: 'chosen.mp4',
        ),
        context: StoredMediaContext.compose,
      )));
      await tester.pump();

      final surface =
          tester.widget<AuraVideoSurface>(find.byType(AuraVideoSurface));
      expect(surface.url, 'https://cdn.example.com/clip.mp4',
          reason: 'a sent video must not keep pointing at a local file');
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // CONTEXT SEMANTICS
  // ───────────────────────────────────────────────────────────────────────

  group('context decides where a video plays', () {
    testWidgets('a message contains its media, so it plays in place',
        (tester) async {
      await tester.pumpWidget(host(AuraStoredMedia(
        media: StoredMedia.fromParts(
          mimeType: 'video/mp4',
          sourceUrl: 'https://cdn.example.com/clip.mp4',
          isPublic: true,
        ),
        context: StoredMediaContext.message,
      )));
      await tester.pump();
      expect(
        tester.widget<AuraVideoSurface>(find.byType(AuraVideoSurface)).tap,
        AuraVideoTap.inline,
      );
    });

    testWidgets('a feed card references media, so it hands off to the viewer',
        (tester) async {
      await tester.pumpWidget(host(AuraStoredMedia(
        media: StoredMedia.fromParts(
          mimeType: 'video/mp4',
          sourceUrl: 'https://cdn.example.com/clip.mp4',
          isPublic: true,
        ),
        onOpenViewer: () {},
      )));
      await tester.pump();
      expect(
        tester.widget<AuraVideoSurface>(find.byType(AuraVideoSurface)).tap,
        AuraVideoTap.viewer,
      );
    });
  });
}
