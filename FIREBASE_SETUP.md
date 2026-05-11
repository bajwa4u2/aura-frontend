# Firebase setup for Aura (Android + iOS)

Aura uses Firebase Cloud Messaging (FCM) for push notifications. The two
platform config files are required at build time but are **not
committed**: they're project-specific and contain a writeable API key
that — while scoped to package id — should be treated as configuration
rather than source.

## Required files

| Platform | File | Path |
|---|---|---|
| Android | `google-services.json` | `aura_final/android/app/google-services.json` |
| iOS     | `GoogleService-Info.plist` | `aura_final/ios/Runner/GoogleService-Info.plist` |

Both files come from the Firebase Console:
`Project settings → Your apps → Android/iOS app → Download config`.

`org.auraplatform.app` is the canonical package/bundle id for both
platforms. The Firebase Console app entry must match exactly.

## CI placement

Production and staging builds should fetch the right file from secret
storage and drop it at the path above before `flutter build`:

```bash
# Android (CI step before `flutter build apk`/`appbundle`)
echo "$FIREBASE_ANDROID_CONFIG_BASE64" | base64 -d \
  > aura_final/android/app/google-services.json

# iOS (CI step before `flutter build ios`)
echo "$FIREBASE_IOS_CONFIG_BASE64" | base64 -d \
  > aura_final/ios/Runner/GoogleService-Info.plist
```

`flutter run` locally also requires the files to be in place; pull them
from the team's secret manager into the working tree.

## iOS APNs auth key

In addition to the plist, iOS push delivery requires an APNs auth key
(`.p8`) uploaded to the Firebase Console:

`Project settings → Cloud Messaging → Apple app configuration → APNs
Authentication Key → Upload`.

Without this, Firebase can register the device token but cannot deliver
the actual push to iOS — the app appears to "register for push" and
then silently fails to receive any notification. Verify after upload
by sending a test push from `Engage → Messaging`.

## Verification

After both files are in place:

```bash
# Android: verify google-services.json was picked up
cd aura_final && flutter build apk --debug --no-tree-shake-icons
# look for "Found google-services.json" in the log

# iOS: verify plist was picked up
cd aura_final && flutter build ios --debug --no-codesign
# Xcode will fail at signing if the bundle id doesn't match the plist
```

## What to do if you see this file in production logs

If the app boots without `google-services.json` / `GoogleService-Info.plist`,
FCM SDK calls fail silently and the device never registers for push.
The DeviceService log line `firebase_messaging not configured` is the
canonical signal — drop the files in and rebuild.
