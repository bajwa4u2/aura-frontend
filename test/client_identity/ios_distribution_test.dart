import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/client_identity/client_identity.dart';

/// iOS is a first-class distribution on the wire.
///
/// It previously resolved to `unknown`, the same value macOS, Linux and any
/// unresolved client send. Release governance selects a policy row by
/// (distribution, channel), so gating iOS through `unknown` would have gated
/// everything unresolved with it, and would have made it impossible to release
/// one native platform ahead of the other.
void main() {
  group('ClientDistribution', () {
    test('names iOS, and round-trips it on the wire', () {
      expect(ClientDistribution.ios.wireValue, 'ios');
      expect(ClientDistribution.fromWire('ios'), ClientDistribution.ios);
    });

    test('keeps unknown meaning unresolved, not iOS', () {
      expect(ClientDistribution.fromWire(null), ClientDistribution.unknown);
      expect(
        ClientDistribution.fromWire('something-else'),
        ClientDistribution.unknown,
      );
      expect(ClientDistribution.unknown.wireValue, isNot('ios'));
    });

    test('leaves the other distributions exactly as they were', () {
      expect(ClientDistribution.webProd.wireValue, 'web-prod');
      expect(ClientDistribution.androidPlay.wireValue, 'android-play');
      expect(ClientDistribution.androidDirect.wireValue, 'android-direct');
      expect(ClientDistribution.windowsStore.wireValue, 'windows-store');
    });
  });

  group('the identity an iOS build sends', () {
    test('carries ios on both the platform and the distribution header', () {
      final identity = ClientIdentity(
        appVersion: '1.3.0',
        buildNumber: 24,
        platform: ClientPlatform.ios,
        distribution: ClientDistribution.ios,
        channel: ReleaseChannel.production,
        protocolGeneration: 1,
        capabilities: const [],
        runtimeDeviceId: null,
        deviceLabel: null,
      );

      final headers = identity.toHttpHeaders();

      expect(headers['X-Aura-Platform'], 'ios');
      expect(headers['X-Aura-Distribution'], 'ios');
      expect(headers['X-Aura-App-Version'], '1.3.0');
      expect(headers['X-Aura-Build'], '24');
      expect(headers['X-Aura-Channel'], 'production');
    });
  });
}
