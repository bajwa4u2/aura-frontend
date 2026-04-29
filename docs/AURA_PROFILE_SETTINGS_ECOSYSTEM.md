# Aura Profile / Preferences / Settings Ecosystem

## Overview

The profile and settings surface is split across four screens, each with a distinct responsibility. All routes are preserved from the existing router configuration.

## Screens

### `/me` — `MeScreen`
`lib/features/me/presentation/me_screen.dart`

The primary identity surface. Responsive (≥900 px wide / narrow layouts).

**Sections:**
- **PresenceHeader** — avatar, cover, display name, handle, bio, follower/following meta, Edit profile + View profile actions
- **Profile health panel** — linear progress bar + chip checklist (display name, handle, bio, avatar, location, website). Shows a "Complete your profile →" CTA when any fields are missing.
- **Personal Record** — saved posts, held-for-later, private posts
- **Public record / Elsewhere** — publications and links (shown when populated)
- **Connections** — invitation center, new invite, follow requests
- **Connected accounts** — LinkedIn and TikTok integration management
- **Settings hub** (formerly "Account") — unified settings entry point:
  - **Security** — routes to `/security`; surfaces an inline email-verification badge (green "Verified" / amber "Verify email") derived from `emailVerifiedProvider`
  - **Communication preferences** — routes to `/me/settings/communications`
  - **Support** — routes to `/support/agent`
- **Authority & Workspaces** — institution workspace and admin workspace (shown only when relevant)

### `/me/edit` — `EditProfileScreen`
`lib/features/me/presentation/edit_profile_screen.dart`

Section-based profile editor with sidebar nav (Identity, Cover & Avatar, Presence, Publications, Links, Account). Image upload via `AuraMediaUpload`. Tracks dirty state per field and shows unsaved-changes indicator.

### `/security` — `SecurityScreen`
`lib/features/me/presentation/security_screen.dart`

Comprehensive security surface:
- Password change / email verification with live status badges (`_StatusStyle`: good / warn / danger / neutral)
- Active sessions list
- Browser push notification permission (web only)
- Account → comms preferences link
- Danger zone: account deletion

### `/me/settings/communications` — `CommunicationsCenterScreen`
`lib/features/communications/presentation/communications_center_screen.dart`

Communication preferences hub. Delegates all rendering to `CommunicationCenterShell`. Supports per-channel (email, push, SMS) and per-frequency (instant, digest, weekly) preferences via `communicationsRepositoryProvider`.

## Providers

| Provider | Source | Description |
|---|---|---|
| `emailVerifiedProvider` | `core/auth/session_providers.dart` | `FutureProvider<bool>` — reads `/users/me` to check `emailVerified` / `emailVerifiedAt` |
| `isAuthedProvider` | `core/auth/session_providers.dart` | `Provider<bool>` — derived from `TokenStore` loaded + authed |
| `appAdminAccessProvider` | `core/auth/admin_access_provider.dart` | `FutureProvider<AppAdminAccess>` |
| `institutionAccessProvider` | `core/institutions/institution_access_provider.dart` | Institution role and state |
| `communicationsRepositoryProvider` | `features/communications/providers.dart` | Repo for GET/PATCH `/users/me/communication-preferences` |

## Widget Primitives

`lib/features/me/presentation/me/me_widgets.dart`

| Widget | Description |
|---|---|
| `MeSection` | Titled card container with divider-separated children |
| `MeSettingsItem` | Row item with icon, label, subtitle, optional `trailing` widget, and chevron |
| `MeStatusBadge` | Pill badge with `MeStatusStyle` (good / warn / neutral) for inline security signals |
| `MeMetaChip` | Static pill chip for hero meta (location, etc.) |
| `MeMetaLinkChip` | Tappable meta chip |
| `MeRecordItemCard` | Card item for publications and links |

## Design Tokens

All components use the Aura design system:
- `AuraSurface` — color tokens (card, elevated, divider, accent, goodBg/goodInk, warnBg/warnInk)
- `AuraText` — text styles (title, body, small, micro)
- `AuraRadius` — border radii (card, xl, pill)
- `AuraSpace` — spacing constants
