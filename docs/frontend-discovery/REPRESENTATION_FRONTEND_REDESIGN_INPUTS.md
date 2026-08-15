# Representation → Frontend Redesign Inputs

**Date:** 2026-08-15 · **Not a visual design specification.**

This exists so later chapters can redesign aggressively **without accidentally redesigning Aura into a different product**. Every statement below is sourced from canonical Representation or founder-frozen product doctrine, not from the current implementation.

---

## 1. What Aura fundamentally is

> Aura is Aura Platform LLC's **institutional platform for civic discourse** — the system through which institutions and the public they serve build a credible, accountable relationship **in both directions**.
> — `PRODUCT_IDENTITY_CANON.md`

Two directions, not one. A redesign that makes Aura feel like an institution broadcasting *outward* has changed the product. The public speaking *back*, and being answerable to, is half the identity.

It exists to replace *"an unmanaged website, an ungoverned social account, and third-party tools with no institutional memory."* Institutional memory is a product function, not a nice-to-have.

## 2. What must never be reduced away

`PUBLIC_REPRESENTATION_CANON` B.8 — Aura must **not** be reduced to:

meetings · membership · association management · institutional relationship management · institutional communication software · community software · social media

> Public institutional communication, publication, and public/civic discourse remain **first-class Aura territory**.

**Redesign test:** if the rebuilt navigation makes Aura read as "a meetings app with some extras" or "a members portal", the redesign has failed regardless of how good it looks. The identity canon says it directly: *"Aura's identity does not reduce to any single module it contains — not its meetings infrastructure, not its communications center, not its public directory."*

## 3. What a Person represents

**Aura Identity is the root of the entire platform** — architecturally upstream of Institutional Identity, which *cannot exist without it*.

> Aura Identity is **not** Authentication, Login, User Accounts, or Member Profiles — those are implementation mechanisms.
> It represents: persistent platform identity, platform participation, cross-institution identity, institutional ownership, institutional membership, authority, participation history, long-term continuity.

**Redesign implications**
- A person is not a row in an institution's user table. Their identity precedes and outlives any institution they belong to.
- "Account settings" framing is an implementation mechanism surfacing as product language — treat with suspicion.
- **Evidence boundary — must not be implied to exist:** portable reputation · cross-institution aggregation · verifiable credentials · identity portability beyond current implementation. A profile redesign must not *look* like it delivers these.

## 4. What an Institution represents

A real institution — *a government body, university, company, association, or public office* — that can establish a **verifiable public presence**.

- **Identity is explicit and verifiable before any interaction begins.**
- Authority to act or speak on an institution's behalf is **individually grantable and revocable, not all-or-nothing**.
- Capability doctrine: authority is *"delegated narrowly (specific capabilities to specific people) and formally transferred — never granted as an undifferentiated 'admin' role."*
- An institution models its own internal structure — departments, committees, boards — as addressable entities.

**Redesign implication:** any surface that presents one "Admin" toggle standing for a bundle of capabilities is contradicting frozen capability doctrine, not merely simplifying.

## 5. What institutional communication represents

Three **distinct** frozen capabilities inside one module — never collapsed into one inbox:

| Capability | What it is |
|---|---|
| **Announcements** | formal institutional statements, distinct from casual content, with a controlled path to the platform-wide feed |
| **Communications Center** | governed outbound — digests, campaigns, newsletters, push — with per-user preference and suppression |
| **Correspondence** | 🧊 the governed formal/deliberate communication form (FD-10, reaffirmed 2026-08-15). ⛔ The module's original scoping — *"spaces, threads, messages, direct threads"* — is legacy umbrella naming and no longer the canonical product meaning; **C7** owns renaming it. |

Framing directive: *trusted institutional communication — **not** messaging, email-marketing, broadcast, or notification software.*

**Redesign implication:** merging announcements, campaigns and correspondence into one "Messages" surface would collapse three frozen capabilities. The pull toward a single unified inbox is strong and must be resisted deliberately.

## 6. What public discourse represents

Features: **Public Posts · Institution Posts · Replies · Unified Feed.**
Framing: *accountable public dialogue — **not** social networking, not a traditional feed.*

- An institution's public statements can be **typed by accountability category** (commitment, resolution) so intent and follow-through are structurally distinguishable, not just prose.
- A post can be **formally routed as public record** within a real jurisdictional hierarchy, behind an approval gate.

**Redesign implication:** engagement mechanics (like counts, streaks, algorithmic ranking, follower vanity metrics) are not neutral visual choices here — they convert accountable dialogue into social networking.

## 7. Distinctions that must remain visible

| Distinction | Source |
|---|---|
| Institution ↔ public, **in both directions** | `PRODUCT_IDENTITY_CANON` |
| Aura Identity **precedes** Institutional Identity | frozen module record |
| Announcement ≠ Campaign/Digest ≠ Correspondence | frozen module features |
| Public Post ≠ Institution Post | frozen module features |
| Formal public record ≠ ordinary post | capability authority |
| Narrow delegated capability ≠ "admin" | capability authority |
| **Add Member ≠ Invite Person ≠ Manage Invites** | `INSTITUTION_SPACE_MEMBERSHIP_DOCTRINE` (frozen) |
| Space membership never implies Institution membership | same doctrine |
| Member ≠ Participant · Meeting ≠ Room ≠ Live · Thread ≠ Space | FD-10 |
| Identity truth is one thing across `SPACE MEMBER → THREAD PARTICIPANT → DM PARTICIPANT → MESSAGE AUTHOR → CALLER/CALLEE → ACTIVE CALL PARTICIPANT` | Founder Acceptance Register |
| Consent before recording is per-participant and server-checked | capability authority |

## 8. Terminology that must not drift

**Required or permitted**
- "public institution directory" — permitted by the 2026-07-30 canon
- Announcements · Communications Center · Correspondence · Meetings · Live · Public Record

**Banned in product language**
- *"trusted discovery"*, *"trusted home"*, and trust-as-an-attribute generally — trust is the reader's conclusion from behaviour, never a claim
- a generic platform ("Aura") identity substituted where a human or institution identity belongs
- "admin" standing in for a narrowly delegated capability

**Settled by founder decision, 2026-08-15**
- A platform person is canonically a **Person**. **Member** is a contextual relationship status and must never become the identity noun for a human.
- **Correspondence** has exactly one product meaning: the governed formal/deliberate communication form. The legacy umbrella sense is architectural naming drift, owned by **C7**.
- The Discovery module's *"always trusted discovery"* directive is **superseded**; "public institution directory" is permitted.

**Still unresolved — do not settle silently**
- **Verification labels.** The Aura Identity evidence boundary forbids implying credentials that do not exist. Per standing instruction, **no generic "Verified" may be used to close this out** — now gate-enforced. Remains a **C2** checkpoint.
- **Official designation / institutional approval** vocabulary — **C5**, deliberately not pre-empted by C0.
- Whether **Live** ever needs a plural form — **C10**. FD-5 makes Live a mode of a Thread or Space, so it may legitimately never need one.

## 9. What is *not* canonically governed

Stated so later chapters do not go looking for authority that does not exist:

| Concept | Status |
|---|---|
| **Presence** | No canonical Representation status. Implementation reality is a *"single-actor, stateless online/recency heartbeat"* — a technical signalling concern. C2 retires the six-meaning overload. |
| **Follow** | No canonical Representation source. Implementation is *"a feed/DM-gating primitive"* across **three parallel, partially inconsistent models**. |
| **Connect** | **Does not exist.** Zero matches for a Relationship or Connection model anywhere in the codebase. Must not appear in product language. |
| **Works** | Zero matches in the canonical body. |
| **Institution Room** | No Representation source; a backend (D5) construct. |
| **Thread** | Not a frozen Representation noun — it appears only as implementation evidence inside Correspondence. |
| **Relationship / Continuity** | Recorded as **Future Product Development Doctrines**, deliberately *not* representation modules and *not* dependency-graph nodes. Continuity is real but scoped **inside Meetings only**. |

## 10. The one-line test

> A redesign is wrong if, after it, an institution's public accountability is harder to see than its internal convenience.
