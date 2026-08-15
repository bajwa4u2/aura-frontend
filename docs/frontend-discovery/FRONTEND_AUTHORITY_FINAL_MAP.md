# Frontend Authority — Final Map

**Sixteen authorities.** Each exists because measured drift proves it is needed — **no authority is created merely to have one**. Pattern for every row:

> **backend contract → repository → client authority → presentation model → consumer set**

---

| # | Authority | Owner (chapter) | Consumers | Backend source | Enforcement |
|---|---|---|---|---|---|
| 1 | **Product Language** | C0 | every surface | Representation + FD-10 | canonical nouns/CTA families where mechanically reliable; **no prose linting** |
| 2 | **Product State Presentation** | C0 | every surface | backend outcome states (delivery, transfer, integrity, lifecycle, room) | no raw spinner / blank-as-empty outside declared exceptions |
| 3 | **Temporal Presentation** | C0 | feeds, messages, attention, meetings, activity | timeline authority; domain event times | no local humanization/conversion; **sorting declares its event** |
| 4 | **Acting Context** | C1 | navigation, composition, identity, attention, realtime, publication | institution capability authority | context never derived from route or role name |
| 5 | **Capability Projection** | C1 | every authorised control | effective capability (role ∪ delegated grants) | no role comparison / `canX` outside projection; **distinguishes presentation from invented authority** |
| 6 | **Identity Projection** (Person/Institution) | C2 | profile, feed, attention, composer, realtime, pickers | `PERSON_IDENTITY_SELECT` / `PERSON_REFERENCE_SELECT` | one identity model; no institution-as-user |
| 7 | **Relationship Projection** | C2 | profile, feed, pickers | follow/relationship, membership | membership ≠ participation |
| 8 | **Presence Projection** | C2 | profile, participants, DM | device presence/availability | **technical connectivity ≠ social presence**; no local inference |
| 9 | **Verification Projection** | C2 | profile, participants, pickers | 3 independent verification layers | **no boolean flattening; no enum leakage** |
| 10 | **People & Participation Selection** | C2 | realtime, threads/spaces, room, composer recipients | backend eligibility | **eligibility never re-derived in client** |
| 11 | **Navigation / Surface** | C3 | every destination | institution capability | no literal route strings; **architecture-aware surface reachability registry** |
| 12 | **Attention** | C4 | Hub + every attention-producing domain | delivery authority, attention records, timeline | no parallel hubs; one badge semantic; no dead CTAs |
| 13 | **Composition** | C5 | all publishing/messaging surfaces | CIS classes, publication authority | no independent composers; **composition ≠ representation ≠ delivery** |
| 14 | **Attachment Lifecycle** | C5 | composers, profiles, meetings | MIME policy, media cleanup | one pipeline; **upload ≠ commitment** |
| 15 | **Content Intake & Resolution** | C5 | all composition surfaces | link intelligence, MIME policy | one intake layer; **preserve richness, never invent it** |
| 16 | **Realtime Presentation / Session** | C6 | DM, Thread, Space, Room, Meeting, Live | realtime session, D1/D2/D6 | no reimplementation of canonical primitives; **must not force semantic convergence** |

---

## Authorities deliberately NOT created

| Considered | Rejected because |
|---|---|
| A "Live" authority | FD-5: Live is a **state of a Thread/Space**, not its own product authority |
| A "Calls" authority | FD-3: no generic realtime domain merely because infrastructure is shared |
| A "Member" identity authority | FD-11: a member is a **Person + relationship**, not a third identity type |
| A "Notification" authority separate from Attention | FD-1: attention is one projection; delivery is backend-owned |
| A governance platform / metadata framework | FD-13 §7: no platform before demonstrated need |
| A copy database | FD-10 §15: language authority governs vocabulary, not every sentence |

---

## Ownership boundaries that must never blur

```
BACKEND owns:  eligibility · permission · authority · lifecycle truth · event meaning
CLIENT owns:   projection · presentation hierarchy · interaction · continuity
```

- The client **projects** capability; it never **computes** it.
- Shared components **render**; the owning domain **means**.
- Attention **projects**; domains **own** their objects and actions.
- Composition **composes**; owning domains supply delivery/publication semantics.
- Temporal **renders** time; owning domains decide **which event** matters.

---

## Enforcement summary (FD-13)

Every authority ships with: **consumer migration + minimum hard-failing gate + narrow reviewable exceptions + regression + certification.**

- **Hard build/certification failure** — never warnings.
- **Exceptions:** narrow, identifiable, justified, reviewable, and **visible in the enforcement artifact**. No wildcards, no `legacy/` exclusions, no ignore directories.
- **Enforce the invariant, not the filename** — gates evolve with their authority.
- **A gate that cannot be trusted becomes a recorded obligation, never a downgraded warning.**
