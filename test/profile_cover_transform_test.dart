import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/shared/media/profile_media_editor.dart';

void main() {
  group('ProfileMediaCoverTransform', () {
    test('member and institution covers opt into the shared fit transform', () {
      expect(ProfileMediaEditorConfig.memberCover.fitInsideFrame, isTrue);
      expect(ProfileMediaEditorConfig.institutionCover.fitInsideFrame, isTrue);
      expect(ProfileMediaEditorConfig.memberAvatar.fitInsideFrame, isFalse);
      expect(ProfileMediaEditorConfig.institutionLogo.fitInsideFrame, isFalse);
    });

    test('same aspect ratio fills the target canvas', () {
      final rect = ProfileMediaCoverTransform.fittedRect(
        sourceSize: const Size(3000, 1000),
        targetSize: const Size(1500, 500),
      );

      expect(rect, const Rect.fromLTWH(0, 0, 1500, 500));
    });

    test('very wide image is centered with vertical padding', () {
      final rect = ProfileMediaCoverTransform.fittedRect(
        sourceSize: const Size(4000, 500),
        targetSize: const Size(1500, 500),
      );

      expect(rect.left, 0);
      expect(rect.width, 1500);
      expect(rect.height, closeTo(187.5, 0.001));
      expect(rect.top, closeTo(156.25, 0.001));
      expect(rect.bottom, closeTo(343.75, 0.001));
    });

    test('very tall image is centered with horizontal padding', () {
      final rect = ProfileMediaCoverTransform.fittedRect(
        sourceSize: const Size(500, 2000),
        targetSize: const Size(1500, 500),
      );

      expect(rect.top, 0);
      expect(rect.height, 500);
      expect(rect.width, closeTo(125, 0.001));
      expect(rect.left, closeTo(687.5, 0.001));
      expect(rect.right, closeTo(812.5, 0.001));
    });

    test('square image is centered without stretching', () {
      final rect = ProfileMediaCoverTransform.fittedRect(
        sourceSize: const Size(1000, 1000),
        targetSize: const Size(1600, 400),
      );

      expect(rect.top, 0);
      expect(rect.height, 400);
      expect(rect.width, 400);
      expect(rect.left, 600);
      expect(rect.right, 1000);
    });

    test('smaller source scales up proportionally to fit target', () {
      final rect = ProfileMediaCoverTransform.fittedRect(
        sourceSize: const Size(300, 100),
        targetSize: const Size(1500, 500),
      );

      expect(rect, const Rect.fromLTWH(0, 0, 1500, 500));
    });

    test('larger photographic source scales down proportionally', () {
      final rect = ProfileMediaCoverTransform.fittedRect(
        sourceSize: const Size(6000, 4000),
        targetSize: const Size(1500, 500),
      );

      expect(rect.width, 750);
      expect(rect.height, 500);
      expect(rect.left, 375);
      expect(rect.top, 0);
    });
  });
}
