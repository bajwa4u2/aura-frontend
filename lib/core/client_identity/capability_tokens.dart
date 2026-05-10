/// Capability token registry — Slice D (Phase 5) of the cross-platform
/// release governance system. Mirrors
/// `aura-backend/src/platform/client-identity/capabilities.ts` exactly.
///
/// Capabilities are versioned strings the app advertises so the backend
/// can route per-feature behavior without relying on the version number.
/// The list returned by `defaultClientCapabilities()` is what every binary
/// build of this version of the app objectively supports.
///
/// Slice D scope: capability advertisement is observability-only. The
/// backend captures adoption rates but does not hard-block any feature on
/// a missing capability yet.
library;

class ClientCapabilities {
  const ClientCapabilities._();

  /// Slice A — canonical client identity contract (X-Aura-* headers).
  static const String clientIdentityV1 = 'client-identity.v1';

  /// Slice B — client honors /v1/client/compatibility verdicts.
  static const String releaseGovernanceCompatibilityV1 =
      'release-governance.compatibility.v1';

  /// Slice C — client renders the UpdateGate UX
  /// (banner / blocking / maintenance).
  static const String releaseGovernanceUpdateGateV1 =
      'release-governance.update-gate.v1';

  /// Slice C — client honors realtime `protocol:incompatible` close events.
  static const String realtimeProtocolGateV1 = 'realtime.protocol-gate.v1';
}

/// Capabilities every release of this app build supports. Build-time
/// dart-defines could extend this list (e.g. `--dart-define=AURA_CAPS=foo,bar`)
/// — see `clientIdentityProvider` for the merge logic.
const List<String> defaultClientCapabilities = <String>[
  ClientCapabilities.clientIdentityV1,
  ClientCapabilities.releaseGovernanceCompatibilityV1,
  ClientCapabilities.releaseGovernanceUpdateGateV1,
  ClientCapabilities.realtimeProtocolGateV1,
];
