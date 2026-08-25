# Create Landing Surface — census, taxonomy, reconstruction

Founder ruling 2026-08-25. Regression gates: `test/create/create_landing_test.dart`
(12), `test/create/create_hub_domains_test.dart` (frozen vocabulary),
`integration_test/create_landing_test.dart` (5, real clients).

---

## 1. Census

### Creation routes in the registered population — 12

| route | renders | disposition |
|---|---|---|
| `/create` | CreateHubScreen | **the landing** |
| `/compose` | ComposeScreen | Post — on Create |
| `/articles/write`, `/articles/write/:id` | ArticleEditorScreen | Article — on Create |
| `/messages/new` | NewConversationPicker | Message — on Create |
| `/announcements/create` | AnnouncementEditorScreen | Announcement — on Create, authority-gated |
| `/institution/:id/posts/new` | InstitutionPostComposerScreen | contextual only |
| `/institution/:id/announcements/new` | (institution scope) | contextual only |
| `/institution/:id/meetings/new` | CreateMeetingScreen | contextual only — **frozen**, and Meetings are protected |
| `/institutions/get-started` | InstitutionOnboardingWizard | acquisition, not Create (frozen) |
| `/invite/create` | InviteCreateScreen | not Create (frozen) |
| `/institution/create` | — | redirect alias → onboarding `?mode=create`. Legitimate, not dead |

### Other Create-facing surfaces

* **Entry actions** that lead to a creation destination: 10 literal sites, plus
  the landing's own cards. After this pass, 8 `push` / 2 `go` — the two
  remaining `go` are flow-completions.
* **Non-route creation surfaces**: 9 sheets/dialogs (space creation, unit
  creation, domain add, meeting assets…). None promoted — see §14 below.
* **Shell entry**: Create is one of the four founder-approved primaries; the
  rail/bottom-bar entry is `PrimaryDestination.create`. There is no FAB.

---

## 2. Canonical taxonomy — unchanged, and deliberately so

The frozen intent vocabulary (founder §5, 2026-08-16) already answers this, and
the evidence gave no reason to reopen it:

| outcome | canonical destination | acting identity | authority |
|---|---|---|---|
| **Message** | `/messages/new` | the person | signed in |
| **Post** | `/compose` | the person | signed in |
| **Article** | `/articles/write` | the person | signed in |
| **Announcement** | `/announcements/create[?scope=institution]` | person **or** institution | platform admin, or institution `authorizedSpeaker` |

Everything else that can be created lives where its context is: institution
posts and announcements in the workspace, meetings in the institution that owns
them, spaces on the Spaces surface, invitations in Connections.

**No new capability was invented to fill a grid, and none was hidden.**

---

## 3. Findings

| # | class | finding | status |
|---|---|---|---|
| 1 | navigation / return | Cards navigated with `context.go`, replacing the stack — cancelling the composer landed on **`/home`**. Verified live before the change | **FIXED** |
| 2 | reachability | Four sections of one card each pushed **Message** below the fold on a laptop | **FIXED** |
| 3 | loading-state | Institution access read with `orElse: none` — "still finding out" rendered as "you cannot", and the Announcement card popped in late | **FIXED** |
| 4 | copy / framing | The hero enumerated the same four things the cards enumerate | **FIXED** |
| 5 | navigation (shared) | A stale return control outlived the destination it was drawn for — Create kept the composer's "✕ Cancel" after returning. Founder-reported | **FIXED** |
| 6 | navigation (shared, out of Create) | Feed "View original" used `go` — the reply the reader came from was gone | **FIXED** |
| 7 | **publishing, end to end** | LinkedIn syndication could not read Aura's own media; every image post failed and blamed the file | **FIXED** (backend) |
| 8 | authority presentation | A platform admin who has not opened `/admin` this session sees no platform-announcement option on Create | **BY DESIGN, recorded** — the no-probe contract is deliberate and the path exists in the admin workspace |
| 9 | product framing | The Post composer offers TikTok/LinkedIn syndication under "Publish elsewhere" | **RECORDED — founder decision**, see §6 |

**Before: 7 executable defects. After: 0.**

---

## 4. The publishing defect, in full

Founder-reported: *"my post with the LinkedIn button failed to send on LinkedIn."*

Two hypotheses were tested and **disproved** before the real one was found:

* token expiry — the connection is valid until 2026-10-03 and carries
  `w_member_social`;
* the governed delivery door — `/media/:id/raw` returns **200** unauthenticated
  for those very media ids.

The actual cause: `prepareLinkedInImages` fetched the media's **stored** URL
with no credentials. That URL is the storage host,
`uploads.auraplatform.org/...`, which answers **401** to an anonymous caller —
media custody working exactly as designed. Verified directly on both the
derivative and the original.

So the read was refused, the image was skipped, and the person was told:

> "This Aura post has image attachments, but none are LinkedIn-compatible."

about a 2 MB PNG that was perfectly compatible. Every recent post carries
exactly one image, so **LinkedIn syndication had been failing for all of them**,
behind a message describing a cause nobody could act on.

**Repair:** the publisher reads through a short-lived signed read
(`keyFromPublicUrl` + `getSignedReadUrl`) — the same governed mechanism
`MediaService` uses. It does not require public exposure, and a URL that does
not reverse to a storage key is left untouched. The message no longer asserts a
format problem it cannot know, on **both** the post and announcement paths.

---

## 5. Navigation, authority, context

* **Return** is the canonical `ReturnPathAuthority` — Create invents nothing.
  Create is `ROOT_NO_RETURN`; the creation flows are `FLOW_CANCEL`, so they
  present **Cancel**, not Back.
* **Deep/cold entry**: entering `/compose` directly still cancels somewhere
  legitimate (the contextual fallback), because the authority resolves from the
  destination rather than from history that does not exist.
* **Acting context**: Create asks *as whom* in the one place a genuine choice
  exists — the announcement scope — and names the institution rather than
  saying "Institution". Everything else is the person. No role-as-permission
  shortcut: institution authority comes from `InstitutionAccessState.authorizedSpeaker`.

---

## 6. Founder decisions

**One, and it is a product-framing question, not an engineering one.**

The Post composer offers **"Publish elsewhere → TikTok / LinkedIn"**. That is a
real, working capability (now genuinely working, per §4) and it is squarely
inside the copy doctrine §9 warns about: syndication to consumer social
platforms is the shape of creator-economy product framing, and Aura's premise
is purposeful, accountable communication.

It is not a defect and it was not touched. Whether third-party syndication
belongs in Aura's canonical Post lifecycle — and if so, how it should be framed
— is a decision about what Aura is, and it is yours.

---

## 7. Modal vs route (§14)

Nothing promoted. The 9 non-route creation surfaces are all transient and
context-dependent (create a space from the Spaces list, add a unit, add a
domain). None needs deep linking, restoration, shareability or durable
continuation. Classified by behaviour, not by size.

---

## 8. Protected boundary

**Meetings and Live were not modified.** Create's only relationship to them is
that institution meeting creation stays contextual-only, which is a frozen rule
this pass preserved rather than revisited. No Create-side defect inside the
protected systems was found.

---

## 9. Certification

> **Harness note.** Run as a single file, the Android Create suite finds the
> session and passes 5/5. Run as the whole `integration_test` directory it
> reports SKIPPED — each test file boots the app and calls `/auth/refresh`,
> whose refresh token is single-use, so the second boot invalidates the first
> one's session. A harness artefact, not a product defect, and stated rather
> than papered over.

| platform | result |
|---|---|
| **Web (live production)** | **PASS** — Create renders three person outcomes plus Announcement for an authorized speaker; Post → composer → Cancel returns to Create with no stale control |
| **Windows native (real session)** | **PASS 5/5** — including composer-cancelled-back-to-Create |
| **Android — physical Pixel 9a** | **PASS 5/5** — with a real session (founder signed in on the debug build, 2026-08-25). Outcomes present, no false Back, **composer cancelled back to Create**, phone geometry, device render + touch target > 44 px, reduced window |
| **iOS** | **NOT EXECUTED** — no TestFlight/iOS environment on this host |

### iOS implementation thesis

Create introduces no platform-coupled behaviour: no hover-only affordance, no
desktop-only geometry assumption, no Android-specific navigation. It composes
`AuraScaffold` and `AdaptiveCardGrid` — both already exercised on iOS-shared
code paths — and its cards are ordinary `InkWell` targets sized above the
44 px minimum, which is the iOS guidance as well as Android's. The governed
return control is the same one certified on Android and Windows, and it uses no
platform channel. Safe areas come from the shell, unchanged by this work.

**That is a thesis, not evidence.** `CREATE_IOS_CERTIFICATION = NOT_EXECUTED`.
