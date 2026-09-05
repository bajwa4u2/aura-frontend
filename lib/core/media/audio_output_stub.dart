import 'audio_output.dart';

/// A platform this build has no audio-routing implementation for. Reports
/// nothing rather than pretending, so the control simply does not appear.
const AudioOutputAuthority platformAudioOutputAuthority =
    UnsupportedAudioOutputAuthority();
