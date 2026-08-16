# C2 — Verification & Trust Experience

**Date:** 2026-08-16 · Reconstruction of all verification/trust presentation onto the canonical layered authority. Built under the founder reconstruction doctrine: canonical product truth → runtime adoption → visible release-client experience → legacy retirement.

---

## 1. Consumer classification (measured, then classified)

Re-measured at task start: **82 `isVerified` sites / 26 files · 16 generic `'Verified'` literals · 0 `verifiedClasses` consumers.**

| Category | Sites | Finding |
|---|---|---|
| **A–C. Person verification (layered)** | `Profile.isVerified` + `author_profile_screen` badge | **DEAD GENERIC CLAIM PATH** — parsed `isVerified`/`verified`/`verificationStatus`, none of which any profile endpoint ever sent. The person badge could never truthfully fire |
| **D. Institution verification** | institution domain models, access provider, directory/detail/profile/wizard/live/composer/shell/rail/realtime/booking presentation | Legitimate canonical field (`Institution.isVerified`); the *presentation* was ad-hoc icon+`'Verified'` without subject or meaning |
| **E. Domain verification** | `institution_domains_screen`, dashboard `_domainTrust`, profile `Domain DNS` row | Subject explicit in context; truthful |
| **F/G. Email/phone** | `router.dart` (8 sites, gating), `me_screen`, `security_screen` | Channel verification; router use is non-presentational |
| **H. Official speech** | `realtime_room_screen._buildTrustLine` | **§11 VIOLATION FOUND**: `"Official session by $name"` was derived from `isVerified` — official speech claimed from verification. Corrected |
| **I. Generic/ambiguous** | the 16 `'Verified'` literals | Classified individually (§5 below) |
| **J. Non-presentational** | monetization models, meeting domain snapshots, access provider plumbing | Boolean legitimately carries the institution fact; no user-facing claim |

## 2. The canonical frontend trust authority (§13)

Two layers, deliberately separated:

- **`lib/core/trust/verification.dart`** — RAW DOMAIN AUTHORITY. Typed `PersonVerificationClass` (frozen taxonomy: IDENTITY / INSTITUTION_AFFILIATION / ROLE_OR_CREDENTIAL) + `PersonVerification` (a SET, never a boolean). Unknown wire classes are **dropped, never guessed at**; malformed payloads are absence, not error.
- **`lib/core/trust/trust_marks.dart`** — CONTEXTUAL PRESENTATION. Typed `TrustFact` enum (each fact carries canonical `label` + one-sentence `meaning`), `TrustMark` (compact/standard), `PersonVerificationMarks` (one mark per class, nothing when empty), `InstitutionVerifiedMark`/`InstitutionVerifiedIcon` (subject-explicit semantics + tooltip always; visible compact label only adjacent to the institution name — the §15 permitted case).

No giant TrustBadge with boolean flags; no flattened ontology. Consumers receive typed facts, never parse wire shapes.

### Canonical wording

| Fact | Label | Boundary carried in meaning |
|---|---|---|
| IDENTITY | Identity verified | — |
| INSTITUTION_AFFILIATION | Affiliation verified | affiliation ≠ role authority |
| ROLE_OR_CREDENTIAL | **Role attested** (founder-ruled 2026-08-16) | "an Aura record, not a portable credential" (§12); public wire has no subtype, so this narrowest wording covers every record of the class |
| Institution | Verified institution | "not an endorsement" (§10, public-first) |
| Domain | Domain verified | — |
| Email/Phone | Email verified / Phone verified | never identity verification |

Labels are literal restatements of the frozen governed classes — nothing invented. Pinned by test: no `TrustFact` label is ever bare "Verified".

## 3. The wire gap and its closure (backend, evidence-driven)

`projectPersonIdentity` had carried `verification.classes` on every **embedded** person since D3 — but the person **profile** endpoints (`publicSelect`) never emitted it. The one surface where a person's trust presentation matters most had no verification data at all. Closed: `publicSelect` + `toPublicProfile` now emit `verification: { classes }` (class list only, no provenance, raw column stripped). REVOKED/EXPIRED cannot present positively **by construction** — the authority removes the class from the denormalized set, and the public wire carries only that set.

**Second closure:** the Person Verification Authority had **zero callers** — no controller exposed grant/revoke/history, so no record could ever exist. Now exposed under the existing `VERIFICATION_READ`/`VERIFICATION_WRITE` admin permission family (`GET/POST /admin/users/:id/verification[/grant|/revoke]`), with audit events, as thin attributed delegations — every governed rule stays in the authority.

## 4. Runtime adoption (what actually changed)

**Person:** `Profile` model consumes `verification.classes` (typed); the dead flattened keys are deleted and pinned dead by test. `author_profile_screen` renders one `TrustMark` per active class — "Identity verified", "Affiliation verified", "Role attested" — never "Verified person", nothing when nothing is verified.

**Institution (13 presentation sites migrated):** member_shell ×2, rail_modules, realtime_room, live_now_card, global_live_banner, institution_live_rooms, post_composer (`(Verified)` retired), wizard, institution_detail ×2, public_booking, booking_confirm, billing. All now canonical marks with semantics + tooltip. Section headings in the public directory and sector screens became "Verified institutions".

**§11 correction:** realtime trust line no longer claims "Official session" from `isVerified`; verification presents as itself, official speech remains authority-derived.

**Contact channels:** me_screen label → "Email verified".

**Admin (§19):** `admin_users_screen` gains "Verification…" per user → `AdminPersonVerificationSheet`: active classes with revoke-with-reason, grant dialog (class/reason/issuer; institution ID required for affiliation — authority-enforced), and the **full governed history with REVOKED/EXPIRED as first-class states**. `evidenceRef` stays server-side (least disclosure).

## 5. Remaining `'Verified'` literals — 16 → 8, each classified

| Site | Classification |
|---|---|
| `trust_marks.dart` compact institution label | canonical: §15 adjacent-to-name case, semantics always subject-explicit |
| `admin_institutions_screen` tab | admin filter over institutions — subject unambiguous |
| `institution_dashboard_screen` `_domainTrust` value | domain verification; helper text names the subject |
| `institution_detail_screen` `Verification` row value | key-value row, label states subject |
| `institution_profile_screen` ×2 (`Institution` / `Domain DNS` rows) | key-value rows, labels state subject |
| `security_screen` email status value | row labeled Email — channel verification |
| `public_booking_screen` comment | not user-facing |

No user-facing generic "Verified" remains whose subject is ambiguous.

## 6. `isVerified` — 82 → 80 sites, every remainder classified

- **Legitimate canonical Institution field** (domain models, projections, gating conditions feeding canonical marks): the boolean IS the canonical institution verification wire fact (mirrors backend `Institution.isVerified`). Not debt.
- **Non-presentational** (`router.dart` email gating — 8 sites; monetization/meeting model fields): not trust claims.
- **Removed**: `Profile.isVerified` (person-side flattening) — deleted with its dead parse keys; `_MiniBadge` dead widget deleted.
- **Active debt**: none known. The two-site reduction is small because the boolean legitimately remains the institution wire contract (§16: the objective was never textual zero).

## 7. Monetization finding — RESOLVED 2026-08-16 (founder ruling: VERIFICATION IS NOT PURCHASABLE)

The plan taxonomy **sells verification**: `InstitutionPlan.VERIFIED` ("Verification badge and verified-only features", `capabilities.isVerified: true` on paid plans), a `TRUSTED` plan label, and `deriveVerifiedTrustState` couples plan upgrades with the `Institution.isVerified` row flag (verification-request approval upgrades FREE→VERIFIED plan). This is **deeper than presentation drift** — the backend product model treats verification as a purchasable capability, and the `TRUSTED` plan name collides with the public-first rejection of inherent "trusted institutions". Founder adjudicated; the coupling is REMOVED at every layer (see `C2 — Monetization × Verification Decoupling` in DECISIONS.md): `applyPlanChange` no longer writes `isVerified`, `PlanCapabilities.isVerified` deleted (both repos), `deriveVerifiedTrustState` deleted (approval writes verification fields only), TRUSTED retired from the offered taxonomy (legacy rows resolve without trust semantics), plan copy truthful, billing entitlements card no longer presents verification at all. Deterministic-provenance reconciliation SQL: `aura-backend/prisma/manual/2026-08-16-institution-isverified-reconciliation.sql` (manual, founder-observed, not in deploy path). Remaining founder decisions: the interim-named commercial tier's public name; TRUSTED rows' remapping target.

## 8. Meetings boundary (§21)

Bounded presentation-only correction: the two booking screens' generic chips became canonical marks; dead `_MiniBadge` removed. No Meetings architecture/behavior touched. Targeted Meetings regression: **20/20 green**.

## 9. Legacy retirement (§26)

Removed: person flattened parse path (`isVerified`/`verified`/`verificationStatus` in `Profile`), the person generic badge, `(Verified)` composer literal, `_MiniBadge`, 11 ad-hoc icon+text constructions. Remaining transitional: `AuraVerifiedInstitutionBadge` (shared/identity, feed identity-context system) — already subject-explicit ("Verified institution"), retirement destination = canonical trust layer when the feed identity-badge system is next reconstructed (C4-adjacent); consumers: 3 public screens.

## 10. Existing users (§18)

Automatic. Person marks appear as soon as a governed record exists (no re-registration, no reverification, no user action); all `verifiedClasses` are empty today **because no grant surface existed** — the admin exposure is what makes the authority operable. Institution marks upgrade in place from the same wire fields already served. No data migration required; nothing downgraded; nothing invented.


---

## 11. Commercial-matrix forensic (2026-08-16, tier-identity adjudication prep)

**Enforcement truth, traced to runtime authority (not copy):**

| Entitlement | FREE | middle (persisted `VERIFIED`) | PRO | legacy TRUSTED | Classification |
|---|---|---|---|---|---|
| Member capacity | env `AURA_PLAN_FREE_MEMBER_LIMIT` (null=unlimited) | env `AURA_PLAN_VERIFIED_MEMBER_LIMIT` | env `AURA_PLAN_PRO_MEMBER_LIMIT` | unlimited | **CAPACITY** — enforced (P0-4 member-activation gate) |
| Official institutional publishing | blocked in `enforce` mode | blocked in `enforce` mode | institution-level gate passes | passes | **CAPABILITY** — enforced (`requireOfficialVoice`, enforce mode only; C1 per-member authority checked first and separately) |
| AI editor | credit-metered | credit-metered | credit-metered | credit-metered | **PRESENTATION ONLY as tier feature** — `hasAiEditor` has zero runtime consumers |
| Translation | credit-metered | credit-metered | credit-metered | credit-metered | **PRESENTATION ONLY as tier feature** — zero consumers |
| Realtime | credit-metered/min | credit-metered/min | credit-metered/min | credit-metered/min | **PRESENTATION ONLY as tier feature** — zero consumers |
| Verification / trust | — | — | — | — | REMOVED (frozen ruling) |

`requirePlan` has **zero callers**. Plans do **not** grant credits — credit packs are purchased separately, and credit-metered features work on any tier with balance. Monetization mode defaults `disabled` (env-driven); `requireOfficialVoice`/credit gates no-op outside `enforce`(/`soft_enforce` for costs).

**Middle-tier honest value after decoupling: member capacity only, with env-configured (not code-fixed) numbers.** Commercially weak — reported to founder, no benefits invented. Descriptions corrected to enforcement truth (backend `d940477`). Dead capability booleans (`hasAiEditor`/`hasTranslation`/`hasRealtime`) remain on the config wire, flagged for retirement with the enum migration.

**TRUSTED evidence:** unreachable at runtime — not offered, no product code, checkout resolves only `PLAN_VERIFIED`/`PLAN_PRO`, no admin path writes plans. Differences from PRO: unlimited members; otherwise identical capability map. Deletion dependencies: prisma enum value, `PLAN_RANK` entry, `legacyPlans()` entry, any persisted Institution/InstitutionSubscription rows (tallied by reconciliation SQL §1b).

**VERIFIED enum migration shape (executes after founder names the tier):** (1) additive enum value; (2) deploy readers tolerant of both; (3) writer cutover (checkout mapping, `resolvePlanByProductCode`); (4) row migration `VERIFIED→<new>` (Institution + InstitutionSubscription), validation counts; (5) frontend label/model sync (labels come from config wire — automatic); (6) drop legacy value + `PLAN_REQUIRED_VERIFIED` error code + dead capability booleans. Stripe: `AURA_PLAN_VERIFIED` product code and `STRIPE_PRICE_AURA_VERIFIED` env key are **internal identifiers customers never see** — no forced migration; optional alias at step 3.

**Customer-facing plan surfaces (complete inventory):** `institution_billing_screen.dart` is the only one — current-plan card, plans list (label/description/member limit from config wire), credit packs, feature costs, mobile web-only notice. Admin screens do not present plan. No onboarding/pricing surface elsewhere. All copy now truthful.


### §11 addendum — taxonomy closeout (2026-08-16)

Founder ruling executed: **FREE + PRO frozen**; middle tier retired (backend `2217480`). Offered taxonomy pinned by test to exactly [FREE, PRO]; legacy VERIFIED/TRUSTED resolve behavior-preserving with neutral labels; new checkout of `AURA_PLAN_VERIFIED` refused (`PLAN_RETIRED`) while webhook recognition of existing subscriptions is unchanged; `requirePlan`/`PLAN_RANK`/`PLAN_REQUIRED_VERIFIED` and the dead capability booleans deleted (both repos); billing current-plan card now displays the config-wire label (`displayName`), so a legacy row shows a neutral “Legacy plan”, never “VERIFIED”. Final Free/Pro entitlement boundary deliberately NOT decided — see the FUTURE COMMERCIALIZATION GOVERNANCE MARKER in DECISIONS.md.
