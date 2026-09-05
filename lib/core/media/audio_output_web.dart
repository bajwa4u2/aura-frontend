import 'audio_output.dart';

/// AUDIO OUTPUT IN A BROWSER.
///
/// A browser has no earpiece, no Bluetooth routing authority and no concept of
/// a communication route. What it has is `setSinkId`, which points an audio
/// element at an output device the user has already granted — and even that is
/// unavailable in several browsers and requires a device permission Aura does
/// not ask for during a call.
///
/// So the honest answer here is "not supported", and the control is not shown.
/// Manufacturing an Earpiece/Speaker/Bluetooth picker on the web would be
/// inventing a capability the browser does not have: every option would do
/// nothing, and the person would be told their audio moved when it had not.
///
/// Output selection on the web belongs to the browser and the operating system,
/// where the person already has it.
class WebAudioOutputAuthority extends UnsupportedAudioOutputAuthority {
  const WebAudioOutputAuthority();
}

const AudioOutputAuthority platformAudioOutputAuthority =
    WebAudioOutputAuthority();
