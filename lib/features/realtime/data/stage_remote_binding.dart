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

/// WHY A BINDING WAS DROPPED.
///
/// resolveRemoteBindings discards a binding on three separate conditions and
/// says nothing about which. A client can receive two perfectly valid
/// bindings from Cloudflare -- correct provider session, correct track names,
/// real mids -- attach ZERO of them, and leave no trace at all. That silence
/// is why "Cloudflare returned valid bindings" and "the tile is black" could
/// both be true with nothing in between to inspect.
class StageBindingAudit {
  const StageBindingAudit({
    required this.serverBindings,
    required this.transceivers,
    required this.receivingLines,
    required this.bound,
    required this.droppedNoMid,
    required this.droppedNoMatchingLine,
    required this.directionUnreadable,
    required this.receiverTrackNull,
  });

  final int serverBindings;
  final int transceivers;
  final int receivingLines;
  final int bound;

  /// Provider named no m-line for this track.
  final int droppedNoMid;

  /// The named mid matched no transceiver that is receiving with a track.
  final int droppedNoMatchingLine;

  /// getCurrentDirection() threw, so the line could not be called receiving.
  /// On a platform where this throws, EVERY remote binding is dropped.
  final int directionUnreadable;

  /// Transceiver exists and is receiving, but carries no receiver track.
  final int receiverTrackNull;

  String get summary =>
      'server=$serverBindings transceivers=$transceivers '
      'receiving=$receivingLines bound=$bound '
      'noMid=$droppedNoMid noLine=$droppedNoMatchingLine '
      'dirUnreadable=$directionUnreadable noTrack=$receiverTrackNull';
}

/// Audit the same rule [resolveRemoteBindings] applies, without changing it.
///
/// Deliberately a SEPARATE function: the binding rule is on the media hot path
/// and is not altered tocarry diagnostics.
StageBindingAudit auditRemoteBindings({
  required List<StageReceivingLine> lines,
  required List<Map<String, dynamic>> serverBindings,
}) {
  var directionUnreadable = 0;
  var receiverTrackNull = 0;
  final byMid = <String, StageReceivingLine>{};
  for (final line in lines) {
    if (line.direction == null) directionUnreadable++;
    if (line.receiverTrack == null) receiverTrackNull++;
    final mid = line.mid;
    if (mid == null || !line.isReceiving || line.receiverTrack == null) continue;
    byMid[mid] = line;
  }

  var noMid = 0;
  var noLine = 0;
  var bound = 0;
  for (final b in serverBindings) {
    final mid = b['mid'];
    if (mid == null) {
      noMid++;
      continue;
    }
    if (byMid['$mid'] == null) {
      noLine++;
      continue;
    }
    bound++;
  }

  return StageBindingAudit(
    serverBindings: serverBindings.length,
    transceivers: lines.length,
    receivingLines: byMid.length,
    bound: bound,
    droppedNoMid: noMid,
    droppedNoMatchingLine: noLine,
    directionUnreadable: directionUnreadable,
    receiverTrackNull: receiverTrackNull,
  );
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
  lastReceivingLines = lines;
  return resolveRemoteBindings(lines: lines, serverBindings: serverBindings);
}

/// The transceiver snapshot from the most recent [bindRemoteMedia] call,
/// so the caller can audit WHY bindings were dropped without asking the
/// peer connection a second time and racing its state.
List<StageReceivingLine> lastReceivingLines = const [];
