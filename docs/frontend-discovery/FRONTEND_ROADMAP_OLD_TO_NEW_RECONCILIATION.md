# Roadmap Reconciliation — Old F0–F10 → Final C0–C11

**STATUS: C0–C11 is FINAL / FOUNDER APPROVED / FROZEN (2026-08-15). The F0–F10 draft is SUPERSEDED — RETAINED FOR HISTORICAL TRACEABILITY, not deleted.** It was written *before any decision was frozen*, then had frozen inputs bolted on as adjudication progressed. Its evidence remains valid; its **sequencing logic does not**.

`DRAFT_FRONTEND_RECONSTRUCTION_ROADMAP.md` is retained for history and marked superseded.

---

## Mapping

| Old chapter | New chapter(s) | Why restructured |
|---|---|---|
| **F0** — Product & UX Architecture Freeze | **(complete)** — adjudication finished; no longer a chapter | The freeze *happened*. Keeping it as a chapter would imply work remains. |
| **F1** — Client Authority Foundation | **C0** + **C1** + parts of **C2** | F1 bundled surface-agnostic foundations (language/state/temporal) with acting context/capability and identity. Different dependencies: C0 needs nothing; C1 gates institutional work; C2 depends on C1. Bundling them would have blocked C0 behind decisions it does not need. |
| **F2** — Navigation & IA | **C3** | Preserved, but now explicitly after C1 (FD-9) and carrying the FD-12 surface-reachability registry. |
| **F3** — Attention & Inbox | **C4** | Preserved. Now depends on C3 for exact-context deep routing (FD-1) and C0 for ordering. |
| **F4** — Identity, Profile & Presence | **C2** | Merged authority + consumer surfaces into one chapter per FD-13 (*authority + consumer migration = complete*). Also absorbs the People & Participation Selection primitive. |
| **F5** — Composition & Attachments | **C5** | Expanded to include **Content Intake & Resolution** (founder-surfaced after the draft) and FD-8 publish-flow designation. |
| **F6** — Realtime Convergence | **C6** + **C8** | Split. The draft bundled convergence with the Institution Room rebuild; DR2 is a *different kind of work* (rebuild against frozen contracts) with different risk and its own founder checkpoint. |
| **F7** — Live Thread/Space | **C10** | Promoted from a frontend phase to an explicit **cross-repository construction chapter**. The draft understated the backend obligation; FD-5 §30 forbids hiding it inside frontend work. |
| **F8** — Cross-Platform | **C9** | Preserved, now carrying **drag/drop** (0 implementations — discovered after the draft) as an explicit MSIX obligation. |
| **F9** — Accessibility & Performance | **dissolved into every chapter** | FD-13 and the founder instruction require accessibility criteria **per chapter**, not a late catch-up phase. Performance hotspots are largely dissolved by the authority consolidation itself. |
| **F10** — Item 17 | **C11** | Unchanged and undiminished. |
| *(none)* | **C7** — Threads, Spaces & Correspondence | **New.** The draft had no home for the Threads/Spaces freeze or the FD-10 Correspondence ruling. Three `thread_screen` implementations and the Correspondence convergence verdict had no owning chapter. |
| *(none)* | **F-T** temporal → folded into **C0** | The draft added a cross-cutting F-T after the Temporal freeze. It belongs with the other surface-agnostic foundations. |

---

## What changed structurally, and why

1. **Foundations split from acting context.** Product language, product state and temporal presentation depend on *nothing*. Putting them in the same chapter as acting context would have delayed the cheapest, highest-leverage migrations behind institutional-authority work.

2. **Identity absorbed its surfaces.** FD-13 defines completion as *authority + consumer migration*. An identity authority without rebuilt profile surfaces would be an incomplete chapter by the frozen definition.

3. **Institution Room separated from realtime convergence.** Convergence is careful extraction from a **certified** surface; the Room is a **rebuild against frozen contracts**. Different risk, different regression, different checkpoint.

4. **Live promoted to cross-repository.** The largest correction. The draft treated Live as frontend F7. FD-5 established real backend construction (go-live authority, public observation, audience scale, replay-as-product) and **forbids hiding it in a frontend phase**.

5. **Threads/Spaces/Correspondence given a chapter.** Three decisions frozen after the draft (Threads/Spaces model, FD-10 Correspondence ruling, FD-3 ownership) had no home.

6. **Accessibility and enforcement dissolved into every chapter.** Both were phases in spirit; both are now per-chapter obligations, per FD-13 and the founder instruction.

---

## Evidence carried forward unchanged

All measured findings remain valid and are cited by the new chapters: 189,134 lines · 544 files · 171 routes · 136 screens · 40 mirrored routes · 8 attention surfaces · 6 composers · 11 upload pipelines · 3 live-room implementations · 3 profile implementations · 3 thread screens · 83 raw spinners vs 63 shared · 68 blank empty states · 52 hand-rolled `.difference()` · 29 role checks + 20 `canX` · **0 drag-and-drop implementations** · `PUBLIC_STAGE` declared but unconsumed.

**History is not rewritten.** The draft's chapter numbering, its recommendations, and the two corrections made during adjudication (the "pure synonyms" premise and the "no speaker/audience model" claim) all remain visible in their original documents.
