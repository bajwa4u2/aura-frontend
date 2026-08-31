/// INTEGRITY, AS DATA.
///
/// Four authorities — moderation, media appeals, product feedback and support
/// — reached through four different clients that never met. This is not a
/// fifth authority: it is the reading side of the four, in one place, so a
/// detail destination can exist for each without a new administration universe
/// growing around it.
///
/// WHAT IS DELIBERATELY ABSENT: any merging. A moderation report and a support
/// case are not two shapes of the same thing, and nothing here pretends they
/// are. Only the fact that an operator meets them in one console is shared.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import '../../support/providers.dart';
import 'admin_providers.dart';
import 'admin_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODERATION
// ─────────────────────────────────────────────────────────────────────────────

final moderationReportProvider = FutureProvider.autoDispose
    .family<ModerationReport, String>((ref, reportId) async {
  return ref.watch(adminRepositoryProvider).fetchModerationReport(reportId);
});

// ─────────────────────────────────────────────────────────────────────────────
// MEDIA APPEALS
// ─────────────────────────────────────────────────────────────────────────────

/// ONE appeal, found in the queue the authority publishes.
///
/// There is no single-appeal endpoint. Rather than invent one on this side or
/// pretend an id is unreachable, the queue is read and the appeal picked out
/// of it — and when it is not there, that is reported as the real answer it
/// is: an appeal that has already been decided leaves the queue.
final mediaAppealProvider = FutureProvider.autoDispose
    .family<MediaAppealSummary?, String>((ref, appealId) async {
  final appeals = await ref.watch(adminRepositoryProvider).fetchMediaAppeals();
  for (final appeal in appeals) {
    if (appeal.id == appealId) return appeal;
  }
  return null;
});

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT FEEDBACK
// ─────────────────────────────────────────────────────────────────────────────

/// What somebody told us about the product, and what came of it.
class OperatorFeedback {
  const OperatorFeedback({
    required this.id,
    required this.ref,
    required this.intent,
    required this.state,
    required this.message,
    required this.product,
    required this.platform,
    required this.submittedAt,
    this.authorLabel,
    this.appVersion,
    this.surface,
    this.releaseChannel,
    this.operatorNote,
    this.outcome,
    this.releaseRef,
    this.reviewedByLabel,
    this.reviewedAt,
    this.closedAt,
  });

  final String id;

  /// Short and human-quotable — a tester can say "AF-7QK2" out loud, which is
  /// why it is what the console leads with rather than the cuid.
  final String ref;

  final String intent;
  final String state;

  /// UNTRUSTED. Rendered as text and never as markup.
  final String message;

  final String product;
  final String platform;
  final DateTime submittedAt;

  /// Null when the account was deleted. The finding survives the person, and
  /// the console says so rather than showing an empty name.
  final String? authorLabel;

  final String? appVersion;

  /// A route PATTERN, never a populated path.
  final String? surface;

  final String? releaseChannel;

  /// Operator-only. Never shown to the person who submitted.
  final String? operatorNote;

  /// What was actually done. This IS shown to them.
  final String? outcome;

  /// Where it shipped. The difference between "we noted it" and a loop that
  /// closes.
  final String? releaseRef;

  final String? reviewedByLabel;
  final DateTime? reviewedAt;
  final DateTime? closedAt;

  /// The states this one may move to, from the authority's own transition
  /// table. Held here so the console offers only real moves — the server
  /// refuses the rest with a conflict, and discovering that after an operator
  /// has written their reasoning is discovering it too late.
  static const _transitions = <String, List<String>>{
    'RECEIVED': ['REVIEWED', 'CLOSED'],
    'REVIEWED': ['ACTIONED', 'CLOSED'],
    'ACTIONED': ['CLOSED'],
    'CLOSED': <String>[],
  };

  List<String> get availableStates =>
      _transitions[state.toUpperCase()] ?? const <String>[];

  bool get isOpen => availableStates.isNotEmpty;

  /// WHAT IS OWED, in the operator's words.
  ///
  /// The founder marked a feedback read and reported that it "still appears
  /// unread". It did not: the state moved to REVIEWED and persisted. But
  /// REVIEWED is still OPEN WORK, so the item stayed in the queue looking
  /// exactly as it had, and nothing on screen distinguished "nobody has read
  /// this" from "read, and nothing has been done about it yet".
  ///
  /// Those are different obligations, so they are different sentences.
  String get owed => switch (state.toUpperCase()) {
        'RECEIVED' => 'Nobody has read this yet',
        'REVIEWED' => 'Read. Nothing has been done about it yet',
        'ACTIONED' => 'Something was done, and the person was told',
        'CLOSED' => 'Closed. Nothing further is owed',
        _ => state,
      };

  /// Whether the person who submitted this has been told anything.
  ///
  /// The authority notifies on ACTIONED and CLOSED only — deliberately, since
  /// "somebody read it" is not news. So this is the honest answer to "has
  /// anyone replied to them?", which is what the operator actually wants.
  bool get submitterHeardBack =>
      state.toUpperCase() == 'ACTIONED' || state.toUpperCase() == 'CLOSED';

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static String? _opt(dynamic v) {
    final s = _s(v);
    return s.isEmpty ? null : s;
  }

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString().trim());

  static String? _personLabel(dynamic person) {
    if (person is! Map) return null;
    final name = _s(person['displayName']);
    if (name.isNotEmpty) return name;
    final handle = _s(person['handle']);
    return handle.isEmpty ? null : '@$handle';
  }

  factory OperatorFeedback.fromJson(Map<String, dynamic> json) {
    return OperatorFeedback(
      id: _s(json['id']),
      ref: _s(json['ref']),
      intent: _s(json['intent']),
      state: _s(json['state']).isEmpty ? 'RECEIVED' : _s(json['state']),
      message: _s(json['message']),
      product: _s(json['product']),
      platform: _s(json['platform']),
      submittedAt: _date(json['submittedAt']) ?? DateTime.now(),
      authorLabel: _personLabel(json['user']),
      appVersion: _opt(json['appVersion']),
      surface: _opt(json['surface']),
      releaseChannel: _opt(json['releaseChannel']),
      operatorNote: _opt(json['operatorNote']),
      outcome: _opt(json['outcome']),
      releaseRef: _opt(json['releaseRef']),
      reviewedByLabel: _personLabel(json['reviewedBy']),
      reviewedAt: _date(json['reviewedAt']),
      closedAt: _date(json['closedAt']),
    );
  }
}

class OperatorFeedbackRepository {
  const OperatorFeedbackRepository(this._dio);

  final Dio _dio;

  static dynamic _body(dynamic raw) =>
      raw is Map && raw['data'] != null ? raw['data'] : raw;

  Future<List<OperatorFeedback>> queue({String? state}) async {
    final res = await _dio.get(
      '/admin/feedback',
      queryParameters: {
        if (state != null && state.isNotEmpty) 'state': state,
      },
    );
    final body = _body(res.data);
    if (body is! List) return const [];
    return body
        .whereType<Map>()
        .map((e) => OperatorFeedback.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<OperatorFeedback> one(String id) async {
    final res = await _dio.get('/admin/feedback/$id');
    final body = _body(res.data);
    return OperatorFeedback.fromJson(
      body is Map ? Map<String, dynamic>.from(body) : const {},
    );
  }

  /// An INTERNAL note. Never shown to the person, never notified, and it
  /// moves nothing — writing a note is not progress on the feedback and must
  /// not look like progress in the queue.
  Future<void> note(String id, String note) async {
    await _dio.post('/admin/feedback/$id/note', data: {'note': note});
  }

  /// Move it along, and record why.
  ///
  /// The authority refuses ACTIONED without an outcome — "ACTIONED without an
  /// outcome is not an action" — so the console asks for one before it calls.
  Future<void> triage(
    String id, {
    required String state,
    String? outcome,
    String? operatorNote,
    String? releaseRef,
  }) async {
    await _dio.post('/admin/feedback/$id/triage', data: {
      'state': state,
      if (outcome != null && outcome.isNotEmpty) 'outcome': outcome,
      if (operatorNote != null && operatorNote.isNotEmpty)
        'operatorNote': operatorNote,
      if (releaseRef != null && releaseRef.isNotEmpty) 'releaseRef': releaseRef,
    });
  }
}

final operatorFeedbackRepositoryProvider =
    Provider<OperatorFeedbackRepository>((ref) {
  return OperatorFeedbackRepository(ref.watch(dioProvider));
});

final operatorFeedbackProvider = FutureProvider.autoDispose
    .family<OperatorFeedback, String>((ref, id) async {
  return ref.watch(operatorFeedbackRepositoryProvider).one(id);
});

// ─────────────────────────────────────────────────────────────────────────────
// SUPPORT
// ─────────────────────────────────────────────────────────────────────────────

/// One support case, as the admin endpoint returns it.
///
/// Returned as a map by the support repository, which is what it has always
/// been. Modelled here rather than left as `dynamic` at the render site: a
/// widget indexing a map is a widget that fails silently when a key is
/// renamed.
class OperatorSupportCase {
  const OperatorSupportCase({
    required this.id,
    required this.ref,
    required this.status,
    required this.category,
    required this.severity,
    required this.messages,
    this.subject,
    this.requesterName,
    this.requesterEmail,
    this.aiSummary,
    this.assignedTo,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ref;
  final String status;
  final String category;
  final String severity;
  final List<OperatorSupportMessage> messages;
  final String? subject;
  final String? requesterName;
  final String? requesterEmail;
  final String? aiSummary;
  final String? assignedTo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Who to call this case's requester. An email address is identifying and is
  /// shown deliberately — support replies to it — but a name is what a person
  /// is called.
  String get requesterLabel {
    final name = requesterName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    final email = requesterEmail?.trim() ?? '';
    return email.isEmpty ? 'Unnamed requester' : email;
  }

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static String? _opt(dynamic v) {
    final s = _s(v);
    return s.isEmpty ? null : s;
  }

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString().trim());

  factory OperatorSupportCase.fromJson(Map<String, dynamic> json) {
    final caseJson = json['case'] is Map
        ? Map<String, dynamic>.from(json['case'] as Map)
        : json;
    final rawMessages = caseJson['messages'] ?? json['messages'];
    final assigned = caseJson['assignedAdmin'];

    return OperatorSupportCase(
      id: _s(caseJson['id']),
      ref: _s(caseJson['ref']),
      status: _s(caseJson['status']).isEmpty ? 'OPEN' : _s(caseJson['status']),
      category: _s(caseJson['category']),
      severity: _s(caseJson['severity']),
      subject: _opt(caseJson['subject']),
      requesterName: _opt(caseJson['requesterName']),
      requesterEmail: _opt(caseJson['requesterEmail']),
      aiSummary: _opt(caseJson['aiSummary']),
      assignedTo: assigned is Map
          ? _opt((assigned)['displayName'] ?? (assigned)['handle'])
          : _opt(caseJson['assignedAdminDisplayName']),
      createdAt: _date(caseJson['createdAt']),
      updatedAt: _date(caseJson['updatedAt']),
      messages: rawMessages is List
          ? rawMessages
              .whereType<Map>()
              .map((e) =>
                  OperatorSupportMessage.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false)
          : const <OperatorSupportMessage>[],
    );
  }
}

/// WHO SAID IT — three voices, not two.
///
/// `SupportMessage.role` carries exactly three values: `user`, `admin` and
/// `assistant`. Flattening the last two into "us" would let Aura's automated
/// reply be read as something a person wrote, which is the one thing a support
/// transcript must never blur.
enum SupportVoice {
  /// The person who asked.
  requester,

  /// A human operator.
  operator,

  /// Aura's automated reply. Named, never disguised as an operator.
  assistant;

  static SupportVoice fromRole(String role) => switch (role.toLowerCase()) {
        'admin' => SupportVoice.operator,
        'assistant' => SupportVoice.assistant,
        _ => SupportVoice.requester,
      };

  bool get isOurs => this != SupportVoice.requester;
}

class OperatorSupportMessage {
  const OperatorSupportMessage({
    required this.id,
    required this.content,
    required this.voice,
    this.authorLabel,
    this.createdAt,
  });

  final String id;
  final String content;

  /// Which side said it. A transcript where every voice looks alike is a
  /// transcript nobody can read.
  final SupportVoice voice;

  final String? authorLabel;
  final DateTime? createdAt;

  factory OperatorSupportMessage.fromJson(Map<String, dynamic> json) {
    String s(dynamic v) => (v ?? '').toString().trim();
    return OperatorSupportMessage(
      id: s(json['id']),
      content: s(json['content']),
      voice: SupportVoice.fromRole(s(json['role'])),
      authorLabel: s(json['authorName']).isEmpty ? null : s(json['authorName']),
      createdAt: DateTime.tryParse(s(json['createdAt'])),
    );
  }
}

final operatorSupportCaseProvider = FutureProvider.autoDispose
    .family<OperatorSupportCase, String>((ref, caseId) async {
  final raw = await ref.watch(supportRepositoryProvider).adminGetCase(caseId);
  return OperatorSupportCase.fromJson(raw);
});
