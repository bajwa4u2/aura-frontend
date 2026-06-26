# Aura Context & Ownership Resolution Framework

## Executive Summary

Aura should determine "who should care" by resolving institutional context and ownership before creating routed work. Topic matching alone is not enough. A road issue in Detroit can be relevant to a city, county, state transportation agency, utility authority, or private contractor, but only some of those institutions are participating in Aura, only some have jurisdiction, and only some should be treated as accountable.

Progressive credibility alignment: this framework is governed by
`aura_final/docs/strategy/AURA_PROGRESSIVE_CREDIBILITY_DOCTRINE.md`.
Declared participation is route eligibility, not earned credibility.
Accountability is not a setup checkbox; it becomes meaningful through official
responses, commitments, progress, resolution, and continuity.

The final model is:

```txt
Public Record
-> Intent
-> Capability
-> Context
-> Jurisdiction
-> Institution Participation
-> Verification
-> Ownership Resolution
-> Routing
-> Official Response / Commitment / Progress / Resolution / Continuity
```

This preserves the product doctrine:

- Public users experience Aura as social public communication: Ask, Raise Issue, Share Update, Topic, Discussion, Official Response.
- Institutions experience Aura as public engagement infrastructure: Public Records, Needs Response, Open Commitments, Official Responses.
- Internally, Aura operates as verified public record infrastructure with capability policy, participation declarations, jurisdiction, ownership resolution, routing, commitments, progress, resolution, dispute, and continuity.

The audit found strong reusable foundations: topics, public spaces, institution profiles, institution classes/types/domain tags, institution verification, official voice, institution units, memberships, follows, mentions, public activity, and discourse intelligence. The missing layer is explicit ownership metadata: institution participation by topic and jurisdiction, participation mode, accountable scope, routing confidence, routing outcome records, and public/private visibility boundaries.

Suggested participation and weak signals may help onboarding, review, and
recommendations, but only explicitly confirmed participation can be considered
for routing. Observed behavior may improve credibility context, but it must not
silently create accountability.

Patch 1, Patch 2, and Patch 3 from the implementation framework can proceed after this document. Patch 4 routing should not proceed until participation, jurisdiction, and ownership resolution have data structures and feature flags in place.

## Context Source Inventory

### Summary

Aura already stores many context signals, but they do not all mean the same thing. Some are authoritative, some are useful but weak, and some are descriptive only. The routing framework must treat them differently.

| Source | Existing support | Current meaning | Authority level | Reusable immediately |
| --- | --- | --- | --- | --- |
| Public Record / Post | `Post`, `InstitutionPost` | Public discussion object, reply, repost, institution authored content | Authoritative for record existence and author identity | Yes |
| Intent | Composer has Ask / Raise Issue / Share Update; backend has topics/status but not durable public-record intent | Public user intent is currently mostly frontend UX | Missing authoritative persistence | Patch 1 |
| Topics | Backend `Topic` enum; frontend topic selector; `primaryTopic`, `secondaryTopics` | Content classification | Authoritative when user-selected; inferred topic is lower confidence | Yes |
| Categories | Institution category/profile fields exist | Broad institution description | Decorative unless normalized to ontology | Limited |
| Ontology | Institution class/type/domain tags exist in backend and frontend | Institutional identity and remit | Semi-authoritative if institution/admin controlled | Yes as seed |
| Domain Tags | Institution profile/domain tag fields | Areas the institution claims to cover | Semi-authoritative; not the same as participation | Yes as participation seed |
| Public Spaces | `PublicSpace`, public-space follows, post association | Public discourse context or audience space | Authoritative as forum/context; not ownership | Yes |
| Institution Spaces | `Space`, institution spaces, threads, members | Private or institution-scoped collaboration | Authoritative for internal collaboration; not public routing | Limited |
| Institution Profiles | `Institution` fields for class, type, domain, jurisdiction, city, region, country, location, status, verification | Public institutional identity | Authoritative for verified institutions; weak when unverified/free text | Yes |
| Institution Membership | `InstitutionMember`, roles, `canSpeakOfficially` | Who can act for institution | Authoritative for official voice gating | Yes |
| Institution Following | `InteractionFollow` user/institution/public-space follows | Interest, relationship, subscription, visibility | Weak signal; not responsibility | Tie-break only |
| Mentions | Mention extraction utility and social text conventions | Explicit reference by public user | Explicit but not accountable | Tie-break/reference |
| Jurisdiction Fields | User city/country; institution jurisdiction/location/city/region/country; unit city/region/country | Location hints | Weak until normalized | Provisional only |
| Institution Units | `InstitutionUnit` with type, public/archive, contact, location fields | Sub-institution structure | Authoritative when institution managed; no topic ownership yet | Yes as future target |
| Institution Classes | `institutionClass` | Institutional class/category | Useful for type matching | Yes |
| Institution Types | `institutionType` | More specific kind of institution | Useful for type matching | Yes |
| Official Voice | Institution post/reply actor fields, member official voice flags | Official communication identity | Authoritative | Yes |
| Accountability Tags | Existing commitment/update/resolved style tags | Public accountability vocabulary | Useful compatibility signal | Yes |
| Discourse Intelligence | Existing endpoints/logic for unanswered questions, related institutions, participation, accountability | Analysis and insight | Observational, not routing authority | Later scoring only |
| Notifications/Activity | Notification and activity types exist | User/institution awareness | Delivery layer | Reuse after routing |

### Authoritative Context Signals

These can safely influence routing once policy and feature flags exist:

- User-selected `primaryTopic` on a top-level public record.
- Public record intent once persisted as `ASK`, `ISSUE`, or `UPDATE`.
- Verified institution identity and official voice state.
- Institution membership and `canSpeakOfficially` permissions.
- Institution class/type/domain tags when controlled by institution admin and validated against the ontology.
- Institution declared participation and jurisdiction once added.
- Public space association as discussion context.
- Official response linkage through institution actor identity.

### Weak or Decorative Signals

These should not create accountability by themselves:

- Free-text institution description, mission, services, and location.
- User or institution follows.
- Mentions.
- Inferred topic without user confirmation.
- Discourse-intelligence related-institution suggestions.
- Public-space description text.
- Search relevance.
- Repost/reply activity volume.

### Immediately Reusable Signals

The following can be reused without changing product doctrine:

- Topic enum and topic selector.
- `primaryTopic` and `secondaryTopics`.
- Public-space association.
- Institution class/type/domain tags as seed input for participation setup.
- Institution verification and domain verification as eligibility gates.
- Institution member official voice gating.
- Institution units as future internal targets.
- Mentions and follows as non-authoritative context enrichment.
- Existing accountability tags as compatibility vocabulary.

## Ownership Resolution Framework

### Core Definitions

| Term | Meaning | Public meaning | Internal use |
| --- | --- | --- | --- |
| Relevant institution | Institution plausibly connected to the topic/context | May appear as related or referenced only if useful | Candidate discovery |
| Participating institution | Institution has declared it participates in a topic/scope | Can receive public records in engagement surfaces | Routing eligibility |
| Accountable institution | Participating institution has declared accountable mode for topic/jurisdiction and is verified | Can be shown as participating/accountable in calm public language | Primary route candidate |
| Referenced institution | Institution is mentioned, followed, detected, or contextually related but has not accepted routeable responsibility | May be displayed as mentioned/referenced if explicit | Context only |
| Responding institution | Institution has issued an official response | Public official response | Response timeline |
| Committing institution | Institution has made a commitment | Public commitment/progress | Continuity and open commitments |

### Decision Hierarchy

Ownership resolution should use deterministic rules before AI or ranking models.

1. Confirm the public record is eligible.
   - Top-level public record.
   - Valid persisted intent.
   - Required primary topic.
   - Author has required capability for the intent.

2. Resolve content context.
   - Primary topic.
   - Secondary topics.
   - Public space.
   - Explicit mentions.
   - Attached institution context, if any.

3. Resolve geography and jurisdiction.
   - Record location if provided.
   - Public-space jurisdiction if defined.
   - Institution/profile context if record is created inside institution context.
   - User location only as a fallback and never as public proof.

4. Find participating institutions.
   - Match topic to declared participation.
   - Match jurisdiction to declared scope.
   - Filter by institution verification and activation state.
   - Filter by participation mode.

5. Classify candidate relationship.
   - `ACCOUNTABLE` if participation mode and jurisdiction declare responsibility.
   - `RESPONDING` if institution accepts official responses but not commitments.
   - `LISTENING` if institution monitors but does not promise action.
   - `REFERENCE_ONLY` if contextually related but not routeable.

6. Apply precedence and tie-breaks.
   - More specific jurisdiction beats broader jurisdiction.
   - Accountable mode beats responding mode.
   - Direct topic participation beats domain-tag inference.
   - Verified official presence beats unverified profile.
   - Explicit public-space ownership beats generic geography.
   - Existing official thread participation beats no prior participation.

7. Produce routing outcome.
   - Create routeable engagement item only for eligible participating institutions.
   - Store non-routed references separately.
   - Do not expose confidence, tie-breaks, or internal routing logic publicly.

### Precedence Order

Recommended ownership precedence:

1. Explicit institution context selected by the user or public record surface, if verified and eligible.
2. Public-space owner or declared public-space participating institution, if the space has jurisdiction/topic rules.
3. Institution participation declaration matching topic and exact jurisdiction.
4. Institution participation declaration matching topic and parent jurisdiction.
5. Institution unit participation matching topic and jurisdiction.
6. Institution class/type/domain tag match within jurisdiction.
7. Explicit mention of a verified institution.
8. Follow/subscription/social graph relevance.
9. Discourse intelligence suggestion.

Only items 1 through 5 should be allowed to create accountable or responding route items by default. Items 6 through 9 can create references, suggestions, or admin review candidates.

### Tie-Breaking Logic

Tie-breaking should be deterministic and explainable internally:

| Tie | Winner |
| --- | --- |
| City vs county vs state | Most specific jurisdiction that covers the record |
| Accountable vs responding | Accountable |
| Responding vs listening | Responding |
| Direct topic participation vs domain tag | Direct participation |
| Institution vs unit | Unit for assignment, institution for public official identity unless unit has official public presence |
| Verified vs unverified | Verified |
| Multiple equal accountable institutions | Route to all as co-primary or primary plus secondary depending on configured ownership split |
| No accountable candidate | Route to responding/listening institutions only if configured; otherwise mark unrouted internally |

### Confidence Handling

Confidence is internal only.

Use confidence to decide whether to:

- Route automatically.
- Hold for admin review.
- Route as reference only.
- Ask the author for clarifying context in a future UX.
- Defer routing.

Recommended confidence classes:

| Class | Meaning | Action |
| --- | --- | --- |
| `HIGH` | Exact topic, jurisdiction, participation, and verification match | Auto-route behind feature flag |
| `MEDIUM` | Strong topic/jurisdiction match with one inferred element | Route to Needs Review or lower-priority workspace section |
| `LOW` | Mostly inferred from free text, mention, follow, or AI | Do not route as accountable; reference or review only |
| `AMBIGUOUS` | Multiple plausible accountable owners with no precedence winner | Multi-route as referenced or send to admin review |
| `NONE` | No routeable institution | Keep public record public; no institution route |

### Ambiguity Handling

Aura should avoid pretending to know responsibility when the context is uncertain.

Ambiguity handling rules:

- Public record remains valid even if unrouted.
- Do not show "sent to" language unless a route was created.
- If several institutions may care, route only to participating eligible institutions and mark relationship type internally.
- If no institution is accountable, surface the record in public discussion without institution accountability claims.
- If a user explicitly mentions an institution, treat it as referenced unless that institution also participates in the topic/scope.
- If AI suggests an institution, use it as review input only until deterministic participation and jurisdiction support it.

## Participation vs Accountability Matrix

### Participation Modes

| Mode | Operational meaning | Routing implication | Public implication | Institution expectation |
| --- | --- | --- | --- | --- |
| `LISTENING` | Institution monitors topic/scope but does not promise official response | Can appear in engagement monitoring; should not create Needs Response by default | Usually hidden; may show "participates in this topic" only on institution profile | Monitor and learn |
| `RESPONDING` | Institution accepts public records for possible official response | Can create Needs Response item | Public can see official response if provided; no implied commitment | Respond when appropriate |
| `ACCOUNTABLE` | Institution accepts accountability workflow for topic/scope | Creates Needs Response and can create Open Commitment lifecycle | Public may see participating/responded/committed/resolved labels | Respond, commit when appropriate, update progress, close/resolution |
| `REFERENCE_ONLY` | Institution can be connected as context but does not receive accountable routing | No queue item unless explicitly mentioned and configured | May appear as referenced only when explicit | No operational expectation |

### When Participation Becomes Accountability

Participation becomes accountability when all of the following are true:

- Institution is verified or otherwise approved for official presence.
- Institution has declared `ACCOUNTABLE` participation for the topic.
- The public record jurisdiction is within the institution's declared accountable scope.
- The public record intent is eligible for accountability, normally `RAISE_ISSUE`.
- The author has the capability required for the intent.
- The route is created by deterministic rules or approved by admin review.

### When Accountability Becomes Commitment

Accountability becomes commitment only when an official institution actor makes a commitment.

Commitment requires:

- Institution actor has `CAN_COMMIT`.
- Public record has eligible intent, normally `RAISE_ISSUE`.
- Commitment text/action is explicit and durable.
- Commitment is linked to an official response or official institution action.
- Commitment status and progress lifecycle are recorded.

Important boundary:

- A route is not a commitment.
- An official response is not automatically a commitment.
- Acknowledgment is not resolution.
- Participation does not automatically create legal obligation.
- Aura creates visible institutional presence and accountable public record, not legal liability by default.

## Multi-Institution Framework

### Model

A single public record can involve multiple institutions. Aura should model institution relationship to a record, not force one owner.

Recommended roles:

| Role | Meaning | Public treatment | Internal treatment |
| --- | --- | --- | --- |
| `PRIMARY_ACCOUNTABLE` | Main participating institution for the record | May appear as the main participating institution if product chooses | Needs Response / Open Commitment eligible |
| `CO_ACCOUNTABLE` | Shares accountable scope | May appear as another participating institution | Needs Response / Open Commitment eligible |
| `SECONDARY_PARTICIPANT` | Relevant and participating, but not primary owner | Public only when it responds or commits | Workspace monitoring or lower priority |
| `RESPONDER` | Has officially responded | Public official response | Response timeline |
| `COMMITTER` | Has made a commitment | Public commitment/progress | Open commitment lifecycle |
| `REFERENCED` | Mentioned or contextually related | Public only if explicitly mentioned or useful | No queue obligation |

### Routing Rules

Routing should support multiple targets with relationship types:

- Route to every `ACCOUNTABLE` institution that matches topic and jurisdiction if the policy allows co-accountability.
- Route to one `PRIMARY_ACCOUNTABLE` and one or more `SECONDARY_PARTICIPANT` institutions when jurisdiction specificity clearly identifies a primary owner.
- Do not route `REFERENCE_ONLY` institutions into Needs Response unless institution policy explicitly opts in.
- Preserve relationship type in the route item.
- Preserve route source: topic, jurisdiction, public space, explicit mention, admin review, or official handoff.

### Public Representation

Public users should not see complex route graphs.

Public labels should stay calm:

- "Official response"
- "Institution responded"
- "Commitment made"
- "Progress update"
- "Resolved"
- "Reopened"
- "Referenced"

Avoid public labels such as:

- Ticket
- Case
- SLA
- Department queue
- Routing confidence
- Assigned to
- Escalation lane

### Continuity Implications

Continuity records must preserve:

- Original public record.
- Intent and topic at creation time.
- Routed institution relationships.
- Official responses.
- Commitments.
- Progress updates.
- Resolution claims.
- Verification/dispute events.
- Closure/reopen events.

If multiple institutions participate, continuity must show each institution's actions separately. One institution's resolution does not automatically resolve another institution's commitment.

### Commitment Implications

Commitments are institution-specific:

- Multiple institutions can make separate commitments on one record.
- A commitment belongs to the committing institution.
- Progress belongs to a commitment, not just the thread.
- Resolution can close one commitment while the public record remains open for other commitments.
- Public continuity should group commitments by institution.

## Institution Activation Framework

### Activation Requirements

An institution becomes routable only after minimum activation is complete.

Required:

- Institution profile exists.
- Institution identity is verified or approved for routing pilot.
- Institution official voice is enabled according to plan/policy.
- At least one active member can respond officially.
- Institution declares participation topic(s).
- Institution declares jurisdiction/scope for those topics.
- Institution selects participation mode for each topic/scope.

Optional:

- Institution units and unit-specific scope.
- Public-space associations.
- Response hours or service windows.
- Contact channels.
- Escalation contacts.
- Reference-only topics.
- Introductory public profile copy.

### Minimum Viable Activation Path

1. Institution creates or claims profile.
2. Institution verifies domain or is approved by admin pilot process.
3. Institution assigns official member with `CAN_RESPOND_OFFICIALLY`.
4. Institution selects topics from existing `Topic` enum.
5. Institution selects jurisdiction/scope for each topic.
6. Institution selects mode: `LISTENING`, `RESPONDING`, `ACCOUNTABLE`, or `REFERENCE_ONLY`.
7. Aura validates the profile as routable.
8. Institution appears in Public Engagement workspace surfaces.

### Activation State

Recommended internal activation states:

| State | Meaning | Routing behavior |
| --- | --- | --- |
| `PROFILE_ONLY` | Institution exists but is not ready for official routing | Do not route |
| `VERIFYING` | Institution verification in progress | Do not route unless pilot override |
| `VERIFIED_NO_PARTICIPATION` | Official identity exists, but no topic/scope declarations | Do not route |
| `PARTICIPATION_DRAFT` | Declarations are being configured | Do not route automatically |
| `ROUTABLE` | Minimum viable activation complete | Eligible for routing |
| `PAUSED` | Institution temporarily paused routing | Keep public profile; stop new route items |
| `SUSPENDED` | Trust/safety or admin restriction | Do not route; suppress official actions as policy requires |

## Public Representation Framework

### Public Surface

Public users should see the public record and institutional actions, not internal operations.

Visible:

- Record intent: Ask, Issue, Update.
- Topic.
- Discussion.
- Official response.
- Institution responded.
- Institution participates in this topic, where useful and not noisy.
- Commitment made.
- Progress update.
- Resolved.
- Reopened/disputed, using calm language.

Hidden:

- Routing confidence.
- Internal assignment.
- Internal queue state.
- Private notes.
- Internal decline reason.
- Age/identity details.
- Capability policy details.
- Raw jurisdiction matching rules.
- AI scoring.
- Institution staff-only workflow state.

### Institution Workspace

Product-facing labels:

- Public Engagement
- Public Records
- Needs Response
- Open Commitments
- Official Responses
- Progress
- Resolved
- Referenced

Institution users may see:

- Routed records by mode and priority.
- Why the record appears in broad terms: topic, jurisdiction, public space, mention.
- Relationship type: accountable, responding, listening, referenced.
- Eligible actions: respond, commit, update progress, resolve, archive, mark as reference.
- Internal notes and assignment if implemented later.

### Admin Surface

Admins may see:

- Routing confidence.
- Ownership resolution decision path.
- Failed/ambiguous route attempts.
- Institution activation state.
- Capability policy.
- Trust/safety flags.
- Verification state.
- Overrides and audit trails.

Admins should not casually expose:

- Sensitive identity assurance evidence.
- Private staff notes.
- Vendor verification details.
- Raw risk scores.

### Safe Public Labels

Recommended labels:

- "Official response"
- "Participating institution"
- "Commitment"
- "Progress update"
- "Resolved"
- "Reopened"
- "Referenced"
- "Part of the public record"

Avoid:

- "Case opened"
- "Ticket assigned"
- "SLA breached"
- "Department owner"
- "Routing confidence"
- "Escalated to queue"
- "Complaint filed"

## Routing Examples

### Example 1: Road Issue in City

| Field | Value |
| --- | --- |
| Intent | Raise Issue |
| Topic | Infrastructure or Transportation |
| Jurisdiction | Detroit, Michigan |
| Context | User-selected topic, city location, possible public-space context |
| Participation | City participates as `ACCOUNTABLE` for local roads; State DOT participates as `RESPONDING` for state highways; utility authority `RESPONDING` for utility cuts |
| Ownership resolution | If record location is local street, city is `PRIMARY_ACCOUNTABLE`; State DOT is referenced or secondary only if state-road metadata matches; utility is referenced if mentioned or utility topic present |
| Routing outcome | Route to City Needs Response; optionally route State DOT/utility as referenced or secondary if deterministic context supports it |

Public result:

- Public record remains a social issue discussion.
- If City responds, show Official Response.
- If City commits to repair, show Commitment and Progress.

### Example 2: University Housing Issue

| Field | Value |
| --- | --- |
| Intent | Raise Issue |
| Topic | Housing or Education |
| Jurisdiction | University campus / institution scope |
| Context | Public record created in university public space or mentions university housing |
| Participation | University participates as `ACCOUNTABLE` for campus housing; city housing office participates as `RESPONDING` for off-campus housing |
| Ownership resolution | Campus residence hall context makes university `PRIMARY_ACCOUNTABLE`; city is not accountable unless off-campus jurisdiction applies |
| Routing outcome | Route to university Public Engagement; optionally route to housing unit if unit participation exists |

Public result:

- Show Official Response from the university if provided.
- Do not imply city responsibility unless city participates and jurisdiction matches.

### Example 3: Public Health Concern

| Field | Value |
| --- | --- |
| Intent | Ask or Raise Issue |
| Topic | Healthcare or Public Safety |
| Jurisdiction | City/county/region |
| Context | Public health topic, location, possible mention of health department |
| Participation | County health department `ACCOUNTABLE`; city `RESPONDING`; hospital `REFERENCE_ONLY` unless participating |
| Ownership resolution | County health department is primary if public-health jurisdiction covers the area |
| Routing outcome | Ask routes to responding/official answer surface; Issue routes to accountable county health department if author capability allows |

Public result:

- Ask may receive Official Response.
- Issue may generate Needs Response and later commitment/progress if official action is promised.

### Example 4: Cross-Jurisdiction Issue

| Field | Value |
| --- | --- |
| Intent | Raise Issue |
| Topic | Transportation or Environment |
| Jurisdiction | Multiple cities / county boundary |
| Context | Location spans boundaries or record references multiple places |
| Participation | County `ACCOUNTABLE`; two cities `RESPONDING`; state agency `ACCOUNTABLE` for state asset |
| Ownership resolution | If asset is county-managed, county primary; if state-managed, state primary; cities secondary or referenced |
| Routing outcome | Route to primary accountable institution and secondary participating institutions; ambiguous cases held for review |

Public result:

- Public record can show multiple official responses.
- Commitments remain institution-specific.
- Do not show internal ambiguity or routing confidence.

### Example 5: Global Topic With No Jurisdiction

| Field | Value |
| --- | --- |
| Intent | Share Update |
| Topic | Technology or Environment |
| Jurisdiction | None |
| Context | General public discussion |
| Participation | No matching jurisdiction-specific participating institution |
| Ownership resolution | No accountable owner; possible topic-related institutions are references only |
| Routing outcome | No Needs Response route; record remains public discussion/update |

Public result:

- No "sent to institution" language.
- Institutions may still respond if they discover or follow the topic, but Aura does not imply accountability.

## Routing Precedence

Final recommended routing precedence:

```txt
1. Public Record
2. Intent
3. Capability
4. Context
5. Jurisdiction
6. Institution Participation
7. Institution Verification / Activation
8. Ownership Resolution
9. Routing
10. Official Response / Commitment / Progress / Resolution / Continuity
```

### Validation

This replaces the earlier simplified chain only by inserting explicit context and activation checks:

- Public Record remains the core object.
- Intent explains what the author is trying to do.
- Capability decides whether the author may do it.
- Context gathers topic, space, mentions, location, and institutional hints.
- Jurisdiction narrows the real-world scope.
- Institution participation identifies who has opted into the topic/scope.
- Verification and activation decide whether the institution can receive official routing.
- Ownership resolution determines role: accountable, responding, listening, referenced.
- Routing creates workspace items only after the above checks.

Routing is therefore an output, not the architecture's first primitive.

## Patch Impact Analysis

### Patch 1: Persist Public Record Intent and Require Topic

Recommendation: can proceed immediately.

Rationale:

- Intent and primary topic are prerequisites for every later framework layer.
- This does not require routing, ownership, or institution workflow.
- Public UX already has Ask / Raise Issue / Share Update.
- Backend should persist intent as public-record metadata, not as a separate complaint/case model.

Risk:

- Existing records need default/backfill semantics.
- Composer and feed DTOs must avoid making the product feel bureaucratic.

### Patch 2: Capability Gate for Raise Issue

Recommendation: can proceed immediately with feature flag and placeholder policy.

Rationale:

- Capability policy is required before issue routing.
- Do not hard-code permanent business logic to email/phone verification.
- Start with capabilities such as `CAN_ASK`, `CAN_SHARE_UPDATE`, `CAN_COMMENT`, `CAN_RAISE_ISSUE`.
- Assurance levels can grant capabilities through policy.

Risk:

- If verification is incomplete, gate must be feature-flagged or use a soft placeholder state.
- Public denial copy must avoid exposing private assurance details.

### Patch 3: Institution Participation and Jurisdiction Model

Recommendation: can proceed after the exact model names and fields are finalized.

Rationale:

- Routing cannot be correct without participation and jurisdiction declarations.
- Existing institution class/type/domain tags can seed setup, but they are not enough.
- Institution activation should require verified identity, official member, topic participation, jurisdiction/scope, and mode.

Risk:

- Free-text jurisdiction is not enough for durable routing.
- A normalized jurisdiction model may need a migration and careful backfill.
- Institution participation must not imply legal obligation by default.

### Patch 4: Routing Rules and Routed Engagement Items

Recommendation: do not proceed until Patch 3 exists and this ownership framework is converted into exact schema/API contracts.

Patch 4 still needs:

- Route item relationship types.
- Participation mode fields.
- Jurisdiction match semantics.
- Idempotency keys.
- Route source field.
- Confidence class.
- Admin review state.
- Feature flag.
- Public/private DTO boundaries.

Routing can be implemented safely only after participation, jurisdiction, verification, activation, and ownership resolution are explicit.

## Files Inspected

Backend:

- `aura-backend/prisma/schema.prisma`
- `aura-backend/src/posts/posts.controller.ts`
- `aura-backend/src/posts/posts.service.ts`
- `aura-backend/src/posts/dto/create-post.dto.ts`
- `aura-backend/src/institution-posts/institution-posts.controller.ts`
- `aura-backend/src/institution-posts/institution-posts.service.ts`
- `aura-backend/src/institutions/institutions.controller.ts`
- `aura-backend/src/institutions/institutions.service.ts`
- `aura-backend/src/institutions/institution-ontology.ts`
- `aura-backend/src/public-spaces/public-spaces.controller.ts`
- `aura-backend/src/public-spaces/public-spaces.service.ts`
- `aura-backend/src/discourse-intelligence/discourse-intelligence.controller.ts`
- `aura-backend/src/discourse-intelligence/discourse-intelligence.service.ts`
- `aura-backend/src/feed-signal/feed-signal.service.ts`
- `aura-backend/src/common/text/mentions.ts`
- `aura-backend/src/notifications/notifications.service.ts`
- `aura-backend/src/activity/activity.service.ts`

Frontend:

- `aura_final/docs/strategy/AURA_STATE.md`
- `aura_final/docs/AURA_ACCOUNTABILITY_ROUTING_AUDIT_PROPOSAL.md`
- `aura_final/docs/strategy/AURA_ACCOUNTABILITY_ROUTING_FRAMEWORK_ADDENDUM.md`
- `aura_final/docs/strategy/AURA_ACCOUNTABILITY_ROUTING_IMPLEMENTATION_FRAMEWORK.md`
- `aura_final/lib/features/posts/presentation/compose_screen.dart`
- `aura_final/lib/features/posts/data/post_repository.dart`
- `aura_final/lib/features/posts/domain/post.dart`
- `aura_final/lib/features/posts/widgets/post_card.dart`
- `aura_final/lib/features/posts/widgets/topic_selector.dart`
- `aura_final/lib/features/posts/domain/topic.dart`
- `aura_final/lib/features/institutions/presentation/institution_dashboard_screen.dart`
- `aura_final/lib/features/institutions/presentation/institution_activity_screen.dart`
- `aura_final/lib/features/institutions/presentation/institution_profile_screen.dart`
- `aura_final/lib/features/institutions/presentation/institution_profile_edit_screen.dart`
- `aura_final/lib/features/institutions/presentation/institution_units_screen.dart`
- `aura_final/lib/features/institutions/domain/institution.dart`
- `aura_final/lib/features/institutions/data/institution_repository.dart`
- `aura_final/lib/features/public_spaces/presentation/public_space_screen.dart`
- `aura_final/lib/features/public_spaces/data/public_space_repository.dart`
- `aura_final/lib/router/app_router.dart`
- `aura_final/lib/router/institution_paths.dart`

## Final Recommendation

Proceed with implementation in this order:

1. Persist Public Record intent and require primary topic for top-level public records.
2. Add capability policy for public intents, especially Raise Issue.
3. Add institution participation, participation mode, activation state, and jurisdiction declarations.
4. Convert this framework into exact routing schema/API contracts.
5. Add routing behind a feature flag with deterministic rules, idempotency, and private confidence.
6. Add Public Engagement workspace surfaces using product-facing language.
7. Add official response linkage.
8. Add commitment/progress/resolution lifecycle.
9. Add continuity endpoints and public continuity panels.

Do not implement Patch 4 routing from topic matching alone. The correct routeable unit is not "topic -> institution"; it is "public record intent + capability + context + jurisdiction + institution participation + verification + ownership resolution -> engagement item."
