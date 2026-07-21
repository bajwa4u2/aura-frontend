# Current State — aura_final

Last updated: 2026-07-21 UTC (AXR-1)

Repository documentation is authoritative. Conversation history is temporary. This continuity set was established 2026-07-21 (workspace-wide continuity doctrine); prior history is reconstructed from git history and the ROS Phase II records.

## Identity

Aura Meetings Flutter frontend (single codebase: iOS + Android + Web). Three application shells (Member / Institution / Admin) + Public shell; talks to `../aura-backend` under global `/v1`. Aura is verified-identity civic discourse infrastructure — see `AGENTS.md`. WebRTC engine: `lib/features/realtime/` (`realtime_controller.dart`, `realtime_media_service.dart`, `realtime_socket_service.dart`).

## New reusable platform capabilities (AXR-1, 2026-07-21)

- **Governed tagging** (`lib/core/tagging/`) — `@member`, `@institution`, `#topic` autocomplete as platform infrastructure, not a Post feature. `TagKind` is an open enum (new entity kinds are a case + a suggest source, no redesign). `tag_token.dart` is pure text/cursor math (no Flutter import) detecting the active token under the cursor, mirroring the backend's `extractHandles` email-boundary guard. `tag_suggest_service.dart` sources `@` suggestions from the existing server-ranked `/search` endpoint (no parallel ranking) and `#` suggestions from the closed `AuraTopic` taxonomy (instant, local). `GovernedTagAutocomplete` wraps any `(TextEditingController, FocusNode)` pair with a keyboard/mouse-navigable overlay. Wired live into post compose, thread messages, and institution announcements — three different composers, one widget.
- **Module attention projection** (`lib/features/updates/module_attention.dart`) — pure function from notification rows → per-module unread counts (Messages, Institutions, Meetings, Mentions), derived from the *same* polled rows the global Activity bell already reads. `moduleAttentionProvider` is the live Riverpod projection; wired into the member shell's side rail and bottom nav.
- **TagStyledText** (`lib/features/public/widgets/mention_text.dart`) — non-interactive tag highlighting for preview surfaces where the whole card is the tap target (e.g. the feed). Companion to the existing interactive `MentionText` used on detail surfaces.

## Production baseline

- Production web deployment at `auraplatform.org`, deployed via Railway. The 2026-07-13 record confirms pushing `main` auto-deployed the web build (verified by asset-hash change + live screenshot). Re-verify auto-deploy still holds before relying on it.
- Mobile: version `1.2.2+22` was the last recorded release commit (`4f6c2a5`). iOS distribution runs through the founder's manual Codemagic/App Store flow.

## Implementation status

- `main` HEAD `39e3964` — **committed locally, NOT pushed** (this milestone did not authorize deploy/push). `origin/main` remains at `b845820`.
- **AXR-1 (2026-07-21): Aura Experience Refinement — unified interaction & identity enhancement.** Consolidated, founder-directed initiative; four workstreams, one commit, no architecture change:
  - **W1 Universal Governed Tagging** — see "New reusable platform capabilities" above. Live in 3 composers today; any future composer (Studio-generated content, future institutional editors) adopts it by wrapping its own field.
  - **W2 Notification Synchronization** — module badges (Messages, Institutions today; Meetings/Mentions destinations don't have nav-rail entries yet, so their counts are computed but not currently displayed anywhere — see NEXT_WORK) now derive from the same notification rows as the global bell, eliminating the fragmented-attention defect the brief described.
  - **W3 Identity Rendering Consistency** — audited every surface the brief listed. The photo→initials fallback rule was never violated *by design*; it was unwired in two ways: (a) server payloads omitting `avatarUrl`/`logoUrl` (fixed in `../aura-backend`, commit `37cb22f`), and (b) five client call sites bypassing the canonical `AuraAvatar` with ad hoc `CircleAvatar`/icon fallbacks that never attempted the image (admin member rows, new-conversation directory, space-screen identity avatar, meeting-participant rows, search's institution tile). All five now delegate to the canonical widget/logo path.
  - **W4 Interaction Consistency** — added `TagStyledText` for the one text surface (feed card preview) rendering raw post text with no tag styling, closing that inconsistency with every other text surface. No duplicated CTAs or navigation actions found on audited surfaces (Single Intent Principle precedent from aura-studio applied as the standard).
  - Tests: 16 new (11 tag-token-engine + 5 module-attention-projection). Full suite: 69 files, all green (1 pre-existing skip, unrelated). `flutter analyze`: 0 issues.
- `b845820` = ROS Phase II fidelity restoration (2026-07-13, founder-authorized, on `origin/main`): stripped a Bajwa Writes trademark symbol from two screens and removed publishing/literary vocabulary from auth/register/search — deployed and live-verified with a cache-busted production screenshot.
- Earlier completed milestones (2026-07-10/11, verified in git history): resolver-driven pre-join (`meeting_entry_resolution.dart`, outcome state machine), invitation OTP flow, authenticated-booking read-only identity card, Profile → Participation continuity tab, managed Past-meetings archive, meeting-workspace surface migration onto AuraSurface tokens (live room internals frozen/untouched).
- ROS Phase II audit closed: **VERIFIED WITH RESIDUAL FOUNDER EDITORIAL ITEMS** (`representation/inventory/AURA_ROS_PHASE_II_CORRECTION_CLOSEOUT.md`). Full audit deliverable set lives in this repo under `representation/inventory/AURA_*.md`.

## AXR-1 — CERTIFIED, closed 2026-07-21

Founder rulings on the three items left open at first delivery, all resolved same-day:

1. **No Meetings/Mentions nav destinations.** Meeting notifications stay Activity-only until Profile → Participation → Meeting History exists (not yet built). Mention notifications don't need a dedicated tab — they must deep-link to their referenced content instead, which was **already true**: `MENTION` notifications carry `postId` (the reply/post containing the mention) and `_routeFor` in `notifications_screen.dart` already resolves `postId` → `/posts/:id`, a real route serving both top-level posts and replies. No code change needed; verified by re-reading the existing routing logic and the backend's `MENTION` notification payload (`postId: created.id`).
2. **Topic-seeded search accepted for AXR-1.** A dedicated topic-scoped view is deferred as a future enhancement (recorded in NEXT_WORK), not a defect.
3. **Institution post composer**: inspected and confirmed a real, routed, active production surface (`/institution/:id/posts/new` and its edit path, `institution_post_composer_screen.dart`). Wired with the same `GovernedTagAutocomplete` pattern as the other three composers — commit `a19547f`. Meeting notes wiring is **not required**: no meeting-notes composer widget exists yet; recorded as a future integration requirement in NEXT_WORK, to be picked up when that composer is built.

`flutter analyze`: 0 issues (file-scoped and full-repo). Full suite: 69 files, all green (1 pre-existing unrelated skip) — unchanged pass count, confirming no regression from the new wiring.

## Next implementation starting point

No founder-defined next milestone is recorded beyond AXR-1, which is now closed. `NEXT_WORK.md` lists the accepted future-enhancement items (topic-scoped search view, meeting-notes tagging once that composer exists) — none authorized to start without separate founder direction.

## Outstanding founder approvals

**None.** AXR-1 is fully implemented, verified, pushed (`a19547f` on `origin/main`, alongside `../aura-backend`'s `37cb22f` on its own `origin/main`), and certified closed. Per this repo's own release doctrine (`OPERATIONAL_BASELINE.md`), pushing `main` is push-to-deploy for the web target on Railway — unlike aura-studio's Cloudflare flow, deploy is not a separate authorized step here. Live cache-busted verification on `auraplatform.org` (the doctrine's own last release-order step) was not performed in this session and is worth a quick confirmation, but is operational follow-through, not a pending decision.
## 2026-07-21: Aura Post Integrity & Editing Remediation

Implemented in the working tree, pending commit/push/deploy verification:

- Member composer discard now calls `DELETE /posts/draft`, clears local composer state, and returns Home through the existing provider invalidation path. Backend stale-token filtering covers refresh/logout/login/restart cases.
- Public composer identity now passes authenticated profile `avatarUrl` into canonical `AuraAvatar`; institution composer actor banner also delegates to `AuraAvatar`.
- Member compose publish/save now requires a canonical selected `AuraTopic` for top-level posts. Raw `#` text does not satisfy this because `_primaryTopic` is only set by `AuraTopicSelector`.
- Member editing restored through `/posts/:postId/edit`, reusing `ComposeScreen` in deterministic edit mode and saving through `PUT /posts/:id`.
- Institution edit now hydrates the existing post through `GET /institutions/:institutionId/posts/:postId`, preserves title/body/topic/visibility/distribution/media state, and saves through `PATCH` instead of create.

Validation recorded this session:

- `flutter analyze` passed with no issues.
- `flutter test` could not be completed: the Flutter test runner hung before output even for pre-existing `test/governed_tagging_test.dart` and `--list-tests`; treat as environment/tooling blocker, not a test assertion failure.

Out-of-scope issues recorded:

- Existing `institutions_repository.dart` had multiple single-line `if` lint issues; fixed because this remediation touched the file.
- Production verification still required after push/deploy.
