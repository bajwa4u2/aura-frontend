# FD-12 — DEAD / NEAR-DEAD SURFACES: PROVEN-DEAD RETIREMENT ONLY

# STATUS: FROZEN — FOUNDER APPROVED 2026-08-15
# SELECTED: OPTION A — RETIRE ONLY WHAT IS PROVEN DEAD; ADJUDICATE LOW-REFERENCE SURFACES IN THEIR OWNING CHAPTERS

---

## 1. Confirmed dead surface

**`conversations_screen.dart` — APPROVED FOR RETIREMENT.**

Evidence accepted: zero router references · only self-references · confirmed unreachable · ~1,033 lines · belongs to already-approved Attention/Inbox demolition territory · contains the codebase's **only** identified `sortDate: updatedAt` ordering pattern, conflicting with the frozen Human Temporal Presentation direction.

> **Do not preserve this surface merely because substantial code was already written.**

## 2. Authorization ≠ implementation

This decision authorises **disposition**. **Do NOT delete frontend code during adjudication.**

Removal occurs in the appropriate implementation/cleanup chapter with: dependency verification · regression · route/build verification · valid behaviour/data salvage where any exists.

## 3. Low reference ≠ dead

> **Do NOT classify a surface as dead merely because static reference count is low.**

These remain **candidates, not retirement decisions**: `InstitutionCorrespondenceScreen` · `PresenceScreen` (declared within `me_screen.dart`) · `SupportScreen` · `LoginScreen`. **Evidence is insufficient for deletion today.**

## 4. Ownership of remaining candidates

| Candidate | Adjudicated in |
|---|---|
| `InstitutionCorrespondenceScreen` | correspondence/communication reconstruction |
| `PresenceScreen` | canonical Identity/Profile/Presence reconstruction (FD-11) |
| `LoginScreen` | authentication/navigation review |
| `SupportScreen` | determine legitimate product/monetization ownership before disposition |

> **These candidates must not disappear from the obligation register simply because FD-12 closes.**

## 5. PresenceScreen

**Not a standalone delete candidate.** Structurally entangled with the existing Me/Profile implementation; adjudicated through the frozen **Canonical Identity Presentation + Contextual Projection** reconstruction. **Do not remove it independently based on reference count.**

## 6. The LoginScreen false-positive lesson *(recorded as evidence)*

> **STATIC REFERENCE COUNT ALONE IS NOT A SAFE REACHABILITY AUTHORITY.**

Indirect routing, generated registration, registry-driven navigation or other legitimate architecture can make a valid surface appear unreferenced to simple grep analysis. **Future enforcement must understand the governed route/surface architecture.**

## 7. Future surface governance principle *(FOUNDER APPROVED)*

> **EVERY PRODUCTION SURFACE MUST HAVE AN EXPLICIT, AUDITABLE REACHABILITY / OWNERSHIP PATH — OR BE EXPLICITLY CLASSIFIED AS A LEGITIMATE NON-ROUTABLE / INTERNAL SURFACE.**

A screen must not remain in production indefinitely merely because nobody knows whether it is still used.

For every surface it must be answerable: **What product/domain owns it? · How is it reached? · Is it user-routable, contextual, modal/internal, or deprecated? · Who consumes it? · Is it still part of the Release Client? · If intentionally non-routable, why?**

## 8. Do NOT freeze a naïve zero-reference gate

> **Do NOT implement or freeze "screen has zero direct references → fail build".**

That would risk false positives such as `LoginScreen`. **Enforcement must be architecture-aware.**

Possible mechanisms: canonical surface registry · canonical route registry · declared owner/reachability metadata · architecture tests · explicit internal/non-routable classification · stale/deprecated surface detection.

**Exact mechanism belongs to FD-13.**

## 9. Temporal authority consequence

The `updatedAt` sorting hazard disappears when the dead surface is removed.

> **Do NOT treat removal of that one instance as proof that Temporal Presentation / sorting semantics are solved.** The frozen cross-product Temporal Authority still applies throughout reconstruction.

## 10. General retirement doctrine *(frozen)*

> **PROVEN DEAD → AUTHORIZE RETIREMENT.**
> **LOW REFERENCE → INVESTIGATE IN OWNING CONTEXT.**
> **INDIRECTLY REACHABLE → PRESERVE IF PRODUCT-CORRECT.**
> **SEMANTICALLY SUPERSEDED → RETIRE DURING THE REPLACEMENT CHAPTER.**
> **DO NOT DELETE FROM GREP COUNT ALONE.**
> **DO NOT PRESERVE FROM FEAR ALONE.**

## 11. Anti-drift guard

| ❌ Prohibited reading | Why it violates FD-12 |
|---|---|
| "Delete all five low-reference screens" | §3 — only one is proven dead |
| "Delete conversations_screen now" | §2 — disposition authorised, not implementation |
| "Keep it; 1,033 lines is a lot of work to lose" | §1 |
| "Remove PresenceScreen, it's barely referenced" | §5 — entangled with FD-11 reconstruction |
| "Zero references → fail the build" | §8 — would have flagged LoginScreen |
| "FD-12 closed, so the candidates are settled" | §4 — they carry forward to their owning chapters |
| "The sorting hazard is gone, temporal is handled" | §9 |
| "Nobody knows if it's used, so leave it" | §7 — that is precisely the condition being outlawed |
