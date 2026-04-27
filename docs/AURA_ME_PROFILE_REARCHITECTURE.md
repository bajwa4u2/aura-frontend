# Aura /me Profile Re-Architecture

## Files Changed

| File | Type | Summary |
|------|------|---------|
| `lib/features/me/presentation/me_screen.dart` | Modified | Full re-architecture of section structure, communication surface, and connected accounts UX |

No other files were modified. All changes are contained to the presentation layer of the /me screen.

---

## Old vs New Information Architecture

### Old IA (settings warehouse)

```
Profile Hero (cover + avatar + name + handle + bio)
  ↳ Actions: Edit presence · Security
  ↳ Workspace panel: Institution workspace · Admin workspace

Section: Identity
  - View public presence

Section: Invitations
  - Open invitation center
  - New invite

Section: Public record (conditional)
  - Publications list

Section: Elsewhere (conditional)
  - Links list

Section: Record Room
  - Saved posts
  - Held for later
  - Private posts

Section: Connected accounts
  - LinkedIn (full action buttons always visible: Connect · Check · Disconnect)
  - TikTok (full action buttons always visible: Connect · Refresh · Check · Disconnect)

Section: Communication
  - Open communication center (link)
  - Toggle: Email notifications (master)
  - Toggle: Messages
  - Toggle: Invites
  - Toggle: Invite responses
  - Toggle: Announcements
  - Toggle: System
```

**Problems:**
- 8 sections of equal visual weight
- Communication section exposed 6 toggle switches directly on the profile surface
- Workspace destinations buried inside the hero card, mixed with profile identity
- Connected accounts showed all action buttons always — visually dense
- "Identity" section had just one item (thin, underused)
- Follow requests, invitations, and followers/following were in different places with no unified "Connections" concept
- Section ordering did not follow profile → personal content → tools hierarchy

---

### New IA (profile-first personal hub)

```
Profile Hero (unchanged visuals)
  ↳ Actions: Edit profile (primary) · View profile (secondary, if handle exists)
  ↳ workspaceActions: [] (moved to Workspaces section)

Section: Personal Record
  - Saved posts
  - Held for later
  - Private posts

Section: Public record (conditional — only if publications exist)
  - Publications list

Section: Elsewhere (conditional — only if links exist)
  - Links list

Section: Connections
  - Invitation center (subtitle shows live counts if any pending)
  - New invite
  - Follow requests (only shown if count > 0)

Section: Connected accounts
  - LinkedIn row (compact: icon + name + status chip + expand chevron)
    ↳ Expanded: Connect · Check · Disconnect actions
  - TikTok row (compact: icon + name + status chip + expand chevron)
    ↳ Expanded: Connect · Refresh · Check · Disconnect actions

Section: Account
  - Security
  - Communication preferences (single navigation link with clear description)

Section: Workspaces (only rendered if admin or institution access)
  - Institution workspace (if user has institution access)
  - Admin workspace (if user is platform admin)
```

**Improvements:**
- Personal Record first — content before tools
- Connections section unifies invitations + follow requests
- Workspaces separated to their own section at bottom
- Communication surface reduced from 7 items to 1 clean navigation link
- Connected accounts are compact by default, actions expand on tap
- Hero actions updated to Edit + View (no workspace mixing)

---

## Behavior Preserved

| Behavior | Status | Notes |
|----------|--------|-------|
| Edit profile navigation | ✅ | Hero primary action → /me/edit, reloads after return |
| View public profile | ✅ | Hero secondary action → /u/:handle |
| Security navigation | ✅ | Account section → /security |
| Admin workspace navigation | ✅ | Workspaces section → /admin (only if admin role) |
| Institution workspace navigation | ✅ | Workspaces section → /institution/dashboard |
| Invitation center navigation | ✅ | Connections section → /me/invitations |
| New invite navigation | ✅ | Connections section → /invite |
| Follow requests navigation | ✅ | Connections section → /me/follow-requests |
| Saved/Held/Private posts navigation | ✅ | Personal Record section |
| LinkedIn connect (OAuth flow) | ✅ | Expanded LinkedIn block |
| LinkedIn check/refresh | ✅ | Expanded LinkedIn block |
| LinkedIn disconnect (with confirmation dialog) | ✅ | Expanded LinkedIn block |
| TikTok connect (OAuth flow) | ✅ | Expanded TikTok block |
| TikTok token refresh | ✅ | Expanded TikTok block |
| TikTok check | ✅ | Expanded TikTok block |
| TikTok disconnect (with confirmation dialog) | ✅ | Expanded TikTok block |
| LinkedIn OAuth redirect handling | ✅ | `_handleLinkedInRedirectIfNeeded()` unchanged |
| Communication preferences full management | ✅ | Navigates to /me/settings/communications |
| Pull-to-refresh | ✅ | RefreshIndicator wraps content |
| Loading / error states | ✅ | AuraLoadingState / AuraErrorState with retry |
| Followers / Following chips | ✅ | Still in meta chips with navigation |
| Location / website chips | ✅ | Still in meta chips |
| Admin / institution role badges | ✅ | Still in meta chips |

---

## Communication Controls Handling

### What changed
The 6 communication toggle switches (`emailEnabled`, `emailMessageReceived`, `emailInviteReceived`, `emailInviteResponded`, `emailAnnouncementPublished`, `emailSystem`) are no longer rendered on the /me main surface.

The communication preferences API call (`/communications/preferences/me`) has been removed from the /me page load. This reduces the number of parallel requests on page open from 8 to 7.

### What is preserved
- `/me/settings/communications` route is fully intact and unchanged
- The `CommunicationPreferencesRepository` and all its logic remain untouched
- Users reach the full communication settings page via the new "Communication preferences" navigation item in the Account section
- The navigation item shows a clear subtitle: "Manage email, digest, message, and announcement preferences"

### Why this is safe
The communication toggles on /me were a secondary surface for settings that already have a dedicated full-page treatment at `/me/settings/communications`. Removing the duplicated surface does not remove any capability — it redirects users to the authoritative settings location.

---

## Connected Accounts UX Change

### Before
Both LinkedIn and TikTok blocks rendered all action buttons (3–4 buttons each) immediately visible, always. This created a dense multi-button layout that felt more like a debug panel than a profile surface.

### After
Each platform shows as a compact single row:
```
[icon] Platform Name    [Account label]    [Connected / Not connected chip]  [▼]
```

Tapping the row expands the actions:
```
[icon] Platform Name    [Account label]    [Connected chip]  [▲]
[Connect] [Check] [Disconnect]
```

The expand/collapse state is tracked per-platform with `_linkedinExpanded` and `_tiktokExpanded` booleans in the screen state. All action methods (`_connectLinkedIn`, `_disconnectLinkedIn`, `_reloadLinkedInOnly`, `_connectTikTok`, `_refreshTikTokToken`, `_disconnectTikTok`, `_reloadTikTokOnly`) are fully preserved and unchanged.

The confirmation dialogs for disconnect remain identical.

---

## Responsive Notes

The screen inherits all responsive behavior from the parent `MemberShell` (which handles the side rail / bottom nav / breakpoints). The /me content itself:

- Uses `ConstrainedBox(maxWidth: 980)` to cap content width on desktop
- `ListView` with `AlwaysScrollableScrollPhysics` ensures pull-to-refresh works at all sizes
- All `MeSection` / `MeSettingsItem` / `MeRecordItemCard` widgets use `AuraTextBlock` which handles text overflow at `maxLines` with ellipsis
- `PresenceHeader` uses `LayoutBuilder` internally with `isNarrow = width < 720` breakpoint (unchanged)
- `Wrap` in connected account action rows handles button wrapping at narrow widths
- The profile hero cover image is `200px` tall and `width: double.infinity` — adapts to all widths
- Bottom padding of `s32` prevents content from being obscured by bottom nav

**Tested against spec widths:**

| Width | Notes |
|-------|-------|
| 320px | Single column, all text wraps within AuraTextBlock maxLines |
| 375px | Standard mobile — normal layout |
| 390px | iPhone 14 — normal layout |
| 430px | Large phone — normal layout, action buttons wrap in Wrap |
| 768px | Tablet — side nav appears, content narrowed appropriately |
| 1024px+ | Desktop — side nav + constrained content column at 980px max |

---

## Validation Results

```
flutter analyze   → No issues found
flutter test      → All tests passed (1/1)
flutter build web → ✓ Built build/web
```

---

## Section Count Comparison

| Metric | Before | After |
|--------|--------|-------|
| Total sections | 8 | 5–7 (2 conditional) |
| Items in communication section | 7 (1 link + 6 toggles) | 1 (navigation link) |
| Items in connected accounts | ~8 buttons always visible | 2 compact rows, expand on demand |
| Workspace exposure | Hero card (mixed with identity) | Dedicated section (conditional, bottom) |
| API calls on page load | 8 parallel | 7 parallel |
| Lines of code | 1804 | ~900 |
