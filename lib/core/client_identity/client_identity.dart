/// Canonical client identity model — the contract every Aura backend caller
/// (HTTP and WebSocket) sends so the backend can govern per-distribution
/// rollouts, min-version enforcement, capability gating, and protocol
/// compatibility. Phase 2 of the cross-platform release governance system.
///
/// The model is built once at app startup and read synchronously thereafter.
/// See `client_identity_provider.dart` for the bootstrap path.
library;

/// Runtime OS the app is executing on.
enum ClientPlatform {
  web('web'),
  android('android'),
  ios('ios'),
  windows('windows'),
  macos('macos'),
  linux('linux'),
  unknown('unknown');

  const ClientPlatform(this.wireValue);

  /// Value sent on the X-Aura-Platform header.
  final String wireValue;
}

/// How this binary reached the user — drives compatibility gating and the
/// Update UX action (web reload vs store redirect vs direct download).
///
/// Distribution is set at build time via `--dart-define=AURA_DISTRIBUTION=...`.
/// Default values when no dart-define is provided:
///   web    → web-prod
///   android → android-direct  (override to android-play for Play builds)
///   windows → windows-store
/// Other platforms remain "unknown" until distribution flavors are added.
enum ClientDistribution {
  webProd('web-prod'),
  androidPlay('android-play'),
  androidDirect('android-direct'),
  windowsStore('windows-store'),
  unknown('unknown');

  const ClientDistribution(this.wireValue);

  final String wireValue;

  static ClientDistribution fromWire(String? raw) {
    if (raw == null) return ClientDistribution.unknown;
    for (final v in ClientDistribution.values) {
      if (v.wireValue == raw) return v;
    }
    return ClientDistribution.unknown;
  }
}

/// Release channel — orthogonal to distribution. The same Play build can
/// ship to production, beta, internal, or development tracks.
enum ReleaseChannel {
  production('production'),
  beta('beta'),
  internal('internal'),
  development('development');

  const ReleaseChannel(this.wireValue);

  final String wireValue;

  static ReleaseChannel fromWire(String? raw) {
    if (raw == null) return ReleaseChannel.production;
    for (final v in ReleaseChannel.values) {
      if (v.wireValue == raw) return v;
    }
    return ReleaseChannel.production;
  }
}

class ClientIdentity {
  const ClientIdentity({
    required this.appVersion,
    required this.buildNumber,
    required this.platform,
    required this.distribution,
    required this.channel,
    required this.protocolGeneration,
    required this.capabilities,
    required this.runtimeDeviceId,
    required this.deviceLabel,
  });

  final String appVersion;
  final int? buildNumber;
  final ClientPlatform platform;
  final ClientDistribution distribution;
  final ReleaseChannel channel;
  final int protocolGeneration;
  final List<String> capabilities;
  final String? runtimeDeviceId;
  final String? deviceLabel;

  /// HTTP header map. Values are formatted as the backend parser expects
  /// (lowercase enum wire values, decimal integers, csv capabilities).
  /// Empty/unknown fields are omitted so legacy proxies don't see junk.
  Map<String, String> toHttpHeaders() {
    final headers = <String, String>{};
    if (appVersion.isNotEmpty) {
      headers['X-Aura-App-Version'] = appVersion;
    }
    if (buildNumber != null) {
      headers['X-Aura-Build'] = buildNumber.toString();
    }
    if (platform != ClientPlatform.unknown) {
      headers['X-Aura-Platform'] = platform.wireValue;
    }
    if (distribution != ClientDistribution.unknown) {
      headers['X-Aura-Distribution'] = distribution.wireValue;
    }
    headers['X-Aura-Channel'] = channel.wireValue;
    headers['X-Aura-Protocol'] = protocolGeneration.toString();
    if (capabilities.isNotEmpty) {
      headers['X-Aura-Capabilities'] = capabilities.join(',');
    }
    if (runtimeDeviceId != null && runtimeDeviceId!.isNotEmpty) {
      headers['X-Aura-Device-Id'] = runtimeDeviceId!;
    }
    if (deviceLabel != null && deviceLabel!.isNotEmpty) {
      headers['X-Aura-Device-Label'] = deviceLabel!;
    }
    return headers;
  }

  /// Socket.IO handshake `auth` payload. Mirrors the HTTP header set so the
  /// backend's `parseFromWsHandshake` produces an identical ClientIdentity.
  Map<String, dynamic> toWsAuth() {
    final auth = <String, dynamic>{};
    if (appVersion.isNotEmpty) auth['appVersion'] = appVersion;
    if (buildNumber != null) auth['buildNumber'] = buildNumber.toString();
    if (platform != ClientPlatform.unknown) {
      auth['platform'] = platform.wireValue;
    }
    if (distribution != ClientDistribution.unknown) {
      auth['distribution'] = distribution.wireValue;
    }
    auth['channel'] = channel.wireValue;
    auth['protocolGeneration'] = protocolGeneration.toString();
    if (capabilities.isNotEmpty) {
      auth['capabilities'] = capabilities.join(',');
    }
    if (runtimeDeviceId != null && runtimeDeviceId!.isNotEmpty) {
      auth['deviceId'] = runtimeDeviceId!;
    }
    if (deviceLabel != null && deviceLabel!.isNotEmpty) {
      auth['deviceLabel'] = deviceLabel!;
    }
    return auth;
  }
}
