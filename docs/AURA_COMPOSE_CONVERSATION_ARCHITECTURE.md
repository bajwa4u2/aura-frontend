# Aura Compose + Conversation Architecture

## Files Changed
- [lib/features/posts/presentation/compose_screen.dart](/mnt/c/Users/muham/flutter_projects/aura_final/lib/features/posts/presentation/compose_screen.dart)
- [lib/features/correspondence/presentation/thread_screen.dart](/mnt/c/Users/muham/flutter_projects/aura_final/lib/features/correspondence/presentation/thread_screen.dart)

## Compose Architecture Summary
- `/compose` was reflowed from a single “everything at once” panel into a guided publishing flow.
- The screen now reads as:
  - hero/status header first
  - editor-first content column
  - supporting review/translate controls
  - media/attachment section
  - audience selection
  - cross-post distribution summary
  - sticky save/publish footer
- Existing submit, autosave, upload, review, translation, LinkedIn, and TikTok logic was preserved.
- Payload keys, endpoints, and draft handling were not changed.
- Copy now favors:
  - `Create post`
  - `Write first, configure second, review third.`
  - `Save draft`
  - `Publish post`

## Thread Mode Architecture Summary
- `/me/correspondence/:spaceId/thread/:threadId` now branches visibly by thread mode using `CorrespondenceIdentity.resolveThreadContext(...)`.
- Presentation now separates:
  - direct conversation
  - group conversation
  - shared space thread
- Direct mode:
  - person-centric header
  - no space labels or space actions
  - profile brief rail
- Group mode:
  - group-centric header
  - participant-focused rail
  - no space actions unless actual space context exists
- Shared space mode:
  - space title + thread framing
  - space actions remain visible only here
- The message composer, attachment logic, edit/delete flow, and realtime call flow were preserved.

## Routes Preserved
- `/compose`
- `/me/correspondence/:spaceId/thread/:threadId`
- existing correspondence and realtime navigation paths were left intact

## Backend / API Contracts Preserved
- No backend files were changed.
- No repositories or providers were changed.
- No API endpoints, payload keys, auth/session logic, or route paths were changed.
- The refactor is presentation-only and uses existing thread/context data.

## Commands Run And Results
- `flutter analyze`
  - passed
- `flutter test`
  - passed
- `flutter build web --release --dart-define=API_BASE_URL=https://api.auraplatform.org --dart-define=AURA_ADMIN_USER_IDS=cmm69u97n0000pi01rm3fyglq`
  - passed

## Known Follow-Ups
- Thread mode detection still depends on the data available in the existing thread payload; if a backend record is sparse, the resolver falls back to the safest generic label.
- The compose page still contains the existing large feature set; this change reorganizes it into a guided structure rather than removing capabilities.
- The web build still reports the existing Flutter web initialization deprecation in `index.html` and the `socket_io_common` wasm dry-run lint warning, but both are outside this task scope and the release build succeeded.
