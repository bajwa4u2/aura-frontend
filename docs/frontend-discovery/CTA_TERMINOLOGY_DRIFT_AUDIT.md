# CTA & Terminology Drift Audit

> **FD-8 (FROZEN 2026-08-15) adds a workflow-language obligation.** Where an actor may designate but not approve, the flow becomes something equivalent to **DESIGNATE AS OFFICIAL -> SUBMIT FOR APPROVAL**, and the consequence must be legible **before** commitment. The client currently has **no product language at all** for official designation or the institutional approval floor. Final copy is decided under FD-10. See `FD8_OFFICIAL_DESIGNATION_MOMENT_FROZEN.md`.
>
> ✅ **HUMAN TEMPORAL PRESENTATION AUTHORITY — FROZEN 2026-08-15** adds **temporal verbs** to the product-language scope: Posted · Sent · Received · Published · Updated · Invited · Started · Ended must correspond to **real product semantics**, never used interchangeably as decorative copy. See `HUMAN_TEMPORAL_PRESENTATION_AUTHORITY_FROZEN.md`.

> ✅ **GOVERNED — CANONICAL PRODUCT LANGUAGE AUTHORITY, FROZEN 2026-08-15.**
>
> Drift is to be resolved **systematically, never one screen at a time**. Governing rule: **CONVERGE SYNONYMS · PRESERVE GENUINE SEMANTIC DISTINCTIONS** — and **SAME ACTION → CONSISTENT LANGUAGE; DIFFERENT ACTION → PRESERVE MEANINGFUL DISTINCTION**.
>
> **Semantic truth first, vocabulary second.** Where drift reflects **duplicated architecture**, renaming is insufficient — the screens themselves must converge. Where two different concepts share one label, they must be distinguished.
>
> ✅ **FD-10 RESOLVED / FROZEN 2026-08-15 — canonical semantic vocabulary.** `RETRY` is the canonical failed-operation CTA. **Cancel / Dismiss / Close / Discard are FOUR distinct semantic families**, not synonyms (this audit's original premise was corrected by the founder). Correspondence, Post, Presence, Follow/Connect and layered verification are ruled below. See `FD10_TERMINOLOGY_FROZEN.md`.
>
> **Exact final presentation copy may still be refined during design; the underlying semantic vocabulary is frozen.** Historical note: this audit previously stated no terminology was frozen — this freeze establishes the method and authority, not the words. See `NAVIGATION_IA_PRODUCT_LANGUAGE_FROZEN.md`.

## FINDING T1 — Same action, two labels, near-equal usage

**Evidence.** Button label census across `lib/features`:

| Label | Count |
|---|---|
| `Try again` | 29 |
| `Retry` | 22 |

One recovery action, two words, essentially split down the middle. This is the cleanest possible proof that no CTA authority exists.

Others in the same census: `Cancel` 21 · `Dismiss` 6 · `Close` 5 · `Discard` 3 — four words competing for "stop/undo" with no stated distinction.

**CLASSIFICATION.** SIMPLIFY — one CTA vocabulary, enforced.

---

## FINDING T2 — Architectural vocabulary users never see

**Evidence.** 3,733 user-visible string literals scanned.

| Term | In code / routes | In user-visible strings |
|---|---|---|
| **Correspondence** | feature dir, `/me/correspondence/*` routes, repositories | **0** |
| **Presence** | 7 distinct symbols | **0** |
| Conversation | dead screen only | used throughout correspondence UI |
| Space | routes + UI | 7 |

Inside `features/correspondence/`, the words users actually see are **"conversation"**, **"space"**, **"Archive conversation"**, **"Archived spaces"** — never "correspondence".

**PRODUCT CONSEQUENCE.** The architecture is named for concepts the product does not speak. Engineers navigate by "correspondence"; users experience "conversations". Every conversation about the product requires translation, and Representation/company language adds a third vocabulary.

**CLASSIFICATION.** FOUNDER DECISION REQUIRED — this is a naming decision with company-canon consequences, not an engineering cleanup.

**OPTIONS.**
- A. User language wins: rename the architecture to Conversation/Space.
- B. Canon language wins: surface "Correspondence" in the product.
- **C. Deliberate two-layer naming:** Correspondence remains the *governance* concept (as the backend and Representation use it); Conversation remains the *user* concept. Documented, not accidental.

**RECOMMENDATION.** C, **if and only if** it is written down. The current state is C by accident, which is indistinguishable from drift.

---

## FINDING T3 — CTA semantic map (initial)

Terms requiring adjudication before any rebuild. `Action` column is a proposal, not a decision.

| Current CTA | Product intent | Competing labels | Issue |
|---|---|---|---|
| Try again / Retry | recover from error | both | pick one |
| Cancel / Dismiss / Close / Discard | stop or undo | four | undefined distinction |
| Post / Work | publish personal content | both (4 each) | noun/verb collision |
| Message / Correspondence | start or open a conversation | Message user-facing, Correspondence architectural | layer mismatch |
| Profile / Presence | a person's page | Presence has 6 meanings | overloaded |
| Join / Attend / Enter | enter a live context | Join (4) | which for meeting vs room vs live? |
| Follow / Connect | relationship | Follow (12), Connect (0 as CTA) | is there one relationship or two? |
| Member / Participant | a person in a context | Member (21), Participant (0 user-visible) | backend distinguishes them |
| Publish / Send | commit a composition | both | must differ once E_OFFICIAL approval exists |
| Live / Meeting / Room | realtime context | Live (15), Meeting (0 in sampled strings) | the core semantic question |

**Note on Member vs Participant.** The frozen backend deliberately separates institution *membership* (entitlement) from room *participation* (interruption eligibility). The client uses "Member" 21 times and "Participant" never — so the distinction D5 makes structural is invisible in the product.

**FOUNDER DECISION.** **Method RESOLVED; vocabulary still OPEN (FD-10).**

Each row must first be settled as a **semantic** question — *are these the same product concept or genuinely different?* — before any word is chosen. Worked examples given in the freeze: if Works and Posts are one concept, one term survives; if Presence and Profile are genuinely distinct, both survive and are never interchangeable; if Correspondence is a governed form genuinely different from DM/Message, both survive because the products differ.

Rows whose drift reflects **duplicated architecture** (e.g. Correspondence/Conversation, Profile/Presence) cannot be closed by renaming — see `NAVIGATION_IA_PRODUCT_LANGUAGE_FROZEN.md` §15.
