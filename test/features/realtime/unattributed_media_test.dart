import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/realtime/domain/remote_media_presentation.dart';

/// "Why does refreshing create a new participant for the same person?"
/// Founder-observed 2026-08-26. It did not create a participant — the roster
/// holds one row per person and re-joining three times still produces one.
/// It created a TILE, because a refreshed peer rejoins with a new device id
/// and its old renderer lingers under the old key.
void main() {
  group('an unclaimed renderer is only shown while attribution is pending', () {
    test('shown when somebody has no device id yet', () {
      expect(
        shouldShowUnattributedMedia(const [
          ParticipantRef(id: 'p1', userId: 'alice', runtimeDeviceId: null),
        ]),
        isTrue,
        reason: 'media must not be dropped while the roster backfills',
      );
      expect(
        shouldShowUnattributedMedia(const [
          ParticipantRef(id: 'p1', userId: 'alice', runtimeDeviceId: '   '),
        ]),
        isTrue,
      );
    });

    test('NOT shown when everybody is already attributed', () {
      // The refresh case: alice is present with a fresh device id, and the
      // leftover renderer under her previous key must not become a second
      // anonymous tile.
      expect(
        shouldShowUnattributedMedia(const [
          ParticipantRef(id: 'p1', userId: 'alice', runtimeDeviceId: 'device-new'),
        ]),
        isFalse,
        reason: 'a stale device is not a new person',
      );
    });

    test('an empty room shows nothing unattributed', () {
      expect(shouldShowUnattributedMedia(const []), isFalse);
    });

    test('one pending attribution is enough to keep showing media', () {
      expect(
        shouldShowUnattributedMedia(const [
          ParticipantRef(id: 'p1', userId: 'alice', runtimeDeviceId: 'device-a'),
          ParticipantRef(id: 'p2', userId: 'bob', runtimeDeviceId: null),
        ]),
        isTrue,
      );
    });
  });
}
