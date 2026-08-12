/// Realtime Architecture Correction — Phase 0 canonical contract.
///
/// Dart mirror of aura-backend/src/realtime/canonical/device-socket-binding.ts.
///
/// Target layering:
///   LOGICAL PARTICIPANT   = (sessionId, userId)         — durable
///     -> DEVICE BINDING    = (participantId, deviceId)   — durable
///         -> SOCKET BINDING = (deviceId, socketId)        — ephemeral
///             -> MEDIA OWNERSHIP = which binding may publish
///
/// PHASE 0 SCOPE: defines the target shape and pure media-ownership-claim
/// logic only. Does not touch any real device registry.
library;

class CanonicalDeviceBinding {
  final String participantId;
  final String deviceId;
  /// Null when no socket is currently connected for this device.
  final String? socketId;
  /// True if this binding currently holds media-publish ownership. At most one binding per participant may be true.
  final bool isMediaOwner;
  /// Last heartbeat/activity timestamp, epoch millis.
  final int lastSeenAt;

  const CanonicalDeviceBinding({
    required this.participantId,
    required this.deviceId,
    required this.socketId,
    required this.isMediaOwner,
    required this.lastSeenAt,
  });

  CanonicalDeviceBinding copyWith({
    String? socketId,
    bool clearSocketId = false,
    bool? isMediaOwner,
    int? lastSeenAt,
  }) {
    return CanonicalDeviceBinding(
      participantId: participantId,
      deviceId: deviceId,
      socketId: clearSocketId ? null : (socketId ?? this.socketId),
      isMediaOwner: isMediaOwner ?? this.isMediaOwner,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }
}

class MediaOwnershipClaimResult {
  final String ownerDeviceId;
  final List<CanonicalDeviceBinding> bindings;

  const MediaOwnershipClaimResult({required this.ownerDeviceId, required this.bindings});
}

/// Pure media-ownership claim resolution — first-action-wins. A binding
/// may claim ownership only if no OTHER binding for the same participant
/// currently holds it, or if the current owner's lastSeenAt is older than
/// [staleAfterMs] (handles a crashed device never releasing its claim).
MediaOwnershipClaimResult resolveMediaOwnershipClaim(
  List<CanonicalDeviceBinding> bindings,
  String claimantDeviceId,
  int now,
  int staleAfterMs,
) {
  CanonicalDeviceBinding? currentOwner;
  for (final b in bindings) {
    if (b.isMediaOwner) currentOwner = b;
  }
  final claimantExists = bindings.any((b) => b.deviceId == claimantDeviceId);
  if (!claimantExists) {
    throw StateError('Unknown device binding: $claimantDeviceId');
  }

  final ownerIsStale =
      currentOwner != null && (now - currentOwner.lastSeenAt) > staleAfterMs;

  if (currentOwner == null || currentOwner.deviceId == claimantDeviceId || ownerIsStale) {
    final next = bindings
        .map((b) => b.copyWith(isMediaOwner: b.deviceId == claimantDeviceId))
        .toList();
    return MediaOwnershipClaimResult(ownerDeviceId: claimantDeviceId, bindings: next);
  }

  return MediaOwnershipClaimResult(
    ownerDeviceId: currentOwner.deviceId,
    bindings: List.of(bindings),
  );
}

/// SOCKET DEPARTURE != HUMAN DEPARTURE, made mechanical: a socket binding
/// disappearing never by itself implies the logical participant should
/// transition to left. Callers must consult whether ANY device binding
/// for the participant still has a live socket, or is within its
/// reconnect grace window, before treating a single socket's departure
/// as participant-level departure.
bool hasAnyLiveOrRecoverableSocket(
  List<CanonicalDeviceBinding> bindings,
  int now,
  int graceMs,
) {
  return bindings.any((b) => b.socketId != null || (now - b.lastSeenAt) <= graceMs);
}
