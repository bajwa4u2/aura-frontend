import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'audio_output.dart';

/// AUDIO OUTPUT ON A PHONE.
///
/// Two sources, deliberately, because neither alone is sufficient:
///
///   * **flutter_webrtc** lists the routes it is able to SELECT, and performs
///     the selection. It is the only thing that may change the route, because
///     it also owns audio focus and mode for the call — a second actor setting
///     the communication device behind its back would fight it.
///
///   * **Android itself** answers what route is actually in force, and which
///     routes it considers usable for communication. The plugin does not expose
///     its selection to Dart, and even if it did, the last thing we ASKED for is
///     not evidence of where the audio is: a request can be refused,
///     substituted, or overridden when a headset connects.
///
/// So: the plugin is asked to act, the OS is asked what happened. Where they
/// disagree, the OS wins, because the OS is where the sound comes out.
class NativeAudioOutputAuthority extends AudioOutputAuthority {
  const NativeAudioOutputAuthority();

  static const MethodChannel _channel =
      MethodChannel('org.auraplatform.app/audio_route');

  /// Android has real communication-route switching. iOS has its own audio
  /// session model and its platform adapter is deliberately still gated, so it
  /// is not claimed here — see the call-platform gate.
  @override
  bool get isSupported {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<AudioOutputRoute>> available() async {
    if (!isSupported) return const [];

    // The SELECTABLE set. A route Aura cannot switch to is not a choice, so
    // this is the list that bounds what is offered.
    final selectable = <String, AudioOutputRoute>{};
    try {
      for (final device in await Helper.audiooutputs) {
        final id = device.deviceId.trim();
        if (id.isEmpty) continue;
        selectable[id] = AudioOutputRoute(
          id: id,
          kind: _kindFromId(id),
          deviceName: device.label.trim().isEmpty ? null : device.label.trim(),
        );
      }
    } catch (_) {
      // A platform that cannot enumerate offers nothing rather than a guess.
      return const [];
    }

    // The OS's own view, used to ENRICH names and to drop anything the system
    // no longer considers usable. It is not used to invent routes: a route the
    // OS reports but the plugin cannot select would be an option that does
    // nothing when tapped.
    try {
      final reported = await _platformRoutes('availableRoutes');
      if (reported.isNotEmpty) {
        final live = reported.map((r) => r.id).toSet();
        selectable.removeWhere((id, _) => !live.contains(id));
        for (final route in reported) {
          final existing = selectable[route.id];
          if (existing == null) continue;
          final name = route.deviceName;
          if (name != null && name.isNotEmpty) {
            selectable[route.id] =
                AudioOutputRoute(id: existing.id, kind: existing.kind, deviceName: name);
          }
        }
      }
    } catch (_) {
      // Below API 31, or the read failed. The selectable list stands on its own.
    }

    final routes = selectable.values.toList()
      ..sort((a, b) => _order(a.kind).compareTo(_order(b.kind)));
    return routes;
  }

  @override
  Future<AudioOutputRoute?> current() async {
    if (!isSupported) return null;
    try {
      final routes = await _platformRoutes('currentRoute');
      return routes.isEmpty ? null : routes.first;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AudioOutputRoute?> select(AudioOutputRoute route) async {
    if (!isSupported) return null;
    try {
      await Helper.selectAudioOutput(route.id);
    } catch (_) {
      // The request failed outright. Fall through and report what the platform
      // is actually on, which is the only honest answer either way.
    }
    // Deliberately re-read rather than returning `route`. Reporting the request
    // as though it were the result is exactly the optimism this control must
    // not have.
    return current();
  }

  Future<List<AudioOutputRoute>> _platformRoutes(String method) async {
    final raw = await _channel.invokeMethod<Object?>(method);
    if (raw == null) return const [];
    final entries = raw is List ? raw : [raw];
    final routes = <AudioOutputRoute>[];
    for (final entry in entries) {
      if (entry is! Map) continue;
      final id = (entry['id'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      final name = (entry['name'] ?? '').toString().trim();
      routes.add(AudioOutputRoute(
        id: id,
        kind: _kindFromId(id),
        deviceName: name.isEmpty ? null : name,
      ));
    }
    return routes;
  }

  /// The vocabulary is shared with the platform side on purpose, so a route
  /// read from the OS and a route selected through the plugin are the same
  /// value and can be compared without a translation table in between.
  static AudioOutputKind _kindFromId(String id) => switch (id) {
        'earpiece' => AudioOutputKind.earpiece,
        'speaker' => AudioOutputKind.speaker,
        'bluetooth' => AudioOutputKind.bluetooth,
        'wired-headset' => AudioOutputKind.wiredHeadset,
        _ => AudioOutputKind.other,
      };

  /// Presentation order only — the order a person scans, not a priority rule.
  /// What a call STARTS on is the call's decision and is not made here.
  static int _order(AudioOutputKind kind) => switch (kind) {
        AudioOutputKind.bluetooth => 0,
        AudioOutputKind.wiredHeadset => 1,
        AudioOutputKind.earpiece => 2,
        AudioOutputKind.speaker => 3,
        AudioOutputKind.other => 4,
      };
}
