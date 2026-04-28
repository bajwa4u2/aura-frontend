class SupportMessage {
  final String id;
  final String role; // 'user' | 'assistant' | 'admin'
  final String content;
  final DateTime createdAt;

  const SupportMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> j) => SupportMessage(
        id: j['id'] as String? ?? '',
        role: j['role'] as String? ?? 'assistant',
        content: j['content'] as String? ?? '',
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}

class SupportConversation {
  final String conversationId;
  final String? sessionToken;
  final String? caseRef;
  final List<SupportMessage> messages;

  const SupportConversation({
    required this.conversationId,
    this.sessionToken,
    this.caseRef,
    required this.messages,
  });

  factory SupportConversation.fromJson(Map<String, dynamic> j) {
    final rawMessages = j['messages'] as List<dynamic>? ?? [];
    return SupportConversation(
      conversationId: j['conversationId'] as String? ?? '',
      sessionToken: j['sessionToken'] as String?,
      caseRef: j['caseRef'] as String?,
      messages: rawMessages
          .map((m) => SupportMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SupportEscalateResult {
  final String caseId;
  final String caseRef;
  final String status;
  final bool needsHuman;

  const SupportEscalateResult({
    required this.caseId,
    required this.caseRef,
    required this.status,
    required this.needsHuman,
  });

  factory SupportEscalateResult.fromJson(Map<String, dynamic> j) =>
      SupportEscalateResult(
        caseId: j['caseId'] as String? ?? '',
        caseRef: j['caseRef'] as String? ?? '',
        status: j['status'] as String? ?? 'NEW',
        needsHuman: j['needsHuman'] as bool? ?? true,
      );
}

class SupportCaseSummary {
  final String id;
  final String ref;
  final String source;
  final String category;
  final String severity;
  final String status;
  final String? requesterEmail;
  final String? requesterName;
  final String? aiSummary;
  final String? assignedAdminDisplayName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SupportCaseSummary({
    required this.id,
    required this.ref,
    required this.source,
    required this.category,
    required this.severity,
    required this.status,
    this.requesterEmail,
    this.requesterName,
    this.aiSummary,
    this.assignedAdminDisplayName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupportCaseSummary.fromJson(Map<String, dynamic> j) {
    final admin = j['assignedAdmin'] as Map<String, dynamic>?;
    return SupportCaseSummary(
      id: j['id'] as String? ?? '',
      ref: j['ref'] as String? ?? '',
      source: j['source'] as String? ?? 'PUBLIC',
      category: j['category'] as String? ?? 'OTHER',
      severity: j['severity'] as String? ?? 'MEDIUM',
      status: j['status'] as String? ?? 'NEW',
      requesterEmail: j['requesterEmail'] as String?,
      requesterName: j['requesterName'] as String?,
      aiSummary: j['aiSummary'] as String?,
      assignedAdminDisplayName: admin?['displayName'] as String?,
      createdAt: j['createdAt'] != null
          ? DateTime.tryParse(j['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: j['updatedAt'] != null
          ? DateTime.tryParse(j['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class SupportAdminListResult {
  final List<SupportCaseSummary> cases;
  final int total;
  final int skip;
  final int take;

  const SupportAdminListResult({
    required this.cases,
    required this.total,
    required this.skip,
    required this.take,
  });

  factory SupportAdminListResult.fromJson(Map<String, dynamic> j) {
    final raw = j['cases'] as List<dynamic>? ?? [];
    return SupportAdminListResult(
      cases: raw.map((c) => SupportCaseSummary.fromJson(c as Map<String, dynamic>)).toList(),
      total: j['total'] as int? ?? 0,
      skip: j['skip'] as int? ?? 0,
      take: j['take'] as int? ?? 20,
    );
  }
}
