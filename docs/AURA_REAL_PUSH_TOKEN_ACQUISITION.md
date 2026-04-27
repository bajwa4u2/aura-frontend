# Real Push Token Acquisition

## Overview

This document covers the complete push token acquisition implementation for Aura, including Web Push subscriptions and the browser notification permission UX.

---

## Architecture

### Web Push (Browser)

The web push stack is split across three layers:

| Layer | File | Responsibility |
|---|---|---|
| Service | `web_push_service.dart` | Conditional export (web vs stub) |
| Web impl | `web_push_service_web.dart` | Browser Push API via `dart:js_interop` + `package:web` |
| Stub impl | `web_push_service_stub.dart` | No-op for non-web platforms |
| Types | `web_push_types.dart` | `WebPushResult` data class |
| Service worker | `web/push/sw.js` | Background push delivery and notification clicks |

### Mobile (Android / iOS)

FCM and APNS token acquisition is deferred — no Firebase SDK is configured. When Firebase is integrated, `DeviceService._buildPayload()` is the sole place to add FCM token lookup. The backend payload fields (`token`, `platform`, `provider`) are already defined and accepted by the backend.

---

## Service Worker

Path: `web/push/sw.js`  
Scope: `/push/` (default per web spec for scripts served from that directory)

The `/push/` scope avoids collision with Flutter's root-scope `flutter_service_worker.js`. Push events are delivered to any matching registration for the origin, regardless of whether the SW controls the active page.

### Event handlers

| Event | Behaviour |
|---|---|
| `install` | `skipWaiting()` — activates immediately |
| `activate` | `clients.claim()` — takes control of all open pages |
| `push` | Parses JSON payload, shows notification via `showNotification()` |
| `notificationclick` | Focuses an existing matching tab or opens a new one; closes the notification |

### Push payload format

The backend should send a JSON body with:
```json
{
  "title": "New message",
  "body": "You have a new message from...",
  "icon": "/icons/Icon-192.png",
  "badge": "/icons/Icon-192.png",
  "data": { "url": "/messages/abc123" }
}
```

If `data.url` is present, clicking the notification navigates to that URL.

---

## VAPID Key Configuration

The VAPID public key is injected at build time via `--dart-define`:

```bash
flutter build web --dart-define=AURA_WEB_PUSH_VAPID_PUBLIC_KEY=<base64url-encoded-key>
```

Accessed in Dart via `AppConfig.vapidPublicKey`. An empty key causes `WebPushService.subscribe()` to return `null` silently — no crash.

For local development without a VAPID key, the "Enable" button will do nothing (subscribe returns null, no backend call is made).

---

## Permission UX

### Rules

- **Never request permission on app load** — always user-initiated.
- The browser's permission prompt is triggered only when the user explicitly taps "Enable" on the Security screen.
- If permission is already `granted`, the section shows an "Active" badge.
- If permission is `denied`, the section shows "Blocked" and guidance text explaining how to re-enable via browser settings.

### `BrowserNotificationsSection` widget

Lives in `notification_permission_tile.dart`, rendered in `security_screen.dart` behind `if (kIsWeb)`.

States:
| `_permission` | `_supported` | UI shown |
|---|---|---|
| any | false | "Unavailable" label |
| `'granted'` | true | "Active" green badge |
| `'denied'` | true | "Blocked" red label + guidance text |
| `'default'` | true | "Enable" button |

Tapping "Enable" calls `DeviceService.requestAndRegisterWebPush(vapidKey)` which:
1. Requests browser permission (`Notification.requestPermission()`)
2. Subscribes via `PushManager.subscribe()` with the VAPID key
3. PATCHes the existing backend device record if a device ID is known, otherwise registers a new device
4. Returns `true` on success, `false` on any failure

---

## `DeviceService` integration

### Silent subscription check on registration

`DeviceService.registerCurrentDevice()` calls `_buildPayload()` which, on web, silently checks for an existing `PushManager` subscription via `WebPushService.getExistingSubscription()`. If one exists (e.g. permission was granted in a prior session), the subscription keys are included in the registration payload immediately — no user prompt needed.

### Token refresh

No explicit periodic token refresh is implemented. The 30-minute presence debounce in `refreshPresence()` re-calls `registerCurrentDevice()`, which re-reads the existing subscription on every resume. Web Push subscriptions are long-lived and self-renewing; the endpoint changes only if the user clears site data.

---

## Backend Payload

### Web Push device record

```json
{
  "platform": "WEB",
  "provider": "WEB_PUSH",
  "token": "<endpoint-url>",
  "endpoint": "<endpoint-url>",
  "webPushP256dh": "<base64url-encoded-p256dh-key>",
  "webPushAuth": "<base64url-encoded-auth-secret>",
  "deviceName": "Web",
  "appVersion": "1.0.0",
  "locale": "en_US",
  "timezone": "UTC"
}
```

The `token` field is set to the push endpoint URL, which is the stable upsert key for web devices. Both `token` and `endpoint` contain the same value.

---

## Files Changed

| File | Type | Change |
|---|---|---|
| `lib/features/devices/web_push_types.dart` | NEW | `WebPushResult` data class |
| `lib/features/devices/web_push_service.dart` | NEW | Conditional export |
| `lib/features/devices/web_push_service_web.dart` | NEW | Browser Push API implementation |
| `lib/features/devices/web_push_service_stub.dart` | NEW | Non-web stub |
| `lib/features/devices/device_service.dart` | MODIFIED | Async `_buildPayload`, `requestAndRegisterWebPush` |
| `lib/config.dart` | MODIFIED | `vapidPublicKey` getter |
| `web/push/sw.js` | NEW | Push service worker |
| `lib/features/me/presentation/notification_permission_tile.dart` | NEW | `BrowserNotificationsSection` widget |
| `lib/features/me/presentation/security_screen.dart` | MODIFIED | Renders `BrowserNotificationsSection` on web |
