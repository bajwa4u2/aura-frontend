import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A NEW RENDERER IS A NEW VIEW.
///
/// flutter_webrtc 1.4.1's web RTCVideoView finds its <video> once, in
/// initState. Reused with a new renderer it painted the old, removed element:
/// on 2026-10-24 a phone guest's tile went black after the host reloaded,
/// while the host's new video played unseen. Every RTCVideoView is keyed by
/// its renderer so a new renderer always builds a new view.
void main() {
  test('every RTCVideoView is keyed by its renderer', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    var views = 0;
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('RTCVideoView(') ||
            lines[i].trimLeft().startsWith('//')) {
          continue;
        }
        views++;
        final next = lines.skip(i + 1).take(8).join('\n');
        expect(next, contains('key: ObjectKey('),
            reason: '${file.path}:${i + 1} builds an RTCVideoView without '
                'a renderer key');
      }
    }
    expect(views, greaterThan(0));
  });
}
