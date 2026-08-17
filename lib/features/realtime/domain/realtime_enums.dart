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

  /// The clean-sheet Conversation surface (canon 2026-08-16). A first-class
  /// consumer of the shared realtime engine — never parsed as `unknown`,
  /// which routed conversation calls through every unknown-surface
  /// fallback (generic join, /home return route) during the failed
  /// three-party certification of 2026-08-17.
  conversation,
  unknown,
}

enum RealtimeParticipantRole {
  host,
  moderator,
  participant,
  guest,

  /// GO LIVE viewer (task #172): admitted to a PUBLIC_STAGE session as a
  /// receive-only observer — never a Conversation party, never publishes.
  observer,
  unknown,
}
