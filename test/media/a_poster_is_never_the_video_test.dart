import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/media/stored_media.dart';

/// A POSTER IS A PICTURE OF THE MEDIA. IT IS NEVER THE MEDIA.
///
/// The institution post composer had no server thumbnail to use for a video —
/// there is never one, because the backend's derivative pipeline accepts image
/// mimes only, which `StoredMedia.posterUrl` says in its own doc comment — and
/// it fell back to the video's own URL:
///
///     thumbUrl: result.thumbUrl.trim().isNotEmpty ? result.thumbUrl.trim() : url
///
/// A poster is rendered with `Image.network`. So this pointed an image decoder
/// at an .mp4: it fetched the entire file (31 MiB, in the observed case),
/// failed to decode, and left a blank tile in the composition strip. Worse, the
/// fake poster SUPPRESSED the real preview — `AuraVideoSurface.initState` only
/// decodes a frame when `!_hasServerPoster`, so the one branch that could have
/// shown the video was skipped because a poster appeared to exist.
///
/// Founder-observed 2026-09-24, on the institution composer, on web.
///
/// WHY THIS WAS INVISIBLE. Every unit on the path was individually correct.
/// `_asStoredMedia` faithfully copies what it is handed; `fromParts` faithfully
/// stores it; the surface faithfully prefers a poster over a decode. The defect
/// existed only in the RELATIONSHIP between two fields, and nothing owned the
/// relationship. So the rule now lives in the one place both values arrive
/// together, and it is asserted here directly.
void main() {
  group('the rule itself', () {
    test('THE DEFECT: a poster equal to the source is not a poster', () {
      expect(
        posterOrNullFor(
          posterUrl: 'https://cdn.aura/v/clip.mp4',
          sourceUrl: 'https://cdn.aura/v/clip.mp4',
        ),
        isNull,
      );
    });

    test('a real, distinct poster survives', () {
      expect(
        posterOrNullFor(
          posterUrl: 'https://cdn.aura/v/clip.jpg',
          sourceUrl: 'https://cdn.aura/v/clip.mp4',
        ),
        'https://cdn.aura/v/clip.jpg',
      );
    });

    test('an empty or blank poster is still nothing', () {
      for (final p in ['', '   ', null]) {
        expect(
          posterOrNullFor(posterUrl: p, sourceUrl: 'https://cdn.aura/a.mp4'),
          isNull,
          reason: 'poster=${p == null ? 'null' : '"$p"'}',
        );
      }
    });

    test('incidental whitespace does not defeat the comparison', () {
      // The composer trims; a future adapter might not. Identity is about the
      // address, not about how it was spelled.
      expect(
        posterOrNullFor(
          posterUrl: '  https://cdn.aura/v/clip.mp4 ',
          sourceUrl: 'https://cdn.aura/v/clip.mp4',
        ),
        isNull,
      );
    });

    test('a poster with no source at all is kept', () {
      // Local composition: bytes on hand, nothing uploaded yet.
      expect(
        posterOrNullFor(posterUrl: 'blob:poster', sourceUrl: null),
        'blob:poster',
      );
    });
  });

  group('the model enforces it, so no adapter has to remember', () {
    test('fromParts drops a self-referential poster', () {
      final m = StoredMedia.fromParts(
        mimeType: 'video/mp4',
        declaredKind: 'VIDEO',
        sourceUrl: 'https://cdn.aura/v/clip.mp4',
        posterUrl: 'https://cdn.aura/v/clip.mp4',
      );
      expect(m.isVideo, isTrue);
      expect(
        m.posterUrl,
        isNull,
        reason: 'with this null, initState decodes a real frame instead',
      );
    });

    test('and keeps a genuine one', () {
      final m = StoredMedia.fromParts(
        mimeType: 'video/mp4',
        declaredKind: 'VIDEO',
        sourceUrl: 'https://cdn.aura/v/clip.mp4',
        posterUrl: 'https://cdn.aura/v/clip-poster.jpg',
      );
      expect(m.posterUrl, 'https://cdn.aura/v/clip-poster.jpg');
    });

    test('the media stays reachable either way', () {
      // Removing the poster must not make the object look absent — that would
      // trade a blank tile for the "Unavailable" card, which is not a fix.
      final m = StoredMedia.fromParts(
        mimeType: 'video/mp4',
        declaredKind: 'VIDEO',
        sourceUrl: 'https://cdn.aura/v/clip.mp4',
        posterUrl: 'https://cdn.aura/v/clip.mp4',
      );
      expect(m.isReachable, isTrue);
    });
  });

  group('the composer no longer fabricates one', () {
    // COLLAPSED WHITESPACE, so the assertion survives `dart format`. A sibling
    // test in this very directory matched the raw source and started failing
    // the moment an unrelated edit made a condition wrap.
    final src = File(
      'lib/features/institutions/posts/institution_post_composer_screen.dart',
    ).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');

    test('the video fallback is gone at the source', () {
      // Read at the source because the construction is private and the rule is
      // a one-line judgement that a future edit could quietly restore.
      expect(src, contains('(video ? null : url)'));
      expect(
        src.contains(
          'thumbUrl: result.thumbUrl.trim().isNotEmpty '
          '? result.thumbUrl.trim() : url,',
        ),
        isFalse,
        reason: 'the unconditional fallback to the object itself is the defect',
      );
    });

    test('the reason is recorded where the decision is made', () {
      expect(src, contains('A POSTER IS A PICTURE OF THE MEDIA'));
    });
  });
}
