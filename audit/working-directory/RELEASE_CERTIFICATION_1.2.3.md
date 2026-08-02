# Aura 1.2.3 Release Certification

Date: 2026-08-02
Status: Release candidate preparation; publication requires founder approval.

## Unified Identity

- Semantic version: `1.2.3`
- Flutter build number: `23`
- Android: `versionName=1.2.3`, `versionCode=23` via Flutter Gradle variables.
- iOS: `CFBundleShortVersionString=1.2.3`, `CFBundleVersion=23` via Flutter/Xcode variables.
- Windows MSIX: `1.2.3.0` via `msix_version`; the revision is zero for Microsoft Store compatibility.
- Web: Flutter web build derives the application release identity from `pubspec.yaml`; no independent web version source exists.
- CodeMagic: iOS workflow consumes the same `pubspec.yaml` version and produces the signed IPA when the hosted macOS workflow runs.

## Release Scope

This candidate includes the currently pushed Aura frontend state, including the
governed tag persistence coverage repair. No distribution channel publication
or TestFlight submission is authorized by this record.

## Verification Matrix

| Target | Result | Evidence |
|---|---|---|
| Flutter analyze | PASS | `flutter analyze`: no issues found. |
| Flutter tests | PASS | `flutter test --exclude-tags golden`: 64 tests passed. |
| Web release | PASS | `flutter build web --release`; `build/web` produced. |
| Android AAB | PASS | `flutter build appbundle --release`; `build/app/outputs/bundle/release/app-release.aab` produced. |
| Windows MSIX | PASS | `flutter pub run msix:create --release`; `build/windows/x64/runner/Release/aura.msix` produced with manifest version `1.2.3.0`. |
| iOS IPA | CodeMagic-only | Requires hosted macOS, signing, and CodeMagic credentials. |

## Artifact Evidence

- Android AAB: 78,096,093 bytes; SHA-256
  `94EB30E56FBEA385DE7C22F8AB74B5BBBB801D92B3526CD2405E6BF420A8532B`.
- Windows MSIX: 32,025,020 bytes; SHA-256
  `ADB4588CC74D11900DB9470A97731B07135A6E9E0488E09F26A3D88995C30161`.
- Windows package manifest: `AuraPlatformLLC.AURAPLATFORM`, version `1.2.3.0`.
- Web output: `build/web/index.html` produced; Web has no independent version source.
- Android release identity is sourced from Flutter Gradle variables in
  `android/app/build.gradle.kts`, which consume `pubspec.yaml` `1.2.3+23`.
- iOS release identity is sourced from `FLUTTER_VERSION` and
  `FLUTTER_BUILD_NUMBER` in the Xcode project and will consume `1.2.3+23` in
  CodeMagic.

## Known Non-Blocking Constraints

- iOS archive production cannot run on this Windows workstation; CodeMagic is
  the designated build environment. No IPA was produced or uploaded here.
- The Web build reports the existing `socket_io_common` WebAssembly dry-run
  compatibility warning; the standard JavaScript release build passed.
- TestFlight/App Store, Google Play, Microsoft Store, and web publication are
  intentionally excluded until release-candidate verification is complete and
  the founder approves publication.
