import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/public/domain/monetization_kind.dart';

/// Founder decision 2026-10-07: Aura earns nothing from advertising, and paid
/// reach into the feed is advertising. Paid distribution is retired.
void main() {
  test('a DISTRIBUTED row from before reads as organic', () {
    expect(MonetizationKindX.fromPaidActionWire('DISTRIBUTED'), isNull);
    expect(MonetizationKindX.fromPaidActionWire('DISTRIBUTION'), isNull);
  });

  test('the in-thread labels are unchanged', () {
    expect(MonetizationKindX.fromPaidActionWire('PRIORITY'),
        MonetizationKind.priorityResponse);
    expect(MonetizationKindX.fromPaidActionWire('HOSTED'),
        MonetizationKind.hostedSession);
  });

  test('nothing in the product can be labelled paid distribution', () {
    expect(MonetizationKind.values.map((k) => k.label),
        isNot(contains('Paid distribution')));
  });
}
