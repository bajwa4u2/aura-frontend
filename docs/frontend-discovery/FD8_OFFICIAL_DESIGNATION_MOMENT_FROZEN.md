# FD-8 — OFFICIAL DESIGNATION: PRE-PUBLICATION ONLY

# STATUS: FROZEN — FOUNDER APPROVED 2026-08-15
# SELECTED: OPTION A — PRE-PUBLICATION DESIGNATION ONLY

---

## 1. The designation moment

Official designation may **only** be expressed **before publication**, as part of the publication commitment/publish flow. **It is not part of writing/composition.**

```
COMPOSE → CONTENT READY → PUBLISH FLOW → CONFIRM ACTING/PUBLISHING AUTHORITY
  → OFFICIAL DESIGNATION, WHERE AUTHORIZED → REQUIRED INSTITUTIONAL APPROVAL → PUBLISH
```

> **Do not place permanent official-designation machinery into the writing experience merely because the capability exists.**

**FD-6 remains authoritative:** COMPOSITION ≠ REPRESENTATION ≠ DELIVERY/PUBLICATION. **Official designation belongs to the pre-publication governance/publication layer.**

## 2. No post-publication elevation *(Options B and C rejected)*

> **An already-published ordinary institutional publication must NOT later be promoted into `E_OFFICIAL` through a management action.**

Granting official standing after publication would let content acquire official status **without passing the required pre-publication institutional approval floor**.

If substantially the same material later needs to become official, it must **enter an appropriate new official publication lifecycle** — never retroactively acquire official standing.

## 3. Withdrawal is different — and remains legitimate

Withdrawal **removes** standing rather than granting it, so it remains legitimate after publication. It is **object-local to the publication** where authorised.

**Preserve:** actor · timestamp · reason · provenance/history.

> Withdrawal does **not** rewrite historical assessments or pretend the publication was never designated.

## 4. Approval invalidation on edit

> **ANY CONTENT CHANGE AFTER APPROVAL INVALIDATES THE EXISTING APPROVAL.**

```
OFFICIAL CONTENT → APPROVED → CONTENT CHANGED → PREVIOUS APPROVAL STALE → FRESH REVIEW / APPROVAL REQUIRED
```

**The approval belongs to the content that was actually reviewed.**

> **Do not introduce a frontend concept of "minor" versus "substantive" edits** unless a future deterministic governance rule explicitly defines that distinction.

Preserve the backend's existing deterministic stale-review behaviour (content-hash comparison already invalidates a review when content changes).

## 5. User experience

A person must understand the consequence of designation **before committing it**:

> **OFFICIAL DESIGNATION → REQUIRES INSTITUTIONAL APPROVAL BEFORE PUBLICATION.**

**The normal experience must never be:** select Official → press Publish → receive an authorization/governance error.

Where the acting person can designate but cannot grant the approval, the workflow becomes something equivalent to:

```
DESIGNATE AS OFFICIAL → SUBMIT FOR APPROVAL
```

*(Exact copy is subject to **FD-10** terminology adjudication.)*

## 6. Capability-adaptive exposure

Do **not** expose official-designation controls to people or contexts where they are irrelevant. **Authority complexity remains hidden until legitimately exercised.**

The frontend **consumes** acting context · publication capability · designation eligibility · approval state — it **never implements independent institutional-authority logic**.

## 7. Class / governance consequence

Designation puts the publication on the **`E_OFFICIAL` governance path before publication**, so the **mandatory institutional approval floor applies to the actual content that will receive official standing**.

Withdrawal may return **future** review treatment to the appropriate non-official class, but **does not retroactively rewrite assessments already stamped with their historical class**.

## 8. Object-local history

Where authorised, the publication exposes designation state/history **contextually** — not via a distant governance console: current official standing · approval status where relevant · withdrawal · provenance/history.

Apply Capability-Adaptive Experience: **do not expose governance detail without user value.**

---

## 9. Frozen doctrine

> **PRE-PUBLICATION DESIGNATION ONLY.**
> **NO POST-PUBLICATION ELEVATION.**
> **WITHDRAWAL IS OBJECT-LOCAL AND REMAINS LEGITIMATE (IT REMOVES, IT DOES NOT GRANT).**
> **ANY CONTENT CHANGE AFTER APPROVAL INVALIDATES THE APPROVAL.**
> **THE APPROVAL BELONGS TO THE CONTENT ACTUALLY REVIEWED.**
> **DESIGNATION CONSEQUENCE MUST BE UNDERSTOOD BEFORE COMMITMENT — NEVER DISCOVERED AS AN ERROR.**
> **DESIGNATION BELONGS TO PUBLICATION, NOT COMPOSITION.**

## 10. Anti-drift guard

| ❌ Prohibited reading | Why it violates FD-8 |
|---|---|
| "Add an Official toggle to the composer" | §1 — designation belongs to publish, not writing |
| "Let admins mark an existing post official" | §2 — bypasses the pre-publication approval floor |
| "Re-publish it as official from the management screen" | §2 — must enter a new official publication lifecycle |
| "Withdrawal should also be pre-publication only" | §3 — withdrawal removes standing; it stays legitimate |
| "Withdrawal should erase the prior designation" | §3 — provenance is preserved |
| "This was a typo fix, keep the approval" | §4 — no minor/substantive distinction without a deterministic rule |
| "Let Publish fail and show the governance error" | §5 — consequence must be legible in advance |
| "Show designation controls to everyone for consistency" | §6 |
| "Compute locally whether they may designate" | §6 — consume backend eligibility |
| "Withdrawal should reclassify past assessments" | §7 — historical class is not rewritten |
| "Put designation history in the admin console" | §8 — object-local where authorised |
