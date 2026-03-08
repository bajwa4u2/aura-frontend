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
  });

  final String id;
  final String name;
  final String slug;
  final String domain;
  final String jurisdiction;
  final String description;
  final String website;
  final bool isVerified;

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

    return Institution(
      id: readString(['id']),
      name: readString(['name', 'displayName', 'title']),
      slug: readString(['slug', 'handle']),
      domain: readString(['domain']),
      jurisdiction: readString(['jurisdiction', 'country', 'region']),
      description: readString(['description', 'bio', 'summary']),
      website: readString(['website', 'url']),
      isVerified: parseBool(
        json['isVerified'] ?? json['verified'] ?? json['isApproved'],
      ),
    );
  }
}