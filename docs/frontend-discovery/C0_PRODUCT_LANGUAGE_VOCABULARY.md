# C0 — Exact Implemented Product Language Vocabulary

**Source of truth for this document:** `lib/core/product/product_language.dart`, read directly. Every row below is what is *actually in the file*, not a description of intent.

**Date:** 2026-08-15 · **Status:** ✅ **FROZEN / FOUNDER APPROVED 2026-08-15.** The final C0 vocabulary. Later chapters consume it; they do not redefine it.

Provenance columns follow the read-only Representation pass — see `REPRESENTATION_CANONICAL_FRONTEND_ALIGNMENT.md`.

---

## 1. Canonical nouns — `ProductNoun` (13 implemented)

| Semantic concept | Implemented term | Plural | Frozen decision source | Representation canonical source | Alignment | Action |
|---|---|---|---|---|---|---|
| A platform human | **Person** / People | People | 🧊 **FROZEN 2026-08-15: Person is THE canonical human identity** · FD-10/FD-11 | `AURA_REPRESENTATION_MODULE_INVENTORY` — Aura Identity: *"every Aura **member**"* → ⛔ reconciled as stale-for-identity | ✅ **RESOLVED** | applied; gate-enforced |
| An organisation | **Institution** / Institutions | Institutions | FD-10 | `PRODUCT_IDENTITY_CANON` — *"a government body, university, company, association, or public office"* | ✅ ALIGNED | none |
| Contextual membership status | **Member** / Members | Members | 🧊 **FROZEN 2026-08-15: Member is a contextual relationship status, never an identity** · FD-10 `MEMBER != PARTICIPANT` | Institutional membership; `INSTITUTION_SPACE_MEMBERSHIP_DOCTRINE` | ✅ **RESOLVED** | 💬 "Aura member" stays valid prose only where it means *a Person holding that membership* |
| Session-scoped presence in an interaction | **Participant** / Participants | Participants | FD-10 `MEMBER != PARTICIPANT` (durable vs session) | Backend invariant `SPACE MEMBER → THREAD PARTICIPANT → DM PARTICIPANT`; `MeetingParticipant` = *"call admission/attendance state"* | ✅ **ALIGNED** — backend confirms the distinction | none |
| Conversation container | **Thread** / Threads | Threads | FD-10 `THREAD != SPACE` | **NO FROZEN REPRESENTATION NOUN.** Appears only as implementation evidence inside Correspondence: *"Spaces, threads, messages, direct threads"* | ⚠ FRONTEND-ONLY | acceptable — implementation-level noun |
| Membership-scoped container | **Space** / Spaces | Spaces | FD-10 `THREAD != SPACE` | Discovery module feature: **"Public Space Discovery"**; Correspondence evidence | ✅ ALIGNED | none |
| Scheduled/booked interaction | **Meeting** / Meetings | Meetings | FD-10 `MEETING != ROOM != LIVE` | Frozen module **Meetings & Live** — *Meetings; Availability and Booking; Meeting Admission* | ✅ ALIGNED | none |
| Institution drop-in space | **Room** / Rooms | Rooms | FD-10 `MEETING != ROOM != LIVE` | **NO CANONICAL REPRESENTATION SOURCE FOUND.** "Institution Room" is a backend (D5) construct | ⚠ FRONTEND/BACKEND ONLY | C8 must not imply canonical status |
| Broadcast / public-stage mode | **Live** | *Live* (identical) | FD-5 — Live is a governed **mode/state** of an existing Thread or Space | Frozen module records *"'Live' founder-asserted, **evidence thinner**"* | ⚠ **OPEN → C10** | not raised as blocking: FD-5 makes Live a mode, so a plural may legitimately never be needed |
| Unit of conversation | **Message** / Messages | Messages | FD-10 `CORRESPONDENCE != MESSAGE/DM` | Correspondence evidence: *"messages, direct threads"*. Framing directive: Aura is *not messaging software* | ✅ LEGITIMATE CONTEXTUAL DIFFERENCE (**D-3**) | none — directive binds representation, not UI nouns |
| Governed formal communication | **Correspondence** | *Correspondence* (mass noun) | 🧊 **FROZEN 2026-08-15: ONE canonical meaning — the governed formal/deliberate communication form** · FD-10 | ⛔ Umbrella sense (*"Spaces, threads, messages, direct threads"*) = **LEGACY / ARCHITECTURAL NAMING DRIFT**, canonical status withdrawn | ✅ **RESOLVED** | **C7 obligation**: rename/migrate the umbrella safely. Paths may lag until C7; docs and this authority may not |
| Canonical publication object | **Post** / Posts | Posts | FD-10 — Post is canonical; Works may only be a projection | Frozen module **Public Discourse** — *Public Posts; Institution Posts; Replies; Unified Feed* | ✅ **ALIGNED** | none |
| Formal institutional statement | **Announcement** / Announcements | Announcements | FD-10 | Frozen module **Institutional Communication** — *Announcements* | ✅ **ALIGNED** | none |

### Concepts requested for review that are **NOT implemented as nouns**

| Concept | Implemented? | Representation source | Verdict |
|---|---|---|---|
| **Works** | **No** | **NO CANONICAL REPRESENTATION SOURCE FOUND** — zero matches in the canonical body | ✅ Correct to omit. FD-10 allows it only as a curated projection, never a competing publication model |
| **Profile** | **No** | Aura Identity directive: *"is **not** … Member Profiles — those are implementation mechanisms"* | ✅ Correct to omit — a surface, not a product noun |
| **Presence** | **No** | Audit: *"single-actor, stateless online/recency heartbeat … a technical realtime-signalling concern"* | ✅ Correct to omit. C2 retires the six-meaning overload |
| **Connect** | **No** | *"Literal 'Relationship'/'Connection' — **zero matches** … Does not exist under this name anywhere in the codebase"* | ✅ **Must stay omitted** |
| **Official designation** | **No** | 🔧 Backend `OfficialPublicationDesignation`; FD-8 pre-publication designation only | ⚠ **OPEN — C5.** Deliberately not added in C0: the vocabulary must follow the publication surface that presents it |
| **Institutional approval** | **No** | 🔧 Backend E_OFFICIAL approval floor (`REQUIRE_INSTITUTIONAL_APPROVAL`) | ⚠ **OPEN — C5**, same reason |

> Per the standing instruction, **no verification label appears anywhere in this vocabulary**. No generic "Verified" has been used to close the map. Verification semantics return separately at the C2 checkpoint.

---

## 2. The four stop/undo families — `StopIntent` (4 implemented)

FD-10 correction: these are **not** synonyms. My original premise that they were was wrong and was withdrawn.

| Semantic concept | Implemented label | Meaning implemented | Representation source | Alignment |
|---|---|---|---|---|
| Stop an operation that has **not completed** | **Cancel** | withdraw an in-flight intent | NO CANONICAL SOURCE — interaction vocabulary | FRONTEND LANGUAGE ALIGNED (FD-10) |
| Remove from current attention **without deleting** | **Dismiss** | attention projection cleared, object untouched | NO CANONICAL SOURCE | FRONTEND LANGUAGE ALIGNED (FD-10) |
| Close a view/panel/sheet | **Close** | no cancellation, no deletion implied | NO CANONICAL SOURCE | FRONTEND LANGUAGE ALIGNED (FD-10) |
| Abandon **unsaved** composition | **Discard** | uncommitted draft work abandoned | NO CANONICAL SOURCE | FRONTEND LANGUAGE ALIGNED (FD-10) |

---

## 3. Canonical actions — `ProductAction` (26 implemented)

| # | Action | Canonical label | Contextual variant | Retired / constrained term | Representation source | Alignment |
|---|---|---|---|---|---|---|
| 1 | `retry` | **Retry** | — | **`Try again` (33 sites migrated)**, `retry operation`, `try once more` — banned outright | NO CANONICAL SOURCE | FRONTEND ALIGNED (FD-10) |
| 2 | `refresh` | **Refresh** | — | constrained **positionally**: may not be the label of a recovery action | NO CANONICAL SOURCE | FRONTEND ALIGNED |
| 3 | `reload` | **Reload** | app/update gate | constrained positionally | NO CANONICAL SOURCE | FRONTEND ALIGNED |
| 4 | `cancel` | **Cancel** | — | not interchangeable with 5–7 | NO CANONICAL SOURCE | FD-10 |
| 5 | `dismiss` | **Dismiss** | — | not interchangeable | NO CANONICAL SOURCE | FD-10 |
| 6 | `close` | **Close** | — | not interchangeable | NO CANONICAL SOURCE | FD-10 |
| 7 | `discardDraft` | **Discard** | — | not interchangeable | NO CANONICAL SOURCE | FD-10 |
| 8 | `send` | **Send** | — | — | Correspondence | ALIGNED |
| 9 | `publish` | **Publish** | — | — | Public Discourse; E_OFFICIAL publication | ALIGNED |
| 10 | `reply` | **Reply** | — | — | **Public Discourse frozen feature: "Replies"** | ✅ **CANON-BACKED** |
| 11 | `join` | **Join** | — | — | Meeting Admission | ALIGNED |
| 12 | `leave` | **Leave** | — | — | Meetings & Live | ALIGNED |
| 13 | `addMember` | **Add member** | — | — | 🧊 `INSTITUTION_SPACE_MEMBERSHIP_DOCTRINE` (frozen) | ✅ **CANON-BACKED — added in C0** |
| 14 | `invitePerson` | **Invite person** | — | — | 🧊 same doctrine | ✅ **CANON-BACKED — added in C0** |
| 15 | `manageInvites` | **Manage invites** | — | — | 🧊 same doctrine | ✅ **CANON-BACKED — added in C0** |
| 16 | `invite` | **Invite** | generic intent (e.g. meeting invitation) | **never a substitute for `addMember`/`invitePerson` on a membership surface** | Invitations | ✅ constrained |
| 17 | `accept` | **Accept** | — | — | invitation lifecycle | ALIGNED |
| 18 | `decline` | **Decline** | — | — | invitation lifecycle | ALIGNED |
| 19 | `follow` | **Follow** | — | **Connect must never appear** | NO CANONICAL SOURCE — implementation is a feed/DM-gating primitive across 3 inconsistent models | ⚠ WEAK BACKING |
| 20 | `manage` | **Manage** | — | — | — | ✅ no longer overloaded — `manageInvites` owns the frozen operation |
| 21 | `view` | **View** | — | — | — | FRONTEND ALIGNED |
| 22 | `open` | **Open** | — | — | — | FRONTEND ALIGNED |
| 23 | `remove` | **Remove** | — | — | membership removal | ALIGNED |
| 24 | `switchIdentity` | **Switch identity** | "Publish as…" · "Send as…" · "Replying as…" | `change publisher` · `change sender` · `change speaker` · `change institution` · `change identity` — banned as competing semantic actions | 🧊 **C0 EXTENSION via governed C1 discovery, 2026-08-15** | ✅ gate-enforced |
| 25 | `save` | **Save** | — | — | — | FRONTEND ALIGNED |
| 26 | `edit` | **Edit** | — | — | — | FRONTEND ALIGNED |

### Prohibited synonyms — enforced, zero tolerance

`try again` · `retry operation` · `try once more` → all resolve to `ProductAction.retry`.

**`Refresh` and `Reload` are deliberately NOT on this list.** They are separate canonical actions. `saved_screen.dart` legitimately carries both a header `Refresh` and a recovery `Retry`; the update gate's `Reload` reloads the application. The gate governs the *position*, not the word.

---

## 4. Membership operations — **APPLIED in C0** (founder decision 2026-08-15)

`INSTITUTION_SPACE_MEMBERSHIP_DOCTRINE.md`, founder-approved and frozen, requires three distinct operations. They exist now:

| Action | Canonical label | Meaning |
|---|---|---|
| `ProductAction.addMember` | **Add member** | Direct membership establishment where authority and product rules legitimately permit it. **No invitation, no acceptance step.** |
| `ProductAction.invitePerson` | **Invite person** | Issue an invitation requiring the governed invitation lifecycle. |
| `ProductAction.manageInvites` | **Manage invites** | View and manage outstanding invitation state. |
| `ProductAction.invite` | **Invite** | Retained generic intent for surfaces where the membership operation is not the subject (e.g. inviting to a meeting). **Never a substitute for the two above on a membership surface.** |

**These name a semantic action only.** Backend and domain authority still decide whether the action is available — nothing here infers permission from a word.

**Gate:** `membership operations stay distinguishable` proves the three labels are mutually distinct *and* that the generic `invite` has not become a synonym for either specific one.

---

## 4b. Identity concepts — `IdentityConcept` (new in C0)

FD-11's five-way distinction is now **expressible and testable**, not merely written down:

`person` · `institution` · `membership` · `actingContext` · `presence`

These are **not product nouns**. `presence` in particular is deliberately unresolved as a product concept — its only implementation is a single-actor online/recency heartbeat, and C2 owns whatever human-facing presence semantics survive. Declaring it here is what lets the gate prove Person has not been flattened into Membership or Presence.

**This is how the final map "correctly expresses" Presence and Follow** without inventing product nouns the canonical body does not support: Presence as a governed distinction, Follow as `ProductAction.follow`.

---

## 5. Summary of alignment status

| Status | Count | Items |
|---|---|---|
| ✅ **REPRESENTATION ALIGNED** | 8 | Institution · Participant · Space · Meeting · Post · Announcement · Reply · (Works/Profile/Presence/Connect correctly omitted) |
| ✅ **FRONTEND LANGUAGE ALIGNED** (no canonical source needed) | 4 stop intents + 12 actions | interaction vocabulary |
| ✅ **RESOLVED by founder decision 2026-08-15** | 4 | Person/Member · Correspondence · Add Member/Invite Person/Manage Invites · Discovery supersession |
| ⚠ **OPEN, owned by a later chapter** | 3 | `Live` plural (C10) · Official designation (C5) · Institutional approval (C5) |
| ⚠ **NO CANONICAL SOURCE, acceptable** | 2 | Thread · Room |
| ⚠ **WEAK BACKING, recorded** | 1 | Follow — three inconsistent backend models; C2 owns reconciliation |

**Zero founder decisions outstanding on Product Language.** All adjudicated corrections are applied and gate-enforced.

---

## 6. Approved C0 extension — `switchIdentity` (2026-08-15)

**C0 PRODUCT LANGUAGE → EXTENDED THROUGH GOVERNED C1 DISCOVERY.** This is normal authority evolution, **not C0 remediation**. C0 is not reopened.

C1's representative implementation needed a way to say *change which legitimate acting context this action will be attributed to*, and no canonical action covered it — `edit` means edit content; `manage` and `view` do not fit. C1 brought it forward rather than inventing local copy, and the founder ruled.

| | |
|---|---|
| **Semantic action** | `ProductAction.switchIdentity` |
| **Canonical default label** | **Switch identity** |
| **Meaning** | Change which legitimate Person or Institution acting context will be attributed to a consequential action, **before that action is committed** |

**It does not:** grant authority · change membership · change role · change account/login identity · edit content · imply impersonation.

**Availability:** only when multiple legitimate acting contexts actually exist.

### Contextual copy is permitted; a second semantic action is not

A surface may render *"Publishing as …"*, *"Publish as…"*, *"Sending as …"*, *"Replying as …"* or *"Switch identity"*. All of them mean the same thing.

> **SEMANTIC ACTION → SWITCH IDENTITY.**
> **CONTEXTUAL COPY → may describe that action naturally for the surface.**

`change publisher` · `change sender` · `change speaker` · `change institution` · `change identity` are **prohibited synonyms**, gate-enforced, so the action cannot fragment into four.

### Terminology boundary

"Identity" here means **selection among canonical acting identities**. It never collapses PERSON / INSTITUTION / MEMBERSHIP / ACTING CONTEXT / PRESENCE / AUTHENTICATION.

The implementation deliberately keeps the more precise internal name — `ActingOption`, `ActingResolution`, acting-context selection — while Product Language presents "Switch identity" to people.
