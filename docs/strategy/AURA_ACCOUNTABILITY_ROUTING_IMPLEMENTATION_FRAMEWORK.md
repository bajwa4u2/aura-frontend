# Aura Accountability/Routing Implementation Framework

Date: 2026-06-20

Status: Final doctrine alignment and implementation plan only. This document does not implement code, migrations, deployment changes, or commits.

Canonical source: `aura_final/docs/strategy/AURA_STATE.md`.

Progressive credibility alignment: read this framework through
`aura_final/docs/strategy/AURA_PROGRESSIVE_CREDIBILITY_DOCTRINE.md`.
Institution identity may be verified during onboarding, but credibility is
earned through observable behavior. Participation declarations create future
route eligibility; they do not by themselves create public trust,
commitments, or resolved accountability.

## Executive Summary

Aura is verified public communication infrastructure and an accountable public record. It is not a complaint portal, not a generic social network, and not an engagement feed.

The implementation framework should therefore start with the `PublicRecord`, not with an issue, queue, ticket, or routing object. `ASK`, `ISSUE`, and `UPDATE` are intents on that public record. Institution participation, jurisdiction, capability, and verification determine whether a public record becomes routable to an institution.

The public layer remains familiar:

- Ask
- Raise Issue
- Share Update
- Topic
- Discussion
- Official Response

The internal layer operates as infrastructure:

- Public Record
- Institution Participation
- Jurisdiction
- Capability / Assurance
- Routing
- Official Response
- Commitment
- Progress
- Resolution
- Verification / Dispute
- Continuity

Routing is not the first primitive. Routing is a downstream decision after the platform understands the public record, the author's capability, the selected topic, jurisdiction, and the participating institutions that have declared scope.

Patch 3 should therefore avoid a heavy setup ceremony. Institutions should be
able to verify identity, assign official representatives, and start
participating quickly. Topic, jurisdiction, unit, and accountability
declarations can be suggested and progressively confirmed before they are ever
used for routing.

## Final Doctrine

### What Aura Is

Aura is verified-identity public-communication infrastructure for institutions and the public. It creates a domain-verified institutional presence, official communication, typed accountability, and a public record of commitments, updates, and resolutions.

### What Aura Is Not

Aura is not:

- a complaint portal
- a generic social network
- a creator platform
- a customer support ticketing system
- a municipal case-management frontend
- an engagement feed optimized for attention

### Canonical Positioning

From `AURA_STATE.md`, the positioning to preserve is:

- verified identity
- official communication
- accountable public record
- typed accountability
- continuity
- institution as buyer
- public record, not engagement feed

### Language Doctrine

Public product language:

- Public Record
- Ask
- Raise Issue
- Share Update
- Topic
- Discussion
- Official Response
- Commitment
- Progress
- Resolved
- Continuity

Institution workspace language:

- Public Engagement
- Engagement
- Public Records
- Needs Response
- Open Commitments
- Official Responses
- Resolved Records

Internal engineering language:

- capability
- assurance
- institution participation
- participation mode
- jurisdiction
- routing
- routed record
- official response link
- commitment
- progress record
- continuity record

Avoid product-facing language:

- complaint
- ticket
- case
- SLA
- department queue
- assignee
- escalation
- routing confidence

## Public Record Model

### Core Principle

The core object is the public record.

An Aura public record is a durable public communication artifact with:

- author
- intent
- topic
- discussion thread
- optional jurisdiction
- optional public space
- official responses
- typed accountability events
- continuity

### Relationship to Existing `Post`

The existing `Post` model is the natural source object for public records. Do not create a parallel public complaint or request table as the public root.

Recommended concept:

- `Post` remains the public content row.
- A future `PublicRecord` can be a conceptual layer, view, or explicit table if the contract needs separation.
- If explicit, `PublicRecord` should reference `Post`, not replace it.

Minimum model:

- `Post.intent`
- `Post.primaryTopic`
- `Post.secondaryTopics`
- `Post.publicSpaceId`
- future `Post.jurisdictionId`

Optional explicit model later:

- `PublicRecord`
  - `id`
  - `postId`
  - `intent`
  - `topic`
  - `jurisdictionId`
  - `publicSpaceId`
  - `recordStatus`
  - `createdAt`
  - `updatedAt`

### Public Record Status

Public record status should be separate from private routing status.

Public-safe statuses:

- `PUBLISHED`
- `OFFICIAL_RESPONSE_ADDED`
- `COMMITMENT_MADE`
- `PROGRESS_UPDATED`
- `RESOLVED`
- `ANSWERED`
- `ARCHIVED`

Private/internal statuses can be richer, but should not leak to the public DTO.

## Intent Model

### Intents

`ASK`

- A question or request for explanation.
- Can become answered through an official response or community discussion.
- Does not imply institutional obligation by itself.

`ISSUE`

- A public record that raises a matter requiring institutional attention or accountability.
- Requires capability policy, not a hard-coded identity field.
- Can create a path to commitment, progress, resolution, verification, dispute, and continuity.

`UPDATE`

- A public record sharing new information.
- Can reference institutions or topics.
- Can be routed or surfaced to participating institutions, but does not imply required action.

### Intent Is Not the Lifecycle

Intent describes the author's public communication mode. Lifecycle describes what happens after publication.

Do not make `ISSUE` the center of the architecture. `ISSUE` is one intent on a public record.

## Capability Matrix

### Capability-Based Assurance

Do not hard-code `EMAIL_VERIFIED` or `PHONE_VERIFIED` as permanent business logic. These are possible evidence sources. Business rules should check capabilities.

Capabilities:

- `CAN_ASK`
- `CAN_SHARE_UPDATE`
- `CAN_COMMENT`
- `CAN_RAISE_ISSUE`
- `CAN_RESPOND_OFFICIALLY`
- `CAN_COMMIT`
- `CAN_RESOLVE`
- `CAN_VERIFY_RESOLUTION`
- `CAN_DISPUTE_RESOLUTION`
- `CAN_MANAGE_INSTITUTION_PARTICIPATION`
- `CAN_VIEW_PUBLIC_ENGAGEMENT`

Assurance levels may grant capabilities through policy:

- account exists
- terms accepted
- email verified
- phone verified
- age assured
- identity assured
- institution member
- institution official actor
- institution admin/owner
- platform admin

### Capability Matrix

| Capability | Anonymous | Basic member | Assured member | Institution member | Institution official actor | Institution admin/owner | Platform admin |
|---|---:|---:|---:|---:|---:|---:|---:|
| `CAN_ASK` | No | Yes | Yes | Yes | Yes | Yes | Yes |
| `CAN_SHARE_UPDATE` | No | Yes | Yes | Yes | Yes | Yes | Yes |
| `CAN_COMMENT` | No | Yes | Yes | Yes | Yes | Yes | Yes |
| `CAN_RAISE_ISSUE` | No | Policy-dependent | Yes | Policy-dependent | Policy-dependent | Policy-dependent | Yes |
| `CAN_RESPOND_OFFICIALLY` | No | No | No | If granted | Yes | Yes | Admin override only |
| `CAN_COMMIT` | No | No | No | No by default | Policy-dependent | Yes | Admin override only |
| `CAN_RESOLVE` | No | No | No | No by default | Policy-dependent | Yes | Yes |
| `CAN_VERIFY_RESOLUTION` | No | Own record if policy allows | Own record if policy allows | Own record if policy allows | Own record if policy allows | Yes for institution-owned records | Yes |
| `CAN_DISPUTE_RESOLUTION` | No | Own record | Own record | Own record | Own record | Institution can reopen internally | Yes |
| `CAN_MANAGE_INSTITUTION_PARTICIPATION` | No | No | No | No | No | Yes | Yes |
| `CAN_VIEW_PUBLIC_ENGAGEMENT` | No | No | No | Yes | Yes | Yes | Yes |

### Enforcement Points

Backend:

- publish public record
- select `ISSUE` intent
- create official response
- create commitment
- add progress
- resolve
- verify/dispute
- manage participation

Frontend:

- composer affordances
- verification/capability prompts
- disabled states
- institution workspace action visibility

Rule: frontend helps, backend enforces.

## Institution Participation and Obligation Model

### Core Principle

Institution participation comes before routing.

Routing must depend on:

- institution participation
- topic
- jurisdiction
- capability
- verification

Only after those are evaluated should the system create internal public-engagement/routed-record items.

### Participation Is Not Automatic Legal Obligation

Participation does not automatically create legal obligation, service-level obligation, or statutory responsibility.

Aura creates:

- visible institutional presence
- official communication paths
- accountable public record
- typed accountability when an institution chooses to respond, commit, update, or resolve

Aura does not claim:

- legal liability
- agency jurisdiction certainty
- guaranteed institutional action
- SLA compliance
- complaint adjudication

### Participation Modes

`LISTENING`

- Institution wants visibility into relevant public records.
- Records may appear in internal Public Engagement surfaces.
- No expected public action.
- Public label should not imply response expectation.

`RESPONDING`

- Institution accepts relevant Ask/Update records for possible official response.
- Records can appear as Needs Response.
- Expected action: official response when appropriate.
- Does not imply commitment.

`ACCOUNTABLE`

- Institution accepts relevant Issue records for public accountability workflow.
- Records can progress to official response, commitment, progress, resolution, verification/dispute, and continuity.
- Expected action: acknowledge/respond where appropriate, and honor any commitment it creates.
- Still not a legal obligation by platform language alone.

`REFERENCE_ONLY`

- Institution is relevant context but does not receive a work item by default.
- Used for related-institution panels, public context, and continuity.
- No expected action.

### Institution Participation Model

Recommended model: `InstitutionParticipation`.

Fields:

- `id`
- `institutionId`
- `unitId`
- `topic`
- `intentScope`
- `participationMode`
- `jurisdictionId`
- `publicSpaceId`
- `domainTag`
- `priority`
- `active`
- `verifiedByAdminAt`
- `createdByUserId`
- `updatedByUserId`
- `createdAt`
- `updatedAt`

### Topic Ownership

Use "participation" as the main product concept. Use "topic ownership" only if a stronger admin-reviewed claim is required.

Possible future `InstitutionTopicClaim`:

- `CLAIMED`
- `VERIFIED`
- `DISPUTED`
- `REVOKED`

Public copy should say "Participates in" or "Responds on", not "owns complaints for".

## Jurisdiction Model

### Core Principle

Jurisdiction narrows institutional relevance. It prevents global broadcast.

Routing should prefer explicit user-selected jurisdiction over inferred location.

### Existing Support

Current fields already exist:

- `User.city`
- `User.country`
- `Institution.jurisdiction`
- `Institution.location`
- `Institution.city`
- `Institution.region`
- `Institution.country`
- `InstitutionUnit.city`
- `InstitutionUnit.region`
- `InstitutionUnit.country`
- `InstitutionVerificationRequest.jurisdiction`
- `PublicSpace`
- `Post.publicSpaceId`

### Missing Support

Needed:

- normalized `Jurisdiction`
- institution-to-jurisdiction joins
- public-space-to-jurisdiction joins
- post/public-record jurisdiction
- location source and visibility controls

### Proposed Hierarchy

`JurisdictionType`:

- `GLOBAL`
- `COUNTRY`
- `REGION`
- `CITY`
- `DISTRICT`
- `CAMPUS`
- `CUSTOM`

`Jurisdiction` fields:

- `id`
- `type`
- `name`
- `slug`
- `countryCode`
- `regionCode`
- `parentId`
- `geoJson`
- `centroidLat`
- `centroidLng`
- `active`

### Public UX

Ask only when useful:

- "Where is this about?"
- "Use my city"
- "Choose a place"
- "Not location-specific"

Public labels:

- "In New York"
- "In California"
- "Global"

Never show internal jurisdiction IDs publicly.

## Routing Model

### Routing Position in Architecture

Routing is downstream of:

1. Public Record
2. Intent
3. Capability
4. Topic
5. Jurisdiction
6. Institution Participation
7. Institution verification/eligibility

Routing is not the first architectural primitive.

### Deterministic First

Initial routing should be deterministic.

AI can later assist:

- topic suggestion
- jurisdiction suggestion
- summary
- ambiguity detection
- candidate explanation

AI should not be authoritative for first-pass routing.

### Routing Decision Order

1. Confirm public record is eligible:
   - top-level public record
   - valid intent
   - primary topic
   - author has required capability
   - not deleted, blocked, or moderation-held
2. Resolve jurisdiction:
   - explicit record jurisdiction
   - public space jurisdiction
   - user-selected location
   - no jurisdiction if global/nonlocal
3. Find institution participation:
   - active participation rows
   - topic match
   - intent scope match
   - jurisdiction overlap
   - participation mode supports action
4. Apply institution eligibility:
   - verified or allowed by policy
   - not suspended
   - domain trust acceptable for official paths
   - official voice capability where response/commitment is expected
5. Apply explicit context:
   - institution mention
   - institution profile context
   - public space context
   - follows as weak signal only
6. Create internal routed/public-engagement record:
   - idempotently
   - with routing reason
   - with private routing metadata

### Routing Outputs

Prefer internal name:

- `RoutedPublicRecord`
- `PublicEngagementItem`

Acceptable engineering model:

- `RoutedAttentionItem`

Product-facing workspace label should be:

- Public Engagement
- Public Records
- Needs Response
- Open Commitments

Avoid using "Attention" as primary product-facing label unless it is internal-only.

### Idempotency

Rules:

- one active routed item per public record and institution
- retries do not duplicate
- changes create routing attempts/audit records
- rerouting closes or supersedes prior active route explicitly

### Failure Behavior

Publishing should not fail because routing fails.

Behavior:

- public record publishes
- routing attempt logs success/failure
- retry worker can process failed routing
- public user does not see internal routing failure

## Lifecycle Model

### Lifecycle Is Based on Public Record + Intent

The lifecycle belongs to the public record and its institution participation, not to a complaint ticket.

### Lifecycle Matrix

| Intent | Internal lifecycle | Public labels |
|---|---|---|
| ASK | Published -> Matched -> Official Response -> Answered/Closed | Asked -> Official Response -> Answered |
| ISSUE | Published -> Matched -> Needs Response -> Official Response -> Commitment -> Progress -> Resolved -> Verified/Disputed -> Closed | Issue Raised -> Official Response -> Commitment -> Update -> Resolved |
| UPDATE | Published -> Matched/Referenced -> Archived | Update Shared -> Discussion -> Archived |

### Internal Status Enum

Recommended internal statuses:

- `PUBLISHED`
- `MATCHED`
- `NEEDS_RESPONSE`
- `RESPONDED`
- `COMMITMENT_MADE`
- `IN_PROGRESS`
- `RESOLVED`
- `VERIFICATION_REQUESTED`
- `VERIFIED`
- `DISPUTED`
- `REOPENED`
- `CLOSED`
- `ARCHIVED`
- `MISROUTED`
- `DECLINED`

### Public Status Labels

Public labels:

- Published
- Asked
- Issue Raised
- Update Shared
- Official Response
- Commitment
- Progress Update
- Resolved
- Answered
- Follow-up Requested
- Archived

### Transition Rules

ASK:

- can be answered by official response.
- can close after official response or author acknowledgement.
- should not create commitment unless institution explicitly chooses one.

ISSUE:

- requires `CAN_RAISE_ISSUE`.
- can be matched only to `ACCOUNTABLE` participation unless policy allows `RESPONDING`.
- commitment can be created only by authorized institution actor.
- progress must attach to a commitment or official response.
- resolution can be verified, disputed, reopened, or closed.

UPDATE:

- can be matched or referenced.
- should not imply required action.
- can receive official response if institution chooses.

## Public/Private Visibility Model

### Principle

Public record is public. Internal processing is not.

### Visibility Matrix

| Data | Public | Institution workspace | Admin |
|---|---:|---:|---:|
| public record text | Yes | Yes | Yes |
| intent | Yes | Yes | Yes |
| topic | Yes | Yes | Yes |
| public location label | If allowed | Yes | Yes |
| jurisdiction ID | Usually no | Yes | Yes |
| institution participation mode | Public summary optional | Yes | Yes |
| routing reason | No | Yes, simplified | Yes |
| routing confidence | Never | No | Yes |
| internal assignee | Never | Yes | Yes |
| private notes | Never | Yes | Yes |
| internal decline reason | Never | Yes | Yes |
| capability raw evidence | Never | No | Restricted |
| identity/age provider details | Never | Never | Restricted audit only |
| official response | Yes | Yes | Yes |
| commitment/progress/resolution | Yes, public-safe | Yes | Yes |
| dispute state | Public-safe label | Yes | Yes |

### Public DTO

Public DTO should include:

- public record id
- post id
- intent
- topic
- public location label
- public status
- official responses
- commitments
- progress updates
- resolution
- continuity timeline

Public DTO must exclude:

- routing confidence
- internal assignee
- private notes
- internal decline reason
- raw assurance evidence
- age/identity details
- private routing rule metadata

### Institution DTO

Institution DTO can include:

- source public record
- routing reason
- participation match
- status
- action availability
- internal notes
- assigned member
- official responses
- commitments
- progress
- disputes

### Admin DTO

Admin DTO can include:

- route attempts
- policy decisions
- rule IDs
- routing confidence
- audit events
- redacted assurance references
- moderation state

## Commitment and Continuity Model

### Commitment Definition

A commitment is an institution-authored accountability object. It records what an institution has publicly or institutionally committed to do.

It must be tied to:

- public record
- institution
- official response or institution actor
- continuity timeline

### Commitment Fields

Recommended `Commitment` fields:

- `id`
- `publicRecordId`
- `sourcePostId`
- `institutionId`
- `officialResponseLinkId`
- `summary`
- `body`
- `status`
- `dueAt`
- `visibility`
- `createdByUserId`
- `resolvedAt`
- `closedAt`
- `withdrawnAt`
- `withdrawalReason`
- `createdAt`
- `updatedAt`

Statuses:

- `OPEN`
- `IN_PROGRESS`
- `RESOLVED`
- `CLOSED`
- `WITHDRAWN`
- `DISPUTED`

### Progress Fields

Recommended `CommitmentProgress` fields:

- `id`
- `commitmentId`
- `publicRecordId`
- `institutionId`
- `officialResponseLinkId`
- `summary`
- `body`
- `statusAfterUpdate`
- `createdByUserId`
- `createdAt`

### Continuity Model

Continuity is the public institutional memory of the record.

Minimum derived endpoint first:

- `GET /public-records/:id/continuity`

or compatibility:

- `GET /feed/items/:type/:id/continuity`
- `GET /posts/:postId/continuity`

Continuity response:

- source public record
- intent
- topic
- public status
- official responses
- commitments
- progress
- resolution
- verification/dispute state
- timeline

Long-term:

- add append-only `ContinuityEvent` if derived reconstruction becomes complex.
- add materialized read model if public profiles/discourse intelligence need faster reads.

## Revised Implementation Patch Order

### Patch 1: Public Record Intent Contract

Goal:

- persist public record intent and topic without routing.

Backend:

- add `PostIntent`.
- add `Post.intent`.
- validate top-level public records.
- require intent and primary topic behind feature flag.

Frontend:

- send intent.
- require topic and intent for top-level publish.
- keep public language social.

### Patch 2: Capability Policy

Goal:

- replace hard-coded verification assumptions with capability checks.

Backend:

- add capability policy service.
- map existing account/email/phone/institution state to capabilities.
- enforce `CAN_RAISE_ISSUE`, `CAN_RESPOND_OFFICIALLY`, `CAN_COMMIT`, `CAN_RESOLVE`.

Frontend:

- read/display capabilities.
- gate actions by capability.

### Patch 3: Institution Participation and Obligation Modes

Goal:

- let institutions declare how they participate before routing exists.

Backend:

- add `InstitutionParticipation`.
- add participation modes: `LISTENING`, `RESPONDING`, `ACCOUNTABLE`, `REFERENCE_ONLY`.
- add management APIs for institution admins.

Frontend:

- add workspace settings under institution profile or Public Engagement settings.
- show participation summary on public profile only where appropriate.

### Patch 4: Jurisdiction Foundation

Goal:

- support scoped public records and scoped institution participation.

Backend:

- add `Jurisdiction`.
- add joins for institutions, public spaces, and public records.
- add location source/visibility fields.

Frontend:

- add "Where is this about?" composer affordance where required.

### Patch 5: Routing Service and Routed Public Records

Goal:

- route eligible public records after participation, topic, jurisdiction, capability, and verification are known.

Backend:

- add deterministic routing service.
- add internal routed/public-engagement item.
- add route attempts.
- run behind feature flag.

Frontend:

- no public UI change.

### Patch 6: Institution Public Engagement Workspace

Goal:

- expose routed public records privately to institutions.

Backend:

- add list/detail/counter APIs.
- use product-facing concepts: Public Engagement, Public Records, Needs Response, Open Commitments.

Frontend:

- add institution workspace section.
- avoid primary label "Attention" unless internal.

### Patch 7: Official Response Linkage

Goal:

- connect official institution responses to public records.

Backend:

- add `OfficialResponseLink`.
- reuse existing official voice reply path.
- update routed record status.

Frontend:

- add official response action from Public Engagement detail.
- public thread renders official response normally.

### Patch 8: Commitment, Progress, Resolution, Verification/Dispute

Goal:

- make typed accountability durable.

Backend:

- add `Commitment`.
- add `CommitmentProgress`.
- add resolution, verification, dispute, reopen, close transitions.
- map existing COMMITMENT / UPDATE / RESOLVED tags as compatibility display.

Frontend:

- institution controls for commitment/progress/resolution.
- public continuity labels remain calm.

### Patch 9: Continuity Endpoint and Public Record Panels

Goal:

- expose accountable public record without exposing private processing.

Backend:

- add continuity endpoint.
- update discourse intelligence to prefer canonical records.

Frontend:

- add public continuity panel.
- add institution continuity/history view.

## Explicit Non-Goals

This framework does not propose:

- turning Aura into a complaint portal
- replacing public posts with complaint/case records
- exposing ticket/case/SLA language
- making institution participation a legal obligation
- making AI authoritative for routing
- exposing routing confidence publicly
- exposing internal assignees or private notes publicly
- hard-coding email or phone verification as permanent business logic
- duplicating public records into institution posts as a new source of truth
- building full identity/age vendor integration before capability policy exists
- making public record continuity a gamified score or ranking

## Files Referenced

Canonical strategy:

- `aura_final/docs/strategy/AURA_STATE.md`

Prior framework documents:

- `aura_final/docs/AURA_ACCOUNTABILITY_ROUTING_AUDIT_PROPOSAL.md`
- `aura_final/docs/strategy/AURA_ACCOUNTABILITY_ROUTING_FRAMEWORK_ADDENDUM.md`

Backend references:

- `aura-backend/prisma/schema.prisma`
- `aura-backend/src/posts/posts.controller.ts`
- `aura-backend/src/posts/posts.service.ts`
- `aura-backend/src/posts/dto/create-post.dto.ts`
- `aura-backend/src/institutions/posts/institution-posts.controller.ts`
- `aura-backend/src/institutions/posts/institution-posts.service.ts`
- `aura-backend/src/institutions/activity/institution-activity.controller.ts`
- `aura-backend/src/institutions/activity/institution-activity.service.ts`
- `aura-backend/src/discourse-intelligence/discourse-intelligence.controller.ts`
- `aura-backend/src/discourse-intelligence/discourse-intelligence.service.ts`
- `aura-backend/src/institution-ontology/institution-ontology.ts`

Frontend references:

- `aura_final/lib/router.dart`
- `aura_final/lib/features/posts/presentation/compose_screen.dart`
- `aura_final/lib/features/topics/topic.dart`
- `aura_final/lib/features/topics/aura_topic_selector.dart`
- `aura_final/lib/features/institutions/presentation/institution_dashboard_screen.dart`
- `aura_final/lib/features/institutions/activity/institution_activity_screen.dart`
- `aura_final/lib/features/institutions/data/institutions_repository.dart`
- `aura_final/lib/features/public/presentation/thread_screen.dart`
- `aura_final/lib/features/public/widgets/reply_unit.dart`
- `aura_final/lib/features/public/widgets/institution_action_sheet.dart`
- `aura_final/lib/features/discourse_intelligence/providers.dart`
- `aura_final/lib/features/discourse_intelligence/widgets/discourse_continuity_panel.dart`
