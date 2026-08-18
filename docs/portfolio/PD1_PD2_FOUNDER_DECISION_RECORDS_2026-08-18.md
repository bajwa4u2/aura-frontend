# PD-1 & PD-2 — FOUNDER DECISION RECORDS

**Status:** Decision records only. **I have not decided either.** Part 2 not started; execution hold observed.
**Date:** 2026-08-18 · Baseline: 143 findings + 308 obligations = **451 units** · 17 chapters · reconciliation **PASS**

Rulings 1, 2 and 5 are applied and recorded — see §0. Rulings 3 and 4 are answered by the two records below.

---

## 0. Rulings already applied

| Ruling | Applied | Where |
|---|---|---|
| **1** DEFECT-1 → CH-04 | Recorded as `assignedDefects[0]`, `state: OPEN_ASSIGNED`, `waived: false`, `acceptedAsPermanent: false`, plus **three** new CH-04 certification requirements: the restoration requirement, the prohibition on representing the 333-pass suite as visual proof, and the prohibition on touching Meetings to repair it. Explicitly `doesNotAuthorize` unrelated CH-04 work. | `05-execution/index-chapters.json` · `part1-rulings-applied.json` |
| **2** Meetings evidence | `evidenceSupersessions[0]`: historical **97/97 retained verbatim** (still at `certificationRequirements[2]`, unmodified — the script fails closed if it is absent), current **118 PASS** operative, `SUPERSEDED_BY_CURRENT_VERIFICATION`. Suite **grew**; not a coverage loss. | same |
| **5** Part 1 record | All nine accepted outcomes preserved verbatim. F116 and F053 remain `PARTIALLY_VALIDATED`. No chapter closed. | `part1-rulings-applied.json` |

**Canonical accounting unchanged.** DEFECT-1 is a coverage defect against an existing chapter — not a new finding, not a new obligation. **451/451 · 17/17 · PASS ×3.**

---
---

# PD-2 — AUTHENTICATION & ACCOUNT ENTRY

## A. Exact definition and originating evidence

**Definition:** `Authentication & Account Entry`, recorded `rcOwnership: UNMAPPED_TO_RC`
(`00-evidence/unmapped-surfaces.json`).

**Why it exists** — `CO-RC-C1-021` (RC-C1 `contradictionsOrGaps[1]`), verbatim:

> *"PD-1 and PD-2 exist because the approved roadmap names no owner for platform admin, institution
> admin, public directory, search/saves/updates or auth surfaces. **107 of 181 G5 sites were assigned
> from labelled judgment rather than roadmap text.**"*

**The open item** — `CO-RC-C1-022` (RC-C1 `contradictionsOrGaps[2]`), verbatim:

> *"PD-2 STRUCTURAL DISPOSITION remains OPEN even though the PD-2-adjacent public-first copy drift was resolved."*

**Standing gate:** `CO-RC-C11-002` — PD-1 and PD-2 "must be resolved **BEFORE C11**."

**Critical distinction:** PD-2 is **not** an unresolved *product* question. Authentication is built,
shipped and working. What is unresolved is **who owns its reconstruction**, and where the boundary
between two candidate owners falls.

## B. Why it blocks CH-02 / Part 2

A candidate disposition **already exists in canon** and both affected chapters record it independently:

| Chapter | `founderActions` entry |
|---|---|
| **CH-02** | *"Ratify the PD-2 structural/experience split (**structure here**, account-entry experience in CH-10)"* |
| **CH-10** | *"Ratify PD-2's split disposition (**structure to CH-02, experience here**) — required before C11"* |

It blocks at **entry**, not at closure, because **it defines the keystone's boundary**. W1-C/D/E are
slices *of a boundary that is not yet ratified*:

- **S1** writes session establishment at the single `TokenStore.setSession()` choke point. Whether
  `verify-email` / `verify-pending` / `identity-baseline` gating is inside that choke point or is
  account-entry experience is exactly the PD-2 line.
- **S2** classifies 24 currently-unclassified routes fail-closed. Six auth routes plus two alias
  redirects (`/auth`, `/institution/sign-in`) sit precisely on the boundary.
- **S3** publishes the destination-reconstruction contract. Its central mechanism is the
  `?redirect=` parameter — which *is* account entry preserving intent (**F103** auth returns to the
  same Live, **F104** sign-up preserves intent).

Building the keystone first and ratifying the boundary afterwards would mean CH-02 had already
answered PD-2 by construction. That is the failure the authority-admission doctrine exists to prevent.

## C. Current implementation/product reality

- **8 screens:** `auth_screen`, `login`, `register`, `forgot_password`, `reset_password`,
  `verify_email`, `verify_pending`, `identity_baseline`.
- **6 declared routes** + **2 alias redirects** (`/auth → /login`, `/institution/sign-in → /login`).
  The second is the fix from the Meetings router regression — institution-path ≠ institution actor.
- **The structural half already exists and is load-bearing:** `lib/router.dart` lines ~382–651 carry
  the redirect/verification decision logic, emitting `/login?redirect=…` and
  `/verify-pending?redirect=…`. This is destination reconstruction, in CH-02's language, today.
- **F065** (`UNKNOWN`/`RESTORING` treated as unauthenticated) is `IMPLEMENTED_NOT_LIVE_CERTIFIED` and
  gates **F103/F104**, which are `OPEN`.
- Auth carries **5 of 270** foundation-debt sites — negligible. **PD-2 is a boundary question, not a debt question.**

## D. Legitimate disposition alternatives

| | Disposition |
|---|---|
| **D1** | **Ratify the recorded split** — structure (session establishment, route classification, redirect/destination reconstruction, verification gating) to **CH-02**; account-entry experience (login/register/forgot/reset surfaces, conversion, copy) to **CH-10**. |
| **D2** | **Assign PD-2 wholly to CH-02.** One owner for everything authentication. |
| **D3** | **Admit a dedicated authentication chapter (CH-18).** |
| **D4** | **Defer with the consequence accepted** — enter CH-02 with the boundary unratified. |

## E. Consequence of each

| | Architecture | Chapter ownership | Debt | Dependencies | Protected/shared boundaries |
|---|---|---|---|---|---|
| **D1** | Matches the built system: the structural half already lives in the router (CH-02's authority), the experience half in the acquisition funnel (CH-10's). | Two owners, one seam. The seam must be written down or it drifts. | 5 sites split across two chapters. | Unblocks **W1-C/D/E now**. CH-10 stays W5. Satisfies the `CO-RC-C11-002` pre-C11 gate. | None crossed. PB-01 is reached-not-opened by S2's classification of guest-reachable meeting routes, exactly as already governed. |
| **D2** | Coherent, but makes CH-02 own conversion surfaces that have nothing to do with destination authority. | One owner. | 5 sites in one chapter. | Unblocks W1-C/D/E. **Enlarges CH-02**, already the `LARGE` highest-fan-out chapter. | Same. Risk: CH-02's authority silently widens — the exact drift the admission doctrine guards. |
| **D3** | Cleanest conceptually. | A **new** chapter. | 5 sites isolated. | **Blocks Part 2 by weeks.** The roadmap froze 2026-08-15 and CH-02's own `founderActions` record that *the axis has no mechanism for admitting a later authority* — admitting CH-18 requires ruling that mechanism first. | Creates a new entrant to every gate. |
| **D4** | Undefined. | Undefined. | Unchanged. | W1-C/D/E proceed, but **CH-02 answers PD-2 by construction**, and `CO-RC-C11-002` still bites before C11 — with a built system arguing for whatever was built. | The one option that can create authority silently. |

## F. Recommendation — **D1, ratify the recorded split**

Three evidence-based reasons:

1. **It is the only option already recorded in canon**, and it is recorded **independently in two
   chapters** whose `founderActions` were authored separately. Neither cites the other. That is
   convergent evidence, not a single analyst's reading.
2. **It matches the built system.** The structural half is in `router.dart` today, doing destination
   reconstruction; the experience half is in the auth screens. D1 ratifies what exists rather than
   redistributing working code.
3. **It is the only option that unblocks Part 2 without enlarging or inventing an authority.** D2
   grows the largest chapter, D3 needs an admission mechanism that does not exist, D4 decides by construction.

**What I am not claiming:** the *precise* seam is not fully specified in canon. The chapters name it
"structure vs experience" without enumerating each route. If you ratify D1, the first act of CH-02 S3
should be to **publish that enumeration** and have it confirmed — recommended as a condition of D1,
not as a separate decision.

## G. What becomes executable immediately under D1

- **W1-C** CH-02 S1 — single-choke-point session establishment, **F065 proven on a live refresh**
- **W1-D** CH-02 S2 — disjoint fail-closed route classification; 24 routes classified; 23 navigation
  gates + literal ratchet green; Meetings **118** attributable against the W1-000 baseline
- **W1-E** CH-02 S3 — published destination-reconstruction contract, **including the PD-2 seam enumeration**

**Still not executable:** CH-11 (RC-C5 scope ratification), CH-04 PHASE 1 (AD-CON-5, SU-5, VS-02,
devices), CH-02 S4 (needs CH-03's W2 conformance gate), CH-10 (W5).

---
---

# PD-1 — PLATFORM ADMINISTRATION

## A. Exact definition and originating evidence

**Definition:** `Platform Administration`, `rcOwnership: UNMAPPED_TO_RC`
(`00-evidence/unmapped-surfaces.json`).

**Originating record** — `CO-RC-C11-005` (RC-C11 `explicitlyRemainingObligations[1]`), verbatim:

> *"PD-1 Platform Administration disposition (**11 files / 34 G5 sites**) — no owning chapter in the approved roadmap"*

Same root cause as PD-2 (`CO-RC-C1-021`); same pre-C11 gate (`CO-RC-C11-002`).

## B. Present product/runtime reality

**Platform Administration is shipped, live product — not unbuilt scope.**

| | |
|---|---|
| Routes | **12** under `/admin/*` — institutions, users, grants, audit-logs, settings, feature-flags, institution-domains, review-queue, policies, moderation, support, institution members |
| Screens | **14** in `lib/features/admin/presentation/` |
| Shell | Its own `ShellContext.admin` |
| Backend | Dedicated module with `AdminAuthorizationService` and `AdminPermissionGuard` |

**Route classification note:** `/admin` is named in **DB-6** as one of the fail-open **24 unclassified
routes**. **CH-02 S2 (W1-D) will classify it regardless of PD-1's disposition** — classification is
destination authority, not administration ownership. PD-1 does not block Part 2.

## C. Why no chapter owns the 52 sites

The approved roadmap simply **names no owner** for platform administration (`CO-RC-C1-021`). The
17-chapter architecture was derived from that roadmap, and the doctrine forbids force-assignment
(`doNotForceAssign: true`), so the debt is attributed to `PD-1` rather than to a chapter chosen for tidiness.

### Two canonical figures reconciled — and one discrepancy reported, not adjudicated

| Source | Figure | What it counts |
|---|---|---|
| `CO-RC-C11-005` | 11 files / **34** G5 sites | **G5 only** |
| Frozen C0 baseline (`c0_drift_baseline.txt`, 2026-08-15) | 11 files / **35** G5 sites | **G5 only** |
| W1-B remainder register | **11 files / 52 sites** | **all five rules** — G5 35, G7 7, G2 6, G3 3, G4 1 |

- **The 11-file set matches exactly across all three.**
- My "52" and canon's "34" were never in conflict: 52 counts five rules, 34 counts one.
- **The 34 vs 35 discrepancy is real** — two canonical records disagree by one G5 site. The C0 baseline
  is the later, machine-measured, ratchet-enforced record. **I have not adjudicated it.** Reported for
  your disposition alongside PD-1.

## D. Legitimate disposition alternatives

| | Disposition |
|---|---|
| **D1** | **Assign PD-1 to CH-17.** Governance/certification already owns the *decision* (`CO-RC-C9-029` precedent for SupportScreen), and administration is a governance-facing surface. |
| **D2** | **Assign PD-1 to CH-08 (Institution Room).** Six of the 12 routes are institution-facing. |
| **D3** | **Admit a dedicated Platform Administration chapter (CH-18).** |
| **D4** | **Rule PD-1 OUT OF RECONSTRUCTION SCOPE** — an internal operator tool explicitly excluded from this reconstruction and from C11, with its debt frozen by rule the way PB-01's is. |
| **D5** | **Defer.** |

## E. Consequence of each

| | Architecture | Chapter ownership | Debt | Dependencies | Protected/shared boundaries |
|---|---|---|---|---|---|
| **D1** | CH-17 is a certification/release gate, **expressly not a construction chapter** (`CO-RC-C11-001`: "must not be redefined"). Assigning construction work here contradicts that. | Owner exists. | 52 sites become CH-17's burn-down. | CH-17's terminal half is W7 → debt retires **last**. | Would make the release gate also a construction chapter. **Recommend against.** |
| **D2** | Half-fits: 6 of 12 routes are institution-facing; users/grants/audit-logs/feature-flags/policies are platform-wide, not institutional. | Owner exists. | 52 sites into an already-`VERY_LARGE` chapter (63 sites of its own). | Retires at W4. | Enlarges CH-08's authority beyond the Institution Room. |
| **D3** | Honest — it genuinely is a distinct surface. | New chapter. | 52 sites isolated with a real owner. | **Requires the authority-admission mechanism that does not exist** (same blocker as PD-2/D3). Adds an entrant to every gate. | New entrant to all gates. |
| **D4** | Matches what it is: an internal operator tool, never a member-facing product surface. | **No chapter — by ruling, not by omission.** | 52 sites become `FROZEN_BY_RULE`, exactly like PB-01's 31 Meetings sites. **Not orphan debt: ruled debt.** | Removes PD-1 from the pre-C11 gate by explicit exclusion, satisfying `CO-RC-C11-002` by decision. | **None.** Nothing is touched. `/admin` still gets classified by CH-02 S2 — security is unaffected. |
| **D5** | Undefined. | None. | **Remains standing orphan debt — which your ruling forbids.** | Still bites before C11. | None. |

## F. Recommendation — **D4, rule PD-1 out of reconstruction scope with debt frozen by rule**

1. **It is the only option that ends orphan debt without inventing or distorting an owner.** Your
   ruling forbids standing orphan debt and forbids manufacturing an owner. D4 satisfies both: the debt
   gets a *disposition*, not a fictional owner.
2. **The precedent already exists and is working.** 31 Meetings sites are frozen by rule under
   `CO-RC-C0-008` and are correctly reported as *prohibited*, not neglected. The W1-B register already
   distinguishes `FROZEN_BY_RULE` from unscheduled. PD-1 needs no new machinery — only the ruling.
3. **It matches what the surface is.** Twelve operator routes behind a permission guard, with their own
   shell. No member ever sees it. Reconstructing it to member-facing conformance standards spends the
   programme's scarcest resource on the one surface with no product audience.
4. **It costs nothing in safety.** `/admin` is classified fail-closed by CH-02 S2 regardless. D4
   disposes of *foundation-debt conformance*, not authorization.

**What I am not claiming:** D4 is a **scope** judgement, and scope is yours. If Platform Administration
is intended to become a first-class product surface, **D3 is the honest answer** and the admission
mechanism has to be ruled first — the same blocker PD-2/D3 hits. I recommend D4 on the evidence of what
the surface *is today*, not on a prediction of what you may want it to become.

## G. Resulting ownership / retirement treatment of all 52 sites under D4

| Rule | Sites | Treatment |
|---|---:|---|
| G5 direct state-primitive construction | **35** | `FROZEN_BY_RULE` |
| G7 local time formatter | 7 | `FROZEN_BY_RULE` |
| G2 local elapsed time | 6 | `FROZEN_BY_RULE` |
| G3 local timezone conversion | 3 | `FROZEN_BY_RULE` |
| G4 full-surface spinner | 1 | `FROZEN_BY_RULE` |
| **Total** | **52** across **11 files** | |

- **Owner:** `NONE — EXCLUDED FROM RECONSTRUCTION BY FOUNDER RULING`. Not "unassigned".
- **Retirement condition:** the exclusion is lifted by a later founder ruling. Until then there is no
  retirement condition, and that absence is *itself* the recorded disposition.
- **The ratchet still holds the line.** The C0 anti-drift gate keeps these counts frozen: the debt may
  never **rise**, and if it **falls**, the gate fails until the baseline is updated. Exclusion from
  reconstruction is not exclusion from measurement.
- **Reporting rule:** these 52 sites are reported as `FROZEN_BY_RULE`, never folded into "remaining
  debt". With PB-01's 31, that makes **83 of 270 sites** ruled rather than pending — the number that
  must never be presented as neglect.
- **`CO-RC-C11-005`** moves from `REMAINING_OBLIGATION` to disposed-by-ruling, with its text retained
  verbatim. **Evidence supersession, not historical mutation** — the same treatment as ruling 2.

---

## Execution hold observed

Part 2 not started. No unrelated implementation performed. No additional founder decisions accumulated —
the **34 vs 35** discrepancy is reported inside PD-1 rather than raised as a separate item.

**On your ruling of both, I will:** reconcile the effects deterministically, apply them to the canonical
artifacts with the same supersession discipline, rerun the full validation suite, and return the
**Part-2 execution boundary** for authorization.
