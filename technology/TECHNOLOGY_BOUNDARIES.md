# Technology Boundaries — Aura Frontend (aura_final)

**Status: Canonical authority.**

## This repository does not own

Any server-side technology. Institutional identity, governance, discourse intelligence, jurisdiction routing, meeting admission, WebRTC signaling, release governance, AI governance, monetization, and every other item in `aura-backend/technology/TECHNOLOGY_INVENTORY.md` are owned, implemented, and enforced entirely in `aura-backend`. This repository consumes them over HTTP/WebSocket; it does not reimplement or independently enforce any of the governance logic (e.g., meeting admission rules are enforced server-side — this client's UI simply routes correctly around the server's decisions).

## This repository is not

An independent technology estate. It has no relationship — confirmed absent — to Orchestrate, Bajwa Writes, Representation, or Institution Library.

## What this repository does own

The client-side experience layer itself: routing, platform-specific capture code, and UI state management for the technology `aura-backend` implements. See `TECHNOLOGY_INVENTORY.md`.
