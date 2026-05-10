import 'package:url_launcher/url_launcher.dart';

import '_web_reload_stub.dart' if (dart.library.html) '_web_reload_web.dart';
import 'compatibility_models.dart';

/// What the UpdateGate's primary action button should do for a given verdict
/// + distribution. Computed once when the UI builds so we can hide the button
/// entirely if no path forward exists (e.g. force_update on a distribution
/// without a configured storeUrl).
enum UpdateActionKind {
  none,
  reloadWeb,
  openStoreUrl,
}

class UpdateAction {
  const UpdateAction({
    required this.kind,
    required this.label,
    this.targetUrl,
  });

  final UpdateActionKind kind;
  final String label;
  final String? targetUrl;

  bool get hasTarget =>
      kind == UpdateActionKind.reloadWeb ||
      (kind == UpdateActionKind.openStoreUrl &&
          (targetUrl?.isNotEmpty ?? false));
}

/// Resolve the primary action for a verdict. The distribution comes from the
/// verdict's evaluated identity (server-echoed) so the action stays correct
/// even if a beta build is run with the wrong dart-define.
UpdateAction resolveUpdateAction(CompatibilityVerdict verdict) {
  // Maintenance has no user action — the screen just informs.
  if (verdict.status == CompatibilityStatus.maintenance) {
    return const UpdateAction(kind: UpdateActionKind.none, label: 'Waiting…');
  }

  switch (verdict.evaluatedDistribution) {
    case 'web-prod':
      return const UpdateAction(
        kind: UpdateActionKind.reloadWeb,
        label: 'Reload now',
      );
    case 'android-play':
      // Prefer the policy-supplied storeUrl so admins can A/B-test alternate
      // listing pages or pin a specific track. Falls back silently to none if
      // the admin has not populated it — in that case the gate downgrades to
      // a soft warn rather than blocking with no path forward.
      return UpdateAction(
        kind: verdict.storeUrl == null
            ? UpdateActionKind.none
            : UpdateActionKind.openStoreUrl,
        label: 'Open Play Store',
        targetUrl: verdict.storeUrl,
      );
    case 'android-direct':
      return UpdateAction(
        kind: verdict.storeUrl == null
            ? UpdateActionKind.none
            : UpdateActionKind.openStoreUrl,
        label: 'Download update',
        targetUrl: verdict.storeUrl,
      );
    case 'windows-store':
      return UpdateAction(
        kind: verdict.storeUrl == null
            ? UpdateActionKind.none
            : UpdateActionKind.openStoreUrl,
        label: 'Open Microsoft Store',
        targetUrl: verdict.storeUrl,
      );
    default:
      return const UpdateAction(kind: UpdateActionKind.none, label: 'Update');
  }
}

/// Executes the action. Returns false if nothing happened (no target / launch
/// failure) so the caller can keep the user on the blocking screen with a
/// helpful hint rather than silently dropping the tap.
Future<bool> performUpdateAction(UpdateAction action) async {
  switch (action.kind) {
    case UpdateActionKind.none:
      return false;
    case UpdateActionKind.reloadWeb:
      reloadWebPage();
      return true;
    case UpdateActionKind.openStoreUrl:
      final raw = action.targetUrl;
      if (raw == null || raw.isEmpty) return false;
      final uri = Uri.tryParse(raw);
      if (uri == null) return false;
      try {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        return false;
      }
  }
}
