import 'package:aura/features/admin/data/operator_discovery.dart';
import 'package:flutter_test/flutter_test.dart';

/// EVIDENCE HAS AN AGE. THAT IS NOT THE SAME AS BEING STALE.
///
/// Discovery and media retention both carry a reading time from the server —
/// a per-source `lastFetchedAt`, and the retention pass's `finishedAt` — and
/// neither was ever shown. An operator reading a coverage number could not tell
/// whether the evidence behind it came from an hour ago or from last week, and
/// "Last pass ran on schedule" read identically whether that pass finished last
/// night or three weeks ago.
///
/// Showing the age is a fact about the source. Calling it STALE would be a
/// judgement, and in Discovery's case a false one:
///
///   * a provider that answered and reported nothing has reported a RESULT.
///     Bing's zero is live-verified and legitimate; ageing it would turn a
///     finding into a suspicion.
///   * a provider Aura holds no credential for is unavailable by CONFIGURATION.
///     It has no fetch time at all, and inventing one would be worse than
///     saying nothing.
///   * a retention pass that has never run is not an old pass.
///
/// These tests hold that line at the model, where it is cheapest to keep.
void main() {
  group('a source carries its own fetch time', () {
    test('an available source that has spoken has a fetch time', () {
      final source = DiscoverySource.fromJson(const {
        'source': 'SITEMAP',
        'available': true,
        'lastFetchedAt': '2026-08-31T01:00:00.000Z',
      });

      expect(source.available, isTrue);
      expect(source.lastFetchedAt, isNotNull);
      expect(source.reason, isNull);
    });

    test('a source with no credential has a reason and NO fetch time', () {
      final source = DiscoverySource.fromJson(const {
        'source': 'GOOGLE_SEARCH_CONSOLE',
        'available': false,
        'reason': 'Aura holds no credential for this provider',
        'lastFetchedAt': null,
      });

      expect(source.available, isFalse);
      expect(source.reason, isNotNull,
          reason: 'the operator must see WHICH evidence is missing');
      expect(source.lastFetchedAt, isNull,
          reason: 'unavailable by configuration is not an old reading, and '
              'giving it an age would invent one');
    });

    test('an unparseable fetch time is null, never a fabricated instant', () {
      final source = DiscoverySource.fromJson(const {
        'source': 'INDEXNOW',
        'available': true,
        'lastFetchedAt': 'not a date',
      });
      expect(source.lastFetchedAt, isNull);
    });
  });

  group('a legitimate zero is a result, not an old reading', () {
    test('an available source that reported nothing keeps its availability', () {
      // This is the Bing shape: the credential works, the provider answered,
      // and the answer was zero. It is live-verified and it is a finding.
      final bing = DiscoverySource.fromJson(const {
        'source': 'BING_WEBMASTER',
        'available': true,
        'lastFetchedAt': '2026-08-31T01:00:00.000Z',
      });

      expect(bing.available, isTrue,
          reason: 'a zero result must never demote the source to unavailable');
      expect(bing.reason, isNull,
          reason: 'there is nothing wrong to explain — it answered');
      expect(bing.lastFetchedAt, isNotNull,
          reason: 'it spoke, so it has a fetch time like any other source');
    });
  });

  group('unavailable sources are counted, not silently dropped', () {
    test('the report separates who could speak from who could not', () {
      final report = DiscoveryReport(
        coverage: DiscoveryCoverage.fromJson(const <String, dynamic>{}),
        sources: [
          DiscoverySource.fromJson(const {
            'source': 'SITEMAP',
            'available': true,
            'lastFetchedAt': '2026-08-31T01:00:00.000Z',
          }),
          DiscoverySource.fromJson(const {
            'source': 'BING_WEBMASTER',
            'available': true,
            'lastFetchedAt': '2026-08-31T01:00:00.000Z',
          }),
          DiscoverySource.fromJson(const {
            'source': 'GOOGLE_SEARCH_CONSOLE',
            'available': false,
            'reason': 'Aura holds no credential for this provider',
          }),
        ],
      );

      expect(report.sources.length, 3);
      expect(report.unavailable.length, 1,
          reason: 'zero with a source unavailable is not a finding, and the '
              'area needs the count to say so');
      expect(report.unavailable.single.label, 'Google Search Console');
    });
  });
}
