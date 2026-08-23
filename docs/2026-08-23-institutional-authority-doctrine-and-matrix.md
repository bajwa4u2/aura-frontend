# Institutional Authority — recovered doctrine and capability/privacy matrix

**Release Client reconstruction record. 2026-08-23.**

Recovered from canonical sources — Prisma schema, `institution-capabilities.ts`,
`InstitutionAuthorityService`, guards, API projections, and existing consumers.
**Nothing here was designed from the sidebar**, and no permission was invented to
explain current UI. Where the product genuinely says nothing, it is recorded as
category D rather than filled in.

**No implementation has been performed from this document.**

---

## 1. The model Aura already has

From `src/institutions/authority/institution-capabilities.ts`, verbatim:

> Authority (WHO GOVERNS) is the role hierarchy: OWNER > ADMIN > MEMBER.
> Capability (WHAT MAY BE DONE) is this file. Every authorization decision
> resolves through `InstitutionAuthorityService`, which computes:
> **effective = ROLE_CAPABILITIES[role] ∪ active delegated grants.**
> Governance-exclusive acts (ownership transfer, institution lifecycle,
> appointing/removing ADMINs, granting owner-tier capabilities) are **NOT**
> capabilities — they are owner authority, enforced as role checks so they can
> never be delegated away.

### The founder's ladder is not a ladder in Aura

Aura persists **three** roles: `OWNER`, `ADMIN`, `MEMBER`. There is no
Representative role and no Host role. Those are **capabilities**, delegated onto
a role. The ladder is therefore two axes, not one:

| Founder's term | What Aura actually stores | Effective capabilities |
|---|---|---|
| Unaffiliated / public viewer | no membership row | none |
| **Member** | `role = MEMBER` | **`[]` — empty by default** |
| **Representative / Speaker** | `MEMBER` + `OFFICIAL_REPRESENTATION` (and/or `PUBLISH_OFFICIAL`) | official voice only |
| **Host** | `MEMBER` + `HOST_MEETINGS` | hosting only |
| **Admin** | `role = ADMIN` | 18 operational capabilities |
| **Owner / Governance** | `role = OWNER` | all capabilities **+** governance acts that are not capabilities at all |

**`ROLE_CAPABILITIES[MEMBER]` is the empty list.** Every capability a member
holds is an explicit delegation. This single fact is the sharpest test of the
architecture, and §6 applies it.

**Valid combinations** are therefore: `MEMBER` + any delegated subset;
`ADMIN` + owner-delegated owner-tier capabilities (`MANAGE_BRANDING`,
`MANAGE_DOMAINS`, `MANAGE_BILLING`, `MANAGE_VERIFICATION`); `OWNER` = complete.
An ADMIN may delegate only `HOST_MEETINGS` and `OFFICIAL_REPRESENTATION`
(`ADMIN_DELEGABLE_CAPABILITIES`); everything else requires the OWNER.

---

## 2. End-to-end trace

| Layer | State | Evidence |
|---|---|---|
| Canonical doctrine | **present and explicit** | `institution-capabilities.ts` header |
| Persisted authority | **present** | `InstitutionMemberRole`, `InstitutionCapability`, `InstitutionMemberCapability` |
| Server enforcement | **present, two mechanisms** | 31 `@RequireInstitutionCapability` + service-level `assertCapability`; **plus** 10 `@RequireInstitutionRole` |
| API projection | **correct** | `/institutions/me` returns per-membership effective capabilities (C1) |
| Client capability model | **complete and correct** | `InstitutionAccess.can()`, `canManageMembers`, `canRepresent`, … |
| Client consumption | **almost absent** | only **2** institution files consume `.capabilities` |
| Navigation | **6 of 16 entries gated** | `member_shell.dart` |
| Screen content | **role labels, not capabilities** | see §4 |
| Actions / mutations | server-enforced; client rarely pre-checks | refusal arrives as an error |
| Engagement / activity privacy | role-decorator gated | §5 |
| Notifications | Domain 9 recipient authority (separate, frozen) | — |
| Realtime / Meetings / Live | `START_LIVE`/`END_LIVE`/`HOST_MEETINGS` enforced server-side | client ungated |
| Deep links / lifecycle | 9 of 39 destinations validate the path id | destination audit, same date |

---

## 3. The architecture verdict

**The founder's suspicion is confirmed, with one important qualification.**

The *backend* is genuinely composed from institutional authority: a single
authority service, a single capability model, enforcement at 41 sites.

The *client* is the broadly shared surface. It receives a correct, complete
capability set and then largely ignores it:

* **10 of 16** navigation entries have no authority predicate at all. Every
  `WORKSPACE` entry — Overview, Explore, Activity, Announcements, Live, Spaces,
  Messages, Meetings — is visible to every member regardless of capability.
* **`Members` sits in the `ADMIN` section with no gate**, beside `Join Requests`
  and `Invites` which do have one.
* Screens gate on role labels where capabilities exist:
  `institution_spaces_screen` **7 role checks / 0 capability checks**;
  `institution_members_screen` **9 / 2**; `institution_announcements_screen`
  **5 / 3**. (`institution_live_rooms_screen` was reported as ungated and is
  not — see Finding B2. The counts above measure `can*` style checks only and
  therefore undercount `CapabilityProjection` adoption by roughly six files.)
* Client-wide: **139** role-label checks against **19** capability checks.

So the repair is architectural, not cosmetic: the workspace must be **composed
from** the effective capability set, not decorated with conditional widgets. The
model to compose from already exists and is already correct.

### The one thing that is NOT projected under hidden UI

Pending join-request and invite counts are fetched only when the viewer is
admin, deliberately (`member_shell.dart`) — so those badges are not hidden UI
over projected data. They gate on `isAdmin` (a role label) while the nav entries
beside them gate on the capability, which is an internal inconsistency: a MEMBER
holding delegated `MANAGE_JOIN_REQUESTS` sees the entry but never the badge.

---

## 4. Findings

### (A) Already canonical and correctly consumed

1. The two-axis authority model itself, and `effective = role ∪ delegated`.
2. Governance-exclusive acts as role checks, never delegable — doctrinally
   correct, not drift.
3. `/institutions/me` per-membership capability projection (C1).
4. `listInvites` asserts `MANAGE_INVITATIONS`; `listJoinRequests` asserts
   `MANAGE_JOIN_REQUESTS`.
5. **Member roster visibility is deliberate doctrine**, stated in the service:
   *"Visibility follows responsibility: every member sees who holds delegated
   capabilities (hosts, representatives, delegated managers)."* Every member
   seeing every member's role and delegated capabilities is therefore **not** an
   overexposure defect.
6. Institution Spaces enforce `MANAGE_SPACES` through the authority service.
7. `START_LIVE` / `END_LIVE` / `HOST_MEETINGS` enforced server-side.
8. Meetings deliberately treat `institutionId` as context, not a membership
   claim (frozen 2026-08-14).

### (B) Canonical but not consumed — reconstruction obligations

1. **Navigation is not composed from capabilities.** 10 of 16 entries have no
   predicate; the capability accessors they would use already exist.
2. ~~**Live**: `institution_live_rooms_screen` has no gating at all.~~
   **CORRECTED 2026-08-23.** This was wrong, and it was wrong because the
   measurement was too narrow. The screen *does* gate starting a session, via
   `capabilityProjectionProvider.presentationFor(ConsequentialAct.startLive)`,
   with a comment stating the gate is the capability projection "never a role
   label". My grep matched only `can*`/`.can(` and so could not see it.

   The correction matters beyond one screen: the client has a **third**
   canonical authority I under-counted — `CapabilityProjection` (C1), whose
   doctrine is *"what may I do in this context"*, consuming the backend's
   effective set and never recomputing it. It is the RIGHT mechanism for
   controls and navigation alike. The defect is therefore **thin adoption**
   (6 files) rather than absence, and the reconstruction is to consume it more
   widely — not to introduce anything new.
3. **Spaces**: 7 role checks where `canManageSpaces` exists.
4. **Announcements**: partial — 5 role checks alongside 3 capability checks.
5. **Members**: 9 role checks where `canManageMembers` exists; the *roster* is
   member-wide by doctrine (A5), but the *management actions* on it are not.
6. **Badges** gate on `isAdmin` rather than the same capability the entry uses.
7. **Overview nav entry still points at the id-less `/institution/dashboard`**
   even though the route is now addressable per institution (same-date fix).

### (C) Conflicting authorities / legacy drift

1. **Two server authorization mechanisms.** `@RequireInstitutionRole` (10 sites)
   beside `@RequireInstitutionCapability` (31). `RequireInstitutionRole('MEMBER')`
   is a legitimate membership floor. But `@RequireInstitutionRole('ADMIN')` on
   **units** and **participation** admin operations governs by role where the
   capability model should: an OWNER cannot revoke it from an ADMIN, and a
   delegated manager can never be granted it. These are not governance-exclusive
   acts, so the role check is drift, not doctrine.
2. **`Members` placed in the ADMIN section though every member may use it** —
   the section label asserts an authority the surface does not require.
3. **Client role-label gating generally** (139 vs 19) — the same event governed
   by two different vocabularies depending on which screen you open.

### (D) Genuinely unspecified — founder decision required

These are **not** reconstruction obligations and are not resolved by assumption.

1. **What does a plain MEMBER — zero capabilities — legitimately see inside the
   workspace?** The model says they can *do* nothing administrative, but says
   nothing about which of Explore / Activity / Announcements / Live / Spaces /
   Messages / Meetings are *member-wide by nature* versus *operator surfaces a
   member should not see at all*. Every one of them is currently visible to
   everyone, so current behaviour is not evidence of intent.
2. **Is Explore a member surface or a public surface?** Its `scope=public`
   answers unauthenticated callers (verified live), yet it is the workspace
   entry destination. Genuinely ambiguous.
3. **Institution Activity: whose activity, visible to whom?** The endpoint is
   gated at `MEMBER` with no capability. Whether a plain member should see
   institution-wide operational activity (member joins, publications, moderation)
   is a transparency decision, not a technical one.
4. **Engagement records**: gated at `MEMBER` (`RequireInstitutionRole('MEMBER')`)
   while `MANAGE_ANALYTICS` exists. Which engagement data is member-wide and
   which is analytical is unspecified.
5. **Terminal denial addressing** — still shares `/institution/dashboard` with
   Overview and the no-affiliation landing (three meanings, one address). The
   founder ruled it must be independently governed; the destination is not yet
   named.
6. **Overview's placement into ADMIN** (ruled) versus its current role as the
   standing surface a refused or unaffiliated person lands on. Moving it makes
   that landing an admin surface. The two rulings interact and the resolution is
   a product decision.

---

## 5. The authoritative capability/privacy matrix

Read as: what each authority may **see**, **do**, and **have projected to it**.
`—` = nothing. Capabilities are the canonical tokens.

| Surface | Public viewer | Member (no delegation) | + Representative | + Host | Admin | Owner |
|---|---|---|---|---|---|---|
| **Overview** | — | own standing | own standing | own standing | + operational state | + governance state |
| **Explore** | public scope only (verified) | + member scope | + author official (`PUBLISH_OFFICIAL`) | member scope | + internal scope | same |
| **Activity** | — | **D3** | **D3** | **D3** | operational activity | + governance activity |
| **Announcements** | published only | read | **author official** (`PUBLISH_OFFICIAL`) | read | `MANAGE_ANNOUNCEMENTS` | same |
| **Live** | public rooms | join | join | join | `START_LIVE` / `END_LIVE` | same |
| **Spaces** | public spaces | member spaces | member spaces | member spaces | `MANAGE_SPACES` | same |
| **Messages** | — | own conversations | + speak as institution (`OFFICIAL_REPRESENTATION`) | own | own + institution desk | same |
| **Meetings** | book / attend (context, not membership) | attend | attend | **`HOST_MEETINGS`** | `MANAGE_MEETINGS`, `MANAGE_BOOKINGS` | same |
| **Members** | — | **full roster + delegated capabilities (A5)** | same | same | `MANAGE_MEMBERS` actions | + appoint/remove ADMIN (role, not capability) |
| **Governance** (domains, billing, verification, branding) | — | — | — | — | only if owner-delegated | `OWNER_HELD_CAPABILITIES` |
| **Identity** (profile, edit) | public profile | public profile | public profile | public profile | `MANAGE_BRANDING` if delegated | `MANAGE_BRANDING` |
| **Engagement / activity data** | — | **D4** | **D4** | **D4** | `MANAGE_ANALYTICS` | same |

Cells marked **D3 / D4** are the unspecified ones. They are left unresolved
deliberately: filling them from current behaviour would be designing doctrine
from the sidebar, which this record exists to avoid.

---

## 6. What reconstruction must do

1. **Compose navigation from the effective capability set** rather than
   filtering a shared list — the entry list should be *derived*, so an
   ungoverned entry is impossible rather than merely absent.
2. **Never fetch what the viewer may not hold.** Hiding an entry while the data
   is still requested is the defect the founder named. Today only the badge
   counts do this correctly; the rule must be general.
3. **Retire `@RequireInstitutionRole('ADMIN')`** on units and participation in
   favour of capabilities (C1). Keep `MEMBER` as a membership floor, and keep
   genuine governance role checks.
4. **Replace client role-label gating with capability checks** on Spaces, Live,
   Members actions, Announcements.
5. **Fix the badge/entry inconsistency** so both read the same capability.
6. **Point the Overview nav entry at the addressable route.**

Items 1–6 are category B/C — reconstruction obligations, not founder decisions.
The six D items in §4 are the only things that come back for product design.
