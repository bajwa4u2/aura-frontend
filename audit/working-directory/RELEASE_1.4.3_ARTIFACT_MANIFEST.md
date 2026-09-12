# Aura 1.4.3 (38) — Artifact Manifest

**Date:** 2026-09-11
**Branch:** `release/aura-1.4.3-38` on both remotes. `main` untouched on both.

    client   191642d3562ab4f3f7418c90d9ccc9814103f2b5   github.com/bajwa4u2/aura-frontend
    backend  4856728e641ebe4f7029c5079295682f75005343   github.com/bajwa4u2/aura-backend

Both trees clean (tracked files) at build time, asserted in the same command
that produced the artifact rather than checked separately afterwards.

---

## Android — app bundle

    path        build/app/outputs/bundle/release/app-release.aab
    sha256      a1887009fc1bff076ae7031111a601dfa0d8fa9b1de6b82f64cdb574dc231fb2
    size        80,741,455 bytes   (corrected 2026-09-11; the line read
                …457, a transcription error. The sha256 above matches the
                file exactly, so the bytes were always the pinned bytes.)
    signed by   META-INF/UPLOAD.RSA  (Play upload key, not debug)

**versionCode and versionName were read out of the artifact's own protobuf
manifest**, not taken from `pubspec.yaml`:

    base/manifest/AndroidManifest.xml   versionCode = 38
                                        versionName = 1.4.3

**38 is free**, confirmed against Google Play on 2026-09-11 rather than
assumed. Accepted `versionCode`s are `[1, 3, 24, 25, 27, 35, 36, 37]`.

**Reproducibility, measured rather than assumed.** This bundle was built at
four commits across the session. It came out byte-identical wherever `lib/` was
untouched, and CHANGED when `lib/` gained fifteen lines of **comment** — Dart's
AOT snapshot embeds source metadata that a comment moves. The web artifact did
NOT change on that same commit, because `dart2js` drops it.

That matters for one claim in particular, so it is written down: **byte
equality is not available as a proof that two commits produce the same app.**
Where that question arises below, it is answered by showing that no executable
statement differs, which is the stronger answer anyway.

## Web — pinned certification artifact

    output      build/web_final   (built against the isolated stack, not production)
    sha256      4d2743cb53296c4aff6c041f5dce0f1b133eb47712a82699e7117fb95885adc2
                (main.dart.js)

This artifact exists to be DRIVEN, not shipped: the deployed web surface is
built by Railway from the branch it is given. It is pinned here because the
web certification lane must name the bytes it exercised.

**Reproducible only from an LF checkout.** This repository sets
`core.autocrlf=false` and carries no `.gitattributes`, so a clone made where
`core.autocrlf` is true would check the Dart sources out with CRLF and could
produce a different hash for identical content.

## iOS — ACCEPTED BY APPLE AS BUILD 38

    artefact    aura.ipa                      37,917,528 bytes
    sha256      cc61b21f76aa334b0e4868bafb94e48e43acd1a02dfbaa8e3b97f7f52e9d9d10
    CFBundleShortVersionString   1.4.3
    CFBundleVersion              38          <- read from the artifact Apple processed
    extension   org.auraplatform.app.ShareExtension  1.4.3 + 38
    SDK         iphoneos26.5  ·  Xcode 26.6  ·  MinimumOSVersion 15.0
    Flutter     3.47.3  ·  Dart 3.13.3  ·  mac_mini_m2
    signing     AURA PLATFORM App Store Profile 5762789e-82c5-4d66-adb9-eaba498c83a9
                + Aura ShareExtension App Store Profile, both ACTIVE
    ASC build   adf9d5ea-314b-4904-87c0-4839a8d5f616  (app 6772071135)
    verdict     accepted and processed, no error

**BUILD 38 IS NOW CONSUMED ON APPLE'S SIDE.** Any further iOS artifact for
1.4.3 must carry 39 or higher. Apple rejects a duplicate outright, which is
also why this acceptance is the authoritative answer that 38 was free.

**THE ONE DEVIATION FROM "ALL ARTIFACTS FROM THE EXACT COMMIT", stated plainly
rather than smoothed over.** This IPA was built from `5d9bfcdd`, not from the
freeze commit. Between the two, `lib/` changed by exactly **fifteen comment
lines and no executable statement** — measured, by counting every added or
removed line in `lib/` that is not a comment or blank, and finding zero. The
remaining commits touched tests, goldens, CI configuration and records, none of
which ship.

Byte equality was attempted as the proof and failed, for a reason worth
knowing: a comment moves the AOT snapshot. So the claim made here is the
behavioural one — no executable statement differs — and it is not dressed up as
a byte claim. Founder accepted build 38 on this basis, 2026-09-11.

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
