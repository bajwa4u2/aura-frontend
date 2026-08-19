# CH-12 — MEDIA EXAMINATION PREPARATION PACKAGE

**SPECIFICATION ONLY. NOTHING HERE IS IMPLEMENTED.** No code, no schema, no migration, no product
mutation. CH-12's real dependency — **G1 leg 5(B)** — is untouched and unweakened.
**Authority:** founder rulings D1/D3/D4 (2026-08-18), F137's carried adequacy requirements.
**Date:** 2026-08-18

Preparation must not silently become implementation. Every section below states what would be built,
not what was.

---

## 1. OBLIGATION DECOMPOSITION

From the founder-authored policy, CH-12's share decomposes into eight bounded obligations:

| # | Obligation | Depends on | Phase |
|---|---|---|---|
| **E1** | Examination invocation point — where a stored object is submitted for examination | resolved type class (CH-11, done) | 1 |
| **E2** | Verdict model — an examination result persisted as evidence, never overwritten | E1 | 1 |
| **E3** | Quarantine as a **reversible retention state** | E2 | 1 |
| **E4** | Delivery gate honours quarantine — the verdict actually stops bytes | E3, F138 | 1 |
| **E5** | Notice emission carrying D3's eight required elements | E3 | 1 |
| **E6** | Appeal intake + prioritized review queue | E5 | 1 |
| **E7** | Backfill over objects uploaded **before the scanner existed** | E1–E4 | 1 |
| **E8** | Phase 2 — remaining governed media classes | E1–E7 | **2, closure requirement** |

**E4 is the one that makes it an examination system.** F137 is explicit: *a scanner whose verdict cannot
stop bytes reaching a person is not an examination system.* E1–E3 without E4 is detection theatre.

**E7 is not optional.** F137's adequacy requirement is *coverage of every stored object **including a
backfill***. A go-forward filter leaves the entire existing population unexamined and would satisfy
nothing.

---

## 2. PHASE 1 ARCHITECTURE — IMAGE EXAMINATION

**Boundary.** CH-12 owns the **mechanism**. CH-15 owns the **policy and consequence**. Neither absorbs
the other, and neither acquires the other by name similarity (frozen in the F137 placement).

**Shape.** An object becomes examinable once CH-11's door has resolved its type. Examination is
therefore **downstream of ingestion, never inside it** — an ingestion door must not block on a scanner,
or a slow examination becomes an upload outage.

**Provider.** Engineering selection under the Provider Independence Doctrine: a **self-hosted tier-0
default is required**; external providers are **tier-1 enrichment only** and may never be load-bearing.
This is not a founder decision unless a candidate would violate provider independence, privacy, data
custody or another frozen boundary.

**Interim state.** F137 requires *an explicit product-visible interim state for unexamined objects*.
Three states are therefore distinguishable and none may be silently collapsed:

```
NOT_YET_EXAMINED    → honest: nothing has looked at this yet
EXAMINED_CLEARED    → a verdict exists and permits delivery
QUARANTINED         → a verdict exists and delivery is stopped (reversible)
```

`NOT_YET_EXAMINED` must **not** render as cleared. Doing so would make the backfill population look
examined, which is the exact dishonesty the interim-state requirement exists to prevent.

## 3. PHASE 2 ARCHITECTURE — ALL APPLICABLE MEDIA CLASSES

**Phase 2 is a named CH-12 closure requirement, not an enhancement** (D4).

> **ALL APPLICABLE F137 MEDIA CLASSES MUST BE COVERED BEFORE CH-12 CLOSURE.**

Per-kind examination is required; kinds are not interchangeable. **Documents (PDF, DOCX, PPTX) are the
highest-risk and least-covered kind** — and F016 already records that the product does not honestly
understand documents today, so Phase 2 carries an F016 dependency that Phase 1 does not.

A class may leave scope **only** with documented evidence that it is technically or policy-wise outside
F137's canonical scope. Silent exclusion is forbidden.

---

## 4. QUARANTINE / APPEAL STATE MODEL

```
        examination verdict requires stop
NOT_YET_EXAMINED ─────────────────────────► QUARANTINED ──► appeal filed ──► UNDER_REVIEW
        │                                        │                                  │
        │ verdict permits                        │ reversal                ┌────────┴────────┐
        └──────────────► EXAMINED_CLEARED ◄──────┴─────────────────────────┤ upheld / released│
                                                                           └─────────────────┘
```

**Invariants, each traceable to a frozen statement:**

1. **QUARANTINED is retention, never deletion.** The bytes survive. (F137 adequacy)
2. **No terminal state is reachable by timer.** Unresolved review must neither become permanent removal
   nor auto-release. (D3 timing)
3. **A reversal leaves no residue.** No invisible permanent penalty may survive a successful reversal. (D3)
4. **Verdicts are evidence.** A superseded verdict is retained, not overwritten — adjudication data is
   never patched to tidy a queue. (CH-15 destructive boundary)
5. **An automated verdict is never final adjudication on its own.** (D3)

## 5. AUTHORITY BOUNDARIES

| Question | Authority |
|---|---|
| What is prohibited | **CH-15** (D1 taxonomy) |
| What consequence applies | **CH-15** (D2 ratified ladder) |
| Whether delivery stops | **CH-15 policy**, enforced by **CH-12** mechanism |
| Who may appeal | **CH-15** — canonical content authority, **never** possession of an id, URL or reference (D3, and D7's frozen rule) |
| Final disposition of an appeal | **Human review** (D3) |
| How an object is examined | **CH-12** |
| Where bytes live and how they are delivered | **CH-12** (PB-07) |

**Appeal standing is the place this is most likely to go wrong.** D7 established that URL possession
confers no authority. The same rule governs here: knowing a media id does not make you its author.

## 6. PERSISTENCE REQUIREMENTS *(specification — no schema authored)*

- A verdict record: subject object, examined-at, provider tier, resolved category (CH-15 vocabulary),
  disposition, and whether it was automated. **Append-only.**
- A quarantine state on the object, distinguishable from `NOT_YET_EXAMINED`.
- An appeal record: subject, appellant, filed-at, status, resolver, outcome, resolved-at.
- An audit trail sufficient to reconstruct *who decided what, when, and on what evidence*.

**Migration requirements.** Additive only. **Any interim state must default to `NOT_YET_EXAMINED`, never
to cleared** — a default of "cleared" would silently declare the entire pre-existing population examined,
manufacturing exactly the false completion F137 exists to prevent. Backfill is a **separate, guarded,
observable operation**, never part of the deploy path (the migration-verification lesson already on
record).

## 7. API AND UI CONTRACT REQUIREMENTS

**API.** Submit-for-examination is internal, not a public endpoint. Verdict and quarantine state are
readable by the content authority. Appeal intake is authenticated and authority-checked. **Errors must
not disclose whether another person's object exists** — the D7 oracle rule applies unchanged.

**UI contract.** The eight D3 notice elements must be *presentable*: what was quarantined · that use is
restricted · the canonical category · that it was automated · non-sensitive context · preliminary vs
final · how to appeal · current status. Detector internals, thresholds and anything enabling evasion are
**excluded from the contract**, not merely omitted from a screen.

## 8. FAILURE SEMANTICS

| Failure | Required behaviour |
|---|---|
| Provider unavailable | Object stays `NOT_YET_EXAMINED`. **Never** auto-cleared. |
| Provider returns garbage | Treated as no verdict, not as a clear verdict. |
| Examination times out | No verdict. Retryable. Not a silent pass. |
| Appeal queue unavailable | Quarantine persists; the person is still told how to appeal. |
| Backfill interrupted | Resumable; partial completion never reported as coverage. |

Every row is the same rule: **absence of a verdict is never evidence of safety.**

## 9. TEST MATRIX AND FIXTURES *(specified, not written)*

**Rejection fixtures** — each a real violating case: a known-malicious sample refused delivery end to
end; a quarantined object proven undeliverable through *every* delivery path, not one; a verdict proven
appealable and reversible; a reversal proven to leave no residue.

**Counter-check fixtures** — legitimate content of each examined kind still uploads and delivers; an
unexamined object is presented honestly rather than blocked or falsely cleared.

**Backfill fixtures** — objects uploaded *before* the scanner existed receive verdicts; partial backfill
never reports as complete.

**Every gate must be demonstrated to FAIL on a seeded violation before it counts as enforcement**
(FD-13). This is now a standing requirement with three precedents in this programme.

## 10. DETERMINISTIC CLOSURE CRITERIA

CH-12 may close only when **all** hold:

1. Phase 1 image examination live-certified.
2. **Phase 2 — every applicable media class covered**, or a class documented out of scope with evidence.
3. Backfill proven over the pre-existing population.
4. A known-malicious sample **refused delivery end to end**.
5. A deliberately induced false positive proven **appealable and reversed**, with no residue.
6. The interim state proven product-visible and honest.
7. G1 leg 5 discharged — **including 5(B)**.
8. F138 governed delivery satisfied, so a verdict can actually stop bytes.
9. Shared-system health reported across both repositories (PB-12).

**Not closure conditions:** a green suite · a deployed scanner · a provider integration · Phase 1 alone.

---

## WHAT THIS PACKAGE IS NOT

It authorises nothing. It selects no provider. It writes no schema, no migration and no code. It does
not weaken, reinterpret or route around G1 leg 5(B), which remains CH-12's real and unmoved dependency.
