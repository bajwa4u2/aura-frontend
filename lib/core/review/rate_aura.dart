import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';

import '../client_identity/client_identity_provider.dart';
import '../continuation/acquisition_contract.dart';

/// "RATE AURA" — WHEN A PERSON ASKS, NOT WHEN AURA DECIDES TO.
///
/// ── WHY THIS IS NOT `StoreReviewService.maybeAsk` ────────────────────────
///
/// That method exists for the UNSOLICITED prompt: Aura choosing a calm moment
/// and asking. It is policy-gated, cooled down, and refuses most moments by
/// name, which is exactly right for something nobody requested.
///
/// A menu item is the opposite situation. The person went looking for it and
/// pressed it. Refusing them because a cool-down has not elapsed, or because
/// the moment was not classified as settled, would be a control that does
/// nothing — and a control that does nothing is worse than no control.
///
/// ── AND WHY IT OPENS THE LISTING RATHER THAN THE IN-APP SHEET ────────────
///
/// Both stores say so. Google's In-App Review API must not be triggered from a
/// button: the quota is silent, so a person who presses "Rate" can get nothing
/// at all and no explanation. Apple's guidelines say the same of
/// `SKStoreReviewController` — it is for moments the app chooses, and a button
/// must take you somewhere. So the deliberate act opens the real listing on
/// every platform that has one, which is a promise the app can actually keep.
///
/// ── AND WHERE THERE IS NO STORE, THERE IS NO CONTROL ─────────────────────
///
/// Web has no rating destination. Aura shows nothing there rather than
/// inventing a rating surface for symmetry — a five-star widget that posts
/// nowhere is a fiction, and the honest answer to "where would this go" is
/// that it would go nowhere.
enum RateDestination {
  playStore,
  appStore,
  microsoftStore,

  /// No legitimate rating destination. The control is not shown.
  none;

  bool get exists => this != RateDestination.none;
}

/// Which store this build can honestly send someone to.
///
/// Note what this asks: the PLATFORM, because that is what determines whether
/// a store listing exists at all. It is not a distribution check — a
/// sideloaded Android build still has a Play listing to open, and the listing
/// is the truthful destination either way.
RateDestination rateDestinationFor(TargetPlatform platform, {bool web = false}) {
  if (web) return RateDestination.none;
  return switch (platform) {
    TargetPlatform.android => RateDestination.playStore,
    TargetPlatform.iOS => RateDestination.appStore,
    TargetPlatform.macOS => RateDestination.appStore,
    TargetPlatform.windows => RateDestination.microsoftStore,
    _ => RateDestination.none,
  };
}

final rateDestinationProvider = Provider<RateDestination>(
  (ref) => rateDestinationFor(defaultTargetPlatform, web: kIsWeb),
);

/// Open the store listing so the person can rate Aura.
///
/// Best-effort and silent about the outcome, because the platform is silent
/// about it too. An app that could observe whether a rating happened could act
/// on it, and acting on it is rating manipulation.
Future<void> openRateAura(RateDestination destination) async {
  try {
    switch (destination) {
      case RateDestination.appStore:
        await InAppReview.instance.openStoreListing(
          appStoreId: _appStoreId,
        );
      case RateDestination.microsoftStore:
        await InAppReview.instance.openStoreListing(
          microsoftStoreId: _microsoftStoreId,
        );
      case RateDestination.playStore:
        // `in_app_review` has no Play listing helper, and the canonical
        // destination is a URL Aura already publishes. Opened externally so
        // it lands in the Play app rather than a web view of it.
        await launchUrl(
          Uri.parse(kAndroidStoreUrl),
          mode: LaunchMode.externalApplication,
        );
      case RateDestination.none:
        return;
    }
  } catch (e) {
    debugPrint('[rate] opening $destination failed: $e');
  }
}

/// Ids taken apart from the canonical store URLs rather than typed a second
/// time, so a listing cannot drift away from the contract that publishes it.
String get _microsoftStoreId => Uri.parse(kWindowsStoreUrl).pathSegments.last;

String get _appStoreId =>
    Uri.parse(kIosStoreUrl).pathSegments.last.replaceFirst('id', '');

/// "Version 1.4.2" — READ, NEVER TYPED.
///
/// From `PackageInfo` through the canonical client identity, which is the same
/// value the app already sends on every request as `X-Aura-App-Version`. A
/// version written into a widget is a version that will disagree with the
/// binary the moment someone forgets to update it, and it will disagree
/// silently, in the one place a person looks to tell support what they are
/// running.
///
/// Null while identity is resolving, and null is rendered as nothing rather
/// than as a guess.
final appVersionLabelProvider = Provider<String?>((ref) {
  final identity = ref.watch(clientIdentitySnapshotProvider);
  final version = (identity?.appVersion ?? '').trim();
  if (version.isEmpty) return null;
  return 'Version $version';
});

/// The same, with the build number, for support and store review.
///
/// A build number answers "which of the several 1.4.2 uploads is this", which
/// is the question a reviewer or a support conversation actually has. It stops
/// there: this menu is not developer diagnostics.
final appVersionDetailProvider = Provider<String?>((ref) {
  final identity = ref.watch(clientIdentitySnapshotProvider);
  final version = (identity?.appVersion ?? '').trim();
  if (version.isEmpty) return null;
  final build = identity?.buildNumber;
  return build == null ? 'Version $version' : 'Version $version ($build)';
});
