# C2 — Public Home Consistency & Reconstruction

**Date:** 2026-08-16 · Surfaces: `PublicHomeScreen` (`/`, 1867 lines) and `MemberHomeScreen` (`/home`, 869 lines) plus their shared presentation (`discourse_card.dart`, `unified_feed_card.dart`, feed providers). Audit before reconstruction; every correction below is determined by already-frozen doctrine — no new product decisions were needed or made.

## 1. What Public Home actually was

`/` was already **structurally** discourse-first (Public-UX Phase 7): hero → live-discourse rails (Active / Institution responded) → discussion preview (real `globalPublicFeedProvider` content) → continuity cue → How-Aura-works → Spaces → discovery strip → participation band → footer. Data flow is canonical (global public feed + live discovery + spaces repository; no local relevance reconstruction, no ranking invention, honest "no placeholder that fakes activity" classifier). `/home` is the authenticated stream (unified member feed + pinned announcement + live-now + spaces + next meeting).

**But the words and glyphs contradicted the structure**: the hero was the prohibited institution-first acquisition premise, and verification iconography was reused as a general "institution involved" motif.

## 2. Inventory & classification (summary)

| Surface/component | Class | Disposition |
|---|---|---|
| Hero (`_HeroLeft`, chip, pills) | **RECONSTRUCT** | Institution-first, verification-as-premise copy → public-first (below) |
| `_LiveDiscoursePulse`, `_DiscourseRail`, `_RailPill`, `_RailCard` official-reply row, `_DiscourseRailFooter` | **CONVERGE** | `Icons.verified_rounded` used to mean "institution responded/involved" ×5 → institution glyph; verification glyph reserved for verification |
| `_DiscussionPreviewSection`, `_SpacesSection` states | **CONVERGE** | 4 G5 primitives → `AuraProductState` (retry recovery added); baseline burn-down recorded |
| `_ClassifiedFeed`, feed consumption, ordering, pagination | **KEEP** | canonical feed, honest classifier, no local relevance |
| `_HowItWorksSection` | **KEEP** | already the causal doctrine verbatim (people raise → others respond → institutions act → outcomes public) |
| `_ParticipationBand` | **RECONSTRUCT (copy)** | "Identities are verified." blanket claim → attributable-participation truth; paid-labeled-actions claim verified real (transparency screen + `MonetizationKind.priorityResponse`) and kept |
| `_PublicDiscoveryStrip`, institutions link | **KEEP** | legitimate discovery capability; stale "institutions are the authority roots" comment corrected |
| `discourse_card` pulse icons ×2 | **CONVERGE** | involvement glyph decoupled from verification |
| `unified_feed_card` `_VerifiedInstitutionLine` | **CONVERGE** | hand-rolled icon+label → canonical `InstitutionVerifiedMark` (same visible line, now with semantics/tooltip/meaning) |
| `unified_feed_card` accountability chip | **CONVERGE** | `verified_outlined` for *unresolved* accountability state → `hourglass_top_rounded` (accountability ≠ verification) |
| `unified_feed_card` timestamp | **CONVERGE** | deprecated `formatRelative` shim call → direct `AuraTemporal.humanize(posted, compact)`; shim callers 11→10 |
| MemberHome `_DiscourseStream` states | **CONVERGE + vocabulary** | 2 G5 → `AuraProductState`; retired "works" vocabulary removed ("Could not load works" → "Could not load the stream") |
| Live-now, pinned announcement, next-meeting, spaces (member) | **KEEP** | certified/other-chapter systems consumed at boundary |
| Follow direct-dio sites | **NOT Public Home** | `me_screen.dart` + `follow_requests_screen.dart` — recorded for the remaining C2 convergence/closeout task |

Nothing classified FOUNDER DECISION REQUIRED.

## 3. The hero — before → after

**Before:** chip "Verified institutional communication" (AI-sparkle icon) · headline **"A verified public presence for institutions."** · body "For governments, universities, agencies, and associations: a verified identity, official communication…" · pill "Verified identities" · comment "institutions are the authority roots where public discourse happens."

**After:** chip "Public communication with accountability" · headline **"Public conversation that keeps its context."** · body leads with the person ("Raise what matters in the open, with people who answer under their real identity…") and brings institutions in as accountable participants ("…when institutions take part they respond where everyone can see it — governments, universities, agencies, and associations included. Not a feed. A record."), preserving the strong closing line · pill "Accountable identities" · institutions-directory link kept as legitimate discovery.

## 4. Gate hardening

The public-first causal gate's surface list **did not include the home surfaces** — which is exactly how the institution-first hero survived every pass. Both home screens are now in `_generalSurfaces`, and two new prohibited phrases pin the failure class ("verified public presence", "verified institutional communication"). The gate caught its own first run against a comment quoting the old hero — proof it bites.

## 5. Doctrine boundaries enforced

- **Verification glyph reserved for verification** — 8 involvement/accountability motifs across three files no longer borrow `verified_rounded`/`verified_outlined`; institutional involvement reads as attribution (`account_balance`), verification marks remain canonical trust-layer only.
- **No blanket trust claims** — "Identities are verified." removed; participation described as attributable, which is the actual product truth.
- **Temporal, state, vocabulary** — one temporal dialect, C0 product states with retry recovery, retired "works" vocabulary gone from the release surface.

## 6. What was deliberately NOT done

No ranking/recommendation invention (feed relevance stays canonical) · no auth-policy change (`/` remains public, `/home` authenticated — existing frozen behavior) · no redesign of certified Posts/Announcements/Meetings consumption · no commercial surfacing (§29) · no second design system (all edits use existing tokens/primitives) · availability deliberately not added to Home (it has not earned a place in the entry experience; the authority exists for surfaces that need it).

## 7. Measurements

G5: public_home 4→0, member_home 2→0 (baseline updated with dated burn-down notes; ratchet green). Temporal shim callers 11→10. Generic trust-glyph misuse on Home surfaces: 8→0. `'Try again'`: 0. Gates: C0/C1/C2/public-first all green; full suite 534 green; analyze clean.

## 8. Empty/new-user experience

Verified honest: empty feed shows a truthful empty state ("No public discussions yet…") plus the live-discourse placeholder explaining the surface exists, spaces and discovery remain reachable, How-it-works explains the loop. Member home's empty stream keeps live-now + spaces entry points so the account never opens onto a dead page. No fake activity, no invented recommendations.
