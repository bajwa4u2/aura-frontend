/// Canonical Terms / EULA version.
///
/// Apple Store §1.2 UGC compliance. The client persists the version
/// the user accepted; the backend stores the same version on
/// `User.termsAcceptedVersion`. When this constant bumps, signed-in
/// users whose persisted version is stale are routed through the
/// re-acceptance flow before they can resume posting / commenting.
///
/// Bump procedure:
///   1. Update the Terms text in `lib/screens/terms_screen.dart`.
///   2. Bump `kTermsVersion` here to a new label (e.g. "2026-05-26").
///   3. Existing users are gated into re-acceptance on next sign-in;
///      new users see the current version at registration.
///
/// The label is opaque to the backend — it's a string the client
/// chooses. Any ASCII string ≤ 32 chars is accepted.
const String kTermsVersion = '2026-05-26';
