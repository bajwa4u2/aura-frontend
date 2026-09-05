import 'package:flutter/foundation.dart';

/// WHERE A CALL IS BEING HEARD — the shared capability, one shape everywhere.
///
/// ── WHY THIS EXISTS ──────────────────────────────────────────────────────
///
/// Aura's in-call control was a binary speaker toggle. A person with a
/// Bluetooth headset connected has at least three legitimate outputs — the
/// headset, the earpiece and the speaker — and a two-state toggle cannot
/// express three, so there was no way to move a call to where the person
/// actually was.
///
/// That is not a convenience gap. Measured on a real device, 2026-09-05: a
/// paired headset took the call, dropped its link half a second later, and the
/// call was left with no output at all. Media was arriving and correctly bound
/// the entire time. Every layer of the call authority was telling the truth and
/// the person still could not hear, with no control that could fix it.
///
/// ── WHAT THIS IS NOT ─────────────────────────────────────────────────────
///
/// Audio output is LOCAL DEVICE STATE. It is not call truth. Choosing a
/// different speaker does not change `Call.phase`, `acceptedAt`, `connectedAt`,
/// which device answered, whether media is established, or anything in a
/// person's call history. The person hearing audio and the server knowing media
/// is connected are different facts, and this file must never blur them.
///
/// It is also not a routing POLICY. The default a call starts on is decided by
/// the call, not here: a voice call claims the earpiece, a video call the
/// speaker. This provides observability, selection and recovery over that
/// default — never a new set of priority rules.
///
/// ── THE CONTRACT ─────────────────────────────────────────────────────────
///
/// Three questions, answerable by any platform that has real audio routing:
/// what outputs EXIST, which one is CURRENT, and please USE this one. A
/// platform that cannot answer honestly answers with nothing, and the control
/// disappears rather than offering choices that do not exist.

/// A CATEGORY OF OUTPUT, because that is what operating systems actually
/// expose.
///
/// Android reports routes as kinds — `earpiece`, `speaker`, `bluetooth`,
/// `wired-headset` — and names the device only where a name exists. Modelling
/// this as "a list of devices" would invite treating a device NAME as identity,
/// which it is not: two headsets can share a name, a name can be absent, and
/// the route is what the OS switches.
enum AudioOutputKind {
  earpiece,
  speaker,
  bluetooth,
  wiredHeadset,

  /// A real route the platform reported that does not map to a known kind. It
  /// is offered using the platform's own name rather than hidden, because a
  /// route that exists is a route the person may need.
  other,
}

extension AudioOutputKindCopy on AudioOutputKind {
  /// Human words. Never HFP, SCO, sinkId, AVAudioSession or AudioDeviceInfo —
  /// nobody making a phone call can act on any of those.
  String get label => switch (this) {
        AudioOutputKind.earpiece => 'Earpiece',
        AudioOutputKind.speaker => 'Speaker',
        AudioOutputKind.bluetooth => 'Bluetooth',
        AudioOutputKind.wiredHeadset => 'Headset',
        AudioOutputKind.other => 'Other device',
      };
}

/// ONE ROUTE THE PLATFORM HAS ACTUALLY REPORTED.
@immutable
class AudioOutputRoute {
  const AudioOutputRoute({
    required this.id,
    required this.kind,
    this.deviceName,
  });

  /// The platform's own identifier for this route, passed back verbatim when
  /// selecting it. Opaque on purpose — it is the platform's word, not ours.
  final String id;

  final AudioOutputKind kind;

  /// The device's name, where the platform supplies a meaningful one. Shown
  /// only for routes where a name distinguishes something a person recognises
  /// — a headset they can name — and never invented.
  final String? deviceName;

  /// What a person should read. A named Bluetooth headset is worth naming;
  /// "Earpiece" named "Earpiece" is noise.
  String get label {
    final name = (deviceName ?? '').trim();
    if (name.isEmpty) return kind.label;
    switch (kind) {
      case AudioOutputKind.bluetooth:
      case AudioOutputKind.wiredHeadset:
      case AudioOutputKind.other:
        // A device name only earns its place when it says more than the kind.
        return name.toLowerCase() == kind.label.toLowerCase()
            ? kind.label
            : name;
      case AudioOutputKind.earpiece:
      case AudioOutputKind.speaker:
        return kind.label;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is AudioOutputRoute && other.id == id && other.kind == kind;

  @override
  int get hashCode => Object.hash(id, kind);

  @override
  String toString() => 'AudioOutputRoute($id, ${kind.name})';
}

/// WHAT THIS DEVICE CAN DO WITH CALL AUDIO.
///
/// Implementations report only what their platform genuinely exposes. A
/// browser has no earpiece and no Bluetooth routing authority, so the web
/// implementation reports what the browser permits and nothing more —
/// manufacturing an "Earpiece" entry there would be inventing a capability.
abstract class AudioOutputAuthority {
  const AudioOutputAuthority();

  /// Whether this platform can answer the three questions at all. When false
  /// the control is not shown; an empty picker is worse than none.
  bool get isSupported;

  /// Routes the platform reports as available right now. Never a guess, never a
  /// remembered list — a Bluetooth headset that has gone must stop being
  /// offered.
  Future<List<AudioOutputRoute>> available();

  /// The route audio is actually on, as the platform reports it, or null when
  /// the platform will not say.
  ///
  /// Deliberately a READ rather than a memory of the last request: a request
  /// can be refused, silently substituted, or overridden by the system when a
  /// headset connects. The last thing we asked for is not evidence of where the
  /// audio is.
  Future<AudioOutputRoute?> current();

  /// Ask the platform to use [route].
  ///
  /// Returns the route the platform is on AFTERWARDS — which may not be the one
  /// requested. Callers must render what came back, never what they asked for.
  Future<AudioOutputRoute?> select(AudioOutputRoute route);
}

/// A platform with no real audio-routing authority.
///
/// Answers honestly rather than pretending: no support, no routes, no current
/// route, and a selection that changes nothing and says so.
class UnsupportedAudioOutputAuthority extends AudioOutputAuthority {
  const UnsupportedAudioOutputAuthority();

  @override
  bool get isSupported => false;

  @override
  Future<List<AudioOutputRoute>> available() async => const [];

  @override
  Future<AudioOutputRoute?> current() async => null;

  @override
  Future<AudioOutputRoute?> select(AudioOutputRoute route) async => null;
}

/// WHAT THE PICKER KNOWS AT ONE MOMENT.
@immutable
class AudioOutputState {
  const AudioOutputState({
    this.routes = const [],
    this.current,
    this.isSupported = false,
    this.isSwitching = false,
  });

  final List<AudioOutputRoute> routes;
  final AudioOutputRoute? current;
  final bool isSupported;

  /// True while a request is in flight, so the control can be shown as busy
  /// rather than briefly showing the old route as though nothing happened.
  final bool isSwitching;

  /// Worth showing a control at all: the platform answers, and there is more
  /// than one place the audio could go. A single immovable route is not a
  /// choice, and offering it as one would be theatre.
  bool get hasChoice => isSupported && routes.length > 1;

  AudioOutputState copyWith({
    List<AudioOutputRoute>? routes,
    AudioOutputRoute? current,
    bool clearCurrent = false,
    bool? isSupported,
    bool? isSwitching,
  }) {
    return AudioOutputState(
      routes: routes ?? this.routes,
      current: clearCurrent ? null : (current ?? this.current),
      isSupported: isSupported ?? this.isSupported,
      isSwitching: isSwitching ?? this.isSwitching,
    );
  }
}
