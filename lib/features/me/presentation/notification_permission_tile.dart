import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../devices/device_providers.dart';
import '../../devices/web_push_service.dart';

/// "Browser notifications" section added to the security screen on web.
/// Hidden on non-web platforms via [kIsWeb] guard.
class BrowserNotificationsSection extends ConsumerStatefulWidget {
  const BrowserNotificationsSection({super.key});

  @override
  ConsumerState<BrowserNotificationsSection> createState() =>
      _BrowserNotificationsSectionState();
}

class _BrowserNotificationsSectionState
    extends ConsumerState<BrowserNotificationsSection> {
  String _permission = 'default';
  bool _supported = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _supported = WebPushService.isSupported;
      _permission = WebPushService.permission;
    }
  }

  Future<void> _requestAndEnable() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final vapidKey = AppConfig.vapidPublicKey;
      final granted = await ref
          .read(deviceServiceProvider)
          .requestAndRegisterWebPush(vapidKey);
      if (mounted) {
        setState(() {
          _permission = WebPushService.permission;
          _busy = false;
        });
        if (granted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Browser notifications enabled')),
          );
        }
      }
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: AuraSpace.s10),
          child: Text('Browser notifications', style: AuraText.title),
        ),
        AuraCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s16,
            vertical: AuraSpace.s14,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.notifications_outlined,
                size: 18,
                color: AuraSurface.ink,
              ),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Push notifications',
                      style: AuraText.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _statusSubtitle,
                      style: AuraText.small.copyWith(
                        color: AuraSurface.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AuraSpace.s12),
              _trailingWidget,
            ],
          ),
        ),
        if (_permission == 'denied')
          Padding(
            padding: const EdgeInsets.only(top: AuraSpace.s8),
            child: Text(
              'Notifications are blocked by your browser. To enable them, '
              'click the lock icon in your address bar and allow notifications '
              'for this site, then reload the page.',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
          ),
      ],
    );
  }

  String get _statusSubtitle {
    if (!_supported) return 'Not supported in this browser';
    switch (_permission) {
      case 'granted':
        return 'Receive notifications when the app is in the background';
      case 'denied':
        return 'Blocked — change your browser settings to enable';
      default:
        return 'Get notified about messages and calls even when the tab is closed';
    }
  }

  Widget get _trailingWidget {
    if (!_supported) {
      return Text(
        'Unavailable',
        style: AuraText.small.copyWith(
          color: AuraSurface.faint,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    if (_permission == 'granted') {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s10,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: AuraSurface.goodBg,
          borderRadius: BorderRadius.circular(AuraRadius.pill),
        ),
        child: Text(
          'Active',
          style: AuraText.small.copyWith(
            color: AuraSurface.goodInk,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    if (_permission == 'denied') {
      return Text(
        'Blocked',
        style: AuraText.small.copyWith(
          color: AuraSurface.dangerInk,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    // 'default' or unknown — show enable button
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _busy ? null : _requestAndEnable,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s12,
            vertical: AuraSpace.s6,
          ),
          decoration: BoxDecoration(
            color: AuraSurface.accentSoft,
            borderRadius: BorderRadius.circular(AuraRadius.r10),
            border: Border.all(
              color: AuraSurface.accent.withValues(alpha: 0.4),
            ),
          ),
          child: _busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  'Enable',
                  style: AuraText.small.copyWith(
                    color: AuraSurface.accentText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
