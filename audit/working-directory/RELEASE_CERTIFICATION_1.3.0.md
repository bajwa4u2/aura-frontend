# Aura 1.3.0 — Final Release Certification

Date: 2026-08-05
Status: Web certified and live. Android/Windows artifacts certified and ready, distribution not yet submitted. iOS requires a manual Codemagic trigger by the founder.

---

## Release Identity

| Field | Value |
|---|---|
| Version | 1.3.0 |
| Build number | 24 |
| Git commit (release) | `db3a08838529a2869fe51a9eec270646c4349874` |
| Git commit (docs follow-up) | `f9c5762` (manifest commit-hash correction only, untagged) |
| Git tag | `v1.3.0` (points at `db3a088`) |
| Branch | `main` |
| Repo | `aura-frontend` (aura_final) |
| Backend | unchanged this release; `aura-backend` HEAD `9f66ce6`, already live in production |
| Date | 2026-08-05 |

---

## Platform Status

### Web
- Build result: **PASS** — production config (`API_BASE_URL`, `AURA_WEB_PUSH_VAPID_PUBLIC_KEY` matching Railway exactly) + route-metadata generation, both clean.
- Artifact: `build/web/` (73 files, ~41MB); no independent version identity — inherits `pubspec.yaml`.
- Signing: N/A.
- Runtime verification: **PASS** — deployed via Railway auto-deploy on push; live post-deploy smoke test confirms authenticated load, feed render, navigation, zero console errors. `main.dart.js` last-modified timestamp confirms the new build is what's actually being served.
- Distribution readiness: **LIVE** at `https://app.auraplatform.org` and `https://auraplatform.org`.
- Remaining manual action: none.

### Android
- Build result: **PASS** — signed release AAB via the existing governed keystore.
- Artifact: `Aura-1.3.0+24-release.aab` (78,178,652 bytes; SHA-256 `a769674737f67cd5eb453d9c91e85e56131c2571b351d8b56647bad7b5a710eb`).
- Signing: **PASS** — existing release keystore, no debug flags, expected manifest permissions only.
- Runtime verification: **NOT PERFORMED** — no Android emulator or physical device available on this workstation (environment limitation, not a code defect).
- Distribution readiness: artifact ready; **not submitted** to Google Play.
- Remaining manual action: founder (or a device-equipped environment) should install-test the AAB before wide rollout, then upload to Play Console and manage the release rollout — both outside this session's authorization.

### Windows
- Build result: **PASS** — `flutter build windows` + `msix:create` both clean.
- Artifact: `Aura-1.3.0.0-release.msix` (31,920,261 bytes; SHA-256 `2b3dd63223e3e4a1f7fe6726995409bfa1ef9fbb8f8197db45e2eeb56f2f6603`).
- Signing: intentionally unsigned by existing design (`msix_config.store: true` — Microsoft Partner Center signs on Store ingestion; confirmed against the `msix` package's own source, not a defect).
- Runtime verification: **PARTIAL** — package identity/version confirmed via manifest inspection (`AuraPlatformLLC.AURAPLATFORM`, `1.3.0.0`, publisher CN matches Partner Center registration exactly, greater than the previously-installed `1.2.3.0`). A real upgrade-install attempt was made using a throwaway local signing certificate; Windows correctly refused to trust it non-interactively (a deliberate OS security boundary, not a defect). The attempt was abandoned rather than forced; the pre-existing `1.2.3.0` installation was confirmed undisturbed afterward.
- Distribution readiness: artifact ready; **not submitted** to Microsoft Partner Center.
- Remaining manual action: full install/upgrade/launch verification needs either an interactive session to accept a one-time local trust prompt, or the real Store-signed package post-certification; founder submission to Partner Center.

### iOS
- Build result: **not built locally** — requires macOS; Codemagic is the designated environment (unchanged from prior releases).
- Version/build verified in repo: marketing version 1.3.0, build number 24 (greater than all previously recorded builds — 13, 23), bundle identifier `org.auraplatform.app` consistent across all build configs.
- Entitlements/capabilities: intact (`aps-environment=production`, Associated Domains for `auraplatform.org` / `app.auraplatform.org`).
- Privacy usage descriptions: complete (Camera, Microphone, Photo Library, Photo Library Add, Location When In Use).
- Signing: automatic managed signing via Codemagic's App Store Connect API key integration — no local signing performed or possible here.
- Distribution readiness: **requires a manual Codemagic run by the founder** — see instructions below.

---

## Quality Results

| Check | Result |
|---|---|
| Flutter analyze | **PASS** — 0 issues (rerun after the final commit, clean) |
| Frontend tests | **PASS** — 119 unit/widget tests + 14 golden tests (1 pre-existing, documented skip: `realtime_room_golden_test.dart` fixture rot, unrelated to this release) |
| Backend tests | **PASS** — 85 suites / 1105 tests |
| Backend build | **PASS** — clean `nest build` |
| Migration compatibility | **PASS** — 100/100 migrations applied against production, zero drift (`prisma migrate status`) |
| Backend health | **PASS** — `https://api.auraplatform.org/health` → 200 |
| Runtime smoke tests | **PASS** — live browser verification across cold deep-link reload, session restoration, feed rendering, composer/draft-autosave/discard, Communication Workspace (Institution Workspace overview, Announcements, Spaces), Activity/notifications, direct messages with per-message translate, Civic space — zero console errors observed throughout |
| Regression matrix | Substantially covered via live runtime testing; the fully topic-gated end-to-end publish flow was verified through the passing automated test suite (`aura_topic_selector_gate_test.dart`, `topic_relationship_gate_test.dart` — both new this release) rather than a live click-through, after a UI scroll interaction in this session's browser tooling couldn't reach the collapsed topic-selector panel at the available viewport height. Source review confirmed the gating logic (`_canPublish`) and the collapsible Enrichment panel are both correct and intentional, not a regression. |

No reproducible unhandled runtime error was found on any testable platform.

---

## Deployment Status

- **Web**: deployed and live at the certified commit; post-deploy smoke test passed.
- **Android AAB**: built, signed, checksummed — ready for upload; upload not performed.
- **Windows MSIX**: built, packaged, checksummed — ready for submission; submission not performed.
- **iOS**: not built; awaiting the founder's manual Codemagic trigger below.

---

## iOS — Exact Manual Instructions for the Founder

1. **Commit to select**: `db3a08838529a2869fe51a9eec270646c4349874` (tag `v1.3.0`) — already the tip of `main` alongside one harmless docs-only follow-up commit (`f9c5762`). Running the workflow against `main` HEAD is equivalent to running it against the tag.
2. **Workflow to run**: `ios-testflight` ("Aura iOS — TestFlight") in `codemagic.yaml`.
3. **Expected version/build**: marketing version `1.3.0`, build number `24` — greater than every previously uploaded TestFlight build (13, 23), so Apple will accept it.
4. **Expected artifact**: a signed `.ipa` under `build/ios/ipa/*.ipa`, plus xcodebuild logs, retained as Codemagic build artifacts.
5. **Before running, confirm in the Codemagic UI**:
   - The App Store Connect API key integration is still named exactly `Aura Platform LLC` (must match `codemagic.yaml`'s `integrations.app_store_connect` value character-for-character).
   - The secure environment variable `FIREBASE_IOS_CONFIG_BASE64` is still set (cannot be verified from this session — without it, the build still produces a signed IPA, but iOS push notifications will not function until it's provided).
6. **Important — this workflow uploads automatically.** `codemagic.yaml` has `submit_to_testflight: true`. Running this workflow does not just produce an IPA for later manual submission — the moment the build succeeds, it is automatically uploaded and submitted to TestFlight. Be prepared for that outcome before starting the run.
7. **Required post-build checks** (on a physical iPhone once the TestFlight build is available):
   - Install the TestFlight build; log in with the review account.
   - Confirm an iOS device token registers (`GET /v1/devices/me` shows an active `IOS` device).
   - Receive a normal notification.
   - Receive a call/ring notification; confirm the incoming-call overlay appears.
   - Confirm a notification tap opens the correct route.
   - Log out; confirm the device token is revoked.
   - Reinstall and log in; confirm a fresh token re-registers.

No App Store submission or public release has been triggered from this session. TestFlight upload will occur automatically only when the founder runs the workflow above.

---

## Outstanding Items

Requiring **founder action**:
1. Trigger the Codemagic `ios-testflight` workflow (see exact instructions above) — this both builds and automatically submits to TestFlight.
2. Complete the 7-step physical-device TestFlight validation once the build is available.
3. Upload the certified Android AAB to Google Play Console and manage the release rollout.
4. Submit the certified Windows MSIX to Microsoft Partner Center.
5. Provide the real Apple Developer Team ID to replace the `REPLACE_WITH_APPLE_TEAM_ID` placeholder still present in the live `apple-app-site-association` file at `auraplatform.org/.well-known/` — this blocks iOS Universal Links (web-to-app deep linking) specifically. It does not block TestFlight or App Store submission itself, but should be resolved before iOS distribution matters in practice.

Requiring **credentials/external review** (cannot be completed from this session):
6. Confirm the `FIREBASE_IOS_CONFIG_BASE64` secure variable is current in the Codemagic UI.
7. Real Android device/emulator install and smoke testing before wide Play Store rollout.
8. Real interactive Windows install/upgrade/launch verification (this session's attempt was correctly blocked by a non-interactive OS trust boundary).

**No store or public distribution has occurred.** Web is live (an existing, pre-authorized continuous-deployment behavior of this platform). Android and Windows artifacts are certified and ready but not submitted. iOS requires the founder's explicit manual trigger, which will also perform the TestFlight submission automatically once run.
