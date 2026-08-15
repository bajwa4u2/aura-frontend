# Realtime Product Model Audit

> ✅ **FD-5 (FROZEN 2026-08-15):** Live is a governed **mode of a Thread/Space**, not a fourth realtime surface. **Do NOT retrofit Live into any of the three existing live-room screens before convergence.** Backend correction preserved: the **role/stage vocabulary exists** (`PUBLIC_STAGE`, SPEAKER/LISTENER/OBSERVER, hand-raise); the **operational mechanism does not**. See `FD5_LIVE_THREAD_SPACE_FROZEN.md`.

> ✅ **CAPABILITY-ADAPTIVE EXPERIENCE — FROZEN 2026-08-15** now governs realtime participation UX. Participants must not need to understand realtime machinery (`INVITATION → UNDERSTAND CONTEXT → ACCEPT → JOIN → DEVICE CHECK IF NECESSARY → PARTICIPATE`), and **host/admin controls must not permanently occupy everybody else's realtime UI** — they appear progressively when required. A person moves `MEMBER → INVITED PARTICIPANT → SPEAKER → ACTIVE SPEAKER → AUDIENCE` without changing applications or entering role-management screens. Fully compatible with FD-3's distinct semantics. See `CAPABILITY_ADAPTIVE_EXPERIENCE_FROZEN.md`.

## FINDING R1 — Three live-room implementations, one shared transport

**Evidence.** `realtime_room_screen` (3,265 lines), `meeting_live_room_screen` (3,890), `institution_live_rooms_screen` (1,078).

Transport *is* shared: `meetings/` imports `realtime_controller`, `realtime_media_service`, `realtime_event_parser`, `realtime_models`, `realtime_state`. So this is **not** two rival WebRTC stacks.

What is **not** shared is everything above transport. The five shared realtime widgets are consumed by `realtime_room_screen` and **zero times** by `meeting_live_room_screen`:

| Shared widget | realtime_room | meeting_live_room |
|---|---|---|
| `realtime_participant_list` | used | **0** |
| `realtime_host_controls` | used | **0** |
| `realtime_join_requests_panel` | used | **0** |
| `realtime_consent_sheet` | used | **0** |
| `realtime_status_strip` | 0 | 0 |

Meetings reimplements participant grid, spotlight layout and remote tiles internally (`_buildParticipantGrid`, `_buildSpotlightLayout`, `_buildRemoteTile`).

**PRODUCT CONSEQUENCE.** Participant list, host power, admission and consent — the four things a user must understand identically in any live context — look and behave differently depending on which door they entered. Every future realtime obligation costs 2–3 implementations.

**ROOT CAUSE.** Meetings was built first with its own certified lifecycle; the shared realtime authority arrived afterwards and was adopted at the transport layer only. Migration stopped there.

**CLASSIFICATION.** REFACTOR (converge presentation) — **not** demolish. The transport authority is sound and Meetings is a protected certified surface.

**OPTIONS.**
- **A. Converge presentation onto shared participant/host/admission components; keep Meetings lifecycle intact.**
- B. Keep two presentations, extract only participant list.
- C. Rebuild one unified room screen with per-context policy.

**RECOMMENDATION.** A. It preserves Meetings certification while removing the drift that matters to users. C risks the certified surface for aesthetic uniformity.

**MIGRATION CONSEQUENCE.** Meetings behaviour (booking, admission, waiting room, summary) must be preserved exactly; only presentation components change.

**FOUNDER DECISION.** ✅ **RESOLVED — FD-4 OPTION A, FROZEN 2026-08-15.**

Converge participant list · host controls · admission/join-requests · consent onto a **shared component family**; **Meetings lifecycle untouched**.

Two additional freezes: **(1)** one component family may render different **context-specific states and language supplied by the owning domain** — the shared component **does not own semantic meaning**; **(2)** implementation safeguard — **no wholesale Meetings rewrite**; extract/replace proven duplicates **slice by slice with targeted regression after each slice**.

See `FD4_REALTIME_PRESENTATION_CONVERGENCE_FROZEN.md`.

---

## FINDING R2 — `institution_live_rooms_screen` does not use the frozen Institution Room authority

**Evidence.** The screen imports neither `realtime/` nor `meetings/`. It reads `institutionLiveRoomsProvider`, which returns raw JSON consumed as `Map<String, dynamic>` via `_readList(data['sessions'])` — no domain model. It lists **realtime sessions**, not the `InstitutionRoom` entity.

The backend now owns a distinct `InstitutionRoom` with participants, `InstitutionRoomRingPolicy` (`JOIN_ONLY` / `RING_INVITED` / `RING_INVITED_AND_PARTICIPANTS`), invitation lifecycle, and governed ring resolution. **The client has no concept of any of it.**

**PRODUCT CONSEQUENCE.** The frozen D5 capability is unreachable from the product. "Live rooms" currently means "realtime sessions that happen to belong to this institution" — a different concept with no invitation, no ring policy and no governance.

**ROOT CAUSE.** Surface predates the backend authority.

**CLASSIFICATION.** DEMOLISH + REBUILD against the frozen Institution Room contracts.

**MIGRATION CONSEQUENCE.** No user-visible behaviour worth preserving beyond "see what is live now". Salvage: none of the data layer; possibly the card layout.

**FOUNDER DECISION.** No — the mismatch is objective. *How* Institution Room should feel is a design decision (see `LIVE_THREAD_SPACE_ARCHITECTURE_OPTIONS.md`).

---

## FINDING R3 — Realtime product semantics are undefined per context

The task's central question — *what does realtime MEAN in each context* — currently has no answer in the client. Measured state:

| Context | Initiate | Ring | Admission | History owner | Client model |
|---|---|---|---|---|---|
| **DM** | either party | yes (call invite) | none | thread | `thread_call_lifecycle_controller` |
| **Thread** | participants | yes | none | thread | same controller |
| **Space** | members | unclear | none | space | shared with thread |
| **Meeting** | host/booking | yes | **waiting room** | meeting | own lifecycle |
| **Institution Room** | *undefined in client* | **backend: policy-governed** | none | room | **absent** |
| **Live/broadcast** | *does not exist* | — | — | — | **absent** |

**PRODUCT CONSEQUENCE.** Because semantics were never stated, the client generalises: a "call" is a call everywhere except Meetings, which is special because it was built first. Institution Room and Live have no representation at all.

**CLASSIFICATION.** ✅ **RESOLVED — FD-3 FROZEN / FOUNDER APPROVED 2026-08-15.**

Conceptual ownership is now frozen: DM (private person-to-person) · Thread (belongs to and retains continuity with its Thread) · Space (belongs to and retains continuity with its Space) · Institution Room (institution-owned persistent/drop-in with governed participation) · Meeting (own institutional lifecycle, never collapsed into a generic room) · Live (emerges from Thread/Space; **not** another Meeting merely because both use realtime media).

Infrastructure may converge underneath; ownership, initiation, invitation, participation, admission, authority, moderation, history, continuity, public/private meaning, speaker/viewer semantics, end-state and owning surface must not be erased by that convergence.

**The creation/selection/invitation/participation UX is simultaneously frozen as *to be reconstructed*** — semantic separation is not permission to preserve UX fragmentation. See `FD3_REALTIME_SEMANTICS_FROZEN.md`.

---

## FINDING R4 — Multi-device and transfer have no client representation

**Evidence.** Backend froze D1 (preferred-first ring, bounded stagger, fallback), D2 (transfer handshake with `offered/accepted/committed/relinquish/failed` events) and D6 (durable media ownership). Client search finds no consumer of transfer events, no device-picker for an active call, and no relinquish handling.

`devices/` (9 files, 1,072 lines) manages device registration only.

**PRODUCT CONSEQUENCE.** A user cannot move a live call between their own devices, and the backend's ring routing is invisible — a call ringing the preferred device first is indistinguishable from a bug.

**CLASSIFICATION.** NEW CONSTRUCTION (client side of frozen backend authority). Not drift.

**FOUNDER DECISION.** No for existence (backend obligation already approved). Yes for surface placement.

---

## FINDING R5 — Reconnect/orphan recovery exists and is genuinely good

**Evidence.** `realtime_reconciliation_controller`, `orphaned_session.dart`, `orphaned_session_dismissal_cache`, `orphaned_session_banner`, `floating_call_widget`, `incoming_live_overlay`, `caller_ringback_provider`.

**CLASSIFICATION.** **PRESERVE.** This is the strongest realtime work in the client and must survive any reconstruction. `floating_call_widget` in particular already solves "active session survives navigation", which the market research shows is a core expectation.

---

## FINDING R6 — Native notification paths are asymmetric

Backend delivers via WNS (Windows/MSIX), APNs, FCM and Web Push through one authority. Client-side, `updates/incoming_call_bridge.dart` and `notification_permission_tile` exist, but there is no single client notification-presentation authority; call presentation is handled by realtime, other notifications by `updates/`.

**CLASSIFICATION.** REFACTOR into a client Notification Presentation Authority (see `FRONTEND_AUTHORITY_CONSUMER_MATRIX.md`).
