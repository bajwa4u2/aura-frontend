# Aura Live — audience model and public interaction

**Date:** 2026-08-26. **Chapter:** Live Broadcast reconstruction, §10, §11, §16.
**Status:** design, frozen for implementation. No infrastructure state is
implied by this document — it describes product architecture that is
independent of which provider carries the media.

---

## 1. The problem this document exists to solve

Live has no viewer interaction at all today. The obvious fix — let viewers post
into the Conversation the broadcast came from — is **forbidden by Aura's own
rule**, and the backend already says so in as many words:

> a Live viewer is admitted as *session-scoped viewer presence only* … **never a
> Conversation party**; party truth changes only through Invitation admission.

That rule is not incidental. It is why the viewer-exit defect exists: a viewer
who leaves is currently sent to a conversation they are guaranteed to lack
access to. Reusing Conversation membership for comments would take that same
mistake and make it structural.

So Live interaction needs **its own governed public authority**, not a
borrowed one.

## 2. Two presences, never merged

```
STAGE ROSTER                        AUDIENCE
who is publishing                   who is watching
bounded, named, ordered             large, countable, mostly anonymous to peers
RealtimeSessionParticipant          LiveAudiencePresence
appears in the composition          never appears in the composition
```

The invariant, restated from the authority model and now given a data shape:

> **Audience presence is not stage presence.** A viewer never enters the stage
> roster, never creates stage peer state, and never increases host upload.

### Why audience presence cannot simply be participant rows

It is what the product does today, and it is why `LIVE · 1 watching` sits beside
a stage roster of 2: the viewer *is* a `RealtimeSessionParticipant` with role
`OBSERVER`. That worked for one watcher. It fails for an audience because:

* every viewer becomes a durable row in a table designed for a handful of
  people in a call;
* the publish gate had to be taught to exclude them — the vulnerability fixed
  on 2026-08-26 existed precisely because a viewer looked like a participant;
* roster events fan out to every stage client on every join and leave;
* `@@unique([sessionId, userId])` makes a viewer's presence a *seat*, which is
  the wrong noun.

Audience presence is **ephemeral, countable, and separate**.

## 3. Audience model

| Question | Answer |
|---|---|
| How many are watching? | An authoritative count Aura owns, not the provider's |
| Who is watching? | Known to Aura; disclosed to others only per §4 |
| Can a signed-out person watch? | Product decision, deferred — the capability is modelled, the policy is not yet set |
| Does watching create Conversation membership? | **Never** |
| Does watching create a stage seat? | **Never** |
| What survives after the broadcast? | An aggregate, not a per-viewer attendance record, unless the broadcast is institutional and governed otherwise |

### Disclosure rule

Aura knows who is watching. That is not the same as showing it.

* **The host and moderators** see audience *count* always, and audience
  *identity* only where Aura's disclosure rules allow it.
* **Viewers** see the count, never each other's identity.
* **A commenter self-discloses** — posting a comment is a deliberate act that
  attaches your identity to it, which is different from being enumerated as a
  spectator.

This follows the comparator split deliberately: TikTok's audience is effectively
anonymous to itself; LinkedIn/Zoom institutional broadcasts attach verified
identity to attendance. Aura needs both, so identity disclosure is a property
of the **broadcast**, not a global constant.

## 4. Live interaction — a distinct governed stream

`LiveComment` is deliberately NOT a `ConversationMessage`:

| | ConversationMessage | LiveComment |
|---|---|---|
| Authority to post | Conversation party | Audience admission to *this broadcast* |
| Lifetime | durable, edit history, revisions | scoped to the broadcast; retention is a policy choice |
| Addressed to | the conversation | the broadcast |
| Survives the session | yes, it is the record | only per retention policy |
| Moderation target | `CONVERSATION_MESSAGE` | **`LIVE_COMMENT`** (new) |

### What a comment carries

* the broadcast it belongs to;
* the person, through the canonical actor model — never a display-name string;
* the institution they act for, when they act for one, shown *alongside* the
  person and never instead of them;
* body, created-at;
* moderation state — visible, hidden by moderator, removed by author;
* pinned state, set by producer authority.

### Interaction kinds

| Kind | Notes |
|---|---|
| **Comment** | The base act |
| **Reaction** | Lightweight, aggregate-counted, not a row per tap at scale |
| **Question** | A comment marked as asking — feeds the Q&A surface |
| **Pinned** | Producer-selected; exactly one at a time |
| **Reply** | Only to a pinned/question item, so a broadcast does not grow a thread tree |

Mentions are deliberately **excluded for now**: mentioning notifies, and
notifying a person from a public broadcast they are not in is an attention
decision that belongs to the Attention authority, not to this chapter.

## 5. Rate and abuse controls

Live comments are the highest-volume untrusted write surface Aura will have.
Controls are part of the model, not an afterthought:

* **Slow mode** — a minimum interval per commenter, producer-configurable;
* **Keyword filtering** — broadcast-scoped, applied before persistence;
* **Mute** — per commenter, per broadcast, reversible;
* **Remove viewer** — reuses `RealtimeSessionBan`, which the publish gate
  already consults;
* **Rate limiting** — reuses the existing realtime abuse configuration rather
  than inventing a second limiter.

## 6. Moderation consumes canonical authority (§16)

No parallel moderation system. Aura already has `ModerationReport` and
`ModerationAction` with a polymorphic `targetType`/`targetId`. Live extends the
taxonomy:

```
ModerationTargetType += LIVE_BROADCAST, LIVE_COMMENT
```

Moderator actions during a broadcast — hide a comment, mute a commenter, remove
a viewer — are **immediate** in the room and **recorded** as
`ModerationAction` rows, so a live decision is auditable afterwards exactly like
any other moderation decision.

Delegated moderators are a **Live role** (authority model §4), not a new
permission system. Institution broadcasts additionally honour institution
moderation capability.

## 7. What survives the broadcast

Deliberately a policy, not an accident:

| Artefact | Default |
|---|---|
| Comments | Retained with the broadcast record; a replay shows them in time order if replay exists |
| Reaction counts | Retained as aggregates |
| Audience identities | **Not** retained per-viewer; aggregate count only |
| Moderation actions | Retained — they are governance records |
| Pinned item | Retained as part of the broadcast record |

Aura's broadcast record is canonical. Any provider's identifier for the
recording is provider metadata mapped to it, never the product's identity.

## 8. Failure and degradation

* If the interaction stream is unavailable, **the broadcast continues** and the
  viewer is told interaction is unavailable — the same principle as §6 of the
  infrastructure ruling, where audience egress failure must not kill the stage.
* If moderation is unavailable, comments **close** rather than run ungoverned.
  An unmoderatable public write surface is worse than a silent one.

## 9. Not built, and named rather than hidden

* **Anonymous/guest viewing** — modelled as a question, not answered. It
  interacts with abuse control and with identity disclosure, and deserves its
  own ruling.
* **Mentions from a broadcast** — excluded above, belongs to Attention.
* **Polls** — a natural fit, deferred until comments and Q&A are proven.
* **Gifts, coins, any economic system** — remains closed per founder ruling and
  appears in parity accounting only.
