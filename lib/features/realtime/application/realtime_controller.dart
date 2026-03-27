import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../data/realtime_event_parser.dart';
import '../data/realtime_repository.dart';
import '../data/realtime_socket_service.dart';
import '../domain/realtime_enums.dart';
import '../domain/realtime_models.dart';
import '../domain/realtime_state.dart';

class RealtimeController extends StateNotifier<RealtimeState> {
  RealtimeController(
    this._repository,
    this._socketService,
    this._tokenStore,
  ) : super(RealtimeState.initial()) {
    _subscription = _socketService.events.listen(_handleSocketEvent);
  }

  final RealtimeRepository _repository;
  final RealtimeSocketService _socketService;
  final TokenStore _tokenStore;

  StreamSubscription<RealtimeParsedEvent>? _subscription;

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
        throw StateError('You need to sign in before entering a live room.');
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
      state = state.copyWith(
        isBusy: false,
        sessionId: bundle.session.id,
        joinState: RealtimeJoinState.idle,
        infoMessage: 'Live room started.',
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

  Future<void> disconnect() async {
    await _socketService.disconnect();
    state = state.copyWith(
      connectionStatus: RealtimeConnectionStatus.disconnected,
      joinState: RealtimeJoinState.idle,
      clearInfoMessage: true,
      lastSocketEvent: 'socket:disconnected',
    );
  }

  Future<void> hydrateSession(String sessionId) async {
    if (sessionId.trim().isEmpty) return;

    state = state.copyWith(
      isBusy: true,
      clearErrorMessage: true,
      sessionId: sessionId,
    );

    try {
      final bundle = await _repository.loadSessionBundle(sessionId);
      _applyBundle(bundle);
      state = state.copyWith(
        isBusy: false,
        infoMessage: 'Live room loaded.',
      );
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> join(String sessionId) async {
    final trimmed = sessionId.trim();
    if (trimmed.isEmpty) return;

    await connect();

    state = state.copyWith(
      joinState: RealtimeJoinState.joining,
      sessionId: trimmed,
      clearErrorMessage: true,
      clearInfoMessage: true,
    );

    try {
      await _socketService.emitAck('session:join', <String, dynamic>{
        'sessionId': trimmed,
      });

      await hydrateSession(trimmed);

      state = state.copyWith(
        joinState: RealtimeJoinState.joined,
        infoMessage: 'You entered the live room.',
      );
    } catch (error) {
      state = state.copyWith(
        joinState: _mapJoinError(error),
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> resume(String sessionId) async {
    final trimmed = sessionId.trim();
    if (trimmed.isEmpty) return;

    await connect();

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

      state = state.copyWith(
        joinState: RealtimeJoinState.joined,
        infoMessage: 'Your live room was restored.',
      );
    } catch (error) {
      state = state.copyWith(
        joinState: _mapJoinError(error),
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> leave() async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    try {
      await _socketService.emitAck('session:leave', <String, dynamic>{
        'sessionId': sessionId,
      });
    } catch (_) {
      // best effort
    }

    state = state.copyWith(
      joinState: RealtimeJoinState.idle,
      participants: const <RealtimeParticipant>[],
      clearPolicy: true,
      consents: const <RealtimeConsent>[],
      recordings: const <RealtimeRecording>[],
      transcripts: const <RealtimeTranscriptJob>[],
      artifacts: const <RealtimeArtifact>[],
      infoMessage: 'You left the live room.',
    );
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
    state = state.copyWith(infoMessage: 'Member removed from the room.');
  }

  Future<void> requestConsent() async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    await _repository.requestConsent(sessionId);
    final consents = await _repository.listConsents(sessionId);
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
    final consents = await _repository.listConsents(sessionId);
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
    state = state.copyWith(
      session: bundle.session,
      sessionId: bundle.session.id,
      participants: bundle.participants,
      policy: bundle.policy,
      consents: bundle.consents,
      recordings: bundle.recordings,
      transcripts: bundle.transcriptJobs,
      artifacts: bundle.artifacts,
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
        state = state.copyWith(
          connectionStatus: RealtimeConnectionStatus.disconnected,
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
      case 'session:replaced':
        state = state.copyWith(
          connectionStatus: RealtimeConnectionStatus.reconnecting,
          infoMessage: 'This room moved to a new connection.',
          lastSocketEvent: event.name,
        );
        return;
      case 'session:removed':
      case 'realtime:removed':
        state = state.copyWith(
          joinState: RealtimeJoinState.removed,
          infoMessage: 'You were removed from this live room.',
          lastSocketEvent: event.name,
        );
        return;
      case 'join:requested':
        state = state.copyWith(
          joinState: RealtimeJoinState.requested,
          infoMessage: 'Your entry request is pending.',
          lastSocketEvent: event.name,
        );
        return;
      case 'join:approved':
        state = state.copyWith(
          joinState: RealtimeJoinState.joined,
          infoMessage: 'Your entry request was approved.',
          lastSocketEvent: event.name,
        );
        return;
      case 'join:rejected':
        state = state.copyWith(
          joinState: RealtimeJoinState.rejected,
          infoMessage: 'Your entry request was declined.',
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

  @override
  void dispose() {
    _subscription?.cancel();
    _socketService.dispose();
    super.dispose();
  }
}
