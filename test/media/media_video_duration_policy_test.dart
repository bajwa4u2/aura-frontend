import 'dart:io';

import 'package:aura/core/media/media_capacity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Native video runs to 180 s (founder decision 2026-09-19: more than 150 s,
/// as a platform capability). The backend's `media-duration-policy.ts` is the
/// authority; the client mirrors it so camera capture never records a video
/// the server would refuse. No hidden 30-second cap may remain.
void main() {
  test('the client mirrors the server video limit of 180 s', () {
    expect(MediaCapacity.maxVideoDuration, const Duration(seconds: 180));
    expect(MediaCapacity.maxVideoDuration.inSeconds, greaterThan(150));
  });

  test('every camera capture path reads the canonical limit', () {
    final compose = File('lib/features/posts/presentation/compose_screen.dart')
        .readAsStringSync();
    final acquisition =
        File('lib/core/media/media_acquisition.dart').readAsStringSync();
    expect(compose.contains('maxDuration: MediaCapacity.maxVideoDuration'), isTrue);
    expect(acquisition.contains('Duration maxDuration = MediaCapacity.maxVideoDuration'), isTrue);
  });

  test('no hard-coded video capture ceiling survives in lib/', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final text = f.readAsStringSync();
      if (RegExp(r'maxDuration:\s*const Duration\(seconds:').hasMatch(text) ||
          RegExp(r'Duration maxDuration = const Duration\(').hasMatch(text)) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty, reason: 'video capture must read MediaCapacity.maxVideoDuration');
  });
}
