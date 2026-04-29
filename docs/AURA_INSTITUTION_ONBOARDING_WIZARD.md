# Aura Institution Onboarding Wizard

Full-stack, product-grade institution onboarding system covering all user paths from public entry through post-approval workspace setup.

---

## Overview

The wizard replaces the old `/institution/create` form with a guided, multi-path flow at `/institutions/get-started`. It covers four distinct journeys and integrates with the backend via real API calls throughout.

---

## User Paths

| Path | Auth required | API endpoint |
|---|---|---|
| Create new institution | No (account created inline) | `POST /institutions/verification-request` |
| Claim existing institution | Yes | `POST /institutions/claim-request` |
| Join with invite code | Yes | `POST /institutions/invites/accept` |
| Existing admin sign in | Redirect | `/institution/sign-in` |

---

## Frontend

### Entry point

`/institutions/get-started` — canonical new route. Accepts `?mode=create|claim|join|signin` and `?code=<inviteCode>`.

Old routes redirect:
- `/institution/create` → `/institutions/get-started?mode=create`

### Wizard file

`lib/features/institutions/wizard/institution_onboarding_wizard.dart`

Single-file implementation (~700 lines) containing the full wizard and all sub-widgets.

#### Steps — Create / Claim

1. **Path chooser** — 4-way card selection (step 0)
2. **Institution identity** — name, type, website, jurisdiction, description; for claim path includes institution search field
3. **Representative** — first/last name, role, work email, phone, purpose; for unauthenticated create path adds password fields (account creation inline)
4. **Review** — read-only summary of all entered data with authority note
5. **Status** — submission confirmed, status pill, next-steps panel

#### Steps — Join

1. **Invite code** — single field, auth guard
2. **Success** — welcome panel with dashboard link

#### Key widgets

| Widget | Purpose |
|---|---|
| `_WizardHeader` | Back nav, step counter, linear progress bar |
| `_PathCard` | Tappable card for 4-way path selection |
| `_InstitutionSearchField` | Live search against `GET /institutions?q=...` for claim path |
| `_TypeDropdown` | Institution type selector (DropdownButtonFormField) |
| `_ReviewSection` / `_ReviewRow` | Read-only submission summary |
| `_SubmittedStatusPanel` | Post-submit status with `_StatusPill` |
| `_NextStepsPanel` | Ordered next-steps guide |
| `_AuthorityNote` | Inline disclaimer about review gating |
| `_AccountCreationNote` | Explains institution account separation |
| `_ErrorBanner` | Inline error display |
| `_AuthRequiredDialog` | Modal for unauthenticated claim/join attempts |
| `_RedirectingStep` | Loading state for `signin` path redirect |

### Router changes (`lib/router.dart`)

- Added `kInstitutionGetStartedRoute = '/institutions/get-started'`
- Added `InstitutionOnboardingWizard` import
- `/institution/create` now redirects to `/institutions/get-started?mode=create`
- `/institutions/get-started` route passes `mode` and `code` query params to wizard
- Already covered by `isPublicPath` via `path.startsWith('/institutions/')`

### Hub screen (`lib/screens/institutions_hub_screen.dart`)

- Primary CTA in hero changed to "Get started" → `/institutions/get-started`
- "Institution sign in" demoted to ghost button
- `_EntryCard` at bottom also uses wizard route

### Dashboard (`lib/features/institutions/presentation/institution_dashboard_screen.dart`)

- "Create institutional account" action now routes to `/institutions/get-started`
- Added "Invite members" tool card (routes to `/institution/:id/invites` when institution is active)

---

## Backend

### Prisma migration

`aura-backend/prisma/migrations/20260429025250_add_institution_onboarding_wizard/`

Changes:
- `NEEDS_INFO` value added to `InstitutionVerificationRequestStatus` enum
- `InstitutionVerificationRequest` extended: `claimTargetInstitutionId`, `phone`, `requestType` (default `'CREATE'`)
- New `InstitutionInvite` model: single-use, expiry-based, optional email restriction, role assignment

### New service methods (`institutions.service.ts`)

| Method | Description |
|---|---|
| `claimInstitutionRequest(userId, dto)` | Creates a `CLAIM` type verification request for an authenticated user |
| `markNeedsInfo(adminUserId, requestId, dto)` | Sets status to `NEEDS_INFO`, stores review notes, sends email |
| `createInvite(adminUserId, institutionId, dto)` | Creates invite with unique hex code; emails if address provided |
| `acceptInvite(userId, dto)` | Validates code, expiry, email restriction; creates membership |
| `listInvites(adminUserId, institutionId)` | Returns all invites for an institution admin |

Existing changes:
- `approveVerificationRequest` — now sends lifecycle approval email
- `rejectVerificationRequest` — now stores `reviewNotes` and sends rejection email

### New controller endpoints (`institutions.controller.ts`)

| Method | Path | Auth |
|---|---|---|
| `POST` | `/institutions/claim-request` | `JwtAuthGuard` |
| `POST` | `/institutions/invites/accept` | `JwtAuthGuard` |
| `POST` | `/institutions/:institutionId/invites` | `JwtAuthGuard` |
| `GET` | `/institutions/:institutionId/invites` | `JwtAuthGuard` |
| `POST` | `/institutions/admin/verification-requests/:id/needs-info` | `JwtAuthGuard` + `AdminGuard` + `VERIFICATION_WRITE` |

### DTOs (`institutions/dto/`)

**`institution-onboarding.dto.ts`** (new):
- `ClaimVerificationRequestDto`
- `CreateInstitutionInviteDto`
- `AcceptInstitutionInviteDto`
- `AdminNeedsInfoDto`
- `AdminRejectDto`

**`create-verification-request.dto.ts`** (extended):
- Added `phone?: string`

### Tests (`institutions.service.spec.ts`)

22 new unit tests across 6 describe blocks:
- `createVerificationRequest` — 5 tests (valid, password mismatch, existing institution, existing email, domain mismatch)
- `claimInstitutionRequest` — 3 tests (success, existing pending, suspended institution)
- `approveVerificationRequest` — 2 tests (success, wrong state)
- `rejectVerificationRequest` — 2 tests (stores notes, no authority granted)
- `markNeedsInfo` — 2 tests (success, wrong state)
- Invite lifecycle — 8 tests (forbidden non-admin, code generated, not found, already used, expired, success, email mismatch, suspended institution)

Total: 126 tests passing (22 new + 104 existing).

---

## Institution trust lifecycle

```
Submit request
    │
    ▼
UNDER_REVIEW  ──────────────────────────────► REJECTED
    │                                              │
    ├──────────────► NEEDS_INFO ──────────┐        │
    │                                    │        │
    ▼                                    ▼        ▼
APPROVED                         (resubmit)   (new request)
    │
    ▼
Institution + ADMIN membership created
    │
    ▼
Domain verified (DNS TXT record)
    │
    ▼
Full institutional standing active
```

---

## Design notes

- Personal and institutional accounts are explicitly separate. The wizard makes this visible with the `_AccountCreationNote` and `_AuthorityNote` widgets.
- Auth is checked client-side before claim/join paths; unauthenticated users see `_AuthRequiredDialog` and are redirected to `/login?redirect=...` with return path preserved.
- The invite code field is pre-filled when the route includes `?code=...` (for deep-link invite flows).
- All submission errors surface inline via `_ErrorBanner` with the message from the backend response.
