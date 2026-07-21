# Handoff - aura_final

Last updated: 2026-07-21 UTC (Post Integrity Remediation)

Read this first, then `CURRENT_STATE.md`, then `AGENTS.md` (operating law).

Orientation:

- **Post integrity remediation (2026-07-21):** member compose, public composer, institution compose, edit, and draft-resume flows now share the same rule: top-level publishing/saving requires selected canonical topic state. Raw `#` text is not topic selection. Draft discard calls the backend draft-delete endpoint and edit mode bypasses draft autosave.
- **Post editing uses canonical composers.** Member edit routes to `ComposeScreen(editPostId: ...)` and saves through `PUT /posts/:id`; institution edit hydrates the existing row via `GET /institutions/:institutionId/posts/:postId` and saves through `PATCH`, preserving the post id and metadata unless changed.
- **Governed tagging** (`lib/core/tagging/`) is reusable infrastructure. Wrap a composer's `TextEditingController`/`FocusNode` in `GovernedTagAutocomplete`; do not build a new mention widget. `TagKind` is open; add entity kinds there, not a parallel system.
- **Identity rendering** always delegates to `AuraAvatar` for photo/logo/avatar/initials/placeholder precedence. If a surface shows initials despite a real image, first verify whether the API payload includes `avatarUrl`/`logoUrl`.
- **Module attention** (`lib/features/updates/module_attention.dart`) is a pure projection over the notifications the global bell already polls. Never add a second unread-count source for a module.
- Pre-join is resolver-driven: the backend's participation resolver returns an outcome; `meeting_entry_resolution.dart` maps outcomes to UI states. Never add a client-side identity form at a meeting door.
- The WebRTC engine (`lib/features/realtime/`) survived reliability hardening on 2026-07-10. Understand that design before touching reconnection logic.
- Latest remediation verification: `flutter analyze` clean. Flutter test invocations hung in this Windows workspace even for pre-existing tests; treat as an environment/tooling blocker until a normal runner completes.
- ROS Phase II audit deliverables and closeout live in `representation/inventory/` in this repo.
- The backend is `../aura-backend` (own repo, own continuity set).

Pending and founder gates: `NEXT_WORK.md`.
