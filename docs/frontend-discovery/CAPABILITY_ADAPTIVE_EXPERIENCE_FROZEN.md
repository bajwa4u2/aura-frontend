# CAPABILITY-ADAPTIVE EXPERIENCE

# STATUS: FROZEN — FOUNDER APPROVED 2026-08-15
# SCOPE: CROSS-PRODUCT FRONTEND EXPERIENCE PRINCIPLE

This is **not** a single-decision entry. It is a governing principle that constrains **every** remaining frontend decision and every reconstruction chapter.

---

## 1. Why it exists

How should Aura feel to a member · institution operator · institution admin · host · speaker · participant · moderator · ordinary user — **without turning each authority level into another complicated product?**

**Explicitly not wanted:** an admin interface with member features bolted on · separate complicated products per role · giant control panels · permanent exposure of administrative machinery · role terminology dominating ordinary use · local `if admin` UI sprawl · complexity merely because the backend authority model is rigorous.

---

## 2. Core experience doctrine

> **ONE COHERENT PRODUCT → CONTEXT REVEALS RELEVANT CAPABILITY → AUTHORITY REVEALS AVAILABLE ACTIONS → CURRENT STATE DETERMINES WHAT MATTERS NOW → COMPLEXITY APPEARS ONLY WHEN NEEDED.**

```
PERSON + ACTING CONTEXT + PRODUCT CONTEXT + BACKEND CAPABILITIES + CURRENT STATE
  → CURATED AVAILABLE EXPERIENCE
```

**This must be deterministic.** It is **not** AI dynamically inventing UI. It is **not** frontend role inference.

---

## 3. Governing rule

> **ROLES / AUTHORITIES CHANGE AVAILABLE CAPABILITY — THEY DO NOT FORCE PEOPLE INTO DIFFERENT PRODUCTS.**
>
> **NEVER EXPOSE AUTHORITY COMPLEXITY UNTIL THE PERSON NEEDS TO EXERCISE THAT AUTHORITY.**

---

## 4. Member experience

Primarily: people · profiles · conversations · Threads · Spaces · posts/publications · invitations · participation · relevant attention · simple creation/composition.

**Do not continually expose:** institution machinery · permission vocabulary · administrative configuration · role matrices · management controls · governance internals.

The member experience stays **light, understandable and immediately adoptable**.

---

## 5. Institution operator / admin experience

An authorised operator experiences the **same coherent Aura product**. FD-9 determines when they are acting institutionally. Additional authorised capabilities appear **naturally in the context where they matter**.

| Space — member | Same Space — authorised admin |
|---|---|
| read · participate · reply · join permitted realtime | all member capabilities **+** invite/manage people · moderate · start governed realtime · future authorised Live · object-local management |

> **Do NOT automatically send the admin into a separate dense administrative application.**

---

## 6. Object-local management

Management belongs to **the object being managed** where possible: Space → Manage Space · Thread → relevant authorised controls · Room → manage participation · Profile/institution → relevant management.

Deeper administrative/settings surfaces only where genuinely necessary: governance · roles · institution-wide policy · configuration · security · inherently administrative work.

> **Do not create dashboard detours for simple contextual administration.**

---

## 7. Speaker / participant experience

A participant should not need to understand the machinery behind realtime or Live.

```
INVITATION → UNDERSTAND CONTEXT → ACCEPT → JOIN → DEVICE CHECK IF NECESSARY → PARTICIPATE
```

During participation emphasise only what matters now: microphone · camera where applicable · participant/audience awareness · leave · limited granted controls.

> **Do not expose host/admin controls to ordinary participants.**

---

## 8. Host / admin realtime experience

Additional controls appear **progressively when required**: invite · add participant · admit · allow to speak · return to audience · moderate · remove where authorised · end.

> **These controls must not permanently occupy everybody else's realtime UI.** Compatible with frozen FD-3 distinct realtime semantics.

---

## 9. Role / participation transitions

The same person moves naturally through states — **without changing applications or entering role-management screens**:

`MEMBER → INVITED PARTICIPANT → SPEAKER → ACTIVE SPEAKER → PARTICIPANT / AUDIENCE`

An authorised operator likewise: `READ THREAD → REPLY → DELIBERATELY ACT INSTITUTIONALLY → INVITE PARTICIPANTS → START GOVERNED REALTIME → MANAGE PARTICIPATION`, with acting identity remaining clear under FD-9.

> **Design around human tasks and state transitions, not database role names.**

---

## 10. Progressive disclosure — now a governing requirement

| Layer | Rule |
|---|---|
| Default UI | minimal, obvious, immediately usable |
| Additional capability | appears when context and authority make it relevant |
| Advanced capability | available without cluttering ordinary use |
| Administrative capability | available deliberately and clearly |

> **Do not hide essential actions. Do not expose every possible action simultaneously.**

---

## 11. Backend authority / frontend presentation

Do **NOT** rebuild role and capability truth locally. Avoid anything equivalent to `if (user.role == ADMIN) { showManyButtons(); }`.

```
BACKEND AUTHORITY / CAPABILITY → FRONTEND AUTHORITY → CURATED ACTION MODEL → PRESENTATION
```

> The backend remains final authority. **The client determines presentation hierarchy, not permission.**

*(Directly governs Finding M1: 29 files performing role comparisons, 20 computing capability booleans.)*

---

## 12. Compatibility with frozen decisions

| Frozen decision | Requirement |
|---|---|
| **FD-3 Realtime semantics** | DM · Thread · Space · Institution Room · Meeting · future Live retain distinct semantics. This principle improves creation, invitation, selection, participation and management **without collapsing them**. |
| **FD-9 Contextual Acting Authority** | The authenticated person remains the person; acting context determines institutional action; extra capability appears naturally under that context. **Do NOT create a second institution product simply because more capabilities become available.** |
| **FD-1 Attention Hub** | Attention exposes the **smallest useful set of currently valid actions**. Admins may receive administrative actionable attention; participants participation actions; members ordinary communication attention. **One** architecture adapts to legitimate capability/context. |

---

## 13. Product-system consequence

This principle is broader than any one decision. Carry it through later adjudication and design for: navigation · profiles · presence · Inbox/Attention · DM · Threads · Spaces · Meetings · Institution Rooms · future Live · composers · attachments · institution management · member management · moderation · participant management · settings.

> **Do not reconstruct today's role-fragmented experience using prettier components. The EXPERIENCE ARCHITECTURE itself must change.**

---

## 14. Frozen doctrine

> **CAPABILITY-ADAPTIVE EXPERIENCE.**
> **ONE COHERENT PRODUCT.**
> **ROLES CHANGE AVAILABLE CAPABILITY, NOT THE PRODUCT.**
> **CONTEXT REVEALS CAPABILITY.**
> **AUTHORITY REVEALS ACTIONS.**
> **COMPLEXITY APPEARS ONLY WHEN NEEDED.**
> **MANAGEMENT SHOULD BE OBJECT-LOCAL WHERE PRACTICAL.**
> **PROGRESSIVE DISCLOSURE IS REQUIRED.**
> **SIMPLIFY THE EXPERIENCE WITHOUT WEAKENING AUTHORITY.**

---

## 15. Anti-drift guard

| ❌ Prohibited reading | Why it violates this principle |
|---|---|
| "Build an admin app and a member app" | §3, §5 |
| "Admins get a dashboard for everything" | §6 — object-local management first |
| "Show all controls; authority filters them" | §3, §10 |
| "`if (isAdmin)` inline in the widget" | §11 |
| "Participants can see host controls greyed out" | §7, §8 |
| "Role names in the UI make it clearer" | §4, §9 |
| "Adaptive means AI decides the UI" | §2 — must be **deterministic** |
| "Capability-adaptive lets us merge Meeting and Room" | §12 (FD-3) |
| "More institutional capability justifies an institution product" | §12 (FD-9) |
| "Hide essential actions to look simple" | §10 |
| "Redesign the components and the fragmentation is solved" | §13 — the experience architecture must change |
