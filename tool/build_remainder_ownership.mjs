#!/usr/bin/env node
// W1-B REMAINDER OWNERSHIP REGISTER
//
// CH-01's frozen foundation debt is recorded in test/product/c0_drift_baseline.txt
// as counts. A count is not an obligation: it says how much is left, not who
// retires it or on what condition. This tool converts the baseline into an
// owner + retirement-condition record, and FAILS CLOSED on any file it cannot
// attribute rather than guessing an owner.
import { readFileSync, writeFileSync } from 'node:fs'

const BASELINE = 'test/product/c0_drift_baseline.txt'
const OUT = 'docs/portfolio/run/stage0-2026-08-18/05-execution/w1b-remainder-ownership.json'

// Feature area -> owning chapter. Derived from the 17-chapter architecture.
// Every area present in the baseline must appear here; an unmapped area is a
// hard failure, never a default.
const AREA_OWNER = {
  activity: 'CH-05',
  admin: 'PD-1',
  announcements: 'CH-07',
  'app/shell': 'CH-02',
  auth: 'CH-02',
  communications: 'CH-07',
  conversations: 'CH-06',
  correspondence: 'CH-07',
  devices: 'CH-04',
  direct_threads: 'CH-06',
  home: 'CH-03',
  institutions: 'CH-08',
  invitations: 'CH-07',
  me: 'CH-03',
  meetings: 'PB-01',
  messages: 'CH-06',
  monetization: 'CH-16',
  notifications: 'CH-05',
  posts: 'CH-14',
  profile: 'CH-03',
  public: 'CH-10',
  realtime: 'CH-04',
  saves: 'CH-14',
  'screens/contact_screen.dart': 'CH-10',
  search: 'CH-14',
  'shared/media': 'CH-12',
  support: 'CH-17',
  updates: 'CH-05',
  'widgets/note_card.dart': 'CH-14',
}

// Retirement condition per rule. This is the condition under which the debt
// may leave the register - not a deadline and not a priority.
const RETIREMENT = {
  G2: 'Retired when the surface consumes AuraTemporal.humanize(ProductTime(instant, TimeEvent.x)) so the event semantics travel with the instant. Precedent: updates_screen G2 6 -> 0 (C2 §12, 2026-08-16).',
  G3: 'Retired when the surface uses ProductTime.local for presentation, or AuraTemporal.zoneId where a zone identifier is sent or stored. local_timezone.dart is PRESERVED as an interface until its last caller is burnt down (CO-RC-C0-021).',
  G4: 'Retired when the surface renders AuraProductState(state: ProductState.loading). Inline progress (strokeWidth, or a box <= 32px) is legitimately local and was never debt.',
  G5: 'Retired when the surface says what is TRUE via AuraProductState(state: ProductState.x) instead of constructing AuraLoading/Empty/ErrorState itself. CO-RC-C0-019 preserves the three primitives as the authority composes them - they are not deleted, only stopped being constructed directly.',
  G7: 'Retired when the DateTime-to-human-string function moves to the Human Temporal Presentation Authority. relative_time.dart is a temporal-authority shim PRESERVED as an interface while its callers burn down; CH-01 owns its retirement condition (CO-RC-C0-013, CO-RC-C0-020).',
}

// Owners that are NOT executable chapters. Recorded explicitly so that
// "unowned" and "owned by something that is not a chapter" never look alike.
const NON_CHAPTER_OWNER = {
  'PD-1': 'Platform Administration disposition is OPEN and has NO owning chapter in the approved roadmap (CO-RC-C11-005). This debt cannot be assigned to a chapter until the founder disposes PD-1.',
  'PB-01': 'Meetings is a PROTECTED CERTIFIED SURFACE. CO-RC-C0-008 affirmatively PROHIBITS modifying it for foundation debt reduction. This debt is frozen BY RULE and is not scheduled for retirement by any chapter.',
}

const rows = []
const unmapped = new Set()
for (const raw of readFileSync(BASELINE, 'utf8').split(/\r?\n/)) {
  const line = raw.trim()
  if (!line || line.startsWith('#')) continue
  const [rule, count, path] = line.split(/\s+/)
  if (!rule || !count || !path) throw new Error('FAIL-CLOSED: unparsable baseline line: ' + line)
  const parts = path.split('/')
  const area = parts[1] === 'features' ? parts[2] : parts.slice(1, 3).join('/')
  const owner = AREA_OWNER[area]
  if (!owner) { unmapped.add(area); continue }
  if (!RETIREMENT[rule]) throw new Error('FAIL-CLOSED: no retirement condition for rule ' + rule)
  rows.push({
    rule,
    sites: Number(count),
    path,
    area,
    owner,
    ownerIsExecutableChapter: !NON_CHAPTER_OWNER[owner],
    ownerNote: NON_CHAPTER_OWNER[owner] || null,
    retirementCondition: RETIREMENT[rule],
  })
}
if (unmapped.size) throw new Error('FAIL-CLOSED: unattributed areas: ' + [...unmapped].join(', '))

const byRule = {}, byOwner = {}
for (const r of rows) {
  byRule[r.rule] = byRule[r.rule] || { files: 0, sites: 0 }
  byRule[r.rule].files++; byRule[r.rule].sites += r.sites
  byOwner[r.owner] = byOwner[r.owner] || { files: 0, sites: 0 }
  byOwner[r.owner].files++; byOwner[r.owner].sites += r.sites
}

const frozenByRule = rows.filter((r) => !r.ownerIsExecutableChapter)
const out = {
  type: 'W1B_REMAINDER_OWNERSHIP_REGISTER',
  unit: 'W1-B',
  date: '2026-08-18',
  source: BASELINE,
  principle:
    'A count states how much debt remains. An obligation states WHO retires it and UNDER WHAT CONDITION. CH-01 owns the measurement and the ratchet; it does not own the burn-down of surfaces other chapters own.',
  totals: {
    files: rows.length,
    sites: rows.reduce((a, r) => a + r.sites, 0),
    byRule,
    byOwner,
  },
  frozenByRuleNotBySchedule: {
    count: frozenByRule.length,
    sites: frozenByRule.reduce((a, r) => a + r.sites, 0),
    explanation:
      'These carry an owner that is not an executable chapter. They are NOT unowned, and they are NOT scheduled. Reporting them as remaining debt without this distinction would read as neglect.',
    owners: NON_CHAPTER_OWNER,
  },
  rows,
}
writeFileSync(OUT, JSON.stringify(out, null, 1))
console.log('files:', rows.length, ' sites:', out.totals.sites)
console.log('byRule :', JSON.stringify(byRule))
console.log('byOwner:', JSON.stringify(byOwner))
console.log('frozen-by-rule (PB-01/PD-1):', frozenByRule.length, 'files /', out.frozenByRuleNotBySchedule.sites, 'sites')
console.log('OK ->', OUT)
