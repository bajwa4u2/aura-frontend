import '../../topics/topic.dart';

enum ParticipationMode {
  responding,
  accountable;

  String get wire {
    switch (this) {
      case ParticipationMode.responding:
        return 'RESPONDING';
      case ParticipationMode.accountable:
        return 'ACCOUNTABLE';
    }
  }

  String get label {
    switch (this) {
      case ParticipationMode.responding:
        return 'Responding';
      case ParticipationMode.accountable:
        return 'Accountable';
    }
  }

  String get description {
    switch (this) {
      case ParticipationMode.responding:
        return 'Public posts on this topic are routed to your workspace. '
            'You can respond officially. Activity is not tracked as a public commitment.';
      case ParticipationMode.accountable:
        return 'Public posts on this topic are routed to your workspace. '
            'Your responses, commitments, and resolutions are tracked and visible on your public profile.';
    }
  }

  String get shortDescription {
    switch (this) {
      case ParticipationMode.responding:
        return 'Receives posts · responses not publicly tracked';
      case ParticipationMode.accountable:
        return 'Receives posts · commitments tracked publicly';
    }
  }

  static ParticipationMode? fromWire(dynamic raw) {
    switch ((raw ?? '').toString().trim().toUpperCase()) {
      case 'RESPONDING':
        return ParticipationMode.responding;
      case 'ACCOUNTABLE':
        return ParticipationMode.accountable;
      default:
        return null;
    }
  }
}

enum ParticipationStatus {
  active,
  inactive,
  paused;

  String get wire {
    switch (this) {
      case ParticipationStatus.active:
        return 'ACTIVE';
      case ParticipationStatus.inactive:
        return 'INACTIVE';
      case ParticipationStatus.paused:
        return 'PAUSED';
    }
  }

  String get label {
    switch (this) {
      case ParticipationStatus.active:
        return 'Active';
      case ParticipationStatus.inactive:
        return 'Inactive';
      case ParticipationStatus.paused:
        return 'Paused';
    }
  }

  String get routingNote {
    switch (this) {
      case ParticipationStatus.active:
        return 'Routing active — public posts on this topic reach your workspace.';
      case ParticipationStatus.paused:
        return 'Routing paused — posts are not currently reaching you.';
      case ParticipationStatus.inactive:
        return 'Inactive — not receiving posts on this topic.';
    }
  }

  static ParticipationStatus fromWire(dynamic raw) {
    switch ((raw ?? '').toString().trim().toUpperCase()) {
      case 'ACTIVE':
        return ParticipationStatus.active;
      case 'INACTIVE':
        return ParticipationStatus.inactive;
      case 'PAUSED':
        return ParticipationStatus.paused;
      default:
        return ParticipationStatus.inactive;
    }
  }
}

class InstitutionParticipation {
  const InstitutionParticipation({
    required this.id,
    required this.institutionId,
    required this.topic,
    required this.mode,
    required this.status,
    this.jurisdictionId,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String institutionId;
  final AuraTopic? topic;
  final ParticipationMode mode;
  final ParticipationStatus status;
  final String? jurisdictionId;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static String? _opt(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k]?.toString().trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    return null;
  }

  factory InstitutionParticipation.fromJson(Map<String, dynamic> m) {
    DateTime? readDate(dynamic raw) {
      if (raw == null) return null;
      final s = raw.toString().trim();
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    return InstitutionParticipation(
      id: (m['id'] ?? '').toString(),
      institutionId: (m['institutionId'] ?? '').toString(),
      topic: AuraTopic.fromWire(_opt(m, ['topic'])),
      mode: ParticipationMode.fromWire(m['mode']) ?? ParticipationMode.responding,
      status: ParticipationStatus.fromWire(m['status']),
      jurisdictionId: _opt(m, ['jurisdictionId']),
      notes: _opt(m, ['notes']),
      createdAt: readDate(m['createdAt']),
      updatedAt: readDate(m['updatedAt']),
    );
  }
}
