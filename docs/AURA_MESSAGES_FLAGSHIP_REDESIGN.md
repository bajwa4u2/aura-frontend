# Aura Messages — Flagship Redesign

## Files Changed

| File | Type | Summary |
|------|------|---------|
| `lib/features/correspondence/presentation/thread/thread_message_tile.dart` | Modified | Premium bubble system with avatar, gradient sent bubbles, compact author headers |
| `lib/features/correspondence/presentation/thread_screen.dart` | Modified | Date separators between message groups |
| `lib/features/conversations/presentation/conversations_screen.dart` | Modified | AuraAvatar replaces icon badges, unread count badge, bold unread state |
| `lib/features/realtime/presentation/incoming_live_overlay.dart` | Modified | Full-screen incoming call UI with blurred backdrop, large avatar, circular action buttons |

No other files were modified. All changes are contained to the presentation layer.

---

## Thread Message Tile — Premium Bubble System

### Before
- Both sent and received bubbles used flat navy background colors (`AuraSurface.overlay` / `AuraSurface.elevated`)
- Author header was multi-line (name, @handle, context line — 3 stacked rows)
- No visual differentiation by sender except alignment
- No avatar — received messages identified only by text name above the bubble

### After

**Sent bubbles (isMine = true)**
```
Alignment: right
Decoration: LinearGradient(Color(0xFF1E2756) → AuraSurface.overlay)
Border: AuraSurface.accent at 22% opacity (subtle indigo glow)
```

**Received bubbles (isMine = false)**
```
Alignment: left
Avatar: AuraAvatar(name, imageUrl, size: 28) at bottom-left of bubble
Author header: inline one-line — "Name @handle" (compact vs 3-line stack)
Decoration: AuraSurface.elevated + subtle drop shadow
Layout: Row [ 32px avatar column | Expanded [ header? + bubble ] ]
```

**Behavior preserved**: all translation, AI assist, attachment rendering, edit/delete menu, image viewer, timestamp display.

---

## Thread Screen — Date Separators

### What changed
The message list in `_ThreadConversationPanel` now inserts a `_DateSeparator` widget between messages that fall on different calendar days.

### _DateSeparator format
```
─────────────────── Today ───────────────────
─────────────────── Yesterday ───────────────────
─────────────────── Apr 22 ───────────────────
─────────────────── Mar 15, 2024 ───────────────
```

### Implementation
- `_isSameDay(a, b)` compares `createdAt` / `sentAt` fields of two message maps
- `_DateSeparator` widget: Row with `Divider + centered label + Divider`
- Label resolves to: "Today", "Yesterday", weekday-less date, or date+year if different year
- No changes to providers, repositories, or data loading

---

## Conversations Screen — Avatar and Unread State

### Before
- `_ConversationBadge`: circular icon (person_outline for direct, forum_outlined for space)
- No unread count display
- All rows look identical regardless of read state

### After
- `_ConversationBadge` replaced by `AuraAvatar(name: item.title, imageUrl: item.avatarUrl, size: 44)`
- Avatar URL extracted from space data (direct URL or first member's avatar)
- Unread badge: red pill with count overlaid at top-right of avatar (hidden when `unreadCount == 0`)
- Unread rows: bold title (`FontWeight.w800`), accent-colored timestamp, inked preview text
- `_ConversationItem` model gains `unreadCount` and `avatarUrl` fields

---

## Incoming Call Overlay — Full-Screen Takeover

### Before
Centered `AuraCard` (440px wide) on a semi-transparent backdrop:
```
[Icon] Incoming call
[Caller name]
[Title text]
[Body text]
[Dismiss] [Join]
```

### After
Full-screen takeover with blurred backdrop:
```
                    [ Blurred backdrop (18px sigma Gaussian) ]
                    [ Deep navy gradient overlay ]

                    ┌────────────────────────────────────────┐
                    │   [Video call / Audio call chip]        │
                    │                                         │
                    │           [AuraAvatar 96px]             │
                    │           [glow ring]                   │
                    │                                         │
                    │           Caller Name                   │
                    │           Context / title               │
                    │                                         │
                    │    [Decline ●]      [Accept ●]          │
                    │    (red, 68px)      (green/indigo, 68px) │
                    └────────────────────────────────────────┘
```

**`_CallCircleButton`**: New atom widget. Large circular button with:
- Configurable icon, color, background, and size
- Box shadow glow matching background color
- Busy state renders a `CircularProgressIndicator` inside the circle
- `MouseRegion` + `GestureDetector` for cursor and tap handling

**Behavior preserved**: all join/dismiss logic, session ID handling, notification marking, route navigation, suppression on thread/realtime paths.

---

## Design Language Applied

| Attribute | Token / Value |
|-----------|--------------|
| Sent bubble gradient | `Color(0xFF1E2756)` → `AuraSurface.overlay` |
| Sent bubble border | `AuraSurface.accent` @ 22% opacity |
| Received bubble | `AuraSurface.elevated` + 8px drop shadow |
| Date separator label | `AuraText.micro` at `AuraSurface.faint` |
| Unread badge | `AuraSurface.accent` background, white text |
| Call backdrop blur | `ImageFilter.blur(18, 18)` |
| Avatar glow | accent/goodInk @ 25% opacity, 32px spread |
| Accept button (video) | `AuraSurface.accent` |
| Accept button (audio) | `AuraSurface.goodInk` |
| Decline button | `AuraSurface.dangerBg` / `AuraSurface.dangerInk` |

---

## Responsive Notes

- `ThreadMessageTile`: max bubble width `620px` at `>900px`, `500px` below. Avatar column adds `38px` to max width for received.
- `_ConversationRow`: avatar size `44px`, unread badge overlay at top-right
- Incoming call overlay: `Column + Spacer` centered layout adapts to any screen height. No fixed-width constraint.
- Date separators: `Row + Expanded Divider + text` fills full width at any breakpoint

---

## Validation Results

```
flutter analyze   → No issues found
flutter test      → All tests passed (1/1)
flutter build web → ✓ Built build/web
```
