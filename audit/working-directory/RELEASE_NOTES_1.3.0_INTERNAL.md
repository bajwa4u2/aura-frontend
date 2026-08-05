# Aura 1.3.0 — Internal Release Notes

Release identity: `1.3.0+24` (previous: `1.2.3+23`)
Frontend range: `3c7cc2e..HEAD` (16 commits)
Backend range: `dc165f2..HEAD` (22 commits)
Date: 2026-08-05

## Communication and publication reliability

- Repaired publication errors and reconnected multilingual communication end-to-end (frontend `bf08d76`, backend `ddf7685`).
- Fixed a mojibake/encoding corruption defect in the institution post composer (`c140cb4`).
- Fixed the LinkedIn cross-post field name mismatch and appended the canonical Aura backlink to LinkedIn cross-posts (`8785b06`, `cdbf520`).
- Fixed institution-voice reply publish losing its draft while on Communication Integrity hold (`fdd9e91`).
- Reshare commentary and the embedded original post now render correctly on both the feed signal and the repost surface (`4da5b02`, `ff3d3c3`).
- Completed the institutional publication acknowledgement workflow (`781ef1c`).
- Institution post/reply/announcement moderation now targets the correct record instead of blending multiple institutions into one `publicStatus` value (`a914e2b`).

## Multilingual communication

- Added a governed communication translation cache and institution billing accounting for translation usage (`ddf7685`).
- Wired the translation action end-to-end from composer to repository (new: `communication_translate_action.dart`, `communication_translation.dart`, `communication_translation_repository.dart`).

## Governed topics

- Implemented governed topic relationships and secondary-topic suggestions on the backend (`fe8f9f3`), consumed on the frontend (`8551db7`).
- Fixed a topic repository response-envelope parsing defect that silently dropped governed suggestions (`21fefd1`).

## Communication Workspace and continuity

- Added Communication Continuity and Accountability views on the frontend (`c0f5bc8`), backed by a new continuity status computation and read contract on the backend (`b47696f`, plus the dedicated `continuity-read` module).
- Added Raise Issue acknowledgment (`5a6c697`), reconciled onto the same capability system as reply/resolve (`1fcaa8f`).
- Added Raise Issue Resolve and Reopen, bounded to one governed remediation cycle with append-only history (`f9b6455`, `4dabbdc`).
- Added a communication continuation cross-reference so related threads stay linked across the continuity surface (`79e92f8`).
- Share Update is now excluded from institutional routing, and Ask is capped at Responded — closing two cases where the wrong lifecycle state was reachable (`1a7cae9`).
- Restructured the composer's Enrichment/Governance UI and added ambient governance surfacing for personal posts (`d5f226d`).

## Notification, attention, and delivery improvements

- Completed canonical notification routing and the attention ledger (`aa5521c`); notification routing and attention gap inventory documented (`08c71a3`).
- Notify on Raise Issue resolve/reopen — closes a gap where reopening an accountability item did not notify anyone (`1d055ec`).
- Accountability Lifecycle notifications now render on the live Activity screen, with correct labels (`2cecce2`, `bdaf534`).
- Fixed institution-voice actor name/avatar on notifications and added the remaining Communication notification types (`345368e`).
- Severity-aware moderation labels now render on the Activity screen (F24) (`c69774f`, backend `9f66ce6`).
- Implemented the remaining Phase 4 founder decisions: F9 (Publish-Success = Record-Only), F10 (DM presence-awareness), F15 (Reopen notifies institution not individual), F24 (moderation severity from existing data) (`9f66ce6`).

## Realtime and messaging fixes

- Repaired clean migration replay for meeting conversation history (`6f49237`).
- Closed the provider independence and TURN TLS milestones (`4be443f`).

## General reliability and UX repairs

- Fixed Explore feed ordering and the institution reply review flow (`b9d79bc`).
- Feed and detail caches now refresh immediately after deleting a post/reply, closing the stale-content-after-delete defect (`a690480`).
- Reply preview now reorders after the action row, and a per-reply Like was added (`5d19381`).
- Repaired the canonical Jest configuration on the backend (`ab9e823`).

## Not included in this release

- The Eligibility, Identity & Institution Onboarding governance chapter is **governance-complete only**. No engineering implementation for account-age gating, identity verification, or institution-authority verification is included in this build. Do not describe or imply this capability in any store-facing material.

## Known limitations carried into this release

- iOS archive production cannot run on the Windows workstation; Codemagic remains the designated build environment for the signed IPA.
- The web release build reports the pre-existing `socket_io_common` WebAssembly dry-run compatibility warning; the standard JavaScript release build is unaffected and passes.
