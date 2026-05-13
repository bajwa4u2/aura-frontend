import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'capability_tokens.dart';
import 'client_identity.dart';

/// Build-time overrides (defaults shown in fallback logic below):
///   --dart-define=AURA_DISTRIBUTION=android-play
///   --dart-define=AURA_CHANNEL=beta
///   --dart-define=AURA_PROTOCOL_GENERATION=1
///   --dart-define=AURA_EXTRA_CAPABILITIES=preview.tag.v1,other.thing.v2
const _kDistributionOverride =
    String.fromEnvironment('AURA_DISTRIBUTION', defaultValue: '');
const _kChannelOverride =
    String.fromEnvironment('AURA_CHANNEL', defaultValue: '');
const _kProtocolOverride =
    int.fromEnvironment('AURA_PROTOCOL_GENERATION', defaultValue: 1);
const _kExtraCapabilities =
    String.fromEnvironment('AURA_EXTRA_CAPABILITIES', defaultValue: '');

List<String> _resolveCapabilities() {
  final base = List<String>.of(defaultClientCapabilities);
  if (_kExtraCapabilities.trim().isEmpty) return base;
  for (final token in _kExtraCapabilities.split(',')) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) continue;
    if (base.contains(trimmed)) continue;
    base.add(trimmed);
  }
  return base;
}

ClientPlatform _detectPlatform() {
  if (kIsWeb) return ClientPlatform.web;
  try {
    if (Platform.isAndroid) return ClientPlatform.android;
    if (Platform.isIOS) return ClientPlatform.ios;
    if (Platform.isWindows) return ClientPlatform.windows;
    if (Platform.isMacOS) return ClientPlatform.macos;
    if (Platform.isLinux) return ClientPlatform.linux;
  } catch (_) {
    // Platform throws on web, but kIsWeb already handled that. Defensive.
  }
  return ClientPlatform.unknown;
}

/// Default distribution per platform when no AURA_DISTRIBUTION dart-define
/// is supplied. Android intentionally defaults to "android-direct" (sideload)
/// rather than "android-play" — Play Store builds must explicitly opt in via
/// `--dart-define=AURA_DISTRIBUTION=android-play` so an unflagged build is
/// never mistakenly governed as a Play release.
ClientDistribution _defaultDistribution(ClientPlatform platform) {
  switch (platform) {
    case ClientPlatform.web:
      return ClientDistribution.webProd;
    case ClientPlatform.android:
      return ClientDistribution.androidDirect;
    case ClientPlatform.windows:
      return ClientDistribution.windowsStore;
    case ClientPlatform.ios:
    case ClientPlatform.macos:
    case ClientPlatform.linux:
    case ClientPlatform.unknown:
      return ClientDistribution.unknown;
  }
}

/// SharedPreferences key for the stable per-install runtime device id.
///
/// Generated on first launch (UUIDv4-shaped random hex) and persisted
/// for the lifetime of the install. Sent to the backend as
/// `X-Aura-Device-Id`; the auth service uses it to coalesce same-
/// device login retries into a single UserSession row instead of
/// creating a new row per attempt.
///
/// Reset rules:
///   * Cleared on platform-managed app-data wipe (the OS owns this).
///   * NOT cleared on logout — logout revokes the server session but
///     the device-identity persists so the next sign-in coalesces
///     against the same logical device.
const _kRuntimeDeviceIdKey = 'aura_runtime_device_id';

/// Generate or load the stable per-install runtime device id.
/// Returns null on web, where we don't want to depend on
/// localStorage for security-relevant identity (the backend
/// treats null as "no canonical device" and falls back to the old
/// behavior of one session row per login — fine for browsers).
Future<String?> _resolveRuntimeDeviceId() async {
  if (kIsWeb) return null;
  try {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_kRuntimeDeviceIdKey)?.trim();
    if (existing != null && existing.isNotEmpty) return existing;
    final fresh = _generateRuntimeDeviceId();
    await prefs.setString(_kRuntimeDeviceIdKey, fresh);
    return fresh;
  } catch (_) {
    // SharedPreferences can fail in odd embedded contexts; degrade
    // silently to "no canonical device id" rather than crash auth.
    return null;
  }
}

/// 32-character hex string — same shape as a UUIDv4 with dashes
/// removed. Uses [Random.secure] so the value is unguessable by a
/// remote observer, even though the only thing the server uses it
/// for is grouping same-device sessions.
String _generateRuntimeDeviceId() {
  final rnd = Random.secure();
  final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
  final buf = StringBuffer();
  for (final b in bytes) {
    buf.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return buf.toString();
}

Future<ClientIdentity> _buildIdentity() async {
  final info = await PackageInfo.fromPlatform();
  final platform = _detectPlatform();

  final distribution = _kDistributionOverride.isNotEmpty
      ? ClientDistribution.fromWire(_kDistributionOverride)
      : _defaultDistribution(platform);

  final channel = _kChannelOverride.isNotEmpty
      ? ReleaseChannel.fromWire(_kChannelOverride)
      : ReleaseChannel.production;

  final buildNumber = int.tryParse(info.buildNumber.trim());
  final runtimeDeviceId = await _resolveRuntimeDeviceId();

  return ClientIdentity(
    appVersion: info.version.trim(),
    buildNumber: buildNumber,
    platform: platform,
    distribution: distribution,
    channel: channel,
    protocolGeneration: _kProtocolOverride,
    capabilities: _resolveCapabilities(),
    runtimeDeviceId: runtimeDeviceId,
    deviceLabel: null,
  );
}

/// Resolved at app startup. Other code paths (Dio interceptor, Socket.IO
/// handshake) read it via `clientIdentitySnapshotProvider` so they never
/// have to await.
final clientIdentityProvider = FutureProvider<ClientIdentity>((ref) async {
  return _buildIdentity();
});

/// Synchronous read of the resolved identity. Returns null until the
/// FutureProvider has completed bootstrap (typically a few ms after launch).
/// Callers that race the bootstrap simply omit the X-Aura-* headers — the
/// backend tolerates legacy clients and falls back to defaults.
final clientIdentitySnapshotProvider = Provider<ClientIdentity?>((ref) {
  final async = ref.watch(clientIdentityProvider);
  return async.maybeWhen(data: (id) => id, orElse: () => null);
});
