# AURA DYNAMIC RECONSTRUCTION WORKFLOW — DESIGN

**Status:** DESIGN ONLY. Not executed. Requires explicit founder authorization to run.
**Date:** 2026-08-18
**Purpose:** Produce a governed **implementation portfolio** above the F-register and the
C0–C11 reconstruction map — not a bug queue.
**Operating environment:** Claude Code, Claude Max 5x, `opus[1m]`, Windows 11, 12 CPUs.

---

## 0. What this design had to establish first

Three assumptions in the brief did not survive contact with the environment. They
are corrected here because the workflow cannot be designed accurately without them.

| Assumption | Evidence | Corrected fact |
|---|---|---|
| "C0–C8 reconstruction architecture" | `docs/frontend-discovery/FINAL_FRONTEND_RECONSTRUCTION_ROADMAP.md` | The canonical map is **C0–C11** — twelve chapters. C9 Cross-Platform Completion, C10 Live (cross-repository) and C11 Item 17 / Release Gate exist and carry real obligations. A workflow scoped to C0–C8 would silently drop three chapters |
| "complete F-register … at least through F143" | Corpus sweep | **No canonical F-register artifact exists in any repository.** Governed markdown contains only **27** distinct F-ids. The register survives in ~745 MB of Claude session transcripts, where **F001–F143 appear**. Tokens above F143 (`F214`, `F332`, … `F990`) are base64 false positives, verified by inspection. **CORRECTED 2026-08-18 by the Stage 0 run: the register is CONTIGUOUS — 143 issued, no gaps. F097 IS issued** ("Public Home surfaces real Live", first of the Live public-acquisition cluster F097–F107). The earlier gap claim was a false negative from a broken shell pipeline, and this document's own assertion of it later re-entered the corpus as self-contamination |
| "WG register" | Same sweep | **No WG register artifact exists.** ~**WG001–WG018** appear in transcripts |

**Consequence, and it is structural:** Part VII's mandatory accounting proof
(`total in source register == total canonically owned`) is **currently unprovable**,
because there is no source register to count. Reconstructing it from transcripts is
Stage 0's first job, and its output requires founder ratification before it can be
treated as canonical. See §N, decision 1.

**A naming collision the workflow must not conflate.** "C1/C2/C3" denote *two
different axes*:

- **Frontend reconstruction chapters** C0–C11 (the roadmap).
- **Rich Content implementation stages** C1 Content Truth, C2 Reference/Retention,
  C3 Access-context, C4 Ingestion-convergence, C5 Governed-delivery…
  (**CORRECTED 2026-08-18**: the frozen §12 §16 stage set is C1 Content-truth / C2
  Reference-retention / C3 Access-context / C4 Ingestion-convergence / C5
  Governed-delivery. An earlier draft of this document listed a different set —
  a third, incompatible RIC namespace. Stage 0 flagged it as contradiction X3.)

`§12 C2` and `roadmap C2 — Identity, Presence & Profile` are unrelated. Every agent
contract below carries an explicit disambiguation clause; without it, Agent D would
produce a confidently wrong mapping.

---

## 1. Capability facts

Primary evidence is the live tool schema in this session plus direct filesystem
inspection. Nothing below is inferred from marketing copy.

| # | Capability | State | Evidence | Design implication |
|---|---|---|---|---|
| 1 | `Workflow` tool exists, runs a JS orchestration script | **PROVEN AVAILABLE** | Tool present in session with full schema | The workflow is a real script, not a prompt convention |
| 2 | `agent(prompt, opts)` spawns subagents | **PROVEN AVAILABLE** | Tool schema | Stages are explicit agent calls |
| 3 | `schema` option forces structured output via a StructuredOutput tool, validated with model retry | **PROVEN AVAILABLE** | Tool schema | **Every analytical agent returns validated JSON.** No prose parsing |
| 4 | `parallel()` barrier, `pipeline()` no-barrier | **PROVEN AVAILABLE** | Tool schema | Concurrency is controllable per stage |
| 5 | Concurrency cap = `min(16, CPUs-2)` | **PROVEN AVAILABLE** | Schema + `os.cpus()==12` → **cap 10** | The platform will **not** enforce the founder's ≤3. The script must self-limit |
| 6 | Per-agent `model` and `effort` overrides | **PROVEN AVAILABLE** | Tool schema | Cheap stages can run cheap |
| 7 | `agentType` selects a registered subagent | **PROVEN AVAILABLE** | Schema; registry lists `Explore`, `general-purpose`, `Plan`, `claude`, … | `Explore` is the read-only analytical type |
| 8 | `isolation: 'worktree'` | **PROVEN AVAILABLE** | Tool schema | **Not used** — this workflow writes no product code |
| 9 | Resume via `resumeFromRunId`; longest unchanged agent-call prefix returns cached | **DOCUMENTED, NOT LOCALLY VERIFIED** | Tool schema; **zero workflow artifacts exist on this machine** — no run has ever executed here | Cannot be the *only* persistence layer. See §E |
| 10 | `journal.jsonl` records each agent's actual return value | **DOCUMENTED, NOT LOCALLY VERIFIED** | Tool schema | Recovery aid, not a guarantee |
| 11 | Script has **no filesystem or Node API access** | **PROVEN AVAILABLE (as a limitation)** | Tool schema, explicit | **Decisive:** the script cannot write artifacts. *Agents* must, using their `Write` tool |
| 12 | `Date.now()` / `Math.random()` / `new Date()` throw in scripts | **PROVEN AVAILABLE (as a limitation)** | Tool schema | Run label and timestamps must arrive via `args` |
| 13 | Scripts are plain JS, not TypeScript | **PROVEN AVAILABLE (as a limitation)** | Tool schema | No type annotations |
| 14 | Session workflow-size guideline: **medium, <15 agents** | **PROVEN AVAILABLE** | Session system reminder | Design targets **9** |
| 15 | Lifetime cap 1000 agents; ≤4096 items per `parallel`/`pipeline` | **PROVEN AVAILABLE** | Tool schema | Not binding here |
| 16 | `budget.total` / `spent()` / `remaining()` | **PROVEN AVAILABLE, INERT BY DEFAULT** | Tool schema — populated only by a user "+500k"-style directive | Without that directive `budget.total` is `null` and budget-driven loops must not be used |
| 17 | Named workflows resolve from `.claude/workflows/` | **PROVEN AVAILABLE** | Tool schema | Directory **did not exist**; created by this design |
| 18 | Custom agent definitions in `.claude/agents/` | **NOT PRESENT** | Directory absent | Use built-in `agentType`s + prompt-level contracts |
| 19 | Max 5x quota introspection (tokens remaining, reset time) | **NOT AVAILABLE** | No env var, no tool, no file exposes it | Usage economics can only be described **qualitatively**. Any numeric forecast would be fabricated |
| 20 | Behaviour when a Max limit interrupts mid-run | **UNKNOWN / NEEDS EXPERIMENT** | Nothing in the environment documents it | Design must assume interruption is **unannounced and total** |
| 21 | Hard read-only enforcement for an agent | **PARTIAL** | `Explore` excludes `Edit`/`Write`; general types do not | Read-only is enforced by *agent type choice*, plus prompt prohibitions — not by a sandbox |
| 22 | MCP tools reachable inside workflow agents via `ToolSearch` | **DOCUMENTED, NOT VERIFIED** | Tool schema notes headless caveat | Do not depend on browser/MCP inside this workflow |

### `ultracode` — precisely what it is here

**It is an authorization keyword, not a command and not a workflow.**

- The `Workflow` tool may only be called when the founder has explicitly opted in.
  One of the accepted signals is the literal keyword **`ultracode`** in the prompt,
  which causes a system-reminder confirming it. Other accepted signals are the
  founder asking in their own words ("use a workflow", "fan out agents"), a
  skill/slash-command that instructs it, or a named saved workflow.
- It can also be **standing for a session** (a system-reminder announces
  "ultracode is on"). In that mode the default posture inverts: author and run a
  workflow for every substantive task, token cost is not a constraint, and
  multi-phase work runs as several sequential workflows.
- **It does not define, schedule, or execute anything by itself.** It removes the
  opt-in gate. The script, stages and agents are still authored explicitly.

**Therefore I cannot start this workflow on my own initiative.** No system-reminder
in this session enables ultracode. Running it requires the founder to say
`ultracode`, or to authorize the run in their own words.

---

## 2. Workflow architecture

Nine agents, four stages, plus a deterministic proof step that is **not** an agent.

```
                    ┌─────────────────────────────────────────┐
   STAGE 0          │  S0-A Register        S0-B Doctrine      │   3 agents
   Evidence         │  Reconstruction       & Roadmap          │   concurrency 3
   (expensive,      │                                          │   READ-ONLY + Write
    run once)       │  S0-C System & Chapter State             │   → durable artifacts
                    └─────────────────────────────────────────┘
                                       │ artifacts on disk
                    ┌──────────────────▼──────────────────────┐
   STAGE 1          │  A Domain/Root   B Dependency/  C Product│   3 agents
   Analysis         │    System          Risk/Boundary  /Valid │   concurrency 3
                    └──────────────────┬──────────────────────┘
                                       │
                    ┌──────────────────▼──────────────────────┐
   STAGE 2          │  D C0–C11 Reconciliation                 │   1 agent
   Reconciliation   │            ↓ (sequential — see note)     │
                    │  E Adversarial Reviewer                  │   1 agent
                    └──────────────────┬──────────────────────┘
                                       │
   STAGE 3          │  F Portfolio Synthesis (1 agent)         │   1 agent
                                       │
   STAGE 4          │  DETERMINISTIC RECONCILIATION (code)     │   0 agents
                    │  orchestrator-run, exact arithmetic      │
```

**Why D and E are sequential, deviating from the brief's "≤2 heavy agents" batch.**
E's job is to attack the synthesis. If E runs concurrently with D it cannot see D's
C0–C11 mapping, and the single most likely error — a chapter that quietly drops a
C9/C10/C11 obligation — is exactly what E exists to catch. Sequential costs one
stage of latency and buys E complete input. Concurrency stays ≤3 throughout.

**Why Stage 4 is code, not an agent.** Part VII demands an accounting *proof*. A
language model producing `142 == 142` is an assertion; a script producing it is a
proof. The reconciliation is pure set arithmetic over JSON and must never be
delegated to a model, which could hallucinate a balanced ledger.

---

## 3. Agent contracts

Common to **every** agent in this workflow:

- **Prohibited:** modifying any file outside the run's artifact directory; changing
  frozen founder doctrine; deleting/merging findings; resolving founder decisions;
  implementing anything; mutating production; running the reaper; touching Meetings,
  Realtime or Live; converting uncertainty into fact.
- **Required:** every claim carries provenance (file path + anchor, or transcript
  file + line). Unsupported claims must be emitted as `openQuestions`, not asserted.
- **Disambiguation clause (mandatory):** "C0–C11 are frontend *reconstruction
  chapters*. §12's C1/C2/C3… are Rich Content *implementation stages*. They are
  different axes and must never be equated."
- **Stop condition:** if required input artifacts are missing or malformed, stop and
  return `status: "BLOCKED"` with the reason. Do not improvise inputs.

| Agent | Type / effort | Purpose | Allowed evidence | Output |
|---|---|---|---|---|
| **S0-A Register Reconstruction** | `general-purpose`, high | Rebuild the F-register and WG register from transcripts + governed docs into canonical JSONL with provenance | `.claude/projects/**/*.jsonl`, governed `docs/**` | `findings.jsonl`, `wg.jsonl`, `register-anomalies.json` |
| **S0-B Doctrine & Roadmap** | `Explore`, high | Extract C0–C11 intent/state, frozen doctrines, protected boundaries, founder rulings | Roadmap, FD*_FROZEN, DECISIONS, amendments | `roadmap.json`, `doctrines.json`, `boundaries.json` |
| **S0-C System & Chapter State** | `Explore`, high | Repo/system map, completed & active chapters, certification states, validation debt | CURRENT_STATE, HANDOFF, NEXT_WORK, registers, git log | `systems.json`, `chapters-state.json`, `validation-debt.json` |
| **A Domain/Root-System** | `general-purpose`, high | For each finding, the *system* whose correction discharges the obligation. Not keyword grouping | Stage 0 artifacts **only** | `finding-domains.json` |
| **B Dependency/Risk/Boundary** | `general-purpose`, high | Prerequisite chains, shared authorities, destructive ops, migration/auth/identity/storage/realtime boundaries | Stage 0 artifacts + targeted code reads | `dependencies.json` |
| **C Product/Competitive/Validation** | `general-purpose`, high | Product impact vs the frozen "visibly modern, competitive" standard; WG absorption; validation topology per item | Stage 0 artifacts + release client | `product-validation.json` |
| **D C0–C11 Reconciliation** | `general-purpose`, xhigh | Map proposed chapters back onto C0–C11; find dropped obligations | Stage 0 + A/B/C | `c-map.json` |
| **E Adversarial Reviewer** | `general-purpose`, xhigh | Attack the synthesis. Not to make it look clean | Everything prior | `adversarial.json` |
| **F Portfolio Synthesis** | `general-purpose`, xhigh | Emit both portfolio views + full ownership ledger | Everything prior | `portfolio.json` |

**Agent A is the one most likely to fail subtly.** Its prompt states the test
explicitly: *"What architectural correction would discharge this obligation?"* — and
forbids grouping by UI surface, screen name, or shared vocabulary. Rich Content is
the worked example: F126/F127/F128/F131/F138–F143 did not become "media bugs", they
resolved into Content Truth, Reference/Retention Truth, Governed Delivery,
Processing, Acquisition and Presentation.

**Agent E is contractually forbidden from concluding "no issues found."** It must
return at least the questions from Part V verbatim with a verdict and evidence for
each. A clean report from E is treated as E having failed, not as the portfolio
being sound.

---

## 4. Reconciliation invariants (Stage 4, deterministic)

Executed as a script by the orchestrator over `findings.jsonl` + `portfolio.json`.
Any violation **fails the run**; the portfolio is not published.

| # | Invariant |
|---|---|
| R1 | Every finding has **exactly one** `canonicalChapter`. Count of canonically-owned findings **==** count in the source register |
| R2 | Cross-references are `0..N` and never substitute for ownership |
| R3 | No finding disappears for being grouped, duplicated, structurally addressed, implemented-uncertified, C4-owned, blocked, retired or superseded. Retired/superseded reconcile **historically**, with a state, not by omission |
| R4 | Every C0–C11 chapter is represented, or explicitly recorded as complete/excluded **with evidence** |
| R5 | Every WG item is either absorbed into a chapter (traceably) or explicitly deferred with a reason |
| R6 | Certification states are preserved verbatim from Stage 0. No agent may promote a state |
| R7 | The canonical register is **never modified** by analysis. Anomalies are reported, not repaired |
| R8 | Every founder decision remains a decision. No agent output may present one as settled |
| R9 | Ledger reports: duplicates, missing IDs, malformed records, contradictory states, and items with evidence too weak to classify. **Plus SELF-CONTAMINATION**: any identifier evidenced only by this workflow's own output must be quarantined, never counted as issued |

The 42 F-ids appearing only once or twice across transcripts are pre-flagged as
**weak-evidence candidates** for R9.

---

## 5. Max 5x operating model

**Frozen principle: Max 5x limits concurrency, not analytical coverage.**

| Property | Design |
|---|---|
| Max concurrent heavy agents | **3** (platform would allow 10; the script self-limits) |
| Total agents per full run | **9** (guideline is <15) |
| Expensive stages | S0-A (transcript mining over 745 MB), D, E, F |
| Cheap stages | S0-B, S0-C (bounded doc reads) |
| Context-reuse strategy | **Stage 0 reads the corpus once.** Stages 1–3 consume normalized artifacts. No agent re-reads all repos, all findings and all doctrine |
| Anti-pattern explicitly avoided | A swarm where every agent re-derives the whole project — multiplies cost without multiplying truth |
| Quota accounting | **Not available.** Described qualitatively only; no numeric forecast is offered because the environment exposes none |
| Interruption assumption | Unannounced and total |

**Practical guidance:** run Stage 0 as its own invocation and stop. Inspect artifacts.
Then run Stages 1–3. Splitting at the natural artifact boundary makes a mid-run quota
reset cost at most one stage, and Stage 0 — the expensive one — is never repeated.

---

## 6. Persistence and resumability

Two independent layers, because layer 1 alone is insufficient.

**Layer 1 — workflow resume (same session).** `resumeFromRunId` replays the longest
unchanged agent-call prefix from cache. Fast, but same-session only, and **not yet
verified on this machine.**

**Layer 2 — durable on-disk artifacts (survives everything).** Every agent writes
JSON to:

```
aura_final/docs/portfolio/run/<runLabel>/
    00-evidence/   findings.jsonl  wg.jsonl  roadmap.json  doctrines.json
                   boundaries.json systems.json chapters-state.json
                   validation-debt.json  register-anomalies.json
    01-analysis/   finding-domains.json  dependencies.json  product-validation.json
    02-reconcile/  c-map.json  adversarial.json
    03-synthesis/  portfolio.json  founder-portfolio.md  engineering-portfolio.md
    04-proof/      reconciliation.json
    _state.json    stage completion markers
```

Because the **script cannot touch the filesystem** (capability 11), each agent is
instructed to `Write` its artifact *and* return the same object. The script checks a
`skipIfPresent` convention: an agent's first instruction is "if your artifact already
exists and is valid, return it unchanged and do no work." That makes the whole
workflow **idempotent across sessions, laptop restarts and quota resets**, with or
without a runId.

`runLabel` is passed through `args` (the script cannot generate a timestamp —
capability 12).

**Failure semantics.** `agent()` returns `null` on terminal failure or user skip; a
thrown stage in `pipeline()` drops that item. The script therefore `.filter(Boolean)`s
and, if any Stage-0 or Stage-1 artifact is missing, **halts rather than synthesizing
from partial evidence** — an incomplete portfolio that looks complete is the specific
failure this whole exercise exists to prevent.

---

## 7. Portfolio outputs

### Founder portfolio (`founder-portfolio.md`)

A control board, not 142 rows. Answers, on one page:

- How many **systems** remain to reconstruct?
- Which are highest product impact? Which block others?
- Which are implementation-complete but awaiting certification?
- Which need founder decisions?
- Which affect commercialization/readiness?
- Which can proceed without disturbing Meetings/Realtime/Live?
- **What next, and why?**

Per chapter: name · purpose · root deficiency · maturity · blocking/blocked-by ·
founder decisions · product impact · competitive significance · protected boundaries ·
recommended sequence position. Finding IDs appear as counts, not lists.

### Engineering portfolio (`engineering-portfolio.md`)

Full traceability. Every finding visible beneath its canonical chapter, with:
finding ID · canonical owner · current state · root-system classification ·
dependencies · validation class · protected-boundary implications · related WG items ·
cross-chapter effects · evidence references.

Schemas: `schemas/portfolio.schema.json`, `schemas/finding.schema.json`,
`schemas/chapter.schema.json`.

---

## 8. Versioning and re-run model

`runLabel` makes every run an immutable directory. A later run takes
`--compare <previousRunLabel>` and Stage 4 emits a **delta report**:

new findings · state transitions · chapters completed/opened · dependency changes ·
new contradictions · validation debt moved · WG absorbed · **unresolved-system count** ·
register reconciliation delta.

The intended long-run metric is deliberately **not** "how many F-items are OPEN" but:

> **Is Aura's unresolved architectural-system count falling?**

---

## 9. Risks and limitations

| # | Risk | Mitigation |
|---|---|---|
| 1 | **The canonical register does not exist.** The proof in R1 is unprovable until Stage 0 reconstructs it and the founder ratifies it | Stage 0 output is explicitly *proposed*, not canonical, until ratified. §N decision 1 |
| 2 | Transcript mining is lossy — 31 issued F-ids rest on WEAK provenance, and 115 of 143 exist ONLY in transcripts | R9 flags weak evidence; the founder adjudicates rather than the model guessing |
| 3 | Workflow resume is **unverified here** — no run has ever executed on this machine | Layer-2 artifacts make resume optional, not load-bearing |
| 4 | Max 5x interruption behaviour is **unknown** | Stage-split execution; idempotent agents; no stage depends on same-session state |
| 5 | Quota economics are **not exposed** | Reported qualitatively; no invented numbers |
| 6 | Agents can be wrong with confidence, especially on the C-axis collision | Mandatory disambiguation clause; Agent D; Agent E forbidden from returning clean |
| 7 | A chapter could quietly become "the 142-item dump renamed" | Explicit Part V question in E's contract; chapter size and coherence are review criteria |
| 8 | Read-only is a *convention* for general agents, not a sandbox | `Explore` where possible; artifact-directory-only write permission stated in every contract |
| 9 | `.claude/workflows/` is **outside any git repository** | Canonical copy of the script is committed in `aura_final/docs/portfolio/`; the runtime copy is a deployment detail |
| 10 | Dynamic Workflows cannot guarantee correctness, completeness, or that an agent obeyed its contract | Stage 4 is deterministic code; E is adversarial; the founder ratifies |

---

## 10. What this workflow may never do

Unchanged from the standing hard stops: no reaper, no deletion, no production
mutation, no Meetings/Realtime/Live changes, no C4 finding changes, no R2 config,
no F138 ratchet, no implementation, no finding-state promotion from analysis alone,
and no conversion of a founder decision into an engineering assumption.

The workflow is an **execution and analysis mechanism, not an authority mechanism**:

```
founder ruling / frozen doctrine → governing architecture → portfolio →
implementation chapter → orchestrator → agents → evidence → implementation → validation
```
