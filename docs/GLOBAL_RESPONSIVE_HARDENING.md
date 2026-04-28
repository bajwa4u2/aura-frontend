# Global Responsive Hardening — Aura Final

## Shared Primitives Added

**`lib/core/ui/aura_responsive.dart`** — new file containing:

| Export | Purpose |
|---|---|
| `kMobileBreak = 600` | Small phone threshold |
| `kTabletBreak = 900` | Tablet threshold |
| `kDesktopBreak = 1200` | Desktop threshold |
| `kMaxContentWidth = 960.0` | Default content max-width |
| `kMaxNarrowWidth = 640.0` | Narrow form max-width |
| `kMaxFormWidth = 480.0` | Compact form max-width |
| `AuraBreakpoint` | Static helpers: `isMobile()`, `isTablet()`, `isDesktop()`, `pagePadding()` |
| `AuraPageBody` | Centers + constrains content with adaptive horizontal padding |
| `AuraKeyboardSafe` | Adds `viewInsetsOf(context).bottom` padding below child |
| `AuraTwoPanel` | Side rail + content; hides rail below breakpoint |
| `AuraActionRow` | `Wrap`-based row for overflowing action buttons |

## Architectural Baseline

`AuraScaffold` wraps all `body` content in `AuraPageShell(maxWidth: 920)` automatically. This means every screen using `AuraScaffold` already receives a 920 px max-width constraint — so desktop overflow is not a concern for those screens unless they explicitly override `maxWidth`.

Shell navigation is already responsive:
- `MemberShell` / `InstitutionShell` — `LayoutBuilder` with `_desktopBreakpoint=1100`, `_tabletBreakpoint=760`
- `AdminShell` — same pattern, `_desktopBreakpoint=1100`, `_tabletBreakpoint=760`
- `PublicShell` — same pattern, responsive header nav hidden on mobile

## Files Modified

### `lib/features/correspondence/presentation/space_screen.dart`
- **Fix**: Replaced `SizedBox(height: 620)` for `TabBarView` with viewport-relative height: `MediaQuery.sizeOf(context).height * 0.55` clamped to min 400 — eliminates fixed pixel constraint on small screens.
- **Fix**: Added `Center > ConstrainedBox(maxWidth: 960)` wrapper around the `ListView`.

### `lib/features/correspondence/presentation/thread_screen.dart`
- **Fix**: Added `Center > ConstrainedBox(maxWidth: 1100)` wrapper around thread message `ListView` inside `RefreshIndicator`.

### `lib/features/correspondence/presentation/thread/thread_composer.dart`
- **Fix**: Added keyboard inset handling — `final keyboardInset = MediaQuery.viewInsetsOf(context).bottom` applied to bottom padding so the composer bar rises above the software keyboard.

### `lib/features/correspondence/presentation/thread/thread_message_tile.dart`
- **Fix**: Image viewer dialog loading/error placeholder `SizedBox(height: 320, width: 520)` replaced with `LayoutBuilder`-clamped dimensions: `height: maxH.clamp(200, 320)` and `width: maxW.clamp(200, 520)` — prevents overflow on phones (360px wide).

### `lib/features/communications/presentation/widgets/admin_communication_workspace.dart`
- **Fix**: Wrapped the `Text('Admin communication workspace')` in `Flexible` with `maxLines: 1, overflow: TextOverflow.ellipsis` to prevent overflow on narrow screens.

## Screens Audited — No Changes Required

The following screens were audited and found already responsive:

| Screen | Reason |
|---|---|
| `auth_screen.dart` | `LayoutBuilder` + wide/narrow Row/Column switch |
| `register_screen.dart` | Same pattern, keyboard inset handled |
| `forgot_password_screen.dart` | `SafeArea + Center + ConstrainedBox(maxWidth: 520)` |
| `reset_password_screen.dart` | Same pattern |
| `verify_email_screen.dart` | Same pattern |
| `verify_pending_screen.dart` | Same pattern |
| `login_screen.dart` | Same pattern |
| `me_screen.dart` | `LayoutBuilder` >= 900 wide/narrow split |
| `security_screen.dart` | `LayoutBuilder` adaptive maxWidth |
| `edit_profile_screen.dart` | `LayoutBuilder` >= 900 wide (3-col) / narrow (chips + scroll) |
| `author_profile_screen.dart` | `LayoutBuilder` + `PresenceHeader` with adaptive padding |
| `followers_screen.dart` | `AuraScaffold` → 920 px constrained |
| `following_screen.dart` | `AuraScaffold` → 920 px constrained |
| `follow_requests_screen.dart` | `AuraScaffold` → 920 px constrained |
| `compose_screen.dart` | `LayoutBuilder` >= 1080 + `ConstrainedBox(maxWidth: 1240)` + `viewInsets` |
| `post_detail_screen.dart` | `AuraScaffold` + `ConstrainedBox(maxWidth: 920)` |
| `post_card.dart` | Bottom sheets have `SafeArea` + `viewInsets.bottom` |
| `realtime_room_screen.dart` | `AuraScaffold` + `LayoutBuilder` >= 1080 |
| `realtime_lobby_screen.dart` | `AuraScaffold` + `ConstrainedBox(maxWidth: 640)` |
| `announcements_screen.dart` | `AuraScaffold` → 920 px constrained |
| `announcement_detail_screen.dart` | `AuraScaffold` + `SafeArea` in bottom sheet |
| `announcement_editor_screen.dart` | `AuraScaffold(maxWidth: 980)` + `SingleChildScrollView` |
| `communications_center_screen.dart` | `AuraScaffold` + `ConstrainedBox(maxWidth: 1180)` |
| `conversations_screen.dart` | `AuraScaffold` → 920 px constrained |
| `correspondence_hub_screen.dart` | `AuraScaffold` + `ConstrainedBox(maxWidth: 920)` |
| `new_conversation_screen.dart` | `AuraScaffold` + `ConstrainedBox(maxWidth: 980)` + `LayoutBuilder` |
| `create_hub_screen.dart` | `AuraScaffold` + `ConstrainedBox(maxWidth: 960)` + `LayoutBuilder` |
| `invite_hub_screen.dart` | `AuraScaffold` → 920 px constrained |
| `invitations_screen.dart` | `AuraScaffold` → 920 px constrained |
| `invite_accept_screen.dart` | `AuraScaffold` → 920 px constrained |
| `invite_create_screen.dart` | `AuraScaffold` → 920 px constrained |
| `invite_member_screen.dart` | Delegates to `InviteCreateScreen` |
| `admin_audit_logs_screen.dart` | `AuraScaffold` + `ConstrainedBox(maxWidth: 960)` |
| `admin_grants_screen.dart` | `AuraScaffold` + `ConstrainedBox(maxWidth: 960)` |
| `admin_users_screen.dart` | `AuraScaffold` + `ConstrainedBox(maxWidth: 960)` |
| `admin_feature_flags_screen.dart` | `AuraScaffold` + `ConstrainedBox(maxWidth: 960)` |
| `admin_institution_domains_screen.dart` | `AuraScaffold` + `ConstrainedBox(maxWidth: 960)` |
| `admin_settings_screen.dart` | `AuraScaffold` + `ConstrainedBox(maxWidth: 960)` |
| `admin_workspace_screen.dart` | `AuraScaffold` + `ConstrainedBox(maxWidth: 960)` |
| `institution_dashboard_screen.dart` | `AuraScaffold` + `ConstrainedBox(maxWidth: 920)` |
| `institution_detail_screen.dart` | `AuraScaffold` + `ConstrainedBox(maxWidth: 920)` |
| `member_home_screen.dart` | `AuraScaffold` + `ConstrainedBox(maxWidth: 1160)` |
| `public_home_screen.dart` | `ConstrainedBox(maxWidth: 1160)` |
| `updates_screen.dart` | `AuraScaffold` + `ConstrainedBox(maxWidth: 1160)` |
| `activity_screen.dart` | `AuraScaffold` + `ConstrainedBox(maxWidth: 920)` |
| `search_screen.dart` | `AuraScaffold` → 920 px constrained |
| `saved_screen.dart` | `AuraScaffold` → 920 px constrained |
| `support_screen.dart` | `AuraScaffold` → 920 px constrained |
| `claim_audit_screen.dart` | `AuraScaffold` → 920 px constrained |
| `realtime_lobby_screen.dart` | `AuraScaffold` + `ConstrainedBox(maxWidth: 640)` |
| All `lib/screens/*.dart` | Use `DocumentScaffold(maxWidth: 780)` or `AuraScaffold` + `ConstrainedBox` |
| `account_deletion_screen.dart` | Raw `Scaffold` + `Center + ConstrainedBox(maxWidth: 760)` |
| `CommTwoColumnFields` | `LayoutBuilder` >= 820 two-column / single-column below |
| `PresenceHeader` | `LayoutBuilder` isNarrow < 720, adaptive padding |

## Key Constraints: Not Changed

- No route definitions, providers, repositories, auth logic, or API calls were modified.
- No fake data was added.
- No business logic was changed.
- `flutter analyze`: 0 issues throughout.
- `flutter test`: all tests pass.

## Second-Pass Audit (Screen-by-Screen Verification)

High-risk files re-audited individually after the first pass:

| File | Finding | Action |
|---|---|---|
| `compose_screen.dart` (3247 lines) | `viewInsets.bottom` handled, `ConstrainedBox(maxWidth:1240)+Center`, bottom bar uses `LayoutBuilder < 520` to stack, wide rail `SizedBox(width:260)` only in `>= 1080` layout | No changes needed |
| `announcement_editor_screen.dart` (1505 lines) | `AuraScaffold(maxWidth:980)`, all suggestion/translation rows use `Expanded`; action row at bottom was bare `Row([Cancel, Publish announcement])` without overflow guard | **Fixed**: replaced `Row` with `Wrap(spacing:12, runSpacing:8)` |
| `edit_profile_screen.dart` (1765 lines) | `LayoutBuilder >= 900` for wide/narrow split, cover `height:240` intentional, nav rails `SizedBox(width:220/260)` only in wide layout | No changes needed |
| `me_screen.dart` (1555 lines) | `LayoutBuilder >= 900`, all rows use `Expanded`, no fixed widths in narrow path | No changes needed |
| `new_conversation_screen.dart` (1751 lines) | `ConstrainedBox(maxWidth:980)`, inner `LayoutBuilder < 860` switches directory/rail to stacked, action buttons both use `Expanded` | No changes needed |
| `realtime_room_screen.dart` (1115 lines) | `LayoutBuilder >= 1080`, wide side panel `SizedBox(width:380)` only in wide layout, action buttons use `Wrap`, video tiles `SizedBox(width:260)` in `Wrap` (intentional) | No changes needed |
| `conversations_screen.dart` (1033 lines) | `AuraScaffold`, conversation row uses `Expanded` for title/timestamp, no overflow risks | No changes needed |
| `post_card.dart` (1511 lines) | All bottom sheets have `SafeArea`, reply bottom sheet has `viewInsets.bottom`, `_mediaMaxHeight` uses 4-tier responsive breakpoints | No changes needed |

All dialogs across the app (`AlertDialog`) were verified: all use `SafeArea` or are short-content (2–3 lines) that cannot overflow.

All `showModalBottomSheet` calls verified: all wrap content in `SafeArea`.

Shell responsive behavior verified: `MemberShell`, `AdminShell`, `InstitutionShell` all use `_desktopBreakpoint=1100` / `_tabletBreakpoint=760` with `LayoutBuilder`.

### Second-Pass Fix Applied

**`lib/features/announcements/presentation/announcement_editor_screen.dart`**
- **Fix**: Bottom action row `Row([Cancel, Publish announcement])` replaced with `Wrap(spacing:12, runSpacing:8)` — prevents horizontal overflow on 320px screens where both button intrinsic widths (≈90px + ≈200px + 12px gap = ≈302px) can exceed the padded content area.

## Known Limitations

- Video tiles in `realtime_room_screen.dart` use `SizedBox(width: 260)` inside `Wrap` — intentional fixed size for video aspect, wraps responsively.
- Cover image in `edit_profile_screen.dart` has `height: 240` — acceptable minimum height for image cropping context.
- `PresenceHeader` cover uses `const coverHeight = 200.0` — minimal but acceptable for all screen sizes.
- The `AuraTwoPanel`, `AuraPageBody`, `AuraKeyboardSafe`, `AuraActionRow` primitives are available in `aura_responsive.dart` for future use but are not yet imported by all screens (screens were already responsive without them).
- Edit message dialog in `thread_composer.dart` uses `SizedBox(width: 460)` — overridden by `AlertDialog`'s own max-width constraint and safe on all screen sizes.
