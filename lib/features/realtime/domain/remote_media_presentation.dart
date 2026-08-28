import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../data/stage_remote_binding.dart';

/// ONE CANONICAL MODEL OF WHOSE MEDIA IS ARRIVING.
///
/// Founder ruling, client migration §2 and §3. Presentation must be keyed by
/// canonical Aura participant identity, and mesh and SFU must not become two
/// permanent implementations of participant presentation.
///
/// So this is the only model the UI ever reads. Mesh and SFU are adapters into
/// it, and when mesh retires its adapter is deleted while the model and every
/// surface built on it stay exactly as they are.
///
/// ## Why the key changed
///
/// The shipped client keys remote media by `runtimeDeviceId` — a DEVICE, via
/// `Map<peerKey, RTCPeerConnection>` where `peerKey` is that device id. That
/// works only because mesh happens to build one peer connection per remote
/// device. Under SFU there is one peer connection in total, so a device-keyed
/// map has nothing to key on.
///
/// Participant identity is the thing both transports genuinely share, and it
/// is what the roster, the tiles and the authority model already speak.
class RemoteParticipantMedia {
  const RemoteParticipantMedia({
    required this.participantId,
    this.audio,
    this.video,
  });

  /// Canonical Aura participant id — `RealtimeParticipant.id`, the same
  /// identity the server resolves stage bindings to. Never a device id, never
  /// a provider id.
  final String participantId;

  final MediaStreamTrack? audio;
  final MediaStreamTrack? video;

  /// Whether a live video track is actually present.
  ///
  /// Deliberately derived from the TRACK rather than a roster `videoOn` hint.
  /// The roster flag can be stale-false when a peer's camera-on did not
  /// propagate, which previously hid real incoming video — the "host sees
  /// Camera off while the guest is on camera" defect. The received track is
  /// ground truth, and that stays true under both transports.
  bool get hasVideo => video != null;

  bool get hasAudio => audio != null;

  RemoteParticipantMedia copyWith({
    MediaStreamTrack? audio,
    MediaStreamTrack? video,
  }) =>
      RemoteParticipantMedia(
        participantId: participantId,
        audio: audio ?? this.audio,
        video: video ?? this.video,
      );
}

/// The roster facts an adapter needs, without dragging the whole model in.
class ParticipantRef {
  const ParticipantRef({
    required this.id,
    required this.userId,
    this.runtimeDeviceId,
  });

  final String id;
  final String userId;
  final String? runtimeDeviceId;
}

/// MESH ADAPTER — device-keyed streams resolved to participants.
///
/// Rollback path only. It exists so the canonical model can be populated by
/// the transport that is live today, which means the presentation refactor can
/// land and be verified BEFORE any transport changes underneath it.
///
/// A stream whose device is not in the roster is dropped rather than guessed
/// at. The old UI kept an "unclaimed renderer" fallback tile labelled
/// "Participant"; that belongs to presentation policy, not to this mapping,
/// and inventing an identity here would put an unnamed face in a tile.
Map<String, RemoteParticipantMedia> meshRemoteMedia({
  required Map<String, MediaStream> streamsByDeviceId,
  required List<ParticipantRef> roster,
  required String selfUserId,
}) {
  final byDevice = <String, ParticipantRef>{};
  for (final p in roster) {
    final device = (p.runtimeDeviceId ?? '').trim();
    if (device.isEmpty) continue;
    if (p.userId.trim() == selfUserId.trim()) continue;
    byDevice[device] = p;
  }

  final out = <String, RemoteParticipantMedia>{};
  streamsByDeviceId.forEach((device, stream) {
    final participant = byDevice[device.trim()];
    if (participant == null) return;
    final audio = stream.getAudioTracks();
    final video = stream.getVideoTracks();
    out[participant.id] = RemoteParticipantMedia(
      participantId: participant.id,
      audio: audio.isEmpty ? null : audio.first,
      video: video.isEmpty ? null : video.first,
    );
  });
  return out;
}

/// SFU ADAPTER — server-resolved bindings, already participant-keyed.
///
/// Nothing is inferred here. The server said which m-line carries whose track,
/// [bindRemoteMedia] confirmed that m-line is genuinely receiving, and this
/// only groups the result per participant.
Map<String, RemoteParticipantMedia> sfuRemoteMedia({
  required List<StageRemoteBinding> bindings,
}) {
  final out = <String, RemoteParticipantMedia>{};
  for (final b in bindings) {
    final existing = out[b.participantId] ??
        RemoteParticipantMedia(participantId: b.participantId);
    final isVideo = b.trackType.toUpperCase() == 'VIDEO' ||
        b.trackType.toUpperCase() == 'SCREEN' ||
        b.track.kind == 'video';
    out[b.participantId] = isVideo
        ? existing.copyWith(video: b.track)
        : existing.copyWith(audio: b.track);
  }
  return out;
}

/// Should a renderer nobody in the roster claims still be shown?
///
/// Remote media is keyed by device, so an unclaimed renderer means one of two
/// very different things:
///
///  * somebody is in the call but their device id has not been backfilled yet
///    — show it, or their media is dropped;
///  * somebody refreshed and rejoined with a NEW device id, leaving their
///    previous renderer under the old key — do NOT show it, or the same human
///    appears twice, once named and once as an anonymous "Participant".
///
/// The second was founder-observed on 2026-08-26 as "refreshing creates a new
/// participant for the same person". The distinguishing fact is whether anyone
/// is still awaiting attribution: if every other participant already has a
/// device id, an unclaimed renderer belongs to a connection that has already
/// been replaced.
bool shouldShowUnattributedMedia(List<ParticipantRef> others) =>
    others.any((p) => (p.runtimeDeviceId ?? '').trim().isEmpty);

/// WHERE A PARTICIPANT'S RENDERER LIVES — one rule, both transports.
///
/// Two maps carry remote renderers and they answer to different keys:
///
///  * [byParticipant] is canonical, keyed by Aura participant id, and is what
///    the STAGE transport populates. One peer connection, no devices.
///  * [byDevice] is keyed by `runtimeDeviceId` and is written only by the MESH
///    per-peer `onTrack` / `onAddStream` callbacks.
///
/// Participant identity is asked first and the device key is used only to
/// LOCATE mesh media for a person the roster has already named. That ordering
/// is the whole rule, and getting it backwards is not a cosmetic mistake:
/// iterating [byDevice] alone makes a surface structurally blind to the stage
/// transport, because under SFU that map is empty for the entire call.
///
/// Founder-observed 2026-08-28 on the conversation call screen — valid
/// Cloudflare bindings, both remote tracks bound to real receiving
/// transceivers, roster reading "Media on", and one tile on the stage. The
/// Meetings live room had already been migrated; this rule exists so the two
/// surfaces cannot drift apart again.
RTCVideoRenderer? rendererForParticipant({
  required ParticipantRef participant,
  required Map<String, RTCVideoRenderer> byParticipant,
  required Map<String, RTCVideoRenderer> byDevice,
}) {
  final canonical = byParticipant[participant.id];
  if (canonical != null) return canonical;
  final device = (participant.runtimeDeviceId ?? '').trim();
  if (device.isEmpty) return null;
  return byDevice[device];
}
