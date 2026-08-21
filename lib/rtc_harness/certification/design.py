"""Switch the product tree between the negotiation designs under certification.

Each design is applied to a PRISTINE copy of the two product files, never on
top of another design. A certification run must be attributable to exactly one
tree, and layering patches is how that guarantee gets lost.

  python design.py baseline      # 4420602 + the read-only debugPeer probe
  python design.py legacy        # + 9815742 verbatim (the reverted outage)
  python design.py optionA       # + the single-authority recovery candidate
"""
import io
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
CTRL = os.path.join(REPO, 'lib', 'features', 'realtime', 'application',
                    'realtime_controller.dart')
MEDIA = os.path.join(REPO, 'lib', 'features', 'realtime', 'data',
                     'realtime_media_service.dart')
PRISTINE = os.path.join(HERE, 'pristine')


def read(path):
    return io.open(path, encoding='utf-8', newline='').read()


def write(path, text):
    io.open(path, 'w', encoding='utf-8', newline='').write(text)


def restore():
    # Snapshots carry a .snapshot suffix so the analyzer never treats a second
    # copy of the controller as live source in this package.
    shutil.copy(os.path.join(PRISTINE, 'realtime_controller.dart.snapshot'), CTRL)
    shutil.copy(os.path.join(PRISTINE, 'realtime_media_service.dart.snapshot'), MEDIA)


def insert_before(text, anchor, block, label):
    if anchor not in text:
        raise SystemExit('anchor missing for %s: %r' % (label, anchor[:60]))
    return text.replace(anchor, block + anchor, 1)


def insert_after(text, anchor, block, label):
    if anchor not in text:
        raise SystemExit('anchor missing for %s: %r' % (label, anchor[:60]))
    return text.replace(anchor, anchor + block, 1)


# ── LEGACY: 9815742 verbatim, minus the debugPeer probe (already in pristine) ─

LEGACY_MEDIA_TOP = '''/// Which track KINDS a peer is missing and must therefore be given.
///
/// Compared by KIND, never by track identity: a peer already sending video is
/// satisfied even if it is a different track (a switched device, or a screen
/// share standing in for the camera). Re-adding would create a duplicate
/// m-line and a pointless renegotiation on every ordinary join.
Set<String> missingSenderKinds({
  required Set<String> presentKinds,
  required List<String> localKinds,
}) {
  return localKinds
      .where((k) => k.isNotEmpty && !presentKinds.contains(k))
      .toSet();
}

/// Why a peer may or may not be repaired.
enum PeerRepairVerdict {
  repair,
  waitMedia,
  waitRemoteDescription,
  waitNegotiation,
  healthy,
}

PeerRepairVerdict evaluatePeerRepair({
  required bool localMediaReady,
  required bool remoteDescriptionSet,
  required bool signallingStable,
  required bool makingOffer,
  required Set<String> presentKinds,
  required List<String> localKinds,
}) {
  if (!localMediaReady) return PeerRepairVerdict.waitMedia;
  if (!remoteDescriptionSet) return PeerRepairVerdict.waitRemoteDescription;
  if (makingOffer || !signallingStable) return PeerRepairVerdict.waitNegotiation;
  if (missingSenderKinds(presentKinds: presentKinds, localKinds: localKinds)
      .isEmpty) {
    return PeerRepairVerdict.healthy;
  }
  return PeerRepairVerdict.repair;
}

'''

LEGACY_MEDIA_METHODS = '''  Future<PeerRepairVerdict> peerRepairVerdict(String peerKey) async {
    final connection = _peers[peerKey];
    if (connection == null) return PeerRepairVerdict.waitNegotiation;

    final localReady = _localStream != null && _mediaAcquisition == null;

    Set<String> presentKinds = <String>{};
    try {
      final senders = await connection.getSenders();
      presentKinds = senders
          .map((s) => s.track?.kind)
          .whereType<String>()
          .where((k) => k.isNotEmpty)
          .toSet();
    } catch (_) {
      return PeerRepairVerdict.waitNegotiation;
    }

    return evaluatePeerRepair(
      localMediaReady: localReady,
      remoteDescriptionSet: _remoteDescriptionSet.contains(peerKey),
      signallingStable: connection.signalingState ==
          RTCSignalingState.RTCSignalingStateStable,
      makingOffer: _makingOffer[peerKey] == true,
      presentKinds: presentKinds,
      localKinds:
          (_localStream?.getTracks() ?? const <MediaStreamTrack>[])
              .map((t) => t.kind ?? '')
              .toList(),
    );
  }

  /// Give local tracks to peers that are GENUINELY stale, and only those.
  Future<List<String>> repairSilentPeers() async {
    if (_disposed || _localStream == null) return const <String>[];
    final local = _localStream!;
    final repaired = <String>[];

    for (final entry in _peers.entries) {
      final peerKey = entry.key;
      final verdict = await peerRepairVerdict(peerKey);
      if (verdict != PeerRepairVerdict.repair) {
        debugPrint('[rtc-repair] skip peer=$peerKey verdict=${verdict.name}');
        continue;
      }

      final connection = entry.value;
      Set<String> present;
      try {
        final senders = await connection.getSenders();
        present = senders
            .map((s) => s.track?.kind)
            .whereType<String>()
            .where((k) => k.isNotEmpty)
            .toSet();
      } catch (error) {
        debugPrint('[rtc-repair] getSenders failed peer=$peerKey err=$error');
        continue;
      }

      final wanted = missingSenderKinds(
        presentKinds: present,
        localKinds: local.getTracks().map((t) => t.kind ?? '').toList(),
      );
      var added = false;
      for (final track in local.getTracks()) {
        final kind = track.kind ?? '';
        if (!wanted.contains(kind) || present.contains(kind)) continue;
        try {
          await connection.addTrack(track, local);
          present.add(kind);
          added = true;
          debugPrint('[rtc-repair] added $kind peer=$peerKey');
        } catch (error) {
          debugPrint('[rtc-repair] addTrack FAILED $kind peer=$peerKey err=$error');
        }
      }
      if (added) repaired.add(peerKey);
    }
    return repaired;
  }

'''

LEGACY_CTRL_CALL = '''
    // ── SILENT-PEER REPAIR (9815742, reverted at 4420602) ────────────────────
    unawaited(_repairSilentPeersIfAny());
'''

LEGACY_CTRL_METHOD = '''  /// Repair peers that are genuinely stale, then re-offer to those peers only.
  Future<void> _repairSilentPeersIfAny() async {
    if (!state.isJoined) return;
    try {
      final repaired = await _mediaService.repairSilentPeers();
      if (repaired.isEmpty) return;
      debugPrint('[rtc-repair] repaired ${repaired.length} peer(s); re-offering');
      for (final peerKey in repaired) {
        if (!_mediaService.hasPeer(peerKey)) continue;
        try {
          await _sendOfferToSocket(peerKey: peerKey, targetSocketId: peerKey);
        } catch (error) {
          debugPrint('[rtc-repair] re-offer failed peer=$peerKey err=$error');
        }
      }
    } catch (error) {
      debugPrint('[rtc-repair] sweep failed err=$error');
    }
  }

'''

MEDIA_TOP_ANCHOR = 'class RealtimeMediaService {'
MEDIA_METHOD_ANCHOR = '  Future<RTCPeerConnection> _ensurePeer({'
CTRL_CALL_ANCHOR = """      debugPrint('[join-seq] 6 first heartbeat sent sessionId=$sessionId');
    }
"""
CTRL_METHOD_ANCHOR = '''  /// Renegotiate with every peer we already hold a connection to (track'''


def apply_legacy():
    media = read(MEDIA)
    media = insert_before(media, MEDIA_TOP_ANCHOR, LEGACY_MEDIA_TOP, 'legacy media top')
    media = insert_before(media, MEDIA_METHOD_ANCHOR, LEGACY_MEDIA_METHODS,
                          'legacy media methods')
    write(MEDIA, media)

    ctrl = read(CTRL)
    ctrl = insert_after(ctrl, CTRL_CALL_ANCHOR, LEGACY_CTRL_CALL, 'legacy ctrl call')
    ctrl = insert_before(ctrl, CTRL_METHOD_ANCHOR, LEGACY_CTRL_METHOD,
                         'legacy ctrl method')
    write(CTRL, ctrl)


DESIGNS = {'baseline': lambda: None, 'legacy': apply_legacy}


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in DESIGNS:
        raise SystemExit('usage: design.py {%s}' % '|'.join(DESIGNS))
    restore()
    DESIGNS[sys.argv[1]]()
    print('applied design: %s' % sys.argv[1])


if __name__ == '__main__':
    main()
