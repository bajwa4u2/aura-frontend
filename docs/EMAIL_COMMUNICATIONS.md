# Aura Email Communications

## Architecture

Aura uses the existing backend communication modules:

- `EmailModule` sends through Resend and owns email rendering helpers.
- `CommunicationsModule` owns in-app communications, routing, preferences, digests, drafts, campaigns, and email outbox records.
- `NotificationsModule` remains a compatibility facade over communications.
- `AttentionModule` maps canonical events into communications.
- `ContactModule` stores contact/inbox messages and sends support notifications/acknowledgements.
- `AiModule` can draft communication copy, but drafts are persisted as drafts and are never sent automatically.

In-app communication remains primary. Email is routed only when policy, preference, suppression, and category rules allow it.

## Categories

- `security-auth`: verification and password reset. Transactional.
- `support`: contact/support acknowledgements and support workflow messages. Transactional.
- `messages`: direct/correspondence messages.
- `social`: follows, likes, saves, replies, reposts, mentions.
- `institutions`: space/thread invites and institution-scoped communications.
- `announcements`: published Aura/institution announcements.
- `product-updates`: product and account updates.
- `newsletter`: newsletter/product outreach.
- `digest`: grouped summaries of eligible missed updates.
- `system`: fallback system notices.

Transactional categories must not be blocked by marketing unsubscribe/suppression. Engagement, digest, newsletter, and campaign email must respect preferences and suppression.

## Templates

Central templates live in:

- `src/email/templates/auth.template.ts`
- `src/email/templates/base.layout.ts`
- `src/email/templates/brands.ts`
- `src/email/templates/communication.template.ts`

Communication email copy is built by `src/communications/communication-email-builder.ts`.

The builder supports subject, preview text, headline, body, CTA, HTML, text, Aura branding, footer, and preference/unsubscribe footer for non-transactional categories.

Raw payload keys are not rendered. Internal fields such as `postId`, `parentPostId`, `dedupKey`, `targetKind`, `targetUserId`, `ownerId`, `returnRoute`, `interactionFamily`, `mediaMode`, `route`, raw JSON, and internal IDs are excluded.

## Routing Rules

`CommunicationRoutingService` decides:

- category
- priority
- in-app eligibility
- email mode: `none`, `immediate`, or `digest`
- preference result
- transactional override
- suppression result

Legacy boolean preferences remain supported. New channel/frequency fields are additive and backward compatible.

Channels:

- `IN_APP`
- `EMAIL`
- `BOTH`
- `NONE`

Frequencies:

- `INSTANT`
- `DAILY_DIGEST`
- `WEEKLY_DIGEST`
- `NEVER`

## Preferences

Existing endpoint behavior is preserved:

- `GET /communications/preferences/me`
- `POST /communications/preferences/me`

The response now includes additive channel/frequency fields and `preferencesJson`. Existing boolean fields are still accepted and returned.

## Digests And Newsletter Foundation

Digest services can preview and create digest records from communications with `emailMode = digest`.

Auth/security and support communications are excluded from digest queries.

Newsletter preview/test queue endpoints create safe backend output/outbox records and respect suppression.

## Support Communication

Public contact still:

1. upserts `Contact`
2. creates `InboxMessage`
3. sends internal support forwarding email

It now also attempts a support acknowledgement to the submitter. Failure to send acknowledgement does not fail contact submission.

## AI Drafting Rules

AI may draft:

- support replies
- newsletters
- product updates
- admin outreach
- institution campaigns

Rules:

- AI output is stored in `CommunicationDraft`.
- Draft status starts as `DRAFT`.
- No AI draft is sent automatically.
- Provider fallback returns draft content only.
- Safe metadata stores lengths/categories, not secrets.
- Prompts scrub obvious tokens/secrets before provider calls.

## Approval Workflow

Campaign drafts are created in `DRAFT`.

Preview is allowed for drafts. Test send/outbox queue requires `APPROVED` status. Future broadcast sends should use the same approval gate and suppression checks.

## Email Outbox

`EmailOutbox` remains compatible and now includes additive hardening fields:

- `text`
- `category`
- `templateKey`
- `idempotencyKey`
- `scheduledFor`
- `attempts`
- `lastAttemptAt`
- `providerMessageId`
- `failureReason`

Current immediate send behavior is preserved for existing communication emails, but idempotency keys are recorded for communication sends.

## Env Vars

Existing env behavior is preserved:

- `APP_NAME`
- `APP_URL`
- `APP_PUBLIC_URL`
- `RESEND_API_KEY`
- `EMAIL_FROM_AURA_HELLO`
- `EMAIL_FROM_AURA_SUPPORT`
- `EMAIL_FROM_BAJWA_NOREPLY`
- `EMAIL_FROM`
- `SMTP_FROM`
- `EMAIL_REPLY_TO`
- `CONTACT_TO_SUPPORT`
- `CONTACT_TO_HELLO`
- `OPENAI_API_KEY`
- `OPENAI_BASE_URL`
- `OPENAI_MODEL`
- `OPENAI_TIMEOUT_MS`

New optional AI draft controls:

- `AI_COMMUNICATION_DRAFT_MODE=heuristic|llm`
- `OPENAI_COMMUNICATION_DRAFT_MODEL`

## Migrations

Migration:

- `prisma/migrations/20260426000100_communication_system_upgrade/migration.sql`

The migration is additive and non-destructive.

## Test Commands

```bash
npm run postinstall
npm run build
npm test
```
