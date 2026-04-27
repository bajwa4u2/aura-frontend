# Aura Frontend — Device Registration Lifecycle

Complete frontend integration of the device registration lifecycle against the push notification backend.

## Files Changed

| File | Type | Summary |
|------|------|---------|
| `lib/features/devices/device_model.dart` | New | `UserDevice` model with fromJson |
| `lib/features/devices/device_repository.dart` | New | HTTP client for all 4 device endpoints |
| `lib/features/devices/device_service.dart` | New | Orchestration: metadata, persistence, debounce |
| `lib/features/devices/device_providers.dart` | New | Riverpod providers for repo + service |
| `lib/app/aura_app.dart` | Modified | ConsumerStatefulWidget, WidgetsBindingObserver, auth listener |
| `lib/features/auth/auth_controller.dart` | Modified | Best-effort revoke at logout |

---

## Architecture

### `DeviceRepository`
Thin HTTP client. Maps to the four backend endpoints:

```
POST  /devices/register   → register(payload) → UserDevice
GET   /devices/me         → getMyDevices()    → List<UserDevice>
PATCH /devices/:id        → updateDevice(id, fields) → UserDevice
DELETE /devices/:id       → revokeDevice(id)
```

All calls use the app-wide `dioProvider` (includes auth token injection).

### `DeviceService`
Stateful orchestrator. Holds:
- `_cachedDeviceId` — server-assigned device UUID (in-memory, also persisted)
- `_lastPresenceRefresh` — last resume registration timestamp for throttling

Methods:
- `registerCurrentDevice()` — builds metadata payload, calls register, persists device ID
- `revokeCurrentDevice()` — looks up persisted device ID, calls revoke, clears storage
- `refreshPresence()` — throttled re-registration on app resume (30-minute minimum gap)

### Providers

```dart
deviceRepositoryProvider   Provider<DeviceRepository>
deviceServiceProvider      Provider<DeviceService>
```

---

## Registration Triggers

### 1. Auth state transition (login + session restore)
`aura_app.dart` watches `isAuthedProvider`. When it transitions from `false` → `true`, `registerCurrentDevice()` fires:

```dart
ref.listen<bool>(isAuthedProvider, (prev, next) {
  if (next && !(prev ?? false)) {
    ref.read(deviceServiceProvider).registerCurrentDevice();
  }
});
```

Covers:
- Login via password → `AuthController.login()` → `_invalidateAuth()` → `isAuthedProvider` recomputes
- Session restore via bootstrap → `store.setSession()` → `notifyListeners()` → `isAuthedProvider` recomputes

### 2. Already-authed at startup
If the app boots with a valid access token already in storage (from a prior session), `isAuthedProvider` is `true` from the first frame and the listener above never fires. The `addPostFrameCallback` in `initState` handles this:

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (mounted && ref.read(isAuthedProvider)) {
    ref.read(deviceServiceProvider).registerCurrentDevice();
  }
});
```

### 3. App resume (foreground presence)
`_AuraAppState` implements `WidgetsBindingObserver`. On `AppLifecycleState.resumed`:

```dart
ref.read(deviceServiceProvider).refreshPresence();
```

`refreshPresence()` is internally throttled to once per 30 minutes using an in-memory timestamp.

### 4. Revoke at logout
`AuthController.logout()` fires revocation in the `try` block before the server logout call, while the access token is still valid:

```dart
unawaited(ref.read(deviceServiceProvider).revokeCurrentDevice());
```

Best-effort: fire-and-forget, never blocks or interrupts the logout flow.

---

## Platform + Metadata Resolution

`DeviceService._buildPayload()` resolves platform and metadata:

| Platform | `platform` | `provider` |
|----------|-----------|-----------|
| `kIsWeb` | `WEB` | `WEB_PUSH` |
| Android | `ANDROID` | `FCM` |
| iOS | `IOS` | `APNS` |
| macOS / Windows / Linux | `DESKTOP` | `FCM` |

Additional metadata:
- `appVersion`: `String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0')`
- `locale`: `PlatformDispatcher.instance.locale.toString()`
- `timezone`: `DateTime.now().timeZoneName`
- `deviceName`: human-readable platform string (e.g., `"iOS"`, `"Web"`, `"macOS"`)
- `token`: `''` (empty — push tokens wired in a later phase)

---

## Local Device ID Persistence

`SharedPreferences` key: `aura_device_id`

- Written after a successful `register()` response (only if `device.id.isNotEmpty`)
- Read on revoke to identify which device to delete
- Cleared after a successful revoke
- In-memory cache (`_cachedDeviceId`) avoids repeated SharedPreferences reads

---

## Web Push Readiness

Architecture is in place for web push:
- Platform is correctly identified as `WEB` / provider `WEB_PUSH`
- Payload structure includes `token`, `endpoint`, `webPushP256dh`, `webPushAuth` fields
- Registration upserts safely on `(userId, provider, token)` even with empty token

To enable actual web push delivery, the app needs to:
1. Request `Notification` permission from the browser
2. Create a service worker with a push event handler
3. Call `PushManager.subscribe()` with the VAPID public key
4. Pass the resulting `endpoint`, `p256dh`, and `auth` to `registerCurrentDevice()` or `updateDevice()`

No permission prompt is shown automatically — this is intentional until the product decides on the UX for the opt-in.

---

## Error Handling

Every `DeviceService` async method wraps its body in `catch (_) {}`. Registration and revocation failures are silently swallowed. The app's auth flow and logout are never blocked or affected by push device state.

---

## Circular Import Avoidance

`dio_provider.dart` imports `session_bootstrap.dart` for the 401-retry bootstrap check. This means `session_bootstrap.dart` cannot import `device_providers.dart` (which imports `dio_provider.dart`) without creating a cycle.

The registration triggers live entirely in `aura_app.dart`, which is upstream of both, avoiding the cycle:

```
aura_app.dart
├── device_providers.dart → dio_provider.dart → session_bootstrap.dart
└── session_providers.dart → session_bootstrap.dart   (separate chain)
```

---

## Validation Results

```
flutter analyze   → No issues found
flutter test      → All tests passed (1/1)
flutter build web → ✓ Built build/web
```
