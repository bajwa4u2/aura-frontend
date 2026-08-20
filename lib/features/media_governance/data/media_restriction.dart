/// CH-12 — the member's view of a restricted attachment.
///
/// Every field here is answered by the server. The client renders what it is
/// told and decides nothing: whether an appeal is offered, whether the caller
/// has standing, and what the restriction says are all authority questions, and
/// a client that answered them would be answering them somewhere the server
/// cannot enforce.
///
/// A caller without standing receives exactly the same shape as a caller
/// looking at an unrestricted object, so this model has nothing to leak.
class MediaRestriction {
  const MediaRestriction({
    required this.restricted,
    required this.hasStanding,
    required this.canAppeal,
    this.standingBasis,
    this.notice,
    this.appeal,
  });

  /// Delivery is currently stopped for this object.
  final bool restricted;

  /// The viewer is the owner, or an authorized actor for the institution that
  /// published it. Never inferred from being able to name the media id.
  final bool hasStanding;

  /// The server is offering an appeal right now. False while one is already
  /// open, and false once the restriction is lifted.
  final bool canAppeal;

  /// OWNER | INSTITUTION_ACTOR. Null without standing.
  final String? standingBasis;

  final QuarantineNotice? notice;
  final MediaAppeal? appeal;

  static MediaRestriction fromJson(Map<String, dynamic> json) {
    final noticeRaw = json['notice'];
    final appealRaw = json['appeal'];
    return MediaRestriction(
      restricted: json['restricted'] == true,
      hasStanding: json['hasStanding'] == true,
      canAppeal: json['canAppeal'] == true,
      standingBasis: json['standingBasis']?.toString(),
      notice: noticeRaw is Map
          ? QuarantineNotice.fromJson(Map<String, dynamic>.from(noticeRaw))
          : null,
      appeal: appealRaw is Map
          ? MediaAppeal.fromJson(Map<String, dynamic>.from(appealRaw))
          : null,
    );
  }

  /// Nothing to show at all — no standing, or no restriction and no history.
  bool get isEmpty => !restricted && appeal == null;
}

/// The eight governed notice elements, as the server composed them.
///
/// Deliberately holds no copy of its own beyond what the server sent. The
/// wording of a restriction is a governed decision, not a client string.
class QuarantineNotice {
  const QuarantineNotice({
    required this.mediaId,
    required this.useRestricted,
    required this.category,
    required this.automatedVerdict,
    required this.context,
    required this.disposition,
    required this.appealAvailable,
    this.fileName,
    this.mimeType,
    this.appealStatus,
  });

  final String mediaId;
  final String? fileName;
  final String? mimeType;

  /// Always true — the notice exists because use is restricted.
  final bool useRestricted;

  /// MALICIOUS_CONTENT | EXECUTABLE_CONTENT | UNSAFE_STRUCTURE | POLICY_ACTION.
  final String category;

  /// True when an examiner produced the verdict and no person reviewed it.
  final bool automatedVerdict;

  /// Understandable, non-sensitive explanation. Never a signature or a scanner.
  final String context;

  /// PRELIMINARY until a human decides. FINAL afterwards.
  final String disposition;

  final bool appealAvailable;
  final String? appealStatus;

  static QuarantineNotice fromJson(Map<String, dynamic> json) {
    final subject = json['subject'] is Map
        ? Map<String, dynamic>.from(json['subject'] as Map)
        : const <String, dynamic>{};
    final appeal = json['appeal'] is Map
        ? Map<String, dynamic>.from(json['appeal'] as Map)
        : const <String, dynamic>{};
    return QuarantineNotice(
      mediaId: subject['mediaId']?.toString() ?? '',
      fileName: subject['fileName']?.toString(),
      mimeType: subject['mimeType']?.toString(),
      useRestricted: json['useRestricted'] == true,
      category: json['category']?.toString() ?? 'UNSAFE_STRUCTURE',
      automatedVerdict: json['automatedVerdict'] == true,
      context: json['context']?.toString() ?? '',
      disposition: json['disposition']?.toString() ?? 'PRELIMINARY',
      appealAvailable: appeal['available'] == true,
      appealStatus: json['appealStatus']?.toString(),
    );
  }

  /// The restriction can still be reversed — nothing here is permanent while a
  /// human has not decided.
  bool get isReversible => disposition != 'FINAL';
}

/// An appeal as the member is entitled to see it.
///
/// Carries the neutral decision summary and never the reviewer's private note —
/// the server's select is what enforces that, and this model has no field for
/// one so a future widening cannot leak through the client.
class MediaAppeal {
  const MediaAppeal({
    required this.id,
    required this.status,
    this.statement,
    this.submittedAt,
    this.decidedAt,
    this.decisionSummary,
  });

  final String id;

  /// SUBMITTED | UNDER_REVIEW | UPHELD | REVERSED | WITHDRAWN.
  final String status;

  final String? statement;
  final DateTime? submittedAt;
  final DateTime? decidedAt;
  final String? decisionSummary;

  static MediaAppeal fromJson(Map<String, dynamic> json) {
    // Parsed, never converted. Timezone is a PRESENTATION concern owned by
    // ProductTime; a data model doing it here is how two surfaces end up
    // showing the same instant differently.
    DateTime? parse(Object? v) => v == null ? null : DateTime.tryParse(v.toString());
    return MediaAppeal(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'SUBMITTED',
      statement: json['statement']?.toString(),
      submittedAt: parse(json['submittedAt']),
      decidedAt: parse(json['decidedAt']),
      decisionSummary: json['decisionSummary']?.toString(),
    );
  }

  bool get isOpen => status == 'SUBMITTED' || status == 'UNDER_REVIEW';
  bool get isDecided => decidedAt != null;
}
