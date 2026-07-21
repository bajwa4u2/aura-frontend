# Next Work — aura_final

Last updated: 2026-07-21 UTC (AXR-1)

This document lists only remaining work. No item below is authorized as the next milestone until the founder prioritizes it.

## AXR-1: closed 2026-07-21 — founder rulings recorded

All three items from first delivery were ruled on same-day; AXR-1 is certified and fully pushed (`a19547f` / `37cb22f`). Nothing from AXR-1 itself remains open. See `CURRENT_STATE.md` and `DECISIONS.md` for the rulings. The items below are the *accepted future work* those rulings explicitly deferred — not defects, not authorized to start without separate founder direction.

## Accepted future enhancements (unprioritized, explicitly not part of AXR-1)

1. **Topic-scoped search results view.** `#Topic` tap-through seeding general search (`/search?q=%23Topic`) is accepted as AXR-1's final behavior. A dedicated view that filters *specifically* by topic tag rather than general text-matching the `#` would be a genuine future UX improvement.
2. **Governed tagging in meeting notes**, once a meeting-notes composer widget exists (none does today — this is not deferred wiring, it's wiring with no target yet). When that composer is built, wrap its field in `GovernedTagAutocomplete` per the established pattern (see `lib/core/tagging/`).
3. **Meetings/Mentions local badge destinations**, if Profile → Participation → Meeting History (or an equivalent) is ever built — `module_attention.dart` already computes both counts; only the nav destination to attach them to is missing, by founder ruling, not oversight.

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
