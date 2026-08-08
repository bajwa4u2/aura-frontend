# Next Work - aura_final

Last updated: 2026-08-08 UTC (Canonical Flutter Thread-Call Lifecycle Stage 1 locally certified)

This document lists only remaining work. No item below is authorized as the next milestone until the founder prioritizes it.

## Canonical Flutter Thread-Call Lifecycle - Stage 1

Status: implemented and locally certified in the working tree; pending founder Gate 2 review and commit authorization. Blueprint/design record: `docs/2026-08-08-canonical-flutter-thread-call-lifecycle-stage-1-blueprint.md`.

Frozen scope:

- foreground incoming-call ownership;
- caller/callee realtime synchronization;
- app-root Thread-call lifecycle owner;
- one active call intent keyed by `sessionId + current user`;
- existing `RealtimeController` remains the realtime socket/media/session owner;
- root-mounted incoming-call presentation;
- client-only Thread call phases for presentation/runtime.

Deferred: Activity doctrine, multi-device accept/decline arbitration, desktop native notifications, Android/iOS background and terminated push handling.

Meetings hard gate: no Meeting behavior change. If shared `RealtimeController`, `RealtimeState`, `RealtimeSocketService`, `RealtimeMediaService`, or route behavior must change, add Meeting regressions and preserve waiting room, admission, guest handling, host controls, Meeting reconnect, leave/end, Meeting UX, and Meeting notification semantics.

Remaining Stage 1 gates:

1. Founder review of local implementation and Gate 2 report.
2. Commit authorization.
3. No further local verification gate is known. The prior Flutter test/build hang was traced to Flutter SDK Git safe-directory/tool startup and certification now passes when commands are run with the explicit `C:/flutter` safe-directory environment override.

Closed Stage 1 decisions:

1. Root owner placement is `AuraApp` through `ThreadCallLifecycleHost` under the existing notification/app boundary.
2. Shared realtime touch boundary was preserved. `RealtimeController`, `RealtimeState`, `RealtimeSocketService`, `RealtimeMediaService`, and generic realtime route behavior were not edited.

## Thread Calling Reliability - Flutter repair program

Status: read-only collective audit recorded in `../aura-backend/docs/2026-08-08-thread-calling-reliability-collective-audit.md`. No Flutter application/runtime/schema/client code was edited.

Do not reopen backend Reachability Authority, Session Continuity Authority Phase 1, or Canonical Call Notification Stage A from this item. Do not modify Meetings without explicit proof and regression coverage that current Meeting behavior is unchanged.

1. ~~Founder decision required - shared foreground call consumer ownership.~~ **Implemented locally in Stage 1; pending founder review/commit.**
2. ~~Founder decision required - caller/callee synchronization pass.~~ **Implemented locally in Stage 1 as Thread-specific lifecycle coordination over existing `RealtimeController` outputs; pending founder review/commit.**
3. **Founder decision required - Activity doctrine for active calls.** Activity currently reads `/notifications`; Stage A calls create Communication rows. Coordinate with backend before changing Flutter Activity behavior.
4. **Founder decision required - multi-device doctrine.** Current backend rings all eligible devices but allows one same-user media owner by default. Client work must honor the final accepted/replaced/terminal synchronization doctrine.
5. **Platform-specific notification work remains later.** Desktop native push is absent; Android/iOS background and terminated notification display require separate native release work after foreground lifecycle is resolved or explicitly deprioritized.

## Current remediation follow-up

1. ~~Complete Flutter test-suite verification from a healthy runner.~~ **RESOLVED, 2026-08-02**: `flutter test` (full suite, 76 tests) and `flutter analyze` both ran cleanly to completion in this same Windows workspace during the cold-deep-link investigation below — the earlier "hangs before test output" symptom did not reproduce. 1 pre-existing, unrelated failure (`governed_tag_persistence_test.dart` — a stale username fixture, confirmed present on a clean `git stash` of unrelated changes) and 1 pre-existing, documented golden-test skip (`realtime_room_golden_test.dart`) remain; neither is new.
2. After deployment, production-verify post draft discard, token-only draft suppression, topic enforcement, member edit, and institution edit with seeded production-like accounts.
3. Re-verify the Railway push-to-deploy behavior before relying on it for a release.
4. After the edit-save/mention fix deploys, production-verify member edit save, institution edit save, keyboard mention selection, and mouse/touch mention selection.

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
- **RESOLVED (does not reproduce), 2026-08-02 — Cold deep-link reload redirects an authenticated session to `/login`.** Originally recorded 2026-08-02 as an incidental, unconfirmed finding (see prior text below). Direct investigation traced the full chain — `router.dart`'s `redirect` callback, `authStatusProvider`/`sessionBootstrapProvider` (`session_providers.dart`/`session_bootstrap.dart`), and `TokenStore` (`auth_providers.dart`) — and then reproduced the exact described scenario live: a `flutter build web` release build served with an SPA-fallback static server, driven by real browser navigation (confirmed via `performance.getEntriesByType('navigation')` to be a genuine top-level document load, not an SPA-internal route change) against a local mock backend whose `/auth/refresh` carried an artificial 3-5s network delay to widen the race window.
  - **Root cause finding: the suspected race does not currently exist.** `authStatusProvider` (`session_providers.dart:59`) already gates on `sessionBootstrapProvider`'s own loading state (`if (boot.isLoading) return AuthStatus.loading`), and `router.dart`'s `redirect` treats that as `isBootstrapping` and parks the app on `/_boot` (a spinner) until bootstrap resolves — never touching `/login` while a restore is in flight. `git log` confirms this exact mechanism was added by commit `d9c7cef` ("fix(auth): implement auth bootstrap gating + 3-state emailVerified + **prevent 401 bootstrap race**"), dated 2026-05-03 — about three months **before** this defect was observed on 2026-08-02. The fix already existed when the bug was seen.
  - **Empirical verification (real browser, real cold reload, artificial network delay)**: (1) valid session, cold reload on `/home` — correctly held on `/_boot` for the full delay window, then rendered the authenticated home page, confirmed via `RuntimeTrace` console output showing `authStatus` staying at its pre-existing state through the delay and only transitioning once `sessionBootstrapProvider` actually resolved; (2) valid session, cold reload on an institution-gated route (`/institution/:id/dashboard`, which additionally awaits `institutionAccessProvider`) — correctly waited, then correctly routed to `/enter-institution` (accurate "no access" outcome, not a bogus `/login` bounce); (3) a genuinely invalid/expired session (mock `/auth/refresh` returns 401) — correctly, and only after actually attempting the refresh, redirected to `/login?redirect=<original>`. All three match required behavior exactly; none reproduce the reported defect.
  - **One genuine false-positive during this investigation, recorded for anyone repeating it**: restarting the local mock backend process mid-test (to change its artificial delay) reset the mock's own in-memory "logged in" flag, causing a legitimate 401 on the next `/auth/refresh` call — which correctly cleared the client's session hint and correctly redirected to `/login`. This looked identical to the reported bug at first glance but was a test-harness artifact, not an app defect; it is called out here because it is exactly the kind of false signal that could produce a plausible-looking "confirmed reproduction" without being real.
  - **No code fix applied** — per "repair only the actual defect," inventing a change for a non-reproducing race would itself be a defect. Added `test/session_bootstrap_race_test.dart` (3 tests, `ProviderContainer`-based, no widget/network dependency) that locks in the exact invariant the router's redirect logic depends on: `authStatusProvider` reports `loading` (never `unauthed`) while `sessionBootstrapProvider` is in flight, and correctly resolves to `authed`/`unauthed` once it settles, including for an expired persisted token. This gives the mechanism a fast, deterministic regression guard so a future real regression here is caught at the provider level rather than only by a live reload.
  - Original recorded text (2026-08-02, prior to investigation): "Found incidentally while verifying messaging calls through the real web UI (see `../../aura-backend/audit/working-directory/NEXT_WORK.md`'s 'Realtime Reproduction and Capacity Enforcement' closure) — not investigated or repaired as part of that task. Observable behavior: a logged-in session that reaches a deep route via normal in-app navigation (e.g. clicking into a thread) works correctly; the same route loaded via a hard page reload or a fresh navigation directly to that URL (bookmarked link, browser refresh, a pasted deep link) redirects to `/login?redirect=<original path>` even though the session is still valid — confirmed by immediately re-navigating in-app afterward with no re-login required. Likely surface ownership: client-side, almost certainly the router's auth-redirect guard (`router.dart`) running its authenticated/not-authenticated check before the session-hydration path (`session_bootstrap.dart`, `SharedPreferences`-backed) has resolved on a cold load — a hydration-race pattern, not a real logout or token-invalidity issue. Unconfirmed without direct investigation; not investigated further per task scope." If this resurfaces, it is most likely either a genuinely expired/invalid session (item behaves correctly per case 3 above) or a backend-side session/cookie issue, not this client-side race.

## Explicit non-work

- Live room internals (`lib/features/live/` room UI) are frozen; do not restyle.
- Nothing under `../../orchestrate/`.
