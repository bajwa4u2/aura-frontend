#!/usr/bin/env node
/**
 * VALIDATOR FAIL-CLOSEDNESS FIXTURES  (governance doctrine §3.2)
 *
 * A validator must never interpret ABSENCE as SATISFACTION. These fixtures pin
 * that behaviour, including the two holes that actually occurred during Stage 3:
 * an owner emitted under a different key name (absence silently counted as
 * ownership), and a tri-state field whose omission would have read as `false`.
 *
 * Every fixture asserts a DIRECTION, not a message. Run: node fixtures-fail-closed.mjs
 */

const results = []
const t = (name, expected, actual) => results.push({ name, expected, actual, ok: expected === actual })

// ── the rules under test, mirrored from validate-stage3.mjs ────────────────
const TRISTATE_UNRESOLVED = new Set(['UNRESOLVED', 'NOT_ESTABLISHED', 'UNKNOWN'])
const CLASS_VOCAB = new Set(['COMPLETED_OR_SUPERSEDED', 'PARTIALLY_COMPLETED', 'OUTSTANDING_CONSTRUCTION',
  'VALIDATION_OR_GATE_ONLY', 'FOUNDER_ACTION_ONLY', 'UNKNOWN'])

function triState(v) {
  if (v === undefined || v === null) return 'ABSENT'
  const raw = (v && typeof v === 'object') ? v.value : v
  if (raw === true || raw === 'true') return 'TRUE'
  if (raw === false || raw === 'false') return 'FALSE'
  if (typeof raw === 'string' && TRISTATE_UNRESOLVED.has(raw.toUpperCase())) return 'UNRESOLVED'
  return 'ABSENT'
}

/** Returns the failure list — empty means PASS. */
function reconcile(expectedIds, assignments) {
  const owner = new Map(), fails = []
  for (const a of assignments) {
    if (!a || !a.id) continue
    const ch = a.canonicalChapter || a.canonicalOwner
    if (!ch) { fails.push('NO_OWNER:' + a.id); continue }
    if (owner.has(a.id)) fails.push('DUPLICATE:' + a.id)
    else owner.set(a.id, ch)
    if (ch === 'UNASSIGNABLE') fails.push('UNASSIGNABLE:' + a.id)
  }
  for (const id of expectedIds) if (!owner.has(id)) fails.push('DROPPED:' + id)
  for (const id of owner.keys()) if (!expectedIds.includes(id)) fails.push('INVENTED:' + id)
  return fails
}

const IDS = ['F001', 'F002']

// 1. missing owner → FAIL  (the Stage-3 hole: absence must not count as ownership)
t('missing owner → FAIL', 'FAIL',
  reconcile(IDS, [{ id: 'F001', canonicalChapter: 'CH-01' }, { id: 'F002' }]).length ? 'FAIL' : 'PASS')

// 1b. owner under the alternate key name → PASS (documented normalisation)
t('owner under alternate key name → PASS', 'PASS',
  reconcile(IDS, [{ id: 'F001', canonicalChapter: 'CH-01' }, { id: 'F002', canonicalOwner: 'CH-02' }]).length ? 'FAIL' : 'PASS')

// 2. duplicate owner → FAIL
t('duplicate owner → FAIL', 'FAIL',
  reconcile(IDS, [{ id: 'F001', canonicalChapter: 'CH-01' }, { id: 'F001', canonicalChapter: 'CH-03' },
    { id: 'F002', canonicalChapter: 'CH-02' }]).length ? 'FAIL' : 'PASS')

// 3. dropped canonical unit → FAIL
t('dropped canonical unit → FAIL', 'FAIL',
  reconcile(IDS, [{ id: 'F001', canonicalChapter: 'CH-01' }]).length ? 'FAIL' : 'PASS')

// 4. invented canonical unit → FAIL
t('invented canonical unit → FAIL', 'FAIL',
  reconcile(IDS, [{ id: 'F001', canonicalChapter: 'CH-01' }, { id: 'F002', canonicalChapter: 'CH-02' },
    { id: 'F999', canonicalChapter: 'CH-01' }]).length ? 'FAIL' : 'PASS')

// 5. UNASSIGNABLE → FAIL (it is a reported failure signal, not a resting place)
t('UNASSIGNABLE → FAIL', 'FAIL',
  reconcile(IDS, [{ id: 'F001', canonicalChapter: 'CH-01' }, { id: 'F002', canonicalChapter: 'UNASSIGNABLE' }]).length ? 'FAIL' : 'PASS')

// 6. missing required classification → FAIL
const classify = (rows, expected) => {
  const have = new Map(rows.filter((r) => r.obligationClass).map((r) => [r.id, r.obligationClass]))
  const missing = expected.filter((id) => !have.has(id))
  const bad = [...have.values()].filter((c) => !CLASS_VOCAB.has(c))
  return missing.length || bad.length ? 'FAIL' : 'PASS'
}
t('missing required classification → FAIL', 'FAIL',
  classify([{ id: 'CO-1', obligationClass: 'OUTSTANDING_CONSTRUCTION' }, { id: 'CO-2' }], ['CO-1', 'CO-2']))

// 7. unresolved stated explicitly under an allowed state → PASS
t('explicit UNKNOWN classification → PASS', 'PASS',
  classify([{ id: 'CO-1', obligationClass: 'OUTSTANDING_CONSTRUCTION' }, { id: 'CO-2', obligationClass: 'UNKNOWN' }], ['CO-1', 'CO-2']))

// 7b. classification outside the vocabulary → FAIL
t('classification outside vocabulary → FAIL', 'FAIL',
  classify([{ id: 'CO-1', obligationClass: 'PROBABLY_FINE' }], ['CO-1']))

// 8. absent tri-state field masquerading as false → FAIL
t('absent tri-state masquerading as false → FAIL', 'FAIL', triState(undefined) === 'ABSENT' ? 'FAIL' : 'PASS')
t('explicit false tri-state → PASS', 'PASS', triState({ value: false, note: 'reasoned' }) === 'FALSE' ? 'PASS' : 'FAIL')
t('explicit unresolved tri-state → PASS', 'PASS', triState({ value: 'UNRESOLVED' }) === 'UNRESOLVED' ? 'PASS' : 'FAIL')

// 9. unauthorised finding-state mutation → FAIL
const detectMutation = (assertions, baseline, authorised) => assertions.filter((a) => {
  const ruled = authorised[a.id]
  if (ruled) return a.currentState !== ruled
  return baseline[a.id] && a.currentState !== baseline[a.id]
}).length ? 'FAIL' : 'PASS'
const BASE = { F043: 'CONFLICTING_CURRENT_STATE', F139: 'STRUCTURALLY_CLOSED_NOT_LIVE_CERTIFIED' }
const RULED = { F139: 'STRUCTURALLY_CLOSED_NOT_LIVE_CERTIFIED' }
t('unauthorised finding-state mutation → FAIL', 'FAIL',
  detectMutation([{ id: 'F043', currentState: 'LIVE_CERTIFIED' }], BASE, RULED))
t('state matching founder ruling → PASS', 'PASS',
  detectMutation([{ id: 'F139', currentState: 'STRUCTURALLY_CLOSED_NOT_LIVE_CERTIFIED' }], BASE, RULED))
t('contradicting founder ruling → FAIL', 'FAIL',
  detectMutation([{ id: 'F139', currentState: 'OPEN' }], BASE, RULED))

const bad = results.filter((r) => !r.ok)
for (const r of results) console.log((r.ok ? 'PASS  ' : 'FAIL  ') + r.name + '  (expected ' + r.expected + ', got ' + r.actual + ')')
console.log('\nFAIL_CLOSED_FIXTURES: ' + (bad.length ? 'FAIL' : 'PASS') + ' — ' + (results.length - bad.length) + '/' + results.length + '\n')
process.exit(bad.length ? 1 : 0)
