import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../data/realtime_event_parser.dart';
import '../data/realtime_media_service.dart';
import '../data/realtime_repository.dart';
import '../data/realtime_socket_service.dart';
import '../domain/realtime_enums.dart';
import '../domain/realtime_models.dart';
import '../domain/realtime_state.dart';

class RealtimeController extends StateNotifier<RealtimeState> {
  RealtimeController(
    this._repository,
    this._socketService,
    this._mediaService,
    this._tokenStore,
  ) : super(RealtimeState.initial()) {
    _subscription = _socketService.events.listen(_handleSocketEvent);
    _mediaSubscription = _mediaService.snapshots.listen(_handleMediaSnapshot);
  }

  final RealtimeRepository _repository;
  final RealtimeSocketService _socketService;
  final RealtimeMediaService _mediaService;
  final TokenStore _tokenStore;

  StreamSubscription<RealtimeParsedEvent>? _subscription;
  StreamSubscription<RealtimeMediaSnapshot>? _mediaSubscription;

  String? _hydratingSessionId;
  String? _joiningSessionId;
  bool _terminating = false;

  Map<String, dynamic>? _rtcConfiguration;
  String? _rtcConfigurationSessionId;

  String get _managedSessionId =>
      (state.sessionId ?? state.session?.id ?? '').trim();

  bool _isSameManagedSession(String sessionId) {
    final trimmed = sessionId.trim();
    return trimmed.isNotEmpty && _managedSessionId == trimmed;
  }

  RealtimeState _copyWithDetachedMediaState({
    required RealtimeJoinState joinState,
    String? infoMessage,
    String? lastSocketEvent,
    RealtimeConnectionStatus? connectionStatus,
    bool clearSessionContext = false,
    bool clearPolicy = false,
    bool clearErrorMessage = false,
  }) {
    return state.copyWith(
      connectionStatus: connectionStatus,
      joinState: joinState,
      clearSessionId: clearSessionContext,
      clearSession: clearSessionContext,
      participants: clearSessionContext
          ? const <RealtimeParticipant>[]
          : state.participants,
      clearPolicy: clearPolicy,
      consents: clearSessionContext ? const <RealtimeConsent>[] : state.consents,
      recordings: clearSessionContext
          ? const <RealtimeRecording>[]
          : state.recordings,
      transcripts: clearSessionContext
          ? const <RealtimeTranscriptJob>[]
          : state.transcripts,
      artifacts: clearSessionContext
          ? const <RealtimeArtifact>[]
          : state.artifacts,
      infoMessage: infoMessage,
      clearErrorMessage: clearErrorMessage,
      clearRemoteRenderers: true,
      clearLocalRenderer: true,
      isMediaReady: false,
      isMediaBusy: false,
      microphoneEnabled: false,
      cameraEnabled: false,
      clearMediaError: true,
      clearIncomingCall: true,
      clearCallMode: true,
      lastSocketEvent: lastSocketEvent,
    );
  }


  Future<void> connect() async {
    if (state.connectionStatus == RealtimeConnectionStatus.connected ||
        state.connectionStatus == RealtimeConnectionStatus.connecting) {
      return;
    }

    state = state.copyWith(
      connectionStatus: RealtimeConnectionStatus.connecting,
      clearErrorMessage: true,
      clearInfoMessage: true,
    );

    try {
      await _tokenStore.load();
      final token = _tokenStore.accessToken?.trim() ?? '';
      if (token.isEmpty) {
        throw StateError('You need to sign in before joining live.');
      }

      await _socketService.connect(accessToken: token);

      state = state.copyWith(
        connectionStatus: RealtimeConnectionStatus.connected,
        infoMessage: 'Live connection ready.',
      );
    } catch (error) {
      state = state.copyWith(
        connectionStatus: RealtimeConnectionStatus.error,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  Future<String> createSession({
    required String surfaceType,
    required String surfaceId,
    required String kind,
    Map<String, dynamic>? metadata,
  }) async {
    state = state.copyWith(
      isBusy: true,
      clearErrorMessage: true,
      clearInfoMessage: true,
    );

    try {
      final bundle = await _repository.createSession(
        surfaceType: surfaceType,
        surfaceId: surfaceId,
        kind: kind,
        metadata: metadata,
      );
      _applyBundle(bundle);
      final normalizedKind = kind.trim().toLowerCase();
      state = state.copyWith(
        isBusy: false,
        sessionId: bundle.session.id,
        joinState: RealtimeJoinState.idle,
        callMode: normalizedKind == 'video' ? 'video' : 'audio',
        infoMessage: 'Live started here.',
      );
      return bundle.session.id;
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }


  bool isManagingSurface({
    required String surfaceType,
    required String surfaceId,
  }) {
    final session = state.session;
    if (session == null) return false;
    final normalizedType = surfaceType.trim().toLowerCase();
    final sessionType = session.surfaceType.name.trim().toLowerCase();
    final targetId = surfaceId.trim();
    final currentId = (session.surfaceId ?? '').trim();
    return normalizedType.isNotEmpty &&
        sessionType == normalizedType &&
        targetId.isNotEmpty &&
        currentId == targetId;
  }

  Future<String> ensureCorrespondenceLive({
    required String surfaceType,
    required String surfaceId,
    required String kind,
    Map<String, dynamic>? metadata,
    bool joinAfterCreate = true,
  }) async {
    final normalizedType = surfaceType.trim().toUpperCase();
    final normalizedId = surfaceId.trim();
    final normalizedKind = kind.trim().toUpperCase();
    if (normalizedType.isEmpty || normalizedId.isEmpty) {
      throw StateError('A conversation, space, or institution context is required before starting live.');
    }

    if (isManagingSurface(surfaceType: normalizedType, surfaceId: normalizedId)) {
      final existingSessionId = _managedSessionId;
      if (existingSessionId.isNotEmpty) {
        if (joinAfterCreate && state.joinState != RealtimeJoinState.joined) {
          await join(existingSessionId);
        }
        return existingSessionId;
      }
    }

    final sessionId = await createSession(
      surfaceType: normalizedType,
      surfaceId: normalizedId,
      kind: normalizedKind,
      metadata: metadata,
    );
    if (joinAfterCreate) {
      await join(sessionId);
    }
    return sessionId;
  }

  Future<void> disconnect() async {
    await _terminateSession(
      keepSocketConnected: false,
      infoMessage: null,
      alsoCallRepository: true,
    );

    state = state.copyWith(
      connectionStatus: RealtimeConnectionStatus.disconnected,
      clearInfoMessage: true,
      lastSocketEvent: 'socket:disconnected',
    );
  }

  Future<void> hydrateSession(String sessionId) async {
    final trimmed = sessionId.trim();
    if (trimmed.isEmpty) return;
    if (_hydratingSessionId == trimmed) return;

    _hydratingSessionId = trimmed;
    state = state.copyWith(
      isBusy: true,
      clearErrorMessage: true,
      sessionId: trimmed,
    );

    try {
      final bundle = await _repository.loadSessionBundle(trimmed);
      _applyBundle(bundle);
      state = state.copyWith(
        isBusy: false,
        infoMessage: state.isJoined ? state.infoMessage : 'Live loaded.',
      );
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: error.toString(),
      );
      rethrow;
    } finally {
      if (_hydratingSessionId == trimmed) {
        _hydratingSessionId = null;
      }
    }
  }

  Future<void> join(String sessionId) async {
    final trimmed = sessionId.trim();
    if (trimmed.isEmpty || _terminating) return;

    final currentSessionId = (state.sessionId ?? state.session?.id ?? '').trim();
    if (_joiningSessionId == trimmed) return;
    if (state.joinState == RealtimeJoinState.joined && _isSameManagedSession(trimmed)) return;
    if (state.joinState == RealtimeJoinState.joining && _isSameManagedSession(trimmed)) return;

    if (currentSessionId.isNotEmpty && currentSessionId != trimmed && state.isJoined) {
      await leave();
    }

    _joiningSessionId = trimmed;
    await connect();
    _clearRtcConfiguration();

    state = state.copyWith(
      joinState: RealtimeJoinState.joining,
      sessionId: trimmed,
      clearErrorMessage: true,
      clearInfoMessage: true,
    );

    try {
      await hydrateSession(trimmed);

      final session = state.session;
      if (session == null) {
        throw StateError('Live session could not be loaded.');
      }

      final joinedBundle = await _repository.joinSession(session);
      _applyBundle(joinedBundle);

      await connect();
      await _socketService.emitAck('session:join', <String, dynamic>{
        'sessionId': trimmed,
      });

      await hydrateSession(trimmed);
      await _ensureMediaReady(trimmed, refreshTurnCredentials: true);

      state = state.copyWith(
        joinState: RealtimeJoinState.joined,
        clearIncomingCall: true,
        infoMessage: 'You joined live.',
      );
    } catch (error) {
      state = state.copyWith(
        joinState: _mapJoinError(error),
        errorMessage: error.toString(),
      );
      rethrow;
    } finally {
      if (_joiningSessionId == trimmed) {
        _joiningSessionId = null;
      }
    }
  }

  Future<void> resume(String sessionId) async {
    final trimmed = sessionId.trim();
    if (trimmed.isEmpty || _terminating) return;
    if (_joiningSessionId == trimmed) return;

    _joiningSessionId = trimmed;
    await connect();
    _clearRtcConfiguration();

    state = state.copyWith(
      joinState: RealtimeJoinState.joining,
      sessionId: trimmed,
      clearErrorMessage: true,
      clearInfoMessage: true,
    );

    try {
      await _socketService.emitAck('session:resume', <String, dynamic>{
        'sessionId': trimmed,
      });

      await hydrateSession(trimmed);
      await _ensureMediaReady(trimmed, refreshTurnCredentials: true);

      state = state.copyWith(
        joinState: RealtimeJoinState.joined,
        clearIncomingCall: true,
        infoMessage: 'Your live session was restored.',
      );
    } catch (error) {
      state = state.copyWith(
        joinState: _mapJoinError(error),
        errorMessage: error.toString(),
      );
    } finally {
      if (_joiningSessionId == trimmed) {
        _joiningSessionId = null;
      }
    }
  }

  Future<void> leave() async {
    if (_terminating) return;
    final sessionId = (state.sessionId ?? '').trim();
    if (sessionId.isEmpty) return;

    await _terminateSession(
      keepSocketConnected: true,
      infoMessage: 'You left live.',
      alsoCallRepository: true,
    );
  }

  Future<void> toggleMicrophone() async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;
    if (state.isMediaBusy) return;
    if (!state.isMediaReady) {
      state = state.copyWith(
        infoMessage: 'Your microphone is not ready yet.',
        clearErrorMessage: true,
      );
      return;
    }

    final enabled = !state.microphoneEnabled;
    await _mediaService.setMicrophoneEnabled(enabled);
    await _socketService.emitAck('session:audio.set', <String, dynamic>{
      'sessionId': sessionId,
      'enabled': enabled,
    });
    _patchMyTrack(audioOn: enabled);
  }

  Future<void> toggleCamera() async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;
    if (state.isMediaBusy) return;
    if (!state.isVideoMode) {
      state = state.copyWith(
        infoMessage: 'Camera is only available in video calls.',
        clearErrorMessage: true,
      );
      return;
    }
    if (!state.isMediaReady) {
      state = state.copyWith(
        infoMessage: 'Your camera is not ready yet.',
        clearErrorMessage: true,
      );
      return;
    }

    final enabled = !state.cameraEnabled;
    await _mediaService.setCameraEnabled(enabled);
    await _socketService.emitAck('session:video.set', <String, dynamic>{
      'sessionId': sessionId,
      'enabled': enabled,
    });
    _patchMyTrack(videoOn: enabled);
  }

  Future<void> requestJoin(String sessionId) async {
    await _repository.createJoinRequest(sessionId);
    state = state.copyWith(
      sessionId: sessionId,
      joinState: RealtimeJoinState.requested,
      infoMessage: 'Entry request sent.',
      clearErrorMessage: true,
    );
  }

  Future<void> refreshPolicy() async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    try {
      final policy = await _repository.getPolicy(sessionId);
      state = state.copyWith(policy: policy);
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> refreshArtifacts() async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    try {
      final artifacts = await _repository.listArtifacts(sessionId);
      state = state.copyWith(artifacts: artifacts);
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> setWaitingRoom(bool enabled) async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    final policy = await _repository.updatePolicy(
      sessionId,
      waitingRoomEnabled: enabled,
    );
    state = state.copyWith(
      policy: policy,
      infoMessage: enabled ? 'Entry requests turned on.' : 'Entry requests turned off.',
    );
  }

  Future<void> setLocked(bool locked) async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    final policy = await _repository.setLocked(sessionId, locked: locked);
    final session = state.session;

    state = state.copyWith(
      session: session == null
          ? null
          : RealtimeSession(
              id: session.id,
              surfaceType: session.surfaceType,
              surfaceId: session.surfaceId,
              startedByUserId: session.startedByUserId,
              isActive: session.isActive,
              isLocked: locked,
              waitingRoomEnabled: session.waitingRoomEnabled,
              createdAt: session.createdAt,
              updatedAt: DateTime.now(),
            ),
      policy: policy,
      infoMessage: locked ? 'Room closed to new entries.' : 'Room opened to new entries.',
    );
  }

  Future<void> approveJoinRequest(String requestUserId) async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    await _repository.respondToJoinRequest(
      sessionId,
      requestUserId: requestUserId,
      decision: 'approve',
    );

    await refreshPolicy();
    await hydrateSession(sessionId);
    state = state.copyWith(infoMessage: 'Entry request approved.');
  }

  Future<void> rejectJoinRequest(String requestUserId) async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    await _repository.respondToJoinRequest(
      sessionId,
      requestUserId: requestUserId,
      decision: 'reject',
    );

    await refreshPolicy();
    state = state.copyWith(infoMessage: 'Entry request declined.');
  }

  Future<void> inviteMember({
    required String invitedUserId,
    String? note,
  }) async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    await _repository.createInvite(
      sessionId,
      invitedUserId: invitedUserId,
      note: note,
    );

    state = state.copyWith(
      infoMessage: 'Invitation sent.',
      clearErrorMessage: true,
    );
  }

  Future<void> removeParticipant(String targetUserId) async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    await _repository.removeParticipant(sessionId, targetUserId);
    await hydrateSession(sessionId);
    state = state.copyWith(infoMessage: 'Member removed from this live session.');
  }

  Future<void> requestConsent() async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    await _repository.requestConsent(sessionId);

    List<RealtimeConsent> consents = state.consents;
    try {
      consents = await _repository.listConsents(sessionId);
    } catch (error) {
      final text = error.toString().toLowerCase();
      if (!text.contains('403') && !text.contains('forbidden')) {
        rethrow;
      }
    }

    state = state.copyWith(
      consents: consents,
      infoMessage: 'Fresh consent requested.',
    );
  }

  Future<void> answerConsent({required bool granted}) async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    await _repository.respondToOwnConsent(
      sessionId,
      decision: granted ? 'grant' : 'decline',
    );

    List<RealtimeConsent> consents = state.consents;
    try {
      consents = await _repository.listConsents(sessionId);
    } catch (error) {
      final text = error.toString().toLowerCase();
      if (!text.contains('403') && !text.contains('forbidden')) {
        rethrow;
      }
    }

    state = state.copyWith(
      consents: consents,
      infoMessage: granted ? 'Consent granted.' : 'Consent declined.',
    );
  }

  Future<void> requestRecording({String? title}) async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    await _repository.requestRecording(sessionId, title: title);
    final recordings = await _repository.listRecordings(sessionId);
    state = state.copyWith(
      recordings: recordings,
      infoMessage: 'Recording requested.',
    );
  }

  Future<void> requestTranscript({String? title}) async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    await _repository.requestTranscript(sessionId, title: title);
    final transcripts = await _repository.listTranscripts(sessionId);
    state = state.copyWith(
      transcripts: transcripts,
      infoMessage: 'Live notes requested.',
    );
  }

  void clearMessage() {
    state = state.copyWith(
      clearErrorMessage: true,
      clearInfoMessage: true,
    );
  }

  void _applyBundle(RealtimeSessionSnapshot bundle) {
    final session = bundle.session;
    final hasVideo = bundle.participants.any((p) => p.videoOn || p.screenOn);
    final callMode = hasVideo ? 'video' : (state.callMode ?? 'audio');

    state = state.copyWith(
      session: session,
      sessionId: session.id,
      callMode: callMode,
      participants: bundle.participants,
      policy: bundle.policy,
      consents: bundle.consents,
      recordings: bundle.recordings,
      transcripts: bundle.transcriptJobs,
      artifacts: bundle.artifacts,
    );
  }


  Future<void> _terminateSession({
    required bool keepSocketConnected,
    String? infoMessage,
    required bool alsoCallRepository,
  }) async {
    if (_terminating) return;
    _terminating = true;

    final session = state.session;
    final sessionId = _managedSessionId;

    try {
      if (sessionId.isNotEmpty && keepSocketConnected) {
        try {
          await _socketService.emitAck('session:leave', <String, dynamic>{
            'sessionId': sessionId,
          });
        } catch (_) {}
      }

      if (alsoCallRepository && sessionId.isNotEmpty) {
        try {
          await _repository.leaveSession(session);
        } catch (_) {}
      }

      await _mediaService.resetSessionMedia();
      if (!keepSocketConnected) {
        await _socketService.disconnect();
      }
      _clearRtcConfiguration();

      state = _copyWithDetachedMediaState(
        joinState: RealtimeJoinState.idle,
        clearSessionContext: true,
        clearPolicy: true,
        clearErrorMessage: true,
        infoMessage: infoMessage,
      );
    } finally {
      _joiningSessionId = null;
      _hydratingSessionId = null;
      _terminating = false;
    }
  }

  Future<void> _ensureMediaReady(
    String sessionId, {
    bool refreshTurnCredentials = false,
  }) async {
    if (state.isMediaBusy) return;

    state = state.copyWith(
      isMediaBusy: true,
      clearMediaError: true,
    );

    try {
      final configuration = await _resolveRtcConfiguration(
        sessionId,
        refreshTurnCredentials: refreshTurnCredentials,
      );

      final wantsAudio = state.policy?.audioAllowed ?? true;
      final wantsVideo = state.isVideoMode && (state.policy?.videoAllowed ?? true);

      if (!state.isMediaReady) {
        await _mediaService.ensureLocalMedia(
          audio: wantsAudio,
          video: wantsVideo,
        );
      }

      await _socketService.emitAck('session:audio.set', <String, dynamic>{
        'sessionId': sessionId,
        'enabled': wantsAudio,
      });
      await _socketService.emitAck('session:video.set', <String, dynamic>{
        'sessionId': sessionId,
        'enabled': wantsVideo,
      });

      state = state.copyWith(
        isMediaBusy: false,
        isMediaReady: true,
        microphoneEnabled: wantsAudio,
        cameraEnabled: wantsVideo,
      );

      _rtcConfiguration = configuration;
      _rtcConfigurationSessionId = sessionId;
    } catch (error) {
      state = state.copyWith(
        isMediaBusy: false,
        mediaError: error.toString(),
        infoMessage: 'You are connected, but browser media is not active yet.',
      );
    }
  }

  Future<Map<String, dynamic>> _resolveRtcConfiguration(
    String sessionId, {
    bool refreshTurnCredentials = false,
  }) async {
    if (!refreshTurnCredentials &&
        _rtcConfiguration != null &&
        _rtcConfigurationSessionId == sessionId) {
      return _rtcConfiguration!;
    }

    final issued = await _repository.issueTurnCredentials(sessionId);
    final rawIceServers = issued['iceServers'];
    final configuration = <String, dynamic>{
      'iceServers': rawIceServers is List ? rawIceServers : const <dynamic>[],
      'sdpSemantics': 'unified-plan',
    };

    _rtcConfiguration = configuration;
    _rtcConfigurationSessionId = sessionId;
    return configuration;
  }

  void _clearRtcConfiguration() {
    _rtcConfiguration = null;
    _rtcConfigurationSessionId = null;
  }

  void _handleMediaSnapshot(RealtimeMediaSnapshot snapshot) {
    state = state.copyWith(
      isMediaReady: snapshot.ready,
      localRenderer: snapshot.localRenderer,
      remoteRenderers: snapshot.remoteRenderers,
      microphoneEnabled: snapshot.micEnabled,
      cameraEnabled: snapshot.cameraEnabled,
      mediaError: snapshot.error,
    );
  }

  Future<void> _sendOfferToSocket({
    required String peerKey,
    required String targetSocketId,
  }) async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    final configuration = await _resolveRtcConfiguration(sessionId);

    final offer = await _mediaService.createOffer(
      peerKey: peerKey,
      targetSocketId: targetSocketId,
      configuration: configuration,
      onIceCandidate: (candidate) {
        unawaited(_socketService.emitAck('session:ice-candidate', <String, dynamic>{
          'sessionId': sessionId,
          'targetSocketId': targetSocketId,
          'candidate': <String, dynamic>{
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        }));
      },
    );

    await _socketService.emitAck('session:offer', <String, dynamic>{
      'sessionId': sessionId,
      'targetSocketId': targetSocketId,
      'sdp': <String, dynamic>{
        'sdp': offer.sdp,
        'type': offer.type,
      },
    });
  }

  void _patchMyTrack({bool? audioOn, bool? videoOn}) {
    final meSocketId = _socketService.socketId;
    if (meSocketId == null) return;
    state = state.copyWith(
      participants: state.participants
          .map((participant) => participant.runtimeDeviceId == meSocketId
              ? participant.copyWith(
                  audioOn: audioOn ?? participant.audioOn,
                  videoOn: videoOn ?? participant.videoOn,
                )
              : participant)
          .toList(),
    );
  }

  void _handleSocketEvent(RealtimeParsedEvent event) {
    switch (event.name) {
      case 'socket:connected':
        state = state.copyWith(
          connectionStatus: RealtimeConnectionStatus.connected,
          lastSocketEvent: event.name,
        );
        return;
      case 'socket:disconnected':
        unawaited(_mediaService.resetSessionMedia());
        state = _copyWithDetachedMediaState(
          connectionStatus: RealtimeConnectionStatus.disconnected,
          joinState: RealtimeJoinState.idle,
          clearSessionContext: true,
          lastSocketEvent: event.name,
        );
        return;
      case 'socket:connect_error':
      case 'socket:error':
        state = state.copyWith(
          connectionStatus: RealtimeConnectionStatus.error,
          errorMessage: event.payload['message']?.toString(),
          lastSocketEvent: event.name,
        );
        return;
      case 'session:participant.joined':
      case 'session:participant.resumed':
        final merged = RealtimeEventParser.mergeSnapshot(state, event.payload);
        final modeFromEvent =
            ((event.payload['videoState'] ?? '').toString().toUpperCase() == 'ON' ||
             (event.payload['screenState'] ?? '').toString().toUpperCase() == 'ON')
                ? 'video'
                : merged.callMode;
        state = merged.copyWith(
          callMode: modeFromEvent,
          lastSocketEvent: event.name,
        );
        final targetSocketId = event.payload['socketId']?.toString();
        final peerKey = event.payload['userId']?.toString();
        if (targetSocketId != null &&
            targetSocketId.isNotEmpty &&
            targetSocketId != _socketService.socketId &&
            peerKey != null &&
            peerKey.isNotEmpty &&
            state.isJoined &&
            state.isMediaReady) {
          unawaited(_sendOfferToSocket(peerKey: peerKey, targetSocketId: targetSocketId));
        }
        return;
      case 'session:participant.left':
        final leavingUserId = event.payload['userId']?.toString();
        final updatedParticipants = state.participants
            .where((participant) => participant.userId != leavingUserId)
            .toList();

        state = state.copyWith(
          participants: updatedParticipants,
          lastSocketEvent: event.name,
        );

        if (leavingUserId != null && leavingUserId.isNotEmpty) {
          unawaited(_mediaService.removePeer(leavingUserId));
        }

        if (updatedParticipants.length <= 1 && state.isJoined) {
          unawaited(_terminateSession(
            keepSocketConnected: true,
            infoMessage: 'Call ended.',
            alsoCallRepository: false,
          ));
        }
        return;
      case 'session:offer':
        unawaited(() async {
          final sessionId = state.sessionId;
          if (sessionId == null || sessionId.isEmpty) return;

          await _ensureMediaReady(sessionId);
          final configuration = _rtcConfiguration;
          if (configuration == null) return;

          final peerKey = event.payload['userId']?.toString() ?? event.payload['fromSocketId']?.toString() ?? '';
          final fromSocketId = event.payload['fromSocketId']?.toString();
          if (peerKey.isEmpty || fromSocketId == null || fromSocketId.isEmpty) return;
          final answer = await _mediaService.handleRemoteOffer(
            peerKey: peerKey,
            targetSocketId: fromSocketId,
            configuration: configuration,
            sdp: Map<String, dynamic>.from((event.payload['sdp'] ?? const <String, dynamic>{}) as Map),
            onIceCandidate: (candidate) {
              unawaited(_socketService.emitAck('session:ice-candidate', <String, dynamic>{
                'sessionId': sessionId,
                'targetSocketId': fromSocketId,
                'candidate': <String, dynamic>{
                  'candidate': candidate.candidate,
                  'sdpMid': candidate.sdpMid,
                  'sdpMLineIndex': candidate.sdpMLineIndex,
                },
              }));
            },
          );
          await _socketService.emitAck('session:answer', <String, dynamic>{
            'sessionId': sessionId,
            'targetSocketId': fromSocketId,
            'sdp': <String, dynamic>{
              'sdp': answer.sdp,
              'type': answer.type,
            },
          });
        }());
        state = state.copyWith(lastSocketEvent: event.name);
        return;
      case 'session:answer':
        unawaited(() async {
          final peerKey = event.payload['userId']?.toString() ?? event.payload['fromSocketId']?.toString() ?? '';
          if (peerKey.isEmpty) return;
          final sdp = event.payload['sdp'];
          if (sdp is Map) {
            await _mediaService.handleRemoteAnswer(
              peerKey: peerKey,
              sdp: Map<String, dynamic>.from(sdp),
            );
          }
        }());
        state = state.copyWith(lastSocketEvent: event.name);
        return;
      case 'session:ice-candidate':
        unawaited(() async {
          final peerKey = event.payload['userId']?.toString() ?? event.payload['fromSocketId']?.toString() ?? '';
          if (peerKey.isEmpty) return;
          final candidate = event.payload['candidate'];
          if (candidate is Map) {
            await _mediaService.addRemoteCandidate(
              peerKey: peerKey,
              candidate: Map<String, dynamic>.from(candidate),
            );
          }
        }());
        state = state.copyWith(lastSocketEvent: event.name);
        return;
      case 'session:track.updated':
        final userId = event.payload['userId']?.toString();
        if (userId != null && userId.isNotEmpty) {
          final videoOn = (event.payload['videoState'] ?? '').toString().toUpperCase() == 'ON';
          final screenOn = (event.payload['screenState'] ?? '').toString().toUpperCase() == 'ON';
          state = state.copyWith(
            callMode: (videoOn || screenOn) ? 'video' : state.callMode,
            participants: state.participants
                .map((participant) => participant.userId == userId
                    ? participant.copyWith(
                        audioOn: (event.payload['audioState'] ?? '').toString().toUpperCase() == 'ON',
                        videoOn: videoOn,
                        screenOn: screenOn,
                      )
                    : participant)
                .toList(),
            lastSocketEvent: event.name,
          );
        }
        return;
      case 'session:replaced':
        state = state.copyWith(
          connectionStatus: RealtimeConnectionStatus.reconnecting,
          infoMessage: 'This live session moved to a new connection.',
          lastSocketEvent: event.name,
        );
        return;
      case 'session:removed':
      case 'realtime:removed':
        unawaited(_mediaService.resetSessionMedia());
        state = _copyWithDetachedMediaState(
          joinState: RealtimeJoinState.removed,
          infoMessage: 'You were removed from this live session.',
          lastSocketEvent: event.name,
        );
        return;
      case 'join:requested':
        state = state.copyWith(
          joinState: RealtimeJoinState.requested,
          infoMessage: 'Your request to join is pending.',
          lastSocketEvent: event.name,
        );
        return;
      case 'join:approved':
        state = state.copyWith(
          joinState: RealtimeJoinState.joined,
          infoMessage: 'Your request to join was approved.',
          lastSocketEvent: event.name,
        );
        return;
      case 'join:rejected':
        state = state.copyWith(
          joinState: RealtimeJoinState.rejected,
          infoMessage: 'Your request to join was declined.',
          lastSocketEvent: event.name,
        );
        return;
      case 'session:state':
      case 'participants:updated':
      case 'policy:updated':
      case 'session:policyUpdated':
      case 'session:updated':
      case 'session:participantUpdated':
      case 'session:participantRemoved':
      case 'consent:updated':
      case 'recording:updated':
      case 'transcript:updated':
      case 'artifact:updated':
        final merged = RealtimeEventParser.mergeSnapshot(state, event.payload);
        state = merged.copyWith(lastSocketEvent: event.name);
        return;
      default:
        state = state.copyWith(lastSocketEvent: event.name);
        return;
    }
  }

  RealtimeJoinState _mapJoinError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('approval') || text.contains('waiting room')) {
      return RealtimeJoinState.requested;
    }
    if (text.contains('locked')) return RealtimeJoinState.locked;
    if (text.contains('reject')) return RealtimeJoinState.rejected;
    return RealtimeJoinState.failed;
  }

  bool managesCorrespondenceSurface({
    required String threadId,
    String? spaceId,
  }) {
    final session = state.session;
    if (session == null) return false;
    final surfaceType = session.surfaceType.name.trim().toLowerCase();
    final surfaceId = (session.surfaceId ?? '').trim();
    final normalizedThreadId = threadId.trim();
    final normalizedSpaceId = (spaceId ?? '').trim();

    if (surfaceType == 'dm' || surfaceType == 'thread') {
      return normalizedThreadId.isNotEmpty && surfaceId == normalizedThreadId;
    }

    if (surfaceType == 'space') {
      if (normalizedSpaceId.isNotEmpty && surfaceId == normalizedSpaceId) return true;
    }

    return false;
  }

  String? activeSessionIdForCorrespondence({
    required String threadId,
    String? spaceId,
  }) {
    if (!managesCorrespondenceSurface(threadId: threadId, spaceId: spaceId)) {
      return null;
    }
    final value = _managedSessionId;
    return value.isEmpty ? null : value;
  }


  @override
  void dispose() {
    _subscription?.cancel();
    _mediaSubscription?.cancel();
    _mediaService.dispose();
    _socketService.dispose();
    super.dispose();
  }
}
