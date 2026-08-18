#!/usr/bin/env node
// W1-A — CH-17 GOVERNANCE MECHANISM (mechanism half only).
//
// Generates the non-shrinking register and the chapter-closure template into
// BOTH repositories, from the canonical portfolio artifacts, so the governed
// markdown cannot drift from canon. It constructs NO product capability —
// that is an explicit non-goal of this half of CH-17.
//
// F115 (non-shrinking register) currently exists only in transcript evidence,
// and 115 of 143 findings are evidenced only in transcripts. This gives the
// rule a governed home in the repositories that must obey it.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs'
import { resolve } from 'node:path'

const RUN = 'docs/portfolio/run/stage0-2026-08-18'
const REPOS = [
  'C:/Users/muham/flutter_projects/aura/aura_final',
  'C:/Users/muham/flutter_projects/aura/aura-backend',
]
const rd = (p) => JSON.parse(readFileSync(resolve(RUN, p), 'utf8'))

const chapters = rd('05-execution/index-chapters.json').chapters
const cls = Object.fromEntries(
  rd('03-synthesis/co-classification-v2.json').classifications.map((o) => [o.id, o]),
)
const findings = {}
for (const b of ['1', '2', '3']) {
  const d = rd(`00-evidence/findings-batch-${b}.json`)
  for (const f of (d.findings || d)) findings[f.id] = f
}

const totalF = Object.keys(findings).length
const totalCO = Object.keys(cls).length
if (totalF !== 143) throw new Error('FAIL-CLOSED: expected 143 findings, got ' + totalF)
if (totalCO !== 308) throw new Error('FAIL-CLOSED: expected 308 obligations, got ' + totalCO)

// ── Terminal-state vocabulary (F120: every item reaches a terminal state) ────
const TERMINAL = ['LIVE_CERTIFIED', 'RETIRED_BY_RULING', 'SUPERSEDED_BY_RULING', 'FOUNDER_CLOSED']
const NON_TERMINAL_LOOKALIKES = [
  'IMPLEMENTED_NOT_LIVE_CERTIFIED', 'PARTIALLY_VALIDATED', 'STRUCTURALLY_CLOSED_NOT_LIVE_CERTIFIED',
  'CONFLICTING_CURRENT_STATE', 'OPEN',
]

const stateCounts = {}
for (const f of Object.values(findings)) stateCounts[f.currentState] = (stateCounts[f.currentState] || 0) + 1

const PRESERVED_CONFLICTS = ['F043', 'F051', 'F122']
const conflictRows = PRESERVED_CONFLICTS.map((id) => {
  const f = findings[id]
  return `| **${id}** | ${f.title} | \`${f.currentState}\` | PRESERVE — do not adjudicate for cleaner counts |`
}).join('\n')

const register = `# AURA RECONSTRUCTION REGISTER — NON-SHRINKING

> **GENERATED — DO NOT EDIT BY HAND.**
> Source: \`aura_final/${RUN}\` · Generator: \`aura_final/tool/build_governance_mechanism.mjs\`
> Regenerate rather than edit. A hand-edit is indistinguishable from a silent shrink.

**Canonical accounting: ${totalF} findings + ${totalCO} chartered obligations = ${totalF + totalCO} units across ${chapters.length} chapters.**

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

${TERMINAL.map((s) => `- \`${s}\``).join('\n')}

### States that look terminal and are not

${NON_TERMINAL_LOOKALIKES.map((s) => `- \`${s}\``).join('\n')}

---

## CURRENT STATE DISTRIBUTION (${totalF} findings)

| State | Count | Terminal? |
|---|---:|---|
${Object.entries(stateCounts).sort((a, b) => b[1] - a[1])
  .map(([s, n]) => `| \`${s}\` | ${n} | ${TERMINAL.includes(s) ? 'YES' : '**NO**'} |`).join('\n')}

---

## PRESERVED CONFLICTS — REPORT AT EVERY CLOSURE, ITEM BY ITEM

These carry contradictory recorded states. The founder ruling is **PRESERVE BOTH READINGS**.
A chapter-level roll-up that conceals them is the exact failure this register exists to prevent.

| ID | Title | Recorded state | Ruling |
|---|---|---|---|
${conflictRows}

### F139 — TWO DIMENSIONS, REPORTED SEPARATELY

**${findings.F139.title}**

Founder ruling: **PRESERVE BOTH READINGS.** The two candidate states are
\`STRUCTURALLY_CLOSED_NOT_LIVE_CERTIFIED\` and \`OPEN\`, and the open question — *genuinely
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
${chapters.map((c) => `| ${c.id} | ${c.name} | ${c.findings.count} | ${c.obligations.count} |`).join('\n')}

---

## WHAT MAY NEVER HAPPEN TO THIS REGISTER

- Removing an item because it is implemented, green, deployed or merged.
- Promoting a state on unit-test or architectural evidence. A lower certification layer passing
  never implies a higher one.
- Collapsing a preserved conflict to a single state to make a count read cleanly.
- Destabilising a certified suite to manufacture coverage.
- Reporting a chapter roll-up in place of the item-level rows required above.
`

// ─────────────────────────────────────────────── CHAPTER CLOSURE TEMPLATE ────
const template = `# CHAPTER CLOSURE TEMPLATE

> Copy this file per chapter closure. **Every section is required.** A section answered
> "N/A" must say *why* it is not applicable — an empty section is an incomplete closure.
>
> Governed by \`RECONSTRUCTION_REGISTER.md\`. Generated by
> \`aura_final/tool/build_governance_mechanism.mjs\`; do not edit the template in place.

## 0. Identity

- **Chapter:** CH-__ ·  **Name:** ______
- **Closure date:** ______ ·  **Founder authorization reference:** ______

## 1. Item-level state — NOT a roll-up

One row per canonical unit the chapter owns. A chapter-level summary does **not** satisfy this.

| Unit ID | Title | State at entry | State at closure | Terminal? | Evidence reference |
|---|---|---|---|---|---|

**Every non-terminal row needs a named owner and a condition.** "Remaining" is not a disposition.

## 2. Preserved conflicts — MANDATORY, even when untouched

| ID | Reported at this closure | Still preserved? |
|---|---|---|
| F043 Timer before establishment | | |
| F051 Avatar missing in chat | | |
| F122 Wire-kind inconsistency | | |

If this chapter did not touch them, say so explicitly. Silence is not a report.

## 3. F139 — both dimensions, separately

| Dimension | Status at this closure | Evidence |
|---|---|---|
| Structural closure | | |
| Live certification | | |

## 4. Certification layers earned

A lower layer passing never implies a higher one. State each independently.

| Layer | Earned? | Evidence | If not earned, why |
|---|---|---|---|
| Architecture | | | |
| Implementation | | | |
| Product Behaviour (observed on a real surface — never asserted from a lint count) | | | |
| Cross-System | | | |
| Real-Boundary | | | |

## 5. Ratchets and suites

- [ ] Backend and frontend suites reported **TOGETHER** for this closure (PB-12). Neither
      repository silently diverges.
- [ ] Every ratchet introduced or relied on has a recorded **seeded-violation failure**
      (FD-13). A green ratchet that has never been shown to fail is not enforcement.
- [ ] Any frozen baseline the chapter reduced has been **updated**, so the register does not
      overstate remaining debt.

| Suite / ratchet | Result | Seeded-failure proof |
|---|---|---|

## 6. Protected and shared boundaries

| Boundary | Reached? | Crossed? | Authorization | PBCR conditions discharged |
|---|---|---|---|---|

**Reached is not crossed.** Where a crossing occurred, all applicable PBCR conditions are
listed with their evidence — including conditions 7 (targeted regression) and 8 (shared-system
health report).

## 7. What is NOT claimed

Explicitly list what this closure does **not** establish. A closure that claims nothing it did
not prove is worth more than one that reads as complete.

## 8. Founder acts consumed

| Act | Date | Reference |
|---|---|---|

## 9. Continuity

- [ ] \`CURRENT_STATE\` updated in both repositories
- [ ] \`DECISIONS\` updated with any ruling applied
- [ ] \`HANDOFF\` / \`NEXT_WORK\` updated
- [ ] \`RECONSTRUCTION_REGISTER.md\` regenerated and the register did **not** shrink
`

let written = []
for (const repo of REPOS) {
  const dir = resolve(repo, 'docs/governance')
  mkdirSync(dir, { recursive: true })
  writeFileSync(resolve(dir, 'RECONSTRUCTION_REGISTER.md'), register)
  writeFileSync(resolve(dir, 'CHAPTER_CLOSURE_TEMPLATE.md'), template)
  written.push(`${repo}/docs/governance/RECONSTRUCTION_REGISTER.md`, `${repo}/docs/governance/CHAPTER_CLOSURE_TEMPLATE.md`)
}

const proof = {
  type: 'W1A_GOVERNANCE_MECHANISM',
  unit: 'W1-A',
  chapter: 'CH-17 (MECHANISM half only — the TERMINAL half remains W7)',
  date: '2026-08-18',
  constructsProductCapability: false,
  findingsAddressed: {
    F115: 'The non-shrinking rule now has a governed markdown home in BOTH repositories. It previously existed only in transcript evidence. NOT closed — the rule existing is not the rule having governed a closure.',
    F119: 'Recorded as a corollary with its historical failure named.',
    F120: 'Terminal vocabulary published, with the look-alike states that are NOT terminal listed explicitly.',
  },
  carries: {
    preservedConflicts: PRESERVED_CONFLICTS,
    f139Dimensions: ['structural closure', 'live certification'],
    pb12: 'Backend and frontend suites reported together is a required checkbox.',
    fd13: 'Seeded-violation proof is a required column, not an aspiration.',
  },
  accounting: { findings: totalF, obligations: totalCO, units: totalF + totalCO, chapters: chapters.length },
  filesWritten: written,
}
writeFileSync(resolve(RUN, '05-execution/w1a-governance-mechanism.json'), JSON.stringify(proof, null, 1))
console.log('accounting:', totalF, '+', totalCO, '=', totalF + totalCO, 'units /', chapters.length, 'chapters')
for (const w of written) console.log('  wrote', w)
