# FIRST EXECUTABLE WAVE — PART 1 EXECUTION RECORD

**Authorized:** W1-000, W1-A, W1-B, W1-F — non-mutating; no protected crossing; no production, CORS, migration, R2 or deployment action.
**Status:** **ALL FOUR UNITS EXECUTED.** No chapter closed. Part 2 (CH-02 keystone) remains gated on PD-2.
**Date:** 2026-08-18 · Baseline: 143 findings + 308 obligations = **451 units** · 17 chapters

---

## Headline

The suites were **not green when this wave began**, and the audit confirms F053's finding with evidence.
Both facts were discovered by the two units whose whole purpose is to look before anything is built.

| | Finding |
|---|---|
| **1** | The C0 foundation ratchet was **RED**: new drift had entered `realtime_lobby_screen.dart`. Repaired. |
| **2** | `realtime_room_golden_test.dart` is **entirely skipped** for pre-existing rot — the realtime room's *rendered appearance* is unverified by any automated proof, invisible behind 333 passing realtime tests. |
| **3** | The identity audit enumerated **335 consumers**; **99 non-conformant** and **103 surfaces reading identity off raw maps**. F053's claim is confirmed, not merely restated. |
| **4** | **83 of 270** foundation-debt sites are frozen **by rule** (PB-01 prohibition / PD-1 unowned), not merely unscheduled. |
| **5** | The Meetings regression target recorded in governance ("97/97") is **stale** — the current suite is **118**. |

---

## W1-000 — Shared-system baseline evidence · PBCR conditions 7 and 8

**DISCHARGED.** Evidence: `05-execution/w1-000-shared-system-health-report.json`; doctrine updated at
`PORTFOLIO_GOVERNANCE_DOCTRINE.md` §7.1.

**Prerequisite verified:** RC-A `509230a` and RC-B `dfc9027` both present and ancestors of HEAD.

| Subsystem | Result |
|---|---|
| Meetings (PB-01) | **118 PASS** — 90 backend / 28 frontend |
| Realtime transport (PB-02) | **333 PASS** — 290 backend / 43 frontend |
| Backend (whole) | **192 suites / 2426 tests PASS** |
| Frontend (whole) | **578 PASS / 0 fail / 1 skip** — after the W1-B repair; it was **1 FAIL** before |
| Cross-repository (PB-12) | **Satisfied for the first time in this programme** — both repos reported together for one closure |

**DEFECT-1 — reported, not repaired.** `test/realtime_room_golden_test.dart` carries
`@Skip('Pre-existing rot — RealtimeRoomScreen fixtures drifted…')`. The 333 passing realtime tests
cover semantics and lifecycle, **not presentation**. Reviving the goldens is CH-04 territory and is
not authorized in this wave. *A green realtime suite must not be read as covering realtime presentation.*

**Stale figure reported, not retro-fitted.** 118 was not presented as "97/97", and 97 was not rewritten
to 118. Left for founder disposition.

**Not discharged by this:** AD-CON-5, SU-5, VS-02, CH-04 entry. Conditions 7 and 8 are discharged; the
chapter is not.

---

## W1-A — CH-17 governance mechanism *(mechanism half only)*

Generated into **both repositories** from canonical artifacts by `tool/build_governance_mechanism.mjs`,
so the governed markdown cannot drift from canon:

- `docs/governance/RECONSTRUCTION_REGISTER.md`
- `docs/governance/CHAPTER_CLOSURE_TEMPLATE.md`

The register publishes the non-shrinking rule (**F115**) — which until now existed *only in transcript
evidence*, while 115 of 143 findings are themselves transcript-only — together with its two corollaries
(**F119** implemented capabilities must not vanish; **F120** every item reaches a terminal state), the
terminal-state vocabulary, and the **states that look terminal and are not**.

The closure template makes mandatory, per closure:
- **item-level** rows (a chapter roll-up does not satisfy it)
- **F043 / F051 / F122** reported individually even when untouched — silence is not a report
- **F139 in both dimensions separately** (structural closure ≠ live certification)
- five certification layers stated **independently** — a lower layer never implies a higher one
- **PB-12** both-repository reporting, and **FD-13** seeded-failure proof, as checkboxes

It constructs no product capability. That is an explicit non-goal.

---

## W1-B — CH-01 foundation adoption and ratchets

**Ratchets green.** 34 assertions across the three gate suites.

**One real repair.** `realtime_lobby_screen.dart` had introduced a raw full-surface
`CircularProgressIndicator` outside the state authority — the ratchet caught it. Replaced with
`AuraProductState(state: ProductState.loading, subject: ProductNoun.live)`. Presentation only: no
transport, no session semantics, no Meetings surface.

**FD-13 seeded-failure proof — 8/8 ENFORCING.** `tool/ratchet_seeded_failure_proof.mjs` seeds a *real*
violation of each rule, runs only that ratchet, asserts it **fails**, removes the seed, and asserts it
returns green. A green ratchet that has never been shown to fail is not enforcement.

| | G2 elapsed-time · G3 `toLocal()` · G4 surface spinner · G5 state primitives · G7 local formatter · R1 role-derived booleans · R2 role literals · C3 route resolution |
|---|---|

*Both harness bugs found this way were mine, not the ratchets': Windows argument quoting, and a seed
using `Navigator.pushNamed` where the collector scans `context.push`. The ratchets detected every real
violation once the seeds were real.*

**Remainder ownership — counts converted to obligations.** `tool/build_remainder_ownership.mjs` maps all
**139 files / 270 sites** of frozen debt to an owner **and a retirement condition**, failing closed on any
file it cannot attribute.

| Owner | Files | Sites |
|---|---:|---:|
| CH-08 | 34 | 63 | 
| **PD-1** *(no owning chapter exists)* | 22 | 52 |
| CH-07 | 19 | 34 | 
| **PB-01 Meetings** *(modification prohibited)* | 22 | 31 |
| CH-06 | 8 | 21 |
| CH-03 | 7 | 18 |
| CH-10 | 7 | 16 |
| CH-05 · CH-14 · CH-04 · CH-02 · CH-12 · CH-16 · CH-17 | 20 | 35 |

**83 of 270 sites are frozen BY RULE, not unscheduled** — `CO-RC-C0-008` prohibits touching certified
Meetings for foundation-debt reduction, and PD-1 has no owning chapter (`CO-RC-C11-005`). Reporting them
as ordinary remaining debt would read as neglect.

---

## W1-F — CH-03 enumerated consumer audit *(read-only)*

`tool/identity_consumer_audit.mjs` · **335 consumers enumerated across both repositories**, each row
carrying file, line and evidence so any verdict is checkable without rerunning it.

| Verdict | Count |
|---|---:|
| `CONFORMANT` | 41 |
| `NON_CONFORMANT` | **99** |
| `ADHOC_MAP_EXTRACTION_IN_SURFACE` | **103** |
| `TYPED_DESERIALIZATION_BOUNDARY` | 75 |
| `OUT_OF_SCOPE_INSTITUTION_IDENTITY` | 12 |
| `AUTHORITY` | 5 |

The two ad-hoc categories are **deliberately separated**. Deserialising a person inside a model or
repository is a legitimate boundary; a **widget** reading `user['displayName']` off a raw map is the F057
class of defect and the direct subject of F053. Reporting them as one number would have hidden which is which.

**F053 is confirmed with evidence.** The backend now has a canonical authority (`PERSON_IDENTITY_SELECT` /
`projectPersonIdentity`, founder decision D3); **99 sites hand-pick person fields without composing it.**
The certification note "AuraAvatar is being consumed consistently" holds *for AuraAvatar* — 41 conformant
sites — but avatar consumption was never the whole of F053.

**Six person-shaped extraction sites (`CO-RC-C2-010`) reconciled:** 4 located; **2 — `invite_member` and
`member_home` — carry no identity-consumer signal at all**, so the recorded extraction is gone. Stated
carefully: a static scan showing no signal does **not** prove conversion to canonical consumption. CH-03
confirms at W2.

**Nothing was changed.** No consumer edited, no image rendered, no rendered-image evidence claimed — that
half stays CORS-blocked in W2.

---

## Reconciliation — PASS

| Suite | Result |
|---|---|
| `stage4-proof.mjs` (R1–R9) | **PASS** |
| `validate-portfolio-v2.mjs` (17 invariants) | **PASS** |
| `validate-stage5.mjs` (18 invariants) | **PASS** |
| `fixtures-fail-closed.mjs` | **15/15** |
| `derive-first-wave.mjs` | re-derived unchanged |

143/143 findings · 308/308 obligations · 451/451 units · 17/17 chapters. **No state promoted. No gate
weakened. No boundary crossed.**

---

## What is NOT claimed

- **No chapter closed.** CH-01 and CH-17 are continuous; CH-03 entered only its audit partition.
- **No finding closed.** F116 and F053 remain `PARTIALLY_VALIDATED` — the audit is F116's exit-condition
  *input*, and PB-05 forbids closing it by fixing one consumer.
- **F115 is not closed.** The rule now having a home is not the rule having governed a closure.
- **CH-04 is not entered.** Conditions 7 and 8 are discharged; AD-CON-5, SU-5, VS-02 and real devices remain.
- **No live proof of anything.** Every result here is local and static.

## Carried to the founder

1. **PD-2** — still the single blocker on Part 2 and the whole CH-02 keystone.
2. **DEFECT-1** — realtime room goldens skipped; assign to CH-04 or accept the gap knowingly.
3. **Meetings 97/97 vs 118** — disposition of the stale figure.
4. **PD-1** — 52 debt sites have no owning chapter until it is disposed.
