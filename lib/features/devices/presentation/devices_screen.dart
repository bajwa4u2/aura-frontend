import 'package:flutter/material.dart';

import '../../../core/product/temporal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../device_model.dart';
import '../device_providers.dart';

/// Advanced Device Preference / Transfer — item 12.
///
/// Lets a member see every device registered for push/call delivery,
/// revoke one they no longer use, and designate a single preferred
/// device. This is preference capture only — it does not change today's
/// ring-all delivery behavior (see `PushNotificationService.sendToUser`'s
/// own doc comment); that remains the separately-tracked, still-open
/// founder ring-policy decision. Full mid-call device transfer (moving an
/// active call from one device to another) is confirmed genuinely
/// greenfield and is its own, separately-scoped future item — not
/// attempted here.
final _myDevicesProvider = FutureProvider.autoDispose<List<UserDevice>>((
  ref,
) async {
  final repo = ref.watch(deviceRepositoryProvider);
  return repo.getMyDevices();
});

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  String? _busyDeviceId;

  Future<void> _setPreferred(UserDevice device) async {
    setState(() => _busyDeviceId = device.id);
    try {
      await ref
          .read(deviceRepositoryProvider)
          .updateDevice(device.id, {'isPreferred': true});
      ref.invalidate(_myDevicesProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update that device. $e')),
      );
    } finally {
      if (mounted) setState(() => _busyDeviceId = null);
    }
  }

  Future<void> _revoke(UserDevice device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AuraSurface.card,
        title: const Text('Remove this device?'),
        content: Text(
          '${_deviceLabel(device)} will stop receiving notifications and '
          "calls. You can register it again by signing in on it.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyDeviceId = device.id);
    try {
      await ref.read(deviceRepositoryProvider).revokeDevice(device.id);
      ref.invalidate(_myDevicesProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove that device. $e')),
      );
    } finally {
      if (mounted) setState(() => _busyDeviceId = null);
    }
  }

  String _deviceLabel(UserDevice device) {
    final name = (device.deviceName ?? '').trim();
    if (name.isNotEmpty) return name;
    final platform = (device.platform).trim();
    return platform.isNotEmpty ? platform : 'Unknown device';
  }

  IconData _platformIcon(String platform) {
    switch (platform.toUpperCase()) {
      case 'IOS':
        return Icons.phone_iphone_rounded;
      case 'ANDROID':
        return Icons.phone_android_rounded;
      case 'WEB':
        return Icons.language_rounded;
      case 'WINDOWS':
      case 'MACOS':
      case 'LINUX':
        return Icons.laptop_mac_rounded;
      default:
        return Icons.devices_other_rounded;
    }
  }

  String _lastSeenLabel(UserDevice device) {
    final raw = device.lastSeenAt;
    if (raw == null || raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    return 'Active ${AuraTemporal.humanize(ProductTime(dt, TimeEvent.occurred))}';
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(_myDevicesProvider);

    return AuraScaffold(
      // "Your devices" — the ones Aura can REACH you on.
      //
      // Three authorities were all called some version of "device": these
      // (push and calls), trusted devices (skip verification at sign-in), and
      // sessions (where you are signed in). Nothing in the product told them
      // apart, so each is now named for what it does.
      title: 'Your devices',
      body: devicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AuraSpace.s24),
            child: Text(
              'Could not load your devices. $e',
              style: AuraText.muted,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (devices) {
          final active = devices.where((d) => d.isActive).toList()
            ..sort((a, b) {
              if (a.isPreferred != b.isPreferred) {
                return a.isPreferred ? -1 : 1;
              }
              return (b.lastSeenAt ?? '').compareTo(a.lastSeenAt ?? '');
            });

          if (active.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AuraSpace.s24),
                child: Text(
                  'No devices yet. Sign in on a phone or desktop and it will '
                  'appear here.',
                  style: AuraText.muted,
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AuraSpace.s16),
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: AuraSpace.s12),
                child: Text(
                  'These devices receive your calls and notifications. '
                  'Mark one as preferred, or remove a device you no '
                  'longer use.',
                  style: AuraText.muted,
                ),
              ),
              for (final device in active)
                Padding(
                  padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                  child: _DeviceCard(
                    device: device,
                    icon: _platformIcon(device.platform),
                    label: _deviceLabel(device),
                    subtitle: _lastSeenLabel(device),
                    busy: _busyDeviceId == device.id,
                    onSetPreferred: device.isPreferred
                        ? null
                        : () => _setPreferred(device),
                    onRevoke: () => _revoke(device),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.busy,
    required this.onSetPreferred,
    required this.onRevoke,
  });

  final UserDevice device;
  final IconData icon;
  final String label;
  final String subtitle;
  final bool busy;
  final VoidCallback? onSetPreferred;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(
          color: device.isPreferred
              ? AuraSurface.coVerdant.withValues(alpha: 0.4)
              : AuraSurface.divider,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: device.isPreferred
                  ? AuraSurface.coVerdant.withValues(alpha: 0.16)
                  : AuraSurface.subtle,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 18,
              color: device.isPreferred
                  ? AuraSurface.coVerdant
                  : AuraSurface.faint,
            ),
          ),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: AuraText.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (device.isPreferred) ...[
                      const SizedBox(width: AuraSpace.s8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AuraSurface.coVerdant.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(AuraRadius.sm),
                        ),
                        child: Text(
                          'Preferred',
                          style: AuraText.micro.copyWith(
                            color: AuraSurface.coVerdant,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: AuraText.micro.copyWith(color: AuraSurface.muted)),
                ],
              ],
            ),
          ),
          if (busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            if (onSetPreferred != null)
              AuraSecondaryButton(
                label: 'Prefer',
                onPressed: onSetPreferred,
              ),
            const SizedBox(width: AuraSpace.s8),
            AuraSecondaryButton(label: 'Remove', onPressed: onRevoke),
          ],
        ],
      ),
    );
  }
}
