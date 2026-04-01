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
    required this.isActive,
    required this.isLocked,
    required this.waitingRoomEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final RealtimeSurfaceType surfaceType;
  final String? surfaceId;
  final String? startedByUserId;
  final bool isActive;
  final bool isLocked;
  final bool waitingRoomEnabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory RealtimeSession.fromJson(Map<String, dynamic> json) {
    return RealtimeSession(
      id: (json['id'] ?? '').toString(),
      surfaceType: _readSurfaceType(json['surfaceType']),
      surfaceId: _readString(json['surfaceId']),
      startedByUserId: _readString(json['startedByUserId']),
      isActive: _readBool(json['isActive'], fallback: true),
      isLocked: _readBool(json['isLocked']),
      waitingRoomEnabled: _readBool(
        json['waitingRoomEnabled'] ?? json['requiresApproval'],
      ),
      createdAt: _readDate(json['createdAt']),
      updatedAt: _readDate(json['updatedAt']),
    );
  }
}

class RealtimeParticipant {
  const RealtimeParticipant({
    required this.id,
    required this.userId,
    required this.runtimeDeviceId,
    required this.role,
    required this.isPresent,
    required this.audioOn,
    required this.videoOn,
    required this.screenOn,
    required this.joinedAt,
    required this.leftAt,
  });

  final String id;
  final String userId;
  final String? runtimeDeviceId;
  final RealtimeParticipantRole role;
  final bool isPresent;
  final bool audioOn;
  final bool videoOn;
  final bool screenOn;
  final DateTime? joinedAt;
  final DateTime? leftAt;

  bool get isHost => role == RealtimeParticipantRole.host;
  bool get isModerator => role == RealtimeParticipantRole.moderator || isHost;

  RealtimeParticipant copyWith({
    String? id,
    String? userId,
    String? runtimeDeviceId,
    RealtimeParticipantRole? role,
    bool? isPresent,
    bool? audioOn,
    bool? videoOn,
    bool? screenOn,
    DateTime? joinedAt,
    DateTime? leftAt,
  }) {
    return RealtimeParticipant(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      runtimeDeviceId: runtimeDeviceId ?? this.runtimeDeviceId,
      role: role ?? this.role,
      isPresent: isPresent ?? this.isPresent,
      audioOn: audioOn ?? this.audioOn,
      videoOn: videoOn ?? this.videoOn,
      screenOn: screenOn ?? this.screenOn,
      joinedAt: joinedAt ?? this.joinedAt,
      leftAt: leftAt ?? this.leftAt,
    );
  }

  factory RealtimeParticipant.fromJson(Map<String, dynamic> json) {
    final audio = (json['audioState'] ?? '').toString().toUpperCase() == 'ON';
    final video = (json['videoState'] ?? '').toString().toUpperCase() == 'ON';
    final screen = (json['screenState'] ?? '').toString().toUpperCase() == 'ON';

    return RealtimeParticipant(
      id: (json['id'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      runtimeDeviceId: _readString(json['runtimeDeviceId']),
      role: _readRole(json['role']),
      isPresent: _readBool(json['isPresent'], fallback: true),
      audioOn: audio,
      videoOn: video,
      screenOn: screen,
      joinedAt: _readDate(json['joinedAt']),
      leftAt: _readDate(json['leftAt']),
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
          .map(RealtimeParticipant.fromJson)
          .toList(),
      policy: json['policy'] == null ? null : RealtimePolicy.fromJson(_asMap(json['policy'])),
      consents: _asList(consentsRaw).map(RealtimeConsent.fromJson).toList(),
      recordings: _asList(recordingsRaw).map(RealtimeRecording.fromJson).toList(),
      transcriptJobs: _asList(transcriptsRaw).map(RealtimeTranscriptJob.fromJson).toList(),
      artifacts: _asList(artifactsRaw).map(RealtimeArtifact.fromJson).toList(),
    );
  }
}
