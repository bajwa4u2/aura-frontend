import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Runner target never imports WebRTC directly.
///
/// `import WebRTC` in the app's own Swift makes Xcode link the WebRTC
/// framework into Runner, which the CocoaPods set-up does not expect; the
/// archive then failed to link Flutter's own symbols (Codemagic #64,
/// 22 Oct 2026). WebRTC's audio session is reached at run time instead.
void main() {
  test('no Swift file in ios/Runner imports WebRTC', () {
    final offenders = <String>[];
    for (final f in Directory('ios/Runner').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.swift')) continue;
      final lines = f.readAsLinesSync();
      if (lines.any((l) => RegExp(r'^\s*import\s+WebRTC\b').hasMatch(l))) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty);
  });

  test('CallKit still hands audio to WebRTC through the run-time bridge', () {
    final swift = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(swift, contains('NSClassFromString("RTCAudioSession")'));
    expect(swift, contains('RtcAudio.didActivate(audioSession)'));
    expect(swift, contains('RtcAudio.didDeactivate(audioSession)'));
  });
}
