import 'package:flutter_webrtc/flutter_webrtc.dart';

/// CANONICAL REMOTE MEDIA BINDING FOR THE SFU PATH.
///
/// Founder ruling, client migration §2. The product must never reach
///
///     MEDIA_FLOWING = TRUE   while   REMOTE_TILE = BLANK
///
/// merely because an event callback was absent — and on this provider that is
/// not a hypothetical. Measured 2026-08-26 on Windows and a physical Pixel 9a:
/// `onTrack` does not fire for receivers created by the subscribe
/// renegotiation, while `inbound-rtp` already shows megabytes arriving. The
/// shipped mesh client drives every remote tile from `onTrack`, so migrating
/// it unchanged would render blank tiles over live media.
///
/// This binds deterministically instead. Aura's subscribe response says which
/// m-line carries whose track, so once renegotiation completes the receiver is
/// simply looked up — no callback, and no polling.
///
/// ## The trap this exists to avoid
///
/// A send-only transceiver ALSO exposes a non-null `receiver.track`. Measured
/// on the same run: mids 0 and 1 were `SendOnly` and still reported
/// `recvKind=audio` and `recvKind=video`. So remote media must be selected by
/// DIRECTION. Filtering on "has a receiver track" would bind a participant's
/// own outbound audio as if it were somebody else's, and every tile would show
/// the local speaker.
class StageRemoteBinding {
  const StageRemoteBinding({
    required this.participantId,
    required this.trackId,
    required this.trackType,
    required this.mid,
    required this.track,
  });

  /// The Aura participant this media belongs to. Roster identity, not
  /// transport identity — the provider's ids never reach the client.
  final String participantId;
  final String trackId;
  final String trackType;
  final String mid;
  final MediaStreamTrack track;
}

/// A receiving m-line, reduced to what binding actually needs.
///
/// Kept separate from [RTCRtpTransceiver] so the rule can be tested without a
/// live peer connection — the direction trap is a logic bug, and it should be
/// caught by a unit test rather than only by a device.
class StageReceivingLine {
  const StageReceivingLine({
    required this.mid,
    required this.direction,
    required this.receiverTrack,
  });

  final String? mid;
  final TransceiverDirection? direction;
  final MediaStreamTrack? receiverTrack;

  /// Whether this m-line is actually carrying somebody else's media.
  bool get isReceiving =>
      direction == TransceiverDirection.RecvOnly ||
      direction == TransceiverDirection.SendRecv;
}

/// Pure binding rule. See [bindRemoteMedia] for the peer-connection wrapper.
List<StageRemoteBinding> resolveRemoteBindings({
  required List<StageReceivingLine> lines,
  required List<Map<String, dynamic>> serverBindings,
}) {
  final byMid = <String, StageReceivingLine>{};
  for (final line in lines) {
    final mid = line.mid;
    // DIRECTION, not the presence of a receiver track — see the class comment.
    if (mid == null || !line.isReceiving || line.receiverTrack == null) continue;
    byMid[mid] = line;
  }

  final out = <StageRemoteBinding>[];
  for (final b in serverBindings) {
    final mid = b['mid'];
    if (mid == null) continue; // provider did not name an m-line
    final line = byMid['$mid'];
    if (line == null) continue; // negotiated but not receiving yet
    out.add(StageRemoteBinding(
      participantId: '${b['participantId']}',
      trackId: '${b['trackId']}',
      trackType: '${b['trackType']}',
      mid: '$mid',
      track: line.receiverTrack!,
    ));
  }
  return out;
}

/// Bind remote media on [pc] using the bindings Aura returned from subscribe.
///
/// Call this immediately after the subscribe renegotiation completes. There is
/// nothing to wait for: the transceivers exist as a result of applying the
/// remote description, which is precisely why this is deterministic.
Future<List<StageRemoteBinding>> bindRemoteMedia({
  required RTCPeerConnection pc,
  required List<Map<String, dynamic>> serverBindings,
}) async {
  final transceivers = await pc.getTransceivers();
  final lines = <StageReceivingLine>[];
  for (final t in transceivers) {
    TransceiverDirection? direction;
    try {
      direction = await t.getCurrentDirection();
    } catch (_) {
      // The synchronous `currentDirection` getter throws
      // UnimplementedError on this platform; an unreadable direction must not
      // be treated as "receiving", or the trap above reopens.
      direction = null;
    }
    lines.add(StageReceivingLine(
      mid: t.mid,
      direction: direction,
      receiverTrack: t.receiver.track,
    ));
  }
  return resolveRemoteBindings(lines: lines, serverBindings: serverBindings);
}
