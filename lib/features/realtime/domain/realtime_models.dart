import 'call_state.dart';
import 'realtime_enums.dart';
import '../../../core/identity/person_identity_model.dart';

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
    case 'conversation':
      return RealtimeSurfaceType.conversation;
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
    case 'observer':
    case 'listener':
      return RealtimeParticipantRole.observer;
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

/// Minimal per-participant truth carried on a session list row — just
/// enough for a consumer to answer "was I ever actually IN this session,
/// and am I still?" without a second fetch. Parsed from the same
/// `participants` array `activeParticipantCount` already reads.
class RealtimeSessionParticipantSummary {
  const RealtimeSessionParticipantSummary({
    required this.userId,
    required this.joinState,
    required this.joinedAt,
  });

  final String userId;

  /// Server joinState, uppercased: ACTIVE / JOINING / DISCONNECTED / LEFT…
  final String joinState;

  /// Null when this participant never completed a join (invited only).
  final DateTime? joinedAt;
}

class RealtimeSession {
  const RealtimeSession({
    required this.id,
    required this.surfaceType,
    required this.surfaceId,
    required this.startedByUserId,
    required this.status,
    required this.kind,
    this.accessMode = '',
    this.routingMode = '',
    this.liveState = '',
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
    this.participantSummaries = const [],
    this.title,
    this.metadataJson,
    this.call,
  });

  final String id;
  final RealtimeSurfaceType surfaceType;
  final String? surfaceId;
  final String? startedByUserId;
  final String status;
  final String kind;

  /// Server RealtimeAccessMode, uppercased ('' when absent) —
  /// participation policy ("who may enter, what may they do").
  final String accessMode;

  /// SERVER-AUTHORITATIVE TRANSPORT DECISION, uppercased ('' when absent).
  ///
  /// Founder ruling, client migration §2: no screen, caller, route or local
  /// flag may choose mesh vs SFU. The topology owner decides, records it here,
  /// and the client obeys — which is also what keeps the server's reported
  /// topology and the transport actually in use from drifting apart.
  ///
  /// 'SFU' means the stage media path. Anything else, including absent, means
  /// the legacy mesh: a migration is switched on deliberately, never by a
  /// missing field.
  final String routingMode;

  bool get usesStageTransport => routingMode == 'SFU';

  /// FD-5 Live lifecycle truth, uppercased ('' when absent): NORMAL /
  /// LIVE_PREPARING / LIVE / ENDING. Deliberately distinct from
  /// accessMode — never collapsed.
  final String liveState;

  bool get isLive => liveState == 'LIVE';

  /// TERMINAL — this session is over.
  ///
  /// The server defines exactly one rule for this, in
  /// `RealtimeSessionService.decorateSession`:
  ///
  ///     isActive = status not in {ENDED, CANCELLED, FAILED}
  ///
  /// so "ended" is a statement about the lifecycle STATUS, never about whether
  /// anyone happens to be connected right now. This getter names that question
  /// instead of leaving every call site to spell out `isActive == false` and
  /// silently mean something slightly different — which is how "has not
  /// started yet" and "is over" come to be read as the same thing.
  ///
  /// Deliberately identical to `!isActive`, not stricter: the client must not
  /// invent a second definition of ended that the server does not share.
  bool get hasEnded =>
      status == 'ENDED' || status == 'CANCELLED' || status == 'FAILED';

  /// The server's own answer to [hasEnded], inverted. Kept because it is what
  /// the payload carries; prefer [hasEnded] when the question being asked is
  /// "is this call over".
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

  /// Per-participant join truth from the same `participants` payload;
  /// empty when the API response carried no participants array.
  final List<RealtimeSessionParticipantSummary> participantSummaries;
  final String? title;
  final Map<String, dynamic>? metadataJson;

  /// THE CALL THIS ROOM CARRIES, or null when the session is not a call.
  ///
  /// The session is infrastructure — a room, a transport, a roster. This is the
  /// human conversation happening inside it, and it is the only thing a surface
  /// should read to answer "is it ringing", "has it connected", "how long has
  /// it been going". Null means there is no call here (a meeting, a stage),
  /// which is a different fact from a call that has not connected yet.
  final CallState? call;

  /// Replace only the call, keeping every other fact about the room intact.
  ///
  /// Deliberately narrow rather than a general `copyWith`: the session is
  /// server truth, and the one part of it a client legitimately advances on
  /// its own is the call phase it was just told about.
  RealtimeSession withCall(CallState? next) => RealtimeSession(
        id: id,
        surfaceType: surfaceType,
        surfaceId: surfaceId,
        startedByUserId: startedByUserId,
        status: status,
        kind: kind,
        accessMode: accessMode,
        routingMode: routingMode,
        liveState: liveState,
        isActive: isActive,
        isLocked: isLocked,
        waitingRoomEnabled: waitingRoomEnabled,
        startedAt: startedAt,
        answeredAt: answeredAt,
        firstJoinedAt: firstJoinedAt,
        endedAt: endedAt,
        durationSeconds: durationSeconds,
        createdAt: createdAt,
        updatedAt: updatedAt,
        activeParticipantCount: activeParticipantCount,
        participantSummaries: participantSummaries,
        title: title,
        metadataJson: metadataJson,
        call: next,
      );

  /// This user's own participant row, or null when the user is not on the
  /// roster (or the payload had no participants array).
  RealtimeSessionParticipantSummary? participantOf(String userId) {
    final id = userId.trim();
    if (id.isEmpty) return null;
    for (final p in participantSummaries) {
      if (p.userId == id) return p;
    }
    return null;
  }

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
    final summaries = <RealtimeSessionParticipantSummary>[];
    if (rawParts is List) {
      for (final p in rawParts) {
        if (p is Map) {
          final js = (p['joinState'] ?? '').toString().toUpperCase();
          if (js == 'ACTIVE' || js == 'JOINING') activeParts++;
          final uid = (p['userId'] ?? '').toString().trim();
          if (uid.isNotEmpty) {
            summaries.add(
              RealtimeSessionParticipantSummary(
                userId: uid,
                joinState: js,
                joinedAt: _readDate(p['joinedAt']),
              ),
            );
          }
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
      accessMode: (json['accessMode'] ?? '').toString().trim().toUpperCase(),
      routingMode: (json['routingMode'] ?? '').toString().trim().toUpperCase(),
      liveState: (json['liveState'] ?? '').toString().trim().toUpperCase(),
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
      participantSummaries: summaries,
      title: _readString(json['title']),
      metadataJson: meta,
      call: CallState.fromJson(json['call']),
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
    // F116 - the PERSON half of a participant is read by the one canonical
    // reader. What stays here is payload FLATTENING, not identity
    // interpretation: realtime delivers a participant either flattened or
    // wrapped in a `user` envelope, sometimes half of each, so the two are
    // merged into a single person payload with the flattened value winning -
    // the same precedence this code used to hand-write field by field. Which
    // field names count, which aliases are accepted and what happens when a
    // name is missing are the canonical reader's decisions, not this model's.
    final person = AuraPersonIdentity.fromJson(_mergePersonPayload(normalized, user));
    final displayName = _emptyToNull(person.displayName);
    final handle = _emptyToNull(person.handle);
    final avatarUrl = person.avatarUrl;
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

/// Realtime participant payloads arrive flattened, or nested under `user`, or
/// partly both. This produces ONE person payload for the canonical reader,
/// with the flattened value preferred. It deliberately decides nothing about
/// which fields name a person or what to do when they are absent.
Map<String, dynamic> _mergePersonPayload(
  Map<String, dynamic> flattened,
  Map<String, dynamic> nested,
) {
  final merged = Map<String, dynamic>.from(nested);
  flattened.forEach((key, value) {
    if (value == null) return;
    if (value is String && value.trim().isEmpty) return;
    merged[key] = value;
  });
  return merged;
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
