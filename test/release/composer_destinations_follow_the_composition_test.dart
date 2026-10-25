import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// WHAT EACH DESTINATION CAN TAKE FOLLOWS THE COMPOSITION (2026-10-25).
///
/// Found recording Meta's App Review: Instagram stayed greyed out after a
/// photo was attached, because what each destination could take was decided
/// once, when the composer opened. It is now re-decided from the same
/// provider answers whenever the composition changes.
void main() {
  final src = File('lib/features/posts/presentation/compose_screen.dart').readAsStringSync();

  test('destinations are decided in one place, from kept provider answers', () {
    expect(src, contains('void _applyDestinations(List<_ProviderProbe> probes)'));
    expect(src, contains('_destinationProbes = probes;'));
  });

  test('every composition change re-decides them', () {
    final sync = src.substring(src.indexOf('void _syncExternalPublishingToggles()'));
    expect(sync.substring(0, 200), contains('_applyDestinations(probes)'));
  });

  test('an upload finishing and an audience change both re-decide', () {
    final vis = src.substring(src.indexOf('void _setVisibility('));
    expect(vis.substring(0, 400), contains('_syncExternalPublishingToggles()'));
    expect(src, contains('attachment.uploading = false;\n      attachment.error = null;\n      _syncExternalPublishingToggles();'));
  });
}
