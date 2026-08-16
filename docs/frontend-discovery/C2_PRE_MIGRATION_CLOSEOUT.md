# C2 — PRE-MIGRATION CLOSEOUT (execution authority / handoff)

**Date:** 2026-08-16 · **State: C2 RECONSTRUCTION LOCALLY COMPLETE.** Final closure awaits only the two already-authorized, founder-observed data transitions (§Data transitions). This is a handoff authority, not narrative.

## What C2 reconstructed

Blocking (DM refusal, bidirectional availability hiding, canonical Blocks authority) · Availability disclosure (established-Follow default, no raw third-party timestamps, hidden ≡ offline, institution-actor deny, feed path closed) · Edit-profile convergence (shared media pipeline, subjects distinct, capability-gated institution editor) · Canonical Follow (single authority over both stores, consent model frozen, D1 feed signal, D3 bypass closed, D4 counts, notifications, cooldown UX, client transport behind one repository) · Verification & Trust (layered person classes on the wire + admin grant/revoke/history, canonical trust layer, Role attested, 13+ surfaces migrated, §11 official-speech correction) · Monetization × Verification decoupling (payment never verifies, downgrade never un-verifies, approval never touches plan) · Commercial taxonomy FREE + PRO (middle tier retired not renamed, checkout refusal, enforcement-truth copy) · §12 Representation consistency (canon caught up, stale records superseded) · Public Home (public-first hero, glyph doctrine, gate hardening) · Final convergence (Follow HTTP-in-widget retired, startLive gate onto C1, dead privacy parse slot removed).

## Visible experience change (people / institutions)

People: truthful layered verification marks instead of a dead generic badge; working follower counts and follow notifications; honest cooldown; a feed that reflects who they follow; availability private by policy; one temporal dialect; calm honest states with real retry; a homepage that speaks to them first. Institutions: capability-true editor access; verification distinct from participation, endorsement, payment, and speech; truthful plan copy; institutional responses attributed without pseudo-verification.

## Authorities consumed by the release client

C0 Product Language / Product State (`AuraProductState`) / Temporal (`AuraTemporal`) · C1 `CapabilityProjection`/`ConsequentialAct` (incl. `manageBranding`, `startLive`) · C2 `core/trust/` (verification domain + marks), `FollowsRepository` (actor + consent lifecycle), availability disclosure (server-side), canonical feed.

## Debt: remaining, classified (final measurements 2026-08-16)

| Item | Count | Class | Owner / retirement |
|---|---|---|---|
| `'Try again'` / raw-error UX | 0 | — | — |
| Direct Follow HTTP outside repository | 0 | — | — |
| Raw person-verification parsing outside `core/trust` | 0 | — | — |
| Flattened Profile ontology / dead commercial booleans / retired commercial vocab (product-facing) | 0 | — | remaining `'VERIFIED'` strings are the institution *status lifecycle enum*, not the retired plan |
| G5 legacy state primitives | baseline 162/64 (ratcheted) | later-chapter surfaces (admin/devices/security/etc.) | per-chapter burn-down, ratchet enforced |
| R1 role checks | baseline (ratcheted; live_rooms burned to 0) | registered owners: member_shell counts, actor_context composite, institution_correspondence | C4/C7 convergence; ratchet enforced |
| `identity.isAdmin` | 5 code sites | all registered owners above | same |
| Temporal shim callers | 10 files | C4 (notifications/inbox/engagement), C6 (thread surfaces) | last caller → delete `relative_time.dart` |
| `isVerified` | 77 | canonical Institution wire field + non-presentational | not debt (see trust doc §6) |
| Generic `'Verified'` literals | 8 | all subject-unambiguous, classified | trust doc §5 |
| Availability Off control | authority ready | **C4 Settings** | build control, consume existing backend policy |
| People Selection convergence | classified sites | C3/C4/C7/PD-1 as registered | per owner |
| `AuraVerifiedInstitutionBadge` (feed identity chip) | 3 consumers | TRANSITIONAL | retire onto canonical trust layer when feed identity badges are reconstructed |

**No unexplained C2-owned debt remains.**

## Data transitions (AUTHORIZED, SEQUENCED — not backlog)

**1. Physical Follow migration** — target `FollowEdge` + `FollowConsent`. Plan: `C2_RECONSTRUCTION_DEBT_REGISTER.md` Part 1 — additive schema → idempotent backfill (origin provenance incl. `LEGACY_BYPASS`, consent ids + `respondedAt` preserved) → validation queries (incl. Institution→Person residue count; 0 rows = no adjudication, >0 = founder evidence report) → flag-flip cutover **inside the canonical authority** (consumers unchanged by design) → rollback documented → legacy-store + zombie-enum deletion only after observation/validation. **Precondition: founder-observed deployment of the 9 backend C2 commits.**

**2. Commercial/verification reconciliation** — `aura-backend/prisma/manual/2026-08-16-institution-isverified-reconciliation.sql` (manual, founder-observed, NOT in deploy path). Produces: isVerified/status drift counts, deterministic reconciliation (`isVerified := status='VERIFIED'`), per-plan row tallies (Institution + InstitutionSubscription with status), TRUSTED member usage, post-validation. Dispositions it gates: legacy VERIFIED row remap (FREE vs PRO from real subscription evidence), TRUSTED residue (0 rows = retire enum residue; >0 = founder remap), then staged enum retirement after the founder names/blesses final taxonomy mapping.

## What must happen before C2 is FINAL CLOSED

1. Founder-observed deployment of backend commits (9, listed below). 2. Reconciliation script run + evidence reviewed. 3. Follow migration executed per plan + validated. 4. Legacy remaps adjudicated from evidence (VERIFIED rows, TRUSTED rows if any). 5. Founder closure declaration.

## Commit state (all local, nothing pushed)

Backend (9): `ca6d835` `7861510` `5d12e89` `3095746` `f2a01c2` `a2cf129` `07b20be` `d940477` `2217480`. Frontend (5): `11e85fa` trust experience · `0d0abf5` Follow client boundary · `121d029` profile/commercial sync · `cff6982` public-first entry + temporal/state · `7a243e1` governing records (+ this closeout). Representation (1): `e8fb608` (selective 3-file; other agents' worktree content untouched).

## Contracts C3 inherits and MUST NOT reopen without founder adjudication

Follow consent semantics (P→P request-only, P→I immediate, I→P unauthorized, FOLLOW ≠ SUBSCRIBE, BLOCK precedence, cooldown, D1 availability-signal meaning) · availability disclosure policy + InstitutionPresence distinction · layered verification taxonomy, Role attested wording, revoked/expired semantics, verification ≠ authority/payment/endorsement · profile subject separation (no flattened ontology) · commercial: FREE+PRO frozen, entitlement boundary NOT frozen, no enforcement expansion during reconstruction, verification not purchasable · public-first causal doctrine on general surfaces (gate-enforced) · C0 language/state/temporal authorities · C1 per-act capability projection. Canonical Representation record: `representation/inventory/AURA_IDENTITY_RELATIONSHIP_TRUST_CANON.md`.
