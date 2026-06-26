# Aura Accountability and Routing Framework Audit Proposal

Date: 2026-06-20

Scope: audit-derived proposal for the public composer model and the hidden institutional accountability engine.

Hard product rule: Aura must remain a social, familiar public experience. The operational routing and accountability machinery should work underneath and should not turn the product into a complaint portal.

## 1. Executive Summary

Aura already contains a strong foundation for public discourse, institutional identity, official voice, activity, notifications, topics, discourse intelligence, and accountability labels.

The key missing layer is not another public feed feature. The missing layer is a canonical routing and attention model that connects public social posts to institutional workspace action.

Current state:

- Public users can compose with Ask, Raise issue, and Share update chips.
- The composer sends topics, but public intent is not persisted in the backend.
- Topics exist as a content taxonomy.
- Institutions have ontology metadata, domain tags, members, roles, domains, units, posts, announcements, activity, spaces, and correspondence.
- Official voice exists through institution-authored posts and institution replies.
- Accountability tags exist on institution replies: COMMITMENT, UPDATE, RESOLVED.
- Discourse intelligence endpoints aggregate ongoing issues, unanswered questions, responsiveness, accountability, and participation.

Primary gap:

There is no first-class routed attention item representing:

Intent -> Topic -> Institution routing -> Institution workspace attention -> Official response -> Commitment/progress -> Resolution/closure -> Continuity record.

The minimum viable architecture should preserve the public social surface and add a private institution attention layer that indexes public posts, routes them to relevant institutions, and tracks lifecycle without making the public interface bureaucratic.

## 2. Existing Backend Assets

### 2.1 Public posts

The backend has a `Post` model with:

- author
- text
- status
- visibility
- replies and reposts
- institution attribution fields
- public space association
- primary and secondary topics
- media
- notifications and communications

Reusable value:

- Public posts should remain the source object for public questions, issues, and updates.
- Public replies and feed projection should remain the public discussion model.
- `publicSpaceId`, `primaryTopic`, and `secondaryTopics` can seed routing.

Current limitation:

- There is no persisted public `intent`.
- There is no routing status or routed institution relationship.
- There is no canonical link from a public post to institution attention workflow.

### 2.2 Institution posts and official responses

The backend has an `InstitutionPost` model with:

- institution home
- author user
- actor institution
- replies
- reposts
- visibility
- distribution
- status
- primary and secondary topics
- public space association
- accountability tag
- paid action label
- resolution and continuation pointers

Reusable value:

- Institution replies already distinguish official institutional voice via `actorInstitutionId`.
- Institution post replies can carry `COMMITMENT`, `UPDATE`, and `RESOLVED`.
- The current thread UI can already render institutional accountability events.

Current limitation:

- `resolvesInstitutionPostId` and `continuesInstitutionPostId` are scoped to institution posts, not public user posts.
- The accountability tag is attached to a reply, not to a durable commitment object.
- There is no "this is the official response to routed item X" link.

### 2.3 Topics and ontology

The backend has:

- `Topic` enum for content topics.
- Institution ontology: class, type, and domain tags.
- Public spaces.

Reusable value:

- `Topic` should remain the public content dimension.
- Institution class/type/domain tags should remain institution metadata.
- Routing can map topics and public spaces to institution domain metadata.

Current limitation:

- There is no mapping table from topic/public space/jurisdiction to institution.
- There is no routing rules engine.
- Topic selection currently supports discovery, not institutional routing.

### 2.4 Institution workspace

The backend has:

- institutions
- members
- roles
- domains
- units
- posts
- announcements
- activity events
- spaces
- correspondence
- direct threads
- notifications

Reusable value:

- A routed attention queue can live inside institution workspace.
- Activity events can record important lifecycle events.
- Notifications can alert authorized institutional members.

Current limitation:

- Institution activity is an audit/activity feed, not a work queue.
- Correspondence is private messaging, not routed public attention.
- No object stores assignment, status, acknowledgement, closure, or routing reason.

### 2.5 Discourse intelligence

The backend has read endpoints for:

- issues
- unanswered questions
- responsiveness
- related institutions
- accountability
- institution participation

Reusable value:

- These can remain public observational signals.
- They can later use routed attention and commitments for more precise measurement.

Current limitation:

- These endpoints infer signals from existing post/reply rows.
- They do not create or manage workflow.

## 3. Existing Frontend Assets

### 3.1 Public composer

The public composer has:

- Ask
- Raise issue
- Share update
- topic selector
- attachment support
- visibility
- draft save and publish

Reusable value:

- The public UI already matches the desired model.
- It should remain social and lightweight.

Current limitation:

- The intent chips are currently UX-only.
- The backend does not persist intent.
- The composer does not need to expose routing or workflow language.

### 3.2 Public thread and feed

The frontend has:

- unified feed cards
- public thread screen
- official response band
- reply units
- accountability chips
- timeline rendering for commitment, update, and resolved
- continuity cues

Reusable value:

- Public continuity can be shown without changing the public product shape.
- Official responses can remain replies in the social thread.

Current limitation:

- State labels are derived from replies/tags rather than a canonical lifecycle.
- There is no public continuity endpoint summarizing official response, open commitments, progress, and closure.

### 3.3 Institution workspace

The frontend has institution workspace routes for:

- dashboard
- profile
- edit profile
- request verification
- correspondence
- domains
- announcements
- spaces
- messages
- activity
- live rooms
- invites
- members
- join requests
- explore
- units
- billing

Reusable value:

- A new attention route can fit naturally in this workspace.
- The dashboard can show queue counters.
- Existing feed/thread cards can render routed items.

Current limitation:

- No attention queue surface exists.
- Activity is chronological, not actionable.
- Correspondence should not become the routed public attention surface.

## 4. Required Product Model

### 4.1 Public model

Public composer options:

- Ask
- Raise issue
- Share update

Public user mental model:

- "I am posting something in public."
- "I can choose a topic so the right people and institutions can find it."
- "Institutions may respond officially."
- "If an institution commits to something, Aura can show progress."

Avoid:

- complaint portal
- ticket numbers
- case ownership language
- SLA language
- department handoff language

### 4.2 Hidden operating model

Internal engine:

1. Intent captured.
2. Topic selected.
3. Routing service evaluates topic, public space, geography, institution metadata, domain trust, and explicit follows/mentions.
4. Institution attention item is created.
5. Institution workspace receives item.
6. Institution acknowledges or dismisses/misroutes.
7. Institution replies officially.
8. Institution optionally marks commitment.
9. Institution posts progress updates.
10. Institution marks resolved.
11. Item closes.
12. Public thread retains continuity record.

## 5. Proposed Minimum Data Model Expansion

### 5.1 PostIntent enum

Add:

- ASK
- ISSUE
- UPDATE

Attach to public top-level posts.

Rollout:

- nullable at first
- required for new public top-level posts after frontend/backend contract is stable
- null allowed for legacy rows and replies

### 5.2 RoutedAttentionItem

Purpose:

Canonical workflow object connecting public social content to institutional attention.

Recommended fields:

- id
- sourceType: POST, INSTITUTION_POST, PUBLIC_SPACE_THREAD, OTHER
- sourcePostId
- sourceInstitutionPostId
- sourceAuthorUserId
- intent
- primaryTopic
- secondaryTopics
- publicSpaceId
- routedInstitutionId
- routingRuleId
- routingReason
- routingConfidence
- status
- assignedUserId
- acknowledgedByUserId
- acknowledgedAt
- firstOfficialResponsePostId
- firstOfficialResponseInstitutionPostId
- lastOfficialActivityAt
- resolvedAt
- closedAt
- closedByUserId
- closeReason
- misroutedAt
- reroutedFromItemId
- createdAt
- updatedAt

Status enum:

- NEW
- SEEN
- ACKNOWLEDGED
- RESPONDED
- COMMITTED
- IN_PROGRESS
- RESOLVED
- CLOSED
- DECLINED
- MISROUTED

### 5.3 InstitutionRoutingRule

Purpose:

Declarative mapping between public content context and institutions.

Recommended fields:

- id
- institutionId
- topic
- publicSpaceId
- institutionClass
- institutionType
- domainTag
- jurisdiction
- region
- country
- priority
- active
- createdByUserId
- createdAt
- updatedAt

Notes:

- Routing rules should support many-to-one and one-to-many routing.
- Rules should be auditable and admin-visible.
- Initial version can be simple and conservative.

### 5.4 OfficialResponseLink

Purpose:

Canonical link proving that a reply/post is an official response to an attention item.

Recommended fields:

- id
- attentionItemId
- institutionId
- actorUserId
- actorInstitutionId
- responsePostId
- responseInstitutionPostId
- responseKind: ACKNOWLEDGEMENT, ANSWER, COMMITMENT, UPDATE, RESOLUTION
- createdAt

### 5.5 Commitment

Purpose:

Durable commitment object, not just a reply label.

Recommended fields:

- id
- attentionItemId
- institutionId
- sourceResponseLinkId
- sourcePostId or sourceInstitutionPostId
- summary
- status: OPEN, IN_PROGRESS, RESOLVED, CLOSED, WITHDRAWN
- dueAt
- createdByUserId
- createdAt
- updatedAt
- resolvedAt
- closedAt

### 5.6 CommitmentProgress

Purpose:

Track progress updates over time.

Recommended fields:

- id
- commitmentId
- responseLinkId
- note
- progressStatus
- createdByUserId
- createdAt

### 5.7 ContinuityRecord

Optional later abstraction:

If response, commitment, update, and resolution records become scattered, add a read-optimized continuity record or materialized view.

Minimum first pass:

- derive public continuity from attention item, response links, commitments, and progress.

## 6. Proposed API Expansion

### 6.1 Public composer APIs

Update draft and publish payloads:

- intent
- primaryTopic
- secondaryTopics
- publicSpaceId
- media
- visibility

Endpoints:

- PUT /posts/draft
- POST /posts/draft/publish

Backend behavior:

- validate intent on top-level public posts
- validate primary topic on top-level public posts
- allow null intent/topic on replies and legacy rows during rollout
- trigger routing after publish

### 6.2 Routing APIs

Internal service, not public-first:

- route newly published public post
- route updated topic/intent if still not acknowledged
- recompute route only with audit trail

Admin endpoints:

- GET /admin/routing-rules
- POST /admin/routing-rules
- PATCH /admin/routing-rules/:id
- DELETE or archive /admin/routing-rules/:id

Institution endpoints:

- GET /institutions/:institutionId/attention
- GET /institutions/:institutionId/attention/:itemId
- POST /institutions/:institutionId/attention/:itemId/ack
- POST /institutions/:institutionId/attention/:itemId/decline
- POST /institutions/:institutionId/attention/:itemId/reroute-request

### 6.3 Official response APIs

Minimum:

- POST /institutions/:institutionId/attention/:itemId/respond

Behavior:

- creates an official reply in the public thread when applicable
- creates OfficialResponseLink
- updates attention item status to RESPONDED
- emits activity and notification events

Alternative:

- use existing reply endpoints and add optional `attentionItemId`
- service creates OfficialResponseLink after validating actor rights

Preferred:

- use dedicated attention response endpoint for clarity and audit, while internally reusing existing reply creation logic.

### 6.4 Commitment APIs

Endpoints:

- POST /institutions/:institutionId/attention/:itemId/commitments
- GET /institutions/:institutionId/commitments
- POST /institutions/:institutionId/commitments/:commitmentId/progress
- POST /institutions/:institutionId/commitments/:commitmentId/resolve
- POST /institutions/:institutionId/commitments/:commitmentId/close

Behavior:

- creates public-visible reply/update when appropriate
- stores durable commitment/progress record
- emits notifications to post author, thread followers, and relevant participants

### 6.5 Public continuity APIs

Endpoints:

- GET /posts/:postId/continuity
- GET /feed/items/:type/:id/continuity

Response:

- intent
- topic
- routed institutions visible to viewer
- official response summary
- commitment count
- open commitment count
- latest progress
- resolved flag
- closed flag
- public-safe labels

## 7. Institution Workspace Representation

### 7.1 New workspace section

Recommended route:

- /institution/:institutionId/attention

Recommended nav label:

- Attention

Acceptable alternatives:

- Public attention
- Needs response
- Inquiries

Avoid:

- Complaints
- Cases
- Tickets
- Claims

### 7.2 Dashboard counters

Add dashboard cards:

- Needs attention
- Awaiting response
- Open commitments
- Recently resolved

These counters should be private to authorized institution members.

### 7.3 Attention queue list

List fields:

- public post excerpt
- author display
- intent chip
- topic
- public space
- routed reason
- status
- last activity
- assigned member
- quick action

Filters:

- All
- New
- Awaiting response
- Open commitments
- Resolved
- Closed
- Misrouted

Sort:

- newest
- oldest unanswered
- last activity
- open commitments first

### 7.4 Attention detail

Detail view should include:

- source post card
- thread preview
- routing reason
- institution status
- official response composer
- commitment controls
- progress update controls
- resolution/closure controls
- internal notes later, if needed

### 7.5 Permissions

Suggested:

- MEMBER: view items
- EDITOR: respond officially if can speak
- ADMIN/OWNER: assign, mark commitment, resolve, close, reroute/decline

Respect existing:

- InstitutionRoleGuard
- canSpeakOfficially
- official voice entitlement checks

## 8. Public Representation

### 8.1 Public composer

Keep current structure:

- Ask
- Raise issue
- Share update
- Topic
- Attachments
- Visibility

Do not show:

- routed institutions before publish unless explicitly designed as discovery
- case status
- assignment
- workflow terms

### 8.2 Public cards

Use light labels:

- Asked
- Issue raised
- Update shared
- Official response
- Update from institution
- Resolved

Avoid:

- ticket created
- routed to department
- awaiting assignee
- closed by agent

### 8.3 Public thread

Keep official responses as replies.

Show:

- official response band
- commitment/update/resolved timeline
- "Resolved" or "Answered" label when lifecycle reaches public closure
- continuity panel where useful

Hide:

- private routing reason
- internal assignee
- declined/misrouted details unless institution publishes a public note
- admin-only notes

## 9. End-to-End Implementation Sequence

### Phase 1: Contract hardening

Goal:

Persist public composer intent and make topic contract explicit.

Backend:

- Add `PostIntent` enum.
- Add nullable `Post.intent`.
- Update public post DTOs to include `intent`, `primaryTopic`, `secondaryTopics`.
- Stop relying on `any` for public draft payloads where possible.
- Validate intent/topic for new top-level public posts.

Frontend:

- Send intent in compose payload.
- Block publish if no intent or primary topic for top-level public post.
- Keep UI language unchanged.

Checks:

- backend unit tests for draft save and publish
- frontend widget test for intent/topic required publish
- smoke test publish Ask, Issue, Update

Rollback:

- keep field nullable
- ignore intent server-side if needed
- frontend can stop sending intent without breaking legacy rows

### Phase 2: Routing foundation

Goal:

Create minimal routing rules and attention items.

Backend:

- Add `InstitutionRoutingRule`.
- Add `RoutedAttentionItem`.
- Add routing service.
- Trigger routing after public post publish.
- Emit institution activity and notifications when item is created.

Frontend:

- No public UI change.
- Add hidden or basic institution attention list if backend is ready.

Checks:

- route by topic to configured institution
- no route when no active rule
- no duplicate attention item for same source/institution
- routing audit stored

Rollback:

- disable routing trigger behind feature flag
- preserve data without surfacing queue

### Phase 3: Institution attention workspace

Goal:

Give institutions a private surface to process routed public posts.

Backend:

- GET attention list.
- GET attention detail.
- POST acknowledge.
- POST decline/misrouted.

Frontend:

- Add `/institution/:institutionId/attention`.
- Add dashboard counters.
- Use existing post/thread card components.
- Add filters and empty states.

Checks:

- member can view
- non-member cannot view
- admin/editor actions work by role
- queue updates after acknowledge

Rollback:

- remove nav entry while keeping backend data
- attention records remain auditable

### Phase 4: Official response linkage

Goal:

Connect institution replies to attention items.

Backend:

- Add `OfficialResponseLink`.
- Add response endpoint or extend existing reply endpoint with attention item id.
- Reuse official voice validation.
- Update attention status to RESPONDED.
- Notify source author and thread followers.

Frontend:

- Add official response composer/action from attention detail.
- Deep link back to public thread.
- Public thread continues rendering official replies.

Checks:

- only authorized institution speakers can respond
- response appears publicly
- response is linked to attention item
- duplicate first-response handling is stable

Rollback:

- response remains a normal public reply even if link creation fails
- retry link creation from audit job

### Phase 5: Commitments and progress

Goal:

Make commitments durable and auditable.

Backend:

- Add `Commitment`.
- Add `CommitmentProgress`.
- Create commitment from official response or attention detail.
- Add progress and resolve endpoints.
- Map legacy accountability tags to new commitment events where possible.

Frontend:

- Add commitment controls for admins.
- Show open commitments in attention queue.
- Keep public labels lightweight.

Checks:

- commitment creation requires official response or explicit institutional actor
- progress appears in public thread/continuity
- open commitment count is correct
- resolution cannot close unrelated commitment

Rollback:

- keep existing accountability tags as display fallback
- commitment tables can be ignored by frontend until stable

### Phase 6: Resolution and closure

Goal:

Close the lifecycle without exposing bureaucratic language publicly.

Backend:

- Resolve attention item.
- Close attention item.
- Add public continuity endpoint.
- Emit notifications and activity.

Frontend:

- Add resolve/close controls in attention detail.
- Public thread shows "Resolved" or "Answered".
- Activity/notifications deep link to thread.

Checks:

- resolved item remains readable
- closed item no longer appears in active queue
- public continuity hides internal assignee and routing metadata

Rollback:

- mark items reopened
- leave public thread unchanged

### Phase 7: Analytics and hardening

Goal:

Use the canonical lifecycle for better discourse intelligence.

Backend:

- Update discourse intelligence to use attention and commitment records where available.
- Add indexes for queue/status queries.
- Add admin tools for routing health.

Frontend:

- Add institution-level continuity summaries.
- Add empty/loading/error states.

Checks:

- query performance on large data
- privacy review for all public continuity fields
- migration tests for legacy posts

Rollback:

- discourse endpoints can fall back to existing inference queries

## 10. Risk Register

### Product risks

Risk: Public users experience Aura as a complaint system.

Mitigation:

- Keep public labels social.
- Hide queue terminology.
- Do not expose assignment, routing, or case identifiers.

Risk: Institutions feel publicly shamed by routed issues.

Mitigation:

- Make routing private by default.
- Public official response is voluntary.
- Misrouting and decline actions are internal unless institution publishes a note.

Risk: Users expect guaranteed service levels.

Mitigation:

- Avoid SLA language.
- Use "may respond", "official response", and "updates" language.

### Data risks

Risk: Topic-only routing creates false positives.

Mitigation:

- Use institution domain tags, public spaces, jurisdiction, and explicit rules.
- Start conservative.
- Allow misroute/decline without public penalty.

Risk: Duplicate attention items.

Mitigation:

- Unique constraint on source object plus routed institution.
- Idempotent routing service.

Risk: Legacy rows lack intent/topic.

Mitigation:

- Keep fields nullable initially.
- Backfill only where reliable.
- Do not infer sensitive issue intent from old text automatically.

### Permission risks

Risk: Unauthorized member responds officially.

Mitigation:

- Reuse InstitutionRoleGuard.
- Check canSpeakOfficially.
- Preserve official voice entitlement checks.

Risk: Public continuity leaks internal workflow.

Mitigation:

- Separate internal attention detail DTO from public continuity DTO.
- Public endpoint returns only safe fields.

### Migration risks

Risk: Existing accountability tags conflict with new commitments.

Mitigation:

- Treat tags as legacy display/event hints.
- Add durable commitment records going forward.
- Optionally create commitments from old COMMITMENT-tagged replies in a careful backfill.

Risk: Two post systems create confusion.

Mitigation:

- Keep public user posts as public roots.
- Use institution replies as official responses where possible.
- Do not duplicate public roots into institution posts unless explicitly required.

### Technical risks

Risk: Queue queries become expensive.

Mitigation:

- Index institutionId/status/updatedAt.
- Index source post id.
- Cap page sizes.

Risk: Notification fanout becomes noisy.

Mitigation:

- Notify author and explicit followers first.
- Batch lower-priority updates.
- Use existing notification preference infrastructure.

Risk: Routing side effects break publish flow.

Mitigation:

- Routing should be best-effort after successful publish.
- Failed routing should log and retry, not block post creation.

## 11. Acceptance Criteria

End-to-end readiness requires:

1. Public user can publish Ask, Raise issue, and Share update with required topic.
2. Backend persists intent and topic.
3. Routing service creates attention items for configured institutions.
4. Institution member sees item in private attention workspace.
5. Authorized institution actor can acknowledge item.
6. Authorized institution actor can post official response.
7. Official response appears in public thread and links to attention item.
8. Institution can create a commitment.
9. Institution can post progress update.
10. Institution can mark resolved and close.
11. Public thread shows calm continuity labels.
12. Internal queue shows precise operational state.
13. Notifications and activity events are emitted.
14. Public users never see internal assignee, routing confidence, private notes, or case-like workflow language.
15. Tests cover routing, permissions, official response linkage, commitment lifecycle, and public DTO privacy.

## 12. Files Inspected During Audit

Backend:

- aura-backend/prisma/schema.prisma
- aura-backend/src/app.module.ts
- aura-backend/src/main.ts
- aura-backend/src/posts/posts.controller.ts
- aura-backend/src/posts/posts.service.ts
- aura-backend/src/posts/dto/create-post.dto.ts
- aura-backend/src/institutions/posts/institution-posts.controller.ts
- aura-backend/src/institutions/posts/institution-posts.service.ts
- aura-backend/src/institutions/posts/dto/create-institution-post.dto.ts
- aura-backend/src/institutions/posts/dto/set-accountability.dto.ts
- aura-backend/src/institutions/activity/institution-activity.controller.ts
- aura-backend/src/institutions/activity/institution-activity.service.ts
- aura-backend/src/discourse-intelligence/discourse-intelligence.controller.ts
- aura-backend/src/discourse-intelligence/discourse-intelligence.service.ts
- aura-backend/src/feed/feed.module.ts
- aura-backend/src/posts/posts.module.ts
- aura-backend/src/institutions/institutions.module.ts

Frontend:

- aura_final/lib/router.dart
- aura_final/lib/core/institutions/institution_paths.dart
- aura_final/lib/features/posts/presentation/compose_screen.dart
- aura_final/lib/features/topics/topic.dart
- aura_final/lib/features/topics/aura_topic_selector.dart
- aura_final/lib/features/institutions/data/institutions_repository.dart
- aura_final/lib/features/institutions/presentation/institution_dashboard_screen.dart
- aura_final/lib/features/institutions/activity/institution_activity_screen.dart
- aura_final/lib/features/institutions/correspondence/institution_correspondence_screen.dart
- aura_final/lib/features/public/data/institution_action_repository.dart
- aura_final/lib/features/public/widgets/institution_action_sheet.dart
- aura_final/lib/features/public/presentation/thread_screen.dart
- aura_final/lib/features/public/widgets/reply_unit.dart
- aura_final/lib/features/feed/domain/feed_item.dart
- aura_final/lib/features/discourse_intelligence/widgets/discourse_continuity_panel.dart
- aura_final/lib/features/discourse_intelligence/providers.dart

## 13. Recommended Next Patch List

Patch 1:

- Add `PostIntent` enum and nullable `Post.intent`.
- Add DTO validation for public draft/publish intent and topics.
- Persist intent from composer.

Patch 2:

- Add routing tables and idempotent routing service.
- Add post-publish routing hook behind feature flag.

Patch 3:

- Add institution attention list/detail APIs.
- Add workspace route and dashboard counters.

Patch 4:

- Add official response link.
- Wire response from attention detail to existing official reply path.

Patch 5:

- Add commitment and progress records.
- Migrate public timeline rendering to canonical lifecycle where available.

Patch 6:

- Add resolve/close actions and public continuity endpoint.
- Update discourse intelligence to prefer canonical records.
