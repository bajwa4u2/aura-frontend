# C0 — G5 Ownership Matrix

**Date:** 2026-08-15 · **Status:** ✅ **FOUNDER APPROVED.** Every remaining G5 site assigned. **Zero unassigned. No "later" bucket. No "frontend cleanup" bucket.**

G5 = a surface constructing `AuraLoadingState` / `AuraEmptyState` / `AuraErrorState` directly instead of declaring a state through the Product State Presentation Authority.

---

## Founder-frozen ownership rule (recorded)

| Layer | Owns |
|---|---|
| **C0** | the Product State Presentation authority · semantic classification · canonical primitives · anti-drift gate · measured baseline · ratchet · exception rules |
| **The owning reconstruction chapter** | migration/removal of remaining direct constructions inside surfaces that chapter reconstructs |

This prevents C0 from polishing implementations already approved for demolition and rebuild.

---

## Summary

| Owner | Files | Sites |
|---|---|---|
| **C1** — Acting Context & Capability | ~~14~~ **1** | ~~42~~ **4** |
| **C2** — Identity / Presence / Profile | 8 | 21 |
| **C3** — Navigation / IA | 20 | 44 |
| **C4** — Attention | 11 | 26 |
| **C5** — Composition / Intake / Publication | 6 | 16 |
| **C6** — Realtime Presentation Convergence | **0** | **0** |
| **C7** — Threads / Spaces / Correspondence | 11 | 26 |
| **C8** — Institution Room | 1 | 3 |
| **C9** — Cross-Platform | 1 | 3 |
| **C10** — Live | 0 | 0 |
| **PRESERVE / legitimate exception** | 0 | 0 |
| **PD-1** — Platform Administration *(new checkpoint)* | 11 | 34 |
| **PD-2** — Authentication & Account Entry *(new checkpoint)* | 2 | 3 |
| **TOTAL** | **72** | **181** |

### Meetings — counted separately, as instructed

**Meetings holds ZERO G5 sites.** Measured, not assumed: no file under `lib/features/meetings/` constructs these primitives at all.

The 14 protected Meetings sites the founder referred to are **G4** (full-surface spinner), not G5, plus 16 **G3** (`toLocal()`) sites. Those remain frozen in the baseline and are **not** migrated to reduce a count. Where a Meetings construction is genuinely legitimate and should stay local, C6 classifies it as such rather than forcing convergence.

| Rule | Meetings sites | Disposition |
|---|---|---|
| G3 `toLocal()` | 16 of 47 | C6 controlled convergence boundary, or legitimate-local |
| G4 full-surface spinner | 14 of 26 | C6 controlled convergence boundary, or legitimate-local |
| **G5 direct construction** | **0 of 181** | nothing to own |

---

> ### CORRECTED BY C1, 2026-08-15 - historical assignment preserved
>
> C1 re-verified all 42 sites it was assigned and **disproved 38 of them**.
> The `J`-basis premise here was that platform-admin screens are "the densest
> site of role comparison"; measurement found **zero** institutional authority
> code in all 11 admin files and both auth files.
>
> Those 38 sites are **withdrawn from C1** and dispositioned to two named
> product checkpoints - see `C1_G5_DISPOSITION_MATRIX.md`. The original
> assignment is left visible above, struck through, because the correction is
> part of the record.
>
> **This is the R/J rule working as intended:** a `J` assignment is a reasoned
> starting point the owning chapter must verify, not frozen product truth.

## Basis discipline — read this before trusting the table

Each row carries a basis code, because most of this matrix is **not** a direct quotation of the approved roadmap:

| Basis | Meaning | Sites |
|---|---|---|
| **R** | Direct read of that chapter's own DEMOLISH / REBUILD text | **74** |
| **J** | **My judgment extension.** The roadmap does not name this surface; I assigned it from the chapter's stated purpose | **107** |

> **The majority of this matrix (107 of 181 sites) is judgment, not existing rule.**
>
> The cause is a real finding, recorded below: **the approved roadmap C1–C11 never names an owning chapter for platform administration, institution administration, public directory, search/saves/updates, or authentication surfaces.** Those surfaces exist and ship. Assigning them required extending each chapter's purpose beyond its written demolition list.
>
> Every **J** row is a founder-correctable assignment. The **R** rows are not opinions.

### Founder ruling on this distinction (2026-08-15) — binding on later chapters

> **A `J` classification is not automatically a frozen product truth.**
>
> When the owning chapter reaches the site, it must **verify the classification against actual reconstruction scope before migrating**. Sites must not be silently moved between chapters — the register is updated when ownership changes.

The matrix is accepted as C0 continuity evidence, and zero-unassigned is a standing requirement.

### Evidence supporting the largest J group

C3 receives 20 files largely on the basis of DR4 — "40 mirrored `/institution/:institutionId/…` routes". That figure was verified directly: `lib/router.dart` contains **exactly 40** `path: '/institution/:institutionId…'` declarations. The number in the roadmap is real, not approximate.

---

## Why C0 performed no further migrations

Founder clause: *C0 may migrate direct constructions that clearly belong to C0 itself, are not inside surfaces already scheduled for reconstruction, and can consume the authority without changing product interaction or layout.*

All 72 files were checked against that test.

| Candidate | Outcome |
|---|---|
| `features/communications/.../communication_empty_error_states.dart` | **Migrated during C0.** A shared state layer, not a screen — `CommLoadingState` / `CommErrorState` now delegate to `AuraProductState`. Rendering unchanged. |
| `shared/media/profile_media_editor.dart` | The only other non-screen candidate. **Not migrated** — it is one of the eleven upload pipelines DR3 demolishes in C5. |
| The other 70 files | All feature screens owned by a reconstruction chapter. Migrating them would be churning demolition territory for count reduction. |

**Result: one safe C0-owned migration existed, and it was done. No easy C0-owned bypass was retained.**

---

## Full assignment

### C1 — 14 files / 42 sites

| Sites | File | Basis | Why |
|---|---|---|---|
| 4 | `features/admin/presentation/admin_audit_logs_screen.dart` | J | platform administration exists to express capability projection; C1 demolishes shadow governance |
| 3 | `features/admin/presentation/admin_feature_flags_screen.dart` | J | platform administration exists to express capability projection; C1 demolishes shadow governance |
| 3 | `features/admin/presentation/admin_grants_screen.dart` | J | platform administration exists to express capability projection; C1 demolishes shadow governance |
| 3 | `features/admin/presentation/admin_institution_domains_screen.dart` | J | platform administration exists to express capability projection; C1 demolishes shadow governance |
| 3 | `features/admin/presentation/admin_institution_members_screen.dart` | J | platform administration exists to express capability projection; C1 demolishes shadow governance |
| 6 | `features/admin/presentation/admin_institutions_screen.dart` | J | platform administration exists to express capability projection; C1 demolishes shadow governance |
| 2 | `features/admin/presentation/admin_moderation_screen.dart` | J | platform administration exists to express capability projection; C1 demolishes shadow governance |
| 2 | `features/admin/presentation/admin_policies_screen.dart` | J | platform administration exists to express capability projection; C1 demolishes shadow governance |
| 3 | `features/admin/presentation/admin_review_queue_screen.dart` | J | platform administration exists to express capability projection; C1 demolishes shadow governance |
| 2 | `features/admin/presentation/admin_settings_screen.dart` | J | platform administration exists to express capability projection; C1 demolishes shadow governance |
| 4 | `features/admin/presentation/admin_users_screen.dart` | J | platform administration exists to express capability projection; C1 demolishes shadow governance |
| 2 | `features/auth/presentation/auth_screen.dart` | J | C1 PRESERVES auth flows but owns acting-context entry |
| 1 | `features/auth/presentation/register_screen.dart` | J | C1 PRESERVES auth flows but owns acting-context entry |
| 4 | `features/institutions/presentation/admin_workspace_screen.dart` | J | institution admin workspace; 2 role/canX derivations measured |

### C2 — 8 files / 21 sites

| Sites | File | Basis | Why |
|---|---|---|---|
| 3 | `features/institutions/profile/institution_edit_profile_screen.dart` | R | DR5 three profile implementations |
| 4 | `features/institutions/profile/institution_profile_screen.dart` | R | DR5 three profile implementations |
| 1 | `features/me/presentation/edit_profile_screen.dart` | R | DR5 parallel edit screens |
| 2 | `features/me/presentation/me_screen.dart` | R | DR5 three profile implementations |
| 2 | `features/profile/presentation/author_profile_screen.dart` | R | DR5 three profile implementations |
| 3 | `features/profile/presentation/follow_requests_screen.dart` | R | DR5 three profile implementations |
| 3 | `features/profile/presentation/followers_screen.dart` | R | DR5 three profile implementations |
| 3 | `features/profile/presentation/following_screen.dart` | R | DR5 three profile implementations |

### C3 — 20 files / 44 sites

| Sites | File | Basis | Why |
|---|---|---|---|
| 2 | `features/home/presentation/member_home_screen.dart` | J | primary navigation destinations (C3 founder checkpoint) |
| 4 | `features/home/presentation/public_home_screen.dart` | J | primary navigation destinations (C3 founder checkpoint) |
| 1 | `features/institutions/domain/institution_domains_screen.dart` | J | DR4 40 mirrored /institution/:institutionId routes (exactly 40 confirmed in router.dart) |
| 2 | `features/institutions/engagement/engagement_detail_screen.dart` | J | DR4 40 mirrored /institution/:institutionId routes (exactly 40 confirmed in router.dart) |
| 2 | `features/institutions/engagement/engagement_list_screen.dart` | J | DR4 40 mirrored /institution/:institutionId routes (exactly 40 confirmed in router.dart) |
| 2 | `features/institutions/explore/institution_explore_screen.dart` | J | DR4 40 mirrored /institution/:institutionId routes (exactly 40 confirmed in router.dart) |
| 2 | `features/institutions/participation/participation_screen.dart` | J | DR4 40 mirrored /institution/:institutionId routes (exactly 40 confirmed in router.dart) |
| 2 | `features/institutions/presentation/institution_dashboard_screen.dart` | J | DR4 40 mirrored /institution/:institutionId routes (exactly 40 confirmed in router.dart) |
| 2 | `features/institutions/presentation/institution_detail_screen.dart` | J | DR4 40 mirrored /institution/:institutionId routes (exactly 40 confirmed in router.dart) |
| 2 | `features/institutions/presentation/institution_invites_screen.dart` | J | DR4 40 mirrored /institution/:institutionId routes (exactly 40 confirmed in router.dart) |
| 2 | `features/institutions/presentation/institution_join_requests_screen.dart` | J | DR4 40 mirrored /institution/:institutionId routes (exactly 40 confirmed in router.dart) |
| 2 | `features/institutions/presentation/institution_members_screen.dart` | J | DR4 40 mirrored /institution/:institutionId routes (exactly 40 confirmed in router.dart) |
| 1 | `features/institutions/presentation/institution_page.dart` | J | DR4 40 mirrored /institution/:institutionId routes (exactly 40 confirmed in router.dart) |
| 1 | `features/institutions/units/institution_units_screen.dart` | J | DR4 40 mirrored /institution/:institutionId routes (exactly 40 confirmed in router.dart) |
| 3 | `features/public/presentation/institution_sector_screen.dart` | J | public discovery IA; institution directory surfaces |
| 3 | `features/public/presentation/public_institution_units_screen.dart` | J | public discovery IA; institution directory surfaces |
| 3 | `features/public/presentation/public_institutions_directory_screen.dart` | J | public discovery IA; institution directory surfaces |
| 2 | `features/public/presentation/public_unit_detail_screen.dart` | J | public discovery IA; institution directory surfaces |
| 3 | `features/saves/presentation/saved_screen.dart` | J | navigation destination |
| 3 | `features/search/presentation/search_screen.dart` | J | command-find / discovery IA named in C3 GLOBAL RESEARCH |

### C4 — 11 files / 26 sites

| Sites | File | Basis | Why |
|---|---|---|---|
| 1 | `features/activity/presentation/activity_screen.dart` | R | DR1 activity |
| 1 | `features/communications/presentation/widgets/admin_ai_draft_panel.dart` | R | DR1 communications centre |
| 1 | `features/communications/presentation/widgets/admin_campaign_workflow.dart` | R | DR1 communications centre |
| 1 | `features/communications/presentation/widgets/admin_newsletter_lab.dart` | R | DR1 communications centre |
| 2 | `features/communications/presentation/widgets/digest_preferences_panel.dart` | R | DR1 communications centre |
| 2 | `features/conversations/presentation/conversations_screen.dart` | R | DR1 RETIRED in C4 (FD-12) |
| 4 | `features/correspondence/presentation/correspondence_hub_screen.dart` | R | DR1 correspondence hub |
| 4 | `features/direct_threads/presentation/inbox_screen.dart` | R | DR1 direct inbox |
| 2 | `features/institutions/activity/institution_activity_screen.dart` | J | institution attention surface; DR1 names "activity" without qualifying personal vs institution |
| 5 | `features/messages/presentation/messages_hub_screen.dart` | R | DR1 messages hub |
| 3 | `features/notifications/presentation/notifications_screen.dart` | R | DR1 notifications |

### C5 — 6 files / 16 sites

| Sites | File | Basis | Why |
|---|---|---|---|
| 1 | `features/announcements/presentation/announcement_detail_screen.dart` | J | C5 EXTENDED SCOPE: institutional approval workflow language |
| 6 | `features/announcements/presentation/announcements_screen.dart` | J | C5 EXTENDED SCOPE: institutional approval workflow language |
| 2 | `features/institutions/announcements/institution_announcements_screen.dart` | J | C5 EXTENDED SCOPE: institutional approval workflow language |
| 1 | `features/institutions/posts/institution_post_composer_screen.dart` | R | DR3 six composers |
| 4 | `features/institutions/posts/institution_post_detail_screen.dart` | J | C5 EXTENDED SCOPE: E_OFFICIAL designation representation |
| 2 | `shared/media/profile_media_editor.dart` | R | DR3 eleven upload pipelines |

### C7 — 11 files / 26 sites

| Sites | File | Basis | Why |
|---|---|---|---|
| 3 | `features/correspondence/presentation/archived_spaces_screen.dart` | R | DR three thread_screen implementations / spaces |
| 3 | `features/correspondence/presentation/archived_threads_screen.dart` | R | DR three thread_screen implementations / spaces |
| 1 | `features/correspondence/presentation/space_screen.dart` | R | DR three thread_screen implementations / spaces |
| 1 | `features/correspondence/presentation/thread_screen.dart` | R | DR three thread_screen implementations / spaces |
| 3 | `features/direct_threads/presentation/direct_intent_screen.dart` | R | DR duplicated conversation mechanics |
| 4 | `features/direct_threads/presentation/direct_thread_screen.dart` | R | DR duplicated conversation mechanics |
| 3 | `features/institutions/correspondence/institution_correspondence_screen.dart` | R | FD-12 §4 InstitutionCorrespondenceScreen disposition |
| 2 | `features/institutions/messaging/institution_messaging_screen.dart` | R | DR four institution messaging entry points |
| 2 | `features/institutions/presentation/institution_spaces_screen.dart` | J | C7 owns Spaces |
| 1 | `features/public/presentation/space_detail_screen.dart` | J | Space surface; C7 owns Threads/Spaces |
| 3 | `features/public/presentation/thread_screen.dart` | R | DR three thread_screen implementations |

### C8 — 1 files / 3 sites

| Sites | File | Basis | Why |
|---|---|---|---|
| 3 | `features/institutions/live_rooms/institution_live_rooms_screen.dart` | R | DR2 institution_live_rooms_screen |

### C9 — 1 files / 3 sites

| Sites | File | Basis | Why |
|---|---|---|---|
| 3 | `features/updates/presentation/updates_screen.dart` | J | application update/release gate is a cross-platform obligation |
