# Technology Inventory — Aura Frontend (aura_final)

**Status: Canonical authority for this repository.** Seeded from the 2026-07-28 cross-repository audit. This repository does not independently own backend technology — see `aura-backend/technology/TECHNOLOGY_INVENTORY.md` for the full AU-01–AU-33 catalog this client consumes.

## What this repository itself implements

| Item | What it is | Evidence |
|---|---|---|
| Multi-platform client shell | Flutter app targeting web, iOS, Android, and desktop from one codebase | Real platform directories with build artifacts; `build_apk.log`/`build_web.log` present |
| Complete route surface | 39 feature directories, 1,946-line router covering every backend domain (institutions, meetings, realtime, communications, admin, monetization, composition, etc.) | `lib/router.dart`, full read |
| Platform-conditional capture code | Real, separate recording-capture implementations for web vs. native, feeding AU-24's recording pipeline | `lib/features/meetings/data/recording_capture_stub.dart` / `recording_capture_web.dart` |
| Governance-matching UX | Frontend routing logic explicitly encodes the same admission/continuity doctrine as the backend (e.g., guest-safe terminal fallback matching AU-19's admission doctrine) | Router code comments cross-verified against `aura-backend`'s `meeting-admission.service.ts` |

## What this repository is

A real, deployed, multi-platform consumer of the technology catalogued in `aura-backend/technology/TECHNOLOGY_INVENTORY.md` — not a placeholder client, and not an independent technology owner in its own right.
