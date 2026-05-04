import '../domain/realtime_enums.dart';
import '../domain/realtime_models.dart';
import '../domain/realtime_state.dart';

class RealtimeParsedEvent {
  const RealtimeParsedEvent({
    required this.name,
    required this.payload,
  });

  final String name;
  final Map<String, dynamic> payload;
}

class RealtimeEventParser {
  static RealtimeParsedEvent parse(String name, dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return RealtimeParsedEvent(name: name, payload: raw);
    }

    if (raw is Map) {
      return RealtimeParsedEvent(
        name: name,
        payload: Map<String, dynamic>.from(raw),
      );
    }

    return RealtimeParsedEvent(
      name: name,
      payload: <String, dynamic>{'value': raw},
    );
  }

  static RealtimeState mergeSnapshot(
    RealtimeState state,
    Map<String, dynamic> payload,
  ) {
    final sessionJson = _pickMap(payload, const ['session', 'data']);
    final participantsJson = _pickList(payload, const [
      'participants',
      'sessionParticipants',
    ]);
    final policyJson = _pickMap(payload, const ['policy']);
    final consentsJson = _pickList(payload, const ['consents']);
    final recordingsJson = _pickList(payload, const ['recordings']);
    final transcriptsJson = _pickList(payload, const ['transcripts', 'transcriptJobs']);
    final artifactsJson = _pickList(payload, const ['artifacts']);

    final nextSession = sessionJson != null && sessionJson.isNotEmpty
        ? RealtimeSession.fromJson(sessionJson)
        : (_looksLikeSessionPayload(payload) ? RealtimeSession.fromJson(payload) : state.session);

    final nextPolicy = policyJson != null
        ? RealtimePolicy.fromJson(policyJson)
        : (_looksLikePolicyPayload(payload) ? RealtimePolicy.fromJson(payload) : state.policy);

    final nextParticipants = participantsJson != null
        ? participantsJson
            .map((json) => RealtimeParticipant.fromJson(_normalizeParticipantJson(json)))
            .toList()
        : (_looksLikeParticipantPayload(payload)
            ? _mergeSingleParticipant(
                state.participants,
                RealtimeParticipant.fromJson(_normalizeParticipantJson(payload)),
              )
            : state.participants);

    final nextConsents = consentsJson != null
        ? consentsJson.map(RealtimeConsent.fromJson).toList()
        : state.consents;

    final nextRecordings = recordingsJson != null
        ? recordingsJson.map(RealtimeRecording.fromJson).toList()
        : state.recordings;

    final nextTranscripts = transcriptsJson != null
        ? transcriptsJson.map(RealtimeTranscriptJob.fromJson).toList()
        : state.transcripts;

    final nextArtifacts = artifactsJson != null
        ? artifactsJson.map(RealtimeArtifact.fromJson).toList()
        : state.artifacts;

    return state.copyWith(
      sessionId: nextSession?.id ?? state.sessionId,
      session: nextSession,
      participants: nextParticipants,
      policy: nextPolicy,
      consents: nextConsents,
      recordings: nextRecordings,
      transcripts: nextTranscripts,
      artifacts: nextArtifacts,
      joinState: _deriveJoinState(state, nextSession, nextParticipants),
      clearErrorMessage: true,
    );
  }

  static RealtimeJoinState _deriveJoinState(
    RealtimeState state,
    RealtimeSession? session,
    List<RealtimeParticipant> participants,
  ) {
    switch (state.joinState) {
      case RealtimeJoinState.removed:
      case RealtimeJoinState.rejected:
      case RealtimeJoinState.banned:
        return state.joinState;
      default:
        break;
    }

    // Promote to `joined` ONLY when the local user has explicitly initiated
    // join (state already moved to `joining` via join()/resume()) AND the
    // participant snapshot shows quorum. For idle/requested/etc., preserve
    // the existing state — a remote participant arriving in the snapshot
    // (e.g. the caller's join firing `session:participant.joined` on the
    // receiver's correspondence socket) must never silently flip an unaccepted
    // invitee into "joined" and cause the PiP/floating widget to take over
    // the incoming-call surface.
    if (state.joinState == RealtimeJoinState.joining) {
      if (participants.length < 2) {
        return RealtimeJoinState.joining;
      }
      return RealtimeJoinState.joined;
    }
    if (session?.isLocked == true && state.joinState == RealtimeJoinState.locked) {
      return RealtimeJoinState.locked;
    }
    return state.joinState;
  }

  static Map<String, dynamic> _normalizeParticipantJson(Map<String, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);

    final socketId = _readString(map, const ['socketId', 'fromSocketId']);
    final runtimeDeviceId = _readString(map, const ['runtimeDeviceId']);
    final userId = _readString(map, const ['userId']);

    if (socketId.isNotEmpty) {
      map['socketId'] = socketId;
      map['runtimeDeviceId'] = socketId;
    } else if (runtimeDeviceId.isNotEmpty) {
      map['runtimeDeviceId'] = runtimeDeviceId;
    }

    if (userId.isNotEmpty) {
      map['userId'] = userId;
    }

    return map;
  }

  static List<RealtimeParticipant> _mergeSingleParticipant(
    List<RealtimeParticipant> current,
    RealtimeParticipant incoming,
  ) {
    final out = <RealtimeParticipant>[];
    var replaced = false;

    for (final participant in current) {
      final participantUserId = participant.userId.trim();
      final incomingUserId = incoming.userId.trim();
      final participantRuntime = (participant.runtimeDeviceId ?? '').trim();
      final incomingRuntime = (incoming.runtimeDeviceId ?? '').trim();

      final sameUser = participantUserId.isNotEmpty && participantUserId == incomingUserId;
      final sameRuntime = participantRuntime.isNotEmpty && participantRuntime == incomingRuntime;

      if (sameUser || sameRuntime) {
        out.add(incoming);
        replaced = true;
      } else {
        out.add(participant);
      }
    }

    if (!replaced) {
      out.add(incoming);
    }

    return out;
  }

  static String _readString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = (map[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static Map<String, dynamic>? _pickMap(
    Map<String, dynamic> payload,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = payload[key];
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static List<Map<String, dynamic>>? _pickList(
    Map<String, dynamic> payload,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = payload[key];
      if (value is List) return _asList(value);
    }
    return null;
  }

  static List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }

  static bool _looksLikeSessionPayload(Map<String, dynamic> payload) {
    return payload.containsKey('surfaceType') ||
        payload.containsKey('startedByUserId') ||
        payload.containsKey('isActive') ||
        payload.containsKey('isLocked');
  }

  static bool _looksLikePolicyPayload(Map<String, dynamic> payload) {
    return payload.containsKey('waitingRoomEnabled') ||
        payload.containsKey('requiresApproval') ||
        payload.containsKey('canRecord') ||
        payload.containsKey('canTranscribe') ||
        payload.containsKey('joinRequests') ||
        payload.containsKey('pendingJoinRequests');
  }

  static bool _looksLikeParticipantPayload(Map<String, dynamic> payload) {
    return payload.containsKey('userId') ||
        payload.containsKey('socketId') ||
        payload.containsKey('fromSocketId') ||
        payload.containsKey('runtimeDeviceId') ||
        payload.containsKey('audioState') ||
        payload.containsKey('videoState') ||
        payload.containsKey('screenState');
  }
}
