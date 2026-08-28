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
        ? _oneEntryPerIdentity(
            participantsJson
                .map((json) => _carryForwardIdentity(
                      state.participants,
                      RealtimeParticipant.fromJson(
                          _normalizeParticipantJson(json)),
                    ))
                .toList(),
          )
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

  /// ONE CANONICAL PARTICIPANT IDENTITY RENDERS ONCE.
  ///
  /// Founder-observed live, 2026-08-25: re-joining a call while already in it
  /// produced a THIRD participant — one human rendered twice.
  ///
  /// The single-participant merge below already collapsed by identity. The
  /// full-roster path did not: it mapped the array straight to a list, so any
  /// roster carrying a user more than once — a second transport binding, a
  /// re-join racing the previous teardown — rendered as another person in the
  /// call.
  ///
  /// Aura's design is unambiguous that this is wrong, and this only enforces
  /// what the rest of the system already asserts:
  ///
  ///   * the database holds `@@unique([sessionId, userId])`;
  ///   * `PresenceService` keys presence by `(sessionId, userId)` and holds
  ///     `runtimeDeviceIds` as a Set INSIDE that one record;
  ///   * the gateway disconnects replaced sockets;
  ///   * mid-call device handoff is a TRANSFER authority, not a second seat.
  ///
  /// So a new transport for the same person rebinds an existing seat. It is
  /// never a new human in the room.
  ///
  /// Deliberately NOT collapsed: entries with no canonical `userId` — a guest
  /// has none, and two guests are two people. Those fall back to the
  /// participant row id, and only to the runtime device as a last resort, so
  /// distinct anonymous participants stay distinct.
  static List<RealtimeParticipant> _oneEntryPerIdentity(
    List<RealtimeParticipant> participants,
  ) {
    final byIdentity = <String, int>{};
    final out = <RealtimeParticipant>[];

    for (final participant in participants) {
      final userId = participant.userId.trim();
      final rowId = participant.id.trim();
      final runtime = (participant.runtimeDeviceId ?? '').trim();

      final key = userId.isNotEmpty
          ? 'user:$userId'
          : rowId.isNotEmpty
              ? 'row:$rowId'
              : runtime.isNotEmpty
                  ? 'device:$runtime'
                  : '';

      // Nothing identifies this entry at all — keep it rather than silently
      // merging strangers together.
      if (key.isEmpty) {
        out.add(participant);
        continue;
      }

      final seen = byIdentity[key];
      if (seen == null) {
        byIdentity[key] = out.length;
        out.add(participant);
      } else {
        // Later wins: the newest binding carries the current transport and
        // media state. The seat keeps its original position so the roster
        // does not reshuffle under the people reading it.
        out[seen] = participant;
      }
    }

    return out;
  }

  /// The same rule for a whole-roster payload: match each incoming row to the
  /// entry already held and carry forward what the new row does not carry.
  ///
  /// A roster list is authoritative about WHO IS PRESENT — anybody absent from
  /// it is gone, and nothing here changes that. It is not automatically
  /// authoritative about every field of everybody in it.
  static RealtimeParticipant _carryForwardIdentity(
    List<RealtimeParticipant> current,
    RealtimeParticipant incoming,
  ) {
    final incomingUserId = incoming.userId.trim();
    final incomingRuntime = (incoming.runtimeDeviceId ?? '').trim();
    final incomingId = incoming.id.trim();

    for (final participant in current) {
      final sameId =
          incomingId.isNotEmpty && participant.id.trim() == incomingId;
      final sameUser = incomingUserId.isNotEmpty &&
          participant.userId.trim() == incomingUserId;
      final sameRuntime = incomingRuntime.isNotEmpty &&
          (participant.runtimeDeviceId ?? '').trim() == incomingRuntime;
      if (sameId || sameUser || sameRuntime) {
        return _reconcile(participant, incoming);
      }
    }
    return incoming;
  }

  /// AN UPDATE MAY CHANGE WHAT IT CARRIES. IT MAY NOT ERASE WHAT IT OMITS.
  ///
  /// Roster entries arrive from two kinds of payload. The snapshot names the
  /// canonical `RealtimeSessionParticipant.id`; a live presence event
  /// (`session:participant.joined` and its siblings) carries `userId`,
  /// `socketId` and the media flags it exists to announce, and no row id.
  ///
  /// The merge replaced the whole entry with the incoming one, so the moment a
  /// presence event arrived the participant id was gone. Measured in
  /// production 2026-08-28, in the space of two seconds on the same client:
  ///
  ///     09:50:35.792  roster ids=[none, cmtcj956]
  ///     09:50:37.886  roster ids=[none, none]      dev=YyI9Ua-6
  ///
  /// Everything downstream keys on that id. Cloudflare's bindings resolved,
  /// the client bound both tracks, the renderer was created, held and
  /// decoding — and the call stage looked up `renderersByParticipant[p.id]`
  /// with an empty id and drew one tile. The phone kept its copy of the id and
  /// drew two, which is why the same build behaved differently on each end.
  ///
  /// So live state comes from the event — that is what an event is for — and
  /// identity is preserved when the event does not carry it.
  static RealtimeParticipant _reconcile(
    RealtimeParticipant existing,
    RealtimeParticipant incoming,
  ) {
    String pick(String next, String previous) =>
        next.trim().isNotEmpty ? next : previous;
    String? pickOptional(String? next, String? previous) =>
        (next ?? '').trim().isNotEmpty ? next : previous;

    return RealtimeParticipant(
      // Identity — never erased by an update that did not mention it.
      id: pick(incoming.id, existing.id),
      userId: pick(incoming.userId, existing.userId),
      runtimeDeviceId:
          pickOptional(incoming.runtimeDeviceId, existing.runtimeDeviceId),
      displayName: pickOptional(incoming.displayName, existing.displayName),
      handle: pickOptional(incoming.handle, existing.handle),
      avatarUrl: pickOptional(incoming.avatarUrl, existing.avatarUrl),
      displayRole: pickOptional(incoming.displayRole, existing.displayRole),
      institutionName:
          pickOptional(incoming.institutionName, existing.institutionName),
      institutionHandle:
          pickOptional(incoming.institutionHandle, existing.institutionHandle),
      institutionRole:
          pickOptional(incoming.institutionRole, existing.institutionRole),
      institutionTitle:
          pickOptional(incoming.institutionTitle, existing.institutionTitle),
      joinedAt: incoming.joinedAt ?? existing.joinedAt,
      leftAt: incoming.leftAt ?? existing.leftAt,
      // Live state — the event is the authority, that is why it was sent.
      role: incoming.role,
      joinState: pick(incoming.joinState, existing.joinState),
      isPresent: incoming.isPresent,
      audioOn: incoming.audioOn,
      videoOn: incoming.videoOn,
      screenOn: incoming.screenOn,
    );
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
        out.add(_reconcile(participant, incoming));
        replaced = true;
      } else {
        out.add(participant);
      }
    }

    if (!replaced) {
      // An event with no canonical identity cannot be shown to be a new
      // person, and appending it invented one. Ignore it rather than seat a
      // participant nobody can name.
      final hasIdentity = incoming.userId.trim().isNotEmpty ||
          incoming.id.trim().isNotEmpty ||
          (incoming.runtimeDeviceId ?? '').trim().isNotEmpty;
      if (hasIdentity) out.add(incoming);
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
