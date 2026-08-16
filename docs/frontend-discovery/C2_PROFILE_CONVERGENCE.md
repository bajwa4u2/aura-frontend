# C2 §9 — Edit-Profile Convergence Analysis

**Date:** 2026-08-15 · Both files read in full before classification.
`edit_profile_screen.dart` (1,948) + `institution_edit_profile_screen.dart` (2,153) ≈ **4,101 lines**.

---

## 1. What the two screens actually are

| | Person — "Edit profile" | Institution — "Identity Studio" |
|---|---|---|
| Subject | the human's public identity | the governed organisational identity |
| Load | `GET /users/me` | `institutionAccessProvider` (session-cached) |
| Save | `PATCH /users/me` — **one submit saves everything incl. images** | `PATCH /institutions/:id` — fields on submit; **branding auto-persists per image** |
| Form model | listener + initial-vs-current **diff** (`_hasChanges`), discard dialog, `PopScope` | `Form` + validators + `_dirty` flag, sticky save bar |
| Sections | Identity · Cover&Avatar · **"Presence"** (location/website) · Publications · Links · Account | Basic · About · Branding · Contact · Representation (mission/services/audience/founded) · Social · **Ontology** (class/type/domain-tags) |
| Design system | `EditProfilePanel` family | `InsCard`/`InsSection` family |
| Gate | signed-in self | **`identity.isAdmin`** ← see D5 |

## 2. Seven-dimension classification

### D1 — Product semantics

**Person-only:** publications, links, title/bio-as-human-statement, account record (handle/email), display-name-from-first/last fallback.
**Institution-only:** ontology (class/type/domain-tags — server-reconciled), mission/services/audience/foundedYear, public contact block (email/phone/address/city/region/country), five social URLs, tagline.
**Genuinely shared:** *the media pipeline mechanic* (pick → validate → crop → upload PNG → URL) and *the http(s)-URL rule*.
**Superficially similar, semantically different:** "cover" (person cover ≠ institution cover: different configs, different persistence semantics — auto-persist vs submit); location (person free-text place vs institution structured address); name (human display name vs legal/organisational name with server keys).

### D2 — State authority

Both are fully local `setState` machines — no provider-owned form state. That is **legitimately local** (draft editing state) *except*:
- **4 G5 sites** (direct `AuraLoadingState`/`AuraErrorState` construction) — C0 Product State Presentation violations.
- Institution **access-denial rendered as an error** (`AuraErrorState` "Only institution admins…") — C0 doctrine: denials are NOT errors (`ProductState.unauthorized`, neutral, absent-not-disabled per Capability-Adaptive Experience).
- Person screen duplicates response-unwrap/read helpers locally (`_unwrapResponseMap`, `_readString`) — infrastructure duplication, tolerable, not converged this pass (used by one file).

### D3 — Validation

| Rule | Person | Institution |
|---|---|---|
| http(s) URL | **none** — website/links submitted unvalidated | `_urlValidator` on 6 fields |
| name/tagline/desc length caps | none | `_exceedsLimits` (server-mirroring caps) |
| image MIME whitelist | **none** | jpeg/png/webp |
| image size cap | **none** | logo 2 MB / cover 4 MB |

The URL rule and the image-validation rules are **identical product rules applied on one side only**. Length caps are institution-specific (server contract) — stay.

### D4 — Media

Four near-identical copies of pick→crop→upload (person avatar, person cover, institution logo, institution cover) plus four "edit current" variants = **~8 duplicated flows over one transport** (`uploadAuraMedia`, PNG, `editDisclosure: true`). Configs legitimately differ (circle avatar vs rect logo; member vs institution covers). **Transport/mechanics shared; configs and domain fields (avatarUrl vs logoUrl) stay distinct.** Institution auto-persists branding; person saves on submit — **semantic difference preserved**.

### D5 — Identity / acting context

**The material finding:** backend guards `PATCH /institutions/:id` with **`InstitutionCapability.MANAGE_BRANDING`**; the frontend gates with **`identity.isAdmin`**. `ADMIN_CAPABILITIES` does **not** include `MANAGE_BRANDING` (owner-held, delegable). So an ADMIN without the delegated grant is shown the full editor and **403s on save** — role-as-permission drift (R1 pattern) causing a real over-promise. C1 already declares `ConsequentialAct.manageBranding → MANAGE_BRANDING`; the canonical gate exists and is unused here. No ambient acting-context leakage found otherwise (editing doesn't set an actor; saves are explicit endpoints).

### D6 — Verification / trust / availability / follow

Neither screen renders verification, availability or follow state — **no flattening present, nothing to correct, nothing to add** (adding signals ungoverned would violate the disclosure doctrine). No `isVerified` usage in either file.

### D7 — Presentation / language / temporal

- **Person "Presence" naming drift:** the location/website section is labelled **"Presence"**, the save toast says **"Presence updated"**, and the display-name fallback literal is `'Presence'`. C2 froze Presence/Availability as *reachability*, and classified this word-family as the six-meaning overload. On a C2-owned surface under reconstruction this is in-scope naming drift.
- No local temporal formatting (no G2/G7 sites in either file).
- Wording is otherwise contextual prose (legitimate); canonical actions not violated.

## 3. Convergence model

**A — SHARED PRIMITIVES (extract):**
1. `ProfileMediaPipeline` — pick → MIME/size validate → crop (caller's config) → upload → URL. One implementation, 8 call-flows. Person **gains** MIME/size validation (strict improvement, no semantic change).
2. `httpUrlValidator` — one rule, shared.

**B — PERSON AUTHORITY (stays):** publications/links models, diff/discard machinery, `/users/me` contract, section nav.

**C — INSTITUTION AUTHORITY (stays):** Form+validators, ontology editors, branding auto-persist, `/institutions/:id` contract, InsCard layout.

**D — SHARED INFRA / DISTINCT MEANING:** media configs (4, unchanged); upload transport (already shared via `uploadAuraMedia`).

**E — INTENTIONALLY NOT CONVERGED:** screen structure, design systems, form architectures, save semantics, field ontologies, response parsing. **No `ProfileEntity`, no `entityType` flag** — the subjects differ in load, save, validation, persistence and capability; a shared ontology would be false.

**Corrections implemented with the extraction (all evidence-backed, all C2-owned):**
- 4 G5 sites → `AuraProductState`; institution denial becomes `unauthorized` (not an error).
- Institution gate: `isAdmin` → **capability projection** (`ConsequentialAct.manageBranding`) matching the backend guard; same fix at the entry button (`institution_profile_screen.canEdit`).
- Person "Presence" naming drift → location semantics; toast → "Profile updated".

**No founder decision required by this model** — every correction implements an already-frozen authority (C0 state doctrine, C1 capability doctrine, C2 presence classification, backend capability contract).

---

# IMPLEMENTATION OUTCOME — 2026-08-15

## What was built

**`lib/shared/media/profile_media_pipeline.dart`** — the shared primitive. Owns pick → MIME/size validate → crop → PNG upload → URL. Returns `ProfileMediaResult`; carries **no subject flag by design** (a tripwire test forces the conversation if one is ever added). Plus `httpUrlValidator` — the one URL rule, shared.

## What was rewired

| Surface | Change |
|---|---|
| `edit_profile_screen.dart` | 8 duplicated media-flow bodies → 1 `_runPipeline`; **gained MIME whitelist + size caps** (2 MB avatar / 4 MB cover — the existing institution rule applied to the parallel kinds); website URL validated at save with the shared rule; G5 loading → `AuraProductState`; **"Presence" naming drift corrected** (section → *Location*, toast → *Profile updated*, fallback literal retired) |
| `institution_edit_profile_screen.dart` | duplicated flows → same pipeline (auto-persist branding semantic **preserved** — pipeline returns URL, screen persists); local MIME/size/`_inferMime` deleted (now pipeline-owned); 3 G5 sites → `AuraProductState`; **denial is no longer an error** (`ProductState.unauthorized`, honest capability wording); error state gained a real Retry |
| **Gate correction** | `identity.isAdmin` → **`CapabilityProjection.presentationFor(ConsequentialAct.manageBranding)`**, matching the backend guard exactly. Same correction at both entry points in `institution_profile_screen.dart` (`canManageBranding`). |

## The defect the gate correction fixes

Backend: `PATCH /institutions/:id` requires **MANAGE_BRANDING** (owner-held, delegable; **not** in `ADMIN_CAPABILITIES`). Old gate: `isAdmin`. Consequences, both real: an ADMIN without the grant saw the full editor and 403'd on save; a MEMBER **with** a delegated grant was denied entry to an editor the backend would have allowed. Both directions are pinned by `institution_edit_gate_test.dart`.

## Intentionally NOT converged (final)

Screen structure, design systems, form architectures (diff-based vs Form+validators), save semantics (submit-all vs branding auto-persist), field ontologies, response parsing. **No `ProfileEntity`, no subject flag anywhere.**

## G5 / R1 — measured, ratchet-verified

| Register | Before | After | Evidence |
|---|---|---|---|
| G5 (C0 baseline) | 181 sites / 72 files | **177 / 70** | both edit screens → 0; caught by the gate's fall-detection, baseline updated |
| R1 (C1 baseline) | 25 files / 85 sites | **23 / 82** | both institution profile screens → 0 role-as-permission |

Remaining C2-owned G5: the 9 Follow-blocked sites + `author_profile` (2) + `me_screen` (2) + `institution_profile_screen` (4) — view surfaces, not §9 edit scope.

## Tests / certification

New: `profile_media_pipeline_test.dart` (6) + `institution_edit_gate_test.dart` (5). **Frontend: analyze clean · 519 passed** (508 + 11) · C0/C1/C2 + public-first gates green. **Backend: unchanged this pass** — contract inspected, not modified.

## No founder decision required

Every change implements an already-frozen authority. The avatar/cover byte caps reuse the existing institution values for the parallel kinds — noted as a reused rule, not new policy.

