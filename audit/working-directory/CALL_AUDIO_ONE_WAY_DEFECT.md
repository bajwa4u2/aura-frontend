# Live defect — audio is one-way to the Pixel

**Date:** 2026-09-11
**Reported by:** founder, during post-cutover call validation — *"calls not
connecting"*, then *"video connected"*, then *"audio not connecting"*.
**Status:** REPRODUCED, three times, on production. Root cause NOT yet located.

    SYMPTOM            ANDROID SENDS AUDIO BUT RECEIVES NONE
    REPRODUCIBILITY    3 of 3 audio-only calls
    VIDEO              UNAFFECTED
    CAUSED_BY_CUTOVER  NO — founder: audio calls have ALWAYS stayed "Connecting"
    SECOND DEFECT      CONNECTING HAS NO EXIT — see section below

## The measurement

`bytes` in the `op=LIVE` trace is the sum of `bytesReceived` over every
`inbound-rtp` stat on the peer connection, all kinds. So `bytes=0` means **no
RTP of any kind arrived**, which rules out a playback or routing problem on the
device — nothing reached it to play.

Session `cmtwv3xtp00d0p40cmrd4p8t5`, audio-only, 11:17:48 to 11:19:30:

    11:17:59   iOS       bytes=759       (media_flowing)
    11:18:20   iOS       bytes=58430
    11:18:50   iOS       bytes=141035
    11:19:20   iOS       bytes=223612

    11:18:25   android   bytes=0
    11:18:55   android   bytes=0
    11:19:25   android   bytes=0

Three samples, 90 seconds, never a single byte. Session
`cmtwv02fj004ep40cs7uofsks` at 11:14 is the same shape: iOS 65952, android 0.

The founder hears Zakria. Zakria hears nothing. The Pixel's own publish
succeeded — `seq=2 op=PUBLISH trig=MEDIA_READY runMs=655 result=ok` — which is
consistent with iOS receiving real bytes.

## It is not the client's track plumbing

The Android bind audit is clean, with every drop counter at zero:

    android   bind_complete  server=1 transceivers=3 receiving=2 bound=1
                             noMid=0 noLine=0 dirUnreadable=0 noTrack=0

`resolveRemoteBindings` discards a binding on three conditions and all three
report zero. The remote audio track was matched to a receiving m-line and
attached. iOS reports **the identical** accounting and does receive media, so
the bind numbers do not separate the working case from the broken one.

What this rules out is the client's own track-attachment rule. **It does NOT
establish where the failure is**, and the two live possibilities must not be
collapsed:

    (a) a receiving AUDIO track was never negotiated at all; or
    (b) an audio track exists and receives zero packets.

These have different causes and different fixes. The `kinds=` trace was built
to separate them and was never captured, so **neither may be inferred** —
founder instruction, 2026-09-11. Earlier phrasing in this record that leaned
toward (b) was over-stated and is withdrawn.

## Video is unaffected

Session `cmtwv2ejn008ep40cbrehkzdp`, 11:16, with video:

    both      bind_complete  server=2 transceivers=4 receiving=2 bound=2
    android   render_attached withVideo=1 attachedVideoTracks=1
    android   bytes=18375 -> 389948
    iOS       bytes=120390 -> 2518576

Android received RTP in that call. **Whether the audio kind was among it cannot
be told from these logs** — see the instrumentation defect below — so "video
works" is proven and "audio works when video is on" is not.

## What this is not

Not a bind-count problem. `server=1 ... bound=1` in an audio-only call with one
remote participant is **correct**: the peer publishes one track, so the server
offers one binding. The earlier reading that `server=1` was itself the fault was
wrong; `receiving=2` is a spare m-line, not a missing subscription.

**Not caused by the production cutover.** Founder, 2026-09-11: audio calls have
*always* stayed at "Connecting". This is long-standing, not a regression from
`07dcd29b`, and the deployment is cleared of it.

That it survived a prior Chrome↔Pixel call certification is itself worth
noting: the certification proved signalling and presentation, which are exactly
the parts that do work here. `CONNECTED` was never the assertion.

## The second defect — CONNECTING has no exit

Founder: *"if one was hearing still wrong"*. Correct, and it is a separate
defect from the audio itself.

The chain is confirmed end to end in code:

    inbound bytes > 0  ->  onMediaFlowing  ->  reportMediaEstablished
      ->  CallMediaEndpoint.mediaEstablishedAt  ->  evaluateConnected

`evaluateConnected` requires the caller's device **and** the accepting callee's
device to have reported media before it writes `connectedAt`. That rule is
right, and its comment says why: *"One endpoint alone hears silence and would
still be told the call had connected."* Refusing to claim CONNECTED here is
honest.

What is missing is any way out. `CallPhase.CONNECTING` has exactly one
transition into it (`call-lifecycle.service.ts:481`) and **no timeout, sweep,
deadline or watchdog anywhere** — grep finds none. So a call where one side
never receives media sits in CONNECTING until a human hangs up:

  * the person who CAN hear sees "Connecting…" indefinitely while audio plays;
  * the person who cannot hear sees the identical screen, and nothing tells
    them they are the side with the problem;
  * no failure is raised, no degraded state is shown, no diagnostic surfaces.

The teardown record is honest — `deriveOutcome` returns
`ACCEPTED_NOT_CONNECTED` — but that is written only when the call ends, so it
documents the failure after the fact and never shows it to anyone during it.

A CONNECTING deadline that resolves to a stated, visible condition would have
made this defect self-reporting instead of something the founder had to notice.

## Two instrumentation defects that hid this

**1. The per-kind breakdown is computed and then discarded.**
`_mediaBytesByKind` returns `{audio: n, video: m}` and `_armLivenessProbe`
immediately folds it to a single sum for the `op=LIVE` line. The one question
this defect turns on — *is audio arriving?* — is measured every three seconds
and never written down. Adding the kinds to the trace is a one-line change and
would have answered it on the first call.

**2. `bind_complete` is reported while half-bound.**
The code chooses the label with `audit.bound == audit.serverBindings`, ignoring
`audit.receivingLines`. A client with two receiving m-lines and one binding
prints `bind_complete`. It should be `bind_partial` whenever
`bound < receivingLines`; as written, a half-bound client reports success.

## Next diagnostic

The cheapest decisive step is the per-kind trace, because it distinguishes "no
audio track is arriving" from "nothing at all is arriving on this transport",
and those have different causes. After that, the Android candidate-pair and
DTLS state during a live call — the Pixel is attached over adb, so this is
readable without a new build if the trace carries it.

---

## Session end state — 2026-09-11, testing stopped by the founder

**The `kinds=` trace was never captured.** The instrumented build is installed
and working, but no audio call reached it while it was warm, so the question
this record exists to answer — `audio=ABSENT` vs `audio=0b` — is still open.

    INSTRUMENTED APK ON THE PIXEL   sha256 669cb776547d565757ad4d10882e38229228261fbcfca1c948a280673d3b27e9
                                    versionCode 38 / 1.4.3, side-loaded
                                    CORRECTED 2026-09-11 post-restart — see
                                    "Artifact hash correction" below. The value
                                    this line carried, fe9f0678…, was already
                                    stale when it was written.
    CLIENT EDITS                    UNCOMMITTED in the aura_final working tree
                                    (sfu_realtime_transport.dart only)
    BACKEND                         UNTOUCHED. Nothing deployed.
    APPLE BUILD 38                  UNTOUCHED. NOT in App Review — it is in
                                    TestFlight beta review; corrected
                                    2026-09-11, see APPLE_BUILD_38_REVIEW_STATE.md

**The Pixel is NOT running the shipped build.** Anyone testing on it next is
testing a locally modified binary. The clean release APK was overwritten at
`build/app/outputs/flutter-apk/app-release.apk` by the instrumented one, so
restoring it means rebuilding.

## A third suspected defect — incoming calls on a COLD app

The 19:25 UTC call was never presented on the Pixel, and the reason is not the
reinstall:

  * the FCM push ARRIVED — `FlutterFirebaseMessagingBackgroundService started!`
    at device 15:25:30, matching the server's `fcm.push_sent` at 19:25:30 UTC
    exactly (the device clock runs UTC-4);
  * the Telecom account is still registered — `ComponentInfo{org.auraplatform.app/...}
    Capabilities: SelfManaged`;
  * the app process had been alive 5m24s, so **the push itself cold-started it**.

Every call that DID ring today (11:14, 11:16, 11:17) had the app already open
and foregrounded on the Pixel. This one reached a cold app, woke it, and
presented nothing.

**Recorded as SUSPECTED, not proven.** A reinstall sits between the working
calls and this one, so "cold start is broken" and "cold start is broken after a
reinstall" are not yet separable. Settling it needs a clean release APK
installed, the app launched once and then backgrounded or killed, and one call.

If it holds, it outranks the audio defect: a phone that only rings while the
app is already open is not ringing.

---

# HOLD — founder instruction, 2026-09-11

    AURA CALL INVESTIGATION = HOLD
    NO MORE LIVE CALLS      = TRUE
    SESSION                 = STANDBY

## Status of each finding, as frozen

    ONE_WAY_AUDIO_TO_PIXEL            CONFIRMED
    ROOT_CAUSE                        NOT RESOLVED — do not infer
    CONNECTING_HAS_NO_EXIT            CONFIRMED DEFECT
    COLD_START_INCOMING_CALL_FAILURE  SUSPECTED, NOT PROVEN — confound preserved

The unresolved diagnostic question, stated once so it cannot drift:

> Was a receiving AUDIO track never negotiated, or does an audio track exist
> and receive zero packets?

Not established. Not to be inferred from anything already recorded above.

## Pixel artifact state — read this before testing anything

    PIXEL CURRENTLY RUNS AN INSTRUMENTED LOCAL BUILD
    NOT THE CERTIFIED / SHIPPED ARTIFACT
    VERSION LABEL STILL READS         1.4.3 (38)
    INSTRUMENTED APK SHA256           669cb776547d565757ad4d10882e38229228261fbcfca1c948a280673d3b27e9
    CERTIFIED RELEASE APK SHA256      3bd637fe2d44b664e85842a613f01e4e2db883134df40726a68c6ead090ffadc
                                      NO LONGER PRESENT ANYWHERE ON DISK

**`versionName` and `versionCode` do not prove artifact identity.** Both builds
report `1.4.3 (38)`. Only the sha256 distinguishes them. The certified APK was
OVERWRITTEN at `build/app/outputs/flutter-apk/app-release.apk`, so restoring it
requires a rebuild from the frozen source.

### Artifact hash correction — 2026-09-11, post-restart recovery

**This record named the wrong artifact, and it named it wrongly from the moment
it was written.** The value it carried, `fe9f0678…`, describes a build that
exists nowhere on this machine and is not the one installed on the Pixel.

What the device actually carries, established by pulling `base.apk` off it and
hashing the bytes rather than reading a label:

    PIXEL /data/app/…/base.apk        sha256 669cb776547d565757ad4d10882e38229228261fbcfca1c948a280673d3b27e9
    build/app/outputs/flutter-apk/    sha256 669cb776…        IDENTICAL
    APK built                         2026-09-11 16:01:33 EDT
    APK installed (lastUpdateTime)    2026-09-11 16:02:17
    sfu_realtime_transport.dart       2026-09-11 15:57:20     BEFORE the build
    files changed after the build      NONE under lib/ or any tracked path

**How it went stale.** This document was last written at 15:44. The
instrumented source was edited again at 15:57, rebuilt at 16:01 and reinstalled
at 16:02 — all *after* the hash line was committed to the page, and the line was
never revisited. A record that pins an artifact must be re-pinned by whoever
rebuilds it, or it silently becomes a claim about a binary nobody is running.

**What this does and does not change.** The installed APK is byte-matched to the
current working tree, so the `kinds=` instrumentation IS on the device and the
diagnostic path is genuinely available. It changes nothing about any finding:
`fe9f0678…` was never the basis of an observation, only of an inventory line.
`ONE_WAY_AUDIO_TO_PIXEL`, `CONNECTING_HAS_NO_EXIT` and
`COLD_START_INCOMING_CALL_FAILURE` stand exactly as frozen.

## The uncommitted edit

    FILE      aura_final/lib/features/realtime/data/sfu_realtime_transport.dart
    STATE     UNCOMMITTED, working tree only, on main
    CONTENT   (1) per-kind bytes added to the op=LIVE trace
              (2) bind_complete now requires bound >= receivingLines,
                  so a half-bound client reports bind_partial

    DO NOT push, merge, deploy, or let it enter the release branch.

`flutter analyze` is clean on the file. Neither edit touches the media hot
path, the binding rule, or any call behaviour — only what gets written down.

## Clean reproduction procedure, for whoever resumes

The next session must DELIBERATELY CHOOSE one of these before doing anything.
Do not default into either.

**Path A — reproduce from the certified baseline.**
1. `flutter build apk --release` from the frozen source; confirm sha256
   `3bd637fe…` before installing. If it differs, stop: the tree is not frozen.
2. `adb install -r` that artifact.
3. Launch once, then background or kill the app.
4. One audio call. This tests the COLD path and is what separates the
   cold-start defect from the reinstall confound.

**Path B — obtain the missing diagnostic trace.**
1. Keep the instrumented build already installed (`669cb776…`). **But read the
   founder ruling below first: that build is not a pure diagnostic overlay, and
   Path B as written may no longer be the right shape.**
2. Open Aura on the Pixel and leave it FOREGROUNDED — the warm path is the one
   known to ring.
3. Place one audio call; leave it up at least 40s (the probe reports every 30s,
   so it needs a full cycle).
4. Read the server log and find `kinds=` on the `platform=android` line:
       kinds=audio=ABSENT video=…   -> possibility (a), never negotiated
       kinds=audio=0b     video=…   -> possibility (b), negotiated, no packets
5. `railway logs --service aura-backend` DUMPS AND EXITS — it does not stream.
   Poll it after the call; do not try to capture during.

Path A answers the cold-start question. Path B answers the audio question.
Neither answers both, which is why the choice has to be made on purpose.

## Release state — unchanged by any of this

    PRODUCTION CUTOVER   NOT REOPENED. One-way audio is pre-existing relative
                         to the cutover and does not invalidate the authorized
                         backend/web convergence.
    APPLE BUILD 38       UNTOUCHED. TestFlight beta review, NOT App Review
                         — corrected 2026-09-11.
    BUILD 39             NOT to be generated because of this investigation
                         unless a demonstrated release-specific defect requires it.
    BACKEND              UNTOUCHED. Nothing deployed.

## Separate workstreams — preserved, NOT authorization to continue

  * mobile billing steering governed only by server configuration
  * `/moderation/reports` existence-oracle concern
  * production schema drift
  * blocked Windows Partner Center `stage`
  * voice note stored as VIDEO — see `VOICE_NOTE_BECOMES_VIDEO_BACKEND.md`
    (root cause established, nothing changed, nothing deployed)
