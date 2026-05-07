/// Frontend-only metadata for an institution live session.
///
/// The backend `startInstitutionLiveRoom` endpoint does not currently
/// carry session type / audience / title. To avoid blocking the value-
/// layer work on a backend schema change, the picker captures those
/// fields client-side and we cache them here keyed by the session id
/// returned from the start call.
///
/// Cache survives reload (SharedPreferences) so reopening the live rooms
/// list shows the same labels. When metadata is missing — e.g. legacy
/// rooms started before this code shipped, or a different device — the
/// reader falls back to the room's `kind` (AUDIO/VIDEO) and a generic
/// audience.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const String _kPrefix = 'aura.ins.live.session.meta:';

enum InsSessionType {
  internalMeeting,
  publicBriefing,
  classSession,
  research,
  mediaInteraction,
}

extension InsSessionTypeX on InsSessionType {
  String get wire {
    switch (this) {
      case InsSessionType.internalMeeting:
        return 'INTERNAL_MEETING';
      case InsSessionType.publicBriefing:
        return 'PUBLIC_BRIEFING';
      case InsSessionType.classSession:
        return 'CLASS';
      case InsSessionType.research:
        return 'RESEARCH';
      case InsSessionType.mediaInteraction:
        return 'MEDIA_INTERACTION';
    }
  }

  String get label {
    switch (this) {
      case InsSessionType.internalMeeting:
        return 'Internal Meeting';
      case InsSessionType.publicBriefing:
        return 'Public Briefing';
      case InsSessionType.classSession:
        return 'Class';
      case InsSessionType.research:
        return 'Research Session';
      case InsSessionType.mediaInteraction:
        return 'Media Interaction';
    }
  }

  /// Default audience for the type — the picker pre-selects this but the
  /// host can override.
  InsSessionAudience get defaultAudience {
    switch (this) {
      case InsSessionType.publicBriefing:
      case InsSessionType.mediaInteraction:
        return InsSessionAudience.publicAudience;
      case InsSessionType.internalMeeting:
      case InsSessionType.classSession:
      case InsSessionType.research:
        return InsSessionAudience.internal;
    }
  }

  static InsSessionType fromWire(String? raw) {
    switch ((raw ?? '').toUpperCase().trim()) {
      case 'PUBLIC_BRIEFING':
        return InsSessionType.publicBriefing;
      case 'CLASS':
        return InsSessionType.classSession;
      case 'RESEARCH':
        return InsSessionType.research;
      case 'MEDIA_INTERACTION':
        return InsSessionType.mediaInteraction;
      case 'INTERNAL_MEETING':
      default:
        return InsSessionType.internalMeeting;
    }
  }
}

enum InsSessionAudience { internal, publicAudience }

extension InsSessionAudienceX on InsSessionAudience {
  String get wire =>
      this == InsSessionAudience.publicAudience ? 'PUBLIC' : 'INTERNAL';

  String get label =>
      this == InsSessionAudience.publicAudience ? 'Public' : 'Internal';

  static InsSessionAudience fromWire(String? raw) {
    return (raw ?? '').toUpperCase().trim() == 'PUBLIC'
        ? InsSessionAudience.publicAudience
        : InsSessionAudience.internal;
  }
}

class InsSessionMeta {
  const InsSessionMeta({
    required this.type,
    required this.audience,
    this.title,
  });

  final InsSessionType type;
  final InsSessionAudience audience;
  final String? title;

  String get displayTitle {
    final t = (title ?? '').trim();
    if (t.isNotEmpty) return t;
    return type.label;
  }

  Map<String, dynamic> toJson() => {
        'type': type.wire,
        'audience': audience.wire,
        if (title != null && title!.trim().isNotEmpty) 'title': title!.trim(),
      };

  factory InsSessionMeta.fromJson(Map<String, dynamic> j) => InsSessionMeta(
        type: InsSessionTypeX.fromWire(j['type']?.toString()),
        audience: InsSessionAudienceX.fromWire(j['audience']?.toString()),
        title: j['title']?.toString(),
      );
}

class InsSessionMetaCache {
  InsSessionMetaCache._();

  static Future<void> save(String sessionId, InsSessionMeta meta) async {
    final id = sessionId.trim();
    if (id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_kPrefix$id', jsonEncode(meta.toJson()));
  }

  static Future<InsSessionMeta?> read(String sessionId) async {
    final id = sessionId.trim();
    if (id.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_kPrefix$id');
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw);
      if (j is Map) return InsSessionMeta.fromJson(Map<String, dynamic>.from(j));
    } catch (_) {
      // Treat unparseable cache entries as missing — fall back to defaults.
    }
    return null;
  }
}
