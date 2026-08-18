# PRE-EXECUTION ADJUDICATION CHECKPOINT

**Status:** INVESTIGATIVE + one approved factual correction. **No implementation. Wave 1 HOLD. No Stage 6.**
**Date:** 2026-08-18 · **Baseline:** 143 findings + 308 obligations = **451 units** · 17 chapters

---

## A. 299 to 308 correction

Only **one** occurrence was operative: CH-17's `certificationRequirements` closure rule. Everything else was
either Stage-3 *history* or Stage-5 *correctly reporting the staleness* — neither was touched, because those
reports are the evidence the defect was caught.

| Artifact | Action |
|---|---|
| `05-execution/index-chapters.json` | **CORRECTED IN PLACE** — operative closure rule now reads 308 |
| `03-synthesis/chapter-architecture.json` | **SUPERSEDED, NOT EDITED** — frozen founder-ratified Stage-3 artifact; the four-layer doctrine says rulings apply forward and history is not rewritten to look cleaner |
| Stage-5 contradiction reports | **PRESERVED** — S5C-CON-2 / S5D-CON-01 remain as the detection record |

**Reconciliation after correction: PASS x3** — Stage-4 proof, portfolio-v2 and Stage-5 all green at 451.
No obligation disappeared, merged, renumbered or lost provenance.

---

## B. The three cycle edges

`CH-05 -> CH-06 -> CH-13 -> CH-05`

| Edge | Canonical requirement | Class | Grade / Confidence | What is actually needed |
|---|---|---|---|---|
| **CH-05 -> CH-06** | "owning-domain clearing semantics for messages" — where read-truth is committed | *claimed* construction | ANALYTICAL_INFERENCE · **MEDIUM** | Candidate: a **semantic contract only**, resolvable from the frozen Conversation canon via PB-12 — not CH-06 construction |
| **CH-06 -> CH-13** | media/attachments row of the Conversation Completion Register | CERTIFICATION | ANALYTICAL_INFERENCE · **LOW-MEDIUM** | Candidate: a **final-certification** dependency, not construction-start. Keystone K8 (canonical Conversation) does not require it |
| **CH-13 -> CH-05** | **RC-C5 frozen hard gate** — opens only on founder-declared C4 live closure (`DECISIONS.md:382-385`) | **FOUNDER GATE** | **STRONG · HIGH** | Whole gate. **May not be weakened** |

**Chronology:** the gate froze 2026-08-16 and is the only arc that is not inference. The two candidate
re-attachments are this analysis's reading and are recorded nowhere. No later ruling narrowed either.

## C. Cycle verdict — **FOUNDER_DECISION_REQUIRED**

The proposed decomposition would open the cycle as
`CH-05 construction -> CH-06 construction -> [C4 live closure declared] -> CH-13 -> CH-06 final certification`.

**I am not accepting it.** Both non-frozen re-attachments rest on MEDIUM and LOW-MEDIUM inference, and
accepting them *because* they make the graph acyclic is exactly the failure this adjudication exists to
prevent. Agent E separately records the gate as already "routed around in the operative tables, not removed",
which is the live risk in the opposite direction.

**Irreducible alternatives — choose one, do not blend:**

1. **Ratify both re-attachments** (semantic contract + certification phase) — cycle opens, three chapters become enterable.
2. **Ratify only CH-06 -> CH-13** as certification-phase — cycle opens more conservatively; CH-05 still waits on a CH-06 semantic answer.
3. **Reject both** — the cycle stands: **CH-05, CH-06 and CH-13 cannot begin**, and the first wave must exclude all three.

---

## D. First-entry conflict — the exact evidence pair

| Record | Operative instruction | Authority type |
|---|---|---|
| **Founder stop-order (PB-02)** | `realtime transport -> identity/avatar -> refresh-continuity -> video/screenshare/Live` | Emergency **repair/certification** order over the protected transport layer — it is what produced the RC-A and RC-B repairs |
| **Declared chapter graph** | CH-04 `dependsOn` CH-03 **and** CH-02 | **Construction** dependency for tiles and rosters that consume identity |

These are the **exact reverse** of each other in their first three terms.

## E. First-entry verdict — **FOUNDER_DECISION_REQUIRED**

Tested explicitly against the RC-C5 pattern (two records operating on different dimensions). The
reconciliation *is plausible*: a repair order over a protected layer is a different dimension from a
construction order over consuming surfaces.

**But unlike RC-C5, that reading is recorded nowhere.** RC-C5 had two dated artifacts whose scopes were each
independently evidenced. Here the reconciliation exists only as inference, and the task forbids forcing that
interpretation where evidence does not support it.

**Smallest decision actually needed:** *Does the PB-02 stop-order govern repair sequencing only — leaving
CH-02/CH-03 to enter before CH-04 by construction dependency — or does it also govern construction entry,
making CH-04 first?*

---

## F. F006-F010 five-dimensional matrix

**A distinction that changes the reading.** `provenanceStrength: WEAK` is a **mention-count** metric from
Stage 0's deterministic extractor (two or fewer corpus mentions). **It is not an assessment of evidence
quality.** All five carry *founder direct observation* — a strong evidence *type*, recorded once.

| Finding | IMPLEMENTATION | LOCAL_VALIDATION | CERTIFICATION | LIVE_PRODUCTION | Certification evidence |
|---|---|---|---|---|---|
| F006 1:1 audio | NOT_PROVEN¹ | NOT_APPLICABLE | **PROVEN** | PROVEN | founder "connected, been in voice"; server audioState ON both sides |
| F007 Group audio | NOT_PROVEN¹ | NOT_APPLICABLE | **PROVEN** | PROVEN | 4-party; founder "4 of us in call which is amazing" |
| F008 Video call | NOT_PROVEN¹ | NOT_APPLICABLE | **PROVEN** | PROVEN | 4-party video; real frames both directions |
| F009 Grow 1:1 to group | NOT_PROVEN¹ | NOT_APPLICABLE | **PROVEN** | PROVEN | Reviewer added live; invitation accepted; roster 4 |
| F010 Screen share | NOT_PROVEN¹ | NOT_APPLICABLE | **PROVEN** | PROVEN | founder "screenshare working i have validated" |

¹ `implementationEvidenceRefs: NOT_RECORDED` on all five. Implementation is *implied* by live observation —
you cannot be in a four-party video call without it — but that implication is inference and is **not promoted**.

**The contradiction, stated exactly:** the frozen Conversation Completion Register (2026-08-16) names audio
call, video call, screen sharing and media/attachments as **UNRESOLVED required contextual attachments of
canonical Conversation**.

**Candidate reconciliation — presented, not adopted.** These may be **different objects**: the certifications
are of the capabilities *in their existing call surface*; the Register requires them *as attachments of the
canonical Conversation*, which did not exist when they were observed. Both records would then be true, and
neither needs to be wrong. This mirrors the RC-C5 dimensional pattern — and, like the first-entry case, it is
recorded nowhere, so it is offered as the candidate rather than selected.

## G. Consequence for CH-04

- **Reading 1 (different objects):** CH-04 is **CERTIFICATION_REQUIRED** for these five — the capabilities
  exist and are founder-observed; what is owed is certification *within canonical Conversation*.
- **Reading 2 (capabilities themselves unresolved):** CH-04 becomes **CONSTRUCTION_REQUIRED**, twelve
  LIVE_CERTIFIED findings contract to an unknown number, and GR-12/GR-16/GR-17 slip behind it.

Both facts preserved; no state promoted. This is the highest-leverage single uncertainty in the portfolio.

---

## H. CORS eight-item consequence boundary

| # | Item | Finding |
|---|---|---|
| 1 | Configuration changed | R2 bucket **CORS policy** (`PutBucketCors`); JSON already prepared |
| 2 | Environment | **Production** object storage |
| 3 | Runtime/product boundary crossed | **YES** — the web delivery path for all stored media |
| 4 | Expected user-visible effect | Avatars and images render on web; unblocks visual completion of **F051, F052, F056, WG010** |
| 5 | Security implications | CORS governs **cross-origin read access** to a bucket that **F138 proves performs no authorization at its boundary**. An over-broad origin list widens exposure of objects the storage layer does not gate |
| 6 | Targeted validation | VD-019 and VD-026 — SINGLE_AUTHORIZED_BROWSER render proof, plus explicit confirmation that no unintended origin gained read access |
| 7 | Rollback path | Re-apply the prior CORS document. **NOT_RECORDED** whether the current policy has been captured for restore — it must be captured *before* any change |
| 8 | Shared/protected subsystem crossed | **YES** — the media/storage boundary, and precisely the surface F138 flagged |

### Classification: **PROTECTED_OR_SHARED_BOUNDARY_REQUIRES_AUTHORIZATION**

Stage 5 described this as "zero engineering, the earliest real user-visible improvement available anywhere."
That is true about **effort** and false about **consequence**. It mutates production configuration on the one
boundary already proven to perform no authorization, and its rollback document is not recorded. **Not executed.**

---

## I. Canonical / documentary corrections made

1. `index-chapters.json` CH-17 closure rule: 299 to 308, annotated with the ruling and date.
2. `stage2-amendment-rulings.json`: `CH17_POPULATION_CORRECTION` recorded, including what was **superseded
   rather than edited** and what was **deliberately left unchanged** (history, and the contradiction reports).
3. Nothing else. No state promoted, no gate weakened, no boundary crossed, no implementation performed.

## J. Deterministic reconciliation

**PASS on all three validators** — Stage-4 proof (R1-R9), portfolio-v2 (17 invariants), Stage-5 (18
invariants). 143/143 findings, 308/308 obligations, 451/451 units, 17/17 chapters, every unit exactly one
owner, `charteredBy` preserved, founder rulings intact, conflicts unadjudicated.

## K. Remaining founder decisions

1. **Cycle** — ratify both re-attachments, only the certification one, or neither.
2. **First entry** — does the PB-02 stop-order govern repair sequencing only, or construction entry too?
3. **F006-F010** — are the Register rows a *different object* (certification owed) or the capabilities
   themselves (construction owed)?
4. **CORS** — authorize under the eight-item boundary, with the rollback document captured first.
5. Carried unchanged: GAP-1 placement · PD-1 · PD-2 · SupportScreen · multidimensional obligation state ·
   PBCR conditions 7-8.

## L. First executable wave

**Not proposed.** The evidence does not yet make it deterministic — see M.

## M. Recommendation: **HOLD EXECUTION**

Three of the four adjudications returned FOUNDER_DECISION_REQUIRED, and each one changes what the first wave
*is*: the cycle decides whether three chapters can start at all; the stop-order decides which chapter enters
first; F006-F010 decides whether the first realtime grouping is certification or construction work.

Declaring a first wave now would encode an inference as an execution assumption — the precise failure this
workflow's own doctrine forbids.

**LANE-W0 remains available** under Founder Ruling 2 for founder decisions, evidence gathering and
non-mutating governance preparation — **excluding CORS**, which this checkpoint classifies as requiring
separate authorization.
