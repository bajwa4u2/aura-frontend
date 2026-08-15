# CANONICAL COMPOSITION SYSTEM + CONTEXT-GOVERNED EXPERIENCE

# STATUS: FROZEN — FOUNDER APPROVED 2026-08-15

**Identified by NAME.** Not by option letter.

## ⚠ Decision-number reconciliation (read first)

The founder instruction that froze this decision referred to it as **"FD-2"**. In the `FOUNDER_DECISION_REGISTER.md` numbering, **FD-2 is a different decision — *Attention vocabulary*, which remains OPEN.**

| Founder instruction label | Register entry actually resolved | Register status |
|---|---|---|
| "FD-2 — Composer / Messaging / Attachment Architecture" | **FD-6 — Composition architecture** | ✅ **RESOLVED by this decision** |
| — | **FD-7 — Attachment send model** | **CONSTRAINED, still open** (§6 separates attachment lifecycle from communication lifecycle but does not name the send mechanism) |
| — | **FD-2 — Attention vocabulary** | **STILL OPEN — not resolved by this decision** |

> **Do not read "FD-2 resolved" as meaning attention vocabulary was frozen.** It was not. The register numbering is unchanged; this decision is authoritative **by name**.

## Decision history (auditable)

| Step | Record |
|---|---|
| 1 | Original discovery proposed FD-6 options **A / B / C** (A = one composition authority + per-surface policy · B = two engines, message vs publication · C = shared attachment pipeline only). |
| 2 | The founder approved the direction of **A**, defined more fully as *Canonical Composition System + Context-Governed Experience*. |
| 3 | This definition **supersedes the original option set** where necessary. |

---

## 1. Core decision

The fragmented composer/upload architecture — **6 composer implementations, 11 upload pipelines** — does not survive. It must **not** be solved by making those implementations merely visually consistent.

> **ONE CANONICAL COMPOSITION SYSTEM + SHARED ATTACHMENT / MEDIA LIFECYCLE + CONTEXT-GOVERNED PRODUCT SEMANTICS + CAPABILITY-ADAPTIVE PRESENTATION.**

This does **not** mean one giant universal text-box UI used identically everywhere.

---

## 2. Three concepts kept distinct

| Concept | Question | Owner |
|---|---|---|
| **A. Composition** | what content is being created | canonical composition system |
| **B. Representation** | who is acting/speaking | **FD-9 Contextual Acting Authority** |
| **C. Delivery / Publication** | what governed action commits the communication | owning domain + backend authority |

```
ACTING CONTEXT + OWNING PRODUCT CONTEXT + COMPOSITION + BACKEND AUTHORITY
  → AUTHORIZED DELIVERY / PUBLICATION ACTION
```

**No composer may independently reconstruct these concepts.**

---

## 3. Canonical composition foundation

Shared concerns, never reinvented per surface: text/content state · drafts · autosave where appropriate · attachments · media · mentions · links · link previews · internal link hydration · formatting · validation · upload state · retry/failure · edit state · send/publish readiness · keyboard behaviour · paste · drag/drop where supported · accessibility · abandonment/recovery.

*(Directly addresses Finding C1: capability currently distributed with no product logic — hashtags in 1 of 6 composers, upload progress in 1 of 6.)*

---

## 4. Owning domain retains semantics

Shared composition infrastructure does **NOT** mean shared communication semantics.

| Surface | Semantics |
|---|---|
| **DM** | private conversation → Send |
| **Thread** | thread-owned conversation/reply |
| **Space** | space-owned participation |
| **Personal post** | personal publication |
| **Institution post** | institutional acting context + institutional publication authority |
| **Announcement** | governed official/institutional publication |
| **Correspondence** | correspondence-owned recipient and communication semantics |
| **Future Live** | live/public participation semantics |

> **Do not force every surface to say Send or Publish merely for consistency.** CTA vocabulary remains subject to FD-10 (open).

---

## 5. Attachment / media architecture

The ~11 independent upload pipelines are a **DEMOLISH + REBUILD / CONVERGENCE** candidate.

```
SELECT / DROP / PASTE → VALIDATE → PREVIEW → UPLOAD → PROGRESS
  → CANCEL → RETRY → ATTACH → SEND / PUBLISH → RENDER / OPEN
```

**Context policy** determines allowed media/file types · size constraints · count · publication eligibility · permissions · other legitimate domain differences.

> **Do NOT duplicate upload mechanics merely because different surfaces permit different attachment types.**

---

## 6. Attachment state ≠ communication state

Uploading an attachment must **not** automatically mean the communication was sent, the post published, the message exists, or publication authority was exercised.

Preserve the distinction between **attachment lifecycle** and **communication / publication lifecycle**. Handle abandoned/orphaned uploads deliberately.

*(Constrains register FD-7, which remains open on the specific send mechanism.)*

---

## 7. Default composer experience

Dramatically simpler and more curated than today. The default exposes **only what is necessary for the person's immediate act**. No visually heavy control cockpit merely because the system supports many capabilities.

Progressive disclosure for: advanced formatting · attachments/media · audience controls · institutional controls · publication options · additional metadata · advanced recipient controls.

> **The composer should become more capable underneath while appearing simpler to the person using it.**

---

## 8. Demolition direction

Classified **DEMOLISH + REBUILD / CONVERGE, while salvaging proven product behaviour.** Six composers and eleven upload pipelines do not survive as architectural authorities.

**Preserve where valid:** backend contracts · supported content behaviour · attachment/media capabilities · drafts/data · proven validation behaviour · accessibility behaviour · legitimate context differences · working media rendering · user-visible capabilities that remain product-correct.

**The existing implementation form is not sacred.**

---

## 9. Frozen doctrine

> **ONE CANONICAL COMPOSITION SYSTEM.**
> **SHARED ATTACHMENT / MEDIA LIFECYCLE.**
> **OWNING DOMAINS RETAIN COMMUNICATION SEMANTICS.**
> **ACTING CONTEXT SUPPLIES REPRESENTATION.**
> **BACKEND SUPPLIES AUTHORITY.**
> **COMPOSITION, REPRESENTATION AND DELIVERY/PUBLICATION ARE DISTINCT.**
> **THE CURRENT FRAGMENTED COMPOSER/UPLOAD IMPLEMENTATION IS A DEMOLISH + REBUILD / CONVERGENCE CANDIDATE.**

---

## 10. Anti-drift guard

| ❌ Prohibited reading | Why it violates this freeze |
|---|---|
| "Make the six composers look the same" | §1 — visual consistency is explicitly not the solution |
| "One universal text box everywhere" | §1, §4 |
| "Every surface says Send" | §4 |
| "Each composer keeps its own upload code because its file types differ" | §5 |
| "Upload succeeded, so the message is sent" | §6 |
| "Show all capabilities; the system supports them" | §7 |
| "Composer decides who may publish" | §2, backend supplies authority |
| "Each composer implements post-as-institution" | §2 (and FD-9 §7) |
| "This decision froze attention vocabulary" | Reconciliation note — register FD-2 remains **open** |
| "This authorizes deleting the composers now" | §8 — planning permission, not implementation |
