import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';

class PublicInstitutionSummary {
  const PublicInstitutionSummary({
    required this.id,
    required this.slug,
    required this.name,
    required this.tagline,
    required this.description,
    required this.category,
    required this.logoUrl,
    required this.coverUrl,
    required this.websiteUrl,
    required this.jurisdiction,
    required this.city,
    required this.region,
    required this.country,
    required this.foundedYear,
    required this.isVerified,
    required this.canSpeakOfficially,
    required this.memberCount,
    required this.announcementCount,
    required this.unitCount,
    this.institutionClass,
    this.institutionType,
    this.domainTags = const [],
  });

  final String id;
  final String slug;
  final String name;
  final String? tagline;
  final String? description;
  final String? category;
  final String? logoUrl;
  final String? coverUrl;
  final String? websiteUrl;
  final String? jurisdiction;
  final String? city;
  final String? region;
  final String? country;
  final int? foundedYear;
  final bool isVerified;
  final bool canSpeakOfficially;
  final int memberCount;
  final int announcementCount;
  final int unitCount;

  /// Phase 1B — curated Level-1 class wire token. Null until classified.
  final String? institutionClass;

  /// Phase 1B — curated Level-2 type wire token. Null until classified.
  final String? institutionType;

  /// Phase 1B — Level-3 domain-tag wire tokens. Empty when unclassified.
  final List<String> domainTags;

  String get locationLabel {
    final parts = <String>[
      if ((city ?? '').isNotEmpty) city!,
      if ((region ?? '').isNotEmpty) region!,
      if ((country ?? '').isNotEmpty) country!,
    ];
    return parts.join(', ');
  }

  factory PublicInstitutionSummary.fromJson(Map<String, dynamic> json) {
    final counts = json['counts'] as Map<String, dynamic>? ?? const {};
    final rawTags = json['domainTags'];
    final tagList = rawTags is List
        ? rawTags
            .map((e) => e?.toString().trim() ?? '')
            .where((s) => s.isNotEmpty)
            .toList(growable: false)
        : const <String>[];
    return PublicInstitutionSummary(
      id: _s(json['id']),
      slug: _s(json['slug']),
      name: _s(json['name']),
      tagline: _ns(json['tagline']),
      description: _ns(json['description']),
      category: _ns(json['category']),
      logoUrl: _ns(json['logoUrl']),
      coverUrl: _ns(json['coverUrl']),
      websiteUrl: _ns(json['websiteUrl']),
      jurisdiction: _ns(json['jurisdiction']),
      city: _ns(json['city']),
      region: _ns(json['region']),
      country: _ns(json['country']),
      foundedYear:
          json['foundedYear'] is int ? json['foundedYear'] as int : null,
      isVerified: json['isVerified'] == true,
      canSpeakOfficially: json['canSpeakOfficially'] == true,
      memberCount: _i(counts['members']),
      announcementCount: _i(counts['announcements']),
      unitCount: _i(counts['units']),
      institutionClass: _ns(json['institutionClass']),
      institutionType: _ns(json['institutionType']),
      domainTags: tagList,
    );
  }
}

class PublicInstitutionsPage {
  const PublicInstitutionsPage({
    required this.verified,
    required this.other,
    required this.nextCursor,
  });

  final List<PublicInstitutionSummary> verified;
  final List<PublicInstitutionSummary> other;
  final String? nextCursor;

  bool get isEmpty => verified.isEmpty && other.isEmpty;
  int get total => verified.length + other.length;
}

class PublicUnit {
  const PublicUnit({
    required this.id,
    required this.slug,
    required this.name,
    required this.type,
    required this.description,
    required this.logoUrl,
    required this.websiteUrl,
    required this.contactEmail,
    required this.city,
    required this.region,
    required this.country,
  });

  final String id;
  final String slug;
  final String name;
  final String type;
  final String? description;
  final String? logoUrl;
  final String? websiteUrl;
  final String? contactEmail;
  final String? city;
  final String? region;
  final String? country;

  String get locationLabel {
    final parts = <String>[
      if ((city ?? '').isNotEmpty) city!,
      if ((region ?? '').isNotEmpty) region!,
      if ((country ?? '').isNotEmpty) country!,
    ];
    return parts.join(', ');
  }

  factory PublicUnit.fromJson(Map<String, dynamic> json) {
    return PublicUnit(
      id: _s(json['id']),
      slug: _s(json['slug']),
      name: _s(json['name']),
      type: _s(json['type']).isEmpty ? 'OTHER' : _s(json['type']),
      description: _ns(json['description']),
      logoUrl: _ns(json['logoUrl']),
      websiteUrl: _ns(json['websiteUrl']),
      contactEmail: _ns(json['contactEmail']),
      city: _ns(json['city']),
      region: _ns(json['region']),
      country: _ns(json['country']),
    );
  }
}

class PublicInstitutionUnitsPage {
  const PublicInstitutionUnitsPage({
    required this.institutionId,
    required this.institutionSlug,
    required this.institutionName,
    required this.institutionLogoUrl,
    required this.institutionIsVerified,
    required this.units,
  });

  final String institutionId;
  final String institutionSlug;
  final String institutionName;
  final String? institutionLogoUrl;
  final bool institutionIsVerified;
  final List<PublicUnit> units;
}

class PublicUnitDetail {
  const PublicUnitDetail({
    required this.unit,
    required this.institutionId,
    required this.institutionSlug,
    required this.institutionName,
    required this.institutionLogoUrl,
    required this.institutionTagline,
    required this.institutionDescription,
    required this.institutionIsVerified,
  });

  final PublicUnit unit;
  final String institutionId;
  final String institutionSlug;
  final String institutionName;
  final String? institutionLogoUrl;
  final String? institutionTagline;
  final String? institutionDescription;
  final bool institutionIsVerified;
}

class PublicInstitutionsRepository {
  PublicInstitutionsRepository(this._dio);

  final Dio _dio;

  Future<PublicInstitutionsPage> list({
    String? q,
    String? category,
    bool verifiedOnly = false,
    String? cursor,
    int? limit,
    /// Phase 1C ontology filters (wire tokens). The backend
    /// `buildSearchWhere` collapses each onto a Prisma where-clause;
    /// omitting them is a no-op, so empty / null values are safe.
    String? institutionClass,
    String? institutionType,
    String? domainTag,
  }) async {
    final params = <String, dynamic>{
      if (q != null && q.isNotEmpty) 'q': q,
      if (category != null && category.isNotEmpty) 'category': category,
      if (verifiedOnly) 'verifiedOnly': 'true',
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      if (limit != null) 'limit': limit.toString(),
      if (institutionClass != null && institutionClass.isNotEmpty)
        'class': institutionClass,
      if (institutionType != null && institutionType.isNotEmpty)
        'type': institutionType,
      if (domainTag != null && domainTag.isNotEmpty) 'domainTag': domainTag,
    };

    final res = await _dio.get<dynamic>(
      '/v1/public/institutions',
      queryParameters: params,
    );
    final body = _unwrap(res.data);
    final verified = (body['verified'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PublicInstitutionSummary.fromJson)
        .toList();
    final other = (body['other'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PublicInstitutionSummary.fromJson)
        .toList();
    return PublicInstitutionsPage(
      verified: verified,
      other: other,
      nextCursor: _ns(body['nextCursor']),
    );
  }

  Future<List<String>> listCategories() async {
    final res = await _dio.get<dynamic>('/v1/public/institutions/categories');
    final body = _unwrap(res.data);
    if (body is List) {
      return body.whereType<String>().toList(growable: false);
    }
    // success-envelope may put list under .data
    final data = body['data'];
    if (data is List) return data.whereType<String>().toList(growable: false);
    return const [];
  }

  Future<PublicInstitutionUnitsPage> listUnits(String slug) async {
    final res = await _dio.get<dynamic>('/v1/public/institutions/$slug/units');
    final body = _unwrap(res.data);
    final institution = body['institution'] as Map<String, dynamic>? ?? const {};
    final units = (body['units'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PublicUnit.fromJson)
        .toList();
    return PublicInstitutionUnitsPage(
      institutionId: _s(institution['id']),
      institutionSlug: _s(institution['slug']),
      institutionName: _s(institution['name']),
      institutionLogoUrl: _ns(institution['logoUrl']),
      institutionIsVerified: institution['isVerified'] == true,
      units: units,
    );
  }

  Future<PublicUnitDetail> getUnit(String slug, String unitSlug) async {
    final res = await _dio.get<dynamic>(
      '/v1/public/institutions/$slug/units/$unitSlug',
    );
    final body = _unwrap(res.data);
    final inst = body['institution'] as Map<String, dynamic>? ?? const {};
    final unit = body['unit'] as Map<String, dynamic>? ?? const {};
    return PublicUnitDetail(
      unit: PublicUnit.fromJson(unit),
      institutionId: _s(inst['id']),
      institutionSlug: _s(inst['slug']),
      institutionName: _s(inst['name']),
      institutionLogoUrl: _ns(inst['logoUrl']),
      institutionTagline: _ns(inst['tagline']),
      institutionDescription: _ns(inst['description']),
      institutionIsVerified: inst['isVerified'] == true,
    );
  }
}

// Backend uses ResponseWrapInterceptor → `{ ok: true, data: ... }`.
// Some endpoints (older paths) return the payload directly. Tolerate both.
dynamic _unwrap(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    if (raw['data'] is Map<String, dynamic> || raw['data'] is List) {
      return raw['data'];
    }
    return raw;
  }
  return raw;
}

String _s(dynamic v) => v == null ? '' : v.toString();
String? _ns(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}
int _i(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

final publicInstitutionsRepositoryProvider =
    Provider<PublicInstitutionsRepository>((ref) {
  return PublicInstitutionsRepository(ref.watch(dioProvider));
});

final publicInstitutionCategoriesProvider =
    FutureProvider<List<String>>((ref) async {
  final repo = ref.watch(publicInstitutionsRepositoryProvider);
  return repo.listCategories();
});

class PublicInstitutionsQuery {
  const PublicInstitutionsQuery({
    this.q = '',
    this.category,
    this.verifiedOnly = false,
    this.institutionClass,
    this.institutionType,
    this.domainTag,
  });
  final String q;
  final String? category;
  final bool verifiedOnly;

  /// Phase 1C — curated Level-1 class wire token. Null = no class filter.
  final String? institutionClass;

  /// Phase 1C — curated Level-2 type wire token. Should belong to the
  /// `institutionClass` when both are set; the backend doesn't enforce
  /// that on the read path (it would just produce zero results).
  final String? institutionType;

  /// Phase 1C — Level-3 domain-tag wire token. Filter is single-tag for
  /// now; multi-tag is a follow-up.
  final String? domainTag;

  @override
  bool operator ==(Object other) =>
      other is PublicInstitutionsQuery &&
      other.q == q &&
      other.category == category &&
      other.verifiedOnly == verifiedOnly &&
      other.institutionClass == institutionClass &&
      other.institutionType == institutionType &&
      other.domainTag == domainTag;

  @override
  int get hashCode => Object.hash(
        q,
        category,
        verifiedOnly,
        institutionClass,
        institutionType,
        domainTag,
      );
}

final publicInstitutionsListProvider = FutureProvider.family<
    PublicInstitutionsPage, PublicInstitutionsQuery>((ref, query) async {
  final repo = ref.watch(publicInstitutionsRepositoryProvider);
  return repo.list(
    q: query.q,
    category: query.category,
    verifiedOnly: query.verifiedOnly,
    institutionClass: query.institutionClass,
    institutionType: query.institutionType,
    domainTag: query.domainTag,
  );
});
