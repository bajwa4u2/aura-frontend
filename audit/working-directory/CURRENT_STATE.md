# Current State — aura_final

Last updated: 2026-07-21 UTC

Repository documentation is authoritative. Conversation history is temporary. This continuity set was established 2026-07-21 (workspace-wide continuity doctrine); prior history is reconstructed from git history and the ROS Phase II records.

## Identity

Aura Meetings Flutter frontend (single codebase: iOS + Android + Web). Three application shells (Member / Institution / Admin) + Public shell; talks to `../aura-backend` under global `/v1`. Aura is verified-identity civic discourse infrastructure — see `AGENTS.md`. WebRTC engine: `lib/features/realtime/` (`realtime_controller.dart`, `realtime_media_service.dart`, `realtime_socket_service.dart`).

## Production baseline

- Production web deployment at `auraplatform.org`, deployed via Railway. The 2026-07-13 record confirms pushing `main` auto-deployed the web build (verified by asset-hash change + live screenshot). Re-verify auto-deploy still holds before relying on it.
- Mobile: version `1.2.2+22` was the last recorded release commit (`4f6c2a5`). iOS distribution runs through the founder's manual Codemagic/App Store flow.

## Implementation status

- Working tree clean; `main` HEAD `b845820` pushed to `origin/main` (`bajwa4u2/aura-frontend`).
- `b845820` = ROS Phase II fidelity restoration (2026-07-13, founder-authorized): stripped a Bajwa Writes trademark symbol from two screens and removed publishing/literary vocabulary from auth/register/search — deployed and live-verified with a cache-busted production screenshot.
- Earlier completed milestones (2026-07-10/11, verified in git history): resolver-driven pre-join (`meeting_entry_resolution.dart`, outcome state machine), invitation OTP flow, authenticated-booking read-only identity card, Profile → Participation continuity tab, managed Past-meetings archive, meeting-workspace surface migration onto AuraSurface tokens (live room internals frozen/untouched).
- ROS Phase II audit closed: **VERIFIED WITH RESIDUAL FOUNDER EDITORIAL ITEMS** (`representation/inventory/AURA_ROS_PHASE_II_CORRECTION_CLOSEOUT.md`). Full audit deliverable set lives in this repo under `representation/inventory/AURA_*.md`.

## Next implementation starting point

No founder-defined next milestone is recorded. `NEXT_WORK.md` lists the residual items awaiting founder decision.

## Outstanding founder approvals

The four residual editorial items from the ROS Phase II closeout (production data/content, not code) — see `NEXT_WORK.md`.
