# FD-9 — CONTEXTUAL ACTING AUTHORITY

# STATUS: FROZEN — FOUNDER APPROVED 2026-08-15

**The canonical identity of this decision is its NAME: _Contextual Acting Authority_.** It is deliberately not identified by an option letter.

## Decision history (auditable)

| Step | Record |
|---|---|
| 1 | The original discovery proposed FD-9 options **A / B / C**. |
| 2 | Original **Option C = "Separate institution shell"**. |
| 3 | The founder **did NOT select that proposal**. Original Option C is **REJECTED**. |
| 4 | During adjudication, a **distinct model — Contextual Acting Authority — was defined**. |
| 5 | The founder **approved that newly defined model**. |
| 6 | This substantive decision **supersedes the original FD-9 option set** where necessary. |

> **Do not restate this decision as "FD-9 Option C".** Doing so could be read as approval of the rejected separate-institution-shell proposal, which is precisely the authority drift this program exists to eliminate. No replacement letter has been invented — **the decision name is authoritative**.

---

## 1. Core decision

> **ONE RELEASE CLIENT + ONE COHERENT NAVIGATION ARCHITECTURE + FIRST-CLASS CONTEXTUAL ACTING AUTHORITY.**

- Do **not** preserve separate mirrored personal/institution applications or route trees merely because historical implementation created them.
- Do **not** make a permanent global Personal/Institution toggle the organising principle of the product.
- Acting context is a **governed product concept**.

---

## 2. Default actor

The **authenticated PERSON is the default actor.**

```
AUTHENTICATED PERSON
  → BACKEND-ELIGIBLE ACTING CONTEXTS
    → ACTIVE ACTING CONTEXT
      → CLIENT CAPABILITIES / NAVIGATION / COMPOSERS / ACTIONS
        → BACKEND FINAL AUTHORITY
```

A person may hold authority to act for one or more institutions. The frontend **consumes** that authority.

It must **NOT** reconstruct or infer institutional authority from: local role names · route prefixes · cached membership assumptions · UI state · duplicated permission logic.

*(This directly governs Finding M1: 29 files performing role comparisons and 20 computing capability booleans.)*

---

## 3. Contextual institution acting

When the user deliberately enters institution-owned work, the client establishes the appropriate institution acting context — conceptually *"Muhammad Sakhawat acting as Aura Platform LLC"*.

**Visual treatment is NOT frozen.** The frozen requirement is:

> **INSTITUTIONAL REPRESENTATION MUST REMAIN CLEARLY ATTRIBUTABLE.**

Where acting context materially affects representation, authority, communication, publication, moderation, invitation or another consequential action, the user must understand which identity is acting.

---

## 4. No invisible representational switching

**Contextual does NOT mean invisible.** The client must never silently switch a user into institutional representation in a way that could cause accidental institutional speech or action.

Especially protected: publishing · posting · messaging/correspondence · replying · inviting · starting governed communication · moderating · administering · approving · representing an institution publicly.

Acting identity must be **sufficiently visible at the point of consequential action**.

---

## 5. Route-tree consequence

The ~40 mirrored institution routes become explicit reconstruction/demolition candidates. For **each**, determine:

| Test | Outcome |
|---|---|
| **A.** Genuinely a different institution-owned **product semantic** | separation may remain |
| **B.** The same capability rendered under a different **acting context** | should generally **not** survive as separate product architecture |

Do not automatically preserve `/posts` + `/institution/posts`, `/messages` + `/institution/messages`, `/profile` + `/institution/profile` simply because they exist today.

> **Do not mechanically merge everything.** Where institutional ownership creates genuinely different product semantics, separation may remain. Ambiguous cases return for adjudication.

---

## 6. Navigation principle

> Navigation expresses **WHAT THE USER IS TRYING TO DO**, not **WHICH HISTORICAL ROUTE TREE THEY ARE INSIDE**.

Acting context is **state/authority**. It must not unnecessarily duplicate the entire information architecture.

---

## 7. Composer consequence

The future composition system **consumes governed acting context**. No composer may independently implement "post as institution" / "send as institution" / "reply as institution" via local role checks or unrelated selectors.

```
ACTING CONTEXT + SURFACE CAPABILITY + BACKEND AUTHORITY
  → AVAILABLE REPRESENTATIONAL ACTION
```

Where multiple legitimate acting identities exist for an action, selection must be **deliberate and understandable**.

*(Governs Finding C3: institution voice currently implied by which composer was opened.)*

---

## 8. Profile / identity consequence

Three distinct concepts, never collapsed to simplify UI:

| Concept | Meaning |
|---|---|
| **Person identity** | the authenticated person |
| **Acting context** | on whose authorised behalf an action is taken |
| **Institution profile** | the institution itself |

---

## 9. Realtime consequence — compatibility with FD-3

FD-9 **must remain compatible with frozen FD-3**. Realtime semantics remain owned by DM · Thread · Space · Institution Room · Meeting · future Live.

> Acting context determines **authorised representation within** those contexts. It **does NOT redefine their product semantics.**

---

## 10. Modern, simplified experience

Context selection/switching must be modern, minimal and curated. **Not an enterprise account-switching maze.**

It should: make current acting identity understandable · make legitimate alternative contexts discoverable · minimise unnecessary switching · preserve context naturally while working · prevent accidental representation · avoid repetitive identity selection · clearly signal consequential context changes.

Research contemporary patterns later; **do not copy another product.**

---

## 11. Backend remains final authority

The frontend Acting Context Authority must **NOT become shadow authorization.**

| Backend determines | Frontend responsibility |
|---|---|
| eligible institutional relationships | maintain coherent active context |
| roles / capabilities | present it |
| permissions | propagate it correctly |
| whether an action is allowed | prevent UX ambiguity |
| representational authority | consume backend eligibility/authority |

---

## 12. Demolition authorization boundary

This decision establishes **architectural permission to recommend** demolition of mirrored institution navigation/routes whose only justification is historical acting-context duplication.

> **It does NOT authorize implementation or deletion.**

- **PRESERVE** — genuinely different institutional product semantics.
- **DEMOLISH / CONVERGE** — duplicated personal/institution surfaces differing only by acting context.
- **ADJUDICATE** — ambiguous cases.

---

## 13. Enforcement expectation

Acting Context becomes an explicit frontend authority, not developer convention. Later design should investigate: canonical Acting Context authority/controller · restricted direct role interpretation · consumer boundaries · navigation integration · composer integration · architecture tests · source-level gates.

Exact implementation remains for later design.

---

## 14. Frozen doctrine

> **ONE RELEASE CLIENT.**
> **ONE COHERENT NAVIGATION ARCHITECTURE.**
> **PERSON IS THE DEFAULT ACTOR.**
> **INSTITUTIONAL ACTING CONTEXT IS ENTERED DELIBERATELY AND REMAINS ATTRIBUTABLE.**
> **BACKEND AUTHORITY DEFINES ELIGIBLE ACTING CONTEXTS AND PERMISSIONS.**
> **FRONTEND DOES NOT LOCALLY INFER REPRESENTATIONAL AUTHORITY.**
> **MIRRORED PERSONAL/INSTITUTION ROUTE TREES SHOULD BE DEMOLISHED WHERE THEIR ONLY PURPOSE IS ACTING-CONTEXT DUPLICATION.**
> **GENUINELY DIFFERENT PRODUCT SEMANTICS REMAIN DISTINCT.**
> **SIMPLIFY THE EXPERIENCE WITHOUT SIMPLIFYING AWAY AUTHORITY.**

---

## 15. Anti-drift guard

| ❌ Prohibited reading | Why it violates FD-9 |
|---|---|
| "Keep the mirrored routes, they work" | §1, §5, §14 |
| "Add a global Personal/Institution toggle as the main navigation" | §1 |
| "Acting context can switch silently to reduce friction" | §4 |
| "Merge every mirrored route mechanically" | §5, §12 |
| "The client can infer institution authority from the route prefix" | §2, §11 |
| "Each composer can keep its own post-as-institution selector" | §7 |
| "Person identity and institution profile can be one surface" | §8 |
| "Acting context changes what a Meeting or Room *is*" | §9 (and FD-3) |
| "Acting Context Authority decides whether an action is allowed" | §11 — that is shadow authorization |
| "FD-9 authorizes deleting the mirrored routes now" | §12 — permission to *recommend*, not to implement |
| "Founder selected FD-9 **Option C**" | Decision history — original Option C was *separate institution shell* and was **REJECTED**. This decision is identified by **name**, never by letter |
