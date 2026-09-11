# Aura 1.4.3 (38) — Artifact Manifest

**Date:** 2026-09-11
**Branch:** `release/aura-1.4.3-38` on both remotes. `main` untouched on both.

    client   b0b1c411fd2de77c8b425365cee8ffb45312bde4   github.com/bajwa4u2/aura-frontend
    backend  649fad720e4e80aa07b7711a2478b25b3fe1174a   github.com/bajwa4u2/aura-backend

Both trees clean (tracked files) at build time, asserted in the same command
that produced the artifact rather than checked separately afterwards.

---

## Android — app bundle

    path        build/app/outputs/bundle/release/app-release.aab
    sha256      cae409bce6a54dfb0330e0c9e714fa8fd7881168726cb3e8d11d6e037d1bb720
    size        80,741,457 bytes
    signed by   META-INF/UPLOAD.RSA  (Play upload key, not debug)

**versionCode and versionName were read out of the artifact's own protobuf
manifest**, not taken from `pubspec.yaml`:

    base/manifest/AndroidManifest.xml   versionCode = 38
                                        versionName = 1.4.3

**38 is free**, confirmed against Google Play on 2026-09-11 rather than
assumed. Accepted `versionCode`s are `[1, 3, 24, 25, 27, 35, 36, 37]`.

**A note on reproducibility, offered as an observation and not a guarantee.**
This bundle was built twice, at `b78bf3ef` and again at `b0b1c411`, and came out
byte-identical — the commits between them touched only tests and records, never
`lib/`. That is a useful signal, not a claim of reproducible builds.

## Web — pinned certification artifact

    output      build/web_cert2   (built against the isolated stack, not production)
    sha256      4d2743cb53296c4aff6c041f5dce0f1b133eb47712a82699e7117fb95885adc2
                (main.dart.js)

This artifact exists to be DRIVEN, not shipped: the deployed web surface is
built by Railway from the branch it is given. It is pinned here because the
web certification lane must name the bytes it exercised.

**Reproducible only from an LF checkout.** This repository sets
`core.autocrlf=false` and carries no `.gitattributes`, so a clone made where
`core.autocrlf` is true would check the Dart sources out with CRLF and could
produce a different hash for identical content.

## iOS — see the platform certification record

The IPA is produced by Codemagic (`ios-testflight`) from the same release
branch. Its provenance — source commit, Flutter/Dart, Xcode/iOS SDK, signing
and provisioning, version and build, archive — is recorded with the iOS result
in `INSTITUTION_VERIFICATION_PLATFORM_CERTIFICATION.md` rather than duplicated
here, because a second copy of a fact is a second thing that can drift.

## What is NOT built here

**Windows / Microsoft Store.** Unchanged for this release and blocked upstream
on a founder identity action: Partner Center's Entra tenant association
requires a Global Admin sign-in, which is not mine to perform. No Windows
artifact is claimed.

## Not submitted, and not deployed

No artifact here has been uploaded to any store, and none of this is running in
production — `api.auraplatform.org/health` reports `0b92237d`, which is
`origin/main`. Store submission and the production cutover are the founder's.
