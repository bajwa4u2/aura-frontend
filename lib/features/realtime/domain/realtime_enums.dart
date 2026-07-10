enum RealtimeConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

enum RealtimeJoinState {
  idle,
  joining,
  joined,
  requested,
  rejected,
  removed,
  banned,
  locked,
  failed,

  /// The session moved to another of the user's devices. Deliberate handover:
  /// this device stays quietly parked (no auto-rejoin — that produced two
  /// devices endlessly replacing each other) until the user chooses to
  /// continue here.
  replaced,
}

enum RealtimeConsentStatus {
  none,
  pending,
  granted,
  declined,
}

enum RealtimeRecordingStatus {
  idle,
  requested,
  active,
  stopped,
  failed,
}

enum RealtimeTranscriptStatus {
  idle,
  requested,
  active,
  completed,
  failed,
}

enum RealtimeSurfaceType {
  dm,
  thread,
  space,
  room,
  meeting,
  institution,
  unknown,
}

enum RealtimeParticipantRole {
  host,
  moderator,
  participant,
  guest,
  unknown,
}
