# Aura 1.3.0 — Technical Change Summary

## Scope

- Frontend (`aura_final`): 16 commits, `3c7cc2e..HEAD`, 38 non-test files changed, +4807/-954 lines (including new test files).
- Backend (`aura-backend`): 22 commits, `dc165f2..HEAD`, 106 files changed, +9022/-1153 lines.
- 7 new backend migrations landed and are confirmed applied in production (`prisma migrate status` reports schema up to date, 100/100 migrations, zero drift):
  `20260805000000_routed_public_record_updated_at`, `20260805010000_routed_public_record_acknowledge`, `20260805020000_routed_public_record_resolve_reopen`, `20260805030000_routed_public_record_resolution_history`, `20260805040000_communication_continuation_reference`, `20260804150000_communication_translation_cache`, plus the preceding `20260802100000_unified_notification_routing` / `20260802110000_reconcile_meeting_runtime_schema` already live from the prior window.
- No breaking API contract changes identified: all endpoint changes are additive (new controllers/DTOs for continuity-read, acknowledge, resolve/reopen, topics) or internal-logic repairs to existing endpoints.
- One new backend config surface, `continuity-thresholds.config.ts`, reads optional env vars (`CONTINUITY_RAISE_ISSUE_OVERDUE_HOURS`, `CONTINUITY_RAISE_ISSUE_STALE_HOURS`, `CONTINUITY_RAISE_ISSUE_DORMANT_HOURS`, `CONTINUITY_ASK_STALE_HOURS`) with safe hardcoded fallbacks — not a required deployment dependency.
- No new required frontend `--dart-define` values; the existing `API_BASE_URL`, `AURA_ADMIN_USER_IDS`, `AURA_WEB_PUSH_VAPID_PUBLIC_KEY` set is unchanged.

## Deployment topology (verified, not assumed)

- Web and Backend auto-deploy on push to `main` via Railway; both are confirmed already running current HEAD in production as of this baseline (deployment timestamps match commit timestamps; `/health` returns 200; migration status confirms schema sync).
- Android, Windows, and iOS are versioned and distributed separately from `pubspec.yaml` and do not auto-deploy; they are the platforms this release actually advances.

## Version identity

| Field | Previous | New |
|---|---|---|
| `pubspec.yaml` version | `1.2.3+23` | `1.3.0+24` |
| Android `versionName`/`versionCode` | `1.2.3` / `23` | `1.3.0` / `24` (derived) |
| iOS `CFBundleShortVersionString`/`CFBundleVersion` | `1.2.3` / `23` | `1.3.0` / `24` (derived) |
| Windows `msix_version` | `1.2.3.0` | `1.3.0.0` |

## Known limitations

- iOS release archive cannot be produced on this Windows workstation; the signed IPA is produced only via the Codemagic hosted macOS workflow.
- The web release build emits the pre-existing `socket_io_common` WebAssembly dry-run compatibility warning during `flutter build web --release`; this does not affect the JavaScript release output actually shipped.
- `continuity-thresholds.config.ts` ships with hardcoded default thresholds (72h/14d/30d/14d) since Decision R3 of the Communication Continuity & Resolution Doctrine leaves exact values as founder-tunable rather than fixed doctrine; no action required unless the founder wants different defaults.
