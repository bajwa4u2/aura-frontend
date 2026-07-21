# Handoff — aura_final

Last updated: 2026-07-21 UTC

Read this first, then `CURRENT_STATE.md`, then `AGENTS.md` (operating law).

Orientation:

- Pre-join is resolver-driven: the backend's participation resolver returns an outcome; `meeting_entry_resolution.dart` maps outcomes to UI states. Never add a client-side identity form at a meeting door — the identity-integrity doctrine (authentication, invitation, or booking only) is enforced on both sides.
- The WebRTC engine (`lib/features/realtime/`) survived a consolidated reliability hardening (2026-07-10): media plane decoupled from socket, per-peer reconnect grace, parked "Continue here" replaced-session state. Understand that design before touching reconnection logic.
- Verification bar from the last recorded runs: `flutter analyze` clean, `flutter build web --release` compiles. Re-run both before building on top.
- ROS Phase II audit deliverables and closeout live in `representation/inventory/` in this repo.
- The backend is `../aura-backend` (own repo, own continuity set).

Pending and founder gates: `NEXT_WORK.md`.
