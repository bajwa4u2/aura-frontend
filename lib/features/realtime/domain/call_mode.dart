/// WHAT KIND OF CALL IS THIS — asked in exactly one place.
///
/// `session.kind` is the sole authority for call mode. Participant media state
/// reflects capability and choice, not the call type the host started.
///
/// This existed twice and the two copies disagreed. The canonical one mapped
/// VIDEO and MIXED to video; an older one, from 2026-03-30, mapped anything not
/// literally `"video"` to audio — which sent MIXED to audio. Meetings are
/// created with kind MIXED, so a meeting hydrated through that path captured an
/// audio-only stream: no video track was ever published, and "Show camera" had
/// no track to enable. Founder-observed as an attendee sitting in an "audio
/// meeting" while the caller was in a video call.
///
/// MIXED is video-CAPABLE, not video-forced. A person can still turn their
/// camera off; what they must not be denied is the ability to turn it on.
library;

/// Canonical call mode for a session kind.
///
/// Returns `'video'`, `'audio'`, or [fallback] when the kind is absent or
/// unrecognised — an unknown kind must not silently downgrade a call to audio,
/// which is the mistake this function exists to prevent.
String? callModeForSessionKind(String? sessionKind, {String? fallback}) {
  final kind = (sessionKind ?? '').trim().toUpperCase();
  switch (kind) {
    case 'VIDEO':
    case 'MIXED':
      return 'video';
    case 'AUDIO':
      return 'audio';
    default:
      return fallback;
  }
}
