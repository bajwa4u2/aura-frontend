# Decisions — aura_final

Last updated: 2026-07-21 UTC (AXR-1 closeout)

Founder-approved decisions governing this repository (recorded retroactively at continuity establishment, 2026-07-21).

## 2026-07-21: AXR-1 closeout rulings

Decision, founder-issued to resolve the three items AXR-1's first delivery left open:

1. **No Meetings or Mentions nav destinations solely for badges.** Meeting notifications remain Activity-only until Profile → Participation → Meeting History exists. Mention notifications must deep-link to their referenced content instead of getting a dedicated tab — confirmed already true (see below), not a new build.
2. **Topic-seeded search is accepted as AXR-1's final behavior.** A dedicated topic-scoped view is future enhancement only, not required for this milestone.
3. **The institution post composer is in scope.** It is a real, routed, active production surface — inspected and confirmed, not assumed. It gets governed tagging like the other three composers. Meeting notes do not, because no meeting-notes composer exists yet; that's a future integration requirement, not a deferred build.

Verification for (1): `MENTION` notifications already carry `postId` (the reply/post containing the mention — backend `posts.service.ts`'s mention fanout: `postId: created.id`), and `notifications_screen.dart::_routeFor` already resolves `postId` → `/posts/:id`, a route that serves both posts and replies. No code change was needed — the deep-link requirement was already satisfied by existing infrastructure; verifying that first is what avoided building a redundant Mentions tab.

Reason: keeps the badge/nav surface exactly as large as real destinations justify (Single Intent Principle spirit — don't add a nav item whose only job is carrying a number), while confirming attention still reaches the user through Activity + the correct deep link.

Repository impact: `institution_post_composer_screen.dart` wired with `GovernedTagAutocomplete` (commit `a19547f`). No routing changes — the mention deep-link was verified, not built.

## 2026-07-21: Governed tagging is platform infrastructure, not a Post feature

Decision: `@member` / `@institution` / `#topic` tagging lives in `lib/core/tagging/` and is entity-agnostic (`TagKind` is an open enum). Any text-composing surface adopts it by wrapping its existing `TextEditingController`/`FocusNode` in `GovernedTagAutocomplete` — not by reimplementing autocomplete per surface.

Reason: the brief was explicit that tagging must generalize across posts, comments, replies, messages, announcements, meeting notes, Studio-generated content, and future editors without redesign per surface.

Alternatives considered: a Post-scoped mention widget extended ad hoc per surface — rejected; would recreate the exact per-surface drift the brief was trying to eliminate.

Repository impact: `lib/core/tagging/`; wired into post compose, thread messages, institution announcements (commit `39e3964`).

## 2026-07-21: Module attention derives from one source, never a parallel count

Decision: per-module unread badges (`module_attention.dart`) are a pure projection over the same notification rows the global Activity bell already polls. No module maintains its own unread count.

Reason: a second unread source is a second thing that can drift from the first — the exact "fragmented attention" defect the brief named as the problem to fix.

Repository impact: `moduleAttentionProvider`; wired into member shell side rail + bottom nav.

## 2026-07-21: Identity rendering precedence — canonical widget, not per-surface fallback logic

Decision: photo → institution logo → approved avatar → initials → placeholder, implemented once in `AuraAvatar` (`lib/core/ui/aura_platform_components.dart`). Surfaces rendering identity must delegate to it, not reimplement a `CircleAvatar`/initials fallback.

Reason: five surfaces had silently drifted from the canonical widget over time, each with its own incomplete fallback that skipped the image even when one existed. See `../aura-backend/audit/working-directory/DECISIONS.md` for the paired server-side decision (payloads must include the image field).

Repository impact: `admin_institution_members_screen.dart`, `new_conversation_screen.dart`, `space_screen.dart::_IdentityAvatar`, `meeting_detail_screen.dart`, `search_screen.dart::_InstitutionTile` — all five now delegate to `AuraAvatar` or an equivalent logo-with-fallback path (commit `39e3964`).

## 2026-07-11: No identity forms at meeting doors

The pre-join guest name/email form is deleted; identity renders from resolver outcomes only ("Invited as <name>", OTP verification, or login). Do not reintroduce.

## 2026-07-11: Member booking identity is read-only

Authenticated members see a read-only "Booking as" card; name/email fields render only for anonymous visitors.

## 2026-07-10/11: Live room internals are frozen

Meeting workspace surfaces migrated to AuraSurface tokens, but the live room's internals were explicitly left untouched and stay frozen.

## 2026-07-13: ROS Phase II verdict

VERIFIED WITH RESIDUAL FOUNDER EDITORIAL ITEMS. Audit and deployment were two separately authorized founder missions; follow the two-stage pattern.

## Frozen classification

Aura's product architecture was frozen 2026-07-12 (`AURA_REPRESENTATION_MODULE_INVENTORY.md`, `AURA_PLATFORM_ARCHITECTURE.md` — in `representation/inventory/`). When a later audit runs, Phase 1 is "confirm and cite," never "re-derive and re-freeze."
