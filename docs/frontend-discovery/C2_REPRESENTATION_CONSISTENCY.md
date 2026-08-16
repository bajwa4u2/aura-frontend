# C2 §12 — Representation Consistency

**Date:** 2026-08-16 · Full bidirectional pass: canonical product purpose → Representation authority → runtime authority → release-client experience → legacy retirement. Representation read at its **current working-tree state** (which includes the founder-approved 2026-08-15 public-first reconciliation banners plus other agents' uncommitted work — see Provenance).

## Sources audited

`inventory/AURA_PUBLIC_FIRST_CAUSAL_DOCTRINE.md` · `PRODUCT_IDENTITY_CANON.md` (Aura sections) · `PUBLIC_REPRESENTATION_CANON.md` (Parts A/B incl. items 8–15) · `AURA_REPRESENTATION_MODULE_INVENTORY.md` · `AURA_CAPABILITY_INVENTORY.md` · `AURA_LIFECYCLE_MODULE_AUDIT.md` · `AURA_JOURNEY_VERIFICATION.md` · `AURA_EXPERIENCE_VERIFICATION.md` · `AURA_PUBLIC_EXPERIENCE_AUDIT.md` · `AURA_ARCHITECTURE_DRIFT.md` · `AURA_FUTURE_REPRESENTATION_MODULE_INVENTORY.md` · `MODULE_ANALYSIS_AURA_INSTITUTION_IDENTITY_GOVERNANCE.md` · `MODULE_ANALYSIS_AURA_MONETIZATION.md` · `canon/README.md` context. Concept-driven reading with surrounding context, not keyword skims.

## The matrix

| # | Concept | Representation claim | Class | Runtime | Client | Status → action |
|---|---|---|---|---|---|---|
| 1 | Public-first causality | `AURA_PUBLIC_FIRST_CAUSAL_DOCTRINE.md` + reconciled identity/representation canons | **A frozen** | n/a | copy reconciled (C-1…C-4, 2026-08-15) | **CONSISTENT** |
| 2 | Person identity | Module inventory carries `PERSON ≠ INSTITUTION ≠ MEMBERSHIP ≠ ACTING CONTEXT ≠ PRESENCE` (FD-11) | **A** | canonical person projection (D3) + layered verification | Profile + trust marks adopted | **CONSISTENT** |
| 3 | Institution identity | accountability infrastructure, never inferred from URL/payment/domain-alone | **A** | status-lifecycle verification authority; plan decoupled | canonical marks; router boundary (institutionId-in-path ≠ actor) | **CONSISTENT** (post-decoupling) |
| 4 | Profile ontology | no flattened-Profile claim exists in Representation | — | §9 convergence: shared primitives, separate subjects | implemented | **CONSISTENT**; truth recorded in new canon |
| 5 | **Follow model** | `AURA_LIFECYCLE_MODULE_AUDIT.md`: "three parallel, partially inconsistent models… two live and disagree" | **C historical** | canonical Follow authority; D3 bypass closed; consent partition frozen; R9 refusals; target FollowEdge+FollowConsent | consent UX, cooldown, counts, notifications adopted | **REPRESENTATION STALE → superseded** (dated banner + new canon) |
| 6 | Follow consequences | absent from Representation | — | feed availability signal (D1), counts, request/accept events, availability source | adopted | **R→ gap → new canon records them** |
| 7 | Blocking | absent from Representation (C2-relevant scope) | — | BLOCK > CONSENT/REJECTION > FOLLOW; bidirectional availability hiding; DM refusal | adopted | **R→ gap → new canon** |
| 8 | **Availability / Presence** | Lifecycle audit: "Presence = single-actor stateless heartbeat… a technical realtime-signaling concern" | **C historical** | AvailabilityDisclosureService: Person projection, established-Follow default, block precedence, no raw lastActiveAt, hidden ≡ offline, institution-actor deny; InstitutionPresence distinct | adopted; "Presence" naming drift fixed in §9 | **REPRESENTATION STALE → superseded** (banner + new canon). Off-control = C4-owned (recorded) |
| 9 | **Verification** | Capability inventory: "Verification implemented (binary… not graduated tiers)" + ad-hoc badge note | **C historical** (accurate 2026-07-13) | layered Person classes + admin exposure + wire projection; institution/domain/channel distinct | canonical trust layer, Role attested | **REPRESENTATION STALE → superseded** (banner + new canon) |
| 10 | Trust ≠ sale / commercial | Representation never canonized plan tiers (monetization module = market research; Institutional Economy = future module, deferred) | **C/D** | FREE+PRO frozen; verification not purchasable; boundary not frozen | billing truthful | **CONSISTENT**; FREE+PRO + not-frozen marker recorded in new canon |
| 11 | "trusted institution" wording | market-category research language only (LinkedIn/Meta/KYB comparisons); founder-reasoning note "trusted institutional participation" in future-module record | **C historical** | — | — | **ACCEPTABLE** — research/history, no product claim; public-first banner already governs |
| 12 | Acting identity / authority | consistent with C1 (module inventory FD chain) | **A** | C1 frozen | per-act attribution intact | **CONSISTENT** |
| 13 | People Selection | DirectoryEntry vs CorrespondenceIdentity preserved | **A** | — | no C2 surface conflates them | **CONSISTENT**; broader convergence stays with named owners (C4-retired/C7/C3/PD-1) |
| 14 | Temporal presentation | (client-side) three local time-ago dialects bypassed the C0 authority | — | — | **CORRECTED**: activity/civic-signal/updates converged onto `AuraTemporal.humanize(compact)`; G2 baseline burn-down recorded | **CLIENT BEHIND AUTHORITY → fixed** |
| 15 | Institution mark in discourse intelligence | (client-side) bare unexplained `verified_rounded` icons ×3 | — | — | **CORRECTED** → `InstitutionVerifiedIcon` (semantics + meaning) | **CLIENT BEHIND AUTHORITY → fixed** |
| 16 | Journey/experience verdicts ("verified badge renders live", booking evidence) | dated live-verification verdict records | **C historical** | — | badge now canonical primitive | **ACCEPTABLE** — self-dated evidence, no current-authority claim |

## Q — valid authority with no release-client adoption

After this pass: **only the Availability Off user-facing control** (backend authority ready; C4 Settings owns the surface — recorded owner, not silent debt). Everything else audited either has adoption or is explicitly future/other-chapter.

## R — reconstructed truth that was missing from Representation

The consent Follow model + consequences, blocking precedence, availability disclosure policy, InstitutionPresence distinction, layered verification + Role attested, verification-not-purchasable, FREE+PRO + not-frozen-boundary marker, and the §9 profile-subject rule were all absent from canonical Representation. **Now recorded** in the new `inventory/AURA_IDENTITY_RELATIONSHIP_TRUST_CANON.md` (Representation repo), which cites the implementing repositories as evidence owners rather than restating implementation detail.

## S — stale material superseded (not silently rewritten)

Dated supersession banners added to two **clean** (no provenance collision) historical records: `AURA_LIFECYCLE_MODULE_AUDIT.md` (Follow three-model finding; Presence-as-heartbeat characterization) and `AURA_CAPABILITY_INVENTORY.md` (binary-verification-only snapshot). History preserved; claims marked superseded with pointers.

## Provenance (§24)

Representation worktree contains extensive uncommitted modifications (public-first reconciliation banners dated 2026-08-15 + other agents' operational/commercial files). **Rule applied:** modified files were read as current truth but never edited or committed; all §12 Representation writes went to clean files or a new file, committed selectively (`git add` per file). No other agent's work staged, absorbed, or reformatted. No collisions blocked any required correction — the three Representation writes all landed on clean paths.

## Debt remeasurement (§28)

| Signal | State after §12 |
|---|---|
| G5 ratchet | green at baseline 168/67 (admin sheet used C0 authority; no movement) |
| G2 local humanized time | **updates_screen 6→0** (converged); remaining G2 files owned per baseline (admin/devices/security — later chapters) |
| G3 local tz conversion | no rise; baseline intact |
| `'Try again'` | 0 |
| `isVerified` | 77 (institution canonical field + non-presentational; classified in trust doc §6) |
| generic `'Verified'` | 8, all subject-unambiguous (classified) |
| raw verification parsing outside `core/trust` | Person: 0. Institution boolean tolerance keys in `institution_access_provider` (domain parsing, legitimate); auth email-routing params (channel); discourse `verified` field now rendered canonically |
| `identity.isAdmin` | registered owners only (member_shell, actor_context, institution_correspondence) |
| deprecated temporal shim (`relative_time.dart`) | **11 caller files** (inbox, feed card, engagement ×2, live rooms, post detail, notifications, thread surfaces ×4) — shim forwards to the authority, so semantics are canonical; per-chapter burn-down owners: C4 (notifications/inbox), C5/feed, C6/threads. Legitimate migration boundary retained |
| legacy Follow direct dio calls | 6 sites in me_screen/follow_requests_screen — canonical endpoints, presentation-layer HTTP debt; owner: C2 closeout/C4 refactor note |
| legacy plan identifiers | `AURA_PLAN_VERIFIED`/`STRIPE_PRICE_AURA_VERIFIED` — explicit LEGACY billing identifiers, retirement with enum migration |

No unexplained remainder.
