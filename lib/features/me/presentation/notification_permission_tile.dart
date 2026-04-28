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

// ── State ─────────────────────────────────────────────────────────────────────

enum _SubState {
  /// Checking for an existing subscription in the background.
  loading,

  /// Permission granted and a valid push subscription is active.
  active,

  /// Permission is default — user hasn't been asked yet.
  defaultPerm,

  /// Permission was granted but subscription acquisition failed
  /// (InPrivate, VAPID error, SW error, etc.).
  failed,

  /// Browser has blocked notifications.
  blocked,

  /// Browser / platform doesn't support Web Push.
  unsupported,
}

// ── Widget ────────────────────────────────────────────────────────────────────

/// Browser notification section shown on web inside the security screen.
/// Hidden on non-web platforms.
class BrowserNotificationsSection extends ConsumerStatefulWidget {
  const BrowserNotificationsSection({super.key});

  @override
  ConsumerState<BrowserNotificationsSection> createState() =>
      _BrowserNotificationsSectionState();
}

class _BrowserNotificationsSectionState
    extends ConsumerState<BrowserNotificationsSection> {
  _SubState _state = _SubState.loading;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _resolveInitialState();
    }
  }

  /// Determines the real initial state:
  ///  - not supported → unsupported
  ///  - permission denied → blocked
  ///  - permission default → defaultPerm
  ///  - permission granted → check if an active subscription actually exists
  Future<void> _resolveInitialState() async {
    if (!WebPushService.isSupported) {
      if (mounted) setState(() => _state = _SubState.unsupported);
      return;
    }

    final perm = WebPushService.permission;

    if (perm == 'denied') {
      if (mounted) setState(() => _state = _SubState.blocked);
      return;
    }

    if (perm == 'default' || perm == 'unavailable') {
      if (mounted) setState(() => _state = _SubState.defaultPerm);
      return;
    }

    // Permission is 'granted' — verify that a subscription actually exists.
    // This fails silently in InPrivate / hardened browsers.
    final sub = await WebPushService.getExistingSubscription();
    if (!mounted) return;
    setState(() {
      _state = (sub != null && sub.endpoint.isNotEmpty)
          ? _SubState.active
          : _SubState.failed;
    });
  }

  /// Full registration flow triggered by the user:
  ///  1. Request browser permission.
  ///  2. Subscribe with VAPID key.
  ///  3. POST / PATCH device record — only if endpoint is non-empty.
  Future<void> _enable() async {
    if (_busy) return;

    final vapidKey = AppConfig.vapidPublicKey;
    if (vapidKey.isEmpty) {
      // VAPID key not configured — nothing to do.
      if (mounted) setState(() => _state = _SubState.failed);
      return;
    }

    setState(() => _busy = true);

    try {
      final ok = await ref
          .read(deviceServiceProvider)
          .requestAndRegisterWebPush(vapidKey);

      if (!mounted) return;

      final perm = WebPushService.permission;

      if (ok) {
        setState(() {
          _state = _SubState.active;
          _busy = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Browser notifications enabled')),
        );
        return;
      }

      // Not ok — determine why.
      if (perm == 'denied') {
        setState(() { _state = _SubState.blocked; _busy = false; });
      } else if (perm == 'granted') {
        // Granted but subscription failed (InPrivate, VAPID error, SW issue).
        setState(() { _state = _SubState.failed; _busy = false; });
      } else {
        // User dismissed the permission prompt.
        setState(() { _state = _SubState.defaultPerm; _busy = false; });
      }
    } catch (_) {
      if (mounted) {
        final blocked = WebPushService.permission == 'denied';
        setState(() {
          _state = blocked ? _SubState.blocked : _SubState.failed;
          _busy = false;
        });
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
              Icon(
                _stateIcon,
                size: 18,
                color: _stateIconColor,
              ),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Push notifications',
                      style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _statusSubtitle,
                      style: AuraText.small.copyWith(color: AuraSurface.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AuraSpace.s12),
              _trailingWidget,
            ],
          ),
        ),
        if (_state == _SubState.blocked)
          Padding(
            padding: const EdgeInsets.only(top: AuraSpace.s8),
            child: Text(
              'Notifications are blocked by your browser. To enable them, '
              'click the lock icon in your address bar, allow notifications '
              'for this site, then reload the page.',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
          ),
        if (_state == _SubState.failed)
          Padding(
            padding: const EdgeInsets.only(top: AuraSpace.s8),
            child: Text(
              'Subscription could not be created. This can happen in private '
              'browsing mode or when a VAPID key mismatch occurs. '
              'Try a normal browser window or a different browser.',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
          ),
      ],
    );
  }

  // ── State-derived props ───────────────────────────────────────────────────

  IconData get _stateIcon {
    switch (_state) {
      case _SubState.active:
        return Icons.notifications_active_outlined;
      case _SubState.blocked:
        return Icons.notifications_off_outlined;
      case _SubState.unsupported:
        return Icons.notifications_none_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color get _stateIconColor {
    switch (_state) {
      case _SubState.active:
        return AuraSurface.goodInk;
      case _SubState.blocked:
      case _SubState.failed:
        return AuraSurface.dangerInk;
      default:
        return AuraSurface.ink;
    }
  }

  String get _statusSubtitle {
    switch (_state) {
      case _SubState.unsupported:
        return 'Not supported in this browser';
      case _SubState.blocked:
        return 'Blocked — change your browser settings to enable';
      case _SubState.active:
        return 'Receive notifications when the app is in the background';
      case _SubState.failed:
        return 'Registration failed — check browser privacy settings';
      case _SubState.loading:
        return 'Checking subscription…';
      case _SubState.defaultPerm:
        return 'Get notified about messages and calls even when the tab is closed';
    }
  }

  Widget get _trailingWidget {
    switch (_state) {
      case _SubState.unsupported:
        return Text(
          'Unavailable',
          style: AuraText.small.copyWith(
            color: AuraSurface.faint,
            fontWeight: FontWeight.w600,
          ),
        );

      case _SubState.blocked:
        return Text(
          'Blocked',
          style: AuraText.small.copyWith(
            color: AuraSurface.dangerInk,
            fontWeight: FontWeight.w600,
          ),
        );

      case _SubState.active:
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

      case _SubState.loading:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );

      case _SubState.failed:
        return _ActionButton(
          label: 'Retry',
          busy: _busy,
          onTap: _enable,
        );

      case _SubState.defaultPerm:
        return _ActionButton(
          label: 'Enable',
          busy: _busy,
          onTap: _enable,
        );
    }
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: busy ? null : onTap,
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
          child: busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  label,
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
