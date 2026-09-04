import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/acquisition_envelope.dart';
import 'share_intake_inbox.dart';

/// THE ONE CHANNEL EVERY OPERATING SYSTEM SPEAKS INTO.
///
/// `org.auraplatform.app/share_intake` — one name, one message shape, one
/// arrival path. Android implements it in `ShareIntake.kt`; iOS and Windows
/// will implement the same two methods, and neither will get a Dart branch of
/// its own.
///
/// THIS IS WHY `PAGE_SPECIFIC_SHARE_PIPELINES = 0` SURVIVES CONTACT WITH
/// THREE PLATFORMS. There is no `Platform.isAndroid` here and there must never
/// be one. A platform that has not implemented the channel answers
/// [MissingPluginException], which means exactly what it should mean — nothing
/// was shared — and is handled as such rather than guarded against by asking
/// which platform this is. The result is that adding iOS is writing Swift, not
/// editing Dart.
///
/// TWO WAYS IN, FOR ONE REASON.
///
///   * [_drain] — a PULL, at startup. A share that launches a cold app arrives
///     before Dart exists to hear it, so the native side holds it and Dart
///     asks. A push into a listener that is not there yet is a share that
///     silently never happened.
///   * `onShare` — a PUSH, while running. A share arriving at an app already
///     open has no cold start to survive, and waiting for a poll would leave
///     the person looking at whatever they had open.
///
/// Both end in the same `deliver`, and the native side hands each share over
/// at most once.
class ShareIntakeChannel {
  ShareIntakeChannel(this._ref);

  static const channel = MethodChannel('org.auraplatform.app/share_intake');

  final Ref _ref;
  bool _started = false;

  /// Begin listening, and take anything already waiting.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    channel.setMethodCallHandler((call) async {
      if (call.method == 'onShare') {
        _deliver(call.arguments);
      }
      return null;
    });

    await _drain();
  }

  /// Ask for a share that arrived while Dart was not listening.
  ///
  /// Safe to call repeatedly: the native side hands each share over at most
  /// once, so a drain on every resume cannot present the same content twice.
  Future<void> drainPending() => _drain();

  Future<void> _drain() async {
    try {
      _deliver(await channel.invokeMethod<dynamic>('consumePendingShare'));
    } on MissingPluginException {
      // This platform has no share target. Not an error, and specifically not
      // something to branch on: it is the honest answer to "was anything
      // shared", which is no.
    } on PlatformException {
      // The native side failed to describe a share. Nothing is delivered, and
      // nothing is invented to fill the gap.
    }
  }

  void _deliver(dynamic raw) {
    final envelope = _parse(raw);
    if (envelope == null) return;
    _ref.read(shareIntakeInboxProvider.notifier).deliver(envelope);
  }

  /// Turn what the platform said into an envelope, or nothing.
  ///
  /// EVERY FIELD IS TREATED AS ABSENT UNTIL PROVEN PRESENT. This parses a
  /// message from outside Aura, so a missing key, a wrong type or a null must
  /// produce a smaller envelope rather than an exception on the way into the
  /// app — the person shared something, and a crash is the one response that
  /// tells them nothing.
  static AcquisitionEnvelope? _parse(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<Object?, Object?>.from(raw);

    final payloads = <AcquiredPayload>[];
    final rawPayloads = map['payloads'];
    if (rawPayloads is List) {
      for (final item in rawPayloads) {
        if (item is! Map) continue;
        final payload = _payload(Map<Object?, Object?>.from(item));
        if (payload != null) payloads.add(payload);
      }
    }

    final refusals = <String>[
      for (final refusal in (map['refusals'] as List?) ?? const [])
        if (refusal is String && refusal.trim().isNotEmpty) refusal.trim(),
    ];

    if (payloads.isEmpty && refusals.isEmpty) return null;

    return AcquisitionEnvelope(
      platform: _platform(map['platform']),
      payloads: payloads,
      refusals: refusals,
      receivedAt: _receivedAt(map['receivedAt']),
      subject: _string(map['subject']),
      handoffReference: _string(map['handoffReference']),
    );
  }

  static AcquiredPayload? _payload(Map<Object?, Object?> item) {
    final kind = switch (_string(item['kind'])) {
      'text' => AcquiredPayloadKind.text,
      'url' => AcquiredPayloadKind.url,
      'file' => AcquiredPayloadKind.file,
      _ => null,
    };
    if (kind == null) return null;

    final text = _string(item['text']);
    final filePath = _string(item['filePath']);
    final bytes = item['bytes'];

    // A payload that carries nothing is not a payload. Keeping it would put an
    // empty row in the preview and a refusal in front of a person who shared
    // one thing and would be told two failed.
    if (kind == AcquiredPayloadKind.file && filePath == null && bytes == null) {
      return null;
    }
    if (kind != AcquiredPayloadKind.file && text == null) return null;

    return AcquiredPayload(
      kind: kind,
      text: text,
      bytes: bytes is Uint8List ? bytes : null,
      filePath: filePath,
      declaredMimeType: _string(item['declaredMimeType']),
      fileName: _string(item['fileName']),
      sourceUri: _string(item['sourceUri']),
      sizeBytes: item['sizeBytes'] is int ? item['sizeBytes'] as int : null,
    );
  }

  /// Which door it came through. Recorded for provenance and used for nothing
  /// else — an unrecognised platform is still a share.
  static AcquisitionPlatform _platform(Object? raw) => switch (_string(raw)) {
        'android' => AcquisitionPlatform.android,
        'ios' => AcquisitionPlatform.ios,
        'windows' => AcquisitionPlatform.windows,
        _ => AcquisitionPlatform.web,
      };

  static DateTime _receivedAt(Object? raw) {
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    return DateTime.now();
  }

  static String? _string(Object? raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Tell the platform the copies it made are no longer needed.
  ///
  /// Content someone shared and then abandoned should not sit in a cache on
  /// their device. Best effort by design: failing to tidy up must never fail
  /// the share it is tidying up after.
  static Future<void> release() async {
    try {
      await channel.invokeMethod<void>('releaseSharedContent');
    } catch (_) {
      // Nothing to report. The platform clears this directory on the way in
      // as well, so a missed cleanup is corrected by the next share.
    }
  }
}

final shareIntakeChannelProvider = Provider<ShareIntakeChannel>(
  (ref) => ShareIntakeChannel(ref),
);
