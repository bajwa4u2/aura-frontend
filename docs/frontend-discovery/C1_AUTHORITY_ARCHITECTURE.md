# C1 — Acting Context & Capability Projection

**Date:** 2026-08-15 · **Status:** READY FOR FOUNDER FINAL CLOSEOUT REVIEW. **Not committed.**

All six founder rulings implemented. Section 12 records each outcome.

---

## 1. Backend canonical authority — traced before anything was projected

`InstitutionAuthorityService` is, in its own words, *"the single authorization authority for institutions… No service may re-implement role logic with ad-hoc equality checks."*

| Concept | Canonical source |
|---|---|
| Role resolution | `resolveRole()` — member row is truth; legacy `adminUserId` reconciles to OWNER |
| **Effective capability** | `getContext()` → `ROLE_CAPABILITIES[role] ∪ active delegated grants` |
| Enforcement | `can()` / `assertCapability()` / `assertOwner()` / `assertRoleAtLeast()` |
| Platform authority | `AdminAuthorizationService.hasPermission()`, **14+ granular `AdminPermission` values** |
| Projection endpoint | `GET /institutions/:id/authority/me` → `{ role, capabilities[], roleCapabilities, adminDelegable }` |

**The decisive distinction, taken directly from backend doctrine:**

> Governance-exclusive acts — ownership transfer, institution lifecycle, appointing/removing ADMINs — are **NOT capabilities**. They are owner authority, enforced as role checks *so they can never be delegated away*.

So role is not always drift. Role answering a *capability* question is drift; role answering a *governance* question is correct. C1 encodes exactly that split.

## 2. Frontend shadow authority — measured

| # | Finding | Severity |
|---|---|---|
| **F1** | **`authority/me` is never called.** The client fetches grant/revoke/transfer endpoints but never the canonical per-institution context. | HIGH |
| **F2** | **Capabilities fabricated on the client.** `institution_access_provider.dart:243-252` injected six capability tokens (`OFFICIAL_REPRESENTATION`, `PUBLISH_OFFICIAL`, `MANAGE_ANNOUNCEMENTS`, `MANAGE_MEETINGS`, `START_LIVE`, `END_LIVE`) whenever it judged a session an "authorized speaker" with no role. **The client was a second source of authority.** | HIGH |
| **F3** | **Acting identity derived from the URL.** `ActorContext` decides you speak *as an institution* because the path starts with `/institution/` — the exact defect frozen after the Meetings router regression: **institutionId-in-path ≠ institution-actor identity.** | HIGH |
| **F4** | **A path-blind twin contradicted it.** `activeActorContextProvider` returns the **institution** actor whenever any institution identity has loaded. Its consumer was the presence heartbeat — so **every person who merely belongs to an institution was reporting presence as that institution, everywhere, permanently.** | HIGH |
| **F5** | **`canSpeakAsInstitution = canPublishPosts \|\| isAdmin`** — a role OR-ed into a capability question, in both `ActorContext` implementations. | MEDIUM |
| **F6** | **Platform administration flattened to one boolean.** Backend has 14+ granular `AdminPermission` values; the client models `AppAdminState { none, admin }`. Every admin screen therefore shows every admin control. | MEDIUM |
| **F7** | **The effective-capability formula is duplicated in the backend.** `institutions.service.ts` recomputes `ROLE_CAPABILITIES[role] ∪ grants` inline instead of calling `InstitutionAuthorityService.getContext()` — a second implementation of the rule its own doctrine says must have one. | MEDIUM |
| **F8** | **`/institutions/me` returns capabilities for ONE membership.** `activeMembership` is singular while `memberships[]` is a list — the structural cause of the client's single-institution acting model. | MEDIUM |

## 3. Re-measured drift — the discovery baseline was wrong in both directions

Discovery said *"role comparisons in 29 files, `canX` derivations in 20"*. Measured, comment-stripped:

| Signal | Discovery | Measured | Reality |
|---|---|---|---|
| Role-literal comparisons | 29 files | **5 files / 6 sites** | and 3 of the 6 are not authorization at all |
| `canX` declarations | 20 files | **38 files / 73 sites** | most are not authorization |
| `isOwner`/`isAdmin`/`isAdminLike` | not measured | **26 files / 86 sites** | the real vector |

**The named drift pattern was largely not the problem.** `role == 'ADMIN'` barely exists. What exists is role-derived *booleans*, and a great deal of `canX` that has nothing to do with authority.

### A/B/C/D/E classification (§5)

| Class | Meaning | Examples |
|---|---|---|
| **A — Shadow authorization, must die** | F2 fabricated capabilities · F3/F4 route- and ambient-derived acting identity · F5 role OR-ed into capability | 4 sites |
| **B — Presentation projection, legitimate** | `canPublish = identity?.canPublishPosts` and similar — consuming backend capability to decide presentation | ~20 sites |
| **C — Non-authorization role presentation, legitimate** | `role == 'user' ? 'User' : 'Admin'` in support chat (**message author**, not permission) · `member.role != 'ADMIN'` in a members roster (**displaying** a role) · realtime `isHost`/`isModerator` (**meeting participant** roles) | ~15 sites |
| **D — Not authorization at all** | `_canSubmit`, `canSave`, `canLeft`/`canRight` scroll affordances, `canCopyLink`, `canZoom` | ~40 sites |
| **E — Uncertain, brought forward** | F6 platform-admin flattening · institutional DM choice (see §8) | 2 |

**No mechanical replacement was performed.** Category D alone would have been 40 pointless edits.

## 4. The Acting Context model

`lib/core/authority/acting_context.dart`

> **Acting identity is not global state.** There is no ambient "current actor", because a person is not continuously in a mode.

```
ordinary act        → the person, no ceremony
consequential act   → resolved explicitly, for that act
```

`ActingContextAuthority.resolve(ConsequentialAct)` → `ActingResolution { options, recommended, requiresExplicitChoice }`.

- **Not route-aware, by construction.** It takes no path and reads no router. A path can never make someone an institution.
- **`ActingOption.personId` is always populated** for institutional options — an institution never acts by itself; the human stays attributable.
- **`requiresExplicitChoice` is false in the ordinary case.** One legitimate identity means no ceremony. This is the mechanism that keeps Aura from feeling like a permission console.
- **`ActingAvailability`** records *why* an option exists — personal default, institutional capability, institutional governance role, institution account — so a surface can explain authority instead of merely obeying it.

## 5. The Capability Projection model

`lib/core/authority/capability_projection.dart`

> **CLIENT PRESENTATION ≠ SECURITY AUTHORIZATION.** Hidden UI is never the security boundary.

- `InstitutionStanding.effectiveCapabilities` is a **closed set from the backend**. Nothing is added client-side; unknown tokens are dropped rather than guessed.
- `ConsequentialAct.requirement` declares **exactly one** of: personal / capability / governance role — gate-enforced.
- Governance acts (`transferOwnership`, `appointAdmin`) require `InstitutionRole.owner` and **carry no capability**, mirroring the backend's non-delegable design. A holder of all 22 capabilities still cannot transfer ownership.
- `ControlPresentation` defaults to **`absent`, not disabled** — the frozen Capability-Adaptive Experience doctrine says a person should not be walked through an interface built around authority they do not have. `explained` exists only when the caller supplies a reason worth communicating.

## 6. Consumers migrated

| Consumer | Old authority source | New authority source | Behavioural effect | Tests | Owner |
|---|---|---|---|---|---|
| `presence_repository.dart` (heartbeat) | `activeActorContextProvider` → institution actor for anyone affiliated | `actingContextAuthorityProvider.personId` | **Correction.** Presence is now always the person. Previously an institutionally-affiliated person's presence was published as the institution everywhere. | C1 authority suite + gate | C1 |
| `activeActorContextProvider` | — | retired, `@Deprecated`, **zero consumers**, gate-enforced | none | gate | C1 |
| `institution_access_provider` fabrication | six invented capability tokens | modelled as `isInstitutionAccount` standing; **no capability invented** | see §7 | C1 authority suite | C1 |

**Deliberately not migrated:** `resolveActorContext` still has 3 consumers (`direct_thread_screen`, `inbox_screen`, `institution_detail_screen`). Those are C7/C3 surfaces; C1 establishes the authority and leaves the surface reconstruction to its owner (§16).

## 7. The fabricated capabilities — modelled, not silently removed

Removing the client-side injection outright would have **broken institution-account sessions**, because the backend genuinely returns an empty capability set for them (`activeMembership` is null → `activeCapabilities = []`).

So C1 does not delete the compensation and does not hide it. `InstitutionStanding.isInstitutionAccount` names the situation, `ActingAvailability.institutionAccount` records why an act is available, and **no capability is fabricated in the new model**.

> **The real fix is backend-side:** an institution-account session should receive its own effective capability set from `InstitutionAuthorityService`. Raised as a founder decision (§M-2).

The legacy provider still carries its injection so nothing breaks today; the gate prevents any *new* fabrication anywhere.

## 8. Consequential-action UX — options, not a freeze (§22)

The founder checkpoint. Three researched options; **nothing frozen.**

| | Option A — Attribution at the act | Option B — Contextual acting banner | Option C — Global identity switcher |
|---|---|---|---|
| **What** | The composer/send control shows *who this will represent*, with the avatar and name inline, and offers the alternative only when one legitimately exists | A persistent strip inside institutional surfaces reading "Acting as Wayne County" | A permanent top-level identity selector |
| **Ceremony** | none for personal acts | low, but always present in institutional context | always present everywhere |
| **Honesty** | attribution appears exactly where consequence is decided | attribution is ambient, easy to stop seeing | invites mode-switching as a habit |
| **FD-9 fit** | contextual and quiet | borderline — reintroduces a per-surface institutional indicator | **contradicts** the frozen one-product-tree direction |
| **Risk** | must be present on every consequential surface | banner blindness | the "choose your role" experience the instruction rejects |

**Recommendation: Option A.** It is the only one where authority becomes visible *because a consequence is about to happen* rather than because of where the person navigated — which is the same principle that made route-derived acting identity wrong in the first place. `ActingResolution.requiresExplicitChoice` already carries exactly the signal Option A needs.

**Not implemented.** No screen was changed. The authority can answer the question; the interaction is the founder's to adjudicate.

## 9. G5 re-verification (§15) — 42 sites re-checked, **26 reassigned**

C0 assigned 14 files / 42 sites to C1 on `J` basis. Every one was re-verified against actual C1 reconstruction scope.

| Files | Sites | Verdict |
|---|---|---|
| `admin/presentation/*` (11 files) | 34 | ❌ **REASSIGN.** Measured: **zero** institutional authority code — no `isOwner`/`isAdmin`/capability/`institutionIdentityProvider` usage. They are platform-admin CRUD screens governed by the separate `AppAdminAccess` boolean. C1 owns acting context and capability projection; these do neither. |
| `auth/presentation/*` (2 files) | 3 | ❌ **REASSIGN.** Sign-in/register error states. C1 explicitly *preserves* auth flows; nothing here is acting context. |
| `institutions/presentation/admin_workspace_screen.dart` | 4 | ✅ **CONFIRMED C1.** Institutional workspace with real capability-gated surfaces. |

**Net: C1 keeps 1 file / 4 sites. 13 files / 38 sites need reassignment.**

Their honest owner is the same gap C0 surfaced: **the approved roadmap names no chapter for platform administration or authentication surfaces.** Rather than silently move them to another chapter, they are raised for founder disposition (§M-3). Zero silent carry-forward.

## 10. Anti-drift gates

`test/authority/c1_anti_drift_gate_test.dart` — hard build failure, 11 tests.

**Zero tolerance** (each proven to fire by deliberate violation, probe reverted):
- no new ambient current-actor provider
- the retired `activeActorContextProvider` has zero consumers
- no capability token added to a set client-side
- the role→capability table is never rebuilt client-side
- every act declares exactly one requirement; governance acts carry no capability; institutional options never lose the acting person

**Ratchets** (`test/authority/c1_drift_baseline.txt`, same fail-on-rise-and-on-unrecorded-fall discipline as C0):
- **A1** route-derived acting identity — 1 file, blocked on the founder checkpoint
- **R1** role-derived authority booleans — 26 files / 86 sites
- **R2** role-literal comparisons — 3 files / 6 sites

## 11. Verification

`flutter analyze lib/ test/` clean · `flutter test` **494 passed**, 1 skipped, 0 failed (463 at C0 close, **+31 C1**). All C0 gates preserved and green. No production polling.

---

## 12. Founder rulings — implemented

### Ruling 1 · Attribution at the consequential act — APPROVED, implemented

`lib/core/authority/acting_attribution.dart`. Frozen rule encoded literally:

| Requirement | How it is enforced |
|---|---|
| no global acting mode | there is no ambient actor to read; `resolve(act)` is the only entry |
| no route-derived sender | the authority takes no path and reads no router, by construction |
| one context → no chooser | `requiresExplicitChoice` false; the widget *states* attribution |
| several contexts → explicit choice | chooser renders only when `requiresExplicitChoice` |
| institution keeps the person | `ActingOption.personId` populated on every institutional option, gate-enforced |
| capability-adaptive | `ControlPresentation` defaults to `absent`, not disabled |
| governance stays role authority | `transferOwnership`/`appointAdmin` carry no capability, gate-enforced |

### Ruling 2 · Institution-account compensation — REMOVED, and no backend change was needed

Investigation reached a different answer than expected, and a better one: **the gap the client compensated for does not exist.**

- `institution-bootstrap.ts` **always** creates an `InstitutionMember` row with `role: OWNER, canSpeakOfficially: true`. There is no session that governs an institution without a member row.
- `/institutions/me` returns **no top-level `institution` key**, so the client's `accountType == 'INSTITUTION'` branch could never populate an identity either.
- Therefore `isAuthorizedSpeaker && role.isEmpty` was **unreachable**: whenever an identity exists it carries a role.

The six-token injection was dead code that made the client a second source of authority. **Removed.** No alternate authority service, no institution-account special path, no new formula — because none was warranted. Gate-enforced against reintroduction.

### Ruling 3 · Duplicate effective-capability formula — CONVERGED

`institutions.service.ts` recomputed `ROLE_CAPABILITIES[role] ∪ grants` inline **while `InstitutionAuthorityService` was already injected as `this.authority`**. Now delegates to `authority.getContext()`; the `ROLE_CAPABILITIES` import is gone, so the second formula cannot be reconstructed by accident.

Shared-system preservation: consumers identified (`/institutions/me` only), behavioural equivalence proven by spec, contract unchanged, 316 institution tests green, full backend suite 172 suites / 2200 tests green.

### Ruling 4 · `/institutions/me` single-membership — CORRECTED

**Disposition: not intentional scoping.** `activeMembership` is `findFirst` ordered `createdAt: 'asc'` — the person's **oldest** membership, chosen arbitrarily. A person may legitimately hold several. The payload's `memberships[]` carried role but **no capabilities**, and `institutionIdentityProvider` built the client's entire capability picture from that one arbitrary membership.

**Consequence:** a client viewing institution B was reasoning with institution A's authority.

**Corrected** through the canonical boundary — every `memberships[]` entry now carries its own effective capabilities from `InstitutionAuthorityService`. No second membership authority was created. Client consumes it via `standingForInstitutionProvider(institutionId)`: ask about the institution you are actually showing.

### Ruling 5 · 38 displaced G5 sites — DISPOSITIONED

Two named product disposition checkpoints before C11: **PD-1 Platform Administration** (11 files / 34 sites) and **PD-2 Authentication & Account Entry** (2 files / 3 sites). C1 retains 4 sites on `R` basis. The C0 ledger is annotated with the original assignment struck through, so the correction stays visible. Full matrix: `C1_G5_DISPOSITION_MATRIX.md`. **181 sites still traceable; zero lost.**

### Ruling 6 · Institutional direct messaging — ROUTE INFERENCE REMOVED

`interaction_service.dart` no longer derives the sender from the URL. The route may still establish recipient and viewed context; it no longer establishes acting identity.

- **Behaviour change:** a person in an institution workspace who taps Message now starts the thread **as themselves**. Previously an institution admin's personal message silently became institutional correspondence.
- **Contract provided for C7:** `ConsequentialAct.correspondAsInstitution` (requires `OFFICIAL_REPRESENTATION`). When it resolves alongside `sendDirectMessage`, two legitimate contexts exist and C7 must require explicit selection at message initiation.
- **The A1 ratchet is now at zero** and stays armed. C1 did not redesign any correspondence surface.

### Presence — APPROVED

Heartbeat is always the person. `PERSON ≠ INSTITUTION ≠ MEMBERSHIP ≠ ACTING CONTEXT ≠ PRESENCE` holds: presence no longer inherits institutional identity from affiliation, navigation or membership.

---

## 13. Verification (final)

| Check | Result |
|---|---|
| `flutter analyze lib/ test/` | clean |
| `flutter test` | **502 passed**, 1 skipped, 0 failed (463 at C0 close, **+39 C1**) |
| `aura-backend` `tsc` | clean |
| `aura-backend` jest | **172 suites / 2200 tests passed** (+1 suite, +3 tests) |
| Targeted institution regression | 316 passed |
| C0 gates | preserved and green |

## 14. Remaining exceptions — reported, not converted to backlog

| # | Exception | Why it remains |
|---|---|---|
| 1 | **R1 ratchet: 25 files / 85 `isOwner`/`isAdmin` sites** | Legitimate where role has product meaning; each owning chapter burns down its own share. Frozen so none can be added. |
| 2 | **R2 ratchet: 3 files / 6 role-literal comparisons** | 3 of the 6 are not authorization at all (support-chat message author, members roster display). |
| 3 | **`resolveActorContext` — 3 consumers** | `direct_thread_screen`, `inbox_screen`, `institution_detail_screen` are C7/C3 surfaces. C1 established the contract; §16 forbids reconstructing them here. |
| 4 | **F6 — platform admin flattened to one boolean** | 14+ granular backend `AdminPermission` values vs client `AppAdminState{none,admin}`. Raised under **PD-1**; needs a product decision before a G5 cleanup buries it. |
| 5 | **Attribution is live on ONE representative surface** | `institution_post_composer_screen.dart`. Announcements, Live and correspondence composers belong to C5/C7; the contract is ready for them. Deliberately not spread further — that would be reconstructing surfaces C1 does not own. |
| 6 | **Attribution copy is not canonical vocabulary** | `Change` is an action label with no C0 action behind it. Brought forward for founder decision (§16); not frozen. |

---

## 15. Representative Option-A implementation — certified

**Surface:** `institution_post_composer_screen.dart`, immediately above the control that commits publication.

Publishing in an institution's voice is the canonical consequential act, so attribution is stated exactly where the consequence is decided — not inferred from the route that led there. The composer publishes only in the institution's voice, so **no chooser is manufactured**; the strip states who the act represents and shows *why* that authority exists, keeping the acting person visible so the institution never appears to act by itself.

This is the minimum presentation required to establish acting-context behaviour. **No composer was reconstructed** — C5 still owns that surface.

### A modelling error the implementation exposed

`alsoPerformablePersonally` was originally a property of the **act** (`publishInstitutionPost => true`). Attempting the real implementation proved that wrong: whether a personal alternative exists depends on the **surface**. An institution's post composer offers only the institution's voice; a unified composer that can publish either way offers both.

Left as-is, the institution composer would have rendered a chooser it could not honour — **a control that changes nothing is worse than no control.** Corrected: `resolve(act, offerPersonalAlternative: …)` is now declared by the caller.

### Certification — `test/authority/acting_attribution_test.dart`, 4 widget tests

| Frozen requirement | Test |
|---|---|
| one legitimate context → no unnecessary choice | states "Publishing as Wayne County", no `Change` control |
| institution retains the natural person | renders the availability explanation; `personId` populated |
| several contexts → explicit choice before the act | `Change` appears, both identities offered with reasons, selection takes effect |
| capability-adaptive: absent, not disabled | an unavailable act renders nothing at all |

## 16. Representation / authority consistency check

| Check | Result |
|---|---|
| Does C1 introduce competing words for Person / Institution / Member / Participant? | **No.** `ActingOption.noun` resolves through `ProductNoun`; no new identity noun exists. |
| Does C1 re-derive capability vocabulary? | **No.** `InstitutionCapabilityToken` mirrors the backend enum; unknown tokens are dropped. |
| Canonical identity-projection invariant — *"generic platform ('Aura') identity substituting for human/institution identity"* is not acceptable | **Honoured.** Attribution always names the real person or institution. |
| Capability doctrine — *authority delegated narrowly, never an undifferentiated "admin" role* | **Honoured.** Attribution explains authority as capability or governance role; it never renders "Admin" as a stand-in. |
| `IdentityConcept` (C0) preserved | **Yes.** `PERSON ≠ INSTITUTION ≠ MEMBERSHIP ≠ ACTING CONTEXT ≠ PRESENCE` holds, and the presence correction enforces the last term. |

### ⚑ One gap found — C1 needs vocabulary C0 does not have

C1 authored four UI strings with no canonical backing:

`"Publishing as"` · `"This will be attributed to"` · `"Change"` · `"Change who this represents"`

`Change` is an **action label**, and the Product Language Authority has no action for *change which identity this act represents*. `edit` means edit content; `manage` and `view` do not fit.

Per the instruction — *"If C1 exposes missing vocabulary required for a genuine product concept: bring it forward. Do not invent local copy to bypass C0."* — this is **brought forward, not frozen**. The strings work today; they are not proposed as canonical.

**Founder decision required:** add a canonical action for attribution change (e.g. `ProductAction.changeAttribution`), or rule that attribution copy is contextual prose outside the governed action vocabulary. Either answer is legitimate; C1 must not decide it.
