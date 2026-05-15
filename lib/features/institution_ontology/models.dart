/// Curated Institution Ontology — client-side models.
///
/// Wire shapes for `/v1/institutions/ontology`. The curated taxonomy is
/// owned by the backend (`src/institution-ontology/institution-ontology.ts`)
/// so this file only carries the receive-side types. Defensive parsers —
/// unknown wire tokens are not invented client-side; an institution that
/// carries a class id absent from the current payload is rendered with
/// the raw token as fallback.
library;

class InstitutionClassDef {
  const InstitutionClassDef({
    required this.id,
    required this.label,
    required this.description,
  });

  /// Stable wire token (UPPER_SNAKE_CASE).
  final String id;

  /// Display label (English; multilingual labels future work).
  final String label;

  /// One-sentence description for tooltips / admin UIs.
  final String description;

  factory InstitutionClassDef.fromJson(Map<String, dynamic> m) {
    return InstitutionClassDef(
      id: (m['id'] ?? '').toString().trim(),
      label: (m['label'] ?? '').toString().trim(),
      description: (m['description'] ?? '').toString().trim(),
    );
  }
}

class InstitutionTypeDef {
  const InstitutionTypeDef({
    required this.id,
    required this.classId,
    required this.label,
  });

  /// Stable wire token (UPPER_SNAKE_CASE).
  final String id;

  /// Parent class id this type belongs to.
  final String classId;

  /// Display label.
  final String label;

  factory InstitutionTypeDef.fromJson(Map<String, dynamic> m) {
    return InstitutionTypeDef(
      id: (m['id'] ?? '').toString().trim(),
      classId: (m['classId'] ?? '').toString().trim(),
      label: (m['label'] ?? '').toString().trim(),
    );
  }
}

class InstitutionDomainTagDef {
  const InstitutionDomainTagDef({required this.id, required this.label});

  /// Stable wire token (kebab-case).
  final String id;

  /// Display label.
  final String label;

  factory InstitutionDomainTagDef.fromJson(Map<String, dynamic> m) {
    return InstitutionDomainTagDef(
      id: (m['id'] ?? '').toString().trim(),
      label: (m['label'] ?? '').toString().trim(),
    );
  }
}

class InstitutionOntology {
  const InstitutionOntology({
    required this.classes,
    required this.types,
    required this.domainTags,
    required this.maxDomainTagsPerInstitution,
  });

  final List<InstitutionClassDef> classes;
  final List<InstitutionTypeDef> types;
  final List<InstitutionDomainTagDef> domainTags;
  final int maxDomainTagsPerInstitution;

  /// Resolve a class id to its display label. Returns the raw id when
  /// the token is unknown to this payload (e.g., a newer backend has
  /// added a class and clients haven't refreshed yet).
  String classLabel(String? id) {
    if (id == null || id.isEmpty) return '';
    for (final c in classes) {
      if (c.id == id) return c.label;
    }
    return id;
  }

  /// Resolve a type id to its display label.
  String typeLabel(String? id) {
    if (id == null || id.isEmpty) return '';
    for (final t in types) {
      if (t.id == id) return t.label;
    }
    return id;
  }

  /// Resolve a domain-tag id to its display label.
  String tagLabel(String id) {
    for (final t in domainTags) {
      if (t.id == id) return t.label;
    }
    return id;
  }

  /// Filtered types that belong to the given class.
  List<InstitutionTypeDef> typesForClass(String classId) {
    return types.where((t) => t.classId == classId).toList(growable: false);
  }

  factory InstitutionOntology.fromJson(dynamic raw) {
    final root = raw is Map<String, dynamic>
        ? raw
        : (raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{});
    final container = root['data'] is Map
        ? Map<String, dynamic>.from(root['data'] as Map)
        : root;

    List<T> mapList<T>(
      dynamic v,
      T Function(Map<String, dynamic> m) ctor,
    ) {
      if (v is! List) return const [];
      return v
          .whereType<Map>()
          .map((m) => ctor(Map<String, dynamic>.from(m)))
          .toList(growable: false);
    }

    return InstitutionOntology(
      classes: mapList(container['classes'], InstitutionClassDef.fromJson),
      types: mapList(container['types'], InstitutionTypeDef.fromJson),
      domainTags:
          mapList(container['domainTags'], InstitutionDomainTagDef.fromJson),
      maxDomainTagsPerInstitution:
          (container['maxDomainTagsPerInstitution'] as num?)?.toInt() ?? 8,
    );
  }

  static const empty = InstitutionOntology(
    classes: <InstitutionClassDef>[],
    types: <InstitutionTypeDef>[],
    domainTags: <InstitutionDomainTagDef>[],
    maxDomainTagsPerInstitution: 8,
  );
}
