# Technology Architecture — Aura Frontend (aura_final)

**Status: Canonical authority.** This repository is a client layer, not an independent architecture — see `aura-backend/technology/TECHNOLOGY_ARCHITECTURE.md` for the real technology graph.

```
aura_final (this repo — Flutter client, all platforms)
        │
        │  full HTTP API consumption, all 64 controllers
        ▼
aura-backend (owns all AU-01..AU-33 technology)
```

No independent backend logic exists in this repository. Its 39 feature directories mirror `aura-backend`'s domains one-to-one (institutions, meetings, realtime, communications, admin, monetization, composition, discourse intelligence, civic signals, etc.). Internal structure within each feature directory typically follows domain/data/application/presentation layering in the more mature areas (meetings, realtime, monetization, composition); thinner in others.
