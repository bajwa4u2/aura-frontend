# Aura — Store Listing Record, 2026-09-06

Field-by-field record of what the three store consoles held, what was changed,
and on what evidence. Kept in the repository so the words and answers that go
into a console are the same ones that were reviewed, rather than typed fresh
into a text box at submission time.

**Scope of this pass.** Listing and compliance *metadata* only. Founder ruling
on 2026-09-06: audit, edit and submit metadata changes; stop short of any
product release — no build trigger, no binary upload, no rollout, no app
version submitted for review.

`NEW_BUILD_CREATED=NO · NEW_BINARY_UPLOADED=NO · NEW_VERSION_SUBMITTED=NO · ROLLOUT_STARTED=NO`

---

## Identity, as the consoles actually hold it

| | |
|---|---|
| Apple | `org.auraplatform.app`, Apple ID `6772071135`, listed as **Aura Platform** |
| Google | `org.auraplatform.app`, Closed testing – Alpha, production never active |
| Microsoft | `AuraPlatformLLC.AURAPLATFORM`, reserved name **AURA PLATFORM** |
| Seller | Aura Platform LLC (Play developer account is Personal — see below) |
| Shipped version | 1.4.1 (36), tag `v1.4.1` |
| Version in preparation | 1.4.2 (37), client range `v1.4.1..7a10dc90` |

**The product name differs on all three stores** — "Aura Platform" (Apple),
"AURA PLATFORM" (Microsoft, reserved verbatim and validated at certification),
and Aura on Play. Recorded, not changed: the Microsoft name is load-bearing
(a prior submission failed certification when it read "Aura"), so this is a
founder decision, not a tidy-up.

---

## Apple — App Store Connect

### State found

1.4.1 (36) **Rejected**, 2026-09-04, Guideline **2.1(a) Performance — App
Completeness**, reviewed on iPad Air 11-inch (M3) / iPadOS 26.6.1:

> "We were unable to access the app because sign in button unresponsive after
> entered the demo account. Also attempted to create account, after receiving
> verification link, still unable to login and access full features"

**This is already fixed in the 1.4.2 range.** Commit `ea1f91dd` (2026-09-04)
diagnosed exactly this: `AuraInput` had no `onFieldSubmitted`, so no form built
on it could be submitted from the keyboard — and on a tablet with the keyboard
up, the Sign in button sits below the fold and Done is what a person reaches
for. Sign-in also ended on "router handles redirect", and the router treats a
null authority as stay-put, so one failed `/auth/me` left a signed-in person on
the form with no spinner, no error and nothing to press. The demo account
itself was never the problem.

1.4.2 is therefore the remediation build, not merely the next one.

### Age ratings — CHANGED, and saved

Apple required answers to two new Social Media questions by **2026-09-07**.
Both were unanswered. Two other answers were checked against the code and were
false.

| Question | Was | Now | Evidence |
|---|---|---|---|
| Unrestricted Web Access | YES | **NO** | No `webview_flutter`, no `flutter_inappwebview`, no webview import anywhere in `lib/`. All 22 `launchUrl` calls use `LaunchMode.externalApplication` or `platformDefault` — both hand the URL to the system browser and leave the app. |
| Advertising | YES | **NO** | No ad SDK in `pubspec.yaml` (no AdMob, AppLovin, Unity, Meta). Every `advertis*` hit in `lib/` is either prose or the internal sitemap sense of "advertised from inventory". No banner, no interstitial, no ad unit. |
| Social Media | *unanswered* | **YES** | Public feed, follows (`lib/core/interactions/follows_repository.dart`), publishing (`lib/core/distribution/feed_draft_publisher.dart`) and discovery. Apple's definition — redistribution or amplification through a feed that visibly spreads content to many users — describes Aura exactly. |
| Social Media Disabled for Users Under 13 | *unanswered* | **NO** | Aura does not call the Declared Age Range API. No reference in `lib/` or `ios/`. Answering YES would be a false statement about a technical control the app does not have. |

Unchanged and left alone: Parental Controls NO, Age Assurance NO,
User-Generated Content YES, Messaging and Chat YES, and every content
question on steps 2–6 (all None).

**Recalculated rating: 16+ → 13+** (171 countries; Brazil 15+, Korea 15+,
16+ in 2). Removing two false capability claims outweighed honestly adding
Social Media. Override left at Not Applicable.

**One anomaly, recorded and deliberately not acted on.** The legacy rating for
operating systems earlier than version 26 moved from *17+* to *4+*. That is
Apple's own recalculation — the legacy questionnaire has no Social Media or UGC
concept, and the old 17+ was carried almost entirely by Unrestricted Web
Access. 4+ is low for a platform with public UGC and direct messaging, and
correcting it means an explicit rating override, which changes a public rating
on judgment rather than on evidence. That is a founder decision.

### App Privacy — CHANGED, and published

Found: **2 data types — Name and Email Address** — published three months ago,
before meetings, calls, voice notes, share intake and file attachments existed.
Every other collection the app performs was undeclared.

Now **8 data types**, each *used for App Functionality*, *linked to the user's
identity*, *not used for tracking*:

| Data type | Status | Evidence |
|---|---|---|
| Name | was declared | — |
| Email Address | was declared | — |
| **User ID** | added | account and institution membership identity |
| **Device ID** | added | push token, installation id and device name sent to `POST /devices/register` (`lib/features/devices/device_service.dart`) |
| **Photos or Videos** | added | `image_picker`, posts, attachments, institution branding |
| **Audio Data** | added | `record` voice notes; WebRTC calls with recording |
| **Other User Content** | added | posts, messages, announcements, `file_picker` attachments |
| **Customer Support** | added | `POST /feedback` and `POST /support/conversations` |

Linked-to-identity is YES throughout, and that is not a formality: Aura's canon
states communication is attributable and never anonymous, so content is bound
to its author by design.

**What is deliberately NOT declared, each verified rather than assumed:**

- **No Usage Data or Diagnostics.** Firebase is `firebase_core` +
  `firebase_messaging` only. No Analytics, no Crashlytics, no Sentry.
- **No advertising data.** No ad SDK, no IDFA, nothing to track with.
- **No Location.** No location plugin. `NSLocationWhenInUseUsageDescription`
  and its Always counterpart are present in `Info.plist` but the strings
  themselves say the app does not use location — see the open item below.
- **No Contacts.** No contacts plugin.
- **No Purchases.** No `in_app_purchase`, no Stripe in the client.

### Not changed this pass, and why

- **Name / Subtitle / Category.** The subtitle field currently reads
  "Public First conversations" and is flagged *Edited* — an unsaved-to-live
  change whose casing does not match the canon's "public-first". Left for the
  1.4.2 pass, because App Information copy only reaches the public with a
  version submission and the founder has stopped this pass short of that.
- **Content Rights** reads "No, this app does not contain, show, or access
  third-party content" on a platform whose entire purpose is hosting content
  authored by other people. Flagged; changing it is a legal characterisation,
  not a metadata correction.
- **China mainland ICP filing number is absent** while China mainland remains
  an available territory. Sits alongside the unresolved MIIT/CallKit history in
  `docs/governance/CHINA_CALLKIT_JURISDICTION_REMEDIATION_2026-08-31.md`.

---

## Open items for the founder

1. **`ios/Runner/PrivacyInfo.xcprivacy` does not exist.** Apple reads this file
   out of the IPA and enforces required-reason API declarations. Orchestrate
   has one; Aura has none, which means the eight answers published above are
   the only privacy statement Aura makes, anchored to nothing inside the
   binary. If a manifest is authored, the honest sequence is to derive it from
   what the client actually collects — the audit above — and not to write one
   that merely agrees with the console.

2. **Two dead location usage strings in `Info.plist`.** They exist because
   ITMS-90683 demanded them for a linked framework, and they honestly say the
   app does not use location. They are still two permission declarations for a
   capability that does not exist, and they invite the same class of question
   that Unrestricted Web Access just cost.

3. **The legacy 4+ rating** described above.

4. **Play developer account is Personal, not Organization**, with an individual
   and a residential address as the verified identity, while both signing
   certificates carry `O=Aura Platform LLC`. Unchanged from
   `docs/governance/DISTRIBUTION_PROVIDER_STATE_2026-08-31.md`; not a
   verification blocker.

---

## Method, inherited from Orchestrate

Taken from `orchestrate/orchestrate_app/store_assets/release_notes/0.2.3.md`
and `docs/RELEASE_CERTIFICATION.md`, which did this for Orchestrate 0.2.3:

- Answer every privacy and rating question **from the code**, never from the
  previous version's answers or from another product's.
- Apple's and Google's privacy forms ask different questions; the labels are
  allowed to differ, and Google's test is whether data is transmitted off the
  device.
- Keep BUILT / INSTALLED / EXERCISED / CERTIFIED / SUBMITTED apart, and claim
  none of them loosely.
- Read the real artifact in the real place. Production beats the code that
  generates it.

---

## Google — Play Console

App id `4974271607117335943`, package `org.auraplatform.app`, listing name
**Aura**. Closed testing – Alpha, 8 testers. **Production has never been
active**, and the dashboard still shows "Apply for access to production" — a
closed test meeting Google's criteria is a precondition, so production is
gated on that, not on this metadata.

### Data safety — READ, and it is the worst of the three estates

Found: **one data type declared in the entire form.** Personal info 1/9;
every other category zero.

| Category | Declared | Should be | Evidence |
|---|---|---|---|
| Location | 0/2 | **0/2 — correct** | no location plugin |
| Personal info | **1/9** | Name, Email address, User IDs | account identity |
| Financial info | 0/4 | **0/4 — correct** | no IAP, no Stripe in client |
| Health and fitness | 0/2 | **0/2 — correct** | — |
| **Messages** | **0/3** | at least "Other in-app messages" | direct messaging is a shipped feature |
| **Photos and videos** | **0/2** | Photos, Videos | `image_picker`, posts, attachments, branding |
| **Audio files** | **0/3** | Voice or sound recordings | `record` voice notes; calls with recording |
| **Files and docs** | **0/1** | Files and docs | `file_picker` attachments, share intake, meeting materials |
| Calendar | 0/1 | **0/1 — correct** | no calendar read |
| Contacts | 0/1 | **0/1 — correct** | no contacts plugin |
| App activity | 0/5 | **0/5 — correct** | no analytics SDK |
| App info and performance | 0/3 | **0/3 — correct** | no Crashlytics or crash reporting |
| **Device or other IDs** | **0/1** | Device or other IDs | push token + installation id to `POST /devices/register` |

Encryption in transit is answered Yes, and "collects or shares required user
data types" is answered Yes — so the form is not switched off; it is switched
on and almost empty.

**Google's test is different from Apple's, and that matters here.** Google
defines collection as data *transmitted off the user's device*. Every item
above is transmitted to Aura's own backend and stored, so all of them qualify.
Nothing in this list is declarable as ephemeral — the Orchestrate pass found
exactly that error on Play (Name and Email marked "processed ephemerally" when
both persist for the life of the account) and it is the mistake most easily
repeated here.

**Not yet changed.** This is a larger rebuild than Apple's — roughly six
categories, each needing its data types selected and then, in step 4, its
purpose, shared/collected, ephemeral and required/optional answers. Recorded
here first so the answers are reviewed before they are typed.

### Not yet read this pass

Main store listing copy, screenshots, content rating (IARC) questionnaire,
target audience, news/government declarations, and the Microsoft Partner
Center estate in full.

---

## Screenshots and listing copy — READ, nothing changed

Asked directly on 2026-09-06: are the screenshots current? **Apple's are
roughly current. Play's are not, and Play's tablet sets do not exist.**

### Apple — current enough

| Set | Count | Content |
|---|---|---|
| iPhone 6.5" | **4 of 10** | profile, **Institutions** ("public ledgers of accountability… verified organizations speak under their official identity"), Spaces / pinned announcement / institutional voices, **Aura Support** |
| iPad 13" | 4 | the same four screens |
| App previews | 0 of 3 | none |

These describe the institution-and-discourse product, so they are not
misleading. Gaps rather than errors: only 4 of 10 slots used, no app preview
video, and no 6.9" set.

### Play — a different, older product

| Field | Current value |
|---|---|
| App name | `Aura` |
| Short description | "Write, publish, and engage in thoughtful public discourse on Au…" (66/80) |
| Full description | opens "Aura is a platform built for **thoughtful writing**, responsible discourse, and institutional dialogue." (1001/4000) |
| Feature graphic | wordmark over "**A space for thoughtful writing** and responsible discourse" |
| Phone screenshots | **5 of 8**, captioned "A space for thoughtful writing", "Read ideas that last", "Write with care", "Share knowledge and media", plus a founder profile |
| 7-inch tablet | **EMPTY** (required) |
| 10-inch tablet | **EMPTY** (required) |
| Chromebook | empty |

The Play screenshots are not merely old renders — they show a **different
navigation** (Home / Search / Updates / Me, "Save draft", "Post") that the
current client does not have, and they sell writing and publishing.

**This is a product-identity conflict, not just staleness.**
`PRODUCT_IDENTITY_CANON.md` states under Aura's Non-Identity Clarifications:
*"Aura is not a publishing or preservation platform for authored long-form
work — that is Bajwa Writes' domain."* Play's listing leads with "thoughtful
writing" in the short description, the full description, the feature graphic
and two screenshot captions. The live Play listing currently positions Aura
inside another product's identity.

**Nothing on any listing mentions meetings, calls or announcements** — three
shipped capabilities, and the substance of the last three releases.

### What changing them actually requires

Screenshots cannot be corrected from a console. They have to be captured from
a running build, on real device classes, against real signed-in state — the
same rule Orchestrate set: real seeded or authenticated data only, and a
designed empty state captured honestly rather than a fabricated populated one.
That is a build-and-capture task, and it is gated on 1.4.2 existing.

Copy, by contrast, can be written now against the canon and reviewed before it
is pasted.

---

## Play Data safety rebuild — ATTEMPTED, LOST, NOT APPLIED

Recorded because a failed attempt is a fact about this pass, not something to
quietly retry.

All nine data types were selected and four were fully configured (Name, Email
address, User IDs, Other in-app messages), each verified on screen before its
panel was saved. Then the Play Console renderer wedged — screenshots and script
injection timing out repeatedly across two tabs — and recovering required a
reload.

**Everything reverted.** Personal info is back to `1/9`, Messages `0/3`, Photos
and videos `0/2`, Audio files `0/3`. Play's Data safety form holds the entire
questionnaire as one **unsaved draft** until either `Save draft` is pressed or
step 5 is completed; the per-data-type `Save` button commits only inside that
draft. Nothing was published and nothing was damaged — the listing is exactly
as it was found — but nothing was gained either.

**Two corrections for the retry:**

1. Press `Save draft` after each data type, or complete all five steps in one
   uninterrupted pass. Do not navigate away mid-draft.
2. **Prefer `Import from CSV`.** The Data safety page offers `Export to CSV`
   and `Import from CSV`. Nine data types times four questions each is roughly
   forty interactions through a UI that reflows under the cursor — during this
   attempt that reflow twice checked **Analytics** as a collection purpose,
   which Aura does not have and which would have been a false declaration had
   it not been caught before saving. A CSV round-trip states the same answers
   as reviewable text and removes the whole class of error.

The intended answers are unchanged and are recorded in the table above. Nothing
about the evidence needs redoing — only the data entry.

---

## Play Data safety — CSV prepared for import, 2026-09-06

The click-through attempt above was abandoned in favour of Play's own
`Export to CSV` / `Import from CSV`. The exported file supplies the exact
question and response IDs for this app, so the schema is Google's rather than
guessed, and the answers become reviewable text instead of forty clicks
through a reflowing form.

**Generator:** `store_assets/build_data_safety_csv.py`
**Template:** `~/Downloads/data_safety_export.csv` (exported from the console)
**Output:** `~/Downloads/aura_data_safety_import.csv`

783 rows in, 783 rows out. Header, question IDs, response IDs, answer
requirements and labels are byte-identical; **only 50 response-value cells
differ**, each with a stated reason in the script.

### Ten data types declared

| Data type | Control | Purposes |
|---|---|---|
| Name | Required | App functionality, Account management |
| Email address | Required | App functionality, Account management |
| User IDs | Required | App functionality, Account management |
| Other in-app messages | Optional | App functionality |
| Photos | Optional | App functionality |
| Videos | Optional | App functionality |
| Voice or sound recordings | Optional | App functionality |
| Files and docs | Optional | App functionality |
| Other user-generated content | Optional | App functionality |
| Device or other IDs | Optional | App functionality |

All ten: **collected, never shared, never ephemeral.** No analytics, no
advertising, no personalisation purpose is claimed anywhere, because the client
has no SDK that would perform any of them.

**Required versus optional is a real distinction here, not a formality.**
Name, email and user id are required because the account cannot exist without
them. Everything else is optional because the person decides whether it is ever
collected — posting a photo, recording a voice note, attaching a file. Device
or other IDs is optional for a reason worth stating: `_fcmPayload` returns null
when no push token exists, and `_buildPayload` then registers no device at all,
so declining notification permission genuinely prevents that collection.

### Reading the real taxonomy corrected an earlier mistake

This record previously said Play's **App activity 0/5 was correct**. It was
not. Play files *"Other user-generated content"* under App activity, and Aura's
public posts, announcements and profile text are exactly that. It is now
declared. The remaining four App activity types stay undeclared: no analytics
SDK means no app-interaction telemetry, no stored in-app search history, no
installed-app inventory.

### A false answer found in passing, and corrected

`PSL_SUPPORT_DATA_DELETION_BY_USER` was answered **`DATA_DELETION_NO = true`**
— "we do not provide a way for users to request that their data is deleted" —
while the very same form already carried an account deletion URL of
`https://auraplatform.org/account-deletion`. The form contradicted itself.

Aura ships a full in-app deletion flow: `lib/screens/account_deletion_screen.dart`
at route `/account-deletion`, reachable from Security (Danger Zone → "Delete
account") and from Preferences. The CSV now answers **yes**, and populates
`PSL_DATA_DELETION_URL` with the same route the account deletion URL already
uses.

That answer is worth the founder's eye before import: it is the one change that
asserts something about a *web* endpoint rather than about client code.

### Imported and verified live, 2026-09-06

Founder imported `aura_data_safety_import.csv` and submitted. Verified in the
console afterwards:

| Category | Selected |
|---|---|
| Personal info | **3/9** — Name, Email address, User IDs |
| Messages | 1/3 — Other in-app messages |
| Photos and videos | **2/2** — Photos, Videos |
| Audio files | 1/3 — Voice or sound recordings |
| Files and docs | 1/1 |
| App activity | 1/5 — Other user-generated content |
| Device or other IDs | 1/1 |
| Location, Financial, Health, Calendar, Contacts, Web browsing, App info | **0** |

All five wizard steps show complete, no data type is left "Not started", the
store listing preview reads **"No data shared with third parties"**, and a
**Data deletion** section now appears on the preview where previously there was
none — confirming the corrected deletion answer took.

**Play's declaration went from 1 data type to 10.** `PLAY_DATA_SAFETY = CURRENT`.

---

## Microsoft — Partner Center

Product `9N6CZR88F4NT`, **AURA PLATFORM**, MSIX or PWA app, 240 markets,
**live: "In Microsoft Store"**. Submission 12, last modified 2026-09-03 — the
1.4.1 submission certified and published.

This is the only store where Aura is publicly released. Apple has 1.3.0 live
with 1.4.1 rejected; Play has never had a production track.

### Read-only, deliberately

Partner Center holds a shipped submission as read-only; changing listing text
means pressing **Start update**, which opens Submission 13. The founder is
about to submit 1.4.2, and a metadata-only Submission 13 would collide with
it. So this pass **audits and stops**, and the corrections below belong in the
1.4.2 submission rather than in a competing one.

### In better shape than the other two estates

| Field | State |
|---|---|
| Description | **On-canon.** "AURA PLATFORM is a public discourse and communication platform designed to help individuals, communities, and institutions communicate responsibly in real time… public spaces, member workspaces, and institution-focused…" |
| Product features | Public discourse and discussion platform · Realtime messaging and communication · **Voice and video calling** · Institution and community interaction · Activity notifications |
| Screenshots | 2 desktop, and they are **current** — the real desktop shell with the announcement feed and Institutional voices |
| Category | Social |
| Generative AI declaration | **Checked** |
| Age rating | IARC **12+**, ESRB **Teen**, USK 12+, Brazil 12, Russia 12+, Chile 14+, interactive elements *Users Interact* |
| Privacy policy | Provided; "product uses personal information" answered yes |

Two things worth stating plainly. **Microsoft is the only store whose listing
mentions voice and video calling**, which is the substance of the last three
releases. And it is **the only store that declares generative AI**, which Aura
genuinely has — AI-assisted, human-approved composition, and the AI-provenance
disclosure work that landed in the 1.4.2 range.

Its 12+/Teen rating is also coherent with Apple's recalculated 13+. The two
estates now agree about what kind of product this is.

### Gaps, for the 1.4.2 submission

1. **"What's new in this version" is empty** on a submission that shipped.
   Nothing tells a Windows customer what changed.
2. **Only 2 desktop screenshots.** Microsoft recommends at least 4 per device
   family, and **neither carries a caption** — both read "Add image caption".
3. **One product feature field holds two features**: "Activity notifications
   and updates Structured public co…" — two bullets concatenated into a single
   entry, so the Store renders them as one run-on line.
4. **The second screenshot carries ORCHESTRATE branding** on Aura's listing.
   It is the founder's profile page, so the mention is legitimate in context,
   but a different product's wordmark on this product's store page is worth a
   deliberate decision rather than an accident.

### Not audited this pass

Play's **content rating (IARC) questionnaire** and target-audience declarations
were not opened; only Data safety was. Partner Center's **Short description**
and **keywords** were not read.

---

## Play listing copy — CHANGED and saved, 2026-09-06

The product-identity conflict is corrected in text. Verified after reload:
short description 77 chars, full description 1,703 chars, and no occurrence of
"thoughtful writing" or "Write and publish" anywhere in the listing.

The old full description was worse than first recorded. In full it read:
"Aura is a platform built for **thoughtful writing**, responsible discourse,
and institutional dialogue… On Aura, individuals, **writers, researchers**, and
institutions can **publish reflections**… **Write and publish structured
posts**… Every contribution becomes part of a **growing archive of ideas**."

That is Bajwa Writes' identity almost line for line — authored work, writers and
researchers, a durable archive — on Aura's store page. The canon reserves all
of it: *"Aura is not a publishing or preservation platform for authored
long-form work — that is Bajwa Writes' domain."*

New copy is derived from the canon's own Identity, Scope and Non-Identity
Clarifications, and is recorded verbatim in
`store_assets/release_notes/1.4.2.md`.

**It also fixes an omission rather than only a misstatement.** No store listing
mentioned meetings, and only Microsoft mentioned calling. The new description
names public discussion, following, direct messaging with media and voice
notes, **voice and video calls, meetings**, the verified institution directory,
and announcements.

### A console mechanism worth recording

The first save silently failed. `form_input` set the DOM value — the tool even
reported the old value it replaced — but Play Console is React-controlled, and
assigning `.value` does not update React's state. Save therefore saw no change,
and a reload showed the field back at 66 characters.

The fix is to write through the prototype's native value setter and dispatch
`input` and `change`, which React observes. Confirmed by the Save button
becoming enabled, and by the values surviving a reload.

**Verify a console write by reloading and re-reading the field, never by the
tool's own success message.** A tool reporting "set value" is reporting what it
did to the DOM, not what the application accepted.

### Still image-bound, not text-bound

The **feature graphic** still reads "A space for thoughtful writing and
responsible discourse", and two screenshot captions still read "A space for
thoughtful writing" and "Write with care". Those sentences are baked into PNGs.
The listing's words are now canon-aligned; its pictures are not, and cannot be
until the images are regenerated.

---

## Android screenshots — captured from the real 1.4.2 client, 2026-09-06

Captured from the **shipped build on real hardware**, not a web build and not a
mockup. Pixel 9a (`53061JEBF08485`), Android 17 / API 37, running
`versionCode=37 versionName=1.4.2` — the frozen tag. The app's own drawer shows
"Version 1.4.2", which is the build corroborating itself in the picture.

Generators: `store_assets/build_play_screenshots.py`,
`store_assets/build_feature_graphic.py`. Raw captures kept in
`store_assets/android/screenshots/raw/`.

### The aspect-ratio trap, and why raw captures cannot be uploaded

The Pixel 9a is **1080×2424**, which is 9:20.2. Google Play accepts **16:9 or
9:16 only**, so a raw device screenshot is rejected outright. This is the same
wall Orchestrate hit and recorded.

Nothing is cropped to content and nothing is stretched. Each capture is scaled
to fit and centred on a canvas painted with the app's **own background colour,
sampled from the capture itself** (the modal colour, not a guessed hex), so the
result reads as a framed screenshot rather than a letterboxed one.

| Set | Target | Count |
|---|---|---|
| Phone | 1080×1920 (9:16) | 5 |
| 7-inch tablet | 1920×1080 (16:9) | 3 |
| 10-inch tablet | 1920×1080 (16:9) | 3 |

All eight pass Play's constraints — aspect, min/max side, and under 8 MB —
asserted by a check in the build script rather than by eye.

### What the set shows

1. **Home** — pinned institutional announcement, composer with a public scope,
   Spaces (Civic, Climate), real posts.
2. **Institutions** — "Presences participating in public", verified badges.
3. **Verified institution** — Cedarline Community Foundation, *Verified
   institution*, `cedarline.org`, United States, and a **Domains &
   verification** panel showing Verification / Domain / Jurisdiction.
4. **Messages** — read receipts with timestamps, call and video buttons in the
   thread header, voice-note and attachment controls.
5. **Discover** — people, spaces and institutions.

The tablet set is **landscape captures of the same build**, which render the
**side-rail layout** rather than a stretched phone UI — so they show a genuine
large-screen experience rather than a padded phone.

### Two capture artifacts caught and removed

- **A 3px keyboard-focus ring** appeared on every capture taken after
  `adb shell input text`. It is an artifact of automation, not part of the
  product, and would have shipped a bright yellow-green border around store
  images. Every capture is now trimmed by 4px uniformly; a check confirms
  **0 residual ring pixels**.
- **The padding colour was initially sampled from that ring**, which tinted the
  canvas green. Sampling the modal colour instead fixed it.

Both were caught by looking at the rendered output rather than trusting the
pipeline. Neither would have been visible in a log.

### Feature graphic — the last "thoughtful writing" artifact

The **live** Play feature graphic reads *"A space for thoughtful writing and
responsible discourse"*. Writing is Bajwa Writes' domain under the canon.

The repository already held a **different, unshipped** graphic reading
"Communication with continuity" — better, but not the line the listing now
makes. `build_feature_graphic.py` preserves the founder-approved sun mark,
AURA wordmark and gold rule **pixel-for-pixel** and repaints only the tagline
band, to **"Public-first civic discourse"** — the canon's own opening words and
a match for the new short description.

### Deliberately not used

- **Live** — an honest empty state, "Nothing is live right now". True, and weak
  as a store image. No live session was staged to fill it.
- **Profile** — the account's banner and avatar are a game scene and a Roblox
  character. Real, and wrong for a civic-discourse listing.
- **Bajwa Writes' institution page** — a different product's brand on Aura's
  listing, the same cross-product bleed already flagged on Microsoft.

### Raised, and answered by the founder

The device holds a personal account: Messages showed real family names, faces
and private message previews. That was put to the founder before anything was
used. Ruling: **the accounts are internal and it is his call.** Recorded here
because a store screenshot is published to the world and consent for that is
not the assistant's to assume.

---

## Microsoft screenshots — captured from the Windows 1.4.2 build, 2026-09-06

Captured from the **shipped Windows artifact**, not the web build:
`build/windows/x64/runner/Release/aura.exe`, alongside the MSIX whose size
(32,984,560 bytes) matches `RELEASE_CERTIFICATION_1.4.2.md` exactly. The app
was signed in as `review@auraplatform.org`.

Output: `store_assets/windows/store/` — 3 files at **1920×1080**, all passing
Microsoft's rules (≥1366×768, ≤3840, PNG, <50 MB), asserted by a check rather
than by eye. Raw captures in `store_assets/windows/raw/`.

| # | Surface | What it shows |
|---|---|---|
| 1 | Home | pinned 1.4.2 announcement, composer, the full **Spaces** taxonomy — Civic, Climate, Technology, Education, Health, Local, Economy, Science, Culture, Justice |
| 2 | Create | *"Say something that stands up — to a person, to the public, or on the record."* with Share / Message / Post / Article |
| 3 | Discover | People, Spaces, and **Institutions** including the **Aura Platform** presence |

The Spaces grid is the single best argument the listing has: ten named civic
contexts, rendered by the product, matching the description's claim about
public discussion far better than any sentence could.

### How they had to be captured, and why it matters

`SetForegroundWindow` is blocked by Windows' foreground lock, so the first
attempt captured **a different application's window** — another Claude
session's terminal. That was discarded, not cropped and used.

`PrintWindow` with `PW_RENDERFULLCONTENT` renders a specific window regardless
of z-order and cannot capture anything else, which is the safe primitive here.
The final set uses `SetWindowPos(HWND_TOPMOST)` plus a **client-area** capture
computed from `GetClientRect` + `ClientToScreen`, so the window frame is
excluded and only Aura's own pixels are in the file.

**A capture that contains another window is not a cropping problem, it is a
disclosure problem.** Two captures were discarded on that basis.

### Observed, and worth someone's judgement

- **The header overflows above roughly 1700px of client width.** At 1905 the
  "Live" pill is cut mid-word; at 1625 it renders fully. That is the shipped
  client's own layout behaviour on a wide desktop window, not a capture
  artifact — it reproduces across independent captures at both widths.
- **Discover's two-column layout clips its right column** at 1625 wide.
- Avatars render as plain colour discs for this account because
  `review@auraplatform.org` has no profile image. Honest, and it is why the
  reviewer account looks sparse.

Only three distinct surfaces were obtained. Driving the desktop app by
synthetic clicks proved unreliable — rail hits landed one item off and other
windows repeatedly stole the foreground — so this stops at three rather than
manufacturing a fourth. Microsoft **recommends** four; three is still an
improvement on the two currently live, and every one of them shows 1.4.2.

---

## Both consoles updated, 2026-09-06 — what was actually applied

### Google Play — applied, auto-submitted for listing review

Managed publishing is **off**, so Play sent these for review itself once its
quick checks passed. Five items in "Changes in review":

| Item | Change |
|---|---|
| Short description | → "Public-first civic discourse, where people and institutions speak accountably" |
| Full description | canon-aligned rewrite |
| Phone screenshots | 5 retired → **5 new**, 1080×1920 |
| **7-inch tablet** | **empty → 3** |
| **10-inch tablet** | **empty → 3** |
| Feature graphic | → "Public-first civic discourse" |

**The two empty tablet sets are filled.** They were the only hard blocker on
the listing — required and missing. Everything else was correcting something
that already existed.

Play accepted every image with no crop prompt and reported each as 9:16
1080×1920 or 16:9 1920×1080, which is the aspect-ratio work holding.

This is a **store-listing review only**. No build, no AAB, no rollout — it does
not touch the 1.4.2 release.

### Microsoft — Submission 13 saved as a draft, deliberately not submitted

`Store listings: Updated`. Everything else — Pricing, Properties, Age ratings,
Packages, Submission options — reads **Unchanged**.

| Field | Was | Now |
|---|---|---|
| What's new in this version | **empty** on a shipped submission | the 1.4.2 release note (476 chars) |
| Product feature 5 | "Activity notifications and updates Structured public convers" — two features concatenated and truncated | split into "Activity notifications and updates" **and** "Structured public conversations" |
| Desktop screenshots | 2, one carrying **ORCHESTRATE** branding | **3**, from the Windows 1.4.2 build |

**Submit for certification was not pressed.** A metadata-only submission would
carry the existing 1.4.1 package through certification and republish 1.4.1 —
that is a product release, and it is the founder's to trigger. The draft waits
for the 1.4.2 MSIX to be attached to it.

`NEW_BUILD_CREATED=NO · NEW_BINARY_UPLOADED=NO · MSFT_SUBMITTED=NO`

### Still open

- **Play's IARC content rating questionnaire** — never opened this pass.
- **Apple** — deferred by the founder.
- **Retired assets remain in Play's asset library** — the "thoughtful writing"
  feature graphic and the five old phone screenshots are out of the listing but
  still selectable. Worth deleting so they cannot be picked again.
- **`ios/Runner/PrivacyInfo.xcprivacy`** still absent, by deliberate decision.

---

## Play IARC content rating — AUDITED, and deliberately left alone

Opened on 2026-09-06. **No change made, and that is the finding.**

The date looked like drift — last submitted **March 11, 2026**, months before
meetings, calls, voice notes and share intake existed. Data safety had rotted
over exactly that period. This had not.

### The answers on file are still true of the shipped product

| Answer | Still correct? |
|---|---|
| Category: **Social or Communication** | yes |
| App is a social networking app | yes |
| Users or user-generated content **can be blocked** | yes |
| Users or user-generated content **can be reported** | yes |
| **Moderated chat** | yes — platform moderation and integrity infrastructure ship |

### The resulting ratings

| Authority | Rating | Interactive elements |
|---|---|---|
| ESRB | **Teen** | Users Interact |
| IARC Generic | **12+**, Parental Guidance Recommended | Users Interact |
| USK (Germany) | 12+ | Users Interact |
| ClassInd (Brazil) | 12+, Inappropriate Language | Users Interact |
| PEGI | Parental guidance | Users Interact |

**This matches Microsoft's IARC result exactly** — 12+ / Teen / USK 12+ /
Brazil 12, *Users Interact* throughout — and sits coherently beside Apple's
recalculated **13+**. Three estates, independently answered, agreeing about
what kind of product this is.

### Why nothing was resubmitted

IARC asks about **content and interaction**, not feature count. Adding calling,
meetings, voice notes and share intake does not change any answer: user-to-user
communication was already declared through *social networking* and
*Users Interact*, and moderation, blocking and reporting were already declared.

Two interactive elements are correctly **absent** and were checked rather than
assumed: **Shares Location** (no location plugin, nothing collected) and
**Digital Purchases** (no `in_app_purchase`, no Stripe in the client).

Play itself agrees: Content ratings sits under **Actioned**, not *Need
attention*, on the App content page.

**Resubmitting would have churned a correct, cross-store-consistent public
rating for no reason, and a new questionnaire issues a new IARC certificate.**
A stale-looking date is not the same as a stale answer. Data safety needed
rebuilding because the app had grown past its declaration; this had not.

---

## Apple — 6.9" screenshots captured and uploaded, 2026-09-06

Uploaded to the **iPhone 6.9" Display** slot of the in-flight 1.4.1 (36) version
record via Media Manager. Verified after a full page reload:
**6.9" = 4 of 10**, and **6.5" untouched at 4 of 10**. Additive only; nothing
existing was replaced or deleted.

### iOS capture is not Android capture

There is no `adb` equivalent. Established rather than assumed:

- **Apple Mobile Device Service is NOT installed** on this host — no iTunes, no
  Apple Devices app, no Mobile Device Support. That service *is* usbmuxd on
  Windows, so `pymobiledevice3` (installed to test) failed at
  *"Failed to connect to usbmuxd socket"*.
- Windows sees the iPhone only as an **MTP/WPD device**, which exposes DCIM and
  nothing else. No screenshot service, no input injection.
- Even with the device stack present, **iOS 26 needs a developer tunnel with
  admin rights** to capture a screenshot.

So the founder pressed the shutter and the pipeline did the rest: pull from
DCIM over MTP → verify → upload. Trust had to be granted first; before that,
Internal Storage enumerated **0 children**.

### The dimensions were already exact

Captures are **1320 × 2868**, which is precisely one of Apple's accepted 6.9"
sizes — the slot itself lists `1320 × 2868px`. **No fitting, scaling, cropping
or padding was applied**, unlike Android where the Pixel's 9:20.2 had to be
fitted onto 9:16. The files uploaded are the device's own pixels.

### The set

| # | Screen | Why it earns its place |
|---|---|---|
| 1 | Home | pinned 1.4.2 announcement, composer, Spaces, a real post |
| 2 | **Aura Platform ✓ Verified** | `@aura-platform-llc · auraplatform.org`, "a social and civic communication platform… structured dialogue", Verified institution, United States — **the institution page that could not be reached on Android** |
| 3 | **Cedarline ✓ Verified** | a real civic institution, plus a **"Follow as: You / Aura Platform"** control — institutional authority visible in the product |
| 4 | Conversation | call and video buttons in the header, a **voice message with transcript**, message withdrawal, link previews, mic and attachment controls |

**Discover was captured and deliberately not used.** It rendered one person
card with a blank avatar over mostly empty space — honest, and a poor argument
for the product. Nothing was staged to fill it.

### This closes the 6.9" gap

App Store Connect previously had **no 6.9" set at all** — one of the three gaps
recorded in the Apple audit. The others remain: only 4 of 10 slots used, and no
app preview video.

**Nothing here is public yet.** Apple publishes listing changes only with a
version submission, and 1.4.2 has not been submitted. These sit in the version
record until the founder submits.

---

## 1.4.2 submitted — Google and Microsoft, 2026-09-06

Founder submitted both. Verified in the consoles afterwards.

### Google Play

`Closed testing – Alpha · 37 (1.4.2)`, sitting in **Changes in review** with
quick checks running. Managed publishing is off, so Play sends it on once the
checks pass. **Same track 1.4.1 shipped to** — production remains inactive,
which stays a separate, deliberate decision.

### Microsoft

**Submission 13 — In certification.** Progress reads Submission →
Pre-processing → Certification → Publishing, and *"Your product will start
publishing as soon as it passes certification."*

The package was checked rather than assumed: **`aura.msix v1.4.2.0, X64`**,
`Windows.Desktop min version 10.0.17763.0`. The carried-forward 1.4.1 package
was replaced, which is the thing that had to be right — a metadata-only
submission would have recertified and republished 1.4.1 under the new listing.

`MSFT_PACKAGE = 1.4.2.0 · PLAY_VERSION_CODE = 37`

### The one unverified item, now checked and fixed

The item recorded above as **unknown** — whether the Play release carried the
drafted "What's new" — was checked. It did not.

Release **37 (1.4.2)** on the Closed testing - Alpha track carried the Play
Console default:

```
<en-US>
bug fixes and app improvements
</en-US>
```

That is the same defect found on Microsoft, in a different shape: Microsoft had
**no** release note, Play had a **placeholder** one. A placeholder is worse,
because it reads as a deliberate statement that nothing in this release matters
to anybody — on a release whose headline change is that **sign-in was broken on
tablets and now works**, which is the defect Apple rejected 1.4.1 for.

Replaced with the 440-character block from `release_notes/1.4.2.md`, verbatim
(measured: 440 of Google's 500, inside the `<en-US>` tags).

**Route.** The console would not render the track through
`/tracks/closed-testing` or `/releases/overview` — the track is custom-named
"Alpha" and lives under a numeric id, which is why several earlier attempts
found nothing. The id was read out of the DOM of the closed-testing index
(`tracks/4699039987015105878`), and the release detail reached from the track's
own **Manage release** link (`.../releases/18/details`).

**Verified by reload, not by the save confirmation.** The dialog was saved, the
page reloaded from the URL, and the field re-read: it returns the nine drafted
lines. Publishing overview then re-checked — still one pending item, *"Your
changes are now in review"*, still **Closed testing - Alpha / 37 (1.4.2)**. The
edit was absorbed into the submission already in review rather than creating a
second unsubmitted change or knocking the release back to draft. Managed
publishing is off, so it auto-submitted.

Nothing about the build, the rollout or the track was touched — the release
name `37 (1.4.2)`, the 177 countries and the 100% rollout target are as the
founder submitted them.

### Apple — submitted, 2026-09-06

Build **37 (1.4.2)** reached TestFlight (status Complete, uploaded 6:50 AM),
which removed the only real blocker. The founder then authorised the App Store
submission outright.

**The rejected record was reused rather than replaced.** 1.4.1 (36) had never
been released, so the same version record was carried forward: Version field
`1.4.1 (36)` → `1.4.2`, build 36 detached, build 37 attached. The status moved
Rejected → Prepare for Submission → Ready for Review on its own as those two
edits landed.

The Version field is worth recording separately: it literally contained
`1.4.1 (36)`. Apple's Version field takes a version string, not ASC's
`version (build)` display format. It now reads `1.4.2`.

#### What Apple actually said, and why the review note was rewritten

The rejection detail had not been read in full before this pass. It is more
specific than the summary suggested:

> Review Device: **iPad Air 11-inch (M3)**, iPadOS 26 · Version reviewed: 1.4.1 (36)
> Guideline 2.1(a): *"sign in button unresponsive after entered the demo
> account. Also attempted to create account, after receiving verification link,
> still unable to login and access full features"*

A first draft of the App Review note explained only the keyboard defect — the
Done key doing nothing because `AuraInput` had no `onFieldSubmitted`. That is
real, and it is half of it. `ea1f91dd` names a second cause, and the second
cause is the one Apple actually described:

Sign-in ended on the comment *"router handles redirect"*. The router treats an
unresolved authority as stay-put — deliberately, so nobody gets bounced — and
the authority provider returned the same empty value on ERROR as it did while
loading. **One failed `/auth/me` therefore left an already-signed-in person on
the sign-in form, with no spinner, no error and nothing to press.** That is
"the sign in button is unresponsive" exactly, and it is also why a newly
created and verified account still could not get in — Apple's second sentence,
which the first draft did not address at all.

The note was rewritten to name both causes and both symptoms, and to tell the
reviewer to retest on iPad with either the button or the Done key. Submitting
a resubmission note that answered half of a two-part rejection would have
invited the same rejection again.

#### Also changed on the way through

| Field | Was | Now |
|---|---|---|
| What's New | 1.4.1's text, ending in the stray fragment `call bug fixes` | the 1.4.2 block, 994 chars |
| Subtitle | `Public First conversations` | `Public-first civic discourse` (28/30) |
| iPhone 6.5" screenshots | 4 stale ones, led by a founder profile carrying an ORCHESTRATE banner and the words "thoughtful writing" | **empty — "Using 6.9" Display"** |

The 6.5" outcome is better than the plan. Four 1242×2688 copies were built and
uploaded, then the old set was cleared — and with the slot empty App Store
Connect falls back to scaling the 6.9" set. That is the four real 1.4.2 device
captures at their native 1320×2868, one canonical set, with no resizing or
padding of mine in the path. The built 6.5" copies in
`store_assets/ios/store_65/` are therefore unused.

#### Checked before submitting, not assumed

- Age rating **13+** in 171 countries (16+ Brazil, 15+ Korea) — pending, publishes with this version.
- `ITSAppUsesNonExemptEncryption = false` is present in `ios/Runner/Info.plist:186`, so no export-compliance prompt.
- Demo account present and flagged required; App Review contact complete.
- Release option **AFTER_APPROVAL** — it goes live automatically once approved.
- No blocking validation warnings on the version page.

#### Two steps, not one

Clicking **Update Review** on the version page moved the version to Ready for
Review — but the *submission* still sat at **Unresolved Issues**. A rejected
submission is only actually sent by opening it and pressing **Resubmit to App
Review**. Verified after reload:

`iOS Submission — Waiting for Review · iOS App 1.4.2 (37) — Waiting for Review`

The only remaining action on that page is Cancel Submission, which is what a
sent submission looks like.

### Left alone deliberately

- **Content Rights still answers "No, this app does not contain, show, or
  access third-party content."** On a platform carrying user posts, media and
  link previews to third-party sites, the accurate answer is Yes — which
  requires attesting to holding the necessary rights. That is a legal
  attestation and a founder's to make, not an engineer's, and it was not the
  ground of the rejection. Raised, not changed.
- **The 6.9" screenshot order is upload order**, leading with a conversation
  rather than Home; Apple uses the first three on install sheets. Reordering
  needs a drag that neither keyboard nor synthetic mouse events would drive,
  and the destructive rebuild was declined by the permission layer. It is a
  two-second drag in the console.
- **iPad 13" still holds the four older screenshots.** No iPad captures exist;
  that needs the device.
