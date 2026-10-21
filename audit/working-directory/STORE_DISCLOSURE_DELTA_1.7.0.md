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

**Read the live form first.** The 6 Sep record found it declaring one data
type, and the rebuild attempted that day was lost before saving. Unless it has
been completed since, the form under-declares Aura as it already is, and 1.7.0
adds to that. Use `Import from CSV` as that record recommends.

Collected (all: required for App Functionality, encrypted in transit, can be
deleted on request):

- Personal info: **Name**, **Email address** (now also from LinkedIn), **User IDs** (now including Facebook, Instagram, LinkedIn and TikTok account ids).
- Pre-existing types still missing per the 6 Sep record: Other in-app messages, Photos, Videos, Voice or sound recordings, Files and docs, Device or other IDs.

Shared: **none needs declaring for connected accounts.** Google exempts
transfers the user initiates and reasonably expects (sharing a post to their
own Facebook Page or LinkedIn). Keep "Shared" as declared today.

Data deletion: the account-deletion URL (`/account-deletion`) now states that
connected accounts are disconnected at once; account deletion revokes and
removes them (`aura-backend` branch `fix/deletion-ends-social-connections`).

## Microsoft Store

Policy 7.20 (effective 22 Oct 2026): 11.11 age rating must stay accurate (no
change from 1.7.0); 11.12 UGC reporting/moderation (Aura has report and block).
No privacy declaration change; the privacy policy URL is the same page.

## Meta App Review

Privacy policy URL `https://auraplatform.org/privacy` must show section 06
before submission: Meta's review now re-reads the privacy policy and data
deletion URLs on every submission.
