# Aura Frontend Admin Hub Readiness Handoff

Audit only. No code was modified for this report.

## Executive Summary
The backend Admin Hub is now grant-based and production-capable. The frontend is not ready to connect to it safely yet because it still relies on local admin heuristics:

- `AURA_ADMIN_USER_IDS` is still used in two places.
- `role == 'admin'` is still treated as admin authority on the frontend.
- several admin-like screens are gated by a local provider instead of backend `admin/me`.
- some screens are real and useful, but others are placeholders or mixed-purpose shells that would leak capability if connected as-is.

The frontend should not be redesigned until the admin permission client exists. The safest next step is to replace local admin identity checks with a backend-hydrated admin session state from `GET /v1/admin/me`.

## Exact Files Inspected

### Routing / shell
- `lib/router.dart`
- `lib/app/route_classification.dart`
- `lib/app/app_shell.dart`
- `lib/app/shell/admin_shell.dart`

### Frontend admin identity / gating
- `lib/core/auth/admin_access_provider.dart`
- `lib/core/auth/session_bootstrap.dart` (route/auth context only)

### Member / admin entry points
- `lib/features/me/presentation/me_screen.dart`
- `lib/features/communications/presentation/communications_center_screen.dart`
- `lib/features/communications/presentation/widgets/communication_center_shell.dart`
- `lib/features/communications/presentation/widgets/communication_role_hero.dart`
- `lib/features/communications/presentation/widgets/admin_communication_workspace.dart`
- `lib/features/institutions/presentation/admin_workspace_screen.dart`

### Announcements
- `lib/features/announcements/presentation/announcements_screen.dart`
- `lib/features/announcements/presentation/announcement_editor_screen.dart`
- `lib/features/announcements/data/announcements_repository.dart`

### Institutions
- `lib/features/institutions/presentation/institution_dashboard_screen.dart`
- `lib/features/institutions/domain/institution_domains_screen.dart`
- `lib/features/institutions/data/institutions_repository.dart`
- `lib/features/institutions/announcements/institution_announcements_screen.dart`
- `lib/features/institutions/correspondence/institution_correspondence_screen.dart`

### Admin-adjacent data layer
- `lib/features/communications/communications_repository.dart`
- `lib/features/institutions/data/institutions_repository.dart`

## Exact Frontend Admin-ID / Env Usages Found

### 1) `lib/core/auth/admin_access_provider.dart`
Uses:
- `String.fromEnvironment('AURA_ADMIN_USER_IDS', defaultValue: '')`
- local `role == 'admin'` check from `/users/me`
- `id in AURA_ADMIN_USER_IDS` as a second admin authority path

Risk:
- this is runtime admin authority in the frontend, which is now stale and unsafe.
- it can diverge from the backend’s durable `AdminGrant` model.

### 2) `lib/features/announcements/presentation/announcements_screen.dart`
Uses:
- duplicate `AURA_ADMIN_USER_IDS` env list
- local `role == 'admin'` check
- branches the screen into admin/public/institution views based on that local gate

Risk:
- the admin branch can be shown or hidden without backend grant truth.
- this screen mixes public browsing with admin workspace behavior.

### 3) `lib/router.dart`
Uses:
- `appAdminAccessProvider`
- `requiresAppAdmin(path) && !appAdmin.isAdmin` redirect to `/home`

Risk:
- route access depends on frontend-local admin state instead of `/v1/admin/me`.

### 4) `lib/features/institutions/presentation/admin_workspace_screen.dart`
Uses:
- `appAdminAccessProvider`
- local `admin.isAdmin` to render the whole workspace

Risk:
- placeholder admin modules are visible behind a local check that no longer matches backend authority.

### 5) `lib/features/communications/presentation/widgets/communication_center_shell.dart`
Uses:
- `appAdminAccessProvider`
- reveals admin workspace content when `isAdmin` is true

Risk:
- admin communication tools are mixed into a member communications screen.

### 6) `lib/features/communications/presentation/widgets/communication_role_hero.dart`
Uses:
- `isAdmin` from `appAdminAccessProvider`
- shows “Open admin workspace”

Risk:
- front-end admin CTA is local-state driven.

### 7) `lib/features/me/presentation/me_screen.dart`
Uses:
- `appAdminAccessProvider`
- shows an “Admin workspace” link when local admin state is true

Risk:
- member profile surface can expose admin routing based on stale local authority.

## Current Admin / Institution / Moderation / Announcement Screens

| File | Route | Current state | Current data source / API | Risk | Backend endpoint it should connect to now |
|---|---|---|---|---|---|
| `lib/features/institutions/presentation/admin_workspace_screen.dart` | `/admin` | Real shell, but mostly placeholder cards | `appAdminAccessProvider`; currently routes to announcements, communications, institutions, search, activity | High: placeholder hub with local admin gate | `GET /v1/admin/me`, `GET /v1/admin/metrics/overview`, `GET /v1/admin/health`, `GET /v1/admin/users`, `GET /v1/admin/grants`, `GET /v1/admin/audit-logs`, `GET /v1/admin/settings`, `GET /v1/admin/feature-flags` |
| `lib/features/communications/presentation/communications_center_screen.dart` | `/admin/communications` | Real, but still local-admin-gated | `communicationsRepositoryProvider` + `appAdminAccessProvider` | Medium-high: mixed member/admin surface | `GET /v1/admin/me` for permission state, plus existing admin-guarded comms workflows |
| `lib/features/communications/presentation/widgets/admin_communication_workspace.dart` | nested in `/admin/communications` | Real feature panel, but still a narrow legacy workspace | comms repo workflows | Medium: admin tools embedded in member comm center | `GET /v1/admin/me` plus existing comms admin workflow endpoints |
| `lib/features/announcements/presentation/announcements_screen.dart` | `/announcements` | Real public screen with admin/institution branching | `/users/me`, `announcementsProvider`, `pinnedAnnouncementsProvider` | High: local env admin heuristic and mixed surface | `GET /v1/admin/me` for admin branch gating; existing announcement CRUD remains on `/admin/announcements` |
| `lib/features/announcements/presentation/announcement_editor_screen.dart` | `/announcements/create` | Real editor, but mixed-purpose and backend-heavy | `announcementsRepository`, LinkedIn/TikTok publish endpoints | Medium-high: exposes publish workflows without a backend admin gate | `GET /v1/admin/me` for admin-only publishing branches; current publish APIs remain backend-specific |
| `lib/features/institutions/presentation/institution_dashboard_screen.dart` | `/institution/dashboard` | Real institution workspace | `/institutions/me` | Low for admin hub; this is institution/member workflow | Keep on institution routes; admin hub should not replace this screen |
| `lib/features/institutions/domain/institution_domains_screen.dart` | `/institution/domains` | Real institution admin/member tool | `/institutions/:institutionId/domains` | Low-medium: separate institution governance branch | Keep on institution routes; platform-admin domain review should use `/v1/admin/institution-domains` in a separate admin view |
| `lib/features/institutions/announcements/institution_announcements_screen.dart` | `/institution/announcements` | Placeholder / legacy | No real backend binding | High: explicit placeholder workspace | Do not connect until a real institution publishing API exists |
| `lib/features/institutions/correspondence/institution_correspondence_screen.dart` | `/institution/correspondence` | Placeholder / legacy | No real backend binding | High: explicit placeholder workspace | Do not connect until a real institution correspondence API exists |

## Backend Endpoint Mapping Table

| Backend endpoint | Frontend consumer now | What it should power | Status |
|---|---|---|---|
| `GET /v1/admin/me` | `appAdminAccessProvider` replacement; `/admin` shell; `/admin/communications`; `/announcements` admin branch | Hydrated admin identity, role, permissions, grants, status | Not connected yet |
| `GET /v1/admin/users` | future admin users panel | Member search, identity detail, role/status management | Not connected yet |
| `GET /v1/admin/users/:id` | future admin user detail drawer/page | Member detail, grants, devices, status history | Not connected yet |
| `PATCH /v1/admin/users/:id/status` | future user moderation action | Suspend/restore/disable | Not connected yet |
| `GET /v1/admin/grants` | future grants panel | View grants, roles, expiration, owner controls | Not connected yet |
| `POST /v1/admin/grants` | future grants panel | Bootstrap/assign grants | Not connected yet |
| `PATCH /v1/admin/grants/:id` | future grants detail panel | Update grant role/permissions/expiry | Not connected yet |
| `POST /v1/admin/grants/:id/revoke` | future grants detail panel | Revoke grant, enforce last-owner rules | Not connected yet |
| `GET /v1/admin/audit-logs` | future audit viewer | Governance trail and filtering | Not connected yet |
| `GET /v1/admin/settings` | future settings panel | Platform settings list | Not connected yet |
| `PATCH /v1/admin/settings/:key` | future settings panel | Upsert config | Not connected yet |
| `GET /v1/admin/feature-flags` | future flags panel | Feature flag list | Not connected yet |
| `POST /v1/admin/feature-flags` | future flags panel | Create flag | Not connected yet |
| `PATCH /v1/admin/feature-flags/:key` | future flags panel | Update flag | Not connected yet |
| `GET /v1/admin/metrics/overview` | future dashboard overview | Users, institutions, reports, communications, realtime, devices, push | Not connected yet |
| `GET /v1/admin/health` | future system status panel | API, DB, Prisma, email, push, realtime health | Not connected yet |
| `GET /v1/admin/institution-domains` | future institution review panel | Platform-admin domain review list | Not connected yet |
| `POST /v1/admin/institution-domains/:id/approve` | future institution review panel | Approve domain | Not connected yet |
| `POST /v1/admin/institution-domains/:id/reject` | future institution review panel | Reject domain | Not connected yet |

## Required Frontend Data-Layer Work

### Models to add
- `AdminAccess`
- `AdminGrant`
- `AdminUserSummary`
- `AdminUserDetail`
- `AdminAuditLogEntry`
- `AdminSetting`
- `AdminFeatureFlag`
- `AdminMetricOverview`
- `AdminHealthSnapshot`
- `AdminInstitutionDomain`
- `AdminInstitutionDomainReviewResult`

### Repository/service layer
- `lib/features/admin/data/admin_repository.dart`
- `lib/features/admin/providers.dart`
- or a thin replacement of `lib/core/auth/admin_access_provider.dart` that hydrates `GET /v1/admin/me`

### Riverpod providers to add
- `adminMeProvider`
- `adminUsersProvider`
- `adminGrantsProvider`
- `adminAuditLogsProvider`
- `adminSettingsProvider`
- `adminFeatureFlagsProvider`
- `adminMetricsProvider`
- `adminHealthProvider`
- `adminInstitutionDomainsProvider`

### Permission/session state
- remove local env ID checks
- hydrate admin access from `/v1/admin/me`
- keep loading state while admin session is being resolved
- treat 403 as “not authorized”, not as a crash

### Route gating
- gate admin routes with backend permission state, not `AURA_ADMIN_USER_IDS`
- keep public/member routes independent
- do not let admin gating leak into institution/member-only routes

### UI states needed
- loading
- unauthorized / insufficient-permission
- empty state
- error state
- retry

## Screens / Components To Remove or Replace Later

### Replace / remove
- `lib/core/auth/admin_access_provider.dart`
- `lib/features/announcements/presentation/announcements_screen.dart` local env-admin branch
- `lib/features/institutions/presentation/admin_workspace_screen.dart` placeholder module cards
- `lib/features/communications/presentation/widgets/communication_center_shell.dart` admin workspace reveal logic
- `lib/features/communications/presentation/widgets/communication_role_hero.dart` admin CTA/role badge logic
- `lib/features/communications/presentation/widgets/admin_communication_workspace.dart` once a real admin hub layout exists
- `lib/app/shell/admin_shell.dart` if its two-tab shell remains only a stub
- `lib/router.dart` admin route gate based on `appAdmin.isAdmin`

### Keep but rewire
- `lib/features/announcements/presentation/announcement_editor_screen.dart`
- `lib/features/institutions/presentation/institution_dashboard_screen.dart`
- `lib/features/institutions/domain/institution_domains_screen.dart`

### Do not promote yet
- `lib/features/institutions/announcements/institution_announcements_screen.dart`
- `lib/features/institutions/correspondence/institution_correspondence_screen.dart`

## Recommended Files To Edit Later

1. `lib/core/auth/admin_access_provider.dart`
2. `lib/router.dart`
3. `lib/app/shell/admin_shell.dart`
4. `lib/features/me/presentation/me_screen.dart`
5. `lib/features/communications/presentation/communications_center_screen.dart`
6. `lib/features/communications/presentation/widgets/communication_center_shell.dart`
7. `lib/features/communications/presentation/widgets/communication_role_hero.dart`
8. `lib/features/institutions/presentation/admin_workspace_screen.dart`
9. `lib/features/announcements/presentation/announcements_screen.dart`
10. `lib/features/announcements/presentation/announcement_editor_screen.dart`

## Recommended Frontend Models / Providers / Repositories

### Repositories
- `admin_repository.dart`

### Providers
- `adminAccessProvider`
- `adminMeProvider`
- `adminOverviewProvider`
- `adminUsersProvider`
- `adminGrantsProvider`
- `adminAuditLogProvider`
- `adminSettingsProvider`
- `adminFeatureFlagsProvider`
- `adminHealthProvider`

### Domain models
- `AdminAccess`
- `AdminGrant`
- `AdminUserSummary`
- `AdminUserDetail`
- `AdminAuditLogEntry`
- `AdminMetricSnapshot`
- `AdminHealthSnapshot`
- `AdminSetting`
- `AdminFeatureFlag`

## Claude Execution Prompt Draft

Use this sequence when starting the frontend implementation:

1. Replace `AURA_ADMIN_USER_IDS` and any local `role == 'admin'` heuristics with backend-hydrated admin session state from `GET /v1/admin/me`.
2. Add a typed admin repository, providers, and models for `/v1/admin/*`.
3. Rewire `/admin` and `/admin/communications` to use backend permission state, not local checks.
4. Connect the admin home/overview to `/v1/admin/me`, `/v1/admin/metrics/overview`, and `/v1/admin/health`.
5. Add users, grants, and audit-log views next.
6. Connect institution domain review/admin governance next.
7. Connect settings and feature flags after the core admin views are stable.
8. Redesign the Admin Hub UI only after the data layer is correct.
9. Finish with a route-permission matrix and QA pass.

## Validation Checklist For The Next Phase

- No frontend code reads `AURA_ADMIN_USER_IDS`.
- No frontend code assumes `role == 'admin'` from `/users/me` is enough for platform admin access.
- `/admin` and `/admin/communications` hydrate from `/v1/admin/me`.
- Unauthorized users see an explicit denied/unauthorized state.
- Admin routes do not leak into member or institution routes.
- Admin dashboard shows backend metrics and health, not placeholder cards.
- Users, grants, audit logs, settings, feature flags, and institution review screens are backed by typed data.
- All admin mutations are permissioned and have loading/error/retry states.
- The existing public/member experience remains unchanged.

## Bottom Line
The backend is ready enough to support the Admin Hub. The frontend is not ready to connect yet because it still trusts local admin IDs and has placeholder admin surfaces. The first frontend change should be to remove frontend authority and hydrate admin permissions from `/v1/admin/me`.
