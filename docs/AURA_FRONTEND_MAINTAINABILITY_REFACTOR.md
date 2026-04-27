# Aura Frontend Maintainability Refactor

Zero behavior change. All screens still render identically. No provider changes, no route changes, no backend calls added or removed.

---

## What was done

Heavy single-file screens and widgets were split into focused sub-modules using feature-local subfolders. Private Dart classes and utilities that were extracted were renamed to public names (Dart file-scoped privacy rule: `_Foo` is not visible outside its file).

---

## Files changed

### `lib/features/correspondence/presentation/` (prior session)

| File | Lines | Note |
|---|---|---|
| `thread_screen.dart` | 1,847 | Reduced from 4,958 |
| `thread/thread_composer.dart` | 1,684 | New — composer bar extracted |
| `thread/thread_message_tile.dart` | 1,205 | New — message tile extracted |
| `thread/thread_utils.dart` | 306 | New — shared utilities |

### `lib/features/posts/presentation/` (prior session)

| File | Lines | Note |
|---|---|---|
| `compose_screen.dart` | 3,241 | Reduced from 3,638 |
| `compose/compose_models.dart` | 94 | New — attachment models / enums |
| `compose/compose_widgets.dart` | 347 | New — visibility chip, attachment widgets |

### `lib/features/posts/presentation/widgets/` (this session)

| File | Lines | Note |
|---|---|---|
| `post_card.dart` | 1,511 | Reduced from 2,481 |
| `post_card/post_card_models.dart` | 38 | New — `PostCardResolvedMediaItem` |
| `post_card/post_card_utils.dart` | 71 | New — URL/share/clipboard helpers |
| `post_card/post_card_parts.dart` | 498 | New — identity header, media block, badges |
| `post_card/post_card_media.dart` | 444 | New — media viewer dialog, video/image viewers |

### `lib/features/me/presentation/` (this session)

| File | Lines | Note |
|---|---|---|
| `me_screen.dart` | 1,803 | Reduced from 2,029 |
| `me/me_widgets.dart` | 303 | New — record card, section, settings item, chips |
| `edit_profile_screen.dart` | 1,765 | Reduced from 1,972 |
| `edit_profile/edit_profile_widgets.dart` | 338 | New — panel, entry card, field, empty surface |

---

## Naming conventions

- Extracted **widget classes**: prefixed by feature context (`PostCard*`, `Thread*`, `Compose*`, `Me*`, `EditProfile*`)
- Extracted **utility functions**: short descriptive names without prefix (e.g., `canonicalPostUrl`, `openExternalUrl`)
- Extracted **models**: prefixed by feature context (`PostCardResolvedMediaItem`, `ComposeAttachment`)

---

## What was NOT changed

- Routes (`go_router` configuration)
- Providers (Riverpod state)
- Repository or domain layer
- Auth / realtime logic
- Any existing public API surface
