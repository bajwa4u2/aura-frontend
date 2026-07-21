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

## Next implementation starting point

No founder-defined next milestone is recorded beyond AXR-1 itself. `NEXT_WORK.md` lists residual/follow-on items awaiting founder decision — including the two AXR-1 items intentionally left unresolved (Meetings/Mentions badge destinations, `#Topic` tap-through route) and the pre-existing ROS Phase II editorial residuals.

## Outstanding founder approvals

1. **Push `39e3964` to `origin/main`** and deploy alongside the backend's `37cb22f` (this milestone implemented and tested but did not push/deploy — do so only on explicit instruction; the two repos' AXR-1 changes should ship together since the frontend identity fixes depend on the backend payload fields).
2. Whether Meetings and Mentions need their own nav-rail destinations to surface the module badges `module_attention.dart` already computes for them (see NEXT_WORK) — a genuine design decision, not a bug fix.
3. The four residual editorial items from the ROS Phase II closeout (production data/content, not code) — see `NEXT_WORK.md`.
