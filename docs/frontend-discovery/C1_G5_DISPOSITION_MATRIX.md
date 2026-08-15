# C1 — Disposition of the 38 G5 sites withdrawn from C1

**Date:** 2026-08-15 · **Founder ruling:** the C0 `J`-basis assignments are **WITHDRAWN** where C1 measurement disproved them. Not forced back into C1, not silently redistributed. **Zero sites disappear from traceability.**

---

## What C1 measured

C0 assigned 14 files / 42 sites to C1 on `J` (reasoned) basis, premised on admin screens being "the densest site of role comparison". Measured against the actual code:

| File group | `isOwner`/`isAdmin` | capability tokens | `institutionIdentityProvider` | Verdict |
|---|---|---|---|---|
| `admin/presentation/*` (11 files) | **0** | **0** | **0** | premise false |
| `auth/presentation/*` (2 files) | **0** | **0** | **0** | premise false |
| `institutions/presentation/admin_workspace_screen.dart` | 1 | yes | yes | **confirmed C1** |

The admin screens are governed by `AppAdminAccess` — a **binary platform-admin boolean**, a completely separate authority system from institutional capability. C1 owns acting context and capability projection. These screens do neither.

---

## Two named PRODUCT DISPOSITION CHECKPOINTS

No approved chapter C0–C10 genuinely owns these concerns, so per the ruling they receive **named checkpoints before C11** rather than an invented architectural home.

### ⚑ PD-1 — PLATFORM ADMINISTRATION
**11 files · 34 sites**

| Surface | Actual product concern | Basis | Migration obligation |
|---|---|---|---|
| `admin_audit_logs_screen.dart` (4) | platform audit record | measured: zero institutional authority | G5 → `AuraProductState` |
| `admin_institutions_screen.dart` (6) | platform institution administration | same | G5 → `AuraProductState` |
| `admin_users_screen.dart` (4) | platform user administration | same | G5 → `AuraProductState` |
| `admin_feature_flags_screen.dart` (3) | platform configuration | same | G5 → `AuraProductState` |
| `admin_grants_screen.dart` (3) | platform grant administration | same | G5 → `AuraProductState` |
| `admin_institution_domains_screen.dart` (3) | platform domain verification | same | G5 → `AuraProductState` |
| `admin_institution_members_screen.dart` (3) | platform view of institution members | same | G5 → `AuraProductState` |
| `admin_review_queue_screen.dart` (3) | platform review queue | same | G5 → `AuraProductState` |
| `admin_moderation_screen.dart` (2) | platform moderation | same | G5 → `AuraProductState` |
| `admin_policies_screen.dart` (2) | platform policy | same | G5 → `AuraProductState` |
| `admin_settings_screen.dart` (2) | platform settings | same | G5 → `AuraProductState` |

**Why a checkpoint and not a chapter:** platform administration is a real, shipped product surface that the approved roadmap never names. It also carries an unresolved authority question of its own — **finding F6: the backend exposes 14+ granular `AdminPermission` values and the client collapses them to one boolean**, so every admin screen shows every admin control. Assigning these files to a chapter would bury that question inside a G5 cleanup. It needs a product decision first.

**Checkpoint must decide:** does platform administration get its own reconstruction chapter, fold into an existing one, or remain preserved-as-is? And is the granular permission model projected, or is the boolean deliberate?

### ⚑ PD-2 — AUTHENTICATION & ACCOUNT ENTRY
**2 files · 3 sites**

| Surface | Actual product concern | Basis | Migration obligation |
|---|---|---|---|
| `auth_screen.dart` (2) | sign-in error presentation | measured: zero acting-context code | G5 → `AuraProductState` |
| `register_screen.dart` (1) | registration error presentation | same | G5 → `AuraProductState` |

**Why not C1 or C2.** C1's own roadmap entry says it **PRESERVES** existing auth flows — preserving is not reconstructing. And C2 cannot claim it either: the frozen Aura Identity directive states *"Aura Identity is **not** Authentication, Login, User Accounts, or Member Profiles — those are implementation mechanisms."* Canon explicitly separates identity from authentication.

**Checkpoint must decide:** whether account entry is reconstructed at all, and if so by whom.

---

## Confirmed retained by C1

| Surface | Sites | Basis |
|---|---|---|
| `institutions/presentation/admin_workspace_screen.dart` | 4 | Institutional workspace with genuine capability-gated surfaces and a measured role-derived authority use. **`R` basis now, not `J`.** |

---

## Updated G5 ledger

| Owner | Before (C0) | After (C1 re-verification) |
|---|---|---|
| C1 | 42 | **4** |
| **PD-1 Platform Administration** | — | **34** |
| **PD-2 Authentication & Account Entry** | — | **3** |
| C2 | 21 | 21 |
| C3 | 44 | 44 |
| C4 | 26 | 26 |
| C5 | 16 | 16 |
| C6 | 0 | 0 |
| C7 | 26 | 26 |
| C8 | 3 | 3 |
| C9 | 3 | 3 |
| **Total** | **181** | **181** |

**Nothing lost, nothing invented.** The two checkpoints are named obligations before C11, not chapters.
