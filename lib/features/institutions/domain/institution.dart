class InstitutionUnit {
  const InstitutionUnit({
    required this.id,
    required this.institutionId,
    required this.name,
    required this.slug,
    required this.type,
    this.description,
    this.logoUrl,
    this.websiteUrl,
    this.contactEmail,
    this.contactPhone,
    this.address,
    this.city,
    this.region,
    this.country,
    required this.sortOrder,
    required this.isPublic,
    this.archivedAt,
  });

  final String id;
  final String institutionId;
  final String name;
  final String slug;
  final String type;
  final String? description;
  final String? logoUrl;
  final String? websiteUrl;
  final String? contactEmail;
  final String? contactPhone;
  final String? address;
  final String? city;
  final String? region;
  final String? country;
  final int sortOrder;
  final bool isPublic;
  final String? archivedAt;

  bool get isArchived => archivedAt != null && archivedAt!.isNotEmpty;

  String get typeLabel {
    switch (type.toUpperCase()) {
      case 'PRODUCT':
        return 'Product';
      case 'BUSINESS':
        return 'Business';
      case 'BRANCH':
        return 'Branch';
      case 'OFFICE':
        return 'Office';
      case 'DEPARTMENT':
        return 'Department';
      case 'SERVICE':
        return 'Service';
      case 'PROGRAM':
        return 'Program';
      default:
        return 'Unit';
    }
  }

  factory InstitutionUnit.fromJson(Map<String, dynamic> json) {
    String s(String key) => json[key]?.toString().trim() ?? '';
    String? opt(String key) {
      final v = json[key]?.toString().trim();
      return (v != null && v.isNotEmpty) ? v : null;
    }

    return InstitutionUnit(
      id: s('id'),
      institutionId: s('institutionId'),
      name: s('name'),
      slug: s('slug'),
      type: s('type').isEmpty ? 'OTHER' : s('type'),
      description: opt('description'),
      logoUrl: opt('logoUrl'),
      websiteUrl: opt('websiteUrl'),
      contactEmail: opt('contactEmail'),
      contactPhone: opt('contactPhone'),
      address: opt('address'),
      city: opt('city'),
      region: opt('region'),
      country: opt('country'),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isPublic: json['isPublic'] == true || json['isPublic'] == 1,
      archivedAt: opt('archivedAt'),
    );
  }
}

class Institution {
  const Institution({
    required this.id,
    required this.name,
    required this.slug,
    required this.domain,
    required this.jurisdiction,
    required this.description,
    required this.website,
    required this.isVerified,
    this.logoUrl,
    this.coverUrl,
    this.category,
    this.location,
    this.units = const [],
  });

  final String id;
  final String name;
  final String slug;
  final String domain;
  final String jurisdiction;
  final String description;
  final String website;
  final bool isVerified;
  final String? logoUrl;
  final String? coverUrl;
  final String? category;
  final String? location;
  final List<InstitutionUnit> units;

  factory Institution.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      final s = (value ?? '').toString().trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }

    String readString(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value != null) {
          final text = value.toString().trim();
          if (text.isNotEmpty) return text;
        }
      }
      return '';
    }

    String? readOptional(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value != null) {
          final text = value.toString().trim();
          if (text.isNotEmpty) return text;
        }
      }
      return null;
    }

    final rawUnits = json['units'];
    final unitList = rawUnits is List
        ? rawUnits
            .whereType<Map<String, dynamic>>()
            .map(InstitutionUnit.fromJson)
            .toList()
        : <InstitutionUnit>[];

    return Institution(
      id: readString(['id']),
      name: readString(['name', 'displayName', 'title', 'organizationName']),
      slug: readString(['slug', 'handle']),
      domain: readString(['domain']),
      jurisdiction: readString(['jurisdiction', 'country', 'region']),
      description: readString(['description', 'bio', 'summary', 'purpose']),
      website: readString(['website', 'websiteUrl', 'url']),
      isVerified: parseBool(
        json['isVerified'] ?? json['verified'] ?? json['isApproved'],
      ),
      logoUrl: readOptional(['logoUrl', 'avatarUrl', 'logo', 'logoImage']),
      coverUrl: readOptional(['coverUrl', 'bannerUrl', 'cover', 'banner', 'coverImage']),
      category: readOptional(['category', 'type', 'institutionType', 'kind']),
      location: readOptional(['location', 'city', 'address', 'place']),
      units: unitList,
    );
  }

  Institution copyWith({
    String? name,
    String? description,
    String? website,
    String? category,
    String? location,
    String? logoUrl,
    String? coverUrl,
    List<InstitutionUnit>? units,
  }) {
    return Institution(
      id: id,
      name: name ?? this.name,
      slug: slug,
      domain: domain,
      jurisdiction: jurisdiction,
      description: description ?? this.description,
      website: website ?? this.website,
      isVerified: isVerified,
      logoUrl: logoUrl ?? this.logoUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      category: category ?? this.category,
      location: location ?? this.location,
      units: units ?? this.units,
    );
  }
}