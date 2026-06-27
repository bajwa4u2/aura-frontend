import 'realtime_enums.dart';

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _asList(dynamic value) {
  if (value is List) {
    return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  return const <Map<String, dynamic>>[];
}

DateTime? _readDate(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text)?.toLocal();
}

bool _readBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase();
  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;
  return fallback;
}

String? _readString(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

int? _readInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.round();
  final text = value.toString().trim();
  return int.tryParse(text);
}

String _readFirstString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = (json[key] ?? '').toString().trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}

Map<String, dynamic> _normalizeParticipantJson(Map<String, dynamic> raw) {
  final json = Map<String, dynamic>.from(raw);

  final socketId = _readFirstString(json, const ['socketId', 'fromSocketId']);
  final runtimeDeviceId = _readFirstString(json, const ['runtimeDeviceId']);
  final participantId = _readFirstString(json, const ['id']);
  final userId = _readFirstString(json, const ['userId']);

  if (socketId.isNotEmpty) {
    json['socketId'] = socketId;
    json['runtimeDeviceId'] = socketId;
  } else if (runtimeDeviceId.isNotEmpty) {
    json['runtimeDeviceId'] = runtimeDeviceId;
  }

  if (participantId.isNotEmpty) {
    json['id'] = participantId;
  }
  if (userId.isNotEmpty) {
    json['userId'] = userId;
  }

  return json;
}

RealtimeSurfaceType _readSurfaceType(dynamic value) {
  switch ((value ?? '').toString().trim().toLowerCase()) {
    case 'dm':
      return RealtimeSurfaceType.dm;
    case 'thread':
      return RealtimeSurfaceType.thread;
    case 'space':
      return RealtimeSurfaceType.space;
    case 'event_room':
    case 'room':
      return RealtimeSurfaceType.room;
    case 'meeting':
      return RealtimeSurfaceType.meeting;
    case 'institution':
    case 'institution_room':
      return RealtimeSurfaceType.institution;
    default:
      return RealtimeSurfaceType.unknown;
  }
}

RealtimeParticipantRole _readRole(dynamic value) {
  switch ((value ?? '').toString().trim().toLowerCase()) {
    case 'host':
      return RealtimeParticipantRole.host;
    case 'moderator':
      return RealtimeParticipantRole.moderator;
    case 'participant':
      return RealtimeParticipantRole.participant;
    case 'guest':
      return RealtimeParticipantRole.guest;
    default:
      return RealtimeParticipantRole.unknown;
  }
}

RealtimeConsentStatus _readConsentStatus(dynamic value) {
  switch ((value ?? '').toString().trim().toLowerCase()) {
    case 'requested':
    case 'pending':
      return RealtimeConsentStatus.pending;
    case 'granted':
      return RealtimeConsentStatus.granted;
    case 'declined':
      return RealtimeConsentStatus.declined;
    default:
      return RealtimeConsentStatus.none;
  }
}

RealtimeRecordingStatus _readRecordingStatus(dynamic value) {
  switch ((value ?? '').toString().trim().toLowerCase()) {
    case 'requested':
      return RealtimeRecordingStatus.requested;
    case 'active':
    case 'recording':
      return RealtimeRecordingStatus.active;
    case 'stopped':
    case 'completed':
      return RealtimeRecordingStatus.stopped;
    case 'failed':
      return RealtimeRecordingStatus.failed;
    default:
      return RealtimeRecordingStatus.idle;
  }
}

RealtimeTranscriptStatus _readTranscriptStatus(dynamic value) {
  switch ((value ?? '').toString().trim().toLowerCase()) {
    case 'requested':
      return RealtimeTranscriptStatus.requested;
    case 'active':
    case 'processing':
      return RealtimeTranscriptStatus.active;
    case 'completed':
      return RealtimeTranscriptStatus.completed;
    case 'failed':
      return RealtimeTranscriptStatus.failed;
    default:
      return RealtimeTranscriptStatus.idle;
  }
}

class RealtimeSession {
  const RealtimeSession({
    required this.id,
    required this.surfaceType,
    required this.surfaceId,
    required this.startedByUserId,
    required this.status,
    required this.kind,
    required this.isActive,
    required this.isLocked,
    required this.waitingRoomEnabled,
    required this.startedAt,
    required this.answeredAt,
    required this.firstJoinedAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.createdAt,
    required this.updatedAt,
    required this.activeParticipantCount,
    this.title,
    this.metadataJson,
  });

  final String id;
  final RealtimeSurfaceType surfaceType;
  final String? surfaceId;
  final String? startedByUserId;
  final String status;
  final String kind;
  final bool isActive;
  final bool isLocked;
  final bool waitingRoomEnabled;
  final DateTime? startedAt;
  final DateTime? answeredAt;
  final DateTime? firstJoinedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  /// Number of participants with joinState ACTIVE or JOINING.
  final int activeParticipantCount;
  final String? title;
  final Map<String, dynamic>? metadataJson;

  String? get contextName {
    final meta = metadataJson ?? {};
    for (final key in const ['contextName', 'spaceName', 'threadTitle', 'roomTitle', 'label']) {
      final v = (meta[key] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    return null;
  }

  factory RealtimeSession.fromJson(Map<String, dynamic> json) {
    final rawMeta = json['metadataJson'] ?? json['metadata'];
    final meta = rawMeta is Map ? Map<String, dynamic>.from(rawMeta) : null;

    final rawParts = json['participants'];
    int activeParts = 0;
    if (rawParts is List) {
      for (final p in rawParts) {
        if (p is Map) {
          final js = (p['joinState'] ?? '').toString().toUpperCase();
          if (js == 'ACTIVE' || js == 'JOINING') activeParts++;
        }
      }
    }

    return RealtimeSession(
      id: (json['id'] ?? '').toString(),
      surfaceType: _readSurfaceType(json['surfaceType']),
      surfaceId: _readString(json['surfaceId']),
      startedByUserId: _readString(json['startedByUserId']),
      status: (json['status'] ?? '').toString().trim().toUpperCase(),
      kind: (json['kind'] ?? '').toString().trim().toUpperCase(),
      isActive: _readBool(
        json['isActive'],
        fallback: (json['status'] ?? '').toString().trim().toUpperCase() != 'ENDED' &&
            (json['status'] ?? '').toString().trim().toUpperCase() != 'CANCELLED' &&
            (json['status'] ?? '').toString().trim().toUpperCase() != 'FAILED',
      ),
      isLocked: _readBool(json['isLocked']),
      waitingRoomEnabled: _readBool(
        json['waitingRoomEnabled'] ?? json['requiresApproval'],
      ),
      startedAt: _readDate(json['startedAt']),
      answeredAt: _readDate(json['answeredAt']),
      firstJoinedAt: _readDate(json['firstJoinedAt']),
      endedAt: _readDate(json['endedAt']),
      durationSeconds: _readInt(json['durationSeconds']),
      createdAt: _readDate(json['createdAt']),
      updatedAt: _readDate(json['updatedAt']),
      activeParticipantCount: activeParts,
      title: _readString(json['title']),
      metadataJson: meta,
    );
  }
}

class RealtimeParticipant {
  const RealtimeParticipant({
    required this.id,
    required this.userId,
    required this.runtimeDeviceId,
    required this.role,
    required this.joinState,
    required this.isPresent,
    required this.audioOn,
    required this.videoOn,
    required this.screenOn,
    required this.displayName,
    required this.handle,
    required this.avatarUrl,
    required this.displayRole,
    required this.institutionName,
    required this.institutionHandle,
    required this.institutionRole,
    required this.institutionTitle,
    required this.joinedAt,
    required this.leftAt,
  });

  final String id;
  final String userId;
  final String? runtimeDeviceId;
  final RealtimeParticipantRole role;
  final String joinState;
  final bool isPresent;
  final bool audioOn;
  final bool videoOn;
  final bool screenOn;
  final String? displayName;
  final String? handle;
  final String? avatarUrl;
  final String? displayRole;
  final String? institutionName;
  final String? institutionHandle;
  final String? institutionRole;
  final String? institutionTitle;
  final DateTime? joinedAt;
  final DateTime? leftAt;

  bool get isHost => role == RealtimeParticipantRole.host;
  bool get isModerator => role == RealtimeParticipantRole.moderator || isHost;
  String get identityLabel {
    final name = displayName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    final handleLabel = handle?.trim() ?? '';
    if (handleLabel.isNotEmpty) return '@$handleLabel';
    return 'Participant';
  }

  String get roleLabel {
    final explicit = (displayRole ?? '').trim();
    if (explicit.isNotEmpty) {
      return explicit
          .replaceAll('_', ' ')
          .split(' ')
          .where((part) => part.isNotEmpty)
          .map((part) => part[0].toUpperCase() + part.substring(1))
          .join(' ');
    }

    switch (role) {
      case RealtimeParticipantRole.host:
        return 'Host';
      case RealtimeParticipantRole.moderator:
        return 'Moderator';
      case RealtimeParticipantRole.participant:
        return 'Participant';
      case RealtimeParticipantRole.guest:
        return 'Guest';
      default:
        return 'Participant';
    }
  }

  RealtimeParticipant copyWith({
    String? id,
    String? userId,
    String? runtimeDeviceId,
    RealtimeParticipantRole? role,
    String? joinState,
    bool? isPresent,
    bool? audioOn,
    bool? videoOn,
    bool? screenOn,
    String? displayName,
    String? handle,
    String? avatarUrl,
    String? displayRole,
    String? institutionName,
    String? institutionHandle,
    String? institutionRole,
    String? institutionTitle,
    DateTime? joinedAt,
    DateTime? leftAt,
  }) {
    return RealtimeParticipant(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      runtimeDeviceId: runtimeDeviceId ?? this.runtimeDeviceId,
      role: role ?? this.role,
      joinState: joinState ?? this.joinState,
      isPresent: isPresent ?? this.isPresent,
      audioOn: audioOn ?? this.audioOn,
      videoOn: videoOn ?? this.videoOn,
      screenOn: screenOn ?? this.screenOn,
      displayName: displayName ?? this.displayName,
      handle: handle ?? this.handle,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      displayRole: displayRole ?? this.displayRole,
      institutionName: institutionName ?? this.institutionName,
      institutionHandle: institutionHandle ?? this.institutionHandle,
      institutionRole: institutionRole ?? this.institutionRole,
      institutionTitle: institutionTitle ?? this.institutionTitle,
      joinedAt: joinedAt ?? this.joinedAt,
      leftAt: leftAt ?? this.leftAt,
    );
  }

  factory RealtimeParticipant.fromJson(Map<String, dynamic> json) {
    final normalized = _normalizeParticipantJson(json);
    final user = _asMap(normalized['user']);
    final institutionAdmin = _asMap(user['adminInstitution']);
    final topLevelInstitutionAdmin = _asMap(normalized['institutionAdmin']);
    final institutionMemberships = _asList(user['institutionMemberships']);
    final firstMembership = institutionMemberships.isEmpty
        ? <String, dynamic>{}
        : _asMap(institutionMemberships.first);
    final audio = (normalized['audioState'] ?? '').toString().toUpperCase() == 'ON';
    final video = (normalized['videoState'] ?? '').toString().toUpperCase() == 'ON';
    final screen = (normalized['screenState'] ?? '').toString().toUpperCase() == 'ON';
    final displayName = _readString(normalized['displayName']) ?? _readString(user['displayName']);
    final handle = _readString(normalized['handle']) ?? _readString(user['handle']);
    final avatarUrl = _readString(normalized['avatarUrl']) ?? _readString(user['avatarUrl']);
    final institutionName = _readString(normalized['institutionName']) ??
        _readString(institutionAdmin['name']) ??
        _readString(topLevelInstitutionAdmin['name']) ??
        _readString(_asMap(firstMembership['institution'])['name']);
    final institutionHandle = _readString(normalized['institutionHandle']) ??
        _readString(institutionAdmin['slug']) ??
        _readString(institutionAdmin['handle']) ??
        _readString(topLevelInstitutionAdmin['slug']) ??
        _readString(topLevelInstitutionAdmin['handle']) ??
        _readString(_asMap(firstMembership['institution'])['slug']) ??
        _readString(_asMap(firstMembership['institution'])['handle']);
    final institutionRole = _readString(normalized['institutionRole']) ??
        _readString(firstMembership['role']);
    final institutionTitle = _readString(normalized['institutionTitle']) ??
        _readString(firstMembership['title']);
    final displayRole = _readString(normalized['displayRole']);

    return RealtimeParticipant(
      id: (normalized['id'] ?? '').toString(),
      userId: (normalized['userId'] ?? '').toString(),
      runtimeDeviceId: _readString(normalized['runtimeDeviceId']),
      role: _readRole(normalized['role']),
      joinState: (normalized['joinState'] ?? '').toString().trim(),
      isPresent: _readBool(normalized['isPresent'], fallback: true),
      audioOn: audio,
      videoOn: video,
      screenOn: screen,
      displayName: displayName,
      handle: handle,
      avatarUrl: avatarUrl,
      displayRole: displayRole,
      institutionName: institutionName,
      institutionHandle: institutionHandle,
      institutionRole: institutionRole,
      institutionTitle: institutionTitle,
      joinedAt: _readDate(normalized['joinedAt']),
      leftAt: _readDate(normalized['leftAt']),
    );
  }
}

class RealtimeJoinRequest {
  const RealtimeJoinRequest({
    required this.userId,
    required this.createdAt,
  });

  final String userId;
  final DateTime? createdAt;

  factory RealtimeJoinRequest.fromJson(Map<String, dynamic> json) {
    return RealtimeJoinRequest(
      userId: (json['userId'] ?? '').toString(),
      createdAt: _readDate(json['createdAt']),
    );
  }
}

class RealtimePolicy {
  const RealtimePolicy({
    required this.waitingRoomEnabled,
    required this.audioAllowed,
    required this.videoAllowed,
    required this.screenAllowed,
    required this.canRecord,
    required this.canTranscribe,
    required this.isLocked,
    required this.joinRequests,
    required this.bannedUserIds,
  });

  final bool waitingRoomEnabled;
  final bool audioAllowed;
  final bool videoAllowed;
  final bool screenAllowed;
  final bool canRecord;
  final bool canTranscribe;
  final bool isLocked;
  final List<RealtimeJoinRequest> joinRequests;
  final List<String> bannedUserIds;

  factory RealtimePolicy.fromJson(Map<String, dynamic> json) {
    final joinRequestsRaw = json['joinRequests'] ?? json['pendingJoinRequests'];
    final joinRequests = _asList(joinRequestsRaw)
        .map(RealtimeJoinRequest.fromJson)
        .toList();

    final bannedRaw = json['bannedUserIds'];
    final banned = bannedRaw is List
        ? bannedRaw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : const <String>[];

    return RealtimePolicy(
      waitingRoomEnabled: _readBool(
        json['waitingRoomEnabled'] ?? json['requiresApproval'],
      ),
      audioAllowed: _readBool(
        json['audioAllowed'] ?? json['allowAudio'] ?? true,
        fallback: true,
      ),
      videoAllowed: _readBool(
        json['videoAllowed'] ?? json['allowVideo'] ?? true,
        fallback: true,
      ),
      screenAllowed: _readBool(
        json['screenAllowed'] ?? json['allowScreenShare'] ?? true,
        fallback: true,
      ),
      canRecord: _readBool(json['canRecord'], fallback: false),
      canTranscribe: _readBool(json['canTranscribe'], fallback: false),
      isLocked: _readBool(json['isLocked']),
      joinRequests: joinRequests,
      bannedUserIds: banned,
    );
  }
}

class RealtimeConsent {
  const RealtimeConsent({
    required this.userId,
    required this.status,
    required this.decidedAt,
  });

  final String userId;
  final RealtimeConsentStatus status;
  final DateTime? decidedAt;

  factory RealtimeConsent.fromJson(Map<String, dynamic> json) {
    return RealtimeConsent(
      userId: (json['userId'] ?? '').toString(),
      status: _readConsentStatus(json['status']),
      decidedAt: _readDate(json['decidedAt']),
    );
  }
}

class RealtimeRecording {
  const RealtimeRecording({
    required this.id,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final RealtimeRecordingStatus status;
  final DateTime? createdAt;

  factory RealtimeRecording.fromJson(Map<String, dynamic> json) {
    return RealtimeRecording(
      id: (json['id'] ?? '').toString(),
      status: _readRecordingStatus(json['status']),
      createdAt: _readDate(json['createdAt']),
    );
  }
}

class RealtimeTranscriptJob {
  const RealtimeTranscriptJob({
    required this.id,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final RealtimeTranscriptStatus status;
  final DateTime? createdAt;

  factory RealtimeTranscriptJob.fromJson(Map<String, dynamic> json) {
    return RealtimeTranscriptJob(
      id: (json['id'] ?? '').toString(),
      status: _readTranscriptStatus(json['status']),
      createdAt: _readDate(json['createdAt']),
    );
  }
}

class RealtimeArtifact {
  const RealtimeArtifact({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.isRetained,
  });

  final String id;
  final String kind;
  final DateTime? createdAt;
  final bool isRetained;

  factory RealtimeArtifact.fromJson(Map<String, dynamic> json) {
    return RealtimeArtifact(
      id: (json['id'] ?? '').toString(),
      kind: (json['kind'] ?? '').toString(),
      createdAt: _readDate(json['createdAt']),
      isRetained: _readBool(json['isRetained']),
    );
  }
}

class RealtimeSessionSnapshot {
  const RealtimeSessionSnapshot({
    required this.session,
    required this.participants,
    required this.policy,
    required this.consents,
    required this.recordings,
    required this.transcriptJobs,
    required this.artifacts,
  });

  final RealtimeSession session;
  final List<RealtimeParticipant> participants;
  final RealtimePolicy? policy;
  final List<RealtimeConsent> consents;
  final List<RealtimeRecording> recordings;
  final List<RealtimeTranscriptJob> transcriptJobs;
  final List<RealtimeArtifact> artifacts;

  factory RealtimeSessionSnapshot.fromJson(Map<String, dynamic> json) {
    final sessionMap = _asMap(
      json['session'].runtimeType == Null ? json : json['session'],
    );

    final participantsRaw = json['participants'] ?? json['sessionParticipants'];
    final consentsRaw = json['consents'];
    final recordingsRaw = json['recordings'];
    final transcriptsRaw = json['transcripts'] ?? json['transcriptJobs'];
    final artifactsRaw = json['artifacts'];

    return RealtimeSessionSnapshot(
      session: RealtimeSession.fromJson(sessionMap),
      participants: _asList(participantsRaw)
          .map((item) => RealtimeParticipant.fromJson(_normalizeParticipantJson(item)))
          .toList(),
      policy: json['policy'] == null ? null : RealtimePolicy.fromJson(_asMap(json['policy'])),
      consents: _asList(consentsRaw).map(RealtimeConsent.fromJson).toList(),
      recordings: _asList(recordingsRaw).map(RealtimeRecording.fromJson).toList(),
      transcriptJobs: _asList(transcriptsRaw).map(RealtimeTranscriptJob.fromJson).toList(),
      artifacts: _asList(artifactsRaw).map(RealtimeArtifact.fromJson).toList(),
    );
  }
}
