# Frontend Integration Notes

Backend-only notes for later frontend work. No frontend implementation was added.

## Preferences

### Get Current User Preferences

`GET /communications/preferences/me`

Returns existing boolean fields plus additive channel/frequency fields.

Example response:

```json
{
  "id": "pref_id",
  "userId": "user_id",
  "emailEnabled": true,
  "emailMessageReceived": true,
  "socialChannel": "BOTH",
  "socialFrequency": "INSTANT",
  "messagesChannel": "BOTH",
  "messagesFrequency": "DAILY_DIGEST",
  "newsletterChannel": "EMAIL",
  "newsletterFrequency": "WEEKLY_DIGEST",
  "digestChannel": "EMAIL",
  "digestFrequency": "DAILY_DIGEST"
}
```

### Update Current User Preferences

`POST /communications/preferences/me`

Body may include legacy booleans and/or new fields:

```json
{
  "emailMessageReceived": true,
  "messagesChannel": "BOTH",
  "messagesFrequency": "DAILY_DIGEST",
  "newsletterChannel": "EMAIL",
  "newsletterFrequency": "NEVER"
}
```

Allowed channels:

- `IN_APP`
- `EMAIL`
- `BOTH`
- `NONE`

Allowed frequencies:

- `INSTANT`
- `DAILY_DIGEST`
- `WEEKLY_DIGEST`
- `NEVER`

## Digest

### Preview Digest

`POST /communications/digests/preview`

```json
{
  "frequency": "DAILY_DIGEST"
}
```

Response:

```json
{
  "frequency": "DAILY_DIGEST",
  "itemCount": 2,
  "subject": "Aura digest",
  "previewText": "2 updates waiting for you",
  "items": []
}
```

### Create Digest Record

`POST /communications/digests`

Creates or updates an idempotent backend digest draft.

```json
{
  "frequency": "DAILY_DIGEST"
}
```

## Newsletter / Product Update

### Preview Newsletter

`POST /communications/newsletters/preview`

```json
{
  "subject": "Aura update",
  "headline": "What is new in Aura",
  "body": "Short body copy.",
  "ctaLabel": "Open Aura",
  "ctaUrl": "https://auraplatform.org"
}
```

Returns rendered `subject`, `previewText`, `text`, and `html`.

### Queue Newsletter Test

`POST /communications/newsletters/test`

Queues a test `EmailOutbox` record if suppression permits.

```json
{
  "to": "person@example.com",
  "subject": "Aura update",
  "headline": "What is new in Aura",
  "body": "Short body copy."
}
```

Possible response:

```json
{
  "ok": true,
  "queued": true,
  "outboxId": "outbox_id"
}
```

Suppressed response:

```json
{
  "ok": true,
  "skipped": true,
  "reason": "suppressed"
}
```

## Contact / Support

Existing public contact endpoint behavior is preserved. Backend now also attempts a submitter acknowledgement email after creating `Contact` and `InboxMessage`.

No new frontend work is required for the acknowledgement.

## AI Drafts

### Create AI Draft

`POST /communications/drafts/ai`

Creates a draft only. It does not send.

```json
{
  "draftType": "support_reply",
  "category": "support",
  "audience": "member",
  "goal": "Reply to the member clearly.",
  "sourceText": "The member asked for help with account access."
}
```

Response:

```json
{
  "ok": true,
  "draft": {
    "id": "draft_id",
    "status": "DRAFT",
    "source": "AI",
    "subject": "Aura support update",
    "bodyText": "..."
  },
  "sendStatus": "NOT_SENT"
}
```

## Campaigns

### Create Campaign Draft

`POST /communications/campaigns`

```json
{
  "name": "April product update",
  "category": "newsletter",
  "audienceKind": "manual",
  "subject": "Aura update",
  "bodyText": "Draft body",
  "ctaLabel": "Open Aura",
  "ctaUrl": "https://auraplatform.org"
}
```

Returns:

```json
{
  "campaign": { "id": "campaign_id", "status": "DRAFT" },
  "draft": { "id": "draft_id", "status": "DRAFT" }
}
```

### Preview Campaign Draft

`POST /communications/campaigns/drafts/:id/preview`

Returns rendered `subject`, `previewText`, `text`, and `html`.

### Approve Campaign Draft

`POST /communications/campaigns/drafts/:id/approve`

Marks the draft `APPROVED`.

### Queue Approved Test

`POST /communications/campaigns/drafts/:id/test`

Requires approved draft.

```json
{
  "to": "person@example.com"
}
```

If draft is not approved, backend returns `403`.

## Preference / Unsubscribe Links

Rendered non-transactional emails include a preference footer when a preference URL is available. Frontend can later provide a user-facing route for:

- `/me/settings/communications`

Backend suppression records support future unsubscribe flows. Transactional `security-auth` and `support` categories must not be blocked by marketing suppression.

## Error Expectations

Common statuses:

- `401`: missing/invalid auth for protected communication endpoints.
- `403`: campaign test send attempted before approval or invalid operation.
- `404`: draft not found.
- `200/201`: preview, draft, queue, and preference operations.
