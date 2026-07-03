import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The user's device intent captured at the meeting-entry surface (pre-join /
/// lobby): whether to enter with camera and microphone on, and which devices
/// to use once device selection lands (Phase 1 · Priority 2).
///
/// This is additive PRODUCT-layer state. It never touches the RTC / signalling
/// / join path — the live room simply READS it after media is ready and applies
/// the choice via the public `setCameraEnabled` / `setMicrophoneEnabled` media
/// controls. Verified infrastructure stays frozen.
class MeetingEntryPrefs {
  final bool cameraOn;
  final bool micOn;

  /// Preferred device ids (populated by device selection). Empty = system
  /// default. Reserved for Phase 1 · Priority 2.
  final String? cameraDeviceId;
  final String? micDeviceId;
  final String? speakerDeviceId;

  const MeetingEntryPrefs({
    this.cameraOn = true,
    this.micOn = true,
    this.cameraDeviceId,
    this.micDeviceId,
    this.speakerDeviceId,
  });

  MeetingEntryPrefs copyWith({
    bool? cameraOn,
    bool? micOn,
    String? cameraDeviceId,
    String? micDeviceId,
    String? speakerDeviceId,
  }) {
    return MeetingEntryPrefs(
      cameraOn: cameraOn ?? this.cameraOn,
      micOn: micOn ?? this.micOn,
      cameraDeviceId: cameraDeviceId ?? this.cameraDeviceId,
      micDeviceId: micDeviceId ?? this.micDeviceId,
      speakerDeviceId: speakerDeviceId ?? this.speakerDeviceId,
    );
  }
}

class MeetingEntryPrefsNotifier extends StateNotifier<MeetingEntryPrefs> {
  MeetingEntryPrefsNotifier() : super(const MeetingEntryPrefs());

  void setCameraOn(bool value) => state = state.copyWith(cameraOn: value);
  void setMicOn(bool value) => state = state.copyWith(micOn: value);

  void setDevices({String? camera, String? mic, String? speaker}) {
    state = state.copyWith(
      cameraDeviceId: camera,
      micDeviceId: mic,
      speakerDeviceId: speaker,
    );
  }
}

/// Survives the entry → room navigation so the room can honour the choice.
final meetingEntryPrefsProvider =
    StateNotifierProvider<MeetingEntryPrefsNotifier, MeetingEntryPrefs>(
  (ref) => MeetingEntryPrefsNotifier(),
);
