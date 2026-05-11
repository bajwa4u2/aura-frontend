# `web/.well-known/` — public verification files for deep-link domains

These files are required for Android App Links and iOS Universal Links
to bind the `auraplatform.org` domain to the installed app. Without
them the OS treats every tap on an `https://auraplatform.org/...` URL
as a browser navigation and never opens the app.

Both files **must be served verbatim at the site root**, with no
authentication and no redirects:

- `https://auraplatform.org/.well-known/assetlinks.json`  → Android
- `https://auraplatform.org/.well-known/apple-app-site-association` → iOS
  (no `.json` extension; Content-Type `application/json`)

## Placeholders that MUST be replaced before any store submission

### `assetlinks.json`

Replace the two `sha256_cert_fingerprints` entries with:

1. The SHA-256 fingerprint of the **upload keystore** used to sign the
   AAB you upload to Play Console. Get it with:

   ```bash
   keytool -list -v -keystore aura_final/android/upload-keystore.jks \
     -alias upload | grep SHA256
   ```

2. The SHA-256 fingerprint of the **Play App Signing** certificate
   (issued by Google when you opt in to Play App Signing). Copy it
   from Play Console → App integrity → App signing.

Both fingerprints are required: the upload key proves you authored
the upload, the Play key is what user devices see after install.

### `apple-app-site-association`

Replace every occurrence of `REPLACE_WITH_APPLE_TEAM_ID` with your
10-character Apple Developer Team ID. Visible at
`developer.apple.com → Account → Membership`. The full string is
`<TEAM_ID>.<bundle_id>` — e.g. `A1B2C3D4E5.org.auraplatform.app`.

The bundle id is fixed at `org.auraplatform.app` (Android namespace
+ iOS bundle).

## Verification

After deploy:

```bash
# Android: should fetch JSON, status 200, content-type application/json
curl -i https://auraplatform.org/.well-known/assetlinks.json

# iOS: same, no .json extension, content-type application/json
curl -i https://auraplatform.org/.well-known/apple-app-site-association
```

Then test the App Link verifier:

- Android: `adb shell pm verify-app-links --re-verify org.auraplatform.app`
- iOS: launch a TestFlight build and tap a Universal Link; the link
  should open in the app, not Safari.

Until both files contain real values, the app falls back to the custom
`aura://` scheme (still works for internal flows; doesn't claim
https URLs).
