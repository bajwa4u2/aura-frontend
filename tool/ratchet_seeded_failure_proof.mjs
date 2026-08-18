#!/usr/bin/env node
// FD-13 SEEDED-FAILURE PROOF for the CH-01 foundation ratchets.
//
// Doctrine: "Every ratchet demonstrated to FAIL on a deliberately introduced
// real violation before it is counted as enforcement." A green ratchet proves
// nothing on its own — it may be green because it detects nothing.
//
// For each ratchet this harness:
//   1. seeds a REAL violation of exactly that rule,
//   2. runs ONLY that ratchet,
//   3. asserts it FAILS,
//   4. removes the seed and asserts the ratchet returns to GREEN.
//
// The harness is non-mutating with respect to the repository: the seed file is
// created and deleted inside one step, and a dirty-tree check runs at the end.
import { writeFileSync, unlinkSync, existsSync, readFileSync } from 'node:fs'
import { execSync } from 'node:child_process'

const PROBE = 'lib/features/fd13_ratchet_seed_probe.dart'
const GUEST_PROBE = 'lib/features/fd13_guest_seed_probe.dart'
const C0 = 'test/product/c0_anti_drift_gate_test.dart'
const C1 = 'test/authority/c1_anti_drift_gate_test.dart'
const C3 = 'test/navigation/c3_route_integrity_gate_test.dart'
const S1 = 'test/authority/ch02_s1_session_choke_point_test.dart'

const header = `// TEMPORARY FD-13 SEED PROBE — created and deleted by
// tool/ratchet_seeded_failure_proof.mjs. If this file is committed, the
// harness crashed; delete it.
import 'package:flutter/material.dart';

class Fd13SeedProbe extends StatelessWidget {
  const Fd13SeedProbe({super.key});
`
const footer = `}
`
const NL = String.fromCharCode(10)
const MAT_IMPORT = "import 'package:flutter/material.dart';"

// Each seed is a REAL violation of exactly one ratchet rule.
const SEEDS = [
  {
    id: 'G2',
    rule: 'HUMAN TEMPORAL / local elapsed-time',
    suite: C0,
    test: 'no new local humanized-time formatting',
    body: `
  String probe(DateTime t) {
    final d = DateTime.now().difference(t);
    return '\${d.inMinutes}m ago';
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
`,
  },
  {
    id: 'G3',
    rule: 'HUMAN TEMPORAL / toLocal',
    suite: C0,
    test: 'no new local timezone conversion',
    body: `
  DateTime probe(DateTime t) => t.toLocal();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
`,
  },
  {
    id: 'G4',
    rule: 'PRODUCT STATE / full-surface loading',
    suite: C0,
    test: 'no new full-surface spinner outside the state authority',
    body: `
  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
`,
  },
  {
    id: 'G5',
    rule: 'PRODUCT STATE / direct primitive construction',
    suite: C0,
    test: 'no new direct construction of the state primitives',
    body: `
  Widget probe() {
    return AuraLoadingState();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
`,
  },
  {
    id: 'G7',
    rule: 'HUMAN TEMPORAL / local formatter declarations',
    suite: C0,
    test: 'no new locally declared time formatter',
    body: `
  String formatProbe(DateTime when) => when.toIso8601String();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
`,
  },
  {
    id: 'R1',
    rule: 'ROLE-AS-PERMISSION',
    suite: C1,
    test: 'no new role-derived authority booleans',
    body: `
  bool probe(bool isAdmin) => isAdmin;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
`,
  },
  {
    id: 'R2',
    rule: 'ROLE LITERAL COMPARISON',
    suite: C1,
    test: 'no new role-literal comparisons',
    body: `
  bool probe(String role) => role == 'OWNER';

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
`,
  },
  {
    id: 'S1-ESTABLISH',
    rule: 'CH-02 S1',
    suite: S1,
    test: 'setSessionHint(true) is written ONLY at the choke point',
    imports: `import '../core/auth/session_hint.dart';
`,
    body: `
  Future<void> probe() async {
    await setSessionHint(true);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
`,
  },
  {
    id: 'S1-CLEAR',
    rule: 'CH-02 S1',
    suite: S1,
    test: 'setSessionHint(false) appears only at governed clear sites',
    imports: `import '../core/auth/session_hint.dart';
`,
    body: `
  Future<void> probe() async {
    await setSessionHint(false);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
`,
  },
  {
    id: 'S1-GUEST',
    rule: 'CH-02 S1',
    suite: S1,
    probe: GUEST_PROBE,
    test: 'no path establishes a hint for a guest token',
    imports: `import '../core/auth/session_hint.dart';
`,
    body: `
  Future<void> probe() async {
    await setSessionHint(true);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
`,
  },
  {
    id: 'C3-RESOLVE',
    rule: 'C3 ROUTE INTEGRITY / literal resolves against the route table',
    suite: C3,
    test: 'every feature navigation literal resolves against the declared route table',
    body: `
  void probe(BuildContext context) {
    context.push('/fd13-probe-address-that-does-not-exist');
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
`,
  },
]

// Windows quoting: pass ONE command string through the shell and decide the
// verdict from the reporter's own words, never from the exit code alone.
const run = (suite, name) => {
  const cmd = `flutter test ${suite} --plain-name "${name}"`
  let out = ''
  try {
    out = execSync(cmd, { stdio: 'pipe', encoding: 'utf8' })
  } catch (e) {
    out = String(e.stdout || '') + String(e.stderr || '')
  }
  const passed = /All tests passed!/.test(out)
  const failed = /Some tests failed|Test failed/.test(out)
  if (passed === failed) {
    throw new Error(`FAIL-CLOSED: indeterminate reporter output for "${name}"\n${out.slice(-800)}`)
  }
  return { failed, out }
}

const results = []
let harnessError = null
try {
  for (const s of SEEDS) {
    process.stdout.write(`${s.id.padEnd(11)} ${s.rule} ... `)
    const probePath = s.probe || PROBE
    const hdr = s.imports ? header.replace(MAT_IMPORT, MAT_IMPORT + NL + s.imports) : header
    writeFileSync(probePath, hdr + s.body + footer)
    const seeded = run(s.suite, s.test)
    unlinkSync(probePath)
    const clean = run(s.suite, s.test)

    const proven = seeded.failed && !clean.failed
    // Confirm the failure names THIS rule, not some neighbouring one.
    const namesRule = seeded.failed && seeded.out.includes(s.rule.split(' / ')[0])
    results.push({
      id: s.id,
      rule: s.rule,
      suite: s.suite,
      test: s.test,
      failedWhenSeeded: seeded.failed,
      greenWhenClean: !clean.failed,
      failureNamedTheRule: namesRule,
      verdict: proven && namesRule ? 'ENFORCING' : 'NOT_PROVEN_ENFORCING',
    })
    console.log(proven && namesRule ? 'ENFORCING' : 'NOT PROVEN')
  }
} catch (e) {
  harnessError = String(e && e.message)
} finally {
  for (const p of [PROBE, GUEST_PROBE]) if (existsSync(p)) unlinkSync(p)
}

const enforcing = results.filter((r) => r.verdict === 'ENFORCING').length
const out = {
  type: 'FD13_SEEDED_FAILURE_PROOF',
  unit: 'W1-B',
  date: '2026-08-18',
  doctrine:
    'A ratchet counts as enforcement ONLY after it is demonstrated to FAIL on a deliberately introduced real violation (FD-13 precedent).',
  harnessError,
  ratchetsProven: enforcing,
  ratchetsAttempted: results.length,
  results,
}
writeFileSync('docs/portfolio/run/stage0-2026-08-18/05-execution/w1b-ratchet-seeded-failure-proof.json', JSON.stringify(out, null, 1))
console.log(`\nENFORCING: ${enforcing}/${results.length}`)
if (harnessError) console.log('HARNESS ERROR:', harnessError)
for (const p of [PROBE, GUEST_PROBE]) if (existsSync(p)) {
  console.log('FAIL-CLOSED: probe file survived; repository is dirty:', p)
  process.exit(1)
}
process.exit(enforcing === results.length && !harnessError ? 0 : 1)
