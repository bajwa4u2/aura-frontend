# FD-13 — ENFORCEMENT: GATES SHIP WITH THE AUTHORITY THEY PROTECT

# STATUS: FROZEN — FOUNDER APPROVED 2026-08-15
# SELECTED: OPTION A — SOURCE-LEVEL GATES + ARCHITECTURE TESTS PER AUTHORITY
# ENFORCEMENT: HARD BUILD / CERTIFICATION FAILURE

---

## 1. Core decision

The reconstructed frontend must not rely on convention · documentation alone · code review alone · developer memory · *"please use the shared component"* · warnings that do not affect certification.

**The discovery proves that model has already failed repeatedly.** A shared authority is **not complete merely because it exists**.

> **AUTHORITY + CONSUMER MIGRATION + ANTI-DRIFT ENFORCEMENT + REGRESSION/CERTIFICATION = COMPLETE RECONSTRUCTION OF THAT AUTHORITY.**

## 2. Hard failure

Gates protecting frozen invariants **hard-fail** the relevant build/test/certification path.

```
VIOLATION → BUILD / CERTIFICATION FAILURE
  → CORRECT THE VIOLATION, or
  → ADD A DELIBERATE, REVIEWABLE LEGITIMATE EXCEPTION
```

> **Soft gates are rejected as the default enforcement model.** Informational warnings accumulate indefinitely and are then ignored.

## 3. Exception model

Exceptions are permitted but must be **narrow · identifiable · justified · reviewable · attributable to a specific architectural reason**.

**Forbidden:** broad wildcard suppressions · generic "legacy" exclusions · permanent ignore directories · silent bypasses · warning-only exceptions.

> **The existence of an exception must itself be visible in the governing enforcement artifact/test.**

## 4. Enforce the invariant, not accidental implementation

> A gate protects the **architectural/product invariant** — it must not fossilise today's implementation name or file path.

| The invariant IS | The invariant is NOT |
|---|---|
| Humanized/semantic time flows through the canonical Temporal Authority | every file must forever import `relative_time.dart` |
| Canonical loading presentation is owned | this exact widget class name must exist forever |

If the canonical implementation legitimately evolves, **the gate evolves with the authority without weakening the doctrine**. Protect semantic/architectural ownership, not incidental syntax, wherever architecture-aware enforcement is practical.

## 5. Sequencing *(frozen)*

> **ENFORCEMENT SHIPS WITH THE AUTHORITY IT PROTECTS. THERE IS NO SEPARATE END-OF-PROGRAM "ENFORCEMENT CHAPTER."**

```
AUTHORITY REBUILT → MIGRATE ITS CONSUMERS → ADD MINIMUM GATE(S) PREVENTING BYPASS
  → RUN REGRESSION/CERTIFICATION → ONLY THEN IS THAT AUTHORITY COMPLETE
```

**F1 may establish the pattern. Every later chapter owns its own enforcement.** No retrofit phase.

## 6. Minimum effective mechanism

> **DO NOT CREATE BUREAUCRACY MERELY FOR ENFORCEMENT.**

Candidates: source-level tests · architecture tests · restricted imports/usages · canonical consumer checks · route/surface registry validation · capability-authority checks · targeted lint where justified · explicit allow-lists.

## 7. No governance platform up front *(Option B rejected)*

Do **not** pre-build comprehensive generated governance infrastructure · large metadata frameworks · custom governance DSLs · broad registries for concepts that do not need them · generalized lint platforms — **before reconstructed authorities establish demonstrated need**.

> If later evidence proves a shared mechanism is warranted across multiple gates, **bring that consolidation forward** rather than silently constructing a platform.

---

## 8–16. Per-authority enforcement obligations

| Authority | Must prevent recurrence of | Must NOT do |
|---|---|---|
| **Surface reachability** (FD-12) | surfaces with no auditable reachability/ownership path | a naïve *zero references → dead* gate (**forbidden**). A declared surface/route registry is approved **in principle**, introduced **with** the navigation/IA reconstruction, **not prematurely** |
| **Capability** | direct role checks, local `canX` derivations rebuilding backend authority | block legitimate presentation-state logic — the gate must distinguish **presentation** from **invented authority** |
| **Temporal** | hand-rolled `.difference()` humanization · arbitrary direct timezone conversion · local semantic timestamp selection · `updatedAt` sorting where the domain defines another event | merely ban strings/functions where architecture-aware enforcement can protect the real invariant |
| **Loading / empty / error** | shared authority existing while dozens of new raw competing patterns accumulate | forbid legitimate local visual primitives where semantically warranted — exceptions must be explicit |
| **Attention** (FD-1, FD-2) | parallel attention hubs · unread-as-universal-attention · independent badge semantics · dead CTA projections · competing reconciliation | protect only a specific widget name instead of the ownership/invariants |
| **Realtime** (FD-4) | another owning surface casually reimplementing canonical shared primitives | force Meeting/Room/Thread/Space/Live **semantic** convergence — FD-3 stands: shared presentation ≠ shared semantics |
| **Identity/Profile/Presence** (FD-11) | independent Person/Member identity models · institution-as-user presentation · boolean verification flattening · local presence inference · local role-derived identity · duplicated identity presentation authorities | ban filenames instead of enforcing architectural truth |
| **Composition / attachments** (FD-6, FD-7) | independent composer architectures · independent upload mechanics · local attachment lifecycle interpretation · send/upload lifecycle collapse · context-specific reimplementation of shared intake | erase legitimate domain differences — owning domains retain communication semantics |
| **Product language / CTA** (FD-10) | known terminology/CTA drift returning | hard-code every sentence of product copy into governance. Protect canonical nouns, semantic CTA families and prohibited duplicates where there is clear architectural value |

---

## 17. Gate quality requirement

**A gate itself must be trustworthy.** Do not create enforcement that produces known false positives · requires routine suppression · cannot understand legitimate indirect architecture · blocks harmless implementation evolution · tests incidental formatting rather than architecture · gives a false sense of certification.

> Where a reliable hard gate cannot yet be constructed: **record the enforcement obligation with the owning authority and bring the limitation forward. Do not silently downgrade it to an ignored warning.**

## 18. Definition of done *(frozen)*

Every authority reconstruction chapter records:

**the frozen invariant · canonical owner · migrated consumers · prohibited competing pattern · enforcement mechanism · legitimate exceptions · regression/certification evidence.**

> **This is part of the definition of done for frontend reconstruction.**

---

## 19. Frozen doctrine

> **SOURCE-LEVEL GATES + ARCHITECTURE TESTS, PER AUTHORITY.**
> **HARD BUILD / CERTIFICATION FAILURE.**
> **EXCEPTIONS: EXPLICIT, NARROW, JUSTIFIED, REVIEWABLE.**
> **THE GATE SHIPS WITH THE AUTHORITY IT PROTECTS.**
> **NO STANDALONE END-STAGE ENFORCEMENT CHAPTER.**
> **NO FULL GOVERNANCE PLATFORM UP FRONT.**
> **ENFORCE ARCHITECTURAL INVARIANTS, NOT ACCIDENTAL IMPLEMENTATION DETAILS.**
> **A GATE THAT CANNOT BE TRUSTED MUST BE RECORDED AS AN OBLIGATION, NOT DOWNGRADED TO A WARNING.**

## 20. Anti-drift guard

| ❌ Prohibited reading | Why it violates FD-13 |
|---|---|
| "Add the gates at the end, once things settle" | §5 — no retrofit chapter |
| "Ship the authority now, migrate consumers later" | §1 — migration is part of completion |
| "Make it a warning first, harden it later" | §2 |
| "Exclude `legacy/` from the gate" | §3 — no generic legacy exclusions |
| "Ban the import of `relative_time.dart` forever" | §4 — enforce the invariant, not the filename |
| "Zero references → fail the build" | §8 (FD-12) — forbidden |
| "Gate every string of product copy" | §16 |
| "Force all realtime surfaces to one semantic model" | §13 — FD-3 stands |
| "Block any local spinner anywhere" | §11 — legitimate primitives may exist with explicit exceptions |
| "Build the governance platform first" | §7 |
| "The gate has false positives but it mostly works" | §17 |
| "Authority exists, so the chapter is done" | §18 |
