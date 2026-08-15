# THREADS / SPACES PRODUCT MODEL — DISTINCT BUT COMPOSABLE

# STATUS: FROZEN — FOUNDER APPROVED 2026-08-15

**Identified by NAME.** Register mapping: **no pre-existing FD entry** — Threads/Spaces semantics were previously only partially covered inside FD-3 (realtime). Recorded as a named decision; **no new FD number invented**. It **complies with, and does not supersede, FD-3.**

---

## 1. Core decision

| | Frozen meaning |
|---|---|
| **THREAD** | **FOCUSED CONVERSATION CONTINUITY** |
| **SPACE** | **PERSISTENT SHARED CONTEXT / COMMUNITY** |

Distinct product concepts. **Do NOT:** reduce both to generic communication containers · merge them into one universal conversation/community object · treat a Space as merely a large group chat · treat a Thread as merely a message list · force every Thread to belong to a Space.

> Technical infrastructure may converge where appropriate. **Product semantics remain distinct.**

---

## 2. Thread

Owns focused continuing conversation: `CONVERSATION → PARTICIPANTS → ATTACHMENTS/MEDIA → REALTIME → HISTORY → FOLLOW-UP/CONTINUITY`.

A Thread may originate in an appropriate product context; once established, its communication/realtime continuity **belongs to that Thread**.

Per **FD-3**: Thread realtime is Thread-owned realtime · a missed Thread realtime interaction returns to the Thread · Thread invitations/attention preserve Thread context · Thread history stays with the Thread.

> **A Thread does NOT become a Meeting merely because realtime media is used.**

---

## 3. Space

Persistent shared context/community. Depending on purpose and backend capability it may contain or expose: identity/purpose · membership · people · content · conversation · Threads · participation · appropriate realtime · contextual management · future governed Live.

> **Do NOT translate that list into a permanent eight-tab interface.** Capability-Adaptive Experience and progressive disclosure govern.

---

## 4. Composition of the two

> **A SPACE MAY CONTAIN MULTIPLE THREADS. A THREAD DOES NOT REQUIRE A SPACE.**

Do not force all focused communication through Spaces for architectural neatness. Do not duplicate Thread semantics inside Space-specific communication implementations.

*(Directly relevant to the discovery finding of three `thread_screen` implementations across `correspondence/`, `public/` and `direct_threads/`.)*

---

## 5. Membership experience

Human-readable and simple. Conceptual flows: `DISCOVER/OPEN → UNDERSTAND SPACE → JOIN → PARTICIPATE` · `INVITATION → UNDERSTAND CONTEXT → ACCEPT/DECLINE → PARTICIPATE` · `REQUEST → PENDING → APPROVED/DECLINED` where policy requires approval.

Not all flows are universally required — legitimate Space policy decides.

> **Do not expose internal membership records, role enums or permission machinery as the user experience.**

---

## 6. Durable membership ≠ temporary participation role *(frozen)*

A person's **durable relationship** to a Space is not their **temporary participation state** in realtime · Institution Room · Meeting · future Live.

> **SPACE MEMBER ≠ LIVE SPEAKER.**

A Space member may temporarily become invited participant → speaker → active speaker → audience/participant **without mutating their durable Space membership role**.

> **Do not collapse relationship authority and session participation state.**

*(This is the client-side counterpart of the backend's frozen distinction between institution membership and room participation.)*

---

## 7. Roles / capabilities

Backend authority stays rigorous. The frontend must **not** project a growing internal vocabulary — OWNER · ADMIN · MODERATOR · EDITOR · MEMBER · CONTRIBUTOR · SPEAKER · PARTICIPANT — everywhere merely because those concepts exist.

Per Capability-Adaptive Experience: `AUTHORITY → RELEVANT CAPABILITY → CURATED ACTION`.

> **Expose role/status terminology only where the distinction itself has user value.**

---

## 8. Object-local management

`SPACE → PEOPLE → INVITE/MANAGE` · `SPACE → relevant authorised controls` · `THREAD → relevant participant/context controls`.

> **Do not force simple management actions through distant institution administration dashboards.** Deep administration remains appropriate where genuinely necessary.

---

## 9–11. Compliance with frozen decisions

| Frozen decision | Requirement |
|---|---|
| **FD-9 Acting Context** | Acting context does **not** redefine Space/Thread semantics. Institutional authority stays explicit where consequential. **No mirrored personal/institution Space or Thread products.** |
| **FD-1 Attention** | Thread/Space attention retains owning context — Thread mention → exact Thread location · Space invitation → exact Space · missed Thread realtime → owning Thread · participation request → owning Space. **Attention is a projection; Thread/Space remain owners.** |
| **FD-6 Composition** | Threads and Spaces **consume the canonical Composition System**. **No independent Thread/Space composer architectures.** Owning semantics determine available capability · recipient/participation meaning · attachment policy · Send/Reply/Publish semantics · authority. |

---

## 12. Future Live dependency *(only this is frozen)*

> **FUTURE LIVE SHOULD EMERGE FROM AN APPROPRIATE GOVERNED THREAD / SPACE CONTEXT RATHER THAN DEFAULTING TO AN ISOLATED GENERIC BROADCAST PRODUCT.**

`GOVERNED THREAD/SPACE CONTEXT → AUTHORIZED GO-LIVE TRANSITION → PUBLIC/AUDIENCE ENGAGEMENT → INVITED PARTICIPATION WHERE PERMITTED → CONTINUITY WITH OWNING CONTEXT`.

> ✅ **FD-5 NOW FROZEN (2026-08-15).** Live is a governed mode/state of the owning Thread/Space; audience visibility is policy-governed; speaking is invited or request-based; durable membership is never mutated by temporary Live roles; replay is owned by the Thread/Space; ordinary audience attention does not ring. See `FD5_LIVE_THREAD_SPACE_FROZEN.md`.

---

## 13. Frozen doctrine

> **THREAD = FOCUSED CONVERSATION CONTINUITY.**
> **SPACE = PERSISTENT SHARED CONTEXT / COMMUNITY.**
> **SPACE MAY CONTAIN THREADS. THREAD DOES NOT REQUIRE SPACE.**
> **SPACE MEMBERSHIP ≠ TEMPORARY REALTIME/LIVE PARTICIPATION ROLE.**
> **MANAGEMENT SHOULD BE OBJECT-LOCAL WHERE PRACTICAL.**
> **REALTIME RETAINS THREAD/SPACE OWNERSHIP.**
> **FUTURE LIVE EMERGES FROM GOVERNED THREAD/SPACE CONTEXT — NOW FULLY RULED BY FD-5 (FROZEN 2026-08-15).**

---

## 14. Anti-drift guard

| ❌ Prohibited reading | Why it violates this freeze |
|---|---|
| "Thread and Space are both just conversation containers" | §1 |
| "A Space is a big group chat" | §1 |
| "Every Thread should live inside a Space" | §4 |
| "Spaces need a tab per capability" | §3 |
| "Promote them to speaker — update their Space role" | §6 — durable membership ≠ participation state |
| "Show the role enum so people understand permissions" | §5, §7 |
| "Space needs its own composer" | §11 (FD-6) |
| "Institution Spaces need a mirrored product" | §9 (FD-9) |
| "Thread realtime is basically a Meeting" | §2 (FD-3) |
| "This decision defines Live" | §12 — this froze only the *dependency*; the full Live model is **FD-5**, now frozen separately |
