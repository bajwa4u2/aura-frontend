import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/media/aura_video_surface.dart';

/// A film that opens on black must not sit in the feed as a black box
/// (founder, 2026-09-30: "sometimes looks broken cards sometimes fine").
void main() {
  test('short clips keep their first frame', () {
    expect(videoPosterPosition(const Duration(seconds: 3)), Duration.zero);
    expect(videoPosterPosition(const Duration(seconds: 4)), Duration.zero);
  });

  test('a longer video takes its poster a tenth of the way in', () {
    expect(videoPosterPosition(const Duration(seconds: 20)), const Duration(seconds: 2));
  });

  test('never more than three seconds in, however long the film', () {
    expect(videoPosterPosition(const Duration(seconds: 95)), const Duration(seconds: 3));
    expect(videoPosterPosition(const Duration(minutes: 40)), const Duration(seconds: 3));
  });
}
