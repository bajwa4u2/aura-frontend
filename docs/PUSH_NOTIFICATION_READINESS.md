# Push Notification Readiness

Aura now has a durable push architecture layered on top of the existing communications and realtime systems.

## Models

### `UserDevice`
Global device registry for authenticated users.

Fields:
- `userId`
- `platform`: `WEB | IOS | ANDROID | DESKTOP`
- `provider`: `WEB_PUSH | APNS | FCM`
- `token`
- `endpoint`
- `webPushP256dh`
- `webPushAuth`
- `deviceName`
- `appVersion`
- `userAgent`
- `locale`
- `timezone`
- `isActive`
- `lastSeenAt`
- `revokedAt`
- `createdAt`
- `updatedAt`

### `PushDeliveryAttempt`
Audit trail for push delivery and skips.

Fields:
- `userId`
- `deviceId` nullable
- `communicationId` nullable
- `type`
- `provider`
- `status`: `QUEUED | SENT | FAILED | SKIPPED`
- `failureCode`
- `failureReason`
- `payloadJson`
- `createdAt`

## Endpoints

Authenticated device management:

- `POST /v1/devices/register`
- `GET /v1/devices/me`
- `PATCH /v1/devices/:id`
- `DELETE /v1/devices/:id`

Rules:
- users can only manage their own devices
- registration upserts safely on `(userId, provider, token)`
- revoked or inactive devices never receive push

## Push delivery service

`PushNotificationService` exposes:

- `sendForCommunication(communicationId)`
- `sendToUser(userId, payload)`
- `sendToDevice(deviceId, payload)`

Delivery flow:
1. communication is created
2. push routing checks communication preferences
3. active devices for the recipient are loaded
4. provider adapter sends or skips with a recorded attempt
5. failures are recorded, but the core app flow does not crash

## Provider adapters

### APNs
Uses:
- `APNS_TEAM_ID`
- `APNS_KEY_ID`
- `APNS_BUNDLE_ID`
- `APNS_PRIVATE_KEY` or `APNS_PRIVATE_KEY_PATH`

### FCM
Uses:
- `FCM_SERVER_KEY`

### Web Push
Uses:
- `WEB_PUSH_VAPID_PUBLIC_KEY`
- `WEB_PUSH_VAPID_PRIVATE_KEY`
- `WEB_PUSH_VAPID_SUBJECT`

Web Push is credential-aware and transport-aware. If credentials are missing, or the transport library is unavailable, delivery is skipped and logged rather than faked.

## Call ringing flow

Realtime invites and call-start paths already emit canonical attention/communication events.

For call ringing:
- live invite/start attention maps to `notificationKind = CALL_RINGING`
- missed calls map to `notificationKind = CALL_MISSED`
- `CommunicationsService.create()` now routes these communications into push delivery
- callers are excluded by the existing recipient filtering
- websocket behavior remains unchanged

## Frontend / mobile contract

Expected client responsibilities:
- register a device after login/session restore
- send platform/provider/token plus optional metadata
- refresh `lastSeenAt` by re-registering periodically or on app resume
- revoke the device on logout or explicit device removal

Recommended client payload for registration:
- `platform`
- `provider`
- `token` or `endpoint`
- `webPushP256dh`
- `webPushAuth`
- `deviceName`
- `appVersion`
- `userAgent`
- `locale`
- `timezone`

## Known future work

- add a dedicated browser push worker/service-worker delivery path if browser push transport is enabled
- add mobile SDK wiring for APNs/FCM token refresh and background handling
- add user-facing push preference controls if product wants explicit push opt-out independent of device revocation
- replace the FCM legacy key path with service-account HTTP v1 when the infrastructure is ready
- decide whether Web Push should depend on an installed `web-push` package or a dedicated push gateway

