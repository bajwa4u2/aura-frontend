# Aura Institution Participation & Activation Framework

Date: 2026-06-20

Status: Final pre-Patch-3 architecture document. This document does not implement application code, create migrations, commit changes, or deploy anything.

Canonical references:

- `aura_final/docs/strategy/AURA_STATE.md`
- `aura_final/docs/strategy/AURA_ACCOUNTABILITY_ROUTING_IMPLEMENTATION_FRAMEWORK.md`
- `aura_final/docs/strategy/AURA_CONTEXT_OWNERSHIP_RESOLUTION_FRAMEWORK.md`
- `aura_final/docs/strategy/AURA_PRE_IMPLEMENTATION_LOCK.md`
- `aura_final/docs/strategy/AURA_PROGRESSIVE_CREDIBILITY_DOCTRINE.md`

Progressive credibility alignment: this document is revised by the doctrine
that identity is declared, participation is observed, credibility is earned,
accountability is progressively accepted, and trust accumulates through
continuity. Any language below that appears to require complete participation,
jurisdiction, unit, or accountability setup during onboarding should be read as
future route-readiness, not as a prerequisite to joining Aura and beginning
official participation.

## Executive Summary

An institution becomes a meaningful participant in Aura progressively. It starts
with declared and verified identity, assigns official representatives, begins
participating, earns credibility through observable behavior, accepts
accountability through official action, and builds trust through continuity.

Participation is the bridge between institutional identity and future routing,
but participation setup should not become a barrier to joining Aura. Aura must
not route public records to institutions simply because a topic appears
relevant. Routing becomes legitimate only after the institution has explicitly
confirmed the participation needed for routing:

- who it is
- that it is verified or approved for official presence
- who may speak officially
- what topics it participates in
- where it operates
- how it participates
- which parts of that participation are eligible for accountable workflows when it is ready
- whether participation applies at the institution level or unit level

Existing assets are strong enough to support Patch 3 design:

- Institution profile, class, type, domain tags, and ontology.
- Domain verification and institution verification flows.
- Members, roles, official voice flags, and institution plan gating.
- Public institution units with CRUD, archive, reorder, and public display.
- Existing `Topic` enum and public composer topic model.
- Free-text jurisdiction/location fields on institutions, users, units, and verification requests.

The missing pieces are the Patch 3 contracts:

- `InstitutionParticipation`.
- `ParticipationMode`.
- `InstitutionActivationState`.
- normalized global `Jurisdiction`.
- `InstitutionJurisdiction`.
- optional `InstitutionUnitParticipation`.
- participation history/audit.
- onboarding and activation UX around these models.

Patch 3 receives a **CONDITIONAL PASS**. It can proceed after the exact Patch 3 schema and API contracts are reviewed, but Patch 3 must not create routing. It should create a lightweight participation and activation foundation that lets institutions start with official presence, then progressively confirm topic, jurisdiction, unit, and accountability details before Patch 4 consumes them.

## Institution Participation Framework

### Definition

Institution participation means an institution has declared that it wants Aura to treat it as present in a defined topic, jurisdiction, and mode.

Participation is not generic profile metadata. It is an operational declaration that can later be used by ownership resolution and routing.

### Participation Modes

| Mode | Operational meaning | Public meaning | Routing implications | Continuity implications | Institution expectations |
| --- | --- | --- | --- | --- | --- |
| `LISTENING` | Institution monitors public records in a topic/scope without promising response | Usually hidden; may appear as "participates in this topic" on profile if configured | Eligible for monitoring surfaces only; should not create Needs Response by default | Can preserve that institution observed or followed a record internally, but not public continuity by default | Monitor, learn, optionally respond manually |
| `RESPONDING` | Institution accepts relevant public records for possible official response | Public sees official responses when the institution chooses to respond | Can create Public Engagement items; may appear in Needs Response if policy enables it | Official responses become part of continuity | Review and respond where appropriate |
| `ACCOUNTABLE` | Institution accepts accountable workflow for topic/scope | Public may see participating institution, official response, commitment, progress, resolved | Eligible for Needs Response, Open Commitments, progress, resolution, dispute | Full continuity path: response, commitment, progress, resolution, verification/dispute | Respond, commit when appropriate, update progress, resolve or close responsibly |
| `REFERENCE_ONLY` | Institution may be attached as context but does not receive accountable workflow | Public may see explicit references only when useful | Does not create routeable Needs Response items by default | Reference can be preserved as context, not responsibility | No operational expectation |

### Boundary Rules

Participation is not credibility, and participation is not accountability.

- `LISTENING`, `RESPONDING`, and `REFERENCE_ONLY` participation do not create accountable responsibility.
- `ACCOUNTABLE` participation creates eligibility for accountable workflow, but only inside declared topic and jurisdiction scope.

Accountability is not commitment.

- An accountable route means the institution has accepted a mode where the record may require official attention.
- It does not mean the institution has promised an action.

Commitment is not resolution.

- A commitment is an official promise or concrete action path.
- Resolution requires a later official resolution claim and, where policy allows, verification or dispute handling.

### Existing Support

Reusable now:

- `Institution.status`, `verifiedAt`, `domainVerifiedAt`, `canSpeakOfficially`, and plan fields.
- `InstitutionMember.role` and `canSpeakOfficially`.
- `Institution.institutionClass`, `institutionType`, and `domainTags`.
- `InstitutionUnit`.
- `Topic` enum.
- Existing public profile and institution workspace surfaces.

Missing:

- Dedicated participation table/model.
- Participation mode.
- Participation lifecycle.
- Topic-to-participation declaration.
- Jurisdiction-to-participation declaration.
- Unit participation.
- Participation audit/history.

## Institution Activation Journey

### Stage 1: Profile Exists

| Item | Details |
| --- | --- |
| Required actions | Create or claim institution profile with name, slug, class/type where available |
| Optional actions | Add logo, tagline, description, website, contact fields, public units |
| Blocked capabilities | Official routing, official response, commitments, accountable participation |
| Unlocked capabilities | Public profile may exist; discovery can show profile depending on status policy |

### Stage 2: Verified Identity

| Item | Details |
| --- | --- |
| Required actions | Domain verification or platform/admin approval |
| Optional actions | Add additional verified domains, trust level upgrades |
| Blocked capabilities | Routing still blocked until official representatives and participation are configured |
| Unlocked capabilities | Verified identity, verified badge, stronger public trust, eligibility for official voice |

### Stage 3: Official Representatives

| Item | Details |
| --- | --- |
| Required actions | At least one active institution member with official response capability |
| Optional actions | Invite additional admins, editors, official actors, unit leads |
| Blocked capabilities | Accountable routing remains blocked until participation and jurisdiction setup |
| Unlocked capabilities | Official response eligibility, institution-authored communication, workspace management |

### Stage 4: Participation Setup

| Item | Details |
| --- | --- |
| Required actions | Select topics and participation mode for each declared area |
| Optional actions | Seed from ontology/domain tags; attach units; add plain-language scope notes |
| Blocked capabilities | Routing blocked until jurisdiction/scope is configured |
| Unlocked capabilities | Draft participation declarations, onboarding progress, future route eligibility |

### Stage 5: Jurisdiction Setup

| Item | Details |
| --- | --- |
| Required actions | Declare where the institution operates for each participation area |
| Optional actions | Add service areas, campuses, districts, custom boundaries, unit-specific scopes |
| Blocked capabilities | Auto-routing blocked until activation checks pass |
| Unlocked capabilities | Scope-aware participation; ownership resolution can later evaluate routeability |

### Stage 6: Activation

| Item | Details |
| --- | --- |
| Required actions | Validate identity, representative, participation, mode, and jurisdiction completeness |
| Optional actions | Admin review for accountable declarations, pilot override, pause/resume settings |
| Blocked capabilities | Patch 4 routing remains blocked by separate schema/API review gate |
| Unlocked capabilities | Institution becomes routable-ready for future routing; participation can appear in workspace setup |

### Stage 7: Public Engagement

| Item | Details |
| --- | --- |
| Required actions | Patch 4+ only: route records after approved routing contracts |
| Optional actions | Workspace filters, counters, broad route reasons, internal notes |
| Blocked capabilities | Commitments/resolution until official response and lifecycle support exist |
| Unlocked capabilities | Needs Response, Public Records, referenced records, official response surfaces |

### Stage 8: Commitments & Continuity

| Item | Details |
| --- | --- |
| Required actions | Official actor makes explicit commitment or resolution action |
| Optional actions | Progress updates, verification/dispute, continuity panel |
| Blocked capabilities | None after lifecycle support exists; subject to capability policy |
| Unlocked capabilities | Open Commitments, progress, resolved records, durable continuity |

### Activation States

Recommended Patch 3 activation states:

| State | Meaning | Route readiness |
| --- | --- | --- |
| `PROFILE_ONLY` | Profile exists, but identity or setup is incomplete | Not routeable |
| `VERIFYING` | Identity verification in progress | Not routeable except pilot override |
| `VERIFIED_NO_REPRESENTATIVE` | Institution verified but lacks official actor | Not routeable |
| `VERIFIED_NO_PARTICIPATION` | Verified and represented, but no topic/mode declarations | Not routeable |
| `PARTICIPATION_DRAFT` | Participation exists but not active or scoped | Not routeable |
| `JURISDICTION_INCOMPLETE` | Topic/mode exists but scope is missing | Not routeable |
| `ROUTABLE_READY` | Patch 3 foundation complete | Eligible for Patch 4 routing later |
| `PAUSED` | Institution has paused participation/routing | Not routeable for new records |
| `SUSPENDED` | Trust/safety/admin restriction | Not routeable; official actions restricted by policy |

## Global Jurisdiction Framework

### Design Principle

Aura is global. Jurisdiction must not be hard-coded to one country's government structure. It must support public institutions, universities, health systems, transit agencies, utilities, international organizations, campuses, service areas, and custom operating scopes.

### Minimum Viable Global Model

Recommended concept:

`Jurisdiction` is a generic place or scope node.

Minimum fields:

- stable id
- display name
- type
- optional parent id
- country code when applicable
- region code/name when applicable
- external reference/source when available
- active/archived state
- metadata for future geometry or provider identifiers

Recommended jurisdiction types:

| Type | Meaning |
| --- | --- |
| `GLOBAL` | No specific geography; worldwide or global topic |
| `COUNTRY` | Sovereign country or country-level scope |
| `STATE_PROVINCE` | State, province, governorate, emirate, canton, or equivalent |
| `REGION` | Region that is not neatly state/province/county |
| `COUNTY` | County, parish, prefecture, or equivalent |
| `DISTRICT` | District, borough, ward, constituency, school district, service district |
| `MUNICIPALITY` | City, town, village, local municipality |
| `CAMPUS` | University, school, hospital, or organizational campus |
| `SERVICE_AREA` | Utility, transit, hospital, media, or organizational service area |
| `CUSTOM` | Institution-defined scope that does not fit a standard geographic hierarchy |

### Hierarchy Rules

- Every jurisdiction may have a parent except `GLOBAL`.
- Parent/child structure is generic and not country-specific.
- A child inherits geographic containment from its parent only when the type/source supports containment.
- Service areas and campuses may overlap multiple geographic parents.
- Custom jurisdictions should require display name, owning institution or admin source, and audit.

### Extensibility Model

Patch 3 should design for:

- provider-backed identifiers later, such as geocoding or administrative-boundary providers
- multilingual display labels
- alternate names and aliases
- multiple parents for non-tree regions, if needed later
- geometry/shape metadata later without requiring it now
- institution-owned custom service areas
- admin-approved canonical jurisdictions for pilot markets

### Onboarding Implications

The UI should ask:

- "Where do you operate?"
- not "What department owns this case?"

Recommended selection levels:

- global
- country
- region/state/province
- city/municipality
- campus
- service area
- custom area

Do not require institutions to understand a country-specific administrative model. The onboarding should offer search, suggestions, and plain labels.

## Participation Declaration Framework

### Declaration Process

An institution declares participation by selecting:

1. Topic.
2. Optional subtopic or domain tag.
3. Participation mode.
4. Jurisdiction/scope.
5. Optional unit.
6. Optional public description.
7. Active/draft state.

Examples:

| Institution | Participation declaration |
| --- | --- |
| University | Education, Housing, Research, Admissions, Financial Aid |
| City | Transportation, Infrastructure, Housing, Public Safety |
| Hospital | Healthcare, Emergency Services, Public Health |
| Utility | Infrastructure, Energy, Water, Service Outages |

### Existing Assets

| Existing asset | Use in Patch 3 | Limitation |
| --- | --- | --- |
| `Topic` enum | Primary public record topic and participation topic | Broad; may need subtopic/domain layer later |
| Institution class/type | Seeds suggested participation defaults | Describes institution identity, not active participation |
| Domain tags | Seeds remit suggestions | Not authoritative participation |
| Institution units | Can receive future unit-level participation | Current unit model has no participation/scope fields |
| Verification/domain models | Gate official participation | Does not define topic or jurisdiction |
| Institution profile location fields | Onboarding defaults | Free text; not normalized routing scope |

### Management Process

Institution admins should be able to:

- create participation declarations
- save drafts
- activate declarations
- pause declarations
- archive declarations
- change mode
- change jurisdiction
- assign or remove units
- view audit/history

Capability required:

- `CAN_MANAGE_INSTITUTION_PARTICIPATION`

### Lifecycle

Recommended participation lifecycle:

| State | Meaning | Routing impact |
| --- | --- | --- |
| `DRAFT` | Being configured | Not routeable |
| `PENDING_REVIEW` | Awaiting admin/platform review for sensitive/accountable scope | Not routeable unless pilot override |
| `ACTIVE` | Valid and active | Routeable-ready |
| `PAUSED` | Temporarily disabled | Do not route new records |
| `ARCHIVED` | Retired historical declaration | Do not route; preserve continuity |
| `REJECTED` | Not accepted by platform/admin | Do not route |

### Versioning Implications

Participation changes must be auditable.

Recommended approach:

- Keep participation row stable for the declared scope.
- Add audit/history events for mode, topic, jurisdiction, unit, status, and actor changes.
- Future routed records should snapshot the participation id/version used.
- Past continuity should preserve the declaration that existed at route time.

## Accountability Declaration Framework

### Definition

Accountability declaration is a stricter subset of participation. It says an institution accepts accountable public-record workflow for a topic and jurisdiction.

Example:

- Participates in Transportation.
- Accountable for Road Maintenance inside city-owned local roads.

### Scope Types

| Scope | Meaning |
| --- | --- |
| Participation scope | Broad area where the institution listens, responds, or participates |
| Accountability scope | Narrower area where the institution accepts accountable workflow |
| Commitment scope | Specific official promise made on a public record |
| Resolution scope | Specific claim that a commitment or issue has been resolved |

### Public Visibility

Public surfaces may show:

- institution participates in a topic
- official response
- commitment
- progress
- resolved

Public surfaces should not overstate:

- legal obligation
- internal ownership
- route confidence
- staff assignment
- department responsibility

### Routing Impact

`ACCOUNTABLE` mode can create routeable-ready accountable candidates only when:

- institution is activated
- topic matches
- jurisdiction/scope matches
- author capability allows the intent
- public record intent is eligible
- Patch 4 routing contracts are approved and enabled

### Review Policy

Some accountability declarations should require review:

- public safety
- health
- elections
- utilities
- child/youth services
- cross-border or international authority
- ambiguous government jurisdiction
- institution claiming accountability outside its verified identity

Patch 3 should allow review status even if the first implementation starts with simple admin approval or pilot-only activation.

## Institution Unit Participation Framework

### Existing Unit Model

Existing backend and frontend support institution units:

- `InstitutionUnit` model with name, slug, type, description, logo, website, contact, address, city, region, country, sort order, public flag, and archive timestamp.
- `InstitutionUnitType` includes `PRODUCT`, `BUSINESS`, `BRANCH`, `OFFICE`, `DEPARTMENT`, `SERVICE`, `PROGRAM`, `OTHER`.
- Institution unit CRUD is exposed through institution admin APIs.
- Frontend has a Units & branches management screen and public unit display components.

### Unit Participation Model

Units should be optional route targets under an institution, not independent public institutions by default.

Recommended rules:

- Institution-level participation is the default.
- Unit-level participation can refine topic, mode, jurisdiction, or operational owner.
- Unit-level accountability must inherit from an activated institution.
- A unit cannot be more publicly authoritative than the parent institution unless the parent explicitly grants it.
- Public official identity remains the institution unless product later supports official unit identity.

### Inheritance

| Parent declaration | Unit behavior |
| --- | --- |
| Institution `LISTENING` | Unit may listen only unless given stronger reviewed declaration |
| Institution `RESPONDING` | Unit may respond if official actor policy allows |
| Institution `ACCOUNTABLE` | Unit may become operational owner for accountable records within scope |
| Institution `REFERENCE_ONLY` | Unit can be referenced only |

Recommended default:

- Unit cannot escalate inherited mode.
- Unit can narrow topic or jurisdiction.
- Unit can be assigned as internal handling target.
- Public continuity records actions under institution identity, with optional unit label if safe.

### Routing Implications

Patch 4 later may route:

- to institution as public accountable actor
- to unit as internal workspace target
- to unit-level queue/filter when unit participation exists

Patch 3 should only model unit participation and inheritance. It should not create routed records.

## Participation Evolution Framework

### Why Evolution Matters

Institutions will not configure all participation on day one. A university may start with Education, then add Housing, Admissions, Financial Aid, and Research later. A city may start with Infrastructure, then add Transportation, Housing, and Public Safety.

### Expansion Process

Recommended process:

1. Admin opens participation settings.
2. Adds topic or subtopic.
3. Selects mode.
4. Selects jurisdiction/scope.
5. Assigns optional unit.
6. Saves draft.
7. Activates directly or submits for review depending on policy.
8. System records audit/history.

### Auditability

Every meaningful participation change should record:

- actor user id
- institution id
- unit id, if any
- previous values
- new values
- reason or note, optional
- timestamp
- review status, if applicable

### Continuity

Participation evolution must not rewrite history.

- Public records routed under an older declaration keep the old participation snapshot.
- Archived participation remains visible to admins and continuity services.
- Public users should not see internal version history unless a continuity event needs a public label.

### Routing Safety

When participation changes:

- New records use the new active declaration.
- Existing unresolved route items should not silently move.
- Mode downgrade from `ACCOUNTABLE` to `RESPONDING` should not erase existing commitments.
- Pausing participation should stop new route creation but preserve existing continuity.
- Archive should require confirmation if open commitments exist.

## Institution Onboarding Framework

### Product Feel

Onboarding should feel like setting up a verified public presence, not completing a compliance form.

Avoid:

- bureaucratic setup
- country-specific configuration
- large compliance forms
- case/ticket/department language

Use:

- Who are you?
- Where do you operate?
- What topics do you participate in?
- How do you participate?
- Who can respond officially?

### Wizard Flow

Recommended onboarding steps:

1. Identity.
   - Name, website/domain, class, type.

2. Verification.
   - Domain verification or admin-approved pilot path.

3. Official representatives.
   - Invite or assign people who can manage, respond, and later commit/resolve.

4. Topics.
   - Suggested from class/type/domain tags.
   - Institution selects topics it actually participates in.

5. Scope.
   - Select global, country, region, municipality, campus, service area, or custom area.

6. Mode.
   - Listening, Responding, Accountable, Reference Only.

7. Units.
   - Optional departments, branches, services, programs.

8. Review and activate.
   - Plain summary of how Aura will treat the institution.

### Recommendations

Defaults can be suggested from ontology:

- University: Education, Research, Housing, Employment.
- City/municipality: Government, Transportation, Infrastructure, Housing, Public Safety.
- Hospital/public health organization: Healthcare, Public Safety.
- Utility/infrastructure operator: Infrastructure, Energy, Environment.

Recommendation rules:

- Suggestions are not active declarations.
- Institution must confirm participation.
- Accountable mode should require explicit selection.
- Sensitive scopes may require admin review.

### Future AI Assistance

AI may help by:

- suggesting topics from profile text
- suggesting likely units from website/profile
- summarizing participation in plain language
- detecting missing jurisdiction details

AI must not:

- activate participation
- create accountability
- infer legal responsibility
- bypass verification/review

## Inactive Participation Policy

### Default State

If an institution verifies identity but never configures participation, its state should be:

`VERIFIED_NO_PARTICIPATION`

### Visibility

Public visibility:

- Institution can show as verified.
- Institution profile can show official presence.
- No public statement should imply it receives public records for response or accountability.

Institution workspace:

- Show activation prompts.
- Explain that participation setup is required before public records can be routed in future.
- Provide a simple setup entry point.

Admin visibility:

- Show missing participation and jurisdiction.
- Allow pilot assistance or admin-managed setup.

### Routing Behavior

- Do not route records to the institution.
- Mentions can create references only.
- Follows/social graph do not create routeability.
- Official responses may still be possible if institution chooses to respond manually through existing official voice paths, subject to permissions.

### Activation Prompts

Recommended prompts:

- "Choose topics your institution participates in."
- "Add where your institution operates."
- "Choose how you want to participate."
- "Assign people who can respond officially."

Avoid:

- "Complete case routing setup."
- "Configure complaint intake."
- "Set department queue ownership."

## Patch 3 Readiness Review

### Result

**CONDITIONAL PASS**

Patch 3 can proceed after this framework if it remains scoped to participation, activation, and jurisdiction foundation. It must not implement routing.

### Readiness Assessment

| Area | Readiness | Explanation |
| --- | --- | --- |
| Participation model | Conditional pass | Modes and lifecycle are now defined, but exact schema/API contracts still need approval before implementation |
| Activation model | Conditional pass | Required stages and activation states are defined; implementation must avoid routing side effects |
| Global jurisdiction model | Conditional pass | Generic hierarchy is defined; exact storage and lookup strategy must be approved |
| Institution units | Pass for foundation | Existing unit CRUD and UI exist; Patch 3 can add optional participation relationships later |
| Onboarding model | Conditional pass | UX flow is defined; first implementation can be minimal and settings-driven |
| Existing assets | Pass | Verification, membership, ontology, units, and profile infrastructure are reusable |
| Routing dependency | Blocked | Patch 4 remains blocked by `AURA_PRE_IMPLEMENTATION_LOCK.md` |

### Patch 3 May Implement

Patch 3 may implement, after schema/API approval:

- participation declarations
- participation modes
- activation states
- global jurisdiction records
- institution jurisdiction declarations
- optional unit participation declarations
- participation lifecycle/audit
- onboarding/settings surfaces for participation

### Patch 3 Must Not Implement

Patch 3 must not implement:

- automatic routing
- route attempts
- public engagement queue generation
- routing confidence
- official response linkage as routing output
- commitment lifecycle
- public continuity panels derived from route items

## Files Inspected

Strategy documents:

- `aura_final/docs/strategy/AURA_STATE.md`
- `aura_final/docs/strategy/AURA_ACCOUNTABILITY_ROUTING_IMPLEMENTATION_FRAMEWORK.md`
- `aura_final/docs/strategy/AURA_CONTEXT_OWNERSHIP_RESOLUTION_FRAMEWORK.md`
- `aura_final/docs/strategy/AURA_PRE_IMPLEMENTATION_LOCK.md`

Backend:

- `aura-backend/prisma/schema.prisma`
- `aura-backend/src/institution-ontology/institution-ontology.ts`
- `aura-backend/src/institutions/institutions.controller.ts`
- `aura-backend/src/institutions/institutions.service.ts`
- `aura-backend/src/institutions/dto/institution-unit.dto.ts`

Frontend:

- `aura_final/lib/features/institution_ontology/models.dart`
- `aura_final/lib/features/institution_ontology/providers.dart`
- `aura_final/lib/features/institutions/domain/institution.dart`
- `aura_final/lib/features/institutions/units/institution_units_screen.dart`
- `aura_final/lib/features/institutions/units/institution_unit_card.dart`
- `aura_final/lib/features/institutions/presentation/institution_detail_screen.dart`
- `aura_final/lib/features/public/presentation/public_institution_units_screen.dart`
- `aura_final/lib/features/public/presentation/public_unit_detail_screen.dart`

## Final Recommendation

Proceed to Patch 3 only after approving exact schema/API contracts for:

- `InstitutionParticipation`
- `ParticipationMode`
- `InstitutionActivationState`
- `Jurisdiction`
- `InstitutionJurisdiction`
- optional `InstitutionUnitParticipation`
- participation lifecycle/audit
- onboarding/settings DTOs

Keep Patch 3 narrowly focused on institution participation and activation readiness. It should make institutions capable of becoming routable later, but it should not route any public records.

The correct implementation boundary is:

```txt
Patch 3 creates declared participation and activation.
Patch 4 consumes declared participation for routing after separate review.
```
