import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/admin_access_provider.dart';
import '../ui/aura_radius.dart';
import '../ui/aura_surface.dart';
import '../ui/aura_text.dart';
import 'compatibility_models.dart';
import 'compatibility_provider.dart';
import 'update_actions.dart';
import '../../router.dart';

/// Wraps the routed widget tree with release-governance UX. Renders one of
/// four modes based on the latest CompatibilityVerdict:
///
///   compatible          → child as-is, no overlay
///   degraded/soft_warn  → child + non-blocking banner at top
///   blocked/force_update→ blocking screen replaces child
///   maintenance         → maintenance screen replaces child
///
/// The widget also wires app-resume into a verdict refresh so a user who
/// foregrounds the app after a long background gets the current policy
/// without waiting for the periodic timer.
///
/// Slice C scope: even when the verdict says `blocked`, this gate only
/// REPLACES the visible UI. Backend routes are not enforced server-side
/// from this slice — that is intentionally left to the operator who can
/// flip `forceUpdate` per (distribution, channel) when ready.
class UpdateGate extends ConsumerStatefulWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends ConsumerState<UpdateGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Best-effort refresh — failures are swallowed inside the controller.
      // `force: true` bypasses the controller's visibility gate so a tab
      // returning from background gets a fresh verdict immediately rather
      // than waiting for the next periodic tick.
      ref.read(compatibilityControllerProvider.notifier).refresh(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final verdict = ref.watch(compatibilityControllerProvider);

    // Maintenance + admin override: a confirmed platform admin reaching an
    // /admin/* route during maintenance must NOT be locked out — they're
    // the only ones who can disable the maintenance flag from the admin
    // settings screen. The check is "cached admin AND on /admin/*" so a
    // signed-out user with no cache cannot bypass, and admins on member
    // routes still see the maintenance screen (they should navigate to
    // /admin to operate).
    if (verdict.status == CompatibilityStatus.maintenance) {
      final isAdmin = ref.watch(appAdminCachedDisplayProvider);
      // NOT `GoRouterState.of(context)`. This widget is mounted in
      // `MaterialApp.router`'s builder — deliberately, so the blocking screens
      // get Material and MediaQuery ancestors — which puts it ABOVE the route
      // tree. `GoRouterState.of` only resolves under a `RouteBase.builder`, so
      // it threw `GoError: There is no GoRouterState above the current
      // context` and replaced the maintenance screen with an error screen.
      //
      // The bug was invisible until maintenance was switched on for the first
      // time, because this is the only branch that reads the route. The router
      // itself is reachable from anywhere, so ask it directly.
      final path = ref
              .read(routerProvider)
              .routerDelegate
              .currentConfiguration
              .uri
              .path;
      if (isAdmin && path.startsWith('/admin')) {
        return widget.child;
      }
    }

    switch (verdict.status) {
      case CompatibilityStatus.compatible:
        // COMPATIBLE MEANS NOTHING IS WRONG, SO SAY NOTHING.
        //
        // A "a new release is available, reload" bar used to sit over the
        // header here whenever the deployed web bundle moved ahead of the one
        // in the tab. The backend has no complaint in this branch — the client
        // works — so the bar interrupted people to report our deployment
        // cadence, which is our business and not theirs. On a platform that
        // deploys several times a day it was permanent furniture above the
        // product, and dismissing it only lasted until the next deploy.
        //
        // Founder decision, 2026-08-30. A genuinely incompatible client is
        // still stopped by `blocked` below, and a degraded one still warns —
        // those are the cases where a person actually needs to act. The web
        // release watcher is a lazy provider, so with nothing watching it, it
        // stops running rather than polling for a banner that no longer draws.
        return widget.child;
      case CompatibilityStatus.degraded:
        return _SoftWarnBannerOverlay(
          verdict: verdict,
          child: widget.child,
        );
      case CompatibilityStatus.blocked:
        return _BlockingScreen(verdict: verdict);
      case CompatibilityStatus.maintenance:
        return _MaintenanceScreen(verdict: verdict);
    }
  }
}

class _SoftWarnBannerOverlay extends StatefulWidget {
  const _SoftWarnBannerOverlay({required this.verdict, required this.child});

  final CompatibilityVerdict verdict;
  final Widget child;

  @override
  State<_SoftWarnBannerOverlay> createState() => _SoftWarnBannerOverlayState();
}

class _SoftWarnBannerOverlayState extends State<_SoftWarnBannerOverlay> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!_dismissed)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: _SoftWarnBanner(
                  verdict: widget.verdict,
                  onDismiss: () => setState(() => _dismissed = true),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SoftWarnBanner extends StatelessWidget {
  const _SoftWarnBanner({required this.verdict, required this.onDismiss});

  final CompatibilityVerdict verdict;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final action = resolveUpdateAction(verdict);
    final message = verdict.message ??
        'A newer version of Aura is available.';
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: AuraSurface.elevated,
          borderRadius: BorderRadius.circular(AuraRadius.r12),
          border: Border.all(color: AuraSurface.divider),
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.update,
              size: 20,
              color: AuraSurface.accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AuraText.small.copyWith(color: AuraSurface.ink),
              ),
            ),
            if (action.hasTarget) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => performUpdateAction(action),
                child: Text(action.label),
              ),
            ],
            // NO TOOLTIP HERE, DELIBERATELY.
            //
            // This banner is built inside MaterialApp.builder, which sits
            // ABOVE the Navigator -- and the Navigator is what supplies the
            // Overlay. Tooltip requires an Overlay ancestor, so `tooltip:`
            // threw "No Overlay widget found." on every build, and the global
            // ErrorWidget replaced the button with a 460x320 box sitting where
            // the dismiss control should be. Founder-observed on the live site,
            // 2026-08-22.
            //
            // The accessible name moves to the Icon, which carries it without
            // needing an Overlay, so screen readers still announce "Dismiss".
            IconButton(
              icon: const Icon(
                Icons.close,
                size: 18,
                semanticLabel: 'Dismiss',
              ),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockingScreen extends StatelessWidget {
  const _BlockingScreen({required this.verdict});

  final CompatibilityVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final action = resolveUpdateAction(verdict);
    final headline = verdict.action == CompatibilityAction.forceUpdate
        ? 'Update required'
        : 'New version available';
    final message = verdict.message ??
        'Please update Aura to continue. This version is no longer '
            'supported on your platform.';

    // If no action target exists (e.g. android-direct without storeUrl on a
    // force_update), we show an explanatory message instead of a dead button
    // so the user is not stuck staring at an inert screen.
    return _GovernanceScaffold(
      icon: Icons.system_update_alt,
      title: headline,
      body: message,
      footer: action.hasTarget
          ? FilledButton(
              onPressed: () => performUpdateAction(action),
              child: Text(action.label),
            )
          : Text(
              'No update path is configured for this build. '
              'Contact support if this persists.',
              textAlign: TextAlign.center,
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
      versionHint: _versionHint(verdict),
    );
  }
}

class _MaintenanceScreen extends StatelessWidget {
  const _MaintenanceScreen({required this.verdict});

  final CompatibilityVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final message = verdict.message ??
        'Aura is briefly offline for maintenance. We will be back shortly.';
    return _GovernanceScaffold(
      icon: Icons.build_circle_outlined,
      title: 'Aura is in maintenance',
      body: message,
      footer: Text(
        "We'll let you back in as soon as it's done.",
        textAlign: TextAlign.center,
        style: AuraText.small.copyWith(color: AuraSurface.muted),
      ),
      versionHint: null,
    );
  }
}

class _GovernanceScaffold extends StatelessWidget {
  const _GovernanceScaffold({
    required this.icon,
    required this.title,
    required this.body,
    required this.footer,
    required this.versionHint,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget footer;
  final String? versionHint;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AuraSurface.page,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(icon, size: 56, color: AuraSurface.accent),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: AuraText.headline,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    body,
                    style: AuraText.body.copyWith(color: AuraSurface.muted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  footer,
                  if (versionHint != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      versionHint!,
                      style: AuraText.micro.copyWith(color: AuraSurface.faint),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String? _versionHint(CompatibilityVerdict verdict) {
  if (kReleaseMode &&
      verdict.minSupportedVersion == null &&
      verdict.recommendedVersion == null) {
    return null;
  }
  final parts = <String>[
    if (verdict.minSupportedVersion != null)
      'Min supported: ${verdict.minSupportedVersion}',
    if (verdict.recommendedVersion != null)
      'Recommended: ${verdict.recommendedVersion}',
    if (verdict.latestVersion != null) 'Latest: ${verdict.latestVersion}',
  ];
  if (parts.isEmpty) return null;
  return parts.join(' • ');
}

/// A quiet, dismissible notice that a newer Aura is live.
///
/// Deliberately non-blocking: the running client still works, and the person
/// decides when to take the update. Reloading preserves the current URL — the
/// destination was never the thing being replaced.
