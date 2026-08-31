/// DISCOVERY, AS DATA.
///
/// Whether the outside world can find what the estates published. Read from
/// Aura's own observation tables, never from a provider directly — the client
/// must not know or care which adapter produced a number, because the whole
/// architectural point is that no single provider is load-bearing.
///
/// OBSERVATION ≠ CONTROL. There is no method here that publishes, retires,
/// submits or asks a search engine for anything. `collect` gathers evidence
/// into Aura's own tables and does nothing outward beyond fetching two of our
/// own public documents.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';

/// The five estates Discovery observes. Frozen scope, founder-set.
enum DiscoveryEstate {
  auraPlatform('AURA_PLATFORM', 'Aura Platform'),
  aura('AURA', 'Aura'),
  orchestrate('ORCHESTRATE', 'Orchestrate'),
  bajwaWrites('BAJWA_WRITES', 'Bajwa Writes'),
  founder('FOUNDER', 'Founder');

  const DiscoveryEstate(this.wire, this.label);

  final String wire;
  final String label;

  static DiscoveryEstate fromWire(String? value) {
    final v = (value ?? '').trim().toUpperCase();
    for (final e in DiscoveryEstate.values) {
      if (e.wire == v) return e;
    }
    return DiscoveryEstate.aura;
  }
}

/// How visible one published object is.
///
/// UNOBSERVED and UNKNOWN are deliberately different. "No provider has spoken
/// about this" and "a provider looked and could not tell" are different
/// problems with different owners, and collapsing them into "not indexed"
/// loses the only distinction that says who should act.
enum DiscoveryVisibility {
  unobserved('UNOBSERVED', 'Nothing has seen it'),
  unreachable('UNREACHABLE', 'A crawler could not fetch it'),
  unknown('UNKNOWN', 'Seen, but nothing says whether it is indexed'),
  reachable('REACHABLE', 'A crawler fetched a real card');

  const DiscoveryVisibility(this.wire, this.label);

  final String wire;
  final String label;

  static DiscoveryVisibility fromWire(String? value) {
    final v = (value ?? '').trim().toUpperCase();
    for (final e in DiscoveryVisibility.values) {
      if (e.wire == v) return e;
    }
    return DiscoveryVisibility.unknown;
  }
}

/// One evidence source and whether it can currently speak.
class DiscoverySource {
  const DiscoverySource({
    required this.source,
    required this.available,
    this.reason,
    this.lastFetchedAt,
  });

  final String source;
  final bool available;

  /// Why not. Shown verbatim: an operator reading a coverage number must be
  /// able to see which evidence is missing rather than trusting a figure built
  /// from less than they think.
  final String? reason;

  final DateTime? lastFetchedAt;

  /// Human name for an adapter. The wire value is an enum shout.
  String get label => switch (source.toUpperCase()) {
        'GOOGLE_SEARCH_CONSOLE' => 'Google Search Console',
        'BING_WEBMASTER' => 'Bing Webmaster',
        'INDEXNOW' => 'IndexNow',
        'SITEMAP' => 'Our own sitemap',
        'CRAWLER_FETCH' => 'Crawler reachability probe',
        'AURA_REFERRAL' => 'Aura referral telemetry',
        _ => source,
      };

  factory DiscoverySource.fromJson(Map<String, dynamic> json) {
    String s(dynamic v) => (v ?? '').toString().trim();
    return DiscoverySource(
      source: s(json['source']),
      available: json['available'] == true,
      reason: s(json['reason']).isEmpty ? null : s(json['reason']),
      lastFetchedAt: DateTime.tryParse(s(json['lastFetchedAt'])),
    );
  }
}

/// Published, advertised, observed — and the gaps between them.
class DiscoveryCoverage {
  const DiscoveryCoverage({
    required this.estate,
    required this.published,
    required this.advertisedTotal,
    required this.advertisedFromInventory,
    required this.observed,
    required this.indexed,
    required this.families,
  });

  final DiscoveryEstate estate;

  /// What Aura has made public, counted from its own tables.
  final int published;

  /// Everything the sitemap lists, INCLUDING addresses that are not governed
  /// objects at all.
  final int advertisedTotal;

  /// How much of the published corpus the sitemap actually mentions. The gap
  /// between this and [published] is the finding Discovery exists to surface.
  final int advertisedFromInventory;

  final int observed;
  final int indexed;
  final List<DiscoveryFamily> families;

  /// Published objects the sitemap never mentions.
  int get unadvertised => (published - advertisedFromInventory).clamp(0, published);

  bool get hasSitemapGap => unadvertised > 0;

  factory DiscoveryCoverage.fromJson(Map<String, dynamic> json) {
    int i(String k) => (json[k] as num?)?.toInt() ?? 0;
    final raw = json['families'];
    return DiscoveryCoverage(
      estate: DiscoveryEstate.fromWire(json['estate']?.toString()),
      published: i('published'),
      advertisedTotal: i('advertisedTotal'),
      advertisedFromInventory: i('advertisedFromInventory'),
      observed: i('observed'),
      indexed: i('indexed'),
      families: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => DiscoveryFamily.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false)
          : const <DiscoveryFamily>[],
    );
  }
}

class DiscoveryFamily {
  const DiscoveryFamily({
    required this.family,
    required this.published,
    required this.advertised,
    required this.observed,
  });

  final String family;
  final int published;
  final int advertised;
  final int observed;

  factory DiscoveryFamily.fromJson(Map<String, dynamic> json) {
    int i(String k) => (json[k] as num?)?.toInt() ?? 0;
    return DiscoveryFamily(
      family: (json['family'] ?? '').toString(),
      published: i('published'),
      advertised: i('advertised'),
      observed: i('observed'),
    );
  }
}

/// One published object and what is known about its visibility.
class DiscoveryObject {
  const DiscoveryObject({
    required this.canonicalUrl,
    required this.objectFamily,
    required this.visibility,
    required this.impressions,
    required this.clicks,
    required this.sources,
    this.publishedAt,
    this.lastObservedOn,
  });

  final String canonicalUrl;
  final String objectFamily;
  final DiscoveryVisibility visibility;
  final int impressions;
  final int clicks;
  final List<String> sources;
  final DateTime? publishedAt;
  final DateTime? lastObservedOn;

  factory DiscoveryObject.fromJson(Map<String, dynamic> json) {
    String s(dynamic v) => (v ?? '').toString().trim();
    return DiscoveryObject(
      canonicalUrl: s(json['canonicalUrl']),
      objectFamily: s(json['objectFamily']),
      visibility: DiscoveryVisibility.fromWire(s(json['visibility'])),
      impressions: (json['impressions'] as num?)?.toInt() ?? 0,
      clicks: (json['clicks'] as num?)?.toInt() ?? 0,
      sources: json['sources'] is List
          ? (json['sources'] as List).map((e) => e.toString()).toList()
          : const <String>[],
      publishedAt: DateTime.tryParse(s(json['publishedAt'])),
      lastObservedOn: DateTime.tryParse(s(json['lastObservedOn'])),
    );
  }
}

/// An aggregated, redacted search query.
class DiscoveryQuery {
  const DiscoveryQuery({
    required this.query,
    required this.impressions,
    required this.clicks,
  });

  /// ALREADY REDACTED BY THE SERVER. Emails, phone numbers, card-shaped digits
  /// and key-shaped tokens are replaced before this leaves the backend, and
  /// nothing on this side un-redacts anything.
  final String query;

  final int impressions;
  final int clicks;

  factory DiscoveryQuery.fromJson(Map<String, dynamic> json) {
    return DiscoveryQuery(
      query: (json['query'] ?? '').toString(),
      impressions: (json['impressions'] as num?)?.toInt() ?? 0,
      clicks: (json['clicks'] as num?)?.toInt() ?? 0,
    );
  }
}

class DiscoveryQueryPage {
  const DiscoveryQueryPage({
    required this.items,
    required this.withheld,
    required this.floor,
  });

  final List<DiscoveryQuery> items;

  /// How many were withheld for being below the display floor. Named so a
  /// short list reads as a floor doing its job rather than as an estate
  /// nobody searches for.
  final int withheld;

  final int floor;

  factory DiscoveryQueryPage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    return DiscoveryQueryPage(
      items: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => DiscoveryQuery.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false)
          : const <DiscoveryQuery>[],
      withheld: (json['withheld'] as num?)?.toInt() ?? 0,
      floor: (json['withheldBelowImpressions'] as num?)?.toInt() ?? 5,
    );
  }
}

class DiscoveryRetention {
  const DiscoveryRetention({
    required this.rawRows,
    required this.observations,
    required this.rawRetentionDays,
    required this.observationRetentionMonths,
    this.oldestRawFetchedAt,
  });

  final int rawRows;
  final int observations;
  final int rawRetentionDays;
  final int observationRetentionMonths;
  final DateTime? oldestRawFetchedAt;

  factory DiscoveryRetention.fromJson(Map<String, dynamic> json) {
    int i(String k, int fallback) => (json[k] as num?)?.toInt() ?? fallback;
    return DiscoveryRetention(
      rawRows: i('rawRows', 0),
      observations: i('observations', 0),
      rawRetentionDays: i('rawRetentionDays', 90),
      observationRetentionMonths: i('observationRetentionMonths', 24),
      oldestRawFetchedAt:
          DateTime.tryParse((json['oldestRawFetchedAt'] ?? '').toString()),
    );
  }
}

/// Coverage and the sources behind it, together — because a coverage number
/// read without knowing which evidence was missing is a number that misleads.
class DiscoveryReport {
  const DiscoveryReport({required this.coverage, required this.sources});

  final DiscoveryCoverage coverage;
  final List<DiscoverySource> sources;

  Iterable<DiscoverySource> get unavailable =>
      sources.where((s) => !s.available);
}

class OperatorDiscoveryRepository {
  const OperatorDiscoveryRepository(this._dio);

  final Dio _dio;

  static Map<String, dynamic> _map(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const {};
  }

  Future<DiscoveryReport> report(DiscoveryEstate estate) async {
    final res = await _dio.get(
      '/v1/admin/discovery/coverage',
      queryParameters: {'estate': estate.wire},
    );
    final body = _map(res.data);
    final inner = body['data'] is Map ? _map(body['data']) : body;
    return DiscoveryReport(
      coverage: DiscoveryCoverage.fromJson(_map(inner['coverage'])),
      sources: inner['sources'] is List
          ? (inner['sources'] as List)
              .whereType<Map>()
              .map((e) => DiscoverySource.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false)
          : const <DiscoverySource>[],
    );
  }

  Future<List<DiscoveryObject>> objects(
    DiscoveryEstate estate, {
    String? family,
  }) async {
    final res = await _dio.get(
      '/v1/admin/discovery/objects',
      queryParameters: {
        'estate': estate.wire,
        if (family != null && family.isNotEmpty) 'family': family,
      },
    );
    final body = _map(res.data);
    final inner = body['data'] is Map ? _map(body['data']) : body;
    final items = inner['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => DiscoveryObject.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<DiscoveryQueryPage> queries(DiscoveryEstate estate) async {
    final res = await _dio.get(
      '/v1/admin/discovery/queries',
      queryParameters: {'estate': estate.wire},
    );
    final body = _map(res.data);
    return DiscoveryQueryPage.fromJson(
      body['data'] is Map ? _map(body['data']) : body,
    );
  }

  Future<DiscoveryRetention> retention() async {
    final res = await _dio.get('/v1/admin/discovery/retention');
    final body = _map(res.data);
    return DiscoveryRetention.fromJson(
      body['data'] is Map ? _map(body['data']) : body,
    );
  }

  Future<void> collect(DiscoveryEstate estate) async {
    await _dio.post(
      '/v1/admin/discovery/collect',
      queryParameters: {'estate': estate.wire},
    );
  }
}

final operatorDiscoveryRepositoryProvider =
    Provider<OperatorDiscoveryRepository>((ref) {
  return OperatorDiscoveryRepository(ref.watch(dioProvider));
});

/// Which estate is being observed. AURA by default — the estate this database
/// actually holds, and the only one whose published corpus can be counted from
/// the inside.
final discoveryEstateProvider =
    StateProvider<DiscoveryEstate>((_) => DiscoveryEstate.aura);

final discoveryReportProvider =
    FutureProvider.autoDispose<DiscoveryReport>((ref) async {
  final estate = ref.watch(discoveryEstateProvider);
  return ref.watch(operatorDiscoveryRepositoryProvider).report(estate);
});

final discoveryObjectsProvider =
    FutureProvider.autoDispose<List<DiscoveryObject>>((ref) async {
  final estate = ref.watch(discoveryEstateProvider);
  return ref.watch(operatorDiscoveryRepositoryProvider).objects(estate);
});

final discoveryQueriesProvider =
    FutureProvider.autoDispose<DiscoveryQueryPage>((ref) async {
  final estate = ref.watch(discoveryEstateProvider);
  return ref.watch(operatorDiscoveryRepositoryProvider).queries(estate);
});

final discoveryRetentionProvider =
    FutureProvider.autoDispose<DiscoveryRetention>((ref) async {
  return ref.watch(operatorDiscoveryRepositoryProvider).retention();
});
