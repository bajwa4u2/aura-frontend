# Aura Multi-Shell Architecture

## Overview

Aura uses three distinct shell experiences to give Members, Institutions, and Platform Admins visually and structurally different products — all served from the same Flutter app.

Shell selection is driven entirely by the current route path and requires no additional backend calls. The decision tree lives in `lib/app/app_shell.dart`.

---

## The Three Shells

### Shell 1 — Member Shell

**Design tone:** Modern social platform. Expressive, identity-first, welcoming.

**Accent:** Indigo (#5B6CFF)

**Navigation:**

| Label    | Route               |
|----------|---------------------|
| Works    | /home               |
| Messages | /me/correspondence  |
| Create   | /compose            |
| Spaces   | /conversations      |
| Me       | /me                 |

**Desktop:** 240px side rail with rounded-pill active states. Create item renders as a gradient action button.

**Mobile:** Bottom navigation bar with icon + label. Create item renders as a glowing circular FAB.

**File:** `lib/app/shell/member_shell.dart` — `MemberShell` class

---

### Shell 2 — Institution Shell

**Design tone:** Organizational workspace. Structured, calm authority, professional clarity.

**Accent:** Teal (#0D9488)

**Navigation:**

| Label         | Route                         |
|---------------|-------------------------------|
| Overview      | /institution/dashboard        |
| Announcements | /institution/announcements    |
| Messages      | /institution/correspondence   |
| Settings      | /institution/profile          |

The Settings item also activates for `/institution/domains` and `/institution/request-verification` (sub-pages of the profile/settings area).

**Desktop:** 224px side rail with left-border indicator active states (3px teal bar + teal bg tint). Distinct from member pill style.

**Mobile:** Bottom navigation bar with teal active states.

**Header:** Teal "Workspace" badge alongside the wordmark. Teal-tinted header gradient.

**File:** `lib/app/shell/member_shell.dart` — `InstitutionShell` class

---

### Shell 3 — Admin Shell

**Design tone:** Platform command center. Operational, authoritative, utility-first.

**Accent:** Amber (#F59E0B)

**Navigation:**

| Label          | Route                  |
|----------------|------------------------|
| Dashboard      | /admin                 |
| Communications | /admin/communications  |

**Desktop:** 240px side rail with left-border indicator active states (3px amber bar + amber bg tint). Darker background than all other shells. "PLATFORM CONTROL" section label. "Elevated access" footer indicator.

**Mobile:** Bottom navigation bar with amber active states.

**Header:** Glowing amber "ADMIN" badge with pulsing dot indicator. Very dark header gradient.

**File:** `lib/app/shell/admin_shell.dart` — `AdminShell` class

---

## Route Detection Logic

### Detection Order in AppShell

```
isAdminShellPath(path)       → AdminShell
isInstitutionShellPath(path) → InstitutionShell
isMemberShellPath(path)      → MemberShell
(authed + public-ish path)   → MemberShell
default                      → PublicShell
```

Admin is checked first because no admin paths overlap with institution or member paths.

### isAdminShellPath

```
/admin
/admin/communications
```

### isInstitutionShellPath

```
/enter-institution
/institution/sign-in
/institution/create
/institution/dashboard
/institution/domains
/institution/profile
/institution/request-verification
/institution/announcements
/institution/correspondence
```

### isMemberShellPath

All authenticated member routes including `/home`, `/me/*`, `/compose`, `/conversations`, `/realtime/*`, `/me/correspondence/*`, and all institution paths (institution paths are a subset — the check falls through from institution detection first).

### MemberShell for authenticated users on public paths

When a user is authenticated and visits `/search`, `/posts/:id`, `/u/:handle`, or `/announcements/*`, the `MemberShell` renders instead of `PublicShell`. This is handled by `shouldUseMemberShellForAuthed()` in `lib/app/route_targets.dart`.

---

## Files Changed

| File | Change |
|------|--------|
| `lib/app/shell/admin_shell.dart` | **Created** — AdminShell widget with amber command-center design |
| `lib/app/shell/member_shell.dart` | **Updated** — InstitutionShell fully redesigned with teal palette and left-border nav; MemberShell Create button elevated to gradient action style |
| `lib/app/route_classification.dart` | **Updated** — Added `isAdminShellPath()`; removed `/admin` and `/admin/communications` from `isMemberShellPath()` |
| `lib/app/app_shell.dart` | **Updated** — Added AdminShell import and check at top of decision tree |
| `docs/AURA_MULTI_SHELL_ARCHITECTURE.md` | **Created** — This document |

---

## Visual Differentiation Summary

| Attribute           | Member Shell   | Institution Shell | Admin Shell     |
|---------------------|----------------|-------------------|-----------------|
| Accent color        | Indigo #5B6CFF | Teal #0D9488      | Amber #F59E0B   |
| Nav active style    | Rounded pill   | Left border + tint| Left border + tint |
| Header badge        | None           | "Workspace" (teal)| "ADMIN" (amber, glowing dot) |
| Header border       | Subtle white   | Subtle teal       | Subtle amber    |
| Side nav width      | 240px          | 224px             | 240px           |
| Side nav background | Navy gradient  | Deep teal-navy    | Near-black      |
| Section label       | None           | "INSTITUTION"     | "PLATFORM CONTROL" |
| Footer element      | None           | None              | "Elevated access" indicator |
| Create button       | Gradient FAB   | N/A               | N/A             |

---

## Expanding the Admin Shell

When new admin routes are added to the router:

1. Add the path(s) to `isAdminShellPath()` in `lib/app/route_classification.dart`
2. Add a `_NavItem` entry to `AdminShell._items` in `lib/app/shell/admin_shell.dart`
3. Update `_indexForPath()` in `AdminShell` to map the new path to its index

No changes to `AppShell` or `router.dart` are needed unless the route guard logic changes.

## Expanding the Institution Shell

When new institution routes are added:

1. Add path(s) to `isInstitutionShellPath()` if they should use the institution shell
2. Optionally add a `_NavItem` to `InstitutionShell._items` and update `_indexForPath()`

## Adding a Fourth Shell

If a new user role or product area requires a fourth shell:

1. Create `lib/app/shell/<name>_shell.dart`
2. Add a detection function in `route_classification.dart`
3. Add the check in `AppShell.build()` before the member shell check
4. Export from `app_shell.dart`
