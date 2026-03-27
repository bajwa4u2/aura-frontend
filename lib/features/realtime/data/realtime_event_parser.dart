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
        ? participantsJson.map(RealtimeParticipant.fromJson).toList()
        : state.participants;

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

    if (participants.isNotEmpty) {
      return RealtimeJoinState.joined;
    }
    if (session?.isLocked == true && state.joinState == RealtimeJoinState.locked) {
      return RealtimeJoinState.locked;
    }
    return state.joinState;
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
}
