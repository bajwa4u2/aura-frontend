import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// STANDING UNKNOWN IS NOT STANDING REFUSED (2026-09-19).
///
/// A verified owner/admin opening `/institution/<slug>/posts/new` directly was
/// sent to the denial page, while the same composer opened from Explore. The
/// membership snapshot latches its last answer through an access re-check; the
/// capability projection reads the live value, which is empty in that window,
/// and the destination gate treated "empty" as "not granted". The gate must
/// wait while institution access is reloading, and still refuse otherwise.
void main() {
  final router = File('lib/router.dart').readAsStringSync();
  final gate = router.substring(router.indexOf('String? _enforceCanonicalIdMatch('));
  final body = gate.substring(0, gate.indexOf('\n}\n') > 0 ? gate.indexOf('\n}\n') : gate.length);

  test('the destination gate waits whenever standing is unknown', () {
    final wait = body.indexOf('if (projection.standing == null) {');
    final deny = body.indexOf('kInstitutionDenialDestination');
    expect(wait, greaterThan(0));
    expect(wait, lessThan(deny), reason: 'the wait must come before the denial');
    // 2026-10-08: an access re-check can SETTLE on an empty answer for a
    // moment; waiting only while loading refused owners on a fresh page load.
    expect(body.contains('projection.standing == null &&'), isFalse,
        reason: 'unknown standing must not be conditioned on loading');
  });

  test('a settled refusal still reaches the denial destination', () {
    expect(body.contains('institutionDestinationPermits(projection, section)'), isTrue);
    expect(body.contains(': kInstitutionDenialDestination;'), isTrue);
  });
}
