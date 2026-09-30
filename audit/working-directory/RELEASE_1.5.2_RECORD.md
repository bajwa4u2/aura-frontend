# Release record — Aura 1.5.2 (44), 2026-09-30

One version on every store (founder: "all stores must match the version").
Source `108176b0`. iOS was built from `6a993d49`, whose only change is a test;
`lib/` and `pubspec.yaml` are identical. Store copy: `aura/release-notes/v1.5.2.md`.

## Where each platform stands (Wednesday, September 30, 2026 · 10:28 AM ET)

| Platform | Version | State |
|---|---|---|
| Web | 1.5.2 (44) | Live (Railway) |
| Microsoft | 1.5.2.0 | **Published**. Submission `1152921505702011218`, committed 9:35 AM; "What's new" set by API and read back |
| Google Play | 44 (1.5.2) | **In review**, production full rollout, managed publishing off (publishes on approval). Release notes from the internal release; no device changes |
| iOS | 1.5.2 (44) | **Waiting for Review**, submitted 10:27 AM. Codemagic #61; review notes rewritten for 1.5.2; review contact support@auraplatform.org |

## What 1.5.2 carries (over 1.5.0/1.5.1)

- Night Chamber look everywhere (DD-25).
- Posts ask what they are (Ask / Raise an issue / Share an update), gated by identity verification.
- Right-to-left scripts read right to left.
- Feed media is centred on desktop.
- Video posters: frame from a moment in; restricted videos show the server's poster.
- Dates are written in full with their time.
- Search-engine listing preference.
- "Start a conversation".
- The caller fix, now on Android and Windows too.
- Windows video playback (1.5.1).

## Found and fixed during the release

1. **Feed media start-aligned on desktop** (founder). Fixed in the shared widgets (`cac762b4`), with a measured test and an updated golden.
2. **Codemagic #58 failed at Flutter test.** Two untagged golden comparisons (made on Windows, compared on macOS) in `compose_intent_at_publish_test.dart`. Fixed by `expectReferenceGolden` plus a gate test (`6a993d49`).

## Tooling added

- `scripts/play_upload_internal.py`: bundle to the internal track with notes. It validates by default and changes Play only with `--commit`.
- Play Console: typing into the release-notes box does not register; "Copy from a previous release" does.

## Open

- **"Require intent": switch back ON once Play and iOS are live**, not before, or older store builds cannot post.
- Windows items still not checked by a person: a browser-recorded voice note, composer video attach, sound after unmute.
- Firefox web calling is untested, and the callee is not told the caller dropped (Richard's call, 2026-09-28).
