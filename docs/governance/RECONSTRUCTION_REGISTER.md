# AURA RECONSTRUCTION REGISTER — NON-SHRINKING

> **GENERATED — DO NOT EDIT BY HAND.**
> Source: `aura_final/docs/portfolio/run/stage0-2026-08-18` · Generator: `aura_final/tool/build_governance_mechanism.mjs`
> Regenerate rather than edit. A hand-edit is indistinguishable from a silent shrink.

**Canonical accounting: 143 findings + 308 chartered obligations = 451 units across 17 chapters.**

---

## THE RULE (F115)

**The register may never shrink.** An item leaves only by reaching a **terminal state** — never
by being implemented, deployed, green, merged, superseded in conversation, or judged a duplicate.

Three corollaries, each of which has already been violated once and is therefore written down:

1. **F119 — implemented capabilities must not vanish from reporting.** Capabilities that were
   implemented, some live-certified, disappeared from later reporting. Re-appearing later as
   "new work" is the failure mode this rule exists to prevent.
2. **F120 — every item reaches a terminal state.** *Implemented, deployed and test-green are
   not terminal.* An item with no terminal state is still owed, however finished it looks.
3. **Duplicate never means erase.** Where two findings share a root cause or a chapter, the
   relationship is recorded as an annotation. F064 and F113 are the standing precedent: **two
   separate canonical findings**, cross-referenced, never merged.

### Terminal states

- `LIVE_CERTIFIED`
- `RETIRED_BY_RULING`
- `SUPERSEDED_BY_RULING`
- `FOUNDER_CLOSED`

### States that look terminal and are not

- `IMPLEMENTED_NOT_LIVE_CERTIFIED`
- `PARTIALLY_VALIDATED`
- `STRUCTURALLY_CLOSED_NOT_LIVE_CERTIFIED`
- `CONFLICTING_CURRENT_STATE`
- `OPEN`

---

## CURRENT STATE DISTRIBUTION (143 findings)

| State | Count | Terminal? |
|---|---:|---|
| `OPEN` | 57 | **NO** |
| `IMPLEMENTED_NOT_LIVE_CERTIFIED` | 30 | **NO** |
| `LIVE_CERTIFIED` | 24 | YES |
| `PARTIALLY_VALIDATED` | 18 | **NO** |
| `C4_OWNED_OPEN` | 6 | **NO** |
| `CONFLICTING_CURRENT_STATE` | 3 | **NO** |
| `BLOCKED` | 2 | **NO** |
| `EXPLICITLY_RETIRED` | 2 | **NO** |
| `STRUCTURALLY_CLOSED_NOT_LIVE_CERTIFIED` | 1 | **NO** |

---

## PRESERVED CONFLICTS — REPORT AT EVERY CLOSURE, ITEM BY ITEM

These carry contradictory recorded states. The founder ruling is **PRESERVE BOTH READINGS**.
A chapter-level roll-up that conceals them is the exact failure this register exists to prevent.

| ID | Title | Recorded state | Ruling |
|---|---|---|---|
| **F043** | Timer before establishment | `CONFLICTING_CURRENT_STATE` | PRESERVE — do not adjudicate for cleaner counts |
| **F051** | Avatar missing in chat | `CONFLICTING_CURRENT_STATE` | PRESERVE — do not adjudicate for cleaner counts |
| **F122** | Wire-kind inconsistency between canonical wireKind and conversation_screen | `CONFLICTING_CURRENT_STATE` | PRESERVE — do not adjudicate for cleaner counts |

### F139 — TWO DIMENSIONS, REPORTED SEPARATELY

**Identity media is orphaned at upload and reaper-deletable while in active identity use**

Founder ruling: **PRESERVE BOTH READINGS.** The two candidate states are
`STRUCTURALLY_CLOSED_NOT_LIVE_CERTIFIED` and `OPEN`, and the open question — *genuinely
contradictory current states, or different dimensions of completion/certification?* — is
**not adjudicated**.

Every closure touching F139 reports **both dimensions separately**:

| Dimension | Question | May be reported as |
|---|---|---|
| **Structural** | Is the logical defect closed in code? | closed / not closed |
| **Live certification** | Has it been proven on the live system? | certified / NOT certified |

Reporting one dimension as "F139 status" is a governance violation.

---

## CHAPTERS

| Chapter | Name | Findings | Obligations |
|---|---|---:|---:|
| CH-01 | Product Foundations & Conformance | 0 | 42 |
| CH-02 | Continuity & Destination Authority | 16 | 17 |
| CH-03 | Identity Consumption & Presentation Truth | 9 | 32 |
| CH-04 | Realtime Substrate, Devices & Shared Presentation | 26 | 32 |
| CH-05 | Attention, Notification Preference & Personal Controls | 6 | 31 |
| CH-06 | Conversation & Messaging Core | 5 | 4 |
| CH-07 | Threads, Spaces & Institutional Communication | 0 | 21 |
| CH-08 | Institution Room | 0 | 17 |
| CH-09 | Live as a Governed Mode | 24 | 16 |
| CH-10 | Public Acquisition & Anonymous Access | 8 | 2 |
| CH-11 | Content Truth & Ingestion Governance | 9 | 2 |
| CH-12 | Media Custody, Delivery & Processing | 13 | 0 |
| CH-13 | Composition, Intake & Rich Presentation | 12 | 26 |
| CH-14 | Publication, Discovery & Public Entry | 8 | 11 |
| CH-15 | Trust, Safety & Moderation Authority | 1 | 1 |
| CH-16 | Cross-Platform, Native Surfaces & Release Delivery | 2 | 28 |
| CH-17 | Governance, Certification & Release Gate | 4 | 26 |

---

## WHAT MAY NEVER HAPPEN TO THIS REGISTER

- Removing an item because it is implemented, green, deployed or merged.
- Promoting a state on unit-test or architectural evidence. A lower certification layer passing
  never implies a higher one.
- Collapsing a preserved conflict to a single state to make a count read cleanly.
- Destabilising a certified suite to manufacture coverage.
- Reporting a chapter roll-up in place of the item-level rows required above.
