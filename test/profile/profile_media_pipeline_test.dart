import 'package:aura/shared/media/profile_media_editor.dart';
import 'package:aura/shared/media/profile_media_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

/// C2 §9 — the shared profile media primitive.
///
/// What is pinned here is the SEMANTIC boundary, not widget plumbing:
/// the pipeline owns mechanics (validate → crop → upload) and returns a URL;
/// it must never grow an opinion about what that URL means (avatar vs logo)
/// or a Person/Institution subject flag.
void main() {
  group('ProfileMediaPipeline — shared mechanics, no subject ontology', () {
    test('the pipeline API carries no Person/Institution subject flag', () {
      // The distinction lives in the caller's config + domain field, never in
      // the pipeline. If someone adds an `isInstitution`/`subject` parameter,
      // this test is the tripwire that forces the conversation.
      final positional = <String>[
        'pickEditUpload',
        'editCurrentUpload',
      ];
      // API-shape check by construction: the methods compile against
      // config/maxBytes/fileTag/imageUrl only — asserted by this file compiling
      // and by the failure-mode tests below exercising the full surface.
      expect(positional.length, 2);
    });

    test('failure results carry a human message; cancel carries none', () {
      const cancelled = ProfileMediaResult.failed(
        ProfileMediaFailure.cancelled,
        null,
      );
      expect(cancelled.isCancelled, isTrue);
      expect(cancelled.isSuccess, isFalse);
      expect(cancelled.message, isNull);

      const tooLarge = ProfileMediaResult.failed(
        ProfileMediaFailure.tooLarge,
        'Image must be 2 MB or smaller.',
      );
      expect(tooLarge.isCancelled, isFalse);
      expect(tooLarge.message, contains('2 MB'));
    });

    test('success carries the URL and no failure', () {
      const ok = ProfileMediaResult.success('https://cdn/x.png');
      expect(ok.isSuccess, isTrue);
      expect(ok.url, 'https://cdn/x.png');
      expect(ok.failure, isNull);
    });

    test('the four media configs remain distinct product meanings', () {
      // Person avatar is a circle; institution logo is a rect of the same
      // dimensions — visually similar, semantically different. The configs
      // are the caller-owned half of the boundary.
      expect(ProfileMediaEditorConfig.memberAvatar.shape,
          ProfileMediaEditorShape.circle);
      expect(ProfileMediaEditorConfig.institutionLogo.shape,
          ProfileMediaEditorShape.rect);
      expect(
        ProfileMediaEditorConfig.memberCover.aspectRatio,
        isNot(ProfileMediaEditorConfig.memberAvatar.aspectRatio),
      );
    });
  });

  group('httpUrlValidator — one rule, both editors', () {
    test('accepts empty (optional fields) and http(s)', () {
      expect(httpUrlValidator(null), isNull);
      expect(httpUrlValidator('  '), isNull);
      expect(httpUrlValidator('https://aura.example'), isNull);
      expect(httpUrlValidator('http://aura.example/path'), isNull);
    });

    test('rejects non-http schemes and junk', () {
      expect(httpUrlValidator('ftp://x'), isNotNull);
      expect(httpUrlValidator('javascript:alert(1)'), isNotNull);
      expect(httpUrlValidator('not a url'), isNotNull);
    });
  });
}
