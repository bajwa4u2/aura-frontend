# HUMAN TEMPORAL PRESENTATION AUTHORITY

# STATUS: FOUNDER DIRECTION FROZEN — 2026-08-15
# CROSS-PRODUCT OBLIGATION

**Founder-surfaced — the original discovery audit missed this entirely.** The audit covered composers, attention, identity, navigation and state language, but never examined temporal presentation or sorting semantics. Recorded here with evidence gathered after the fact. **No pre-existing FD entry; no new FD number invented.**

---

## Measured evidence (gathered 2026-08-15)

**Shared helpers exist and are barely adopted — the same pattern as every other drift in this codebase:**

| Signal | Measurement |
|---|---|
| `core/utils/relative_time.dart` consumers | **9 files** |
| `core/utils/local_timezone.dart` consumers | **3 files** |
| Files independently computing `.difference(` | **52 files** |
| Files calling `toLocal()` | **35 files** |
| Files using `DateFormat` | **5 files** |
| Files performing `.sort(` | **22 files** |

> A shared relative-time helper is used by **9** files while **52** compute elapsed time themselves. Formatting is hand-rolled almost everywhere (`DateFormat` in only 5 files).

**Timestamp semantics are collapsed onto one field:**

| Field | Occurrences |
|---|---|
| `createdAt` | **295** |
| `updatedAt` | 99 |
| `publishedAt` | 68 |
| `startedAt` | 53 |
| `sentAt` | 14 |
| `endedAt` | 13 |
| `deliveredAt` | 6 |
| `receivedAt` | **0** |
| `occurredAt` | **0** |

> `createdAt` is used ~21× more than `sentAt`, and **`receivedAt` / `occurredAt` are never used at all** — the client has no vocabulary for when something was *received* or when an event *occurred*. This is precisely the semantic collapse the founder describes.

**Sorting hazard.** One `sortDate: updatedAt` was found — in `conversations_screen.dart`, which the audit already established is **dead code (zero router references)**. So the hazard pattern exists but is not currently live; it must not return during reconstruction.

---

> **FD-12 (FROZEN):** the single `sortDate: updatedAt` instance disappears when `conversations_screen.dart` is retired. **This must NOT be treated as proof that temporal/sorting semantics are solved** — this authority applies throughout reconstruction regardless.

## 1. Core doctrine

> **MACHINES STORE PRECISE TIME. PEOPLE EXPERIENCE MEANINGFUL TIME.**

Ordinary product UI communicates time by human context · event semantics · recency · locale/timezone · product meaning.

> **Do not expose raw/developer-style timestamps as the dominant ordinary experience.**

Temporal presentation is a **cross-product governed concern** — never repaired screen by screen.

## 2. Semantic time

Different timestamps do **not** automatically mean the same thing. Meaningful event semantics include: POSTED · SENT · RECEIVED · REPLIED · PUBLISHED · UPDATED · INVITED · STARTED · ENDED · SCHEDULED.

> **Do NOT interchange** `createdAt` · `updatedAt` · `publishedAt` · `sentAt` · `receivedAt` · `deliveredAt` · event start · event end **merely because one field is convenient.**

**The owning domain determines which event time has product meaning.**

## 3. Humanized presentation

Coherent human-readable forms appropriate to context — *illustrative, not final copy rules*: `Just now` · `5 min ago` · `Today, 7:42 PM` · `Yesterday, 9:16 AM` · `Aug 12` · `Aug 12, 2025` · `Starts tomorrow at 2:00 PM`.

Presentation is determined by **semantic event type and temporal distance**.

## 4. Semantic verb + time

Where useful, communicate *what happened*, not merely when: post → *Posted 8 min ago* · outgoing message → *Sent 8 min ago* · incoming → *Received 8 min ago* where that adds value · announcement → *Published Aug 12* · meeting → *Starts tomorrow at 2:00 PM* · invitation → *Invited yesterday / Expires…* where semantics warrant.

> **Do not force verbose labels everywhere.** Use them where they improve comprehension.

## 5. Sorting authority

Sorting must use **canonical event semantics**.

> **Do NOT sort a communication feed by `updatedAt` merely because an invisible metadata change occurred.**

For each product projection — posts · replies · messages · conversations · notifications · attention · invitations · meetings · Threads · Spaces/activity · publication history — determine explicitly: **WHAT EVENT DETERMINES ORDER?** (posted · sent · received · last meaningful conversation activity · published · scheduled start · attention occurrence.)

> **Do not guess per screen.** 22 files currently sort independently.

## 6. Timezone / locale

Must correctly account for: user locale · user/device timezone · event timezone where semantically relevant · daylight-saving transitions · cross-timezone meetings/events · absolute timestamp preservation.

> **Do not implement this ad hoc in individual widgets** — 35 files currently call `toLocal()` directly.

## 7. Relative time must age coherently

`Just now` · `5 min ago` · `Yesterday` must transition coherently as time passes. **Do not allow stale relative labels to persist because a component never refreshed** — and do not create unnecessary high-frequency client work. A shared strategy is designed later.

## 8. Exact time remains available

Humanized presentation does **not** mean loss of precision. Exact date/time stays available where useful: details · audit-sensitive contexts · scheduled events · hover/secondary presentation · expanded metadata · accessibility where appropriate.

> The ordinary communication surface prioritises human comprehension.

## 9. Relationship to frozen decisions

| Frozen decision | Requirement |
|---|---|
| **FD-1 Attention** | Ordering and labels reflect the event that **created/changed meaningful attention**. **Do not let arbitrary database updates reorder resolved or unrelated attention.** Invitation → invitation event · message → relevant incoming communication · missed realtime → missed interaction event · action resolution → reconciles state **without pretending a new attention event occurred**. |
| **Canonical Product Language Authority** | Posted · Sent · Received · Published · Updated · Invited · Started · Ended must correspond to **real product semantics** — never decorative copy used interchangeably. |

## 10. Cross-product authority direction

Investigate one governed Temporal Presentation authority/primitives responsible for: semantic event type · canonical timestamp selection · relative vs absolute presentation · locale/timezone handling · humanized formatting · exact-time access · sorting semantics · refresh/aging behaviour.

> **Owning domains remain authoritative for what the event means.** The temporal layer renders that meaning coherently.

---

## 11. Frozen doctrine

> **MACHINES STORE PRECISE TIME; PEOPLE EXPERIENCE MEANINGFUL TIME.**
> **EVENT SEMANTICS DETERMINE LABELING AND SORTING.**
> **RAW DEVELOPER TIMESTAMPS SHOULD NOT DOMINATE ORDINARY PRODUCT EXPERIENCE.**
> **THE OWNING DOMAIN DETERMINES WHICH EVENT TIME HAS PRODUCT MEANING.**
> **EXACT TIME REMAINS AVAILABLE WHERE USEFUL.**

## 12. Anti-drift guard

| ❌ Prohibited reading | Why it violates this obligation |
|---|---|
| "`createdAt` is close enough" | §2 — used 295× vs `sentAt` 14×, `receivedAt` 0× |
| "Sort by `updatedAt`, it is always fresh" | §5 — invisible metadata changes reorder the feed |
| "Show the ISO timestamp; it is unambiguous" | §1 |
| "Add a relative-time helper to this widget" | §6, evidence — 52 files already did that |
| "Humanized time means we drop precision" | §8 |
| "Relative labels can refresh on next rebuild" | §7 |
| "Resolving an attention item is a new attention event" | §9 (FD-1) |
| "Use Posted/Sent/Published interchangeably — they read nicely" | §9 (Product Language Authority) |
| "Fix the timestamps on this screen" | §1 — cross-product concern, never screen by screen |
