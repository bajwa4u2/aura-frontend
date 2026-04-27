# Aura Conversation Screen — Layout & Responsive Polish

**Branch:** main  
**Date:** 2026-04-27  
**File changed:** `lib/features/correspondence/presentation/thread_screen.dart`

---

## Files changed

| File | Change type |
|---|---|
| `lib/features/correspondence/presentation/thread_screen.dart` | Responsive layout fixes, sticky composer, mobile breakpoints |

`thread_composer.dart`, `thread_message_tile.dart`, `thread_utils.dart` — no changes needed (see "skipped" section).

---

## Responsive fixes (Priority A)

### 1. Fixed broken wide-layout breakpoint

**Root cause:** The `LayoutBuilder` inside `thread_screen.dart` checked `constraints.maxWidth >= 1180` to activate the side-rail Row layout. `AuraScaffold` defaults to `AuraPageShell(maxWidth: 920)`, and the `ListView` inside adds `16+16=32px` horizontal padding. This means the `LayoutBuilder` child never sees a width above ~888px. The wide layout (side rail in a Row) **never activated** — the side rail always dumped as a Column below messages on every screen size.

**Fix:** Changed breakpoint to `constraints.maxWidth >= 760`. At the default 920px page shell, the LayoutBuilder sees ~888px → wide layout activates correctly. On 768px tablets (~736px effective), narrow layout is used.

### 2. Added mobile breakpoint — no side rail below 560px

**Problem:** Even after fixing the breakpoint, the side rail would still appear below messages on phones (320–430px).

**Fix:** Added a second threshold `showRail = constraints.maxWidth >= 560`. On screens below 560px (all standard phones), only `conversationPanel` is returned — no side rail at all. On 560–759px (small tablets / landscape phones), the side rail appears below the conversation panel. Above 760px, the side rail is in a Row alongside the conversation.

**Side rail widths at breakpoints:**
- `>= 760px` → Row: conversation (Expanded) + 16px + 300px side rail
- `560–759px` → Column: conversation + 16px gap + side rail
- `< 560px` → conversation panel only

Rail reduced from 352px to 300px in the wide Row layout to give more room to the conversation column.

### 3. Sticky composer (Priority A.5 / C.2 / D)

**Problem:** `ThreadComposerBar` was embedded inside `_ThreadConversationPanel`, which was inside a scrollable `ListView`. On any thread with multiple messages, the user had to scroll down to reach the composer. On mobile, the composer was completely buried and inaccessible without significant scrolling. This violated "composer sticky near bottom" and "composer must never be covered by footer/nav".

**Fix:**
- Extracted `ThreadComposerBar` from `_ThreadConversationPanel` into the outer body `Column` of `_ThreadScreenState.build()` as a second child below the `Expanded(RefreshIndicator(ListView(...)))`.
- Removed the `threadId` field from `_ThreadConversationPanel` (was only used by the composer — the class now has no uses for it).
- Changed `ListView` bottom padding from `24` to `16` (the composer now acts as the natural bottom boundary).

The composer is now always visible at the bottom of the viewport. When the soft keyboard opens, Flutter's `resizeToAvoidBottomInset: true` (Scaffold default) shrinks the body, the `Expanded` ListView shrinks, and the composer stays above the keyboard — correct behavior on all platforms.

### 4. Header actions already wrap-safe

`_ThreadActionCluster` uses `Wrap(alignment: end, ...)` for the call/video/more buttons — wraps cleanly on narrow headers. No changes needed.

### 5. Message bubbles already mobile-safe

`ConstrainedBox(maxWidth: 660 or 560)` inside message tiles is limited by parent constraints from the `AuraCard(padding: 18)`. On 320px screen the effective bubble max is ~252px — no overflow. No changes needed.

---

## Mode clarity (Priority B)

No code changes required. The existing implementation is already mode-correct:

- **Direct:** `_ThreadActionCluster` shows `onSpaceOpen: isSpace ? onOpenSpace : null` — space actions only appear for space threads.
- **Direct rail:** `_DirectConversationRail` shows only profile brief + live status.
- **Space thread:** `_SpaceThreadRail` shows conversation brief, live status, open space, manage invites.
- With the mobile breakpoint fix, on mobile (< 560px) the large profile/space brief cards in the side rail are **hidden entirely** — only the header card (compact, already responsive via `Wrap`) is visible.

---

## Messaging-first hierarchy (Priority C / D)

- Timeline dominates: message list fills the `Expanded` area.
- Composer is now visually connected to the bottom — `AuraCard` composer card is directly below the message list.
- Side rail on desktop is secondary (300px fixed, conversation is `Expanded`).
- Call/video actions are in the header's `_ThreadActionCluster` — available but not dominant.

---

## Desktop polish (Priority E)

- Wide layout now correctly activates at 760px (was never triggering before).
- Side rail narrowed from 352px to 300px in wide Row — conversation column gets more breathing room.
- No excessive blank space — `ListView` bottom padding reduced from 24px to 16px.

---

## Behavior preserved

All the following are untouched:
- Send message (moved `ThreadComposerBar` only changes position, not logic)
- Edit/delete messages
- Attachment upload (image, video, audio) and preview
- Audio recording
- Translation (Polish, Language, Translate buttons in composer)
- Audio call / video call actions via `_ThreadActionCluster` and `_ThreadLiveDock`
- Live status strip, audio stage, video stage (WebRTC)
- Space open / manage invite actions
- Realtime/live state observing (from `realtimeControllerProvider`)
- Auto-poll and mark-read behavior
- All three conversation modes (direct / group / shared space)

---

## Skipped / not changed

**`thread_composer.dart`:** The `_AttachmentPreviewCard(width: 240)` is inside a horizontal `ListView.separated` scroll — it scrolls on narrow screens (does not overflow). The edit dialog (`SizedBox(width: 460)`) only shows on desktop (≥ 760px) via the `desktopSheet` check. All safe.

**`thread_message_tile.dart`:** The image-viewer errorBuilder `Container(width: 520)` is inside an `InteractiveViewer` — the viewer clips its viewport, so no screen overflow. Message bubble `ConstrainedBox(maxWidth: 560)` is correctly capped by card padding on all screen sizes.

**`thread_utils.dart`:** Pure utilities, no layout.

---

## Test / build results

| Check | Result |
|---|---|
| `flutter analyze` | 0 issues |
| `flutter test` | All passed |
| `flutter build web` | ✓ Built build/web |
