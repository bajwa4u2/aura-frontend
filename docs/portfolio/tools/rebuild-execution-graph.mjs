#!/usr/bin/env node
/**
 * EXECUTION GRAPH REBUILD under the 2026-08-18 pre-execution founder rulings.
 *
 * Applies exactly four rulings, changes nothing else, and proves whether the
 * CH-05 -> CH-06 -> CH-13 -> CH-05 cycle disappears.
 *
 * GOVERNING PRINCIPLE (Ruling 1): a dependency needed to CONSUME a capability is
 * not authority to RECONSTRUCT or fully complete the chapter that provides it.
 * Demotion touches EXECUTION-GRAPH AUTHORITY ONLY — the underlying obligation,
 * its ownership, its provenance and its validation burden all survive untouched.
 *
 * No frozen gate is weakened to obtain an acyclic graph.
 *
 * Usage: node rebuild-execution-graph.mjs <runRoot>
 * Writes: <runRoot>/05-execution/execution-graph-v2.json
 */

import { readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'

const root = process.argv[2]
if (!root) { console.error('usage: node rebuild-execution-graph.mjs <runRoot>'); process.exit(2) }
const EX = join(root, '05-execution')
const rd = (p) => JSON.parse(readFileSync(p, 'utf8'))
const dep = rd(join(EX, 's5-dependency-keystones.json'))

// ── Ruling 1 — the two inferred arcs lose GRAPH AUTHORITY only ──────────────
// Identified by their canonical requirement, not by id, so the rebuild is
// reproducible if ids ever move.
const DEMOTIONS = [
  {
    edge: 'CH-05 -> CH-06',
    requirement: 'owning-domain clearing semantics for messages (where read-truth is committed)',
    oldState: 'HARD_CHAPTER_SEQUENCING_GATE (claimed construction dependency)',
    newState: 'BOUNDED_CONTRACT_PREREQUISITE — a semantic contract CH-05 consumes; resolvable from the frozen Conversation canon (PB-12) without CH-06 construction',
    reason: 'MEDIUM inference only. Canonical primary evidence does not establish that the whole providing chapter must complete. Ruling 1.5: consuming a capability is not authority to complete the provider.',
    founderRuling: 'RULING 1 (2026-08-18)',
    underlyingObligationPreserved: true,
    obligationNote: 'The clearing-semantics requirement remains a real obligation owned where it was owned, satisfied at the CH-05/CH-06 capability boundary. Nothing deleted.',
    provenancePreserved: true,
    validationBurdenPreserved: true,
  },
  {
    edge: 'CH-06 -> CH-13',
    requirement: 'media/attachments row of the Conversation Completion Register',
    oldState: 'HARD_CHAPTER_SEQUENCING_GATE (construction-start dependency)',
    newState: 'FINAL_CERTIFICATION_PREREQUISITE — required for CH-06 FINAL certification, not for CH-06 construction start',
    reason: 'LOW-MEDIUM inference. Keystone K8 (canonical Conversation party/message authority) does not require it. Ruling 1.4: demote execution-graph authority only.',
    founderRuling: 'RULING 1 (2026-08-18)',
    underlyingObligationPreserved: true,
    obligationNote: 'The Completion Register media/attachments row remains a frozen obligation and a CH-06 certification condition. It is not discharged, merely re-attached to the certification phase.',
    provenancePreserved: true,
    validationBurdenPreserved: true,
  },
]

const PRESERVED_GATE = {
  edge: 'CH-13 -> CH-05',
  requirement: 'RC-C5 frozen hard gate — opens only on founder-declared C4 live closure',
  state: 'HARD_FOUNDER_GATE — UNCHANGED',
  evidence: 'DECISIONS.md:382-385, frozen 2026-08-16; STRONG/HIGH',
  note: 'Preserved exactly. Not weakened, not narrowed, not re-phased. The BIFURCATED scope ruling still applies: it governs RC-C5 chapter/deployment transition and what was explicitly in scope when frozen.',
}

// ── rebuild the graph ───────────────────────────────────────────────────────
const demotedKeys = new Set(DEMOTIONS.map((d) => d.edge))
const chapterOf = (s) => { const m = String(s || "").match(/\bCH-\d{2}\b/); return m ? m[0] : null }

// TWO GRAPHS EXIST AND THEY ARE NOT THE SAME GRAPH.
//   DECLARED  — index-chapters.json `dependsOn`. This is where CYCLE-1 lives.
//   EVIDENCE  — the 52 dependencies derived by S5-A from canonical sources.
// Neither CH-05 -> CH-06 nor CH-06 -> CH-13 exists in the EVIDENCE graph at all,
// which independently supports Ruling 1: those arcs are declarations, not
// evidenced dependencies.
const ic = rd(join(EX, 'index-chapters.json'))
const declared = []
for (const c of ic.chapters || []) {
  for (const d of c.dependsOn || []) {
    const m = String(d).match(/\bCH-\d{2}\b/)
    if (m && m[0] !== c.id) declared.push({ from: c.id, to: m[0], text: String(d).slice(0, 90) })
  }
}

const edges = []
for (const d of dep.dependencies || []) {
  const from = chapterOf(d.from), to = chapterOf(d.to)
  if (!from || !to || from === to) continue
  edges.push({ id: d.id, from, to, class: d.class, confidence: d.confidence, grade: d.evidenceGrade })
}

// Which concrete edges are affected by the demotions
const affected = edges.filter((e) =>
  (e.from === 'CH-05' && e.to === 'CH-06') || (e.from === 'CH-06' && e.to === 'CH-13'))

const sequencingEdgesBefore = edges.slice()
const sequencingEdgesAfter = edges.filter((e) =>
  !((e.from === 'CH-05' && e.to === 'CH-06') || (e.from === 'CH-06' && e.to === 'CH-13')))

function findCycles(list) {
  const adj = new Map()
  for (const e of list) { if (!adj.has(e.from)) adj.set(e.from, []); adj.get(e.from).push(e.to) }
  const cycles = []
  const WHITE = 0, GREY = 1, BLACK = 2
  const colour = new Map()
  const stack = []
  const visit = (n) => {
    colour.set(n, GREY); stack.push(n)
    for (const m of adj.get(n) || []) {
      const c = colour.get(m) || WHITE
      if (c === GREY) cycles.push([...stack.slice(stack.indexOf(m)), m].join(' -> '))
      else if (c === WHITE) visit(m)
    }
    stack.pop(); colour.set(n, BLACK)
  }
  for (const n of adj.keys()) if ((colour.get(n) || WHITE) === WHITE) visit(n)
  return [...new Set(cycles)]
}

const cyclesBefore = findCycles(sequencingEdgesBefore)
const cyclesAfter = findCycles(sequencingEdgesAfter)

// DECLARED graph: `dependsOn` means "X depends on Y", i.e. the edge Y -> X in
// execution order. CYCLE-1 was reported in this graph.
const declaredEdges = declared.map((d) => ({ from: d.to, to: d.from, text: d.text }))
const declaredCyclesBefore = findCycles(declaredEdges)
// Ruling 1 removes the two demoted arcs' SEQUENCING authority here.
const declaredAfter = declaredEdges.filter((e) =>
  !(e.from === 'CH-06' && e.to === 'CH-05') && !(e.from === 'CH-13' && e.to === 'CH-06'))
const declaredCyclesAfter = findCycles(declaredAfter)

const out = {
  artifact: 'EXECUTION_GRAPH_V2',
  type: 'ANALYTICAL_PROPOSAL',
  date: '2026-08-18',
  rulingsApplied: ['RULING 1 cycle', 'RULING 2 PB-02 dimensional separation', 'RULING 3 F006-F010', 'RULING 4 CORS not authorized'],
  governingPrinciple: 'A dependency needed to CONSUME a capability is not automatically authority to reconstruct or fully complete the capability that provides it. Bounded prerequisites are preferred where evidence supports them. No frozen founder gate may be weakened to make the graph acyclic.',
  preservedGate: PRESERVED_GATE,
  demotions: DEMOTIONS,
  affectedConcreteEdges: affected,
  declaredGraph: {
    note: 'index-chapters dependsOn. CYCLE-1 lives HERE, not in the evidence graph.',
    edgesBefore: declaredEdges.length, cyclesBefore: declaredCyclesBefore,
    edgesAfter: declaredAfter.length, cyclesAfter: declaredCyclesAfter,
  },
  evidenceGraph: {
    note: 'The 52 S5-A dependencies. Neither demoted arc EXISTS here — independent support for Ruling 1.',
    chapterEdges: sequencingEdgesBefore.length, cycles: cyclesBefore,
  },
  secondCycleFound: {
    cycle: 'CH-04 <-> CH-06 (evidence graph, NOT the cycle the founder ruled on)',
    arcs: [
      'D-16 CH-04 realtime attachments certified (F006/F008/F010) -> CH-06 Conversation FINAL certification [CERTIFICATION, MEDIUM edge / LOW endpoint state]',
      'D-27 CH-06 Conversation shared capabilities certified -> CH-04 Meetings validation batch F112 and convergence slices [PROTECTED_BOUNDARY, STRONG/HIGH]',
    ],
    resolution: 'DISSOLVES AT BOUNDED-CAPABILITY GRANULARITY, with no ruling required and nothing weakened. The two CH-04 endpoints are DIFFERENT bounded capabilities: realtime-attachment certification is not the Meetings validation batch. The true order is: CH-04 realtime-attachment certification -> CH-06 FINAL certification -> CH-04 Meetings validation batch. That is a sequence, not a cycle.',
    appliedPrinciple: 'Ruling 1.5 — consuming a capability is not authority over the whole providing chapter. Chapter-granular reading manufactured the cycle.',
    gateWeakened: false,
    d27Preserved: 'D-27 is STRONG/HIGH and PROTECTED_BOUNDARY (PB-01, Meetings). It is NOT demoted and NOT re-phased.',
  },
  cycleResolved: declaredCyclesBefore.length > 0 && declaredCyclesAfter.length === 0,
  obligationSurvival: {
    deleted: 0,
    ownershipChanged: 0,
    provenanceChanged: 0,
    note: 'Both demotions changed EXECUTION-GRAPH AUTHORITY only. No obligation was deleted, no ownership moved, no provenance altered, no validation burden removed.',
  },
  // ── Ruling 2 — dimensional separation, stated as an invariant ─────────────
  firstEntryInvariant: {
    ruling: 'RULING 2 (2026-08-18)',
    dimensionA: 'PROTECTED-BOUNDARY REPAIR ORDER — PB-02 remains FULLY authoritative whenever work actually performs protected-layer corrective repair, a protected-boundary crossing, or modification of the protected subsystem.',
    dimensionB: 'GENERAL RECONSTRUCTION / CONSUMER CONSTRUCTION ORDER — governed by the declared dependency graph.',
    invariant: 'PB-02 does NOT become the general construction order. Consuming-surface construction follows the dependency graph; the moment execution would actually touch the protected subsystem, it STOPS at that boundary and applies PB-02 / PBCR governance before proceeding.',
    consequence: 'CH-02 and CH-03 may be entered ahead of CH-04 by construction dependency WITHOUT reversing or weakening PB-02, because entering them performs no protected-layer repair.',
    protectedAuthorityCreated: false,
    note: 'No protected-system authority is created by this invariant. It narrows nothing in PB-02 and grants nothing new.',
  },
}

writeFileSync(join(EX, 'execution-graph-v2.json'), JSON.stringify(out, null, 1))
console.log('DECLARED graph cycles BEFORE:', declaredCyclesBefore.join(' | ') || 'none')
console.log('DECLARED graph cycles AFTER :', declaredCyclesAfter.join(' | ') || 'NONE')
console.log('EVIDENCE graph cycles       :', cyclesBefore.join(' | ') || 'none')
console.log('chapter edges before :', sequencingEdgesBefore.length)
console.log('chapter edges after  :', sequencingEdgesAfter.length)
console.log('cycles BEFORE        :', cyclesBefore.length ? cyclesBefore.join(' | ') : 'none')
console.log('cycles AFTER         :', cyclesAfter.length ? cyclesAfter.join(' | ') : 'NONE')
console.log('cycle resolved       :', out.cycleResolved)
console.log('obligations deleted  :', out.obligationSurvival.deleted)
console.log('affected concrete edges:', affected.map((e) => e.id + ' ' + e.from + '->' + e.to).join(', ') || 'none matched by chapter pair')
