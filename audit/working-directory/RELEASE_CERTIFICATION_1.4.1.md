# Aura 1.4.1 — release certification

**Date:** 2026-09-01
**Released source:** tag `v1.4.1` = `52ff2ee76fa2992a42dec664286359f9e6676784`
**Backend at release:** `f4d144a` (deployed, healthy)
**Status:** submitted on all three stores; web already live

---

## 1. What shipped, and from where

One source revision produced every client artifact. `main` and `release/1.4.1`
were identical at `52ff2ee` when the builds were cut, and the tag pins it.

| Platform | Artifact | Version | Identity |
|---|---|---|---|
| iOS | `aura.ipa`, Codemagic build #33 | 1.4.1 (36) | `org.auraplatform.app` |
| Android | `app-release.aab` | 1.4.1 (36) | `org.auraplatform.app`, upload key `84:39:92:54…` |
| Windows | `aura.msix` | 1.4.1.0 | `AuraPlatformLLC.AURAPLATFORM` |
| Web | Railway `aura-frontend` | 1.4.1+36 | live at app.auraplatform.org |

**Submission state at close of day:**

* **iOS** — submitted to TestFlight by the founder, already approved.
* **Android** — uploaded and submitted to **Closed testing – Alpha** (the same
  track 1.4.0 (35) shipped to on Aug 30). This app has never been in
  Production; that remains a separate, deliberate decision.
* **Windows** — Partner Center **Submission 12**, badge reads *Update in
  certification*. The draft inherits everything from Submission 11, so the
  carried-forward v1.4.0.0 package had to be replaced rather than left in
  place — a submission made without that step would have recertified 1.4.0.

**The MSIX of record** was rebuilt in the main checkout so exactly one exists
on disk:

```
aura_final/build/windows/x64/runner/Release/aura.msix
32,736,952 bytes
sha256 d612d007cfa06676326dac2177272625294d441e0760167f08b70b1c7d047223
built from 7eafeb1 (= v1.4.1 plus the codemagic revert, which compiles into
nothing)
```

An earlier MSIX built in the `aura_final-calling` worktree, and a copy placed
on the Desktop, were both deleted. Two paths for one artifact is a defect in
its own right.

---

## 2. What was actually certified

**Calling, on physical hardware, bidirectionally.** Full record in
`aura-backend/docs/2026-09-01-calling-production-certification-and-three-repairs.md`.

The frozen sequence proven end to end on a **locked** iPhone:

```
21:19:27  call.invite.push_attempt  deviceCount=2  FCM/ANDROID,APNS/IOS
21:19:33  callkit push_received     PushKit handler reached report      (5s)
21:19:34  callkit presented         reportNewIncomingCall succeeded     (6s)
21:19:34  call.presentation         ESTABLISHED  installation=a23c0bb7…
21:19:42  call:terminal             reason=ACCEPTED
          (no fallback_presents — the 12s deadline passed unused)
```

Teardown without an answer, run twice, identical: `reason=CANCELLED`
distinguished from `DECLINED` and `AUTO_ENDED`, cancel delivered to both FCM
endpoints, APNS correctly skipped, and the lock-screen call UI dismissing on
its own. Reverse direction (iPhone → Android) answered and ended cleanly.
Two-way media confirmed on both sides.

**What was not certified:** everything else. Messaging, media, admin and the
rest of 1.4.1 were not re-exercised. The analyze gate was fixed and the
artifacts were built; no broad functional pass was run. There is no 36-point
matrix — an exhaustive search of both repositories found no such canon, and
none was invented.

---

## 3. Four defects found and fixed during release, all verified in production

Each was found by placing a real call and reading production. **A green suite
proved nothing here: 4193 tests passed against all four.**

| # | Defect | Fix |
|---|---|---|
| 1 | `installationId` stamped only in `POST /devices/register`, but clients POST once then always PATCH → **0 of 37** devices ever grouped | `01b2630` |
| 2 | An APNS row **is** a VoIP token, so every `CALL_CANCELLED` was rejected `400 DeviceTokenNotForTopic` — 44 against 25 sends | `19a6ec5` |
| 3 | Fallback grace was 3s, derived from other constants, never measured; a cold PushKit wake takes 6–7s → second ring on every locked call | `380d501` |
| 4 | `call.invite.fallback_immediate` warned on every teardown, worded as though a ring had failed | `cb0a084` |

They masked each other in that order. **#1 kept the fallback from ever arming**
— it is gated on `companions.length > 0` — so #3 was unreachable until #1 was
fixed, and #2 only surfaced once real calls ran end to end.

---

## 4. Carried into the next release

1. **The presentation ack now retries** — `2775c28`, bounded at 0.8s / 2s / 4s,
   all inside the server's 12s grace, 4xx never retried. **Deliberately not in
   1.4.1**: the released source is tagged and already submitted. It exists
   because one locked call rang while the server received nothing for ~28s, so
   "silence means it did not ring" is empirically false. The 12s grace makes
   that race unlikely; the retry addresses the cause.
2. **Institution identity verification** stays FOUNDER-DEFERRED — see
   `aura-backend/capability/IDENTITY_VERIFICATION_DEFERRED_TO_NEXT_RELEASE.md`.
3. **`installationId` coverage was 3/36** at release. It fills in as each device
   next launches; no action needed.
4. **The `aura_final-calling` worktree** still exists and holds duplicate build
   outputs. It should be removed so there is one checkout and one set of
   artifacts.
