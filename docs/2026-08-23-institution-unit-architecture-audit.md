# Institution Units — architecture audit

**Release Client reconstruction record. 2026-08-23.** Founder ruling: a Unit is
a *governed operating context* inside an Institution, not an information card.
Audit before design; `MANAGE_UNITS` must not be invented.

**No Unit redesign has been implemented.** Two concrete defects found during the
audit were fixed because they are bugs in the *existing* intent, not new
architecture — both are recorded in §7.

---

## 1. Existing canonical doctrine

**There is none.** No governance document, reconstruction record or schema
comment states what a Unit *is*, who belongs to one, or what authority governs
it. The schema carries doctrine comments for Spaces, Conversations, Media,
capabilities and ownership — and **nothing** for Units.

That absence is itself the finding: the product meaning the founder describes
has never been written down, which is why "which capability governs Units?" had
no answer to recover.

## 2. Existing schema and runtime model

`InstitutionUnit`: `id`, `institutionId`, `name`, `slug`, `type`,
`description`, `logoUrl`, `websiteUrl`, `contactEmail`, `contactPhone`,
`address`, `city`, `region`, `country`, `sortOrder`, `isPublic`, `archivedAt`.

`InstitutionUnitType` = `PRODUCT · BUSINESS · BRANCH · OFFICE · DEPARTMENT ·
SERVICE · PROGRAM · OTHER` — **already the founder's framing.** The vocabulary
for "Aura and Orchestrate inside Aura Platform LLC" exists; only the operating
model does not.

### Everything in the database that scopes anything to a Unit

```
MeetingAudienceTarget.targetUnitId      ← the only one
```

Verified against the live database's `information_schema`, not inferred from the
model file. There is **no Unit membership, assignment, space, conversation,
post, announcement, activity, resource, availability or analytics relation.**

### The one operational relation is inert

`MeetingAudienceTargetKind` includes `UNIT`, `DEPARTMENT`, `COMMITTEE`, `BOARD`,
`LEADERSHIP`, `WORKING_GROUP`, all targeting a Unit. But meeting eligibility
resolves audience targets **only** for `kind: 'MEMBER'` with a `targetUserId`
(`meeting.service.ts`). A `UNIT` target is **written and never read**.

It cannot work as written: resolving "everyone in this Unit" requires Unit
membership, and none exists. The feature is a schema-level intention with no
runtime.

## 3. Current released experience

| Surface | What it is |
|---|---|
| `institution_units_screen.dart` (608 lines) | full create / edit / archive CRUD |
| `institution_unit_card.dart` (133 lines) | descriptive card |
| Institution profile "Units & branches" | the card list |
| Public institution page | units appear where `isPublic` |

Screen copy describes them as *"departments, branches, offices, products, or
services that appear on the public institution profile"* — i.e. the product
today treats a Unit as **public descriptive information**, exactly as the
founder observed.

## 4. Production data

| Fact | Value |
|---|---|
| Units, all institutions | **1** |
| That unit | `Orchestrate Operations`, type `PRODUCT`, public, unarchived, on `aura-platform-llc` |
| Meeting audience targets, any kind | **0** |
| Meetings by audience | `GUEST` 112 · `INSTITUTION` 6 · `PRIVATE` 2 — **`SELECTED` never used** |

**"Aura" is not a Unit.** The founder's example is aspirational: one unit exists
and the unit-targeting path has never been exercised in production. This is a
*greenfield* reconstruction, not a migration of established usage.

## 5. Unit-owned vs Institution-owned — classified

| Concept | Class | Evidence |
|---|---|---|
| Name, slug, type, description, logo | **A — Unit-owned** | persisted per unit |
| Contact/address/website | **A**, but duplicates institution fields | both models carry them |
| `isPublic`, `archivedAt`, `sortOrder` | **A — Unit lifecycle/presentation** | persisted |
| Meeting audience cohort | **D — missing runtime** | targetable, never resolved |
| Membership / assignment | **D — does not exist** | no table, no column |
| Representatives, Hosts inside a Unit | **D** | capabilities are institution-scoped only |
| Spaces, Conversations, Posts, Announcements, Activity, Analytics, Resources, Availability | **D** | no unit scoping anywhere |
| Identity, verification, ownership, billing, domains | **B — Institution-owned, must stay** | founder hard boundary §2 |
| Create/edit/archive authority | **C — legacy drift** | role check, no capability (§7) |
| Public presence | **A/E** | units render publicly today with no stated provenance rule |

Nothing is classified A merely because a field exists.

## 6. Authority relationships as they stand

* Reads: `GET /institutions/:id/units` — authentication only.
* Writes: `@RequireInstitutionRole('ADMIN')` — **role, not capability.**
* No `MANAGE_UNITS`, and per the ruling none has been invented.
* Client: `ConsequentialAct.administerUnits` now *names* the existing
  role requirement (`governance(InstitutionRole.admin)`). It creates no new
  authority and deliberately stays role-shaped so §11 — creation/retirement may
  be governance-different from operation — remains open.

## 7. Defects found and fixed during the audit

**(i) Authenticated was treated as authorised.** `listUnits` read
`const isAdmin = !!adminUserId`, so *any signed-in Aura user* — including
someone holding no standing in that institution — could list its **non-public
and archived** units. `isPublic`/`archivedAt` exist precisely to withhold those;
the intent was expressed, the check was wrong. The elevated view now requires
the same authority that may create and edit units.

**(ii) Management controls were offered to everyone.** The Units screen rendered
create / edit / archive with no client gate, so any member reaching it was
offered actions that could only 403. Controls are now **absent** rather than
disabled, gated on `administerUnits`. The destination itself stays participation
baseline — units are part of how an institution describes itself.

## 8. Privacy / audience model — as measured

`isPublic` is the only audience control, and it is binary: public, or
admin-visible. There is no member-contextual tier, no per-unit visibility, and
no notion of "operational detail of a Unit you are not responsible for" —
because there is no per-unit responsibility to compare against.

**Founder §9 cannot be satisfied today**: "a person responsible for one Unit
should not automatically see private operational details of another" has no
implementable meaning while responsibility is not unit-scoped.

## 9. Proposed model — evidence, not yet a design

The evidence supports a specific and narrow direction:

1. **Unit as a scope, not a container.** Every operational system Aura already
   has (Spaces, Conversations, Meetings, Announcements, Activity) is
   institution-scoped. A Unit should become an optional *dimension* of those,
   not a parallel copy — matching the hard boundary in §2 of the ruling.
2. **Assignment before authority.** The single blocking gap is that nobody
   *belongs* to a Unit. Meeting cohort targeting already assumes this and is
   inert without it. Assignment is the first thing to reconstruct, and it is
   what makes §9 privacy expressible at all.
3. **Scoped delegation, not new roles.** Existing capabilities
   (`OFFICIAL_REPRESENTATION`, `HOST_MEETINGS`, `MANAGE_SPACES`) are
   institution-wide. The founder's example — Representative *for Orchestrate*,
   Host *for Orchestrate meetings* — needs those same capabilities carrying an
   optional unit scope, not new persisted roles.
4. **Creation/retirement stays institutional.** Consistent with §11 and with the
   role gate already in force.

## 10. Founder decisions required

| # | Decision |
|---|---|
| **U1** | Does a Unit get **membership/assignment**? Nothing else in §9 or the meeting cohort feature is implementable without it. |
| **U2** | Should existing capabilities gain an **optional unit scope**, or should unit responsibility be a separate delegation? This is the "Representative for Orchestrate" question. |
| **U3** | Which operational systems become unit-scopable, and in what order — Meetings (already half-built), Spaces, Announcements, Activity? |
| **U4** | **Public Unit presence**: units render publicly today with no stated provenance rule. What must a public Unit show about its parent Institution, and may it be discoverable/searchable independently? |
| **U5** | Is unit **creation/retirement** institution-governance (current behaviour) or delegable operation? |
| **U6** | Should the inert `UNIT`/`DEPARTMENT`/`COMMITTEE`/`BOARD`/`LEADERSHIP`/`WORKING_GROUP` cohort kinds be **implemented or retired**? They are schema intent with no runtime and zero production use. |
| **U7** | Does a Unit get its own **contact/address/website**, duplicating institution fields, or inherit with overrides? |

## 11. Cross-platform

Units are consumed today only by the institution profile card and the
management screen — both Web/Desktop layouts. **Android and iOS have not been
exercised at all**, and no PASS is inferred. Any reconstructed Unit context must
be certified per platform; iOS remains structurally UNVERIFIED.

## 12. Not audited

Search/Discover participation (§13 of the ruling) is not audited because units
appear in no search or discovery index today — there is nothing to measure. It
becomes a real question only if U3/U4 are answered affirmatively.
