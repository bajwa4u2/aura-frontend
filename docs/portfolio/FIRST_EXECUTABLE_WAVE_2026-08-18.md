# FIRST EXECUTABLE WAVE — PRE-EXECUTION CHECKPOINT

**Status:** Rulings applied · graph rebuilt · wave re-derived · reconciliation PASS.
**Nothing executed. Wave 1 not authorized. No Stage 6. No production, CORS, migration, R2 or deployment action.**
**Date:** 2026-08-18 · **Baseline:** 143 findings + 308 obligations = **451 units** · 17 chapters
**Supersedes for sequencing purposes:** Stage-5 `W1`. Supersedes nothing else.

---

## A. Founder rulings applied — exact artifact locations

| Ruling | Applied in | What it produced |
|---|---|---|
| **1** cycle | `05-execution/execution-graph-v2.json` · `tools/rebuild-execution-graph.mjs` | Two demotions, each with old/new state, reason, ruling, obligation-preserved and provenance-preserved flags |
| **2** PB-02 first entry | `execution-graph-v2.json` → `firstEntryInvariant` | Dimensional separation recorded; `protectedAuthorityCreated: false` |
| **3** F006–F010 | `05-execution/ch04-posture-v2.json` | Five-row dimensional matrix + four-partition chapter posture |
| **4** CORS | `05-execution/cors-current-state.json` | Eight-item record, non-mutating capture, sequencing verdict |
| **Wave** | `05-execution/first-wave-v2.json` · `tools/derive-first-wave.mjs` · `tools/first-wave-attributes.json` | 10 candidates evaluated against a 6-criterion fail-closed predicate; 13 attributes per unit |

---

## B. Cycle result

**Before (declared graph):** `CH-05 → CH-13 → CH-06 → CH-05`
**After (declared graph):** **NONE.** The cycle is gone.

| Edge | Treatment | Authority |
|---|---|---|
| `CH-13 → CH-05` | **PRESERVED UNCHANGED** — RC-C5 frozen founder gate | Not touched. Not routed around. No admitted unit reaches either endpoint. |
| `CH-05 → CH-06` | **DEMOTED** from hard chapter-sequencing gate to *bounded semantic prerequisite* | Ruling 1 §2. MEDIUM inference never established it as a whole-chapter gate. |
| `CH-06 → CH-13` | **DEMOTED** from hard chapter-sequencing gate to *certification-phase prerequisite* | Ruling 1 §2. LOW–MEDIUM inference. |

**Proof that the underlying obligations survived:** `obligations deleted: 0`. The rebuild reports `chapter edges before: 42 / after: 42` — no edge was removed, only two had their *execution authority* reclassified. Ownership, provenance and validation burden are unchanged on both, and reconciliation still accounts 451/451.

### Two findings worth the founder's attention

**B1 — the cycle was never in the evidence.** Neither `CH-05 → CH-06` nor `CH-06 → CH-13` appears among the 52 evidence-derived dependencies. Both exist *only* as `dependsOn` declarations in `index-chapters.json`. The deadlock was an artifact of the declaration layer. This independently supports Ruling 1 rather than merely complying with it.

**B2 — a different cycle exists in the evidence graph: `CH-04 ↔ CH-06`.** It is untouched by Ruling 1 and is reported rather than resolved:

| | Edge | Class | Grade |
|---|---|---|---|
| D-16 | CH-04 realtime attachments certified (F006/F008/F010) → CH-06 Conversation FINAL certification | CERTIFICATION | MEDIUM edge / LOW endpoint state · graded CONFLICTED |
| D-27 | CH-06 Conversation shared capabilities certified → CH-04 Meetings validation batch F112 | PROTECTED_BOUNDARY | **STRONG / HIGH** (PB-01, VD-045) |

It **dissolves at bounded-capability granularity**: the two CH-04 endpoints are *different* bounded capabilities — realtime attachment certification on one side, Meetings equivalent validation on the other. No ruling is required and nothing is weakened. **D-27 is explicitly NOT demoted.**

---

## C. First-entry result

- **PB-02 scope:** protected-layer corrective repair, protected-boundary crossing, modification of the protected subsystem. Fully authoritative there. **Not weakened.**
- **General reconstruction order:** the declared construction graph. CH-02 and CH-03 may be entered ahead of CH-04 by construction dependency.
- **Resulting invariant:** *PB-02 does not become the general construction order. Where execution actually reaches a protected boundary, it stops there and applies PBCR governance first.*
- **`protectedAuthorityCreated: false`** — recorded mechanically in `execution-graph-v2.json`. No admitted unit performs a protected-layer repair.

The invariant has teeth in this very wave: the first admitted unit (**W1-000**) exists *because* Ruling 2 requires the owed PBCR conditions to be discharged before CH-04's boundary is approached.

---

## D. F006–F010 final dimensional state matrix

`provenanceStrength: WEAK` is a **mention-count** metric, not an evidence-quality judgement. All five carry **direct founder observation**.

| | Capability | IMPLEMENTATION | LOCAL_VALIDATION | CERTIFICATION | LIVE_PRODUCTION | CANONICAL_INTEGRATION |
|---|---|---|---|---|---|---|
| F006 | 1:1 audio | NOT_RECORDED | N/A | **PROVEN** | **PROVEN** | NOT_PROVEN |
| F007 | Group audio | NOT_RECORDED | N/A | **PROVEN** | **PROVEN** | NOT_PROVEN |
| F008 | Video call | NOT_RECORDED | N/A | **PROVEN** | **PROVEN** | NOT_PROVEN |
| F009¹ | Grow 1:1 → group | NOT_RECORDED | N/A | **PROVEN** | **PROVEN** | NOT_PROVEN |
| F010 | Screen share | NOT_RECORDED | N/A | **PROVEN** | **PROVEN** | NOT_PROVEN |

¹ **F009 is owned by CH-06, not CH-04** — verified against `index-chapters.json`. Its capability is realtime; its canonical home is the Conversation. The split is preserved, not merged.

**IMPLEMENTATION stays NOT_RECORDED on all five.** You cannot be in a four-party video call without an implementation — but that is inference, and Ruling 3 restores the CERTIFICATION and LIVE_PRODUCTION columns without manufacturing the IMPLEMENTATION column.

---

## E. CH-04 recalculated execution posture

CH-04 no longer has one construction state. It has four partitions:

| Partition | Units | Obligation |
|---|---|---|
| **EXISTING_CAPABILITY_LIVE_PROVEN** | F006, F007, F008, F010 (+F009 in CH-06) | **PRESERVE.** No reconstruction scheduled. |
| **CANONICAL_INTEGRATION_VALIDATION_REQUIRED** | F006, F007, F008, F010 | Establish the attachment contract → validate → preserve what conforms. **Bounded prerequisite:** the contract is CH-06's and does not yet exist in any form → this is W3-adjacent, **not W1**. |
| **DELTA_CONSTRUCTION_REQUIRED_IF_VALIDATION_FAILS** | contingent | Construct only the demonstrated delta. **Size deliberately not estimated** — estimating it would convert the validation's outcome into an assumption. |
| **INDEPENDENTLY_OUTSTANDING** | F045, F112, 18 OUTSTANDING_CONSTRUCTION obligations in CO-RC-C6-* | Untouched by Ruling 3; outstanding on their own evidence. |

**The twelve LIVE_CERTIFIED findings are preserved at twelve.** The adjudication's "Reading 2" — under which they would have contracted to an unknown number — is **not adopted**. Ruling 3 holds both truths, and Truth A keeps them intact.

**Posture verdict: CH-04 PHASE 1 is REFUSED for the first wave.** Ruling 3 removed the *construction conflict*; it did not discharge PBCR 7–8, settle AD-CON-5, settle SU-5, make VS-02 convenable, or produce real devices. Three independent blockers survive.

---

## F. CORS — current state captured, no mutation

**`GetBucketCors` on `aura-uploads` → `AccessDenied`, HTTP 403.** A *read* was refused.

| # | Item | Finding |
|---|---|---|
| 1 | Current policy | **NOT CAPTURABLE with available credentials** |
| 2 | Environment | Production R2, account `4aaf8b85…`, bucket `aura-uploads`. No non-production bucket in evidence. |
| 3 | Runtime boundary | **YES** — web delivery path for all stored media; the boundary F138 proves performs no authorization |
| 4 | Current allowed origins | **UNKNOWN.** F058's symptom is evidence *that* something is in force or absent, not *what*. |
| 5 | Security | Over-broad origins widen exposure of objects the storage layer does not gate. F143 compounds it: Media identity is not 1:1 with storage objects (10 production aliasing pairs), so app-level disclosure does not bound what a permissive policy exposes. |
| 6 | Proposed change | `PutBucketCors`, JSON prepared earlier. **Not re-proposed, not modified, not executed.** |
| 7 | Targeted validation | VD-019 / VD-026 render proof **plus** a positive check that no unintended origin gained access |
| 8 | Rollback | **NOT ESTABLISHABLE FROM THIS ENVIRONMENT** |

### Rollback-readiness status — the material change since the last checkpoint

The previous checkpoint recorded rollback as `NOT_RECORDED` — *unknown whether captured*. It is now established as **stronger than that: the prior document cannot be read at all from here.** A change made now would be irreversible in the only sense that matters — the prior state would be *unknown*, not merely unsaved.

**Explicitly not inferred:** AccessDenied on a read is **not** the same fact as "no CORS policy exists". The two have different rollback consequences and are not conflated.

**What would capture it:** the Cloudflare dashboard, or an API token scoped to bucket-configuration read. Both are founder-held.

### Sequencing verdict — **CORS IS NOT A FIRST-WAVE PREREQUISITE**

It gates the *visual* half of F051/F052/F056 and WG010's premise. No admitted unit depends on a rendered image. CORS leaves the sequencing path and remains a LANE-W0 external action — now recorded as **blocked on a prior capture**, not merely awaiting a dashboard visit.

---

## G. Updated dependency / keystone / wave accounting

| | Before | After | Change |
|---|---|---|---|
| Chapter edges (declared) | 42 | 42 | none removed; 2 demoted in authority |
| Evidence dependencies | 52 | 52 | unchanged — all still point at real canonical targets |
| Keystones | 9 | 9 | unchanged |
| Chapters | 17 | 17 | no chapter invented, split or merged |
| Obligations deleted | — | **0** | — |
| Declared-graph cycles | 1 | **0** | Ruling 1 |
| Evidence-graph cycles | 1 | 1 | `CH-04 ↔ CH-06`, reported, dissolves at bounded granularity |
| Waves | 9 | 9 | W1's *contents* re-derived; the wave structure is not redesigned |

---

## H. Exact first executable wave

Ten candidates were evaluated against a six-criterion fail-closed predicate. Stage-5 W1 **did not survive unchanged**.

**C1** dependency satisfied at source · **C2** no unresolved founder decision load-bearing at entry · **C3** no protected crossing with owed conditions · **C4** not in a surviving cycle · **C5** validation convenable today · **C6** deterministic completion proof exists.

### Admitted unconditionally — executable on chapter authorization alone

| Unit | Work | Owner |
|---|---|---|
| **W1-000** | Shared-system baseline evidence — discharge PBCR conditions **7 and 8** | CH-04 (pre-entry) |
| **W1-A** | CH-17 governance **MECHANISM** half — non-shrinking register + closure template, both repos | CH-17 |
| **W1-B** | CH-01 foundation adoption and ratchets (continuous) | CH-01 |
| **W1-F** | CH-03 **enumerated consumer audit** — read-only, CODE_STATIC | CH-03 |

### Admitted conditionally — one founder act each

| Unit | Work | Blocking act |
|---|---|---|
| **W1-C** | CH-02 **S1** single-choke-point session establishment, F065 proven on a live refresh | **PD-2** structural disposition |
| **W1-D** | CH-02 **S2** disjoint fail-closed route classification | **PD-2** |
| **W1-E** | CH-02 **S3** published destination-reconstruction contract | **PD-2** |
| **W1-X1** | CH-11 security-first head of the content chain | **RC-C5 scope ratification** (Stage-5's own fail-closed default is *gated*) |

### Refused

| Unit | Failed |
|---|---|
| **W1-X2** CH-04 PHASE 1 | **C2, C3, C5** — AD-CON-5 outstanding; PBCR 7–8 owed; VS-02 and real devices unavailable |
| **W1-X3** CH-02 S4 draft identity contract | **C1, C2** — consumes CH-03's conformance gate, which is W2 |

### Delta from Stage-5 W1

- **Removed:** CH-04 PHASE 1 · CH-02 S4
- **Downgraded:** CH-11 → conditional
- **Added:** **W1-000** (Ruling 2 makes the owed PBCR conditions a boundary obligation *and* it is the attribution baseline for every CH-02 router regression) · **W1-F** (Ruling 4 removes CORS from the sequencing path, partitioning CH-03)

**Why this is the smallest coherent wave:** it establishes exactly two truths — *where a person is* (CH-02's destination authority at one choke point) and *how closure is measured* (CH-17's mechanism, which must exist before the programme's first chapter closure) — while every other admitted unit is non-mutating. It enters no protected boundary, touches no production data, requires no migration and no deployment beyond CH-02's own authenticated-behaviour change under PB-11 observation.

---

## I. Completion proof per unit

Full 13-attribute records are in `tools/first-wave-attributes.json`; the derivation binds them mechanically (a unit with ≠13 attributes, or a wrong attribute name, throws).

| Unit | Completion evidence required |
|---|---|
| **W1-000** | Meetings 97/97 + realtime suites + a written shared-system health report naming every subsystem implicated by the historical crossing, with backend and frontend reported **together** (PB-12) |
| **W1-A** | Register + closure template live in governed markdown in **both** repositories; template carries item-level reporting of F043/F051/F122 and F139's **two** dimensions; each ratchet has a recorded **seeded-violation failure** |
| **W1-B** | Ratchets green **and** each demonstrated to fail on a real seeded violation; G5 / relative_time / local_timezone remainders carry an owner and retirement condition, not a count |
| **W1-C** | A live refresh on an authenticated session that does **not** drop to unauthenticated, in a SINGLE_AUTHORIZED_BROWSER, plus a static proof that session establishment is written at exactly **one** call site |
| **W1-D** | Live signed-out probe; 23 navigation gates + 103-file/294-site literal ratchet green **after** the change; Meetings 97/97 attributable to this change; all 24 previously unclassified routes classified; guest/booker path still resolves |
| **W1-E** | Contract published, with a static check binding each clause to the S1/S2 site that satisfies it |
| **W1-F** | The **enumerated** consumer list — every identity consumer in both repos classified against F053, with the six known extraction sites reconciled in. The list is the deliverable; a count is not. |

**Explicitly not claimed:** no chapter closes; F065's live proof has not occurred; F103/F104 remain OPEN and are not closed by publishing S3; F116 is not closed by the audit — the audit is its exit-condition *input*.

---

## J. Protected / shared-system impact

| Boundary | Exposure in this wave |
|---|---|
| **PB-01 Meetings** | **Reached, not opened.** F064/F113 fixed in CH-02 without modifying Meetings. A near-miss is on record: an order-dependent fix would have bounced guests into a login wall (DB-6). Every router change carries Meetings 97/97 against the W1-000 baseline. |
| **PB-02 realtime** | **Read-only.** W1-000 observes health; no repair performed. |
| **PB-05 identity** | **Approached, not crossed.** W1-F changes no consumer. Acting on the audit is W2. |
| **PB-06 / PB-09 session** | CH-02's **own chartered repair** (PBX-10) — not a foreign crossing. |
| **PB-07 identity media** | Untouched. The six SUPERSEDED identity assets are not authored, moved or deleted. |
| **PB-11 founder observation** | Applies to CH-02's live authentication behaviour change. |
| **PB-12 both repositories** | Enforced in W1-000, W1-A and W1-B closure evidence. |
| **RC-C5 gate (CH-13→CH-05)** | **Not reached.** Mechanically asserted: the derivation throws if any admitted unit enters either endpoint. |

---

## K. Remaining founder decisions, separated

### A — BLOCKS THE FIRST EXECUTABLE WAVE

1. **PD-2 structural disposition** (`CO-RC-C1-022`, recorded OPEN). Blocks W1-C/D/E — the entire CH-02 keystone. *Ratify or explicitly defer with the consequence accepted.*
2. **RC-C5 scope ratification for CH-11** — does the BIFURCATED ruling answer CH-11's recorded scope question? Blocks W1-X1 only. Stage-5's fail-closed default is *gated*.
3. **Individual chapter authorizations** for CH-01, CH-02, CH-03-audit-partition, CH-17-mechanism.

### B — BLOCKS ITS OWN CHAPTER OR WAVE, NOT THIS ONE

4. **AD-CON-5** — classification of the completed PB-02 / RC-C6 crossing. Blocks CH-04 entry.
5. **SU-5** — did RC-C6's "blocked until C2" discharge when RC-C2 closed 2026-08-16? No document says either way.
6. **CORS authorization** — *and, first, the capture*. Blocks the visual half of CH-03, in W2.
7. **Migration deployment under founder observation** — blocks CH-12; until it happens, CH-12's five-cohort reconciliation measures nothing.
8. **Checkpoint 7** (attention interaction direction) — required before any DR1 surface is retired in W2.
9. **CH-15 content policy freeze** — founder-authored; hard prerequisite of the F137 remediation.
10. **Real-device access** (iOS / Android / Windows MSIX) — long lead; blocks CH-16 and CH-04's device layer.

### C — GOVERNANCE / CLASSIFICATION, NOT CURRENTLY BLOCKING

11. **PD-1** Platform Administration disposition · 12. **SupportScreen** ownership (`CO-RC-C9-029`) · 13. **GAP-1** placement · 14. **multidimensional obligation state** schema · 15. the **68 `SizedBox.shrink()`** adjudication · 16. **PBCR conditions 7–8 formal classification** once W1-000 reports.

*Carried unchanged. None was silently resolved by this rebuild.*

---

## L. Deterministic reconciliation

**PASS ×3, plus the fail-closed fixture suite.**

| Suite | Result |
|---|---|
| `stage4-proof.mjs` (R1–R9) | **PASS** — 143 + 308 = 451, each owned exactly once |
| `validate-portfolio-v2.mjs` (17 invariants) | **PASS** |
| `validate-stage5.mjs` (18 invariants) | **PASS** — 52 dependencies still point at real targets; 15 protected crossings surfaced, **not authorised** |
| `fixtures-fail-closed.mjs` | **15/15** — the validators still fail on seeded corruption |

143/143 findings · 308/308 obligations · 451/451 units · 17/17 chapters. `charteredBy`, classification provenance (293 inference / 9 derivation / 6 ruling), founder rulings, Stage-0 evidence, F137, F139, RC-C10, the original-299 disposition, the nine ratified COs and the PBCR obligations are all preserved. **No state promoted. No gate weakened. No boundary crossed. No product behaviour changed.**

---

## M. Health of implicated shared/protected subsystems

Honest position: **the current health of the shared subsystems this wave touches is not established — establishing it is W1-000, which is why it is the first unit.**

| Subsystem | Recorded status | Gap |
|---|---|---|
| Meetings (PB-01) | 97/97 recorded historically | Not re-run against the current tree. W1-000 re-establishes the baseline. |
| Realtime transport (PB-02) | RC-A `509230a` + RC-B `dfc9027` present | Post-repair health never reported — this *is* the owed PBCR condition 8. |
| Router / navigation | 23 gates + literal ratchet exist | Current state unmeasured; 24 routes remain unclassified (fail-open). |
| Cross-repository (PB-12) | Suites exist in both repos | Never reported *together* for one closure — LANE-CONT's standing requirement. |
| R2 / storage | F138 (no authorization at the boundary) and F143 (10 aliasing pairs) stand | Unchanged. **CORS policy unreadable** — see §F. |

Reporting a green baseline here without running it would be exactly the failure this programme's doctrine forbids.

---

## N. Documentation and continuity updates made

- `FIRST_EXECUTABLE_WAVE_2026-08-18.md` — this checkpoint
- `05-execution/execution-graph-v2.json` — rebuilt graph, demotions, preserved gate, first-entry invariant
- `05-execution/first-wave-v2.json` — derived wave with per-unit criterion evidence
- `05-execution/ch04-posture-v2.json` — F006–F010 matrix and four-partition posture
- `05-execution/cors-current-state.json` — eight-item non-mutating capture
- `tools/rebuild-execution-graph.mjs` · `tools/derive-first-wave.mjs` · `tools/first-wave-attributes.json`

Owed on authorization, not before: repository `CURRENT_STATE` / `DECISIONS` / `HANDOFF` / `NEXT_WORK` updates in both repos — they should record an authorized wave, not a proposed one.

---

## O. Recommendation — **AUTHORIZE THE FIRST EXECUTABLE WAVE, in two parts**

The three adjudications that previously forced HOLD are all discharged: the cycle is gone from the declared graph, the first-entry conflict is resolved dimensionally, and F006–F010 no longer blocks CH-04's classification. The wave was re-derived rather than inherited, and Stage-5 W1 did not survive it.

### Exact bounded implementation authorization to issue

> **AUTHORIZED — PART 1 (immediate, no further decision required)**
> `W1-000` discharge of PBCR conditions 7 and 8 · `W1-A` CH-17 governance mechanism half · `W1-B` CH-01 foundation adoption and ratchets · `W1-F` CH-03 enumerated consumer audit (read-only).
> Bounded to: no protected-boundary crossing; no production, CORS, R2, migration or deployment action; no chapter closure; no finding or obligation state promoted without its stated completion evidence.
>
> **AUTHORIZED — PART 2 (on ratification of PD-2)**
> `W1-C` / `W1-D` / `W1-E` — the CH-02 keystone S1–S3.
> Additional bounds: F065's live refresh proof passes **first**; PB-11 founder observation of the authentication behaviour change; Meetings 97/97 attributable to one change at a time, against W1-000's baseline.
>
> **NOT AUTHORIZED**
> `W1-X1` CH-11 (pending RC-C5 scope ratification) · `W1-X2` CH-04 PHASE 1 · `W1-X3` CH-02 S4 · CORS · migrations · R2 · any protected-boundary crossing.

**The smallest decision that unlocks the largest part of the wave is PD-2** — one ratification releases the entire CH-02 keystone, which is the portfolio's highest fan-out unbuilt system.

**STOP.** Nothing above is executed.
