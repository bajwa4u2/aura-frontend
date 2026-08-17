# Live Origination Correction — State Escalation, Not Broadcast Creation

**Date:** 2026-08-17 · **Status:** FOUNDER-FROZEN · **Supersedes:** the
2026-08-16/17 conversation-menu Go Live implementation and the legacy
standalone Live lobby. **Companion to:** `frontend-discovery/FD5_LIVE_THREAD_SPACE_FROZEN.md`
(FD-5 remains the design authority; this records its enforcement).

## Frozen sentences

> **LIVE IS NOT SOMETHING A USER CREATES.**
> **LIVE IS SOMETHING AN EXISTING REALTIME HUMAN INTERACTION DELIBERATELY BECOMES.**

> **ORIGINATION IS CONTEXTUAL. DISCOVERY IS GLOBAL.**

> **NO ACTIVE REALTIME INTERACTION = NO GO LIVE ORIGINATION.**

Future agents must not reinterpret Live as a standalone broadcast
product. "Build a Live product and link it back" is a prohibited reading
(FD-5 §1, rejected Option B).

## The model

- **Conversation** — durable private continuity. Never becomes public.
- **Audio/Video call** — private synchronous realtime interaction owned
  by that Conversation.
- **Go Live** — governed transition of THAT EXISTING ACTIVE SESSION from
  private to public participation. FD-5 lifecycle, stored as
  `RealtimeSession.liveState`: `NORMAL → LIVE_PREPARING → LIVE → ENDING
  → NORMAL`. `liveState` is lifecycle truth; `accessMode` is
  participation policy (kept in sync — PUBLIC_STAGE while LIVE — never
  collapsed into one concept).
- **The existing callers become the initial stage.** No second session,
  no re-ringing, no participant reconstruction, no broadcast object.
- **End Live ≠ End Call.** Observers detach with terminal truth, access
  returns to INVITE_ONLY, the SAME session stays ACTIVE, the private
  call continues.
- **Viewers** are OBSERVER-role session participants: receive-only
  media, no publish controls, never Conversation parties, no access to
  Conversation messages/history/attachments. Viewer count is its own
  truth, never merged into the stage/participant count.

## The only origination door

Inside the active call (realtime room → More panel): **"Go Live — open
this call to the public"**, behind the FD-5 ritual (public-visibility
confirm + recording state + stage = the people in the call now).
Available only to joined non-observer participants of a
Conversation-owned session in `liveState NORMAL`.

## Retired doors (2026-08-17)

1. **Legacy global Live lobby** (`/realtime`, `RealtimeLobbyScreen`):
   "Start live" console creating `surfaceType: STANDALONE` sessions —
   the retired individual-broadcast product. The screen is now a
   watch-only **Live directory** ("What is live on Aura right now?")
   with an honest empty state and no creation CTA. Backend refuses
   STANDALONE creation (`[live:standalone_retired]`) and refuses any
   session BORN public (`[live:cold_start_retired]`); historical
   STANDALONE rows remain readable.
2. **Conversation-menu "Go Live — public broadcast"**: created a
   parallel PUBLIC_STAGE session next to any running call — the same
   rejected standalone-origination model with a Conversation id
   attached. Removed outright, including the cold-start
   `broadcast/:kind/start` backend route and the
   `ConversationsRepository.startBroadcast` client method.

## Wire/API surface

- `POST /conversations/:conversationId/live/:sessionId/go-live` —
  escalates the current session (active participant, non-observer).
- `POST /conversations/:conversationId/live/:sessionId/end-live` —
  closes the public boundary; session stays active.
- `GET /realtime/live/broadcasts` — discovery: ACTIVE sessions in
  `liveState LIVE` + broadcaster canonical identity only.
- Viewer admission and the view guard key on `liveState LIVE`.

## Regression pins (backend spec, "live state escalation" block)

Charter §26 A–O coverage: same-session escalation (B/C), no re-invites
(D), durable NORMAL→LIVE_PREPARING→LIVE trail (E), observer/non-party
refusals, already-live refusal, End-Live returns the same session to
NORMAL and never ENDED with only observers detached (H/I), STANDALONE
creation refused (L), born-public refused (M), discovery keyed on
liveState LIVE.

## FOUNDER ACCEPTANCE + INTERNET-PUBLIC REACH (resolved 2026-08-17)

The origination correction is **ACCEPTED** as the long-term model. Newly
frozen rulings:

> **"INTERNET-PUBLIC LIVE ACCESS IS A 15-SECOND PREVIEW, NOT ANONYMOUS
> PARTICIPATION."**
> **"AFTER 15 SECONDS, CONTINUED LIVE VIEWING REQUIRES SIGN UP OR LOG
> IN."**
> **"PUBLIC HOME MAY SURFACE ACTIVE LIVE AS A PUBLIC-FIRST ACQUISITION
> SURFACE."**
> **"THE SIGNED-OUT PREVIEW GRANTS NO LIVE PARTICIPATION OR CONVERSATION
> AUTHORITY."**
> **"AUTHENTICATION MUST RETURN THE PERSON TO THE SAME LIVE."**

- The 15-second duration is the product rule — not tunable during
  implementation.
- Signed-out preview: media preview only — no chat/reactions/raise-hand/
  publication/moderation/Conversation access; never a normal OBSERVER
  participation record unless an ephemeral delivery representation is
  technically required and carries ZERO participation semantics.
- Preview → Sign up/Log in → **the SAME Live** (owned by the shared
  destination-continuity authority, not a one-off redirect).
- Public Home Live presence consumes canonical Live/session + identity
  truth only — no fabricated metadata, no fake/sample Live, coherent
  without the section when nothing is live.
- HEADER LIVE (authenticated global discovery) and PUBLIC HOME LIVE
  (signed-out acquisition preview) are different doors into the SAME
  governed Live state — one truth, one lifecycle authority, one identity
  projection.
- Live chat identity: not a founder question — reconcile FD-5 §§8–10 +
  C2/D3 Identity doctrine first; anonymous ends at the preview boundary.
- SFU/scale: mesh-bounded delivery accepted for product-semantics
  certification only; an informed engineering assessment precedes any
  architecture decision; no topology migration in this pass.

## Known truthful limits

- **Scale (FD-5 §23):** every viewer is currently another peer
  connection against the stage (mesh). This serves bounded audiences
  only; public-internet scale requires an SFU-class distribution
  boundary that FD-5 deliberately left unfrozen. No product cap invented;
  the limitation is recorded, not hidden.
- **Recording/replay:** not implemented; the ritual states "Recording:
  off" honestly. Any future replay models an artifact under the existing
  recording/publication architecture — never a standalone Live object.
- Engagement layer (Live chat, reactions, raise hand → stage, questions,
  moderation) implements FD-5 §§8–10 — reconcile there before building;
  chat is session-scoped and never Conversation messages.
