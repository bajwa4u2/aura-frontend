# STAGE 0 — FOUNDER-RATIFIED CANONICAL BASELINE

**Declaration:** `FOUNDER_RATIFIED_CANONICAL_BASELINE`
**Date:** 2026-08-18
**Run:** `docs/portfolio/run/stage0-2026-08-18/`
**Stage 0:** COMPLETE + FOUNDER RATIFIED · **Stage 1:** NOT STARTED — requires separate founder authorization

---

## What was ratified

The Stage-0 evidence package is **Aura's canonical reconstructed portfolio baseline**.

| Axis | Canonical value |
|---|---|
| **Findings** | **143 issued — F001–F143, fully contiguous** |
| **F097** | **ISSUED.** Prior apparent absence was a false negative from a broken shell pipeline, permanently superseded by recovered issuance evidence |
| **WG** | **17 issued — WG001–WG017.** Identifier space observed through WG018; **WG018 = RESERVED / UNISSUED** |
| **Reconstruction axis** | **RC-C0 … RC-C11** — the complete historical axis currently evidenced |
| **Doctrines indexed** | 64 |
| **Validation obligations** | 82 |
| **Protected boundaries** | 12 (PB-01 … PB-12) |
| **Quarantined non-findings** | 41 self-contamination / base64 / generated-example identifiers |
| **Provenance** | 59 STRONG · 53 MODERATE · 31 WEAK |

---

## What "canonical" means — and what it does not

**Canonical MEANS:** accepted evidence universe · accepted provenance · accepted historical
reconstruction axis · accepted unresolved contradictions · accepted validation-debt index ·
accepted protected-boundary index · accepted WG issuance universe.

**Canonical does NOT mean:** that all findings are correct in every historical description ·
that all states are resolved · that anything is prioritised · that any finding has
Implementation Chapter ownership · that any WG candidate is authorised · that RC dependencies
remain architecturally optimal · that implementation is authorised · that certification is granted.

---

## Rulings applied in this closeout

1. **F097 — ISSUED.** Contiguous F001–F143 confirmed.
2. **WG018 — RESERVED / UNISSUED.** Visible in the evidence layer so its historical appearance
   is explained; excluded from issued, ownership, authorization and implementation totals.
3. **F064 / F113 — two separate canonical findings.** "Duplicate" evidence is an annotation and
   a relationship, never deletion authority. A later chapter may own both and cross-reference them.
4. **Five surfaces — `UNMAPPED_TO_RC`** (PD-1, PD-2, SupportScreen, GAP-1 Settings,
   GAP-2 Long-Form Publishing). Not force-assigned; not automatically a defect.
5. **RC-C4 / RC-C5 chain — preserved as evidence.** The gate was not removed, RC-C4 was not
   started, and no inference was drawn that RC-C7…RC-C11 are abandoned. *Frozen gates are not
   removed for portfolio convenience.*
6. **138 vs 143 — both facts preserved.** The five later findings were issued beyond the last
   consolidated arithmetic checkpoint. The absence of a 143-total checkpoint is provenance
   history, not evidence of invalidity.

## Deliberately NOT resolved

`F043`, `F051`, `F122` remain **CONFLICTING_CURRENT_STATE**. `F139` retains **both readings**
(STRUCTURALLY_CLOSED_NOT_LIVE_CERTIFIED vs OPEN, same day, equal recency). `RC-C10` retains
CONFLICTING_CURRENT_STATE. Later analysis must determine whether these are genuinely
contradictory states or **different dimensions of completion versus certification**.

> Ratification preserves the contradiction. It does not adjudicate it.

Provenance debt stays visible: only **28 of 143** findings appear in governed documents;
**115 depend on transcript evidence**; no original founder issuance evidence survives for
F001–F048. WEAK provenance does **not** mean invalid.

---

## FROZEN EVIDENCE-PROCESSING INVARIANT

> ### ANALYSIS OUTPUT IS NOT HISTORICAL ISSUANCE EVIDENCE MERELY BECAUSE IT LATER APPEARS IN THE SEARCHABLE CORPUS.

Stage 0 demonstrated this empirically: the workflow-design session printed candidate and
missing identifier lists, that output entered the transcript corpus, and re-reading it
manufactured issuance "evidence" for **41 identifiers that were never issued**.

Every future evidence reconstruction MUST distinguish: original issuance · later status
report · summary · workflow hypothesis · generated example · analysis artifact ·
self-reference · quoted historical evidence.

**A generated identifier in workflow or design discussion cannot create a finding or a WG item.**
The quarantine mechanism in `tools/reconcile-ids.mjs` is a permanent requirement, not an
optimisation. Classification is never by token shape alone — `RC-A`, `RC-B`, `RC1`, `RC7` are
root-cause labels, not Reconstruction Chapters.

---

## Namespace (canonical for portfolio artifacts)

`RC-C0 … RC-C11` = historical Reconstruction chapters.
`RIC-C1, RIC-C2, RIC-C3 …` = Rich Content & Interaction stages.

Historical source documents are **not** rewritten to rename their terminology; portfolio
artifacts normalise references while retaining provenance to the original wording.

---

## Stage-0 economy — empirical, not a quota forecast

```
corpus                703 MB · 272 files · 178,004 lines
deterministic pass    ONE scan  →  2,588 deduplicated mentions
normalised input      ~665 KB of provenanced dossiers
execution             6 agents · peak concurrency 3 · 0 errors
                      ~35.5 min · ~1.21 M subagent tokens · 204 tool uses
resume                DESIGNED_NOT_EMPIRICALLY_PROVEN (no interruption occurred)
```

**Frozen operating lesson:**

> **LARGE RAW CORPUS → DETERMINISTIC EXTRACTION ONCE → SMALL PROVENANCED DOSSIERS → MODEL REASONING**

Future stages consume the canonical normalized evidence package. They must **not** casually
rescan the 703 MB corpus.

---

## Deterministic proof

`node docs/portfolio/tools/validate-stage0.mjs docs/portfolio/run/stage0-2026-08-18/00-evidence`

```
ISSUED (deterministic)   : 143  range F001-F143  contiguous=true
RECONSTRUCTED            : 143  balances=true
WG reconstructed         : 18 / 17          (WG018 present but RESERVED)
RC chapters covered      : 12 / 12
CONFLICTING_CURRENT_STATE: 3
RATIFIED  F097 = ISSUED
RATIFIED  findings = 143, range F001-F143, contiguous
RATIFIED  WG issued = 17 (WG001-WG017); reserved = WG018
RATIFIED  F064 and F113 both present and independently reconciled
RATIFIED  F043/F051/F122 remain CONFLICTING_CURRENT_STATE; F139 dual reading preserved
RATIFIED  Stage-4 ownership invariant deliberately NOT applied at Stage 0
VERDICT: PASS   baseline: FOUNDER_RATIFIED_CANONICAL_BASELINE
```

Stage 0 does **not** require Implementation Chapter ownership; the Stage-4
exactly-one-owner invariant is deliberately not applied here.

---

## Stage status

| Stage | Status |
|---|---|
| **Stage 0 — Canonical evidence** | **COMPLETE · FOUNDER RATIFIED** |
| Stage 1 — Domain / dependency / product analysis | **NOT STARTED — requires separate founder authorization** |
| Stages 2–4 | NOT STARTED |

No implementation task is created by this baseline.
