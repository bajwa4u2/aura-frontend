# Aura calls: the test list

Founder decision, 4 Nov 2026: "write the test list first". Calls stop being
fixed one finding at a time. A release that changes calls ships only when every
test below passes, and no new call feature is started until they all do.

Same day: "we will mature our own system and not use the livekit". Aura keeps
its own call room on Cloudflare, and this list is how that room matures.

## Rules

- **Store builds only:** App Store / TestFlight iPhone, Play-installed S24,
  Microsoft Store Windows app, and Chrome on auraplatform.org. A cable or adb
  install does not count, because the system grants it permissions a store
  install does not have (lesson of 28 Oct).
- **Same backend as users:** production. No deploys while a test run is going.
- **One test, one call.** A failure is written down with its time (ET) and the
  call is not retried until the cause is known.
- **Evidence for each call:** you say what you heard and saw. I read the
  server log for the same call and record the numbers below.

## What "pass" means for every call

| Check | Pass |
|---|---|
| Rings | The callee's device rings within 3 s of the call being placed, in the state the test names |
| Connects | Both people hear each other within 8 s of Accept (video: also see each other) |
| Sound both ways | Server log shows audio sent AND played on both devices |
| Ends | When one side ends, the other side's call ends within 2 s, on its own |
| Nothing left over | No green call pill on the iPhone, no call notification on Android, no call still open on the server one minute later |
| History | The call shows in both people's history with the right result (connected, declined, missed, cancelled) |

## The tests

**Ringing.** The S24 and the iPhone are each called while open, in the
background, locked and fully closed. Voice calls.

| # | Caller → callee | Callee's state | Result |
|---|---|---|---|
| 1 | S24 → iPhone | app open | |
| 2 | S24 → iPhone | app in background | |
| 3 | S24 → iPhone | locked | |
| 4 | S24 → iPhone | app closed (swiped away) | |
| 5 | iPhone → S24 | app open | |
| 6 | iPhone → S24 | app in background | |
| 7 | iPhone → S24 | locked | |
| 8 | iPhone → S24 | app closed (swiped away) | |
| 9 | Chrome → Windows app | open | |
| 10 | Chrome → Windows app | minimised | |
| 11 | Windows app → Chrome | tab in background | |

**Connecting: voice and video, every pair.**

| # | Call | Result |
|---|---|---|
| 12 | iPhone → S24, video | |
| 13 | S24 → iPhone, video, answered from the lock screen | |
| 14 | Windows app ↔ S24, voice | |
| 15 | Chrome → iPhone, video | |

**During the call.**

| # | What happens | Pass | Result |
|---|---|---|---|
| 16 | Voice call: tap speaker, then earpiece, on the S24 and on the iPhone | Each tap moves the sound at once, and the button shows where it is | |
| 17 | Mute and unmute on each side, once from inside Aura and once from the iPhone's call screen | The other side hears silence, then the voice again, and both mute buttons agree | |
| 18 | Bluetooth headset or earbuds connected mid-call | Sound moves to the headset, and back when it is disconnected | |
| 19 | Callee puts Aura in the background for 30 s, then comes back | Sound never stops, and the picture returns | |
| 20 | S24 switches from Wi-Fi to mobile data mid-call | Call recovers within 10 s without anyone pressing anything | |
| 21 | Chrome side reloads the page mid-call | Call comes back, and the other device does not crash or freeze | |

**Ending.**

| # | What happens | Pass | Result |
|---|---|---|---|
| 22 | Caller hangs up | Callee's call ends within 2 s | |
| 23 | Callee hangs up | Caller's call ends within 2 s | |
| 24 | Hung up from the system screen (iPhone call screen, Android notification) | Ends on both sides within 2 s | |
| 25 | Declined from the lock screen | Caller is told "declined" within 2 s | |
| 26 | Caller gives up before the callee answers | Ringing stops on all the callee's devices within 2 s | |
| 27 | Nobody answers | Ringing stops by itself, and both see a missed call | |

**One call after another.**

| # | What happens | Result |
|---|---|---|
| 28 | A second call straight after the first, same direction | |
| 29 | A second call straight after the first, other direction | |
| 30 | A call arrives while the keyboard is open in a conversation | |

## Known failures to fix before the first full run (3 Nov 2026)

- **Test 23:** the S24 hung up, and the iPhone stayed in the call until it was
  ended by hand.
  - Cause: ending was left to the remaining phone noticing it was alone.
  - Fix (4 Nov, server): when one person hangs up and nobody else is in the
    call or still being rung, the server ends the call for everyone.
- **Tests 13, 29:** a call answered from the iPhone lock screen sent and played
  no sound, and ended after 90 s as not connected.
  - Cause: an answered call waited for iOS to hand over the audio, and the
    handover never came. The previous call was most likely still held by iOS.
  - Fix (4 Nov, iPhone, needs 1.7.3): answering or placing a call ends any
    call still held. Audio starts at once if iOS already has it, or after 3 s
    at the latest.
- **Tests 9, 10:** Microsoft's push service refused the ring to a Windows
  device (HTTP 400).
  - Cause: call rings carried two headers that are allowed only on visible
    notifications, with a value longer than allowed. Every call ring to
    Windows was refused.
  - Fix (4 Nov, server): headers removed; a ring older than 60 s is dropped.
- **All tests:** Cloudflare sometimes takes 8 s to answer one request.
  - Cause: all three 8-second waits on 3 Nov were the S24 asking for the
    iPhone's audio, which never existed (the fault above). The one slow
    start on its own was 7.7 s, once, on 2 Nov.
  - Watch it in the full run; no separate fix yet.

## Runs

**6 Nov 2026 · ~7:30 PM ET — founder decision for 1.7.3 (53):** "release 100% across stores, we will
experience and see what need fixes when happens". 1.7.3 carries the iPhone answered-call audio change
(b0b2ac27; Android and Windows call code unchanged since 1.7.2) and shipped WITHOUT a full pre-release
run. The tests below are ticked from real calls as they happen on the store builds; any failure is fixed
in the next release.

| Date (ET) | Builds | Passed | Failed tests |
|---|---|---|---|
| | | | |
