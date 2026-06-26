# Aura Accountability/Routing Framework Addendum

Date: 2026-06-20

Status: Audit and implementation plan only. No application code, migrations, commits, or deploys are included in this addendum.

Location note: this file lives under `aura_final/docs/strategy/` because the Aura operating guide allows Codex file work only inside `aura_final/` and `aura-backend/`.

## Executive Summary

The prior `AURA_ACCOUNTABILITY_ROUTING_AUDIT_PROPOSAL.md` correctly identified the missing engine: Aura has a social public composer and significant institutional/accountability primitives, but it does not yet have a canonical model that carries a public Ask, Raise Issue, or Share Update into institutional attention, official response, commitment, progress, resolution, verification/dispute, and durable continuity.

This addendum makes the missing framework decisions explicit before implementation:

- Public Aura should keep social language: Ask, Raise Issue, Share Update, Topic, Discussion, Official response.
- Internal Aura should operate as accountability infrastructure: identity assurance, topic and jurisdiction routing, institution participation, official response, commitment, progress, resolution, verification/dispute, and continuity record.
- Public users should not see ticket, case, SLA, department, assignment, routing confidence, or internal workflow language.
- The first implementation should be deterministic and rules-based. AI can later assist classification or summaries, but routing authority should begin with explicit data: user capability, post intent, topic, jurisdiction, public space, institution participation declarations, institution verification, domain trust, and official voice rights.

The core additions should be:

- `PostIntent`
- user assurance/capability model
- institution participation/topic ownership model
- jurisdiction hierarchy
- deterministic routing service
- `RoutedAttentionItem`
- official response link
- commitment/progress/resolution objects
- public-safe continuity endpoint

## Framework Decisions

### Product Doctrine

Decision: public Aura remains a social discourse product.

Public language:

- Ask
- Raise Issue
- Share Update
- Topic
- Discussion
- Official response
- Update
- Resolved
- Answered

Internal language:

- attention item
- routing rule
- institution participation
- official response link
- commitment
- progress
- resolution
- verification
- dispute
- continuity record

Forbidden or avoided public language:

- ticket
- case
- SLA
- department queue
- assignee
- escalation
- complaint portal
- routing confidence

### Architecture Doctrine

Decision: public posts stay public posts. Do not duplicate public roots into institution posts.

Recommended shape:

- `Post` remains the source object for public Ask, Issue, and Update.
- Institution official responses are replies, linked through a canonical `OfficialResponseLink`.
- `RoutedAttentionItem` is the private work object for the institution.
- `Commitment` and `CommitmentProgress` are durable lifecycle objects.
- Public continuity is derived from safe fields, not from the private queue DTO.

### Enforcement Doctrine

Decision: enforce capabilities at the backend, guide users in the frontend.

Frontend should:

- show the right affordances
- explain verification requirements
- block invalid submission early

Backend must:

- validate intent and topic
- enforce capability gates
- enforce institution role/official voice permissions
- strip private fields from public DTOs

## 1. Participation and Identity Rights

### Existing Support

Public user identity support already exists in the backend:

- `User.email`
- `User.emailVerifiedAt`
- `User.disabledAt`
- `User.termsAcceptedAt`
- `User.termsAcceptedVersion`
- `User.phoneNumberE164`
- `User.phoneVerifiedAt`
- `User.phoneCountryCode`
- `User.phoneHash`
- `PhoneVerificationAttempt`
- `PhoneAbuseSignal`
- `UserContactDiscoveryConsent`
- login/session/trusted-device models
- moderation report/action models
- admin grant/audit models

Institution identity support already exists:

- `Institution.status`
- `Institution.verifiedAt`
- `Institution.domainVerifiedAt`
- `Institution.isVerified`
- `Institution.canSpeakOfficially`
- `InstitutionVerificationRequest`
- `InstitutionDomain`
- `InstitutionDomainVerificationAttempt`
- `InstitutionDomainAuditLog`
- `InstitutionMember.role`
- `InstitutionMember.canSpeakOfficially`
- `InstitutionRoleGuard`
- official voice checks in institution post/reply paths

Frontend support exists for:

- institution verification screens
- institution dashboard standing
- institution role and official speech status
- security/session surfaces
- identity badges

### Missing Support

Public members do not currently have a normalized assurance level.

Missing:

- `UserAssuranceLevel` enum
- durable user assurance records
- current effective user capability map
- policy flags for feature-gated verification requirements
- explicit "Raise Issue requires verified member" enforcement
- future age assurance fields/provider records
- public-safe explanation of assurance requirements

Current email and phone verification are useful primitives, but they are not yet expressed as a product-level assurance model.

### Proposed Assurance Levels

Add a stable assurance ladder that can absorb future verification providers without redesign:

- `ANONYMOUS_VIEWER`: no account; can read public content where allowed.
- `BASIC_MEMBER`: account exists, accepted terms, not disabled.
- `EMAIL_VERIFIED`: email verified.
- `PHONE_VERIFIED`: phone verified.
- `IDENTITY_ASSURED`: stronger identity proof from future provider.
- `AGE_ASSURED`: age threshold confirmed without exposing date of birth publicly.
- `INSTITUTION_VERIFIED_MEMBER`: verified member of an institution.
- `OFFICIAL_INSTITUTION_ACTOR`: can speak officially for an institution.

Important: assurance should be additive and policy-driven. Do not hard-code permanent meaning into a single boolean.

### Proposed Capability Matrix

| Capability | Anonymous | Basic member | Email verified | Phone verified | Identity assured | Institution official |
|---|---:|---:|---:|---:|---:|---:|
| Read public posts | Yes | Yes | Yes | Yes | Yes | Yes |
| Like/save/follow | No | Yes | Yes | Yes | Yes | Yes |
| Ask | No | Yes | Yes | Yes | Yes | Yes |
| Share Update | No | Yes | Yes | Yes | Yes | Yes |
| Comment/reply | No | Yes | Yes | Yes | Yes | Yes |
| Raise Issue | No | Feature flag decides | Recommended minimum | Preferred minimum | Yes | Yes when acting as user |
| Official institution response | No | No | No | No | No | Role and official voice required |
| Make commitment | No | No | No | No | No | Institution admin/authorized speaker |
| Resolve/close institutional item | No | No | No | No | No | Institution admin/owner |
| Dispute/reopen own issue | No | Own item only | Own item only | Own item only | Own item only | Own item only unless admin |

Initial recommendation:

- Basic members can Ask, Share Update, comment, reply.
- Raise Issue requires `EMAIL_VERIFIED` at minimum.
- A feature flag can temporarily allow Basic members to Raise Issue while verification UX is incomplete.
- Later policy can raise the requirement to `PHONE_VERIFIED`, `IDENTITY_ASSURED`, or `AGE_ASSURED` for selected jurisdictions/topics.

### Enforcement Points

Backend:

- `PostsController` / `PostsService`: validate intent and capability on publish.
- draft save can allow incomplete intent/topic but publish must enforce.
- routing service: only route an Issue if capability gate passes.
- moderation service: can use assurance in abuse controls.
- guards/policies: introduce an `IntentCapabilityGuard` or policy service rather than scattering checks.

Frontend:

- composer intent row: show Raise Issue as available only when user capability permits.
- publish button: block with a verification prompt if capability is missing.
- profile/security: show verification status and next step.
- route guard: do not rely on route guard alone; final enforcement stays backend-side.

## 2. Institution Participation and Topic Ownership

### Existing Support

Institution metadata already includes:

- `Institution.category`
- `Institution.institutionClass`
- `Institution.institutionType`
- `Institution.domainTags`
- `Institution.jurisdiction`
- `Institution.location`
- `Institution.city`
- `Institution.region`
- `Institution.country`
- `Institution.status`
- `Institution.isVerified`
- `Institution.canSpeakOfficially`
- `InstitutionUnit`
- `InstitutionDomain`
- institution profile edit flows
- institution ontology endpoint
- public spaces

This is strong descriptive metadata.

### Missing Support

Institutions cannot yet explicitly declare:

- "we participate in this public topic"
- "we accept routed Issues for this topic"
- "we answer Ask posts in this scope"
- "we cover this jurisdiction"
- "this unit owns this topic"
- "we participate only for campus/region/city/country"
- "we do not participate in this topic"

`domainTags` are not enough. They describe institutional remit but do not express operational participation or routing consent.

### Proposed InstitutionParticipation / TopicOwnership Model

Recommended model: `InstitutionParticipation`.

Core fields:

- `id`
- `institutionId`
- `unitId`
- `topic`
- `intentScope`: ASK, ISSUE, UPDATE, ALL
- `participationMode`: LISTENING, RESPONDING, ACCOUNTABLE, REFERENCE_ONLY
- `jurisdictionId`
- `publicSpaceId`
- `domainTag`
- `priority`
- `active`
- `startsAt`
- `endsAt`
- `createdByUserId`
- `updatedByUserId`
- `createdAt`
- `updatedAt`

Recommended enum meanings:

- `LISTENING`: institution wants visibility but not default routing.
- `RESPONDING`: institution can answer Ask/Update items.
- `ACCOUNTABLE`: institution accepts Issue routing and commitment lifecycle.
- `REFERENCE_ONLY`: can appear in related institutions or continuity, but not receive work.

Optional later model: `InstitutionTopicOwnership`.

Use it if participation needs stronger public claims:

- `CLAIMED`
- `VERIFIED`
- `DISPUTED`
- `REVOKED`

Initial recommendation:

- Implement `InstitutionParticipation` first.
- Keep "ownership" language internal/admin-only.
- Public UI can say "Participates in" or "Responds on".

### Admin/Workspace UI Representation

Institution workspace should add a "Participation" settings surface, possibly under profile or future attention settings.

Fields:

- Topic
- What this institution does on Aura:
  - listens
  - responds
  - accepts issue routing
  - reference only
- Scope:
  - global
  - country
  - region/state
  - city
  - district/campus
  - custom jurisdiction
- Optional unit
- Active toggle

Public profile representation should be lighter:

- "Participates in: Housing, Transportation, Public Safety"
- "Responds in: New York City"
- Do not say "owns complaints for".

### Migration Path

1. Seed `InstitutionParticipation` from existing `domainTags` where confidence is high, but default to `LISTENING` or `REFERENCE_ONLY`.
2. Let institution admins confirm topics in workspace.
3. Make `ACCOUNTABLE` routing opt-in for verified institutions.
4. Use admin review for high-risk institution classes/topics.

## 3. Jurisdiction and Geography

### Existing Support

Users:

- `User.city`
- `User.country`

Institutions:

- `Institution.jurisdiction`
- `Institution.location`
- `Institution.city`
- `Institution.region`
- `Institution.country`

Institution units:

- `InstitutionUnit.address`
- `InstitutionUnit.city`
- `InstitutionUnit.region`
- `InstitutionUnit.country`

Institution verification requests:

- `InstitutionVerificationRequest.jurisdiction`

Public spaces:

- `PublicSpace` has name/slug/description but no explicit geography fields.

Posts:

- `Post.publicSpaceId`
- `Post.primaryTopic`
- no explicit jurisdiction or geo scope fields.

### Missing Support

Missing:

- normalized jurisdiction hierarchy
- post-level jurisdiction/scope selection
- public space geography
- location confidence/source fields
- user-selected issue location separate from profile location
- campus/district concepts
- routeable administrative levels

### Proposed Jurisdiction Hierarchy

Add `Jurisdiction` as a normalized table.

Recommended fields:

- `id`
- `type`: GLOBAL, COUNTRY, REGION, CITY, DISTRICT, CAMPUS, CUSTOM
- `name`
- `slug`
- `countryCode`
- `regionCode`
- `parentId`
- `geoJson`
- `centroidLat`
- `centroidLng`
- `active`
- `createdAt`
- `updatedAt`

Common hierarchy:

- Global
- Country
- Region/state/province
- City/municipality
- District/neighborhood
- Campus/facility
- Custom service area

Add joins:

- `InstitutionJurisdiction`
- `PublicSpaceJurisdiction`
- `PostJurisdiction` or nullable `Post.jurisdictionId`
- `InstitutionParticipation.jurisdictionId`

### Required Fields

For posts:

- `jurisdictionId`
- `locationLabel`
- `locationSource`: USER_SELECTED, PROFILE_DEFAULT, PUBLIC_SPACE_DEFAULT, INFERRED, NONE
- `locationVisibility`: PUBLIC_LABEL, PRIVATE_TO_ROUTING, NONE

For institutions:

- keep existing string fields
- add normalized jurisdiction joins
- allow one primary jurisdiction and multiple service jurisdictions

For public spaces:

- optional jurisdiction
- optional topic focus

### Routing Impact

Routing should avoid global broadcast.

Routing should prefer:

1. explicit post jurisdiction
2. public space jurisdiction
3. user-selected location in composer
4. profile city/country as fallback only when user confirms
5. global only for intentionally global public spaces/topics

Routing should match institutions where:

- participation topic matches
- intent scope matches
- jurisdiction overlaps
- institution is verified or otherwise allowed
- participation mode is sufficient

### Public UX Impact

Public composer should ask for location only when needed.

Recommended copy:

- "Where is this about?"
- "Use my city"
- "Choose a place"
- "Not location-specific"

Avoid:

- jurisdiction filing
- service area selection
- department region

Public card can show:

- "In Brooklyn"
- "In California"
- "Global discussion"

It should not expose internal routing region IDs.

## 4. Routing Logic

### Proposed Routing Decision Order

Routing should be deterministic rules first.

Decision order:

1. Validate source post:
   - top-level public post
   - persisted intent
   - primary topic present
   - author capability permits selected intent
   - post is not deleted/hidden/moderation-blocked
2. Resolve scope:
   - explicit post jurisdiction
   - public space jurisdiction
   - user-confirmed location
   - no jurisdiction if global/nonlocal
3. Resolve candidate institutions:
   - active `InstitutionParticipation`
   - matching topic
   - matching intent scope
   - matching jurisdiction or parent/child overlap
   - participation mode sufficient for intent
4. Apply institution eligibility:
   - institution status verified or allowed
   - domain trust acceptable
   - official voice enabled for response/commitment paths
   - not suspended
5. Apply explicit context:
   - direct mention of institution
   - post in institution public space/profile context
   - user follows or institution follows thread as weak signal
6. Rank:
   - exact jurisdiction match
   - topic/intent exactness
   - participation priority
   - verified status
   - explicit mention
   - recency/activity can break ties
7. Create routed attention item:
   - one per source/institution
   - idempotent
   - record rule and reason
8. Notify institution members according to preferences.

AI later:

- suggest topic
- suggest jurisdiction from text
- summarize issue
- detect likely institutions
- flag routing ambiguity

AI should not be the first source of routing authority.

### Proposed Tables and Services

Tables:

- `PostIntent` enum
- `UserAssuranceLevel` enum or assurance records
- `InstitutionParticipation`
- `Jurisdiction`
- `InstitutionJurisdiction`
- `PublicSpaceJurisdiction`
- `RoutedAttentionItem`
- `RoutingAttempt`
- `OfficialResponseLink`
- `Commitment`
- `CommitmentProgress`
- `ContinuityEvent` later if needed

Services:

- `IdentityAssuranceService`
- `IntentCapabilityPolicyService`
- `InstitutionParticipationService`
- `JurisdictionService`
- `RoutingService`
- `AttentionService`
- `OfficialResponseLinkService`
- `CommitmentService`
- `ContinuityService`

### Feature Flags

Recommended flags:

- `ACCOUNTABILITY_INTENT_REQUIRED`
- `RAISE_ISSUE_REQUIRES_VERIFICATION`
- `ACCOUNTABILITY_ROUTING_ENABLED`
- `INSTITUTION_PARTICIPATION_ENABLED`
- `ATTENTION_WORKSPACE_ENABLED`
- `OFFICIAL_RESPONSE_LINKING_ENABLED`
- `COMMITMENTS_ENABLED`
- `PUBLIC_CONTINUITY_ENABLED`
- `AI_ROUTING_ASSIST_ENABLED`

### Idempotency Rules

Core uniqueness:

- one `RoutedAttentionItem` per source post and institution
- one active route per source post, institution, intent, topic combination unless rerouted
- routing attempts logged separately

Recommended unique key:

- `(sourceType, sourcePostId, routedInstitutionId)` where sourcePostId is not null

Retry behavior:

- routing can retry after transient failure
- duplicate insert should become no-op
- changed topic/jurisdiction can create reroute attempt but should not silently duplicate active attention items

### Failure and Retry Behavior

Routing must not block publishing.

Behavior:

- publish succeeds
- routing runs after commit
- failure logs `RoutingAttempt` with reason
- retry worker can process failed attempts
- user does not see routing failure publicly
- institution does not see item until route is created

## 5. Lifecycle Model

### Status Enums

Use separate lifecycle states by intent, but store a common internal enum for attention items.

Common internal enum:

- `CREATED`
- `ROUTED`
- `SEEN`
- `ACKNOWLEDGED`
- `ANSWERED`
- `COMMITMENT_MADE`
- `IN_PROGRESS`
- `RESOLVED`
- `VERIFIED`
- `DISPUTED`
- `REOPENED`
- `CLOSED`
- `ARCHIVED`
- `DECLINED`
- `MISROUTED`

### Lifecycle Matrix

| Intent | Internal lifecycle | Public labels |
|---|---|---|
| ASK | CREATED -> ROUTED -> ANSWERED -> CLOSED | Asked -> Official response -> Answered |
| ISSUE | CREATED -> ROUTED -> ACKNOWLEDGED -> COMMITMENT_MADE -> IN_PROGRESS -> RESOLVED -> VERIFIED -> CLOSED | Issue raised -> Official response -> Commitment -> Update -> Resolved |
| ISSUE dispute | RESOLVED -> DISPUTED -> REOPENED -> IN_PROGRESS/RESOLVED | Resolved -> Follow-up requested -> Updated |
| UPDATE | PUBLISHED -> ROUTED/REFERENCED -> ARCHIVED | Update shared -> Seen by institution -> Archived |

### Actor Permissions

| Action | Public author | Other public member | Institution member | Institution editor | Institution admin/owner | Platform admin |
|---|---:|---:|---:|---:|---:|---:|
| Ask | Yes | Yes | Yes as user | Yes as user | Yes as user | Yes |
| Raise Issue | If verified | If verified | If verified | If verified | If verified | Yes |
| Share Update | Yes | Yes | Yes | Yes | Yes | Yes |
| Comment/reply | Yes | Yes | Yes | Yes | Yes | Yes |
| View public continuity | Yes | Yes | Yes | Yes | Yes | Yes |
| View institution attention item | No | No | Yes | Yes | Yes | Yes |
| Acknowledge | No | No | Optional no | Yes if policy allows | Yes | Yes |
| Official response | No | No | If canSpeakOfficially | If canSpeakOfficially | If canSpeakOfficially | No unless acting via institution |
| Make commitment | No | No | No | Optional no | Yes | Yes by admin override |
| Add progress | No | No | No | Yes if assigned | Yes | Yes |
| Resolve | No | No | No | Optional no | Yes | Yes |
| Verify resolution | Own issue only | No | No | No | No | Yes if dispute review |
| Dispute/reopen | Own issue only | No | No | No | Institution may reopen internally | Yes |
| Close | Own Ask if answered maybe | No | No | No | Yes | Yes |

### Transition Rules

ASK:

- created when public post is published with intent ASK.
- routed when matching institution participation exists.
- answered when official response link is created.
- closed automatically after answer or manually by author/institution policy.

ISSUE:

- created when public post is published with intent ISSUE and author passes assurance gate.
- routed to accountable participating institutions.
- acknowledged by institution.
- commitment made only by institution actor.
- in progress when progress update is posted.
- resolved by institution actor.
- verified by author or platform process.
- disputed/reopened by author/platform if resolution is contested.
- closed after verified resolution or timeout policy.

UPDATE:

- published when public post is published with intent UPDATE.
- routed/referenced when institution participation matches.
- archived by normal content lifecycle; no commitment required.

## 6. Public vs Private Visibility Boundary

### Visibility Matrix

| Field/Concept | Public DTO | Institution DTO | Admin DTO |
|---|---:|---:|---:|
| post id/text/author public profile | Yes | Yes | Yes |
| intent | Yes | Yes | Yes |
| topic | Yes | Yes | Yes |
| public location label | Yes if user allowed | Yes | Yes |
| jurisdiction id | Usually no | Yes | Yes |
| routed institution public identity | Only when public response exists or policy allows | Yes | Yes |
| routing rule id | No | Optional no | Yes |
| routing confidence | Never | No | Yes |
| internal assignee | Never | Yes | Yes |
| private notes | Never | Yes | Yes |
| internal decline reason | Never | Yes | Yes |
| misroute reason | Never | Yes | Yes |
| age assurance detail | Never | Never | Minimal policy/audit only |
| identity provider payload | Never | Never | Restricted audit only |
| official response | Yes | Yes | Yes |
| commitment/progress/resolution | Yes public-safe | Yes full workspace | Yes full |
| dispute status | Public-safe label only | Yes | Yes |
| moderation flags | No | Limited if relevant | Yes |

### Public DTO Fields

Public continuity DTO should include:

- `sourceId`
- `intent`
- `intentLabel`
- `topic`
- `topicLabel`
- `publicLocationLabel`
- `officialResponses`
- `hasOfficialResponse`
- `commitments`
- `openCommitmentCount`
- `latestProgress`
- `resolution`
- `publicStatus`
- `publicStatusLabel`
- `timeline`

Public DTO must not include:

- assignee
- routing confidence
- private notes
- internal decline/misroute reason
- identity assurance raw detail
- age assurance raw detail
- routing rule internals

### Institution DTO Fields

Institution attention DTO can include:

- source post summary
- author public identity
- intent/topic/location
- routing reason
- route status
- assigned user
- internal notes
- official response links
- commitments
- progress
- dispute/reopen state
- private action availability

### Admin DTO Fields

Admin DTO can include:

- routing attempts
- routing confidence
- rule ids
- policy flags
- moderation state
- audit events
- redacted assurance level
- provider references, not raw identity documents

### Safe Labels

Public-safe labels:

- Asked
- Issue raised
- Update shared
- Official response
- Commitment
- Progress update
- Resolved
- Answered
- Follow-up requested

Internal labels:

- Routed
- Acknowledged
- Assigned
- Declined
- Misrouted
- Reopened
- Closed

## 7. Commitment Framework

### What Counts as a Commitment

A commitment is an institution-authored, public or institution-visible statement that promises action, review, correction, delivery, investigation, publication, or follow-up.

Commitments should be created only by:

- official institution actor
- institution admin/owner
- authorized institution speaker where policy allows
- platform admin only for data correction, not as the institution's voice

### Multiple Commitments

One issue may have multiple commitments.

Examples:

- "We will inspect the site this week."
- "We will publish findings by July 15."
- "We will update the policy page."

Each should be independently trackable.

### Commitment Object Proposal

Fields:

- `id`
- `attentionItemId`
- `institutionId`
- `sourceOfficialResponseLinkId`
- `sourcePostId`
- `sourceInstitutionPostId`
- `summary`
- `body`
- `status`: OPEN, IN_PROGRESS, RESOLVED, CLOSED, WITHDRAWN
- `dueAt`
- `visibility`: PUBLIC, INSTITUTION_ONLY
- `createdByUserId`
- `createdAt`
- `updatedAt`
- `withdrawnAt`
- `withdrawalReason`
- `resolvedAt`
- `closedAt`

### Progress Object Proposal

Fields:

- `id`
- `commitmentId`
- `attentionItemId`
- `institutionId`
- `sourceOfficialResponseLinkId`
- `sourcePostId`
- `sourceInstitutionPostId`
- `summary`
- `body`
- `statusAfterUpdate`
- `createdByUserId`
- `createdAt`

### Relationship to Official Responses

Official response link records who spoke officially and where it appeared.

Commitment records what durable promise was made.

Progress records what changed after the promise.

Resolution records the claimed outcome.

This prevents a reply label from being the only source of truth.

### Legacy Compatibility

Existing tags map as follows:

- `COMMITMENT`: create or display as a legacy commitment event.
- `UPDATE`: create or display as a legacy progress event.
- `RESOLVED`: create or display as a legacy resolution event.

Migration should be conservative:

- do not infer due dates
- do not create commitments from ambiguous text without review
- preserve existing tag rendering as fallback

### Public Timeline Representation

Public thread timeline:

- Official response
- Commitment
- Update
- Resolved

Keep public cards simple:

- no internal status code
- no assignment
- no workflow clock

## 8. Continuity Record

### What Becomes Durable Institutional Memory

Continuity should preserve:

- public source post
- intent
- topic
- public space
- public location label
- routed institution
- official responses
- commitments
- progress updates
- resolution statements
- verification/dispute/reopen events
- final closure

It should not preserve publicly:

- private routing confidence
- internal notes
- private decline reasons
- identity provider payloads
- age verification details

### Minimum Continuity Endpoint

Add:

- `GET /feed/items/:type/:id/continuity`

or:

- `GET /posts/:postId/continuity`

Minimum response:

- `source`
- `publicStatus`
- `intent`
- `topic`
- `officialResponses`
- `commitments`
- `progress`
- `resolution`
- `timeline`

### Public Continuity Panel Model

Fields:

- title: "Continuity"
- status label: Asked, Answered, Issue raised, Official response, Commitment, Updated, Resolved
- timeline entries
- latest official response
- open commitment count
- resolved indicator

### Institution Continuity View

Institution workspace can include:

- full source context
- routing details
- internal action history
- official response history
- commitments/progress/resolution
- disputes/reopens
- audit trail

### Long-Term Audit Trail Strategy

Start derived.

Phase 1:

- derive continuity from source post, attention item, official response links, commitments, and progress.

Phase 2:

- add `ContinuityEvent` append-only records if reconstruction becomes complex.

Phase 3:

- add materialized read model for public/profile/discourse intelligence performance.

## 9. Compliance and Future Readiness

### Existing Support

Current codebase already has:

- terms acceptance fields
- email verification
- phone verification scaffold
- phone abuse signals
- account deletion screen
- child safety screen/docs
- moderation reports/actions
- blocks
- admin audit logs
- institution domain audit logs
- trusted devices and sessions
- user/device communication preferences
- media lifecycle fields

### Compliance-Ready Architecture Principles

Design now for:

- policy-driven capabilities
- provider-neutral verification
- data minimization
- public/private DTO separation
- auditability without public exposure
- regional policy overrides
- retention/deletion workflows
- child safety and age minimums

Do not build full vendor verification now unless required.

### Required Fields and Enums

Future-proof models:

- `UserAssuranceLevel`
- `UserAssuranceRecord`
- `AssuranceProvider`
- `AssuranceStatus`
- `AssurancePurpose`
- `PolicyFlag`
- `PolicyRegion`
- `Jurisdiction`
- `Capability`

Possible assurance fields:

- provider
- providerSubjectRef
- level
- purpose
- status
- verifiedAt
- expiresAt
- revokedAt
- country/region applicability
- evidenceHash
- metadataJson redacted/minimized

Never store raw identity documents unless absolutely required and reviewed.

### Policy Flags

Examples:

- Raise Issue requires email verification.
- Raise Issue requires phone verification in selected jurisdictions.
- Age assurance required for selected features/regions.
- Institution routing disabled in selected jurisdictions.
- Public continuity labels hidden for sensitive topics.

### Verification Provider Integration Points

Provider adapter should sit behind an assurance service:

- `AssuranceProviderAdapter`
- `requestVerification`
- `handleWebhook`
- `mapProviderResult`
- `storeAssuranceRecord`
- `deriveCapabilities`

The composer should depend on capabilities, not provider details.

### Data Retention Considerations

Retention rules:

- public posts follow content retention/deletion policy.
- attention items preserve audit records but should redact deleted-user personal details where required.
- commitments and official responses may remain as institutional records if public content remains.
- identity assurance records should have expiration and deletion paths.
- age assurance should store proof of threshold, not birth date, unless policy requires otherwise.
- private notes should have retention limits.

User deletion:

- anonymize or detach personal author details where required.
- preserve institutional official responses and commitments as institutional records.
- preserve audit logs with minimal actor reference if legally permissible.

## Proposed Models

### PostIntent

Values:

- ASK
- ISSUE
- UPDATE

### UserAssuranceRecord

Fields:

- id
- userId
- level
- provider
- purpose
- status
- verifiedAt
- expiresAt
- revokedAt
- region
- metadataJson
- createdAt
- updatedAt

### InstitutionParticipation

Fields:

- id
- institutionId
- unitId
- topic
- intentScope
- participationMode
- jurisdictionId
- publicSpaceId
- domainTag
- priority
- active
- createdByUserId
- updatedByUserId
- createdAt
- updatedAt

### Jurisdiction

Fields:

- id
- type
- name
- slug
- countryCode
- regionCode
- parentId
- geoJson
- centroidLat
- centroidLng
- active
- createdAt
- updatedAt

### RoutedAttentionItem

Fields:

- id
- sourceType
- sourcePostId
- sourceInstitutionPostId
- sourceAuthorUserId
- intent
- primaryTopic
- publicSpaceId
- jurisdictionId
- routedInstitutionId
- routingRuleId
- routingReason
- routingConfidence
- status
- assignedUserId
- acknowledgedByUserId
- acknowledgedAt
- firstOfficialResponseLinkId
- lastOfficialActivityAt
- resolvedAt
- closedAt
- closedByUserId
- closeReason
- createdAt
- updatedAt

### RoutingAttempt

Fields:

- id
- sourceType
- sourcePostId
- status
- reason
- candidateCount
- selectedCount
- errorCode
- errorMessage
- createdAt

### OfficialResponseLink

Fields:

- id
- attentionItemId
- institutionId
- actorUserId
- actorInstitutionId
- responsePostId
- responseInstitutionPostId
- responseKind
- createdAt

### Commitment

See Commitment Framework section.

### CommitmentProgress

See Commitment Framework section.

## End-to-End Flow Examples

### Ask Flow

1. User chooses Ask.
2. User selects Topic.
3. User optionally selects location.
4. User publishes.
5. Backend persists intent ASK and topic.
6. Routing service finds participating institutions.
7. Institution sees item privately as "Needs response".
8. Institution posts official response.
9. Public thread shows Official response.
10. Continuity shows Answered.
11. Item closes.

### Issue Flow

1. User chooses Raise Issue.
2. Frontend checks capability and prompts verification if needed.
3. Backend enforces verified capability at publish.
4. User selects topic and location.
5. Routing service finds accountable institutions in scope.
6. Institution acknowledges privately.
7. Institution replies officially.
8. Institution creates commitment.
9. Institution posts progress.
10. Institution marks resolved.
11. User may verify or dispute.
12. Closed item remains in continuity.

### Update Flow

1. User chooses Share Update.
2. User selects topic and optional public space/location.
3. Backend persists intent UPDATE.
4. Routing may reference institutions that participate in that topic/scope.
5. Institution may respond, repost, or ignore.
6. Continuity can show "Seen by institution" only if policy supports it; otherwise the update remains ordinary public discourse.

## Patch Plan

### Patch 1: Persist PostIntent and require public intent/topic

Backend:

- Add `PostIntent` enum.
- Add nullable `Post.intent`.
- Add DTO validation for public draft and publish payloads.
- Require `intent` and `primaryTopic` for top-level public posts when feature flag is enabled.
- Do not route yet.

Frontend:

- Send intent from composer.
- Require intent and primary topic before publish.
- Keep public language unchanged.

Checks:

- Ask/Issue/Update publish paths persist intent.
- Replies do not require intent.
- Legacy drafts remain readable.

### Patch 2: Add identity assurance/capability gate for Raise Issue

Backend:

- Add assurance/capability policy service.
- Add feature flag for Raise Issue verification gate.
- Use existing email/phone fields as current evidence.
- If full verification is not implemented, add placeholder assurance state and policy flag.

Frontend:

- Disable or gate Raise Issue when capability is missing.
- Show verification prompt.

Checks:

- Basic users can Ask/Share/comment.
- Verified users can Raise Issue.
- Backend rejects unauthorized Issue publish.

### Patch 3: Add InstitutionParticipation / TopicOwnership and jurisdiction model

Backend:

- Add `Jurisdiction`.
- Add institution jurisdiction joins.
- Add `InstitutionParticipation`.
- Add CRUD APIs for institution admins.

Frontend:

- Add workspace participation settings.
- Allow institution to declare topics and scope.

Checks:

- Admin can create participation scope.
- Non-admin cannot.
- Verified status rules are enforced.

### Patch 4: Add routing rules/service and RoutedAttentionItem

Backend:

- Add `RoutedAttentionItem`.
- Add `RoutingAttempt`.
- Implement deterministic routing service.
- Trigger after publish behind feature flag.
- Idempotent create.

Frontend:

- No required public UI change.

Checks:

- Issue routes by intent/topic/jurisdiction/participation.
- Duplicate publish/retry does not duplicate item.
- Failures do not block publishing.

### Patch 5: Add institution attention/public engagement queue

Backend:

- Add attention list/detail APIs.
- Add acknowledge/decline/misroute actions.
- Add counters.

Frontend:

- Add `/institution/:institutionId/attention`.
- Add dashboard counters.
- Add list/detail views using existing cards.

Checks:

- Members can view.
- Editors/admins can act according to policy.
- Public users cannot view private queue.

### Patch 6: Add official response linkage

Backend:

- Add `OfficialResponseLink`.
- Add attention response endpoint or extend existing reply path.
- Reuse official voice validation.

Frontend:

- Add official response action from attention detail.
- Public thread renders normal official reply.

Checks:

- Response link is created.
- Public thread updates.
- Queue status moves to answered/responded.

### Patch 7: Add commitments/progress/resolution lifecycle

Backend:

- Add `Commitment`.
- Add `CommitmentProgress`.
- Add resolve, verify, dispute, reopen, close transitions.
- Map legacy tags as fallback.

Frontend:

- Add commitment/progress controls to attention detail.
- Keep public labels calm and social.

Checks:

- Multiple commitments can attach to one issue.
- Progress belongs to a commitment.
- Resolution can be disputed/reopened.

### Patch 8: Add continuity endpoint/panel and discourse intelligence upgrades

Backend:

- Add public continuity endpoint.
- Add institution continuity view.
- Update discourse intelligence to prefer canonical records.

Frontend:

- Add public continuity panel.
- Add institution continuity/history panel.

Checks:

- Public DTO excludes private fields.
- Institution DTO includes workspace fields.
- Admin DTO includes audit fields.

## Risks

### Product Risk: Aura becomes a complaint portal

Mitigation:

- keep social composer language
- hide internal workflow
- no public ticket/case/SLA labels
- only show official responses and continuity

### Routing Risk: false positives

Mitigation:

- deterministic rules first
- institution opt-in participation
- jurisdiction matching
- misroute path
- no public penalty for decline/misroute

### Identity Risk: over-collection

Mitigation:

- use assurance levels, not raw identity details
- store provider references and minimal metadata
- separate public DTOs from internal audit

### Permission Risk: unauthorized official commitments

Mitigation:

- reuse institution role guard
- require official voice rights
- restrict commitments/resolution to admin/authorized actors

### Privacy Risk: internal routing data leaks publicly

Mitigation:

- strict DTO separation
- tests for public continuity response shape
- never expose routing confidence, private notes, assignee, age/identity details

### Migration Risk: legacy accountability tags conflict with durable commitments

Mitigation:

- treat tags as display fallback
- create durable objects going forward
- migrate only high-confidence legacy rows

### Operational Risk: routing blocks publishing

Mitigation:

- route after publish
- record routing attempts
- retry failures
- never fail public publish due to routing outage

## Files Inspected

Existing proposal:

- `aura_final/docs/AURA_ACCOUNTABILITY_ROUTING_AUDIT_PROPOSAL.md`

Backend:

- `aura-backend/prisma/schema.prisma`
- `aura-backend/src`
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

Frontend:

- `aura_final/lib`
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

Docs:

- `aura_final/docs`
- `aura_final/docs/strategy/AURA_STATE.md`
