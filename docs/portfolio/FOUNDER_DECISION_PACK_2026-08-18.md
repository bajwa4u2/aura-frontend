# FOUNDER DECISION PACK — Stage-3 Closeout

**Status:** INVESTIGATIVE. No canonical mutation. **Stage 4 = NOT_STARTED / NOT_AUTHORIZED.**
**Date:** 2026-08-18 · **Stage 3:** COMPLETE + FROZEN (442/442, PASS)

Five unresolved items. Each dossier separates **explicit founder ruling · frozen charter · implementation
evidence · agent inference · later amendment · unresolved contradiction**, and states what is *unknown*.
Recommendations are labelled and carry no authority.

---

## DECISION 1 — RC-C5 HARD-GATE SCOPE

**1. Question requiring founder authority.** Does the C5 hard gate close **RC-C5 the chapter only**, or
does it also close the **§12 Rich Content stages** that cover substantially the same original scope?

**2. Canonical current state.** `NOT_RECORDED` as to scope. May not be inferred, weakened, removed,
reinterpreted or scheduled around.

**3. Exact source evidence.**

> **C5 HARD GATE (frozen transition rule):** "C5 remains CLOSED until C4 is implemented, locally certified,
> pushed as authorized, deployed, observed end-to-end on the LIVE site, live defects resolved, and founder
> declares C4 certified/closed. **C4 LOCAL CERTIFICATION != C5 AUTHORIZATION.**"
> — `DECISIONS.md:382-385`, frozen **2026-08-16**

Dependency graph **as actually recorded** (`roadmap:273,275,308,312,511`):

```
RC-C5 dependsOn : RC-C0, RC-C1, RC-C2, RC-C3        ← NOT RC-C4
RC-C5 parallelWith : RC-C4, RC-C6
RC-C5 unlocks   : RC-C7, RC-C9
RC-C4 parallelWith : RC-C5, RC-C6 ; RC-C4 "hardGateIssued" carries the same text
```

**4. Chronology — decisive.**

| Date | Event |
|---|---|
| — | Roadmap records RC-C4 and RC-C5 as **parallel siblings**; RC-C5 depends on C0–C3 only |
| **2026-08-16** | **C5 hard gate frozen** (`DECISIONS.md:382-385`) |
| **2026-08-17** | **§12 Rich Content & Interaction frozen** — governing acquisition/intake, attachment/upload primitives, drag/drop, paste, link previews, delivery |

**5. What is FACT.**
- The gate text is explicit, frozen, and names **"C5"**.
- The declared dependency graph makes C4 and C5 **parallel**, not sequential. The gate is therefore a
  separately-issued **transition rule**, not a technical dependency — both records are true simultaneously.
- The gate **predates §12 by one day**. It could not have scoped a contract that did not yet exist.
- Stage 0 recorded the overlap explicitly as `OVERLAPPING_WORK_OUTSIDE_THE_CHAPTER` and did not resolve it.
- A **namespace hazard** is recorded: §12's dependency line "…→ GOVERNED DELIVERY (C5) →…" is **RIC-C5**,
  not RC-C5. Equating them produces a confidently wrong mapping.
- A second overlap: the **Conversation Completion Register** (frozen 2026-08-16) makes media/attachments a
  REQUIRED attachment of canonical Conversation *while RC-C5 is hard-gated closed*.

**6. What is INFERENCE.** Agent B offered six readings (still-valid coupling · deployment-discipline gate ·
obsolete sequencing · correctly-held blocker · namespace risk · implementation-vs-certification). All are
inference. None is authority.

**7. Options.**

- **(A) Chapter-only.** The gate closes RC-C5's chapter; §12/RIC stages proceed under their own contract.
- **(B) Scope-wide.** The gate closes the *capability*, so §12 stages covering RC-C5 scope are also gated.
- **(C) Explicitly bifurcated.** The gate binds composer/attachment **surfaces** (RC-C5) but not content
  **truth/retention** stages (RIC-C1/C2), with the split written down.

**8. Consequences.**
**(A)** unblocks CH-13 and CH-11/CH-12 sequencing; risk — composition may be rebuilt on surfaces the gate
was written to protect from premature construction. **(B)** halts §12 continuation including work already
delivered under RIC-C1/C2; maximally conservative, and retroactively places completed work behind a gate.
**(C)** matches the observed evidence most closely but is the one option the record does not currently state.

**9. Recommendation.** *Evidence does not resolve the scope; I do not recommend a scope.* The one thing
evidence does establish is that the gate is a **deployment-discipline transition rule**, not a technical
dependency — the graph says parallel. That distinction is fact and should survive whichever option is chosen.

**10. Founder ruling requested.**
> Does the 2026-08-16 C5 hard gate bind **only RC-C5's chapter surfaces**, or also the **§12 Rich Content
> stages** covering the same original scope — and if bifurcated, where exactly does the line fall?

---

## DECISION 2 — RC-C10 COMPLETED-SET SIZE

**1. Question.** Are the **3 additional** COMPLETED_OR_SUPERSEDED classifications accepted, or should
RC-C10's completed set be exactly the **2** you evidenced?

**2. Canonical current state.** RC-C10 = ACTIVE / STRUCTURALLY PARTIAL / NOT CERTIFIED. Classification
inferred 5 of 21 as completed-or-superseded.

**3–6. The five, separated by evidence class.**

**FOUNDER-EVIDENCED (2) — not in dispute**

| CO | Obligation | Evidence | Class established |
|---|---|---|---|
| **CO-RC-C10-013** | PUBLIC_STAGE consumption — *"declared but unconsumed"* | `d3981e5` production consumption; Stage 0 `SUPERSEDED_BACKEND_STATE_ROW` | **SUPERSEDED** (state row overtaken) · confidence HIGH |
| **CO-RC-C10-014** | Go-live authority — *"missing"* | `fb9bfa1`, `88179ee` | **SUPERSEDED** · HIGH. *Preserved tension:* CO-RC-C10-010 still records go-live authority formalization as backend-missing |

**CLASSIFIER-INFERRED (3) — your decision**

| CO | Obligation | What the evidence establishes | Argument against |
|---|---|---|---|
| **CO-RC-C10-001** | FD-5 — Live is a governed state of an owning Thread/Space; not a standalone product | **FOUNDER DECIDED** only. A finished *ruling*, not construction | FD-5 is a *constraint on all remaining Live work*. Marking it complete may read as the constraint being discharged |
| **CO-RC-C10-002** | Backend discovery correction — earlier "no speaker/audience model" claim WITHDRAWN | **FOUNDER DECIDED** + its embedded state clause superseded by later production consumption | Its value is as a live correction to the record; "complete" is ambiguous for a correction |
| **CO-RC-C10-003** | 2026-08-17 origination correction — Live is something an interaction *becomes* | **FOUNDER DECIDED** + origination **IMPLEMENTED** (single door, backend fence live-verified 400/404) | Implemented ≠ **VALIDATED** ≠ **LIVE CERTIFIED**. Earlier Live proofs were *invalidated* by this correction |

**Dimensions deliberately not normalised:** IMPLEMENTED · STRUCTURALLY COMPLETE · VALIDATED · LIVE CERTIFIED
· SUPERSEDED · FOUNDER DECIDED. The three disputed rows are **FOUNDER DECIDED**; only 003 additionally carries
IMPLEMENTED, and **none** carries VALIDATED or LIVE CERTIFIED.

**7–8. Options and consequence.**
- **(A) Accept 5.** Consistent with RC-C0…C5, where 33 of 36 FROZEN_OUTCOME rows were classed completed. Risk:
  a frozen *constraint* reads as discharged.
- **(B) Restrict to 2.** The 3 become VALIDATION_OR_GATE_ONLY. Distribution shifts; RC-C0…C5 then uses a
  different rule from RC-C6…C11 — an internal inconsistency of 33 rows.
- **(C) Accept 5 but add a `FROZEN_DECISION_COMPLETE` distinction** separating "the decision is made" from
  "the obligation it imposes is discharged." Schema change; applies to ~45 rows axis-wide.

**9. Recommendation.** **(C)**, weakly. The classifier applied the existing rule consistently, so (B) would
make the axis internally inconsistent — but the objection to (A) is real: FD-5 is a *live constraint*, and
"completed" is a poor word for it. (C) preserves both truths. **Note:** (C) is a schema change and must not
be adopted silently.

**10. Founder ruling requested.**
> For **each** of CO-RC-C10-001, -002, -003: is COMPLETED_OR_SUPERSEDED accepted, or should it be
> VALIDATION_OR_GATE_ONLY / a new frozen-decision class?

---

## DECISION 3 — CO-RC-C7-015 CONTRADICTION

**1. Question.** Do the two frozen records actually conflict — and if not, what is the reconciling wording?

**2. Canonical current state.** `UNKNOWN` / confidence LOW. Untouched.

**3. Exact source evidence.**

> **Charter (CO-RC-C7-015, `CHARTERED_SCOPE/build`):** *"Correspondence as a distinct governed communication
> form — **sharing infrastructure but not semantics**"*

> **Amendment, founder-approved and frozen 2026-08-16:** *"C7 = INSTITUTIONAL CONVERSATION & DESK"* … *"C7
> does **NOT recreate Correspondence as a product**"* — `DECISIONS.md:355-361`

Adjacent frozen row **CO-RC-C7-002**: *"Correspondence = one canonical product meaning; C7 owns the eventual
path/module rename or convergence — **the semantic decision is NOT reopened there**."*

**4. Chronology.** Charter (original) → **2026-08-16 amendment** → Agent D's RC-C7 remaining list **omits**
this build row.

**5. What is FACT.**
- The charter phrase is **"sharing infrastructure but not semantics"** — it is explicitly about *form and
  semantics*, not about shipping a product surface.
- The amendment's prohibition is explicitly about a **product**.
- CO-RC-C7-002 independently states Correspondence retains *one canonical product meaning* and that the
  **semantic decision is not reopened** — i.e. the semantics survive the amendment.

**6. What is INFERENCE.** That the omission from Agent D's remaining list implies supersession. That is an
absence, not a ruling.

**7. Options.**
- **(A) Compatible.** "Correspondence remains a distinct governed communication **form/capability**, while C7
  does not create a separate Correspondence **product surface**." — tested against source and **supported**:
  the charter says *form*, the amendment forbids a *product*, and CO-RC-C7-002 preserves the semantics.
- **(B) Incompatible.** The amendment retired the build obligation; the row is SUPERSEDED.

**8. Consequence.** **(A)** CO-RC-C7-015 becomes classifiable (likely OUTSTANDING_CONSTRUCTION or
VALIDATION_OR_GATE_ONLY) and the umbrella rename/migration obligation stays coherent. **(B)** the row is
retired and Correspondence's distinct governed form loses its only build obligation — while CO-RC-C7-002 still
asserts the semantics, creating a *new* inconsistency.

**9. Recommendation.** **(A).** This is the one of the five where evidence genuinely favours a reading: the
two records use *different nouns* (**form/capability** vs **product**), and a third frozen row explicitly
preserves the semantics. Reading them as contradictory requires treating "form" and "product" as synonyms,
which the charter's own qualifier — *"sharing infrastructure but not semantics"* — contradicts.

**10. Founder ruling requested.**
> Confirm: *"Correspondence remains a distinct governed communication form; C7 does not create a separate
> Correspondence product surface"* — and if confirmed, state the class CO-RC-C7-015 should carry.

---

## DECISION 4 — PB-02 / RC-C6 CROSSING

**Per the task's own instruction, this is presented as analysis, not yet as a founder decision.**

**2. Canonical current state.** Declined by five consecutive artifacts. Neither classified nor absolved.

**3. PB-02, exactly.**

> **Domain:** REALTIME (transport, media service, session lifecycle)
> **Protects:** realtime transport, media service and event parser · reconnect/orphan recovery
> (`realtime_reconciliation_controller`, orphaned-session handling) · session continuity across navigation ·
> the distinct product semantics of each realtime context · 1:1 calls, group A/V and screenshare as
> **already LIVE_CERTIFIED** (F006–F010, F048, F049)
> **Doctrine:** FD-3 *"Shared realtime infrastructure does NOT imply shared product semantics"* · roadmap C6
> *"PRESERVE — do not touch"* · FD-4 permits **presentation convergence only, slice-by-slice, with regression
> after each slice**

**Answering the six questions.**

1. **What would cross?** Not a planned operation — an **already-completed** one. The RC-A repair (controller
   disposing shared socket/media singletons on tokenStore-watch rebuild, `509230a`) and RC-B (root-overlay
   `_joining` latch) touched the protected layer.
2. **Why would RC-C6 need it?** RC-C6's chartered work is *presentation convergence* — FD-4 already permits
   that, slice-by-slice. It does **not** require touching transport/lifecycle.
3. **Is the crossing necessary?** **On the evidence, no.** The chartered work is permitted without it. The
   crossing that occurred was **defect repair**, not chapter execution.
4. **Alternative architecture?** Yes, and it is the chartered one: presentation convergence slice-by-slice
   with regression after each slice, leaving transport/media/parser untouched.
5. **What is at risk?** Five LIVE_CERTIFIED capabilities (1:1 calls, group audio, group video, screenshare,
   session continuity) plus the two recorded root causes that must not regress.
6. **What remains unresolved?** Whether the **already-completed** RC-A/RC-B crossing was authorised. Five
   artifacts declined to classify it — the record shows *no governed authorization* and also *no censure*.

**5/6. Fact vs inference.** FACT: PB-02's contents, FD-4's slice-by-slice permission, that RC-A/RC-B touched
the layer, that no governed authorization exists. INFERENCE: that the repairs were therefore unauthorised —
they may have been emergency defect work outside chapter framing, which is a *different* category.

**7–8. Options.** **(A) Retroactively authorise** the completed crossing as defect repair, with regression
evidence required → clears the ambiguity, sets a precedent. **(B) Classify as an unauthorised crossing**
requiring regression proof before further work in that layer → strictest; may mislabel legitimate emergency
repair. **(C) Rule that defect repair in a protected layer is categorically distinct from chapter execution**,
and define the standing evidence requirement → general, and prevents the sixth artifact from declining again.

**9. Recommendation.** **(C).** Five artifacts declining the same question is itself the finding: the record
has **no category** for "protected-layer repair that is not chapter execution." Adjudicating this instance
without creating the category guarantees a sixth decline.

**10. Founder ruling requested.**
> Is defect repair inside a protected realtime layer categorically distinct from chapter execution — and what
> standing evidence does such a repair require? Then: is the completed RC-A/RC-B crossing accepted under it?

---

## DECISION 5 — RC-C7 MISSING CHECKPOINT OBLIGATION

**1. Question.** Should a CO be created for the Correspondence architectural convergence verdict — changing
the canonical total **299 → 300**?

**2. Canonical current state.** No obligation among the 299 represents it. RC-C7 contributes **zero**
FOUNDER_ACTION_ONLY rows.

**3. Exact source evidence.**

> *"The Correspondence architectural convergence verdict — the chapter's **named founder checkpoint** — has
> **no recorded outcome**."* — `FINAL_FRONTEND_RECONSTRUCTION_ROADMAP.md:395`

**4. Why deterministic extraction omitted it — established mechanically.** The extractor reads exactly three
fields: `keyFrozenOutcomes`, `explicitlyRemainingObligations`, `originalScope.*`. This checkpoint was recorded
by Stage 0 in **`contradictionsOrGaps`** — a fourth field, not an extraction source. Only **RC-C10** carries
an `openCheckpoints` scope array (→ CO-RC-C10-019/020/021, the only 3 checkpoint-derived COs axis-wide).
**This is a structural extraction gap, not a transcription error** — any chapter recording a checkpoint as a
gap rather than as scope is invisible to the CO axis.

**5. Was a verdict ever recorded?** No. Searched: no outcome in any governed artifact.

**6. Does an existing CO already cover it?** **No — but one is adjacent.** `CO-RC-C7-002` states *"C7 owns the
eventual path/module rename or convergence — the semantic decision is NOT reopened there."* That is the
**execution** of convergence, explicitly *excluding* the semantic decision. The checkpoint is the **verdict**
itself. Creating a CO would **not** duplicate CO-RC-C7-002; it would supply the decision that -002 presumes.

**7–8. Options.** **(A) Create `CO-RC-C7-025`** → 299→300, accounting and fixtures updated. **(B) Do not
create; record as a known extraction gap** → 299 preserved, but a named founder checkpoint stays invisible to
the axis built to prevent exactly that. **(C) Create it *and* re-run extraction against `contradictionsOrGaps`
axis-wide** → may surface further omissions; total unknown until run.

**Proposed CO if approved:**

```
id                CO-RC-C7-025
charteredBy       RC-C7
obligationType    REMAINING_OBLIGATION   (scopeArea: openCheckpoints)
obligation        "Correspondence architectural convergence verdict — the chapter's named
                   founder checkpoint. NO RECORDED OUTCOME."
provenance        FINAL_FRONTEND_RECONSTRUCTION_ROADMAP.md:395
obligationClass   FOUNDER_ACTION_ONLY
currentState      NOT_RECORDED_AT_OBLIGATION_LEVEL
```

**Artifacts requiring update if approved:** `chartered-obligation-register.json` (299→300) ·
`co-input-dispositions.json` (+1 input, disposition PROMOTED) · `ownership-co-b.json` (executable owner) ·
`classification-co-b.json` · `validate-stage3.mjs` expected totals · `validate-stage2.mjs` 299-invariant ·
`STAGE0_RATIFIED_BASELINE.md` · this pack.

**9. Recommendation.** **(C).** (A) fixes one symptom; the *mechanism* — checkpoints recorded as gaps being
invisible to extraction — would remain, and this axis exists precisely to stop chartered work disappearing.
Re-running is cheap and deterministic.

**10. Founder ruling requested.**
> Create `CO-RC-C7-025` (299→300)? And should extraction additionally read `contradictionsOrGaps` axis-wide,
> accepting that the total may rise further?

---

## PROVENANCE NOTE — the 135 B-range obligations

All 135 RC-C6…RC-C11 obligations carry `currentState: NOT_RECORDED_AT_OBLIGATION_LEVEL` and
`implementationEvidence: NOT_RECORDED`. **Their Stage-3 classifications are inferred**, including the
HIGH-confidence ones (72 HIGH / 59 MEDIUM / 4 LOW).

**Is the explicit-vs-inferred distinction mechanically preserved? PARTIALLY — proven, with a deficiency.**

**Preserved:** every obligation retains `currentState: NOT_RECORDED_AT_OBLIGATION_LEVEL` with the standing
note *"chapter-level status must not be read as this obligation being satisfied"*; classification lives in a
**separate field** (`obligationClass`) in a **separate artifact** (`classification-co-b.json`), each row
carrying `classificationRationale`, `evidenceRefs` and `classificationConfidence`.

**Deficiency for Stage-4 planning:** `obligationClass` itself carries **no provenance-kind flag**. A reader of
the register alone cannot distinguish an obligationClass derived from a *recorded state* (RC-C0…C5, where some
rows had evidence) from one *inferred from charter text* (all 135 B-range). The separation currently depends
on knowing which artifact produced the row. **Recommended for Stage 4:** a `classificationBasis` field —
`RECORDED_STATE` | `INFERRED_FROM_CHARTER` | `FOUNDER_EVIDENCED`. **Not applied here** — this task forbids
mutating the 135 rows for presentation.

---

## ACCOUNTING IMPACT

| | Findings | Obligations | Total |
|---|--:|--:|--:|
| **Current canonical** | 143 | **299** | **442** |
| Decisions 1–4 (any outcome) | 143 | 299 | 442 — **no arithmetic change** |
| Decision 5, option A or C | 143 | **300** | **443** |
| Decision 5, option C with further extraction | 143 | **≥300** | **≥443** — unknown until re-run |

Decisions 1–4 change **classification, interpretation or authorisation** — never the unit count. **Only
Decision 5 can alter accounting.**

---

## FOUNDER DECISIONS REQUIRED

1. **RC-C5 gate scope** — chapter-only, scope-wide, or bifurcated (and where).
2. **RC-C10 completed set** — accept 5, restrict to 2, or add a frozen-decision class; **per CO** for -001/-002/-003.
3. **CO-RC-C7-015** — confirm the form-vs-product reconciliation, and the resulting class.
4. **PB-02** — is protected-layer defect repair categorically distinct from chapter execution, and is the
   completed RC-A/RC-B crossing accepted under that rule?
5. **CO-RC-C7-025** — create it (299→300)? And extend extraction to `contradictionsOrGaps` axis-wide?

---

**Stage 0** COMPLETE + FOUNDER_RATIFIED · **Stage 1** COMPLETE · **Stage 2** COMPLETE + AMENDMENT PASS ·
**Stage 3** COMPLETE + FROZEN · **Founder Decision Pack** INVESTIGATIVE · **Stage 4** NOT_STARTED / NOT_AUTHORIZED
