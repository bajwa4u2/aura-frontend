# Admin Operator Hub — reconstruction record

**Closed 2026-08-31.** Client `a2290b0`, backend `d12d825`. Both pushed; the
backend deployed to production through the ordinary Railway path.

This is the record of what was rebuilt, what it replaced, what the work found,
and what is deliberately still open.

---

## 1. What existed before

The console was eighteen small applications sharing a sidebar.

| Finding | Evidence |
|---|---|
| Five admin routes had no navigation entry at all | `/admin/institutions/:id/members`, `/admin/institution-domains`, `/admin/policies`, `/admin/media-appeals`, `/admin/migrations` were reachable only by typing the URL |
| Fourteen destinations were shown to every operator | Navigation read no capability; a MODERATOR holding 4 permissions and an ANALYST holding 3 saw exactly what an OWNER holding 25 saw |
| Capability truth was fetched and thrown away | `AdminAccess.fromJson` read `role` and `permissions`; the server sends `roles` and `effectivePermissions`, so the permission list was **always empty** — very likely why nobody ever built gating on it |
| The mobile shell put 14 destinations in one `Row` of `Expanded` children | No scroll, no overflow, roughly 27px per target |
| Eighteen screens each built their own scaffold inside the shell | The shell owned no chrome |
| Seven queue authorities sat behind seven front doors | An operator's work was whatever screen they happened to open |

---

## 2. The reconstruction

**Frozen IA:** `NOW → WORK → SUBJECTS → INTEGRITY → PLATFORM → RECORD → DISCOVERY`

| Area | Answers | Requires |
|---|---|---|
| **NOW** | What needs attention, what is degraded, what changed | any capability |
| **WORK** | One list, every queue, oldest first, filtered to what you may act on | any queue read |
| **SUBJECTS** | A person or an institution, whole — without collapsing the authorities behind them | `USERS_READ` / `INSTITUTIONS_READ` |
| **INTEGRITY** | Conduct, appeals, feedback, support, and communication governance | `MODERATION_READ` / `SUPPORT_READ` / `PRODUCT_FEEDBACK_READ` |
| **PLATFORM** | Health, released clients, policy, flags, media retention | `SYSTEM_HEALTH_READ` / `SETTINGS_READ` / `ANALYTICS_READ` |
| **RECORD** | Who did what, under what authority, why, and what changed | `AUDIT_READ` |
| **DISCOVERY** | Whether the outside world can find what the estates published | `DISCOVERY_READ` |

### The migration register is empty

All seventeen routes migrated; every screen behind them deleted rather than
left unrouted. `test/admin/operator_conformance_test.dart` holds this: a new
`/admin` route that belongs to no area fails the build.

```
users, institutions, institutions/:id/members, grants, identity-review
                              → SUBJECTS and the subject pages
review-queue, institution-domains
                              → WORK, decided on the subject
moderation, media-appeals, feedback, support, communications
                              → INTEGRITY
settings, feature-flags, policies
                              → PLATFORM
audit-logs                    → RECORD
migrations                    → RETIRED
```

`/admin/migrations` was engineering evidence for a one-off sign-off and was
never an operator destination. **The convergence audit tables survive
untouched** — only the door is gone.

### Governed action ceremony

Every consequential act follows one shape:

```
INTENT → CONSEQUENCE PREVIEW → CONFIRM → ACTION → OUTCOME → RECORD
```

The preview is the part that was missing. An operator revoking a grant is
changing someone's standing and usually notifying them; they are told that
before they commit, not afterwards from the audit log. The sheet holds the
barrier during exactly one phase — while the action is in flight — because an
operator who dismisses mid-flight never learns whether the decision landed,
and a decision believed not to have landed gets taken twice.

---

## 3. Defects the work found

Each of these could never have worked. None was visible to a passing test.

1. **Every operator grant read as inactive.** `AdminGrant.fromJson` compared
   the wire's status against lowercase `'active'`; the server sends `'ACTIVE'`.
2. **Domain proof was invisible on every institution.** The section compared a
   domain *record's* id against an institution's id, so the filter was never
   true and it reported "no domain proof on record" for institutions that had
   some.
3. **Approving a domain was a guaranteed 400.** `approveDomain` posted an empty
   body to a DTO whose `action` is required and validated *before* the
   controller substitutes its own value.
4. **The audit record could not name its actor.** The client read `actorId`,
   which the endpoint never sends — it returns the Prisma row, whose column is
   `actorUserId`. A record with no actor email showed no actor at all. The
   record now names the person and shows the **reason**, the fourth question it
   exists to answer and the one nothing rendered.
5. **Member removal asked for a reason nothing keeps**, and offered to remove
   OWNERs the endpoint refuses outright (the platform-admin bypass was closed
   deliberately, because it let an institution be stranded).
6. **Aura's sitemap advertises 19 URLs and zero canonical share URLs** — see §4.
7. **The query redactor missed the commonest secret shape.** `sk_live_…` and
   `pk_test_…` survived, because the pattern's tail required an unbroken run of
   alphanumerics and a word boundary does not break on an underscore.
8. **Media retention had no scheduler.** The cleanup job was reference-safe and
   had a dry run from the day it was written; nothing ever ran it.

---

## 4. DISCOVERY — the finding

Verified against production on 2026-08-31 with
`scripts/discovery-providers-check.ts`:

```
SITEMAP advertises 19 URLs
  of which 0 are canonical /p/ share URLs

CRAWLER REACHABILITY
  https://auraplatform.org/p/u/aura   → reachable, real card
  https://auraplatform.org/p/org/aura → reachable, real card
```

Every article, profile, institution page and announcement Aura has published
is absent from the only list search engines are given — **while being
demonstrably reachable and serving real cards.** The objects are findable and
never advertised. That same 19-URL set is, line for line, the hand-kept static
list the web acquisition surface used, so one blind spot had been copied into
two places.

**Not fixed here, deliberately.** Generating a sitemap from the inventory would
be *control*, and the founder froze this area as observation. It is surfaced as
a finding for a decision, not acted on.

### What Discovery promises, and where each promise is enforced

| Promise | Enforced in |
|---|---|
| Observation ≠ control | No write path exists. `collect` writes only Aura's own tables |
| Raw evidence: 90 days | `expiresAt` stamped per row; deleted in `enforceRetention()` |
| Normalized: up to 24 months | `enforceRetention()`; the projection has no query column |
| Never joined to a member | No column, no code path |
| Emails, phones, cards, keys redacted | `redactQuery`, applied server-side |
| Nothing shown below 5 impressions | `queryIsDisplayable`; the withheld count is reported |
| `DISCOVERY_READ` ≠ `DISCOVERY_EVIDENCE_READ` | Separate permissions; queries sit behind the second |

No provider is load-bearing. Google Search Console is one adapter of six; four
report "no adapter is configured" today and Discovery works, which is the point.

---

## 5. Media retention

The founder ruling was explicit: *"Never expose a naked destructive 'Run
cleanup' button merely because an endpoint exists."*

So there is no such button. Retention runs nightly (`@Cron(EVERY_DAY_AT_3AM)`),
records each pass to `PlatformSetting['media.retention.lastRun']`, and PLATFORM
reports **the leftovers** — `failed` and `unresolvedKey`, the rows the job could
not resolve on its own. Everything else is the system doing its job quietly.

A manual pass exists, offered only when there is something a run would address,
and it runs a **dry run first** so the decision is made against a number rather
than a guess.

---

## 6. Verification

| Gate | Result |
|---|---|
| Client suite | 2122 passed, 1 skipped |
| Backend suite | 3966 passed, 321 suites |
| Route path compilation + HTTP route registration | pass — the gap that caused the 2026-08-20 crash loop |
| Migration replay from empty | all applied; both convergence audit tables survive |
| Windows desktop certification (`integration_test`) | 10/10 on the real client |
| Renders | 49 PNGs, every area at desktop/tablet/phone, in `test/admin/goldens/operator/` |

### What is NOT certified

- **Android and iOS** were not exercised. The Windows lane runs headlessly;
  Android needs an AVD and iOS needs macOS. Reported per-platform rather than
  generalised, per the cross-platform certification rule.
- **Production observation of the console itself** is owed. The backend is
  deployed and its routes answer; the operator surfaces have been judged from
  renders and from the Windows client, not from production with a real grant.

---

## 7. Anti-drift

| Gate | Holds |
|---|---|
| `test/admin/operator_conformance_test.dart` | Every `/admin` route belongs to an area; the register only lists routes that exist; the worklist's seven destinations are all declared; area order frozen |
| `c0` / `c1` / `c3` baselines | 25 entries retired with the screens that carried them, recorded rather than deleted |
| `bounded_field_family_test` | The console's one bounded field adopts `AuraBoundedEditor`; the retired screen's exception went with it |
| `modal_and_flow_exit_test` | Sheet census 19 → 21, each new member reclassified against §6 |
| `return_path_audit_gate_test` | Shell census names `operator_shell.dart`; it draws no back control because it wraps the shared `ReturnPathFrame` |

---

## 8. Open

- Android and iOS certification of the console.
- Founder observation of the live console with a real grant.
- The sitemap decision (§4) — a finding awaiting a ruling, not a task.
