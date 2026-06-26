# Aura Pre-Implementation Lock

Date: 2026-06-20

Status: Documentation-only lock. This file does not implement application code, create migrations, commit changes, or deploy anything.

Canonical references:

- `aura_final/docs/strategy/AURA_STATE.md`
- `aura_final/docs/strategy/AURA_ACCOUNTABILITY_ROUTING_IMPLEMENTATION_FRAMEWORK.md`
- `aura_final/docs/strategy/AURA_CONTEXT_OWNERSHIP_RESOLUTION_FRAMEWORK.md`
- `aura_final/docs/strategy/AURA_PROGRESSIVE_CREDIBILITY_DOCTRINE.md`

Progressive credibility alignment: identity is declared, participation is
observed, credibility is earned, accountability is progressively accepted, and
trust accumulates through continuity. Patch 3 may create suggested and declared
participation foundations, but it must not require full accountability setup
during onboarding.

## Executive Summary

This document locks two final decisions before implementation begins:

1. Public Record Context Priority.
2. Patch 4 Routing Schema/API Review Gate.

Aura remains verified public communication infrastructure and an accountable public record. It is not a complaint portal, not a generic social network, and not a ticketing or case-management system.

Implementation may begin only for Patches 1 through 3:

- Patch 1: persist public record intent and require a primary topic for top-level public records.
- Patch 2: add capability-based gating for Raise Issue.
- Patch 3: add institution participation foundations, suggested vs declared participation, activation state, and jurisdiction primitives without requiring heavy setup before institutions can begin official participation.

Patch 4 routing remains blocked. It may not begin until exact schema and API contracts are reviewed and approved for participation, jurisdiction, routing attempts, engagement items, official response linkage, DTO visibility, idempotency, feature flags, failure behavior, migration/backfill, and tests.

Patch 4 must not route from suggested participation, observed credibility, AI
suggestions, social graph, or inferred responsibility. It can only consume
confirmed participation and approved routing contracts.

## Public Record Context Priority

Context must be resolved before routing. The routeable object is not "topic -> institution." The routeable object is:

```txt
Public Record
-> Intent
-> Capability
-> Context Priority
-> Jurisdiction
-> Institution Participation
-> Institution Verification / Activation
-> Ownership Resolution
-> Routing
```

### Priority Order

1. Explicit institution context.
   - Applies when a record is created from an institution profile, institution space, institution thread, institution post, institution workspace surface, or another institution-specific surface.
   - This can outweigh generic topic routing because the user is already acting in an institution-specific context.
   - It still does not create accountability unless participation, jurisdiction, and activation match.

2. Public space context.
   - Applies when a record is created inside a public space with topic and jurisdiction scope.
   - Public space context can narrow routing by limiting candidate institutions to those participating in that public space, topic, or jurisdiction.
   - Public space context is authoritative as discourse context, but not automatically as ownership.

3. Explicit mention.
   - Applies when the user mentions an institution.
   - A mention creates a reference, not accountability.
   - A mentioned institution becomes routeable only if participation, jurisdiction, mode, and activation also match.

4. User-selected topic.
   - Primary topic is required for top-level public records.
   - The selected topic is authoritative for content classification.
   - Topic alone never creates accountability.

5. User-selected jurisdiction/location.
   - Required when the record is location-dependent.
   - Jurisdiction/location narrows responsibility to institutions whose declared scope covers that place.
   - User profile location may assist defaults, but should not be treated as public proof of record location.

6. Institution participation.
   - Topic + jurisdiction + participation mode determine routability.
   - Institution class, type, and domain tags can seed participation setup, but they are not a substitute for explicit participation declarations.

7. Institution verification/activation.
   - An institution must be verified and activated before official routing.
   - Activation requires at least a valid institution profile, official voice eligibility, a capable official actor, participation declarations, jurisdiction/scope, and participation mode.

8. Weak signals.
   - Includes follows, social graph, activity, public attention, discourse intelligence, search relevance, inferred related institutions, and AI suggestions.
   - Weak signals are never authoritative alone.
   - Weak signals can support tie-breaking, admin review, suggestions, or reference-only context.

### Locked Clarifications

- Explicit institution context can outweigh generic topic routing.
- Public space context can narrow routing.
- Mentions create references unless participation and jurisdiction match.
- Weak signals never create accountability by themselves.
- Routing confidence, assignment, internal review status, and private routing logic are never public-facing product concepts.
- Public labels must remain calm and social: Ask, Raise Issue, Share Update, Topic, Discussion, Official Response, Commitment, Progress, Resolved.

## Examples Showing Context Priority

### Example 1: Record Created From Institution Profile

| Field | Value |
| --- | --- |
| Context priority winner | Explicit institution context |
| Scenario | User raises an infrastructure issue from a city institution profile |
| Topic | Infrastructure |
| Jurisdiction | City scope selected or inferred from institution surface |
| Routing rule | Start with the city as the primary candidate, then verify participation, jurisdiction, mode, and activation |
| Outcome | Route only if the city participates in Infrastructure for that jurisdiction and is activated |

Important point: the institution-specific surface can outrank a generic topic match to another infrastructure institution, but it does not bypass participation or verification.

### Example 2: Record Created Inside Public Space

| Field | Value |
| --- | --- |
| Context priority winner | Public space context |
| Scenario | User asks a transportation question inside a city transportation public space |
| Topic | Transportation |
| Jurisdiction | Public space scope |
| Routing rule | Candidate institutions are narrowed to participants in that public space or its declared jurisdiction/topic |
| Outcome | Route to eligible responding/accountable institutions; otherwise keep as public discussion |

Important point: the public space narrows the candidate set before generic city/county/state topic matching.

### Example 3: Mentioned Institution

| Field | Value |
| --- | --- |
| Context priority winner | Explicit mention, but reference only by default |
| Scenario | User mentions a utility authority in a road issue |
| Topic | Infrastructure |
| Jurisdiction | City |
| Routing rule | Mentioned utility is referenced; route only if it participates in the relevant topic/scope |
| Outcome | City may be primary accountable; utility may be referenced or secondary if participation/jurisdiction match |

Important point: a mention is not an accountability claim.

### Example 4: Topic and Location With No Institution Context

| Field | Value |
| --- | --- |
| Context priority winner | Topic + jurisdiction |
| Scenario | User raises a public health issue with selected county location |
| Topic | Healthcare |
| Jurisdiction | County |
| Routing rule | Find institutions participating in Healthcare/Public Safety for the county scope |
| Outcome | Route to activated accountable/responding public health institution if one exists |

Important point: the route is created from participation plus jurisdiction, not from topic alone.

### Example 5: Weak Signals Only

| Field | Value |
| --- | --- |
| Context priority winner | None authoritative |
| Scenario | User shares an update followed by many users who also follow a university |
| Topic | Education |
| Jurisdiction | None |
| Routing rule | Weak signals may suggest related institutions for review, but cannot create accountable routing |
| Outcome | No accountable route; optional reference or discovery surface only |

Important point: follows, activity, discourse intelligence, and AI suggestions cannot create accountability without explicit participation and jurisdiction.

## Patch 4 Schema/API Review Checklist

Patch 4 may not begin until the following contracts are reviewed and approved.

### Models and Enums

| Contract | Decision required before Patch 4 |
| --- | --- |
| `PublicRecord` or `Post.intent` strategy | Decide whether intent is persisted directly on `Post` first, whether `PublicRecord` is a conceptual layer, and when an explicit `PublicRecord` table is justified |
| `InstitutionParticipation` | Define institution/topic/jurisdiction participation row, status, ownership, actor, audit fields, and lifecycle |
| `ParticipationMode` | Lock enum values: `LISTENING`, `RESPONDING`, `ACCOUNTABLE`, `REFERENCE_ONLY` |
| `Jurisdiction` | Define hierarchy, type, parent/child behavior, canonical keys, display labels, and source of truth |
| `InstitutionJurisdiction` | Define institution scope coverage, active state, verification relationship, and optional unit scope |
| `PublicRecordJurisdiction` or `Post.jurisdictionId` | Decide record-to-jurisdiction storage and whether multiple jurisdictions are allowed |
| `RoutedPublicRecord` / `PublicEngagementItem` | Define route item identity, institution, record, status, ownership role, queue visibility, and public/private state separation |
| `OwnershipRole` | Lock values such as `PRIMARY_ACCOUNTABLE`, `CO_ACCOUNTABLE`, `SECONDARY_PARTICIPANT`, `RESPONDER`, `COMMITTER`, `REFERENCED` |
| `RouteSource` | Lock values such as institution context, public space, mention, topic/jurisdiction, admin review, official handoff, discourse intelligence |
| `ConfidenceClass` | Lock internal-only values such as `HIGH`, `MEDIUM`, `LOW`, `AMBIGUOUS`, `NONE` |
| `RoutingAttempt` | Define attempt lifecycle, decision path, failure reason, idempotency key, feature flag snapshot, and audit fields |
| `OfficialResponseLink` | Define how official replies/responses attach to a public record and, optionally, to a routed engagement item or commitment |

### APIs

| API area | Decision required before Patch 4 |
| --- | --- |
| Institution participation CRUD | Define create/update/archive participation, permission checks, audit, mode changes, and draft/active states |
| Jurisdiction selection/resolution | Define public record jurisdiction selection, institution scope selection, lookup, validation, and fallback behavior |
| Route attempt creation | Define internal service endpoint/command behavior, idempotency, retry, review, feature-flag checks, and failure semantics |
| Public engagement list/detail | Define institution workspace list/detail DTOs, filters, counters, sorting, and allowed actions |
| Official response linkage | Define how official responses connect to records, route items, commitments, progress, and public continuity |
| Public continuity DTO boundaries | Define public-safe fields, institution-private fields, and admin-only fields |

### Required Cross-Cutting Decisions

Patch 4 must define:

- Idempotency keys.
  - Recommended inputs: public record id, institution id, participation id, ownership role, route source, jurisdiction id, feature flag version.
  - Duplicate route attempts must update or no-op deterministically rather than creating duplicate engagement items.

- Public/private/admin DTO separation.
  - Public DTOs may show official response, participating institution, commitment, progress, resolved, reopened, and referenced labels.
  - Institution DTOs may show relationship type, workspace state, broad route reason, eligible actions, and private workflow status.
  - Admin DTOs may show confidence, decision path, failed attempts, review state, feature flag version, and policy diagnostics.

- Feature flags.
  - Routing engine enabled/disabled.
  - Auto-route enabled/disabled.
  - Institution participation enabled/disabled.
  - Jurisdiction routing enabled/disabled.
  - Official response linkage enabled/disabled.
  - Public continuity panel enabled/disabled.

- Route failure behavior.
  - No matching institution: keep record public and record internal `NO_ROUTE` attempt if routing was evaluated.
  - Ambiguous ownership: hold for admin review or create reference-only suggestions.
  - Institution not activated: do not route; optionally show admin diagnostic.
  - Capability failure: block the public action before routing.
  - Feature flag disabled: do not create route items.
  - Duplicate attempt: return existing route item or no-op.

- Migration/backfill plan.
  - Existing posts need default intent strategy or explicit unknown/backfilled state.
  - Existing primary topics should be preserved.
  - Existing institution profile class/type/domain tags can seed participation drafts, not active accountable participation.
  - Existing public-space relationships should be preserved as context, not ownership.
  - Existing official replies should be eligible for later official response linking.

- Tests required before routing is enabled.
  - Intent persistence tests.
  - Capability gate tests.
  - Institution participation CRUD permission tests.
  - Jurisdiction hierarchy and selection tests.
  - Ownership resolution deterministic precedence tests.
  - Idempotency tests for duplicate routing.
  - Public/private/admin DTO leakage tests.
  - Feature flag disabled/enabled tests.
  - Route failure tests for no match, ambiguity, inactive institution, and duplicate attempts.
  - Official response linkage tests.
  - Regression tests confirming weak signals cannot create accountable routes.

## Implementation Lock Rules

### Rule 1: Patches 1-3 May Start

Implementation may start only for:

1. Persisting Public Record intent and requiring a primary topic.
2. Adding capability-based gates for public intents, especially Raise Issue.
3. Adding institution participation, participation mode, activation state, and jurisdiction declarations.

These patches establish the minimum data foundation for routing but do not route records.

### Rule 2: Patch 4 Routing Remains Blocked

Patch 4 routing remains blocked until schema/API review is approved for every item in the checklist above.

Patch 4 may not implement:

- Automatic route creation.
- Public engagement queue creation.
- Routing attempts.
- Routing confidence.
- Route-based notifications.
- Official response linkage as routing output.
- Public continuity derived from route items.

until the schema/API review is complete and approved.

### Rule 3: Topic Matching Alone Is Invalid

Patch 4 must not route by topic alone.

Valid routing requires:

```txt
Public record intent
+ author capability
+ resolved context
+ jurisdiction, when required
+ institution participation
+ participation mode
+ institution verification/activation
+ ownership role
+ idempotent route creation
```

### Rule 4: Weak Signals Are Non-Authoritative

Weak signals may help discovery, review, or ranking, but cannot create accountable routing.

Weak signals include:

- follows
- social graph
- activity
- discourse intelligence
- AI suggestions
- inferred related institutions
- search relevance
- public attention volume

### Rule 5: Public Product Language Stays Non-Bureaucratic

Public surfaces must not expose internal routing mechanics or bureaucratic labels.

Use:

- Ask
- Raise Issue
- Share Update
- Topic
- Discussion
- Official Response
- Commitment
- Progress
- Resolved

Avoid:

- complaint
- ticket
- case
- SLA
- assignee
- queue state
- routing confidence
- department routing

## Files Referenced

- `aura_final/docs/strategy/AURA_STATE.md`
- `aura_final/docs/strategy/AURA_ACCOUNTABILITY_ROUTING_IMPLEMENTATION_FRAMEWORK.md`
- `aura_final/docs/strategy/AURA_CONTEXT_OWNERSHIP_RESOLUTION_FRAMEWORK.md`
