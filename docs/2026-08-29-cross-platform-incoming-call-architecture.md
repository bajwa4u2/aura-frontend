# Cross-platform incoming call — traced system and frozen contract

Date: 2026-08-29 · Scope: Conversation/thread call sessions. **Meetings is a
protected surface and is not touched.**

## 1. What already exists (traced, not inferred)

The call-arrival contract is **already canonical**. It was not missing; only
two of four platforms consume it.

```
caller
 → correspondence-orchestrator.service.ts        ← call-session authority
 → buildCanonicalIncomingCallNotification()      ← invitation projection
 → toIncomingCallSocketPayload()  → realtime socket  (in-app overlay)
 → toDirectCallPushPayload()      → PushNotificationService.sendToUser()
 → deviceRegistry.listActiveForUser(userId)      ← multi-device fan-out
 → per-device adapter: FCM | APNS | WNS | WEB_PUSH
 → device
```

`CanonicalIncomingCallNotification` already carries everything the contract
needs: `sessionId`, `realtimeSessionId`, `inviteId`, `mediaMode`/`callKind`,
`expiresAt`, `correspondenceId`/`threadId`/`spaceId`, actor identity
(`displayName`, `handle`, `avatarUrl`), `recipientUserId`, `activeDeeplink`,
`contextDeeplink`, and `collapseKey = sessionId` as the dedup identifier.

**No new schema is required.** Inventing a parallel invitation model would be
the wrong move.

### Authorities

| Concern | Authority |
|---|---|
| Call session | `correspondence-orchestrator.service.ts`, `realtime-session.service.ts` |
| Invitation lifecycle | PENDING invite rows + **periodic TTL sweep** on `expiresAt` |
| Expiry | backend sweep — not the device |
| Cancellation cleanup | silent `CALL_CANCELLED` fanned to **every participant** |
| State transitions | `INVITE_DECLINED` / `INVITE_EXPIRED` / `INVITE_ACCEPTED` / `SESSION_ENDED` |
| Device registry | `deviceRegistry.listActiveForUser` |
| Dedup | `collapseKey` / tag = `sessionId` |

Native UI is **never** a call-state authority. It renders backend truth.

### Known contract gap, already recorded upstream

`RealtimeSessionStatus.CANCELLED` is never written. The runtime cannot
distinguish *caller withdrew before anyone accepted* from *session ended*.
`event-contract.ts` documents this as Phase 3 scope and forbids fabricating
`SESSION_CANCELLED` from notification cleanup. **This work inherits that
limitation and must not paper over it**: "caller cancelled" and "call ended"
present identically today.

## 2. Platform reality — audited from released code

| | Delivery | Presentation | Verdict |
|---|---|---|---|
| **Android** | FCM data-only (`deviceOwnsCallPresentation`) | `AuraCallPushReceiver` → `IncomingCallPresenter`: `CallStyle.forIncomingCall`, full-screen intent, `ongoing`, `FLAG_NO_CLEAR`, `FLAG_INSISTENT` | **Most complete.** Real ring. |
| **Web** | `WEB_PUSH` subscription | `web/push/sw.js` — recognises `CALL_RINGING`/`LIVE`, `requireInteraction` for calls, tagged, `notificationclick` → deeplink | **Second most complete.** |
| **iOS** | FCM alert + `aps{sound,badge}` | **none** — `AppDelegate.swift` is stock Flutter boilerplate | banner at best; **no call experience** |
| **Windows** | **none** | **none** | `_nativePushPayload()` returns `null` for every platform except android/ios. No device is ever registered. |

Two findings worth stating plainly:

**Windows registers no push device at all.** The backend ships a
`WnsPushAdapter` and a `windows-store` distribution; the client never creates a
row for them, so `listActiveForUser` cannot return one. Windows call arrival
works **only** while the app is open and the realtime socket is connected. This
is not a tuning problem — the leg does not exist.

**iOS is not "missing a ring", it is missing an architecture.** An FCM alert is
a notification. A call is a call. Apple's supported model is a PushKit VoIP
push delivered to CallKit; the repo already knows this — `Info.plist` warns
that claiming the `voip` background mode without PushKit + CallKit is a
rejection trigger, which is why only `remote-notification` is claimed today.

## 3. Frozen determinations

These follow from platform behaviour and are engineering calls, not product
choices:

1. **iOS ⇒ PushKit + CallKit.** A VoIP push must always report an incoming call
   to CallKit or iOS kills the app. That makes the VoIP push a *distinct
   registration path* with its own token — modelled intentionally beside the
   FCM token, never overloaded onto it.
2. **Android keeps its native presenter.** It already satisfies the contract.
   Converge it to shared semantics; do not rewrite it. `FLAG_INSISTENT` is
   reviewed per context rather than applied blindly.
3. **Windows gets a real delivery leg** — register a `windows-store` device and
   implement actionable toast plus activation. Visual parity with CallKit is
   not the goal; identical *semantics* are.
4. **Web is classified, not upgraded past the platform.** Foreground and
   background-tab notification with click-to-join is the honest ceiling;
   terminated-browser ringing is not available and will not be claimed.
5. **Shared arrival semantics, platform-specific adapters.** One contract, four
   presentations — not four ringing systems.

## 4. Observability — a narrower gap than assumed

The send side is already instrumented with `sessionId` correlation:
`call.invite.push_attempt` (device count, providers, ring policy),
`call.invite.push_sent`, `call.invite.push_failed`, and an explicit
`NO_ACTIVE_DEVICES` warning.

The silent failure that hid the iOS defect was **client-side registration**,
where a null token produced only a `debugPrint`. `fa55e8c` fixed the timing
cause; the reporting gap — a device that never registers is invisible to the
backend — remains open and is the observability work that matters.

## 5. Status

Traced and frozen. Implementation of the iOS PushKit/CallKit layer, the Windows
delivery leg, Android convergence and the multi-device reconciliation proof has
**not** started. No client build has been cut. `BUILD_28` remains held.
