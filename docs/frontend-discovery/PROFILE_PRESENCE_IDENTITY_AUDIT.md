# Profile / Presence / Identity Audit

> ✅ **RESOLVED — CANONICAL IDENTITY PRESENTATION + CONTEXTUAL PROJECTION, FROZEN 2026-08-15** (register **FD-11**).
>
> **PERSON ≠ INSTITUTION ≠ MEMBERSHIP ≠ ACTING CONTEXT ≠ PRESENCE**, never collapsed, in one coherent experience. A member is a Person + relationship, **not a third identity type**. **IDENTITY FIRST · CONTEXT SECOND · ACTIONS THIRD · METADATA ON DEMAND.** Institution is a first-class identity. **Technical connectivity does not automatically become social presence.** Verification keeps layered meaning without badge clutter. Public/member profile = demolish + rebuild. See `CANONICAL_IDENTITY_PRESENTATION_FROZEN.md`.

> ✅ **FD-10 (FROZEN):** **Presence survives as the authority/domain concept** — **not** globally renamed to Availability, which is only one human projection of it. Ordinary UI expresses the meaningful human state rather than exposing "Presence" as a technical noun, and **local surfaces must never infer presence independently**. **Verification keeps its layered meaning** — no generic "Verified" label; each frozen class is mapped before labels are chosen. See `FD10_TERMINOLOGY_FROZEN.md`.

## FINDING P1 — "Presence" carries six unrelated meanings

**Evidence.** Symbol census across `lib/`:

| Symbol | Meaning |
|---|---|
| `PresenceScreen` (declared inside `me_screen.dart`) | the person's own hub/profile |
| `FeedPresence`, `FeedPresenceState` (18 + 13 uses) | presence *within the feed* |
| `PresenceStatus`, `PresenceState` (10 + 12) | online/offline availability |
| `CallPresenceState`, `callPresenceBridgeProvider` (7 + 6) | device availability for calls |
| `PresencePublication`, `PresenceLink` (6 + 6) | published/representational presence |
| `PresencePinger` (5) | heartbeat transport |
| `PresenceHeaderAction` (20) | a UI action |

**PRODUCT CONSEQUENCE.** One word means the person's page, their online dot, their device call-readiness, their published identity, and a heartbeat. Nobody — user or engineer — can reason about "presence" reliably.

**ROOT CAUSE.** The word was reused each time a new adjacent concept appeared.

**CLASSIFICATION.** SEPARATE, then rename. These are five distinct product concepts.

**Proposed separation (for adjudication):**

| Concept | Question it answers | Owner |
|---|---|---|
| **Identity** | who is this person, verifiably | backend identity + verification authority |
| **Profile** | how they present themselves | profile surface |
| **Availability** | can they be reached right now | presence/device authority |
| **Relationship** | what is my connection to them | relationship authority |
| **Participation** | are they in this live context now | realtime session |

**FOUNDER DECISION.** ✅ **RESOLVED (FD-11).** The five concepts are frozen as distinct and must never be collapsed; presence is a **contextual projection**, not identity, and infrastructure telemetry (socket, device, `lastSeen`, transport state) must not be exposed socially. *Whether the word "Presence" survives as user-facing copy remains open under FD-10.*

---

> **FD-12 (FROZEN):** `PresenceScreen` (declared inside `me_screen.dart`) is **NOT a standalone delete candidate**. It is structurally entangled with the Me/Profile implementation and is adjudicated **through this reconstruction**, never removed on reference count. See `FD12_SURFACE_DISPOSITION_FROZEN.md`.

## FINDING P2 — Profile is split across two features with no boundary

**Evidence.** `features/profile/` (7 files: author profile, followers, following, follow requests) and `features/me/` (10 files, 7,219 lines, incl. `me_screen.dart` 1,905 and `edit_profile_screen.dart` 1,948). `PresenceScreen` is declared inside `me_screen.dart`. Institution profile is a third implementation: `institutions/profile/institution_edit_profile_screen.dart` (2,153).

So: viewing someone else = `profile/`; viewing yourself = `me/`; institution = `institutions/profile/`. Three implementations of "a profile".

**PRODUCT CONSEQUENCE.** Editing your profile and editing an institution profile are ~4,100 lines of parallel implementation. Self-view and other-view diverge in what they show.

**CLASSIFICATION.** MERGE — one profile presentation authority, parameterised by subject (person / self / institution) and viewer relationship.

**FOUNDER DECISION.** ✅ **RESOLVED (FD-11).** One canonical identity presentation with contextual projection — no separate personal/member/institution profile architectures, and **no "Member" identity type**. Consolidation confirmed; the reconstruction is a demolish + rebuild, not cosmetic cleanup.

---

## FINDING P3 — Profile is visually heavy (founder-observed, confirmed)

`edit_profile_screen` 1,948 lines and `institution_edit_profile_screen` 2,153 lines indicate a very large surface area of profile fields.

**Recommended hierarchy for adjudication:**

| Tier | Content |
|---|---|
| Immediate | name, handle, verification state, institution affiliation, one primary action |
| Secondary | relationship state, availability, short bio |
| Progressive disclosure | activity, followers/following, credentials, extended metadata |
| Moved elsewhere | editing (own surface), governance/admin (institution dashboard) |

**Simplification must not remove capability** — verification, affiliation and credential state are governed backend truths (D4 layered verification: IDENTITY / INSTITUTION_AFFILIATION / ROLE_OR_CREDENTIAL) and must remain expressible. The three verification layers are independent and must never be collapsed into one "verified" tick — the client currently shows `'Verified'` as a single label in 4 places.

**FOUNDER DECISION.** ✅ **RESOLVED (FD-11).** Frozen hierarchy: **IDENTITY FIRST · CONTEXT SECOND · ACTIONS THIRD · METADATA ON DEMAND**, with the smallest useful current action set. The three verification layers must remain independently expressible — **no boolean flattening, no enum leakage, no badge clutter**. Exact verification presentation remains later design.
