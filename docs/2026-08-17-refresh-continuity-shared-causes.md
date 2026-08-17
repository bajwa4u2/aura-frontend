# REFRESH IS NOT NAVIGATION — Shared-Cause Audit (2026-08-17)

Founder platform contract: refresh on a legitimate destination must
reconstruct that destination. This is the traced shared-cause record
(investigation only; corrections tracked against the stop-order sequence).

## Ranked shared root causes

**RC1 — Web session restore gated behind a device-local hint boolean.**
`lib/core/auth/auth_providers.dart:112-121`: on web the token store restores
NOTHING; the only restore path is `/auth/refresh`, and
`lib/core/auth/session_bootstrap.dart:199-200` skips it entirely unless a
SharedPreferences hint exists. The hint is written only by the two member
sign-in paths (`auth_controller.dart:334,407`) — NOT by institution sign-in
(`institution_sign_in_screen.dart:96`), guest meeting auth
(`pre_join_screen.dart:165`, `guest_waiting_room_screen.dart:85`,
`meeting_live_room_screen.dart:793`, `router.dart:2055`), or the dio silent
re-auth (`dio_provider.dart:379,420`). It is destroyed on any transient
401/403 (`session_bootstrap.dart:215-221`) and lost when SharedPreferences
throws. Every downstream gate then fires "correctly" against a false
unauthenticated premise. **Highest leverage fix: make restore unconditional
/ hint-write every setSession site.**

**RC2 — Route-level redirects run without the top-level "still resolving"
discipline.** `router.dart:250-254` (`_redirectShorthandToCanonical`) reads
`institutionIdentityProvider` synchronously; while it is still loading, six
institution shorthand routes (`:1742,1758,1774,1795,1812,1819`) hard-land
on the dashboard. Cold-load of /institution/edit-profile etc. can never
survive.

**RC3 — Provider identity outranks the URL** (`router.dart:261-277`,
contradicting its own doc comment): refresh on institution B rewrites to
institution A (single-identity provider vs `memberships[]`), and the
screens ignore the path id entirely (e.g. `:1768` builds
`InstitutionEditProfileScreen()` argument-less).

**RC4 — Destination preservation is per-exit, not a rule.** Preserved: →
/login, /complete-identity, /verify-pending, /_boot. Destroyed (no
?redirect=): admin denial → /home (`:734`), institution access →
/enter-institution (`:741`), institution admin/speaker → dashboard
(`:752,:756`), realtime unauthed → /meetings/join (`:2148`), the six
shorthands, plus screen-level `context.go('/home')` sites
(`keep_meeting_screen.dart:49`, `meeting_live_room_screen.dart:1035-1039`,
`institution_onboarding_wizard.dart:92-93`,
`article_editor_screen.dart:68` pop-on-fail).

**RC5 — refreshListenable fires only on materialized value CHANGE**
(`router.dart:308-348`); loading→error emits null→null and never re-runs
the redirect, while `/auth/me` errors are swallowed to `{}`
(`session_providers.dart:107-109`) → "unknown" forever → permanent /_boot
spinner with no timeout/retry/fail-open (`router.dart:583-593,627-633`).

**RC6 — Two hand-maintained path classification tables**
(`route_classification.dart:21-62`, `router.dart:377-443`) not derived from
the route table: ~16 registered routes in NEITHER (e.g. /articles/write,
/realtime/:id, /devices, /discover/people, /spaces/:slug, /thread/:id) —
so they are never ?redirect=-restored and never gated; inversely
`/posts/:postId/edit` is classified PUBLIC by prefix; and
`requiresInstitutionAdmin` matches only shorthand constants, so canonical
/institution/:id/edit-profile carries no admin gate.

**RC7 — Draft surfaces never write identity into the URL.** Compose stores
`_draftPostId` in memory only (`compose_screen.dart:1428-1436`; URL
rebuilder `:549-572` omits it); the Article editor calls `createDraft()` on
EVERY mount of /articles/write and never `context.replace`s to
`/articles/write/<id>` (`article_editor_screen.dart:57-59`;
`navigation_authority.dart:208-209` builder unused here) — this is also the
founder-reported "draft not resumable" defect AND creates an orphan draft
per refresh.

**RC8 — `state.extra` destinations have no durable equivalent** (booking/
reschedule flows `router.dart:923-941,1294-1320,1322-1346`; meeting-live
isHost/sessionId as query-only `:1188-1189` with empty-sessionId self-
navigation to /home).

**RC9 — Bootstrap is a run-once module singleton**
(`session_bootstrap.dart:81-82,262,270-271`) so cross-tab login
invalidation (`aura_app.dart:176`) no-ops.

## Widest-leverage corrections (in order)
1. Unconditional web session restore + hint written by every setSession
   call site (fixes the largest share of all families at once).
2. "Still resolving → return null" discipline extended into route-level
   redirects (one resolved-predicate; fixes 11 institution families).
3. Path-id dominance + validate against memberships[]; pass :id into the
   institution screens.
4. One `gateRedirect(target, from)` helper for every destructive exit;
   gate screens honor ?redirect= on success.
5. refreshListenable fires on AsyncValue identity; bound the unknown state
   (timeout → truthful retry UI, never an eternal /_boot).
6. Derive public/member classification from the GoRoute table itself.
7. URL write-back on draft creation (articles + compose) — converts the
   draft family to durable-route.

## Status
Recorded 2026-08-17. Execution follows the founder's stop-order sequence:
realtime transport → identity/avatar certification → THIS contract →
video/screenshare/Live. Meetings participates via continuity + regression
only (no redesign).
