# FD-5 — LIVE AS A GOVERNED MODE OF A THREAD OR SPACE

# STATUS: FROZEN — FOUNDER APPROVED 2026-08-15
# SELECTED: OPTION A — LIVE AS A GOVERNED MODE / STATE OF AN EXISTING THREAD OR SPACE

**This closes the Founder Decision Register.** Register closure is **not** roadmap approval.

---

## 1. Core Live model

**LIVE is NOT:** a standalone generic broadcast product · another Meeting · an expanded Institution Room · a fourth disconnected realtime surface.

**LIVE IS** a governed public/stage participation **state** of an appropriate owning **Thread** or **Space**.

```
THREAD / SPACE → AUTHORIZED GO LIVE → LIVE STATE → AUDIENCE / PARTICIPATION
  → LIVE ENDS → CONTINUITY REMAINS WITH THREAD / SPACE
```

The owning context retains identity/context · conversation continuity · history · participants/relationships · resulting replay/content where authorised · post-live continuity.

> **Going Live must never orphan the conversation from its source context.**

## 2. Backend reality — discovery correction preserved

**Already modelled:** `RealtimeAccessMode.PUBLIC_STAGE` · `RealtimeParticipantRole` (HOST · CO_HOST · MODERATOR · SPEAKER · PARTICIPANT · LISTENER · OBSERVER) · `RealtimeHandState` (LOWERED/RAISED) · `RealtimePublishState` (per-track audio/video/screen).

**However:** `PUBLIC_STAGE` is **declared but not operationally consumed** — it appears only in the enum declaration, with no service behind it.

> **CORRECTION PRESERVED:** the earlier discovery statement that *"the backend has no speaker/audience model"* was **wrong and is withdrawn**.
>
> **Correct statement: THE ROLE/STAGE VOCABULARY EXISTS. THE OPERATIONAL LIVE MECHANISM DOES NOT.**

## 3. Who may enable Live

> **Capability-based.** Do **not** hard-code *owner only* or *admin only*.

`ACTING CONTEXT + OWNING THREAD/SPACE + BACKEND CAPABILITY → MAY ENABLE LIVE`

Owner/admin may legitimately hold it; delegated authority may too where governance permits. **The frontend must not infer this from role names.**

## 4. Who may watch

> **Audience visibility is governed by the owning context / Live visibility policy.**
> **GO LIVE ≠ MAKE EVERYTHING PUBLIC.**

The policy model must distinguish **public internet** (where explicitly permitted) · **platform/community/institution-restricted** · **invited/controlled**. Public observation is an **explicit governed visibility consequence**, never automatic. Exact policy vocabulary refined in design.

## 5. Public internet viewing

Where authorised, public viewers may observe **without becoming ordinary Aura participants/members merely by watching**.

Requires **PUBLIC OBSERVATION without DURABLE MEMBERSHIP or ACTIVE PARTICIPATION**. The existing `OBSERVER`/`LISTENER` roles may contribute — **but do not assume current transport implements it**.

## 6. Who may speak

> **Invited speakers + request-to-speak / hand-raise. NO uncontrolled open microphone.**

```
LISTENER / OBSERVER → RAISE HAND / REQUEST → HOST/MODERATOR DECISION
  → SPEAKER → PUBLISH CAPABILITY → RETURN TO LISTENER/AUDIENCE
```

Explicit speaker invitation may bypass the request step where legitimately authorised.

## 7. Durable membership ≠ Live participation

> **SPACE MEMBER ≠ LIVE SPEAKER. THREAD PARTICIPANT ≠ LIVE SPEAKER. PUBLIC VIEWER ≠ MEMBER.**

Temporary Live roles **must not mutate durable relationship/membership state**. A person may move listener → speaker → listener without changing Space membership.

## 8–10. Audience voice

| Concern | Ruling |
|---|---|
| **Live reactions** | ephemeral/lightweight engagement |
| **Live questions** | governed audience-to-host/speaker interaction, with moderation where required |
| **Ordinary continuing discussion** | **remains owned by the originating Thread/Space conversation** |

> **Do NOT create a second independent generic Live comments system.** This prevents Live comments + Thread comments + Space comments becoming three competing conversation systems.

**Questions** must support submit · surface to host/moderator · select/address · dismiss/resolve · retain relationship to the Live event. **Asking a question must not require becoming an active speaker.**

**Reactions must not become** a moderation bypass · a notification-noise source · durable membership state · a replacement for substantive discussion.

## 11–12. Recording and replay

> **LIVE RECORDING IS EXPLICIT / OPT-IN.** Never silent-by-default merely because capability exists. Recording state must be clearly communicated per governance/consent requirements. **Recording authorization is distinct from GO LIVE authorization.**

```
LIVE → RECORDING → REVIEW / AUTHORIZE WHERE REQUIRED → REPLAY / ARCHIVE → OWNED BY THREAD / SPACE
```

> **Replay belongs to the originating Thread/Space — never an orphaned generic Video/Live object.** **Recording does not automatically mean replay is publicly available.**

Replay carries deliberate publication · attention · retention · integrity · moderation · content-rendering consequences.

## 13. Scheduled vs instant

**Both supported.** Instant: an authorised person starts Live from the owning context. Scheduled: planned in advance while remaining attached to the owning Thread/Space.

> **Scheduled Live does NOT become a Meeting merely because it has a time.**

## 14–16. Start, end and end-state

**Start** (Capability-Adaptive): `GO LIVE → CONFIRM VISIBILITY/PARTICIPATION POLICY → CONFIRM RECORDING STATE → CONFIRM HOST/SPEAKER SETUP → START`. **No dense broadcast console before Live begins** — progressive disclosure.

**End:** **primary termination is an authorised host/co-host action.** A scheduled end is **advisory** — expected time, displayed guidance, scheduling metadata — **not an automatic hard cutoff**. Infrastructure may separately clean up genuinely abandoned sessions.

**End-state:** public/stage state terminates · speaker/audience participation resolves · recording finalises where applicable · artifacts remain governed · attention resolves · **the owning Thread/Space remains**.

> **LIVE ENDS. THREAD / SPACE CONTINUITY DOES NOT.**

## 17–19. Notification and attention

> **AUDIENCE ELIGIBILITY DOES NOT IMPLY RINGING. ENTITLEMENT ≠ INTERRUPTION.**

Ordinary audience notification is **non-ringing attention** (*a Space you follow is Live* → passive attention). **Do NOT ring every eligible viewer/member.**

**Explicitly invited speakers, co-hosts, moderators and active participants** may receive governed interruption/ringing where policy permits — consuming the **canonical Notification Delivery Authority + Multi-Device Authority**. **No separate Live ringing implementation.**

**Attention** belongs to the originating Thread/Space: *invited to speak* → Accept/Decline/View · *request resolved* → current-state action · *Live started* → View/Join where eligible · *missed invitation* → owning context. **No standalone generic Live Inbox.**

## 20–21. Moderation

`HOST` · `CO_HOST` · `MODERATOR` may support the future architecture. **Moderation is capability-adaptive** — ordinary listeners/viewers must **not** see speaker management · moderation queues · removal controls · host tooling.

**To design later:** remove active speaker · return speaker to audience · deny request-to-speak · remove viewer/participant where governance permits · mute/restrict publishing · handle questions · audience/reaction moderation · abuse/report path · public-viewer moderation implications.

> **Moderation policy is NOT invented here.** Unresolved policy is brought forward during implementation architecture.

## 22. Shared presentation primitives (FD-4)

Live consumes the shared realtime component family where the concern is genuinely universal: participant identity · speaker tiles · host-control patterns · consent/recording presentation · participant lists · hand raise · state presentation.

**The owning Live context supplies SPEAKER / LISTENER / OBSERVER / HOST / MODERATOR semantics.**

> **The shared component never owns product meaning.**

## 23–25. Scale, observation and lifecycle

**Audience scale is a genuine backend construction concern.** Do **not** assume the peer realtime path can serve arbitrary public audiences. Investigate scalable topology (SFU/broadcast). **Do not prematurely freeze a provider or topology.**

> Required property: **active speakers/publishers must serve a much larger observing audience without treating every observer as a peer media participant.**

**Public observation** must be architecturally distinct from **active media participation** — a viewer must not automatically receive publish tracks · microphone/camera role · durable membership · full peer participation machinery.

**Go-live transition** must be explicitly modelled: `NORMAL → LIVE_PREPARING (where useful) → LIVE → ENDING/FINALIZING (where useful) → NORMAL / POST-LIVE CONTINUITY`. **Do not model Live as a boolean `isLive`** if the real lifecycle needs more state.

## 26–28. Boundaries

**Thread vs Space.** Do not force identical Live behaviour. A Thread may host focused Live discussion around a continuing conversation; a Space may host a community/institutional Live event in persistent shared context. Same governing authority where possible; context may legitimately change audience defaults · discovery · notification · moderation · scheduling · participant selection. **Material semantic differences are brought forward.**

**Meeting boundary.** **Do NOT use Meetings as the implementation shortcut.** Scheduled Live does not become a Meeting; Live with invited speakers does not become a Meeting. Shared realtime infrastructure remains permissible.

**Institution Room boundary — OPTION C REJECTED.** Do not extend Institution Room to carry Live audience semantics. It remains institution-owned governed room communication; Live may originate from contexts that are not institution-owned. **Do not bend the D5 authority to absorb this feature.**

## 29–31. Status and staging

**Client:** no valid Live surface exists. **Do NOT retrofit Live into any of the three existing live-room screens before realtime convergence.** Staging **APPROVED**: realtime presentation/authority convergence **first**, Live implementation **after**. **Do not build a fourth disconnected live surface.**

**Backend status (recorded accurately):**

| Concern | State |
|---|---|
| Role/participation vocabulary | substantially modelled |
| Stage mode (`PUBLIC_STAGE`) | **declared but unconsumed** |
| Go-live authority | **missing** |
| Public observation | **missing** |
| Audience scale | **missing** |
| Live attention / interaction | **missing/incomplete** |
| Replay as product | **missing** |

> **FD-5 therefore creates a deliberate future CROSS-REPOSITORY construction chapter. It is NOT frontend-only.**

The chapter must include: backend authority · scalable media/audience delivery · public observation · Live lifecycle · speaker/audience participation · moderation · recording/replay · attention · client experience · cross-platform · certification.

> **Do not hide backend construction inside a frontend phase.**

## 32. Global-market research

Before final Live UX/architecture: research public live video/audio · staged conversations · speaker/audience systems · request-to-speak · moderated Q&A · reactions · scheduling · recording/replay · public viewing · host tools. Study interaction quality · audience mental model · scale expectations · participation clarity · moderation · progressive disclosure · failure modes.

> **Do NOT copy a specific product.** Aura's model remains governed by Thread/Space continuity.

## 33. Structural enforcement (FD-13)

Ship Live's anti-drift gates **with** the Live authority. Protect against: standalone orphan Live product · local role inference · ungoverned public visibility · ring-all audience behaviour · durable membership mutation from temporary speaker state · duplicate Live comment system · Meeting lifecycle reuse · Institution Room reuse · local notification delivery · unsupported peer-to-peer audience scaling.

## 34. Final rulings

| # | Ruling |
|---|---|
| **1. Enable** | governed delegated **capability**; owner/admin may hold it; frontend never hard-codes role semantics |
| **2. Watch** | governed **visibility policy**; public internet only where explicitly authorised; restricted/invited modes supported |
| **3. Speak** | **invited speakers + request-to-speak/hand-raise**; no uncontrolled open mic |
| **4. Audience voice** | lightweight **reactions** + governed **questions**; continuing discussion stays owned by Thread/Space |
| **5. Recording** | **explicit/opt-in**; replay only when separately authorised, owned by Thread/Space |
| **6. Timing** | **both** instant and scheduled |
| **7. End** | authorised **host/co-host action** primary; scheduled end advisory, not a hard cutoff; infra cleans abandoned sessions |
| **8. Notification** | ordinary audience attention **does not ring**; explicitly invited active participants/speakers may receive governed ringing |

## 35. Anti-drift guard

| ❌ Prohibited reading | Why it violates FD-5 |
|---|---|
| "Build a Live product and link it back" | §1 — Option B rejected |
| "Extend Institution Room for audiences" | §28 — Option C rejected |
| "Scheduled Live is just a Meeting" | §13, §27 |
| "Only owners can go live" | §3 — capability-based |
| "Live means public" | §4 — `GO LIVE ≠ MAKE EVERYTHING PUBLIC` |
| "Open the mic to the audience" | §6 |
| "Promote to speaker — update their Space membership" | §7 |
| "Add Live comments" | §8 — Thread/Space owns continuing discussion |
| "Record everything; it's useful later" | §11 — explicit/opt-in |
| "Recorded, so replay is available" | §12 |
| "Auto-end at the scheduled time" | §15 — advisory only |
| "Ring everyone who follows the Space" | §17 — entitlement ≠ interruption |
| "Give Live its own ringing path" | §18 — canonical delivery authority |
| "Create a Live Inbox" | §19 |
| "Observers can join as peers; it'll scale" | §23, §24 |
| "`isLive` boolean is enough" | §25 |
| "The backend has no speaker/audience model" | §2 — **withdrawn; vocabulary exists, mechanism does not** |
| "Retrofit Live into the existing room screens" | §29 |
| "Live is a frontend chapter" | §30 — cross-repository |
