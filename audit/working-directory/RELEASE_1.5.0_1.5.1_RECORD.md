# Release record — Aura 1.5.0 (40/42) and 1.5.1 (43), 2026-09-25

Detailed evidence: `aura/release-notes/frozen/1.5.0+40-pixel-2026-09-25b/FROZEN.md`
and `aura/release-notes/frozen/1.5.1+43-windows-2026-09-25/FROZEN.md` (outside git).
Store copy: `aura/release-notes/v1.5.0.md`.

## Where each platform stands

| Platform | Version | Source | State |
|---|---|---|---|
| Web | 1.5.0 (42) | `4ef86f59` | Live (Railway SUCCESS 10:00 UTC) |
| Google Play | 1.5.0 (40) | `3adbc7fb` | Submitted 100%, managed publishing off; **release notes empty** |
| iOS | 1.5.0 (42) | `4ef86f59` | Submitted to App Review 06:48 EDT; TestFlight 40/41 expired |
| Microsoft | 1.5.0.0 | `3adbc7fb` | Live (Submission 16) |
| Microsoft | 1.5.1.0 | `9180a492` | Submission 17 draft: package saved; listing text to be pasted by founder; not submitted |

## What 1.5.0 carries (over 1.4.4)

Meetings stage rebuild; calls rebuild (PiP card, either side of a two-person call may end,
audio-only sink, C-1 receiver rebuild, ICE asked not mirrored); dock auto-hide (video only);
composer video preview (poster rule + local copy over 401 origin); Android voice notes typed
as audio (backend `8188c4f`); `/i/` links on every platform (contract + AASA + Windows web link);
feed video autoplay (public, member, institution explore) with feed-wide mute; viewer starts
on open; C0/C1/C3 gates and Android link contract repaired.

## Defects found during certification and their outcomes

1. **Build 40 dock** — band persisted / audio controls hid. Fixed `c7a4cdb6`; Pixel pass.
2. **Four gate tests red on the frozen build** — found after the first web deploy because only
   subset suites had been run. Fixed on the autoplay branch. Lesson: run the full suite before
   calling a build certified.
3. **iPhone-as-caller silent** (video both ways, no audio; audio-only "not connecting").
   ROOT CAUSE from the iPhone's own syslog: the callee's `participant.accepted` reached the
   caller, the incoming-call bridge projected "stop ringing", and its choke point reported the
   system call ended — the CallKit UUID is derived from the session id in both directions, so it
   ended the caller's own call and CallKit deactivated the audio session. Present since
   `5ffed711` (1.4.2). Fixed `16b545d1` (placed-call registry; `reportRingEnded`; controller ends
   the system call on remote hang-up). TestFlight 42 founder-passed. Build 41's iOS
   audio-session reverts (`2609aaa2`) did not fix it and were kept as harmless.
4. **Viewer clock frozen at 0:00** once the viewer auto-started (all platforms). Fixed in
   `00aa6092`.
5. **Windows showed a frame instead of playing** — `video_player` had no Windows
   implementation. `video_player_win` added (`00aa6092`); feed autoplay and viewer playback
   certified on the release build.

## Open

- Microsoft 1.5.1.0: paste listing text, then founder submits.
- Windows unverified: browser-recorded (WebM/Opus) voice note, composer video attach, audible
  sound after unmute.
- Play release notes once 40 is live. Play/Microsoft 1.5.0 lack the caller fix (no audio
  effect on Android/Windows; the system call record ends early on Android).
- App Store Connect review contact email is Gmail.
- Voice notes stored as `video/mp4` before `8188c4f` remain mis-typed (data decision pending).
- `feature/windows-video-player` (`00aa6092`, `9180a492` + records) must reach `main`.
