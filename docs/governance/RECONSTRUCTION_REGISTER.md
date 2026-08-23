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

## STAGE-0 RATIFIED STATE DISTRIBUTION (143 findings)

> **This is the FOUNDER-RATIFIED BASELINE of 2026-08-18, not a live count.** Stage-0 evidence is
> never rewritten, so this table does not move. Every later transition is recorded in the execution
> layer and printed below under **LIVE CERTIFICATIONS**, **TERMINAL CLOSURES** and **RECORDED
> NON-TERMINAL TRANSITIONS**. Reading this table alone will understate what has been done.

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

## ADMITTED EXECUTION DEFECTS (not canonical units)

Discovered while executing, governed for closure through execution provenance. Stage 0 did not
know them, so admitting one is **not** retroactively a finding: the accounting stays
**143 + 308 = 451**. They are printed here because a recorded item that disappears from
reporting comes back later looking like new work — the exact failure F119 names.

| ID | Chapter | State | Statement | Closure requirement |
|---|---|---|---|---|
| **DEFECT-1** | CH-04 | `OPEN_ASSIGNED` | Realtime rendered presentation currently lacks automated visual proof despite the broader realtime suite being green. | Restoration or replacement of meaningful realtime-room presentation verification is a CH-04 certification/closure requirement. |
| **D7-DEFECT** | CH-11 | `CLOSED_LOCALLY_NOT_LIVE_CERTIFIED` | Institution-post media authority — URL match treated as attachment and visibility authority | - |
| **ARTICLES-FIRST-CLASS-DEFECT** | CH-14 | `CLOSED` (2026-08-22, founder-certified) | Articles are not established as a first-class publication surface | Audit Articles against the canonical publication/interaction capability set - like/reaction, reply/discussion, share/reshare, translation - confirming each against the running product rather than assuming Posts are the template. |

---

## PRODUCT DISPOSITION CHECKPOINTS

Surfaces the approved roadmap never named an owner for. Each is resolved by founder ruling, and a
resolved disposition is **not** the same thing as a closed obligation — the originating records are
retained verbatim and superseded only as to current status.

### PD-2 — Authentication & Account Entry

**Status:** `RESOLVED` · **Ruled by:** FOUNDER RULING 2026-08-18

**Disposition:** RATIFIED_SPLIT — CH-02 owns STRUCTURE; CH-10 owns ACCOUNT-ENTRY EXPERIENCE.

**Supersedes:** CO-RC-C1-022 — "PD-2 STRUCTURAL DISPOSITION remains OPEN" — RETAINED VERBATIM as historical evidence; superseded as to current status only.

### PD-1 — Platform Administration

**Status:** `RESOLVED_FOR_THIS_RECONSTRUCTION_PROGRAMME` · **Ruled by:** FOUNDER RULING 2026-08-18

**Disposition:** OUT_OF_CURRENT_RECONSTRUCTION_SCOPE

**Product standing — the ruling is about RECONSTRUCTION SCOPE, not the product:**

| | |
|---|---|
| Legitimate shipped capability | YES |
| Deprecated | NO |
| Demolished | NO |
| Architecturally invalid | NO |
| Removed from Aura | NO |

**Debt:** 11 files / 52 sites, classified `FROZEN_BY_RULE / OUT_OF_CURRENT_RECONSTRUCTION_SCOPE`. Counted as ordinary executable reconstruction debt: **NO**. Ownerless-by-reconstruction is **INTENTIONAL, NOT NEGLECTED**.

> The C0 anti-drift ratchet continues to hold these counts: they may never rise, and if they fall the gate fails until the baseline is updated. Exclusion from reconstruction is NOT exclusion from measurement.

**Does not exempt:** PD-1 does NOT exempt Platform Administration from shared runtime/security authorities. CH-02 S2 fail-closed classification of /admin REMAINS APPLICABLE where the shared auth/routing boundary requires it. Scope exclusion does not create a security or shared-authority bypass.

**Readmission:** A future founder-authorized admission may explicitly bring it into reconstruction. Until then there is no retirement condition, and that absence IS the recorded disposition.

**Supersedes:** CO-RC-C11-005 — "PD-1 Platform Administration disposition (11 files / 34 G5 sites) — no owning chapter in the approved roadmap" — RETAINED VERBATIM as historical evidence; superseded as to current status only — the obligation is now DISPOSED_BY_RULING rather than REMAINING.

---

## LIVE CERTIFICATIONS (execution layer)

Recorded from founder-observed live evidence bound to a technically established deployed artifact.
Stage-0 evidence is NOT rewritten; a certification is a new evidenced fact, and it becomes a register
state transition at chapter closure. ~~**No chapter has closed.**~~ **SUPERSEDED 2026-08-22: CH-14
CLOSED, founder-certified.** No other chapter has closed. CH-13 remains IN PROGRESS with live
certification owed on F011/F125/F014/F025/F026.

| Item | Verdict | Against artifact | Limit of what is proven |
|---|---|---|---|
| **F065** | `LIVE_CERTIFIED` | deployed artifact v1.3.0+24 / code cdbae96 | Certifies the deployed contract. The unpushed S1 refinement is behaviour-neutral on these paths and is not separately certified. |
| **S2_S3_LIVE_PROBE** | `PASS 6/6` | deployed artifact v1.3.0+24 / code cdbae96 | - |
| **G1_LEG_5B** | `LIVE_CERTIFIED` | founder-observed live test, 2026-08-20 | Founder observed the predeclared leg 5(B) test: a plain-text file renamed photo.png was REJECTED live. All four predeclared properties PASS. With 5(A) already complete, G1 leg 5 is COMPLETE and F127 is live-certified ON THE D2 CONFIRM PATH ONLY. F127 D7 remains outstanding and is not covered by this. |
| **INSTITUTION_SPACES** | `LIVE_CERTIFIED` | deployed reconstructed Institution Spaces, 2026-08-20 | Founder live observation PASS across the predeclared journeys. Legacy history was neither preserved nor validated, and its absence is not a defect. Calling defects observed during the walkthrough are INHERITED, route-proven, and created no new finding. |
| **CH12_E6** | `LIVE_CERTIFIED` | backend 3faa46d / frontend daeb8fa, 2026-08-21 | Founder-observed walkthrough PASSED; backend evidence corroborates without contradiction. Certifies E6 only. It does NOT certify the chapter, and does NOT carry the web-consumer delivery leg — see CH12_WEB_CONSUMER_LEG. |
| **CH12_WEB_CONSUMER_LEG** | `CERTIFICATION_CORRECTED` | backend fc2bd71 / frontend 3f24f94, 2026-08-21 | A CORRECTION, not a pass. The earlier private-origin custody and byte-authority results remain valid, but the WEB CONSUMER leg had been incompletely certified: it proved a signed URL returned correct bytes and never exercised the Flutter Web / CanvasKit CORS-read path, where a cross-origin redirect taints Origin to null at R2. The same-origin delivery incident that followed is CLOSED, founder-verified in the released product 2026-08-21. |
---

## TERMINAL CLOSURES BY FOUNDER RULING (execution layer)

Recorded here rather than by editing Stage-0 evidence. The Stage-0 state column is the ratified
baseline and stays as it was; the terminal column is the later evidenced transition. Every state
used below is already in the register vocabulary — **no new terminal state exists**.

**`FOUNDER_CLOSED` is terminal by founder authority. It does NOT mean `LIVE_CERTIFIED`,** which is
why the certification dimension is printed separately on every row.

| Item | Stage-0 state | Terminal state | Basis | Structural | Live certification |
|---|---|---|---|---|---|
| **F017** | `PARTIALLY_VALIDATED` | `FOUNDER_CLOSED` | FOUNDER RULING 2026-08-19 | CLOSED | NOT CERTIFIED |
| **ARTICLES-FIRST-CLASS-DEFECT** | `OPEN_ASSIGNED` | `CLOSED` | FOUNDER CERTIFICATION 2026-08-22 | CLOSED — Articles carry reactions, saves, discussion, native reshare, external share with real OG, translation, notifications, blocking, moderation, Discourse Quality, retract/restore, media interaction, accessibility and canonical deep linking, each through the SHARED authority rather than an article-private copy. | CERTIFIED — founder observed the live article action row 2026-08-22, the last item requiring observation rather than a test. |
| **F137** | `OPEN` | `FOUNDER_CLOSED` | FOUNDER RULING 2026-08-21 | CLOSED - every governed media class present in production is covered at the current examiner identity, every deliverable object holds a malware pass, and the accepted envelope is examinable end to end with the deployment verified live against it. | NOT CERTIFIED as a chapter. E6 is live-certified in its own right; F137's closure is terminal by founder authority and must never be read as certifying CH-12. |

---

## RECORDED NON-TERMINAL TRANSITIONS (execution layer)

Movement since the ratified baseline that is **not** terminal. Stage-0 `currentState` is preserved
verbatim in the left column; the right column is the later evidenced state. **None of these is
terminal** — every one is still owed, however finished it looks (F120).

They are printed because the distribution table above is the RATIFIED BASELINE, not a live count.
Without this section a reader sees a 2026-08-18 snapshot and no way to reconcile it.

| Item | Chapter | Stage-0 state | Execution-layer state | Date | Basis |
|---|---|---|---|---|---|
| **F059** | CH-02 | `OPEN` | `IMPLEMENTED_NOT_LIVE_CERTIFIED` | 2026-08-19 | Named causes RC1, RC2 and RC3 all repaired. |
| **F062** | CH-02 | `OPEN` | `IMPLEMENTED_NOT_LIVE_CERTIFIED` | 2026-08-19 | Named causes RC2 and RC4 repaired, plus the RC3 screen-binding half its destination depends on. |
| **F061** | CH-02 | `OPEN` | `IMPLEMENTED_NOT_LIVE_CERTIFIED` | 2026-08-19 | RC4 repaired; RC8 proven inapplicable (its whole surface is booking/meeting entry). |
| **F063** | CH-02 | `OPEN` | `IMPLEMENTED_NOT_LIVE_CERTIFIED` | 2026-08-19 | RC7 repaired in both halves. |
| **F053** | CH-03 | `PARTIALLY_VALIDATED` | `IMPLEMENTED_NOT_LIVE_CERTIFIED` | 2026-08-20 | Founder-authorised promotion. |
| **F116** | CH-03 | `PARTIALLY_VALIDATED` | `IMPLEMENTED_NOT_LIVE_CERTIFIED` | 2026-08-20 | Founder-authorised promotion. |
| **F044** | CH-05 | `IMPLEMENTED_NOT_LIVE_CERTIFIED` | `IMPLEMENTED_NOT_LIVE_CERTIFIED` | 2026-08-20 | UNCHANGED and explicitly NOT promoted across the Phase 5 work. |

### CH-03 — 2026-08-23 consumption completion (F053 / F116 NOT closed)

Founder observed on the live Institution → Members surface that established
people rendered as generic initials. The trace found a failure mode that only
became possible AFTER the canonical model landed:

> **PARTIAL ADOPTION** — a surface calls the canonical reader, uses it for the
> name, and discards the avatar, the verification and the lifecycle. It reads
> as converged in review, because the canonical reader is right there.

Four measured surfaces converged: Institution Members, Join Requests,
Institution Activity, People Discovery. Backend upgraded from the reduced
person reference to the canonical person identity on all four, and the
projection is now APPLIED rather than only selected — `accountStatus` and
`verification` are derived, so a governed select returning a raw row emitted
neither. The client model now carries verification, so trust is part of who
someone is rather than something each surface fetches or forgets.

**STATUS UNCHANGED: `IMPLEMENTED_NOT_LIVE_CERTIFIED`.** PB-05 forbids closing
F116 by fixing one consumer, and it is equally not closed by fixing four:

- the convergence is proven by a gate that walks the whole consumer set, and
  that walk currently finds zero remaining partial adopters — but a source walk
  is not a live observation;
- Members rendering an actual avatar in production is NOT yet verified; it
  needs the deploy plus a founder or browser check;
- Institution Activity renders the actor's avatar but no trust marks, which is
  a deliberate scope boundary rather than an oversight: it presents an EVENT,
  and whether an actor's verification belongs on an audit row is a
  presentation decision the ruling did not make.

An independent finding in the same investigation was WITHDRAWN. The stored
avatar URLs were reported as a non-renderable `/media/<id>` shape; that was an
artefact of a 48-character truncation in the census query used to gather the
evidence. All six production values are the governed `/media/<id>/raw` form,
the write path already converts to it, and the door returns real image bytes.
No media-address defect existed and no production repair was required.

---

## WHAT MAY NEVER HAPPEN TO THIS REGISTER

- Removing an item because it is implemented, green, deployed or merged.
- Promoting a state on unit-test or architectural evidence. A lower certification layer passing
  never implies a higher one.
- Collapsing a preserved conflict to a single state to make a count read cleanly.
- Destabilising a certified suite to manufacture coverage.
- Reporting a chapter roll-up in place of the item-level rows required above.
