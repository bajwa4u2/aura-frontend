# FIRST EXECUTABLE WAVE — PART 2 EXECUTION RECORD

**Authorized by founder ruling 2026-08-18** (PD-1 + PD-2 adjudicated; Part 2 authorized on reconciliation PASS).
**Units executed:** W1-C (CH-02 S1) · W1-D (CH-02 S2) · W1-E (CH-02 S3).
**No chapter closed. No unproven state promoted.**
Baseline: 143 findings + 308 obligations = **451 units** · 17 chapters · reconciliation **PASS**

---

## 0. Rulings applied before execution

| Ruling | Result |
|---|---|
| **PD-2** | **RESOLVED.** CH-02 owns STRUCTURE; CH-10 owns ACCOUNT-ENTRY EXPERIENCE. Recorded on both chapters as `productDispositions`, and the seam enumeration added as a CH-02 certification requirement. `CO-RC-C1-022` retained verbatim, superseded as to status only. |
| **PD-1** | **RESOLVED for this programme.** Platform Administration is `OUT_OF_CURRENT_RECONSTRUCTION_SCOPE` — explicitly **not** deprecated, demolished, architecturally invalid, or removed. 11 files / 52 sites `FROZEN_BY_RULE`, preserved in the register, ownerless-by-reconstruction recorded as **intentional**. |
| **34 vs 35** | **Closed mechanically, no escalation.** |
| **Part-1 rulings** | All preserved unchanged. |

### The 34-vs-35 reconciliation

Instructed to compare the underlying **site sets**, not the totals. `reconcile-pd1-g5-count.mjs` parses
the PD-1 enumeration out of `C1_G5_DISPOSITION_MATRIX.md` and the G5 admin rows out of the frozen C0
baseline, then compares them **file by file**:

- **Same 11 files. Every per-file count agrees. Zero disagreements, zero files unique to either side.**
- The matrix's **own enumerated rows sum to 35**; its **summary line says 34**.

**Cause: `SUMMATION_ERROR_IN_THE_SUMMARY_LINE`.** Not stale evidence, not methodology, not a changed
tree, not a missing site. Product scope and governance intent are unchanged, so per the ruling this is
closed here. Both figures retained with provenance; **35 is operative**, 34 is historical.

### Debt separation now explicit

| Class | Files | Sites |
|---|---:|---:|
| **EXECUTABLE** | 95 | **187** |
| **FROZEN_BY_RULE** | 44 | **83** |

The two frozen reasons are recorded as **semantically distinct**, not merged into one bucket:
`OUT_OF_CURRENT_RECONSTRUCTION_SCOPE` (PD-1, 52 sites — the surface is out of scope) vs
`PROTECTED_SURFACE_MODIFICATION_PROHIBITED` (PB-01, 31 sites — modification is forbidden on a certified
surface). Both are frozen; the rules differ and conflating them would lose why.

---

## 1. W1-C — CH-02 S1 · single-choke-point session establishment

**What I found.** The choke point already existed and was correct: `TokenStore.setSession` writes the
session hint for non-guest tokens, and `clearTokens` clears it symmetrically. Consistent with F065 being
`IMPLEMENTED_NOT_LIVE_CERTIFIED`.

**What was still wrong.** Both *original* call sites were still writing the hint themselves —
`auth_controller.dart` password login and code verification. Not merely redundant: they wrote the hint
**unconditionally**, bypassing the choke point's guest-token exclusion. The contract said "a consequence
of holding a member session"; the code still had two paths *performing* it.

**Change made.** Removed both call-site writes; the choke point is now the only establishment site.
Each removal carries a comment naming why, so the next reader does not restore it.

**A behavioural consequence I am not hiding.** Those call sites `await`-ed the write; the choke point
does it `unawaited` by frozen design ("hint bookkeeping must never delay or fail auth"). Establishment
is therefore now fire-and-forget on the login path. A person who signs in and hard-refreshes within the
same few milliseconds could in principle outrun the write. The doctrine chose that trade deliberately;
recording it so the choice stays visible rather than becoming folklore.

**Clearing was deliberately left alone.** S1 is about *establishment*. `clearTokens`'s own frozen comment
blesses redundant clears — losing a session twice is safe, gaining one silently is not. The three extra
clear sites are enumerated **with their justifications** in the gate, including one genuine governed
exception: `session_bootstrap`'s 401/403 path forgets a hint when there is **no session to clear at all**,
so it cannot route through `clearTokens`.

**Gate:** `test/authority/ch02_s1_session_choke_point_test.dart` — **7 assertions**, covering: one
establishment site; the choke point actually writes it (so the first test cannot pass vacuously); the
write lives *inside* `setSession`; the guest exclusion survives; no guest surface touches the hint;
clears stay governed; and every governed clear site still exists and still clears.

---

## 2. W1-D — CH-02 S2 · disjoint fail-closed route classification

**Found already shipped** in `4bafb1a` (F069): `lib/app/route_classification.dart` declares
`RouteClass{public, member, authAction, guestReachable}` with a **fail-closed default**, and the F069
sweep classified the previously-unclassified routes — **`/admin` was the starkest case, the entire
workspace unclassified and failing open.** `/articles/write` was another: the editor was reachable with
no login redirect and no destination preservation.

**Verified rather than rebuilt.** The F069 gate already carries the completeness proof — *"no declared
route falls through to the fail-closed default"* — which is what stops the 24 unclassified routes from
recurring. Re-running it, plus the C3 route-integrity gates: **12/12 green**, including the literal
ratchet and DR4 alias resolution.

**One thing S2 owed that PD-1 made newly load-bearing.** The founder ruling states scope exclusion must
not create a security bypass. That is now **asserted, not assumed** — the S3 gate proves `/admin`,
`/admin/users` and `/admin/audit-logs` still classify `member` and still refuse unauthenticated entry.
Path traversal (`/admin/../public`) also fails closed.

---

## 3. W1-E — CH-02 S3 · destination reconstruction contract + PD-2 seam enumeration

**Published:** `docs/governance/CH02_DESTINATION_RECONSTRUCTION_CONTRACT.md`.

Four structural clauses (C1 single establishment site · C2 guest exclusion · C3 total classification
failing closed · C4 unprovable destination → declared fallback), the redirect contract with its **four
interruption points**, and the **PD-2 seam enumeration** carrying all six elements the ruling requires.

**The seam, stated once:** *CH-02 decides that a redirect happens and what it carries; CH-10 decides what
the person sees when they arrive.* There are exactly three crossings (X1 unauthenticated interrupt, X2
sign-up establishes a session, X3 auth completes and returns). CH-10 may change every pixel of `/login`;
CH-10 may **not** change what `?redirect=` carries, what happens when it cannot be reconstructed, or the
order of the identity/verification gates.

**Ordering recorded as load-bearing:** identity baseline is evaluated **before** email verification, so
the two independent "authed but incomplete" gates never fight over which wins on a cold boot. Reversing
them makes the winner depend on arrival path.

**Five fail-closed behaviours enumerated**, including the one the ruling asked for by name — an
unprovable destination becomes a *declared* destination (`/public` signed out, `/home` signed in), never
empty and never an unvalidated echo, with the boot path excluded so a redirect cannot loop.

**Gate:** `test/navigation/ch02_s3_destination_contract_test.dart` — **12 assertions**. It tests **both
directions**: that the code still satisfies the contract, and that the contract still describes the code
(every route it assigns to CH-02 or CH-10 still classifies as claimed). A published contract nothing
checks decays into a description of what the code used to do.

---

## 4. Evidence

| Suite | Result |
|---|---|
| Frontend (whole) | **597 passed · 0 failed · 1 skipped** (was 585; +12 from the S3 gate) |
| Backend (whole) | **192 suites / 2426 tests PASS** — unchanged |
| **Meetings regression** | **118 PASS** (90 backend + 28 frontend) — **unchanged, attributable to these changes** |
| CH-02 S1 gate | 7/7 |
| CH-02 S3 gate | 12/12 |
| F069 + C3 route gates | 12/12 |
| **FD-13 seeded-failure proof** | **11/11 ENFORCING** — the three new S1 gates each seeded with a real violation, shown to fail, then returned green |
| Reconciliation | `stage4-proof` **PASS** · `validate-portfolio-v2` **PASS** · `validate-stage5` **PASS** · fixtures **15/15** |

The 1 skipped test remains `realtime_room_golden_test.dart` — **DEFECT-1**, assigned to CH-04 and not
waived.

---

## 5. What is NOT claimed

- **F065 remains `IMPLEMENTED_NOT_LIVE_CERTIFIED`.** The live refresh proof has **not** been performed.
  It requires a running app and founder observation under PB-11, and it is CH-02's own first gate.
  Everything above is static and local.
- **F103 and F104 remain `OPEN`.** They are gated by F065's live proof; publishing the contract that
  governs them closes nothing.
- **The live signed-out probe for S2 is owed.** The classification is proven fail-closed by gate; it is
  not yet proven on a live signed-out browser.
- **No chapter closed.** CH-02 remains open; CH-10 has not been entered; S4 is still refused (it needs
  CH-03's W2 conformance gate).
- **No protected boundary crossed.** PB-01 reached, not opened — Meetings unchanged and re-verified.

---

## 6. Continuity

- Reconstruction Register regenerated in **both repositories**, now carrying the PD-1/PD-2 dispositions
  with product standing stated explicitly (`deprecated: NO`, `demolished: NO`, `removed: NO`).
- `docs/governance/CH02_DESTINATION_RECONSTRUCTION_CONTRACT.md` published.
- Canonical artifacts updated: `index-chapters.json`, `w1b-remainder-ownership.json`,
  `pd1-pd2-rulings-applied.json`, `pd1-g5-count-reconciliation.json`.

## 7. Next authorized unit

Under the standing authorization, the next Part-2 work is **W1-X1 (CH-11)** — which remains **gated**
on the RC-C5 scope ratification, whose fail-closed default is *treat as gated*. That is a founder
decision, and this record stops rather than assuming it.
