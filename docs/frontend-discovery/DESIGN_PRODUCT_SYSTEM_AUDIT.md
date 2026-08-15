# Design System vs Product System Audit

> ✅ **CAPABILITY-ADAPTIVE EXPERIENCE — FROZEN 2026-08-15 (cross-product principle).** Finding D2 below — *visual coherence has been masking product divergence* — is now answered by governing doctrine: **the experience architecture itself must change; today's role-fragmented experience must not be reconstructed with prettier components.** Progressive disclosure is a governing requirement, management is object-local where practical, and the client determines presentation hierarchy — never permission. See `CAPABILITY_ADAPTIVE_EXPERIENCE_FROZEN.md`.
>
> ✅ **CANONICAL IDENTITY PRESENTATION — FROZEN 2026-08-15** adds identity primitives to the *product interaction system* column: avatar/name treatment, verification presentation, relationship and acting-identity rendering are **governed projections**, not per-surface styling choices. See `CANONICAL_IDENTITY_PRESENTATION_FROZEN.md`.
>
> ✅ **CANONICAL PRODUCT LANGUAGE AUTHORITY — FROZEN 2026-08-15** adds CTA families, action labels and **state terminology** to the governed product interaction system. The state language in Finding D3 is therefore a product-language obligation, not per-module wording: **same action → consistent language; different action → preserve meaningful distinction**. See `NAVIGATION_IA_PRODUCT_LANGUAGE_FROZEN.md`.

## FINDING D1 — A shared visual system exists and is only half adopted

**Evidence.**

| Shared component | Files using it | Competing raw pattern | Files using that |
|---|---|---|---|
| `AuraLoadingState` | 63 | raw `CircularProgressIndicator` | **83** |
| `AuraErrorState` (74 uses) | — | ad-hoc error `Text` | widespread |
| `AuraEmptyState` (40 uses) | — | `SizedBox.shrink()` as empty | **68** |

**PRODUCT CONSEQUENCE.** More files hand-roll a spinner than use the shared loading state. `SizedBox.shrink()` standing in for an empty state means **68 files can render nothing at all** where an empty state belongs — silent blankness is the worst possible empty state, because it is indistinguishable from a bug.

**ROOT CAUSE.** The design system arrived after many screens existed; adoption was started and never completed or enforced.

**CLASSIFICATION.** REFACTOR + enforce. The system is sound; adoption is the failure.

**RECOMMENDATION.** Do not redesign these components. Complete adoption and add a source-level gate, exactly as the backend did for duplicated person projections.

**FD-13 (FROZEN 2026-08-15)** makes this binding: the gate **hard-fails**, ships **with** the migration, and permits only explicit narrow exceptions. Legitimate local visual primitives may remain where semantically warranted — as declared exceptions, not as silent accumulation. See `FD13_ENFORCEMENT_MECHANISMS_FROZEN.md`.

**FOUNDER DECISION.** No — objective.

---

## FINDING D2 — Visual coherence has been masking product divergence

Shared components (`AuraScaffold`, `AuraText`, `AuraSurface`, `aura_radius`, `aura_space`, `substrate_chip`, `aura_platform_components`) are widely used — including by `institution_live_rooms_screen`, which is fully on-system visually while being architecturally disconnected from every realtime authority and consuming raw JSON maps.

**A surface can look correct and be architecturally wrong.** This is why "the app looks consistent" has not prevented the drift documented elsewhere in this discovery.

**CLASSIFICATION.** SEPARATE the two systems explicitly:

| Visual Design System | Product Interaction System |
|---|---|
| typography, spacing, colour, radius | composer, attachment, participant list |
| buttons, cards, fields, dialogs | profile, inbox, attention, badges |
| scaffold, surfaces, chips | realtime room, host controls, admission |
| loading/empty/error **presentation** | loading/empty/error **semantics** |

The visual system is in good shape. The product interaction system does not exist yet.

---

## FINDING D3 — No shared state language

There is no single definition of what loading, empty, error, offline, reconnecting, unauthorized, deleted, unavailable, expired, sending, pending, disabled or destructive-confirmation mean as a *set*. Components exist for three of them; the rest are improvised per module.

**CLASSIFICATION.** REFACTOR — define the state language, then enforce it.

**RECOMMENDATION.** Derive the vocabulary from states the frozen backend can actually produce, so the client can express real outcomes rather than generic failure:

- delivery `SKIPPED` / `FAILED`, `WNS_CHANNEL_EXPIRED`
- transfer `OFFERED` / `ACCEPTED` / `REJECTED` / `EXPIRED` / `FAILED`
- integrity `REQUIRE_ACKNOWLEDGEMENT` / `REQUIRE_ADDITIONAL_REVIEWER` / `REQUIRE_INSTITUTIONAL_APPROVAL`
- account lifecycle `SELF_DELETED` / `PENDING_DISPOSITION`
- room `INVITED` / `JOINED` / `LEFT` / `REMOVED`

The client currently has no vocabulary for most of these, which means a governed backend outcome degrades to a generic error toast.

**FOUNDER DECISION.** No for existence. Yes for how much backend state is exposed as product language.

---

## FINDING D5 — Temporal presentation drift *(founder-surfaced; this audit missed it)*

**Evidence.** Shared helpers exist and are barely adopted: `relative_time.dart` **9 consumers** vs **52 files** computing `.difference(` independently; `local_timezone.dart` **3 consumers** vs `toLocal()` in **35 files**; `DateFormat` in only 5 files; **22 files** sorting independently. Timestamp semantics collapse onto `createdAt` (**295** uses vs `sentAt` 14, and `receivedAt`/`occurredAt` **never used**).

**PRODUCT CONSEQUENCE.** The same "shared authority arrived late, adoption never finished" pattern as `AuraLoadingState`. Time is presented and sorted by whichever field was convenient, so a feed can reorder on invisible metadata changes and the product has no way to say *received* or *occurred*.

**CLASSIFICATION.** ✅ **GOVERNED — Human Temporal Presentation Authority, FROZEN 2026-08-15.** Temporal presentation joins the **product interaction system** alongside the state language: both are semantics, not per-module wording. See `HUMAN_TEMPORAL_PRESENTATION_AUTHORITY_FROZEN.md`.

---

## FINDING D4 — Performance / complexity hotspots (architectural, not premature)

| Risk | Evidence |
|---|---|
| Oversized route file | `router.dart` 2,100 lines, 171 routes, 27 redirects |
| Oversized screens | 3,890 / 3,385 / 3,265 / 2,737 / 2,209-line files |
| Duplicate fetch paths | 3 live-room data paths; 8 attention surfaces each fetching |
| Raw-map consumption | `institution_live_rooms_screen` parses untyped JSON |
| Retained state | 4 shells + `member_shell` 2,034 lines |
| Media memory | 11 independent upload/preview implementations |

**CLASSIFICATION.** REFACTOR — these are architectural hotspots, not micro-optimisations. No optimisation is recommended before the authority consolidation, which removes most of them as a side effect.
