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
