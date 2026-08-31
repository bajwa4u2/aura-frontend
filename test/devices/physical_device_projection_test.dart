import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/devices/device_model.dart';
import 'package:aura/features/devices/physical_device.dart';

/// ONE PHONE SHOULD LOOK LIKE ONE PHONE.
///
/// An iPhone registers twice, because a PushKit credential and an FCM
/// credential are genuinely different things. That is an implementation fact
/// and it was leaking into the product: the Devices screen listed one phone as
/// *"iPhone"* and *"iPhone (calls)"*, and marking either one "preferred" set a
/// routing preference over half a phone.
UserDevice _row({
  required String id,
  String? installationId,
  String? deviceName,
  String provider = 'FCM',
  String platform = 'IOS',
  bool isPreferred = false,
  bool isActive = true,
  String? lastSeenAt,
}) => UserDevice(
  id: id,
  userId: 'u1',
  platform: platform,
  provider: provider,
  installationId: installationId,
  deviceName: deviceName,
  isPreferred: isPreferred,
  isActive: isActive,
  lastSeenAt: lastSeenAt,
);

void main() {
  group('grouping registrations into phones', () {
    test('an iPhone with two registrations is ONE device', () {
      final phones = groupIntoPhysicalDevices([
        _row(id: 'fcm', installationId: 'i1', deviceName: 'iPhone', provider: 'FCM'),
        _row(
          id: 'apns',
          installationId: 'i1',
          deviceName: 'iPhone (calls)',
          provider: 'APNS',
        ),
      ]);

      expect(phones, hasLength(1));
      expect(phones.single.endpoints, hasLength(2));
      expect(physicalDeviceLabel(phones.single), 'iPhone');
    });

    test('the calls suffix never becomes the name of the phone', () {
      // Even if the VoIP row is the only one that survived, or comes first.
      final phones = groupIntoPhysicalDevices([
        _row(
          id: 'apns',
          installationId: 'i1',
          deviceName: 'iPhone (calls)',
          provider: 'APNS',
        ),
      ]);
      expect(physicalDeviceLabel(phones.single), 'iPhone');
    });

    test('two different phones stay two devices', () {
      final phones = groupIntoPhysicalDevices([
        _row(id: 'a-fcm', installationId: 'i1', deviceName: 'iPhone'),
        _row(id: 'a-apns', installationId: 'i1', deviceName: 'iPhone (calls)'),
        _row(id: 'b-fcm', installationId: 'i2', deviceName: 'iPhone'),
        _row(id: 'b-apns', installationId: 'i2', deviceName: 'iPhone (calls)'),
      ]);
      expect(phones, hasLength(2));
    });

    test('two identical iPhones are NOT merged by their shared name', () {
      // The exact reason grouping is by installation and not by device name:
      // a person with two iPhone 15s would otherwise lose one of them.
      final phones = groupIntoPhysicalDevices([
        _row(id: 'a', installationId: 'i1', deviceName: 'iPhone'),
        _row(id: 'b', installationId: 'i2', deviceName: 'iPhone'),
      ]);
      expect(phones, hasLength(2));
    });

    test('registrations with no installation id are each their own phone', () {
      // Rows written before the field existed. Previous behaviour, preserved.
      final phones = groupIntoPhysicalDevices([
        _row(id: 'legacy-1', deviceName: 'iPhone'),
        _row(id: 'legacy-2', deviceName: 'iPhone (calls)'),
      ]);
      expect(phones, hasLength(2));
    });

    test('input order is preserved so the caller still decides the sort', () {
      final phones = groupIntoPhysicalDevices([
        _row(id: 'b', installationId: 'i2', deviceName: 'Pixel'),
        _row(id: 'a', installationId: 'i1', deviceName: 'iPhone'),
      ]);
      expect(phones.map(physicalDeviceLabel), ['Pixel', 'iPhone']);
    });

    test('a phone with no name at all falls back to its platform', () {
      final phones = groupIntoPhysicalDevices([
        _row(id: 'x', installationId: 'i1', platform: 'WINDOWS'),
      ]);
      expect(physicalDeviceLabel(phones.single), 'WINDOWS');
    });
  });

  group('preference belongs to the phone', () {
    test('a preference on either registration makes the PHONE preferred', () {
      for (final preferred in ['fcm', 'apns']) {
        final phones = groupIntoPhysicalDevices([
          _row(
            id: 'fcm',
            installationId: 'i1',
            deviceName: 'iPhone',
            isPreferred: preferred == 'fcm',
          ),
          _row(
            id: 'apns',
            installationId: 'i1',
            deviceName: 'iPhone (calls)',
            provider: 'APNS',
            isPreferred: preferred == 'apns',
          ),
        ]);
        expect(
          phones.single.isPreferred,
          isTrue,
          reason: 'preferring $preferred means preferring the iPhone',
        );
      }
    });

    test('a phone with no preferred registration is not preferred', () {
      final phones = groupIntoPhysicalDevices([
        _row(id: 'fcm', installationId: 'i1', deviceName: 'iPhone'),
      ]);
      expect(phones.single.isPreferred, isFalse);
    });
  });

  group('removing a phone removes all of it', () {
    test('every registration is revocable, not just the visible one', () {
      // Revoking one endpoint would leave the other half registered and still
      // receiving — a phone the person believes they removed, still ringing.
      final phones = groupIntoPhysicalDevices([
        _row(id: 'fcm', installationId: 'i1', deviceName: 'iPhone'),
        _row(
          id: 'apns',
          installationId: 'i1',
          deviceName: 'iPhone (calls)',
          provider: 'APNS',
        ),
      ]);
      expect(phones.single.revocableIds, containsAll(['fcm', 'apns']));
      expect(phones.single.revocableIds, hasLength(2));
    });
  });

  group('the phone reports its own freshness and transports', () {
    test('last seen is the most recent across every transport', () {
      final phones = groupIntoPhysicalDevices([
        _row(
          id: 'fcm',
          installationId: 'i1',
          deviceName: 'iPhone',
          lastSeenAt: '2026-08-30T10:00:00Z',
        ),
        _row(
          id: 'apns',
          installationId: 'i1',
          deviceName: 'iPhone (calls)',
          provider: 'APNS',
          lastSeenAt: '2026-08-31T10:00:00Z',
        ),
      ]);
      expect(phones.single.lastSeenAt, '2026-08-31T10:00:00Z');
    });

    test('transport detail is kept available for diagnostics', () {
      // Grouping is a projection, not a merge: the credentials underneath are
      // real and operational work still needs to see them.
      final phones = groupIntoPhysicalDevices([
        _row(id: 'fcm', installationId: 'i1', deviceName: 'iPhone'),
        _row(
          id: 'apns',
          installationId: 'i1',
          deviceName: 'iPhone (calls)',
          provider: 'APNS',
        ),
      ]);
      expect(phones.single.transportSummary, 'FCM + APNS');
    });
  });
}
