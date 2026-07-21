# Handoff — aura_final

Last updated: 2026-07-21 UTC (AXR-1)

Read this first, then `CURRENT_STATE.md`, then `AGENTS.md` (operating law).

Orientation:

- **Governed tagging** (`lib/core/tagging/`) is reusable infrastructure — wrap a composer's `TextEditingController`/`FocusNode` in `GovernedTagAutocomplete`, don't build a new mention widget. `TagKind` is open; add entity kinds there, not a parallel system.
- **Identity rendering**: always delegate to `AuraAvatar` (photo → logo → avatar → initials → placeholder). If a surface shows initials for a user/institution with a real image on file, check first whether the *API payload* includes `avatarUrl`/`logoUrl` before assuming it's a client bug — that was the actual root cause for most of AXR-1's W3 findings.
- **Module attention** (`lib/features/updates/module_attention.dart`) is a pure projection over the notifications the global bell already polls — never add a second unread-count source for a module.
- Pre-join is resolver-driven: the backend's participation resolver returns an outcome; `meeting_entry_resolution.dart` maps outcomes to UI states. Never add a client-side identity form at a meeting door — the identity-integrity doctrine (authentication, invitation, or booking only) is enforced on both sides.
- The WebRTC engine (`lib/features/realtime/`) survived a consolidated reliability hardening (2026-07-10): media plane decoupled from socket, per-peer reconnect grace, parked "Continue here" replaced-session state. Understand that design before touching reconnection logic.
- Verification bar from the last recorded runs: `flutter analyze` clean, `flutter build web --release` compiles. Re-run both before building on top.
- ROS Phase II audit deliverables and closeout live in `representation/inventory/` in this repo.
- The backend is `../aura-backend` (own repo, own continuity set).

Pending and founder gates: `NEXT_WORK.md`.
