# Aura Meetings Audit Baseline

Date: 2026-06-27

Scope:
- `aura-backend/`
- `aura_final/`

## 1. Backend module inventory

Meeting-related backend surface:
- `src/meetings/meeting.controller.ts`
- `src/meetings/services/meeting.service.ts`
- `src/meetings/services/meeting-session-bridge.service.ts`
- `src/meetings/services/meeting-code.service.ts`
- `src/meetings/services/meeting-email.service.ts`
- `src/meetings/services/meeting-guest.service.ts`
- `src/meetings/domain/meeting-room.ts`
- DTOs under `src/meetings/dto/`

Supporting runtime dependencies:
- `src/realtime/` for live session transport
- `src/availability/` for booking and windows
- `src/institutions/availability/` for institution-owned booking pages

Observed meeting model:
- `Meeting`, `MeetingParticipant`, `MeetingInvitation`, `MeetingBooking` exist in Prisma.
- There is no dedicated persisted `MeetingSummary` or `PostMeetingWorkspace` model.

## 2. Frontend route/screen inventory

Meeting surfaces found in Flutter:
- `MeetingsHomeScreen`
- `MeetingDetailScreen`
- `MeetingRoomScreen`
- `PreJoinScreen`
- `PublicBookingScreen`
- `SlotPickerScreen`
- `BookingConfirmScreen`
- `InstitutionAvailabilityScreen`
- `CreateMeetingScreen`
- `AvailabilitySetupScreen`
- `BookingCancelScreen`

Missing from the current implementation:
- dedicated guest waiting-room screen
- dedicated meeting summary screen
- dedicated post-meeting workspace screen
- dedicated host preparation workspace route

## 3. Backend/frontend API integration map

Frontend meeting repositories currently call:
- `GET /meetings`
- `GET /meetings/:id`
- `GET /meetings/join/:code`
- `POST /meetings`
- `POST /meetings/instant`
- `POST /meetings/:id/start`
- `POST /meetings/:id/end`
- `POST /meetings/:id/cancel`
- `POST /meetings/:id/invite`
- `GET /meetings/:id/participants`

Booking flow calls:
- `GET /book/:slug`
- `GET /book/:slug/slots`
- `POST /book/:slug`
- institution-owned booking equivalents under `/i/:institutionSlug/meet/...`

Institution availability calls:
- `/availability`
- `/availability/:profileId/windows`
- `/availability/:profileId/overrides`
- institution-owned equivalents under `/institution/:institutionId/availability/...`

Realtime transport is still a separate surface and is not the meeting source of truth.

## 4. Empty files

No empty files were confirmed under `aura_final/lib/features/meetings/` during this audit pass.

Project-wide files previously flagged by baseline instructions still need re-verification:
- `aura_final/test/widget_test.dart` / `lib/test/widget_test.dart` mismatch
- any empty placeholder screens outside the meetings feature

## 5. Dead files

No dead meeting files were confirmed during this pass.

Project-level dead/unused items still to verify from baseline:
- `aura-backend/src/app.controller.ts`
- `aura-backend/src/app.service.ts`
- `aura-backend/src/app-controller.spec.ts`

## 6. Duplicate providers/services

No duplicate meeting repositories were found in the current feature pass.

Important duplicate logic still exists:
- meeting lifecycle is computed both in backend `buildMeetingRoomSnapshot(...)`
- and frontend `MeetingLifecyclePresenter`

That duplication is functional today, but it is a consistency risk because both sides decide status text and primary actions.

## 7. Unregistered controllers

No unregistered meeting controllers were found in this pass.

Meeting controller is registered as:
- `src/meetings/meeting.controller.ts`

## 8. Suspicious half-done features

Confirmed meeting gaps:
- no first-class summary screen
- no first-class post-meeting workspace
- no dedicated guest waiting room screen
- no dedicated host preparation workspace route
- detail/home/room surfaces still carry some review/summary wording, but the related destination screens were missing

Confirmed backend state:
- meeting lifecycle snapshot exists and is time-aware
- stale ended realtime sessions are repaired when joining/starting
- meeting booking/participant data is enough to render attendance and source context
- there is no persisted meeting-summary model yet

## 9. Compile/build blockers

No meeting-specific compile blocker was confirmed in this pass.

Functional blocker:
- meeting home/detail/room action buttons can still route terminal states into non-terminal surfaces unless summary routes are added
- join flow still needed a dedicated waiting-room surface

## 10. Recommended Phase 1 patch list

Priority 1:
- add meeting summary screen
- add post-meeting workspace screen
- add dedicated guest waiting-room screen
- wire terminal actions to summary instead of detail/room

Priority 2:
- add a host preparation workspace route
- normalize start/join/summary navigation across institution and non-institution routes
- keep lifecycle labels/actions consistent between home, detail, room, and join surfaces

Priority 3:
- persist meeting follow-up artifacts once a summary model exists
- reduce duplicated lifecycle derivation by centralizing a single presentational adapter

