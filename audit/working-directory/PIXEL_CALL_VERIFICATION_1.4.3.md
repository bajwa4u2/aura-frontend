# Pixel 9a call verification — after the 1.4.3 production cutover

**Date:** 2026-09-11
**Authorised by:** founder — *"After backend + web are confirmed current, use the
Pixel 9a release APK for the call/runtime validation. A call test before the
backend cutover would exercise the wrong server generation and would not certify
the 1.4.3 system."*

    SIGNALLING_END_TO_END        PROVEN
    INCOMING_CALL_PRESENTATION   PROVEN
    MEDIA_CONNECTED              NOT CERTIFIED — see the two limits below

## The generation under test

    PRODUCTION_BACKEND   07dcd29b   (deployment 1dde31e4)
    PRODUCTION_WEB       76177ce7   (deployment 1fc1cf08)
                         CORRECTED 2026-09-11 post-restart. This line read
                         109f0cc1 / 95e35405; that deployment is REMOVED and
                         1fc1cf08 was the live one. The web BYTES are identical
                         across the two (main.dart.js sha256 0749d167…, 76177ce7
                         is documentation-only), so the artifact exercised by
                         this verification is unchanged and nothing below is
                         affected. Only the commit label was wrong.
    PIXEL_APK            sha256 3bd637fe2d44b664e85842a613f01e4e2db883134df40726a68c6ead090ffadc
                         versionCode 38 · versionName 1.4.3, read from the artifact
    DEVICE               Pixel 9a, 53061JEBF08485, signed in as Muhammad Zakria

The device being signed in as Zakria is why this rings the attached handset
rather than a third party.

## What was proven

An audio call was placed from Chrome on thread `cmtdalbpw000fmp0c9qpt4ywf`.

**1. Signalling reached the device.** Android Telecom reported it, which is the
platform's own account and not the app's:

    Call id=51d81918-336a-4c9a-81a5-ee46dfcc8f11, state=RINGING,
    tpac=ComponentInfo{org.auraplatform.app/...}, handle=aura:***,
    cap=[ hld sup_hld], prop=[ self_mng], voip=true
    Ringing calls: [same]
    Audio mode: MODE_RINGTONE

`prop=[ self_mng]` is the self-managed VoIP path: the app presents the
incoming-call UI, not Android. The chain Chrome (new web build) -> production
backend (`07dcd29b`) -> Pixel (new APK) -> Android Telecom RINGING is therefore
established on the new generation.

**2. The call was presented and joined.** A screenshot of the device shows
Aura's own in-call screen: header "Audio call", a participant count of 2, the
callee identified as **M S Bajwa**, and the full control bar — Mute, Share,
Earpiece, More, Leave.

This retires an earlier suspicion. A first screenshot taken ~5s after the click
showed a browser on another site while Telecom said RINGING, which looked like a
presentation defect. It was screenshot timing: the second capture shows the call
screen, and `dumpsys` independently agreed the call existed. **A screen-based
finding was not reported as a defect until a second method confirmed it** — the
Chrome extension has twice produced false visual artifacts in this session, so
one screenshot is not evidence.

## What was NOT proven, and why

The captured frame reads **"Connecting…"**, not connected. The backend writes
`Call.connectedAt` only when every required endpoint has reported a usable media
path, so that field — not a screen — is the authority on whether media was
established. Two things prevented closing it:

  * **The Chrome tab was `visibility: hidden` and unfocused** for the whole
    attempt (`document.visibilityState === "hidden"`, `hasFocus() === false`,
    1142x613). A hidden tab is throttled, and this session has already recorded
    that no web-side media or timing measurement may be quoted in that state.
    Attempts to bring the window forward did not change it.
  * **The production `Call` record could not be read.** Both routes to it —
    `railway variables` and `railway run` against the production database — were
    refused by the permission classifier. This was not worked around.

The call subsequently ended; Telecom's call list is empty and the device has
moved to another app. `AHal::VoiceCall` did show echo-reference setup and
teardown on the speaker path at 07:07:26 / 07:07:29, which is consistent with
audio routing having been engaged, but routing engaged is not media flowing and
is not offered as proof of it.

## Disposition

    SIGNALLING       CERTIFIED on the 1.4.3 generation
    PRESENTATION     CERTIFIED on the 1.4.3 generation
    MEDIA            OPEN — requires a visible Chrome tab, or a read of
                     Call.connectedAt / CallMediaEndpoint for this call

Closing the media half needs one of: a foreground browser window on the
operator's desktop, or permission to read the production `Call` row. Neither is
a product finding; both are harness limits, and they are recorded as such rather
than reported as a pass.
