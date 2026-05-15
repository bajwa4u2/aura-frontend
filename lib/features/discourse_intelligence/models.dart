// Discourse intelligence DTOs.
//
// Wire shapes for the `/v1/discourse/*` endpoints. Defensive parsers —
// missing fields fall back to safe defaults so an older backend
// shipping a subset of fields never crashes the rail module.

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _asList(dynamic v) {
  if (v is! List) return const <Map<String, dynamic>>[];
  return v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
}

String _s(Map<String, dynamic> m, String key) =>
    (m[key] ?? '').toString().trim();

String? _opt(Map<String, dynamic> m, String key) {
  final v = (m[key] ?? '').toString().trim();
  return v.isEmpty ? null : v;
}

int _i(Map<String, dynamic> m, String key) {
  final v = m[key];
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse((v ?? '').toString().trim()) ?? 0;
}

bool _b(Map<String, dynamic> m, String key) => m[key] == true;

class DiscourseIssue {
  const DiscourseIssue({
    required this.parentPostId,
    required this.preview,
    required this.targetRoute,
    required this.ageInDays,
    required this.lastActivityAt,
    required this.replyCount,
    required this.institutionReplyCount,
    required this.participatingInstitutionIds,
    required this.authorHandle,
    this.publicSpaceSlug,
    this.publicSpaceName,
  });

  final String parentPostId;
  final String preview;
  final String targetRoute;
  final int ageInDays;
  final DateTime? lastActivityAt;
  final int replyCount;
  final int institutionReplyCount;
  final List<String> participatingInstitutionIds;
  final String authorHandle;
  final String? publicSpaceSlug;
  final String? publicSpaceName;

  factory DiscourseIssue.fromJson(Map<String, dynamic> m) {
    final ids = m['participatingInstitutionIds'];
    final idList = ids is List
        ? ids.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : const <String>[];
    return DiscourseIssue(
      parentPostId: _s(m, 'parentPostId'),
      preview: _s(m, 'preview'),
      targetRoute: _s(m, 'targetRoute'),
      ageInDays: _i(m, 'ageInDays'),
      lastActivityAt: DateTime.tryParse(_s(m, 'lastActivityAt')),
      replyCount: _i(m, 'replyCount'),
      institutionReplyCount: _i(m, 'institutionReplyCount'),
      participatingInstitutionIds: idList,
      authorHandle: _s(m, 'authorHandle'),
      publicSpaceSlug: _opt(m, 'publicSpaceSlug'),
      publicSpaceName: _opt(m, 'publicSpaceName'),
    );
  }
}

class DiscourseIssuesPage {
  const DiscourseIssuesPage({required this.items});

  final List<DiscourseIssue> items;

  factory DiscourseIssuesPage.fromJson(dynamic raw) {
    final root = _asMap(raw);
    final container = root['data'] is Map
        ? Map<String, dynamic>.from(root['data'] as Map)
        : root;
    return DiscourseIssuesPage(
      items: _asList(container['items']).map(DiscourseIssue.fromJson).toList(),
    );
  }
}

class AccountabilityRow {
  const AccountabilityRow({
    required this.institutionId,
    required this.institutionName,
    required this.institutionSlug,
    required this.commitments,
    required this.updates,
    required this.resolved,
    this.oldestCommitmentAt,
  });

  final String institutionId;
  final String institutionName;
  final String institutionSlug;
  final int commitments;
  final int updates;
  final int resolved;
  final DateTime? oldestCommitmentAt;

  factory AccountabilityRow.fromJson(Map<String, dynamic> m) {
    final oldest = _opt(m, 'oldestCommitmentAt');
    return AccountabilityRow(
      institutionId: _s(m, 'institutionId'),
      institutionName: _s(m, 'institutionName'),
      institutionSlug: _s(m, 'institutionSlug'),
      commitments: _i(m, 'commitments'),
      updates: _i(m, 'updates'),
      resolved: _i(m, 'resolved'),
      oldestCommitmentAt: oldest == null ? null : DateTime.tryParse(oldest),
    );
  }
}

class AccountabilityTrailPage {
  const AccountabilityTrailPage({required this.items});

  final List<AccountabilityRow> items;

  factory AccountabilityTrailPage.fromJson(dynamic raw) {
    final root = _asMap(raw);
    final container = root['data'] is Map
        ? Map<String, dynamic>.from(root['data'] as Map)
        : root;
    return AccountabilityTrailPage(
      items: _asList(container['items'])
          .map(AccountabilityRow.fromJson)
          .toList(),
    );
  }
}

class InstitutionParticipationRow {
  const InstitutionParticipationRow({
    required this.institutionId,
    required this.institutionName,
    required this.institutionSlug,
    required this.responseCount,
    required this.lastRespondedAt,
    required this.verified,
  });

  final String institutionId;
  final String institutionName;
  final String institutionSlug;
  final int responseCount;
  final DateTime? lastRespondedAt;
  final bool verified;

  factory InstitutionParticipationRow.fromJson(Map<String, dynamic> m) {
    return InstitutionParticipationRow(
      institutionId: _s(m, 'institutionId'),
      institutionName: _s(m, 'institutionName'),
      institutionSlug: _s(m, 'institutionSlug'),
      responseCount: _i(m, 'responseCount'),
      lastRespondedAt: DateTime.tryParse(_s(m, 'lastRespondedAt')),
      verified: _b(m, 'verified'),
    );
  }
}

class InstitutionParticipationPage {
  const InstitutionParticipationPage({required this.items});

  final List<InstitutionParticipationRow> items;

  factory InstitutionParticipationPage.fromJson(dynamic raw) {
    final root = _asMap(raw);
    final container = root['data'] is Map
        ? Map<String, dynamic>.from(root['data'] as Map)
        : root;
    return InstitutionParticipationPage(
      items: _asList(container['items'])
          .map(InstitutionParticipationRow.fromJson)
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//   /v1/discourse/unanswered-questions
// ─────────────────────────────────────────────────────────────────────

class UnansweredQuestion {
  const UnansweredQuestion({
    required this.parentPostId,
    required this.preview,
    required this.targetRoute,
    required this.authorHandle,
    required this.ageInDays,
    required this.waitingHours,
    required this.replyCount,
    required this.responseExists,
    required this.linkageSource,
    this.publicSpaceSlug,
    this.publicSpaceName,
  });

  final String parentPostId;
  final String preview;
  final String targetRoute;
  final String authorHandle;
  final int ageInDays;
  final int waitingHours;
  final int replyCount;
  final bool responseExists;

  /// Linkage source token — `'public-space'` today; `'mention'` reserved.
  final String linkageSource;

  final String? publicSpaceSlug;
  final String? publicSpaceName;

  factory UnansweredQuestion.fromJson(Map<String, dynamic> m) {
    return UnansweredQuestion(
      parentPostId: _s(m, 'parentPostId'),
      preview: _s(m, 'preview'),
      targetRoute: _s(m, 'targetRoute'),
      authorHandle: _s(m, 'authorHandle'),
      ageInDays: _i(m, 'ageInDays'),
      waitingHours: _i(m, 'waitingHours'),
      replyCount: _i(m, 'replyCount'),
      responseExists: _b(m, 'responseExists'),
      linkageSource: _s(m, 'linkageSource'),
      publicSpaceSlug: _opt(m, 'publicSpaceSlug'),
      publicSpaceName: _opt(m, 'publicSpaceName'),
    );
  }
}

class UnansweredQuestionsPage {
  const UnansweredQuestionsPage({required this.items});

  final List<UnansweredQuestion> items;

  factory UnansweredQuestionsPage.fromJson(dynamic raw) {
    final root = _asMap(raw);
    final container = root['data'] is Map
        ? Map<String, dynamic>.from(root['data'] as Map)
        : root;
    return UnansweredQuestionsPage(
      items: _asList(container['items'])
          .map(UnansweredQuestion.fromJson)
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//   /v1/discourse/responsiveness
// ─────────────────────────────────────────────────────────────────────

class ResponsivenessRow {
  const ResponsivenessRow({
    required this.institutionId,
    required this.institutionName,
    required this.institutionSlug,
    required this.recentResponseCount,
    required this.verified,
    this.institutionClass,
    this.medianResponseHours,
    this.lastRespondedAt,
  });

  final String institutionId;
  final String institutionName;
  final String institutionSlug;
  final String? institutionClass;
  final bool verified;
  final int recentResponseCount;
  final double? medianResponseHours;
  final DateTime? lastRespondedAt;

  factory ResponsivenessRow.fromJson(Map<String, dynamic> m) {
    final raw = m['medianResponseHours'];
    double? median;
    if (raw is num) median = raw.toDouble();
    final last = _opt(m, 'lastRespondedAt');
    return ResponsivenessRow(
      institutionId: _s(m, 'institutionId'),
      institutionName: _s(m, 'institutionName'),
      institutionSlug: _s(m, 'institutionSlug'),
      institutionClass: _opt(m, 'institutionClass'),
      verified: _b(m, 'verified'),
      recentResponseCount: _i(m, 'recentResponseCount'),
      medianResponseHours: median,
      lastRespondedAt: last == null ? null : DateTime.tryParse(last),
    );
  }
}

class ResponsivenessPage {
  const ResponsivenessPage({required this.items});

  final List<ResponsivenessRow> items;

  factory ResponsivenessPage.fromJson(dynamic raw) {
    final root = _asMap(raw);
    final container = root['data'] is Map
        ? Map<String, dynamic>.from(root['data'] as Map)
        : root;
    return ResponsivenessPage(
      items: _asList(container['items'])
          .map(ResponsivenessRow.fromJson)
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//   /v1/discourse/related-institutions
// ─────────────────────────────────────────────────────────────────────

class RelatedInstitutionRow {
  const RelatedInstitutionRow({
    required this.institutionId,
    required this.institutionName,
    required this.institutionSlug,
    required this.sharedParentCount,
    required this.verified,
    this.institutionClass,
  });

  final String institutionId;
  final String institutionName;
  final String institutionSlug;
  final String? institutionClass;
  final bool verified;
  final int sharedParentCount;

  factory RelatedInstitutionRow.fromJson(Map<String, dynamic> m) {
    return RelatedInstitutionRow(
      institutionId: _s(m, 'institutionId'),
      institutionName: _s(m, 'institutionName'),
      institutionSlug: _s(m, 'institutionSlug'),
      institutionClass: _opt(m, 'institutionClass'),
      verified: _b(m, 'verified'),
      sharedParentCount: _i(m, 'sharedParentCount'),
    );
  }
}

class RelatedInstitutionsPage {
  const RelatedInstitutionsPage({required this.items});

  final List<RelatedInstitutionRow> items;

  factory RelatedInstitutionsPage.fromJson(dynamic raw) {
    final root = _asMap(raw);
    final container = root['data'] is Map
        ? Map<String, dynamic>.from(root['data'] as Map)
        : root;
    return RelatedInstitutionsPage(
      items: _asList(container['items'])
          .map(RelatedInstitutionRow.fromJson)
          .toList(),
    );
  }
}
