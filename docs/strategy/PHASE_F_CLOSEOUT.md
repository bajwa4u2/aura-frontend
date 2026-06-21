# Phase F Closeout — Public Record Accountability System

**Date:** 2026-06-21
**Status:** Complete and deployed

---

## What was built

A complete public record accountability system connecting Aura's public posts to institution engagement workspaces. When a user posts publicly, the post is routed to institutions based on topic participation declarations. Institutions see those records in their workspace and can respond, commit, or mark resolved. The status is reflected publicly on the original post.

---

## Deployments

### Backend — `https://api.auraplatform.org/v1`

| Commit | Description |
|--------|-------------|
| `a41282e` | Fix Railway crashloop: Prisma WASM → binary engine. Removed `queryCompiler`/`driverAdapters` preview features; switched `prisma.service.ts` from `PrismaPg` adapter to plain `super()` constructor. Stable on Railway Node.js 20. |
| `d34ae7c` | Fix engagement records showing null status: added `status: true` to `RECORD_SELECT` in `institution-engagement.service.ts` and exposed `status` on `EngagementRecordDto`. |
| `af5da7c` | (prior session) Public record routing, accountability tag lifecycle, publicStatus computation, engagement workspace endpoints. |

Binary targets in `schema.prisma`: `["native", "linux-arm64-openssl-3.0.x"]`

### Frontend — Flutter / GitHub `bajwa4u2/aura-frontend`

| Commit | Description |
|--------|-------------|
| `3dac187` | Align engagement repository and models to live API shapes: `records:[]` key in list response, `record:{}` key in detail response, `needsResponse` summary field, `post.id` nested for `postId`. |
| `d615d4f` | (prior session) F1–F4 public record UI: intent picker in compose, publicStatus badge on feed detail, engagement workspace screens, participation declaration screen. |

---

## Feature flags

| Flag | State | Notes |
|------|-------|-------|
| `PUBLIC_RECORD_INTENT_REQUIRED` | **OFF** | Do not enable. Gates post visibility by intent — not ready for broader users. |
| `CAN_RAISE_ISSUE_GATE_ENABLED` | **OFF** | Do not enable. Gates who can raise an issue — not ready for broader users. |

---

## What is live

- **Intent routing:** public posts with intent (`ASK`, `ISSUE`, `SHARE_UPDATE`) route to institutions based on topic participation declarations
- **Participation declarations:** institutions declare topic/mode (`ACCOUNTABLE`, `RESPONDING`) to receive routed records
- **Engagement workspace:** institution admins see all routed records with topic, intent, author, post body, and lifecycle status
- **Status lifecycle:** `PENDING → RESPONDED → COMMITTED → RESOLVED` driven by institution accountability tags; updates propagate to `publicStatus` on the public post detail
- **publicStatus on post detail:** public users see `COMMITTED` or `RESOLVED` badges on posts once institution acts
- **Engagement summary:** total count and `needsResponse` count for workspace dashboard
- **Seeded institution:** Aura Platform LLC has active COMMITTED and RESOLVED engagement records demonstrating the full lifecycle

---

## What remains off / not built

- "Reply Officially" action from engagement detail screen — **next build**
- Participation admin UX polish (topic descriptions, mode explanations, transitions) — **next build**
- LISTENING and REFERENCE_ONLY participation modes — explicitly deferred, do not implement
- Jurisdiction-aware routing refinement — deferred
- Intent-required gate — flag off, not wired through UI

---

## E2E verification (Phase F5)

All flows verified with `review@auraplatform.org / AuraReview123!` (institution admin on `aura-platform-llc`):

- [x] Login and auth token
- [x] Compose post with intent (ASK, ISSUE)
- [x] Post published, routes to engagement workspace
- [x] Engagement list returns records with correct topic, intent, author
- [x] Engagement detail returns full record with status
- [x] Institution post create → publish → reply (with `asInstitution: true`)
- [x] PATCH accountability tag `COMMITMENT` → `publicStatus: COMMITTED` on post detail
- [x] PATCH accountability tag `RESOLVED` → `publicStatus: RESOLVED` on post detail
- [x] Engagement records show correct status after d34ae7c fix

---

## Next build

**Participation admin UX polish + Public Engagement detail "Reply Officially" action**

The engagement detail screen (`engagement_detail_screen.dart`) needs a primary action that lets institution admins compose and publish an institution post reply with an accountability tag — without leaving the engagement workspace. This closes the loop between the public record and the institution response in a single flow.

Scope:
1. "Reply Officially" button on `EngagementDetailScreen` (visible to institution admins only)
2. Bottom sheet or modal: text compose area + accountability tag selector (COMMITMENT / UPDATE / RESOLVED)
3. On submit: `POST /institutions/:id/posts` (create) → `POST /institutions/:id/posts/:id/publish` → `POST /institutions/:id/posts/:id/replies` (with `asInstitution: true, actorInstitutionId`) → `PATCH /institutions/:id/posts/:id/accountability` with tag + `publicPostId`
4. On success: refresh engagement detail to show updated status badge

Do not expose routing internals, ticket/case/SLA language, or assignee concepts in this UI.
