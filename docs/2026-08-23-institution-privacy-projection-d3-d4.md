# D3 / D4 — engagement and activity privacy projection

**Release Client reconstruction record. 2026-08-23.** Continues
`2026-08-23-institutional-authority-doctrine-and-matrix.md`.

---

## 0. Corrections to earlier measurements — carried, not quietly dropped

The founder required that contrary evidence revise the record rather than leave
an inflated drift narrative standing. Three findings are **withdrawn**:

| Earlier claim | Corrected |
|---|---|
| `institution_live_rooms_screen` has no client gate | **False.** It gates on `CapabilityProjection` / `ConsequentialAct.startLive`, commented "never a role label". |
| Announcements gates on role labels (5 role / 3 capability) | **False.** `_isAdmin` read `canManageAnnouncements`; `_canCompose` composed `canManageAnnouncements ‖ canRepresent`. Management and representation were already distinguished correctly. The defect was the **name**. |
| `isInstitutionAdminCheck` (server) is role drift | **False.** It is a `MANAGE_SPACES` capability check. The name overstated the drift. |

**Cause of the error:** the drift census matched `can*` / `.can(` only, so it
could not see `CapabilityProjection` adoption (~6 files) and counted
role-shaped *names* as role-shaped *authority*. The client's
under-consumption is real — 10 of 16 navigation entries had no authority
predicate, since fixed — but it is **less severe than "139 role checks vs 19
capability checks" implied**, and that figure should not be requoted.

---

## 1. The frozen result this work implements

```
NORMAL EXPERIENCE
standing + effective capabilities + audience/data policy
  → destination projection
  → screen/data projection
  → action/control projection

EXCEPTIONAL ENTRY
direct URL / stale link / notification / refresh / revoked authority
  → canonical authorization
  → truthful standing/access surface
```

Denial is defense in depth. It is not Aura's permissions UX.

---

## 2. Activity — what was already right

**Institution Activity was already a contextual projection**, not one global
feed. Every `InstitutionActivityEvent` carries a `visibility`
(`PUBLIC` / `MEMBER` / `ADMIN`) and the service filters by viewer. Production
confirms the classification is real and used:

| Visibility | Kinds present in production |
|---|---|
| MEMBER | `MEETING_STARTED` (36), `POST_PUBLISHED` (14), `MEETING_ENDED` (11), `ROLE_CHANGED` (8), `MEMBER_JOINED` (4), `POST_REPLY` (4) |
| ADMIN | `INVITE_SENT` (6), `POST_CREATED` (5), `POST_ARCHIVED` (4), `CAPABILITY_GRANTED` (3), `INVITE_REVOKED` (2) |

`ROLE_CHANGED` and `MEMBER_JOINED` sitting at MEMBER is consistent with the
canonical doctrine *"visibility follows responsibility"* — members may see who
holds responsibility. It is not overexposure.

### What was wrong: the tier was chosen by RANK

`allowedVisibilityFor` used `rankFor(role) >= rankFor('ADMIN')`. Consequences,
both directions:

* **Underexposure** — a member holding a delegated administrative capability
  could *act* but could not see the operational record of their own
  responsibility.
* **Overexposure by rank** — an ADMIN received the operational tier by rank
  alone, independent of any capability.

Now the tier follows **operational authority**: holding any administrative
capability. Named once as `OPERATIONAL_CAPABILITIES` /
`holdsOperationalAuthority`, and consumed by both the Activity tier and the
workspace Overview so the two cannot drift apart. Representation and hosting
are deliberately **not** operational — a Representative or Host holds real
authority, and it must not become operational visibility.

### A second implementation of role logic, removed

`InstitutionActivityController` resolved the viewer's role itself, **with the
opposite precedence to the canonical resolver**: it checked the legacy
`adminUserId` column *before* the membership row, where
`InstitutionAuthorityService` checks membership first and treats `adminUserId`
only as a fallback. Two implementations of one rule that disagree is precisely
what the authority doctrine forbids. It now consumes `getContext()`.

The consolidation required a `forwardRef` cycle (the authority module records
governance events *into* activity). Taking the cycle is correct; duplicating
role resolution to avoid it is not.

---

## 3. Engagement — three disclosure questions, kept apart

| Question | Surface | Authority |
|---|---|---|
| **My engagement** | own participation | standing |
| **Public / shared engagement** | `GET .../engagement`, `.../engagement/:recordId` — `RoutedPublicRecord`, public posts routed to the institution, identifiable author | follows the underlying publication policy |
| **Aggregate institutional analytics** | `GET .../engagement/summary` — counts by topic/intent, no identifiable person | **`MANAGE_ANALYTICS`** |
| **Another identifiable person's engagement** | *no such surface exists* | would require a separately named accountability authority |

**Fixed:** `summary` inherited the class-level `MEMBER` floor, so
institution-wide engagement analytics were readable by anyone with standing.
Permission to participate is not permission to measure the institution. It now
requires `MANAGE_ANALYTICS` *within* the MEMBER floor — so a delegated analyst
who is not an admin qualifies, and an admin without the capability does not.

**Positive finding:** there is no endpoint returning another identifiable
person's private engagement. The per-person disclosure question has no surface
to defend, which is the right answer rather than a gap.

**Recorded, deliberately NOT changed:** `list` / `:recordId` return *public*
records behind a MEMBER gate. Under the D4 ruling ("visible according to the
underlying publication policy") that gate is **stricter than the policy** —
under-exposure, not a privacy defect. Loosening access is a disclosure decision
and is not made silently here; the institutional *routing* of a public record
may itself be operational information. Flagged for a founder decision.

---

## 4. The eight questions, answered per surface

| Surface | Data a MEMBER sees | Representative changes? | Operational authority adds | Classification |
|---|---|---|---|---|
| Activity | PUBLIC + MEMBER events | **no** | ADMIN-tier operational trail | member-contextual → operational |
| Engagement list | public routed records | no | — | public |
| Engagement summary | **nothing** | no | aggregate counts | analytical |
| Members | roster + who holds delegated capabilities | no | management actions | member-contextual (doctrine A5) |
| Spaces | spaces their standing admits (server-filtered) | no | management + archived scope | member-contextual |
| Announcements | published | **yes** — may author official | management of drafts | public / operational |
| Explore | member scope | yes — may author official | internal scope | member-contextual |
| Overview | **not projected at all** | no | the whole surface | operational |

No surface grants identifiable-person engagement to any authority.

---

## 5. Still open — nothing marked resolved by inference

* Engagement `list` gate vs publication policy (§3) — **founder decision**.
* Explore entry scope ambiguity (D2 partially ruled; the *entry* remains
  unvalidated in the router).
* Audit destinations still unvalidated and recommended: `/announcements`,
  `/spaces`, `/units`, `/activity`, `/posts/new`, `/posts/:id/edit`.
* `/messages*` — deliberately untouched, gated behind the DirectThread cutover.
* Notification-derived institutional activity — not yet audited against this
  model.
* Meetings/Live data projection — not yet audited.
* Cross-platform: Web only. Android needs an AVD; **iOS remains structurally
  UNVERIFIED** and no PASS is inferred from other clients.
