# AURA PORTFOLIO GOVERNANCE DOCTRINE

**Status:** FOUNDER-RATIFIED · 2026-08-18
**Scope:** governs the Aura Dynamic Reconstruction Workflow and the implementation portfolio it produces.
**Companion artifacts:** `STAGE0_RATIFIED_BASELINE.md` · `AURA_DYNAMIC_RECONSTRUCTION_WORKFLOW.md` ·
`run/stage0-2026-08-18/02-reconcile/stage2-amendment-rulings.json`

---

## 1. THE AUTHORITY-ADMISSION DOCTRINE *(frozen)*

> A new executable authority may be admitted **after** a reconstruction chapter has been frozen
> **only when cross-axis evidence demonstrates a systemic responsibility that cannot be safely or
> coherently owned by an existing authority.**

Such admission:

- **does not** reopen or rewrite the historical RC charter;
- **must** preserve the originating charter evidence;
- **must** identify the systemic responsibility and the evidence justifying admission;
- **must** demonstrate why distribution into existing authorities would recreate fragmentation,
  duplication, contradictory truth, or another known failure mode;
- **must** preserve protected boundaries;
- **must** be founder-ratified before becoming canonical.

**This is not a convenience mechanism for creating chapters.** The burden is evidence that
distribution *reproduces a known failure*, not that a new chapter would be tidier.

### 1.1 First application — CH-02 Continuity & Destination Authority *(founder-approved)*

| Test | Evidence |
|---|---|
| Systemic responsibility | 16 findings across six unrelated surfaces reduce to **two shared causes**: session-state establishment written at 2 of N call sites (F065), and route classification kept as a hand-maintained fail-OPEN allowlist (F069) |
| Cannot be owned by an existing authority | Three RC chapters touch continuity as **PRESERVATION** (C1 session handling, C3 session continuity, C5 drafts) and one as a platform build item (C9). *Preserving a thing is an instruction not to reconstruct it* — so nothing charters its construction |
| Why distribution fails | Tested and rejected: each surface chapter would build **its own destination reconstruction** — precisely the temporary architecture the chapter test forbids, and the observed cause of the 16 findings |
| Chronology | The roadmap froze 2026-08-15; REFRESH IS NOT NAVIGATION froze 2026-08-17. The axis **could not** have chartered it |
| Charter evidence preserved | Yes — Stage-2 correction CORR-1 adopted: **F069 IS attributed to RC-C3** |
| Protected boundaries | Preserved. F064 (single-browser) and F113 (multi-party Meetings, VD-031 UNKNOWN) keep **separate proof burdens** |

**F065 is preserved as an ordering constraint, not a merge.** Its live refresh proof is the
chapter's first gate, gating F059/F061/F062/F063/F064/F103/F104.

**Recorded outstanding:** admitting CH-02 required an explicit founder act because RC-C0 had
already closed, and **no general admission mechanism existed**. This doctrine is that mechanism.

---

## 2. RC-C5 HARD GATE — NON-INFERENCE RULING *(frozen)*

Canonical status: **`NOT_RECORDED`** as to the unresolved scope question Stage 3 identified —
namely whether the gate extends to the §12 Rich Content stages or only to the composer surfaces.

**Do not infer, weaken, remove, reinterpret, or schedule around it.**

Before any future portfolio ordering depends on an interpretation of this gate, the **actual
frozen dependency/gate evidence must be recovered and presented**.

> No analytical consensus, chapter convenience, dependency pressure, or implementation preference
> may substitute for that evidence or for founder adjudication.

Stage 4 receives **no authority** to resolve RC-C5.

---

## 3. WORKFLOW SAFETY INVARIANTS *(permanent)*

Both were discovered the hard way during Stage 3 and are now general requirements, not incident patches.

### 3.1 Dependency halt guard

> If a downstream workflow stage depends on an upstream agent artifact, downstream agents **MUST
> NOT launch** unless the required upstream artifact exists and passes its prerequisite validation.

**Origin:** a `529 Overloaded` run launched all four Stage-3 agents even though the architect had
failed. Three assigners would have distributed **442 canonical units against a chapter set that did
not exist** — producing either invented chapters or a wall of `UNASSIGNABLE`.

**Generalised form:** every stage declares its upstream prerequisites; the orchestrator halts and
returns a `HALT_*` reason rather than proceeding on partial evidence. **A total failure is cheap.
A partial failure that looks complete is the expensive one.**

### 3.2 Validator fail-closedness

> A validator must **not** interpret absence as satisfaction.

Missing canonical values, missing ownership, missing classifications, malformed rows, unexpected
schema drift, or an inability to establish the required invariant **must FAIL** reconciliation —
unless the governing schema **explicitly defines an unresolved state**.

**Origin:** the first Stage-3 reconciliation returned PASS while **135 obligations carried no owning
chapter at all**. The check read one key name and *skipped* `undefined`, so absence was silently
counted as ownership. The ownership genuinely existed under a different key — but the validator
could not have known that, and reported success either way.

**Corollaries:**
- Tri-state fields must distinguish **true / false / unresolved**. Absence is never `false`.
- Schema drift between agents is a **reportable event**, not a silent normalisation.
- A red validator is **evidence**. Never weaken a validator, change accounting semantics, or
  reinterpret canonical evidence to obtain PASS.

---

## 4. STANDING BASELINE PROTECTIONS

Carried forward and not reopened: **F097 issued** · **WG001–WG017 issued, WG018 reserved/unissued**
· **F064 and F113 remain separate canonical findings** · **F139 = STRUCTURALLY_CLOSED_NOT_LIVE_CERTIFIED**
with structural and production-certification dimensions preserved separately · **F137 =
ZERO_COVERAGE_SECURITY_GAP**, owned by CH-12 by responsibility boundary and never relocated by name
similarity · **F043 / F051 / F122 remain unresolved canonical conflicts** · **RC-C10 = ACTIVE /
STRUCTURALLY PARTIAL / NOT CERTIFIED** with both exit gates intact · **self-contamination protection
active** · historical and superseded analytical artifacts remain **evidence, not current authority**.

## 5. THE FOUR LAYERS — never collapsed

```
historical charter   RC-C0..RC-C11 — what Aura undertook
analytical evidence  Stage 0-3 agent artifacts — ANALYTICAL_PROPOSAL, never authority
founder rulings      explicit, dated, superseding forward only
canonical portfolio  the current ratified state
```

A founder ruling applies **forward**. Artifacts produced before it are recorded as
`SUPERSEDED_BY_FOUNDER_RULING` and **retained** — never silently amended, never treated as
misconduct for failing to anticipate a decision that did not yet exist.

---

## 6. RC-C5 HARD GATE — **BIFURCATED** *(founder ruling, 2026-08-18; supersedes the NOT_RECORDED status in §2)*

> RC-C5's frozen hard gate governs **(1)** the RC-C5 chapter/deployment transition, and **(2)** authorities,
> conditions or dependencies **explicitly within the scope of that gate when it was frozen**.
>
> It does **NOT** retroactively become a platform-wide gate over systems, contracts or authorities frozen
> **later** merely because they now exist downstream in the reconstruction portfolio.

A later independently frozen system is governed by **its own explicit gates**, or by RC-C5 **only where an
explicit dependency on RC-C5 exists**.

**Historical facts preserved:** gate frozen **2026-08-16** · §12 frozen **2026-08-17** · RC-C4 and RC-C5 are
**parallel** in the recorded graph · RC-C5 depends on **C0–C3**, not C4 · the gate is a
**deployment-discipline transition rule**, not evidence of an invented RC-C4 → RC-C5 technical dependency.

**The original gate is neither weakened nor retroactively extended.**

## 7. PROTECTED BOUNDARY CORRECTIVE REPAIR *(frozen)*

A protected/shared subsystem may be changed **outside** the execution scope of a reconstruction chapter only
when **all ten** conditions hold:

1. Evidence demonstrates an actual defect **resides in or necessarily crosses** the protected subsystem.
2. The change is **corrective**, not opportunistic reconstruction or feature expansion.
3. The repair is the **minimum necessary** change.
4. The repair does **not silently expand** the executing chapter's authority or scope.
5. The protected subsystem's **governing invariants remain authoritative**.
6. The affected shared-system boundary is **explicitly identified before** modification.
7. **Targeted regression/certification** for the protected subsystem is mandatory.
8. **Shared-system health must be reported** before the repair is considered complete.
9. Any change altering a founder-frozen doctrine, product boundary or protected invariant **still requires
   explicit founder approval**.
10. This category must **never** be used as a convenience bypass around a protected boundary.

**Generalises to all of PB-01…PB-12**, not only PB-02.

**Historical application — PB-02 / RC-C6.** The RC-A (`509230a`) and RC-B (`_joining` latch) repairs are
classified **defect repair, not RC-C6 chapter execution**: RC-C6's chartered work is presentation convergence,
which FD-4 already permits slice-by-slice *without* touching transport, media service or event parser.
Governance reconciliation only — **no protected-system modification was performed**. Conditions **7 and 8
were owed** for the historical crossing.

### 7.1 Discharge of conditions 7 and 8 — W1-000, 2026-08-18

Evidence: `run/stage0-2026-08-18/05-execution/w1-000-shared-system-health-report.json`.
Non-mutating: suites were run and behaviour observed; **no protected system was modified**.

| | Condition | Status | Evidence |
|---|---|---|---|
| 7 | Targeted regression for the protected subsystem | **DISCHARGED** | Meetings **118** tests PASS (90 backend + 28 frontend); realtime transport **333** PASS (290 backend + 43 frontend); RC-A `509230a` and RC-B `dfc9027` verified present and ancestors of HEAD |
| 8 | Shared-system health reported | **DISCHARGED, two defects reported** | Backend 192 suites / 2426 tests PASS; frontend 578 PASS after repair; **PB-12 satisfied for the first time** — both repositories reported together for one closure |

**Two defects the green suites concealed, both recorded rather than smoothed over:**

- **DEFECT-1 — `REPORTED_NOT_REPAIRED`.** `test/realtime_room_golden_test.dart` is `@Skip`-ped
  entirely for "pre-existing rot". The realtime room's **rendered appearance is unverified by any
  automated proof**; the 333 passing realtime tests cover semantics and lifecycle, not presentation.
  Reviving it is CH-04 territory and is not authorized in this wave. **A green realtime suite must
  not be read as covering realtime presentation.**
- **DEFECT-2 — `REPAIRED_IN_W1-B`.** The C0 anti-drift ratchet was **RED before this wave began**:
  `realtime_lobby_screen.dart` had introduced a new full-surface spinner outside the state authority.
  Repaired to `AuraProductState`. **The baseline was not green when the programme proposed to start.**

**Stale figure reported, not retro-fitted.** The governance record requires "Meetings 97/97"; the
current suite is **118**. The suite grew, so this is not a coverage loss — but 118 was **not** presented
as 97/97 and 97 was **not** rewritten to 118. Left for founder disposition.

**Still owed after this discharge:** AD-CON-5 (founder classification of the crossing) and SU-5.
Conditions 7 and 8 are discharged; **CH-04 entry is not**.

## 8. CHECKPOINT-AWARE EXTRACTION *(frozen)*

> Chartered obligations may be recorded in **any** structured charter field, not only the three the first
> extractor happened to read.

RC-C7's Correspondence architectural-convergence verdict — a **named founder checkpoint with no recorded
outcome** — sat in `contradictionsOrGaps` and was invisible to the axis built to stop chartered work
disappearing. **It was not a one-off:** the same class hid **9 obligations**, including all five previously
`UNMAPPED_TO_RC` surfaces.

**Narrative commentary is not an obligation.** Only entries whose **type token** signals an unresolved
required decision — `UNRESOLVED`, `OPEN_`, `VOID`, `UNASSIGNED`, `UNADDRESSED`, `UNMET`, `DISPOSITION` —
create obligations. The rule is a documented token test, reproducible on every run. **30 entries were
mechanically rejected as commentary.**

**Ids are stable.** Existing COs are matched by (chapter, normalised text) and keep their ids; new ones
continue each chapter's sequence. **Nothing is renumbered to make the register look tidy.**

## 9. CLASSIFICATION PROVENANCE *(frozen)*

Every obligation carries `classificationBasis`, so **inference can never be read as historical fact**:

| Value | Meaning |
|---|---|
| `EXPLICIT_RECORDED_STATE` | a recorded obligation-level state |
| `EXPLICIT_FOUNDER_RULING` | adjudicated by the founder |
| `DETERMINISTIC_DERIVATION` | derived mechanically from canonical evidence |
| `ANALYTICAL_INFERENCE` | inferred from charter/evidence by an agent |
| `UNRESOLVED_INSUFFICIENT_EVIDENCE` | evidence does not determine a class |

**Current distribution: 293 ANALYTICAL_INFERENCE · 9 DETERMINISTIC_DERIVATION · 6 EXPLICIT_FOUNDER_RULING.**
That 293 is the honest headline: the axis is uniformly classified but **overwhelmingly by inference**, because
no obligation-level state was ever recorded.

**Schema limitation reported, not hidden.** The six-value taxonomy cannot express a multidimensional state
(`FOUNDER_DECIDED` + `IMPLEMENTED` + `NOT VALIDATED` + `ACTIVE_CONSTRAINT`). Rather than collapse it, a
`dimensions` object is carried on the affected RC-C10 rows. **The taxonomy was not widened without founder
authority.**

## 10. FROZEN COMPLETION DISTINCTIONS

```
FOUNDER_DECIDED        != COMPLETED_OR_SUPERSEDED
IMPLEMENTED            != VALIDATED
IMPLEMENTED            != LIVE_CERTIFIED
STRUCTURALLY_COMPLETE  != LIVE_CERTIFIED
ACTIVE_CONSTRAINT      != DISCHARGED_OBLIGATION
```

**A live founder constraint must never be made to appear discharged.** Implementation evidence may be recorded
where it exists; validation and live certification may **never** be inferred.

## 11. CORRESPONDENCE — FORM vs PRODUCT *(frozen)*

> **DISTINCT GOVERNED COMMUNICATION FORM ≠ SEPARATE PRODUCT**

Correspondence remains a distinct governed communication form/capability with its own semantics and authority.
RC-C7 does **not** recreate Correspondence as a separate product. The original charter statement and the
2026-08-16 amendment **coexist** — they use different nouns. `CO-RC-C7-015` is reconciled on this basis and is
no longer UNKNOWN. The ruling does not extend to unrelated Correspondence architecture.

## 12. G1 DECOMPOSITION — PROOF GATES FOLLOW DEPENDENCIES *(founder ruling, 2026-08-18)*

> **PROOF GATES FOLLOW DEPENDENCIES; THEY DO NOT GLOBALLY FREEZE UNRELATED WORK MERELY BECAUSE THEY
> ONCE SHARED A WAVE.**

**What was superseded.** The *aggregate* reading of G1 — "all six legs must pass before any W2 work may
begin" — is superseded as an **execution-sequencing rule**.

**What was NOT superseded.** No individual G1 proof obligation is deleted, weakened, waived or
discharged. No unattempted leg became PASS by decomposition.

**Why the aggregate reading became impossible.** G1 was written to terminate Stage-5's W1, which
contained CH-04 PHASE 1 and the CH-11 chapter head. The first executable wave was later re-derived from
canonical evidence, and CH-04 PHASE 1 was **refused on its own evidence**. The executed wave is
therefore narrower than the gate that terminates it, so G1 retained prerequisites belonging to branches
the evidence correctly excluded. It could never have opened — not because a proof failed.

**A wave is an execution-planning construct.** It cannot manufacture a technical dependency, and
historical wave membership is not itself a prerequisite. Each leg now attaches to the capability,
chapter or dependency it actually proves, and remains fail-closed there.

| Leg | State | Attached to |
|---|---|---|
| 1 F065 live refresh | **PASS** | CH-02 continuity keystone |
| 2 signed-out probe + gates + Meetings regression | **PASS** | CH-02 route classification |
| 3 F045 three sequential calls | **OPEN** | CH-04 — AD-CON-5, SU-5, VS-02, real devices |
| 4 F006–F010 live on the Conversation surface | **OPEN** | CH-04 / CH-06 boundary |
| 5 violating file refused live + doors enumerated | **5(A) ESTABLISHED · 5(B) OPEN** | CH-11 and everything downstream of governed ingestion |
| 6 PBCR 7 and 8 | **PASS** | the historical PB-02/RC-C6 crossing (§7.1) |

The original G1 remains unedited in `s5-execution-architecture.json` as historical Stage-5 architecture.

