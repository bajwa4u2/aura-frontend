# Aura 1.3.0 — Artifact Integrity Manifest

Build timestamp: 2026-08-05T19:38:57Z (all artifacts built from the same working-tree state, prior to the release commit — see note below)
Source commit: to be finalized as the Phase 12 release commit (working tree at build time is identical to that commit's content)

## Web

- Platform: Web
- Version: 1.3.0+24
- Build output: `build/web/` (73 files, ~41MB)
- Build command: `flutter build web --release --dart-define=API_BASE_URL=https://api.auraplatform.org --dart-define=AURA_WEB_PUSH_VAPID_PUBLIC_KEY=<production VAPID key>` followed by `dart run tool/web/generate_route_metadata.dart`
- Signing: N/A (web)
- Test status: PASS — production config build succeeds; no source maps; no secrets embedded beyond the intentionally-public API base URL and VAPID public key; service worker actively self-unregisters and force-reloads clients on every activation (no stale-cache risk).
- Deployment: continuous, auto-deployed by Railway on push to `main` — live verification occurs after the Phase 12 push.

## Android

- Platform: Android
- Version name: 1.3.0
- Version code: 24
- Application ID: org.auraplatform.app
- File name: `Aura-1.3.0+24-release.aab`
- File size: 78,178,652 bytes (74.57 MB)
- SHA-256: `a769674737f67cd5eb453d9c91e85e56131c2571b351d8b56647bad7b5a710eb`
- Signing status: Signed with the existing governed release keystore (`android/key.properties` / `android/upload-keystore.jks`), successful.
- Test status: PASS — `flutter build appbundle --release` clean; manifest permissions (INTERNET, POST_NOTIFICATIONS, RECORD_AUDIO, MODIFY_AUDIO_SETTINGS, CAMERA) match expected feature set; no debug flags present.
- Runtime install/smoke test: NOT PERFORMED — no Android emulator or physical device available on this workstation (environment-only limitation, not a code defect).

## Windows

- Platform: Windows
- Package version: 1.3.0.0
- Package identity: `AuraPlatformLLC.AURAPLATFORM`
- Publisher: `CN=3E4027A7-4D4D-4492-B8DE-BBE425E307E5` (matches existing Partner Center registration exactly)
- File name: `Aura-1.3.0.0-release.msix`
- File size: 31,920,261 bytes (30.44 MB)
- SHA-256: `2b3dd63223e3e4a1f7fe6726995409bfa1ef9fbb8f8197db45e2eeb56f2f6603`
- Signing status: Intentionally unsigned by design — `msix_config.store: true` in `pubspec.yaml` causes the build tool to skip local signing, since Microsoft Partner Center signs the package on Store ingestion. This is the existing, correct governed process (confirmed against the `msix` package source), not a defect.
- Test status: PASS — package builds cleanly; identity/version confirmed via direct manifest inspection.
- Runtime install/smoke test: PARTIAL — a temporary, throwaway self-signed certificate was generated to attempt a local upgrade-install test over the existing `1.2.3.0` installation; Windows correctly refused to trust the ad hoc root certificate non-interactively (a deliberate OS security boundary requiring an interactive trust prompt). The attempt was abandoned rather than forced, and all temporary certificate material was removed. The pre-existing `1.2.3.0` installation was confirmed undisturbed and healthy afterward. Full install/upgrade/launch verification requires either an interactive session to accept a one-time local trust prompt, or the actual Store-signed package post-certification.

## iOS

- Platform: iOS
- Marketing version: 1.3.0 (via `$(FLUTTER_BUILD_NAME)`)
- Build number: 24 (via `$(FLUTTER_BUILD_NUMBER)`) — greater than all previously recorded builds (13, 23)
- Bundle identifier: org.auraplatform.app (consistent across all build configurations)
- Signing: Automatic managed signing via Codemagic's App Store Connect API key integration (`ios_signing.distribution_type: app_store`) — no local signing performed, none possible on this Windows workstation.
- Test status: Cannot build or test locally (`flutter build ios` requires macOS). Codemagic is the designated build environment. See Phase 9 findings for full detail and the manual trigger instructions.
- Artifact: Not produced in this session — produced only when the founder manually runs the `ios-testflight` Codemagic workflow.

## Backend (reference — not independently versioned/distributed)

- Migrations: 100/100 applied, schema confirmed up to date against production, zero drift.
- Test status: PASS — 85 suites / 1105 tests.
- Build: PASS — clean `nest build`.
- Health check: `https://api.auraplatform.org/health` → `200 {"ok":true,"service":"aura-api"}`.
- Deployment: continuous, auto-deployed by Railway on push to `main`; already running the full commit range included in this release as of this baseline.
