# Next Work — aura_final

Last updated: 2026-07-21 UTC (AXR-1)

This document lists only remaining work. No item below is authorized as the next milestone until the founder prioritizes it.

## Priority: push and deploy AXR-1

`main` HEAD `39e3964` (this repo) and `../aura-backend`'s `37cb22f` are committed but not pushed/deployed — AXR-1 implementation is complete and tested, awaiting founder authorization to ship. Push both together (the frontend identity fixes depend on the backend payload fields).

## AXR-1 follow-on items (recorded, unprioritized)

1. **Meetings and Mentions have no member-nav badge destination.** `module_attention.dart` computes unread counts for all four modules (Messages, Institutions, Meetings, Mentions), but the member shell's nav only has Messages and Institutions destinations to attach a badge to — Meetings lives inside the institution shell, and there is no dedicated Mentions surface at all. Those two modules' events still reach global Activity (so nothing is silently dropped), but W2's "no event in only one place" principle isn't fully realized for them. Needs a founder decision: add nav destinations, or accept Activity-only for these two.
2. **`#Topic` tap-through** routes to `/search?q=%23Topic`, which the Search screen now seeds via its query param — but Search doesn't yet filter *specifically* by topic tag (it does a general text search including the `#`). A dedicated topic-scoped results view would be a genuine UX improvement, not a bug.
3. Extend governed tagging to remaining editors named in the original brief not yet wired: institution post composer (`institution_post_composer_screen.dart`), meeting notes (no dedicated composer widget currently exists to wire into).

## Residual founder editorial items (from ROS Phase II closeout, 2026-07-13)

Production content decisions, not code fixes — founder-only:

1. Two live announcements on Aura Platform's own institution feed show raw `[OFFICIAL:ANNOUNCEMENT]` tag syntax in their titles.
2. Aura Platform's own institution profile banner is stock-photo buzzword imagery ("2050 AND BEYOND"), plus a comic-meme official post — the company's own dogfooded account should be the strongest register, not the weakest.
3. "Founder & Steward" booking-page title — backend/profile data, not in frontend source.
4. (Fixed items — trademark symbol, publishing vocabulary — are deployed; do not reopen.)

## Recorded technical items (unprioritized)

- Re-verify the Railway push-to-deploy behavior before relying on it for a release.
- 3 pre-existing lints in `create_meeting_screen.dart` (recorded 2026-07-11).

## Explicit non-work

- Live room internals (`lib/features/live/` room UI) are frozen — do not restyle.
- Nothing under `../../orchestrate/`.
