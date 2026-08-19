# W1 EXIT — FOUNDER LIVE-CERTIFICATION PROCEDURES

**Two procedures. Nothing else.** No further architecture or implementation is performed while these await observation.
**Site:** `https://auraplatform.org` · **Account:** `review@auraplatform.org`
**Date prepared:** 2026-08-18

---

## STEP 0 — BUILD IDENTITY *(do this first; it can invalidate everything below)*

These procedures certify **whatever build is currently deployed**, not the local tree.

F065's structural fix is recorded as *"structural fix pushed"* — **pushed, not confirmed deployed**. The
Part-1/Part-2 refinements (S1's call-site removal, the S3 contract, CH-11's ingestion door) are
committed locally and are **not deployed**.

**0.1** Confirm the deployed web build contains the session-hint fix at `TokenStore.setSession`.
**0.2** If it does not, deploy first. *Deployment is a founder act; I have not performed or polled it.*

> A PASS recorded against a build that lacks the fix certifies nothing. If you are unsure which build
> is live, say so and I will treat the result as **NOT_ESTABLISHED** rather than PASS.

---

# A. F065 / PB-11 — LIVE REFRESH PROOF

**Frozen doctrine being tested:** *AUTHENTICATION UNKNOWN/RESTORING IS NOT UNAUTHENTICATED.*

**Why A2 is the real proof.** The defect was never that password login broke — that path always wrote
the hint. It was that sessions established by **every other path** (institution sign-in, guest/booker
auth, bootstrap refresh, silent re-auth after a 401) left the hint unwritten, so the next reload
skipped `/auth/refresh` and the app declared the person signed out. **A1 is the control. A2 is the
proof.** A PASS on A1 alone does not certify F065.

**The critical observable is the transient state**, not just the end state. Watch the address bar
*during* the reload.

### A1 — Control: password login *(the path that always worked)*

1. Open `https://auraplatform.org` in a normal (non-incognito) window, **signed out**.
2. Sign in with `review@auraplatform.org`.
3. Navigate to `/home`. Confirm the address bar reads `/home` and you are signed in.
4. Press **F5** (hard reload).
5. **Watch the address bar throughout the reload.**

| | |
|---|---|
| **Expected before refresh** | `/home`, signed in |
| **Expected after refresh** | `/home`, **still signed in** |
| **PASS** | The address bar never shows `/login` at any point, and you end on `/home` signed in |
| **FAIL** | Any of: you land on `/login`; `/login` appears even briefly mid-reload; you end signed out; you end somewhere other than `/home` |

### A2 — **THE PROOF: a session established by a non-password path**

6. Sign out completely.
7. Establish a session via **institution sign-in** (`/institution/sign-in`) — one of the paths recorded
   as leaving the hint unwritten. *(If the reviewer account cannot use institution sign-in, use any
   other non-password establishment path available to you and tell me which one you used — the path
   matters to what this certifies.)*
8. Navigate to a member destination (`/home` or an institution surface). Note the exact address.
9. Press **F5**.
10. **Watch the address bar throughout the reload.**

| | |
|---|---|
| **Expected before refresh** | the noted member destination, signed in |
| **Expected after refresh** | the **same** destination, **still signed in** |
| **PASS** | No `/login` at any point; same destination; still signed in |
| **FAIL** | Any drop to `/login`, any sign-out, or any loss of the destination |

### A3 — Negative control: guest meeting entry must NOT gain a member session

11. In a **separate incognito window**, open a meeting guest/booking link (a `/meet/…` address).
12. Enter as a **guest** (no Aura account).
13. Press **F5**.

| | |
|---|---|
| **Expected** | You are **not** signed in as an Aura member. No member session appears. |
| **PASS** | Refresh does not produce a member session |
| **FAIL** | You appear signed in as a member, or as the review account |

> **Read this before judging A3.** A guest holds no member refresh cookie, so the guest exclusion is
> deliberate. **If the guest loses their place in the meeting on refresh, that is F064 / F113 — both
> recorded OPEN — and is NOT a failure of this proof.** Note it separately; do not fail A3 for it.

---

# B. S2 — SIGNED-OUT LIVE PROBE

**Testing:** the fail-closed route classification and the destination-reconstruction contract.
**Starting authentication condition for every step: SIGNED OUT.** Use a fresh incognito window.

### B1 — A member route interrupts and preserves the destination

1. Signed out, go to `https://auraplatform.org/home`.

| | |
|---|---|
| **Expected** | Redirected to `/login`, with the destination preserved in the URL — `?redirect=%2Fhome` (or `/home`) |
| **PASS** | You land on `/login` **and** the address bar carries the redirect parameter naming `/home` |
| **FAIL** | `/home` renders while signed out · you reach `/login` with **no** redirect parameter · you land anywhere else |

### B2 — Account entry returns you to the preserved destination

2. From that screen, sign in with `review@auraplatform.org`.

| | |
|---|---|
| **Expected** | You arrive at **`/home`** — the destination you originally asked for |
| **PASS** | You land on `/home` |
| **FAIL** | You land on a generic landing page, or anywhere other than `/home` |

> This is the CH-02 / CH-10 seam in one action: CH-02 decided the interrupt and carried the
> destination; CH-10 owned the screen you just used.

### B3 — An unknown route fails **CLOSED**

3. Sign out. Signed out, go to `https://auraplatform.org/zzz-not-a-route`.

| | |
|---|---|
| **Expected** | Treated as a **member** route: redirected to `/login` |
| **PASS** | You are redirected to `/login` |
| **FAIL** | Public content renders · a bare 404 renders **without** requiring sign-in · anything reachable without authentication |

### B4 — `/admin` still refuses unauthenticated entry

4. Signed out, go to `https://auraplatform.org/admin`.

| | |
|---|---|
| **Expected** | Redirected to `/login`. No admin surface renders. |
| **PASS** | Redirected to `/login` |
| **FAIL** | Any admin surface, shell or navigation renders while signed out |

> Platform Administration is **out of reconstruction scope** by your PD-1 ruling — and that exclusion
> is explicitly **not** a security bypass. This step is that assertion, live.

### B5 — Public routes are still open *(the fail-closed contract must not have closed everything)*

5. Signed out, go to `https://auraplatform.org/public`.

| | |
|---|---|
| **Expected** | The public surface renders. **No** redirect to `/login`. |
| **PASS** | Public content renders while signed out |
| **FAIL** | You are redirected to `/login` — the classification has over-closed and acquisition is broken |

### B6 — Optional: an unprovable destination falls back to a declared one

6. Signed out, go to `https://auraplatform.org/login?redirect=notavalidpath` then sign in.

| | |
|---|---|
| **Expected** | You land on a **declared** destination (`/home`), never a blank screen, an error, or `notavalidpath` |
| **PASS** | You land on `/home` |
| **FAIL** | Blank screen, error, or navigation to the raw value |

---

## HOW TO RETURN RESULTS

For each step, one line is enough:

```
A1 PASS
A2 FAIL — dropped to /login during reload, ended signed out
A3 PASS  (guest lost meeting place — noting separately)
B1 PASS
...
```

Please also state, from Step 0, **which build was live**.

## WHAT I WILL AND WILL NOT DO WITH THE RESULTS

- I will record your observation **exactly as given** and adjudicate PASS/FAIL against the criteria
  above **as predeclared** — not against criteria adjusted after the fact.
- I will update evidence state **only to the level proven**.
- **I will not infer PASS from local or static evidence, and I will not self-certify PB-11.**
- If **A** passes, G1 opens and I proceed into W2 under the existing Stage-5 architecture — unless
  another explicit gate blocks its first unit.
- If **either** proof fails, I stop, report the observed failure and its bounded implicated authority,
  and **change no code** until you rule.
