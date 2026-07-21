# AGENTS.md — Aura Flutter Frontend

Operating law for agents working in `aura_final/`. The umbrella scope file is `../AGENTS.md`; this file overrides for frontend work.

## Repo identity

Flutter (single codebase: iOS + Android + Web). Three application shells (Member / Institution / Admin) + Public shell. Talks to `aura-backend` under global `/v1`. Out-of-scope: anything under `../../orchestrate/`.

## Category guardrail

Aura is **verified-identity civic discourse infrastructure**. This frontend is **not**:

- a consumer social app (no engagement bait, no algorithmic feed, no virality patterns)
- a workspace messenger (the Institution Shell is institutional authority, not internal chat)
- an AI assistant app (AI is utility — Review, Translate, Support — never the headline)
- a generic content-management UI (institutional voice is typed and authority-gated)

If a change would flatten Aura into any of those, refuse it.

## Architecture boundaries

```
lib/
  app/
    app_shell.dart                   ← shell selection (token-keyed)
    shell/                           ← Member / Institution / Admin / Public shells
  router.dart                        ← route table + guards
  core/
    network/                         ← single API client; base URL owns /v1
    ui/                              ← AuraDesignSystem, AuraText, AuraSpace, AuraRadius
    theme/                           ← dark-first
  features/
    auth, home, posts, feed, correspondence, conversations, direct_threads,
    institutions, announcements, announcements, invitations, me, profile,
    create, search, saves, notifications, activity, updates, support,
    admin, realtime, ai, communications, devices, monetization, share, public
```

Shells are structurally distinct. Members switch into Institution Shell for institutional work; Admin Shell is a separate IA with amber accent and "PLATFORM CONTROL" register.

## Canonical abstractions (preserve)

- **Multi-shell architecture** (`lib/app/app_shell.dart`): shell selection is **token-keyed** (presence of refresh token), not auth-state-keyed. Prevents mid-session shell thrash during JWT refresh.
- **API client contract** (`lib/core/network/`): single `Dio` client, base URL owns `/v1`, individual paths must NOT include `/v1`.
- **AuraDesignSystem** (`lib/core/ui/aura_design_system.dart` + adjacent files): `AuraText`, `AuraSpace` (s4–s32), `AuraRadius` (card / xl / pill / r10 / r14), `AuraShadows`, gradients. Dark-first.
- **Shell accents**: Member = indigo `#5B6CFF`, Institution = teal `#0D9488`, Admin = amber `#F59E0B`, Public = neutral navy `#1A1A2E`.
- **Compose intents**: `Ask` / `Raise` / `Share` — these are user-visible vocabulary.
- **Speech-mode toggle** in compose: maps to `InstitutionSpeechMode` enum on the post. UI must surface the active mode clearly.

## Forbidden drift

- Adding social-media engagement vocabulary or affordances: "like", "viral", "trending", algorithmic ranking, recommended-for-you feed, follower-count-as-social-proof.
- Adding CRM / sales vocabulary to user-visible surfaces: "Leads", "Pipeline", "Campaign" (in nav, page titles, button labels, empty state copy). Internal model names may carry these; user-facing strings must not. See `../marketing/terminology-system.md`.
- Promoting "AI" as a top-level feature surface. AI is utility (`Review`, `Translate`, `Support agent`); never `AI assistant` / `AI copilot` / `AI agent`.
- Bypassing the shell-selection logic in `lib/app/app_shell.dart`. Route-key on shell intent, not URL parsing.
- Importing test packages in `lib/` (test code belongs in `test/`).
- Adding empty referenced screens (every imported screen must render meaningfully or carry a self-aware "feature in progress" empty state).
- Breaking the API contract by adding fallback / non-`/v1` paths.
- Mixing terminology: "Messages" / "Correspondence" / "Conversations" / "Direct Threads" — see `../marketing/terminology-system.md`. The canonical user-facing label is **Correspondence**.
- Removing empty / loading / error / permission / offline states from critical flows. New screens must carry all five where applicable.
- Hardcoding URLs or API tokens in source. Use `dart-define` at build time.

## Secret handling

- `.env` is gitignored at the project root (`**/.env` in parent `.gitignore`).
- Never commit: `android/key.properties`, `android/local.properties`, `android/app/upload-keystore.jks`, signing keys.
- API tokens for OAuth / push (Firebase, LinkedIn, TikTok) come from `dart-define` at build time or are fetched from `aura-backend`.
- If a real credential is discovered in any file, flag for rotation and remove the value.
- Do not commit `aura.stderr.log`, `aura.stdout.log`, `logcat-aura.log`, `flutter_verbose.log` (already gitignored as `*.log`).

## Token discipline

Default load for agents:

- this file (`AGENTS.md`)
- `../AGENTS.md` (umbrella scope, only if cross-repo context needed)

Opt-in (load only when the task requires):

- `docs/AURA_MULTI_SHELL_ARCHITECTURE.md` — shell architecture details
- `docs/AURA_INSTITUTION_ONBOARDING_WIZARD.md` — institution onboarding wizard
- `docs/AURA_ME_PROFILE_REARCHITECTURE.md`, `docs/AURA_PROFILE_SETTINGS_ECOSYSTEM.md` — profile system
- `docs/AURA_MESSAGES_FLAGSHIP_REDESIGN.md` — correspondence redesign
- `docs/ADMIN_FRONTEND_READINESS_HANDOFF.md`, `docs/ADMIN_RUNTIME_GOVERNANCE.md` — admin shell
- `docs/AURA_REAL_PUSH_TOKEN_ACQUISITION.md`, `docs/AURA_FRONTEND_DEVICE_REGISTRATION.md` — push / device
- `../docs/AURA_FULL_FRONTEND_REDESIGN_PLAN.md`, `../docs/AURA_HERO_SURFACES_REBUILD_MAP.md` — frontend roadmap

Do not load by default:

- `aura.stderr.log`, `aura.stdout.log`, `logcat-aura.log`, `flutter_verbose.log`, `deps.txt`, `build-error.log` — debug artifacts, often huge
- `../marketing/**` — load only for positioning, copy, or external-facing work
- `../docs/RELEASE_READINESS_AUDIT_*.md` — release readiness; load only for that
- `docs/business_deck/` — marketing-adjacent; load only when working on decks
- `.dart_tool/`, `build/`, `ios/Pods/`, `android/.gradle/`, `web/canvaskit/` — generated

## Required validation

For Dart code changes:

```
flutter analyze
flutter test
```

For routing / runtime changes:

```
flutter build apk --debug      # or appropriate target
```

For web SEO / metadata changes:

```
flutter build web --release --dart-define=...
```

Do not claim `flutter analyze` is clean unless it actually exited 0 with zero issues.

## Git discipline

- Branch per task.
- Commit messages: short imperative summary + body that explains the "why."
- Never force-push to `main`.
- Do not bypass hooks (`--no-verify`) without explicit user authorization.
- If a pre-commit hook fails, fix the issue and create a new commit. Do not `--amend` a published commit.

## Documentation discipline

- Frontend architecture decisions → `docs/` with a dated filename.
- Marketing / positioning / external narrative → `../marketing/` (canon lives there; do not duplicate).
- Do not create a new audit/redesign/handoff doc unless the task explicitly requests it.

## Completion standard

A change is complete when:

1. `flutter analyze` exits 0 with zero issues.
2. `flutter test` passes affected tests.
3. New screens carry empty / loading / error states where applicable.
4. No new empty referenced screens.
5. No new lib-side imports of test packages.
6. No new hardcoded API URLs or tokens.
7. Terminology conforms to `../marketing/terminology-system.md`.
8. Shell separation respected; no cross-shell route leaks.
9. A PR / commit message explains the change and the validation run.

## Known live findings (verify before assuming fixed)

- `test/widget_test.dart` may reference `MyApp` while the app uses `AuraApp` — fix when touched.
- `lib/test/widget_test.dart` should not exist under `lib/` — remove if encountered.
- `lib/features/institutions/announcements/institution_announcement_editor_screen.dart` and `lib/features/institutions/members/institution_members_screen.dart` may be empty — verify before importing.
- "Messages" / "Correspondence" / "Conversations" terminology collision is a known launch blocker — see `../marketing/terminology-system.md` Conflict #1.

These are tracked. Do not "fix" them in passing without scope.

## Repository Continuity Doctrine (workspace-wide, 2026-07-21)

Repository documentation is authoritative. Conversation history is temporary.

This repository maintains its canonical continuity records in `audit/working-directory/` (`CURRENT_STATE.md`, `NEXT_WORK.md`, `HANDOFF.md`, `DECISIONS.md`, `OPERATIONAL_BASELINE.md`). Read `HANDOFF.md` first when taking over work.

- No implementation milestone is complete until the continuity documents are synchronized.
- Every milestone must record: completed implementation; founder-approved architectural decisions; production baseline; current implementation status; the next implementation starting point; and outstanding founder approvals.
- Future agents resume from repository continuity documentation, never from assumptions or prior conversations.

Engineering lifecycle -- no step may be bypassed:

```text
Implement -> Founder Approval -> Commit -> Continuity Synchronization -> Next Milestone
```
