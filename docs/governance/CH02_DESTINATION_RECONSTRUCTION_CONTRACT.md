# CH-02 S3 — DESTINATION RECONSTRUCTION CONTRACT & PD-2 SEAM ENUMERATION

> **Published under founder ruling 2026-08-18** (PD-2 ratified: CH-02 owns STRUCTURE, CH-10 owns
> ACCOUNT-ENTRY EXPERIENCE). Publishing this enumeration is an implementation/certification
> obligation created by making the already-frozen structural seam explicit — **not** a new decision.
>
> Every clause below is bound to its implementation site by
> `test/navigation/ch02_s3_destination_contract_test.dart`. A clause that stops matching code fails
> the gate. **A contract nothing enforces is a comment.**

**Frozen premise — REFRESH IS NOT NAVIGATION.** A browser refresh is not a request to go somewhere;
it is the same place, re-entered. Everything here follows from that.

---

## 1. The four structural facts

| | Fact | Site |
|---|---|---|
| **C1** | A session hint is a **consequence** of holding a member session, never an act a path performs. Establishment is written at exactly one choke point. | `lib/core/auth/auth_providers.dart` · `TokenStore.setSession` |
| **C2** | Guest tokens never establish a member session hint. | same, `_jwtType(token) != 'guest'` |
| **C3** | Every route the router declares carries a classification. Unknown paths fail **CLOSED**. | `lib/app/route_classification.dart` · `classifyRoute` |
| **C4** | A destination that cannot be reconstructed falls back to a **declared** destination, never to an empty or arbitrary one. | `lib/router.dart` · `_normalizeRedirectDest` |

---

## 2. The redirect/destination reconstruction contract

**The mechanism is one query parameter: `?redirect=`.** It is the product's memory of where a person
was going when authentication interrupted them.

### 2.1 Who may write it

Only the router's `redirect` callback. A feature surface that builds its own
`/login?redirect=…` is re-implementing destination authority and is a contract violation.

### 2.2 The four interruption points

Each preserves the destination and hands it to the ceremony that must complete first.

| Interruption | Condition | Emits | Preserves |
|---|---|---|---|
| **Not authenticated** | `requiresAuth(path) && !isPublic` | `/login?redirect=<dest>` | current location |
| **Identity baseline incomplete** | `isIdentityBaselineComplete == false` | `/complete-identity?redirect=<dest>` | intended destination |
| **Email unverified** | `isVerified == false` | `/verify-pending?redirect=<dest>` | intended destination |
| **Cold boot** | `isBootPath(path)` | resolves the carried destination | destination across the whole cold load |

**Ordering is load-bearing.** Identity baseline is evaluated **before** email verification so the two
independent "authed but incomplete" gates never fight over which wins on a cold boot, reopen or
refresh. Reversing them makes the winner depend on arrival path.

### 2.3 Normalization — fail-closed by construction

`_normalizeRedirectDest(dest, {fallback})` returns the **fallback** when the destination is: empty,
`/`, not absolute (does not start with `/`), or the boot path itself. Otherwise it is normalized
through `normalizeMemberFacingRoute`.

**This is clause C4 and it is the fail-closed behaviour required where destination reconstruction
cannot be proven:** an unprovable destination becomes a *declared* destination — `/public` when
signed out, `/home` when signed in — never an empty string, never an unvalidated echo of user input.
The boot path is excluded explicitly so a redirect can never loop through the boot route.

---

## 3. PD-2 SEAM ENUMERATION

The founder ruling requires this enumeration to identify six things. Each has its own subsection.

### 3.1 Structural auth/destination routes — **GOVERNED BY CH-02**

CH-02 owns these as **structure**: what the route means, when it is entered, what it preserves,
and where it goes next.

| Route | Class | Structural role |
|---|---|---|
| `/_boot` | boot | Cold-load destination resolution. Not a surface — a decision point. |
| `/complete-identity` | `authAction` | Identity-baseline gate; **evaluated before verification**. |
| `/verify-pending` | `authAction` | Verification gate; carries the destination forward. |
| `/verify-email` | `authAction` | Verification ceremony completion. |
| `/institution/sign-in` | `authAction` | Institution authority establishment. **Not** a member surface, and **not** an institution-actor claim — see 3.5. |
| `/auth` → `/login` | alias | Retired address; must stay alias-resolvable, never buildable (DR4). |

### 3.2 Account-entry experience surfaces — **GOVERNED BY CH-10**

CH-10 owns these as **experience**: what they look like, what they say, and how well they convert.

| Route | Class | Experience role |
|---|---|---|
| `/login` | `authAction` (plain auth page) | Sign-in experience |
| `/register` | `authAction` (plain auth page) | Sign-up experience |
| `/forgot-password` | `authAction` | Recovery entry experience |
| `/reset-password` | `authAction` | Recovery completion experience |

### 3.3 The ownership boundary at each crossing

There are exactly **three** crossings. At each, the rule is the same: **CH-02 decides that a
redirect happens and what it carries; CH-10 decides what the person sees when they arrive.**

| # | Crossing | CH-02 owns | CH-10 owns |
|---|---|---|---|
| **X1** | Unauthenticated member route → `/login?redirect=…` | the decision to interrupt, the preserved destination, the fail-closed fallback | the login surface and its copy |
| **X2** | `/register` completes → session established | that establishing a session writes the hint at the choke point (C1) | the sign-up surface, and preserving *intent* through it (**F104**) |
| **X3** | Auth completes → return to destination | resolving and normalizing the carried destination (C4), and returning to the **same** Live (**F103**) | the completion experience |

**The seam is not a file boundary — it is a decision boundary.** CH-10 may change every pixel of
`/login` without consulting CH-02. CH-10 may **not** change what `?redirect=` carries, what happens
when it cannot be reconstructed, or the order of the identity/verification gates. Those are C1–C4.

### 3.4 Shared dependencies

| Dependency | Shared between | Rule |
|---|---|---|
| `?redirect=` parameter | CH-02 (writes) · CH-10 (carries through the ceremony) | CH-10 must **preserve it unmodified**. It may not re-encode, shorten, or substitute it. |
| `RouteClass` classification | CH-02 · CH-10 · CH-04 (guest-reachable) | Single source: `route_classification.dart`. No second classifier. |
| `TokenStore.setSession` | CH-02 (structure) · CH-10 (invokes on sign-in/up) | CH-10 calls it; CH-10 does **not** write the session hint. Gated by `ch02_s1_session_choke_point_test.dart`. |
| Session hint (`aura_session_hint`) | CH-02 (owner) · bootstrap (reader) | One establishment site; clears are enumerated and justified. |

### 3.5 Fail-closed behaviour where destination reconstruction cannot be proven

Five distinct fail-closed behaviours, each already implemented and each gated:

1. **Unclassified route → member.** No declared route falls through to the fail-closed default;
   unknown paths are never public. *(F069 gate)*
2. **Unprovable destination → declared fallback.** `/public` signed out, `/home` signed in. Never
   empty, never an unvalidated echo. *(C4)*
3. **Unknown authentication → not unauthenticated.** `UNKNOWN`/`RESTORING` must not be treated as
   signed out; the router waits rather than discarding the destination. **This is F065.**
4. **Guest token → no member hint.** A guest holds no member refresh cookie; claiming otherwise makes
   every later cold load ask blindly for a cookie that cannot exist. *(C2)*
5. **Institution path ≠ institution actor.** A meeting URL carrying institution context does **not**
   make its attendee an institution actor. Authentication decides who the person is; institution
   authority decides whether they may act as the institution; meeting attendance authority decides
   whether they may attend. *(frozen 2026-08-14 after the booked-attendee regression)*

---

## 4. What this contract does NOT establish

- **F103 and F104 remain `OPEN`.** They are gated by F065's live proof. Publishing the contract that
  governs them does not close them.
- **F065 remains `IMPLEMENTED_NOT_LIVE_CERTIFIED`.** The live refresh proof has not been performed;
  it is the chapter's own first gate and requires founder observation under PB-11.
- **No chapter is closed.** CH-02 remains open; CH-10 has not been entered.
- **CH-10's experience work is not started.** Only the boundary is published.

---

## MOBILE NAVIGATION DOCTRINE (founder ruling, 2026-08-23)

Recorded as doctrine, not as a Pixel-specific workaround. It governs Android,
iOS and equivalent narrow presentations. Desktop is deliberately NOT forced
into the same model.

**Mobile Aura does not duplicate primary destinations across bottom
navigation, drawer and header merely because all three containers exist.**
Each chrome region has a distinct responsibility:

| Region | Owns |
|---|---|
| Bottom navigation | Home, Create, Messages, Discover — primary product movement |
| Drawer | account, institutional context, global/secondary destinations |
| Discover | global search and exploration |
| Top header | contextual identity, and attention only where genuinely earned |

**The top header may legitimately become very light. Its emptiness is not a
problem and is not backfilled.** Do not optimise for filling available chrome;
optimise for clear hierarchy and contextual relevance.

### What the audit found, and what it changed

The defect that exposed this was reported as a header collision. It was not
primarily a layout bug: at 411dp the tools row pushed the ACCOUNT BUTTON off
the screen entirely, taking identity and sign-out with it. Narrowing the pill
made it fit; it did not make the architecture right.

- **The drawer was a copy of the bar beneath it.** It rendered the same four
  `PrimaryDestination`s the bottom bar owns, and nothing else but the identity
  header. Removing them removes duplicate NAVIGATION, not capability.
- **"Activity" and the bell are ONE control, not two.** `activityPath` is
  `/notifications`, and the same button carries the unread count. The ruling
  listed them separately; the built product had merged them.
- **Notification attention stays in the header, and that is evidence-based.**
  It is personal and immediate, and nothing else projects it persistently —
  the bottom bar badges Messages, not notifications — so burying it would have
  destroyed the signal rather than relocated it.
- **Search needed no new home.** Discover already embedded it as its primary
  affordance. The convergence was removing the header's competing copy.
- **Live was classified, not inherited.** The ruling did not name it. Applying
  the ruling's own taxonomy: Live is global exploration, and its indicator is
  AMBIENT (someone is live) rather than personal unread, so it joins the other
  global destinations in the drawer. Flagged as a classification call.

### The boundary that must not move

Responsive presentation difference is legitimate; authority difference is not.
Shared across form factors: destination identity, authority, audience/privacy,
contextual projection, navigation semantics. May differ: where a destination is
presented — drawer, rail, header or bottom bar. No separate mobile permission
or navigation authority was created; the same canonical Navigation and
Capability Authorities are consumed.
