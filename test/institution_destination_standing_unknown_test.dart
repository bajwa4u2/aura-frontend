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

  test('the destination gate waits while standing is unknown and access is loading', () {
    final wait = body.indexOf('projection.standing == null');
    final deny = body.indexOf('kInstitutionDenialDestination');
    expect(wait, greaterThan(0));
    expect(body.contains('institutionAccessProvider).isLoading'), isTrue);
    expect(wait, lessThan(deny), reason: 'the wait must come before the denial');
  });

  test('a settled refusal still reaches the denial destination', () {
    expect(body.contains('institutionDestinationPermits(projection, section)'), isTrue);
    expect(body.contains(': kInstitutionDenialDestination;'), isTrue);
  });
}
