# Live Thread / Space — Architecture Options

> ✅ **RESOLVED — FD-5 OPTION A, FROZEN 2026-08-15.** Live is a governed mode/state of an owning Thread or Space. Options B and C are **rejected**. All eight sub-decisions are ruled. See `FD5_LIVE_THREAD_SPACE_FROZEN.md`.

**Historical options document, retained for traceability.**

> **FD-3 CONSTRAINT — FROZEN 2026-08-15.** Live is a governed public-stage/audience capability **emerging from the appropriate Thread/Space context**, and is **NOT to be treated as another Meeting merely because both use realtime media**. Live state and history remain attached to the originating Thread/Space. Any option below that would make Live a Meeting variant is excluded by this freeze. See `FD3_REALTIME_SEMANTICS_FROZEN.md`.

## The founder's direction

A governed Thread/Space should be able to become **LIVE for public engagement** when its authorised owner/admin deliberately enables it, with live state and history remaining attached to the originating Thread/Space.

## What exists today

**Nothing.** There is no live/broadcast concept in the client. There is no speaker/viewer distinction, no audience eligibility, no public observation of a live session, and no post-live continuity. Every existing realtime surface assumes **all present participants are peers**.

> ⚠ **CORRECTION (2026-08-15, preserved by founder instruction).** The paragraph originally here claimed the backend had **no** broadcast/audience model. **That was wrong and is withdrawn.**
>
> Already modelled: `RealtimeAccessMode.PUBLIC_STAGE` · `RealtimeParticipantRole` (HOST · CO_HOST · MODERATOR · SPEAKER · PARTICIPANT · LISTENER · OBSERVER) · `RealtimeHandState` (LOWERED/RAISED) · `RealtimePublishState` per-track publishing.
>
> **But `PUBLIC_STAGE` appears only in its enum declaration — no service consumes it.**
>
> **Correct statement: THE ROLE/STAGE VOCABULARY EXISTS. THE OPERATIONAL LIVE MECHANISM DOES NOT.** Missing: go-live authority, public observation, audience scale, Live attention/interaction, replay-as-product.

## Proving the distinction from Meetings (required by the task)

| | **Meeting** | **Live Thread/Space** |
|---|---|---|
| Core act | a conversation **among participants** | an existing conversation **becomes observable** |
| Membership | invited/booked attendees | existing Thread/Space governance |
| Default role | everyone may speak | most watch; few speak |
| Origin | created as a meeting | a conversation that already exists |
| History | belongs to the meeting | belongs to the Thread/Space |
| Lifecycle | scheduled/instant, prep → waiting → live → summary | toggled on and off within an ongoing context |
| Ends as | a meeting record | the conversation continues |

The distinction holds and is **not** a Meetings duplicate: Meetings owns booking, admission and the meeting record; Live owns audience and speaker control over an existing governed context.

## Market patterns (research, not imitation)

- **Slack Huddles** — impromptu live attached to an existing DM or channel; deliberately low-ceremony, no scheduling, no invitation. Its value is *continuity with the context it started in*.
- **Discord Voice channels** — always-on, drop-in; no scheduling or invites.
- **Discord Stage channels** — explicit **speaker vs audience** separation for presentation.
- **Scheduled meetings** — ceremony, invitation, admission.

The relevant implication: the market has converged on **live-attached-to-context** (huddle) and **speaker/audience separation** (stage) as *different things from a meeting*. The founder's direction matches a pattern that already works at scale, rather than inventing one.

**Sources:** [Slack Huddles vs Calls](https://clickup.com/blog/slack-huddles-vs-call/) · [Slack vs Discord](https://zapier.com/blog/slack-vs-discord/) · [Slack Huddles launch](https://www.engadget.com/slack-huddles-audio-143014019.html)

---

## OPTION A — Live is a *mode* of an existing Thread/Space (recommended)

The Thread/Space gains a live state. Its owner/admin toggles it. Participation policy decides who may speak; visibility policy decides who may watch. History, timeline and attention stay with the Thread/Space.

- **Pros.** Matches founder direction and the huddle/stage pattern. No new top-level product. Post-live continuity is free — the conversation simply continues. Reuses the frozen room/participant governance shape (invitation ≠ interruption) already proven in D5.
- **Cons.** Requires new backend: audience/speaker roles, public observation, viewer scale (SFU/broadcast path), reactions/comments during live, replay/archive.
- **Risk.** Viewer scale is a genuinely different engineering problem from peer calls.

## OPTION B — Live is a distinct product that *links* to a Thread/Space

A separate Live entity referencing its originating Thread/Space.

- **Pros.** Clean separation of scale concerns; broadcast infrastructure isolated.
- **Cons.** Creates a fourth realtime product; post-live continuity becomes an integration rather than a property; risks exactly the fragmentation this discovery is trying to end.

## OPTION C — Extend Institution Room to carry audiences

Reuse the just-frozen Institution Room, adding audience/speaker.

- **Pros.** Reuses fresh, governed, ring-policy-aware infrastructure.
- **Cons.** Institution Room is institution-owned; Threads/Spaces are not necessarily. Would bend a just-frozen authority to a different purpose.

---

## RECOMMENDATION

**Option A**, staged — and explicitly **not** started until the realtime convergence (Finding R1) and Institution Room client (Finding R2) are done. Building a fourth live surface on top of three unconverged ones would repeat the exact failure this discovery documents.

## Questions requiring founder decision

1. **Who may enable live** — owner only, admin, or delegated capability?
2. **Who may watch** — public internet, platform members, institution members, or invited?
3. **Who may speak** — invited only, request-to-speak, or open?
4. **Does the audience have a voice** — reactions, comments, questions, or nothing?
5. **Is live recorded by default**, and does replay live in the Thread/Space?
6. **Scheduled live, instant live, or both?**
7. **What ends it** — host action, inactivity, or scheduled end?
8. **Does live-ness notify** — and if so, does it ring, or only appear? (The frozen "entitlement ≠ interruption" doctrine should govern this.)

**FOUNDER DECISION.** Yes — all eight, before any architecture is frozen.
