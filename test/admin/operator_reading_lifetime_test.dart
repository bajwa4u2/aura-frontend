import 'package:aura/features/admin/data/operator_cache.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// PERFORMANCE IS PRODUCT, AND SO IS FRESHNESS.
///
/// The console's transition cost was structural: every shared read was
/// `autoDispose`, so moving from NOW to WORK threw away the worklist and then
/// drew a skeleton while re-fetching the identical answer.
///
/// A survival window fixes that, and introduces a risk of its own — an
/// operator acting on a reading from before their own decision. These tests
/// hold both ends: the reading survives a navigation, and it does NOT survive
/// long, and an explicit invalidation still discards it at once.
void main() {
  test('a reading survives a navigation between two areas', () async {
    var reads = 0;
    final provider = FutureProvider.autoDispose<int>((ref) async {
      cacheOperatorReading(ref);
      return ++reads;
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    // NOW watches it.
    var sub = container.listen(provider, (_, __) {});
    await container.read(provider.future);
    expect(reads, 1);

    // The operator leaves NOW, then arrives at WORK a moment later.
    sub.close();
    sub = container.listen(provider, (_, __) {});
    await container.read(provider.future);

    // The same answer, not a second request behind a skeleton.
    expect(reads, 1);
    sub.close();
  });

  // The two timing tests run on the test binding's fake clock: they used
  // real 20-60 ms waits against 20-40 ms windows and failed under load
  // (21 Oct 2026). tester.pump(d) advances time exactly.
  testWidgets('and it does not survive being left alone', (tester) async {
    var reads = 0;
    final provider = FutureProvider.autoDispose<int>((ref) async {
      cacheOperatorReading(ref, lifetime: const Duration(milliseconds: 20));
      return ++reads;
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    var sub = container.listen(provider, (_, __) {});
    await container.read(provider.future);
    expect(reads, 1);
    sub.close();

    // Long enough that somebody else could have changed the governed state
    // this reading describes.
    await tester.pump(const Duration(milliseconds: 60));

    sub = container.listen(provider, (_, __) {});
    await container.read(provider.future);
    expect(reads, 2, reason: 'a stale reading must not outlive its window');
    sub.close();
    // Let the last window run out so no timer outlives the test.
    await tester.pump(const Duration(milliseconds: 60));
  });

  test('an operator decision discards the reading immediately', () async {
    // The dangerous case: revoke a grant, then read a list that still shows
    // it. Invalidation must beat the survival window every time.
    var reads = 0;
    final provider = FutureProvider.autoDispose<int>((ref) async {
      cacheOperatorReading(ref);
      return ++reads;
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final sub = container.listen(provider, (_, __) {});
    await container.read(provider.future);
    expect(reads, 1);

    container.invalidate(provider);
    await container.read(provider.future);
    expect(reads, 2);
    sub.close();
  });

  testWidgets('the window is measured from the last time anybody looked',
      (tester) async {
    var reads = 0;
    final provider = FutureProvider.autoDispose<int>((ref) async {
      cacheOperatorReading(ref, lifetime: const Duration(milliseconds: 40));
      return ++reads;
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    var sub = container.listen(provider, (_, __) {});
    await container.read(provider.future);
    sub.close();

    // Halfway through the window, somebody looks again.
    await tester.pump(const Duration(milliseconds: 20));
    sub = container.listen(provider, (_, __) {});
    await container.read(provider.future);
    expect(reads, 1);
    sub.close();

    // The clock restarted from that second look, so this is still inside it.
    await tester.pump(const Duration(milliseconds: 20));
    sub = container.listen(provider, (_, __) {});
    await container.read(provider.future);
    expect(reads, 1);
    sub.close();
    // Let the last window run out so no timer outlives the test.
    await tester.pump(const Duration(milliseconds: 60));
  });

  test('the default window is short enough to be honest', () {
    // A console for live governed state. If this ever grows past a minute it
    // has stopped being a navigation aid and started being a cache.
    expect(kOperatorReadingLifetime.inSeconds, lessThanOrEqualTo(30));
    expect(kOperatorReadingLifetime.inSeconds, greaterThan(0));
  });
}
