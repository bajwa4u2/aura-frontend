# Aura 1.4.3 (38) — frozen release source and product surface inventory

Frozen 2026-09-09. This document does two things the release cannot proceed
without: it names **one** source that every 1.4.3 artifact is built from, and it
enumerates the **actual** product surface so that certification is measured
against the product rather than against the parts of it anyone happens to
remember.

---

## 1. The frozen source

A release is not a version number, it is a pair of commits. The client cannot
ship ahead of the backend on this release — the backend's global
`ValidationPipe` runs with `forbidNonWhitelisted: true`, so the reconstructed
registration and profile payloads the 1.4.3 client emits are *refused* by any
backend older than the identity merge. The two are frozen together.

| Repo | Commit | Tree |
|---|---|---|
| `aura-backend` | `0b92237` | re-frozen after the permanent Finance doorway |
| `aura_final` | `90b4383e` | re-frozen after the permanent Finance doorway |

Superseded, and left standing rather than overwritten: the first freeze was
`aura-backend d27169a` / `aura_final f9464912`, taken before the Finance entry
work. The shipped-code difference between them is four files — the Finance
doorway screen and its repository, the Android `<queries>` declaration that lets
the app resolve a browser, and two test-only dependencies named in
`pubspec.yaml`. **The artifacts built from the first freeze are therefore stale
and must be rebuilt before submission; none of them was submitted.**

Client version line, single source for all three stores:

    version: 1.4.3+38          → Android versionCode 38, iOS build 38
    msix_version: 1.4.3.0      → Microsoft Store package version

Every artifact submitted under 1.4.3 (38) must be built from these trees.

**A CORRECTION TO THIS DOCUMENT'S OWN RULE.** It first said that if either tree
moves the build number is spent and the next is 39. That is wrong, and stating
it wrongly would have cost a build number for no reason. A build number is spent
when a **store accepts an artifact under it** — that is the identifier a store
will never take twice. Before any submission, rebuilding under the same number
is ordinary and correct.

What the freeze actually buys is narrower and still worth having: an artifact
must not be submitted unless it was built from the tree named here, so a
submitted binary can always be traced to a commit. If the tree moves before
submission, the artifacts are rebuilt and this record is re-frozen — which is
what happened below.

### Store-number legality, verified in the real consoles (not from repo notes)

| Store | Highest consumed | 1.4.3 (38) |
|---|---|---|
| Apple App Store Connect | 1.4.2 (37), Sep 6 2026 | build 38 absent → uploadable |
| Google Play Console | versionCode 37, Active | versionCode 38 unused |
| Microsoft Partner Center | `aura.msix` 1.4.2.0 live | 1.4.3.0 > 1.4.2.0 → monotonic |

---

## 2. Product surface inventory

The route and controller tables below are the authority for what "the product"
means in the 1.4.3 regression matrix. Nothing may be certified by describing it;
it is certified by exercising a row here.

### 2.1 Client — `lib/router.dart`

    187  GoRoute nodes
    165  distinct declared path patterns
    124  screen/page widgets
    734  Dart files, 240,505 lines under lib/

40 feature modules:

    accountability  activity  admin  ai  ai_safety  announcements  articles
    auth  civic_signals  communications  composition  conversation
    correspondence  create  devices  direct_threads  discourse_intelligence
    discover  feed  feedback  home  identity  institution_ontology
    institutions  invitations  me  media_governance  meetings  monetization
    notifications  posts  profile  public  realtime  saves  search  share
    share_intake  support  topics  translation  updates

Route families. Counts are derived from the router by classifying all 165
declared paths, not estimated:

| Family | Paths | What a pass must hold to reach it |
|---|---|---|
| Institution space | 41 | institution authority, not merely a session |
| Member core | 24 | a signed-in member |
| Meetings and booking | 20 | member; the `/meet/*` booking pages are public by link |
| Platform administration | 16 | operator only |
| Public marketing / legal / trust | 15 | nothing |
| Publishing | 13 | a signed-in member |
| Messaging | 8 | a signed-in member |
| Auth | 7 | nothing |
| Profiles and media | 7 | mostly nothing; `/media/:id/restricted` gates |
| Public institution directory | 6 | nothing |
| Invitations | 5 | a valid invite token |
| Realtime / calls | 3 | a signed-in member in a session |
| **Total** | **165** | |

**57 of 165 routes — institution space plus platform administration — are not
reachable by an ordinary signed-in member.** That is more than a third of the
product. It is stated here so that its absence from any member-session
certification is recorded as absence, rather than passing silently because
nobody counted.

Two declared paths are Dart interpolations rather than literals
(`$kMessagesRoute/direct*`, `/meetings/$meetingId/live`); they resolve to
`/messages/direct*` and a concrete meeting id at runtime, and are counted once
each.

### 2.2 Backend — controllers

    95   controllers
    689  HTTP route decorators
    68   route modules

Ten largest, which is where the product's weight actually sits:

    92  institutions        29  conversations       23  announcements
    80  realtime            26  posts               20  external
    48  meetings            23  users               19  media
    33  admin               23  auth

`auth/finance` (2 routes) is the Finance relying-party doorway. It is present,
tested and dormant: it grants nothing until a FinanceGrant exists. Shipping it
in 1.4.3 does not activate Finance authority.

---

## 3. What this freeze does not decide

It does not decide that 1.4.3 (38) is releasable. It decides what would be
released and what would have to be certified for that judgement to be made. The
regression matrix and the store gate are separate records and reach their own
verdicts.
