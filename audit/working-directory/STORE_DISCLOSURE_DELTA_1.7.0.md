# Store privacy disclosures for 1.7.0 — what must change

21 Oct 2026 · 1:45 PM ET. Internal. Nothing here has been entered in a store
console; this states what the consoles must say once 1.7.0 ships.

1.7.0 adds connected accounts for sharing elsewhere: Facebook Page (and the
Instagram linked to it), beside the existing LinkedIn and TikTok. It also adds
Invite to Aura and share cards. The privacy policy (`lib/screens/privacy_policy_screen.dart`,
section 06) now describes them; the declarations below must agree with it.

## What connecting collects (verified in aura-backend)

| Platform | Received | Kept |
|---|---|---|
| Facebook Page | Facebook account id and name (`me?fields=id,name`), the Pages the person manages (name, picture, posting permission), the Instagram business account linked to the chosen Page (id, username) | sealed token; chosen Page id and name; granted permissions; the Facebook account id (`SocialAccount.platformAccountId`, branch `feat/meta-data-deletion`) |
| LinkedIn | `openid profile email`: id, name, email | sealed token; LinkedIn id; one of name/email as the connection's name |
| TikTok | `user.info.basic`: id, display name | sealed token; TikTok id; display name |

Aura sends only the post or announcement the member chooses to share, at the
moment they choose. It never reads feeds, messages, friends, followers or
comments (the Graph calls are `/feed`, `/photos`, `/videos` POSTs only).

Invite to Aura reads no contacts: the link goes out through the system share
sheet. Arrivals are stored only as `InviteArrivalDay(day, channel, count)`.

## Apple — App Privacy

The published answers (record of 6 Sep 2026, `store_assets/STORE_LISTING_RECORD_2026-09-06.md`)
list 8 data types. 1.7.0 needs **no new data type**, but two existing ones gain
a source and must stay declared:

- **Email Address**: also received from LinkedIn on connect. Purpose: App Functionality. Linked to identity. Not tracking.
- **User ID**: now also third-party account ids (Facebook, Facebook Page, Instagram, LinkedIn, TikTok). Purpose: App Functionality.
- Sharing to Facebook, Instagram, LinkedIn or TikTok happens only at the member's own request, so it is not "tracking" and not third-party advertising. Answer "No" to tracking, as now.

Review notes for 1.7.0 should say: connecting is optional, from Me → Connected
accounts; nothing is posted without the member choosing it; disconnect and
account deletion revoke at the platform.

## Google Play — Data safety

**Live form, read in Play Console on 21 Oct 2026** (the 6 Sep record's
"one data type declared" is stale): Personal info (Name, Email address, User
IDs, Other info), Messages, Photos and videos, Audio, Files and docs, App
activity (Other user-generated content), Device or other IDs; **no data
shared**.

1.7.0 needs **no new data type**. The existing declarations already cover
what connecting adds, provided their descriptions are read that way:

- **Email address**: now also received from LinkedIn on connect.
- **User IDs**: now including Facebook, Instagram, LinkedIn and TikTok account ids.
- Both: collected, required for App Functionality, encrypted in transit, deletable.

Shared: **keep "no data shared".** Google exempts transfers the user
initiates and reasonably expects (sharing a post to their own Facebook Page
or LinkedIn), which is the only way Aura sends anything to those platforms.

Data deletion: the account-deletion URL (`/account-deletion`) now states the
real lifecycle: the account ends at once (signed out, no sign-in, name, email,
photo, cover, bio, links and location removed, connected accounts revoked and
removed — `aura-backend` branch `fix/deletion-ends-social-connections`); the
remaining personal details (date of birth, phone number, device registrations)
go within 30 days (`ORDINARY_RETENTION_POLICY.recoveryWindowDays`, hourly
disposition); published posts, replies and announcements stay as public record
under "Deleted user"; messages stay with recipients; institution, billing,
audit and legal-hold records are kept. If the Data safety "data deletion"
answers say all data is deleted, they overstate it: published content is
retained as public record.

**Open, for the founder:** the backend has a 30-day recovery mechanism
(`AccountRetentionService.recoverAccount`) but nothing reaches it — no
endpoint calls it, admin restore refuses self-deleted accounts, and the email
is scrubbed at deletion so the person cannot sign in. The pages therefore say a
deleted account cannot be restored. Apple 5.1.1(v) expects deletion of the
account "along with associated data"; keeping published posts as public
record under "Deleted user" is a retention choice the review notes should
state plainly.

## Microsoft Store

Policy 7.20 (effective 22 Oct 2026): 11.11 age rating must stay accurate (no
change from 1.7.0); 11.12 UGC reporting/moderation (Aura has report and block).
No privacy declaration change; the privacy policy URL is the same page.

## Meta App Review

Privacy policy URL `https://auraplatform.org/privacy` must show section 06
before submission: Meta's review now re-reads the privacy policy and data
deletion URLs on every submission.
