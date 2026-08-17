# C4 DR1 — Legacy Global Attention Banner: Live Evidence + Mechanism Trace (2026-08-16)

**Status:** EVIDENCE RECORD for the C4 Attention reconstruction. No fix applied —
founder instruction: no isolated cosmetic patch; this surface is retired
comprehensively by C4 under the canonical Attention Authority.

## Live evidence (founder-observed + independently reproduced)

- Founder screenshot (Edge, Mrs Bajwa session): full-width bottom banner
  **"Mrs Bajwa started a call"** overlaying `/articles/write` — physically
  occupying the bottom of the authoring surface.
- Independently reproduced during live certification (Chrome, Zakria session):
  the same overlay rendered a bare **"M S Bajwa"** strip over `/messages`.
- Ruling: the CALL is not the subject. The defect class is **LEGACY ATTENTION
  PRESENTATION IS STILL ALIVE AND GLOBALLY OVERLAYS UNRELATED SURFACES.**

## The mechanism

It is **not** `global_live_banner_layer.dart`, `orphaned_session_banner.dart`,
or `floating_call_widget.dart` (those are top-anchored or a PiP card). It is a
**global floating `SnackBar`** pushed through an app-root
`GlobalKey<ScaffoldMessengerState>`:

- Emit sites (identical): `lib/core/notifications/notification_bridge.dart:294-308`
  (`_showForegroundSnackbar`, FCM foreground path) and `:425-440`
  (`_showForegroundNotification`, **polling path — the observed one**).
  Both: `SnackBar(behavior: floating, content: Text('$title — $body'), 4s)`
  via `auraScaffoldMessengerKey.currentState` (`:297`, `:428`).
- Global key: `notification_bridge.dart:21`.
- Mounted at app root: `lib/app/aura_app.dart:306-329` — `NotificationBridge`
  wraps `MaterialApp.router`, `scaffoldMessengerKey` bound at `:309`. The
  ScaffoldMessenger lives ABOVE the Router → route-independent → overlays every
  surface.
- Full-width generic look: `lib/app/aura_app.dart:441-449` (`snackBarTheme`).

### Text producers

`lib/core/notifications/notification_presentation.dart`
- `:85` — `'$actorName started a call'` (in `_callTitle`, `:70-86`)
- `:54` — bare display-name fallback (renders "M S Bajwa" with no verb)
- `:58` — `'Update'` last resort; entry points `resolveNotificationTitle` /
  `resolveNotificationBody` (`:31`, `:61`)

### Why calls leak into it

Skip filter `notification_bridge.dart:415-420` (`_isLiveInterrupt`) suppresses
only `isCallKind(kind) && attention == 'INTERRUPT'`. Any CALL-kind notification
without `attention: INTERRUPT` (or terminal MISSED/ENDED/DECLINED) falls
through `:405` → `:407` → `_showForegroundNotification` → "… started a call".

## Producers feeding it

- **A. Polling (observed):** `lib/features/updates/providers.dart:12-16`
  (`notificationsControllerProvider`) → `notifications_controller.dart:12`
  (120s poll, `:103-138` loop) → consumed at `notification_bridge.dart:326-331`
  (`ref.listen`) → `_handleNotificationUpdate` (`:383-409`).
- **B. FCM foreground:** `notification_bridge.dart:113` (`onMessage`) →
  `_onFcmForeground` (`:133-162`) → snackbar at `:154` and `:161`. Web variant
  `lib/core/notifications/sw_message_bridge.dart`.
- **C. Sockets** feed the sibling call surface (not this snackbar):
  `lib/features/updates/incoming_call_bridge.dart:7-63` +
  `lib/features/realtime/application/incoming_call_projection.dart`.

## Consumers that MUST SURVIVE retirement (same producers, independent surfaces)

- Canonical incoming-call experience: `incoming_live_overlay.dart:56`
  (`AuraIncomingLiveLayer`, merges bridge+poll `:500-530`), mounted via
  `thread_call_lifecycle_host.dart:27` → `aura_app.dart:321`;
  `floating_call_widget.dart:68` (PiP, fed by `realtimeControllerProvider` +
  `call_presence_bridge.dart`, NOT notifications);
  `thread_call_lifecycle_controller.dart` eviction sites;
  `native_call_notification_channel.dart` (cancelled from
  `incoming_live_overlay.dart:483`, `notification_bridge.dart:186`);
  `aura_app.dart:129, 244-267` auth-drop clear + resume reconciliation;
  `notification_open_reconcile.dart:88, 187`.
- Other `notificationsControllerProvider` consumers: activity_screen
  (`:93,:99,:433,:455,:485,:529`; own phrasing `:1176`),
  notifications_screen (`:38,:50,:131,:151,:172`), module_attention `:123`
  (nav badges → member_shell `:220-229`), messages_hub `:106`,
  correspondence_hub `:84`, since_you_were_here `:178`, mark-read call sites
  (institution_members `:62`, institution_post_detail `:66`, post_detail
  `:157`, meeting_detail `:62`, followers `:54`, announcement_detail `:286`),
  derived providers `providers.dart:18-25`, `:35-49`.
- Pin: `test/notifications/notification_presentation_test.dart:91` asserts
  `'Iffat started a call'`.

## Companion legacy global attention surfaces (same retirement inventory)

- `orphaned_session_banner.dart:32` — top rejoin banner ('You have an active
  call/meeting'), fed by `liveSessionsProvider` + `realtimeControllerProvider`,
  dismissal cache `orphaned_session_dismissal_cache.dart`. (MaterialApp builder,
  `aura_app.dart:320-326`.)
- `update_gate.dart:99-133` — `_SoftWarnBannerOverlay` top-center global banner.
- `global_live_banner_layer.dart:97` — top "LIVE NOW" join banner
  (member/institution shells `member_shell.dart:190-191`, `:352-353`), fed by
  `publicLiveDiscoveryProvider`, 8s auto-dismiss, 5-min cooldown.
- `active_meeting_return_layer.dart:17` — bottom-anchored floating pill
  (`Positioned(bottom: 18)`), fed by `activeMeetingReturnProvider` — the only
  other bottom-anchored global surface (pill, not full-width).
- **Dead code:** `aura_platform_components.dart:1075` — `AuraCallBanner`,
  zero call sites.

## Addendum (2026-08-16, later same day): stale-ACTIVE session feed confirmed

During live certification the strip became PERSISTENT over the conversation
composer in the Zakria session (blocking composition — independently
reproducing the founder's /articles/write observation). Production data
inspection found **five RealtimeSession rows stuck ACTIVE since
2026-08-12** on the legacy THREAD surface `cmsp7euhf00soqw0cjcrzh2d1`
(Bajwa↔Zakria direct thread; four started by cmm69u97n…, one by
cmsp7aos4…; all `answeredAt` set, `endedAt` NULL): `cmsps0jiw0059qk0c…`,
`cmspp1r1m01glnz0c…`, `cmspiuyp6023mpb0c…`, `cmsphxazx01v0pb0c…`,
`cmsphvdbe01t7pb0c…`. These orphans predate the Realtime Architecture
Correction closure and continuously feed the legacy attention layer.

Per founder instruction, NOTHING was patched or deleted — the stale rows
are themselves C4 evidence (lifecycle-convergence failure class) and the
retirement must handle both the presentation AND the orphaned-session
reconciliation under the canonical Attention/lifecycle authorities.

## Disposition

Held for C4 resume: this generic global banner/overlay is explicitly part of
the legacy Attention retirement inventory, to be eliminated/replaced per the
canonical Attention Authority. Conversation/call lifecycle work proceeds
independently and must not be conflated with this finding.
