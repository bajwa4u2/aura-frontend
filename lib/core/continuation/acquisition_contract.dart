/// THE ACQUISITION CONTRACT, IN DART.
///
/// Mirror of `contracts/native_continuation_contract.json`, held to it by
/// `test/continuation/acquisition_contract_test.dart`. Nothing here is an
/// independent decision: eligibility, store destinations and platform
/// capability all come from that file, because the alternative is what was
/// here before — a hand-kept list of exact paths that had drifted from every
/// other authority in the product.
library;

import 'package:flutter/foundation.dart';

/// Path prefixes eligible for native continuation.
///
/// This IS the association scope. A page is eligible to offer the app exactly
/// when a link to it can reach the app — anything else advertises a door that
/// does not open.
const List<String> kEligiblePrefixes = [
  '/p/',
  '/posts/',
  '/announcements/',
  '/articles/',
  '/u/',
  '/author/',
  '/institutions/',
  '/spaces/',
  '/meetings/join/',
  '/invite/',
  '/auth/',
];

/// Exact paths eligible for continuation.
const Set<String> kEligibleExactPaths = {
  '/verify-email',
  '/reset-password',
  '/forgot-password',
  '/account-deletion',
};

/// Paths excluded from continuation even though a prefix above matches them.
///
/// Android cannot express these in a manifest and Windows cannot express them
/// at all, so they are enforced here and by route classification.
const List<String> kExcludedSuffixes = ['/edit', '/write', '/create'];
const Set<String> kExcludedPaths = {'/institutions/get-started'};

/// Store destinations, per platform.
const String kAndroidStoreUrl =
    'https://play.google.com/store/apps/details?id=org.auraplatform.app';
const String kIosStoreUrl =
    'https://apps.apple.com/us/app/aura-platform/id6772071135';
const String kWindowsStoreUrl = 'https://apps.microsoft.com/detail/9N6CZR88F4NT';

/// Whether a RELEASED client can actually route a continuation link.
///
/// Deliberately separate from "is association configured in this source tree".
/// The web surface deploys before native clients do, so offering "Open in Aura"
/// against a client that cannot route the destination opens the old app at home
/// and loses what the person tapped. That is the fake Open state the contract
/// forbids, so these stay false until a released client carries the capability.
const bool kAndroidContinuationShipped = false;
const bool kIosContinuationShipped = false;
const bool kWindowsContinuationShipped = false;

/// Android is in CLOSED TESTING; Play production access has not been granted.
///
/// A general visitor sent to that Play page cannot install from it. Offering
/// "Get Aura" on Android would be advertising distribution that does not exist
/// for the person being offered it.
const bool kAndroidGenerallyAvailable = false;

/// True when this path may offer native continuation at all.
bool isContinuationEligiblePath(String path) {
  if (path.isEmpty || !path.startsWith('/')) return false;
  if (kExcludedPaths.contains(path)) return false;
  for (final suffix in kExcludedSuffixes) {
    if (path.endsWith(suffix)) return false;
  }
  if (kEligibleExactPaths.contains(path)) return true;
  for (final prefix in kEligiblePrefixes) {
    if (path.startsWith(prefix)) return true;
  }
  return false;
}

/// What the public web surface should offer on this platform.
enum AcquisitionAction {
  /// The app can route this destination — offer to continue there.
  open,

  /// The app exists and can be obtained — offer to get it.
  get,

  /// Nothing honest to offer. The web page stands on its own.
  none,
}

/// Decides the affordance from real distribution truth, never from optimism.
AcquisitionAction acquisitionActionFor(TargetPlatform platform) {
  switch (platform) {
    case TargetPlatform.android:
      if (kAndroidContinuationShipped) return AcquisitionAction.open;
      // Closed testing: the Play link is real, but a visitor cannot install
      // from it, so offering it would be advertising unavailable distribution.
      return kAndroidGenerallyAvailable
          ? AcquisitionAction.get
          : AcquisitionAction.none;
    case TargetPlatform.iOS:
      return kIosContinuationShipped
          ? AcquisitionAction.open
          : AcquisitionAction.get;
    case TargetPlatform.windows:
      return kWindowsContinuationShipped
          ? AcquisitionAction.open
          : AcquisitionAction.get;
    default:
      return AcquisitionAction.none;
  }
}

/// The store destination for a platform, or null when there is none to offer.
String? storeUrlFor(TargetPlatform platform) {
  switch (platform) {
    case TargetPlatform.android:
      return kAndroidGenerallyAvailable ? kAndroidStoreUrl : null;
    case TargetPlatform.iOS:
      return kIosStoreUrl;
    case TargetPlatform.windows:
      return kWindowsStoreUrl;
    default:
      return null;
  }
}
