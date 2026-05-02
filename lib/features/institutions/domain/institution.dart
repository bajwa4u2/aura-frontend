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
    );
  }
}