/// CALLS THAT CANNOT RING ON THE LOCK SCREEN, SAID TO THE PERSON WHO CAN FIX IT.
///
/// From Android 14 the system decides whether an app may show a call over the
/// lock screen ("full-screen alerts"), and a Play install of Aura arrives with
/// it OFF. Measured on a Galaxy S24, 1.7.0 (49) from Play, 2026-10-28: a call
/// to the locked phone only showed a notification; the person had to unlock,
/// open the panel and accept from there. With the setting turned on, the same
/// call woke the phone into Aura's ring screen and Accept went straight in.
///
/// Only the person can turn it on, so Aura asks: once as a sheet when the app
/// opens (and not again for [snooze] after "Not now"), and for as long as it
/// stays off, as a card on "Your devices", where a person looks when calls are
/// not reaching them. Android only; nowhere else has this setting.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/notifications/native_call_actions.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

/// Whether calls can ring full-screen on this device, and how to fix it.
/// Overridden in tests; the real one asks Android.
class CallRingAccess {
  const CallRingAccess({
    required this.applies,
    required this.allowed,
    required this.openSettings,
  });

  /// Whether this platform has the setting at all.
  final bool applies;
  final Future<bool> Function() allowed;
  final Future<bool> Function() openSettings;

  static CallRingAccess get device => CallRingAccess(
        // The same gate the native check keeps: a platform that only claims
        // to be Android (a test, a desktop build) has no such setting, and
        // asking there would ask for nothing.
        applies: !kIsWeb && Platform.isAndroid,
        allowed: NativeCallActions.instance.canPresentFullScreen,
        openSettings: NativeCallActions.instance.openFullScreenSettings,
      );
}

final callRingAccessProvider =
    Provider<CallRingAccess>((ref) => CallRingAccess.device);

const _title = 'Let calls ring on your lock screen';
const _body = 'Full-screen alerts are off for Aura on this phone, so a call '
    'arrives only as a notification and you have to unlock to answer it.';
const _hint = 'On the next screen, switch Aura on.';

/// How long "Not now" keeps the sheet away.
const snooze = Duration(days: 30);
const _snoozedAtKey = 'aura_call_ring_ask_snoozed_at';

/// Asks once when a signed-in person opens the app, if calls cannot ring.
class CallRingAsk extends ConsumerStatefulWidget {
  const CallRingAsk({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CallRingAsk> createState() => _CallRingAskState();
}

/// Once per app run, whatever the answer.
bool _askedThisRun = false;

@visibleForTesting
void resetCallRingAskForTest() => _askedThisRun = false;

class _CallRingAskState extends ConsumerState<CallRingAsk> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_maybeAsk()));
  }

  Future<void> _maybeAsk() async {
    final access = ref.read(callRingAccessProvider);
    if (!access.applies || _askedThisRun) return;
    _askedThisRun = true;
    if (await access.allowed()) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final at = prefs.getInt(_snoozedAtKey);
      if (at != null &&
          DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(at)) <
              snooze) {
        return;
      }
    } catch (_) {
      // No record is no snooze.
    }
    if (!mounted) return;
    final turnedOn = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CallRingSheet(),
    );
    if (turnedOn == true) {
      await access.openSettings();
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_snoozedAtKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The sheet. Pops true for "Turn on", false or null otherwise.
class CallRingSheet extends StatelessWidget {
  const CallRingSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AuraRadius.xl)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AuraSpace.s20,
            AuraSpace.s10,
            AuraSpace.s20,
            AuraSpace.s20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AuraSurface.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AuraSpace.s20),
              const _RingIcon(),
              const SizedBox(height: AuraSpace.s16),
              const Text(_title, style: AuraText.title),
              const SizedBox(height: AuraSpace.s8),
              Text(_body, style: AuraText.body.copyWith(color: AuraSurface.muted)),
              const SizedBox(height: AuraSpace.s8),
              Text(_hint, style: AuraText.small.copyWith(color: AuraSurface.faint)),
              const SizedBox(height: AuraSpace.s20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AuraSecondaryButton(
                    label: 'Not now',
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(width: AuraSpace.s12),
                  AuraPrimaryButton(
                    label: 'Turn on',
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The standing reminder on "Your devices". Shows nothing once calls can
/// ring, and checks again whenever the person comes back from Settings.
class CallRingCard extends ConsumerStatefulWidget {
  const CallRingCard({super.key});

  @override
  ConsumerState<CallRingCard> createState() => _CallRingCardState();
}

class _CallRingCardState extends ConsumerState<CallRingCard>
    with WidgetsBindingObserver {
  bool _blocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  Future<void> _check() async {
    final access = ref.read(callRingAccessProvider);
    if (!access.applies) return;
    final allowed = await access.allowed();
    if (mounted && _blocked == allowed) setState(() => _blocked = !allowed);
  }

  @override
  Widget build(BuildContext context) {
    if (!_blocked) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: AuraSpace.s12),
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _RingIcon(size: 40),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Text(
                  _title,
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(_body, style: AuraText.small.copyWith(color: AuraSurface.muted)),
          const SizedBox(height: AuraSpace.s12),
          Align(
            alignment: Alignment.centerRight,
            child: AuraPrimaryButton(
              label: 'Turn on',
              onPressed: () =>
                  unawaited(ref.read(callRingAccessProvider).openSettings()),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingIcon extends StatelessWidget {
  const _RingIcon({this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AuraSurface.accentSoft,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.ring_volume_rounded,
        size: size * 0.45,
        color: AuraSurface.accent,
      ),
    );
  }
}
