# CH-02 S4 — EXPLICIT ACTING-CONTEXT IDENTITY CONTRACT

**Canonical obligation:** `CO-RC-C3-006` — *"Contracts inherited by later chapters."*
**Authorized:** founder, 2026-08-18. **Scope:** the explicit acting-context identity contract only.
**Gate:** `test/authority/ch02_s4_acting_context_contract_test.dart` — every clause below is bound to code.

This contract is **inherited**, not advisory. C7 (CH-07) consumes it; CH-08, CH-10 and PD-1 inherit their
own rows of `CO-RC-C3-006` separately.

---

## THE ONE SENTENCE

> **A route may establish the RECIPIENT and the CONTEXT BEING VIEWED.
> It may never establish ACTING IDENTITY.**

Founder ruling, already stated verbatim in `interaction_service.dart`. Everything below follows from it.

---

## 1. THE FOUR CLAUSES

### C1 — `institutionId`-in-path is navigation, not authority

A path beginning `/institution/…` says where a person is looking. It says nothing about who they are
speaking as. This is the frozen ruling from the Meetings router regression, where a booked attendee was
redirected to Institution Sign In because an institution-namespaced URL was read as an institution-actor
claim.

### C2 — `institutionContextId` is VIEWING CONTEXT, never sender authority

The institution inbox and thread receive `institutionContextId` from their own route builder. That is
legitimate and must keep working. What it may never do is become the sender.

**Verified across the whole client: `institutionContextId` appears in no actor, sender or
speak-as construction. It reaches presentation only.**

### C3 — Institutional correspondence is an explicit act, resolved per act

Speaking as an institution is `ConsequentialAct.correspondAsInstitution`, resolved through the
capability projection at the moment of the act — never inferred from where the person happens to be.

### C4 — With no chooser at message initiation, the only correct sender is the person

`interaction_service.dart` sets `ActorRef.user(userId)` unconditionally. This is the **safe default**,
not an omission: absent an explicit choice, defaulting to the person can only under-claim authority,
while defaulting to the institution would silently turn a personal message into institutional
correspondence — which is precisely the defect that was removed.

---

## 2. WHAT IS ALREADY TRUE *(established, not created by S4)*

| | |
|---|---|
| **C3 RETIREMENT (2026-08-16)** | `resolveActorContext` and `_pathIsInstitutionShell` are **DELETED**. They manufactured an institutional acting context from the URL prefix. |
| **Explicit delivery** | Consumers receive context explicitly — Follow-as selection on institution detail; `institutionContextId` on inbox/thread. |
| **Sender today** | Always the person. |

S4 does not re-do this work. **S4 publishes the contract and gates it**, so the retirement cannot be
quietly undone by a future edit.

---

## 3. THE C7 HANDOFF — stated exactly

`CO-RC-C3-006`, verbatim:

> *"C7: membership/invite/join lifecycles + correspondence sender experience MUST consume
> `institutionContextId` + `correspondAsInstitution`; **no route-derived sender may survive C7
> closure**; the institutional-inbox trio's route disposition finalizes with it."*

**The division of labour:**

| Owner | Owns |
|---|---|
| **CH-02 (here)** | The **structural** contract: what a route may and may not establish |
| **CH-07 / C7** | The **chooser experience**: how a person explicitly picks their acting identity at message initiation |

CH-02 does not build the chooser, and C7 may not satisfy its obligation by re-deriving a sender from a
route.

---

## 4. THE KNOWN BASELINED SITE — stated, not hidden

The C1 anti-drift ratchet (`ACTING CONTEXT / route-derived acting identity`) carries **one baselined
file**: `interaction_service.dart`.

It is baselined because the file still *matches the pattern* — it discusses `/institution` paths and
acting identity in the course of documenting the fix — **not because a route-derived sender survives
there**. Its actual sender is `ActorRef.user(userId)`.

The ratchet's own comment records why it is a ratchet rather than zero-tolerance: correcting the last
site means deciding **how a person chooses** to correspond as an institution, which is the founder
checkpoint C7 owns. Changing it unilaterally would either remove a real capability or invent an
interaction pattern.

**This is stated here so a future reader does not mistake a baselined pattern-match for an outstanding
defect.**

---

## 5. PROTECTED BOUNDARY — Meetings

`CO-RC-C3-006` ends: *"Meetings: protected, its 8 institution-context routes untouched."*

**They were not touched.** The institution-namespaced Meetings routes
(`/institution/:institutionId/meetings/…`) remain exactly as they were, and their protection is the
reason C1 exists: an institution-namespaced meeting URL must never make its attendee an institution
actor.

*Observed and not adjudicated:* the router currently declares more institution-context Meetings route
entries than the obligation's figure of 8, depending on whether redirects and sub-routes are counted.
No count is asserted and nothing was changed — the same treatment given to the 34-vs-35 figure, except
that here no reconciliation is owed because nothing in scope depends on the number.

---

## 6. WHAT S4 DOES NOT DO

- Does not build the C7 sender chooser.
- Does not reopen F055 or F056 — both founder-ruled 2026-08-17 and implemented.
- Does not touch CH-03's identity work, F058/CORS, or CH-10's account-entry experience.
- Does not modify Meetings.
- Does not change the shipped default sender.
- Does not clear the C1 ratchet's baselined site — that clearance belongs to C7.
