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
