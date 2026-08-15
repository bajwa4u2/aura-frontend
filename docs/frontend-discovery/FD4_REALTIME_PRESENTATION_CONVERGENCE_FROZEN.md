# FD-4 — REALTIME PRESENTATION CONVERGENCE

# STATUS: FROZEN — FOUNDER APPROVED 2026-08-15
# SELECTED: OPTION A — SHARED REALTIME PRESENTATION PRIMITIVES, MEETINGS LIFECYCLE UNTOUCHED

---

## 1. Core decision

Converge the **presentation** of participant list · host controls · admission/join-requests · consent onto a shared component family.

> **Meetings lifecycle is untouched.** Booking, invitation, attendance, waiting/admission rules, prep, summary and follow-up remain exactly as certified.

**Evidence this addresses.** The five shared realtime widgets are consumed by `realtime_room_screen` and **zero times** by `meeting_live_room_screen` (3,890 lines), which reimplements participant grid, spotlight layout and remote tiles internally — while both already share transport, media service, event parser and domain models.

---

## 2. Shared components do not own semantics *(frozen)*

> **ONE SHARED PARTICIPANT/PRESENTATION COMPONENT FAMILY MAY RENDER DIFFERENT CONTEXT-SPECIFIC STATES AND LANGUAGE SUPPLIED BY THE OWNING DOMAIN.**
>
> **THE SHARED COMPONENT DOES NOT OWN SEMANTIC MEANING.**

A Meeting attendee, an Institution Room invitee and a future Live speaker are **different states on the same component**. The owning domain supplies the state vocabulary and language; the component renders it.

This is the client-side expression of FD-3: **shared infrastructure, distinct product semantics.** A shared component that started deciding what "participant" means would violate FD-3 as surely as a shared room screen would.

---

## 3. Implementation safeguard *(frozen — founder addition)*

> **MEETINGS MUST NOT BE REWRITTEN WHOLESALE TO "USE THE NEW SHARED SCREEN."**

- **Extract and replace only the proven duplicate presentation concerns** — participant list, host controls, admission/join-requests, consent.
- Work proceeds **slice by slice**, not as a single migration.
- **Targeted regression after each slice** (Meetings currently 97/97 passing).

This is what keeps the certified lifecycle protected while still allowing meaningful convergence. A wholesale rewrite would put certification at risk for a gain that slicing achieves anyway.

---

## 4. Explicitly rejected

| Rejected | Why |
|---|---|
| **One unified room screen with per-context policy** (option C) | Risks a certified surface for visual uniformity; FD-3 warns shared infrastructure must not erase distinct semantics |
| **Extract the participant list only** (option B) | Leaves three of the four divergences — host controls, admission, consent — duplicated |
| Rewriting Meetings onto a new shared screen | §3 |
| A shared component deciding participant semantics | §2 |

---

## 5. Scope boundaries

- **`institution_live_rooms_screen` is not in scope here.** It remains **DR2** — a rebuild against the frozen Institution Room contracts, for different reasons (it consumes untyped JSON and represents sessions rather than rooms).
- **Transport, media service, event parser, reconciliation and orphan recovery are untouched** — already shared and sound.
- **Session continuity** (`floating_call_widget`, `incoming_live_overlay`, `thread_call_lifecycle_host`) is preserved.

## 6. Compliance with frozen decisions

| Frozen decision | Requirement |
|---|---|
| **FD-3** | Realtime semantics stay distinct per context; convergence is presentation only. Creation/selection/invitation/participation UX is still to be **reconstructed** — *simplify the act, not the authority*. |
| **Capability-Adaptive Experience** | **Host/admin controls must not permanently occupy everybody else's realtime UI** — they appear progressively when required. Participants must not see host controls, greyed out or otherwise. |
| **FD-11 Identity** | Participant rendering **consumes canonical identity projection** — no realtime-specific identity model. |

---

## 7. Consequence

- Meetings **presentation** changes; Meetings **lifecycle, booking, admission rules and certification** do not.
- Roughly 3,900 lines of Meetings room code shrink substantially as reimplemented widgets are replaced — **incrementally**.
- Targeted Meetings regression is required after **each** slice, not only at the end.

## 8. Frozen doctrine

> **SHARED REALTIME PRESENTATION PRIMITIVES; MEETINGS LIFECYCLE UNTOUCHED.**
> **ONE COMPONENT FAMILY, MANY CONTEXT-SUPPLIED STATES AND LANGUAGES.**
> **THE SHARED COMPONENT DOES NOT OWN SEMANTIC MEANING.**
> **NO WHOLESALE MEETINGS REWRITE — EXTRACT AND REPLACE PROVEN DUPLICATES, SLICE BY SLICE, WITH TARGETED REGRESSION AFTER EACH.**

## 9. Anti-drift guard

| ❌ Prohibited reading | Why it violates FD-4 |
|---|---|
| "Build one room screen for everything" | §1, §4 — option C was rejected |
| "Port Meetings onto the shared screen" | §3 — no wholesale rewrite |
| "Do the whole convergence, then regress once" | §3 — regression follows **each** slice |
| "The shared participant component defines what a participant is" | §2 — it renders, it does not mean |
| "Use one participant label everywhere for consistency" | §2 — language is supplied by the owning domain |
| "Show host controls disabled for participants" | §6 — Capability-Adaptive Experience |
| "Give realtime its own participant identity model" | §6 (FD-11) |
| "Fold institution live rooms into this work" | §5 — that is DR2 |
| "Meetings admission rules can move to the shared component" | §1 — lifecycle is untouched |
