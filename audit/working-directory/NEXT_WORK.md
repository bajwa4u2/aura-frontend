# Next Work - aura_final

Last updated: 2026-07-21 UTC (Post Integrity Remediation)

This document lists only remaining work. No item below is authorized as the next milestone until the founder prioritizes it.

## Current remediation follow-up

1. Complete Flutter test-suite verification from a healthy runner. In this Windows workspace, `flutter test` hangs before test output even on pre-existing tests; `flutter analyze` is clean.
2. After deployment, production-verify post draft discard, token-only draft suppression, topic enforcement, member edit, and institution edit with seeded production-like accounts.
3. Re-verify the Railway push-to-deploy behavior before relying on it for a release.

## Accepted future enhancements (unprioritized, explicitly not part of AXR-1)

1. Topic-scoped search results view. `#Topic` tap-through seeding general search (`/search?q=%23Topic`) is accepted as AXR-1's final behavior. A dedicated view that filters specifically by topic tag remains a future UX improvement.
2. Governed tagging in meeting notes, once a meeting-notes composer widget exists. When that composer is built, wrap its field in `GovernedTagAutocomplete` per the established pattern.
3. Meetings/Mentions local badge destinations, if Profile -> Participation -> Meeting History or an equivalent is ever built. `module_attention.dart` already computes both counts; only the nav destination to attach them to is missing by founder ruling.

## Residual founder editorial items (from ROS Phase II closeout, 2026-07-13)

1. Two live announcements on Aura Platform's own institution feed show raw `[OFFICIAL:ANNOUNCEMENT]` tag syntax in their titles.
2. Aura Platform's own institution profile banner is stock-photo buzzword imagery ("2050 AND BEYOND"), plus a comic-meme official post.
3. "Founder & Steward" booking-page title is backend/profile data, not frontend source.

## Recorded technical items (unprioritized)

- 3 pre-existing lints in `create_meeting_screen.dart` (recorded 2026-07-11).

## Explicit non-work

- Live room internals (`lib/features/live/` room UI) are frozen; do not restyle.
- Nothing under `../../orchestrate/`.
