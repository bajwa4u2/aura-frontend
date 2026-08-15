# Frontend Surface Inventory

**Measured 2026-08-15** against `aura_final`. Counts are from the source tree, not from memory.

## Scale

| Metric | Value |
|---|---|
| Dart files | 544 |
| Lines of Dart | 189,134 |
| `GoRoute` declarations | 171 |
| Redirects in `router.dart` | 27 |
| `router.dart` size | 2,100 lines |
| Shells | 4 (`public`, `member`, `admin`, `global_platform`) |
| Screen classes | 136 |
| Feature directories | 37 |

## Competing organisational roots

`lib/` carries **five** parallel organisation schemes, each from a different era:

| Root | Files | Lines |
|---|---|---|
| `features/` | 348 | 151,591 |
| `core/` | 158 | 22,767 |
| `app/` | 13 | 7,416 |
| `screens/` | 14 | 3,440 |
| `shared/` + `state/` + `widgets/` + `models/` | 8 | 1,587 |

`screens/` holds public marketing/legal pages; `features/` holds product; `core/` holds shared UI + services. Nothing states which root a new surface belongs in.

## Largest files (patch-accumulation hotspots)

| Lines | File |
|---|---|
| 3,890 | `features/meetings/presentation/meeting_live_room_screen.dart` |
| 3,385 | `features/posts/presentation/compose_screen.dart` |
| 3,265 | `features/realtime/presentation/realtime_room_screen.dart` |
| 2,737 | `features/realtime/application/realtime_controller.dart` |
| 2,209 | `features/correspondence/presentation/thread/thread_composer.dart` |
| 2,153 | `features/institutions/profile/institution_edit_profile_screen.dart` |
| 2,100 | `router.dart` |
| 2,068 | `features/institutions/posts/institution_post_composer_screen.dart` |
| 2,034 | `app/shell/member_shell.dart` |
| 1,977 | `app/shell/rail/rail_modules.dart` |

## Feature inventory by size

institutions 28,249 · meetings 19,827 · realtime 13,533 · correspondence 11,086 · public 9,550 · admin 8,235 · posts 7,690 · me 7,219 · feed 5,916 · auth 4,595 · invitations 3,345 · announcements 3,273 · communications 3,108 · home 2,736 · support 2,158 · updates 2,117 · profile 1,863 · create 1,576 · direct_threads 1,460 · activity 1,423 · messages 1,356 · devices 1,072 · accountability 1,122 · conversations 1,033 · monetization 967 · search 752 · institution_ontology 709 · topics 647 · composition 667 · ai 616 · ai_safety 560 · civic_signals 531 · saves 324 · share 130 · translation 79

## Duplicated surface families

**Live/realtime rooms — 3 independent implementations**
- `realtime/presentation/realtime_room_screen.dart` (3,265)
- `meetings/presentation/meeting_live_room_screen.dart` (3,890)
- `institutions/live_rooms/institution_live_rooms_screen.dart` (1,078)

**Thread screens — 3 with overlapping names**
- `correspondence/presentation/thread_screen.dart` (1,751)
- `public/presentation/thread_screen.dart` (1,707)
- `direct_threads/presentation/direct_thread_screen.dart`

**Inbox / attention — 8 surfaces** (see `INBOX_ATTENTION_AUDIT.md`)

**Composers — 6 production composers** (see `COMPOSER_MESSAGING_ATTACHMENT_AUDIT.md`)

> ✅ **TASK/DOMAIN-ORIENTED ADAPTIVE NAVIGATION — FROZEN 2026-08-15.** The route inventory below is **reconstruction territory**, not a structure to preserve. 171 routes · 27 redirects · 40 mirrored institution routes · module-oriented destinations are all demolition/convergence candidates. Deep-link requirements and valid product behaviour must survive; **exact primary destinations are not frozen**. See `NAVIGATION_IA_PRODUCT_LANGUAGE_FROZEN.md`.

## Institution-context route mirroring

**40 routes** are `/institution/:institutionId/...` duplicates of personal-context routes, including `u/:handle`, `institutions/:slug`, `direct/:threadId`, `posts/:postId/edit`, `activity`, `messages`. The entire personal navigation tree is mirrored under institution context rather than context being a property of a single tree.

## Dead / near-dead surfaces

| Surface | Lines | Evidence |
|---|---|---|
| `conversations/presentation/conversations_screen.dart` | 1,033 | **Zero router references; only self-references.** Unreachable. |
| `InstitutionCorrespondenceScreen` | — | ≤2 references repo-wide |
| `PresenceScreen` (inside `me_screen.dart`) | — | ≤2 references repo-wide |
| `SupportScreen` (monetization) | — | ≤2 references repo-wide |

**FD-12 (FROZEN 2026-08-15) dispositions the above.** `conversations_screen.dart` is **approved for retirement** (proven dead). The other four remain **candidates, not retirement decisions** — carried into correspondence reconstruction, FD-11 identity reconstruction, auth/navigation review and monetization-ownership review.

**Recorded lesson:** the `LoginScreen` entry is a **false positive** — a `/login` route exists. **Static reference count alone is not a safe reachability authority.**

**Founder-approved principle:** every production surface must have an explicit, auditable reachability/ownership path, or be explicitly classified as legitimate non-routable/internal. A naïve zero-reference build gate is **forbidden**; enforcement must be architecture-aware (mechanism deferred to FD-13). See `FD12_SURFACE_DISPOSITION_FROZEN.md`.

Confirmed dead code is reported, not deleted — this task is investigation only.
