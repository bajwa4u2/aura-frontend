# Correspondence Entry Flow Repair

Date: 2026-08-08
Repository: aura_final
Status: implemented locally, certified, not committed, not pushed

## Founder Evidence

Production public-user flow failed at the communication entry surface:

- selecting one member worked;
- searching/selecting a second member removed or replaced the first;
- creating the resulting private/shared conversation failed with backend validation;
- the Messages/Correspondence create flow was unreliable at the point of starting communication.

This chapter is a focused defect repair. It does not reopen Meetings, Reachability Authority, Session Continuity Authority, Canonical Call Notification Stage A, Thread Call Lifecycle Stage 1, or Device Communication Presence Phase 1.

## Root Causes

1. Selected-member state was split between persistent selected IDs and entries derived from the current search cache. When search results changed, a previously selected member could fall out of `_allEntries`; `_selectedEntries` then lost that member, and the submitted payload matched the broken UI state.
2. The frontend exposed Circle, Workroom, and Salon creation modes, but the backend accepted only `PRIVATE`, `CIRCLE`, and `STUDIO`. Workroom/Salon submissions hit backend validation before creation.
3. Submit errors surfaced as generic Dio exceptions rather than safe, actionable application errors.

## Frontend Repair

`NewConversationScreen` now stores selected entries by ID independently of the current relationship/search result set. Search query changes no longer destroy prior selections. Selection appends, duplicate selection is ignored, and deselection removes only the intended selected user. The UI chip summary is now the same state that is submitted.

Creation mode behavior:

- one selected other person and no shared-space title submits a private one-to-one conversation;
- two or more selected people, or an explicit shared-space title, submits shared-space creation;
- Circle, Workroom, and Salon remain distinct visible modes;
- current user is filtered from relationship/search selections client-side and remains defensively excluded backend-side.

`CompositionAssist` received a layout-only responsive fix because it is embedded by the shared-space details surface and could overflow on constrained widths. No composition behavior or network contract changed.

## Contracts

One-to-one private conversation:

- endpoint: `POST /spaces`
- payload: `type: PRIVATE`, `visibility: PRIVATE`, `participantIds: [otherUserId]`, `title: <other display name>`
- backend excludes current user and requires exactly one other participant for `PRIVATE`
- existing private space reuse remains preserved

Shared/multi-party conversation:

- endpoint: `POST /spaces`
- payload: `type: CIRCLE | WORKROOM | SALON | STUDIO`, `visibility: PRIVATE`, `participantIds: [selected others]`, `title: <required>`, optional `description`
- `STUDIO` remains accepted for backward compatibility although the current public entry UI exposes Circle, Workroom, and Salon

## Verification

Flutter certification:

- focused `test/new_conversation_screen_test.dart`: 5/5 passed
- `flutter analyze`: passed
- practical non-golden suite: 130/130 passed
- web release build: passed

Backend certification for the corresponding contract repair is recorded in `../aura-backend/docs/2026-08-08-correspondence-entry-flow-contract-repair.md`.

## Shared-System Health

- Meetings: untouched.
- Reachability Authority: untouched.
- Session Continuity Authority: untouched.
- Canonical Call Notification Stage A: untouched.
- Thread Call Lifecycle Stage 1: untouched.
- Correspondence/Spaces: directly touched and covered by focused frontend/backend tests.
- Auth/session/member search/navigation: indirectly exercised by focused widget tests and practical Flutter suite.
- Shared `CompositionAssist`: directly touched for layout only; practical Flutter suite and analyzer passed.

## Deferred

No product redesign was performed. Broader improvements such as richer mode education, Activity integration, or new public-space taxonomy remain out of scope unless separately authorized.
