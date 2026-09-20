import '../data/realtime_media_service.dart';

/// THE `session:quality` WIRE PAYLOAD, built in one pure place.
///
/// Kept out of the controller so the one rule this contract turns on can be
/// asserted directly rather than inferred from a socket: **zero is a
/// measurement, absent is not.** A field measured as `0` is SENT as `0`; a
/// field that was not measured is OMITTED. The server stores `0` and `null`
/// respectively and never coerces one into the other.
///
/// That distinction is not pedantry. `audioBytesReceived: 0` means a receiving
/// audio track was negotiated and no packets ever arrived on it — the
/// one-way-audio defect reproduced three times in September and never
/// diagnosed, because the instrumentation summed audio and video together
/// before writing anything down. An omitted field means no such track existed
/// to measure. Merging them destroys the only evidence that separates a dead
/// stream from an absent one.
///
/// Contract: `aura-backend/docs/2026-09-19-call-quality-telemetry-contract.md`.
Map<String, dynamic> buildQualitySamplePayload({
  required String sessionId,
  required RealtimeQualitySample sample,
  required String appLifecycleState,
  required String reconnectState,
  required String clientPlatform,
  String? clientVersion,
}) {
  return <String, dynamic>{
    'sessionId': sessionId,

    // The four the heartbeat already carried, unchanged in meaning.
    if (sample.rttMs != null) 'rtt': sample.rttMs,
    if (sample.jitterMs != null) 'jitter': sample.jitterMs,
    if (sample.packetLossPct != null) 'packetLoss': sample.packetLossPct,
    if (sample.bitrateKbps != null) 'bitrateKbps': sample.bitrateKbps,

    // The path the media actually took. Absent where the platform withholds
    // it — some browsers refuse network type for fingerprinting reasons, and
    // a withheld fact is not UNKNOWN-the-measurement.
    if (sample.selectedCandidateType != null)
      'selectedCandidateType': sample.selectedCandidateType,
    if (sample.transportProtocol != null)
      'transportProtocol': sample.transportProtocol,
    if (sample.networkType != null) 'networkType': sample.networkType,

    // Bytes BY KIND, and frames, which are not bytes.
    if (sample.audioBytesReceived != null)
      'audioBytesReceived': sample.audioBytesReceived,
    if (sample.videoBytesReceived != null)
      'videoBytesReceived': sample.videoBytesReceived,
    if (sample.videoFramesDecoded != null)
      'videoFramesDecoded': sample.videoFramesDecoded,
    if (sample.videoFrameWidth != null)
      'videoFrameWidth': sample.videoFrameWidth,
    if (sample.videoFrameHeight != null)
      'videoFrameHeight': sample.videoFrameHeight,

    // What the connection and the app were doing while this was measured.
    // transportState is omitted on mesh, which has one connection per peer
    // and therefore no single state to report.
    if (sample.transportState != null) 'transportState': sample.transportState,
    'appLifecycleState': appLifecycleState,
    'reconnectState': reconnectState,

    // Which build produced the sample. Omitted until the package answers,
    // because a guessed version is worse than none: it would make one build
    // look like another in exactly the analysis this column exists for.
    if (clientVersion != null) 'clientVersion': clientVersion,
    'clientPlatform': clientPlatform,
  };
}
