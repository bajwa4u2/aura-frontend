# FD-2 — ATTENTION VOCABULARY: OBLIGATION BADGE

# STATUS: FROZEN — FOUNDER APPROVED 2026-08-15
# SELECTED: OPTION A — OBLIGATION BADGE

Register identifier: **FD-2**. This is the register's own FD-2 (*Attention vocabulary*) — **not** the composition decision a founder instruction once labelled "FD-2", which is registered as FD-6.

---

## 1. Core decision

> **PRIMARY ATTENTION BADGE = UNRESOLVED ACTIONABLE OBLIGATIONS.**

The badge answers one question and only one: **is something waiting on me?**

---

## 2. What contributes to the primary badge

| State | Contributes | Condition |
|---|---|---|
| `ACTION_REQUIRED` | ✅ | while unresolved |
| `INVITED` | ✅ | while unresolved |
| `MISSED` | ✅ | while unresolved |
| **Mentions** | ✅ **conditionally** | **when they represent unresolved attention**, resolving through owning-domain behaviour |

> Mentions are **not** blanket-counted. A mention contributes only where it constitutes unresolved attention, and it clears through the owning domain's own resolution behaviour — not through a separate mention-clearing mechanism.

## 3. What does NOT contribute

> **PASSIVE UNREAD COMMUNICATION DOES NOT CONTRIBUTE TO THE PRIMARY BADGE.**

`UNREAD` **remains contextual** to conversations and content — shown per conversation and per item, where it is genuinely useful. It is simply not an obligation, so it does not compete in the obligation counter.

## 4. Internal lifecycle states

> **INTERNAL LIFECYCLE STATES DO NOT BECOME UNNECESSARY GLOBAL UI VOCABULARY.**

`UNSEEN` · `RESOLVED` · `DISMISSED` · `EXPIRED` remain **modelled and behavioural** (per FD-1) without being promoted into product-wide labels.

**However:** context **may still explain** states such as *expired* or *dismissed* **where that explanation is useful** — for example, why an action is no longer available. Explanation in context is permitted; global vocabulary is not.

## 5. Truncation

> **Badge truncation = `99+`.**

## 6. Consequence, stated plainly

The badge number **drops sharply** compared with today, because it stops counting passive reading and counts only obligations. **This is the intended correction, and it is user-visible.**

---

## 7. Relationship to FD-1

FD-1 froze the *model*: `UNREAD` is not universal · at least `UNSEEN`/`UNREAD`/`INVITED`/`MISSED`/`ACTION_REQUIRED`/`RESOLVED`/`DISMISSED`/`EXPIRED` are modelled · clearing semantics are owned by the originating domain · items reconcile deterministically with no dead CTAs · state must have behavioural meaning.

**FD-2 froze the *exposure*:** which states reach the person, and what the badge counts. Together they close the attention vocabulary question.

---

## 8. Frozen doctrine

> **PRIMARY ATTENTION BADGE = UNRESOLVED ACTIONABLE OBLIGATIONS.**
> **PASSIVE UNREAD COMMUNICATION DOES NOT CONTRIBUTE TO THE PRIMARY BADGE.**
> **UNREAD REMAINS CONTEXTUAL TO CONVERSATIONS AND CONTENT.**
> **ACTION_REQUIRED, INVITED AND MISSED CONTRIBUTE WHILE UNRESOLVED.**
> **MENTIONS CONTRIBUTE WHEN THEY REPRESENT UNRESOLVED ATTENTION, AND RESOLVE THROUGH OWNING-DOMAIN BEHAVIOUR.**
> **INTERNAL LIFECYCLE STATES DO NOT BECOME UNNECESSARY GLOBAL UI VOCABULARY.**
> **CONTEXT MAY STILL EXPLAIN STATES SUCH AS EXPIRED/DISMISSED WHERE USEFUL.**
> **BADGE TRUNCATION = 99+.**

## 9. Anti-drift guard

| ❌ Prohibited reading | Why it violates FD-2 |
|---|---|
| "Add unread messages to the badge so it feels familiar" | §3 — passive unread never contributes |
| "Count every mention" | §2 — only unresolved attention contributes |
| "Give mentions their own clearing mechanism" | §2 — they resolve through the owning domain |
| "Surface UNSEEN/RESOLVED/DISMISSED as labels everywhere" | §4 |
| "Never mention expiry to the user" | §4 — contextual explanation **is** permitted |
| "The badge looks too low; add more sources" | §6 — the reduction is the intended correction |
| "Use 9+ / 999+ / no truncation" | §5 — `99+` is frozen |
| "FD-2 decided the composition system" | Header — that is FD-6 |
